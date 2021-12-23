/*-------------------------------------------------------------------------
 *
 * deparse.c
 * 		Query deparser for mysql_fdw
 *
 * Portions Copyright (c) 2012-2014, PostgreSQL Global Development Group
 * Portions Copyright (c) 2004-2021, EnterpriseDB Corporation.
 *
 * IDENTIFICATION
 * 		deparse.c
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include "access/heapam.h"
#include "access/htup_details.h"
#include "access/sysattr.h"
#include "access/transam.h"
#include "catalog/pg_collation.h"
#include "catalog/pg_namespace.h"
#include "catalog/pg_operator.h"
#include "catalog/pg_proc.h"
#include "catalog/pg_type.h"
#include "commands/defrem.h"
#include "catalog/pg_aggregate.h"
#include "datatype/timestamp.h"
#include "mysql_fdw.h"
#include "nodes/nodeFuncs.h"
#include "nodes/plannodes.h"
#include "optimizer/clauses.h"
#include "optimizer/prep.h"
#if PG_VERSION_NUM < 120000
#include "optimizer/var.h"
#else
#include "optimizer/optimizer.h"
#endif
#include "optimizer/tlist.h"
#include "parser/parsetree.h"
#include "pgtime.h"
#include "utils/builtins.h"
#include "utils/lsyscache.h"
#include "utils/syscache.h"
#include "utils/timestamp.h"
#include "utils/typcache.h"

/* Return true if integer type */
#define IS_INTEGER_TYPE(typid) ((typid == INT2OID) || (typid == INT4OID) || (typid == INT8OID))

static bool mysql_contain_functions_walker(Node *node, void *context);

/*
 * Global context for foreign_expr_walker's search of an expression tree.
 */
typedef struct foreign_glob_cxt
{
	PlannerInfo *root;			/* global planner state */
	RelOptInfo *foreignrel;		/* the foreign relation we are planning for */
	Relids		relids;			/* relids of base relations in the underlying
								 * scan */
} foreign_glob_cxt;

/*
 * Local (per-tree-level) context for foreign_expr_walker's search.
 * This is concerned with identifying collations used in the expression.
 */
typedef enum
{
	FDW_COLLATE_NONE,			/* expression is of a noncollatable type */
	FDW_COLLATE_SAFE,			/* collation derives from a foreign Var */
	FDW_COLLATE_UNSAFE			/* collation derives from something else */
} FDWCollateState;

typedef struct foreign_loc_cxt
{
	Oid			collation;		/* OID of current collation, if any */
	FDWCollateState state;		/* state of current collation choice */
	bool		can_skip_cast;	/* outer function can skip numeric cast */
	bool		op_flag;		/* operator can be pushed down or not */
	bool		can_pushdown_function;	/* true if query contains function
										 * which can pushed down to remote
										 * server */
	bool		can_use_outercast;	/* true if inner function accept outer
									 * cast */
} foreign_loc_cxt;

/*
 * Context for deparseExpr
 */
typedef struct deparse_expr_cxt
{
	PlannerInfo *root;			/* global planner state */
	RelOptInfo *foreignrel;		/* the foreign relation we are planning for */
	RelOptInfo *scanrel;		/* the underlying scan relation. Same as
								 * foreignrel, when that represents a join or
								 * a base relation. */
	StringInfo	buf;			/* output buffer to append to */
	List	  **params_list;	/* exprs that will become remote Params */
	bool		can_skip_cast;	/* outer function can skip numeric cast
								 * function */
	bool		can_convert_time;	/* time interval need to be converted to
									 * second */
	bool		is_not_distinct_op; /* check operator is IS NOT DISTINCT or IS
									 * DISTINCT  */
	bool		is_not_add_array;	/* check if function has variadic argument
									 * so will not add ARRAY[] */
	bool		can_convert_unit_arg;	/* time interval need to be converted
										 * to Unit Arguments of Mysql. */
	bool		can_skip_convert_unit_arg;	/* outer function can skip time
											 * interval cast function */
	Oid			return_type;	/* return type Oid of outer cast function */
	FuncExpr   *json_table_expr;	/* for json_table function */
} deparse_expr_cxt;

typedef struct pull_func_clause_context
{
	List	   *funclist;
}			pull_func_clause_context;

#define REL_ALIAS_PREFIX	"r"
/* Handy macro to add relation name qualification */
#define ADD_REL_QUALIFIER(buf, varno)	\
		appendStringInfo((buf), "%s%d.", REL_ALIAS_PREFIX, (varno))
#define SUBQUERY_REL_ALIAS_PREFIX	"s"
#define SUBQUERY_COL_ALIAS_PREFIX	"c"

/*
 * Functions to construct string representation of a node tree.
 */
static void deparseExpr(Expr *expr, deparse_expr_cxt *context);
static void mysql_deparse_from_expr(List *quals, deparse_expr_cxt *context);
static void mysql_deparse_explicit_target_list(List *tlist,
											   bool is_returning,
											   List **retrieved_attrs,
											   deparse_expr_cxt *context);
static void mysql_deparse_select_sql(List *tlist, bool is_subquery, List **retrieved_attrs,
									 deparse_expr_cxt *context);
static void mysql_deparse_subquery_target_list(deparse_expr_cxt *context);
static void mysql_deparse_locking_clause(deparse_expr_cxt *context);
static void mysql_deparse_from_expr_for_rel(StringInfo buf, PlannerInfo *root,
											RelOptInfo *foreignrel, bool use_alias,
											Index ignore_rel, List **ignore_conds,
											List **params_list);
static void mysql_deparse_range_tbl_ref(StringInfo buf, PlannerInfo *root,
										RelOptInfo *foreignrel, bool make_subquery,
										Index ignore_rel, List **ignore_conds, List **params_list);
static void mysql_append_conditions(List *exprs, deparse_expr_cxt *context);
static void mysql_deparse_var(Var *node, deparse_expr_cxt *context);
static void mysql_deparse_const(Const *node, deparse_expr_cxt *context);
static void mysql_deparse_param(Param *node, deparse_expr_cxt *context);
#if PG_VERSION_NUM < 120000
static void mysql_deparse_array_ref(ArrayRef * node, deparse_expr_cxt *context);
#else
static void mysql_deparse_subscripting_ref(SubscriptingRef *node,
										   deparse_expr_cxt *context);
#endif
static void mysql_deparse_func_expr(FuncExpr *node, deparse_expr_cxt *context);
static void mysql_deparse_op_expr(OpExpr *node, deparse_expr_cxt *context);
static void mysql_deparse_operator_name(StringInfo buf,
										Form_pg_operator opform);
static void mysql_deparse_distinct_expr(DistinctExpr *node,
										deparse_expr_cxt *context);
static void mysql_deparse_scalar_array_op_expr(ScalarArrayOpExpr *node,
											   deparse_expr_cxt *context);
static void mysql_deparse_relabel_type(RelabelType *node,
									   deparse_expr_cxt *context);
static void mysql_deparse_bool_expr(BoolExpr *node, deparse_expr_cxt *context);
static void mysql_deparse_null_test(NullTest *node, deparse_expr_cxt *context);
static void mysql_deparse_aggref(Aggref *node, deparse_expr_cxt *context);
static void mysql_deparse_array_expr(ArrayExpr *node,
									 deparse_expr_cxt *context);
static void mysql_print_remote_param(int paramindex, Oid paramtype,
									 int32 paramtypmod,
									 deparse_expr_cxt *context);
static void mysql_print_remote_placeholder(Oid paramtype, int32 paramtypmod,
										   deparse_expr_cxt *context);
static void mysql_deparse_relation(StringInfo buf, Relation rel);
static void mysql_deparse_target_list(StringInfo buf,
									  RangeTblEntry *rte,
									  Index rtindex,
									  Relation rel,
									  Bitmapset *attrs_used,
									  bool qualify_col,
									  List **retrieved_attrs);
static void mysql_deparse_column_ref(StringInfo buf, int varno, int varattno,
									 RangeTblEntry *rte, bool qualify_col);
static bool mysql_deparse_op_divide(Expr *node, deparse_expr_cxt *context);
static Node *mysql_deparse_sort_group_clause(Index ref, List *tlist, bool force_colno,
											 deparse_expr_cxt *context);
static void mysql_deparse_row_expr(RowExpr *node, deparse_expr_cxt *context);

/*
 * Functions to construct string representation of a specific types.
 */
static void deparse_interval(StringInfo buf, Datum datum);
static void mysql_append_order_by_clause(List *pathkeys, bool has_final_sort,
										 deparse_expr_cxt *context);
static void mysql_append_limit_clause(deparse_expr_cxt *context);
static void mysql_append_group_by_clause(List *tlist, deparse_expr_cxt *context);
static void mysql_append_function_name(Oid funcid, deparse_expr_cxt *context);
static void mysql_append_time_unit(Const *node, deparse_expr_cxt *context);
static void mysql_append_agg_order_by(List *orderList, List *targetList, deparse_expr_cxt *context);

/*
 * Helper functions
 */
static bool mysql_is_subquery_var(Var *node, RelOptInfo *foreignrel,
								  int *relno, int *colno);
static void mysql_get_relation_column_alias_ids(Var *node, RelOptInfo *foreignrel,
												int *relno, int *colno);
static bool exist_in_function_list(char *funcname, const char **funclist);
static bool mysql_is_unique_func(Oid funcid, char *in);
static bool mysql_is_supported_builtin_func(Oid funcid, char *in);
static bool starts_with(const char *pre, const char *str);
static char *mysql_deparse_type_name(Oid type_oid, int32 typemod);
static void mysql_deconstruct_constant_array(Const *node, bool **elem_nulls,
											 Datum **elem_values, Oid *elmtype, int *num_elems);
static bool mysql_pull_func_clause_walker(Node *node, pull_func_clause_context * context);
static void mysql_deparse_const_array(Const *node, deparse_expr_cxt *context);
static void mysql_deparse_target_json_table_func(FuncExpr *node, deparse_expr_cxt *context);
static void mysql_append_json_table_func(FuncExpr *node, deparse_expr_cxt *context);
static void mysql_append_json_value_func(FuncExpr *node, deparse_expr_cxt *context);
static void mysql_append_memberof_func(FuncExpr *node, deparse_expr_cxt *context);
static void mysql_append_convert_function(FuncExpr *node, deparse_expr_cxt *context);
static void mysql_deparse_numeric_cast(FuncExpr *node, deparse_expr_cxt *context);
static void mysql_deparse_string_cast(FuncExpr *node, deparse_expr_cxt *context, char *proname);
static void mysql_deparse_datetime_cast(FuncExpr *node, deparse_expr_cxt *context, char *proname);
static void mysql_deparse_func_expr_match_against(FuncExpr *node, deparse_expr_cxt *context,
												  StringInfo buf, char *proname);
static void mysql_deparse_func_expr_position(FuncExpr *node, deparse_expr_cxt *context,
											 StringInfo buf, char *proname);
static void mysql_deparse_func_expr_trim(FuncExpr *node, deparse_expr_cxt *context,
										 StringInfo buf, char *proname, char *origin_function);
static void mysql_deparse_func_expr_weight_string(FuncExpr *node, deparse_expr_cxt *context,
												  StringInfo buf, char *proname);

static void interval2unit(Datum datum, char **expr, char **unit);

/*
 * Local variables.
 */
static char *cur_opname = NULL;

/*
 * MysqlUniqueNumericFunction
 * List of unique numeric functions for MySQL
 */
static const char *MysqlUniqueNumericFunction[] = {
	"atan",
	"conv",
	"crc32",
	"log2",
	"match_against",
	"mysql_pi",
	"rand",
	"truncate",
NULL};

/*
 * MysqlUniqueJsonFunction
 * List of unique json functions for MySQL
 */
static const char *MysqlUniqueJsonFunction[] = {
	"json_array_append",
	"json_array_insert",
	"json_contains",
	"json_contains_path",
	"json_depth",
	"json_extract",
	"json_insert",
	"json_keys",
	"json_length",
	"json_merge",
	"json_merge_patch",
	"json_merge_preserve",
	"json_overlaps",
	"json_pretty",
	"json_quote",
	"json_remove",
	"json_replace",
	"json_schema_valid",
	"json_schema_validation_report",
	"json_search",
	"json_set",
	"json_storage_free",
	"json_storage_size",
	"mysql_json_table",
	"json_type",
	"json_unquote",
	"json_valid",
	"json_value",
	"member_of",
NULL};

/*
 * MysqlUniqueStringFunction
 * List of unique string function for MySQL
 */
static const char *MysqlUniqueStringFunction[] = {
	"bin",
	"mysql_char",
	"elt",
	"export_set",
	"field",
	"find_in_set",
	"format",
	"from_base64",
	"hex",
	"insert",
	"instr",
	"lcase",
	"locate",
	"make_set",
	"mid",
	"oct",
	"ord",
	"quote",
	"regexp_instr",
	"regexp_like",
	"regexp_replace",
	"regexp_substr",
	"space",
	"strcmp",
	"substring_index",
	"to_base64",
	"ucase",
	"unhex",
	"weight_string",
NULL};

/*
 * MysqlUniqueDateTimeFunction
 * List of unique Date/Time function for MySQL
 */
static const char *MysqlUniqueDateTimeFunction[] = {
	"adddate",
	"addtime",
	"convert_tz",
	"curdate",
	"mysql_current_date",
	"curtime",
	"mysql_current_time",
	"mysql_current_timestamp",
	"date_add",
	"date_format",
	"date_sub",
	"datediff",
	"day",
	"dayname",
	"dayofmonth",
	"dayofweek",
	"dayofyear",
	"mysql_extract",
	"from_days",
	"from_unixtime",
	"get_format",
	"hour",
	"last_day",
	"mysql_localtime",
	"mysql_localtimestamp",
	"makedate",
	"maketime",
	"microsecond",
	"minute",
	"month",
	"monthname",
	"mysql_now",
	"period_add",
	"period_diff",
	"quarter",
	"sec_to_time",
	"second",
	"str_to_date",
	"subdate",
	"subtime",
	"sysdate",
	"mysql_time",
	"time_format",
	"time_to_sec",
	"timediff",
	"mysql_timestamp",
	"timestampadd",
	"timestampdiff",
	"to_days",
	"to_seconds",
	"unix_timestamp",
	"utc_date",
	"utc_time",
	"utc_timestamp",
	"week",
	"weekday",
	"weekofyear",
	"year",
	"yearweek",
NULL};

/*
 * MysqlSupportedBuiltinDateTimeFunction
 * List of supported date time function for MySQL
 */
static const char *MysqlSupportedBuiltinDateTimeFunction[] = {
	"date",
NULL};

/*
 * MysqlSupportedBuiltinNumericFunction
 * List of supported builtin numeric functions for MySQL
 */
static const char *MysqlSupportedBuiltinNumericFunction[] = {
	"abs",
	"acos",
	"asin",
	"atan",
	"atan2",
	"ceil",
	"ceiling",
	"cos",
	"cot",
	"degrees",
	"div",
	"exp",
	"floor",
	"ln",
	"log",
	"log10",
	"mod",
	"pow",
	"power",
	"radians",
	"round",
	"sign",
	"sin",
	"sqrt",
	"tan",
NULL};

/*
 * MysqlSupportedBuiltinJsonFunction
 * List of supported builtin json functions for MySQL
 */
static const char *MysqlSupportedBuiltinJsonFunction[] = {
	"json_build_array",
	"json_build_object",
NULL};

/*
 * MysqlSupportedBuiltinAggFunction
 * List of supported builtin aggregate functions for MySQL
 */
static const char *MysqlSupportedBuiltinAggFunction[] = {
	/* aggregate functions */
	"sum",
	"avg",
	"max",
	"min",
	"bit_and",
	"bit_or",
	"stddev",
	"stddev_pop",
	"stddev_samp",
	"var_pop",
	"var_samp",
	"variance",
	"count",
NULL};

/*
 * MysqlUniqueAggFunction
 * List of unique aggregate function for MySQL
 */
static const char *MysqlUniqueAggFunction[] = {
	"bit_xor",
	"group_concat",
	"json_arrayagg",
	"json_objectagg",
	"std",
NULL};

/*
 * MysqlSupportedBuiltinStringFunction
 * List of supported builtin string functions for MySQL
 */
static const char *MysqlSupportedBuiltinStringFunction[] = {
	"ascii",
	"bit_length",
	"btrim",
	"char_length",
	"character_length",
	"concat",
	"concat_ws",
	"left",
	"length",
	"lower",
	"lpad",
	"ltrim",
	"octet_length",
	"repeat",
	"replace",
	"reverse",
	"right",
	"rpad",
	"rtrim",
	"position",
	"regexp_replace",
	"substr",
	"substring",
	"trim",
	"upper",
NULL};

/*
 * MysqlUniqueCastFunction
 * List of supported unique cast functions for MySQL
 */
static const char *MysqlUniqueCastFunction[] = {
	"convert",
NULL};

/*
 * CastFunction
 * List of PostgreSQL cast functions, these functions can be skip cast.
 */
static const char *CastFunction[] = {
	"float4",
	"float8",
	"int2",
	"int4",
	"int8",
	"numeric",
	"double precision",
	/* string cast */
	"bpchar",
	"varchar",
	/* date time cast */
	"time",
	"timetz",
	"timestamp",
	"timestamptz",
	"interval",
	/* json cast */
	"json",
	"jsonb",
	/* binary cast */
	"bytea",
NULL};

/*
 * pull_func_clause_walker
 *
 * Recursively search for functions within a clause.
 */
static bool
mysql_pull_func_clause_walker(Node *node, pull_func_clause_context * context)
{
	if (node == NULL)
		return false;
	if (IsA(node, FuncExpr))
	{
		context->funclist = lappend(context->funclist, node);
		return false;
	}

	return expression_tree_walker(node, mysql_pull_func_clause_walker,
								  (void *) context);
}

/*
 * pull_func_clause
 *
 * Pull out function from a clause and then add to target list
 */
List *
mysql_pull_func_clause(Node *node)
{
	pull_func_clause_context context;

	context.funclist = NIL;

	mysql_pull_func_clause_walker(node, &context);

	return context.funclist;
}

/*
 * Append remote name of specified foreign table to buf.  Use value of
 * table_name FDW option (if any) instead of relation's name.  Similarly,
 * schema_name FDW option overrides schema name.
 */
static void
mysql_deparse_relation(StringInfo buf, Relation rel)
{
	ForeignTable *table;
	const char *nspname = NULL;
	const char *relname = NULL;
	ListCell   *lc;

	/* Obtain additional catalog information. */
	table = GetForeignTable(RelationGetRelid(rel));

	/*
	 * Use value of FDW options if any, instead of the name of object itself.
	 */
	foreach(lc, table->options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "dbname") == 0)
			nspname = defGetString(def);
		else if (strcmp(def->defname, "table_name") == 0)
			relname = defGetString(def);
	}

	/*
	 * Note: we could skip printing the schema name if it's pg_catalog, but
	 * that doesn't seem worth the trouble.
	 */
	if (nspname == NULL)
		nspname = get_namespace_name(RelationGetNamespace(rel));
	if (relname == NULL)
		relname = RelationGetRelationName(rel);

	appendStringInfo(buf, "%s.%s", mysql_quote_identifier(nspname, '`'),
					 mysql_quote_identifier(relname, '`'));
}

char *
mysql_quote_identifier(const char *str, char quotechar)
{
	char	   *result = palloc(strlen(str) * 2 + 3);
	char	   *res = result;

	*res++ = quotechar;
	while (*str)
	{
		if (*str == quotechar)
			*res++ = *str;
		*res++ = *str;
		str++;
	}
	*res++ = quotechar;
	*res++ = '\0';

	return result;
}

/*
 * Deparse remote INSERT statement
 *
 * The statement text is appended to buf, and we also create an integer List
 * of the columns being retrieved by RETURNING (if any), which is returned
 * to *retrieved_attrs.
 */
#if PG_VERSION_NUM >= 140000
/*
 * This also stores end position of the VALUES clause, so that we can rebuild
 * an INSERT for a batch of rows later.
 */
void
mysql_deparse_insert(StringInfo buf, RangeTblEntry *rte, Index rtindex,
					 Relation rel, List *targetAttrs, bool doNothing,
					 int *values_end_len)
#else
void
mysql_deparse_insert(StringInfo buf, RangeTblEntry *rte, Index rtindex,
					 Relation rel, List *targetAttrs, bool doNothing)
#endif
{
#if PG_VERSION_NUM >= 140000
	TupleDesc	tupdesc = RelationGetDescr(rel);
#endif
	ListCell   *lc;

	appendStringInfo(buf, "INSERT %sINTO ", doNothing ? "IGNORE " : "");
	mysql_deparse_relation(buf, rel);

	if (targetAttrs)
	{
		AttrNumber	pindex;
		bool		first;

		appendStringInfoChar(buf, '(');

		first = true;
		foreach(lc, targetAttrs)
		{
			int			attnum = lfirst_int(lc);

			if (!first)
				appendStringInfoString(buf, ", ");
			first = false;

			mysql_deparse_column_ref(buf, rtindex, attnum, rte, false);
		}

		appendStringInfoString(buf, ") VALUES (");

		pindex = 1;
		first = true;
		foreach(lc, targetAttrs)
		{
#if PG_VERSION_NUM >= 140000
			int			attnum = lfirst_int(lc);
			Form_pg_attribute attr = TupleDescAttr(tupdesc, attnum - 1);
#endif

			if (!first)
				appendStringInfoString(buf, ", ");
			first = false;
#if PG_VERSION_NUM >= 140000
			if (attr->attgenerated)
			{
				appendStringInfoString(buf, "DEFAULT");
				continue;
			}
#endif
			appendStringInfo(buf, "?");
			pindex++;
		}

		appendStringInfoChar(buf, ')');
	}
	else
		appendStringInfoString(buf, " DEFAULT VALUES");
#if PG_VERSION_NUM >= 140000
	*values_end_len = buf->len;
#endif
}

