/*-------------------------------------------------------------------------
 *
 * connection.c
 * 		Connection management functions for mysql_fdw
 *
 * Portions Copyright (c) 2012-2014, PostgreSQL Global Development Group
 * Portions Copyright (c) 2004-2021, EnterpriseDB Corporation.
 *
 * IDENTIFICATION
 * 		connection.c
 *
 *-------------------------------------------------------------------------
 */

#include "postgres.h"

#if PG_VERSION_NUM >= 130000
#include "common/hashfn.h"
#endif
#include "mb/pg_wchar.h"
#include "mysql_fdw.h"
#include "utils/hsearch.h"
#include "utils/inval.h"
#include "utils/memutils.h"
#include "utils/syscache.h"
#include "access/xact.h"
#if PG_VERSION_NUM >= 140000
#include "funcapi.h"
#include "utils/builtins.h"
#include "utils/datetime.h"
#include "miscadmin.h"
#endif
#include "commands/defrem.h"

/* Length of host */
#define HOST_LEN 256

/*
 * Connection cache hash table entry
 *
 * The lookup key in this hash table is the foreign server OID plus the user
 * mapping OID.  (We use just one connection per user per foreign server,
 * so that we can ensure all scans use the same snapshot during a query.)
 */
typedef struct ConnCacheKey
{
	Oid			serverid;		/* OID of foreign server */
	Oid			userid;			/* OID of local user whose mapping we use */
} ConnCacheKey;

typedef struct ConnCacheEntry
{
	ConnCacheKey key;			/* hash key (must be first) */
	MYSQL	   *conn;			/* connection to foreign server, or NULL */
	bool		invalidated;	/* true if reconnect is pending */
	uint32		server_hashvalue;	/* hash value of foreign server OID */
	uint32		mapping_hashvalue;	/* hash value of user mapping OID */
	int			xact_depth;		/* 0 = no xact open, 1 = main xact open, 2 =
								 * one level of subxact open, etc */

	bool		keep_connections;	/* setting value of keep_connections
									 * server option */
	Oid			serverid;		/* foreign server OID used to get server name */
} ConnCacheEntry;

/*
 * Connection cache (initialized on first use)
 */
static HTAB *ConnectionHash = NULL;

/* tracks whether any work is needed in callback functions */
static bool xact_got_connection = false;

static void mysql_inval_callback(Datum arg, int cacheid, uint32 hashvalue);
static void mysql_do_sql_command(MYSQL * conn, const char *sql, int level);
static void mysql_begin_remote_xact(ConnCacheEntry *entry);
static void mysql_xact_callback(XactEvent event, void *arg);
static void mysql_subxact_callback(SubXactEvent event, SubTransactionId mySubid,
								   SubTransactionId parentSubid, void *arg);

/*
 * SQL functions
 */
PG_FUNCTION_INFO_V1(mysql_fdw_get_connections);
PG_FUNCTION_INFO_V1(mysql_fdw_disconnect);
PG_FUNCTION_INFO_V1(mysql_fdw_disconnect_all);

/* prototypes of private functions */
static void mysql_make_new_connection(ConnCacheEntry *entry, UserMapping *user, mysql_opt * opt);
#if (PG_VERSION_NUM >= 140000)
static bool disconnect_cached_connections(Oid serverid);
#endif
static void disconnect_mysql_server(ConnCacheEntry *entry);

/*
 * mysql_get_connection:
 * 		Get a connection which can be used to execute queries on the remote
 * 		MySQL server with the user's authorization.  A new connection is
 * 		established if we don't already have a suitable one.
 */
