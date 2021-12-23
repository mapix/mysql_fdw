\set ECHO none
\ir sql/parameters.conf
\set ECHO all
-- Before running this file User must create database mysql_fdw_regress on
-- mysql with all permission for MYSQL_USER_NAME user with MYSQL_PWD password
-- and ran mysql_init.sh file to create tables.

\c contrib_regression
--Testcase 1:
CREATE EXTENSION IF NOT EXISTS mysql_fdw;

-- FDW-139: Support for JOIN pushdown.
--Testcase 2:
CREATE SERVER mysql_svr FOREIGN DATA WRAPPER mysql_fdw
  OPTIONS (host :MYSQL_HOST, port :MYSQL_PORT);
--Testcase 3:
CREATE USER MAPPING FOR public SERVER mysql_svr
  OPTIONS (username :MYSQL_USER_NAME, password :MYSQL_PASS);

--Testcase 4:
CREATE SERVER mysql_svr1 FOREIGN DATA WRAPPER mysql_fdw
  OPTIONS (host :MYSQL_HOST, port :MYSQL_PORT);
--Testcase 5:
CREATE USER MAPPING FOR public SERVER mysql_svr1
  OPTIONS (username :MYSQL_USER_NAME, password :MYSQL_PASS);

--Testcase 6:
CREATE TYPE user_enum AS ENUM ('foo', 'bar', 'buz');
--Testcase 7:
CREATE FOREIGN TABLE fdw139_t1(c1 int, c2 int, c3 text COLLATE "C", c4 text COLLATE "C")
  SERVER mysql_svr OPTIONS(dbname 'mysql_fdw_regress', table_name 'test1');
--Testcase 8:
CREATE FOREIGN TABLE fdw139_t2(c1 int, c2 int, c3 text COLLATE "C", c4 text COLLATE "C")
  SERVER mysql_svr OPTIONS(dbname 'mysql_fdw_regress', table_name 'test2');
--Testcase 9:
CREATE FOREIGN TABLE fdw139_t3(c1 int, c2 int, c3 text COLLATE "C")
  SERVER mysql_svr OPTIONS(dbname 'mysql_fdw_regress', table_name 'test3');
--Testcase 10:
CREATE FOREIGN TABLE fdw139_t4(c1 int, c2 int, c3 text COLLATE "C")
  SERVER mysql_svr1 OPTIONS(dbname 'mysql_fdw_regress', table_name 'test3');

--Testcase 11:
INSERT INTO fdw139_t1 values(1, 100, 'AAA1', 'foo');
--Testcase 12:
INSERT INTO fdw139_t1 values(2, 100, 'AAA2', 'bar');
--Testcase 13:
INSERT INTO fdw139_t1 values(11, 100, 'AAA11', 'foo');

--Testcase 14:
INSERT INTO fdw139_t2 values(1, 200, 'BBB1', 'foo');
--Testcase 15:
INSERT INTO fdw139_t2 values(2, 200, 'BBB2', 'bar');
--Testcase 16:
INSERT INTO fdw139_t2 values(12, 200, 'BBB12', 'foo');

--Testcase 17:
INSERT INTO fdw139_t3 values(1, 300, 'CCC1');
--Testcase 18:
INSERT INTO fdw139_t3 values(2, 300, 'CCC2');
--Testcase 19:
INSERT INTO fdw139_t3 values(13, 300, 'CCC13');

--Testcase 20:
SET enable_mergejoin TO off;
--Testcase 21:
SET enable_hashjoin TO off;
--Testcase 22:
SET enable_sort TO off;

--Testcase 23:
ALTER FOREIGN TABLE fdw139_t1 ALTER COLUMN c4 type user_enum;
--Testcase 24:
ALTER FOREIGN TABLE fdw139_t2 ALTER COLUMN c4 type user_enum;

-- Join two tables
-- target list order is different for v10 and v96.
--Testcase 25:
EXPLAIN (COSTS false, VERBOSE)
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c3, t1.c1;
--Testcase 26:
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c3, t1.c1;

-- INNER JOIN with where condition.  Should execute where condition separately
-- on remote side.
-- target list order is different for v10 and v96.
--Testcase 27:
EXPLAIN (COSTS false, VERBOSE)
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1) WHERE t1.c2 = 100
  ORDER BY t1.c3, t1.c1;
