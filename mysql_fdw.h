/*-------------------------------------------------------------------------
 *
 * mysql_fdw.h
 * 		Foreign-data wrapper for remote MySQL servers
 *
 * Portions Copyright (c) 2012-2014, PostgreSQL Global Development Group
 * Portions Copyright (c) 2004-2021, EnterpriseDB Corporation.
 *
 * IDENTIFICATION
 * 		mysql_fdw.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef MYSQL_FDW_H
#define MYSQL_FDW_H

#define list_length mysql_list_length
#define list_delete mysql_list_delete
#define list_free mysql_list_free

#include <mysql.h>
#undef list_length
#undef list_delete
#undef list_free

#include "funcapi.h"
#include "access/tupdesc.h"
#include "fmgr.h"
#include "foreign/foreign.h"
#include "funcapi.h"
#include "lib/stringinfo.h"
#include "optimizer/paths.h"
#if PG_VERSION_NUM < 120000
#include "nodes/relation.h"
#else
#include "nodes/pathnodes.h"
#endif
#include "utils/rel.h"
#include "utils/float.h"
#include "catalog/pg_proc.h"

#define MYSQL_PREFETCH_ROWS	100
#define MYSQL_BLKSIZ		(1024 * 4)
#define MYSQL_DEFAULT_SERVER_PORT	3306
#define MAXDATALEN			1024 * 64

#define WAIT_TIMEOUT		0
#define INTERACTIVE_TIMEOUT 0

#define CR_NO_ERROR 0

#if PG_VERSION_NUM >= 140000
#define MYSQL_ATTRIBUTE_GENERATED_STORED 'S'
#endif

#define mysql_options (*_mysql_options)
#define mysql_stmt_prepare (*_mysql_stmt_prepare)
#define mysql_stmt_execute (*_mysql_stmt_execute)
#define mysql_stmt_fetch (*_mysql_stmt_fetch)
#define mysql_query (*_mysql_query)
#define mysql_stmt_attr_set (*_mysql_stmt_attr_set)
#define mysql_stmt_close (*_mysql_stmt_close)
#define mysql_stmt_reset (*_mysql_stmt_reset)
#define mysql_free_result (*_mysql_free_result)
#define mysql_stmt_bind_param (*_mysql_stmt_bind_param)
#define mysql_stmt_bind_result (*_mysql_stmt_bind_result)
#define mysql_stmt_init (*_mysql_stmt_init)
#define mysql_stmt_result_metadata (*_mysql_stmt_result_metadata)
#define mysql_stmt_store_result (*_mysql_stmt_store_result)
#define mysql_fetch_row (*_mysql_fetch_row)
#define mysql_fetch_field (*_mysql_fetch_field)
#define mysql_fetch_fields (*_mysql_fetch_fields)
#define mysql_error (*_mysql_error)
#define mysql_close (*_mysql_close)
#define mysql_store_result (*_mysql_store_result)
#define mysql_init (*_mysql_init)
#define mysql_ssl_set (*_mysql_ssl_set)
#define mysql_real_connect (*_mysql_real_connect)
#define mysql_get_host_info (*_mysql_get_host_info)
#define mysql_get_server_info (*_mysql_get_server_info)
#define mysql_get_proto_info (*_mysql_get_proto_info)
#define mysql_stmt_errno (*_mysql_stmt_errno)
#define mysql_errno (*_mysql_errno)
#define mysql_num_fields (*_mysql_num_fields)
#define mysql_num_rows (*_mysql_num_rows)
#define mysql_warning_count (*_mysql_warning_count)
#define mysql_stmt_affected_rows (*_mysql_stmt_affected_rows)

/*
 * FDW-specific planner information kept in RelOptInfo.fdw_private for a
 * mysql_fdw foreign table.  For a baserel, this struct is created by
 * mysqlGetForeignRelSize, although some fields are not filled till later.
 * mysqlGetForeignJoinPaths creates it for a joinrel, and
 * mysqlGetForeignUpperPaths creates it for an upperrel.
 */