#if PG_VERSION_NUM >= 140000
/*
 * rebuild remote INSERT statement
 *
 * Provided a number of rows in a batch, builds INSERT statement with the
 * right number of parameters.
 */
void
mysql_rebuild_insert_sql(StringInfo buf, Relation rel,
						 char *orig_query, List *target_attrs,
						 int values_end_len, int num_params,
						 int num_rows)
{
	TupleDesc	tupdesc = RelationGetDescr(rel);
	int			i;
	int			pindex;
	bool		first;
	ListCell   *lc;

	/* Make sure the values_end_len is sensible */
	Assert((values_end_len > 0) && (values_end_len <= strlen(orig_query)));

	/* Copy up to the end of the first record from the original query */
	appendBinaryStringInfo(buf, orig_query, values_end_len);

	/*
	 * Add records to VALUES clause (we already have parameters for the first
	 * row, so start at the right offset).
	 */
	pindex = num_params + 1;
	for (i = 0; i < num_rows; i++)
	{
		appendStringInfoString(buf, ", (");

		first = true;
		foreach(lc, target_attrs)
		{
#if PG_VERSION_NUM >= 140000
			int			attnum = lfirst_int(lc);
			Form_pg_attribute attr = TupleDescAttr(tupdesc, attnum - 1);
#endif

			if (!first)
				appendStringInfoString(buf, ", ");
			first = false;

#if PG_VERSION_NUM >= 140000
			if (attr->attgenerated)
			{
				appendStringInfoString(buf, "DEFAULT");
				continue;
			}
#endif
			appendStringInfo(buf, "?");
			pindex++;
		}

		appendStringInfoChar(buf, ')');
	}

	/* Copy stuff after VALUES clause from the original query */
	appendStringInfoString(buf, orig_query + values_end_len);
}
#endif

void
mysql_deparse_analyze(StringInfo sql, char *dbname, char *relname)
{
	appendStringInfo(sql, "SELECT");
	appendStringInfo(sql, " round(((data_length + index_length)), 2)");
	appendStringInfo(sql, " FROM information_schema.TABLES");
	appendStringInfo(sql, " WHERE table_schema = '%s' AND table_name = '%s'",
					 dbname, relname);
}

/*
 * Emit a target list that retrieves the columns specified in attrs_used.
 * This is used for both SELECT and RETURNING targetlists; the is_returning
 * parameter is true only for a RETURNING targetlist.
 *
 * The tlist text is appended to buf, and we also create an integer List
 * of the columns being retrieved, which is returned to *retrieved_attrs.
 *
 * If qualify_col is true, add relation alias before the column name.
 */

#if PG_VERSION_NUM >= 140000
/*
 * Construct a simple "TRUNCATE rel" statement
 */
void
mysql_deparse_truncate_sql(StringInfo buf,
						   List *rels)
{
	ListCell   *cell;

	appendStringInfoString(buf, "TRUNCATE ");

	foreach(cell, rels)
	{
		Relation	rel = lfirst(cell);

		if (cell != list_head(rels))
			appendStringInfoString(buf, ", ");

		mysql_deparse_relation(buf, rel);
	}
}
#endif

static void
mysql_deparse_target_list(StringInfo buf,
						  RangeTblEntry *rte,
						  Index rtindex,
						  Relation rel,
						  Bitmapset *attrs_used,
						  bool qualify_col,
						  List **retrieved_attrs)
{
	TupleDesc	tupdesc = RelationGetDescr(rel);
	bool		have_wholerow;
	bool		first;
	int			i;

	*retrieved_attrs = NIL;

	/* If there's a whole-row reference, we'll need all the columns. */
	have_wholerow = bms_is_member(0 - FirstLowInvalidHeapAttributeNumber,
								  attrs_used);

	first = true;
	for (i = 1; i <= tupdesc->natts; i++)
	{
		Form_pg_attribute attr = TupleDescAttr(tupdesc, i - 1);

		/* Ignore dropped attributes. */
		if (attr->attisdropped)
			continue;

		if (have_wholerow ||
			bms_is_member(i - FirstLowInvalidHeapAttributeNumber,
						  attrs_used))
		{
			if (!first)
				appendStringInfoString(buf, ", ");

			first = false;

			mysql_deparse_column_ref(buf, rtindex, i, rte, qualify_col);

			*retrieved_attrs = lappend_int(*retrieved_attrs, i);
		}
	}
	/* Don't generate bad syntax if no undropped columns */
	if (first)
		appendStringInfoString(buf, "NULL");
}

/*
 * Deparse the appropriate locking clause (FOR UPDATE or FOR SHARE) for a
 * given relation (context->scanrel).
 */