--Testcase 28:
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1) WHERE t1.c2 = 100
  ORDER BY t1.c3, t1.c1;

-- INNER JOIN in which join clause is not pushable.
-- target list order is different for v10 and v96.
--Testcase 29:
EXPLAIN (COSTS false, VERBOSE)
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 JOIN fdw139_t2 t2 ON (abs(t1.c1) = t2.c1) WHERE t1.c2 = 100
  ORDER BY t1.c3, t1.c1;
--Testcase 30:
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 JOIN fdw139_t2 t2 ON (abs(t1.c1) = t2.c1) WHERE t1.c2 = 100
  ORDER BY t1.c3, t1.c1;

-- Join three tables
-- target list order is different for v10 and v96.
--Testcase 31:
EXPLAIN (COSTS false, VERBOSE)
SELECT t1.c1, t2.c2, t3.c3
  FROM fdw139_t1 t1 JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1) JOIN fdw139_t3 t3 ON (t3.c1 = t1.c1)
  ORDER BY t1.c3, t1.c1;
--Testcase 32:
SELECT t1.c1, t2.c2, t3.c3
  FROM fdw139_t1 t1 JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1) JOIN fdw139_t3 t3 ON (t3.c1 = t1.c1)
  ORDER BY t1.c3, t1.c1;

EXPLAIN (COSTS false, VERBOSE)
SELECT t1.c1, t2.c1, t3.c1
  FROM fdw139_t1 t1, fdw139_t2 t2, fdw139_t3 t3 WHERE t1.c1 = 11 AND t2.c1 = 12 AND t3.c1 = 13
  ORDER BY t1.c1;

SELECT t1.c1, t2.c1, t3.c1
  FROM fdw139_t1 t1, fdw139_t2 t2, fdw139_t3 t3 WHERE t1.c1 = 11 AND t2.c1 = 12 AND t3.c1 = 13
  ORDER BY t1.c1;

-- LEFT OUTER JOIN
--Testcase 33:
EXPLAIN (COSTS false, VERBOSE)
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 LEFT JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c1, t2.c1 NULLS LAST;
--Testcase 34:
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 LEFT JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c1, t2.c1 NULLS LAST;

-- LEFT JOIN evaluating as INNER JOIN, having unsafe join clause.
--Testcase 35:
EXPLAIN (COSTS false, VERBOSE)
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 LEFT JOIN fdw139_t2 t2 ON (abs(t1.c1) = t2.c1)
  WHERE t2.c1 > 1 ORDER BY t1.c1, t2.c1;
--Testcase 36:
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 LEFT JOIN fdw139_t2 t2 ON (abs(t1.c1) = t2.c1)
  WHERE t2.c1 > 1 ORDER BY t1.c1, t2.c1;

-- LEFT OUTER JOIN in which join clause is not pushable.
--Testcase 37:
EXPLAIN (COSTS false, VERBOSE)
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 LEFT JOIN fdw139_t2 t2 ON (abs(t1.c1) = t2.c1)
  ORDER BY t1.c1, t2.c1;
--Testcase 38:
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 LEFT JOIN fdw139_t2 t2 ON (abs(t1.c1) = t2.c1)
  ORDER BY t1.c1, t2.c1;

-- LEFT OUTER JOIN + placement of clauses.
--Testcase 39:
EXPLAIN (COSTS false, VERBOSE)
SELECT t1.c1, t1.c2, t2.c1, t2.c2
  FROM fdw139_t1 t1 LEFT JOIN (SELECT * FROM fdw139_t2 WHERE c1 < 10) t2 ON (t1.c1 = t2.c1)
  WHERE t1.c1 < 10;
--Testcase 40:
SELECT t1.c1, t1.c2, t2.c1, t2.c2
  FROM fdw139_t1 t1 LEFT JOIN (SELECT * FROM fdw139_t2 WHERE c1 < 10) t2 ON (t1.c1 = t2.c1)
  WHERE t1.c1 < 10;

-- Clauses within the nullable side are not pulled up, but the top level clause
-- on nullable side is not pushed down into nullable side
--Testcase 41:
EXPLAIN (COSTS false, VERBOSE)
SELECT t1.c1, t1.c2, t2.c1, t2.c2
  FROM fdw139_t1 t1 LEFT JOIN (SELECT * FROM fdw139_t2 WHERE c1 < 10) t2 ON (t1.c1 = t2.c1)
  WHERE (t2.c1 < 10 OR t2.c1 IS NULL) AND t1.c1 < 10;