typedef struct MySQLFdwRelationInfo
{
	/*
	 * True means that the relation can be pushed down. Always true for simple
	 * foreign scan.
	 */
	bool		pushdown_safe;

	/*
	 * Restriction clauses, divided into safe and unsafe to pushdown subsets.
	 * All entries in these lists should have RestrictInfo wrappers; that
	 * improves efficiency of selectivity and cost estimation.
	 */
	List	   *remote_conds;
	List	   *local_conds;

	/* Actual remote restriction clauses for scan (sans RestrictInfos) */
	List	   *final_remote_exprs;

	/* Bitmap of attr numbers we need to fetch from the remote server. */
	Bitmapset  *attrs_used;

	/* True means that the query_pathkeys is safe to push down */
	bool		qp_is_pushdown_safe;

	/* Cost and selectivity of local_conds. */
	QualCost	local_conds_cost;
	Selectivity local_conds_sel;

	/* Selectivity of join conditions */
	Selectivity joinclause_sel;

	/* Estimated size and cost for a scan, join, or grouping/aggregation. */
	double		rows;
	int			width;
	Cost		startup_cost;
	Cost		total_cost;

	/*
	 * Estimated number of rows fetched from the foreign server, and costs
	 * excluding costs for transferring those rows from the foreign server.
	 * These are only used by estimate_path_cost_size().
	 */
	double		retrieved_rows;
	Cost		rel_startup_cost;
	Cost		rel_total_cost;

	/* Options extracted from catalogs. */
	bool		use_remote_estimate;
	Cost		fdw_startup_cost;
	Cost		fdw_tuple_cost;
	List	   *shippable_extensions;	/* OIDs of whitelisted extensions */

	/* Cached catalog information. */
	ForeignTable *table;
	ForeignServer *server;
	UserMapping *user;			/* only set in use_remote_estimate mode */

	int			fetch_size;		/* fetch size for this remote table */

	/*
	 * Name of the relation, for use while EXPLAINing ForeignScan.  It is used
	 * for join and upper relations but is set for all relations.  For a base
	 * relation, this is really just the RT index as a string; we convert that
	 * while producing EXPLAIN output.  For join and upper relations, the name
	 * indicates which base foreign tables are included and the join type or
	 * aggregation type used.
	 */
	StringInfo	relation_name;

	/* Join information */
	RelOptInfo *outerrel;
	RelOptInfo *innerrel;
	JoinType	jointype;
	/* joinclauses contains only JOIN/ON conditions for an outer join */
	List	   *joinclauses;	/* List of RestrictInfo */

	/* Upper relation information */
	UpperRelationKind stage;

	/* Grouping information */
	List	   *grouped_tlist;

	/* Subquery information */
	bool		make_outerrel_subquery; /* do we deparse outerrel as a
										 * subquery? */
	bool		make_innerrel_subquery; /* do we deparse innerrel as a
										 * subquery? */
	Relids		lower_subquery_rels;	/* all relids appearing in lower
										 * subqueries */

	/*
	 * Index of the relation.  It is used to create an alias to a subquery
	 * representing the relation.
	 */
	int			relation_index;

	/* Function pushdown surppot in target list */
	bool		is_tlist_func_pushdown;
}			MySQLFdwRelationInfo;

/* Macro for list API backporting. */
#if PG_VERSION_NUM < 130000
#define mysql_list_concat(l1, l2) list_concat(l1, list_copy(l2))
#else
#define mysql_list_concat(l1, l2) list_concat((l1), (l2))
#endif

/*
 * Options structure to store the MySQL
 * server information
 */
typedef struct mysql_opt
{
	int			svr_port;		/* MySQL port number */
	char	   *svr_address;	/* MySQL server ip address */
	char	   *svr_username;	/* MySQL user name */
	char	   *svr_password;	/* MySQL password */
	char	   *svr_database;	/* MySQL database name */
	char	   *svr_table;		/* MySQL table name */
	bool		svr_sa;			/* MySQL secure authentication */
	char	   *svr_init_command;	/* MySQL SQL statement to execute when
									 * connecting to the MySQL server. */
	unsigned long max_blob_size;	/* Max blob size to read without
									 * truncation */
	bool		use_remote_estimate;	/* use remote estimate for rows */
	unsigned long fetch_size;	/* Number of rows to fetch from remote server */
	bool		reconnect;		/* set to true for automatic reconnection */

	char	   *column_name;	/* use column name option */

	/* SSL parameters; unused options may be given as NULL */
	char	   *ssl_key;		/* MySQL SSL: path to the key file */
	char	   *ssl_cert;		/* MySQL SSL: path to the certificate file */
	char	   *ssl_ca;			/* MySQL SSL: path to the certificate
								 * authority file */
	char	   *ssl_capath;		/* MySQL SSL: path to a directory that
								 * contains trusted SSL CA certificates in PEM
								 * format */
	char	   *ssl_cipher;		/* MySQL SSL: list of permissible ciphers to
								 * use for SSL encryption */
}			mysql_opt;

