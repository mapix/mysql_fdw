\set ECHO none
\ir sql/parameters.conf
\set ECHO all

-- Before running this file User must create database mysql_fdw_regress on
-- mysql with all permission for MYSQL_USER_NAME user with MYSQL_PWD password
-- and ran mysql_init.sh file to create tables.

\c contrib_regression
--Testcase 1:
CREATE EXTENSION IF NOT EXISTS mysql_fdw;
--Testcase 2:
CREATE SERVER mysql_svr FOREIGN DATA WRAPPER mysql_fdw
  OPTIONS (host :MYSQL_HOST, port :MYSQL_PORT);
--Testcase 3:
CREATE USER MAPPING FOR public SERVER mysql_svr
  OPTIONS (username :MYSQL_USER_NAME, password :MYSQL_PASS);

-- Create foreign tables
--Testcase 4:
CREATE FOREIGN TABLE f_test_tbl1 (c1 INTEGER, c2 VARCHAR(10), c3 CHAR(9), c4 BIGINT, c5 pg_catalog.Date, c6 DECIMAL, c7 INTEGER, c8 SMALLINT)
  SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_regress', table_name 'test_tbl1');
--Testcase 5:
CREATE FOREIGN TABLE f_test_tbl2 (c1 INTEGER, c2 VARCHAR(14), c3 VARCHAR(13))
  SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_regress', table_name 'test_tbl2');

-- Insert data in mysql db using foreign tables
--Testcase 6:
INSERT INTO f_test_tbl1 VALUES (100, 'EMP1', 'ADMIN', 1300, '1980-12-17', 800.23, NULL, 20);
--Testcase 7:
INSERT INTO f_test_tbl1 VALUES (200, 'EMP2', 'SALESMAN', 600, '1981-02-20', 1600.00, 300, 30);
--Testcase 8:
INSERT INTO f_test_tbl1 VALUES (300, 'EMP3', 'SALESMAN', 600, '1981-02-22', 1250, 500, 30);
--Testcase 9:
INSERT INTO f_test_tbl1 VALUES (400, 'EMP4', 'MANAGER', 900, '1981-04-02', 2975.12, NULL, 20);
--Testcase 10:
INSERT INTO f_test_tbl1 VALUES (500, 'EMP5', 'SALESMAN', 600, '1981-09-28', 1250, 1400, 30);
--Testcase 11:
INSERT INTO f_test_tbl1 VALUES (600, 'EMP6', 'MANAGER', 900, '1981-05-01', 2850, NULL, 30);
--Testcase 12:
INSERT INTO f_test_tbl1 VALUES (700, 'EMP7', 'MANAGER', 900, '1981-06-09', 2450.45, NULL, 10);
--Testcase 13:
INSERT INTO f_test_tbl1 VALUES (800, 'EMP8', 'FINANCE', 400, '1987-04-19', 3000, NULL, 20);
--Testcase 14:
INSERT INTO f_test_tbl1 VALUES (900, 'EMP9', 'HEAD', NULL, '1981-11-17', 5000, NULL, 10);
--Testcase 15:
INSERT INTO f_test_tbl1 VALUES (1000, 'EMP10', 'SALESMAN', 600, '1980-09-08', 1500, 0, 30);
--Testcase 16:
INSERT INTO f_test_tbl1 VALUES (1100, 'EMP11', 'ADMIN', 800, '1987-05-23', 1100, NULL, 20);
--Testcase 17:
INSERT INTO f_test_tbl1 VALUES (1200, 'EMP12', 'ADMIN', 600, '1981-12-03', 950, NULL, 30);
--Testcase 18:
INSERT INTO f_test_tbl1 VALUES (1300, 'EMP13', 'FINANCE', 400, '1981-12-03', 3000, NULL, 20);
--Testcase 19:
INSERT INTO f_test_tbl1 VALUES (1400, 'EMP14', 'ADMIN', 700, '1982-01-23', 1300, NULL, 10);
--Testcase 20:
INSERT INTO f_test_tbl2 VALUES(10, 'DEVELOPMENT', 'PUNE');
--Testcase 21:
INSERT INTO f_test_tbl2 VALUES(20, 'ADMINISTRATION', 'BANGLORE');
--Testcase 22:
INSERT INTO f_test_tbl2 VALUES(30, 'SALES', 'MUMBAI');
--Testcase 23:
INSERT INTO f_test_tbl2 VALUES(40, 'HR', 'NAGPUR');

SET datestyle TO ISO;

