/*-------------------------------------------------------------------------
 *
 * mysql_fdw.c
 * 		Foreign-data wrapper for remote MySQL servers
 *
 * Portions Copyright (c) 2012-2014, PostgreSQL Global Development Group
 * Portions Copyright (c) 2004-2020, EnterpriseDB Corporation.
 *
 * IDENTIFICATION
 * 		mysql_fdw.c
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

/*
 * Must be included before mysql.h as it has some conflicting definitions like
 * list_length, etc.
 */
#include "mysql_fdw.h"

#include <dlfcn.h>
#include <errmsg.h>
#include <mysql.h>
#include <stdio.h>
#include <sys/stat.h>
#include <unistd.h>

#include "access/htup_details.h"
#include "access/sysattr.h"
#include "access/reloptions.h"
#if PG_VERSION_NUM >= 120000
#include "access/table.h"
#endif
#include "commands/defrem.h"
#include "commands/explain.h"
#include "foreign/fdwapi.h"
#include "miscadmin.h"
#include "mysql_query.h"
#include "nodes/makefuncs.h"
#include "nodes/nodeFuncs.h"
#include "optimizer/pathnode.h"
#include "optimizer/planmain.h"
#include "optimizer/paths.h"
#if PG_VERSION_NUM < 120000
#include "optimizer/var.h"
#else
#include "optimizer/optimizer.h"
#endif
#include "optimizer/cost.h"
#include "optimizer/clauses.h"
#include "optimizer/tlist.h"
#include "optimizer/restrictinfo.h"
#include "parser/parsetree.h"
#include "storage/ipc.h"
#include "utils/builtins.h"
#include "utils/datum.h"
#include "utils/guc.h"
#include "utils/lsyscache.h"
#include "utils/memutils.h"
#include "utils/syscache.h"
#include "utils/selfuncs.h"

/* Declarations for dynamic loading */
PG_MODULE_MAGIC;

/* Default CPU cost to start up a foreign query. */
#define DEFAULT_FDW_STARTUP_COST	100.0

/* Default CPU cost to process 1 row (above and beyond cpu_tuple_cost). */
#define DEFAULT_FDW_TUPLE_COST		0.01

/* If no remote estimates, assume a sort costs 20% extra */
#define DEFAULT_FDW_SORT_MULTIPLIER 1.2

int ((mysql_options) (MYSQL *mysql, enum mysql_option option,
					  const void *arg));
int ((mysql_stmt_prepare) (MYSQL_STMT *stmt, const char *query,
						   unsigned long length));
int ((mysql_stmt_execute) (MYSQL_STMT *stmt));
int ((mysql_stmt_fetch) (MYSQL_STMT *stmt));
int ((mysql_query) (MYSQL *mysql, const char *q));
bool ((mysql_stmt_attr_set) (MYSQL_STMT *stmt,
							 enum enum_stmt_attr_type attr_type,
							 const void *attr));
bool ((mysql_stmt_close) (MYSQL_STMT *stmt));
bool ((mysql_stmt_reset) (MYSQL_STMT *stmt));
bool ((mysql_free_result) (MYSQL_RES *result));
bool ((mysql_stmt_bind_param) (MYSQL_STMT *stmt, MYSQL_BIND *bnd));
bool ((mysql_stmt_bind_result) (MYSQL_STMT *stmt, MYSQL_BIND *bnd));

MYSQL_STMT *((mysql_stmt_init) (MYSQL *mysql));
MYSQL_RES *((mysql_stmt_result_metadata) (MYSQL_STMT *stmt));
int ((mysql_stmt_store_result) (MYSQL *mysql));
MYSQL_ROW((mysql_fetch_row) (MYSQL_RES *result));
MYSQL_FIELD *((mysql_fetch_field) (MYSQL_RES *result));
MYSQL_FIELD *((mysql_fetch_fields) (MYSQL_RES *result));
const char *((mysql_error) (MYSQL *mysql));
void ((mysql_close) (MYSQL *sock));
MYSQL_RES *((mysql_store_result) (MYSQL *mysql));
MYSQL *((mysql_init) (MYSQL *mysql));
bool ((mysql_ssl_set) (MYSQL *mysql, const char *key, const char *cert,
					   const char *ca, const char *capath,
					   const char *cipher));
MYSQL *((mysql_real_connect) (MYSQL *mysql, const char *host, const char *user,
							  const char *passwd, const char *db,
							  unsigned int port, const char *unix_socket,
							  unsigned long clientflag));

const char *((mysql_get_host_info) (MYSQL *mysql));
const char *((mysql_get_server_info) (MYSQL *mysql));
int ((mysql_get_proto_info) (MYSQL *mysql));

unsigned int ((mysql_stmt_errno) (MYSQL_STMT *stmt));
unsigned int ((mysql_errno) (MYSQL *mysql));
unsigned int ((mysql_num_fields) (MYSQL_RES *result));
unsigned int ((mysql_num_rows) (MYSQL_RES *result));
unsigned int ((mysql_warning_count)(MYSQL *mysql));
uint64_t ((mysql_stmt_affected_rows) (MYSQL_STMT *stmt));

#define DEFAULTE_NUM_ROWS    1000

/*
 * In PG 9.5.1 the number will be 90501,
 * our version is 2.5.5 so number will be 20505
 */
#define CODE_VERSION   20505

/* Struct for extra information passed to estimate_path_cost_size() */
typedef struct
{
	PathTarget *target;
	bool		has_final_sort;
	bool		has_limit;
	double		limit_tuples;
	int64		count_est;
	int64		offset_est;
} MySQLFdwPathExtraData;

/*
 * This enum describes what's kept in the fdw_private list for a ForeignPath.
 * We store:
 *
 * 1) Boolean flag showing if the remote query has the final sort
 * 2) Boolean flag showing if the remote query has the LIMIT clause
 */
enum FdwPathPrivateIndex
{
	/* has-final-sort flag (as an integer Value node) */
	FdwPathPrivateHasFinalSort,
	/* has-limit flag (as an integer Value node) */
	FdwPathPrivateHasLimit
};

/* Callback argument for ec_member_matches_foreign */
typedef struct
{
	Expr	   *current;		/* current expr, or NULL if not yet found */
	List	   *already_used;	/* expressions already dealt with */
} ec_member_foreign_arg;

/*
 * Similarly, this enum describes what's kept in the fdw_private list for
 * a ModifyTable node referencing a postgres_fdw foreign table.  We store:
 *
 * 1) INSERT/UPDATE/DELETE statement text to be sent to the remote server
 * 2) Integer list of target attribute numbers for INSERT/UPDATE
 *        (NIL for a DELETE)
 * 3) Boolean flag showing if the remote query has a RETURNING clause
 * 4) Integer list of attribute numbers retrieved by RETURNING, if any
 */
enum FdwModifyPrivateIndex
{
	/* SQL statement to execute remotely (as a String node) */
	FdwModifyPrivateUpdateSql,
	/* Integer list of target attribute numbers for INSERT/UPDATE */
	FdwModifyPrivateTargetAttnums,
	/* has-returning flag (as an integer Value node) */
	FdwModifyPrivateHasReturning,
	/* Integer list of attribute numbers retrieved by RETURNING */
	FdwModifyPrivateRetrievedAttrs
};

/*
 * Similarly, this enum describes what's kept in the fdw_private list for
 * a ForeignScan node that modifies a foreign table directly.  We store:
 *
 * 1) UPDATE/DELETE statement text to be sent to the remote server
 * 2) Boolean flag showing if the remote query has a RETURNING clause
 * 3) Integer list of attribute numbers retrieved by RETURNING, if any
 * 4) Boolean flag showing if we set the command es_processed
 */
enum FdwDirectModifyPrivateIndex
{
	/* SQL statement to execute remotely (as a String node) */
	FdwDirectModifyPrivateUpdateSql,
	/* has-returning flag (as an integer Value node) */
	FdwDirectModifyPrivateHasReturning,
	/* Integer list of attribute numbers retrieved by RETURNING */
	FdwDirectModifyPrivateRetrievedAttrs,
	/* set-processed flag (as an integer Value node) */
	FdwDirectModifyPrivateSetProcessed
};

extern PGDLLEXPORT void _PG_init(void);
extern Datum mysql_fdw_handler(PG_FUNCTION_ARGS);

PG_FUNCTION_INFO_V1(mysql_fdw_handler);
PG_FUNCTION_INFO_V1(mysql_fdw_version);

/*
 * FDW callback routines
 */
static void mysqlExplainForeignScan(ForeignScanState *node, ExplainState *es);
static void mysqlBeginForeignScan(ForeignScanState *node, int eflags);
static TupleTableSlot *mysqlIterateForeignScan(ForeignScanState *node);
static void mysqlReScanForeignScan(ForeignScanState *node);
static void mysqlEndForeignScan(ForeignScanState *node);

static List *mysqlPlanForeignModify(PlannerInfo *root, ModifyTable *plan,
									Index resultRelation, int subplan_index);
static void mysqlBeginForeignModify(ModifyTableState *mtstate,
									ResultRelInfo *resultRelInfo,
									List *fdw_private, int subplan_index,
									int eflags);
static TupleTableSlot *mysqlExecForeignInsert(EState *estate,
											  ResultRelInfo *resultRelInfo,
											  TupleTableSlot *slot,
											  TupleTableSlot *planSlot);
static void mysqlAddForeignUpdateTargets(Query *parsetree,
										 RangeTblEntry *target_rte,
										 Relation target_relation);
static TupleTableSlot *mysqlExecForeignUpdate(EState *estate,
											  ResultRelInfo *resultRelInfo,
											  TupleTableSlot *slot,
											  TupleTableSlot *planSlot);
static TupleTableSlot *mysqlExecForeignDelete(EState *estate,
											  ResultRelInfo *resultRelInfo,
											  TupleTableSlot *slot,
											  TupleTableSlot *planSlot);
static void mysqlEndForeignModify(EState *estate,
								  ResultRelInfo *resultRelInfo);

static bool mysqlPlanDirectModify(PlannerInfo *root,
									  ModifyTable *plan,
									  Index resultRelation,
									  int subplan_index);
static void mysqlBeginDirectModify(ForeignScanState *node, int eflags);
static TupleTableSlot *mysqlIterateDirectModify(ForeignScanState *node);
static void mysqlEndDirectModify(ForeignScanState *node);
static void mysqlExplainDirectModify(ForeignScanState *node,
										 struct ExplainState *es);


static void mysqlGetForeignRelSize(PlannerInfo *root, RelOptInfo *baserel,
								   Oid foreigntableid);
static void mysqlGetForeignPaths(PlannerInfo *root, RelOptInfo *baserel,
								 Oid foreigntableid);
static bool mysqlAnalyzeForeignTable(Relation relation,
									 AcquireSampleRowsFunc *func,
									 BlockNumber *totalpages);
#if PG_VERSION_NUM >= 90500
static ForeignScan *mysqlGetForeignPlan(PlannerInfo *root,
										RelOptInfo *foreignrel,
										Oid foreigntableid,
										ForeignPath *best_path, List *tlist,
										List *scan_clauses, Plan *outer_plan);
#else
static ForeignScan *mysqlGetForeignPlan(PlannerInfo *root,
										RelOptInfo *foreignrel,
										Oid foreigntableid,
										ForeignPath *best_path, List *tlist,
										List *scan_clauses);
#endif
static void mysqlEstimateCosts(PlannerInfo *root, RelOptInfo *baserel,
							   Cost *startup_cost, Cost *total_cost,
							   Oid foreigntableid);

#if PG_VERSION_NUM >= 90500
static List *mysqlImportForeignSchema(ImportForeignSchemaStmt *stmt,
									  Oid serverOid);
#endif

static void mysqlGetForeignJoinPaths(PlannerInfo *root,
										RelOptInfo *joinrel,
										RelOptInfo *outerrel,
										RelOptInfo *innerrel,
										JoinType jointype,
										JoinPathExtraData *extra);

#if PG_VERSION_NUM >= 110000
static void mysqlBeginForeignInsert(ModifyTableState *mtstate,
									ResultRelInfo *resultRelInfo);
static void mysqlEndForeignInsert(EState *estate,
								  ResultRelInfo *resultRelInfo);
#endif

static void mysqlGetForeignUpperPaths(PlannerInfo *root,
										 UpperRelationKind stage,
										 RelOptInfo *input_rel,
										 RelOptInfo *output_rel,
										 void *extra);

/*
 * Helper functions
 */
bool mysql_load_library(void);
static void mysql_fdw_exit(int code, Datum arg);
static bool mysql_is_column_unique(Oid foreigntableid);
static void estimate_path_cost_size(PlannerInfo *root,
									RelOptInfo *foreignrel,
									List *param_join_conds,
									List *pathkeys,
									MySQLFdwPathExtraData *fpextra,
									double *p_rows, int *p_width,
									Cost *p_startup_cost, Cost *p_total_cost);
static void get_remote_estimate(const char *sql,
								MYSQL *conn,
								double *rows,
								int *width,
								Cost *startup_cost,
								Cost *total_cost);
static void adjust_foreign_grouping_path_cost(PlannerInfo *root,
											  List *pathkeys,
											  double retrieved_rows,
											  double width,
											  double limit_tuples,
											  Cost *p_startup_cost,
											  Cost *p_run_cost);
static List *get_useful_pathkeys_for_relation(PlannerInfo *root,
											  RelOptInfo *rel);
static List *get_useful_ecs_for_relation(PlannerInfo *root, RelOptInfo *rel);
static void prepare_query_params(PlanState *node,
								 List *fdw_exprs,
								 int numParams,
								 FmgrInfo **param_flinfo,
								 List **param_exprs,
								 const char ***param_values,
								 Oid **param_types);

static void process_query_params(ExprContext *econtext,
								 FmgrInfo *param_flinfo,
								 List *param_exprs,
								 const char **param_values,
								 MYSQL_BIND **mysql_bind_buf,
								 Oid *param_types);

static void bind_stmt_params_and_exec(ForeignScanState *node);
static void execute_dml_stmt(ForeignScanState *node);

void *mysql_dll_handle = NULL;
static int wait_timeout = WAIT_TIMEOUT;
static int interactive_timeout = INTERACTIVE_TIMEOUT;
static void mysql_error_print(MYSQL *conn);
static void mysql_stmt_error_print(MYSQL *conn, MYSQL_STMT *stmt, const char *msg);
static List *getUpdateTargetAttrs(RangeTblEntry *rte);

static bool foreign_join_ok(PlannerInfo *root, RelOptInfo *joinrel,
							JoinType jointype, RelOptInfo *outerrel, RelOptInfo *innerrel,
							JoinPathExtraData *extra);
static void add_paths_with_pathkeys_for_rel(PlannerInfo *root, RelOptInfo *rel,
											Path *epq_path);
static void add_foreign_grouping_paths(PlannerInfo *root,
									   RelOptInfo *input_rel,
									   RelOptInfo *grouped_rel,
									   GroupPathExtraData *extra);
static void add_foreign_ordered_paths(PlannerInfo *root,
									  RelOptInfo *input_rel,
									  RelOptInfo *ordered_rel);
static void add_foreign_final_paths(PlannerInfo *root,
									RelOptInfo *input_rel,
									RelOptInfo *final_rel,
									FinalPathExtraData *extra);
static void apply_server_options(MySQLFdwRelationInfo *fpinfo);
static void apply_table_options(MySQLFdwRelationInfo *fpinfo);
static void merge_fdw_options(MySQLFdwRelationInfo *fpinfo,
							  const MySQLFdwRelationInfo *fpinfo_o,
							  const MySQLFdwRelationInfo *fpinfo_i);
static bool ec_member_matches_foreign(PlannerInfo *root, RelOptInfo *rel,
									  EquivalenceClass *ec, EquivalenceMember *em,
									  void *arg);

/*
 * mysql_load_library function dynamically load the mysql's library
 * libmysqlclient.so. The only reason to load the library using dlopen
 * is that, mysql and postgres both have function with same name like
 * "list_delete", "list_delete" and "list_free" which cause compiler
 * error "duplicate function name" and erroneously linking with a function.
 * This port of the code is used to avoid the compiler error.
 *
 * #define list_delete mysql_list_delete
 * #include <mysql.h>
 * #undef list_delete
 *
 * But system crashed on function mysql_stmt_close function because
 * mysql_stmt_close internally calling "list_delete" function which
 * wrongly binds to postgres' "list_delete" function.
 *
 * The dlopen function provides a parameter "RTLD_DEEPBIND" which
 * solved the binding issue.
 *
 * RTLD_DEEPBIND:
 * Place the lookup scope of the symbols in this library ahead of the
 * global scope. This means that a self-contained library will use its
 * own symbols in preference to global symbols with the same name contained
 * in libraries that have already been loaded.
 */
bool
mysql_load_library(void)
{
#if defined(__APPLE__) || defined(__FreeBSD__)
	/*
	 * Mac OS/BSD does not support RTLD_DEEPBIND, but it still works without
	 * the RTLD_DEEPBIND
	 */
	mysql_dll_handle = dlopen(_MYSQL_LIBNAME, RTLD_LAZY);
#else
	mysql_dll_handle = dlopen(_MYSQL_LIBNAME, RTLD_LAZY | RTLD_DEEPBIND);
#endif
	if (mysql_dll_handle == NULL)
		return false;

	_mysql_stmt_bind_param = dlsym(mysql_dll_handle, "mysql_stmt_bind_param");
	_mysql_stmt_bind_result = dlsym(mysql_dll_handle, "mysql_stmt_bind_result");
	_mysql_stmt_init = dlsym(mysql_dll_handle, "mysql_stmt_init");
	_mysql_stmt_prepare = dlsym(mysql_dll_handle, "mysql_stmt_prepare");
	_mysql_stmt_execute = dlsym(mysql_dll_handle, "mysql_stmt_execute");
	_mysql_stmt_fetch = dlsym(mysql_dll_handle, "mysql_stmt_fetch");
	_mysql_query = dlsym(mysql_dll_handle, "mysql_query");
	_mysql_stmt_result_metadata = dlsym(mysql_dll_handle, "mysql_stmt_result_metadata");
	_mysql_stmt_store_result = dlsym(mysql_dll_handle, "mysql_stmt_store_result");
	_mysql_fetch_row = dlsym(mysql_dll_handle, "mysql_fetch_row");
	_mysql_fetch_field = dlsym(mysql_dll_handle, "mysql_fetch_field");
	_mysql_fetch_fields = dlsym(mysql_dll_handle, "mysql_fetch_fields");
	_mysql_stmt_close = dlsym(mysql_dll_handle, "mysql_stmt_close");
	_mysql_stmt_reset = dlsym(mysql_dll_handle, "mysql_stmt_reset");
	_mysql_free_result = dlsym(mysql_dll_handle, "mysql_free_result");
	_mysql_error = dlsym(mysql_dll_handle, "mysql_error");
	_mysql_options = dlsym(mysql_dll_handle, "mysql_options");
	_mysql_ssl_set = dlsym(mysql_dll_handle, "mysql_ssl_set");
	_mysql_real_connect = dlsym(mysql_dll_handle, "mysql_real_connect");
	_mysql_close = dlsym(mysql_dll_handle, "mysql_close");
	_mysql_init = dlsym(mysql_dll_handle, "mysql_init");
	_mysql_stmt_attr_set = dlsym(mysql_dll_handle, "mysql_stmt_attr_set");
	_mysql_store_result = dlsym(mysql_dll_handle, "mysql_store_result");
	_mysql_stmt_errno = dlsym(mysql_dll_handle, "mysql_stmt_errno");
	_mysql_errno = dlsym(mysql_dll_handle, "mysql_errno");
	_mysql_num_fields = dlsym(mysql_dll_handle, "mysql_num_fields");
	_mysql_num_rows = dlsym(mysql_dll_handle, "mysql_num_rows");
	_mysql_get_host_info = dlsym(mysql_dll_handle, "mysql_get_host_info");
	_mysql_get_server_info = dlsym(mysql_dll_handle, "mysql_get_server_info");
	_mysql_get_proto_info = dlsym(mysql_dll_handle, "mysql_get_proto_info");
	_mysql_warning_count = dlsym(mysql_dll_handle, "mysql_warning_count");
	_mysql_stmt_affected_rows = dlsym(mysql_dll_handle, "mysql_stmt_affected_rows");

	if (_mysql_stmt_bind_param == NULL ||
		_mysql_stmt_bind_result == NULL ||
		_mysql_stmt_init == NULL ||
		_mysql_stmt_prepare == NULL ||
		_mysql_stmt_execute == NULL ||
		_mysql_stmt_fetch == NULL ||
		_mysql_query == NULL ||
		_mysql_stmt_result_metadata == NULL ||
		_mysql_stmt_store_result == NULL ||
		_mysql_fetch_row == NULL ||
		_mysql_fetch_field == NULL ||
		_mysql_fetch_fields == NULL ||
		_mysql_stmt_close == NULL ||
		_mysql_stmt_reset == NULL ||
		_mysql_free_result == NULL ||
		_mysql_error == NULL ||
		_mysql_options == NULL ||
		_mysql_ssl_set == NULL ||
		_mysql_real_connect == NULL ||
		_mysql_close == NULL ||
		_mysql_init == NULL ||
		_mysql_stmt_attr_set == NULL ||
		_mysql_store_result == NULL ||
		_mysql_stmt_errno == NULL ||
		_mysql_errno == NULL ||
		_mysql_num_fields == NULL ||
		_mysql_num_rows == NULL ||
		_mysql_get_host_info == NULL ||
		_mysql_get_server_info == NULL ||
		_mysql_get_proto_info == NULL ||
		_mysql_warning_count == NULL ||
		_mysql_stmt_affected_rows == NULL)
		return false;

	return true;
}

/*
 * Library load-time initialization, sets on_proc_exit() callback for
 * backend shutdown.
 */
void
_PG_init(void)
{
	if (!mysql_load_library())
		ereport(ERROR,
				(errcode(ERRCODE_FDW_UNABLE_TO_CREATE_EXECUTION),
				 errmsg("failed to load the mysql query: \n%s", dlerror()),
				 errhint("Export LD_LIBRARY_PATH to locate the library.")));

	DefineCustomIntVariable("mysql_fdw.wait_timeout",
							"Server-side wait_timeout",
							"Set the maximum wait_timeout"
							"use to set the MySQL session timeout",
							&wait_timeout,
							WAIT_TIMEOUT,
							0,
							INT_MAX,
							PGC_USERSET,
							0,
							NULL,
							NULL,
							NULL);

	DefineCustomIntVariable("mysql_fdw.interactive_timeout",
							"Server-side interactive timeout",
							"Set the maximum interactive timeout"
							"use to set the MySQL session timeout",
							&interactive_timeout,
							INTERACTIVE_TIMEOUT,
							0,
							INT_MAX,
							PGC_USERSET,
							0,
							NULL,
							NULL,
							NULL);

	on_proc_exit(&mysql_fdw_exit, PointerGetDatum(NULL));
}

/*
 * mysql_fdw_exit
 * 		Exit callback function.
 */
static void
mysql_fdw_exit(int code, Datum arg)
{
	mysql_cleanup_connection();
}

/*
 * Foreign-data wrapper handler function: return
 * a struct with pointers to my callback routines.
 */
Datum
mysql_fdw_handler(PG_FUNCTION_ARGS)
{
	FdwRoutine *fdwroutine = makeNode(FdwRoutine);

	/* Functions for scanning foreign tables */
	fdwroutine->GetForeignRelSize = mysqlGetForeignRelSize;
	fdwroutine->GetForeignPaths = mysqlGetForeignPaths;
	fdwroutine->GetForeignPlan = mysqlGetForeignPlan;
	fdwroutine->BeginForeignScan = mysqlBeginForeignScan;
	fdwroutine->IterateForeignScan = mysqlIterateForeignScan;
	fdwroutine->ReScanForeignScan = mysqlReScanForeignScan;
	fdwroutine->EndForeignScan = mysqlEndForeignScan;

	/* Functions for updating foreign tables */
	fdwroutine->AddForeignUpdateTargets = mysqlAddForeignUpdateTargets;
	fdwroutine->PlanForeignModify = mysqlPlanForeignModify;
	fdwroutine->BeginForeignModify = mysqlBeginForeignModify;
	fdwroutine->ExecForeignInsert = mysqlExecForeignInsert;
	fdwroutine->ExecForeignUpdate = mysqlExecForeignUpdate;
	fdwroutine->ExecForeignDelete = mysqlExecForeignDelete;
	fdwroutine->EndForeignModify = mysqlEndForeignModify;

	/* suport for Direct Modification */
	fdwroutine->PlanDirectModify = mysqlPlanDirectModify;
	fdwroutine->BeginDirectModify = mysqlBeginDirectModify;
	fdwroutine->IterateDirectModify = mysqlIterateDirectModify;
	fdwroutine->EndDirectModify = mysqlEndDirectModify;

	/* Support functions for EXPLAIN */
	fdwroutine->ExplainForeignScan = mysqlExplainForeignScan;
	fdwroutine->ExplainDirectModify = mysqlExplainDirectModify;

	/* Support functions for ANALYZE */
	fdwroutine->AnalyzeForeignTable = mysqlAnalyzeForeignTable;

	/* Support functions for IMPORT FOREIGN SCHEMA */
#if PG_VERSION_NUM >= 90500
	fdwroutine->ImportForeignSchema = mysqlImportForeignSchema;
#endif

#if PG_VERSION_NUM >= 110000
	/* Partition routing and/or COPY from */
	fdwroutine->BeginForeignInsert = mysqlBeginForeignInsert;
	fdwroutine->EndForeignInsert = mysqlEndForeignInsert;
#endif

	/* Support functions for join push-down */
	fdwroutine->GetForeignJoinPaths = mysqlGetForeignJoinPaths;

	/* Support functions for upper relation push-down */
	fdwroutine->GetForeignUpperPaths = mysqlGetForeignUpperPaths;

	PG_RETURN_POINTER(fdwroutine);
}