typedef struct mysql_column
{
	Datum		value;
	unsigned long length;
	bool		is_null;
	bool		error;
	MYSQL_BIND *mysql_bind;
}			mysql_column;

typedef struct mysql_table
{
	MYSQL_RES  *mysql_res;
	MYSQL_FIELD *mysql_fields;
	mysql_column *column;
	MYSQL_BIND *mysql_bind;
}			mysql_table;

typedef struct
{
	/*
	 * Tuple descriptor for whole-row reference. We can not use the base
	 * relation's tuple descriptor as it is, since it might have information
	 * about dropped attributes.
	 */
	TupleDesc	tupdesc;

	/*
	 * Positions of the required attributes in the tuple fetched from the
	 * foreign server.
	 */
	int		   *attr_pos;

	/* Position of attribute indicating NULL-ness of whole-row reference */
	int			wr_null_ind_pos;

	/* Values and null array for holding column values. */
	Datum	   *values;
	bool	   *nulls;
}			MySQLWRState;

/*
 * FDW-specific information for ForeignScanState
 * fdw_state.
 */
typedef struct MySQLFdwExecState
{
	MYSQL	   *conn;			/* MySQL connection handle */
	MYSQL_STMT *stmt;			/* MySQL prepared stament handle */
	mysql_table *table;
	char	   *query;			/* Query string */
	Relation	rel;			/* relcache entry for the foreign table */
	List	   *retrieved_attrs;	/* list of target attribute numbers */
	bool		query_executed; /* have we executed the query? */
	int			numParams;		/* number of parameters passed to query */
	FmgrInfo   *param_flinfo;	/* output conversion functions for them */
	List	   *param_exprs;	/* executable expressions for param values */
	const char **param_values;	/* textual values of query parameters */
	Oid		   *param_types;	/* type of query parameters */
	int			p_nums;			/* number of parameters to transmit */
	FmgrInfo   *p_flinfo;		/* output conversion functions for them */
	mysql_opt  *mysqlFdwOptions;	/* MySQL FDW options */

	bool		is_tlist_pushdown;	/* pushdown target list or not */
	/* working memory context */
	MemoryContext temp_cxt;		/* context for per-tuple temporary data */
	AttInMetadata *attinmeta;
	AttrNumber	rowidAttno;		/* attnum of resjunk rowid column */
	MYSQL_RES  *metadata;

	/* for update row movement if subplan result rel */
	struct MySQLFdwExecState *aux_fmstate;	/* foreign-insert state, if
											 * created */

	/*
	 * Members used for constructing the ForeignScan result row when whole-row
	 * references are involved in a pushed down join.
	 */
	MySQLWRState **mysqlwrstates;	/* whole-row construction information for
									 * each base relation involved in the
									 * pushed down join. */
	int		   *wr_attrs_pos;	/* Array mapping the attributes in the
								 * ForeignScan result to those in the rows
								 * fetched from the foreign server.  The array
								 * is indexed by the attribute numbers in the
								 * ForeignScan. */
	TupleDesc	wr_tupdesc;		/* Tuple descriptor describing the result of
								 * ForeignScan node.  Should be same as that
								 * in ForeignScanState::ss::ss_ScanTupleSlot */
	/* Array for holding column values. */
	Datum	   *wr_values;
	bool	   *wr_nulls;
#if PG_VERSION_NUM >= 140000
	char	   *orig_query;		/* original text of INSERT command */
	List	   *target_attrs;	/* list of target attribute numbers */
	int			values_end;		/* length up to the end of VALUES */
	int			batch_size;		/* value of FDW option "batch_size" */
	/* batch operation stuff */
	int			num_slots;		/* number of slots to insert */
#endif
}			MySQLFdwExecState;


/*
 * Execution state of a foreign scan that modifies a foreign table directly.
 */