MYSQL *
mysql_get_connection(ForeignServer *server, UserMapping *user, mysql_opt * opt)
{
	bool		found;
	ConnCacheEntry *entry;
	ConnCacheKey key;
	bool		retry = false;
	MemoryContext ccxt = CurrentMemoryContext;

	/* First time through, initialize connection cache hashtable */
	if (ConnectionHash == NULL)
	{
		HASHCTL		ctl;

		MemSet(&ctl, 0, sizeof(ctl));
		ctl.keysize = sizeof(ConnCacheKey);
		ctl.entrysize = sizeof(ConnCacheEntry);
		ctl.hash = tag_hash;

		/* Allocate ConnectionHash in the cache context */
		ctl.hcxt = CacheMemoryContext;
		ConnectionHash = hash_create("mysql_fdw connections", 8,
									 &ctl,
#if (PG_VERSION_NUM >= 140000)
									 HASH_ELEM | HASH_BLOBS);
#else
									 HASH_ELEM | HASH_FUNCTION | HASH_CONTEXT);
#endif

		/*
		 * Register some callback functions that manage connection cleanup.
		 * This should be done just once in each backend.
		 */
		CacheRegisterSyscacheCallback(FOREIGNSERVEROID,
									  mysql_inval_callback, (Datum) 0);
		CacheRegisterSyscacheCallback(USERMAPPINGOID,
									  mysql_inval_callback, (Datum) 0);
		RegisterXactCallback(mysql_xact_callback, NULL);
		RegisterSubXactCallback(mysql_subxact_callback, NULL);
	}

	/* Create hash key for the entry.  Assume no pad bytes in key struct */
	key.serverid = server->serverid;
	key.userid = user->userid;
	/* Set flag that we did GetConnection during the current transaction */
	xact_got_connection = true;

	/* Set flag that we did GetConnection during the current transaction */
	xact_got_connection = true;

	/*
	 * Find or create cached entry for requested connection.
	 */
	entry = hash_search(ConnectionHash, &key, HASH_ENTER, &found);
	if (!found)
	{
		/* Initialize new hashtable entry (key is already filled in) */
		entry->conn = NULL;
	}

	/* If an existing entry has invalid connection then release it */
	if (entry->conn != NULL && entry->invalidated && entry->xact_depth == 0)
	{
		elog(DEBUG3, "disconnecting mysql_fdw connection %p for option changes to take effect",
			 entry->conn);
		disconnect_mysql_server(entry);
	}
	if (entry->conn == NULL)
		mysql_make_new_connection(entry, user, opt);

	/*
	 * We check the health of the cached connection here when starting a new
	 * remote transaction. If a broken connection is detected, we try to
	 * reestablish a new connection later.
	 */
	PG_TRY();
	{
		/* Start a new transaction or subtransaction if needed. */
		mysql_begin_remote_xact(entry);
	}
	PG_CATCH();
	{
		MemoryContext ecxt = MemoryContextSwitchTo(ccxt);
		unsigned int conn_sts = mysql_errno(entry->conn);

		/*
		 * If connection failure is reported when starting a new remote
		 * transaction (not subtransaction), new connection will be
		 * reestablished later.
		 *
		 * If the error is CR_SERVER_LOST, Which mean the server might be
		 * restart perform to retry connect
		 */
		if (conn_sts != CR_SERVER_LOST ||
			entry->xact_depth > 0)
		{
			MemoryContextSwitchTo(ecxt);
			PG_RE_THROW();
		}

		/* Clean up the error state */
		FlushErrorState();

		retry = true;
	}
	PG_END_TRY();

	/*
	 * If a broken connection is detected, disconnect it, reestablish a new
	 * connection and retry a new remote transaction. If connection failure is
	 * reported again, we give up getting a connection.
	 */
	if (retry)
	{
		Assert(entry->xact_depth == 0);

		ereport(DEBUG3,
				(errmsg_internal("could not start remote transaction on connection %p",
								 entry->conn)),
				errdetail_internal("%s", mysql_error(entry->conn)));

		elog(DEBUG3, "closing connection %p to reestablish a new one",
			 entry->conn);
		disconnect_mysql_server(entry);

		if (entry->conn == NULL)
			mysql_make_new_connection(entry, user, opt);

		mysql_begin_remote_xact(entry);
	}

	return entry->conn;
}

static void
disconnect_mysql_server(ConnCacheEntry *entry)
{
	if (entry->conn)
	{
		elog(DEBUG3, "mysql_fdw disconnecting connection %p", entry->conn);
		mysql_close(entry->conn);
		entry->conn = NULL;
	}
}

/*
 * Reset all transient state fields in the cached connection entry and
 * establish new connection to the remote server.
 */
