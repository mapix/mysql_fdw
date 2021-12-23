\set ECHO none
\ir sql/parameters.conf
\set ECHO all
--Testcase 179:
SET datestyle TO "ISO, YMD";

--Testcase 1:
CREATE EXTENSION mysql_fdw;

--Testcase 2:
\df mysql_fdw*
--Testcase 180:
SELECT * FROM public.mysql_fdw_version();
--Testcase 181:
SELECT mysql_fdw_version();

-- Before running this file User must create database mysql_fdw_regress on
-- MySQL with all permission for 'edb' user with 'edb' password and ran
-- mysql_init.sh file to create tables.
--Testcase 3:
CREATE SERVER mysql_svr FOREIGN DATA WRAPPER mysql_fdw
  OPTIONS (host :MYSQL_HOST, port :MYSQL_PORT);
--Testcase 4:
CREATE USER MAPPING FOR PUBLIC SERVER mysql_svr
  OPTIONS (username :MYSQL_USER_NAME, password :MYSQL_PASS);
-- ===================================================================
-- create foreign tables
-- ===================================================================
--Testcase 5:
CREATE FOREIGN TABLE ft1 (c1 INTEGER, c2 INTEGER, c3 CHAR(9), c4 timestamptz, c5 timestamp, c6 DECIMAL, c7 INTEGER, c8 SMALLINT)
  SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_post', table_name 'position_data1');
--Testcase 6:
CREATE FOREIGN TABLE ft2 (c1 INTEGER, c2 INTEGER, c3 CHAR(9), c4 timestamptz, c5 timestamptz, c6 DECIMAL, c7 INTEGER, c8 SMALLINT)
  SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_post', table_name 'position_data2');
--Testcase 7:
CREATE FOREIGN TABLE ft3 (i int, b bool)
  SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_post', table_name 'table_data');