/*
 * mysqlBeginForeignScan
 * 		Initiate access to the database
 */
static void
mysqlBeginForeignScan(ForeignScanState *node, int eflags)
{
	TupleTableSlot *tupleSlot = node->ss.ss_ScanTupleSlot;
	TupleDesc	tupleDescriptor = tupleSlot->tts_tupleDescriptor;
	MYSQL	   *conn;
	RangeTblEntry *rte;
	MySQLFdwExecState *festate;
	EState	   *estate = node->ss.ps.state;
	ForeignScan *fsplan = (ForeignScan *) node->ss.ps.plan;
	mysql_opt  *options;
	ListCell   *lc;
	int			atindex = 0;
	unsigned long prefetch_rows = MYSQL_PREFETCH_ROWS;
	unsigned long type = (unsigned long) CURSOR_TYPE_READ_ONLY;
	Oid			userid;
	ForeignServer *server;
	UserMapping *user;
	ForeignTable *table;
	char		timeout[255];
	int			numParams;
	int               rtindex;

	/*
	 * We'll save private state in node->fdw_state.
	 */
	festate = (MySQLFdwExecState *) palloc0(sizeof(MySQLFdwExecState));
	node->fdw_state = (void *) festate;

	/*
	 * Identify which user to do the remote access as.  This should match what
	 * ExecCheckRTEPerms() does.
	 */
	if (fsplan->scan.scanrelid > 0)
		rtindex = fsplan->scan.scanrelid;
	else
		rtindex = bms_next_member(fsplan->fs_relids, -1);
	rte = exec_rt_fetch(rtindex, estate);
	userid = rte->checkAsUser ? rte->checkAsUser : GetUserId();

	/* Get info about foreign table. */
	table = GetForeignTable(rte->relid);
	server = GetForeignServer(table->serverid);
	user = GetUserMapping(userid, server->serverid);

	/* Fetch the options */
	options = mysql_get_options(rte->relid);

	/*
	 * Get the already connected connection, otherwise connect and get the
	 * connection handle.
	 */
	conn = mysql_get_connection(server, user, options);

	/* Stash away the state info we have already */
	festate->query = strVal(list_nth(fsplan->fdw_private, 0));
	festate->retrieved_attrs = list_nth(fsplan->fdw_private, 1);
	festate->conn = conn;
	festate->query_executed = false;

#if PG_VERSION_NUM >= 110000
	festate->temp_cxt = AllocSetContextCreate(estate->es_query_cxt,
											  "mysql_fdw temporary data",
											  ALLOCSET_DEFAULT_SIZES);
#else
	festate->temp_cxt = AllocSetContextCreate(estate->es_query_cxt,
											  "mysql_fdw temporary data",
											  ALLOCSET_SMALL_MINSIZE,
											  ALLOCSET_SMALL_INITSIZE,
											  ALLOCSET_SMALL_MAXSIZE);
#endif

	if (wait_timeout > 0)
	{
		/* Set the session timeout in seconds */
		sprintf(timeout, "SET wait_timeout = %d", wait_timeout);
		mysql_query(festate->conn, timeout);
	}

	if (interactive_timeout > 0)
	{
		/* Set the session timeout in seconds */
		sprintf(timeout, "SET interactive_timeout = %d", interactive_timeout);
		mysql_query(festate->conn, timeout);
	}

	/* Change sql_mode to TRADITIONAL to catch warning "Division by 0" */
	mysql_query(festate->conn, "SET sql_mode='TRADITIONAL'");

	/* Initialize the MySQL statement */
	festate->stmt = mysql_stmt_init(festate->conn);
	if (festate->stmt == NULL)
		ereport(ERROR,
				(errcode(ERRCODE_FDW_UNABLE_TO_CREATE_EXECUTION),
				 errmsg("failed to initialize the mysql query: \n%s",
						mysql_error(festate->conn))));

	/* Prepare MySQL statement */
	if (mysql_stmt_prepare(festate->stmt, festate->query,
						   strlen(festate->query)) != 0)
		mysql_stmt_error_print(festate->conn, festate->stmt, "failed to prepare the MySQL query");

	/*
	 * Do nothing in EXPLAIN (no ANALYZE) case.  node->fdw_state stays NULL.
	 */
	if (eflags & EXEC_FLAG_EXPLAIN_ONLY)
		return;

	/* Prepare for output conversion of parameters used in remote query. */
	numParams = list_length(fsplan->fdw_exprs);
	festate->numParams = numParams;
	if (numParams > 0)
		prepare_query_params((PlanState *) node,
							 fsplan->fdw_exprs,
							 numParams,
							 &festate->param_flinfo,
							 &festate->param_exprs,
							 &festate->param_values,
							 &festate->param_types);

	/* int column_count = mysql_num_fields(festate->meta); */

	/* Set the statement as cursor type */
	mysql_stmt_attr_set(festate->stmt, STMT_ATTR_CURSOR_TYPE, (void *) &type);

	/* Set the pre-fetch rows */
	mysql_stmt_attr_set(festate->stmt, STMT_ATTR_PREFETCH_ROWS,
						(void *) &prefetch_rows);

	festate->table = (mysql_table *) palloc0(sizeof(mysql_table));
	festate->table->column = (mysql_column *) palloc0(sizeof(mysql_column) * tupleDescriptor->natts);
	festate->table->mysql_bind = (MYSQL_BIND *) palloc0(sizeof(MYSQL_BIND) * tupleDescriptor->natts);

	festate->table->mysql_res = mysql_stmt_result_metadata(festate->stmt);
	if (NULL == festate->table->mysql_res)
		ereport(ERROR,
				(errcode(ERRCODE_FDW_UNABLE_TO_CREATE_EXECUTION),
				 errmsg("failed to retrieve query result set metadata: \n%s",
						mysql_error(festate->conn))));

	festate->table->mysql_fields = mysql_fetch_fields(festate->table->mysql_res);

	foreach(lc, festate->retrieved_attrs)
	{
		int			attnum = lfirst_int(lc) - 1;
		Oid			pgtype = TupleDescAttr(tupleDescriptor, attnum)->atttypid;
		int32		pgtypmod = TupleDescAttr(tupleDescriptor, attnum)->atttypmod;

		if (TupleDescAttr(tupleDescriptor, attnum)->attisdropped)
			continue;

		festate->table->column[atindex].mysql_bind = &festate->table->mysql_bind[atindex];

		mysql_bind_result(pgtype, pgtypmod,
						  &festate->table->mysql_fields[atindex],
						  &festate->table->column[atindex]);
		atindex++;
	}

	/* Bind the results pointers for the prepare statements */
	if (mysql_stmt_bind_result(festate->stmt, festate->table->mysql_bind) != 0)
		mysql_stmt_error_print(festate->conn, festate->stmt, "failed to bind the MySQL query");
}

/*
 * mysqlIterateForeignScan
 * 		Iterate and get the rows one by one from  MySQL and placed in tuple
 * 		slot
 */
static TupleTableSlot *
mysqlIterateForeignScan(ForeignScanState *node)
{
	MySQLFdwExecState *festate = (MySQLFdwExecState *) node->fdw_state;
	TupleTableSlot *tupleSlot = node->ss.ss_ScanTupleSlot;
	TupleDesc		tupleDescriptor = tupleSlot->tts_tupleDescriptor;
	int				attid;
	ListCell	   *lc;
	int				rc = 0;
	MYSQL_FIELD	   *fields;

	memset(tupleSlot->tts_values, 0, sizeof(Datum) * tupleDescriptor->natts);
	memset(tupleSlot->tts_isnull, true, sizeof(bool) * tupleDescriptor->natts);

	ExecClearTuple(tupleSlot);

	/*
	 * If this is the first call after Begin or ReScan, we need to bind the
	 * params and execute the query.
	 */
	if (!festate->query_executed)
		bind_stmt_params_and_exec(node);

	attid = 0;
	rc = mysql_stmt_fetch(festate->stmt);
	
	if (rc == 0)
	{
		festate->metadata = mysql_stmt_result_metadata(festate->stmt);
		fields = mysql_fetch_fields(festate->metadata);
		
		foreach(lc, festate->retrieved_attrs)
		{
			int			attnum = lfirst_int(lc) - 1;
			Oid			pgtype = TupleDescAttr(tupleDescriptor, attnum)->atttypid;
			int32		pgtypmod = TupleDescAttr(tupleDescriptor, attnum)->atttypmod;

			tupleSlot->tts_isnull[attnum] = festate->table->column[attid].is_null;
			if (!festate->table->column[attid].is_null)
				tupleSlot->tts_values[attnum] = mysql_convert_to_pg(pgtype,
																	pgtypmod,
																	&festate->table->column[attid],
																	fields[attid]);

			attid++;
		}

		ExecStoreVirtualTuple(tupleSlot);
	}
	else if (rc == 1)
	{
		/*
		 * Error occurred. Error code and message can be obtained by calling
		 * mysql_stmt_errno() and mysql_stmt_error().
		 */
	}
	else if (rc == MYSQL_NO_DATA)
	{
		/*
		 * No more rows/data exists
		 */
	}
	else if (rc == MYSQL_DATA_TRUNCATED)
	{
		/* Data truncation occurred */
		/*
		 * MYSQL_DATA_TRUNCATED is returned when truncation reporting is
		 * enabled. To determine which column values were truncated when this
		 * value is returned, check the error members of the MYSQL_BIND
		 * structures used for fetching values. Truncation reporting is
		 * enabled by default, but can be controlled by calling
		 * mysql_options() with the MYSQL_REPORT_DATA_TRUNCATION option.
		 */
	}

	return tupleSlot;
}


/*
 * mysqlExplainForeignScan
 * 		Produce extra output for EXPLAIN
 */
static void
mysqlExplainForeignScan(ForeignScanState *node, ExplainState *es)
{
	MySQLFdwExecState *festate = (MySQLFdwExecState *) node->fdw_state;
	mysql_opt  *options;
	ForeignScan *fsplan = (ForeignScan *) node->ss.ps.plan;
	int rtindex;
	RangeTblEntry *rte;
	EState *estate = node->ss.ps.state;

	if (fsplan->scan.scanrelid > 0)
		rtindex = fsplan->scan.scanrelid;
	else
		rtindex = bms_next_member(fsplan->fs_relids, -1);
	rte = exec_rt_fetch(rtindex, estate);

	/* Fetch options */
	options = mysql_get_options(rte->relid);

	/* Give some possibly useful info about startup costs */
	if (es->verbose)
	{
		if (strcmp(options->svr_address, "127.0.0.1") == 0 ||
			strcmp(options->svr_address, "localhost") == 0)
#if PG_VERSION_NUM >= 110000
			ExplainPropertyInteger("Local server startup cost", NULL, 10, es);
#else
			ExplainPropertyLong("Local server startup cost", 10, es);
#endif
		else
#if PG_VERSION_NUM >= 110000
			ExplainPropertyInteger("Remote server startup cost", NULL, 25, es);
#else
			ExplainPropertyLong("Remote server startup cost", 25, es);
#endif
		ExplainPropertyText("Remote query", festate->query, es);
	}
}

/*
 * mysqlEndForeignScan
 * 		Finish scanning foreign table and dispose objects used for this scan
 */
static void
mysqlEndForeignScan(ForeignScanState *node)
{
	MySQLFdwExecState *festate = (MySQLFdwExecState *) node->fdw_state;

	if (festate->table && festate->table->mysql_res)
	{
		mysql_free_result(festate->table->mysql_res);
		festate->table->mysql_res = NULL;
	}

	if (festate->stmt)
	{
		mysql_stmt_close(festate->stmt);
		festate->stmt = NULL;
	}
}

/*
 * mysqlReScanForeignScan
 * 		Rescan table, possibly with new parameters
 */
static void
mysqlReScanForeignScan(ForeignScanState *node)
{
	MySQLFdwExecState *festate = (MySQLFdwExecState *) node->fdw_state;

	/*
	 * Set the query_executed flag to false so that the query will be executed
	 * in mysqlIterateForeignScan().
	 */
	festate->query_executed = false;

}

/*
 * mysqlGetForeignRelSize
 * 		Create a FdwPlan for a scan on the foreign table
 */
static void
mysqlGetForeignRelSize(PlannerInfo *root, RelOptInfo *baserel,
					   Oid foreigntableid)
{
	MYSQL	   *conn;
	Bitmapset  *attrs_used = NULL;
	mysql_opt  *options;
	Oid			userid = GetUserId();
	ForeignServer *server;
	UserMapping *user;
	ForeignTable *table;
	MySQLFdwRelationInfo *fpinfo;
	ListCell   *lc;
	RangeTblEntry *rte = planner_rt_fetch(baserel->relid, root);

	fpinfo = (MySQLFdwRelationInfo *) palloc0(sizeof(MySQLFdwRelationInfo));
	baserel->fdw_private = (void *) fpinfo;

	table = GetForeignTable(foreigntableid);
	server = GetForeignServer(table->serverid);
	user = GetUserMapping(userid, server->serverid);

	/* Fetch options */
	options = mysql_get_options(foreigntableid);

	/* Connect to the server */
	conn = mysql_get_connection(server, user, options);

	mysql_query(conn, "SET sql_mode='ANSI_QUOTES'");

	/* Base foreign tables need to be pushed down always. */
	fpinfo->pushdown_safe = true;
	/* Look up foreign-table catalog info. */
	fpinfo->table = GetForeignTable(foreigntableid);
	fpinfo->server = GetForeignServer(fpinfo->table->serverid);

	/*
	 * Extract user-settable option values.  Note that per-table setting of
	 * use_remote_estimate overrides per-server setting.
	 */
	fpinfo->use_remote_estimate = false;
	fpinfo->fdw_startup_cost = DEFAULT_FDW_STARTUP_COST;
	fpinfo->fdw_tuple_cost = DEFAULT_FDW_TUPLE_COST;
	fpinfo->shippable_extensions = NIL;
	fpinfo->fetch_size = 100;

	apply_server_options(fpinfo);
	apply_table_options(fpinfo);

	/*
	 * If the table or the server is configured to use remote estimates,
	 * identify which user to do remote access as during planning.  This
	 * should match what ExecCheckRTEPerms() does.  If we fail due to lack of
	 * permissions, the query would have failed at runtime anyway.
	 */
	if (fpinfo->use_remote_estimate)
	{
		Oid			userid = rte->checkAsUser ? rte->checkAsUser : GetUserId();

		fpinfo->user = GetUserMapping(userid, fpinfo->server->serverid);
	}
	else
		fpinfo->user = NULL;

	/*
	 * Identify which attributes will need to be retrieved from the remote
	 * server.  These include all attrs needed for joins or final output, plus
	 * all attrs used in the local_conds.  (Note: if we end up using a
	 * parameterized scan, it's possible that some of the join clauses will be
	 * sent to the remote and thus we wouldn't really need to retrieve the
	 * columns used in them.  Doesn't seem worth detecting that case though.)
	 */
	fpinfo->attrs_used = NULL;
#if PG_VERSION_NUM >= 90600
	pull_varattnos((Node *) baserel->reltarget->exprs, baserel->relid,
				   &attrs_used);
#else
	pull_varattnos((Node *) baserel->reltargetlist, baserel->relid,
				   &attrs_used);
#endif
	foreach(lc, fpinfo->local_conds)
	{
		RestrictInfo *rinfo = lfirst_node(RestrictInfo, lc);

		pull_varattnos((Node *) rinfo->clause, baserel->relid,
					   &fpinfo->attrs_used);
	}

	/*
	 * Compute the selectivity and cost of the local_conds, so we don't have
	 * to do it over again for each path.  The best we can do for these
	 * conditions is to estimate selectivity on the basis of local statistics.
	 */
	fpinfo->local_conds_sel = clauselist_selectivity(root,
													 fpinfo->local_conds,
													 baserel->relid,
													 JOIN_INNER,
													 NULL);

	cost_qual_eval(&fpinfo->local_conds_cost, fpinfo->local_conds, root);

	/*
	 * Set # of retrieved rows and cached relation costs to some negative
	 * value, so that we can detect when they are set to some sensible values,
	 * during one (usually the first) of the calls to estimate_path_cost_size.
	 */
	fpinfo->retrieved_rows = -1;
	fpinfo->rel_startup_cost = -1;
	fpinfo->rel_total_cost = -1;

	foreach(lc, baserel->baserestrictinfo)
	{
		RestrictInfo *ri = (RestrictInfo *) lfirst(lc);

		if (mysql_is_foreign_expr(root, baserel, ri->clause))
			fpinfo->remote_conds = lappend(fpinfo->remote_conds, ri);
		else
			fpinfo->local_conds = lappend(fpinfo->local_conds, ri);
	}

#if PG_VERSION_NUM >= 90600
	pull_varattnos((Node *) baserel->reltarget->exprs, baserel->relid,
				   &fpinfo->attrs_used);
#else
	pull_varattnos((Node *) baserel->reltargetlist, baserel->relid,
				   &fpinfo->attrs_used);
#endif

	foreach(lc, fpinfo->local_conds)
	{
		RestrictInfo *rinfo = (RestrictInfo *) lfirst(lc);

		pull_varattnos((Node *) rinfo->clause, baserel->relid,
					   &fpinfo->attrs_used);
	}

	/*
	 * If the table or the server is configured to use remote estimates,
	 * connect to the foreign server and execute EXPLAIN to estimate the
	 * number of rows selected by the restriction clauses, as well as the
	 * average row width.  Otherwise, estimate using whatever statistics we
	 * have locally, in a way similar to ordinary tables.
	 */
	if (fpinfo->use_remote_estimate)
	{
		/*
		 * Get cost/size estimates with help of remote server.  Save the
		 * values in fpinfo so we don't need to do it again to generate the
		 * basic foreign path.
		 */
		estimate_path_cost_size(root, baserel, NIL, NIL, NULL,
								&fpinfo->rows, &fpinfo->width,
								&fpinfo->startup_cost, &fpinfo->total_cost);

		/* Report estimated baserel size to planner. */
		baserel->rows = fpinfo->rows;
		baserel->reltarget->width = fpinfo->width;
	}
	else
	{
		/*
		 * If the foreign table has never been ANALYZEd, it will have relpages
		 * and reltuples equal to zero, which most likely has nothing to do
		 * with reality.  We can't do a whole lot about that if we're not
		 * allowed to consult the remote server, but we can use a hack similar
		 * to plancat.c's treatment of empty relations: use a minimum size
		 * estimate of 10 pages, and divide by the column-datatype-based width
		 * estimate to get the corresponding number of tuples.
		 */
		if (baserel->pages == 0 && baserel->tuples == 0)
		{
			baserel->pages = 10;
			baserel->tuples =
				(10 * BLCKSZ) / (baserel->reltarget->width +
								 MAXALIGN(SizeofHeapTupleHeader));
		}

		/* Estimate baserel size as best we can with local statistics. */
		set_baserel_size_estimates(root, baserel);

		/* Fill in basically-bogus cost estimates for use later. */
		estimate_path_cost_size(root, baserel, NIL, NIL, NULL,
								&fpinfo->rows, &fpinfo->width,
								&fpinfo->startup_cost, &fpinfo->total_cost);
		baserel->rows = fpinfo->rows;
	}

	/*
	 * fpinfo->relation_name gets the numeric rangetable index of the foreign
	 * table RTE.  (If this query gets EXPLAIN'd, we'll convert that to a
	 * human-readable string at that time.)
	 */
	fpinfo->relation_name = psprintf("%u", baserel->relid);

	/* No outer and inner relations. */
	fpinfo->make_outerrel_subquery = false;
	fpinfo->make_innerrel_subquery = false;
	fpinfo->lower_subquery_rels = NULL;
	/* Set the relation index. */
	fpinfo->relation_index = baserel->relid;
}

static bool
mysql_is_column_unique(Oid foreigntableid)
{
	StringInfoData sql;
	MYSQL	   *conn;
	MYSQL_RES  *result;
	mysql_opt  *options;
	Oid			userid = GetUserId();
	ForeignServer *server;
	UserMapping *user;
	ForeignTable *table;

	table = GetForeignTable(foreigntableid);
	server = GetForeignServer(table->serverid);
	user = GetUserMapping(userid, server->serverid);

	/* Fetch the options */
	options = mysql_get_options(foreigntableid);

	/* Connect to the server */
	conn = mysql_get_connection(server, user, options);

	/* Build the query */
	initStringInfo(&sql);

	/*
	 * Construct the query by prefixing the database name so that it can lookup
	 * in correct database.
	 */
	appendStringInfo(&sql, "EXPLAIN %s.%s",
					 mysql_quote_identifier(options->svr_database, '`'),
					 mysql_quote_identifier(options->svr_table, '`'));
	if (mysql_query(conn, sql.data) != 0)
		mysql_error_print(conn);

	result = mysql_store_result(conn);
	if (result)
	{
		int			num_fields = mysql_num_fields(result);
		MYSQL_ROW	row;

		while ((row = mysql_fetch_row(result)))
		{
			if (num_fields > 3)
			{
				if ((strcmp(row[3], "PRI") == 0) || (strcmp(row[3], "UNI")) == 0)
				{
					mysql_free_result(result);
					return true;
				}
			}
		}
		mysql_free_result(result);
	}

	return false;
}

/*
 * mysqlEstimateCosts
 * 		Estimate the remote query cost
 */
static void
mysqlEstimateCosts(PlannerInfo *root, RelOptInfo *baserel, Cost *startup_cost,
				   Cost *total_cost, Oid foreigntableid)
{
	mysql_opt  *options;

	/* Fetch options */
	options = mysql_get_options(foreigntableid);

	/* Local databases are probably faster */
	if (strcmp(options->svr_address, "127.0.0.1") == 0 ||
		strcmp(options->svr_address, "localhost") == 0)
		*startup_cost = 10;
	else
		*startup_cost = 25;

	*total_cost = baserel->rows + *startup_cost;
}

/*
 * mysqlGetForeignPaths
 * 		Get the foreign paths
 */