static void
mysql_deparse_locking_clause(deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	PlannerInfo *root = context->root;
	RelOptInfo *rel = context->scanrel;
	MySQLFdwRelationInfo *fpinfo = (MySQLFdwRelationInfo *) rel->fdw_private;
	int			relid = -1;

	while ((relid = bms_next_member(rel->relids, relid)) >= 0)
	{
		/*
		 * Ignore relation if it appears in a lower subquery.  Locking clause
		 * for such a relation is included in the subquery if necessary.
		 */
		if (bms_is_member(relid, fpinfo->lower_subquery_rels))
			continue;

		/*
		 * Add FOR UPDATE/SHARE if appropriate.  We apply locking during the
		 * initial row fetch, rather than later on as is done for local
		 * tables. The extra roundtrips involved in trying to duplicate the
		 * local semantics exactly don't seem worthwhile (see also comments
		 * for RowMarkType).
		 *
		 * Note: because we actually run the query as a cursor, this assumes
		 * that DECLARE CURSOR ... FOR UPDATE is supported, which it isn't
		 * before 8.3.
		 */
#if PG_VERSION_NUM >= 140000
		if (bms_is_member(relid, root->all_result_relids) &&
#else
		if (relid == root->parse->resultRelation &&
#endif
			(root->parse->commandType == CMD_UPDATE ||
			 root->parse->commandType == CMD_DELETE))
		{
			/* Relation is UPDATE/DELETE target, so use FOR UPDATE */
			appendStringInfoString(buf, " FOR UPDATE");

			/* Add the relation alias if we are here for a join relation */
			if (IS_JOIN_REL(rel))
				appendStringInfo(buf, " OF %s%d", REL_ALIAS_PREFIX, relid);
		}
		else
		{
			PlanRowMark *rc = get_plan_rowmark(root->rowMarks, relid);

			if (rc)
			{
				/*
				 * Relation is specified as a FOR UPDATE/SHARE target, so
				 * handle that.  (But we could also see LCS_NONE, meaning this
				 * isn't a target relation after all.)
				 *
				 * For now, just ignore any [NO] KEY specification, since (a)
				 * it's not clear what that means for a remote table that we
				 * don't have complete information about, and (b) it wouldn't
				 * work anyway on older remote servers.  Likewise, we don't
				 * worry about NOWAIT.
				 */
				switch (rc->strength)
				{
					case LCS_NONE:
						/* No locking needed */
						break;
					case LCS_FORKEYSHARE:
					case LCS_FORSHARE:
						appendStringInfoString(buf, " FOR SHARE");
						break;
					case LCS_FORNOKEYUPDATE:
					case LCS_FORUPDATE:
						appendStringInfoString(buf, " FOR UPDATE");
						break;
				}

				/* Add the relation alias if we are here for a join relation */
				if (bms_membership(rel->relids) == BMS_MULTIPLE &&
					rc->strength != LCS_NONE)
					appendStringInfo(buf, " OF %s%d", REL_ALIAS_PREFIX, relid);
			}
		}
	}
}

/*
 * Deparse WHERE clauses in given list of RestrictInfos and append them to buf.
 *
 * baserel is the foreign table we're planning for.
 *
 * If no WHERE clause already exists in the buffer, is_first should be true.
 *
 * If params is not NULL, it receives a list of Params and other-relation Vars
 * used in the clauses; these values must be transmitted to the remote server
 * as parameter values.
 *
 * If params is NULL, we're generating the query for EXPLAIN purposes,
 * so Params and other-relation Vars should be replaced by dummy values.
 */
void
mysql_append_where_clause(StringInfo buf, PlannerInfo *root,
						  RelOptInfo *baserel, List *exprs, bool is_first,
						  List **params)
{
	deparse_expr_cxt context;
	ListCell   *lc;

	if (params)
		*params = NIL;			/* initialize result list to empty */

	/* Set up context struct for recursion */
	context.root = root;
	context.foreignrel = baserel;
	context.buf = buf;
	context.params_list = params;
	context.can_skip_cast = false;
	context.can_convert_time = false;
	context.can_convert_unit_arg = false;
	context.is_not_add_array = false;
	context.json_table_expr = NULL;
	context.can_skip_convert_unit_arg = false;

	foreach(lc, exprs)
	{
		RestrictInfo *ri = (RestrictInfo *) lfirst(lc);

		/* Connect expressions with "AND" and parenthesize each condition. */
		if (is_first)
			appendStringInfoString(buf, " WHERE ");
		else
			appendStringInfoString(buf, " AND ");

		appendStringInfoChar(buf, '(');
		deparseExpr(ri->clause, &context);
		appendStringInfoChar(buf, ')');

		is_first = false;
	}
}

/*
 * Construct name to use for given column, and emit it into buf.  If it has a
 * column_name FDW option, use that instead of attribute name.
 */
static void
mysql_deparse_column_ref(StringInfo buf, int varno, int varattno,
						 RangeTblEntry *rte, bool qualify_col)
{
	/* varno must not be any of OUTER_VAR, INNER_VAR and INDEX_VAR. */
	Assert(!IS_SPECIAL_VARNO(varno));

	/* We not support fetching any system attributes from remote side */
	if (varattno < 0)
	{
		/*
		 * All other system attributes are fetched as 0, except for table OID
		 * and ctid, table OID is fetched as the local table OID, ctid is
		 * fectch as invalid value. However, we must be careful; the table
		 * could be beneath an outer join, in which case it must go to NULL
		 * whenever the rest of the row does.
		 */
		char		fetchval[32];

		if (varattno == TableOidAttributeNumber)
		{
			/*
			 * table OID is fetched as the local table OID
			 */
			pg_snprintf(fetchval, sizeof(fetchval), "%u", rte->relid);
		}
		else if (varattno == SelfItemPointerAttributeNumber)
		{
			/*
			 * ctid is fetched as '(4294967295,0)' ~ (0xFFFFFFFF, 0) (invalid
			 * value), which is default value of tupleSlot->tts_tid after run
			 * ExecClearTuple.
			 */
			pg_snprintf(fetchval, sizeof(fetchval), "'(%u,%u)'",
						InvalidBlockNumber,
						InvalidOffsetNumber);
		}
		else
		{
			/* other system attributes are fetched as 0 */
			pg_snprintf(fetchval, sizeof(fetchval), "%u", 0);
		}

		appendStringInfo(buf, "%s", fetchval);
	}
	else if (varattno == 0)
	{
		/* Whole row reference */
		Relation	rel;
		Bitmapset  *attrs_used;

		/* Required only to be passed down to deparseTargetList(). */
		List	   *retrieved_attrs;

		/*
		 * The lock on the relation will be held by upper callers, so it's
		 * fine to open it with no lock here.
		 */
		rel = table_open(rte->relid, NoLock);

		/*
		 * The local name of the foreign table can not be recognized by the
		 * foreign server and the table it references on foreign server might
		 * have different column ordering or different columns than those
		 * declared locally. Hence we have to deparse whole-row reference as
		 * ROW(columns referenced locally). Construct this by deparsing a
		 * "whole row" attribute.
		 */
		attrs_used = bms_add_member(NULL,
									0 - FirstLowInvalidHeapAttributeNumber);

		/*
		 * In case the whole-row reference is under an outer join then it has
		 * to go NULL whenever the rest of the row goes NULL. Deparsing a join
		 * query would always involve multiple relations, thus qualify_col
		 * would be true.
		 */

		mysql_deparse_target_list(buf, rte, varno, rel, attrs_used, qualify_col,
								  &retrieved_attrs);

		table_close(rel, NoLock);
		bms_free(attrs_used);
	}
	else
	{
		char	   *colname = NULL;
		List	   *options;
		ListCell   *lc;

		/* varno must not be any of OUTER_VAR, INNER_VAR and INDEX_VAR. */
		Assert(!IS_SPECIAL_VARNO(varno));

		/*
		 * If it's a column of a foreign table, and it has the column_name FDW
		 * option, use that value.
		 */
		options = GetForeignColumnOptions(rte->relid, varattno);
		foreach(lc, options)
		{
			DefElem    *def = (DefElem *) lfirst(lc);

			if (strcmp(def->defname, "column_name") == 0)
			{
				colname = defGetString(def);
				break;
			}
		}

		/*
		 * If it's a column of a regular table or it doesn't have column_name
		 * FDW option, use attribute name.
		 */
		if (colname == NULL)
#if PG_VERSION_NUM >= 110000
			colname = get_attname(rte->relid, varattno, false);
#else
			colname = get_relid_attribute_name(rte->relid, varattno);
#endif
		if (qualify_col)
			ADD_REL_QUALIFIER(buf, varno);

		appendStringInfoString(buf, mysql_quote_identifier(colname, '`'));
	}
}

/*
 * Append a SQL string literal representing "val" to buf.
 */
static void
mysql_deparse_string_literal(StringInfo buf, const char *val)
{
	const char *valptr;

	appendStringInfoChar(buf, '\'');

	for (valptr = val; *valptr; valptr++)
	{
		char		ch = *valptr;

		if (SQL_STR_DOUBLE(ch, true))
			appendStringInfoChar(buf, ch);
		appendStringInfoChar(buf, ch);
	}

	appendStringInfoChar(buf, '\'');
}

/*
 * Append a SQL const array to buf.
 * Support for text, json and path_value
 */
static void
mysql_deparse_const_array(Const *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	char	   *extval;
	int			num_elems = 0;
	Datum	   *elem_values;
	bool	   *elem_nulls;
	Oid			elmtype;
	int			i;
	Oid			outputFunctionId;
	bool		typeVarLength;
	char	   *type_name = mysql_deparse_type_name(node->consttype, node->consttypmod);

	mysql_deconstruct_constant_array(node, &elem_nulls, &elem_values, &elmtype, &num_elems);
	getTypeOutputInfo(elmtype, &outputFunctionId, &typeVarLength);

	for (i = 0; i < num_elems; i++)
	{
		Assert(!elem_nulls[i]);

		if (i > 0)
			appendStringInfoString(buf, ", ");

		/* Just add value for path_value[] type */
		if (strstr(type_name, "json[]") != NULL)
			/* Mysql not cast text to json automatically */
			appendStringInfoString(buf, "CAST(\'");
		else if (strstr(type_name, "text[]") != NULL)
			/* Add single quote for text value */
			appendStringInfoChar(buf, '\'');

		extval = OidOutputFunctionCall(outputFunctionId, elem_values[i]);
		appendStringInfo(buf, "%s", extval);

		if (strstr(type_name, "json[]") != NULL)
			appendStringInfoString(buf, "\' AS JSON)");
		else if (strstr(type_name, "text[]") != NULL)
			appendStringInfoChar(buf, '\'');
	}

	pfree(elem_values);
	pfree(elem_nulls);
}

/*
 * Deparse given expression into context->buf.
 *
 * This function must support all the same node types that foreign_expr_walker
 * accepts.
 *
 * Note: unlike ruleutils.c, we just use a simple hard-wired parenthesization
 * scheme: anything more complex than a Var, Const, function call or cast
 * should be self-parenthesized.
 */
static void
deparseExpr(Expr *node, deparse_expr_cxt *context)
{
	bool		outer_can_skip_cast = context->can_skip_cast;
	bool		outer_is_not_distinct_op = context->is_not_distinct_op;

	if (node == NULL)
		return;

	context->can_skip_cast = false;

	switch (nodeTag(node))
	{
		case T_Var:
			mysql_deparse_var((Var *) node, context);
			break;
		case T_Const:
			mysql_deparse_const((Const *) node, context);
			break;
		case T_Param:
			mysql_deparse_param((Param *) node, context);
			break;
#if PG_VERSION_NUM < 120000
		case T_ArrayRef:
			mysql_deparse_array_ref((ArrayRef *) node, context);
#else
		case T_SubscriptingRef:
			mysql_deparse_subscripting_ref((SubscriptingRef *) node, context);
#endif
			break;
		case T_FuncExpr:
			context->can_skip_cast = outer_can_skip_cast;
			mysql_deparse_func_expr((FuncExpr *) node, context);
			break;
		case T_OpExpr:
			context->can_skip_cast = outer_can_skip_cast;
			mysql_deparse_op_expr((OpExpr *) node, context);
			break;
		case T_DistinctExpr:
			context->is_not_distinct_op = outer_is_not_distinct_op;
			mysql_deparse_distinct_expr((DistinctExpr *) node, context);
			break;
		case T_ScalarArrayOpExpr:
			mysql_deparse_scalar_array_op_expr((ScalarArrayOpExpr *) node,
											   context);
			break;
		case T_RelabelType:
			mysql_deparse_relabel_type((RelabelType *) node, context);
			break;
		case T_BoolExpr:
			mysql_deparse_bool_expr((BoolExpr *) node, context);
			break;
		case T_NullTest:
			mysql_deparse_null_test((NullTest *) node, context);
			break;
		case T_Aggref:
			mysql_deparse_aggref((Aggref *) node, context);
			break;
		case T_ArrayExpr:
			mysql_deparse_array_expr((ArrayExpr *) node, context);
			break;
		case T_RowExpr:
			mysql_deparse_row_expr((RowExpr *) node, context);
			break;
		case T_CoerceViaIO:
			/* skip outer cast */
			deparseExpr(((CoerceViaIO *) node)->arg, context);
			break;
		default:
			elog(ERROR, "unsupported expression type for deparse: %d",
				 (int) nodeTag(node));
			break;
	}
}

/*
 * Construct a FROM clause and, if needed, a WHERE clause, and append those to
 * "buf".
 *
 * quals is the list of clauses to be included in the WHERE clause.
 * (These may or may not include RestrictInfo decoration.)
 */
static void
mysql_deparse_from_expr(List *quals, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	RelOptInfo *scanrel = context->scanrel;

	/* For upper relations, scanrel must be either a joinrel or a baserel */
	Assert(!IS_UPPER_REL(context->foreignrel) ||
		   IS_JOIN_REL(scanrel) || IS_SIMPLE_REL(scanrel));

	/* Construct FROM clause */
	appendStringInfoString(buf, " FROM ");
	mysql_deparse_from_expr_for_rel(buf, context->root, scanrel,
									(bms_membership(scanrel->relids) == BMS_MULTIPLE),
									(Index) 0, NULL, context->params_list);

	/* construct JSON_TABLE if needed */
	if (context->json_table_expr != NULL && IS_SIMPLE_REL(scanrel))
		mysql_append_json_table_func(context->json_table_expr, context);

	/* Construct WHERE clause */
	if (quals != NIL)
	{
		appendStringInfoString(buf, " WHERE ");
		mysql_append_conditions(quals, context);
	}
}

/*
 * Deparse Interval type into MySQL Interval representation.
 */
static void
deparse_interval(StringInfo buf, Datum datum)
{
	struct pg_tm tm;
	fsec_t		fsec;
	bool		is_first = true;

#define append_interval(expr, unit) \
do { \
	if (!is_first) \
		appendStringInfo(buf, " %s ", cur_opname); \
	appendStringInfo(buf, "INTERVAL %d %s", expr, unit); \
	is_first = false; \
} while (0)

	/* Check saved opname. It could be only "+" and "-" */
	Assert(cur_opname);

	if (interval2tm(*DatumGetIntervalP(datum), &tm, &fsec) != 0)
		elog(ERROR, "could not convert interval to tm");

	if (tm.tm_year > 0)
		append_interval(tm.tm_year, "YEAR");

	if (tm.tm_mon > 0)
		append_interval(tm.tm_mon, "MONTH");

	if (tm.tm_mday > 0)
		append_interval(tm.tm_mday, "DAY");

	if (tm.tm_hour > 0)
		append_interval(tm.tm_hour, "HOUR");

	if (tm.tm_min > 0)
		append_interval(tm.tm_min, "MINUTE");

	if (tm.tm_sec > 0)
		append_interval(tm.tm_sec, "SECOND");

	if (fsec > 0)
	{
		if (!is_first)
			appendStringInfo(buf, " %s ", cur_opname);
#ifdef HAVE_INT64_TIMESTAMP
		appendStringInfo(buf, "INTERVAL %d MICROSECOND", fsec);
#else
		appendStringInfo(buf, "INTERVAL %f MICROSECOND", fsec);
#endif
	}
}

/*
 * Deparse remote UPDATE statement
 *
 * The statement text is appended to buf, and we also create an integer List
 * of the columns being retrieved by RETURNING (if any), which is returned
 * to *retrieved_attrs.
 */
void
mysql_deparse_update(StringInfo buf, PlannerInfo *root, Index rtindex,
					 Relation rel, List *targetAttrs, char *attname)
{
#if PG_VERSION_NUM >= 140000
	TupleDesc	tupdesc = RelationGetDescr(rel);
#endif
	AttrNumber	pindex;
	bool		first;
	ListCell   *lc;

	appendStringInfoString(buf, "UPDATE ");
	mysql_deparse_relation(buf, rel);
	appendStringInfoString(buf, " SET ");

	pindex = 2;
	first = true;
	foreach(lc, targetAttrs)
	{
		int			attnum = lfirst_int(lc);
#if PG_VERSION_NUM >= 140000
		Form_pg_attribute attr = TupleDescAttr(tupdesc, attnum - 1);
#endif

		if (attnum == 1)
			continue;

		if (!first)
			appendStringInfoString(buf, ", ");
		first = false;

		mysql_deparse_column_ref(buf, rtindex, attnum, planner_rt_fetch(rtindex, root), false);
#if PG_VERSION_NUM >= 140000
		if (attr->attgenerated)
		{
			appendStringInfoString(buf, " = DEFAULT");
			continue;
		}
#endif
		appendStringInfo(buf, " = ?");
		pindex++;
	}

	appendStringInfo(buf, " WHERE %s = ?", attname);
}


/*
 * deparse remote UPDATE statement
 *
 * 'buf' is the output buffer to append the statement to 'rtindex' is the RT
 * index of the associated target relation 'rel' is the relation descriptor
 * for the target relation 'foreignrel' is the RelOptInfo for the target
 * relation or the join relation containing all base relations in the query
 * 'targetlist' is the tlist of the underlying foreign-scan plan node
 * 'targetAttrs' is the target columns of the UPDATE 'remote_conds' is the
 * qual clauses that must be evaluated remotely '*params_list' is an output
 * list of exprs that will become remote Params '*retrieved_attrs' is an
 * output list of integers of columns being retrieved by RETURNING (if any)
 */
void
mysql_deparse_direct_update_sql(StringInfo buf, PlannerInfo *root,
								Index rtindex, Relation rel,
								RelOptInfo *foreignrel,
								List *targetlist,
								List *targetAttrs,
								List *remote_conds,
								List **params_list,
								List **retrieved_attrs)
{
	deparse_expr_cxt context;
	int			nestlevel;
	bool		first;
#if PG_VERSION_NUM >= 140000
	ListCell   *lc,
			   *lc2;
#else
	ListCell   *lc;
#endif

	/* Set up context struct for recursion */
	context.root = root;
	context.foreignrel = foreignrel;
	context.scanrel = foreignrel;
	context.buf = buf;
	context.params_list = params_list;
	context.can_convert_time = false;
	context.is_not_distinct_op = false;
	context.can_skip_cast = false;
	context.is_not_add_array = false;
	context.json_table_expr = NULL;

	/*
	 * MySQL does not support UPDATE...FROM, must to deparse UPDATE...JOIN.
	 */
	appendStringInfoString(buf, "UPDATE ");
	if (IS_JOIN_REL(foreignrel))
	{
		List	   *ignore_conds = NIL;
		MySQLFdwRelationInfo *fpinfo = (MySQLFdwRelationInfo *) foreignrel->fdw_private;

		mysql_deparse_relation(buf, rel);
		appendStringInfo(buf, " %s%d", REL_ALIAS_PREFIX, rtindex);
		appendStringInfo(buf, " %s JOIN ", mysql_get_jointype_name(fpinfo->jointype));

		mysql_deparse_from_expr_for_rel(buf, root, foreignrel, true, rtindex,
										&ignore_conds, params_list);
		remote_conds = list_concat(remote_conds, ignore_conds);
	}
	else
		mysql_deparse_relation(buf, rel);

	appendStringInfoString(buf, " SET ");

	/* Make sure any constants in the exprs are printed portably */
	nestlevel = mysql_set_transmission_modes();

	first = true;
#if PG_VERSION_NUM >= 140000
	forboth(lc, targetlist, lc2, targetAttrs)
	{
		TargetEntry *tle = lfirst_node(TargetEntry, lc);
		int			attnum = lfirst_int(lc2);

		/* update's new-value expressions shouldn't be resjunk */
		Assert(!tle->resjunk);
#else
	foreach(lc, targetAttrs)
	{
		int			attnum = lfirst_int(lc);
		TargetEntry *tle = get_tle_by_resno(targetlist, attnum);

		if (!tle)
			elog(ERROR, "attribute number %d not found in UPDATE targetlist",
				 attnum);
#endif

		if (!first)
			appendStringInfoString(buf, ", ");
		first = false;

		if (IS_JOIN_REL(foreignrel))
			appendStringInfo(buf, " %s%d.", REL_ALIAS_PREFIX, rtindex);
		mysql_deparse_column_ref(buf, rtindex, attnum, planner_rt_fetch(rtindex, root), false);
		appendStringInfoString(buf, " = ");
		deparseExpr((Expr *) tle->expr, &context);
	}

	mysql_reset_transmission_modes(nestlevel);

	if (remote_conds)
	{
		appendStringInfoString(buf, " WHERE ");
		mysql_append_conditions(remote_conds, &context);
	}
}

/*
 * Deparse remote DELETE statement
 *
 * The statement text is appended to buf, and we also create an integer List
 * of the columns being retrieved by RETURNING (if any), which is returned
 * to *retrieved_attrs.
 */
void
mysql_deparse_delete(StringInfo buf, PlannerInfo *root, Index rtindex,
					 Relation rel, char *name)
{
	appendStringInfoString(buf, "DELETE FROM ");
	mysql_deparse_relation(buf, rel);
	appendStringInfo(buf, " WHERE %s = ?", name);
}


/*
 * deparse remote DELETE statement
 *
 * 'buf' is the output buffer to append the statement to 'rtindex' is the RT
 * index of the associated target relation 'rel' is the relation descriptor
 * for the target relation 'foreignrel' is the RelOptInfo for the target
 * relation or the join relation containing all base relations in the query
 * 'remote_conds' is the qual clauses that must be evaluated remotely
 * '*params_list' is an output list of exprs that will become remote Params
 * '*retrieved_attrs' is an output list of integers of columns being
 * retrieved by RETURNING (if any)
 */
void
mysql_deparse_direct_delete_sql(StringInfo buf, PlannerInfo *root,
								Index rtindex, Relation rel,
								RelOptInfo *foreignrel,
								List *remote_conds,
								List **params_list,
								List **retrieved_attrs)
{
	deparse_expr_cxt context;

	/* Set up context struct for recursion */
	context.root = root;
	context.foreignrel = foreignrel;
	context.scanrel = foreignrel;
	context.buf = buf;
	context.params_list = params_list;
	context.can_convert_time = false;
	context.is_not_distinct_op = false;
	context.can_skip_cast = false;
	context.is_not_add_array = false;
	context.json_table_expr = NULL;

	appendStringInfoString(buf, "DELETE FROM ");

	if (IS_JOIN_REL(foreignrel))
	{
		List	   *ignore_conds = NIL;
		MySQLFdwRelationInfo *fpinfo = (MySQLFdwRelationInfo *) foreignrel->fdw_private;

		appendStringInfo(buf, " %s%d", REL_ALIAS_PREFIX, rtindex);
		appendStringInfo(buf, " USING ");

		/*
		 * MySQL does not allow to define alias in FROM clause, alias must be
		 * defined in USING clause.
		 */
		mysql_deparse_relation(buf, rel);
		appendStringInfo(buf, " %s%d", REL_ALIAS_PREFIX, rtindex);
		appendStringInfo(buf, " %s JOIN ", mysql_get_jointype_name(fpinfo->jointype));

		mysql_deparse_from_expr_for_rel(buf, root, foreignrel, true, rtindex,
										&ignore_conds, params_list);
		remote_conds = list_concat(remote_conds, ignore_conds);
	}
	else
		mysql_deparse_relation(buf, rel);

	if (remote_conds)
	{
		appendStringInfoString(buf, " WHERE ");
		mysql_append_conditions(remote_conds, &context);
	}
}

/*
 * Deparse given Var node into context->buf.
 *
 * If the Var belongs to the foreign relation, just print its remote name.
 * Otherwise, it's effectively a Param (and will in fact be a Param at
 * run time).  Handle it the same way we handle plain Params --- see
 * deparseParam for comments.
 */
static void
mysql_deparse_var(Var *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	Relids		relids = context->scanrel->relids;
	int			relno;
	int			colno;

	/* Qualify columns when multiple relations are involved. */
	bool		qualify_col = (bms_membership(relids) == BMS_MULTIPLE);

	/*
	 * If the Var belongs to the foreign relation that is deparsed as a
	 * subquery, use the relation and column alias to the Var provided by the
	 * subquery, instead of the remote name.
	 */
	if (mysql_is_subquery_var(node, context->scanrel, &relno, &colno))
	{
		appendStringInfo(context->buf, "%s%d.%s%d",
						 SUBQUERY_REL_ALIAS_PREFIX, relno,
						 SUBQUERY_COL_ALIAS_PREFIX, colno);
		return;
	}

	if (bms_is_member(node->varno, relids) && node->varlevelsup == 0)
	{
		if (context->can_convert_time)
			appendStringInfoString(buf, "TIME_TO_SEC(");

		/* Var belongs to foreign table */
		mysql_deparse_column_ref(buf, node->varno, node->varattno,
								 planner_rt_fetch(node->varno, context->root), qualify_col);

		if (context->can_convert_time)
		{
			appendStringInfoString(buf, ") + ROUND(MICROSECOND(");
			mysql_deparse_column_ref(buf, node->varno, node->varattno,
									 planner_rt_fetch(node->varno, context->root), qualify_col);
			appendStringInfoString(buf, ")/1000000, 6)");
		}
	}
	else
	{
		/* Treat like a Param */
		if (context->params_list)
		{
			int			pindex = 0;
			ListCell   *lc;

			/* Find its index in params_list */
			foreach(lc, *context->params_list)
			{
				pindex++;
				if (equal(node, (Node *) lfirst(lc)))
					break;
			}
			if (lc == NULL)
			{
				/* Not in list, so add it */
				pindex++;
				*context->params_list = lappend(*context->params_list, node);
			}
			mysql_print_remote_param(pindex, node->vartype, node->vartypmod,
									 context);
		}
		else
			mysql_print_remote_placeholder(node->vartype, node->vartypmod,
										   context);
	}
}

/*
 * Deparse given constant value into context->buf.
 *
 * This function has to be kept in sync with ruleutils.c's get_const_expr.
 */
static void
mysql_deparse_const(Const *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	Oid			typoutput;
	bool		typIsVarlena;
	char	   *extval;

	if (node->constisnull)
	{
		appendStringInfoString(buf, "NULL");
		return;
	}

	getTypeOutputInfo(node->consttype, &typoutput, &typIsVarlena);

	switch (node->consttype)
	{
		case INT2OID:
		case INT4OID:
		case INT8OID:
		case OIDOID:
		case FLOAT4OID:
		case FLOAT8OID:
		case NUMERICOID:
			{
				extval = OidOutputFunctionCall(typoutput, node->constvalue);

				/*
				 * No need to quote unless it's a special value such as 'NaN'.
				 * See comments in get_const_expr().
				 */
				if (strspn(extval, "0123456789+-eE.") == strlen(extval))
				{
					if (extval[0] == '+' || extval[0] == '-')
						appendStringInfo(buf, "(%s)", extval);
					else
						appendStringInfoString(buf, extval);
				}
				else
					appendStringInfo(buf, "'%s'", extval);
			}
			break;
		case BITOID:
		case VARBITOID:
			extval = OidOutputFunctionCall(typoutput, node->constvalue);
			appendStringInfo(buf, "B'%s'", extval);
			break;
		case BOOLOID:
			extval = OidOutputFunctionCall(typoutput, node->constvalue);
			if (strcmp(extval, "t") == 0)
				appendStringInfoString(buf, "true");
			else
				appendStringInfoString(buf, "false");
			break;
		case INTERVALOID:
			if (context->can_convert_time)
			{
				char	   *expr;
				char	   *unit = "SECOND_MICROSECOND";

				/* convert interval to second_microsecond */
				interval2unit(node->constvalue, &expr, &unit);
				appendStringInfo(buf, "%s", expr);
				break;
			}

			if (context->can_convert_unit_arg)
			{
				char	   *expr;
				char	   *unit = NULL;

				/* convert interval to time unit of Mysql */
				interval2unit(node->constvalue, &expr, &unit);
				appendStringInfo(buf, "INTERVAL \'%s\' %s", expr, unit);
				break;
			}

			if (context->can_skip_convert_unit_arg)
			{
				char	   *expr;
				char	   *unit = NULL;

				/* convert interval to time unit of Mysql */
				interval2unit(node->constvalue, &expr, &unit);
				appendStringInfo(buf, "\'%s\'", expr);
				break;
			}

			deparse_interval(buf, node->constvalue);
			break;
		case BYTEAOID:

			/*
			 * The string for BYTEA always seems to be in the format "\\x##"
			 * where # is a hex digit, Even if the value passed in is
			 * 'hi'::bytea we will receive "\x6869". Making this assumption
			 * allows us to quickly convert postgres escaped strings to mysql
			 * ones for comparison
			 */
			extval = OidOutputFunctionCall(typoutput, node->constvalue);
			appendStringInfo(buf, "X\'%s\'", extval + 2);
			break;
		case TEXTARRAYOID:
			mysql_deparse_const_array(node, context);
			break;
		case JSONARRAYOID:
			mysql_deparse_const_array(node, context);
			break;
		case JSONOID:
			extval = OidOutputFunctionCall(typoutput, node->constvalue);
			appendStringInfoString(buf, "CAST(");
			mysql_deparse_string_literal(buf, extval);
			appendStringInfoString(buf, " AS JSON)");
			break;
		default:
			if (strcmp(mysql_deparse_type_name(node->consttype, node->consttypmod), "public.path_value[]") == 0)
				mysql_deparse_const_array(node, context);
			else
			{
				extval = OidOutputFunctionCall(typoutput, node->constvalue);
				mysql_deparse_string_literal(buf, extval);
			}
			break;
	}
}

/*
 * Deparse given Param node.
 *
 * If we're generating the query "for real", add the Param to
 * context->params_list if it's not already present, and then use its index
 * in that list as the remote parameter number.  During EXPLAIN, there's
 * no need to identify a parameter number.
 */
static void
mysql_deparse_param(Param *node, deparse_expr_cxt *context)
{
	if (context->params_list)
	{
		int			pindex = 0;
		ListCell   *lc;

		/* Find its index in params_list */
		foreach(lc, *context->params_list)
		{
			pindex++;
			if (equal(node, (Node *) lfirst(lc)))
				break;
		}
		if (lc == NULL)
		{
			/* Not in list, so add it */
			pindex++;
			*context->params_list = lappend(*context->params_list, node);
		}

		mysql_print_remote_param(pindex, node->paramtype, node->paramtypmod,
								 context);
	}
	else
		mysql_print_remote_placeholder(node->paramtype, node->paramtypmod,
									   context);
}

/*
 * Deparse an array subscript expression.
 */
static void
#if PG_VERSION_NUM < 120000
mysql_deparse_array_ref(ArrayRef * node, deparse_expr_cxt *context)
#else
mysql_deparse_subscripting_ref(SubscriptingRef *node, deparse_expr_cxt *context)
#endif
{
	ListCell   *uplist_item;
	ListCell   *lc;
	StringInfo	buf = context->buf;
	bool		first = true;
	ArrayExpr  *array_expr = (ArrayExpr *) node->refexpr;

	/* Not support slice function, which is excluded in pushdown checking */
	Assert(node->reflowerindexpr == NULL);
	Assert(node->refupperindexpr != NULL);

	/* Transform array subscripting to ELT(index number, str1, str2, ...) */
	appendStringInfoString(buf, "ELT(");

	/* Append index number of ELT() expression */
	uplist_item = list_head(node->refupperindexpr);
	deparseExpr(lfirst(uplist_item), context);
	appendStringInfoString(buf, ", ");

	/* Deparse Array Expression in form of ELT syntax */
	foreach(lc, array_expr->elements)
	{
		if (!first)
			appendStringInfoString(buf, ", ");
		deparseExpr(lfirst(lc), context);
		first = false;
	}

	/* Enclose the ELT() expression */
	appendStringInfoChar(buf, ')');

}

/*
 * This is possible that the name of function in PostgreSQL and mysql differ,
 * so return the mysql equivalent function name.
 */
static char *
mysql_replace_function(char *in, List *args)
{
	bool		has_mysql_prefix = false;

	if (strcmp(in, "btrim") == 0 ||
		strcmp(in, "ltrim") == 0 ||
		strcmp(in, "rtrim") == 0)
		return "trim";
	if (strcmp(in, "log") == 0 && list_length(args) == 1)
		return "log10";

	has_mysql_prefix = starts_with("mysql_", in);

	if (strcmp(in, "json_agg") == 0)
		return "json_arrayagg";
	if (strcmp(in, "json_object_agg") == 0)
		return "json_objectagg";
	if (strcmp(in, "json_build_array") == 0)
		return "json_array";
	if (strcmp(in, "json_build_object") == 0)
		return "json_object";

	if (has_mysql_prefix == true &&
		(strcmp(in, "mysql_pi") == 0 ||
		 strcmp(in, "mysql_char") == 0 ||
		 strcmp(in, "mysql_current_date") == 0 ||
		 strcmp(in, "mysql_current_time") == 0 ||
		 strcmp(in, "mysql_current_timestamp") == 0 ||
		 strcmp(in, "mysql_extract") == 0 ||
		 strcmp(in, "mysql_localtime") == 0 ||
		 strcmp(in, "mysql_localtimestamp") == 0 ||
		 strcmp(in, "mysql_now") == 0 ||
		 strcmp(in, "mysql_time") == 0 ||
		 strcmp(in, "mysql_timestamp") == 0 ||
		 strcmp(in, "mysql_json_table") == 0))
	{
		in += strlen("mysql_");
	}

	return in;
}

/*
 * Deparse function match_against()
 */
static void
mysql_deparse_func_expr_match_against(FuncExpr *node, deparse_expr_cxt *context, StringInfo buf, char *proname)
{
	ListCell   *arg;
	bool		first;

	/* get all the arguments */
	first = true;
	foreach(arg, node->args)
	{
		Expr	   *node;
		ListCell   *lc;
		ArrayExpr  *anode;
		bool		swt_arg;

		node = lfirst(arg);
		if (IsA(node, ArrayCoerceExpr))
		{
			node = (Expr *) ((ArrayCoerceExpr *) node)->arg;
		}

		Assert(nodeTag(node) == T_ArrayExpr);
		anode = (ArrayExpr *) node;
		appendStringInfoString(buf, "MATCH (");
		swt_arg = true;
		foreach(lc, anode->elements)
		{
			Expr	   *node;

			node = lfirst(lc);
			if (nodeTag(node) == T_Var)
			{
				if (!first)
					appendStringInfoString(buf, ", ");
				mysql_deparse_var((Var *) node, context);
			}
			else if (nodeTag(node) == T_Const)
			{
				Const	   *cnode = (Const *) node;

				if (swt_arg == true)
				{
					appendStringInfoString(buf, ") AGAINST ( ");
					swt_arg = false;
					first = true;
					mysql_deparse_const(cnode, context);
					appendStringInfoString(buf, " ");
				}
				else
				{
					Oid			typoutput;
					const char *valptr;
					char	   *extval;
					bool		typIsVarlena;

					getTypeOutputInfo(cnode->consttype,
									  &typoutput, &typIsVarlena);

					extval = OidOutputFunctionCall(typoutput, cnode->constvalue);
					for (valptr = extval; *valptr; valptr++)
					{
						char		ch = *valptr;

						if (SQL_STR_DOUBLE(ch, true))
							appendStringInfoChar(buf, ch);
						appendStringInfoChar(buf, ch);
					}
				}
			}
			first = false;
		}
		appendStringInfoChar(buf, ')');
	}
}

/*
 * Deparse function position()
 */
static void
mysql_deparse_func_expr_position(FuncExpr *node, deparse_expr_cxt *context, StringInfo buf, char *proname)
{
	Expr	   *arg1;
	Expr	   *arg2;

	/* Append the function name */
	appendStringInfo(buf, "%s(", proname);

	/*
	 * POSITION function has only two arguments. When deparsing, the range of
	 * these argument will be changed, the first argument will be in last so
	 * it will be get first, After that, the last argument will be get later.
	 */
	Assert(list_length(node->args) == 2);

	/* Get the first argument */
	arg1 = lsecond(node->args);
	deparseExpr(arg1, context);
	appendStringInfo(buf, " IN ");
	/* Get the last argument */
	arg2 = linitial(node->args);
	deparseExpr(arg2, context);

	appendStringInfoChar(buf, ')');
}

/*
 * Deparse function trim()
 */
static void
mysql_deparse_func_expr_trim(FuncExpr *node, deparse_expr_cxt *context, StringInfo buf, char *proname, char *origin_function)
{
	Expr	   *arg1;
	Expr	   *arg2;

	/*
	 * If rtrim, ltrim function has 1 argument, we still keep the function
	 * name.
	 */
	if (list_length(node->args) == 1)
	{
		if (strcmp(origin_function, "ltrim") == 0 ||
			strcmp(origin_function, "rtrim") == 0)
			/* Append the function name */
			appendStringInfo(buf, "%s(", origin_function);
		else
			/* Append the function name */
			appendStringInfo(buf, "%s(", proname);
		arg1 = linitial(node->args);
		deparseExpr(arg1, context);
	}

	/*
	 * With rtrim, ltrim, btrim function. If they have 2 arguments, we will
	 * replace into trim. And we base on the origin_function which is the name
	 * before replace to determine to add TRAILING|LEADING|BOTH.
	 */
	else
	{
		/* Append the function name */
		appendStringInfo(buf, "%s(", proname);

		if (strcmp(origin_function, "rtrim") == 0)
			appendStringInfo(buf, "TRAILING ");
		if (strcmp(origin_function, "ltrim") == 0)
			appendStringInfo(buf, "LEADING ");
		if (strcmp(origin_function, "btrim") == 0)
			appendStringInfo(buf, "BOTH ");

		/* Get the first argument */
		arg1 = lsecond(node->args);
		deparseExpr(arg1, context);
		appendStringInfo(buf, " FROM ");
		/* Get the last argument */
		arg2 = linitial(node->args);
		deparseExpr(arg2, context);
	}
	appendStringInfoChar(buf, ')');
}

/*
 * Deparse function weight_string()
 */
static void
mysql_deparse_func_expr_weight_string(FuncExpr *node, deparse_expr_cxt *context, StringInfo buf, char *proname)
{
	bool		first;
	ListCell   *arg;

	/* Append the function name ... */
	appendStringInfo(buf, "%s(", proname);

	/* ... and all the arguments */
	first = true;
	bool		check_arg_const = true;

	foreach(arg, node->args)
	{
		Expr	   *nodeExpr;

		nodeExpr = lfirst(arg);
		if (nodeTag(nodeExpr) == T_Var)
		{
			if (!first)
				appendStringInfoString(buf, ", ");
			mysql_deparse_var((Var *) nodeExpr, context);
		}
		else if (nodeTag(nodeExpr) == T_Const)
		{
			Const	   *cnode = (Const *) nodeExpr;

			if (check_arg_const && node->args->length > 2)
			{
				Oid			typoutput;
				const char *valptr;
				char	   *extval;
				bool		typIsVarlena;

				getTypeOutputInfo(cnode->consttype,
								  &typoutput, &typIsVarlena);

				extval = OidOutputFunctionCall(typoutput, cnode->constvalue);
				appendStringInfoString(buf, " AS ");
				for (valptr = extval; *valptr; valptr++)
				{
					char		ch = *valptr;

					if (SQL_STR_DOUBLE(ch, true))
						appendStringInfoChar(buf, ch);
					appendStringInfoChar(buf, ch);
				}
				check_arg_const = false;
			}

			/* deparse query when input is NULL */
			else if (check_arg_const && node->args->length == 1)
			{
				Oid			typoutput;
				const char *valptr;
				char	   *extval;
				bool		typIsVarlena;

				getTypeOutputInfo(cnode->consttype,
								  &typoutput, &typIsVarlena);

				extval = OidOutputFunctionCall(typoutput, cnode->constvalue);
				for (valptr = extval; *valptr; valptr++)
				{
					char		ch = *valptr;

					if (SQL_STR_DOUBLE(ch, true))
						appendStringInfoChar(buf, ch);
					appendStringInfoChar(buf, ch);
				}
				check_arg_const = false;
			}
			else
			{
				appendStringInfoChar(buf, '(');
				mysql_deparse_const(cnode, context);
				appendStringInfoChar(buf, ')');
			}
		}
		first = false;
	}
	appendStringInfoChar(buf, ')');
}


/*
 * Deparse target for query has json_table function
 */
static void
mysql_deparse_target_json_table_func(FuncExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	Expr	   *arg = llast(node->args);
	Const	   *cnode;
	char	   *extval;
	int			num_elems = 0;
	Datum	   *elem_values;
	bool	   *elem_nulls;
	Oid			elmtype;
	int			i;
	Oid			outputFunctionId;
	bool		typeVarLength;

	if (!IsA(arg, Const))
		ereport(ERROR,
				(errcode(ERRCODE_FDW_INVALID_ATTRIBUTE_VALUE),
				 errmsg("Wrong input type for last argument of JSON_TABLE"),
				 errhint("Use string literal to describle column list.")));

	if (context->json_table_expr != NULL)
		ereport(ERROR,
				(errcode(ERRCODE_FDW_INVALID_ATTRIBUTE_VALUE),
				 errmsg("Only one JSON_TABLE function is allowed in SELECT clause."),
				 errhint("Use string literal to describle column list.")));

	cnode = (Const *) arg;

	mysql_deconstruct_constant_array(cnode, &elem_nulls, &elem_values, &elmtype, &num_elems);
	getTypeOutputInfo(elmtype, &outputFunctionId, &typeVarLength);

	appendStringInfoString(buf, " CONCAT('(', CONCAT_WS(',', ");
	for (i = 0; i < num_elems; i++)
	{
		Assert(!elem_nulls[i]);
		if (i > 0)
			appendStringInfoString(buf, ", ");
		extval = OidOutputFunctionCall(outputFunctionId, elem_values[i]);
		appendStringInfo(buf, " IF(ISNULL(%s%d.%s), '',", REL_ALIAS_PREFIX, context->foreignrel->relid + 1, extval);
		appendStringInfo(buf, " JSON_QUOTE(CONCAT(%s%d.%s)))", REL_ALIAS_PREFIX, context->foreignrel->relid + 1, extval);
	}

	appendStringInfoString(buf, "), ')')");
	/* Save json_table node for deparse from */
	context->json_table_expr = node;
	pfree(elem_values);
	pfree(elem_nulls);
}

/*
 * append json_value function to buf
 */
static void
mysql_append_json_value_func(FuncExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	ListCell   *arg;
	int			arg_num = 1;

	context->can_skip_cast = true;

	/* Deparse function name... */
	appendStringInfo(buf, "json_value(");
	/* ... and all argumnents */
	foreach(arg, node->args)
	{
		if (arg_num == 1)
		{
			deparseExpr((Expr *) lfirst(arg), context);
			appendStringInfo(buf, ", ");
		}
		else if (arg_num == 2)
		{
			deparseExpr((Expr *) lfirst(arg), context);
		}
		else
		{
			/* deparse option */
			Expr	   *node;

			node = lfirst(arg);

			if (nodeTag(node) == T_Const)
			{
				Const	   *cnode = (Const *) node;
				Oid			typoutput;
				const char *valptr;
				char	   *extval;
				bool		typIsVarlena;

				getTypeOutputInfo(cnode->consttype,
								  &typoutput, &typIsVarlena);

				extval = OidOutputFunctionCall(typoutput, cnode->constvalue);

				appendStringInfoChar(buf, ' ');
				for (valptr = extval; *valptr; valptr++)
				{
					char		ch = *valptr;

					if (SQL_STR_DOUBLE(ch, true))
						appendStringInfoChar(buf, ch);
					appendStringInfoChar(buf, ch);
				}
			}
			else
			{
				appendStringInfoChar(buf, ' ');
				deparseExpr(node, context);
			}
		}
		arg_num++;
	}
	appendStringInfoChar(buf, ')');
}

/*
 * Deparse member_of() to ... MEMBER OF ... function
 */
static void
mysql_append_memberof_func(FuncExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	ListCell   *arg;
	bool		first = true;

	context->can_skip_cast = true;

	foreach(arg, node->args)
	{
		if (first)
		{
			deparseExpr((Expr *) lfirst(arg), context);
		}
		else
		{
			appendStringInfo(buf, " MEMBER OF(");
			deparseExpr((Expr *) lfirst(arg), context);
			appendStringInfo(buf, ") ");
		}
		first = false;
	}
}

/*
 * append json_table function to FROM clause
 */
static void
mysql_append_json_table_func(FuncExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	ListCell   *arg;
	int			arg_count = 1;

	appendStringInfoString(buf, ", JSON_TABLE(");
	foreach(arg, node->args)
	{
		Expr	   *n = lfirst(arg);
		char	   *extval;
		Const	   *cnode;

		if (arg_count == 1)
		{
			deparseExpr(n, context);
			appendStringInfoChar(buf, ',');
			arg_count++;
			continue;
		}

		if (!IsA(n, Const))
			ereport(ERROR,
					(errcode(ERRCODE_FDW_INVALID_ATTRIBUTE_VALUE),
					 errmsg("Wrong input type for argument %d of JSON_TABLE", arg_count),
					 errhint("Use string literal to describle column list.")));

		cnode = (Const *) n;

		if (arg_count == 2)
		{
			mysql_deparse_const(cnode, context);
			arg_count++;
			continue;
		}
		if (arg_count == 3)
		{
			int			num_elems = 0;
			Datum	   *elem_values;
			bool	   *elem_nulls;
			Oid			elmtype;
			int			i;
			Oid			outputFunctionId;
			bool		typeVarLength;

			mysql_deconstruct_constant_array(cnode, &elem_nulls, &elem_values, &elmtype, &num_elems);
			getTypeOutputInfo(elmtype, &outputFunctionId, &typeVarLength);

			appendStringInfoString(buf, " COLUMNS(");
			for (i = 0; i < num_elems; i++)
			{
				Assert(!elem_nulls[i]);
				if (i > 0)
					appendStringInfoString(buf, ", ");
				extval = OidOutputFunctionCall(outputFunctionId, elem_values[i]);
				appendStringInfo(buf, "%s", extval);
			}
			appendStringInfoString(buf, ")");
			pfree(elem_values);
			pfree(elem_nulls);
			break;
		}
	}

	appendStringInfo(buf, ") AS %s%d", REL_ALIAS_PREFIX, context->foreignrel->relid + 1);
}

/*
 * Append convert function to buf
 */
static void
mysql_append_convert_function(FuncExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	ListCell   *arg;
	bool		first = true;

	appendStringInfoString(buf, "convert(");
	foreach(arg, node->args)
	{
		Expr	   *n = lfirst(arg);

		if (first == true)
		{
			deparseExpr(n, context);
			appendStringInfoChar(buf, ',');
			first = false;
		}
		else
		{
			Expr	   *node;

			node = lfirst(arg);

			if (nodeTag(node) == T_Const)
			{
				Const	   *cnode = (Const *) node;
				Oid			typoutput;
				const char *valptr;
				char	   *extval;
				bool		typIsVarlena;

				getTypeOutputInfo(cnode->consttype,
								  &typoutput, &typIsVarlena);
				extval = OidOutputFunctionCall(typoutput, cnode->constvalue);

				for (valptr = extval; *valptr; valptr++)
				{
					char		ch = *valptr;

					if (SQL_STR_DOUBLE(ch, true))
						appendStringInfoChar(buf, ch);
					appendStringInfoChar(buf, ch);
				}
			}
			else
			{
				ereport(ERROR,
						(errcode(ERRCODE_FDW_INVALID_ATTRIBUTE_VALUE),
						 errmsg("Wrong input type for argument 2 of CONVERT function.")));
			}
		}
	}
	appendStringInfoChar(buf, ')');
}

/*
 * Deparse numeric cast from val::numeric(p,s) --> CAST(val AS DECIMAL(p,s))
 */
static void
mysql_deparse_numeric_cast(FuncExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	ListCell   *arg;
	bool		first = true;

	/* append function name ... */
	appendStringInfoString(buf, "CAST(");

	/* ... and all arguments */
	Assert(list_length(node->args) == 2);
	foreach(arg, node->args)
	{
		Expr	   *expr = lfirst(arg);

		if (first == true)
		{
			deparseExpr(expr, context);
			appendStringInfoString(buf, " AS DECIMAL");
			first = false;
		}
		else
		{
			if (nodeTag(expr) == T_Const)
			{
				Const	   *cnode = (Const *) expr;
				int32		typmod = 0;
				int32		tmp_typmod;
				int			precision;
				int			scale;

				if (cnode->consttype == INT4OID)
					typmod = DatumGetInt32(cnode->constvalue);

				if (typmod > (int32) (VARHDRSZ))
				{
					/*
					 * Get the precision and scale out of the typmod value
					 */
					tmp_typmod = typmod - VARHDRSZ;
					precision = (tmp_typmod >> 16) & 0xffff;
					scale = tmp_typmod & 0xffff;

					appendStringInfo(buf, "(%d, %d)", precision, scale);
				}
			}
		}
	}
	appendStringInfoChar(buf, ')');
}

/*
 * Deparse char and varchar cast to CAST(val AS char(n))
 */
static void
mysql_deparse_string_cast(FuncExpr *node, deparse_expr_cxt *context, char *proname)
{
	StringInfo	buf = context->buf;
	ListCell   *arg;
	bool		first = true;

	/* append function name ... */
	appendStringInfoString(buf, "CAST(");

	/* ... and all arguments */
	Assert(list_length(node->args) == 3);
	foreach(arg, node->args)
	{
		Expr	   *expr = lfirst(arg);

		if (first == true)
		{
			deparseExpr(expr, context);
			first = false;
		}
		else
		{
			appendStringInfo(buf, " AS %s", proname);
			if (nodeTag(expr) == T_Const)
			{
				Const	   *cnode = (Const *) expr;
				int32		typmod = 0;

				if (cnode->consttype == INT4OID)
					typmod = DatumGetInt32(cnode->constvalue);

				if (typmod > (int32) (VARHDRSZ))
				{
					/*
					 * Get the size from the typmod value
					 */
					typmod -= VARHDRSZ;

					appendStringInfo(buf, "(%d)", typmod);
				}
			}
			appendStringInfoChar(buf, ')');
			break;
		}
	}
}

/*
 * Deparse time, timetz, timestamp, timestamptz cast
 */
static void
mysql_deparse_datetime_cast(FuncExpr *node, deparse_expr_cxt *context, char *proname)
{
	StringInfo	buf = context->buf;
	ListCell   *arg;
	bool		first = true;

	/* append function name ... */
	appendStringInfoString(buf, "CAST(");

	/* ... and all arguments */
	Assert(list_length(node->args) == 2);
	foreach(arg, node->args)
	{
		Expr	   *expr = lfirst(arg);

		if (first == true)
		{
			deparseExpr(expr, context);
			first = false;
		}
		else
		{
			appendStringInfo(buf, " AS %s", proname);
			if (nodeTag(expr) == T_Const)
			{
				Const	   *cnode = (Const *) expr;
				int32		typmod = 0;

				if (cnode->consttype == INT4OID)
					typmod = DatumGetInt32(cnode->constvalue);

				appendStringInfo(buf, "(%d)", typmod);
			}
			appendStringInfoChar(buf, ')');
			break;
		}
	}
}

/*
 * Deparse a function call.
 */
static void
mysql_deparse_func_expr(FuncExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	char	   *proname;
	char	   *origin_function;
	bool		first;
	ListCell   *arg;
	bool		can_skip_cast = false;

	/* If function has variadic argument, we do not add ARRAY[] when deparsing */
	context->is_not_add_array = node->funcvariadic;

	/*
	 * If the function call came from an implicit coercion, then just show the
	 * first argument.
	 */
	if (node->funcformat == COERCE_IMPLICIT_CAST)
	{
		deparseExpr((Expr *) linitial(node->args), context);
		return;
	}

	/*
	 * Normal function: display as proname(args).
	 */
	proname = get_func_name(node->funcid);
	origin_function = proname;

	/* check NULL for proname */
	if (proname == NULL)
		elog(ERROR, "cache lookup failed for function %u", node->funcid);

	/* remove cast function if parent function can handle without cast */
	if ((exist_in_function_list(proname, CastFunction)))
	{
		if (context->can_skip_cast == true &&
			(list_length(node->args) == 1 ||
			 strcmp(proname, "interval") == 0))
		{
			arg = list_head(node->args);
			context->can_skip_cast = false;
			deparseExpr((Expr *) lfirst(arg), context);
			return;
		}

		if (strcmp(proname, "numeric") == 0)
		{
			mysql_deparse_numeric_cast(node, context);
			return;
		}
		if (strcmp(proname, "bpchar") == 0 ||
			strcmp(proname, "varchar") == 0)
		{
			mysql_deparse_string_cast(node, context, "char");
			return;
		}
		if (strcmp(proname, "time") == 0 ||
			strcmp(proname, "timetz") == 0)
		{
			mysql_deparse_datetime_cast(node, context, "time");
			return;
		}
		if (strcmp(proname, "timestamp") == 0 ||
			strcmp(proname, "timestamptz") == 0)
		{
			mysql_deparse_datetime_cast(node, context, "datetime");
			return;
		}
	}

	proname = mysql_replace_function(proname, node->args);

	if (strcmp(proname, "match_against") == 0)
	{
		mysql_deparse_func_expr_match_against(node, context, buf, proname);
		return;
	}

	if (strcmp(proname, "position") == 0)
	{
		mysql_deparse_func_expr_position(node, context, buf, proname);
		return;
	}

	if (strcmp(proname, "trim") == 0)
	{
		mysql_deparse_func_expr_trim(node, context, buf, proname, origin_function);
		return;
	}

	if (strcmp(proname, "weight_string") == 0)
	{
		mysql_deparse_func_expr_weight_string(node, context, buf, proname);
		return;
	}

	if (strcmp(proname, "get_format") == 0 ||
		strcmp(proname, "timestampadd") == 0 ||
		strcmp(proname, "timestampdiff") == 0 ||
		strcmp(proname, "extract") == 0)
	{
		first = true;
		context->can_skip_cast = true;

		/* Deparse the function name and all the arguments */
		appendStringInfo(buf, "%s(", proname);
		foreach(arg, node->args)
		{
			if (!first)
			{
				if (strcmp(proname, "extract") == 0)
					appendStringInfoString(buf, " FROM ");
				else
					appendStringInfoString(buf, ", ");
			}
			else
			{
				node = lfirst(arg);
				Assert(nodeTag(node) == T_Const);
				mysql_append_time_unit((Const *) node, context);
				first = false;
				continue;
			}

			deparseExpr((Expr *) lfirst(arg), context);
			first = false;
		}
		appendStringInfoChar(buf, ')');

		return;
	}

	/*
	 * Deparse function div, mod to operator syntax div(a, b) to (a div b)
	 */

	if (strcmp(proname, "div") == 0 ||
		strcmp(proname, "mod") == 0)
	{
		first = true;
		context->can_skip_cast = true;

		appendStringInfoChar(buf, '(');
		foreach(arg, node->args)
		{
			if (!first)
				appendStringInfo(buf, " %s ", proname);

			deparseExpr((Expr *) lfirst(arg), context);
			first = false;
		}
		appendStringInfoChar(buf, ')');

		return;
	}

	if (strcmp(proname, "json_value") == 0)
	{
		mysql_append_json_value_func(node, context);
		return;
	}

	if (strcmp(proname, "json_table") == 0)
	{
		mysql_deparse_target_json_table_func(node, context);
		return;
	}

	if (strcmp(proname, "member_of") == 0)
	{
		mysql_append_memberof_func(node, context);
		return;
	}

	if (strcmp(proname, "convert") == 0)
	{
		mysql_append_convert_function(node, context);
		return;
	}

	if (mysql_is_unique_func(node->funcid, origin_function) ||
		mysql_is_supported_builtin_func(node->funcid, origin_function))
		can_skip_cast = true;

	/* inner function need convert time inverval to time unit */
	if (strcmp(proname, "adddate") == 0 ||
		strcmp(proname, "date_add") == 0 ||
		strcmp(proname, "date_sub") == 0 ||
		strcmp(proname, "subdate") == 0)
		context->can_convert_unit_arg = true;

	if (strcmp(proname, "addtime") == 0 ||
		strcmp(proname, "subtime") == 0 ||
		strcmp(proname, "timediff") == 0)
		context->can_skip_convert_unit_arg = true;

	/* Deparse the function name ... */
	appendStringInfo(buf, "%s(", proname);

	/* ... and all the arguments */
	first = true;
	foreach(arg, node->args)
	{
		context->is_not_add_array = node->funcvariadic;
		if (!first)
			appendStringInfoString(buf, ", ");

		if (can_skip_cast)
			context->can_skip_cast = true;
		deparseExpr((Expr *) lfirst(arg), context);
		first = false;
	}
	appendStringInfoChar(buf, ')');
}

/*
 * In Postgres, with divide operand '/', the results is integer with
 * truncates which different with mysql.
 * In mysql, with divide operand '/', the results is the scale
 * of the first operand plus the value of the div_precision_increment
 * system variable (which is 4 by default)
 *
 * To make Postgres consistence with mysql in this case, we will do follow:
 *  + Check operands recursively.
 *  + If all operands are non floating point type, change '/' to 'DIV'.
 */
static bool
mysql_deparse_op_divide(Expr *node, deparse_expr_cxt *context)
{
	bool		is_convert = true;

	if (node == NULL)
		return false;

	switch (nodeTag(node))
	{
		case T_Var:
			{
				Var		   *var = (Var *) node;
				RangeTblEntry *rte;
				PlannerInfo *root = context->root;
				int			col_type = 0;
				int			varno = var->varno;
				int			varattno = var->varattno;

				/*
				 * varno must not be any of OUTER_VAR, INNER_VAR and
				 * INDEX_VAR.
				 */
				Assert(!IS_SPECIAL_VARNO(varno));

				/* Get RangeTblEntry from array in PlannerInfo. */
				rte = planner_rt_fetch(varno, root);

				col_type = get_atttype(rte->relid, varattno);
				is_convert = IS_INTEGER_TYPE(col_type);
			}
			break;
		case T_Const:
			{
				Const	   *c = (Const *) node;

				is_convert = IS_INTEGER_TYPE(c->consttype);
			}
			break;
		case T_FuncExpr:
			{
				FuncExpr   *f = (FuncExpr *) node;

				is_convert = IS_INTEGER_TYPE(f->funcresulttype);
			}
			break;
		case T_Aggref:
			{
				Aggref	   *agg = (Aggref *) node;

				is_convert = IS_INTEGER_TYPE(agg->aggtype);
			}
			break;
		case T_OpExpr:
			{
				HeapTuple	tuple;
				Form_pg_operator form;
				char		oprkind;
				ListCell   *arg;

				OpExpr	   *op = (OpExpr *) node;

				/*
				 * Retrieve information about the operator from system
				 * catalog.
				 */
				tuple = SearchSysCache1(OPEROID, ObjectIdGetDatum(op->opno));
				if (!HeapTupleIsValid(tuple))
					elog(ERROR, "cache lookup failed for operator %u", op->opno);
				form = (Form_pg_operator) GETSTRUCT(tuple);
				oprkind = form->oprkind;

				/* Sanity check. */
				Assert((oprkind == 'r' && list_length(op->args) == 1) ||
					   (oprkind == 'l' && list_length(op->args) == 1) ||
					   (oprkind == 'b' && list_length(op->args) == 2));
				/* Check left operand. */
				if (oprkind == 'r' || oprkind == 'b')
				{
					arg = list_head(op->args);
					is_convert = mysql_deparse_op_divide(lfirst(arg), context);
				}

				/* If left operand is ok, going to check right operand. */
				if (is_convert && (oprkind == 'l' || oprkind == 'b'))
				{
					arg = list_tail(op->args);
					is_convert = is_convert ? mysql_deparse_op_divide(lfirst(arg), context) : false;
				}
				ReleaseSysCache(tuple);
			}
			break;
		default:
			is_convert = false;
			elog(ERROR, "unsupported expression type for check type operand for convert divide : %d",
				 (int) nodeTag(node));
			break;
	}
	return is_convert;
}

/*
 * Deparse given operator expression.  To avoid problems around
 * priority of operations, we always parenthesize the arguments.
 */
static void
mysql_deparse_op_expr(OpExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	HeapTuple	tuple;
	Form_pg_operator form;
	char		oprkind;
#if PG_VERSION_NUM < 140000
	ListCell   *arg;
#endif
	bool		is_convert = false; /* Flag to determine that convert '/' to
									 * 'DIV' or not */
	bool		is_concat = false;	/* Flag to use keyword 'CONCAT' instead of
									 * '||' */

	/* Retrieve information about the operator from system catalog. */
	tuple = SearchSysCache1(OPEROID, ObjectIdGetDatum(node->opno));
	if (!HeapTupleIsValid(tuple))
		elog(ERROR, "cache lookup failed for operator %u", node->opno);

	form = (Form_pg_operator) GETSTRUCT(tuple);
	oprkind = form->oprkind;

	/* Sanity check. */
#if PG_VERSION_NUM >= 140000
	Assert((oprkind == 'l' && list_length(node->args) == 1) ||
		   (oprkind == 'b' && list_length(node->args) == 2));
#else
	Assert((oprkind == 'r' && list_length(node->args) == 1) ||
		   (oprkind == 'l' && list_length(node->args) == 1) ||
		   (oprkind == 'b' && list_length(node->args) == 2));
#endif

	cur_opname = NameStr(form->oprname);
	/* If opname is '/' check all type of operands recursively */
	if (form->oprnamespace == PG_CATALOG_NAMESPACE && strcmp(cur_opname, "/") == 0)
		is_convert = mysql_deparse_op_divide((Expr *) node, context);

	if (strcmp(cur_opname, "||") == 0)
	{
		is_concat = true;
		appendStringInfoString(buf, "CONCAT(");
	}
	else
	{
		/* Always parenthesize the expression. */
		appendStringInfoChar(buf, '(');
	}

#if PG_VERSION_NUM >= 140000
	/* Deparse left operand, if any. */
	if (oprkind == 'b')
	{
		deparseExpr(linitial(node->args), context);
		appendStringInfoChar(buf, ' ');
	}
#else
	/* Deparse left operand. */
	if (oprkind == 'r' || oprkind == 'b')
	{
		arg = list_head(node->args);
		deparseExpr(lfirst(arg), context);
		appendStringInfoChar(buf, ' ');
	}
#endif

	/*
	 * Deparse operator name. If all operands are non floating point type,
	 * change '/' to 'DIV'.
	 */
	if (is_convert)
		appendStringInfoString(buf, "DIV");
	else if (is_concat)
		appendStringInfoString(buf, ",");
	else
		mysql_deparse_operator_name(buf, form);

#if PG_VERSION_NUM >= 140000
	/* Deparse right operand. */
	appendStringInfoChar(buf, ' ');
	deparseExpr(llast(node->args), context);
#else
	/* Deparse right operand. */
	if (oprkind == 'l' || oprkind == 'b')
	{
		arg = list_tail(node->args);
		appendStringInfoChar(buf, ' ');
		deparseExpr(lfirst(arg), context);
	}
#endif

	appendStringInfoChar(buf, ')');

	ReleaseSysCache(tuple);
}

/*
 * Print the name of an operator.
 */
static void
mysql_deparse_operator_name(StringInfo buf, Form_pg_operator opform)
{
	/* opname is not a SQL identifier, so we should not quote it. */
	cur_opname = NameStr(opform->oprname);

	/* Print schema name only if it's not pg_catalog */
	if (opform->oprnamespace != PG_CATALOG_NAMESPACE)
	{
		const char *opnspname;

		opnspname = get_namespace_name(opform->oprnamespace);
		/* Print fully qualified operator name. */
		appendStringInfo(buf, "OPERATOR(%s.%s)",
						 mysql_quote_identifier(opnspname, '`'), cur_opname);
	}
	else
	{
		if (strcmp(cur_opname, "~~") == 0)
			appendStringInfoString(buf, "LIKE BINARY");
		else if (strcmp(cur_opname, "~~*") == 0)
			appendStringInfoString(buf, "LIKE");
		else if (strcmp(cur_opname, "!~~") == 0)
			appendStringInfoString(buf, "NOT LIKE BINARY");
		else if (strcmp(cur_opname, "!~~*") == 0)
			appendStringInfoString(buf, "NOT LIKE");
		else if (strcmp(cur_opname, "~") == 0)
			appendStringInfoString(buf, "REGEXP BINARY");
		else if (strcmp(cur_opname, "~*") == 0)
			appendStringInfoString(buf, "REGEXP");
		else if (strcmp(cur_opname, "!~") == 0)
			appendStringInfoString(buf, "NOT REGEXP BINARY");
		else if (strcmp(cur_opname, "!~*") == 0)
			appendStringInfoString(buf, "NOT REGEXP");
		else
			appendStringInfoString(buf, cur_opname);
	}
}

/*
 * Deparse IS DISTINCT FROM.
 */
static void
mysql_deparse_distinct_expr(DistinctExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	bool		outer_is_not_distinct_op = context->is_not_distinct_op;

	Assert(list_length(node->args) == 2);

	/*
	 * Check value of is_not_distinct_op If is_not_distinct_op is true: IS NOT
	 * DISTINCT operator is equivalents with "<=>" operator in MySQL. If
	 * is_not_distinct_op is false: IS DISTINCT operator is equivalents NOT
	 * logic operator on "<=>" operator expression in MySQL.
	 */
	if (!outer_is_not_distinct_op)
	{
		appendStringInfoString(buf, "(NOT ");
	}

	/* reset if having recursive IS DISTINCT/IS NOT DISTINCT clause */
	context->is_not_distinct_op = false;
	appendStringInfoChar(buf, '(');
	deparseExpr(linitial(node->args), context);
	appendStringInfoString(buf, " <=> ");
	deparseExpr(lsecond(node->args), context);
	appendStringInfoChar(buf, ')');

	/* recover after deparsing recursive IS DISTINCT/IS NOT DISTINCT clause */
	context->is_not_distinct_op = outer_is_not_distinct_op;

	/* close NOT expression */
	if (!outer_is_not_distinct_op)
	{
		appendStringInfoString(buf, ")");
	}

}


static void
mysql_deparse_string(ScalarArrayOpExpr *node, deparse_expr_cxt *context, StringInfo buf, const char *extval, bool isstr, bool useIn)
{
	const char *valptr;
	int			i = 0;
	bool		deparseLeft = true;
	Expr	   *arg1;
	char	   *opname;

	arg1 = linitial(node->args);
	opname = get_opname(node->opno);

	for (valptr = extval; *valptr; valptr++, i++)
	{
		char		ch = *valptr;

		if (useIn)
		{
			if (i == 0 && isstr)
				appendStringInfoChar(buf, '\'');
		}
		else if (deparseLeft)
		{
			/* Deparse left operand. */
			deparseExpr(arg1, context);
			/* Append operator */
			appendStringInfo(buf, " %s ", opname);
			if (isstr)
				appendStringInfoChar(buf, '\'');
			deparseLeft = false;
		}

		/*
		 * Remove '{', '}' and \" character from the string. Because this
		 * syntax is not recognize by the remote MySQL server.
		 */
		if ((ch == '{' && i == 0) || (ch == '}' && (i == (strlen(extval) - 1))) || ch == '\"')
			continue;

		if (ch == ',')
		{
			if (useIn)
			{
				if (isstr)
					appendStringInfoChar(buf, '\'');
				appendStringInfoChar(buf, ch);
				appendStringInfoChar(buf, ' ');
				if (isstr)
					appendStringInfoChar(buf, '\'');
			}
			else
			{
				if (isstr)
					appendStringInfoChar(buf, '\'');
				if (node->useOr)
					appendStringInfoString(buf, " OR ");
				else
					appendStringInfoString(buf, " AND ");
				deparseLeft = true;
			}
			continue;
		}
		appendStringInfoChar(buf, ch);
	}

	if (isstr)
		appendStringInfoChar(buf, '\'');
}

/*
 * Deparse given ScalarArrayOpExpr expression.  To avoid problems
 * around priority of operations, we always parenthesize the arguments.
 */
static void
mysql_deparse_scalar_array_op_expr(ScalarArrayOpExpr *node,
								   deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	Expr	   *arg1;
	Expr	   *arg2;
	char	   *opname;
	Oid			typoutput;
	bool		typIsVarlena;
	char	   *extval;
	bool		useIn = false;

	opname = get_opname(node->opno);

	/* Sanity check. */
	Assert(list_length(node->args) == 2);

	/* Using IN clause for '= ANY' and NOT IN clause for '<> ALL' */
	if ((strcmp(opname, "=") == 0 && node->useOr == true) ||
		(strcmp(opname, "<>") == 0 && node->useOr == false))
		useIn = true;

	/* Get left and right argument for deparsing */
	arg1 = linitial(node->args);
	arg2 = lsecond(node->args);

	/*
	 * Deparse right operand to check type of argument first. For an fixed-len
	 * array, we use IN clause, e.g. ANY(ARRAY[1, 2, 3]). For an variable-len
	 * array, we use FIND_IN_SET clause, e.g. ANY(ARRAY(SELECT * FROM table),
	 * because we can bind a string representation of array.
	 */
	if (nodeTag((Node *) arg2) == T_Param)
	{
		if (strcmp(opname, "<>") == 0)
			appendStringInfo(buf, " NOT ");

		/* Use FIND_IN_SET for binding the array parameter */
		appendStringInfo(buf, " FIND_IN_SET (");

		/* Deparse left operand. */
		deparseExpr(arg1, context);
		appendStringInfoChar(buf, ',');
	}
	else
	{
		if (useIn)
		{
			/* Deparse left operand. */
			deparseExpr(arg1, context);
			appendStringInfoChar(buf, ' ');

			/* Add IN clause */
			if (strcmp(opname, "<>") == 0)
			{
				appendStringInfoString(buf, " NOT IN (");
			}
			else if (strcmp(opname, "=") == 0)
			{
				appendStringInfoString(buf, " IN (");
			}
		}
	}

	switch (nodeTag((Node *) arg2))
	{
		case T_Const:
			{
				Const	   *c = (Const *) arg2;

				if (!c->constisnull)
				{
					getTypeOutputInfo(c->consttype,
									  &typoutput, &typIsVarlena);
					extval = OidOutputFunctionCall(typoutput, c->constvalue);

					/* Determine array type */
					switch (c->consttype)
					{
						case BOOLARRAYOID:
						case INT8ARRAYOID:
						case INT2ARRAYOID:
						case INT4ARRAYOID:
						case OIDARRAYOID:
						case FLOAT4ARRAYOID:
						case FLOAT8ARRAYOID:
							mysql_deparse_string(node, context, buf, extval, false, useIn);
							break;
						default:
							mysql_deparse_string(node, context, buf, extval, true, useIn);
							break;
					}
				}
				else
				{
					appendStringInfoString(buf, " NULL");
				}
				break;
			}
		case T_ArrayExpr:
			{
				bool		first = true;
				ListCell   *lc;
				ArrayExpr  *a = (ArrayExpr *) arg2;

				foreach(lc, a->elements)
				{
					if (!first)
					{
						if (useIn)
						{
							appendStringInfoString(buf, ", ");
						}
						else
						{
							if (node->useOr)
								appendStringInfoString(buf, " OR ");
							else
								appendStringInfoString(buf, " AND ");
						}
					}

					if (useIn)
					{
						deparseExpr(lfirst(lc), context);
					}
					else
					{
						/* Deparse left argument */
						appendStringInfoChar(buf, '(');
						deparseExpr(arg1, context);
						appendStringInfo(buf, " %s ", opname);

						/* Deparse each element in right argument */
						deparseExpr(lfirst(lc), context);
						appendStringInfoChar(buf, ')');
					}
					first = false;
				}
				break;
			}
		case T_Param:
			{
				deparseExpr(arg2, context);
				break;
			}
		default:
			{
				elog(ERROR, "unsupported expression type for deparse: %d", (int) nodeTag((Node *) arg2));
				break;
			}
	}

	/* Close IN clause */
	if (useIn)
	{
		appendStringInfoChar(buf, ')');
	}
	if ((nodeTag((Node *) arg2) == T_Param && strcmp(opname, "=") == 0 && node->useOr == false) ||
		(nodeTag((Node *) arg2) == T_Param && strcmp(opname, "<>") == 0 && node->useOr == true))
	{
		appendStringInfoChar(buf, ')');
	}
}

/*
 * Deparse a RelabelType (binary-compatible cast) node.
 */
static void
mysql_deparse_relabel_type(RelabelType *node, deparse_expr_cxt *context)
{
	deparseExpr(node->arg, context);
}

/*
 * Deparse a BoolExpr node.
 *
 * Note: by the time we get here, AND and OR expressions have been flattened
 * into N-argument form, so we'd better be prepared to deal with that.
 */
static void
mysql_deparse_bool_expr(BoolExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	const char *op = NULL;		/* keep compiler quiet */
	bool		first;
	ListCell   *lc;
	Expr	   *arg;

	switch (node->boolop)
	{
		case AND_EXPR:
			op = "AND";
			break;
		case OR_EXPR:
			op = "OR";
			break;
		case NOT_EXPR:

			/*
			 * Postgres has converted IS NOT DISTINCT expression to NOT (IS
			 * DISTINCT) and pass it to mysql_fdw. We set is_not_distinct_op
			 * equals to true to mark this conversion for further deparsing.
			 */
			arg = (Expr *) lfirst(list_head(node->args));
			if (IsA(arg, DistinctExpr))
			{
				context->is_not_distinct_op = true;
			}

			/*
			 * If expression is not IS NOT DISTINCT, we append NOT operator
			 * here.
			 */
			if (!context->is_not_distinct_op)
			{
				appendStringInfoString(buf, "(NOT ");
			}

			deparseExpr(arg, context);

			if (!context->is_not_distinct_op)
			{
				appendStringInfoString(buf, ")");
			}

			return;
	}

	appendStringInfoChar(buf, '(');
	first = true;
	foreach(lc, node->args)
	{
		if (!first)
			appendStringInfo(buf, " %s ", op);
		deparseExpr((Expr *) lfirst(lc), context);
		first = false;
	}
	appendStringInfoChar(buf, ')');
}

/*
 * Deparse IS [NOT] NULL expression.
 */
static void
mysql_deparse_null_test(NullTest *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;

	appendStringInfoChar(buf, '(');
	deparseExpr(node->arg, context);
	if (node->nulltesttype == IS_NULL)
		appendStringInfoString(buf, " IS NULL");
	else
		appendStringInfoString(buf, " IS NOT NULL");
	appendStringInfoChar(buf, ')');
}

/*
 * Deparse an Aggref node.
 */
static void
mysql_deparse_aggref(Aggref *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	bool		use_variadic;
	Oid			func_rettype;
	char	   *func_name;
	bool		is_bit_func = false;

	/* Only basic, non-split aggregation accepted. */
	Assert(node->aggsplit == AGGSPLIT_SIMPLE);

	/* Check if need to print VARIADIC (cf. ruleutils.c) */
	use_variadic = node->aggvariadic;
	func_rettype = get_func_rettype(node->aggfnoid);
	func_name = get_func_name(node->aggfnoid);
	func_name = mysql_replace_function(func_name, NIL);

	/*
	 * On Postgres, BIT_AND and BIT_OR return a signed bigint value. On MySQL,
	 * BIT_AND and BIT_OR return an unsigned bigint value. So, to display
	 * correct value on Postgres, we need to CAST return value AS SIGNED.
	 */
	if (strcmp(func_name, "bit_and") == 0 ||
		strcmp(func_name, "bit_or") == 0)
	{
		is_bit_func = true;
		appendStringInfoString(buf, "CAST(");
	}

	/*
	 * MySQL cannot calculate SUM, AVG correctly with time interval under
	 * format "hh:mm:ss". We should convert time to second (plus microsecond
	 * if needed).
	 */
	if ((func_rettype == INTERVALOID) && (strcmp(func_name, "sum") == 0 ||
										  strcmp(func_name, "avg") == 0))
	{
		context->can_convert_time = true;
		appendStringInfoString(buf, "SEC_TO_TIME(");
	}
	else
		context->can_convert_time = false;

	/* Find aggregate name from aggfnoid which is a pg_proc entry */
	mysql_append_function_name(node->aggfnoid, context);
	appendStringInfoChar(buf, '(');

	/* Add DISTINCT */
	appendStringInfo(buf, "%s", (node->aggdistinct != NIL) ? "DISTINCT " : "");

	/*
	 * Skip cast for aggregation functions. TODO: We may hanlde another
	 * functions in future if we have more test case with cast function.
	 */
	if (strcmp(func_name, "count") == 0 ||
		strcmp(func_name, "avg") == 0 ||
		strcmp(func_name, "sum") == 0)
	{
		context->can_skip_cast = true;
	}

	/* aggstar can be set only in zero-argument aggregates */
	if (node->aggstar)
		appendStringInfoChar(buf, '*');
	else
	{
		ListCell   *arg;
		bool		first = true;

		/* Add all the arguments */
		foreach(arg, node->args)
		{
			TargetEntry *tle = (TargetEntry *) lfirst(arg);
			Node	   *n = (Node *) tle->expr;

			if (tle->resjunk)
				continue;

			if (!first)
				appendStringInfoString(buf, ", ");
			first = false;

			/* Add VARIADIC */
#if PG_VERSION_NUM < 130000
			if (use_variadic && lnext(arg) == NULL)
#else
			if (use_variadic && lnext(node->args, arg) == NULL)
#endif
				appendStringInfoString(buf, "VARIADIC ");

			deparseExpr((Expr *) n, context);
		}

		/* Add ORDER BY */
		if (node->aggorder != NIL)
		{
			appendStringInfoString(buf, " ORDER BY ");
			mysql_append_agg_order_by(node->aggorder, node->args, context);
		}
	}

	appendStringInfoChar(buf, ')');

	if (is_bit_func)
		appendStringInfoString(buf, " AS SIGNED)");

	if (context->can_convert_time == true)
		appendStringInfoChar(buf, ')');

	/* Reset after finish deparsing */
	context->can_convert_time = false;
	context->can_skip_cast = false;
}

/*
 * Append ORDER BY within aggregate function.
 */
static void
mysql_append_agg_order_by(List *orderList, List *targetList, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	ListCell   *lc;
	bool		first = true;

	foreach(lc, orderList)
	{
		SortGroupClause *srt = (SortGroupClause *) lfirst(lc);
		Node	   *sortexpr;
		Oid			sortcoltype;
		TypeCacheEntry *typentry;

		if (!first)
			appendStringInfoString(buf, ", ");
		first = false;

		sortexpr = mysql_deparse_sort_group_clause(srt->tleSortGroupRef, targetList,
												   false, context);
		sortcoltype = exprType(sortexpr);
		/* See whether operator is default < or > for datatype */
		typentry = lookup_type_cache(sortcoltype,
									 TYPECACHE_LT_OPR | TYPECACHE_GT_OPR);
		if (srt->sortop == typentry->lt_opr)
			appendStringInfoString(buf, " ASC");
		else if (srt->sortop == typentry->gt_opr)
			appendStringInfoString(buf, " DESC");
		else
		{
			HeapTuple	opertup;
			Form_pg_operator operform;

			appendStringInfoString(buf, " USING ");

			/* Append operator name. */
			opertup = SearchSysCache1(OPEROID, ObjectIdGetDatum(srt->sortop));
			if (!HeapTupleIsValid(opertup))
				elog(ERROR, "cache lookup failed for operator %u", srt->sortop);
			operform = (Form_pg_operator) GETSTRUCT(opertup);
			mysql_deparse_operator_name(buf, operform);
			ReleaseSysCache(opertup);
		}
	}
}

/*
 * Deparse a RowExpr node to mysql format agg_func(expr,[expr...])
 * agg((col1, col2)) => agg(col1,col2)
 */
static void
mysql_deparse_row_expr(RowExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	bool		first = true;
	ListCell   *lc;
	Expr	   *expr;

	foreach(lc, node->args)
	{
		if (!first)
			appendStringInfoString(buf, ", ");
		expr = (Expr *) lfirst(lc);
		deparseExpr(expr, context);
		first = false;
	}
}

/*
 * Deparse ARRAY[...] construct.
 */
static void
mysql_deparse_array_expr(ArrayExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	bool		first = true;
	bool		is_not_add_array = context->is_not_add_array;
	ListCell   *lc;

	if (!is_not_add_array)
		appendStringInfoString(buf, "ARRAY[");

	foreach(lc, node->elements)
	{
		if (!first)
			appendStringInfoString(buf, ", ");
		deparseExpr(lfirst(lc), context);
		first = false;
	}

	if (!is_not_add_array)
		appendStringInfoChar(buf, ']');
}

/*
 * Print the representation of a parameter to be sent to the remote side.
 *
 * Note: we always label the Param's type explicitly rather than relying on
 * transmitting a numeric type OID in PQexecParams().  This allows us to
 * avoid assuming that types have the same OIDs on the remote side as they
 * do locally --- they need only have the same names.
 */
static void
mysql_print_remote_param(int paramindex, Oid paramtype, int32 paramtypmod,
						 deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;

	appendStringInfo(buf, "?");
}

static void
mysql_print_remote_placeholder(Oid paramtype, int32 paramtypmod,
							   deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;

	appendStringInfo(buf, "(SELECT null)");
}

/*
 * Return true if given object is one of PostgreSQL's built-in objects.
 *
 * We use FirstBootstrapObjectId as the cutoff, so that we only consider
 * objects with hand-assigned OIDs to be "built in", not for instance any
 * function or type defined in the information_schema.
 *
 * Our constraints for dealing with types are tighter than they are for
 * functions or operators: we want to accept only types that are in pg_catalog,
 * else format_type might incorrectly fail to schema-qualify their names.
 * (This could be fixed with some changes to format_type, but for now there's
 * no need.)  Thus we must exclude information_schema types.
 *
 * XXX there is a problem with this, which is that the set of built-in
 * objects expands over time.  Something that is built-in to us might not
 * be known to the remote server, if it's of an older version.  But keeping
 * track of that would be a huge exercise.
 */
bool
mysql_is_builtin(Oid oid)
{
	return (oid < FirstBootstrapObjectId);
}

/*
 * Check if expression is safe to execute remotely, and return true if so.
 *
 * In addition, *outer_cxt is updated with collation information.
 *
 * We must check that the expression contains only node types we can deparse,
 * that all types/functions/operators are safe to send (which we approximate
 * as being built-in), and that all collations used in the expression derive
 * from Vars of the foreign table.  Because of the latter, the logic is pretty
 * close to assign_collations_walker() in parse_collate.c, though we can assume
 * here that the given expression is valid.
 */
static bool
foreign_expr_walker(Node *node, foreign_glob_cxt *glob_cxt,
					foreign_loc_cxt *outer_cxt)
{
	bool		check_type = true;
	foreign_loc_cxt inner_cxt;
	Oid			collation;
	FDWCollateState state;
	HeapTuple	tuple;

	/* Need do nothing for empty subexpressions */
	if (node == NULL)
		return true;

	/* Set up inner_cxt for possible recursion to child nodes */
	inner_cxt.collation = InvalidOid;
	inner_cxt.state = FDW_COLLATE_NONE;
	inner_cxt.can_skip_cast = false;
	inner_cxt.op_flag = outer_cxt->op_flag;
	inner_cxt.can_pushdown_function = false;
	inner_cxt.can_use_outercast = false;

	switch (nodeTag(node))
	{
		case T_Var:
			{
				Var		   *var = (Var *) node;

				/*
				 * If the Var is from the foreign table, we consider its
				 * collation (if any) safe to use.  If it is from another
				 * table, we treat its collation the same way as we would a
				 * Param's collation, ie it's not safe for it to have a
				 * non-default collation.
				 */
				if (bms_is_member(var->varno, glob_cxt->relids) &&
					var->varlevelsup == 0 && var->varattno > 0)
				{
					/* Var belongs to foreign table */
					/* Else check the collation */
					collation = var->varcollid;
					state = OidIsValid(collation) ? FDW_COLLATE_SAFE : FDW_COLLATE_NONE;

					/* Mysql do not have Array data type */
					if (type_is_array(var->vartype))
						elog(ERROR, "mysql_fdw: Not support array data type\n");

				}
				else
				{
					/* Var belongs to some other table */
					if (var->varcollid != InvalidOid &&
						var->varcollid != DEFAULT_COLLATION_OID)
						return false;

					/*
					 * System columns should not be sent to the remote, since
					 * we don't make any effort to ensure that local and
					 * remote values match (tableoid, in particular, almost
					 * certainly doesn't match).
					 */
					if (var->varattno < 0)
						return false;

					/* We can consider that it doesn't set collation */
					collation = InvalidOid;
					state = FDW_COLLATE_NONE;
				}
			}
			break;
		case T_Const:
			{
				Const	   *c = (Const *) node;
				char	   *type_name;

				/*
				 * Get type name based on the const value. If the type name is
				 * "mysql_string_type" or "time_unit", allow it to push down
				 * to remote.
				 */
				type_name = mysql_deparse_type_name(c->consttype, c->consttypmod);
				if (strcmp(type_name, "public.mysql_string_type") == 0 ||
					strcmp(type_name, "public.time_unit") == 0 ||
					strcmp(type_name, "public.path_value[]") == 0)
				{
					check_type = false;
				}

				/*
				 * If the constant has non default collation, either it's of a
				 * non-built in type, or it reflects folding of a CollateExpr;
				 * either way, it's unsafe to send to the remote.
				 */
				if (c->constcollid != InvalidOid &&
					c->constcollid != DEFAULT_COLLATION_OID)
					return false;

				/* Otherwise, we can consider that it doesn't set collation */
				collation = InvalidOid;
				state = FDW_COLLATE_NONE;
			}
			break;
		case T_Param:
			{
				Param	   *p = (Param *) node;

				/*
				 * boolean op_flag is used to check operator If value op_flag
				 * is true (operator are >, <, <=, >=), we will not push down
				 * and vice versa
				 */
				if (inner_cxt.op_flag)
					return false;

				/*
				 * Collation rule is same as for Consts and non-foreign Vars.
				 */
				collation = p->paramcollid;
				if (collation == InvalidOid ||
					collation == DEFAULT_COLLATION_OID)
					state = FDW_COLLATE_NONE;
				else
					state = FDW_COLLATE_UNSAFE;
			}
			break;
#if PG_VERSION_NUM < 120000
		case T_ArrayRef:
			{
				ArrayRef   *ar = (ArrayRef *) node;
#else
		case T_SubscriptingRef:
			{
				SubscriptingRef *ar = (SubscriptingRef *) node;
#endif

				Assert(list_length(ar->refupperindexpr) > 0);
				/* Assignment should not be in restrictions. */
				if (ar->refassgnexpr != NULL)
					return false;

#if PG_VERSION_NUM >= 140000

				/*
				 * Recurse into the remaining subexpressions.  The container
				 * subscripts will not affect collation of the SubscriptingRef
				 * result, so do those first and reset inner_cxt afterwards.
				 */
#else

				/*
				 * Recurse to remaining subexpressions.  Since the array
				 * subscripts must yield (noncollatable) integers, they won't
				 * affect the inner_cxt state.
				 */
#endif
				/* Allow 1-D subcription, other case does not push down */
				if (list_length(ar->refupperindexpr) > 1)
					return false;

				if (!foreign_expr_walker((Node *) ar->refupperindexpr,
										 glob_cxt, &inner_cxt))
					return false;

				/* Disable slice by checking reflowerindexpr [:] */
				if (ar->reflowerindexpr)
					return false;

#if PG_VERSION_NUM >= 140000
				inner_cxt.collation = InvalidOid;
				inner_cxt.state = FDW_COLLATE_NONE;
#endif
				/* Disble subcripting for Var, eg: c1[1] by checking T_Var */
				if (!foreign_expr_walker((Node *) ar->refexpr,
										 glob_cxt, &inner_cxt))
					return false;
#if PG_VERSION_NUM >= 140000

				/*
				 * Container subscripting typically yields same collation as
				 * refexpr's, but in case it doesn't, use same logic as for
				 * function nodes.
				 */
#else

				/*
				 * Container subscripting should yield same collation as
				 * input, but for safety use same logic as for function nodes.
				 */
#endif
				collation = ar->refcollid;
				if (collation == InvalidOid)
					state = FDW_COLLATE_NONE;
				else if (inner_cxt.state == FDW_COLLATE_SAFE &&
						 collation == inner_cxt.collation)
					state = FDW_COLLATE_SAFE;
				else
					state = FDW_COLLATE_UNSAFE;
			}
			break;
		case T_FuncExpr:
			{
				FuncExpr   *fe = (FuncExpr *) node;
				char	   *funcname = NULL;
				Node	   *node_arg = (Node *) fe->args;
				bool		is_need_var = true;
				bool		is_cast_functions = false;
				bool		is_unique_func = false;
				bool		is_common_function = false;

				/*
				 * If function used by the expression is not built-in, it
				 * can't be sent to remote because it might have incompatible
				 * semantics on remote side.
				 */
				funcname = get_func_name(fe->funcid);

				/* check NULL for funcname */
				if (funcname == NULL)
					elog(ERROR, "cache lookup failed for function %u", fe->funcid);

				/* is cast functions */
				if (exist_in_function_list(funcname, CastFunction))
				{
					is_cast_functions = true;
				}
				else
				{
					/* Mysql unique functions */
					if (mysql_is_unique_func(fe->funcid, funcname))
						is_unique_func = true;

					/* Mysql supported builtin functions */
					if (mysql_is_supported_builtin_func(fe->funcid, funcname))
						is_common_function = true;
				}

				/* Does not push down function to mysql if not */
				if (!is_cast_functions &&
					!is_unique_func &&
					!is_common_function)
					return false;

				/* inner function can skip numeric cast if any */
				if (is_common_function || is_unique_func)
					inner_cxt.can_skip_cast = true;

				if (strcmp(funcname, "match_against") == 0 && IsA(node_arg, List))
				{
					List	   *l = (List *) node_arg;
					ListCell   *lc = list_head(l);

					node_arg = (Node *) lfirst(lc);
					if (IsA(node_arg, ArrayCoerceExpr))
					{
						node_arg = (Node *) ((ArrayCoerceExpr *) node_arg)->arg;
					}
				}

				if (strcmp(funcname, "json_extract") == 0 ||
					strcmp(funcname, "json_value") == 0 ||
					strcmp(funcname, "json_unquote") == 0 ||
					strcmp(funcname, "convert") == 0)
				{
					outer_cxt->can_use_outercast = true;
				}

				if (is_unique_func || is_common_function)
				{
					inner_cxt.can_skip_cast = true;
					outer_cxt->can_pushdown_function = true;
					inner_cxt.can_pushdown_function = true;
					is_need_var = false;
				}

				/*
				 * Recurse to input subexpressions.
				 */
				if (!foreign_expr_walker((Node *) node_arg,
										 glob_cxt, &inner_cxt))
					return false;

				if (inner_cxt.can_pushdown_function == true)
					outer_cxt->can_pushdown_function = true;

				/* Accept type cast functions if outer is specific functions */
				if (is_cast_functions == true && strcmp(funcname, "interval") != 0)
				{
					if (inner_cxt.can_use_outercast == true)
					{
						if (list_length(fe->args) > 1)
						{
							/* outer/inner type modifier can pushdown */
							if ((strcmp(funcname, "numeric") == 0 ||
								 strcmp(funcname, "bpchar") == 0 ||
								 strcmp(funcname, "varchar") == 0) ||
								strcmp(funcname, "time") == 0 ||
								strcmp(funcname, "timetz") == 0 ||
								strcmp(funcname, "timestamp") == 0 ||
								strcmp(funcname, "timestamptz") == 0)
							{
								outer_cxt->can_pushdown_function = true;
								is_need_var = false;
							}
							else
								return false;
						}
					}
					else if (fe->funcformat == COERCE_IMPLICIT_CAST)
					{
						outer_cxt->can_skip_cast = true;
						is_need_var = false;
					}
					else if (outer_cxt->can_skip_cast == false)
						return false;
				}

				if (!is_need_var)
				{
					collation = InvalidOid;
					state = FDW_COLLATE_NONE;
					check_type = false;
				}
				else
				{
					/*
					 * If function's input collation is not derived from a
					 * foreign Var, it can't be sent to remote.
					 */
					if (fe->inputcollid == InvalidOid)
						 /* OK, inputs are all noncollatable */ ;
					else if (inner_cxt.state != FDW_COLLATE_SAFE ||
							 fe->inputcollid != inner_cxt.collation)
						return false;

					/*
					 * Detect whether node is introducing a collation not
					 * derived from a foreign Var.  (If so, we just mark it
					 * unsafe for now rather than immediately returning false,
					 * since the parent node might not care.)
					 */
					collation = fe->funccollid;
					if (collation == InvalidOid)
						state = FDW_COLLATE_NONE;
					else if (inner_cxt.state == FDW_COLLATE_SAFE &&
							 collation == inner_cxt.collation)
						state = FDW_COLLATE_SAFE;
					else
						state = FDW_COLLATE_UNSAFE;
				}
			}
			break;
		case T_OpExpr:
		case T_DistinctExpr:	/* struct-equivalent to OpExpr */
			{
				OpExpr	   *oe = (OpExpr *) node;
				char	   *oprname;
				Form_pg_operator form;

				/*
				 * Similarly, only built-in operators can be sent to remote.
				 * (If the operator is, surely its underlying function is
				 * too.)
				 */
				if (!mysql_is_builtin(oe->opno))
					return false;

				tuple = SearchSysCache1(OPEROID, ObjectIdGetDatum(oe->opno));
				if (!HeapTupleIsValid(tuple))
					elog(ERROR, "cache lookup failed for operator %u", oe->opno);
				form = (Form_pg_operator) GETSTRUCT(tuple);

				/* Get operation name */
				oprname = pstrdup(NameStr(form->oprname));
				ReleaseSysCache(tuple);

				/* MySQL does not support ! */
				if (strcmp(oprname, "!") == 0)
					return false;

				/*
				 * Recurse to input subexpressions.
				 */
				if (!foreign_expr_walker((Node *) oe->args,
										 glob_cxt, &inner_cxt))
					return false;

				if (inner_cxt.can_pushdown_function == false)
				{
					/*
					 * If operator's input collation is not derived from a
					 * foreign Var, it can't be sent to remote.
					 */
					if (oe->inputcollid == InvalidOid)
						 /* OK, inputs are all noncollatable */ ;
					else if (inner_cxt.state != FDW_COLLATE_SAFE ||
							 oe->inputcollid != inner_cxt.collation)
						return false;
				}
				else
				{
					outer_cxt->can_pushdown_function = true;
				}

				/* Result-collation handling is same as for functions */
				collation = oe->opcollid;
				if (collation == InvalidOid)
					state = FDW_COLLATE_NONE;
				else if (inner_cxt.state == FDW_COLLATE_SAFE &&
						 collation == inner_cxt.collation)
					state = FDW_COLLATE_SAFE;
				else
					state = FDW_COLLATE_UNSAFE;
			}
			break;
		case T_ScalarArrayOpExpr:
			{
				ScalarArrayOpExpr *oe = (ScalarArrayOpExpr *) node;
				char	   *opname;

				opname = get_opname(oe->opno);

				/*
				 * Value opname which is represented for type of operator If
				 * ARRRAY has parameter is sub-query and operator are >, <,
				 * >=, <=, set value for op_flag boolean is true In these
				 * case, we do not push down
				 */
				if (strcmp(opname, "<") == 0 ||
					strcmp(opname, ">") == 0 ||
					strcmp(opname, "<=") == 0 ||
					strcmp(opname, ">=") == 0)
				{
					inner_cxt.op_flag = true;
				}

				/*
				 * Again, only built-in operators can be sent to remote.
				 */
				if (!mysql_is_builtin(oe->opno))
					return false;

				/*
				 * Recurse to input subexpressions.
				 */
				if (!foreign_expr_walker((Node *) oe->args,
										 glob_cxt, &inner_cxt))
					return false;

				inner_cxt.op_flag = false;

				/*
				 * If operator's input collation is not derived from a foreign
				 * Var, it can't be sent to remote.
				 */
				if (oe->inputcollid == InvalidOid)
					 /* OK, inputs are all noncollatable */ ;
				else if (inner_cxt.state != FDW_COLLATE_SAFE ||
						 oe->inputcollid != inner_cxt.collation)
					return false;

				/* Output is always boolean and so noncollatable. */
				collation = InvalidOid;
				state = FDW_COLLATE_NONE;
			}
			break;
		case T_RelabelType:
			{
				RelabelType *r = (RelabelType *) node;

				/*
				 * Recurse to input subexpression.
				 */
				if (!foreign_expr_walker((Node *) r->arg,
										 glob_cxt, &inner_cxt))
					return false;

				/*
				 * RelabelType must not introduce a collation not derived from
				 * an input foreign Var.
				 */
				collation = r->resultcollid;
				if (collation == InvalidOid)
					state = FDW_COLLATE_NONE;
				else if (inner_cxt.state == FDW_COLLATE_SAFE &&
						 collation == inner_cxt.collation)
					state = FDW_COLLATE_SAFE;
				else
					state = FDW_COLLATE_UNSAFE;
			}
			break;
		case T_BoolExpr:
			{
				BoolExpr   *b = (BoolExpr *) node;

				/*
				 * Recurse to input subexpressions.
				 */
				if (!foreign_expr_walker((Node *) b->args,
										 glob_cxt, &inner_cxt))
					return false;

				/* Output is always boolean and so noncollatable. */
				collation = InvalidOid;
				state = FDW_COLLATE_NONE;
			}
			break;
		case T_NullTest:
			{
				NullTest   *nt = (NullTest *) node;

				/*
				 * Recurse to input subexpressions.
				 */
				if (!foreign_expr_walker((Node *) nt->arg,
										 glob_cxt, &inner_cxt))
					return false;

				/* Output is always boolean and so noncollatable. */
				collation = InvalidOid;
				state = FDW_COLLATE_NONE;
			}
			break;
		case T_Aggref:
			{
				Aggref	   *agg = (Aggref *) node;
				ListCell   *lc;
				char	   *aggname = NULL;

				/* Not safe to pushdown when not in grouping context */
				if (!IS_UPPER_REL(glob_cxt->foreignrel))
					return false;

				/* Only non-split aggregates are pushable. */
				if (agg->aggsplit != AGGSPLIT_SIMPLE)
					return false;

				/* get function name */
				aggname = get_func_name(agg->aggfnoid);
				aggname = mysql_replace_function(aggname, NIL);

				if (!exist_in_function_list(aggname, MysqlUniqueAggFunction) &&
					!exist_in_function_list(aggname, MysqlSupportedBuiltinAggFunction))
					return false;

				/*
				 * Recurse to input args. aggdirectargs, aggorder and
				 * aggdistinct are all present in args, so no need to check
				 * their shippability explicitly.
				 */
				foreach(lc, agg->args)
				{
					Node	   *n = (Node *) lfirst(lc);

					/* If TargetEntry, extract the expression from it */
					if (IsA(n, TargetEntry))
					{
						TargetEntry *tle = (TargetEntry *) n;

						n = (Node *) tle->expr;
					}

					if (!foreign_expr_walker(n, glob_cxt, &inner_cxt))
						return false;
				}

				if (agg->aggorder)
				{
					/* We support ORDER BY inside these aggregate functions */
					if (!(strcmp(aggname, "group_concat") == 0 ||
						  strcmp(aggname, "json_arrayagg") == 0 ||
						  strcmp(aggname, "json_objectagg") == 0))
					{
						return false;
					}
				}

				if (agg->aggfilter)
				{
					return false;
				}

				/*
				 * If aggregate's input collation is not derived from a
				 * foreign Var, it can't be sent to remote.
				 */
				if (agg->inputcollid == InvalidOid)
					 /* OK, inputs are all noncollatable */ ;
				else if (inner_cxt.state != FDW_COLLATE_SAFE ||
						 agg->inputcollid != inner_cxt.collation)
					return false;

				/*
				 * Detect whether node is introducing a collation not derived
				 * from a foreign Var.  (If so, we just mark it unsafe for now
				 * rather than immediately returning false, since the parent
				 * node might not care.)
				 */
				collation = agg->aggcollid;
				if (collation == InvalidOid)
					state = FDW_COLLATE_NONE;
				else if (inner_cxt.state == FDW_COLLATE_SAFE &&
						 collation == inner_cxt.collation)
					state = FDW_COLLATE_SAFE;
				else if (collation == DEFAULT_COLLATION_OID)
					state = FDW_COLLATE_NONE;
				else
					state = FDW_COLLATE_UNSAFE;
			}
			break;
		case T_ArrayExpr:
			{
				ArrayExpr  *a = (ArrayExpr *) node;

				/*
				 * Recurse to input subexpressions.
				 */
				if (!foreign_expr_walker((Node *) a->elements,
										 glob_cxt, &inner_cxt))
					return false;

				/*
				 * ArrayExpr must not introduce a collation not derived from
				 * an input foreign Var.
				 */
				collation = a->array_collid;
				if (collation == InvalidOid)
					state = FDW_COLLATE_NONE;
				else if (inner_cxt.state == FDW_COLLATE_SAFE &&
						 collation == inner_cxt.collation)
					state = FDW_COLLATE_SAFE;
				else
					state = FDW_COLLATE_UNSAFE;
			}
			break;
		case T_List:
			{
				List	   *l = (List *) node;
				ListCell   *lc;

				/* inherit can_skip_cast flag */
				inner_cxt.can_skip_cast = outer_cxt->can_skip_cast;
				inner_cxt.can_pushdown_function = outer_cxt->can_pushdown_function;

				/*
				 * Recurse to component subexpressions.
				 */
				foreach(lc, l)
				{
					if (!foreign_expr_walker((Node *) lfirst(lc),
											 glob_cxt, &inner_cxt))
						return false;
				}

				if (inner_cxt.can_pushdown_function == true)
					outer_cxt->can_pushdown_function = true;

				if (inner_cxt.can_skip_cast == true)
					outer_cxt->can_skip_cast = true;

				if (inner_cxt.can_use_outercast == true)
					outer_cxt->can_use_outercast = true;

				/*
				 * When processing a list, collation state just bubbles up
				 * from the list elements.
				 */
				collation = inner_cxt.collation;
				state = inner_cxt.state;

				/* Don't apply exprType() to the list. */
				check_type = false;
			}
			break;
		case T_RowExpr:
			/* Enable to support count(expr, [expr]) */
			{
				collation = InvalidOid;
				state = FDW_COLLATE_NONE;
			}
			break;
		case T_CoerceViaIO:
			{
				/* Accept cast function outer of json_extract and json_value */
				CoerceViaIO *c = (CoerceViaIO *) node;

				if (IsA(c->arg, FuncExpr))
				{
					FuncExpr   *fe = (FuncExpr *) c->arg;
					char	   *func_name;

					func_name = get_func_name(fe->funcid);

					if (!(strcmp(func_name, "json_extract") == 0 ||
						  strcmp(func_name, "json_value") == 0 ||
						  strcmp(func_name, "json_unquote") == 0 ||
						  strcmp(func_name, "convert") == 0))
						return false;

					if (!foreign_expr_walker((Node *) c->arg,
											 glob_cxt, &inner_cxt))
						return false;

					if (inner_cxt.can_pushdown_function == true)
						outer_cxt->can_pushdown_function = true;

					if (inner_cxt.can_use_outercast == true)
						outer_cxt->can_use_outercast = true;
				}
				else
				{
					return false;
				}

				/* Output is always boolean and so noncollatable. */
				collation = InvalidOid;
				state = FDW_COLLATE_NONE;
				check_type = false;
			}
			break;
		case T_FieldSelect:

			/*
			 * Allow pushdown FieldSelect to support accessing value of record
			 * of json_table functions
			 */
			{
				if (!(glob_cxt->foreignrel->reloptkind == RELOPT_BASEREL ||
					  glob_cxt->foreignrel->reloptkind == RELOPT_OTHER_MEMBER_REL))
					return false;

				collation = InvalidOid;
				state = FDW_COLLATE_NONE;
				check_type = false;
			}
			break;
		default:

			/*
			 * If it's anything else, assume it's unsafe.  This list can be
			 * expanded later, but don't forget to add deparse support below.
			 */
			return false;
	}

	/*
	 * If result type of given expression is not built-in, it can't be sent to
	 * remote because it might have incompatible semantics on remote side.
	 */
	if (check_type && !mysql_is_builtin(exprType(node)))
		return false;

	/*
	 * Now, merge my collation information into my parent's state.
	 */
	if (state > outer_cxt->state)
	{
		/* Override previous parent state */
		outer_cxt->collation = collation;
		outer_cxt->state = state;
	}
	else if (state == outer_cxt->state)
	{
		/* Merge, or detect error if there's a collation conflict */
		switch (state)
		{
			case FDW_COLLATE_NONE:
				/* Nothing + nothing is still nothing */
				break;
			case FDW_COLLATE_SAFE:
				if (collation != outer_cxt->collation)
				{
					/*
					 * Non-default collation always beats default.
					 */
					if (outer_cxt->collation == DEFAULT_COLLATION_OID)
					{
						/* Override previous parent state */
						outer_cxt->collation = collation;
					}
					else if (collation != DEFAULT_COLLATION_OID)
					{
						/*
						 * Conflict; show state as indeterminate.  We don't
						 * want to "return false" right away, since parent
						 * node might not care about collation.
						 */
						outer_cxt->state = FDW_COLLATE_UNSAFE;
					}
				}
				break;
			case FDW_COLLATE_UNSAFE:
				/* We're still conflicted ... */
				break;
		}
	}

	/* It looks OK */
	return true;
}

/*
 * Returns true if given expr is safe to evaluate on the foreign server.
 */
bool
mysql_is_foreign_expr(PlannerInfo *root, RelOptInfo *baserel, Expr *expr)
{
	foreign_glob_cxt glob_cxt;
	foreign_loc_cxt loc_cxt;
	MySQLFdwRelationInfo *fpinfo = (MySQLFdwRelationInfo *) (baserel->fdw_private);

	/*
	 * Check that the expression consists of nodes that are safe to execute
	 * remotely.
	 */
	glob_cxt.root = root;
	glob_cxt.foreignrel = baserel;

	/*
	 * For an upper relation, use relids from its underneath scan relation,
	 * because the upperrel's own relids currently aren't set to anything
	 * meaningful by the core code.  For other relation, use their own relids.
	 */
	if (IS_UPPER_REL(baserel))
		glob_cxt.relids = fpinfo->outerrel->relids;
	else
		glob_cxt.relids = baserel->relids;

	loc_cxt.collation = InvalidOid;
	loc_cxt.state = FDW_COLLATE_NONE;
	loc_cxt.can_skip_cast = false;
	loc_cxt.op_flag = false;
	if (!foreign_expr_walker((Node *) expr, &glob_cxt, &loc_cxt))
		return false;

	/*
	 * If the expression has a valid collation that does not arise from a
	 * foreign var, the expression can not be sent over.
	 */
	if (loc_cxt.state == FDW_COLLATE_UNSAFE)
		return false;

	/* Expressions examined here should be boolean, ie noncollatable */
	/* Assert(loc_cxt.collation == InvalidOid); */
	/* Assert(loc_cxt.state == FDW_COLLATE_NONE); */

	/* OK to evaluate on the remote server */
	return true;
}

/*
 * Returns true if given expr is something we'd have to send the value of
 * to the foreign server.
 *
 * This should return true when the expression is a shippable node that
 * deparseExpr would add to context->params_list.  Note that we don't care
 * if the expression *contains* such a node, only whether one appears at top
 * level.  We need this to detect cases where setrefs.c would recognize a
 * false match between an fdw_exprs item (which came from the params_list)
 * and an entry in fdw_scan_tlist (which we're considering putting the given
 * expression into).
 */
bool
mysql_is_foreign_param(PlannerInfo *root,
					   RelOptInfo *baserel,
					   Expr *expr)
{
	if (expr == NULL)
		return false;

	switch (nodeTag(expr))
	{
		case T_Var:
			{
				/* It would have to be sent unless it's a foreign Var */
				Var		   *var = (Var *) expr;
				MySQLFdwRelationInfo *fpinfo = (MySQLFdwRelationInfo *) (baserel->fdw_private);
				Relids		relids;

				if (IS_UPPER_REL(baserel))
					relids = fpinfo->outerrel->relids;
				else
					relids = baserel->relids;

				if (bms_is_member(var->varno, relids) && var->varlevelsup == 0)
					return false;	/* foreign Var, so not a param */
				else
					return true;	/* it'd have to be a param */
				break;
			}
		case T_Param:
			/* Params always have to be sent to the foreign server */
			return true;
		default:
			break;
	}
	return false;
}

/*****************************************************************************
 *		Check clauses for immutable functions
 *****************************************************************************/

/*
 * mysql_contain_functions
 * Recursively search for immutable, stable and volatile functions within a clause.
 *
 * Returns true if any function (or operator implemented by a function) is found.
 *
 * We will recursively look into TargetEntry exprs.
 */
static bool
mysql_contain_functions(Node *clause)
{
	return mysql_contain_functions_walker(clause, NULL);
}

static bool
mysql_contain_functions_walker(Node *node, void *context)
{
	if (node == NULL)
		return false;
	/* Check for functions in node itself */
	if (nodeTag(node) == T_FuncExpr)
	{
		return true;
	}

	/*
	 * It should be safe to treat MinMaxExpr as immutable, because it will
	 * depend on a non-cross-type btree comparison function, and those should
	 * always be immutable.  Treating XmlExpr as immutable is more dubious,
	 * and treating CoerceToDomain as immutable is outright dangerous.  But we
	 * have done so historically, and changing this would probably cause more
	 * problems than it would fix.  In practice, if you have a non-immutable
	 * domain constraint you are in for pain anyhow.
	 */

	/* Recurse to check arguments */
	if (IsA(node, Query))
	{
		/* Recurse into subselects */
		return query_tree_walker((Query *) node,
								 mysql_contain_functions_walker,
								 context, 0);
	}
	return expression_tree_walker(node, mysql_contain_functions_walker,
								  context);
}

/*
 * Returns true if given tlist is safe to evaluate on the foreign server.
 */
bool
mysql_is_foreign_function_tlist(PlannerInfo *root,
								RelOptInfo *baserel,
								List *tlist)
{
	foreign_glob_cxt glob_cxt;
	foreign_loc_cxt loc_cxt;
	MySQLFdwRelationInfo *fpinfo = (MySQLFdwRelationInfo *) (baserel->fdw_private);
	ListCell   *lc;
	bool		is_contain_function;

	/*
	 * Check that the expression consists of any immutable function.
	 */
	is_contain_function = false;
	foreach(lc, tlist)
	{
		TargetEntry *tle = lfirst_node(TargetEntry, lc);

		if (mysql_contain_functions((Node *) tle->expr))
		{
			is_contain_function = true;
			break;
		}
	}

	if (!is_contain_function)
		return false;

	/*
	 * Check that the expression consists of nodes that are safe to execute
	 * remotely.
	 */
	foreach(lc, tlist)
	{
		TargetEntry *tle = lfirst_node(TargetEntry, lc);

		glob_cxt.root = root;
		glob_cxt.foreignrel = baserel;

		/*
		 * For an upper relation, use relids from its underneath scan
		 * relation, because the upperrel's own relids currently aren't set to
		 * anything meaningful by the cor  e code.For other relation, use
		 * their own relids.
		 */
		if (IS_UPPER_REL(baserel))
			glob_cxt.relids = fpinfo->outerrel->relids;
		else
			glob_cxt.relids = baserel->relids;

		loc_cxt.collation = InvalidOid;
		loc_cxt.state = FDW_COLLATE_NONE;
		loc_cxt.can_skip_cast = false;
		loc_cxt.op_flag = false;
		loc_cxt.can_pushdown_function = false;

		if (!foreign_expr_walker((Node *) tle->expr, &glob_cxt, &loc_cxt))
			return false;

		/*
		 * If the expression has a valid collation that does not arise from a
		 * foreign var, the expression can not be sent over.
		 */
		if (loc_cxt.state == FDW_COLLATE_UNSAFE)
			return false;

		/*
		 * An expression which includes any mutable functions can't be sent
		 * over because its result is not stable.  For example, sending now()
		 * remote side could cause confusion from clock offsets.  Future
		 * versions might be able to make this choice with more granularity.
		 * (We check this last because it requires a lot of expensive catalog
		 * lookups.)
		 */
		if (!IsA(tle->expr, FieldSelect))
		{
			if (loc_cxt.can_pushdown_function == false &&
				contain_mutable_functions((Node *) tle->expr))
			{
				return false;
			}
		}
	}

	/* OK for the target list with functions to evaluate on the remote server */
	return true;
}

/* Output join name for given join type */
const char *
mysql_get_jointype_name(JoinType jointype)
{
	switch (jointype)
	{
		case JOIN_INNER:
			return "INNER";

		case JOIN_LEFT:
			return "LEFT";

		case JOIN_RIGHT:
			return "RIGHT";

		case JOIN_FULL:
			return "FULL";

		default:
			/* Shouldn't come here, but protect from buggy code. */
			elog(ERROR, "unsupported join type %d", jointype);
	}

	/* Keep compiler happy */
	return NULL;
}

/*
 * Deparse given targetlist and append it to context->buf.
 *
 * tlist is list of TargetEntry's which in turn contain Var nodes.
 *
 * retrieved_attrs is the list of continuously increasing integers starting
 * from 1. It has same number of entries as tlist.
 *
 * This is used for both SELECT and RETURNING targetlists; the is_returning
 * parameter is true only for a RETURNING targetlist.
 */
static void
mysql_deparse_explicit_target_list(List *tlist,
								   bool is_returning,
								   List **retrieved_attrs,
								   deparse_expr_cxt *context)
{
	ListCell   *lc;
	StringInfo	buf = context->buf;
	int			i = 0;

	*retrieved_attrs = NIL;

	foreach(lc, tlist)
	{
		TargetEntry *tle = lfirst_node(TargetEntry, lc);

		if (i > 0)
			appendStringInfoString(buf, ", ");
		else if (is_returning)
			appendStringInfoString(buf, " RETURNING ");

		deparseExpr((Expr *) tle->expr, context);

		*retrieved_attrs = lappend_int(*retrieved_attrs, i + 1);
		i++;
	}

	if (i == 0 && !is_returning)
		appendStringInfoString(buf, "NULL");
}

/*
 * Emit expressions specified in the given relation's reltarget.
 *
 * This is used for deparsing the given relation as a subquery.
 */
static void
mysql_deparse_subquery_target_list(deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	RelOptInfo *foreignrel = context->foreignrel;
	bool		first;
	ListCell   *lc;

	/* Should only be called in these cases. */
	Assert(IS_SIMPLE_REL(foreignrel) || IS_JOIN_REL(foreignrel));

	first = true;
	foreach(lc, foreignrel->reltarget->exprs)
	{
		Node	   *node = (Node *) lfirst(lc);

		if (!first)
			appendStringInfoString(buf, ", ");
		first = false;

		deparseExpr((Expr *) node, context);
	}

	/* Don't generate bad syntax if no expressions */
	if (first)
		appendStringInfoString(buf, "NULL");
}


/*
 * Examine each qual clause in input_conds, and classify them into two groups,
 * which are returned as two lists:
 *	- remote_conds contains expressions that can be evaluated remotely
 *	- local_conds contains expressions that can't be evaluated remotely
 */
void
mysql_classify_conditions(PlannerInfo *root,
						  RelOptInfo *baserel,
						  List *input_conds,
						  List **remote_conds,
						  List **local_conds)
{
	ListCell   *lc;

	*remote_conds = NIL;
	*local_conds = NIL;

	foreach(lc, input_conds)
	{
		RestrictInfo *ri = lfirst_node(RestrictInfo, lc);

		if (mysql_is_foreign_expr(root, baserel, ri->clause))
			*remote_conds = lappend(*remote_conds, ri);
		else
			*local_conds = lappend(*local_conds, ri);
	}
}

/*
 * Construct FROM clause for given relation
 *
 * The function constructs ... JOIN ... ON ... for join relation. For a base
 * relation it just returns schema-qualified tablename, with the appropriate
 * alias if so requested.
 *
 * 'ignore_rel' is either zero or the RT index of a target relation.  In the
 * latter case the function constructs FROM clause of UPDATE or USING clause
 * of DELETE; it deparses the join relation as if the relation never contained
 * the target relation, and creates a List of conditions to be deparsed into
 * the top-level WHERE clause, which is returned to *ignore_conds.
 */
static void
mysql_deparse_from_expr_for_rel(StringInfo buf, PlannerInfo *root, RelOptInfo *foreignrel,
								bool use_alias, Index ignore_rel, List **ignore_conds,
								List **params_list)
{
	MySQLFdwRelationInfo *fpinfo = (MySQLFdwRelationInfo *) foreignrel->fdw_private;

	if (IS_JOIN_REL(foreignrel))
	{
		StringInfoData join_sql_o;
		StringInfoData join_sql_i;
		RelOptInfo *outerrel = fpinfo->outerrel;
		RelOptInfo *innerrel = fpinfo->innerrel;
		bool		outerrel_is_target = false;
		bool		innerrel_is_target = false;

		if (ignore_rel > 0 && bms_is_member(ignore_rel, foreignrel->relids))
		{
			/*
			 * If this is an inner join, add joinclauses to *ignore_conds and
			 * set it to empty so that those can be deparsed into the WHERE
			 * clause.  Note that since the target relation can never be
			 * within the nullable side of an outer join, those could safely
			 * be pulled up into the WHERE clause (see foreign_join_ok()).
			 * Note also that since the target relation is only inner-joined
			 * to any other relation in the query, all conditions in the join
			 * tree mentioning the target relation could be deparsed into the
			 * WHERE clause by doing this recursively.
			 */
			if (fpinfo->jointype == JOIN_INNER)
			{
				*ignore_conds = list_concat(*ignore_conds,
#if PG_VERSION_NUM < 130000
											list_copy(fpinfo->joinclauses));
#else
											fpinfo->joinclauses);
#endif
				fpinfo->joinclauses = NIL;
			}

			/*
			 * Check if either of the input relations is the target relation.
			 */
			if (outerrel->relid == ignore_rel)
				outerrel_is_target = true;
			else if (innerrel->relid == ignore_rel)
				innerrel_is_target = true;
		}

		/* Deparse outer relation if not the target relation. */
		if (!outerrel_is_target)
		{
			initStringInfo(&join_sql_o);
			mysql_deparse_range_tbl_ref(&join_sql_o, root, outerrel,
										fpinfo->make_outerrel_subquery,
										ignore_rel, ignore_conds, params_list);

			/*
			 * If inner relation is the target relation, skip deparsing it.
			 * Note that since the join of the target relation with any other
			 * relation in the query is an inner join and can never be within
			 * the nullable side of an outer join, the join could be
			 * interchanged with higher-level joins (cf. identity 1 on outer
			 * join reordering shown in src/backend/optimizer/README), which
			 * means it's safe to skip the target-relation deparsing here.
			 */
			if (innerrel_is_target)
			{
				Assert(fpinfo->jointype == JOIN_INNER);
				Assert(fpinfo->joinclauses == NIL);
				appendBinaryStringInfo(buf, join_sql_o.data, join_sql_o.len);
				return;
			}
		}

		/* Deparse inner relation if not the target relation. */
		if (!innerrel_is_target)
		{
			initStringInfo(&join_sql_i);
			mysql_deparse_range_tbl_ref(&join_sql_i, root, innerrel,
										fpinfo->make_innerrel_subquery,
										ignore_rel, ignore_conds, params_list);

			/*
			 * If outer relation is the target relation, skip deparsing it.
			 * See the above note about safety.
			 */
			if (outerrel_is_target)
			{
				Assert(fpinfo->jointype == JOIN_INNER);
				Assert(fpinfo->joinclauses == NIL);
				appendBinaryStringInfo(buf, join_sql_i.data, join_sql_i.len);
				return;
			}
		}

		/* Neither of the relations is the target relation. */
		Assert(!outerrel_is_target && !innerrel_is_target);

		/*
		 * For a join relation FROM clause entry is deparsed as
		 *
		 * ((outer relation) <join type> (inner relation) ON (joinclauses))
		 */
		appendStringInfo(buf, "(%s %s JOIN %s ON ", join_sql_o.data,
						 mysql_get_jointype_name(fpinfo->jointype), join_sql_i.data);

		/* Append join clause; (TRUE) if no join clause */
		if (fpinfo->joinclauses)
		{
			deparse_expr_cxt context;

			context.buf = buf;
			context.foreignrel = foreignrel;
			context.scanrel = foreignrel;
			context.root = root;
			context.params_list = params_list;
			context.is_not_add_array = false;
			context.can_convert_time = false;
			context.json_table_expr = NULL;

			appendStringInfoChar(buf, '(');
			mysql_append_conditions(fpinfo->joinclauses, &context);
			appendStringInfoChar(buf, ')');
		}
		else
			appendStringInfoString(buf, "(TRUE)");

		/* End the FROM clause entry. */
		appendStringInfoChar(buf, ')');
	}
	else
	{
		RangeTblEntry *rte = planner_rt_fetch(foreignrel->relid, root);

		/*
		 * Core code already has some lock on each rel being planned, so we
		 * can use NoLock here.
		 */
		Relation	rel;

		rel = table_open(rte->relid, NoLock);

		mysql_deparse_relation(buf, rel);

		/*
		 * Add a unique alias to avoid any conflict in relation names due to
		 * pulled up subqueries in the query being built for a pushed down
		 * join.
		 */
		if (use_alias)
			appendStringInfo(buf, " %s%d", REL_ALIAS_PREFIX, foreignrel->relid);

		table_close(rel, NoLock);
	}
}

/*
 * Append FROM clause entry for the given relation into buf.
 */
static void
mysql_deparse_range_tbl_ref(StringInfo buf, PlannerInfo *root, RelOptInfo *foreignrel,
							bool make_subquery, Index ignore_rel, List **ignore_conds,
							List **params_list)
{
	MySQLFdwRelationInfo *fpinfo = (MySQLFdwRelationInfo *) foreignrel->fdw_private;

	/* Should only be called in these cases. */
	Assert(IS_SIMPLE_REL(foreignrel) || IS_JOIN_REL(foreignrel));

	Assert(fpinfo->local_conds == NIL);

	/* If make_subquery is true, deparse the relation as a subquery. */
	if (make_subquery)
	{
		List	   *retrieved_attrs;
		int			ncols;

		/*
		 * The given relation shouldn't contain the target relation, because
		 * this should only happen for input relations for a full join, and
		 * such relations can never contain an UPDATE/DELETE target.
		 */
		Assert(ignore_rel == 0 ||
			   !bms_is_member(ignore_rel, foreignrel->relids));

		/* Deparse the subquery representing the relation. */
		appendStringInfoChar(buf, '(');
		mysql_deparse_select_stmt_for_rel(buf, root, foreignrel, NIL,
										  fpinfo->remote_conds, NIL,
										  false, false, true,
										  &retrieved_attrs, params_list);
		appendStringInfoChar(buf, ')');

		/* Append the relation alias. */
		appendStringInfo(buf, " %s%d", SUBQUERY_REL_ALIAS_PREFIX,
						 fpinfo->relation_index);

		/*
		 * Append the column aliases if needed.  Note that the subquery emits
		 * expressions specified in the relation's reltarget (see
		 * deparseSubqueryTargetList).
		 */
		ncols = list_length(foreignrel->reltarget->exprs);
		if (ncols > 0)
		{
			int			i;

			appendStringInfoChar(buf, '(');
			for (i = 1; i <= ncols; i++)
			{
				if (i > 1)
					appendStringInfoString(buf, ", ");

				appendStringInfo(buf, "%s%d", SUBQUERY_COL_ALIAS_PREFIX, i);
			}
			appendStringInfoChar(buf, ')');
		}
	}
	else
		mysql_deparse_from_expr_for_rel(buf, root, foreignrel, true, ignore_rel,
										ignore_conds, params_list);
}

/*
 * Deparse conditions from the provided list and append them to buf.
 *
 * The conditions in the list are assumed to be ANDed. This function is used to
 * deparse WHERE clauses, JOIN .. ON clauses and HAVING clauses.
 *
 * Depending on the caller, the list elements might be either RestrictInfos
 * or bare clauses.
 */
static void
mysql_append_conditions(List *exprs, deparse_expr_cxt *context)
{
	ListCell   *lc;
	bool		is_first = true;
	StringInfo	buf = context->buf;

	foreach(lc, exprs)
	{
		Expr	   *expr = (Expr *) lfirst(lc);

		/* Extract clause from RestrictInfo, if required */
		if (IsA(expr, RestrictInfo))
			expr = ((RestrictInfo *) expr)->clause;

		/* Connect expressions with "AND" and parenthesize each condition. */
		if (!is_first)
			appendStringInfoString(buf, " AND ");

		appendStringInfoChar(buf, '(');
		deparseExpr(expr, context);
		appendStringInfoChar(buf, ')');

		is_first = false;
	}

}

/*
 * Deparse SELECT statement for given relation into buf.
 *
 * tlist contains the list of desired columns to be fetched from foreign server.
 * For a base relation fpinfo->attrs_used is used to construct SELECT clause,
 * hence the tlist is ignored for a base relation.
 *
 * remote_conds is the list of conditions to be deparsed into the WHERE clause
 * (or, in the case of upper relations, into the HAVING clause).
 *
 * If params_list is not NULL, it receives a list of Params and other-relation
 * Vars used in the clauses; these values must be transmitted to the remote
 * server as parameter values.
 *
 * If params_list is NULL, we're generating the query for EXPLAIN purposes,
 * so Params and other-relation Vars should be replaced by dummy values.
 *
 * pathkeys is the list of pathkeys to order the result by.
 *
 * is_subquery is the flag to indicate whether to deparse the specified
 * relation as a subquery.
 *
 * List of columns selected is returned in retrieved_attrs.
 */
void
mysql_deparse_select_stmt_for_rel(StringInfo buf, PlannerInfo *root, RelOptInfo *rel,
								  List *tlist, List *remote_conds, List *pathkeys,
								  bool has_final_sort, bool has_limit, bool is_subquery,
								  List **retrieved_attrs, List **params_list)
{
	deparse_expr_cxt context;
	MySQLFdwRelationInfo *fpinfo = (MySQLFdwRelationInfo *) rel->fdw_private;
	List	   *quals;

	/*
	 * We handle relations for foreign tables, joins between those and upper
	 * relations.
	 */
	Assert(IS_JOIN_REL(rel) || IS_SIMPLE_REL(rel) || IS_UPPER_REL(rel));

	/* Fill portions of context common to upper, join and base relation */
	context.buf = buf;
	context.root = root;
	context.foreignrel = rel;
	context.scanrel = IS_UPPER_REL(rel) ? fpinfo->outerrel : rel;
	context.params_list = params_list;
	context.can_convert_time = false;
	context.is_not_distinct_op = false;
	context.is_not_add_array = false;
	context.can_convert_unit_arg = false;
	context.can_skip_cast = false;
	context.json_table_expr = NULL;
	context.can_skip_convert_unit_arg = false;

	/* Construct SELECT clause */
	mysql_deparse_select_sql(tlist, is_subquery, retrieved_attrs, &context);

	/*
	 * For upper relations, the WHERE clause is built from the remote
	 * conditions of the underlying scan relation; otherwise, we can use the
	 * supplied list of remote conditions directly.
	 */
	if (IS_UPPER_REL(rel))
	{
		MySQLFdwRelationInfo *ofpinfo;

		ofpinfo = (MySQLFdwRelationInfo *) fpinfo->outerrel->fdw_private;
		quals = ofpinfo->remote_conds;
	}
	else
		quals = remote_conds;

	/* Construct FROM and WHERE clauses */
	mysql_deparse_from_expr(quals, &context);

	if (IS_UPPER_REL(rel))
	{
		/* Append GROUP BY clause */
		mysql_append_group_by_clause(tlist, &context);

		/* Append HAVING clause */
		if (remote_conds)
		{
			appendStringInfoString(buf, " HAVING ");
			mysql_append_conditions(remote_conds, &context);
		}
	}

	/* Add ORDER BY clause if we found any useful pathkeys */
	if (pathkeys)
		mysql_append_order_by_clause(pathkeys, has_final_sort, &context);

	/* Add LIMIT clause if necessary */
	if (has_limit)
		mysql_append_limit_clause(&context);

	/* Add any necessary FOR UPDATE/SHARE. */
	mysql_deparse_locking_clause(&context);
}

/*
 * Construct a simple SELECT statement that retrieves desired columns
 * of the specified foreign table, and append it to "buf".  The output
 * contains just "SELECT ... ".
 *
 * We also create an integer List of the columns being retrieved, which is
 * returned to *retrieved_attrs, unless we deparse the specified relation
 * as a subquery.
 *
 * tlist is the list of desired columns.  is_subquery is the flag to
 * indicate whether to deparse the specified relation as a subquery.
 * Read prologue of deparseSelectStmtForRel() for details.
 */
static void
mysql_deparse_select_sql(List *tlist, bool is_subquery, List **retrieved_attrs,
						 deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	RelOptInfo *foreignrel = context->foreignrel;
	PlannerInfo *root = context->root;
	MySQLFdwRelationInfo *fpinfo = (MySQLFdwRelationInfo *) foreignrel->fdw_private;

	/*
	 * Construct SELECT list
	 */
	appendStringInfoString(buf, "SELECT ");

	if (is_subquery)
	{
		/*
		 * For a relation that is deparsed as a subquery, emit expressions
		 * specified in the relation's reltarget.  Note that since this is for
		 * the subquery, no need to care about *retrieved_attrs.
		 */
		mysql_deparse_subquery_target_list(context);
	}
	else if (IS_JOIN_REL(foreignrel) || IS_UPPER_REL(foreignrel))
	{
		/*
		 * For a join or upper relation the input tlist gives the list of
		 * columns required to be fetched from the foreign server.
		 */
		mysql_deparse_explicit_target_list(tlist, false, retrieved_attrs, context);
	}
	else
	{
		/*
		 * For a base relation fpinfo->attrs_used gives the list of columns
		 * required to be fetched from the foreign server.
		 */
		RangeTblEntry *rte = planner_rt_fetch(foreignrel->relid, root);

		/*
		 * Core code already has some lock on each rel being planned, so we
		 * can use NoLock here.
		 */
		Relation	rel;

		rel = table_open(rte->relid, NoLock);

		if (tlist != NULL)
		{
			ListCell   *cell;
			int			i = 0;
			bool		first;

			first = true;
			*retrieved_attrs = NIL;

			foreach(cell, tlist)
			{
				Expr	   *expr = ((TargetEntry *) lfirst(cell))->expr;

				if (!first)
					appendStringInfoString(buf, ", ");
				first = false;

				/* Deparse target list for push down */
				deparseExpr(expr, context);
				*retrieved_attrs = lappend_int(*retrieved_attrs, i + 1);
				i++;
			}
		}
		else
		{
			mysql_deparse_target_list(buf, rte, foreignrel->relid, rel,
									  fpinfo->attrs_used, false, retrieved_attrs);
		}

		table_close(rel, NoLock);
	}
}

/*
 * Build the targetlist for given relation to be deparsed as SELECT clause.
 *
 * The output targetlist contains the columns that need to be fetched from the
 * foreign server for the given relation.  If foreignrel is an upper relation,
 * then the output targetlist can also contain expressions to be evaluated on
 * foreign server.
 */
List *
mysql_build_tlist_to_deparse(RelOptInfo *foreignrel)
{
	List	   *tlist = NIL;
	MySQLFdwRelationInfo *fpinfo = (MySQLFdwRelationInfo *) foreignrel->fdw_private;
	ListCell   *lc;

	/*
	 * For an upper relation, we have already built the target list while
	 * checking shippability, so just return that.
	 */
	if (IS_UPPER_REL(foreignrel))
		return fpinfo->grouped_tlist;

	/*
	 * We require columns specified in foreignrel->reltarget->exprs and those
	 * required for evaluating the local conditions.
	 */
	tlist = add_to_flat_tlist(tlist,
							  pull_var_clause((Node *) foreignrel->reltarget->exprs,
											  PVC_RECURSE_PLACEHOLDERS));
	foreach(lc, fpinfo->local_conds)
	{
		RestrictInfo *rinfo = lfirst_node(RestrictInfo, lc);

		tlist = add_to_flat_tlist(tlist,
								  pull_var_clause((Node *) rinfo->clause,
												  PVC_RECURSE_PLACEHOLDERS));
	}

	return tlist;
}

/*
 * Deparse ORDER BY clause according to the given pathkeys for given base
 * relation. From given pathkeys expressions belonging entirely to the given
 * base relation are obtained and deparsed.
 */
static void
mysql_append_order_by_clause(List *pathkeys, bool has_final_sort,
							 deparse_expr_cxt *context)
{
	ListCell   *lcell;
	char	   *delim = " ";
	RelOptInfo *baserel = context->scanrel;
	StringInfo	buf = context->buf;

	/* Make sure any constants in the exprs are printed portably */

	appendStringInfoString(buf, " ORDER BY");
	foreach(lcell, pathkeys)
	{
		PathKey    *pathkey = lfirst(lcell);
		Expr	   *em_expr;

		if (has_final_sort)
		{
			/*
			 * By construction, context->foreignrel is the input relation to
			 * the final sort.
			 */
			em_expr = mysql_find_em_expr_for_input_target(context->root,
														  pathkey->pk_eclass,
														  context->foreignrel->reltarget);
		}
		else
			em_expr = mysql_find_em_expr_for_rel(pathkey->pk_eclass, baserel);

		Assert(em_expr != NULL);

		appendStringInfoString(buf, delim);
		deparseExpr(em_expr, context);

		delim = ", ";

		if (pathkey->pk_nulls_first)
			appendStringInfoString(buf, " IS NULL DESC");	/* NULLS FIRST */
		else
			appendStringInfoString(buf, " IS NULL ASC");	/* NULLS LAST */

		appendStringInfoString(buf, delim);
		deparseExpr(em_expr, context);

		if (pathkey->pk_strategy == BTLessStrategyNumber)
			appendStringInfoString(buf, " ASC");
		else
			appendStringInfoString(buf, " DESC");

	}
}

/*
 * Deparse LIMIT/OFFSET clause.
 */
static void
mysql_append_limit_clause(deparse_expr_cxt *context)
{
	PlannerInfo *root = context->root;
	StringInfo	buf = context->buf;

	if (root->parse->limitCount)
	{
		appendStringInfoString(buf, " LIMIT ");
		deparseExpr((Expr *) root->parse->limitCount, context);
	}
	if (root->parse->limitOffset)
	{
		appendStringInfoString(buf, " OFFSET ");
		deparseExpr((Expr *) root->parse->limitOffset, context);
	}

}

/*
 * Find an equivalence class member expression to be computed as a sort column
 * in the given target.
 */
Expr *
mysql_find_em_expr_for_input_target(PlannerInfo *root,
									EquivalenceClass *ec,
									PathTarget *target)
{
	ListCell   *lc1;
	int			i;

	i = 0;
	foreach(lc1, target->exprs)
	{
		Expr	   *expr = (Expr *) lfirst(lc1);
		Index		sgref = get_pathtarget_sortgroupref(target, i);
		ListCell   *lc2;

		/* Ignore non-sort expressions */
		if (sgref == 0 ||
			get_sortgroupref_clause_noerr(sgref,
										  root->parse->sortClause) == NULL)
		{
			i++;
			continue;
		}

		/* We ignore binary-compatible relabeling on both ends */
		while (expr && IsA(expr, RelabelType))
			expr = ((RelabelType *) expr)->arg;

		/* Locate an EquivalenceClass member matching this expr, if any */
		foreach(lc2, ec->ec_members)
		{
			EquivalenceMember *em = (EquivalenceMember *) lfirst(lc2);
			Expr	   *em_expr;

			/* Don't match constants */
			if (em->em_is_const)
				continue;

			/* Ignore child members */
			if (em->em_is_child)
				continue;

			/* Match if same expression (after stripping relabel) */
			em_expr = em->em_expr;
			while (em_expr && IsA(em_expr, RelabelType))
				em_expr = ((RelabelType *) em_expr)->arg;

			if (equal(em_expr, expr))
				return em->em_expr;
		}

		i++;
	}

	elog(ERROR, "could not find pathkey item to sort");
	return NULL;				/* keep compiler quiet */
}

/*
 * Returns true if given Var is deparsed as a subquery output column, in
 * which case, *relno and *colno are set to the IDs for the relation and
 * column alias to the Var provided by the subquery.
 */
static bool
mysql_is_subquery_var(Var *node, RelOptInfo *foreignrel, int *relno, int *colno)
{
	MySQLFdwRelationInfo *fpinfo = (MySQLFdwRelationInfo *) foreignrel->fdw_private;
	RelOptInfo *outerrel = fpinfo->outerrel;
	RelOptInfo *innerrel = fpinfo->innerrel;

	/* Should only be called in these cases. */
	Assert(IS_SIMPLE_REL(foreignrel) || IS_JOIN_REL(foreignrel));

	/*
	 * If the given relation isn't a join relation, it doesn't have any lower
	 * subqueries, so the Var isn't a subquery output column.
	 */
	if (!IS_JOIN_REL(foreignrel))
		return false;

	/*
	 * If the Var doesn't belong to any lower subqueries, it isn't a subquery
	 * output column.
	 */
	if (!bms_is_member(node->varno, fpinfo->lower_subquery_rels))
		return false;

	if (bms_is_member(node->varno, outerrel->relids))
	{
		/*
		 * If outer relation is deparsed as a subquery, the Var is an output
		 * column of the subquery; get the IDs for the relation/column alias.
		 */
		if (fpinfo->make_outerrel_subquery)
		{
			mysql_get_relation_column_alias_ids(node, outerrel, relno, colno);
			return true;
		}

		/* Otherwise, recurse into the outer relation. */
		return mysql_is_subquery_var(node, outerrel, relno, colno);
	}
	else
	{
		Assert(bms_is_member(node->varno, innerrel->relids));

		/*
		 * If inner relation is deparsed as a subquery, the Var is an output
		 * column of the subquery; get the IDs for the relation/column alias.
		 */
		if (fpinfo->make_innerrel_subquery)
		{
			mysql_get_relation_column_alias_ids(node, innerrel, relno, colno);
			return true;
		}

		/* Otherwise, recurse into the inner relation. */
		return mysql_is_subquery_var(node, innerrel, relno, colno);
	}
}


/*
 * Get the IDs for the relation and column alias to given Var belonging to
 * given relation, which are returned into *relno and *colno.
 */
static void
mysql_get_relation_column_alias_ids(Var *node, RelOptInfo *foreignrel,
									int *relno, int *colno)
{
	MySQLFdwRelationInfo *fpinfo = (MySQLFdwRelationInfo *) foreignrel->fdw_private;
	int			i;
	ListCell   *lc;

	/* Get the relation alias ID */
	*relno = fpinfo->relation_index;

	/* Get the column alias ID */
	i = 1;
	foreach(lc, foreignrel->reltarget->exprs)
	{
		if (equal(lfirst(lc), (Node *) node))
		{
			*colno = i;
			return;
		}
		i++;
	}

	/* Shouldn't get here */
	elog(ERROR, "unexpected expression in subquery output");
}

/*
 * Appends a sort or group clause.
 *
 * Like get_rule_sortgroupclause(), returns the expression tree, so caller
 * need not find it again.
 */
static Node *
mysql_deparse_sort_group_clause(Index ref, List *tlist, bool force_colno,
								deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	TargetEntry *tle;
	Expr	   *expr;

	tle = get_sortgroupref_tle(ref, tlist);
	expr = tle->expr;

	if (force_colno)
	{
		/* Use column-number form when requested by caller. */
		Assert(!tle->resjunk);
		appendStringInfo(buf, "%d", tle->resno);
	}
	else if (expr && IsA(expr, Const))
	{
		/*
		 * Force a typecast here so that we don't emit something like "GROUP
		 * BY 2", which will be misconstrued as a column position rather than
		 * a constant.
		 */
		mysql_deparse_const((Const *) expr, context);
	}
	else if (!expr || IsA(expr, Var))
		deparseExpr(expr, context);
	else
	{
		/* Always parenthesize the expression. */
		appendStringInfoChar(buf, '(');
		deparseExpr(expr, context);
		appendStringInfoChar(buf, ')');
	}

	return (Node *) expr;
}

/*
 * Deparse GROUP BY clause.
 */
static void
mysql_append_group_by_clause(List *tlist, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	Query	   *query = context->root->parse;
	ListCell   *lc;
	bool		first = true;

	/* Nothing to be done, if there's no GROUP BY clause in the query. */
	if (!query->groupClause)
		return;

	appendStringInfoString(buf, " GROUP BY ");

	/*
	 * Queries with grouping sets are not pushed down, so we don't expect
	 * grouping sets here.
	 */
	Assert(!query->groupingSets);

	foreach(lc, query->groupClause)
	{
		SortGroupClause *grp = (SortGroupClause *) lfirst(lc);

		if (!first)
			appendStringInfoString(buf, ", ");
		first = false;

		mysql_deparse_sort_group_clause(grp->tleSortGroupRef, tlist, true, context);
	}
}

/*
 * Deparses function name from given function oid.
 */
static void
mysql_append_function_name(Oid funcid, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	char	   *proname;

	/* Always print the function name */
	proname = get_func_name(funcid);
	proname = mysql_replace_function(proname, NIL);

	appendStringInfoString(buf, quote_identifier(proname));
}

/*
 * Append time units without apostrophes
 */
static void
mysql_append_time_unit(Const *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	char	   *extval;
	const char *valptr;
	Oid			typoutput;
	bool		typIsVarlena;

	if (nodeTag(node) != T_Const)
		elog(ERROR, "mysql_fdw: Node must be const type");

	getTypeOutputInfo(node->consttype, &typoutput, &typIsVarlena);
	extval = OidOutputFunctionCall(typoutput, node->constvalue);
	for (valptr = extval; *valptr; valptr++)
	{
		char		ch = *valptr;

		if (SQL_STR_DOUBLE(ch, true))
			appendStringInfoChar(buf, ch);
		appendStringInfoChar(buf, ch);
	}
}

/*
 * Return true if function name existed in list of function
 */
static bool
exist_in_function_list(char *funcname, const char **funclist)
{
	int			i;

	for (i = 0; funclist[i]; i++)
	{
		if (strcmp(funcname, funclist[i]) == 0)
			return true;
	}
	return false;
}

/*
 * Return true if function is Mysql unique function
 */
static bool
mysql_is_unique_func(Oid funcid, char *in)
{
	if (mysql_is_builtin(funcid))
		return false;

	if (exist_in_function_list(in, MysqlUniqueNumericFunction) ||
		exist_in_function_list(in, MysqlUniqueDateTimeFunction) ||
		exist_in_function_list(in, MysqlUniqueStringFunction) ||
		exist_in_function_list(in, MysqlUniqueJsonFunction) ||
		exist_in_function_list(in, MysqlUniqueCastFunction))
		return true;

	return false;
}

/*
 * Return true if function is builtin function can pushdown to Mysql
 */
static bool
mysql_is_supported_builtin_func(Oid funcid, char *in)
{
	if (!mysql_is_builtin(funcid))
		return false;

	if (exist_in_function_list(in, MysqlSupportedBuiltinNumericFunction) ||
		exist_in_function_list(in, MysqlSupportedBuiltinDateTimeFunction) ||
		exist_in_function_list(in, MysqlSupportedBuiltinStringFunction) ||
		exist_in_function_list(in, MysqlSupportedBuiltinJsonFunction))
		return true;

	return false;
}

/*
 * Return true if the string (*str) have prefix (*pre)
 */
static bool
starts_with(const char *pre, const char *str)
{
	size_t		lenpre = strlen(pre);
	size_t		lenstr = strlen(str);

	return lenstr < lenpre ? false : strncmp(pre, str, lenpre) == 0;
}

/*
 * Convert PostgreSQL interval to Mysql interval
 * If unit is NULL, automatically detect UNIT and convert interval to that UNIT
 * If UNIT is given, the function converts interval to specified UNIT
 * Currently, we just support specified UNIT: SECOND_MICROSECOND
 * https://dev.mysql.com/doc/refman/8.0/en/expressions.html#temporal-intervals
 */
static void
interval2unit(Datum datum, char **expr, char **unit)
{
	struct pg_tm tm;
	fsec_t		fsec;

	if (interval2tm(*DatumGetIntervalP(datum), &tm, &fsec) != 0)
		elog(ERROR, "mysql_fdw: could not convert interval to tm");

	if (*unit == NULL)
	{
		if (fsec != 0 ||
			tm.tm_sec != 0 ||
			tm.tm_min != 0 ||
			tm.tm_hour != 0 ||
			tm.tm_mday != 0)
		{
			int			mday = tm.tm_year * DAYS_PER_YEAR + tm.tm_mon * DAYS_PER_MONTH + tm.tm_mday;

			/* DAYS HOURS:MINUTES:SECONDS.MICROSECONDS */
			*expr = psprintf("%d %d:%d:%d.%d", mday, tm.tm_hour, tm.tm_min, tm.tm_sec, fsec);
			*unit = "DAY_MICROSECOND";
		}
		else if (tm.tm_mon != 0)
		{
			/* YEAR and MONTH */
			*expr = psprintf("%d-%d", tm.tm_year, tm.tm_mon);
			*unit = "YEAR_MONTH";
		}
		else
		{
			/* Only YEAR */
			*expr = psprintf("%d", tm.tm_year);
			*unit = "YEAR";
		}
	}
	else if (strcmp(*unit, "SECOND_MICROSECOND") == 0)
	{
		uint64		sec = 0;
		int32		microsecond = 0;

		sec = tm.tm_year * SECS_PER_YEAR +
			tm.tm_mon * DAYS_PER_MONTH * SECS_PER_DAY +
			tm.tm_mday * SECS_PER_DAY +
			tm.tm_hour * SECS_PER_HOUR +
			tm.tm_min * SECS_PER_MINUTE +
			tm.tm_sec;

		if (fsec > 0)
			microsecond = fsec;

		*expr = psprintf("%lu.%d", sec, microsecond);
	}
}

/*
 * Convert type OID + typmod info into a type name we can ship to the remote
 * server.  Someplace else had better have verified that this type name is
 * expected to be known on the remote end.
 *
 * This is almost just format_type_with_typemod(), except that if left to its
 * own devices, that function will make schema-qualification decisions based
 * on the local search_path, which is wrong.  We must schema-qualify all
 * type names that are not in pg_catalog.  We assume here that built-in types
 * are all in pg_catalog and need not be qualified; otherwise, qualify.
 */
static char *
mysql_deparse_type_name(Oid type_oid, int32 typemod)
{
	bits16		flags = FORMAT_TYPE_TYPEMOD_GIVEN;

	if (!mysql_is_builtin(type_oid))
		flags |= FORMAT_TYPE_FORCE_QUALIFY;

	return format_type_extended(type_oid, typemod, flags);
}

static void
mysql_deconstruct_constant_array(Const *node, bool **elem_nulls, Datum **elem_values, Oid *elmtype, int *num_elems)
{
	ArrayType  *array;
	int16		elmlen;
	bool		elmbyval;
	char		elmalign;

	array = DatumGetArrayTypeP(node->constvalue);
	*elmtype = ARR_ELEMTYPE(array);

	get_typlenbyvalalign(*elmtype, &elmlen, &elmbyval, &elmalign);
	deconstruct_array(array, *elmtype, elmlen, elmbyval, elmalign,
					  elem_values, elem_nulls, num_elems);
}