static void
mysql_make_new_connection(ConnCacheEntry *entry, UserMapping *user, mysql_opt * opt)
{
	ForeignServer *server = GetForeignServer(user->serverid);
	ListCell   *lc;

	Assert(entry->conn == NULL);

	/* Reset all transient state fields, to be sure all are clean */
	entry->xact_depth = 0;
	entry->invalidated = false;
	entry->serverid = server->serverid;
	entry->server_hashvalue =
		GetSysCacheHashValue1(FOREIGNSERVEROID,
							  ObjectIdGetDatum(server->serverid));
	entry->mapping_hashvalue =
		GetSysCacheHashValue1(USERMAPPINGOID,
							  ObjectIdGetDatum(user->umid));

	/*
	 * Determine whether to keep the connection that we're about to make here
	 * open even after the transaction using it ends, so that the subsequent
	 * transactions can re-use it.
	 *
	 * It's enough to determine this only when making new connection because
	 * all the connections to the foreign server whose keep_connections option
	 * is changed will be closed and re-made later.
	 *
	 * By default, all the connections to any foreign servers are kept open.
	 */
	entry->keep_connections = true;
	foreach(lc, server->options)
	{
		DefElem    *def = (DefElem *) lfirst(lc);

		if (strcmp(def->defname, "keep_connections") == 0)
		{
			entry->keep_connections = defGetBoolean(def);
			break;
		}

	}

	/* Now try to make the connection */
	entry->conn = mysql_connect(opt);

	elog(DEBUG3, "new mysql_fdw connection %p for server \"%s\"",
		 entry->conn, server->servername);
}

/*
 * mysql_cleanup_connection:
 * 		Delete all the cache entries on backend exists.
 */
void
mysql_cleanup_connection(void)
{
	HASH_SEQ_STATUS scan;
	ConnCacheEntry *entry;

	if (ConnectionHash == NULL)
		return;

	hash_seq_init(&scan, ConnectionHash);
	while ((entry = (ConnCacheEntry *) hash_seq_search(&scan)))
	{
		if (entry->conn == NULL)
			continue;

		disconnect_mysql_server(entry);
	}
}

/*
 * Release connection created by calling mysql_get_connection.
 */
void
mysql_release_connection(MYSQL * conn)
{
	HASH_SEQ_STATUS scan;
	ConnCacheEntry *entry;

	if (ConnectionHash == NULL)
		return;

	hash_seq_init(&scan, ConnectionHash);
	while ((entry = (ConnCacheEntry *) hash_seq_search(&scan)))
	{
		if (entry->conn == NULL)
			continue;

		if (entry->conn == conn)
		{
			disconnect_mysql_server(entry);
			hash_seq_term(&scan);
			break;
		}
	}
}

MYSQL *
mysql_connect(mysql_opt * opt)
{
	MYSQL	   *conn;
	char	   *svr_database = opt->svr_database;
	bool		svr_sa = opt->svr_sa;
	char	   *svr_init_command = opt->svr_init_command;
	char	   *ssl_cipher = opt->ssl_cipher;
#if	MYSQL_VERSION_ID < 80000
	my_bool		secure_auth = svr_sa;
#endif

	/* Connect to the server */
	conn = mysql_init(NULL);
	if (!conn)
		ereport(ERROR,
				(errcode(ERRCODE_FDW_OUT_OF_MEMORY),
				 errmsg("failed to initialise the MySQL connection object")));

	mysql_options(conn, MYSQL_SET_CHARSET_NAME, GetDatabaseEncodingName());
#if MYSQL_VERSION_ID < 80000
	mysql_options(conn, MYSQL_SECURE_AUTH, &secure_auth);
#endif

	if (!svr_sa)
		elog(WARNING, "MySQL secure authentication is off");

	if (svr_init_command != NULL)
		mysql_options(conn, MYSQL_INIT_COMMAND, svr_init_command);

	mysql_ssl_set(conn, opt->ssl_key, opt->ssl_cert, opt->ssl_ca,
				  opt->ssl_capath, ssl_cipher);

	if (!mysql_real_connect(conn, opt->svr_address, opt->svr_username,
							opt->svr_password, svr_database, opt->svr_port,
							NULL, 0))
		ereport(ERROR,
				(errcode(ERRCODE_FDW_UNABLE_TO_ESTABLISH_CONNECTION),
				 errmsg("failed to connect to MySQL: %s", mysql_error(conn))));

	/* Useful for verifying that the connection's secured */
	elog(DEBUG1,
		 "Successfully connected to MySQL database %s at server %s with cipher %s (server version: %s, protocol version: %d) ",
		 (svr_database != NULL) ? svr_database : "<none>",
		 mysql_get_host_info(conn),
		 (ssl_cipher != NULL) ? ssl_cipher : "<none>",
		 mysql_get_server_info(conn),
		 mysql_get_proto_info(conn));

	return conn;
}