static void
mysqlGetForeignPaths(PlannerInfo *root, RelOptInfo *baserel,
					 Oid foreigntableid)
{
	MySQLFdwRelationInfo *fpinfo = (MySQLFdwRelationInfo *) baserel->fdw_private;
	Cost		startup_cost;
	Cost		total_cost;
	ForeignPath *path;
	List	   *ppi_list;
	ListCell   *lc;

	/* Estimate costs */
	mysqlEstimateCosts(root, baserel, &startup_cost, &total_cost,
					   foreigntableid);

	/* Create a ForeignPath node and add it as only possible path */
	add_path(baserel, (Path *)
			 create_foreignscan_path(root, baserel,
#if PG_VERSION_NUM >= 90600
									 NULL,	/* default pathtarget */
#endif
									fpinfo->rows,
									fpinfo->startup_cost,
									fpinfo->total_cost,
									 NIL,	/* no pathkeys */
									 baserel->lateral_relids,
#if PG_VERSION_NUM >= 90500
									 NULL,	/* no extra plan */
#endif
									 NULL));	/* no fdw_private data */

	/* Add paths with pathkeys */
	add_paths_with_pathkeys_for_rel(root, baserel, NULL);

	/*
	 * If we're not using remote estimates, stop here.  We have no way to
	 * estimate whether any join clauses would be worth sending across, so
	 * don't bother building parameterized paths.
	 */
	if (!fpinfo->use_remote_estimate)
		return;

	/*
	 * Thumb through all join clauses for the rel to identify which outer
	 * relations could supply one or more safe-to-send-to-remote join clauses.
	 * We'll build a parameterized path for each such outer relation.
	 *
	 * It's convenient to manage this by representing each candidate outer
	 * relation by the ParamPathInfo node for it.  We can then use the
	 * ppi_clauses list in the ParamPathInfo node directly as a list of the
	 * interesting join clauses for that rel.  This takes care of the
	 * possibility that there are multiple safe join clauses for such a rel,
	 * and also ensures that we account for unsafe join clauses that we'll
	 * still have to enforce locally (since the parameterized-path machinery
	 * insists that we handle all movable clauses).
	 */
	ppi_list = NIL;
	foreach(lc, baserel->joininfo)
	{
		RestrictInfo *rinfo = (RestrictInfo *) lfirst(lc);
		Relids		required_outer;
		ParamPathInfo *param_info;

		/* Check if clause can be moved to this rel */
		if (!join_clause_is_movable_to(rinfo, baserel))
			continue;

		/* See if it is safe to send to remote */
		if (!mysql_is_foreign_expr(root, baserel, rinfo->clause))
			continue;

		/* Calculate required outer rels for the resulting path */
		required_outer = bms_union(rinfo->clause_relids,
								   baserel->lateral_relids);
		/* We do not want the foreign rel itself listed in required_outer */
		required_outer = bms_del_member(required_outer, baserel->relid);

		/*
		 * required_outer probably can't be empty here, but if it were, we
		 * couldn't make a parameterized path.
		 */
		if (bms_is_empty(required_outer))
			continue;

		/* Get the ParamPathInfo */
		param_info = get_baserel_parampathinfo(root, baserel,
											   required_outer);
		Assert(param_info != NULL);

		/*
		 * Add it to list unless we already have it.  Testing pointer equality
		 * is OK since get_baserel_parampathinfo won't make duplicates.
		 */
		ppi_list = list_append_unique_ptr(ppi_list, param_info);
	}

	/*
	 * The above scan examined only "generic" join clauses, not those that
	 * were absorbed into EquivalenceClauses.  See if we can make anything out
	 * of EquivalenceClauses.
	 */
	if (baserel->has_eclass_joins)
	{
		/*
		 * We repeatedly scan the eclass list looking for column references
		 * (or expressions) belonging to the foreign rel.  Each time we find
		 * one, we generate a list of equivalence joinclauses for it, and then
		 * see if any are safe to send to the remote.  Repeat till there are
		 * no more candidate EC members.
		 */
		ec_member_foreign_arg arg;

		arg.already_used = NIL;
		for (;;)
		{
			List	   *clauses;

			/* Make clauses, skipping any that join to lateral_referencers */
			arg.current = NULL;
			clauses = generate_implied_equalities_for_column(root,
															 baserel,
															 ec_member_matches_foreign,
															 (void *) &arg,
															 baserel->lateral_referencers);

			/* Done if there are no more expressions in the foreign rel */
			if (arg.current == NULL)
			{
				Assert(clauses == NIL);
				break;
			}

			/* Scan the extracted join clauses */
			foreach(lc, clauses)
			{
				RestrictInfo *rinfo = (RestrictInfo *) lfirst(lc);
				Relids		required_outer;
				ParamPathInfo *param_info;

				/* Check if clause can be moved to this rel */
				if (!join_clause_is_movable_to(rinfo, baserel))
					continue;

				/* See if it is safe to send to remote */
				if (!mysql_is_foreign_expr(root, baserel, rinfo->clause))
					continue;

				/* Calculate required outer rels for the resulting path */
				required_outer = bms_union(rinfo->clause_relids,
										   baserel->lateral_relids);
				required_outer = bms_del_member(required_outer, baserel->relid);
				if (bms_is_empty(required_outer))
					continue;

				/* Get the ParamPathInfo */
				param_info = get_baserel_parampathinfo(root, baserel,
													   required_outer);
				Assert(param_info != NULL);

				/* Add it to list unless we already have it */
				ppi_list = list_append_unique_ptr(ppi_list, param_info);
			}

			/* Try again, now ignoring the expression we found this time */
			arg.already_used = lappend(arg.already_used, arg.current);
		}
	}

	/*
	 * Now build a path for each useful outer relation.
	 */
	foreach(lc, ppi_list)
	{
		ParamPathInfo *param_info = (ParamPathInfo *) lfirst(lc);
		double		rows;
		int			width;
		Cost		startup_cost;
		Cost		total_cost;

		/* Get a cost estimate from the remote */
		estimate_path_cost_size(root, baserel,
								param_info->ppi_clauses, NIL, NULL,
								&rows, &width,
								&startup_cost, &total_cost);

		/*
		 * ppi_rows currently won't get looked at by anything, but still we
		 * may as well ensure that it matches our idea of the rowcount.
		 */
		param_info->ppi_rows = rows;

		/* Make the path */
		path = create_foreignscan_path(root, baserel,
#if PG_VERSION_NUM >= 90600
									   NULL,	/* default pathtarget */
#endif
									   rows,
									   startup_cost,
									   total_cost,
									   NIL, /* no pathkeys */
									   param_info->ppi_req_outer,
#if PG_VERSION_NUM >= 90500
									   NULL,
#endif
									   NIL);	/* no fdw_private list */
		add_path(baserel, (Path *) path);
	}
}


/*
 * mysqlGetForeignPlan
 * 		Get a foreign scan plan node
 */
#if PG_VERSION_NUM >= 90500
static ForeignScan *
mysqlGetForeignPlan(PlannerInfo *root, RelOptInfo *foreignrel,
					Oid foreigntableid, ForeignPath *best_path,
					List *tlist, List *scan_clauses, Plan *outer_plan)
#else
static ForeignScan *
mysqlGetForeignPlan(PlannerInfo *root, RelOptInfo *foreignrel,
					Oid foreigntableid, ForeignPath *best_path,
					List *tlist, List *scan_clauses)
#endif
{
	MySQLFdwRelationInfo *fpinfo = (MySQLFdwRelationInfo *) foreignrel->fdw_private;
	Index		scan_relid = foreignrel->relid;
	List	   *fdw_private;
	List	   *local_exprs = NIL;
	List	   *remote_exprs = NIL;
	List	   *params_list = NIL;
	List       *fdw_scan_tlist = NIL;
	List	   *remote_conds = NIL;
	StringInfoData sql;
	List	   *retrieved_attrs;
	ListCell   *lc;
	bool		has_final_sort = false;
	bool		has_limit = false;

	/* Decide to execute function pushdown support in the target list. */
	fpinfo->is_tlist_func_pushdown = mysql_is_foreign_function_tlist(root, foreignrel, tlist);

	/*
	 * Get FDW private data created by mysqlGetForeignUpperPaths(), if any.
	 */
	if (best_path->fdw_private)
	{
		has_final_sort = intVal(list_nth(best_path->fdw_private,
										 FdwPathPrivateHasFinalSort));
		has_limit = intVal(list_nth(best_path->fdw_private,
									FdwPathPrivateHasLimit));
	}

	/*
	 * Build the query string to be sent for execution, and identify
	 * expressions to be sent as parameters.
	 */

	if (IS_SIMPLE_REL(foreignrel))
	{
		/*
		 * Separate the scan_clauses into those that can be executed remotely and
		 * those that can't.  baserestrictinfo clauses that were previously
		 * determined to be safe or unsafe by mysql_classify_conditions are shown in
		 * fpinfo->remote_conds and fpinfo->local_conds.  Anything else in the
		 * scan_clauses list will be a join clause, which we have to check for
		 * remote-safety.
		 *
		 * Note: the join clauses we see here should be the exact same ones
		 * previously examined by mysqlGetForeignPaths.  Possibly it'd be worth
		 * passing forward the classification work done then, rather than
		 * repeating it here.
		 *
		 * This code must match "extract_actual_clauses(scan_clauses, false)"
		 * except for the additional decision about remote versus local execution.
		 * Note however that we only strip the RestrictInfo nodes from the
		 * local_exprs list, since appendWhereClause expects a list of
		 * RestrictInfos.
		 */
		foreach(lc, scan_clauses)
		{
			RestrictInfo *rinfo = (RestrictInfo *) lfirst(lc);

			Assert(IsA(rinfo, RestrictInfo));

			/* Ignore any pseudoconstants, they're dealt with elsewhere */
			if (rinfo->pseudoconstant)
				continue;

			if (list_member_ptr(fpinfo->remote_conds, rinfo))
			{
				remote_conds = lappend(remote_conds, rinfo);
				remote_exprs = lappend(remote_exprs, rinfo->clause);
			}
			else if (list_member_ptr(fpinfo->local_conds, rinfo))
				local_exprs = lappend(local_exprs, rinfo->clause);
			else if (mysql_is_foreign_expr(root, foreignrel, rinfo->clause))
			{
				remote_conds = lappend(remote_conds, rinfo);
				remote_exprs = lappend(remote_exprs, rinfo->clause);
			}
			else
				local_exprs = lappend(local_exprs, rinfo->clause);
		}

		if (fpinfo->is_tlist_func_pushdown == true)
		{
			
			fdw_scan_tlist = copyObject(tlist);
			foreach(lc, fpinfo->local_conds)
			{
				RestrictInfo *rinfo = lfirst_node(RestrictInfo, lc);

				fdw_scan_tlist = add_to_flat_tlist(fdw_scan_tlist,
												pull_var_clause((Node *) rinfo->clause,
																PVC_RECURSE_PLACEHOLDERS));
			}
		}
	}
	else
	{
		/*
		 * Join relation or upper relation - set scan_relid to 0.
		 */
		scan_relid = 0;

		/*
		 * For a join rel, baserestrictinfo is NIL and we are not considering
		 * parameterization right now, so there should be no scan_clauses for
		 * a joinrel or an upper rel either.
		 */
		Assert(!scan_clauses);

		/*
		 * Instead we get the conditions to apply from the fdw_private
		 * structure.
		 */
		remote_exprs = extract_actual_clauses(fpinfo->remote_conds, false);
		local_exprs = extract_actual_clauses(fpinfo->local_conds, false);

		/*
		 * We leave fdw_recheck_quals empty in this case, since we never need
		 * to apply EPQ recheck clauses.  In the case of a joinrel, EPQ
		 * recheck is handled elsewhere --- see mysqlGetForeignJoinPaths().
		 * If we're planning an upperrel (ie, remote grouping or aggregation)
		 * then there's no EPQ to do because SELECT FOR UPDATE wouldn't be
		 * allowed, and indeed we *can't* put the remote clauses into
		 * fdw_recheck_quals because the unaggregated Vars won't be available
		 * locally.
		 */

		/* Build the list of columns to be fetched from the foreign server. */
		
		fdw_scan_tlist = mysql_build_tlist_to_deparse(foreignrel);

		/*
		 * Ensure that the outer plan produces a tuple whose descriptor
		 * matches our scan tuple slot.  Also, remove the local conditions
		 * from outer plan's quals, lest they be evaluated twice, once by the
		 * local plan and once by the scan.
		 */
		if (outer_plan)
		{
			ListCell   *lc;

			/*
			 * Right now, we only consider grouping and aggregation beyond
			 * joins. Queries involving aggregates or grouping do not require
			 * EPQ mechanism, hence should not have an outer plan here.
			 */
			Assert(!IS_UPPER_REL(foreignrel));

			/*
			 * First, update the plan's qual list if possible.  In some cases
			 * the quals might be enforced below the topmost plan level, in
			 * which case we'll fail to remove them; it's not worth working
			 * harder than this.
			 */
			foreach(lc, local_exprs)
			{
				Node	   *qual = lfirst(lc);

				outer_plan->qual = list_delete(outer_plan->qual, qual);

				/*
				 * For an inner join the local conditions of foreign scan plan
				 * can be part of the joinquals as well.  (They might also be
				 * in the mergequals or hashquals, but we can't touch those
				 * without breaking the plan.)
				 */
				if (IsA(outer_plan, NestLoop) ||
					IsA(outer_plan, MergeJoin) ||
					IsA(outer_plan, HashJoin))
				{
					Join	   *join_plan = (Join *) outer_plan;

					if (join_plan->jointype == JOIN_INNER)
						join_plan->joinqual = list_delete(join_plan->joinqual,
														  qual);
				}
			}

			/*
			 * Now fix the subplan's tlist --- this might result in inserting
			 * a Result node atop the plan tree.
			 */
			outer_plan = change_plan_targetlist(outer_plan, fdw_scan_tlist,
												best_path->path.parallel_safe);
		}
	}

	/* Build the query */
	initStringInfo(&sql);

	mysql_deparse_select_stmt_for_rel(&sql, root, foreignrel, fdw_scan_tlist,
									remote_exprs, best_path->path.pathkeys,
									has_final_sort, has_limit, false,
									&retrieved_attrs, &params_list);

	/* Remember remote_exprs for possible use by mysqlPlanDirectModify */
	fpinfo->final_remote_exprs = remote_exprs;

	/*
	 * Build the fdw_private list that will be available to the executor.
	 * Items in the list must match enum FdwScanPrivateIndex, above.
	 */

	fdw_private = list_make3(makeString(sql.data), retrieved_attrs, fdw_scan_tlist);

	if (IS_JOIN_REL(foreignrel) || IS_UPPER_REL(foreignrel))
		fdw_private = lappend(fdw_private,
							  makeString(fpinfo->relation_name));
	/*
	 * Create the ForeignScan node from target list, local filtering
	 * expressions, remote parameter expressions, and FDW private information.
	 *
	 * Note that the remote parameter expressions are stored in the fdw_exprs
	 * field of the finished plan node; we can't keep them in private state
	 * because then they wouldn't be subject to later planner processing.
	 */
#if PG_VERSION_NUM >= 90500
	return make_foreignscan(tlist, local_exprs, scan_relid, params_list,
							fdw_private, fdw_scan_tlist, NIL, outer_plan);
#else
	return make_foreignscan(tlist, local_exprs, scan_relid, params_list,
							fdw_private);
#endif
}

/*
 * mysqlAnalyzeForeignTable
 * 		Implement stats collection
 */
static bool
mysqlAnalyzeForeignTable(Relation relation, AcquireSampleRowsFunc *func,
						 BlockNumber *totalpages)
{
	StringInfoData sql;
	double		table_size = 0;
	MYSQL	   *conn;
	MYSQL_RES  *result;
	Oid			foreignTableId = RelationGetRelid(relation);
	mysql_opt  *options;
	ForeignServer *server;
	UserMapping *user;
	ForeignTable *table;

	table = GetForeignTable(foreignTableId);
	server = GetForeignServer(table->serverid);
	user = GetUserMapping(relation->rd_rel->relowner, server->serverid);

	/* Fetch options */
	options = mysql_get_options(foreignTableId);
	Assert(options->svr_database != NULL && options->svr_table != NULL);

	/* Connect to the server */
	conn = mysql_get_connection(server, user, options);

	/* Build the query */
	initStringInfo(&sql);
	mysql_deparse_analyze(&sql, options->svr_database, options->svr_table);

	if (mysql_query(conn, sql.data) != 0)
		mysql_error_print(conn);

	result = mysql_store_result(conn);

	/*
	 * To get the table size in ANALYZE operation, we run a SELECT query by
	 * passing the database name and table name.  So if the remote table is not
	 * present, then we end up getting zero rows.  Throw an error in that case.
	 */
	if (mysql_num_rows(result) == 0)
		ereport(ERROR,
				(errcode(ERRCODE_FDW_TABLE_NOT_FOUND),
				 errmsg("relation %s.%s does not exist", options->svr_database,
						options->svr_table)));

	if (result)
	{
		MYSQL_ROW	row;

		row = mysql_fetch_row(result);
		table_size = atof(row[0]);
		mysql_free_result(result);
	}

	*totalpages = table_size / MYSQL_BLKSIZ;

	return false;
}

static List *
mysqlPlanForeignModify(PlannerInfo *root,
					   ModifyTable *plan,
					   Index resultRelation,
					   int subplan_index)
{

	CmdType		operation = plan->operation;
	RangeTblEntry *rte = planner_rt_fetch(resultRelation, root);
	Relation	rel;
	List	   *targetAttrs = NIL;
	StringInfoData sql;
	char	   *attname = NULL;
	Oid			foreignTableId;
	List	   *options;
	ListCell   *lc;
	int			key_column_idx = 1;

	initStringInfo(&sql);

	/*
	 * Core code already has some lock on each rel being planned, so we can
	 * use NoLock here.
	 */
	rel = table_open(rte->relid, NoLock);

	foreignTableId = RelationGetRelid(rel);

	if (!mysql_is_column_unique(foreignTableId))
		ereport(ERROR,
				(errcode(ERRCODE_FDW_UNABLE_TO_CREATE_EXECUTION),
				 errmsg("One column of remote table must be unique for INSERT/UPDATE/DELETE operation")));

	/*
	 * In an INSERT, we transmit all columns that are defined in the foreign
	 * table.  In an UPDATE, if there are BEFORE ROW UPDATE triggers on the
	 * foreign table, we transmit all columns like INSERT; else we transmit
	 * only columns that were explicitly targets of the UPDATE, so as to avoid
	 * unnecessary data transmission.  (We can't do that for INSERT since we
	 * would miss sending default values for columns not listed in the source
	 * statement, and for UPDATE if there are BEFORE ROW UPDATE triggers since
	 * those triggers might change values for non-target columns, in which
	 * case we would miss sending changed values for those columns.)
	 */
	if (operation == CMD_INSERT ||
		(operation == CMD_UPDATE &&
		 rel->trigdesc &&
		 rel->trigdesc->trig_update_before_row))
	{
		TupleDesc	tupdesc = RelationGetDescr(rel);
		int			attnum;

		/*
		 * If it is an UPDATE operation, check for row identifier column in
		 * target attribute list by calling getUpdateTargetAttrs().
		 */
		if (operation == CMD_UPDATE)
			getUpdateTargetAttrs(rte);

		for (attnum = 1; attnum <= tupdesc->natts; attnum++)
		{
			Form_pg_attribute attr = TupleDescAttr(tupdesc, attnum - 1);

			if (!attr->attisdropped)
				targetAttrs = lappend_int(targetAttrs, attnum);
		}
	}
	else if (operation == CMD_UPDATE)
	{
		targetAttrs = getUpdateTargetAttrs(rte);
		/* We also want the rowid column to be available for the update */
		targetAttrs = lcons_int(1, targetAttrs);
	}
	else
		targetAttrs = lcons_int(1, targetAttrs);

	/*
	 * If it's a column of a foreign table, and it has the column_name FDW
	 * option, use that value.
	 */
	options = GetForeignColumnOptions(rte->relid, key_column_idx);
	foreach (lc, options)
	{
		DefElem *def = (DefElem *)lfirst(lc);

		if (strcmp(def->defname, "column_name") == 0)
		{
			attname = mysql_quote_identifier(defGetString(def), '`');
			break;
		}
	}

	/* If no column_name in FDW option */
	if (attname == NULL)
	{
#if PG_VERSION_NUM >= 110000
		attname = get_attname(foreignTableId, key_column_idx, false);
#else
		attname = get_relid_attribute_name(foreignTableId, key_column_idx);
#endif
	}

	/*
	 * Construct the SQL command string.
	 */
	switch (operation)
	{
		case CMD_INSERT:
			mysql_deparse_insert(&sql, root, resultRelation, rel, targetAttrs);
			break;
		case CMD_UPDATE:
			mysql_deparse_update(&sql, root, resultRelation, rel, targetAttrs,
								 attname);
			break;
		case CMD_DELETE:
			mysql_deparse_delete(&sql, root, resultRelation, rel, attname);
			break;
		default:
			elog(ERROR, "unexpected operation: %d", (int) operation);
			break;
	}

	if (plan->returningLists)
		ereport(ERROR,
				(errcode(ERRCODE_FDW_UNABLE_TO_CREATE_EXECUTION),
				 errmsg("RETURNING is not supported by this FDW")));

	table_close(rel, NoLock);

	return list_make2(makeString(sql.data), targetAttrs);
}

/*
 * mysqlBeginForeignModify
 * 		Begin an insert/update/delete operation on a foreign table
 */
static void
mysqlBeginForeignModify(ModifyTableState *mtstate,
						ResultRelInfo *resultRelInfo,
						List *fdw_private,
						int subplan_index,
						int eflags)
{
	MySQLFdwExecState *fmstate;
	EState	   *estate = mtstate->ps.state;
	Relation	rel = resultRelInfo->ri_RelationDesc;
	AttrNumber	n_params;
	Oid			typefnoid = InvalidOid;
	bool		isvarlena = false;
	ListCell   *lc;
	Oid			foreignTableId = InvalidOid;
	RangeTblEntry *rte;
	Oid			userid;
	ForeignServer *server;
	UserMapping *user;
	ForeignTable *table;

	rte = rt_fetch(resultRelInfo->ri_RangeTableIndex, estate->es_range_table);
	userid = rte->checkAsUser ? rte->checkAsUser : GetUserId();

	foreignTableId = RelationGetRelid(rel);

	table = GetForeignTable(foreignTableId);
	server = GetForeignServer(table->serverid);
	user = GetUserMapping(userid, server->serverid);

	/*
	 * Do nothing in EXPLAIN (no ANALYZE) case. resultRelInfo->ri_FdwState
	 * stays NULL.
	 */
	if (eflags & EXEC_FLAG_EXPLAIN_ONLY)
		return;

	/* Begin constructing MySQLFdwExecState. */
	fmstate = (MySQLFdwExecState *) palloc0(sizeof(MySQLFdwExecState));

	fmstate->rel = rel;
	fmstate->mysqlFdwOptions = mysql_get_options(foreignTableId);
	fmstate->conn = mysql_get_connection(server, user,
										 fmstate->mysqlFdwOptions);

	fmstate->query = strVal(list_nth(fdw_private, FdwModifyPrivateUpdateSql));

	fmstate->retrieved_attrs = (List *) list_nth(fdw_private, FdwModifyPrivateTargetAttnums);

	n_params = list_length(fmstate->retrieved_attrs);
	fmstate->p_flinfo = (FmgrInfo *) palloc0(sizeof(FmgrInfo) * n_params);
	fmstate->p_nums = 0;
#if PG_VERSION_NUM >= 110000
	fmstate->temp_cxt = AllocSetContextCreate(estate->es_query_cxt,
											  "mysql_fdw temporary data",
											  ALLOCSET_DEFAULT_SIZES);
#else
	fmstate->temp_cxt = AllocSetContextCreate(estate->es_query_cxt,
											  "mysql_fdw temporary data",
											  ALLOCSET_SMALL_MINSIZE,
											  ALLOCSET_SMALL_INITSIZE,
											  ALLOCSET_SMALL_MAXSIZE);
#endif

	/* Set up for remaining transmittable parameters */
	foreach(lc, fmstate->retrieved_attrs)
	{
		int			attnum = lfirst_int(lc);
		Form_pg_attribute attr = TupleDescAttr(RelationGetDescr(rel),
											   attnum - 1);

		Assert(!attr->attisdropped);

		getTypeOutputInfo(attr->atttypid, &typefnoid, &isvarlena);
		fmgr_info(typefnoid, &fmstate->p_flinfo[fmstate->p_nums]);
		fmstate->p_nums++;
	}
	Assert(fmstate->p_nums <= n_params);

	/* Initialize mysql statment */
	fmstate->stmt = mysql_stmt_init(fmstate->conn);
	if (!fmstate->stmt)
		ereport(ERROR,
				(errcode(ERRCODE_FDW_UNABLE_TO_CREATE_EXECUTION),
				 errmsg("failed to initialize the MySQL query: \n%s",
						mysql_error(fmstate->conn))));

	/* Prepare mysql statment */
	if (mysql_stmt_prepare(fmstate->stmt, fmstate->query,
						   strlen(fmstate->query)) != 0)
		mysql_stmt_error_print(fmstate->conn, fmstate->stmt, "failed to prepare the MySQL query");

	resultRelInfo->ri_FdwState = fmstate;
}

/*
 * mysqlExecForeignInsert
 * 		Insert one row into a foreign table
 */