--Testcase 42:
SELECT t1.c1, t1.c2, t2.c1, t2.c2
  FROM fdw139_t1 t1 LEFT JOIN (SELECT * FROM fdw139_t2 WHERE c1 < 10) t2 ON (t1.c1 = t2.c1)
  WHERE (t2.c1 < 10 OR t2.c1 IS NULL) AND t1.c1 < 10;

-- RIGHT OUTER JOIN
-- target list order is different for v10 and v96.
--Testcase 43:
EXPLAIN (COSTS false, VERBOSE)
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 RIGHT JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1)
  ORDER BY t2.c1, t1.c1 NULLS LAST;
--Testcase 44:
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 RIGHT JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1)
  ORDER BY t2.c1, t1.c1 NULLS LAST;

-- Combinations of various joins
-- INNER JOIN + RIGHT JOIN
-- target list order is different for v10 and v96.
--Testcase 45:
EXPLAIN (COSTS false, VERBOSE)
SELECT t1.c1, t2.c2, t3.c3
  FROM fdw139_t1 t1 JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN fdw139_t3 t3 ON (t1.c1 = t3.c1)
  ORDER BY t1.c1 NULLS LAST, t1.c3, t1.c1;
--Testcase 46:
SELECT t1.c1, t2.c2, t3.c3
  FROM fdw139_t1 t1 JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1) RIGHT JOIN fdw139_t3 t3 ON (t1.c1 = t3.c1)
  ORDER BY t1.c1 NULLS LAST, t1.c3, t1.c1;

-- FULL OUTER JOIN, should not be pushdown as target database doesn't support
-- it.
--Testcase 47:
EXPLAIN (COSTS false, VERBOSE)
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 FULL JOIN fdw139_t1 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c1, t2.c1;
--Testcase 48:
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 FULL JOIN fdw139_t1 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c1, t2.c1;

-- Join two tables with FOR UPDATE clause
-- tests whole-row reference for row marks
-- target list order is different for v10 and v96.
--Testcase 49:
EXPLAIN (COSTS false, VERBOSE)
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c3, t1.c1 FOR UPDATE OF t1;
--Testcase 50:
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c3, t1.c1 FOR UPDATE OF t1;

-- target list order is different for v10 and v96.
--Testcase 51:
EXPLAIN (COSTS false, VERBOSE)
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c3, t1.c1 FOR UPDATE;
--Testcase 52:
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c3, t1.c1 FOR UPDATE;

-- Join two tables with FOR SHARE clause
-- target list order is different for v10 and v96.
--Testcase 53:
EXPLAIN (COSTS false, VERBOSE)
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c3, t1.c1 FOR SHARE OF t1;
--Testcase 54:
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c3, t1.c1 FOR SHARE OF t1;

-- target list order is different for v10 and v96.
--Testcase 55:
EXPLAIN (COSTS false, VERBOSE)
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c3, t1.c1 FOR SHARE;
--Testcase 56:
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c3, t1.c1 FOR SHARE;

-- Join in CTE.
-- Explain plan difference between v11 (or pre) and later.
--Testcase 57:
EXPLAIN (COSTS false, VERBOSE)
WITH t (c1_1, c1_3, c2_1) AS (
  SELECT t1.c1, t1.c3, t2.c1
    FROM fdw139_t1 t1 JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1)
) SELECT c1_1, c2_1 FROM t ORDER BY c1_3, c1_1;
--Testcase 58:
WITH t (c1_1, c1_3, c2_1) AS (
  SELECT t1.c1, t1.c3, t2.c1
    FROM fdw139_t1 t1 JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1)
) SELECT c1_1, c2_1 FROM t ORDER BY c1_3, c1_1;

-- Whole-row reference
--Testcase 59:
EXPLAIN (COSTS false, VERBOSE)
SELECT t1, t2, t1.c1
  FROM fdw139_t1 t1 JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c3, t1.c1;
--Testcase 60:
SELECT t1, t2, t1.c1
  FROM fdw139_t1 t1 JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c3, t1.c1;