/*
 * Connection invalidation callback function for mysql.
 *
 * After a change to a pg_foreign_server or pg_user_mapping catalog entry,
 * mark connections depending on that entry as needing to be remade. This
 * implementation is similar as pgfdw_inval_callback.
 */
static void
mysql_inval_callback(Datum arg, int cacheid, uint32 hashvalue)
{
	HASH_SEQ_STATUS scan;
	ConnCacheEntry *entry;

	Assert(cacheid == FOREIGNSERVEROID || cacheid == USERMAPPINGOID);

	/* ConnectionHash must exist already, if we're registered */
	hash_seq_init(&scan, ConnectionHash);
	while ((entry = (ConnCacheEntry *) hash_seq_search(&scan)))
	{
		/* Ignore invalid entries */
		if (entry->conn == NULL)
			continue;

		/* hashvalue == 0 means a cache reset, must clear all state */
		if (hashvalue == 0 ||
			(cacheid == FOREIGNSERVEROID &&
			 entry->server_hashvalue == hashvalue) ||
			(cacheid == USERMAPPINGOID &&
			 entry->mapping_hashvalue == hashvalue))
		{
			/*
			 * Close the connection immediately if it's not used yet in this
			 * transaction. Otherwise mark it as invalid so that
			 * mysql_xact_callback() can close it at the end of this
			 * transaction.
			 */
			if (entry->xact_depth == 0)
			{
				disconnect_mysql_server(entry);
			}
			else
				entry->invalidated = true;
		}
		entry->invalidated = true;
	}
}

/*
 * Convenience subroutine to issue a non-data-returning SQL command to remote
 */
static void
mysql_do_sql_command(MYSQL * conn, const char *sql, int level)
{
	elog(DEBUG3, "mysql_fdw do_sql_command %s", sql);

	if (mysql_query(conn, sql) != 0)
	{
		ereport(level,
				(errcode(ERRCODE_FDW_ERROR),
				 errmsg("mysql_fdw: failed to execute sql: %s, Error %u: %s\n", sql, mysql_errno(conn), mysql_error(conn))
				 ));
	}
}

/*
 * Start remote transaction or subtransaction, if needed.
 */
static void
mysql_begin_remote_xact(ConnCacheEntry *entry)
{
	int			curlevel = GetCurrentTransactionNestLevel();

	/* Start main transaction if we haven't yet */
	if (entry->xact_depth <= 0)
	{
		const char *sql = "START TRANSACTION";

		elog(DEBUG3, "mysql_fdw starting remote transaction on connection %p",
			 entry->conn);

		mysql_do_sql_command(entry->conn, sql, ERROR);
		entry->xact_depth = 1;
	}

	/*
	 * If we're in a subtransaction, stack up savepoints to match our level.
	 * This ensures we can rollback just the desired effects when a
	 * subtransaction aborts.
	 */
	while (entry->xact_depth < curlevel)
	{
		const char *sql = psprintf("SAVEPOINT s%d", entry->xact_depth + 1);

		mysql_do_sql_command(entry->conn, sql, ERROR);
		entry->xact_depth++;
	}
}

/*
 * mysql_xact_callback --- cleanup at main-transaction end.
 */