static TupleTableSlot *
mysqlExecForeignInsert(EState *estate,
					   ResultRelInfo *resultRelInfo,
					   TupleTableSlot *slot,
					   TupleTableSlot *planSlot)
{
	MySQLFdwExecState *fmstate;
	MYSQL_BIND *mysql_bind_buffer;
	ListCell   *lc;
	int			n_params;
	MemoryContext oldcontext;
	bool	   *isnull;
	int			bindnum = 0;

	fmstate = (MySQLFdwExecState *) resultRelInfo->ri_FdwState;
	n_params = list_length(fmstate->retrieved_attrs);

	oldcontext = MemoryContextSwitchTo(fmstate->temp_cxt);

	mysql_bind_buffer = (MYSQL_BIND *) palloc0(sizeof(MYSQL_BIND) * n_params);
	isnull = (bool *) palloc0(sizeof(bool) * n_params);

	mysql_query(fmstate->conn, "SET sql_mode='ANSI_QUOTES'");

	foreach(lc, fmstate->retrieved_attrs)
	{
		int			attnum = lfirst_int(lc) - 1;
		Oid			type = TupleDescAttr(slot->tts_tupleDescriptor, attnum)->atttypid;
		Datum		value;

		/* attnum is not sequential number, we should use bindnum */
		value = slot_getattr(slot, attnum + 1, &isnull[bindnum]);

		mysql_bind_sql_var(type, bindnum, value, mysql_bind_buffer,
						   &isnull[bindnum]);
		bindnum++;
	}

	/* Bind values */
	if (mysql_stmt_bind_param(fmstate->stmt, mysql_bind_buffer) != 0)
		mysql_stmt_error_print(fmstate->conn, fmstate->stmt, "failed to bind the MySQL query");

	/* Execute the query */
	if (mysql_stmt_execute(fmstate->stmt) != 0)
		mysql_stmt_error_print(fmstate->conn, fmstate->stmt, "failed to execute the MySQL query");

	MemoryContextSwitchTo(oldcontext);
	MemoryContextReset(fmstate->temp_cxt);
	return slot;
}

static TupleTableSlot *
mysqlExecForeignUpdate(EState *estate,
					   ResultRelInfo *resultRelInfo,
					   TupleTableSlot *slot,
					   TupleTableSlot *planSlot)
{
	MySQLFdwExecState *fmstate = (MySQLFdwExecState *) resultRelInfo->ri_FdwState;
	Relation	rel = resultRelInfo->ri_RelationDesc;
	MYSQL_BIND *mysql_bind_buffer;
	Oid			foreignTableId = RelationGetRelid(rel);
	bool		is_null = false;
	ListCell   *lc;
	int			bindnum = 0;
	Oid			typeoid;
	Datum		value;
	int			n_params;
	bool	   *isnull;
	Datum		new_value;
	HeapTuple	tuple;
	Form_pg_attribute attr;
	bool		found_row_id_col = false;

	n_params = list_length(fmstate->retrieved_attrs);

	mysql_bind_buffer = (MYSQL_BIND *) palloc0(sizeof(MYSQL_BIND) * n_params);
	isnull = (bool *) palloc0(sizeof(bool) * n_params);

	/* Bind the values */
	foreach(lc, fmstate->retrieved_attrs)
	{
		int			attnum = lfirst_int(lc);
		Oid			type;

		/*
		 * The first attribute cannot be in the target list attribute.  Set the
		 * found_row_id_col to true once we find it so that we can fetch the
		 * value later.
		 */
		if (attnum == 1)
		{
			found_row_id_col = true;
			continue;
		}

		type = TupleDescAttr(slot->tts_tupleDescriptor, attnum - 1)->atttypid;
		value = slot_getattr(slot, attnum, (bool *) (&isnull[bindnum]));

		mysql_bind_sql_var(type, bindnum, value, mysql_bind_buffer,
						   &isnull[bindnum]);
		bindnum++;
	}

	/*
	 * Since we add a row identifier column in the target list always, so
	 * found_row_id_col flag should be true.
	 */
	if (!found_row_id_col)
		elog(ERROR, "missing row identifier column value in UPDATE");

	new_value = slot_getattr(slot, 1, &is_null);

	/*
	 * Get the row identifier column value that was passed up as a resjunk
	 * column and compare that value with the new value to identify if that
	 * value is changed.
	 */
	value = ExecGetJunkAttribute(planSlot, 1, &is_null);

	tuple = SearchSysCache2(ATTNUM,
							ObjectIdGetDatum(foreignTableId),
							Int16GetDatum(1));
	if (!HeapTupleIsValid(tuple))
		elog(ERROR, "cache lookup failed for attribute %d of relation %u",
			 1, foreignTableId);

	attr = (Form_pg_attribute) GETSTRUCT(tuple);
	typeoid = attr->atttypid;

	if (DatumGetPointer(new_value) != NULL && DatumGetPointer(value) != NULL)
	{
		Datum		n_value = new_value;
		Datum 		o_value = value;

		/* If the attribute type is varlena then need to detoast the datums. */
		if (attr->attlen == -1)
		{
			n_value = PointerGetDatum(PG_DETOAST_DATUM(new_value));
			o_value = PointerGetDatum(PG_DETOAST_DATUM(value));
		}

		if (!datumIsEqual(o_value, n_value, attr->attbyval, attr->attlen))
			ereport(ERROR,
					(errcode(ERRCODE_FDW_UNABLE_TO_CREATE_EXECUTION),
					 errmsg("row identifier column update is not supported")));

		/* Free memory if it's a copy made above */
		if (DatumGetPointer(n_value) != DatumGetPointer(new_value))
			pfree(DatumGetPointer(n_value));
		if (DatumGetPointer(o_value) != DatumGetPointer(value))
			pfree(DatumGetPointer(o_value));
	}
	else if (!(DatumGetPointer(new_value) == NULL &&
			   DatumGetPointer(value) == NULL))
		ereport(ERROR,
				(errcode(ERRCODE_FDW_UNABLE_TO_CREATE_EXECUTION),
				 errmsg("row identifier column update is not supported")));

	ReleaseSysCache(tuple);

	/* Bind qual */
	mysql_bind_sql_var(typeoid, bindnum, value, mysql_bind_buffer, &is_null);

	if (mysql_stmt_bind_param(fmstate->stmt, mysql_bind_buffer) != 0)
		ereport(ERROR,
				(errcode(ERRCODE_FDW_UNABLE_TO_CREATE_EXECUTION),
				 errmsg("failed to bind the MySQL query: %s",
						mysql_error(fmstate->conn))));

	/* Execute the query */
	if (mysql_stmt_execute(fmstate->stmt) != 0)
		mysql_stmt_error_print(fmstate->conn, fmstate->stmt, "failed to execute the MySQL query");

	/* Return NULL if nothing was updated on the remote end */
	return slot;
}

/*
 * mysqlAddForeignUpdateTargets
 * 		Add column(s) needed for update/delete on a foreign table, we are
 * 		using first column as row identification column, so we are adding
 * 		that into target list.
 */
static void
mysqlAddForeignUpdateTargets(Query *parsetree,
							 RangeTblEntry *target_rte,
							 Relation target_relation)
{
	Var		   *var;
	const char *attrname;
	TargetEntry *tle;

	/*
	 * What we need is the rowid which is the first column
	 */
	Form_pg_attribute attr =
		TupleDescAttr(RelationGetDescr(target_relation), 0);

	/* Make a Var representing the desired value */
	var = makeVar(parsetree->resultRelation,
				  1,
				  attr->atttypid,
				  attr->atttypmod,
				  InvalidOid,
				  0);

	/* Wrap it in a TLE with the right name ... */
	attrname = NameStr(attr->attname);

	tle = makeTargetEntry((Expr *) var,
						  list_length(parsetree->targetList) + 1,
						  pstrdup(attrname), true);

	/* ... and add it to the query's targetlist */
	parsetree->targetList = lappend(parsetree->targetList, tle);
}

/*
 * mysqlExecForeignDelete
 * 		Delete one row from a foreign table
 */
static TupleTableSlot *
mysqlExecForeignDelete(EState *estate,
					   ResultRelInfo *resultRelInfo,
					   TupleTableSlot *slot,
					   TupleTableSlot *planSlot)
{
	MySQLFdwExecState *fmstate = (MySQLFdwExecState *) resultRelInfo->ri_FdwState;
	Relation	rel = resultRelInfo->ri_RelationDesc;
	MYSQL_BIND *mysql_bind_buffer;
	Oid			foreignTableId = RelationGetRelid(rel);
	bool		is_null = false;
	Oid			typeoid;
	Datum		value;

	mysql_bind_buffer = (MYSQL_BIND *) palloc(sizeof(MYSQL_BIND));

	/* Get the id that was passed up as a resjunk column */
	value = ExecGetJunkAttribute(planSlot, 1, &is_null);
	typeoid = get_atttype(foreignTableId, 1);

	/* Bind qual */
	mysql_bind_sql_var(typeoid, 0, value, mysql_bind_buffer, &is_null);

	if (mysql_stmt_bind_param(fmstate->stmt, mysql_bind_buffer) != 0)
		ereport(ERROR,
				(errcode(ERRCODE_FDW_UNABLE_TO_CREATE_EXECUTION),
				 errmsg("failed to execute the MySQL query: %s",
						mysql_error(fmstate->conn))));

	/* Execute the query */
	if (mysql_stmt_execute(fmstate->stmt) != 0)
		mysql_stmt_error_print(fmstate->conn, fmstate->stmt, "failed to execute the MySQL query");

	/* Return NULL if nothing was updated on the remote end */
	return slot;
}

/*
 * mysqlEndForeignModify
 *		Finish an insert/update/delete operation on a foreign table
 */
static void
mysqlEndForeignModify(EState *estate, ResultRelInfo *resultRelInfo)
{
	MySQLFdwExecState *festate = resultRelInfo->ri_FdwState;

	if (festate && festate->stmt)
	{
		mysql_stmt_close(festate->stmt);
		festate->stmt = NULL;
	}
}

/*
 * mysqlPlanDirectModify
 *		Consider a direct foreign table modification
 *
 * Decide whether it is safe to modify a foreign table directly, and if so,
 * rewrite subplan accordingly.
 */
static bool
mysqlPlanDirectModify(PlannerInfo *root,
						  ModifyTable *plan,
						  Index resultRelation,
						  int subplan_index)
{
	CmdType		operation = plan->operation;
	Plan	   *subplan;
	RelOptInfo *foreignrel;
	RangeTblEntry *rte;
	MySQLFdwRelationInfo *fpinfo;
	Relation	rel;
	StringInfoData sql;
	ForeignScan *fscan;
	List	   *targetAttrs = NIL;
	List	   *remote_exprs;
	List	   *params_list = NIL;
	List	   *retrieved_attrs = NIL;
	Oid			foreignTableId;

	/*
	 * Decide whether it is safe to modify a foreign table directly.
	 */

	/*
	 * The table modification must be an UPDATE or DELETE.
	 */
	if (operation != CMD_UPDATE && operation != CMD_DELETE)
		return false;

	/*
	 * It's unsafe to modify a foreign table directly if there are any local
	 * joins needed.
	 */
	subplan = (Plan *) list_nth(plan->plans, subplan_index);
	if (!IsA(subplan, ForeignScan))
		return false;
	fscan = (ForeignScan *) subplan;

	/*
	 * It's unsafe to modify a foreign table directly if there are any quals
	 * that should be evaluated locally.
	 */
	if (subplan->qual != NIL)
		return false;

	/* not supported  RETURNING clause by this FDW */
	if (plan->returningLists)
	{
		return false;
	}

	/* Safe to fetch data about the target foreign rel */
	if (fscan->scan.scanrelid == 0)
	{
		foreignrel = find_join_rel(root, fscan->fs_relids);
		/* We should have a rel for this foreign join. */
		Assert(foreignrel);
	}
	else
		foreignrel = root->simple_rel_array[resultRelation];

	rte = root->simple_rte_array[resultRelation];
	fpinfo = (MySQLFdwRelationInfo *) foreignrel->fdw_private;

	/*
	 * It's unsafe to update a foreign table directly, if any expressions to
	 * assign to the target columns are unsafe to evaluate remotely.
	 */
	if (operation == CMD_UPDATE)
	{
		int			col;

		/*
		 * We transmit only columns that were explicitly targets of the
		 * UPDATE, so as to avoid unnecessary data transmission.
		 */
		col = -1;
		while ((col = bms_next_member(rte->updatedCols, col)) >= 0)
		{
			/* bit numbers are offset by FirstLowInvalidHeapAttributeNumber */
			AttrNumber	attno = col + FirstLowInvalidHeapAttributeNumber;
			TargetEntry *tle;

			if (attno <= InvalidAttrNumber) /* shouldn't happen */
				elog(ERROR, "system-column update is not supported");

			tle = get_tle_by_resno(subplan->targetlist, attno);

			if (!tle)
				elog(ERROR, "attribute number %d not found in subplan targetlist",
					 attno);

			if (!mysql_is_foreign_expr(root, foreignrel, (Expr *) tle->expr))
				return false;

			targetAttrs = lappend_int(targetAttrs, attno);
		}
	}

	/*
	 * Ok, rewrite subplan so as to modify the foreign table directly.
	 */
	initStringInfo(&sql);

	/*
	 * Core code already has some lock on each rel being planned, so we can
	 * use NoLock here.
	 */
	rel = table_open(rte->relid, NoLock);

	foreignTableId = RelationGetRelid(rel);

	/* Similar as mysqlPlanForeignModify, check the first column of remote table is unique or not */
	if (!mysql_is_column_unique(foreignTableId))
		ereport(ERROR,
				(errcode(ERRCODE_FDW_UNABLE_TO_CREATE_EXECUTION),
				 errmsg("first column of remote table must be unique for INSERT/UPDATE/DELETE operation")));

	/*
	 * Recall the qual clauses that must be evaluated remotely.  (These are
	 * bare clauses not RestrictInfos, but deparse.c's appendConditions()
	 * doesn't care.)
	 */
	remote_exprs = fpinfo->final_remote_exprs;

	/*
	 * Construct the SQL command string.
	 */
	switch (operation)
	{
		case CMD_UPDATE:
			mysql_deparse_direct_update_sql(&sql, root, resultRelation, rel,
												foreignrel,
												((Plan *) fscan)->targetlist,
												targetAttrs,
												remote_exprs, &params_list,
												&retrieved_attrs);
			break;
		case CMD_DELETE:
			mysql_deparse_direct_delete_sql(&sql, root, resultRelation, rel,
												foreignrel,
												remote_exprs, &params_list,
												&retrieved_attrs);
			break;
		default:
			elog(ERROR, "unexpected operation: %d", (int) operation);
			break;
	}

	/*
	 * Update the operation info.
	 */
	fscan->operation = operation;

	/*
	 * Update the fdw_exprs list that will be available to the executor.
	 */
	fscan->fdw_exprs = params_list;

	/*
	 * Update the fdw_private list that will be available to the executor.
	 * Items in the list must match enum FdwDirectModifyPrivateIndex, above.
	 */
	fscan->fdw_private = list_make4(makeString(sql.data),
									makeInteger(0),
									retrieved_attrs,
									makeInteger(plan->canSetTag));

	/*
	 * Update the foreign-join-related fields.
	 */
	if (fscan->scan.scanrelid == 0)
	{
		/* No need for the outer subplan. */
		fscan->scan.plan.lefttree = NULL;
	}

	table_close(rel, NoLock);
	return true;
}

/*
 * mysqlBeginDirectModify
 *		Prepare a direct foreign table modification
 */
static void
mysqlBeginDirectModify(ForeignScanState *node, int eflags)
{
	ForeignScan *fsplan = (ForeignScan *) node->ss.ps.plan;
	EState	   *estate = node->ss.ps.state;
	MySQLFdwDirectModifyState *dmstate;
	Index		rtindex;
	RangeTblEntry *rte;
	Oid			userid;
	ForeignTable *table;
	ForeignServer *server;
	UserMapping *user;
	mysql_opt *options;
	Oid			foreignTableId = InvalidOid;
	int			numParams;

	/*
	 * Do nothing in EXPLAIN (no ANALYZE) case.  node->fdw_state stays NULL.
	 */
	if (eflags & EXEC_FLAG_EXPLAIN_ONLY)
		return;

	/*
	 * We'll save private state in node->fdw_state.
	 */
	dmstate = (MySQLFdwDirectModifyState *) palloc0(sizeof(MySQLFdwDirectModifyState));
	node->fdw_state = (void *) dmstate;

	/*
	 * Identify which user to do the remote access as.  This should match what
	 * ExecCheckRTEPerms() does.
	 */
	rtindex = estate->es_result_relation_info->ri_RangeTableIndex;
#if (PG_VERSION_NUM < 120000)	
	rte = rt_fetch(rtindex, estate->es_range_table);
#else
	rte = exec_rt_fetch(rtindex, estate);
#endif 
	userid = rte->checkAsUser ? rte->checkAsUser : GetUserId();

	/* Get info about foreign table. */
	if (fsplan->scan.scanrelid == 0)
		dmstate->rel = ExecOpenScanRelation(estate, rtindex, eflags);
	else
		dmstate->rel = node->ss.ss_currentRelation;

	foreignTableId = RelationGetRelid(dmstate->rel);

	table = GetForeignTable(foreignTableId);
	server = GetForeignServer(table->serverid);
	user = GetUserMapping(userid, server->serverid);

	options = mysql_get_options(foreignTableId);

	/*
	 * Get connection to the foreign server.  Connection manager will
	 * establish new connection if necessary.
	 */
	dmstate->conn = mysql_get_connection(server, user, options);

	/* Update the foreign-join-related fields. */
	if (fsplan->scan.scanrelid == 0)
	{
		/* Save info about foreign table. */
		dmstate->resultRel = dmstate->rel;

		/*
		 * Set dmstate->rel to NULL to teach get_returning_data() and
		 * make_tuple_from_result_row() that columns fetched from the remote
		 * server are described by fdw_scan_tlist of the foreign-scan plan
		 * node, not the tuple descriptor for the target relation.
		 */
		dmstate->rel = NULL;
	}

	/* Initialize state variable */
	dmstate->num_tuples = -1;	/* -1 means not set yet */

	/* Get private info created by planner functions. */
	dmstate->query = strVal(list_nth(fsplan->fdw_private,
									 FdwDirectModifyPrivateUpdateSql));
	dmstate->has_returning = intVal(list_nth(fsplan->fdw_private,
											 FdwDirectModifyPrivateHasReturning));
	dmstate->retrieved_attrs = (List *) list_nth(fsplan->fdw_private,
												 FdwDirectModifyPrivateRetrievedAttrs);
	dmstate->set_processed = intVal(list_nth(fsplan->fdw_private,
											 FdwDirectModifyPrivateSetProcessed));

	/* Create context for per-tuple temp workspace. */
	dmstate->temp_cxt = AllocSetContextCreate(estate->es_query_cxt,
											  "mysql_fdw temporary data",
											  ALLOCSET_SMALL_SIZES);

	/* Initialize the MySQL statement */
	dmstate->stmt = mysql_stmt_init(dmstate->conn);
	if (dmstate->stmt == NULL)
		ereport(ERROR,
				(errcode(ERRCODE_FDW_UNABLE_TO_CREATE_EXECUTION),
				 errmsg("failed to initialize the mysql query: \n%s",
						mysql_error(dmstate->conn))));

	/* Prepare mysql statement */
	if (mysql_stmt_prepare(dmstate->stmt, dmstate->query, strlen(dmstate->query)) != 0)
		mysql_stmt_error_print(dmstate->conn, dmstate->stmt, "failed to prepare the MySQL query");
	/*
	 * Prepare for processing of parameters used in remote query, if any.
	 */
	numParams = list_length(fsplan->fdw_exprs);
	dmstate->numParams = numParams;
	if (numParams > 0)
		prepare_query_params((PlanState *) node,
							 fsplan->fdw_exprs,
							 numParams,
							 &dmstate->param_flinfo,
							 &dmstate->param_exprs,
							 &dmstate->param_values,
							 &dmstate->param_types);
}

/*
 * mysqlIterateDirectModify
 *		Execute a direct foreign table modification
 */
static TupleTableSlot *
mysqlIterateDirectModify(ForeignScanState *node)
{
	MySQLFdwDirectModifyState *dmstate = (MySQLFdwDirectModifyState *) node->fdw_state;
	EState	   *estate = node->ss.ps.state;
	TupleTableSlot *slot = node->ss.ss_ScanTupleSlot;
	Instrumentation *instr = node->ss.ps.instrument;

	Assert(!dmstate->has_returning);

	/*
	 * If this is the first call after Begin, execute the statement.
	 */
	if (dmstate->num_tuples == -1)
		execute_dml_stmt(node);

	/* Increment the command es_processed count if necessary. */
	if (dmstate->set_processed)
		estate->es_processed += dmstate->num_tuples;

	/* Increment the tuple count for EXPLAIN ANALYZE if necessary. */
	if (instr)
		instr->tuplecount += dmstate->num_tuples;

	return ExecClearTuple(slot);
}

/*
 * mysqlEndDirectModify
 *		Finish a direct foreign table modification
 */
static void
mysqlEndDirectModify(ForeignScanState *node)
{
	MySQLFdwDirectModifyState *dmstate = (MySQLFdwDirectModifyState *) node->fdw_state;

	/* if dmstate is NULL, we are in EXPLAIN; nothing to do */
	if (dmstate == NULL)
		return;

	if (dmstate && dmstate->stmt)
	{
		mysql_stmt_close(dmstate->stmt);
		dmstate->stmt = NULL;
	}

}

/*
 * mysqlExplainDirectModify
 *		Produce extra output for EXPLAIN of a ForeignScan that modifies a
 *		foreign table directly
 */
static void
mysqlExplainDirectModify(ForeignScanState *node,
							 struct ExplainState *es)
{
	List	   *fdw_private;
	char	   *sql;

	if (es->verbose)
	{
		fdw_private = ((ForeignScan *) node->ss.ps.plan)->fdw_private;
		sql = strVal(list_nth(fdw_private, FdwDirectModifyPrivateUpdateSql));
		ExplainPropertyText("mysql query", sql, es);
	}
}

/*
 * mysqlImportForeignSchema
 * 		Import a foreign schema (9.5+)
 */