-- WHERE clause pushdown

--Testcase 24:
EXPLAIN (VERBOSE, COSTS FALSE)
SELECT c1, c2, c6 AS "salary", c8 FROM f_test_tbl1 e
  WHERE c6 IN (800,2450)
  ORDER BY c1;
--Testcase 25:
SELECT c1, c2, c6 AS "salary", c8 FROM f_test_tbl1 e
  WHERE c6 IN (800,2450)
  ORDER BY c1;

--Testcase 26:
EXPLAIN (VERBOSE, COSTS FALSE)
SELECT * FROM f_test_tbl1 e
  WHERE c6 > 3000
  ORDER BY c1;
--Testcase 27:
SELECT * FROM f_test_tbl1 e
  WHERE c6 > 3000
  ORDER BY c1;

--Testcase 28:
EXPLAIN (VERBOSE, COSTS FALSE)
SELECT c1, c2, c6, c8 FROM f_test_tbl1 e
  WHERE c6 = 1500
  ORDER BY c1;
--Testcase 29:
SELECT c1, c2, c6, c8 FROM f_test_tbl1 e
  WHERE c6 = 1500
  ORDER BY c1;

--Testcase 30:
EXPLAIN (VERBOSE, COSTS FALSE)
SELECT c1, c2, c6, c8 FROM f_test_tbl1 e
  WHERE c6 BETWEEN 1000 AND 4000
  ORDER BY c1;
--Testcase 31:
SELECT c1, c2, c6, c8 FROM f_test_tbl1 e
  WHERE c6 BETWEEN 1000 AND 4000
  ORDER BY c1;

--Testcase 32:
EXPLAIN (VERBOSE, COSTS FALSE)
SELECT c1, c2, c6, c8 FROM f_test_tbl1 e
  WHERE c2 IS NOT NULL
  ORDER BY c1;
--Testcase 33:
SELECT c1, c2, c6, c8 FROM f_test_tbl1 e
  WHERE c2 IS NOT NULL
  ORDER BY c1;

--Testcase 34:
EXPLAIN (VERBOSE, COSTS FALSE)
SELECT * FROM f_test_tbl1 e
  WHERE c5 <= '1980-12-17'
  ORDER BY c1;
--Testcase 35:
SELECT * FROM f_test_tbl1 e
  WHERE c5 <= '1980-12-17'
  ORDER BY c1;

--Testcase 36:
EXPLAIN (VERBOSE, COSTS FALSE)
SELECT c1, c2, c6, c8 FROM f_test_tbl1 e
  WHERE c2 IN ('EMP6', 'EMP12', 'EMP5')
  ORDER BY c1;
--Testcase 37:
SELECT c1, c2, c6, c8 FROM f_test_tbl1 e
  WHERE c2 IN ('EMP6', 'EMP12', 'EMP5')
  ORDER BY c1;

--Testcase 38:
EXPLAIN (VERBOSE, COSTS FALSE)
SELECT c1, c2, c6, c8 FROM f_test_tbl1 e
  WHERE c2 IN ('EMP6', 'EMP12', 'EMP5')
  ORDER BY c1;
--Testcase 39:
SELECT c1, c2, c6, c8 FROM f_test_tbl1 e
  WHERE c2 IN ('EMP6', 'EMP12', 'EMP5')
  ORDER BY c1;

--Testcase 40:
EXPLAIN (VERBOSE, COSTS FALSE)
SELECT c1, c2, c6, c8 FROM f_test_tbl1 e
  WHERE c3 LIKE 'SALESMAN'
  ORDER BY c1;
--Testcase 41:
SELECT c1, c2, c6, c8 FROM f_test_tbl1 e
  WHERE c3 LIKE 'SALESMAN'
  ORDER BY c1;

--Testcase 42:
EXPLAIN (VERBOSE, COSTS FALSE)
SELECT c1, c2, c6, c8 FROM f_test_tbl1 e
  WHERE c3 LIKE 'MANA%'
  ORDER BY c1;
--Testcase 43:
SELECT c1, c2, c6, c8 FROM f_test_tbl1 e
  WHERE c3 LIKE 'MANA%'
  ORDER BY c1;

-- Aggregate pushdown
--Testcase 51:
CREATE FOREIGN TABLE aggtest (
  a       int2,
  b     float4
) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'aggtest');

--Testcase 52:
SELECT * FROM aggtest;