static void
mysql_xact_callback(XactEvent event, void *arg)
{
	HASH_SEQ_STATUS scan;
	ConnCacheEntry *entry;

	/* Quick exit if no connections were touched in this transaction. */
	if (!xact_got_connection)
		return;

	elog(DEBUG1, "mysql_fdw xact_callback %d", event);

	/*
	 * Scan all connection cache entries to find open remote transactions, and
	 * close them.
	 */
	hash_seq_init(&scan, ConnectionHash);
	while ((entry = (ConnCacheEntry *) hash_seq_search(&scan)))
	{
		/* Ignore cache entry if no open connection right now */
		if (entry->conn == NULL)
			continue;

		/* If it has an open remote transaction, try to close it */
		if (entry->xact_depth > 0)
		{
			elog(DEBUG3, "mysql_fdw closing remote transaction on connection %p",
				 entry->conn);

			switch (event)
			{
				case XACT_EVENT_PARALLEL_PRE_COMMIT:
				case XACT_EVENT_PRE_COMMIT:
					/* Commit all remote transactions */
					mysql_do_sql_command(entry->conn, "COMMIT", ERROR);
					break;
				case XACT_EVENT_PRE_PREPARE:

					/*
					 * We disallow remote transactions that modified anything,
					 * since it's not very reasonable to hold them open until
					 * the prepared transaction is committed.  For the moment,
					 * throw error unconditionally; later we might allow
					 * read-only cases.  Note that the error will cause us to
					 * come right back here with event == XACT_EVENT_ABORT, so
					 * we'll clean up the connection state at that point.
					 */
					ereport(ERROR,
							(errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
							 errmsg("mysql_fdw cannot prepare a transaction that modified remote tables")));
					break;
				case XACT_EVENT_PARALLEL_COMMIT:
				case XACT_EVENT_COMMIT:
				case XACT_EVENT_PREPARE:
					/* Pre-commit should have closed the open transaction */
					elog(ERROR, "mysql_fdw missed cleaning up connection during pre-commit");
					break;
				case XACT_EVENT_PARALLEL_ABORT:
				case XACT_EVENT_ABORT:
					{
						elog(DEBUG3, "mysql_fdw abort transaction");

						/*
						 * rollback if in transaction
						 */
						mysql_do_sql_command(entry->conn, "ROLLBACK", WARNING);
						break;
					}
			}
		}

		/* Reset state to show we're out of a transaction */
		entry->xact_depth = 0;
		if (entry->invalidated || !entry->keep_connections)
		{
			elog(DEBUG3, "mysql_fdw discarding connection %p", entry->conn);
			disconnect_mysql_server(entry);
		}
	}

	/*
	 * Regardless of the event type, we can now mark ourselves as out of the
	 * transaction.
	 */
	xact_got_connection = false;
}

/*
 * mysql_subxact_callback --- cleanup at subtransaction end.
 */
static void
mysql_subxact_callback(SubXactEvent event, SubTransactionId mySubid,
					   SubTransactionId parentSubid, void *arg)
{
	HASH_SEQ_STATUS scan;
	ConnCacheEntry *entry;
	int			curlevel;

	/* Nothing to do at subxact start, nor after commit. */
	if (!(event == SUBXACT_EVENT_PRE_COMMIT_SUB ||
		  event == SUBXACT_EVENT_ABORT_SUB))
		return;

	/* Quick exit if no connections were touched in this transaction. */
	if (!xact_got_connection)
		return;

	/*
	 * Scan all connection cache entries to find open remote subtransactions
	 * of the current level, and close them.
	 */
	curlevel = GetCurrentTransactionNestLevel();
	hash_seq_init(&scan, ConnectionHash);
	while ((entry = (ConnCacheEntry *) hash_seq_search(&scan)))
	{
		char		sql[100];

		/*
		 * We only care about connections with open remote subtransactions of
		 * the current level.
		 */
		if (entry->conn == NULL || entry->xact_depth < curlevel)
			continue;

		if (entry->xact_depth > curlevel)
			elog(ERROR, "mysql_fdw missed cleaning up remote subtransaction at level %d",
				 entry->xact_depth);

		if (event == SUBXACT_EVENT_PRE_COMMIT_SUB)
		{
			/* Commit all remote subtransactions during pre-commit */
			snprintf(sql, sizeof(sql), "RELEASE SAVEPOINT s%d", curlevel);
			mysql_do_sql_command(entry->conn, sql, ERROR);
		}
		else if (in_error_recursion_trouble())
		{
			/*
			 * Don't try to clean up the connection if we're already in error
			 * recursion trouble.
			 */
		}
		else
		{
			/* Rollback all remote subtransactions during abort */
			snprintf(sql, sizeof(sql),
					 "ROLLBACK TO SAVEPOINT s%d",
					 curlevel);
			mysql_do_sql_command(entry->conn, sql, ERROR);
			snprintf(sql, sizeof(sql),
					 "RELEASE SAVEPOINT s%d",
					 curlevel);
			mysql_do_sql_command(entry->conn, sql, ERROR);
		}

		/* OK, we're outta that level of subtransaction */
		entry->xact_depth--;
	}
}

/*
 * List active foreign server connections.
 *
 * This function takes no input parameter and returns setof record made of
 * following values:
 * - server_name - server name of active connection. In case the foreign server
 *   is dropped but still the connection is active, then the server name will
 *   be NULL in output.
 * - valid - true/false representing whether the connection is valid or not.
 * 	 Note that the connections can get invalidated in pgfdw_inval_callback.
 *
 * No records are returned when there are no cached connections at all.
 */
