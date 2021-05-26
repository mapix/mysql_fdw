/*-------------------------------------------------------------------------
 *
 * deparse.c
 * 		Query deparser for mysql_fdw
 *
 * Portions Copyright (c) 2012-2014, PostgreSQL Global Development Group
 * Portions Copyright (c) 2004-2020, EnterpriseDB Corporation.
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

static bool mysql_contain_immutable_functions_walker(Node *node, void *context);

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
	bool        can_skip_cast;  /* outer function can skip float cast */
	bool		can_pushdown_interval;	/* time interval can be pushed down */
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
	int         can_skip_cast;  /* outer function can skip float8/numeric cast */
	bool		can_convert_time;	/* time interval need to be converted to second */
} deparse_expr_cxt;

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
static void mysql_deparse_array_ref(ArrayRef *node, deparse_expr_cxt *context);
#else
static void mysql_deparse_array_ref(SubscriptingRef *node,
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
									  List **retrieved_attrs,
									  bool is_concat);
static void mysql_deparse_column_ref(StringInfo buf, int varno, int varattno,
									 RangeTblEntry *rte, bool qualify_col);
static bool mysql_deparse_op_divide(Expr *node, deparse_expr_cxt *context);
static Node *mysql_deparse_sort_group_clause(Index ref, List *tlist, bool force_colno,
									deparse_expr_cxt *context);

/*
 * Functions to construct string representation of a specific types.
 */
static void deparse_interval(StringInfo buf, Datum datum);
static void mysql_append_order_by_clause(List *pathkeys, bool has_final_sort,
								deparse_expr_cxt *context);
static void mysql_append_limit_clause(deparse_expr_cxt *context);
static void mysql_append_group_by_clause(List *tlist, deparse_expr_cxt *context);
static void mysql_append_function_name(Oid funcid, deparse_expr_cxt *context);

/*
 * Helper functions
 */
static bool mysql_is_subquery_var(Var *node, RelOptInfo *foreignrel,
								   int *relno, int *colno);
static void mysql_get_relation_column_alias_ids(Var *node, RelOptInfo *foreignrel,
												 int *relno, int *colno);
static void interval2sec(Datum datum, uint64 *second, int32 *microsecond);

/*
 * Local variables.
 */