#if PG_VERSION_NUM >= 90500
static List *
mysqlImportForeignSchema(ImportForeignSchemaStmt *stmt, Oid serverOid)
{
	List	   *commands = NIL;
	bool		import_default = false;
	bool		import_not_null = true;
	ForeignServer *server;
	UserMapping *user;
	mysql_opt  *options;
	MYSQL	   *conn;
	StringInfoData buf;
	MYSQL_RES  *volatile res = NULL;
	MYSQL_ROW	row;
	ListCell   *lc;

	/* Parse statement options */
	foreach(lc, stmt->options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "import_default") == 0)
			import_default = defGetBoolean(def);
		else if (strcmp(def->defname, "import_not_null") == 0)
			import_not_null = defGetBoolean(def);
		else
			ereport(ERROR,
					(errcode(ERRCODE_FDW_INVALID_OPTION_NAME),
					 errmsg("invalid option \"%s\"", def->defname)));
	}

	/*
	 * Get connection to the foreign server.  Connection manager will
	 * establish new connection if necessary.
	 */
	server = GetForeignServer(serverOid);
	user = GetUserMapping(GetUserId(), server->serverid);
	options = mysql_get_options(serverOid);
	conn = mysql_get_connection(server, user, options);

	/* Create workspace for strings */
	initStringInfo(&buf);

	/* Check that the schema really exists */
	appendStringInfo(&buf,
					 "SELECT 1 FROM information_schema.TABLES WHERE TABLE_SCHEMA = '%s'",
					 stmt->remote_schema);

	if (mysql_query(conn, buf.data) != 0)
		mysql_error_print(conn);

	res = mysql_store_result(conn);
	if (!res || mysql_num_rows(res) < 1)
		ereport(ERROR,
				(errcode(ERRCODE_FDW_SCHEMA_NOT_FOUND),
				 errmsg("schema \"%s\" is not present on foreign server \"%s\"",
						stmt->remote_schema, server->servername)));

	mysql_free_result(res);
	res = NULL;
	resetStringInfo(&buf);

	/*
	 * Fetch all table data from this schema, possibly restricted by EXCEPT or
	 * LIMIT TO.
	 */
	appendStringInfo(&buf,
					 " SELECT"
					 "  t.TABLE_NAME,"
					 "  c.COLUMN_NAME,"
					 "  CASE"
					 "    WHEN c.DATA_TYPE = 'enum' THEN LOWER(CONCAT(t.TABLE_NAME, '_', c.COLUMN_NAME, '_t'))"
					 "    WHEN c.DATA_TYPE = 'tinyint' THEN 'smallint'"
					 "    WHEN c.DATA_TYPE = 'mediumint' THEN 'integer'"
					 "    WHEN c.DATA_TYPE = 'tinyint unsigned' THEN 'smallint'"
					 "    WHEN c.DATA_TYPE = 'smallint unsigned' THEN 'integer'"
					 "    WHEN c.DATA_TYPE = 'mediumint unsigned' THEN 'integer'"
					 "    WHEN c.DATA_TYPE = 'int unsigned' THEN 'bigint'"
					 "    WHEN c.DATA_TYPE = 'bigint unsigned' THEN 'numeric(20)'"
					 "    WHEN c.DATA_TYPE = 'double' THEN 'double precision'"
					 "    WHEN c.DATA_TYPE = 'float' THEN 'real'"
					 "    WHEN c.DATA_TYPE = 'datetime' THEN 'timestamp'"
					 "    WHEN c.DATA_TYPE = 'longtext' THEN 'text'"
					 "    WHEN c.DATA_TYPE = 'mediumtext' THEN 'text'"
					 "    WHEN c.DATA_TYPE = 'tinytext' THEN 'text'"
					 "    WHEN c.DATA_TYPE = 'blob' THEN 'bytea'"
					 "    WHEN c.DATA_TYPE = 'mediumblob' THEN 'bytea'"
					 "    WHEN c.DATA_TYPE = 'longblob' THEN 'bytea'"
					 "    ELSE c.DATA_TYPE"
					 "  END,"
					 "  c.COLUMN_TYPE,"
					 "  IF(c.IS_NULLABLE = 'NO', 't', 'f'),"
					 "  c.COLUMN_DEFAULT"
					 " FROM"
					 "  information_schema.TABLES AS t"
					 " JOIN"
					 "  information_schema.COLUMNS AS c"
					 " ON"
					 "  t.TABLE_CATALOG <=> c.TABLE_CATALOG AND t.TABLE_SCHEMA <=> c.TABLE_SCHEMA AND t.TABLE_NAME <=> c.TABLE_NAME"
					 " WHERE"
					 "  t.TABLE_SCHEMA = '%s'",
					 stmt->remote_schema);

	/* Apply restrictions for LIMIT TO and EXCEPT */
	if (stmt->list_type == FDW_IMPORT_SCHEMA_LIMIT_TO ||
		stmt->list_type == FDW_IMPORT_SCHEMA_EXCEPT)
	{
		bool		first_item = true;

		appendStringInfoString(&buf, " AND t.TABLE_NAME ");
		if (stmt->list_type == FDW_IMPORT_SCHEMA_EXCEPT)
			appendStringInfoString(&buf, "NOT ");
		appendStringInfoString(&buf, "IN (");

		/* Append list of table names within IN clause */
		foreach(lc, stmt->table_list)
		{
			RangeVar   *rv = (RangeVar *) lfirst(lc);

			if (first_item)
				first_item = false;
			else
				appendStringInfoString(&buf, ", ");

			appendStringInfo(&buf, "'%s'", rv->relname);
		}
		appendStringInfoChar(&buf, ')');
	}

	/* Append ORDER BY at the end of query to ensure output ordering */
	appendStringInfo(&buf, " ORDER BY t.TABLE_NAME, c.ORDINAL_POSITION");

	/* Fetch the data */
	if (mysql_query(conn, buf.data) != 0)
		mysql_error_print(conn);

	res = mysql_store_result(conn);
	row = mysql_fetch_row(res);
	while (row)
	{
		char	   *tablename = row[0];
		bool		first_item = true;

		resetStringInfo(&buf);
		appendStringInfo(&buf, "CREATE FOREIGN TABLE %s (\n",
						 quote_identifier(tablename));

		/* Scan all rows for this table */
		do
		{
			char	   *attname;
			char	   *typename;
			char	   *typedfn;
			char	   *attnotnull;
			char	   *attdefault;

			/* If table has no columns, we'll see nulls here */
			if (row[1] == NULL)
				continue;

			attname = row[1];
			typename = row[2];

			if (strcmp(typename, "char") == 0 || strcmp(typename, "varchar") == 0)
				typename = row[3];

			typedfn = row[3];
			attnotnull = row[4];
			attdefault = row[5] == NULL ? (char *) NULL : row[5];

			if (strncmp(typedfn, "enum(", 5) == 0)
				ereport(NOTICE,
						(errmsg("error while generating the table definition"),
						 errhint("If you encounter an error, you may need to execute the following first:\nDO $$BEGIN IF NOT EXISTS (SELECT 1 FROM pg_catalog.pg_type WHERE typname = '%s') THEN CREATE TYPE %s AS %s; END IF; END$$;\n",
								 typename, typename, typedfn)));

			if (first_item)
				first_item = false;
			else
				appendStringInfoString(&buf, ",\n");

			/* Print column name and type */
			appendStringInfo(&buf, "  %s %s", quote_identifier(attname),
							 typename);

			/* Add DEFAULT if needed */
			if (import_default && attdefault != NULL)
				appendStringInfo(&buf, " DEFAULT %s", attdefault);

			/* Add NOT NULL if needed */
			if (import_not_null && attnotnull[0] == 't')
				appendStringInfoString(&buf, " NOT NULL");
		}
		while ((row = mysql_fetch_row(res)) &&
			   (strcmp(row[0], tablename) == 0));

		/*
		 * Add server name and table-level options.  We specify remote
		 * database and table name as options (the latter to ensure that
		 * renaming the foreign table doesn't break the association).
		 */
		appendStringInfo(&buf,
						 "\n) SERVER %s OPTIONS (dbname '%s', table_name '%s');\n",
						 quote_identifier(server->servername),
						 stmt->remote_schema,
						 tablename);

		commands = lappend(commands, pstrdup(buf.data));
	}

	/* Clean up */
	mysql_free_result(res);
	res = NULL;
	resetStringInfo(&buf);

	mysql_release_connection(conn);

	return commands;
}
#endif

#if PG_VERSION_NUM >= 110000
/*
 * mysqlBeginForeignInsert
 * 		Prepare for an insert operation triggered by partition routing
 * 		or COPY FROM.
 *
 * This is not yet supported, so raise an error.
 */
static void
mysqlBeginForeignInsert(ModifyTableState *mtstate,
						ResultRelInfo *resultRelInfo)
{
	ereport(ERROR,
			(errcode(ERRCODE_FDW_UNABLE_TO_CREATE_EXECUTION),
			 errmsg("COPY and foreign partition routing not supported in mysql_fdw")));
}

/*
 * mysqlEndForeignInsert
 * 		BeginForeignInsert() is not yet implemented, hence we do not
 * 		have anything to cleanup as of now. We throw an error here just
 * 		to make sure when we do that we do not forget to cleanup
 * 		resources.
 */
static void
mysqlEndForeignInsert(EState *estate, ResultRelInfo *resultRelInfo)
{
	ereport(ERROR,
			(errcode(ERRCODE_FDW_UNABLE_TO_CREATE_EXECUTION),
			 errmsg("COPY and foreign partition routing not supported in mysql_fdw")));
}
#endif


/*
 * Force assorted GUC parameters to settings that ensure that we'll output
 * data values in a form that is unambiguous to the remote server.
 *
 * This is rather expensive and annoying to do once per row, but there's
 * little choice if we want to be sure values are transmitted accurately;
 * we can't leave the settings in place between rows for fear of affecting
 * user-visible computations.
 *
 * We use the equivalent of a function SET option to allow the settings to
 * persist only until the caller calls mysql_set_transmission_modes().  If an
 * error is thrown in between, guc.c will take care of undoing the settings.
 *
 * The return value is the nestlevel that must be passed to
 * mysql_set_transmission_modes() to undo things.
 */
int
mysql_set_transmission_modes(void)
{
	int			nestlevel = NewGUCNestLevel();

	/*
	 * The values set here should match what pg_dump does.  See also
	 * configure_remote_session in connection.c.
	 */
	if (DateStyle != USE_ISO_DATES)
		(void) set_config_option("datestyle", "ISO",
								 PGC_USERSET, PGC_S_SESSION,
								 GUC_ACTION_SAVE, true, 0, false);

	if (IntervalStyle != INTSTYLE_POSTGRES)
		(void) set_config_option("intervalstyle", "postgres",
								 PGC_USERSET, PGC_S_SESSION,
								 GUC_ACTION_SAVE, true, 0, false);
	if (extra_float_digits < 3)
		(void) set_config_option("extra_float_digits", "3",
								 PGC_USERSET, PGC_S_SESSION,
								 GUC_ACTION_SAVE, true, 0, false);

	return nestlevel;
}

/*
 * Undo the effects of mysql_set_transmission_modes().
 */
void
mysql_reset_transmission_modes(int nestlevel)
{
	AtEOXact_GUC(true, nestlevel);
}

/*
 * Prepare for processing of parameters used in remote query.
 */
static void
prepare_query_params(PlanState *node,
					 List *fdw_exprs,
					 int numParams,
					 FmgrInfo **param_flinfo,
					 List **param_exprs,
					 const char ***param_values,
					 Oid **param_types)
{
	int			i;
	ListCell   *lc;

	Assert(numParams > 0);

	/* Prepare for output conversion of parameters used in remote query. */
	*param_flinfo = (FmgrInfo *) palloc0(sizeof(FmgrInfo) * numParams);

	*param_types = (Oid *) palloc0(sizeof(Oid) * numParams);

	i = 0;
	foreach(lc, fdw_exprs)
	{
		Node	   *param_expr = (Node *) lfirst(lc);
		Oid			typefnoid;
		bool		isvarlena;

		(*param_types)[i] = exprType(param_expr);

		getTypeOutputInfo(exprType(param_expr), &typefnoid, &isvarlena);
		fmgr_info(typefnoid, &(*param_flinfo)[i]);
		i++;
	}

	/*
	 * Prepare remote-parameter expressions for evaluation.  (Note: in
	 * practice, we expect that all these expressions will be just Params, so
	 * we could possibly do something more efficient than using the full
	 * expression-eval machinery for this.  But probably there would be little
	 * benefit, and it'd require mysql_fdw to know more than is desirable
	 * about Param evaluation.)
	 */
#if PG_VERSION_NUM >= 100000
	*param_exprs = ExecInitExprList(fdw_exprs, node);
#else
	*param_exprs = (List *) ExecInitExpr((Expr *) fdw_exprs, node);
#endif

	/* Allocate buffer for text form of query parameters. */
	*param_values = (const char **) palloc0(numParams * sizeof(char *));
}

/*
 * Construct array of query parameter values in text format.
 */
static void
process_query_params(ExprContext *econtext,
					 FmgrInfo *param_flinfo,
					 List *param_exprs,
					 const char **param_values,
					 MYSQL_BIND **mysql_bind_buf,
					 Oid *param_types)
{
	int			i;
	ListCell   *lc;

	i = 0;
	foreach(lc, param_exprs)
	{
		ExprState  *expr_state = (ExprState *) lfirst(lc);
		Datum		expr_value;
		bool		isNull;

		/* Evaluate the parameter expression */
#if PG_VERSION_NUM >= 100000
		expr_value = ExecEvalExpr(expr_state, econtext, &isNull);
#else
		expr_value = ExecEvalExpr(expr_state, econtext, &isNull, NULL);
#endif
		mysql_bind_sql_var(param_types[i], i, expr_value, *mysql_bind_buf,
						   &isNull);

		/*
		 * Get string representation of each parameter value by invoking
		 * type-specific output function, unless the value is null.
		 */
		if (isNull)
			param_values[i] = NULL;
		else
			param_values[i] = OutputFunctionCall(&param_flinfo[i], expr_value);
		i++;
	}
}

/*
 * Process the query params and bind the same with the statement, if any.
 * Also, execute the statement.
 */
static void
bind_stmt_params_and_exec(ForeignScanState *node)
{
	MySQLFdwExecState *festate = (MySQLFdwExecState *) node->fdw_state;
	ExprContext *econtext = node->ss.ps.ps_ExprContext;
	int			numParams = festate->numParams;
	const char **values = festate->param_values;
	MYSQL_BIND *mysql_bind_buffer = NULL;

	/*
	 * Construct array of query parameter values in text format.  We do the
	 * conversions in the short-lived per-tuple context, so as not to cause a
	 * memory leak over repeated scans.
	 */
	if (numParams > 0)
	{
		MemoryContext oldcontext;

		oldcontext = MemoryContextSwitchTo(econtext->ecxt_per_tuple_memory);

		mysql_bind_buffer = (MYSQL_BIND *) palloc0(sizeof(MYSQL_BIND) * numParams);

		process_query_params(econtext,
							 festate->param_flinfo,
							 festate->param_exprs,
							 values,
							 &mysql_bind_buffer,
							 festate->param_types);

		mysql_stmt_bind_param(festate->stmt, mysql_bind_buffer);

		MemoryContextSwitchTo(oldcontext);
	}

	/*
	 * Finally, execute the query. The result will be placed in the array we
	 * already bind.
	 */
	if (mysql_stmt_execute(festate->stmt) != 0)
	{
		mysql_stmt_error_print(festate->conn, festate->stmt, "failed to execute the MySQL query");
	}
	else
	{
		/* Check the results of query has warning or not */
		if(mysql_warning_count(festate->conn) > 0)
		{
			MYSQL_RES	*result = NULL;

			if (mysql_query(festate->conn, "SHOW WARNINGS"))
			{
				mysql_error_print(festate->conn);
			}
			result = mysql_store_result(festate->conn);
			if (result)
			{
				/*
				* MySQL provide numbers of rows per table invole in
				* the statment, but we don't have problem with it
				* because we are sending separate query per table
				* in FDW.
				*/
				MYSQL_ROW		row;
				unsigned int	num_fields;
				unsigned int	i;

				num_fields = mysql_num_fields(result);
				while ((row = mysql_fetch_row(result)))
				{
					for(i = 0; i < num_fields; i++)
					{
						/* Check warning of query */
						if (strcmp(row[i], "Division by 0") == 0)
							ereport(ERROR,
										(errcode(ERRCODE_DIVISION_BY_ZERO),
										errmsg("division by zero")));
					}
				}
				mysql_free_result(result);
			}
		}
	}
	

	/* Mark the query as executed */
	festate->query_executed = true;
}


/*
 * Execute a direct UPDATE/DELETE statement.
 */
static void
execute_dml_stmt(ForeignScanState *node)
{
	MySQLFdwDirectModifyState *dmstate = (MySQLFdwDirectModifyState *) node->fdw_state;
	ExprContext *econtext = node->ss.ps.ps_ExprContext;
	int			numParams = dmstate->numParams;
	const char **values = dmstate->param_values;
	MYSQL_BIND *mysql_bind_buffer = NULL;

	/*
	 * Construct array of query parameter values in text format.
	 */
	if (numParams > 0)
	{
		mysql_bind_buffer = (MYSQL_BIND *) palloc0(sizeof(MYSQL_BIND) * numParams);

		process_query_params(econtext,
							 dmstate->param_flinfo,
							 dmstate->param_exprs,
							 values,
							 &mysql_bind_buffer,
							 dmstate->param_types);

		mysql_stmt_bind_param(dmstate->stmt, mysql_bind_buffer);
			mysql_stmt_error_print(dmstate->conn, dmstate->stmt, "failed to bind the MySQL query");
	}

	/*
	 * Finally, execute the query. The result will be placed in the array we
	 * already bind.
	 */
	if (mysql_stmt_execute(dmstate->stmt) != 0)
		mysql_stmt_error_print(dmstate->conn, dmstate->stmt, "failed to execute the MySQL query");

	/* Get the number of rows affected. */
	dmstate->num_tuples = mysql_stmt_affected_rows(dmstate->stmt);
}



Datum
mysql_fdw_version(PG_FUNCTION_ARGS)
{
	PG_RETURN_INT32(CODE_VERSION);
}

static void
mysql_error_print(MYSQL *conn)
{
	switch (mysql_errno(conn))
	{
		case CR_NO_ERROR:
			/* Should not happen, though give some message */
			mysql_release_connection(conn);
			elog(ERROR, "unexpected error code");
			break;
		case CR_OUT_OF_MEMORY:
		case CR_SERVER_GONE_ERROR:
		case CR_SERVER_LOST:
		case CR_UNKNOWN_ERROR:
			mysql_release_connection(conn);
			ereport(ERROR,
					(errcode(ERRCODE_FDW_UNABLE_TO_CREATE_EXECUTION),
					 errmsg("failed to execute the MySQL query: \n%s",
							mysql_error(conn))));
			break;
		case CR_COMMANDS_OUT_OF_SYNC:
		default:
			ereport(ERROR,
					(errcode(ERRCODE_FDW_UNABLE_TO_CREATE_EXECUTION),
					 errmsg("failed to execute the MySQL query: \n%s",
							mysql_error(conn))));
	}
}

static void
mysql_stmt_error_print(MYSQL *conn, MYSQL_STMT *stmt, const char *msg)
{
	switch (mysql_stmt_errno(stmt))
	{
		case CR_NO_ERROR:
			/* Should not happen, though give some message */
			mysql_release_connection(conn);
			elog(ERROR, "unexpected error code");
			break;
		case CR_OUT_OF_MEMORY:
		case CR_SERVER_GONE_ERROR:
		case CR_SERVER_LOST:
		case CR_UNKNOWN_ERROR:
			mysql_release_connection(conn);
			ereport(ERROR,
					(errcode(ERRCODE_FDW_UNABLE_TO_CREATE_EXECUTION),
					 errmsg("%s: \n%s", msg, mysql_error(conn))));
			break;
		case CR_COMMANDS_OUT_OF_SYNC:
		default:
			ereport(ERROR,
					(errcode(ERRCODE_FDW_UNABLE_TO_CREATE_EXECUTION),
					 errmsg("%s: \n%s", msg, mysql_error(conn))));
			break;
	}
}

/*
 * getUpdateTargetAttrs
 * 		Returns the list of attribute numbers of the columns being updated.
 */
static List *
getUpdateTargetAttrs(RangeTblEntry *rte)
{
	List	   *targetAttrs = NIL;

#if PG_VERSION_NUM >= 90500
	Bitmapset  *tmpset = bms_copy(rte->updatedCols);
#else
	Bitmapset  *tmpset = bms_copy(rte->modifiedCols);
#endif
	AttrNumber	col;

	while ((col = bms_first_member(tmpset)) >= 0)
	{
		col += FirstLowInvalidHeapAttributeNumber;
		if (col <= InvalidAttrNumber)	/* shouldn't happen */
			elog(ERROR, "system-column update is not supported");

		/* We also disallow updates to the first column */
		if (col == 1)
			ereport(ERROR,
				(errcode(ERRCODE_FDW_UNABLE_TO_CREATE_EXECUTION),
				 errmsg("row identifier column update is not supported")));

		targetAttrs = lappend_int(targetAttrs, col);
	}

	return targetAttrs;
}

/*
 * mysqlGetForeignJoinPaths
 *		Add possible ForeignPath to joinrel, if join is safe to push down.
 */
static void
mysqlGetForeignJoinPaths(PlannerInfo *root,
							RelOptInfo *joinrel,
							RelOptInfo *outerrel,
							RelOptInfo *innerrel,
							JoinType jointype,
							JoinPathExtraData *extra)
{
	MySQLFdwRelationInfo *fpinfo;
	ForeignPath *joinpath;
	double		rows;
	int			width;
	Cost		startup_cost;
	Cost		total_cost;
	Path	   *epq_path;		/* Path to create plan to be executed when
								 * EvalPlanQual gets triggered. */
	/*
	 * Skip if this join combination has been considered already.
	 */
	if (joinrel->fdw_private)
		return;
	/*
	 * This code does not work for joins with lateral references, since those
	 * must have parameterized paths, which we don't generate yet.
	 */
	if (!bms_is_empty(joinrel->lateral_relids))
		return;

	/*
	 * Create unfinished MySQLFdwRelationInfo entry which is used to indicate
	 * that the join relation is already considered, so that we won't waste
	 * time in judging safety of join pushdown and adding the same paths again
	 * if found safe. Once we know that this join can be pushed down, we fill
	 * the entry.
	 */
	fpinfo = (MySQLFdwRelationInfo *) palloc0(sizeof(MySQLFdwRelationInfo));
	fpinfo->pushdown_safe = false;
	joinrel->fdw_private = fpinfo;
	/* attrs_used is only for base relations. */
	fpinfo->attrs_used = NULL;

	/*
	 * If there is a possibility that EvalPlanQual will be executed, we need
	 * to be able to reconstruct the row using scans of the base relations.
	 * GetExistingLocalJoinPath will find a suitable path for this purpose in
	 * the path list of the joinrel, if one exists.  We must be careful to
	 * call it before adding any ForeignPath, since the ForeignPath might
	 * dominate the only suitable local path available.  We also do it before
	 * calling foreign_join_ok(), since that function updates fpinfo and marks
	 * it as pushable if the join is found to be pushable.
	 */
	if (root->parse->commandType == CMD_DELETE ||
		root->parse->commandType == CMD_UPDATE ||
		root->rowMarks)
	{
		epq_path = GetExistingLocalJoinPath(joinrel);
		if (!epq_path)
		{
			elog(DEBUG3, "could not push down foreign join because a local path suitable for EPQ checks was not found");
			return;
		}
	}
	else
		epq_path = NULL;

	if (!foreign_join_ok(root, joinrel, jointype, outerrel, innerrel, extra))
	{
		/* Free path required for EPQ if we copied one; we don't need it now */
		if (epq_path)
			pfree(epq_path);
		return;
	}

	/*
	 * Compute the selectivity and cost of the local_conds, so we don't have
	 * to do it over again for each path. The best we can do for these
	 * conditions is to estimate selectivity on the basis of local statistics.
	 * The local conditions are applied after the join has been computed on
	 * the remote side like quals in WHERE clause, so pass jointype as
	 * JOIN_INNER.
	 */
	fpinfo->local_conds_sel = clauselist_selectivity(root,
													 fpinfo->local_conds,
													 0,
													 JOIN_INNER,
													 NULL);
	cost_qual_eval(&fpinfo->local_conds_cost, fpinfo->local_conds, root);

	/*
	 * If we are going to estimate costs locally, estimate the join clause
	 * selectivity here while we have special join info.
	 */
	if (!fpinfo->use_remote_estimate)
		fpinfo->joinclause_sel = clauselist_selectivity(root, fpinfo->joinclauses,
														0, fpinfo->jointype,
														extra->sjinfo);

	/* Estimate costs for bare join relation */
	estimate_path_cost_size(root, joinrel, NIL, NIL, NULL,
							&rows, &width, &startup_cost, &total_cost);
	/* Now update this information in the joinrel */
	joinrel->rows = rows;
	joinrel->reltarget->width = width;
	fpinfo->rows = rows;
	fpinfo->width = width;
	fpinfo->startup_cost = startup_cost;
	fpinfo->total_cost = total_cost;

	/*
	 * Create a new join path and add it to the joinrel which represents a
	 * join between foreign tables.
	 */
	joinpath = create_foreign_join_path(root,
										joinrel,
										NULL,	/* default pathtarget */
										rows,
										startup_cost,
										total_cost,
										NIL,	/* no pathkeys */
										joinrel->lateral_relids,
										epq_path,
										NIL);	/* no fdw_private */

	/* Add generated path into joinrel by add_path(). */
	add_path(joinrel, (Path *) joinpath);

	/* Consider pathkeys for the join relation */
	add_paths_with_pathkeys_for_rel(root, joinrel, epq_path);

	/* XXX Consider parameterized paths for the join relation */
}

/*
 * Assess whether the join between inner and outer relations can be pushed down
 * to the foreign server. As a side effect, save information we obtain in this
 * function to MySQLFdwRelationInfo passed in.
 */