-- SEMI JOIN, not pushed down
--Testcase 61:
EXPLAIN (COSTS false, VERBOSE)
SELECT t1.c1
  FROM fdw139_t1 t1 WHERE EXISTS (SELECT 1 FROM fdw139_t2 t2 WHERE t1.c1 = t2.c1)
  ORDER BY t1.c1 LIMIT 10;
--Testcase 62:
SELECT t1.c1
  FROM fdw139_t1 t1 WHERE EXISTS (SELECT 1 FROM fdw139_t2 t2 WHERE t1.c1 = t2.c1)
  ORDER BY t1.c1 LIMIT 10;

-- ANTI JOIN, not pushed down
--Testcase 63:
EXPLAIN (COSTS false, VERBOSE)
SELECT t1.c1
  FROM fdw139_t1 t1 WHERE NOT EXISTS (SELECT 1 FROM fdw139_t2 t2 WHERE t1.c1 = t2.c2)
  ORDER BY t1.c1 LIMIT 10;
--Testcase 64:
SELECT t1.c1
  FROM fdw139_t1 t1 WHERE NOT EXISTS (SELECT 1 FROM fdw139_t2 t2 WHERE t1.c1 = t2.c2)
  ORDER BY t1.c1 LIMIT 10;

-- CROSS JOIN can be pushed down
--Testcase 65:
EXPLAIN (COSTS false, VERBOSE)
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 CROSS JOIN fdw139_t2 t2
  ORDER BY t1.c1, t2.c1 LIMIT 10;
--Testcase 66:
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 CROSS JOIN fdw139_t2 t2
  ORDER BY t1.c1, t2.c1 LIMIT 10;

-- CROSS JOIN combined with local table.
--Testcase 67:
CREATE TABLE local_t1(c1 int);
--Testcase 68:
INSERT INTO local_t1 VALUES (1), (2);

--Testcase 69:
EXPLAIN (COSTS false, VERBOSE)
SELECT t1.c1, t2.c1, l1.c1
  FROM fdw139_t1 t1 CROSS JOIN fdw139_t2 t2 CROSS JOIN local_t1 l1
  ORDER BY t1.c1, t2.c1, l1.c1 LIMIT 10;
--Testcase 70:
SELECT t1.c1, t2.c1, l1.c1
  FROM fdw139_t1 t1 CROSS JOIN fdw139_t2 t2 CROSS JOIN local_t1 l1
  ORDER BY t1.c1, t2.c1, l1.c1 LIMIT 10;
--Testcase 71:
SELECT count(t1.c1)
  FROM fdw139_t1 t1 CROSS JOIN fdw139_t2 t2 CROSS JOIN local_t1 l1;

-- Join two tables from two different foreign table
--Testcase 72:
EXPLAIN (COSTS false, VERBOSE)
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 JOIN fdw139_t4 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c3, t1.c1;
--Testcase 73:
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 JOIN fdw139_t4 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c3, t1.c1;

-- Unsafe join conditions (c4 has a UDT), not pushed down.
--Testcase 74:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 LEFT JOIN fdw139_t2 t2 ON (t1.c4 = t2.c4)
  ORDER BY t1.c1, t2.c1;
--Testcase 75:
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 LEFT JOIN fdw139_t2 t2 ON (t1.c4 = t2.c4)
  ORDER BY t1.c1, t2.c1;

-- Unsafe conditions on one side (c4 has a UDT), not pushed down.
--Testcase 76:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 LEFT JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1) WHERE t1.c4 = 'foo'
  ORDER BY t1.c1, t2.c1 NULLS LAST;
--Testcase 77:
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 LEFT JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1) WHERE t1.c4 = 'foo'
  ORDER BY t1.c1, t2.c1 NULLS LAST;

-- Join where unsafe to pushdown condition in WHERE clause has a column not
-- in the SELECT clause.  In this test unsafe clause needs to have column
-- references from both joining sides so that the clause is not pushed down
-- into one of the joining sides.
-- target list order is different for v10 and v96.
--Testcase 78:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1) WHERE t1.c4 = t2.c4
  ORDER BY t1.c3, t1.c1;
--Testcase 79:
SELECT t1.c1, t2.c1
  FROM fdw139_t1 t1 JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1) WHERE t1.c4 = t2.c4
  ORDER BY t1.c3, t1.c1;