--Testcase 53:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT avg(a) AS avg_32 FROM aggtest WHERE a < 100;
--Testcase 54:
SELECT avg(a) AS avg_32 FROM aggtest WHERE a < 100;

--Testcase 55:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT sum(a) AS sum_198 FROM aggtest;
--Testcase 56:
SELECT sum(a) AS sum_198 FROM aggtest;

--Testcase 57:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT sum(b) AS avg_431_773 FROM aggtest;
--Testcase 58:
SELECT sum(b) AS avg_431_773 FROM aggtest;

--Testcase 59:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT max(a) AS max_100 FROM aggtest;
--Testcase 60:
SELECT max(a) AS max_100 FROM aggtest;

--Testcase 61:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT max(aggtest.b) AS max_324_78 FROM aggtest;
--Testcase 62:
SELECT max(aggtest.b) AS max_324_78 FROM aggtest;

--Testcase 63:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT min(a) AS min_0 FROM aggtest;
--Testcase 64:
SELECT min(a) AS min_0 FROM aggtest;

--Testcase 65:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT count(a) FROM aggtest;
--Testcase 66:
SELECT count(a) FROM aggtest;

--Testcase 67:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT min(aggtest.b) AS min_7_8 FROM aggtest WHERE b > 5;
--Testcase 68:
SELECT min(aggtest.b) AS min_7_8 FROM aggtest WHERE b > 5;

--Testcase 69:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT stddev_pop(b) FROM aggtest;
--Testcase 70:
SELECT stddev_pop(b) FROM aggtest;

--Testcase 71:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT stddev_samp(b) FROM aggtest;
--Testcase 72:
SELECT stddev_samp(b) FROM aggtest;

--Testcase 73:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT var_pop(b) FROM aggtest;
--Testcase 74:
SELECT var_pop(b) FROM aggtest;

--Testcase 75:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT var_samp(b) FROM aggtest;
--Testcase 76:
SELECT var_samp(b) FROM aggtest;

--Testcase 77:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT variance(b) FROM aggtest;
--Testcase 78:
SELECT variance(b) FROM aggtest;

--Testcase 79:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT json_agg(a), json_agg(b) FROM aggtest;
--Testcase 80:
SELECT json_agg(a), json_agg(b) FROM aggtest;

--Testcase 81:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT json_object_agg(a, b) FROM aggtest;
--Testcase 82:
SELECT json_object_agg(a, b) FROM aggtest;

--Testcase 83:
CREATE FOREIGN TABLE bitwise_test(
  i2 INT2,
  i4 INT4,
  i8 INT8,
  i INTEGER,
  x INT2
) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'bitwise_test');

--Testcase 84:
DELETE FROM bitwise_test;

--Testcase 85:
INSERT INTO bitwise_test VALUES
  (1, 1, 1, 1, 1),
  (3, 3, 3, null, 2),
  (7, 7, 7, 3, 4);

--Testcase 86:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT
  BIT_AND(i2) AS "1",
  BIT_AND(i4) AS "1",
  BIT_AND(i8) AS "1",
  BIT_AND(i)  AS "?",
  BIT_AND(x)  AS "0",

  BIT_OR(i2)  AS "7",
  BIT_OR(i4)  AS "7",
  BIT_OR(i8)  AS "7",
  BIT_OR(i)   AS "?",
  BIT_OR(x)   AS "7"
FROM bitwise_test;

--Testcase 87:
SELECT
  BIT_AND(i2) AS "1",
  BIT_AND(i4) AS "1",
  BIT_AND(i8) AS "1",
  BIT_AND(i)  AS "?",
  BIT_AND(x)  AS "0",

  BIT_OR(i2)  AS "7",
  BIT_OR(i4)  AS "7",
  BIT_OR(i8)  AS "7",
  BIT_OR(i)   AS "?",
  BIT_OR(x)   AS "7"
FROM bitwise_test;

-- Cleanup
--Testcase 44:
DELETE FROM f_test_tbl1;
--Testcase 45:
DELETE FROM f_test_tbl2;
--Testcase 46:
DROP FOREIGN TABLE f_test_tbl1;
--Testcase 47:
DROP FOREIGN TABLE f_test_tbl2;
--Testcase 88:
DROP FOREIGN TABLE aggtest;
--Testcase 89:
DROP FOREIGN TABLE bitwise_test;
--Testcase 48:
DROP USER MAPPING FOR public SERVER mysql_svr;
--Testcase 49:
DROP SERVER mysql_svr;
--Testcase 50:
DROP EXTENSION mysql_fdw;