static bool
foreign_join_ok(PlannerInfo *root, RelOptInfo *joinrel, JoinType jointype,
				RelOptInfo *outerrel, RelOptInfo *innerrel,
				JoinPathExtraData *extra)
{
	MySQLFdwRelationInfo *fpinfo;
	MySQLFdwRelationInfo *fpinfo_o;
	MySQLFdwRelationInfo *fpinfo_i;
	ListCell   *lc;
	List	   *joinclauses;

	/*
	 * We support pushing down INNER, LEFT, and RIGHT joins.
	 * Constructing queries representing SEMI and ANTI joins is hard, hence
	 * not considered right now.
	 */
	if (jointype != JOIN_INNER && jointype != JOIN_LEFT &&
		jointype != JOIN_RIGHT)
		return false;

	/*
	 * If either of the joining relations is marked as unsafe to pushdown, the
	 * join can not be pushed down.
	 */
	fpinfo = (MySQLFdwRelationInfo *) joinrel->fdw_private;
	fpinfo_o = (MySQLFdwRelationInfo *) outerrel->fdw_private;
	fpinfo_i = (MySQLFdwRelationInfo *) innerrel->fdw_private;
	if (!fpinfo_o || !fpinfo_o->pushdown_safe ||
		!fpinfo_i || !fpinfo_i->pushdown_safe)
		return false;

	/*
	 * If joining relations have local conditions, those conditions are
	 * required to be applied before joining the relations. Hence the join can
	 * not be pushed down.
	 */
	if (fpinfo_o->local_conds || fpinfo_i->local_conds)
		return false;

	/*
	 * Merge FDW options.  We might be tempted to do this after we have deemed
	 * the foreign join to be OK.  But we must do this beforehand so that we
	 * know which quals can be evaluated on the foreign server, which might
	 * depend on shippable_extensions.
	 */
	fpinfo->server = fpinfo_o->server;
	merge_fdw_options(fpinfo, fpinfo_o, fpinfo_i);

	/*
	 * Separate restrict list into join quals and pushed-down (other) quals.
	 *
	 * Join quals belonging to an outer join must all be shippable, else we
	 * cannot execute the join remotely.  Add such quals to 'joinclauses'.
	 *
	 * Add other quals to fpinfo->remote_conds if they are shippable, else to
	 * fpinfo->local_conds.  In an inner join it's okay to execute conditions
	 * either locally or remotely; the same is true for pushed-down conditions
	 * at an outer join.
	 *
	 * Note we might return failure after having already scribbled on
	 * fpinfo->remote_conds and fpinfo->local_conds.  That's okay because we
	 * won't consult those lists again if we deem the join unshippable.
	 */
	joinclauses = NIL;
	foreach(lc, extra->restrictlist)
	{
		RestrictInfo *rinfo = lfirst_node(RestrictInfo, lc);
		bool		is_remote_clause = mysql_is_foreign_expr(root, joinrel,
													   rinfo->clause);

		if (IS_OUTER_JOIN(jointype) &&
			!RINFO_IS_PUSHED_DOWN(rinfo, joinrel->relids))
		{
			if (!is_remote_clause)
				return false;
			joinclauses = lappend(joinclauses, rinfo);
		}
		else
		{
			if (is_remote_clause)
				fpinfo->remote_conds = lappend(fpinfo->remote_conds, rinfo);
			else
				fpinfo->local_conds = lappend(fpinfo->local_conds, rinfo);
		}
	}

	/*
	 * deparseExplicitTargetList() isn't smart enough to handle anything other
	 * than a Var.  In particular, if there's some PlaceHolderVar that would
	 * need to be evaluated within this join tree (because there's an upper
	 * reference to a quantity that may go to NULL as a result of an outer
	 * join), then we can't try to push the join down because we'll fail when
	 * we get to deparseExplicitTargetList().  However, a PlaceHolderVar that
	 * needs to be evaluated *at the top* of this join tree is OK, because we
	 * can do that locally after fetching the results from the remote side.
	 */
	foreach(lc, root->placeholder_list)
	{
		PlaceHolderInfo *phinfo = lfirst(lc);
		Relids		relids;

		/* PlaceHolderInfo refers to parent relids, not child relids. */
		relids = IS_OTHER_REL(joinrel) ?
			joinrel->top_parent_relids : joinrel->relids;

		if (bms_is_subset(phinfo->ph_eval_at, relids) &&
			bms_nonempty_difference(relids, phinfo->ph_eval_at))
			return false;
	}

	/* Save the join clauses, for later use. */
	fpinfo->joinclauses = joinclauses;

	fpinfo->outerrel = outerrel;
	fpinfo->innerrel = innerrel;
	fpinfo->jointype = jointype;

	/*
	 * By default, both the input relations are not required to be deparsed as
	 * subqueries, but there might be some relations covered by the input
	 * relations that are required to be deparsed as subqueries, so save the
	 * relids of those relations for later use by the deparser.
	 */
	fpinfo->make_outerrel_subquery = false;
	fpinfo->make_innerrel_subquery = false;
	Assert(bms_is_subset(fpinfo_o->lower_subquery_rels, outerrel->relids));
	Assert(bms_is_subset(fpinfo_i->lower_subquery_rels, innerrel->relids));
	fpinfo->lower_subquery_rels = bms_union(fpinfo_o->lower_subquery_rels,
											fpinfo_i->lower_subquery_rels);

	/*
	 * Pull the other remote conditions from the joining relations into join
	 * clauses or other remote clauses (remote_conds) of this relation
	 * wherever possible. This avoids building subqueries at every join step.
	 *
	 * For an inner join, clauses from both the relations are added to the
	 * other remote clauses. For LEFT and RIGHT OUTER join, the clauses from
	 * the outer side are added to remote_conds since those can be evaluated
	 * after the join is evaluated. The clauses from inner side are added to
	 * the joinclauses, since they need to be evaluated while constructing the
	 * join.
	 *
	 * For a FULL OUTER JOIN, the other clauses from either relation can not
	 * be added to the joinclauses or remote_conds, since each relation acts
	 * as an outer relation for the other.
	 *
	 * The joining sides can not have local conditions, thus no need to test
	 * shippability of the clauses being pulled up.
	 */
	switch (jointype)
	{
		case JOIN_INNER:
			fpinfo->remote_conds = list_concat(fpinfo->remote_conds,
#if PG_VERSION_NUM < 130000
											   list_copy(fpinfo_i->remote_conds));
#else
											   fpinfo_i->remote_conds);
#endif
			fpinfo->remote_conds = list_concat(fpinfo->remote_conds,
#if PG_VERSION_NUM < 130000
											   list_copy(fpinfo_o->remote_conds));
#else
											   fpinfo_o->remote_conds);
#endif
			break;

		case JOIN_LEFT:
			fpinfo->joinclauses = list_concat(fpinfo->joinclauses,
#if PG_VERSION_NUM < 130000
											  list_copy(fpinfo_i->remote_conds));
#else
											  fpinfo_i->remote_conds);
#endif
			fpinfo->remote_conds = list_concat(fpinfo->remote_conds,
#if PG_VERSION_NUM < 130000
											   list_copy(fpinfo_o->remote_conds));
#else
											   fpinfo_o->remote_conds);
#endif
			break;

		case JOIN_RIGHT:
			fpinfo->joinclauses = list_concat(fpinfo->joinclauses,
#if PG_VERSION_NUM < 130000
											  list_copy(fpinfo_o->remote_conds));
#else
											  fpinfo_o->remote_conds);
#endif
			fpinfo->remote_conds = list_concat(fpinfo->remote_conds,
#if PG_VERSION_NUM < 130000
											   list_copy(fpinfo_i->remote_conds));
#else
											   fpinfo_i->remote_conds);
#endif
			break;

		case JOIN_FULL:

			/*
			 * In this case, if any of the input relations has conditions, we
			 * need to deparse that relation as a subquery so that the
			 * conditions can be evaluated before the join.  Remember it in
			 * the fpinfo of this relation so that the deparser can take
			 * appropriate action.  Also, save the relids of base relations
			 * covered by that relation for later use by the deparser.
			 */
			if (fpinfo_o->remote_conds)
			{
				fpinfo->make_outerrel_subquery = true;
				fpinfo->lower_subquery_rels =
					bms_add_members(fpinfo->lower_subquery_rels,
									outerrel->relids);
			}
			if (fpinfo_i->remote_conds)
			{
				fpinfo->make_innerrel_subquery = true;
				fpinfo->lower_subquery_rels =
					bms_add_members(fpinfo->lower_subquery_rels,
									innerrel->relids);
			}
			break;

		default:
			/* Should not happen, we have just checked this above */
			elog(ERROR, "unsupported join type %d", jointype);
	}

	/*
	 * For an inner join, all restrictions can be treated alike. Treating the
	 * pushed down conditions as join conditions allows a top level full outer
	 * join to be deparsed without requiring subqueries.
	 */
	if (jointype == JOIN_INNER)
	{
		Assert(!fpinfo->joinclauses);
		fpinfo->joinclauses = fpinfo->remote_conds;
		fpinfo->remote_conds = NIL;
	}

	/* Mark that this join can be pushed down safely */
	fpinfo->pushdown_safe = true;

	/* Get user mapping */
	if (fpinfo->use_remote_estimate)
	{
		if (fpinfo_o->use_remote_estimate)
			fpinfo->user = fpinfo_o->user;
		else
			fpinfo->user = fpinfo_i->user;
	}
	else
		fpinfo->user = NULL;

	/*
	 * Set # of retrieved rows and cached relation costs to some negative
	 * value, so that we can detect when they are set to some sensible values,
	 * during one (usually the first) of the calls to estimate_path_cost_size.
	 */
	fpinfo->retrieved_rows = -1;
	fpinfo->rel_startup_cost = -1;
	fpinfo->rel_total_cost = -1;

	/*
	 * Set the string describing this join relation to be used in EXPLAIN
	 * output of corresponding ForeignScan.  Note that the decoration we add
	 * to the base relation names mustn't include any digits, or it'll confuse
	 * mysqlExplainForeignScan.
	 */
	fpinfo->relation_name = psprintf("(%s) %s JOIN (%s)",
									 fpinfo_o->relation_name,
									 mysql_get_jointype_name(fpinfo->jointype),
									 fpinfo_i->relation_name);

	/*
	 * Set the relation index.  This is defined as the position of this
	 * joinrel in the join_rel_list list plus the length of the rtable list.
	 * Note that since this joinrel is at the end of the join_rel_list list
	 * when we are called, we can get the position by list_length.
	 */
	Assert(fpinfo->relation_index == 0);	/* shouldn't be set yet */
	fpinfo->relation_index =
		list_length(root->parse->rtable) + list_length(root->join_rel_list);

	return true;
}

/*
 * estimate_path_cost_size
 *		Get cost and size estimates for a foreign scan on given foreign relation
 *		either a base relation or a join between foreign relations or an upper
 *		relation containing foreign relations.
 *
 * param_join_conds are the parameterization clauses with outer relations.
 * pathkeys specify the expected sort order if any for given path being costed.
 * fpextra specifies additional post-scan/join-processing steps such as the
 * final sort and the LIMIT restriction.
 *
 * The function returns the cost and size estimates in p_rows, p_width,
 * p_startup_cost and p_total_cost variables.
 */
static void
estimate_path_cost_size(PlannerInfo *root,
						RelOptInfo *foreignrel,
						List *param_join_conds,
						List *pathkeys,
						MySQLFdwPathExtraData *fpextra,
						double *p_rows, int *p_width,
						Cost *p_startup_cost, Cost *p_total_cost)
{
	MySQLFdwRelationInfo *fpinfo = (MySQLFdwRelationInfo *) foreignrel->fdw_private;
	double		rows = 0;
	double		retrieved_rows = 0;
	int			width = 0;
	Cost		startup_cost = 0;
	Cost		total_cost = 0;

	/* Make sure the core code has set up the relation's reltarget */
	Assert(foreignrel->reltarget);

	/*
	 * If the table or the server is configured to use remote estimates,
	 * connect to the foreign server and execute EXPLAIN to estimate the
	 * number of rows selected by the restriction+join clauses.  Otherwise,
	 * estimate rows using whatever statistics we have locally, in a way
	 * similar to ordinary tables.
	 */
	if (fpinfo->use_remote_estimate)
	{
		List	   *remote_param_join_conds;
		List	   *local_param_join_conds;
		StringInfoData sql;
		MYSQL	   *conn;
		Selectivity local_sel;
		QualCost	local_cost;
		List	   *fdw_scan_tlist = NIL;
		List	   *remote_conds;

		/* Required only to be passed to deparseSelectStmtForRel */
		List	   *retrieved_attrs;

		/*
		 * param_join_conds might contain both clauses that are safe to send
		 * across, and clauses that aren't.
		 */
		mysql_classify_conditions(root, foreignrel, param_join_conds,
						   &remote_param_join_conds, &local_param_join_conds);

		/* Build the list of columns to be fetched from the foreign server. */
		if (IS_JOIN_REL(foreignrel) || IS_UPPER_REL(foreignrel))
			fdw_scan_tlist = mysql_build_tlist_to_deparse(foreignrel);
		else
			fdw_scan_tlist = NIL;

		/*
		 * The complete list of remote conditions includes everything from
		 * baserestrictinfo plus any extra join_conds relevant to this
		 * particular path.
		 */
		remote_conds = list_concat(remote_param_join_conds,
								   fpinfo->remote_conds);

		/*
		 * Construct EXPLAIN query including the desired SELECT, FROM, and
		 * WHERE clauses. Params and other-relation Vars are replaced by dummy
		 * values, so don't request params_list.
		 */
		initStringInfo(&sql);
		appendStringInfoString(&sql, "EXPLAIN ");
		mysql_deparse_select_stmt_for_rel(&sql, root, foreignrel, fdw_scan_tlist,
										remote_conds, pathkeys,
										fpextra ? fpextra->has_final_sort : false,
										fpextra ? fpextra->has_limit : false,
										false, &retrieved_attrs, NULL);

		/* Connect to the server */
		conn = mysql_get_connection(fpinfo->server, fpinfo->user, (struct mysql_opt *)fpinfo->server->options);

		/* Get the remote estimate */
		get_remote_estimate(sql.data, conn, &rows, &width,
							&startup_cost, &total_cost);

		retrieved_rows = rows;

		/* Factor in the selectivity of the locally-checked quals */
		local_sel = clauselist_selectivity(root,
										   local_param_join_conds,
										   foreignrel->relid,
										   JOIN_INNER,
										   NULL);
		local_sel *= fpinfo->local_conds_sel;

		rows = clamp_row_est(rows * local_sel);

		/* Add in the eval cost of the locally-checked quals */
		startup_cost += fpinfo->local_conds_cost.startup;
		total_cost += fpinfo->local_conds_cost.per_tuple * retrieved_rows;
		cost_qual_eval(&local_cost, local_param_join_conds, root);
		startup_cost += local_cost.startup;
		total_cost += local_cost.per_tuple * retrieved_rows;

		/*
		 * Add in tlist eval cost for each output row.  In case of an
		 * aggregate, some of the tlist expressions such as grouping
		 * expressions will be evaluated remotely, so adjust the costs.
		 */
		startup_cost += foreignrel->reltarget->cost.startup;
		total_cost += foreignrel->reltarget->cost.startup;
		total_cost += foreignrel->reltarget->cost.per_tuple * rows;
		if (IS_UPPER_REL(foreignrel))
		{
			QualCost	tlist_cost;

			cost_qual_eval(&tlist_cost, fdw_scan_tlist, root);
			startup_cost -= tlist_cost.startup;
			total_cost -= tlist_cost.startup;
			total_cost -= tlist_cost.per_tuple * rows;
		}
	}
	else
	{
		Cost		run_cost = 0;

		/*
		 * We don't support join conditions in this mode (hence, no
		 * parameterized paths can be made).
		 */
		Assert(param_join_conds == NIL);

		/*
		 * We will come here again and again with different set of pathkeys or
		 * additional post-scan/join-processing steps that caller wants to
		 * cost.  We don't need to calculate the cost/size estimates for the
		 * underlying scan, join, or grouping each time.  Instead, use those
		 * estimates if we have cached them already.
		 */
		if (fpinfo->rel_startup_cost >= 0 && fpinfo->rel_total_cost >= 0)
		{
			Assert(fpinfo->retrieved_rows >= 1);

			rows = fpinfo->rows;
			retrieved_rows = fpinfo->retrieved_rows;
			width = fpinfo->width;
			startup_cost = fpinfo->rel_startup_cost;
			run_cost = fpinfo->rel_total_cost - fpinfo->rel_startup_cost;

			/*
			 * If we estimate the costs of a foreign scan or a foreign join
			 * with additional post-scan/join-processing steps, the scan or
			 * join costs obtained from the cache wouldn't yet contain the
			 * eval costs for the final scan/join target, which would've been
			 * updated by apply_scanjoin_target_to_paths(); add the eval costs
			 * now.
			 */
			if (fpextra && !IS_UPPER_REL(foreignrel))
			{
				/* Shouldn't get here unless we have LIMIT */
				Assert(fpextra->has_limit);
				Assert(foreignrel->reloptkind == RELOPT_BASEREL ||
					   foreignrel->reloptkind == RELOPT_JOINREL);
				startup_cost += foreignrel->reltarget->cost.startup;
				run_cost += foreignrel->reltarget->cost.per_tuple * rows;
			}
		}
		else if (IS_JOIN_REL(foreignrel))
		{
			MySQLFdwRelationInfo *fpinfo_i;
			MySQLFdwRelationInfo *fpinfo_o;
			QualCost	join_cost;
			QualCost	remote_conds_cost;
			double		nrows;

			/* Use rows/width estimates made by the core code. */
			rows = foreignrel->rows;
			width = foreignrel->reltarget->width;

			/* For join we expect inner and outer relations set */
			Assert(fpinfo->innerrel && fpinfo->outerrel);

			fpinfo_i = (MySQLFdwRelationInfo *) fpinfo->innerrel->fdw_private;
			fpinfo_o = (MySQLFdwRelationInfo *) fpinfo->outerrel->fdw_private;

			/* Estimate of number of rows in cross product */
			nrows = fpinfo_i->rows * fpinfo_o->rows;

			/*
			 * Back into an estimate of the number of retrieved rows.  Just in
			 * case this is nuts, clamp to at most nrows.
			 */
			retrieved_rows = clamp_row_est(rows / fpinfo->local_conds_sel);
			retrieved_rows = Min(retrieved_rows, nrows);

			/*
			 * The cost of foreign join is estimated as cost of generating
			 * rows for the joining relations + cost for applying quals on the
			 * rows.
			 */

			/*
			 * Calculate the cost of clauses pushed down to the foreign server
			 */
			cost_qual_eval(&remote_conds_cost, fpinfo->remote_conds, root);
			/* Calculate the cost of applying join clauses */
			cost_qual_eval(&join_cost, fpinfo->joinclauses, root);

			/*
			 * Startup cost includes startup cost of joining relations and the
			 * startup cost for join and other clauses. We do not include the
			 * startup cost specific to join strategy (e.g. setting up hash
			 * tables) since we do not know what strategy the foreign server
			 * is going to use.
			 */
			startup_cost = fpinfo_i->rel_startup_cost + fpinfo_o->rel_startup_cost;
			startup_cost += join_cost.startup;
			startup_cost += remote_conds_cost.startup;
			startup_cost += fpinfo->local_conds_cost.startup;

			/*
			 * Run time cost includes:
			 *
			 * 1. Run time cost (total_cost - startup_cost) of relations being
			 * joined
			 *
			 * 2. Run time cost of applying join clauses on the cross product
			 * of the joining relations.
			 *
			 * 3. Run time cost of applying pushed down other clauses on the
			 * result of join
			 *
			 * 4. Run time cost of applying nonpushable other clauses locally
			 * on the result fetched from the foreign server.
			 */
			run_cost = fpinfo_i->rel_total_cost - fpinfo_i->rel_startup_cost;
			run_cost += fpinfo_o->rel_total_cost - fpinfo_o->rel_startup_cost;
			run_cost += nrows * join_cost.per_tuple;
			nrows = clamp_row_est(nrows * fpinfo->joinclause_sel);
			run_cost += nrows * remote_conds_cost.per_tuple;
			run_cost += fpinfo->local_conds_cost.per_tuple * retrieved_rows;

			/* Add in tlist eval cost for each output row */
			startup_cost += foreignrel->reltarget->cost.startup;
			run_cost += foreignrel->reltarget->cost.per_tuple * rows;
		}
		else if (IS_UPPER_REL(foreignrel))
		{
			RelOptInfo *outerrel = fpinfo->outerrel;
			MySQLFdwRelationInfo *ofpinfo;
			AggClauseCosts aggcosts;
			double		input_rows;
			int			numGroupCols;
			double		numGroups = 1;

			/* The upper relation should have its outer relation set */
			Assert(outerrel);
			/* and that outer relation should have its reltarget set */
			Assert(outerrel->reltarget);

			/*
			 * This cost model is mixture of costing done for sorted and
			 * hashed aggregates in cost_agg().  We are not sure which
			 * strategy will be considered at remote side, thus for
			 * simplicity, we put all startup related costs in startup_cost
			 * and all finalization and run cost are added in total_cost.
			 */

			ofpinfo = (MySQLFdwRelationInfo *) outerrel->fdw_private;

			/* Get rows from input rel */
			input_rows = ofpinfo->rows;

			/* Collect statistics about aggregates for estimating costs. */
			MemSet(&aggcosts, 0, sizeof(AggClauseCosts));
			if (root->parse->hasAggs)
			{
				get_agg_clause_costs(root, (Node *) fpinfo->grouped_tlist,
									 AGGSPLIT_SIMPLE, &aggcosts);

				/*
				 * The cost of aggregates in the HAVING qual will be the same
				 * for each child as it is for the parent, so there's no need
				 * to use a translated version of havingQual.
				 */
				get_agg_clause_costs(root, (Node *) root->parse->havingQual,
									 AGGSPLIT_SIMPLE, &aggcosts);
			}

			/* Get number of grouping columns and possible number of groups */
			numGroupCols = list_length(root->parse->groupClause);
			numGroups = estimate_num_groups(root,
											get_sortgrouplist_exprs(root->parse->groupClause,
																	fpinfo->grouped_tlist),
											input_rows, NULL);

			/*
			 * Get the retrieved_rows and rows estimates.  If there are HAVING
			 * quals, account for their selectivity.
			 */
			if (root->parse->havingQual)
			{
				/* Factor in the selectivity of the remotely-checked quals */
				retrieved_rows =
					clamp_row_est(numGroups *
								  clauselist_selectivity(root,
														 fpinfo->remote_conds,
														 0,
														 JOIN_INNER,
														 NULL));
				/* Factor in the selectivity of the locally-checked quals */
				rows = clamp_row_est(retrieved_rows * fpinfo->local_conds_sel);
			}
			else
			{
				rows = retrieved_rows = numGroups;
			}

			/* Use width estimate made by the core code. */
			width = foreignrel->reltarget->width;

			/*-----
			 * Startup cost includes:
			 *	  1. Startup cost for underneath input relation, adjusted for
			 *	     tlist replacement by apply_scanjoin_target_to_paths()
			 *	  2. Cost of performing aggregation, per cost_agg()
			 *-----
			 */
			startup_cost = ofpinfo->rel_startup_cost;
			startup_cost += outerrel->reltarget->cost.startup;
			startup_cost += aggcosts.transCost.startup;
			startup_cost += aggcosts.transCost.per_tuple * input_rows;
			startup_cost += aggcosts.finalCost.startup;
			startup_cost += (cpu_operator_cost * numGroupCols) * input_rows;

			/*-----
			 * Run time cost includes:
			 *	  1. Run time cost of underneath input relation, adjusted for
			 *	     tlist replacement by apply_scanjoin_target_to_paths()
			 *	  2. Run time cost of performing aggregation, per cost_agg()
			 *-----
			 */
			run_cost = ofpinfo->rel_total_cost - ofpinfo->rel_startup_cost;
			run_cost += outerrel->reltarget->cost.per_tuple * input_rows;
			run_cost += aggcosts.finalCost.per_tuple * numGroups;
			run_cost += cpu_tuple_cost * numGroups;

			/* Account for the eval cost of HAVING quals, if any */
			if (root->parse->havingQual)
			{
				QualCost	remote_cost;

				/* Add in the eval cost of the remotely-checked quals */
				cost_qual_eval(&remote_cost, fpinfo->remote_conds, root);
				startup_cost += remote_cost.startup;
				run_cost += remote_cost.per_tuple * numGroups;
				/* Add in the eval cost of the locally-checked quals */
				startup_cost += fpinfo->local_conds_cost.startup;
				run_cost += fpinfo->local_conds_cost.per_tuple * retrieved_rows;
			}

			/* Add in tlist eval cost for each output row */
			startup_cost += foreignrel->reltarget->cost.startup;
			run_cost += foreignrel->reltarget->cost.per_tuple * rows;
		}
		else
		{
			Cost		cpu_per_tuple;

			/* Use rows/width estimates made by set_baserel_size_estimates. */
			rows = foreignrel->rows;
			width = foreignrel->reltarget->width;

			/*
			 * Back into an estimate of the number of retrieved rows.  Just in
			 * case this is nuts, clamp to at most foreignrel->tuples.
			 */
			retrieved_rows = clamp_row_est(rows / fpinfo->local_conds_sel);
			retrieved_rows = Min(retrieved_rows, foreignrel->tuples);

			/*
			 * Cost as though this were a seqscan, which is pessimistic.  We
			 * effectively imagine the local_conds are being evaluated
			 * remotely, too.
			 */
			startup_cost = 0;
			run_cost = 0;
			run_cost += seq_page_cost * foreignrel->pages;

			startup_cost += foreignrel->baserestrictcost.startup;
			cpu_per_tuple = cpu_tuple_cost + foreignrel->baserestrictcost.per_tuple;
			run_cost += cpu_per_tuple * foreignrel->tuples;

			/* Add in tlist eval cost for each output row */
			startup_cost += foreignrel->reltarget->cost.startup;
			run_cost += foreignrel->reltarget->cost.per_tuple * rows;
		}

		/*
		 * Without remote estimates, we have no real way to estimate the cost
		 * of generating sorted output.  It could be free if the query plan
		 * the remote side would have chosen generates properly-sorted output
		 * anyway, but in most cases it will cost something.  Estimate a value
		 * high enough that we won't pick the sorted path when the ordering
		 * isn't locally useful, but low enough that we'll err on the side of
		 * pushing down the ORDER BY clause when it's useful to do so.
		 */
		if (pathkeys != NIL)
		{
			if (IS_UPPER_REL(foreignrel))
			{
				Assert(foreignrel->reloptkind == RELOPT_UPPER_REL &&
					   fpinfo->stage == UPPERREL_GROUP_AGG);
				adjust_foreign_grouping_path_cost(root, pathkeys,
												  retrieved_rows, width,
												  fpextra->limit_tuples,
												  &startup_cost, &run_cost);
			}
			else
			{
				startup_cost *= DEFAULT_FDW_SORT_MULTIPLIER;
				run_cost *= DEFAULT_FDW_SORT_MULTIPLIER;
			}
		}

		total_cost = startup_cost + run_cost;

		/* Adjust the cost estimates if we have LIMIT */
		if (fpextra && fpextra->has_limit)
		{
			adjust_limit_rows_costs(&rows, &startup_cost, &total_cost,
									fpextra->offset_est, fpextra->count_est);
			retrieved_rows = rows;
		}
	}

	/*
	 * If this includes the final sort step, the given target, which will be
	 * applied to the resulting path, might have different expressions from
	 * the foreignrel's reltarget (see make_sort_input_target()); adjust tlist
	 * eval costs.
	 */
	if (fpextra && fpextra->has_final_sort &&
		fpextra->target != foreignrel->reltarget)
	{
		QualCost	oldcost = foreignrel->reltarget->cost;
		QualCost	newcost = fpextra->target->cost;

		startup_cost += newcost.startup - oldcost.startup;
		total_cost += newcost.startup - oldcost.startup;
		total_cost += (newcost.per_tuple - oldcost.per_tuple) * rows;
	}

	/*
	 * Cache the retrieved rows and cost estimates for scans, joins, or
	 * groupings without any parameterization, pathkeys, or additional
	 * post-scan/join-processing steps, before adding the costs for
	 * transferring data from the foreign server.  These estimates are useful
	 * for costing remote joins involving this relation or costing other
	 * remote operations on this relation such as remote sorts and remote
	 * LIMIT restrictions, when the costs can not be obtained from the foreign
	 * server.  This function will be called at least once for every foreign
	 * relation without any parameterization, pathkeys, or additional
	 * post-scan/join-processing steps.
	 */
	if (pathkeys == NIL && param_join_conds == NIL && fpextra == NULL)
	{
		fpinfo->retrieved_rows = retrieved_rows;
		fpinfo->rel_startup_cost = startup_cost;
		fpinfo->rel_total_cost = total_cost;
	}

	/*
	 * Add some additional cost factors to account for connection overhead
	 * (fdw_startup_cost), transferring data across the network
	 * (fdw_tuple_cost per retrieved row), and local manipulation of the data
	 * (cpu_tuple_cost per retrieved row).
	 */
	startup_cost += fpinfo->fdw_startup_cost;
	total_cost += fpinfo->fdw_startup_cost;
	total_cost += fpinfo->fdw_tuple_cost * retrieved_rows;
	total_cost += cpu_tuple_cost * retrieved_rows;

	/*
	 * If we have LIMIT, we should prefer performing the restriction remotely
	 * rather than locally, as the former avoids extra row fetches from the
	 * remote that the latter might cause.  But since the core code doesn't
	 * account for such fetches when estimating the costs of the local
	 * restriction (see create_limit_path()), there would be no difference
	 * between the costs of the local restriction and the costs of the remote
	 * restriction estimated above if we don't use remote estimates (except
	 * for the case where the foreignrel is a grouping relation, the given
	 * pathkeys is not NIL, and the effects of a bounded sort for that rel is
	 * accounted for in costing the remote restriction).  Tweak the costs of
	 * the remote restriction to ensure we'll prefer it if LIMIT is a useful
	 * one.
	 */
	if (!fpinfo->use_remote_estimate &&
		fpextra && fpextra->has_limit &&
		fpextra->limit_tuples > 0 &&
		fpextra->limit_tuples < fpinfo->rows)
	{
		Assert(fpinfo->rows > 0);
		total_cost -= (total_cost - startup_cost) * 0.05 *
			(fpinfo->rows - fpextra->limit_tuples) / fpinfo->rows;
	}

	/* Return results. */
	*p_rows = rows;
	*p_width = width;
	*p_startup_cost = startup_cost;
	*p_total_cost = total_cost;
}

