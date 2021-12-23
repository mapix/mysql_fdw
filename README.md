MySQL Foreign Data Wrapper for PostgreSQL
=========================================

This PostgreSQL extension implements a Foreign Data Wrapper (FDW) for
[MySQL][1].

Please note that this version of mysql_fdw works with PostgreSQL and EDB
Postgres Advanced Server 12, 13 and 14.

Installation
------------

To compile the [MySQL][1] foreign data wrapper, MySQL's C client library
is needed. This library can be downloaded from the official [MySQL
website][1].

1. To build on POSIX-compliant systems you need to ensure the
   `pg_config` executable is in your path when you run `make`. This
   executable is typically in your PostgreSQL installation's `bin`
   directory. For example:

    ```
    $ export PATH=/usr/local/pgsql/bin/:$PATH
    ```

2. The `mysql_config` must also be in the path, it resides in the MySQL
   `bin` directory.

    ```
    $ export PATH=/usr/local/mysql/bin/:$PATH
    ```

3. Compile the code using make.

    ```
    $ make USE_PGXS=1
    ```

4.  Finally install the foreign data wrapper.

    ```
    $ make USE_PGXS=1 install
    ```

5. Running regression test.
    ```
    $ test.sh
    ```
   However, make sure to set the `MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER_NAME`,
   and `MYSQL_PWD` environment variables correctly. The default settings
   can be found in the configuration file "sql/parameter.conf"


If you run into any issues, please [let us know][2].


Enhancements
------------

The following enhancements are added to the latest version of `mysql_fdw`:

### Write-able FDW
The previous version was only read-only, the latest version provides the
write capability. The user can now issue an insert, update, and delete
statements for the foreign tables using the mysql_fdw. It uses the PG
type casting mechanism to provide opposite type casting between MySQL
and PG data types.

### Connection Pooling
The latest version comes with a connection pooler that utilises the same
MySQL database connection for all the queries in the same session. The
previous version would open a new MySQL database connection for every
query. This is a performance enhancement.

### WHERE clause push-down
The latest version will push-down the foreign table where clause to
the foreign server. The where condition on the foreign table will be
executed on the foreign server hence there will be fewer rows to bring
across to PostgreSQL. This is a performance feature.

### Column push-down
The previous version was fetching all the columns from the target
foreign table. The latest version does the column push-down and only
brings back the columns that are part of the select target list. This is
a performance feature.

### GROUP BY, HAVING clause push-down
The group by, having clause will be pushed-down to the foreign server that reduce the row and column to bring across to PostgreSQL.

### LIMIT OFFSET clause push-down
The limit offset clause will be pushed-down to the foreign server that will enhance performance.

### Aggregation function push-down
List of aggregate functions push-down:
```
avg, bit_and, bit_or, count, json_agg, json_object_agg, max, min, stddev,
stddev_pop, stddev_samp, sum, var_pop, var_samp, variance.
```

Some function has different specification or different function signature have to be implemented by stub function. The conversion syntax between Postgres and Mysql is described in the table below.

| Postgres syntax   |      Mysql coressponding syntax      |  Remark |
|----------|:-------------|------|
|bit_xor|bit_xor|Different in return value between Mysql and Postgres|
|group_concat|group_concat|unique function of Mysql|
|json_agg|json_arrayagg|Different signature but same functionality|
|json_object_agg|json_objectagg|Different signature but same functionality|
|std|std|unique function of Mysqlsql|

The special syntax for multiple arguments using Postgres ROW() syntax.

| Postgres syntax   |      Mysql coressponding syntax      |  Remark |
|----------|:-------------|------|
| count(DISTINCT (col1, col2))| count(DISTINCT col1, col2)|Deparse "ROW(col1,col2)" to "col1, col2"|
| group_concat(DISTINCT (col1, col2))| group_concat(DISTINCT col1, col2)|Deparse "ROW(col1,col2)" to "col1, col2"|

### Function push-down
The function can be push-down in WHERE, GROUP BY, HAVING, clauses.   
List of builtin functions of PostgreSQL push-down:
```
abs, acos, asin, atan, atan2, ceil, ceiling, cos, cot, degrees, div, exp, floor,
ln, log, log10, mod, pow, power, radians, round, sign, sin, sqrt, tan.
ascii, bit_length, char_length, character_length, concat, concat_ws, left,
length, lower, lpad, ltrim, octet_length, repeat, replace, reverse, right,
rpad, rtrim, position, regexp_replace, substr, substring, trim, upper.
date.
json_build_array, json_build_object.
```
List of unique functions of MySQL push-down:

Numeric:
```
conv, crc32, div, log2, rand, truncate.
```

String:
```
bin, char, elt, export_set, field, find_in_set, format, from_base64, hex, insert,
instr, lcase,locate, make_set, mid, oct, ord, quote, regexp_instr, regexp_like,
regexp_replace, regexp_substr,space, strcmp, substring_index, to_base64, ucase,
unhex, weight_string.
```
Json:
```
"json_array_append", "json_array_insert", "json_contains", "json_contains_path",
"json_depth", "json_extract", "json_insert", "json_keys", "json_length", "json_merge",
"json_merge_patch", "json_merge_preserve", "json_overlaps", "json_pretty", "json_quote",
"json_remove", "json_replace", "json_schema_valid", "json_schema_validation_report",
"json_search", "json_set", "json_storage_free", "json_storage_size", "json_table",
"json_type", "json_unquote", "json_valid", "json_value", "member_of".
```

Cast:
```
convert.
```
List of unique functions of Mysql with different name and syntax:   
  - MATCH ... AGAINST ...: `match_against`   
  Example: SELECT content FROM contents WHERE match_against(content, 'search_keyword','in boolean mode') != 0;
  - Prefix name with `mysql_`:   
  User needs to append prefix with `mysql_` for function name: pi, char, now, current_date, current_time, current_timestamp, extract, localtime, localtimestamp, time, timestamp.   
  Example: pi() -> mysql_pi()
  - WEIGHT_STRING(str [AS {CHAR|BINARY} (N)]):   
  Example: SELECT str1 FROM s3 WHERE weight_string(str1, 'CHAR', 3) > 0 AND weight_string(str1, 'BINARY', 5) > 1;
  - MEMBER ... OF ...: `member_of`    
  Example: SELECT c1 FROM ftbl WHERE member_of(5, c1) = 1;
  - json_array: `json_build_array`    
  Example: SELECT c1 FROM ftbl WHERE member_of(c1, json_build_array('text', 10, mysql_pi())) = 1;
  - json_object: `json_build_object`    
  Example: SELECT c1 FROM ftbl WHERE member_of(c1, json_build_object('a', c2, 'b', 10, 'c', mysql_pi())) = 1;
  - json_array_append, json_array_insert, json_insert, json_replace, json_set:
    - Use pair of  [path, value] in the syntax: `'path, value'`
    - Example: SELECT c1 FROM ftbl WHERE  member_of(c1, json_set(c2, `'$.a, c2'`, `'$.b, c3'`, `'$.c, 1'`, `'$, "a"'`, `'$, pi()'`)) = 1;
  - `json_extract()`, `json_value()`, `json_unquote()` and `convert()` have return type is text in postgres, so we need to convert to appropriate type if required:
    - Example: SELECT * FROM ftbl json_extract(c1, '$.a')::numeric(10, 2) > 0;
    - List cast function can be accepted:
    ```
    "float4", "float8", "int2", "int4", "int8", "numeric", "double precision",
    "char", "varchar",
    "time", "timetz", "timestamp", "timestamptz",
    "json", "jsonb",
    "bytea",
    ```
  - json_value:   
  Example: SELECT c1 FROM ftbl WHERE json_value(c1, '$.a', `'returning date'`)::date > '2001-01-01';

### JOIN clause push-down
mysql_fdw now also supports join push-down. The joins between two
foreign tables from the same remote MySQL server are pushed to a remote
server, instead of fetching all the rows for both the tables and
performing a join locally, thereby enhancing the performance. Currently,
joins involving only relational and arithmetic operators in join-clauses
are pushed down to avoid any potential join failure. Also, only the
INNER and LEFT/RIGHT OUTER joins are supported, and not the FULL OUTER,
SEMI, and ANTI join. This is a performance feature.

### New feature
- Support TRUNCATE with basic syntax only.
- Allow foreign servers to keep connections open after transaction completion. This is controlled by `keep_connections` and default value is enable.
- Support listing cached connections to remote servers by using function mysql_fdw_get_connections().
- Support discard cached connections to remote servers by using function mysql_fdw_disconnect(), mysql_fdw_disconnect_all().
- Support bulk insert by using batch_size option.
- Whole row reference is implemented by modifying the target list to select all whole row reference members and form new row for the whole row in FDW when interate foreign scan.
- Support returning system attribute (`ctid`, `tableiod`)

### Prepared Statement
(Refactoring for `select` queries to use prepared statement)

The `select` queries are now using prepared statements instead of simple
query protocol.