typedef struct MySQLFdwDirectModifyState
{
	Relation	rel;			/* relcache entry for the foreign table */
	AttInMetadata *attinmeta;	/* attribute datatype conversion metadata */

	/* extracted fdw_private data */
	char	   *query;			/* text of UPDATE/DELETE command */
	bool		has_returning;	/* is there a RETURNING clause? */
	List	   *retrieved_attrs;	/* attr numbers retrieved by RETURNING */
	bool		set_processed;	/* do we set the command es_processed? */

	/* for remote query execution */
	MYSQL	   *conn;			/* MySQL connection handle */
	MYSQL_STMT *stmt;			/* MySQL prepared stament handle */
	int			numParams;		/* number of parameters passed to query */
	FmgrInfo   *param_flinfo;	/* output conversion functions for them */
	List	   *param_exprs;	/* executable expressions for param values */
	const char **param_values;	/* textual values of query parameters */
	Oid		   *param_types;	/* type of query parameters */

	/* for storing result tuples */
	mysql_table *table;			/* result for query */
	int			num_tuples;		/* # of result tuples */
	Relation	resultRel;		/* relcache entry for the target relation */

	/* working memory context */
	MemoryContext temp_cxt;		/* context for per-tuple temporary data */
#if PG_VERSION_NUM >= 140000
	char	   *orig_query;		/* original text of INSERT command */
	int			values_end;		/* length up to the end of VALUES */
	int			batch_size;		/* value of FDW option "batch_size" */
	/* batch operation stuff */
	int			num_slots;		/* number of slots to insert */
#endif
}			MySQLFdwDirectModifyState;



/* MySQL Column List */
typedef struct MySQLColumn
{
	int			attnum;			/* Attribute number */
	char	   *attname;		/* Attribute name */
	int			atttype;		/* Attribute type */
}			MySQLColumn;

extern bool mysql_is_foreign_function_tlist(PlannerInfo *root,
											RelOptInfo *baserel,
											List *tlist);
extern int	((mysql_options) (MYSQL * mysql, enum mysql_option option,
							  const void *arg));
extern int	((mysql_stmt_prepare) (MYSQL_STMT * stmt, const char *query,
								   unsigned long length));
extern int	((mysql_stmt_execute) (MYSQL_STMT * stmt));
extern int	((mysql_stmt_fetch) (MYSQL_STMT * stmt));
extern int	((mysql_query) (MYSQL * mysql, const char *q));
extern bool ((mysql_stmt_attr_set) (MYSQL_STMT * stmt,
									enum enum_stmt_attr_type attr_type,
									const void *attr));
extern bool ((mysql_stmt_close) (MYSQL_STMT * stmt));
extern bool ((mysql_stmt_reset) (MYSQL_STMT * stmt));
extern bool ((mysql_free_result) (MYSQL_RES * result));
extern bool ((mysql_stmt_bind_param) (MYSQL_STMT * stmt, MYSQL_BIND * bnd));
extern bool ((mysql_stmt_bind_result) (MYSQL_STMT * stmt, MYSQL_BIND * bnd));

extern MYSQL_STMT * ((mysql_stmt_init) (MYSQL * mysql));
extern MYSQL_RES * ((mysql_stmt_result_metadata) (MYSQL_STMT * stmt));
extern int	((mysql_stmt_store_result) (MYSQL * mysql));
extern MYSQL_ROW((mysql_fetch_row) (MYSQL_RES * result));
extern MYSQL_FIELD * ((mysql_fetch_field) (MYSQL_RES * result));
extern MYSQL_FIELD * ((mysql_fetch_fields) (MYSQL_RES * result));
extern const char *((mysql_error) (MYSQL * mysql));
extern void ((mysql_close) (MYSQL * sock));
extern MYSQL_RES * ((mysql_store_result) (MYSQL * mysql));
extern MYSQL * ((mysql_init) (MYSQL * mysql));
extern bool ((mysql_ssl_set) (MYSQL * mysql, const char *key, const char *cert,
							  const char *ca, const char *capath,
							  const char *cipher));
extern MYSQL * ((mysql_real_connect) (MYSQL * mysql, const char *host,
									  const char *user, const char *passwd,
									  const char *db, unsigned int port,
									  const char *unix_socket,
									  unsigned long clientflag));

extern const char *((mysql_get_host_info) (MYSQL * mysql));
extern const char *((mysql_get_server_info) (MYSQL * mysql));
extern int	((mysql_get_proto_info) (MYSQL * mysql));

extern unsigned int ((mysql_stmt_errno) (MYSQL_STMT * stmt));
extern unsigned int ((mysql_errno) (MYSQL * mysql));
extern unsigned int ((mysql_num_fields) (MYSQL_RES * result));
extern unsigned int ((mysql_num_rows) (MYSQL_RES * result));
extern unsigned int ((mysql_warning_count) (MYSQL * mysql));
extern uint64_t ((mysql_stmt_affected_rows) (MYSQL_STMT * stmt));

void		mysql_reset_transmission_modes(int nestlevel);
int			mysql_set_transmission_modes(void);