-- Check join pushdown in situations where multiple userids are involved
--Testcase 80:
CREATE ROLE regress_view_owner SUPERUSER;
--Testcase 81:
CREATE USER MAPPING FOR regress_view_owner
  SERVER mysql_svr OPTIONS (username :MYSQL_USER_NAME, password :MYSQL_PASS);
GRANT SELECT ON fdw139_t1 TO regress_view_owner;
GRANT SELECT ON fdw139_t2 TO regress_view_owner;

--Testcase 82:
CREATE VIEW v1 AS SELECT * FROM fdw139_t1;
--Testcase 83:
CREATE VIEW v2 AS SELECT * FROM fdw139_t2;
--Testcase 84:
ALTER VIEW v2 OWNER TO regress_view_owner;

--Testcase 85:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2
  FROM v1 t1 LEFT JOIN v2 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c1, t2.c1, t2.c2 NULLS LAST LIMIT 10;  -- not pushed down, different view owners
--Testcase 86:
SELECT t1.c1, t2.c2
  FROM v1 t1 LEFT JOIN v2 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c1, t2.c1, t2.c2 NULLS LAST LIMIT 10;

--Testcase 87:
ALTER VIEW v1 OWNER TO regress_view_owner;
--Testcase 88:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2
  FROM v1 t1 LEFT JOIN v2 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c1, t2.c1, t2.c2 NULLS LAST LIMIT 10;  -- pushed down
--Testcase 89:
SELECT t1.c1, t2.c2
  FROM v1 t1 LEFT JOIN v2 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c1, t2.c1, t2.c2 NULLS LAST LIMIT 10;

--Testcase 90:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2
  FROM v1 t1 LEFT JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c1, t2.c1, t2.c2 NULLS LAST LIMIT 10;  -- not pushed down, view owner not current user
--Testcase 91:
SELECT t1.c1, t2.c2
  FROM v1 t1 LEFT JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c1, t2.c1, t2.c2 NULLS LAST LIMIT 10;

--Testcase 92:
ALTER VIEW v1 OWNER TO CURRENT_USER;
--Testcase 93:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t2.c2
  FROM v1 t1 LEFT JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c1, t2.c1, t2.c2 NULLS LAST LIMIT 10;  -- pushed down
--Testcase 94:
SELECT t1.c1, t2.c2
  FROM v1 t1 LEFT JOIN fdw139_t2 t2 ON (t1.c1 = t2.c1)
  ORDER BY t1.c1, t2.c1, t2.c2 NULLS LAST LIMIT 10;
--Testcase 95:
ALTER VIEW v1 OWNER TO regress_view_owner;

-- Non-Var items in targetlist of the nullable rel of a join preventing
-- push-down in some cases
-- Unable to push {fdw139_t1, fdw139_t2}
--Testcase 96:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT q.a, fdw139_t2.c1
  FROM (SELECT 13 FROM fdw139_t1 WHERE c1 = 13) q(a) RIGHT JOIN fdw139_t2 ON (q.a = fdw139_t2.c1)
  WHERE fdw139_t2.c1 BETWEEN 10 AND 15;
--Testcase 97:
SELECT q.a, fdw139_t2.c1
  FROM (SELECT 13 FROM fdw139_t1 WHERE c1 = 13) q(a) RIGHT JOIN fdw139_t2 ON (q.a = fdw139_t2.c1)
  WHERE fdw139_t2.c1 BETWEEN 10 AND 15;