--Testcase 8:
INSERT INTO ft1 VALUES (1, 1, 'ADMIN', '1970-01-01'::timestamptz, '1970-05-06 00:00:00', 800.23, NULL, 20);
--Testcase 9:
INSERT INTO ft1 VALUES (2, 2, 'SALESMAN', '1970-01-01'::timestamptz, '1970-05-07 00:00:00', 1600.00, 300, 30);
--Testcase 10:
INSERT INTO ft1 VALUES (3, 3, 'SALESMAN', '1970-01-01'::timestamptz, '1970-05-08 00:00:00', 1250, 500, 30);
--Testcase 11:
INSERT INTO ft1 VALUES (4, 4, 'MANAGER', '1970-01-01'::timestamptz, '1970-05-09 00:00:00', 2975.12, NULL, 20);
--Testcase 12:
INSERT INTO ft1 VALUES (5, 5, 'SALESMAN', '1970-01-01'::timestamptz, '1970-05-10 00:00:00', 1250, 1400, 30);
--Testcase 13:
INSERT INTO ft1 VALUES (6, 6, 'MANAGER', '1970-01-01'::timestamptz, '1970-05-11 00:00:00', 2850, NULL, 30);
--Testcase 14:
INSERT INTO ft1 VALUES (7, 7, 'MANAGER', '1970-01-01'::timestamptz, '1970-05-12 00:00:00', 2450.45, NULL, 10);
--Testcase 15:
INSERT INTO ft1 VALUES (8, 8, 'FINANCE', '1970-01-01'::timestamptz, '1970-05-13 00:00:00', 3000, NULL, 20);
--Testcase 16:
INSERT INTO ft1 VALUES (9, 9, 'HEAD', '1970-01-01'::timestamptz, '1970-05-14 00:00:00', 5000, NULL, 10);
--Testcase 17:
INSERT INTO ft1 VALUES (10, 10, 'SALESMAN', '1970-01-01'::timestamptz, '1970-05-15 00:00:00', 1500, 0, 30);
--Testcase 18:
INSERT INTO ft2 VALUES(1, 1, 'ADMIN','1970-01-01'::timestamptz, '1970-05-06 00:00:00', 800, NULL, 20);
--Testcase 19:
INSERT INTO ft2 VALUES(2, 2, 'DEVELOPER','1970-01-01'::timestamptz, '1970-05-07 00:00:00', 809, 250, 20);
--Testcase 20:
INSERT INTO ft2 VALUES(3, 3, 'TESTER', '1970-01-01'::timestamptz, '1970-05-08 00:00:00', 809, 251, 20);
--Testcase 21:
INSERT INTO ft2 VALUES(4, 4, 'SALEMAN', '1970-01-01'::timestamptz, '1970-05-09 00:00:00', 809, 252, 20);
--Testcase 22:
INSERT INTO ft2 VALUES(5, 5, 'SALEMAN', '1970-01-01'::timestamptz, '1970-05-10 00:00:00', 808, 252, 20);
--Testcase 23:
INSERT INTO ft2 VALUES(6, 6, 'MANAGER', '1970-01-01'::timestamptz, '1970-05-11 00:00:00', 809, 252, 20);
--Testcase 24:
INSERT INTO ft2 VALUES(7, 7, 'SALEMAN', '1970-01-01'::timestamptz, '1970-05-12 00:00:00', 809, 252, 20);
--Testcase 25:
INSERT INTO ft2 VALUES(8, 8, 'SALEMAN', '1970-01-01'::timestamptz, '1970-05-13 00:00:00', 809, 252, 20);
--Testcase 26:
INSERT INTO ft2 VALUES(9, 9, 'HEAD', '1970-01-01'::timestamptz, '1970-05-14 00:00:00', 809, 252, 20);
--Testcase 27:
INSERT INTO ft2 VALUES(10, 10, 'FINANCE', '1970-01-01'::timestamptz, '1970-05-15 00:00:00', 809, 252, 20);
--Testcase 28:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE (c1 IS NOT NULL) IS DISTINCT FROM (c7 IS NOT NULL);
--Testcase 29:
SELECT * FROM ft1 t1 WHERE (c1 IS NOT NULL) IS DISTINCT FROM (c7 IS NOT NULL);
--Testcase 30:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE (c1 IS NOT NULL) IS NOT DISTINCT FROM (c1 IS NOT NULL);
--Testcase 31:
SELECT * FROM ft1 t1 WHERE (c1 IS NOT NULL) IS NOT DISTINCT FROM (c1 IS NOT NULL);
--Testcase 32:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE NOT(c1 > 4 OR (c1 IS NOT NULL) IS NOT DISTINCT FROM (c7 IS NOT NULL));
--Testcase 33:
SELECT * FROM ft1 t1 WHERE NOT(c1 > 4 OR (c1 IS NOT NULL) IS NOT DISTINCT FROM (c7 IS NOT NULL));
--Testcase 34:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE NOT(c1 > 4 AND (c1 IS NOT NULL) IS NOT DISTINCT FROM (c1 IS NOT NULL));
--Testcase 35:
SELECT * FROM ft1 t1 WHERE NOT(c1 > 4 AND (c1 IS NOT NULL) IS NOT DISTINCT FROM (c1 IS NOT NULL));
--Testcase 36:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT ((1 IS DISTINCT FROM i) IS NOT DISTINCT FROM b) from ft3;
--Testcase 37:
SELECT ((1 IS DISTINCT FROM i) IS NOT DISTINCT FROM b) from ft3;
--Testcase 38:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT (b IS NOT DISTINCT FROM (1 IS DISTINCT FROM i)) from ft3;
--Testcase 39:
SELECT (b IS NOT DISTINCT FROM (1 IS DISTINCT FROM i)) from ft3;
--Testcase 40:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT i, b FROM ft3 WHERE ((1 IS DISTINCT FROM i) IS NOT DISTINCT FROM b);
--Testcase 41:
SELECT i, b FROM ft3 WHERE ((1 IS DISTINCT FROM i) IS NOT DISTINCT FROM b);
--Testcase 42:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT i, b FROM ft3 WHERE (b IS NOT DISTINCT FROM (1 IS DISTINCT FROM i));
--Testcase 43:
SELECT i, b FROM ft3 WHERE (b IS NOT DISTINCT FROM (1 IS DISTINCT FROM i));
--Testcase 177:
EXPLAIN VERBOSE
  SELECT max(c1), max(c2)+1 FROM ft1 WHERE NOT EXISTS (SELECT c1 FROM ft1 WHERE c3='none') GROUP BY c1 ORDER BY 1 ASC, 2 DESC LIMIT 5 OFFSET 0;