Datum
mysql_fdw_get_connections(PG_FUNCTION_ARGS)
#if PG_VERSION_NUM >= 140000
{
#define MYSQL_FDW_GET_CONNECTIONS_COLS	2
	ReturnSetInfo *rsinfo = (ReturnSetInfo *) fcinfo->resultinfo;
	TupleDesc	tupdesc;
	Tuplestorestate *tupstore;
	MemoryContext per_query_ctx;
	MemoryContext oldcontext;
	HASH_SEQ_STATUS scan;
	ConnCacheEntry *entry;

	/* check to see if caller supports us returning a tuplestore */
	if (rsinfo == NULL || !IsA(rsinfo, ReturnSetInfo))
		ereport(ERROR,
				(errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
				 errmsg("set-valued function called in context that cannot accept a set")));
	if (!(rsinfo->allowedModes & SFRM_Materialize))
		ereport(ERROR,
				(errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
				 errmsg("materialize mode required, but it is not allowed in this context")));

	/* Build a tuple descriptor for our result type */
	if (get_call_result_type(fcinfo, NULL, &tupdesc) != TYPEFUNC_COMPOSITE)
		elog(ERROR, "return type must be a row type");

	/* Build tuplestore to hold the result rows */
	per_query_ctx = rsinfo->econtext->ecxt_per_query_memory;
	oldcontext = MemoryContextSwitchTo(per_query_ctx);

	tupstore = tuplestore_begin_heap(true, false, work_mem);
	rsinfo->returnMode = SFRM_Materialize;
	rsinfo->setResult = tupstore;
	rsinfo->setDesc = tupdesc;

	MemoryContextSwitchTo(oldcontext);

	/* If cache doesn't exist, we return no records */
	if (!ConnectionHash)
	{
		/* clean up and return the tuplestore */
		tuplestore_donestoring(tupstore);

		PG_RETURN_VOID();
	}

	hash_seq_init(&scan, ConnectionHash);
	while ((entry = (ConnCacheEntry *) hash_seq_search(&scan)))
	{
		ForeignServer *server;
		Datum		values[MYSQL_FDW_GET_CONNECTIONS_COLS];
		bool		nulls[MYSQL_FDW_GET_CONNECTIONS_COLS];

		/* We only look for open remote connections */
		if (!entry->conn)
			continue;

		server = GetForeignServerExtended(entry->serverid, FSV_MISSING_OK);

		MemSet(values, 0, sizeof(values));
		MemSet(nulls, 0, sizeof(nulls));

		/*
		 * The foreign server may have been dropped in current explicit
		 * transaction. It is not possible to drop the server from another
		 * session when the connection associated with it is in use in the
		 * current transaction, if tried so, the drop query in another session
		 * blocks until the current transaction finishes.
		 *
		 * Even though the server is dropped in the current transaction, the
		 * cache can still have associated active connection entry, say we
		 * call such connections dangling. Since we can not fetch the server
		 * name from system catalogs for dangling connections, instead we show
		 * NULL value for server name in output.
		 *
		 * We could have done better by storing the server name in the cache
		 * entry instead of server oid so that it could be used in the output.
		 * But the server name in each cache entry requires 64 bytes of
		 * memory, which is huge, when there are many cached connections and
		 * the use case i.e. dropping the foreign server within the explicit
		 * current transaction seems rare. So, we chose to show NULL value for
		 * server name in output.
		 *
		 * Such dangling connections get closed either in next use or at the
		 * end of current explicit transaction in pgfdw_xact_callback.
		 */
		if (!server)
		{
			/*
			 * If the server has been dropped in the current explicit
			 * transaction, then this entry would have been invalidated in
			 * pgfdw_inval_callback at the end of drop server command. Note
			 * that this connection would not have been closed in
			 * pgfdw_inval_callback because it is still being used in the
			 * current explicit transaction. So, assert that here.
			 */
			Assert(entry->conn && entry->xact_depth > 0 && entry->invalidated);

			/* Show null, if no server name was found */
			nulls[0] = true;
		}
		else
			values[0] = CStringGetTextDatum(server->servername);

		values[1] = BoolGetDatum(!entry->invalidated);

		tuplestore_putvalues(tupstore, tupdesc, values, nulls);
	}

	/* clean up and return the tuplestore */
	tuplestore_donestoring(tupstore);

	PG_RETURN_VOID();
}
#else
{
	ereport(ERROR,
			(errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
			 errmsg("Function %s does not support in Postgres version %s", __func__, PG_VERSION)
			 ));
}
#endif