-- Ok to push {fdw139_t1, fdw139_t2 but not {fdw139_t1, fdw139_t2, fdw139_t3}
--Testcase 98:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT fdw139_t3.c1, q.*
  FROM fdw139_t3 LEFT JOIN (
    SELECT 13, fdw139_t1.c1, fdw139_t2.c1
    FROM fdw139_t1 RIGHT JOIN fdw139_t2 ON (fdw139_t1.c1 = fdw139_t2.c1)
    WHERE fdw139_t1.c1 = 11
  ) q(a, b, c) ON (fdw139_t3.c1 = q.b)
  WHERE fdw139_t3.c1 BETWEEN 10 AND 15;
--Testcase 99:
SELECT fdw139_t3.c1, q.*
  FROM fdw139_t3 LEFT JOIN (
    SELECT 13, fdw139_t1.c1, fdw139_t2.c1
    FROM fdw139_t1 RIGHT JOIN fdw139_t2 ON (fdw139_t1.c1 = fdw139_t2.c1)
    WHERE fdw139_t1.c1 = 11
  ) q(a, b, c) ON (fdw139_t3.c1 = q.b)
  WHERE fdw139_t3.c1 BETWEEN 10 AND 15;

-- Delete existing data and load new data for partition-wise join test cases.
--Testcase 100:
DROP OWNED BY regress_view_owner;
--Testcase 101:
DROP ROLE regress_view_owner;
--Testcase 102:
DELETE FROM fdw139_t1;
--Testcase 103:
DELETE FROM fdw139_t2;
--Testcase 104:
DELETE FROM fdw139_t3;
--Testcase 105:
INSERT INTO fdw139_t1 values(1, 1, 'AAA1', 'foo');
--Testcase 106:
INSERT INTO fdw139_t1 values(2, 2, 'AAA2', 'bar');
--Testcase 107:
INSERT INTO fdw139_t1 values(3, 3, 'AAA11', 'foo');
--Testcase 108:
INSERT INTO fdw139_t1 values(4, 4, 'AAA12', 'foo');

--Testcase 109:
INSERT INTO fdw139_t2 values(5, 5, 'BBB1', 'foo');
--Testcase 110:
INSERT INTO fdw139_t2 values(6, 6, 'BBB2', 'bar');
--Testcase 111:
INSERT INTO fdw139_t2 values(7, 7, 'BBB11', 'foo');
--Testcase 112:
INSERT INTO fdw139_t2 values(8, 8, 'BBB12', 'foo');

--Testcase 113:
INSERT INTO fdw139_t3 values(1, 1, 'CCC1');
--Testcase 114:
INSERT INTO fdw139_t3 values(2, 2, 'CCC2');
--Testcase 115:
INSERT INTO fdw139_t3 values(3, 3, 'CCC13');
--Testcase 116:
INSERT INTO fdw139_t3 values(4, 4, 'CCC14');
--Testcase 117:
DROP FOREIGN TABLE fdw139_t4;
--Testcase 118:
CREATE FOREIGN TABLE tmp_t4(c1 int, c2 int, c3 text)
  SERVER mysql_svr1 OPTIONS(dbname 'mysql_fdw_regress', table_name 'test4');
--Testcase 119:
INSERT INTO tmp_t4 values(5, 5, 'CCC1');
--Testcase 120:
INSERT INTO tmp_t4 values(6, 6, 'CCC2');
--Testcase 121:
INSERT INTO tmp_t4 values(7, 7, 'CCC13');
--Testcase 122:
INSERT INTO tmp_t4 values(8, 8, 'CCC13');

-- Test partition-wise join
--Testcase 123:
SET enable_partitionwise_join TO on;

-- Create the partition table in plpgsql block as those are failing with
-- different error messages on back-branches.
-- All test cases related to partition-wise join gives an error on v96 and v95
-- as partition syntax is not supported there.
DO
$$
BEGIN
--Testcase 124:
  EXECUTE 'CREATE TABLE fprt1 (c1 int, c2 int, c3 varchar, c4 varchar) PARTITION BY RANGE(c1)';
EXCEPTION WHEN others THEN
  RAISE NOTICE 'syntax error';
END;
$$
LANGUAGE plpgsql;
--Testcase 125:
CREATE FOREIGN TABLE ftprt1_p1 PARTITION OF fprt1 FOR VALUES FROM (1) TO (4)
  SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_regress', table_name 'test1');
--Testcase 126:
CREATE FOREIGN TABLE ftprt1_p2 PARTITION OF fprt1 FOR VALUES FROM (5) TO (8)
  SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_regress', TABLE_NAME 'test2');

DO
$$
BEGIN
--Testcase 127:
  EXECUTE 'CREATE TABLE fprt2 (c1 int, c2 int, c3 varchar) PARTITION BY RANGE(c2)';
EXCEPTION WHEN syntax_error THEN
  RAISE NOTICE 'syntax error';
END;
$$
LANGUAGE plpgsql;
--Testcase 128:
CREATE FOREIGN TABLE ftprt2_p1 PARTITION OF fprt2 FOR VALUES FROM (1) TO (4)
  SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_regress', table_name 'test3');
--Testcase 129:
CREATE FOREIGN TABLE ftprt2_p2 PARTITION OF fprt2 FOR VALUES FROM (5) TO (8)
  SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_regress', TABLE_NAME 'test4');

-- Inner join three tables
-- Different explain plan on v10 as partition-wise join is not supported there.
--Testcase 130:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1,t2.c2,t3.c3
  FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.c1 = t2.c2) INNER JOIN fprt1 t3 ON (t2.c2 = t3.c1)
  WHERE t1.c1 % 2 =0 ORDER BY 1,2,3;