/*
 * Estimate costs of executing a SQL statement remotely.
 * The given "sql" must be an EXPLAIN command.
 */
static void
get_remote_estimate(const char *sql, MYSQL *conn,
					double *rows, int *width,
					Cost *startup_cost, Cost *total_cost)
{
	MYSQL_RES  *result;
	double		filtered = 0;
	MYSQL_ROW	row;

	if (mysql_query(conn, sql) != 0)
			mysql_error_print(conn);

	result = mysql_store_result(conn);
	if (result)
	{
		int			num_fields;

		/*
			* MySQL provide numbers of rows per table invole in the statement,
			* but we don't have problem with it because we are sending
			* separate query per table in FDW.
			*/
		row = mysql_fetch_row(result);
		num_fields = mysql_num_fields(result);
		if (row)
		{
			MYSQL_FIELD *field;
			int			i;

			for (i = 0; i < num_fields; i++)
			{
				field = mysql_fetch_field(result);
				if (!row[i])
					continue;
				else if (strcmp(field->name, "rows") == 0)
					*rows = atof(row[i]);
				else if (strcmp(field->name, "filtered") == 0)
					filtered = atof(row[i]);
			}
		}
		mysql_free_result(result);
	}

	if (*rows > 0)
		*rows = ((*rows + 1) * filtered) / 100;
	else
		*rows = DEFAULTE_NUM_ROWS;
}

static void
add_paths_with_pathkeys_for_rel(PlannerInfo *root, RelOptInfo *rel,
								Path *epq_path)
{
	List	   *useful_pathkeys_list = NIL; /* List of all pathkeys */
	ListCell   *lc;

	useful_pathkeys_list = get_useful_pathkeys_for_relation(root, rel);

	/* Create one path for each set of pathkeys we found above. */
	foreach(lc, useful_pathkeys_list)
	{
		double		rows;
		int			width;
		Cost		startup_cost;
		Cost		total_cost;
		List	   *useful_pathkeys = lfirst(lc);
		Path	   *sorted_epq_path;

		estimate_path_cost_size(root, rel, NIL, useful_pathkeys, NULL,
								&rows, &width, &startup_cost, &total_cost);

		/*
		 * The EPQ path must be at least as well sorted as the path itself, in
		 * case it gets used as input to a mergejoin.
		 */
		sorted_epq_path = epq_path;
		if (sorted_epq_path != NULL &&
			!pathkeys_contained_in(useful_pathkeys,
								   sorted_epq_path->pathkeys))
			sorted_epq_path = (Path *)
				create_sort_path(root,
								 rel,
								 sorted_epq_path,
								 useful_pathkeys,
								 -1.0);

		if (IS_SIMPLE_REL(rel))
			add_path(rel, (Path *)
					 create_foreignscan_path(root, rel,
#if PG_VERSION_NUM >= 90600
											 NULL,
#endif
											 rows,
											 startup_cost,
											 total_cost,
											 useful_pathkeys,
											 rel->lateral_relids,
#if PG_VERSION_NUM >= 90500
											 sorted_epq_path,
#endif
											 NIL));
		else
			add_path(rel, (Path *)
					 create_foreign_join_path(root, rel,
											  NULL,
											  rows,
											  startup_cost,
											  total_cost,
											  useful_pathkeys,
											  rel->lateral_relids,
											  sorted_epq_path,
											  NIL));
	}
}

/*
 * Parse options from foreign server and apply them to fpinfo.
 *
 * New options might also require tweaking merge_fdw_options().
 */
static void
apply_server_options(MySQLFdwRelationInfo *fpinfo)
{
	ListCell   *lc;

	foreach(lc, fpinfo->server->options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "use_remote_estimate") == 0)
			fpinfo->use_remote_estimate = defGetBoolean(def);
		else if (strcmp(def->defname, "fdw_startup_cost") == 0)
			fpinfo->fdw_startup_cost = strtod(defGetString(def), NULL);
		else if (strcmp(def->defname, "fdw_tuple_cost") == 0)
			fpinfo->fdw_tuple_cost = strtod(defGetString(def), NULL);
		else if (strcmp(def->defname, "fetch_size") == 0)
			fpinfo->fetch_size = strtol(defGetString(def), NULL, 10);
	}
}

/*
 * Parse options from foreign table and apply them to fpinfo.
 *
 * New options might also require tweaking merge_fdw_options().
 */
static void
apply_table_options(MySQLFdwRelationInfo *fpinfo)
{
	ListCell   *lc;

	foreach(lc, fpinfo->table->options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "use_remote_estimate") == 0)
			fpinfo->use_remote_estimate = defGetBoolean(def);
		else if (strcmp(def->defname, "fetch_size") == 0)
			fpinfo->fetch_size = strtol(defGetString(def), NULL, 10);
	}
}

/*
 * Merge FDW options from input relations into a new set of options for a join
 * or an upper rel.
 *
 * For a join relation, FDW-specific information about the inner and outer
 * relations is provided using fpinfo_i and fpinfo_o.  For an upper relation,
 * fpinfo_o provides the information for the input relation; fpinfo_i is
 * expected to NULL.
 */
static void
merge_fdw_options(MySQLFdwRelationInfo *fpinfo,
				  const MySQLFdwRelationInfo *fpinfo_o,
				  const MySQLFdwRelationInfo *fpinfo_i)
{
	/* We must always have fpinfo_o. */
	Assert(fpinfo_o);

	/* fpinfo_i may be NULL, but if present the servers must both match. */
	Assert(!fpinfo_i ||
		   fpinfo_i->server->serverid == fpinfo_o->server->serverid);

	/*
	 * Copy the server specific FDW options.  (For a join, both relations come
	 * from the same server, so the server options should have the same value
	 * for both relations.)
	 */
	fpinfo->fdw_startup_cost = fpinfo_o->fdw_startup_cost;
	fpinfo->fdw_tuple_cost = fpinfo_o->fdw_tuple_cost;
	fpinfo->shippable_extensions = fpinfo_o->shippable_extensions;
	fpinfo->use_remote_estimate = fpinfo_o->use_remote_estimate;

	fpinfo->fetch_size = fpinfo_o->fetch_size;

	/* Merge the table level options from either side of the join. */
	if (fpinfo_i)
	{
		/*
		 * We'll prefer to use remote estimates for this join if any table
		 * from either side of the join is using remote estimates.  This is
		 * most likely going to be preferred since they're already willing to
		 * pay the price of a round trip to get the remote EXPLAIN.  In any
		 * case it's not entirely clear how we might otherwise handle this
		 * best.
		 */
		fpinfo->use_remote_estimate = fpinfo_o->use_remote_estimate ||
			fpinfo_i->use_remote_estimate;

		/*
		 * Set fetch size to maximum of the joining sides, since we are
		 * expecting the rows returned by the join to be proportional to the
		 * relation sizes.
		 */
		fpinfo->fetch_size = Max(fpinfo_o->fetch_size, fpinfo_i->fetch_size);
	}
}

/*
 * Adjust the cost estimates of a foreign grouping path to include the cost of
 * generating properly-sorted output.
 */
static void
adjust_foreign_grouping_path_cost(PlannerInfo *root,
								  List *pathkeys,
								  double retrieved_rows,
								  double width,
								  double limit_tuples,
								  Cost *p_startup_cost,
								  Cost *p_run_cost)
{
	/*
	 * If the GROUP BY clause isn't sort-able, the plan chosen by the remote
	 * side is unlikely to generate properly-sorted output, so it would need
	 * an explicit sort; adjust the given costs with cost_sort().  Likewise,
	 * if the GROUP BY clause is sort-able but isn't a superset of the given
	 * pathkeys, adjust the costs with that function.  Otherwise, adjust the
	 * costs by applying the same heuristic as for the scan or join case.
	 */
	if (!grouping_is_sortable(root->parse->groupClause) ||
		!pathkeys_contained_in(pathkeys, root->group_pathkeys))
	{
		Path		sort_path;	/* dummy for result of cost_sort */

		cost_sort(&sort_path,
				  root,
				  pathkeys,
				  *p_startup_cost + *p_run_cost,
				  retrieved_rows,
				  width,
				  0.0,
				  work_mem,
				  limit_tuples);

		*p_startup_cost = sort_path.startup_cost;
		*p_run_cost = sort_path.total_cost - sort_path.startup_cost;
	}
	else
	{
		/*
		 * The default extra cost seems too large for foreign-grouping cases;
		 * add 1/4th of that default.
		 */
		double		sort_multiplier = 1.0 + (DEFAULT_FDW_SORT_MULTIPLIER
											 - 1.0) * 0.25;

		*p_startup_cost *= sort_multiplier;
		*p_run_cost *= sort_multiplier;
	}
}

/*
 * get_useful_pathkeys_for_relation
 *		Determine which orderings of a relation might be useful.
 *
 * Getting data in sorted order can be useful either because the requested
 * order matches the final output ordering for the overall query we're
 * planning, or because it enables an efficient merge join.  Here, we try
 * to figure out which pathkeys to consider.
 */
static List *
get_useful_pathkeys_for_relation(PlannerInfo *root, RelOptInfo *rel)
{
	List	   *useful_pathkeys_list = NIL;
	List	   *useful_eclass_list;
	MySQLFdwRelationInfo *fpinfo = (MySQLFdwRelationInfo *) rel->fdw_private;
	EquivalenceClass *query_ec = NULL;
	ListCell   *lc;

	/*
	 * Pushing the query_pathkeys to the remote server is always worth
	 * considering, because it might let us avoid a local sort.
	 */
	fpinfo->qp_is_pushdown_safe = false;
	if (root->query_pathkeys)
	{
		bool		query_pathkeys_ok = true;

		foreach(lc, root->query_pathkeys)
		{
			PathKey    *pathkey = (PathKey *) lfirst(lc);
			EquivalenceClass *pathkey_ec = pathkey->pk_eclass;
			Expr	   *em_expr;

			/*
			 * The planner and executor don't have any clever strategy for
			 * taking data sorted by a prefix of the query's pathkeys and
			 * getting it to be sorted by all of those pathkeys. We'll just
			 * end up resorting the entire data set.  So, unless we can push
			 * down all of the query pathkeys, forget it.
			 *
			 * is_foreign_expr would detect volatile expressions as well, but
			 * checking ec_has_volatile here saves some cycles.
			 */
			if (pathkey_ec->ec_has_volatile ||
				!(em_expr = mysql_find_em_expr_for_rel(pathkey_ec, rel)) ||
				!mysql_is_foreign_expr(root, rel, em_expr))
			{
				query_pathkeys_ok = false;
				break;
			}
		}

		if (query_pathkeys_ok)
		{
			useful_pathkeys_list = list_make1(list_copy(root->query_pathkeys));
			fpinfo->qp_is_pushdown_safe = true;
		}
	}

	/*
	 * Even if we're not using remote estimates, having the remote side do the
	 * sort generally won't be any worse than doing it locally, and it might
	 * be much better if the remote side can generate data in the right order
	 * without needing a sort at all.  However, what we're going to do next is
	 * try to generate pathkeys that seem promising for possible merge joins,
	 * and that's more speculative.  A wrong choice might hurt quite a bit, so
	 * bail out if we can't use remote estimates.
	 */
	if (!fpinfo->use_remote_estimate)
		return useful_pathkeys_list;

	/* Get the list of interesting EquivalenceClasses. */
	useful_eclass_list = get_useful_ecs_for_relation(root, rel);

	/* Extract unique EC for query, if any, so we don't consider it again. */
	if (list_length(root->query_pathkeys) == 1)
	{
		PathKey    *query_pathkey = linitial(root->query_pathkeys);

		query_ec = query_pathkey->pk_eclass;
	}

	/*
	 * As a heuristic, the only pathkeys we consider here are those of length
	 * one.  It's surely possible to consider more, but since each one we
	 * choose to consider will generate a round-trip to the remote side, we
	 * need to be a bit cautious here.  It would sure be nice to have a local
	 * cache of information about remote index definitions...
	 */
	foreach(lc, useful_eclass_list)
	{
		EquivalenceClass *cur_ec = lfirst(lc);
		Expr	   *em_expr;
		PathKey    *pathkey;

		/* If redundant with what we did above, skip it. */
		if (cur_ec == query_ec)
			continue;

		/* If no pushable expression for this rel, skip it. */
		em_expr = mysql_find_em_expr_for_rel(cur_ec, rel);
		if (em_expr == NULL || !mysql_is_foreign_expr(root, rel, em_expr))
			continue;

		/* Looks like we can generate a pathkey, so let's do it. */
		pathkey = make_canonical_pathkey(root, cur_ec,
										 linitial_oid(cur_ec->ec_opfamilies),
										 BTLessStrategyNumber,
										 false);
		useful_pathkeys_list = lappend(useful_pathkeys_list,
									   list_make1(pathkey));
	}

	return useful_pathkeys_list;
}

/*
 * get_useful_ecs_for_relation
 *		Determine which EquivalenceClasses might be involved in useful
 *		orderings of this relation.
 *
 * This function is in some respects a mirror image of the core function
 * pathkeys_useful_for_merging: for a regular table, we know what indexes
 * we have and want to test whether any of them are useful.  For a foreign
 * table, we don't know what indexes are present on the remote side but
 * want to speculate about which ones we'd like to use if they existed.
 *
 * This function returns a list of potentially-useful equivalence classes,
 * but it does not guarantee that an EquivalenceMember exists which contains
 * Vars only from the given relation.  For example, given ft1 JOIN t1 ON
 * ft1.x + t1.x = 0, this function will say that the equivalence class
 * containing ft1.x + t1.x is potentially useful.  Supposing ft1 is remote and
 * t1 is local (or on a different server), it will turn out that no useful
 * ORDER BY clause can be generated.  It's not our job to figure that out
 * here; we're only interested in identifying relevant ECs.
 */
static List *
get_useful_ecs_for_relation(PlannerInfo *root, RelOptInfo *rel)
{
	List	   *useful_eclass_list = NIL;
	ListCell   *lc;
	Relids		relids;

	/*
	 * First, consider whether any active EC is potentially useful for a merge
	 * join against this relation.
	 */
	if (rel->has_eclass_joins)
	{
		foreach(lc, root->eq_classes)
		{
			EquivalenceClass *cur_ec = (EquivalenceClass *) lfirst(lc);

			if (eclass_useful_for_merging(root, cur_ec, rel))
				useful_eclass_list = lappend(useful_eclass_list, cur_ec);
		}
	}

	/*
	 * Next, consider whether there are any non-EC derivable join clauses that
	 * are merge-joinable.  If the joininfo list is empty, we can exit
	 * quickly.
	 */
	if (rel->joininfo == NIL)
		return useful_eclass_list;

	/* If this is a child rel, we must use the topmost parent rel to search. */
	if (IS_OTHER_REL(rel))
	{
		Assert(!bms_is_empty(rel->top_parent_relids));
		relids = rel->top_parent_relids;
	}
	else
		relids = rel->relids;

	/* Check each join clause in turn. */
	foreach(lc, rel->joininfo)
	{
		RestrictInfo *restrictinfo = (RestrictInfo *) lfirst(lc);

		/* Consider only mergejoinable clauses */
		if (restrictinfo->mergeopfamilies == NIL)
			continue;

		/* Make sure we've got canonical ECs. */
		update_mergeclause_eclasses(root, restrictinfo);

		/*
		 * restrictinfo->mergeopfamilies != NIL is sufficient to guarantee
		 * that left_ec and right_ec will be initialized, per comments in
		 * distribute_qual_to_rels.
		 *
		 * We want to identify which side of this merge-joinable clause
		 * contains columns from the relation produced by this RelOptInfo. We
		 * test for overlap, not containment, because there could be extra
		 * relations on either side.  For example, suppose we've got something
		 * like ((A JOIN B ON A.x = B.x) JOIN C ON A.y = C.y) LEFT JOIN D ON
		 * A.y = D.y.  The input rel might be the joinrel between A and B, and
		 * we'll consider the join clause A.y = D.y. relids contains a
		 * relation not involved in the join class (B) and the equivalence
		 * class for the left-hand side of the clause contains a relation not
		 * involved in the input rel (C).  Despite the fact that we have only
		 * overlap and not containment in either direction, A.y is potentially
		 * useful as a sort column.
		 *
		 * Note that it's even possible that relids overlaps neither side of
		 * the join clause.  For example, consider A LEFT JOIN B ON A.x = B.x
		 * AND A.x = 1.  The clause A.x = 1 will appear in B's joininfo list,
		 * but overlaps neither side of B.  In that case, we just skip this
		 * join clause, since it doesn't suggest a useful sort order for this
		 * relation.
		 */
		if (bms_overlap(relids, restrictinfo->right_ec->ec_relids))
			useful_eclass_list = list_append_unique_ptr(useful_eclass_list,
														restrictinfo->right_ec);
		else if (bms_overlap(relids, restrictinfo->left_ec->ec_relids))
			useful_eclass_list = list_append_unique_ptr(useful_eclass_list,
														restrictinfo->left_ec);
	}

	return useful_eclass_list;
}

/*
 * Detect whether we want to process an EquivalenceClass member.
 *
 * This is a callback for use by generate_implied_equalities_for_column.
 */
static bool
ec_member_matches_foreign(PlannerInfo *root, RelOptInfo *rel,
						  EquivalenceClass *ec, EquivalenceMember *em,
						  void *arg)
{
	ec_member_foreign_arg *state = (ec_member_foreign_arg *) arg;
	Expr	   *expr = em->em_expr;

	/*
	 * If we've identified what we're processing in the current scan, we only
	 * want to match that expression.
	 */
	if (state->current != NULL)
		return equal(expr, state->current);

	/*
	 * Otherwise, ignore anything we've already processed.
	 */
	if (list_member(state->already_used, expr))
		return false;

	/* This is the new target to process. */
	state->current = expr;
	return true;
}

#if PG_VERSION_NUM < 130000
/*
 * Find an equivalence class member expression, all of whose Vars, come from
 * the indicated relation.
 */
Expr *
mysql_find_em_expr_for_rel(EquivalenceClass *ec, RelOptInfo *rel)
{
	ListCell   *lc_em;

	foreach(lc_em, ec->ec_members)
	{
		EquivalenceMember *em = lfirst(lc_em);

		if (bms_is_subset(em->em_relids, rel->relids) &&
			!bms_is_empty(em->em_relids))
		{
			/*
			 * If there is more than one equivalence member whose Vars are
			 * taken entirely from this relation, we'll be content to choose
			 * any one of those.
			 */
			return em->em_expr;
		}
	}

	/* We didn't find any suitable equivalence class expression */
	return NULL;
}
#endif

/*
 * Assess whether the aggregation, grouping and having operations can be pushed
 * down to the foreign server.  As a side effect, save information we obtain in
 * this function to MySQLFdwRelationInfo of the input relation.
 */