/*
 * Disconnect the specified cached connections.
 *
 * This function discards the open connections that are established by
 * mysql_fdw from the local session to the foreign server with
 * the given name. Note that there can be multiple connections to
 * the given server using different user mappings. If the connections
 * are used in the current local transaction, they are not disconnected
 * and warning messages are reported. This function returns true
 * if it disconnects at least one connection, otherwise false. If no
 * foreign server with the given name is found, an error is reported.
 */
Datum
mysql_fdw_disconnect(PG_FUNCTION_ARGS)
#if PG_VERSION_NUM >= 140000
{
	ForeignServer *server;
	char	   *servername;

	servername = text_to_cstring(PG_GETARG_TEXT_PP(0));
	server = GetForeignServerByName(servername, false);

	PG_RETURN_BOOL(disconnect_cached_connections(server->serverid));
}
#else
{
	ereport(ERROR,
			(errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
			 errmsg("mysql_fdw Function %s does not support in Postgres version %s", __func__, PG_VERSION)
			 ));
}
#endif

/*
 * Disconnect all the cached connections.
 *
 * This function discards all the open connections that are established by
 * mysql_fdw from the local session to the foreign servers.
 * If the connections are used in the current local transaction, they are
 * not disconnected and warning messages are reported. This function
 * returns true if it disconnects at least one connection, otherwise false.
 */
Datum
mysql_fdw_disconnect_all(PG_FUNCTION_ARGS)
#if PG_VERSION_NUM >= 140000
{
	PG_RETURN_BOOL(disconnect_cached_connections(InvalidOid));
}
#else
{
	ereport(ERROR,
			(errcode(ERRCODE_FEATURE_NOT_SUPPORTED),
			 errmsg("mysql_fdw Function %s does not support in Postgres version %s", __func__, PG_VERSION)
			 ));
}
#endif

#if PG_VERSION_NUM >= 140000
/*
 * Workhorse to disconnect cached connections.
 *
 * This function scans all the connection cache entries and disconnects
 * the open connections whose foreign server OID matches with
 * the specified one. If InvalidOid is specified, it disconnects all
 * the cached connections.
 *
 * This function emits a warning for each connection that's used in
 * the current transaction and doesn't close it. It returns true if
 * it disconnects at least one connection, otherwise false.
 *
 * Note that this function disconnects even the connections that are
 * established by other users in the same local session using different
 * user mappings. This leads even non-superuser to be able to close
 * the connections established by superusers in the same local session.
 *
 * XXX As of now we don't see any security risk doing this. But we should
 * set some restrictions on that, for example, prevent non-superuser
 * from closing the connections established by superusers even
 * in the same session?
 */
static bool
disconnect_cached_connections(Oid serverid)
{
	HASH_SEQ_STATUS scan;
	ConnCacheEntry *entry;
	bool		all = !OidIsValid(serverid);
	bool		result = false;

	/*
	 * Connection cache hashtable has not been initialized yet in this
	 * session, so return false.
	 */
	if (!ConnectionHash)
		return false;

	hash_seq_init(&scan, ConnectionHash);
	while ((entry = (ConnCacheEntry *) hash_seq_search(&scan)))
	{
		/* Ignore cache entry if no open connection right now. */
		if (!entry->conn)
			continue;

		if (all || entry->serverid == serverid)
		{
			/*
			 * Emit a warning because the connection to close is used in the
			 * current transaction and cannot be disconnected right now.
			 */
			if (entry->xact_depth > 0)
			{
				ForeignServer *server;

				server = GetForeignServerExtended(entry->serverid,
												  FSV_MISSING_OK);

				if (!server)
				{
					/*
					 * If the foreign server was dropped while its connection
					 * was used in the current transaction, the connection
					 * must have been marked as invalid by
					 * pgfdw_inval_callback at the end of DROP SERVER command.
					 */
					Assert(entry->invalidated);

					ereport(WARNING,
							(errmsg("mysql_fdw cannot close dropped server connection because it is still in use")));
				}
				else
					ereport(WARNING,
							(errmsg("mysql_fdw cannot close connection for server \"%s\" because it is still in use",
									server->servername)));
			}
			else
			{
				elog(DEBUG3, "mysql_fdw discarding connection %p", entry->conn);
				mysql_close(entry->conn);
				entry->conn = NULL;
				result = true;
			}
		}
	}

	return result;
}
#endif