static char *cur_opname = NULL;

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
void
mysql_deparse_insert(StringInfo buf, PlannerInfo *root, Index rtindex,
					 Relation rel, List *targetAttrs)
{
	ListCell   *lc;

	appendStringInfoString(buf, "INSERT INTO ");
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

			mysql_deparse_column_ref(buf, rtindex, attnum, planner_rt_fetch(rtindex, root), false);
		}

		appendStringInfoString(buf, ") VALUES (");

		pindex = 1;
		first = true;
		foreach(lc, targetAttrs)
		{
			if (!first)
				appendStringInfoString(buf, ", ");
			first = false;

			appendStringInfo(buf, "?");
			pindex++;
		}

		appendStringInfoChar(buf, ')');
	}
	else
		appendStringInfoString(buf, " DEFAULT VALUES");
}

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
static void
mysql_deparse_target_list(StringInfo buf,
						RangeTblEntry *rte,
						Index rtindex,
						Relation rel,
						Bitmapset *attrs_used,
						bool qualify_col,
						List **retrieved_attrs,
						bool is_concat)
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

			if (is_concat)
				appendStringInfoString(buf, "IFNULL( ");

			first = false;

			mysql_deparse_column_ref(buf, rtindex, i, rte, qualify_col);

			if (is_concat)
				appendStringInfoString(buf, " , '') ");

			*retrieved_attrs = lappend_int(*retrieved_attrs, i);
		}
	}

	/*
	 * Add ctid if needed.  We currently don't support retrieving any other
	 * system columns.
	 */
	if (bms_is_member(SelfItemPointerAttributeNumber - FirstLowInvalidHeapAttributeNumber,
					  attrs_used))
	{
		if (!first)
			appendStringInfoString(buf, ", ");
		first = false;

		if (qualify_col)
			ADD_REL_QUALIFIER(buf, rtindex);
		appendStringInfoString(buf, "ctid");

		*retrieved_attrs = lappend_int(*retrieved_attrs,
									   SelfItemPointerAttributeNumber);
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
		if (relid == root->parse->resultRelation &&
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

	if (varattno == 0)
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
		appendStringInfoString(buf, "CONCAT( '(', CONCAT_WS(',' , ");
		mysql_deparse_target_list(buf, rte, varno, rel, attrs_used, qualify_col,
												  &retrieved_attrs, true);
		appendStringInfoString(buf, " ) , ')' )");

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
		* If it's a column of a regular table or it doesn't have column_name FDW
		* option, use attribute name.
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

static void
mysql_deparse_string(StringInfo buf, const char *val, bool isstr)
{
	const char *valptr;
	int			i = 0;

	if (isstr)
		appendStringInfoChar(buf, '\'');

	for (valptr = val; *valptr; valptr++,i++)
	{
		char		ch = *valptr;

		/*
		 * Remove '{', '}', and \" character from the string. Because this
		 * syntax is not recognize by the remote MySQL server.
		 */
		if ((ch == '{' && i == 0) || (ch == '}' && (i == (strlen(val) - 1))) ||
			ch == '\"')
			continue;

		if (isstr && ch == ',')
		{
			appendStringInfoString(buf, "', '");
			continue;
		}
		appendStringInfoChar(buf, ch);
	}

	if (isstr)
		appendStringInfoChar(buf, '\'');
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
	bool outer_can_skip_cast = context->can_skip_cast;

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
			mysql_deparse_array_ref((SubscriptingRef *) node, context);
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

		if (attnum == 1)
			continue;

		if (!first)
			appendStringInfoString(buf, ", ");
		first = false;

		mysql_deparse_column_ref(buf, rtindex, attnum, planner_rt_fetch(rtindex, root), false);
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
	ListCell   *lc;

	/* Set up context struct for recursion */
	context.root = root;
	context.foreignrel = foreignrel;
	context.scanrel = foreignrel;
	context.buf = buf;
	context.params_list = params_list;
	context.can_convert_time = false;

	/*
	 * MySQL does not support UPDATE...FROM,
	 * must to deparse UPDATE...JOIN.
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
	foreach(lc, targetAttrs)
	{
		int			attnum = lfirst_int(lc);
		TargetEntry *tle = get_tle_by_resno(targetlist, attnum);

		if (!tle)
			elog(ERROR, "attribute number %d not found in UPDATE targetlist",
				 attnum);

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

	appendStringInfoString(buf, "DELETE FROM ");

	if (IS_JOIN_REL(foreignrel))
	{
		List	   *ignore_conds = NIL;
		MySQLFdwRelationInfo *fpinfo = (MySQLFdwRelationInfo *) foreignrel->fdw_private;

		appendStringInfo(buf, " %s%d", REL_ALIAS_PREFIX, rtindex);
		appendStringInfo(buf, " USING ");

		/* 
		 * MySQL does not allow to define alias in FROM clause,
		 * alias must be defined in USING clause.
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
				uint64 sec = 0;
				int32 msec = 0;

				/* convert interval to second */
				interval2sec(node->constvalue, &sec, &msec);
				appendStringInfo(buf, "%lu.%d", sec, msec);
			}
			else
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
		default:
			extval = OidOutputFunctionCall(typoutput, node->constvalue);
			mysql_deparse_string_literal(buf, extval);
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
mysql_deparse_array_ref(ArrayRef *node, deparse_expr_cxt *context)
#else
mysql_deparse_array_ref(SubscriptingRef *node, deparse_expr_cxt *context)
#endif
{
	StringInfo	buf = context->buf;
	ListCell   *lowlist_item;
	ListCell   *uplist_item;

	/* Always parenthesize the expression. */
	appendStringInfoChar(buf, '(');

	/*
	 * Deparse referenced array expression first.  If that expression includes
	 * a cast, we have to parenthesize to prevent the array subscript from
	 * being taken as typename decoration.  We can avoid that in the typical
	 * case of subscripting a Var, but otherwise do it.
	 */
	if (IsA(node->refexpr, Var))
		deparseExpr(node->refexpr, context);
	else
	{
		appendStringInfoChar(buf, '(');
		deparseExpr(node->refexpr, context);
		appendStringInfoChar(buf, ')');
	}

	/* Deparse subscript expressions. */
	lowlist_item = list_head(node->reflowerindexpr);	/* could be NULL */
	foreach(uplist_item, node->refupperindexpr)
	{
		appendStringInfoChar(buf, '[');
		if (lowlist_item)
		{
			deparseExpr(lfirst(lowlist_item), context);
			appendStringInfoChar(buf, ':');
#if PG_VERSION_NUM < 130000
			lowlist_item = lnext(lowlist_item);
#else
			lowlist_item = lnext(node->reflowerindexpr, lowlist_item);
#endif
		}
		deparseExpr(lfirst(uplist_item), context);
		appendStringInfoChar(buf, ']');
	}

	appendStringInfoChar(buf, ')');
}

/*
 * This is possible that the name of function in PostgreSQL and mysql differ,
 * so return the mysql eloquent function name.
 */
static char *
mysql_replace_function(char *in)
{
	if (strcmp(in, "btrim") == 0)
		return "trim";

	return in;
}

/*
 * Deparse a function call.
 */
static void
mysql_deparse_func_expr(FuncExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	HeapTuple	proctup;
	Form_pg_proc procform;
	const char *proname;
	bool		first;
	ListCell   *arg;
	bool        can_skip_cast = false;

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
	proctup = SearchSysCache1(PROCOID, ObjectIdGetDatum(node->funcid));
	if (!HeapTupleIsValid(proctup))
		elog(ERROR, "cache lookup failed for function %u", node->funcid);

	procform = (Form_pg_proc) GETSTRUCT(proctup);

	/* Translate PostgreSQL function into mysql function */
	proname = mysql_replace_function(NameStr(procform->proname));

	if(strcmp(proname,"match_against")==0)
	{
		/* ... and all the arguments */
		first = true;
		foreach(arg, node->args)
		{
			Expr *node;
			ListCell   *lc;
		    ArrayExpr *anode;
			bool swt_arg;
			node = lfirst(arg);
			if (IsA(node, ArrayCoerceExpr))
			{
				node = (Expr *)((ArrayCoerceExpr *)node)->arg;
			}
			Assert(nodeTag(node)==T_ArrayExpr);
			anode = (ArrayExpr *)node;
			appendStringInfoString(buf, "MATCH (");
			swt_arg = true;
			foreach(lc, anode->elements)
			{
				Expr *node;
				node=lfirst(lc);
				if(nodeTag(node)==T_Var){
					if (!first)
						appendStringInfoString(buf, ", ");
					mysql_deparse_var((Var *)node,context);
				}
				else if(nodeTag(node)==T_Const){
					Const *cnode = (Const *)node;
					if(swt_arg == true){
						appendStringInfoString(buf, ") AGAINST ( ");
						swt_arg = false;
						first = true;
						mysql_deparse_const(cnode,context);
						appendStringInfoString(buf, " ");
					}
					else{
						Oid         typoutput;
						const char *valptr;
						char        *extval;
						bool        typIsVarlena;
						getTypeOutputInfo(cnode->consttype,
										  &typoutput, &typIsVarlena);

						extval = OidOutputFunctionCall(typoutput, cnode->constvalue);
						for (valptr = extval; *valptr; valptr++)
						{
							char	ch = *valptr;
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
		ReleaseSysCache(proctup);

		return;
	}

	/* remove cast function if parent function is can handle without cast */
	if (context->can_skip_cast == true && (strcmp(NameStr(procform->proname), "float8") == 0 ||
										   strcmp(NameStr(procform->proname), "numeric") == 0 ||
										   strcmp(NameStr(procform->proname), "interval") == 0))
	{
		ReleaseSysCache(proctup);
		arg = list_head(node->args);
		context->can_skip_cast = false;
		deparseExpr((Expr *)lfirst(arg), context);
		return;
	}

	/* inner function can skip cast if any */
	if (strcmp(NameStr(procform->proname), "sqrt") == 0 || strcmp(NameStr(procform->proname), "log") == 0)
		can_skip_cast = true;

	/* Deparse the function name ... */
	appendStringInfo(buf, "%s(", proname);

	ReleaseSysCache(proctup);

	/* ... and all the arguments */
	first = true;
	foreach(arg, node->args)
	{
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
	bool is_convert = true;

	if (node == NULL)
		return false;

	switch (nodeTag(node))
	{
		case T_Var:
			{
				Var		   		*var = (Var *) node;
				RangeTblEntry 	*rte;
				PlannerInfo 	*root = context->root;
				int				col_type = 0;
				int				varno = var->varno;
				int				varattno = var->varattno;

				/* varno must not be any of OUTER_VAR, INNER_VAR and INDEX_VAR. */
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
				FuncExpr *f = (FuncExpr *) node;
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

				OpExpr *op = (OpExpr *) node;

				/* Retrieve information about the operator from system catalog. */
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
	ListCell   *arg;
	bool		is_convert = false; /* Flag to determine that convert '/' to 'DIV' or not */
	bool		is_concat = false; /* Flag to use keyword 'CONCAT' instead of '||' */

	/* Retrieve information about the operator from system catalog. */
	tuple = SearchSysCache1(OPEROID, ObjectIdGetDatum(node->opno));
	if (!HeapTupleIsValid(tuple))
		elog(ERROR, "cache lookup failed for operator %u", node->opno);

	form = (Form_pg_operator) GETSTRUCT(tuple);
	oprkind = form->oprkind;

	/* Sanity check. */
	Assert((oprkind == 'r' && list_length(node->args) == 1) ||
		   (oprkind == 'l' && list_length(node->args) == 1) ||
		   (oprkind == 'b' && list_length(node->args) == 2));

	cur_opname = NameStr(form->oprname);
	/* If opname is '/' check all type of operands recursively */
	if (form->oprnamespace == PG_CATALOG_NAMESPACE && strcmp(cur_opname, "/") == 0)
		is_convert = mysql_deparse_op_divide((Expr *)node, context);

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
	
	/* Deparse left operand. */
	if (oprkind == 'r' || oprkind == 'b')
	{
		arg = list_head(node->args);
		deparseExpr(lfirst(arg), context);
		appendStringInfoChar(buf, ' ');
	}

	/*
	 * Deparse operator name.
	 * If all operands are non floating point type, change '/' to 'DIV'.
	 */
	if (is_convert)
		appendStringInfoString(buf, "DIV");
	else if (is_concat)
		appendStringInfoString(buf, ",");
	else
		mysql_deparse_operator_name(buf, form);

	/* Deparse right operand. */
	if (oprkind == 'l' || oprkind == 'b')
	{
		arg = list_tail(node->args);
		appendStringInfoChar(buf, ' ');
		deparseExpr(lfirst(arg), context);
	}

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

	Assert(list_length(node->args) == 2);

	appendStringInfoChar(buf, '(');
	deparseExpr(linitial(node->args), context);
	appendStringInfoString(buf, " IS DISTINCT FROM ");
	deparseExpr(lsecond(node->args), context);
	appendStringInfoChar(buf, ')');
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
	HeapTuple	tuple;
	Expr	   *arg1;
	Expr	   *arg2;
	Form_pg_operator form;
	char	   *opname;
	Oid			typoutput;
	bool		typIsVarlena;
	char	   *extval;

	/* Retrieve information about the operator from system catalog. */
	tuple = SearchSysCache1(OPEROID, ObjectIdGetDatum(node->opno));
	if (!HeapTupleIsValid(tuple))
		elog(ERROR, "cache lookup failed for operator %u", node->opno);
	form = (Form_pg_operator) GETSTRUCT(tuple);

	/* Sanity check. */
	Assert(list_length(node->args) == 2);

	opname = NameStr(form->oprname);

	/*
	 * Deparse right operand to check type of argument first.
	 * For an fixed-len array, we use IN clause, e.g. ANY(ARRAY[1, 2, 3]).
	 * For an variable-len array, we use FIND_IN_SET clause, e.g. ANY(ARRAY(SELECT * FROM table),
	 * because we can bind a string representation of array.
	 */
	arg2 = lsecond(node->args);
	if (nodeTag((Node*)arg2) == T_Const)
	{
		/* Deparse left operand. */
		arg1 = linitial(node->args);
		deparseExpr(arg1, context);
		appendStringInfoChar(buf, ' ');

		if (strcmp(opname, "<>") == 0)
			appendStringInfo(buf, " NOT ");

		/* Deparse operator name plus decoration. */
		appendStringInfo(buf, " IN (");
	}
	else
	{
		if (strcmp(opname, "<>") == 0)
			appendStringInfo(buf, " NOT ");

		/* Use FIND_IN_SET for binding the array parameter */
		appendStringInfo(buf, " FIND_IN_SET (");

		/* Deparse left operand. */
		arg1 = linitial(node->args);
		deparseExpr(arg1, context);
		appendStringInfoChar(buf, ',');
	}

	switch (nodeTag((Node *) arg2))
	{
		case T_Const:
			{
				Const	   *c = (Const *) arg2;

				if (c->constisnull)
				{
					appendStringInfoString(buf, " NULL");
					ReleaseSysCache(tuple);
					return;
				}

				getTypeOutputInfo(c->consttype, &typoutput, &typIsVarlena);
				extval = OidOutputFunctionCall(typoutput, c->constvalue);

				switch (c->consttype)
				{
					case INT4ARRAYOID:
					case OIDARRAYOID:
						mysql_deparse_string(buf, extval, false);
						break;
					default:
						mysql_deparse_string(buf, extval, true);
						break;
				}
			}
			break;
		default:
			deparseExpr(arg2, context);
			break;
	}
	appendStringInfoChar(buf, ')');

	ReleaseSysCache(tuple);
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

	switch (node->boolop)
	{
		case AND_EXPR:
			op = "AND";
			break;
		case OR_EXPR:
			op = "OR";
			break;
		case NOT_EXPR:
			appendStringInfoChar(buf, '(');
			appendStringInfoString(buf, "NOT ");
			deparseExpr(linitial(node->args), context);
			appendStringInfoChar(buf, ')');
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
	char		*func_name;
	bool		is_bit_func = false;

	/* Only basic, non-split aggregation accepted. */
	Assert(node->aggsplit == AGGSPLIT_SIMPLE);

	/* Check if need to print VARIADIC (cf. ruleutils.c) */
	use_variadic = node->aggvariadic;
	func_rettype = get_func_rettype(node->aggfnoid);
	func_name = pstrdup(get_func_name(node->aggfnoid));

	/*
	 * On Postgres, BIT_AND and BIT_OR return a signed bigint value.
	 * On MySQL, BIT_AND and BIT_OR return an unsigned bigint value.
	 * So, to display correct value on Postgres, we need to CAST return value AS SIGNED.
	 */
	if (strcmp(func_name, "bit_and") == 0 ||
		strcmp(func_name, "bit_or") == 0)
	{
		is_bit_func = true;
		appendStringInfoString(buf, "CAST(");
	}

	/* Find aggregate name from aggfnoid which is a pg_proc entry */
	mysql_append_function_name(node->aggfnoid, context);
	appendStringInfoChar(buf, '(');

	/* Add DISTINCT */
	appendStringInfo(buf, "%s", (node->aggdistinct != NIL) ? "DISTINCT " : "");

	/*
	 * MySQL cannot calculate SUM, AVG correctly with time interval under format "hh:mm:ss".
	 * We should convert time to second (plus microsecond if needed).
	 */
	if ((func_rettype == INTERVALOID) && (strcmp(func_name, "sum") == 0 ||
										  strcmp(func_name, "avg") == 0))
	{
		context->can_convert_time = true;
	}
	else
		context->can_convert_time = false;

	/* 
	 * Skip cast for aggregation functions.
	 * TODO: We may hanlde another functions in future if we have more test case with cast function.
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
	}

	appendStringInfoChar(buf, ')');

	if (is_bit_func)
		appendStringInfoString(buf, " AS SIGNED)");

	/* Reset after finish deparsing */
	context->can_convert_time = false;
	context->can_skip_cast = false;
}

/*
 * Deparse ARRAY[...] construct.
 */
static void
mysql_deparse_array_expr(ArrayExpr *node, deparse_expr_cxt *context)
{
	StringInfo	buf = context->buf;
	bool		first = true;
	ListCell   *lc;

	appendStringInfoString(buf, "ARRAY[");
	foreach(lc, node->elements)
	{
		if (!first)
			appendStringInfoString(buf, ", ");
		deparseExpr(lfirst(lc), context);
		first = false;
	}
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
static bool
is_builtin(Oid oid)
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
	inner_cxt.can_pushdown_interval = outer_cxt->can_pushdown_interval;

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

					/*
					 * System columns other than ctid should not be sent to
					 * the remote, since we don't make any effort to ensure
					 * that local and remote values match (tableoid, in
					 * particular, almost certainly doesn't match).
					 */
					if (var->varattno < 0 &&
						var->varattno != SelfItemPointerAttributeNumber)
						return false;

					/* Else check the collation */
					collation = var->varcollid;
					state = OidIsValid(collation) ? FDW_COLLATE_SAFE : FDW_COLLATE_NONE;
				}
				else
				{
					/* Var belongs to some other table */
					if (var->varcollid != InvalidOid &&
						var->varcollid != DEFAULT_COLLATION_OID)
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

				/*
				 * If the constant has non default collation, either it's of a
				 * non-built in type, or it reflects folding of a CollateExpr;
				 * either way, it's unsafe to send to the remote.
				 */
				if (c->constcollid != InvalidOid &&
					c->constcollid != DEFAULT_COLLATION_OID)
					return false;

				/* Don't pushdown INTERVAL const if it is not inside aggregation functions (sum, avg) */
				if (c->consttype == INTERVALOID &&
					inner_cxt.can_pushdown_interval == false)
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

				/* Assignment should not be in restrictions. */
				if (ar->refassgnexpr != NULL)
					return false;

				/*
				 * Recurse to remaining subexpressions.  Since the array
				 * subscripts must yield (noncollatable) integers, they won't
				 * affect the inner_cxt state.
				 */
				if (!foreign_expr_walker((Node *) ar->refupperindexpr,
										 glob_cxt, &inner_cxt))
					return false;
				if (!foreign_expr_walker((Node *) ar->reflowerindexpr,
										 glob_cxt, &inner_cxt))
					return false;
				if (!foreign_expr_walker((Node *) ar->refexpr,
										 glob_cxt, &inner_cxt))
					return false;

				/*
				 * Array subscripting should yield same collation as input,
				 * but for safety use same logic as for function nodes.
				 */
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
				char	   *opername = NULL;
				Node       *node_arg = (Node *)fe->args;

				/*
				 * If function used by the expression is not built-in, it
				 * can't be sent to remote because it might have incompatible
				 * semantics on remote side.
				 */
				tuple = SearchSysCache1(PROCOID, ObjectIdGetDatum(fe->funcid));
				if (!HeapTupleIsValid(tuple))
				{
					elog(ERROR, "cache lookup failed for function %u", fe->funcid);
				}
				opername = pstrdup(((Form_pg_proc) GETSTRUCT(tuple))->proname.data);
				ReleaseSysCache(tuple);

				/* pushed down to mysql */
				if (!is_builtin(fe->funcid) &&
					strcmp(opername, "float8") != 0 &&
					strcmp(opername, "numeric") != 0 &&
					strcmp(opername, "log") != 0 &&
					strcmp(opername, "match_against") != 0)
					return false;

				/* inner function can skip float cast if any */
				if (strcmp(opername, "sqrt") == 0 || strcmp(opername, "log") == 0)
					inner_cxt.can_skip_cast = true;

				/* Accept type cast functions if outer is specific functions */
				if (strcmp(opername, "float8") == 0 ||
					strcmp(opername, "float4") == 0 ||
					strcmp(opername, "int2") == 0 ||
					strcmp(opername, "int4") == 0 ||
					strcmp(opername, "int8") == 0 ||
					strcmp(opername, "numeric") == 0)
				{
					if (outer_cxt->can_skip_cast == false)
						return false;
				}

				if (strcmp(opername, "match_against") == 0 && IsA(node_arg, List))
				{
					List	   *l = (List *) node_arg;
					ListCell   *lc = list_head(l);

					node_arg = (Node *)lfirst(lc);
					if (IsA(node_arg, ArrayCoerceExpr))
					{
						node_arg = (Node *)((ArrayCoerceExpr *)node_arg)->arg;
					}
				}

				/*
				 * Recurse to input subexpressions.
				 */
				if (!foreign_expr_walker((Node *) node_arg,
										 glob_cxt, &inner_cxt))
					return false;

				/*
				 * If function's input collation is not derived from a foreign
				 * Var, it can't be sent to remote.
				 */
				if (fe->inputcollid == InvalidOid)
					 /* OK, inputs are all noncollatable */ ;
				else if (inner_cxt.state != FDW_COLLATE_SAFE ||
						 fe->inputcollid != inner_cxt.collation)
					return false;

				/*
				 * Detect whether node is introducing a collation not derived
				 * from a foreign Var.  (If so, we just mark it unsafe for now
				 * rather than immediately returning false, since the parent
				 * node might not care.)
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
			break;
		case T_OpExpr:
		case T_DistinctExpr:	/* struct-equivalent to OpExpr */
			{
				OpExpr	   *oe = (OpExpr *) node;

				/*
				 * Similarly, only built-in operators can be sent to remote.
				 * (If the operator is, surely its underlying function is
				 * too.)
				 */
				if (!is_builtin(oe->opno))
					return false;

				/*
				 * Recurse to input subexpressions.
				 */
				if (!foreign_expr_walker((Node *) oe->args,
										 glob_cxt, &inner_cxt))
					return false;

				/*
				 * If operator's input collation is not derived from a foreign
				 * Var, it can't be sent to remote.
				 */
				if (oe->inputcollid == InvalidOid)
					 /* OK, inputs are all noncollatable */ ;
				else if (inner_cxt.state != FDW_COLLATE_SAFE ||
						 oe->inputcollid != inner_cxt.collation)
					return false;

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

				/*
				 * Again, only built-in operators can be sent to remote.
				 */
				if (!is_builtin(oe->opno))
					return false;

				/*
				 * Recurse to input subexpressions.
				 */
				if (!foreign_expr_walker((Node *) oe->args,
										 glob_cxt, &inner_cxt))
					return false;

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
				char	   *opername = NULL;
				Oid			schema;

				/* Not safe to pushdown when not in grouping context */
				if (!IS_UPPER_REL(glob_cxt->foreignrel))
					return false;

				/* Only non-split aggregates are pushable. */
				if (agg->aggsplit != AGGSPLIT_SIMPLE)
					return false;

				/* get function name and schema */
				tuple = SearchSysCache1(PROCOID, ObjectIdGetDatum(agg->aggfnoid));
				if (!HeapTupleIsValid(tuple))
				{
					elog(ERROR, "cache lookup failed for function %u", agg->aggfnoid);
				}
				opername = pstrdup(((Form_pg_proc) GETSTRUCT(tuple))->proname.data);
				schema = ((Form_pg_proc) GETSTRUCT(tuple))->pronamespace;
				ReleaseSysCache(tuple);

				/* ignore functions in other than the pg_catalog schema */
				if (schema != PG_CATALOG_NAMESPACE)
					return false;

				/* can pushdown interval const in aggregation functions (sum, avg) */
				if ((strcmp(opername, "sum") == 0
					|| strcmp(opername, "avg") == 0) 
					&& get_func_rettype(agg->aggfnoid) == INTERVALOID)
				{
					inner_cxt.can_pushdown_interval = true;
				}

				/* these function can be passed to Mysql */
				if (!(strcmp(opername, "sum") == 0
					  || strcmp(opername, "avg") == 0
					  || strcmp(opername, "max") == 0
					  || strcmp(opername, "min") == 0
					  || strcmp(opername, "bit_and") == 0
					  || strcmp(opername, "bit_or") == 0
					  || strcmp(opername, "json_agg") == 0
					  || strcmp(opername, "json_object_agg") == 0
					  || strcmp(opername, "stddev") == 0
					  || strcmp(opername, "stddev_pop") == 0
					  || strcmp(opername, "stddev_samp") == 0
					  || strcmp(opername, "var_pop") == 0
					  || strcmp(opername, "var_samp") == 0
					  || strcmp(opername, "variance") == 0
					  || strcmp(opername, "count") == 0))
				{
					return false;
				}

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

				/* Reset after checking aggregation */
				inner_cxt.can_pushdown_interval = false;

				if (agg->aggorder || agg->aggfilter)
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

				/*
				 * Recurse to component subexpressions.
				 */
				foreach(lc, l)
				{
					if (!foreign_expr_walker((Node *) lfirst(lc),
											 glob_cxt, &inner_cxt))
						return false;
				}

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
	if (check_type && !is_builtin(exprType(node)))
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
	loc_cxt.can_pushdown_interval = false;
	if (!foreign_expr_walker((Node *) expr, &glob_cxt, &loc_cxt))
		return false;

	/*
	 * If the expression has a valid collation that does not arise from a
	 * foreign var, the expression can not be sent over.
	 */
	if (loc_cxt.state == FDW_COLLATE_UNSAFE)
		return false;

	/* Expressions examined here should be boolean, ie noncollatable */
	// Assert(loc_cxt.collation == InvalidOid);
	// Assert(loc_cxt.state == FDW_COLLATE_NONE);

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
 * contain_immutable_functions
 *	  Recursively search for immutable functions within a clause.
 *
 * Returns true if any immutable function (or operator implemented by a
 * immutable function) is found.
 *
 * We will recursively look into TargetEntry exprs.
 */
static bool
mysql_contain_immutable_functions(Node *clause)
{
	return mysql_contain_immutable_functions_walker(clause, NULL);
}

static bool
mysql_contain_immutable_functions_walker(Node *node, void *context)
{
	if (node == NULL)
		return false;
	/* Check for mutable functions in node itself */
	if (nodeTag(node) == T_FuncExpr)
	{
		FuncExpr *expr = (FuncExpr *) node;
		if (func_volatile(expr->funcid) == PROVOLATILE_IMMUTABLE)
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
								 mysql_contain_immutable_functions_walker,
								 context, 0);
	}
	return expression_tree_walker(node, mysql_contain_immutable_functions_walker,
								  context);
}

/*
 * Returns true if given tlist is safe to evaluate on the foreign server.
 */
bool mysql_is_foreign_function_tlist(PlannerInfo *root,
									 RelOptInfo *baserel,
									 List *tlist)
{
	foreign_glob_cxt glob_cxt;
	foreign_loc_cxt  loc_cxt;
	MySQLFdwRelationInfo *fpinfo = (MySQLFdwRelationInfo *) (baserel->fdw_private);
	ListCell        *lc;
	bool             is_contain_function;

	if (!(baserel->reloptkind == RELOPT_BASEREL ||
		  baserel->reloptkind == RELOPT_OTHER_MEMBER_REL))
		return false;

	/*
	 * Check that the expression consists of any immutable function.
	 */
	is_contain_function = false;
	foreach(lc, tlist)
	{
		TargetEntry *tle = lfirst_node(TargetEntry, lc);

		if (mysql_contain_immutable_functions((Node *) tle->expr))
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
		 * For an upper relation, use relids from its underneath scan relation,
		 * because the upperrel's own relids currently aren't set to anything
		 * meaningful by the cor  e code.For other relation, use their own relids.
		 */
		if (IS_UPPER_REL(baserel))
			glob_cxt.relids = fpinfo->outerrel->relids;
		else
			glob_cxt.relids = baserel->relids;

		loc_cxt.collation = InvalidOid;
		loc_cxt.state = FDW_COLLATE_NONE;
		loc_cxt.can_skip_cast = false;
		loc_cxt.can_pushdown_interval = false;

		if (!foreign_expr_walker((Node *) tle->expr, &glob_cxt, &loc_cxt))
			return false;

		/*
		 * If the expression has a valid collation that does not arise from a
		 * foreign var, the expression can not be sent over.
		 */
		if (loc_cxt.state == FDW_COLLATE_UNSAFE)
			return false;

		/*
		 * An expression which includes any mutable functions can't be sent over
		 * because its result is not stable.  For example, sending now() remote
		 * side could cause confusion from clock offsets.  Future versions might
		 * be able to make this choice with more granularity.  (We check this last
		 * because it requires a lot of expensive catalog lookups.)
		 */
		if (contain_mutable_functions((Node *) tle->expr))
			return false;
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
			context.can_convert_time = false;

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
			ListCell *cell;
			int i = 0;
			bool first;

			first = true;
			*retrieved_attrs = NIL;
			
			foreach (cell, tlist)
			{
				Expr *expr = ((TargetEntry *)lfirst(cell))->expr;

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
								fpinfo->attrs_used, false, retrieved_attrs, false);
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
			appendStringInfoString(buf, " IS NULL DESC"); /* NULLS FIRST */
		else
			appendStringInfoString(buf, " IS NULL ASC"); /* NULLS LAST */

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
	HeapTuple	proctup;
	Form_pg_proc procform;
	const char *proname;

	proctup = SearchSysCache1(PROCOID, ObjectIdGetDatum(funcid));
	if (!HeapTupleIsValid(proctup))
		elog(ERROR, "cache lookup failed for function %u", funcid);
	procform = (Form_pg_proc) GETSTRUCT(proctup);

	/* Print schema name only if it's not pg_catalog */
	if (procform->pronamespace != PG_CATALOG_NAMESPACE)
	{
		const char *schemaname;

		schemaname = get_namespace_name(procform->pronamespace);
		appendStringInfo(buf, "%s.", quote_identifier(schemaname));
	}

	/* Always print the function name */
	proname = NameStr(procform->proname);

	if (strcmp(proname, "json_agg") == 0)
		appendStringInfoString(buf, quote_identifier("json_arrayagg"));
	else if (strcmp(proname, "json_object_agg") == 0)
		appendStringInfoString(buf, quote_identifier("json_objectagg"));
	else
		appendStringInfoString(buf, quote_identifier(proname));

	ReleaseSysCache(proctup);
}

/*
 * Convert time interval to second
 */
static void 
interval2sec(Datum datum, uint64 *second, int32 *microsecond)
{
	struct pg_tm tm;
	fsec_t fsec;
	uint64 sec = 0;

	if (interval2tm(*DatumGetIntervalP(datum), &tm, &fsec) != 0)
		elog(ERROR, "could not convert interval to tm");

	if (tm.tm_year > 0)
		sec += tm.tm_year * SECS_PER_YEAR;

	if (tm.tm_mon > 0)
		sec += tm.tm_mon * DAYS_PER_MONTH * SECS_PER_DAY;

	if (tm.tm_mday > 0)
		sec += tm.tm_mday * SECS_PER_DAY;

	if (tm.tm_hour > 0)
		sec += tm.tm_hour * SECS_PER_HOUR;

	if (tm.tm_min > 0)
		sec += tm.tm_min * SECS_PER_MINUTE;

	if (tm.tm_sec > 0)
		sec += tm.tm_sec;

	if (fsec > 0)
		*microsecond = fsec;
	
	*second = sec;
}