--Testcase 131:
SELECT t1.c1,t2.c2,t3.c3
  FROM fprt1 t1 INNER JOIN fprt2 t2 ON (t1.c1 = t2.c2) INNER JOIN fprt1 t3 ON (t2.c2 = t3.c1)
  WHERE t1.c1 % 2 =0 ORDER BY 1,2,3;

-- With whole-row reference; partitionwise join does not apply
-- Table alias in foreign scan is different for v12, v11 and v10.
--Testcase 132:
EXPLAIN (VERBOSE, COSTS false)
SELECT t1, t2, t1.c1
  FROM fprt1 t1 JOIN fprt2 t2 ON (t1.c1 = t2.c2)
  ORDER BY t1.c3, t1.c1;
--Testcase 133:
SELECT t1, t2, t1.c1
  FROM fprt1 t1 JOIN fprt2 t2 ON (t1.c1 = t2.c2)
  ORDER BY t1.c3, t1.c1;

-- Join with lateral reference
-- Different explain plan on v10 as partition-wise join is not supported there.
--Testcase 134:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1,t1.c2
  FROM fprt1 t1, LATERAL (SELECT t2.c1, t2.c2 FROM fprt2 t2
  WHERE t1.c1 = t2.c2 AND t1.c2 = t2.c1) q WHERE t1.c1 % 2 = 0 ORDER BY 1,2;
--Testcase 135:
SELECT t1.c1,t1.c2
  FROM fprt1 t1, LATERAL (SELECT t2.c1, t2.c2 FROM fprt2 t2
  WHERE t1.c1 = t2.c2 AND t1.c2 = t2.c1) q WHERE t1.c1 % 2 = 0 ORDER BY 1,2;

-- With PHVs, partitionwise join selected but no join pushdown
-- Table alias in foreign scan is different for v12, v11 and v10.
--Testcase 136:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT t1.c1, t1.phv, t2.c2, t2.phv
  FROM (SELECT 't1_phv' phv, * FROM fprt1 WHERE c1 % 2 = 0) t1 LEFT JOIN
    (SELECT 't2_phv' phv, * FROM fprt2 WHERE c2 % 2 = 0) t2 ON (t1.c1 = t2.c2)
  ORDER BY t1.c1, t2.c2;
--Testcase 137:
SELECT t1.c1, t1.phv, t2.c2, t2.phv
  FROM (SELECT 't1_phv' phv, * FROM fprt1 WHERE c1 % 2 = 0) t1 LEFT JOIN
    (SELECT 't2_phv' phv, * FROM fprt2 WHERE c2 % 2 = 0) t2 ON (t1.c1 = t2.c2)
  ORDER BY t1.c1, t2.c2;

--Testcase 138:
SET enable_partitionwise_join TO off;

-- Cleanup
--Testcase 139:
DELETE FROM fdw139_t1;
--Testcase 140:
DELETE FROM fdw139_t2;
--Testcase 141:
DELETE FROM fdw139_t3;
--Testcase 142:
DELETE FROM tmp_t4;
--Testcase 143:
DROP FOREIGN TABLE fdw139_t1;
--Testcase 144:
DROP FOREIGN TABLE fdw139_t2;
--Testcase 145:
DROP FOREIGN TABLE fdw139_t3;
--Testcase 146:
DROP FOREIGN TABLE tmp_t4;
--Testcase 147:
DROP TABLE IF EXISTS fprt1;
--Testcase 148:
DROP TABLE IF EXISTS fprt2;
--Testcase 149:
DROP USER MAPPING FOR public SERVER mysql_svr;
--Testcase 150:
DROP USER MAPPING FOR public SERVER mysql_svr1;
--Testcase 151:
DROP SERVER mysql_svr;
--Testcase 152:
DROP SERVER mysql_svr1;
--Testcase 153:
DROP EXTENSION mysql_fdw;