Usage
-----

The following parameters can be set on a MySQL foreign server object:

  * `host`: Address or hostname of the MySQL server. Defaults to
    `127.0.0.1`
  * `port`: Port number of the MySQL server. Defaults to `3306`
  * `secure_auth`: Enable or disable secure authentication. Default is
    `true`
  * `init_command`: SQL statement to execute when connecting to the
    MySQL server.
  * `use_remote_estimate`: Controls whether mysql_fdw issues remote
    EXPLAIN commands to obtain cost estimates. Default is `false`
  * `reconnect`: Enable or disable automatic reconnection to the
    MySQL server if the existing connection is found to have been lost.
    Default is `false`.
  * `ssl_key`: The path name of the client private key file.
  * `ssl_cert`: The path name of the client public key certificate file.
  * `ssl_ca`: The path name of the Certificate Authority (CA) certificate
    file. This option, if used, must specify the same certificate used
    by the server.
  * `ssl_capath`: The path name of the directory that contains trusted
    SSL CA certificate files.
  * `ssl_cipher`: The list of permissible ciphers for SSL encryption.
  * `fetch_size`: This option specifies the number of rows mysql_fdw should
    get in each fetch operation. It can be specified for a foreign table or
    a foreign server. The option specified on a table overrides an option
    specified for the server. The default is `100`.

The following parameters can be set on a MySQL foreign table object:

  * `dbname`: Name of the MySQL database to query. This is a mandatory
    option.
  * `table_name`: Name of the MySQL table, default is the same as
    foreign table.
  * `max_blob_size`: Max blob size to read without truncation.
  * `fetch_size`: Same as `fetch_size` parameter for foreign server.

The following parameters need to supplied while creating user mapping.

  * `username`: Username to use when connecting to MySQL.
  * `password`: Password to authenticate to the MySQL server with.

Examples
--------

```sql
-- load extension first time after install
CREATE EXTENSION mysql_fdw;

-- create server object
CREATE SERVER mysql_server
	FOREIGN DATA WRAPPER mysql_fdw
	OPTIONS (host '127.0.0.1', port '3306');

-- create user mapping
CREATE USER MAPPING FOR postgres
	SERVER mysql_server
	OPTIONS (username 'foo', password 'bar');

-- create foreign table
CREATE FOREIGN TABLE warehouse
	(
		warehouse_id int,
		warehouse_name text,
		warehouse_created timestamp
	)
	SERVER mysql_server
	OPTIONS (dbname 'db', table_name 'warehouse');

-- insert new rows in table
INSERT INTO warehouse values (1, 'UPS', current_date);
INSERT INTO warehouse values (2, 'TV', current_date);
INSERT INTO warehouse values (3, 'Table', current_date);

-- select from table
SELECT * FROM warehouse ORDER BY 1;

warehouse_id | warehouse_name | warehouse_created
-------------+----------------+-------------------
           1 | UPS            | 10-JUL-20 00:00:00
           2 | TV             | 10-JUL-20 00:00:00
           3 | Table          | 10-JUL-20 00:00:00

-- delete row from table
DELETE FROM warehouse where warehouse_id = 3;

-- update a row of table
UPDATE warehouse set warehouse_name = 'UPS_NEW' where warehouse_id = 1;

-- explain a table with verbose option
EXPLAIN VERBOSE SELECT warehouse_id, warehouse_name FROM warehouse WHERE warehouse_name LIKE 'TV' limit 1;

                                   QUERY PLAN
--------------------------------------------------------------------------------------------------------------------
Limit  (cost=10.00..11.00 rows=1 width=36)
	Output: warehouse_id, warehouse_name
	->  Foreign Scan on public.warehouse  (cost=10.00..1010.00 rows=1000 width=36)
		Output: warehouse_id, warehouse_name
		Local server startup cost: 10
		Remote query: SELECT `warehouse_id`, `warehouse_name` FROM `db`.`warehouse` WHERE ((`warehouse_name` LIKE BINARY 'TV'))
```

Contributing
------------
Opening issues and pull requests on GitHub are welcome.

License
-------
Copyright (c) 2021, TOSHIBA Corporation.

Copyright (c) 2011-2021, EnterpriseDB Corporation.

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose, without fee, and without a written
agreement is hereby granted, provided that the above copyright notice
and this paragraph and the following two paragraphs appear in all
copies.

See the [`LICENSE`][3] file for full details.

[1]: http://www.mysql.com
[2]: https://github.com/enterprisedb/mysql_fdw/issues/new
[3]: LICENSE