--Testcase 178:
SELECT max(c1), max(c2)+1 FROM ft1 WHERE NOT EXISTS (SELECT c1 FROM ft1 WHERE c3='none') GROUP BY c1 ORDER BY 1 ASC, 2 DESC LIMIT 5 OFFSET 0;

-- ===================================================================
-- Any Array Test
-- ===================================================================

-- ANY(ARRAY(parameter)) with parameter is const/expression/sub-query and operators (=, <>, <, >, <=, >=)
--Testcase 44:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c1 = ANY(ARRAY[c2, 1, c1 + 0]);
--Testcase 45:
SELECT * FROM ft1 t1 WHERE c1 = ANY(ARRAY[c2, 1, c1 + 0]);
--Testcase 46:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c1 <> ANY(ARRAY[c2, 1, c1 + 0]);
--Testcase 47:
SELECT * FROM ft1 t1 WHERE c1 <> ANY(ARRAY[c2, 1, c1 + 0]);
--Testcase 48:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c1 > ANY(ARRAY[c2, 1, c1 + 0]);
--Testcase 49:
SELECT * FROM ft1 t1 WHERE c1 > ANY(ARRAY[c2, 1, c1 + 0]);
--Testcase 50:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c1 < ANY(ARRAY[c1, 1, c2 + 1]);
--Testcase 51:
SELECT * FROM ft1 t1 WHERE c1 < ANY(ARRAY[c1, 1, c2 + 1]);
--Testcase 52:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c1 >= ANY(ARRAY[c2, 1, c1 + 0]);
--Testcase 53:
SELECT * FROM ft1 t1 WHERE c1 >= ANY(ARRAY[c2, 1, c1 + 0]);
--Testcase 54:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c1 <= ANY(ARRAY[c2, 1, c1 + 0]);
--Testcase 55:
SELECT * FROM ft1 t1 WHERE c1 <= ANY(ARRAY[c2, 1, c1 + 0]);
--Testcase 56:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c1 = ANY(ARRAY[1, 2, 3]);
--Testcase 57:
SELECT * FROM ft1 t1 WHERE c1 = ANY(ARRAY[1, 2, 3]);
--Testcase 58:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c1 <> ANY(ARRAY[1, 2, 3]);
--Testcase 59:
SELECT * FROM ft1 t1 WHERE c1 <> ANY(ARRAY[1, 2, 3]);
--Testcase 60:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c1 < ANY(ARRAY[1, 2, 3]);
--Testcase 61:
SELECT * FROM ft1 t1 WHERE c1 < ANY(ARRAY[1, 2, 3]);
--Testcase 62:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c1 > ANY(ARRAY[1, 2, 3]);
--Testcase 63:
SELECT * FROM ft1 t1 WHERE c1 > ANY(ARRAY[1, 2, 3]);
--Testcase 64:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c1 >= ANY(ARRAY[1, 2, 3]);
--Testcase 65:
SELECT * FROM ft1 t1 WHERE c1 >= ANY(ARRAY[1, 2, 3]);
--Testcase 66:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c1 <= ANY(ARRAY[1, 2, 3]);
--Testcase 67:
SELECT * FROM ft1 t1 WHERE c1 <= ANY(ARRAY[1, 2, 3]);
--Testcase 68:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c5 = ANY(ARRAY['1970-05-06 00:00:00'::timestamp,'1970-05-07 00:00:00'::timestamp]);
--Testcase 69:
SELECT * FROM ft1 t1 WHERE c5 = ANY(ARRAY['1970-05-06 00:00:00'::timestamp,'1970-05-07 00:00:00'::timestamp]);
--Testcase 70:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c5 <> ANY(ARRAY['1970-05-06 00:00:00'::timestamp,'1970-05-07 00:00:00'::timestamp]);
--Testcase 71:
SELECT * FROM ft1 t1 WHERE c5 <> ANY(ARRAY['1970-05-06 00:00:00'::timestamp,'1970-05-07 00:00:00'::timestamp]);
--Testcase 72:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c5 < ANY(ARRAY['1970-05-06 00:00:00'::timestamp,'1970-05-07 00:00:00'::timestamp]);
--Testcase 73:
SELECT * FROM ft1 t1 WHERE c5 < ANY(ARRAY['1970-05-06 00:00:00'::timestamp,'1970-05-07 00:00:00'::timestamp]);
--Testcase 74:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c5 > ANY(ARRAY['1970-05-06 00:00:00'::timestamp,'1970-05-07 00:00:00'::timestamp]);
--Testcase 75:
SELECT * FROM ft1 t1 WHERE c5 > ANY(ARRAY['1970-05-06 00:00:00'::timestamp,'1970-05-07 00:00:00'::timestamp]);
--Testcase 76:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c5 <= ANY(ARRAY['1970-05-06 00:00:00'::timestamp,'1970-05-07 00:00:00'::timestamp]);
--Testcase 77:
SELECT * FROM ft1 t1 WHERE c5 <= ANY(ARRAY['1970-05-06 00:00:00'::timestamp,'1970-05-07 00:00:00'::timestamp]);
--Testcase 78:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c5 >= ANY(ARRAY['1970-05-06 00:00:00'::timestamp,'1970-05-07 00:00:00'::timestamp]);
--Testcase 79:
SELECT * FROM ft1 t1 WHERE c5 >= ANY(ARRAY['1970-05-06 00:00:00'::timestamp,'1970-05-07 00:00:00'::timestamp]);
--Testcase 80:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 WHERE c1 = ANY (ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
--Testcase 81:
SELECT * FROM ft1 WHERE c1 = ANY (ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
--Testcase 82:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 WHERE c1 <> ANY(ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
--Testcase 83:
SELECT * FROM ft1 WHERE c1 <> ANY(ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
--Testcase 84:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 WHERE c1 > ANY (ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
--Testcase 85:
SELECT * FROM ft1 WHERE c1 > ANY (ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
--Testcase 86:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 WHERE c1 < ANY (ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
--Testcase 87:
SELECT * FROM ft1 WHERE c1 < ANY (ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
--Testcase 88:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 WHERE c1 >= ANY (ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
--Testcase 89:
SELECT * FROM ft1 WHERE c1 >= ANY (ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
--Testcase 90:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 WHERE c1 <= ANY (ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
--Testcase 91:
SELECT * FROM ft1 WHERE c1 <= ANY (ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
-- ALL(ARRAY(parameter)) with parameter is const/expression/sub-query and operators (=, <>, <, >, <=, >=)
--Testcase 92:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c1 <> ALL(ARRAY[c1 + 1, 1, 3]);
--Testcase 93:
SELECT * FROM ft1 t1 WHERE c1 <> ALL(ARRAY[c1 + 1, 1, 3]);
--Testcase 94:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c1 > ALL(ARRAY[c1 - 1, 1, 3]);
--Testcase 95:
SELECT * FROM ft1 t1 WHERE c1 > ALL(ARRAY[c1 - 1, 1, 3]);
--Testcase 96:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c1 < ALL(ARRAY[c1 + 1, 5, 6]);
--Testcase 97:
SELECT * FROM ft1 t1 WHERE c1 < ALL(ARRAY[c1 + 1, 5, 6]);
--Testcase 98:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c1 >= ALL(ARRAY[c1, 1, 3]);
--Testcase 99:
SELECT * FROM ft1 t1 WHERE c1 >= ALL(ARRAY[c1, 1, 3]);
--Testcase 100:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c1 <= ALL(ARRAY[c2, 1, c1 + 0]);
--Testcase 101:
SELECT * FROM ft1 t1 WHERE c1 <= ALL(ARRAY[c2, 1, c1 + 0]);
--Testcase 102:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c1 <> ALL(ARRAY[1, 2, 3]);
--Testcase 103:
SELECT * FROM ft1 t1 WHERE c1 <> ALL(ARRAY[1, 2, 3]);
--Testcase 104:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c1 < ALL(ARRAY[2, 3, 4]);
--Testcase 105:
SELECT * FROM ft1 t1 WHERE c1 < ALL(ARRAY[2, 3, 4]);
--Testcase 106:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c1 > ALL(ARRAY[1, 2, 3]);
--Testcase 107:
SELECT * FROM ft1 t1 WHERE c1 > ALL(ARRAY[1, 2, 3]);
--Testcase 108:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c1 >= ALL(ARRAY[1, 2, 3]);
--Testcase 109:
SELECT * FROM ft1 t1 WHERE c1 >= ALL(ARRAY[1, 2, 3]);
--Testcase 110:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c1 <= ALL(ARRAY[1, 2, 3]);
--Testcase 111:
SELECT * FROM ft1 t1 WHERE c1 <= ALL(ARRAY[1, 2, 3]);
--Testcase 112:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c5 <> ALL(ARRAY['1970-05-06 00:00:00'::timestamp,'1970-05-07 00:00:00'::timestamp]);
--Testcase 113:
SELECT * FROM ft1 t1 WHERE c5 <> ALL(ARRAY['1970-05-06 00:00:00'::timestamp,'1970-05-07 00:00:00'::timestamp]);
--Testcase 114:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c5 < ALL(ARRAY['1970-05-07 00:00:00'::timestamp,'1970-05-08 00:00:00'::timestamp]);
--Testcase 115:
SELECT * FROM ft1 t1 WHERE c5 < ALL(ARRAY['1970-05-07 00:00:00'::timestamp,'1970-05-08 00:00:00'::timestamp]);
--Testcase 116:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c5 > ALL(ARRAY['1970-05-06 00:00:00'::timestamp,'1970-05-07 00:00:00'::timestamp]);
--Testcase 117:
SELECT * FROM ft1 t1 WHERE c5 > ALL(ARRAY['1970-05-06 00:00:00'::timestamp,'1970-05-07 00:00:00'::timestamp]);
--Testcase 118:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c5 <= ALL(ARRAY['1970-05-06 00:00:00'::timestamp,'1970-05-07 00:00:00'::timestamp]);
--Testcase 119:
SELECT * FROM ft1 t1 WHERE c5 <= ALL(ARRAY['1970-05-06 00:00:00'::timestamp,'1970-05-07 00:00:00'::timestamp]);
--Testcase 120:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 t1 WHERE c5 >= ALL(ARRAY['1970-05-06 00:00:00'::timestamp,'1970-05-07 00:00:00'::timestamp]);
--Testcase 121:
SELECT * FROM ft1 t1 WHERE c5 >= ALL(ARRAY['1970-05-06 00:00:00'::timestamp,'1970-05-07 00:00:00'::timestamp]);
--Testcase 122:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 WHERE c1 = ALL (ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
--Testcase 123:
SELECT * FROM ft1 WHERE c1 = ALL (ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
--Testcase 124:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 WHERE c1 <> ALL(ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
--Testcase 125:
SELECT * FROM ft1 WHERE c1 <> ALL(ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
--Testcase 126:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 WHERE c1 > ALL (ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
--Testcase 127:
SELECT * FROM ft1 WHERE c1 > ALL (ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
--Testcase 128:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 WHERE c1 < ALL (ARRAY(SELECT c1 FROM ft2 WHERE c1 > 5));
--Testcase 129:
SELECT * FROM ft1 WHERE c1 < ALL (ARRAY(SELECT c1 FROM ft2 WHERE c1 > 5));
--Testcase 130:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 WHERE c1 >= ALL (ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
--Testcase 131:
SELECT * FROM ft1 WHERE c1 >= ALL (ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
--Testcase 132:
EXPLAIN (VERBOSE, COSTS OFF)
  SELECT * FROM ft1 WHERE c1 <= ALL (ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));
--Testcase 133:
SELECT * FROM ft1 WHERE c1 <= ALL (ARRAY(SELECT c1 FROM ft2 WHERE c1 < 5));

-- ===================================================================
-- Array Subscripting test
-- ===================================================================

-- Create foreign tables
--Testcase 134:
CREATE FOREIGN TABLE ft5 (id int, c1 int, c2 int, c3 text)
  SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_regress', table_name 's6');

--Testcase 135:
INSERT INTO ft5
	SELECT  id,
          	id,
	        id % 5,
	        to_char(id, 'FM00000')
	FROM generate_series(1, 10) id;

--Testcase 136:
EXPLAIN VERBOSE
	SELECT * FROM ft5 t1 WHERE c1 = (ARRAY[c1,c2,3])[2];
--Testcase 137:
SELECT * FROM ft5 t1 WHERE c1 = (ARRAY[c1,c2,3])[2];
--Testcase 138:
SELECT * FROM ft5 t1 WHERE c1 = c2;

--Testcase 139:
EXPLAIN VERBOSE
	SELECT * FROM ft5 t1 WHERE c1 > (ARRAY[c1,c2,3])[2];
--Testcase 140:
SELECT * FROM ft5 t1 WHERE c1 > (ARRAY[c1,c2,3])[2];
--Testcase 141:
SELECT * FROM ft5 t1 WHERE c1 > c2;

--Testcase 142:
EXPLAIN VERBOSE
	SELECT * FROM ft5 t1 WHERE c1 >= (ARRAY[c1,c2,3])[2];
--Testcase 143:
SELECT * FROM ft5 t1 WHERE c1 >= (ARRAY[c1,c2,3])[2];
--Testcase 144:
SELECT * FROM ft5 t1 WHERE c1 >= c2;

--Testcase 145:
EXPLAIN VERBOSE
	SELECT * FROM ft5 t1 WHERE c1 < (ARRAY[c1,c2,3])[3];
--Testcase 146:
SELECT * FROM ft5 t1 WHERE c1 < (ARRAY[c1,c2,3])[3];
--Testcase 147:
SELECT * FROM ft5 t1 WHERE c1 < 3;

--Testcase 148:
EXPLAIN VERBOSE
	SELECT * FROM ft5 t1 WHERE c1 <= (ARRAY[c1,c2,3])[3];
--Testcase 149:
SELECT * FROM ft5 t1 WHERE c1 <= (ARRAY[c1,c2,3])[3];
--Testcase 150:
SELECT * FROM ft5 t1 WHERE c1 <= 3;

--Testcase 151:
EXPLAIN VERBOSE
	SELECT * FROM ft5 t1 WHERE c1 <> (ARRAY[c1,c2,3])[2];
--Testcase 152:
SELECT * FROM ft5 t1 WHERE c1 <> (ARRAY[c1,c2,3])[2];
--Testcase 153:
SELECT * FROM ft5 t1 WHERE c1 <> c2;

-- Syntax (ARRAY[c1,c2])[id]
--Testcase 154:
EXPLAIN VERBOSE
	SELECT * FROM ft5 WHERE (ARRAY[c1,c2])[id] > 0;
--Testcase 155:
SELECT * FROM ft5 WHERE (ARRAY[c1,c2])[id] > 0;

-- Do not push down slice
--Testcase 156:
EXPLAIN VERBOSE
	SELECT * FROM ft5 t1 WHERE c1 <> ((ARRAY[c1,c2,3])[1:2])[2];
--Testcase 157:
SELECT * FROM ft5 t1 WHERE c1 <> ((ARRAY[c1,c2,3])[1:2])[2];

--Testcase 158:
EXPLAIN VERBOSE
	SELECT * FROM ft5 t1 WHERE c1 = (ARRAY[[c1,c2,3],[1,2,3]])[2][1];
--Testcase 159:
SELECT * FROM ft5 t1 WHERE c1 = (ARRAY[[c1,c2,3],[1,2,3]])[2][1];
--Testcase 160:
SELECT * FROM ft5 t1 WHERE c1 = 1;

--Testcase 161:
EXPLAIN VERBOSE
	SELECT * FROM ft5 t1 WHERE c1 = ((ARRAY[[c1,c2,3],[1,2,3],[3,2,1]])[2:3])[2][1];
--Testcase 162:
SELECT * FROM ft5 t1 WHERE c1 = ((ARRAY[[c1,c2,3],[1,2,3],[3,2,1]])[2:3])[2][1];
--Testcase 163:
SELECT * FROM ft5 t1 WHERE c1 = 3;

-- Aggregate pushdown
--Testcase 182:
CREATE FOREIGN TABLE aggtest (
  a       int2,
  b     float4
) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'aggtest');

--Testcase 183:
SELECT * FROM aggtest;

--Testcase 184:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT avg(a) AS avg_32 FROM aggtest WHERE a < 100;
--Testcase 185:
SELECT avg(a) AS avg_32 FROM aggtest WHERE a < 100;

--Testcase 186:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT sum(a) AS sum_198 FROM aggtest;
--Testcase 187:
SELECT sum(a) AS sum_198 FROM aggtest;

--Testcase 188:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT sum(b) AS avg_431_773 FROM aggtest;
--Testcase 189:
SELECT sum(b) AS avg_431_773 FROM aggtest;

--Testcase 190:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT max(a) AS max_100 FROM aggtest;
--Testcase 191:
SELECT max(a) AS max_100 FROM aggtest;

--Testcase 192:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT max(aggtest.b) AS max_324_78 FROM aggtest;
--Testcase 193:
SELECT max(aggtest.b) AS max_324_78 FROM aggtest;

--Testcase 194:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT min(a) AS min_0 FROM aggtest;
--Testcase 195:
SELECT min(a) AS min_0 FROM aggtest;

--Testcase 196:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT count(a) FROM aggtest;
--Testcase 197:
SELECT count(a) FROM aggtest;

--Testcase 198:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT min(aggtest.b) AS min_7_8 FROM aggtest WHERE b > 5;
--Testcase 199:
SELECT min(aggtest.b) AS min_7_8 FROM aggtest WHERE b > 5;

--Testcase 200:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT stddev_pop(b) FROM aggtest;
--Testcase 201:
SELECT stddev_pop(b) FROM aggtest;

--Testcase 202:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT stddev_samp(b) FROM aggtest;
--Testcase 203:
SELECT stddev_samp(b) FROM aggtest;

--Testcase 204:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT var_pop(b) FROM aggtest;
--Testcase 205:
SELECT var_pop(b) FROM aggtest;

--Testcase 206:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT var_samp(b) FROM aggtest;
--Testcase 207:
SELECT var_samp(b) FROM aggtest;

--Testcase 208:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT variance(b) FROM aggtest;
--Testcase 209:
SELECT variance(b) FROM aggtest;

--Testcase 210:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT json_agg(a), json_agg(b) FROM aggtest;
--Testcase 211:
SELECT json_agg(a), json_agg(b) FROM aggtest;

--Testcase 212:
EXPLAIN (VERBOSE, COSTS OFF)
SELECT json_object_agg(a, b) FROM aggtest;
--Testcase 213:
SELECT json_object_agg(a, b) FROM aggtest;

--Testcase 214:
CREATE FOREIGN TABLE bitwise_test(
  i2 INT2,
  i4 INT4,
  i8 INT8,
  i INTEGER,
  x INT2
) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'bitwise_test');

--Testcase 215:
DELETE FROM bitwise_test;

--Testcase 216:
INSERT INTO bitwise_test VALUES
  (1, 1, 1, 1, 1),
  (3, 3, 3, null, 2),
  (7, 7, 7, 3, 4);

--Testcase 217:
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

--Testcase 218:
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

-- Unsupport syntax case
--Testcase 164:
CREATE FOREIGN TABLE ft4 (id int, c1 int[], c2 int, c3 text)
  SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_regress', table_name 's6');
--Testcase 165:
EXPLAIN VERBOSE
	SELECT * FROM ft4 WHERE c2 = c1[1];
--Testcase 166:
SELECT * FROM ft4 WHERE c2 = c1[1];

--Testcase 167:
EXPLAIN VERBOSE
	SELECT * FROM ft4 WHERE c2 = c1[c2];
--Testcase 168:
SELECT * FROM ft4 WHERE c2 = c1[c2];

--Testcase 169:
DROP FOREIGN TABLE ft1;
--Testcase 170:
DROP FOREIGN TABLE ft2;
--Testcase 171:
DROP FOREIGN TABLE ft3;
--Testcase 172:
DROP FOREIGN TABLE ft4;
--Testcase 173:
DROP FOREIGN TABLE ft5;
--Testcase 219:
DROP FOREIGN TABLE aggtest;
--Testcase 220:
DROP FOREIGN TABLE bitwise_test;

--Testcase 174:
DROP USER MAPPING FOR PUBLIC SERVER mysql_svr;
--Testcase 175:
DROP SERVER mysql_svr CASCADE;
--Testcase 176:
DROP EXTENSION mysql_fdw CASCADE;