static bool
foreign_grouping_ok(PlannerInfo *root, RelOptInfo *grouped_rel,
					Node *havingQual)
{
	Query	   *query = root->parse;
	MySQLFdwRelationInfo *fpinfo = (MySQLFdwRelationInfo *) grouped_rel->fdw_private;
	PathTarget *grouping_target = grouped_rel->reltarget;
	MySQLFdwRelationInfo *ofpinfo;
	ListCell   *lc;
	int			i;
	List	   *tlist = NIL;

	/* We currently don't support pushing Grouping Sets. */
	if (query->groupingSets)
		return false;

	/* Get the fpinfo of the underlying scan relation. */
	ofpinfo = (MySQLFdwRelationInfo *) fpinfo->outerrel->fdw_private;

	/*
	 * If underlying scan relation has any local conditions, those conditions
	 * are required to be applied before performing aggregation.  Hence the
	 * aggregate cannot be pushed down.
	 */
	if (ofpinfo->local_conds)
		return false;

	/*
	 * Examine grouping expressions, as well as other expressions we'd need to
	 * compute, and check whether they are safe to push down to the foreign
	 * server.  All GROUP BY expressions will be part of the grouping target
	 * and thus there is no need to search for them separately.  Add grouping
	 * expressions into target list which will be passed to foreign server.
	 *
	 * A tricky fine point is that we must not put any expression into the
	 * target list that is just a foreign param (that is, something that
	 * deparse.c would conclude has to be sent to the foreign server).  If we
	 * do, the expression will also appear in the fdw_exprs list of the plan
	 * node, and setrefs.c will get confused and decide that the fdw_exprs
	 * entry is actually a reference to the fdw_scan_tlist entry, resulting in
	 * a broken plan.  Somewhat oddly, it's OK if the expression contains such
	 * a node, as long as it's not at top level; then no match is possible.
	 */
	i = 0;
	foreach(lc, grouping_target->exprs)
	{
		Expr	   *expr = (Expr *) lfirst(lc);
		Index		sgref = get_pathtarget_sortgroupref(grouping_target, i);
		ListCell   *l;

		/* Check whether this expression is part of GROUP BY clause */
		if (sgref && get_sortgroupref_clause_noerr(sgref, query->groupClause))
		{
			TargetEntry *tle;

			/*
			 * If any GROUP BY expression is not shippable, then we cannot
			 * push down aggregation to the foreign server.
			 */
			if (!mysql_is_foreign_expr(root, grouped_rel, expr))
				return false;

			/*
			 * If it would be a foreign param, we can't put it into the tlist,
			 * so we have to fail.
			 */
			if (mysql_is_foreign_param(root, grouped_rel, expr))
				return false;

			/*
			 * Pushable, so add to tlist.  We need to create a TLE for this
			 * expression and apply the sortgroupref to it.  We cannot use
			 * add_to_flat_tlist() here because that avoids making duplicate
			 * entries in the tlist.  If there are duplicate entries with
			 * distinct sortgrouprefs, we have to duplicate that situation in
			 * the output tlist.
			 */
			tle = makeTargetEntry(expr, list_length(tlist) + 1, NULL, false);
			tle->ressortgroupref = sgref;
			tlist = lappend(tlist, tle);
		}
		else
		{
			/*
			 * Non-grouping expression we need to compute.  Can we ship it
			 * as-is to the foreign server?
			 */
			if (mysql_is_foreign_expr(root, grouped_rel, expr) &&
				!mysql_is_foreign_param(root, grouped_rel, expr))
			{
				/* Yes, so add to tlist as-is; OK to suppress duplicates */
				tlist = add_to_flat_tlist(tlist, list_make1(expr));
			}
			else
			{
				/* Not pushable as a whole; extract its Vars and aggregates */
				List	   *aggvars;

				aggvars = pull_var_clause((Node *) expr,
										  PVC_INCLUDE_AGGREGATES);

				/*
				 * If any aggregate expression is not shippable, then we
				 * cannot push down aggregation to the foreign server.  (We
				 * don't have to check is_foreign_param, since that certainly
				 * won't return true for any such expression.)
				 */
				if (!mysql_is_foreign_expr(root, grouped_rel, (Expr *) aggvars))
					return false;

				/*
				 * Add aggregates, if any, into the targetlist.  Plain Vars
				 * outside an aggregate can be ignored, because they should be
				 * either same as some GROUP BY column or part of some GROUP
				 * BY expression.  In either case, they are already part of
				 * the targetlist and thus no need to add them again.  In fact
				 * including plain Vars in the tlist when they do not match a
				 * GROUP BY column would cause the foreign server to complain
				 * that the shipped query is invalid.
				 */
				foreach(l, aggvars)
				{
					Expr	   *expr = (Expr *) lfirst(l);

					if (IsA(expr, Aggref))
						tlist = add_to_flat_tlist(tlist, list_make1(expr));
				}
			}
		}

		i++;
	}

	/*
	 * Classify the pushable and non-pushable HAVING clauses and save them in
	 * remote_conds and local_conds of the grouped rel's fpinfo.
	 */
	if (havingQual)
	{
		ListCell   *lc;

		foreach(lc, (List *) havingQual)
		{
			Expr	   *expr = (Expr *) lfirst(lc);
			RestrictInfo *rinfo;

			/*
			 * Currently, the core code doesn't wrap havingQuals in
			 * RestrictInfos, so we must make our own.
			 */
			Assert(!IsA(expr, RestrictInfo));
			rinfo = make_restrictinfo(expr,
									  true,
									  false,
									  false,
									  root->qual_security_level,
									  grouped_rel->relids,
									  NULL,
									  NULL);
			if (mysql_is_foreign_expr(root, grouped_rel, expr))
				fpinfo->remote_conds = lappend(fpinfo->remote_conds, rinfo);
			else
				fpinfo->local_conds = lappend(fpinfo->local_conds, rinfo);
		}
	}

	/*
	 * If there are any local conditions, pull Vars and aggregates from it and
	 * check whether they are safe to pushdown or not.
	 */
	if (fpinfo->local_conds)
	{
		List	   *aggvars = NIL;
		ListCell   *lc;

		foreach(lc, fpinfo->local_conds)
		{
			RestrictInfo *rinfo = lfirst_node(RestrictInfo, lc);

			aggvars = list_concat(aggvars,
								  pull_var_clause((Node *) rinfo->clause,
												  PVC_INCLUDE_AGGREGATES));
		}

		foreach(lc, aggvars)
		{
			Expr	   *expr = (Expr *) lfirst(lc);

			/*
			 * If aggregates within local conditions are not safe to push
			 * down, then we cannot push down the query.  Vars are already
			 * part of GROUP BY clause which are checked above, so no need to
			 * access them again here.  Again, we need not check
			 * is_foreign_param for a foreign aggregate.
			 */
			if (IsA(expr, Aggref))
			{
				if (!mysql_is_foreign_expr(root, grouped_rel, expr))
					return false;

				tlist = add_to_flat_tlist(tlist, list_make1(expr));
			}
		}
	}

	/* Store generated targetlist */
	fpinfo->grouped_tlist = tlist;

	/* Safe to pushdown */
	fpinfo->pushdown_safe = true;

	/*
	 * Set # of retrieved rows and cached relation costs to some negative
	 * value, so that we can detect when they are set to some sensible values,
	 * during one (usually the first) of the calls to estimate_path_cost_size.
	 */
	fpinfo->retrieved_rows = -1;
	fpinfo->rel_startup_cost = -1;
	fpinfo->rel_total_cost = -1;

	/*
	 * Set the string describing this grouped relation to be used in EXPLAIN
	 * output of corresponding ForeignScan.  Note that the decoration we add
	 * to the base relation name mustn't include any digits, or it'll confuse
	 * mysqlExplainForeignScan.
	 */
	fpinfo->relation_name = psprintf("Aggregate on (%s)",
									 ofpinfo->relation_name);

	return true;
}

/*
 * mysqlGetForeignUpperPaths
 *		Add paths for post-join operations like aggregation, grouping etc. if
 *		corresponding operations are safe to push down.
 */
static void
mysqlGetForeignUpperPaths(PlannerInfo *root, UpperRelationKind stage,
							 RelOptInfo *input_rel, RelOptInfo *output_rel,
							 void *extra)
{
	MySQLFdwRelationInfo *fpinfo;

	/*
	 * If input rel is not safe to pushdown, then simply return as we cannot
	 * perform any post-join operations on the foreign server.
	 */
	if (!input_rel->fdw_private ||
		!((MySQLFdwRelationInfo *) input_rel->fdw_private)->pushdown_safe)
		return;

	/* Ignore stages we don't support; and skip any duplicate calls. */
	if ((stage != UPPERREL_GROUP_AGG &&
		 stage != UPPERREL_ORDERED &&
		 stage != UPPERREL_FINAL) ||
		output_rel->fdw_private)
		return;

	fpinfo = (MySQLFdwRelationInfo *) palloc0(sizeof(MySQLFdwRelationInfo));
	fpinfo->pushdown_safe = false;
	fpinfo->stage = stage;
	output_rel->fdw_private = fpinfo;

	switch (stage)
	{
		case UPPERREL_GROUP_AGG:
			add_foreign_grouping_paths(root, input_rel, output_rel,
									   (GroupPathExtraData *) extra);
			break;
		case UPPERREL_ORDERED:
			add_foreign_ordered_paths(root, input_rel, output_rel);
			break;
		case UPPERREL_FINAL:
			add_foreign_final_paths(root, input_rel, output_rel,
									(FinalPathExtraData *) extra);
			break;
		default:
			elog(ERROR, "unexpected upper relation: %d", (int) stage);
			break;
	}
}

/*
 * add_foreign_grouping_paths
 *		Add foreign path for grouping and/or aggregation.
 *
 * Given input_rel represents the underlying scan.  The paths are added to the
 * given grouped_rel.
 */
static void
add_foreign_grouping_paths(PlannerInfo *root, RelOptInfo *input_rel,
						   RelOptInfo *grouped_rel,
						   GroupPathExtraData *extra)
{
	Query	   *parse = root->parse;
	MySQLFdwRelationInfo *ifpinfo = input_rel->fdw_private;
	MySQLFdwRelationInfo *fpinfo = grouped_rel->fdw_private;
	ForeignPath *grouppath;
	double		rows;
	int			width;
	Cost		startup_cost;
	Cost		total_cost;

	/* Nothing to be done, if there is no grouping or aggregation required. */
	if (!parse->groupClause && !parse->groupingSets && !parse->hasAggs &&
		!root->hasHavingQual)
		return;

	Assert(extra->patype == PARTITIONWISE_AGGREGATE_NONE ||
		   extra->patype == PARTITIONWISE_AGGREGATE_FULL);

	/* save the input_rel as outerrel in fpinfo */
	fpinfo->outerrel = input_rel;

	/*
	 * Copy foreign table, foreign server, user mapping, FDW options etc.
	 * details from the input relation's fpinfo.
	 */
	fpinfo->table = ifpinfo->table;
	fpinfo->server = ifpinfo->server;
	fpinfo->user = ifpinfo->user;
	merge_fdw_options(fpinfo, ifpinfo, NULL);

	/*
	 * Assess if it is safe to push down aggregation and grouping.
	 *
	 * Use HAVING qual from extra. In case of child partition, it will have
	 * translated Vars.
	 */
	if (!foreign_grouping_ok(root, grouped_rel, extra->havingQual))
		return;

	/*
	 * Compute the selectivity and cost of the local_conds, so we don't have
	 * to do it over again for each path.  (Currently we create just a single
	 * path here, but in future it would be possible that we build more paths
	 * such as pre-sorted paths as in mysqlGetForeignPaths and
	 * mysqlGetForeignJoinPaths.)  The best we can do for these conditions
	 * is to estimate selectivity on the basis of local statistics.
	 */
	fpinfo->local_conds_sel = clauselist_selectivity(root,
													 fpinfo->local_conds,
													 0,
													 JOIN_INNER,
													 NULL);

	cost_qual_eval(&fpinfo->local_conds_cost, fpinfo->local_conds, root);

	/* Estimate the cost of push down */
	estimate_path_cost_size(root, grouped_rel, NIL, NIL, NULL,
							&rows, &width, &startup_cost, &total_cost);

	/* Now update this information in the fpinfo */
	fpinfo->rows = rows;
	fpinfo->width = width;
	fpinfo->startup_cost = startup_cost;
	fpinfo->total_cost = total_cost;

	/* Create and add foreign path to the grouping relation. */
	grouppath = create_foreign_upper_path(root,
										  grouped_rel,
										  grouped_rel->reltarget,
										  rows,
										  startup_cost,
										  total_cost,
										  NIL,	/* no pathkeys */
										  NULL,
										  NIL); /* no fdw_private */

	/* Add generated path into grouped_rel by add_path(). */
	add_path(grouped_rel, (Path *) grouppath);
}

/*
 * add_foreign_ordered_paths
 *		Add foreign paths for performing the final sort remotely.
 *
 * Given input_rel contains the source-data Paths.  The paths are added to the
 * given ordered_rel.
 */
static void
add_foreign_ordered_paths(PlannerInfo *root, RelOptInfo *input_rel,
						  RelOptInfo *ordered_rel)
{
	Query	   *parse = root->parse;
	MySQLFdwRelationInfo *ifpinfo = input_rel->fdw_private;
	MySQLFdwRelationInfo *fpinfo = ordered_rel->fdw_private;
	MySQLFdwPathExtraData *fpextra;
	double		rows;
	int			width;
	Cost		startup_cost;
	Cost		total_cost;
	List	   *fdw_private;
	ForeignPath *ordered_path;
	ListCell   *lc;

	/* Shouldn't get here unless the query has ORDER BY */
	Assert(parse->sortClause);

	/* We don't support cases where there are any SRFs in the targetlist */
	if (parse->hasTargetSRFs)
		return;

	/* Save the input_rel as outerrel in fpinfo */
	fpinfo->outerrel = input_rel;

	/*
	 * Copy foreign table, foreign server, user mapping, FDW options etc.
	 * details from the input relation's fpinfo.
	 */
	fpinfo->table = ifpinfo->table;
	fpinfo->server = ifpinfo->server;
	fpinfo->user = ifpinfo->user;
	merge_fdw_options(fpinfo, ifpinfo, NULL);

	/*
	 * If the input_rel is a base or join relation, we would already have
	 * considered pushing down the final sort to the remote server when
	 * creating pre-sorted foreign paths for that relation, because the
	 * query_pathkeys is set to the root->sort_pathkeys in that case (see
	 * standard_qp_callback()).
	 */
	if (input_rel->reloptkind == RELOPT_BASEREL ||
		input_rel->reloptkind == RELOPT_JOINREL)
	{
		Assert(root->query_pathkeys == root->sort_pathkeys);

		/* Safe to push down if the query_pathkeys is safe to push down */
		fpinfo->pushdown_safe = ifpinfo->qp_is_pushdown_safe;

		return;
	}

	/* The input_rel should be a grouping relation */
	Assert(input_rel->reloptkind == RELOPT_UPPER_REL &&
		   ifpinfo->stage == UPPERREL_GROUP_AGG);

	/*
	 * We try to create a path below by extending a simple foreign path for
	 * the underlying grouping relation to perform the final sort remotely,
	 * which is stored into the fdw_private list of the resulting path.
	 */

	/* Assess if it is safe to push down the final sort */
	foreach(lc, root->sort_pathkeys)
	{
		PathKey    *pathkey = (PathKey *) lfirst(lc);
		EquivalenceClass *pathkey_ec = pathkey->pk_eclass;
		Expr	   *sort_expr;

		/*
		 * is_foreign_expr would detect volatile expressions as well, but
		 * checking ec_has_volatile here saves some cycles.
		 */
		if (pathkey_ec->ec_has_volatile)
			return;

		/* Get the sort expression for the pathkey_ec */
		sort_expr = mysql_find_em_expr_for_input_target(root,
														pathkey_ec,
														input_rel->reltarget);

		/* If it's unsafe to remote, we cannot push down the final sort */
		if (!mysql_is_foreign_expr(root, input_rel, sort_expr))
			return;
	}

	/* Safe to push down */
	fpinfo->pushdown_safe = true;

	/* Construct MySQLFdwPathExtraData */
	fpextra = (MySQLFdwPathExtraData *) palloc0(sizeof(MySQLFdwPathExtraData));
	fpextra->target = root->upper_targets[UPPERREL_ORDERED];
	fpextra->has_final_sort = true;

	/* Estimate the costs of performing the final sort remotely */
	estimate_path_cost_size(root, input_rel, NIL, root->sort_pathkeys, fpextra,
							&rows, &width, &startup_cost, &total_cost);

	/*
	 * Build the fdw_private list that will be used by mysqlGetForeignPlan.
	 * Items in the list must match order in enum FdwPathPrivateIndex.
	 */
	fdw_private = list_make2(makeInteger(true), makeInteger(false));

	/* Create foreign ordering path */
	ordered_path = create_foreign_upper_path(root,
											 input_rel,
											 root->upper_targets[UPPERREL_ORDERED],
											 rows,
											 startup_cost,
											 total_cost,
											 root->sort_pathkeys,
											 NULL,	/* no extra plan */
											 fdw_private);

	/* and add it to the ordered_rel */
	add_path(ordered_rel, (Path *) ordered_path);
}

/*
 * add_foreign_final_paths
 *		Add foreign paths for performing the final processing remotely.
 *
 * Given input_rel contains the source-data Paths.  The paths are added to the
 * given final_rel.
 */
static void
add_foreign_final_paths(PlannerInfo *root, RelOptInfo *input_rel,
						RelOptInfo *final_rel,
						FinalPathExtraData *extra)
{
	Query	   *parse = root->parse;
	MySQLFdwRelationInfo *ifpinfo = (MySQLFdwRelationInfo *) input_rel->fdw_private;
	MySQLFdwRelationInfo *fpinfo = (MySQLFdwRelationInfo *) final_rel->fdw_private;
	bool		has_final_sort = false;
	List	   *pathkeys = NIL;
	MySQLFdwPathExtraData *fpextra;
	bool		save_use_remote_estimate = false;
	double		rows;
	int			width;
	Cost		startup_cost;
	Cost		total_cost;
	List	   *fdw_private;
	ForeignPath *final_path;

	/*
	 * Currently, we only support this for SELECT commands
	 */
	if (parse->commandType != CMD_SELECT)
		return;

	/*
	 * No work if there is no FOR UPDATE/SHARE clause and if there is no need
	 * to add a LIMIT node
	 */
	if (!parse->rowMarks && !extra->limit_needed)
		return;

	/* We don't support cases where there are any SRFs in the targetlist */
	if (parse->hasTargetSRFs)
		return;

	/* Save the input_rel as outerrel in fpinfo */
	fpinfo->outerrel = input_rel;

	/*
	 * Copy foreign table, foreign server, user mapping, FDW options etc.
	 * details from the input relation's fpinfo.
	 */
	fpinfo->table = ifpinfo->table;
	fpinfo->server = ifpinfo->server;
	fpinfo->user = ifpinfo->user;
	merge_fdw_options(fpinfo, ifpinfo, NULL);

	/*
	 * If there is no need to add a LIMIT node, there might be a ForeignPath
	 * in the input_rel's pathlist that implements all behavior of the query.
	 * Note: we would already have accounted for the query's FOR UPDATE/SHARE
	 * (if any) before we get here.
	 */
	if (!extra->limit_needed)
	{
		ListCell   *lc;

		Assert(parse->rowMarks);

		/*
		 * Grouping and aggregation are not supported with FOR UPDATE/SHARE,
		 * so the input_rel should be a base, join, or ordered relation; and
		 * if it's an ordered relation, its input relation should be a base or
		 * join relation.
		 */
		Assert(input_rel->reloptkind == RELOPT_BASEREL ||
			   input_rel->reloptkind == RELOPT_JOINREL ||
			   (input_rel->reloptkind == RELOPT_UPPER_REL &&
				ifpinfo->stage == UPPERREL_ORDERED &&
				(ifpinfo->outerrel->reloptkind == RELOPT_BASEREL ||
				 ifpinfo->outerrel->reloptkind == RELOPT_JOINREL)));

		foreach(lc, input_rel->pathlist)
		{
			Path	   *path = (Path *) lfirst(lc);

			/*
			 * apply_scanjoin_target_to_paths() uses create_projection_path()
			 * to adjust each of its input paths if needed, whereas
			 * create_ordered_paths() uses apply_projection_to_path() to do
			 * that.  So the former might have put a ProjectionPath on top of
			 * the ForeignPath; look through ProjectionPath and see if the
			 * path underneath it is ForeignPath.
			 */
			if (IsA(path, ForeignPath) ||
				(IsA(path, ProjectionPath) &&
				 IsA(((ProjectionPath *) path)->subpath, ForeignPath)))
			{
				/*
				 * Create foreign final path; this gets rid of a
				 * no-longer-needed outer plan (if any), which makes the
				 * EXPLAIN output look cleaner
				 */
				final_path = create_foreign_upper_path(root,
													   path->parent,
													   path->pathtarget,
													   path->rows,
													   path->startup_cost,
													   path->total_cost,
													   path->pathkeys,
													   NULL,	/* no extra plan */
													   NULL);	/* no fdw_private */

				/* and add it to the final_rel */
				add_path(final_rel, (Path *) final_path);

				/* Safe to push down */
				fpinfo->pushdown_safe = true;

				return;
			}
		}

		/*
		 * If we get here it means no ForeignPaths; since we would already
		 * have considered pushing down all operations for the query to the
		 * remote server, give up on it.
		 */
		return;
	}

	Assert(extra->limit_needed);

	/*
	 * If the input_rel is an ordered relation, replace the input_rel with its
	 * input relation
	 */
	if (input_rel->reloptkind == RELOPT_UPPER_REL &&
		ifpinfo->stage == UPPERREL_ORDERED)
	{
		input_rel = ifpinfo->outerrel;
		ifpinfo = (MySQLFdwRelationInfo *) input_rel->fdw_private;
		has_final_sort = true;
		pathkeys = root->sort_pathkeys;
	}

	/* The input_rel should be a base, join, or grouping relation */
	Assert(input_rel->reloptkind == RELOPT_BASEREL ||
		   input_rel->reloptkind == RELOPT_JOINREL ||
		   (input_rel->reloptkind == RELOPT_UPPER_REL &&
			ifpinfo->stage == UPPERREL_GROUP_AGG));

	/*
	 * We try to create a path below by extending a simple foreign path for
	 * the underlying base, join, or grouping relation to perform the final
	 * sort (if has_final_sort) and the LIMIT restriction remotely, which is
	 * stored into the fdw_private list of the resulting path.  (We
	 * re-estimate the costs of sorting the underlying relation, if
	 * has_final_sort.)
	 */

	/*
	 * Assess if it is safe to push down the LIMIT and OFFSET to the remote
	 * server
	 */

	/*
	 * If the underlying relation has any local conditions, the LIMIT/OFFSET
	 * cannot be pushed down.
	 */
	if (ifpinfo->local_conds)
		return;

	/*
	 * When query contains OFFSET but no LIMIT, do not push down because GridDB
	 * does not support.
	 */
	if (!parse->limitCount && parse->limitOffset)
		return;

	/*
	 * Also, the LIMIT/OFFSET cannot be pushed down, if their expressions are
	 * not safe to remote.
	 */
	if (!mysql_is_foreign_expr(root, input_rel, (Expr *) parse->limitOffset) ||
		!mysql_is_foreign_expr(root, input_rel, (Expr *) parse->limitCount))
		return;

	/* Safe to push down */
	fpinfo->pushdown_safe = true;

	/* Construct MySQLFdwPathExtraData */
	fpextra = (MySQLFdwPathExtraData *) palloc0(sizeof(MySQLFdwPathExtraData));
	fpextra->target = root->upper_targets[UPPERREL_FINAL];
	fpextra->has_final_sort = has_final_sort;
	fpextra->has_limit = extra->limit_needed;
	fpextra->limit_tuples = extra->limit_tuples;
	fpextra->count_est = extra->count_est;
	fpextra->offset_est = extra->offset_est;

	/*
	 * Estimate the costs of performing the final sort and the LIMIT
	 * restriction remotely.  If has_final_sort is false, we wouldn't need to
	 * execute EXPLAIN anymore if use_remote_estimate, since the costs can be
	 * roughly estimated using the costs we already have for the underlying
	 * relation, in the same way as when use_remote_estimate is false.  Since
	 * it's pretty expensive to execute EXPLAIN, force use_remote_estimate to
	 * false in that case.
	 */
	if (!fpextra->has_final_sort)
	{
		save_use_remote_estimate = ifpinfo->use_remote_estimate;
		ifpinfo->use_remote_estimate = false;
	}
	estimate_path_cost_size(root, input_rel, NIL, pathkeys, fpextra,
							&rows, &width, &startup_cost, &total_cost);
	if (!fpextra->has_final_sort)
		ifpinfo->use_remote_estimate = save_use_remote_estimate;

	/*
	 * Build the fdw_private list that will be used by mysqlGetForeignPlan.
	 * Items in the list must match order in enum FdwPathPrivateIndex.
	 */
	fdw_private = list_make2(makeInteger(has_final_sort),
							 makeInteger(extra->limit_needed));

	/*
	 * Create foreign final path; this gets rid of a no-longer-needed outer
	 * plan (if any), which makes the EXPLAIN output look cleaner
	 */
	final_path = create_foreign_upper_path(root,
										   input_rel,
										   root->upper_targets[UPPERREL_FINAL],
										   rows,
										   startup_cost,
										   total_cost,
										   pathkeys,
										   NULL,	/* no extra plan */
										   fdw_private);

	/* and add it to the final_rel */
	add_path(final_rel, (Path *) final_path);
}