/* option.c headers */
extern bool mysql_is_valid_option(const char *option, Oid context);
extern mysql_opt * mysql_get_options(Oid foreigntableid, bool is_foreigntable);

/* depare.c headers */
extern void mysql_deparse_select(StringInfo buf, PlannerInfo *root,
								 RelOptInfo *baserel, Bitmapset *attrs_used,
								 char *svr_table, List **retrieved_attrs, List *tlist);
#if PG_VERSION_NUM >= 140000
extern void mysql_deparse_insert(StringInfo buf, RangeTblEntry *rte,
								 Index rtindex, Relation rel,
								 List *targetAttrs, bool doNothing,
								 int *values_end_len);
#else
extern void mysql_deparse_insert(StringInfo buf, RangeTblEntry *rte,
								 Index rtindex, Relation rel,
								 List *targetAttrs, bool doNothing);
#endif
extern void mysql_deparse_update(StringInfo buf, PlannerInfo *root,
								 Index rtindex, Relation rel,
								 List *targetAttrs, char *attname);
extern void mysql_rebuild_insert_sql(StringInfo buf, Relation rel,
									 char *orig_query, List *target_attrs,
									 int values_end_len, int num_params,
									 int num_rows);
extern void mysql_deparse_direct_update_sql(StringInfo buf, PlannerInfo *root,
											Index rtindex, Relation rel,
											RelOptInfo *foreignrel,
											List *targetlist,
											List *targetAttrs,
											List *remote_conds,
											List **params_list,
											List **retrieved_attrs);

extern void mysql_deparse_delete(StringInfo buf, PlannerInfo *root,
								 Index rtindex, Relation rel, char *name);
extern void mysql_deparse_direct_delete_sql(StringInfo buf, PlannerInfo *root,
											Index rtindex, Relation rel,
											RelOptInfo *foreignrel,
											List *remote_conds,
											List **params_list,
											List **retrieved_attrs);
extern void mysql_append_where_clause(StringInfo buf, PlannerInfo *root,
									  RelOptInfo *baserel, List *exprs,
									  bool is_first, List **params);
extern void mysql_deparse_analyze(StringInfo buf, char *dbname, char *relname);
#if PG_VERSION_NUM >= 140000
extern void mysql_deparse_truncate_sql(StringInfo buf,
									   List *rels);
#endif
extern void mysql_deparse_select_stmt_for_rel(StringInfo buf, PlannerInfo *root,
											  RelOptInfo *foreignrel, List *tlist,
											  List *remote_conds, List *pathkeys,
											  bool has_final_sort, bool has_limit,
											  bool is_subquery,
											  List **retrieved_attrs, List **params_list);
extern bool mysql_is_foreign_expr(PlannerInfo *root, RelOptInfo *baserel,
								  Expr *expr);
extern bool mysql_is_foreign_param(PlannerInfo *root,
								   RelOptInfo *baserel,
								   Expr *expr);
extern const char *mysql_get_jointype_name(JoinType jointype);
extern void mysql_classify_conditions(PlannerInfo *root,
									  RelOptInfo *baserel,
									  List *input_conds,
									  List **remote_conds,
									  List **local_conds);
extern Expr *mysql_find_em_expr_for_input_target(PlannerInfo *root,
												 EquivalenceClass *ec,
												 PathTarget *target);
extern List *mysql_build_tlist_to_deparse(RelOptInfo *foreignrel);

extern Expr *mysql_find_em_expr_for_rel(EquivalenceClass *ec, RelOptInfo *rel);
extern bool mysql_is_builtin(Oid oid);
extern List *mysql_pull_func_clause(Node *node);

/* connection.c headers */
MYSQL	   *mysql_get_connection(ForeignServer *server, UserMapping *user,
								 mysql_opt * opt);
MYSQL	   *mysql_connect(mysql_opt * opt);
void		mysql_cleanup_connection(void);
void		mysql_release_connection(MYSQL * conn);
extern char *mysql_quote_identifier(const char *str, char quotechar);

#if PG_VERSION_NUM < 110000		/* TupleDescAttr is defined from PG version 11 */
#define TupleDescAttr(tupdesc, i) ((tupdesc)->attrs[(i)])
#endif

#if PG_VERSION_NUM < 120000
#define table_close(rel, lock)	heap_close(rel, lock)
#define table_open(rel, lock)	heap_open(rel, lock)
#define exec_rt_fetch(rtindex, estate)	rt_fetch(rtindex, estate->es_range_table)
#endif

#endif							/* MYSQL_FDW_H */
