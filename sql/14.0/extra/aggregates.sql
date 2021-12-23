\set ECHO none
\ir sql/parameters.conf
\set ECHO all

-- Before running this file User must create database mysql_fdw_regress on
-- mysql with all permission for MYSQL_USER_NAME user with MYSQL_PWD password
-- and ran mysql_init.sh file to create tables.

--
-- AGGREGATES
--
--Testcase 1:
CREATE EXTENSION IF NOT EXISTS mysql_fdw;
--Testcase 2:
CREATE SERVER mysql_svr FOREIGN DATA WRAPPER mysql_fdw
  OPTIONS (host :MYSQL_HOST, port :MYSQL_PORT);

--Testcase 3:
CREATE USER MAPPING FOR public SERVER mysql_svr
  OPTIONS (username :MYSQL_USER_NAME, password :MYSQL_PASS);

--Testcase 4:
CREATE FOREIGN TABLE onek(
  unique1   int4  OPTIONS (key 'true'),
  unique2   int4,
  two     int4,
  four    int4,
  ten     int4,
  twenty    int4,
  hundred   int4,
  thousand  int4,
  twothousand int4,
  fivethous int4,
  tenthous  int4,
  odd     int4,
  even    int4,
  stringu1  name,
  stringu2  name,
  string4   name
) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'onek');

--Testcase 5:
CREATE FOREIGN TABLE aggtest (
  a       int2,
  b     float4
) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'aggtest');

--Testcase 6:
CREATE FOREIGN TABLE student (
  name    text,
  age     int4,
  location  point,
  gpa     float8
) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'student');

--Testcase 7:
CREATE FOREIGN TABLE tenk1 (
  unique1   int4,
  unique2   int4,
  two     int4,
  four    int4,
  ten     int4,
  twenty    int4,
  hundred   int4,
  thousand  int4,
  twothousand int4,
  fivethous int4,
  tenthous  int4,
  odd     int4,
  even    int4,
  stringu1  name,
  stringu2  name,
  string4   name
) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'tenk1');

--Testcase 8:
CREATE FOREIGN TABLE INT8_TBL(
  q1 int8 OPTIONS (key 'true'),
  q2 int8 OPTIONS (key 'true')
) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'INT8_TBL');

--Testcase 9:
CREATE FOREIGN TABLE INT4_TBL(f1 int4 OPTIONS (key 'true')) SERVER mysql_svr  OPTIONS (dbname 'mysql_fdw_core', table_name 'INT4_TBL'); 

--Testcase 10:
CREATE FOREIGN TABLE multi_arg_agg (a int OPTIONS (key 'true'), b int, c text) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'multi_arg_agg');

--Testcase 11:
CREATE FOREIGN TABLE VARCHAR_TBL(f1 varchar(4) OPTIONS (key 'true')) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'VARCHAR_TBL');

--Testcase 12:
CREATE FOREIGN TABLE FLOAT8_TBL(f1 float8 OPTIONS (key 'true')) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'FLOAT8_TBL');

-- avoid bit-exact output here because operations may not be bit-exact.
--Testcase 351:
SET extra_float_digits = 0;
--Testcase 13:
SELECT avg(four) AS avg_1 FROM onek;

--Testcase 14:
SELECT avg(a) AS avg_32 FROM aggtest WHERE a < 100;

-- In 7.1, avg(float4) is computed using float8 arithmetic.
-- Round the result to limited digits to avoid platform-specific results.
--Testcase 15:
SELECT avg(b)::numeric(10,3) AS avg_107_943 FROM aggtest;

-- Round the result to limited digits to avoid platform-specific results.
--Testcase 16:
SELECT avg(gpa)::numeric(10,3) AS avg_3_4 FROM ONLY student;


--Testcase 17:
SELECT sum(four) AS sum_1500 FROM onek;
--Testcase 18:
SELECT sum(a) AS sum_198 FROM aggtest;
-- Round the result to limited digits to avoid platform-specific results.
--Testcase 19:
SELECT sum(b)::numeric(10,3) AS avg_431_773 FROM aggtest;
-- Round the result to limited digits to avoid platform-specific results.
--Testcase 20:
SELECT sum(gpa)::numeric(10,3) AS avg_6_8 FROM ONLY student;

--Testcase 21:
SELECT max(four) AS max_3 FROM onek;
--Testcase 22:
SELECT max(a) AS max_100 FROM aggtest;
--Testcase 23:
SELECT max(aggtest.b) AS max_324_78 FROM aggtest;
--Testcase 24:
SELECT max(student.gpa) AS max_3_7 FROM student;

-- Round the result to limited digits to avoid platform-specific results.
--Testcase 25:
SELECT stddev_pop(b)::numeric(20,10) FROM aggtest;
-- Round the result to limited digits to avoid platform-specific results.
--Testcase 26:
SELECT stddev_samp(b)::numeric(20,10) FROM aggtest;
-- Round the result to limited digits to avoid platform-specific results.
--Testcase 27:
SELECT var_pop(b)::numeric(20,10) FROM aggtest;
-- Round the result to limited digits to avoid platform-specific results.
--Testcase 28:
SELECT var_samp(b)::numeric(20,10) FROM aggtest;

--Testcase 29:
SELECT stddev_pop(b::numeric) FROM aggtest;
--Testcase 30:
SELECT stddev_samp(b::numeric) FROM aggtest;
--Testcase 31:
SELECT var_pop(b::numeric) FROM aggtest;
--Testcase 32:
SELECT var_samp(b::numeric) FROM aggtest;

-- population variance is defined for a single tuple, sample variance
-- is not
--Testcase 33:
CREATE FOREIGN TABLE agg_t3(a float8, b float8, id integer OPTIONS (key 'true')) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_t3');
--Testcase 34:
DELETE FROM agg_t3;
--Testcase 35:
INSERT INTO agg_t3 values (1.0::float8, 2.0::float8);
--Testcase 36:
SELECT var_pop(a), var_samp(b) FROM agg_t3;

--Testcase 37:
DELETE FROM agg_t3;
--Testcase 38:
INSERT INTO agg_t3 values (3.0::float8, 4.0::float8);
--Testcase 39:
SELECT stddev_pop(a), stddev_samp(b) FROM agg_t3;

--Testcase 40:
DELETE FROM agg_t3;
--Testcase 41:
INSERT INTO agg_t3 values ('inf'::float8, 'inf'::float8);
--Testcase 42:
SELECT var_pop(a), var_samp(b) FROM agg_t3;
--Testcase 43:
SELECT stddev_pop(a), stddev_samp(b) FROM agg_t3;

--Testcase 44:
DELETE FROM agg_t3;
--Testcase 45:
INSERT INTO agg_t3 values ('nan'::float8, 'nan'::float8);
--Testcase 46:
SELECT var_pop(a), var_samp(b) FROM agg_t3;
--Testcase 47:
SELECT stddev_pop(a), stddev_samp(b) FROM agg_t3;

--Testcase 48:
CREATE FOREIGN TABLE agg_t4(a float4, b float4, id integer OPTIONS (key 'true')) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_t4');
--Testcase 49:
DELETE FROM agg_t4;
--Testcase 50:
INSERT INTO agg_t4 values (1.0::float4, 2.0::float4);
--Testcase 51:
SELECT var_pop(a), var_samp(b) FROM agg_t4;

--Testcase 52:
DELETE FROM agg_t4;
--Testcase 53:
INSERT INTO agg_t4 values (3.0::float4, 4.0::float4);
--Testcase 54:
SELECT stddev_pop(a), stddev_samp(b) FROM agg_t4;

--Testcase 55:
DELETE FROM agg_t4;
--Testcase 56:
INSERT INTO agg_t4 values ('inf'::float4, 'inf'::float4);
--Testcase 57:
SELECT var_pop(a), var_samp(b) FROM agg_t4;
--Testcase 58:
SELECT stddev_pop(a), stddev_samp(b) FROM agg_t4;

--Testcase 59:
DELETE FROM agg_t4;
--Testcase 60:
INSERT INTO agg_t4 values ('nan'::float4, 'nan'::float4);
--Testcase 61:
SELECT var_pop(a), var_samp(b) FROM agg_t4;
--Testcase 62:
SELECT stddev_pop(a), stddev_samp(b) FROM agg_t4;

--Testcase 63:
CREATE FOREIGN TABLE agg_t5(a numeric, b numeric, id integer OPTIONS (key 'true')) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_t5');
--Testcase 64:
DELETE FROM agg_t5;
--Testcase 65:
INSERT INTO agg_t5 values (1.0::numeric, 2.0::numeric);
--Testcase 66:
SELECT var_pop(a), var_samp(b) FROM agg_t5;

--Testcase 67:
DELETE FROM agg_t5;
--Testcase 68:
INSERT INTO agg_t5 values (3.0::numeric, 4.0::numeric);
--Testcase 69:
SELECT stddev_pop(a), stddev_samp(b) FROM agg_t5;

--Testcase 70:
DELETE FROM agg_t5;
--Testcase 71:
INSERT INTO agg_t5 values ('nan'::numeric, 'nan'::numeric);
--Testcase 72:
SELECT var_pop(a), var_samp(b) FROM agg_t5;
--Testcase 73:
SELECT stddev_pop(a), stddev_samp(b) FROM agg_t5;

-- verify correct results for null and NaN inputs
--Testcase 74:
CREATE FOREIGN TABLE agg_t8(a text OPTIONS (key 'true'), b text) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_t8');
--Testcase 75:
DELETE FROM agg_t8;
--Testcase 76:
INSERT INTO agg_t8 select * from generate_series(1,3);
--Testcase 77:
select sum(null::int4) from agg_t8;
--Testcase 78:
select sum(null::int8) from agg_t8;
--Testcase 79:
select sum(null::numeric) from agg_t8;
--Testcase 80:
select sum(null::float8) from agg_t8;
--Testcase 81:
select avg(null::int4) from agg_t8;
--Testcase 82:
select avg(null::int8) from agg_t8;
--Testcase 83:
select avg(null::numeric) from agg_t8;
--Testcase 84:
select avg(null::float8) from agg_t8;
--Testcase 85:
select sum('NaN'::numeric) from agg_t8;
--Testcase 86:
select avg('NaN'::numeric) from agg_t8;

-- verify correct results for infinite inputs
--Testcase 87:
DELETE FROM agg_t3;
--Testcase 88:
INSERT INTO agg_t3 VALUES ('1'::float8), ('infinity'::float8);
--Testcase 89:
SELECT avg(a), var_pop(a) FROM agg_t3;

--Testcase 90:
DELETE FROM agg_t3;
--Testcase 91:
INSERT INTO agg_t3 VALUES ('infinity'::float8), ('1'::float8);
--Testcase 92:
SELECT avg(a), var_pop(a) FROM agg_t3;

--Testcase 93:
DELETE FROM agg_t3;
--Testcase 94:
INSERT INTO agg_t3 VALUES ('infinity'::float8), ('infinity'::float8);
--Testcase 95:
SELECT avg(a), var_pop(a) FROM agg_t3;

--Testcase 96:
DELETE FROM agg_t3;
--Testcase 97:
INSERT INTO agg_t3 VALUES ('-infinity'::float8), ('infinity'::float8);
--Testcase 98:
SELECT avg(a), var_pop(a) FROM agg_t3;

-- test accuracy with a large input offset
--Testcase 99:
CREATE FOREIGN TABLE agg_t6(a float8, id integer OPTIONS (key 'true')) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_t6');
--Testcase 100:
DELETE FROM agg_t6;
--Testcase 101:
INSERT INTO agg_t6 VALUES (100000003), (100000004), (100000006), (100000007);
--Testcase 102:
SELECT avg(a), var_pop(a) FROM agg_t6;

--Testcase 103:
DELETE FROM agg_t6;
--Testcase 104:
INSERT INTO agg_t6 VALUES (7000000000005), (7000000000007);
--Testcase 105:
SELECT avg(a), var_pop(a) FROM agg_t6;

-- SQL2003 binary aggregates
--Testcase 106:
SELECT regr_count(b, a) FROM aggtest;
--Testcase 107:
SELECT regr_sxx(b, a) FROM aggtest;
-- Round the result to limited digits to avoid platform-specific results.
--Testcase 108:
SELECT regr_syy(b, a)::numeric(20,10) FROM aggtest;
-- Round the result to limited digits to avoid platform-specific results.
--Testcase 109:
SELECT regr_sxy(b, a)::numeric(20,10) FROM aggtest;
-- Round the result to limited digits to avoid platform-specific results.
--Testcase 110:
SELECT regr_avgx(b, a), regr_avgy(b, a)::numeric(20,10) FROM aggtest;
-- Round the result to limited digits to avoid platform-specific results.
--Testcase 111:
SELECT regr_r2(b, a)::numeric(20,10) FROM aggtest;
-- Round the result to limited digits to avoid platform-specific results.
--Testcase 112:
SELECT regr_slope(b, a)::numeric(20,10), regr_intercept(b, a)::numeric(20,10) FROM aggtest;
-- Round the result to limited digits to avoid platform-specific results.
--Testcase 113:
SELECT covar_pop(b, a)::numeric(20,10), covar_samp(b, a)::numeric(20,10) FROM aggtest;
-- Round the result to limited digits to avoid platform-specific results.
--Testcase 114:
SELECT corr(b, a)::numeric(20,10) FROM aggtest;

-- check single-tuple behavior
--Testcase 115:
CREATE FOREIGN TABLE agg_t7(a float8, b float8, c float8, d float8, id integer OPTIONS (key 'true')) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_t7');
--Testcase 116:
DELETE FROM agg_t7;
--Testcase 117:
INSERT INTO agg_t7 VALUES (1, 2, 3, 4);
--Testcase 118:
SELECT covar_pop(a,b), covar_samp(c,d) FROM agg_t7;

--Testcase 119:
DELETE FROM agg_t7;
--Testcase 120:
INSERT INTO agg_t7 VALUES (1, 'inf', 3, 'inf');
--Testcase 121:
SELECT covar_pop(a,b), covar_samp(c,d) FROM agg_t7;

--Testcase 122:
DELETE FROM agg_t7;
--Testcase 123:
INSERT INTO agg_t7 VALUES (1, 'nan', 3, 'nan');
--Testcase 124:
SELECT covar_pop(a,b), covar_samp(c,d) FROM agg_t7;

-- test accum and combine functions directly
--Testcase 125:
CREATE FOREIGN TABLE regr_test (x float8, y float8, id int options (key 'true')) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'regr_test');
--Testcase 126:
DELETE FROM regr_test;
--Testcase 127:
INSERT INTO regr_test VALUES (10,150),(20,250),(30,350),(80,540),(100,200);
--Testcase 128:
SELECT count(*), sum(x), regr_sxx(y,x), sum(y),regr_syy(y,x), regr_sxy(y,x)
FROM regr_test WHERE x IN (10,20,30,80);
--Testcase 129:
SELECT count(*), sum(x), regr_sxx(y,x), sum(y),regr_syy(y,x), regr_sxy(y,x)
FROM regr_test;

--Testcase 130:
CREATE FOREIGN TABLE agg_t15 (a text, b int, c int, id int options (key 'true')) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_t15');
--Testcase 131:
delete from agg_t15;
--Testcase 132:
insert into agg_t15 values ('{4,140,2900}', 100);
--Testcase 133:
SELECT float8_accum(a::float8[], b) from agg_t15;

--Testcase 134:
delete from agg_t15;
--Testcase 135:
insert into agg_t15 values ('{4,140,2900,1290,83075,15050}', 200, 100);
--Testcase 136:
SELECT float8_regr_accum(a::float8[], b, c) from agg_t15;

--Testcase 137:
SELECT count(*), sum(x), regr_sxx(y,x), sum(y),regr_syy(y,x), regr_sxy(y,x)
FROM regr_test WHERE x IN (10,20,30);

--Testcase 138:
SELECT count(*), sum(x), regr_sxx(y,x), sum(y),regr_syy(y,x), regr_sxy(y,x)
FROM regr_test WHERE x IN (80,100);

--Testcase 139:
CREATE FOREIGN TABLE agg_t16 (a text, b text, id int options (key 'true')) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_t16');
--Testcase 140:
delete from agg_t16;
--Testcase 141:
insert into agg_t16 values ('{3,60,200}', '{0,0,0}');
--Testcase 142:
insert into agg_t16 values ('{0,0,0}', '{2,180,200}');
--Testcase 143:
insert into agg_t16 values ('{3,60,200}', '{2,180,200}');
--Testcase 144:
SELECT float8_combine(a::float8[], b::float8[]) FROM agg_t16;

--Testcase 145:
delete from agg_t16;
--Testcase 146:
insert into agg_t16 values ('{3,60,200,750,20000,2000}', '{0,0,0,0,0,0}');
--Testcase 147:
insert into agg_t16 values ('{0,0,0,0,0,0}', '{2,180,200,740,57800,-3400}');
--Testcase 148:
insert into agg_t16 values ('{3,60,200,750,20000,2000}', '{2,180,200,740,57800,-3400}');
--Testcase 149:
SELECT float8_regr_combine(a::float8[], b::float8[]) FROM agg_t16;

--Testcase 150:
DROP FOREIGN TABLE regr_test;

-- test count, distinct
--Testcase 151:
SELECT count(four) AS cnt_1000 FROM onek;
--Testcase 152:
SELECT count(DISTINCT four) AS cnt_4 FROM onek;

--Testcase 153:
select ten, count(*), sum(four) from onek
group by ten order by ten;

--Testcase 154:
select ten, count(four), sum(DISTINCT four) from onek
group by ten order by ten;

-- user-defined aggregates
--Testcase 155:
CREATE AGGREGATE newavg (
   sfunc = int4_avg_accum, basetype = int4, stype = _int8,
   finalfunc = int8_avg,
   initcond1 = '{0,0}'
);

--Testcase 156:
CREATE AGGREGATE newsum (
   sfunc1 = int4pl, basetype = int4, stype1 = int4,
   initcond1 = '0'
);

--Testcase 157:
CREATE AGGREGATE newcnt (*) (
   sfunc = int8inc, stype = int8,
   initcond = '0', parallel = safe
);

--Testcase 158:
CREATE AGGREGATE newcnt ("any") (
   sfunc = int8inc_any, stype = int8,
   initcond = '0'
);

--Testcase 159:
CREATE AGGREGATE oldcnt (
   sfunc = int8inc, basetype = 'ANY', stype = int8,
   initcond = '0'
);

--Testcase 160:
create function sum3(int8,int8,int8) returns int8 as
'select $1 + $2 + $3' language sql strict immutable;

--Testcase 161:
create aggregate sum2(int8,int8) (
   sfunc = sum3, stype = int8,
   initcond = '0'
);

--Testcase 162:
SELECT newavg(four) AS avg_1 FROM onek;
--Testcase 163:
SELECT newsum(four) AS sum_1500 FROM onek;
--Testcase 164:
SELECT newcnt(four) AS cnt_1000 FROM onek;
--Testcase 165:
SELECT newcnt(*) AS cnt_1000 FROM onek;
--Testcase 166:
SELECT oldcnt(*) AS cnt_1000 FROM onek;
--Testcase 167:
SELECT sum2(q1,q2) FROM int8_tbl;

-- test for outer-level aggregates

-- this should work
--Testcase 168:
select ten, sum(distinct four) from onek a
group by ten
having exists (select 1 from onek b where sum(distinct a.four) = b.four);

-- this should fail because subquery has an agg of its own in WHERE
--Testcase 169:
select ten, sum(distinct four) from onek a
group by ten
having exists (select 1 from onek b
               where sum(distinct a.four + b.four) = b.four);

-- Test handling of sublinks within outer-level aggregates.
-- Per bug report from Daniel Grace.
--Testcase 170:
select
  (select max((select i.unique2 from tenk1 i where i.unique1 = o.unique1)))
from tenk1 o;

-- Test handling of Params within aggregate arguments in hashed aggregation.
-- Per bug report from Jeevan Chalke.
--Testcase 171:
explain (verbose, costs off)
select s1, s2, sm
from generate_series(1, 3) s1,
     lateral (select s2, sum(s1 + s2) sm
              from generate_series(1, 3) s2 group by s2) ss
order by 1, 2;

--Testcase 172:
select s1, s2, sm
from generate_series(1, 3) s1,
     lateral (select s2, sum(s1 + s2) sm
              from generate_series(1, 3) s2 group by s2) ss
order by 1, 2;

--Testcase 173:
explain (verbose, costs off)
select array(select sum(x+y) s
            from generate_series(1,3) y group by y order by s)
  from generate_series(1,3) x;

--Testcase 174:
select array(select sum(x+y) s
            from generate_series(1,3) y group by y order by s)
  from generate_series(1,3) x;

--
-- test for bitwise integer aggregates
--
--Testcase 175:
CREATE FOREIGN TABLE bitwise_test(
  i2 INT2,
  i4 INT4,
  i8 INT8,
  i INTEGER,
  x INT2
) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'bitwise_test');

-- empty case
--Testcase 176:
SELECT
  BIT_AND(i2) AS "?",
  BIT_OR(i4)  AS "?"
FROM bitwise_test;

--Testcase 177:
INSERT INTO bitwise_test VALUES
  (1, 1, 1, 1, 1),
  (3, 3, 3, null, 2),
  (7, 7, 7, 3, 4);

--Testcase 178:
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

--
-- test boolean aggregates
--
-- first test all possible transition and final states

--Testcase 179:
CREATE FOREIGN TABLE bool_test_tmp(
  b1 BOOL OPTIONS (key 'true'),
  b2 BOOL OPTIONS (key 'true')
) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'bool_test_tmp');

-- mysql_fdw did not supported transactions
-- -- boolean and transitions
-- -- null because strict
-- BEGIN;
-- INSERT INTO bool_test_tmp VALUES
--   (NULL, NULL),
--   (TRUE, NULL),
--   (FALSE, NULL),
--   (NULL, TRUE),
--   (NULL, FALSE);
-- SELECT booland_statefunc(b1, b2) IS NULL as "t" FROM bool_test_tmp;
-- ROLLBACK;

-- -- and actual computations
-- BEGIN;
-- INSERT INTO bool_test_tmp VALUES
--   (TRUE, TRUE);
-- SELECT booland_statefunc(b1, b2) as "t" FROM bool_test_tmp;
-- ROLLBACK;

-- BEGIN;
-- INSERT INTO bool_test_tmp VALUES
--   (TRUE, FALSE),
--   (FALSE, TRUE),
--   (FALSE, FALSE);
-- SELECT NOT booland_statefunc(b1, b2) as "t" FROM bool_test_tmp;
-- ROLLBACK;

-- -- boolean or transitions
-- -- null because strict
-- BEGIN;
-- INSERT INTO bool_test_tmp VALUES
--   (NULL, NULL),
--   (TRUE, NULL),
--   (FALSE, NULL),
--   (NULL, TRUE),
--   (NULL, FALSE);
-- SELECT boolor_statefunc(b1, b2) IS NULL as "t" FROM bool_test_tmp;
-- ROLLBACK;

-- -- actual computations
-- BEGIN;
-- INSERT INTO bool_test_tmp VALUES
--   (TRUE, TRUE),
--   (TRUE, FALSE),
--   (FALSE, TRUE);
-- SELECT boolor_statefunc(b1, b2) as "t" FROM bool_test_tmp;
-- ROLLBACK;

-- BEGIN;
-- INSERT INTO bool_test_tmp VALUES
--   (FALSE, FALSE);
-- SELECT NOT boolor_statefunc(b1, b2) as "t" FROM bool_test_tmp;
-- ROLLBACK;

--Testcase 180:
CREATE FOREIGN TABLE bool_test(
  b1 BOOL,
  b2 BOOL,
  b3 BOOL,
  b4 BOOL
) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'bool_test');

-- empty case
--Testcase 181:
SELECT
  BOOL_AND(b1)   AS "n",
  BOOL_OR(b3)    AS "n"
FROM bool_test;

--Testcase 182:
INSERT INTO bool_test VALUES
  (TRUE, null, FALSE, null),
  (FALSE, TRUE, null, null),
  (null, TRUE, FALSE, null);

--Testcase 183:
SELECT
  BOOL_AND(b1)     AS "f",
  BOOL_AND(b2)     AS "t",
  BOOL_AND(b3)     AS "f",
  BOOL_AND(b4)     AS "n",
  BOOL_AND(NOT b2) AS "f",
  BOOL_AND(NOT b3) AS "t"
FROM bool_test;

--Testcase 184:
SELECT
  EVERY(b1)     AS "f",
  EVERY(b2)     AS "t",
  EVERY(b3)     AS "f",
  EVERY(b4)     AS "n",
  EVERY(NOT b2) AS "f",
  EVERY(NOT b3) AS "t"
FROM bool_test;

--Testcase 185:
SELECT
  BOOL_OR(b1)      AS "t",
  BOOL_OR(b2)      AS "t",
  BOOL_OR(b3)      AS "f",
  BOOL_OR(b4)      AS "n",
  BOOL_OR(NOT b2)  AS "f",
  BOOL_OR(NOT b3)  AS "t"
FROM bool_test;

--
-- Test cases that should be optimized into indexscans instead of
-- the generic aggregate implementation.
--

-- Basic cases
--Testcase 186:
explain (costs off)
  select min(unique1) from tenk1;
--Testcase 187:
select min(unique1) from tenk1;
--Testcase 188:
explain (costs off)
  select max(unique1) from tenk1;
--Testcase 189:
select max(unique1) from tenk1;
--Testcase 190:
explain (costs off)
  select max(unique1) from tenk1 where unique1 < 42;
--Testcase 191:
select max(unique1) from tenk1 where unique1 < 42;
--Testcase 192:
explain (costs off)
  select max(unique1) from tenk1 where unique1 > 42;
--Testcase 193:
select max(unique1) from tenk1 where unique1 > 42;

-- mysql_fdw did not supported transactions
-- -- the planner may choose a generic aggregate here if parallel query is
-- -- enabled, since that plan will be parallel safe and the "optimized"
-- -- plan, which has almost identical cost, will not be.  we want to test
-- -- the optimized plan, so temporarily disable parallel query.
-- begin;
-- set local max_parallel_workers_per_gather = 0;
-- explain (costs off)
--   select max(unique1) from tenk1 where unique1 > 42000;
-- select max(unique1) from tenk1 where unique1 > 42000;
-- rollback;

-- multi-column index (uses tenk1_thous_tenthous)
--Testcase 194:
explain (costs off)
  select max(tenthous) from tenk1 where thousand = 33;
--Testcase 195:
select max(tenthous) from tenk1 where thousand = 33;
--Testcase 196:
explain (costs off)
  select min(tenthous) from tenk1 where thousand = 33;
--Testcase 197:
select min(tenthous) from tenk1 where thousand = 33;

-- check parameter propagation into an indexscan subquery
--Testcase 198:
explain (costs off)
  select f1, (select min(unique1) from tenk1 where unique1 > f1) AS gt
    from int4_tbl;
--Testcase 199:
select f1, (select min(unique1) from tenk1 where unique1 > f1) AS gt
  from int4_tbl;

-- check some cases that were handled incorrectly in 8.3.0
--Testcase 200:
explain (costs off)
  select distinct max(unique2) from tenk1;
--Testcase 201:
select distinct max(unique2) from tenk1;
--Testcase 202:
explain (costs off)
  select max(unique2) from tenk1 order by 1;
--Testcase 203:
select max(unique2) from tenk1 order by 1;
--Testcase 204:
explain (costs off)
  select max(unique2) from tenk1 order by max(unique2);
--Testcase 205:
select max(unique2) from tenk1 order by max(unique2);
--Testcase 206:
explain (costs off)
  select max(unique2) from tenk1 order by max(unique2)+1;
--Testcase 207:
select max(unique2) from tenk1 order by max(unique2)+1;
--Testcase 208:
explain (costs off)
  select max(unique2), generate_series(1,3) as g from tenk1 order by g desc;
--Testcase 209:
select max(unique2), generate_series(1,3) as g from tenk1 order by g desc;

-- interesting corner case: constant gets optimized into a seqscan
--Testcase 210:
explain (costs off)
  select max(100) from tenk1;
--Testcase 211:
select max(100) from tenk1;

-- try it on an inheritance tree
--Testcase 212:
create foreign table minmaxtest(f1 int) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'minmaxtest');
--Testcase 213:
create table minmaxtest1() inherits (minmaxtest);
--Testcase 214:
create table minmaxtest2() inherits (minmaxtest);
--Testcase 215:
create table minmaxtest3() inherits (minmaxtest);
--Testcase 216:
create index minmaxtest1i on minmaxtest1(f1);
--Testcase 217:
create index minmaxtest2i on minmaxtest2(f1 desc);
--Testcase 218:
create index minmaxtest3i on minmaxtest3(f1) where f1 is not null;

--Testcase 219:
insert into minmaxtest values(11), (12);
--Testcase 220:
insert into minmaxtest1 values(13), (14);
--Testcase 221:
insert into minmaxtest2 values(15), (16);
--Testcase 222:
insert into minmaxtest3 values(17), (18);

--Testcase 223:
explain (costs off)
  select min(f1), max(f1) from minmaxtest;
--Testcase 224:
select min(f1), max(f1) from minmaxtest;

-- DISTINCT doesn't do anything useful here, but it shouldn't fail
--Testcase 225:
explain (costs off)
  select distinct min(f1), max(f1) from minmaxtest;
--Testcase 226:
select distinct min(f1), max(f1) from minmaxtest;

-- check for correct detection of nested-aggregate errors
--Testcase 227:
select max(min(unique1)) from tenk1;
--Testcase 228:
select (select max(min(unique1)) from int8_tbl) from tenk1;

--
-- Test removal of redundant GROUP BY columns
--

--Testcase 229:
create foreign table agg_t1 (a int OPTIONS (key 'true'), b int OPTIONS (key 'true'), c int, d int) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_t1');
--Testcase 230:
create foreign table agg_t2 (x int OPTIONS (key 'true'), y int OPTIONS (key 'true'), z int) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_t2');
--Testcase 231:
create foreign table agg_t9 (a int OPTIONS (key 'true'), b int OPTIONS (key 'true'), c int) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_t9');

-- Non-primary-key columns can be removed from GROUP BY
--Testcase 232:
explain (costs off) select * from agg_t1 group by a,b,c,d;

-- No removal can happen if the complete PK is not present in GROUP BY
--Testcase 233:
explain (costs off) select a,c from agg_t1 group by a,c,d;

-- Test removal across multiple relations
--Testcase 234:
explain (costs off) select *
from agg_t1 inner join agg_t2 on agg_t1.a = agg_t2.x and agg_t1.b = agg_t2.y
group by agg_t1.a,agg_t1.b,agg_t1.c,agg_t1.d,agg_t2.x,agg_t2.y,agg_t2.z;

-- Test case where agg_t1 can be optimized but not agg_t2
--Testcase 235:
explain (costs off) select agg_t1.*,agg_t2.x,agg_t2.z
from agg_t1 inner join agg_t2 on agg_t1.a = agg_t2.x and agg_t1.b = agg_t2.y
group by agg_t1.a,agg_t1.b,agg_t1.c,agg_t1.d,agg_t2.x,agg_t2.z;

-- Cannot optimize when PK is deferrable
--Testcase 236:
explain (costs off) select * from agg_t9 group by a,b,c;

--Testcase 237:
create temp table t1c () inherits (agg_t1);

-- Ensure we don't remove any columns when t1 has a child table
--Testcase 238:
explain (costs off) select * from agg_t1 group by a,b,c,d;

-- Okay to remove columns if we're only querying the parent.
--Testcase 239:
explain (costs off) select * from only agg_t1 group by a,b,c,d;

-- Skip this test, mysql_fdw does not support partition table
--create foreign table p_t1 (
--  a int options (key 'true'),
--  b int options (key 'true'),
--  c int,
--  d int,
--) partition by list(a) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'p_t1');
--create temp table p_t1_1 partition of p_t1 for values in(1);
--create temp table p_t1_2 partition of p_t1 for values in(2);

-- Ensure we can remove non-PK columns for partitioned tables.
--explain (costs off) select * from p_t1 group by a,b,c,d;

--drop table t1 cascade;
--drop table t2;
--drop table t3;
--drop table p_t1;

--
-- Test GROUP BY matching of join columns that are type-coerced due to USING
--

--Testcase 240:
create foreign table t1(f1 int, f2 bigint) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 't1');
--Testcase 241:
create foreign table t2(f1 bigint, f22 bigint) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 't2');

--Testcase 242:
select f1 from t1 left join t2 using (f1) group by f1;
--Testcase 243:
select f1 from t1 left join t2 using (f1) group by t1.f1;
--Testcase 244:
select t1.f1 from t1 left join t2 using (f1) group by t1.f1;
-- only this one should fail:
--Testcase 245:
select t1.f1 from t1 left join t2 using (f1) group by f1;

--Testcase 246:
drop foreign table t1, t2;

-- mysql_fdw did not supported transactions
-- --
-- -- Test combinations of DISTINCT and/or ORDER BY
-- --
-- begin;
-- delete from INT8_TBL;
-- insert into INT8_TBL values (1,4),(2,3),(3,1),(4,2);
-- select array_agg(q1 order by q2)
--   from INT8_TBL;
-- select array_agg(q1 order by q1)
--   from INT8_TBL;
-- select array_agg(q1 order by q1 desc)
--   from INT8_TBL;
-- select array_agg(q2 order by q1 desc)
--   from INT8_TBL;

-- delete from INT4_TBL;
-- insert into INT4_TBL values (1),(2),(1),(3),(null),(2);
-- select array_agg(distinct f1)
--   from INT4_TBL;
-- select array_agg(distinct f1 order by f1)
--   from INT4_TBL;
-- select array_agg(distinct f1 order by f1 desc)
--   from INT4_TBL;
-- select array_agg(distinct f1 order by f1 desc nulls last)
--   from INT4_TBL;
-- rollback;

-- multi-arg aggs, strict/nonstrict, distinct/order by
--Testcase 247:
create type aggtype as (a integer, b integer, c text);

--Testcase 248:
create function aggf_trans(aggtype[],integer,integer,text) returns aggtype[]
as 'select array_append($1,ROW($2,$3,$4)::aggtype)'
language sql strict immutable;

--Testcase 249:
create function aggfns_trans(aggtype[],integer,integer,text) returns aggtype[]
as 'select array_append($1,ROW($2,$3,$4)::aggtype)'
language sql immutable;

--Testcase 250:
create aggregate aggfstr(integer,integer,text) (
   sfunc = aggf_trans, stype = aggtype[],
   initcond = '{}'
);

--Testcase 251:
create aggregate aggfns(integer,integer,text) (
   sfunc = aggfns_trans, stype = aggtype[], sspace = 10000,
   initcond = '{}'
);

-- mysql_fdw did not supported transactions
-- begin;
-- insert into multi_arg_agg values (1,3,'foo'),(0,null,null),(2,2,'bar'),(3,1,'baz');
-- select aggfstr(a,b,c) from multi_arg_agg;
-- select aggfns(a,b,c) from multi_arg_agg;

-- select aggfstr(distinct a,b,c) from multi_arg_agg, generate_series(1,3) i;
-- select aggfns(distinct a,b,c) from multi_arg_agg, generate_series(1,3) i;

-- select aggfstr(distinct a,b,c order by b) from multi_arg_agg, generate_series(1,3) i;
-- select aggfns(distinct a,b,c order by b) from multi_arg_agg, generate_series(1,3) i;

-- -- test specific code paths

-- select aggfns(distinct a,a,c order by c using ~<~,a) from multi_arg_agg, generate_series(1,2) i;
-- select aggfns(distinct a,a,c order by c using ~<~) from multi_arg_agg, generate_series(1,2) i;
-- select aggfns(distinct a,a,c order by a) from multi_arg_agg, generate_series(1,2) i;
-- select aggfns(distinct a,b,c order by a,c using ~<~,b) from multi_arg_agg, generate_series(1,2) i;

-- -- check node I/O via view creation and usage, also deparsing logic

-- create view agg_view1 as
--   select aggfns(a,b,c) from multi_arg_agg;

-- select * from agg_view1;
-- select pg_get_viewdef('agg_view1'::regclass);

-- create or replace view agg_view1 as
--   select aggfns(distinct a,b,c) from multi_arg_agg, generate_series(1,3) i;

-- select * from agg_view1;
-- select pg_get_viewdef('agg_view1'::regclass);

-- create or replace view agg_view1 as
--   select aggfns(distinct a,b,c order by b) from multi_arg_agg, generate_series(1,3) i;

-- select * from agg_view1;
-- select pg_get_viewdef('agg_view1'::regclass);

-- create or replace view agg_view1 as
--   select aggfns(a,b,c order by b+1) from multi_arg_agg;

-- select * from agg_view1;
-- select pg_get_viewdef('agg_view1'::regclass);

-- create or replace view agg_view1 as
--   select aggfns(a,a,c order by b) from multi_arg_agg;

-- select * from agg_view1;
-- select pg_get_viewdef('agg_view1'::regclass);

-- create or replace view agg_view1 as
--   select aggfns(a,b,c order by c using ~<~) from multi_arg_agg;

-- select * from agg_view1;
-- select pg_get_viewdef('agg_view1'::regclass);

-- create or replace view agg_view1 as
--   select aggfns(distinct a,b,c order by a,c using ~<~,b) from multi_arg_agg, generate_series(1,2) i;

-- select * from agg_view1;
-- select pg_get_viewdef('agg_view1'::regclass);

-- drop view agg_view1;
-- rollback;

-- incorrect DISTINCT usage errors
--Testcase 252:
insert into multi_arg_agg values (1,1,'foo');
--Testcase 253:
select aggfns(distinct a,b,c order by i) from multi_arg_agg, generate_series(1,2) i;
--Testcase 254:
select aggfns(distinct a,b,c order by a,b+1) from multi_arg_agg, generate_series(1,2) i;
--Testcase 255:
select aggfns(distinct a,b,c order by a,b,i,c) from multi_arg_agg, generate_series(1,2) i;
--Testcase 256:
select aggfns(distinct a,a,c order by a,b) from multi_arg_agg, generate_series(1,2) i;

-- mysql_fdw did not supported transactions
-- -- string_agg tests
-- begin;
-- delete from varchar_tbl;
-- insert into varchar_tbl values ('aaaa'),('bbbb'),('cccc');
-- select string_agg(f1,',') from varchar_tbl;

-- delete from varchar_tbl;
-- insert into varchar_tbl values ('aaaa'),(null),('bbbb'),('cccc');
-- select string_agg(f1,',') from varchar_tbl;

-- delete from varchar_tbl;
-- insert into varchar_tbl values (null),(null),('bbbb'),('cccc');
-- select string_agg(f1,'AB') from varchar_tbl;

-- delete from varchar_tbl;
-- insert into varchar_tbl values (null),(null);
-- select string_agg(f1,',') from varchar_tbl;
-- rollback;

-- check some implicit casting cases, as per bug #5564

--Testcase 257:
select string_agg(distinct f1, ',' order by f1) from varchar_tbl;  -- ok
--Testcase 258:
select string_agg(distinct f1::text, ',' order by f1) from varchar_tbl;  -- not ok
--Testcase 259:
select string_agg(distinct f1, ',' order by f1::text) from varchar_tbl;  -- not ok
--Testcase 260:
select string_agg(distinct f1::text, ',' order by f1::text) from varchar_tbl;  -- ok

-- string_agg bytea tests
--Testcase 261:
create foreign table bytea_test_table(v bytea) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'bytea_test_table');

--Testcase 262:
select string_agg(v, '') from bytea_test_table;

--Testcase 263:
insert into bytea_test_table values(decode('ff','hex'));

--Testcase 264:
select string_agg(v, '') from bytea_test_table;

--Testcase 265:
insert into bytea_test_table values(decode('aa','hex'));

--Testcase 266:
select string_agg(v, '') from bytea_test_table;
--Testcase 267:
select string_agg(v, NULL) from bytea_test_table;
--Testcase 268:
select string_agg(v, decode('ee', 'hex')) from bytea_test_table;

--Testcase 269:
drop foreign table bytea_test_table;

-- FILTER tests

--Testcase 270:
select min(unique1) filter (where unique1 > 100) from tenk1;

--Testcase 271:
select sum(1/ten) filter (where ten > 0) from tenk1;

--Testcase 272:
select ten, sum(distinct four) filter (where four::text ~ '123') from onek a
group by ten;

--Testcase 273:
select ten, sum(distinct four) filter (where four > 10) from onek a
group by ten
having exists (select 1 from onek b where sum(distinct a.four) = b.four);

--Testcase 274:
create foreign table agg_t17(foo text, bar text) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_t17');
--Testcase 275:
insert into agg_t17 values ('a', 'b');

--Testcase 276:
select max(foo COLLATE "C") filter (where (bar collate "POSIX") > '0')
from agg_t17;

-- outer reference in FILTER (PostgreSQL extension)
--Testcase 277:
create foreign table agg_t18 (inner_c int) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_t18');
--Testcase 278:
create foreign table agg_t19 (outer_c int) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_t19');
--Testcase 279:
insert into agg_t18 values (1);
--Testcase 280:
insert into agg_t19 values (2), (3);

--Testcase 281:
select (select count(*)
        from agg_t18) from agg_t19; -- inner query is aggregation query
--Testcase 282:
select (select count(*) filter (where outer_c <> 0)
        from agg_t18) from agg_t19; -- outer query is aggregation query
--Testcase 283:
select (select count(inner_c) filter (where outer_c <> 0)
        from agg_t18) from agg_t19; -- inner query is aggregation query

--Testcase 284:
select
  (select max((select i.unique2 from tenk1 i where i.unique1 = o.unique1))
     filter (where o.unique1 < 10))
from tenk1 o;					-- outer query is aggregation query

-- subquery in FILTER clause (PostgreSQL extension)
--Testcase 285:
select sum(unique1) FILTER (WHERE
  unique1 IN (SELECT unique1 FROM onek where unique1 < 100)) FROM tenk1;

-- mysql_fdw did not supported transactions
-- -- exercise lots of aggregate parts with FILTER
-- begin;
-- delete from multi_arg_agg;
-- insert into multi_arg_agg values (1,3,'foo'),(0,null,null),(2,2,'bar'),(3,1,'baz');
-- select aggfns(distinct a,b,c order by a,c using ~<~,b) filter (where a > 1) from multi_arg_agg, generate_series(1,2) i;
-- rollback;

-- check handling of bare boolean Var in FILTER
--Testcase 372:
select max(0) filter (where b1) from bool_test;
--Testcase 373:
select (select max(0) filter (where b1)) from bool_test;

-- check for correct detection of nested-aggregate errors in FILTER
--Testcase 374:
select max(unique1) filter (where sum(ten) > 0) from tenk1;
--Testcase 375:
select (select max(unique1) filter (where sum(ten) > 0) from int8_tbl) from tenk1;
--Testcase 376:
select max(unique1) filter (where bool_or(ten > 0)) from tenk1;
--Testcase 377:
select (select max(unique1) filter (where bool_or(ten > 0)) from int8_tbl) from tenk1;

-- -- ordered-set aggregates

-- begin;
-- delete from FLOAT8_TBL;
-- insert into FLOAT8_TBL values (0::float8),(0.1),(0.25),(0.4),(0.5),(0.6),(0.75),(0.9),(1);
-- select f1, percentile_cont(f1) within group (order by x::float8)
-- from generate_series(1,5) x,
--      FLOAT8_TBL
-- group by f1 order by f1;
-- rollback;

-- begin;
-- delete from FLOAT8_TBL;
-- insert into FLOAT8_TBL values (0::float8),(0.1),(0.25),(0.4),(0.5),(0.6),(0.75),(0.9),(1);
-- select f1, percentile_cont(f1 order by f1) within group (order by x)  -- error
-- from generate_series(1,5) x,
--      FLOAT8_TBL
-- group by f1 order by f1;
-- rollback;

-- begin;
-- delete from FLOAT8_TBL;
-- insert into FLOAT8_TBL values (0::float8),(0.1),(0.25),(0.4),(0.5),(0.6),(0.75),(0.9),(1);
-- select f1, sum() within group (order by x::float8)  -- error
-- from generate_series(1,5) x,
--      FLOAT8_TBL
-- group by f1 order by f1;
-- rollback;

-- begin;
-- delete from FLOAT8_TBL;
-- insert into FLOAT8_TBL values (0::float8),(0.1),(0.25),(0.4),(0.5),(0.6),(0.75),(0.9),(1);
-- select f1, percentile_cont(f1,f1)  -- error
-- from generate_series(1,5) x,
--      FLOAT8_TBL
-- group by f1 order by f1;
-- rollback;

-- Round the result to limited digits to avoid platform-specific results.
--Testcase 286:
select (percentile_cont(0.5) within group (order by b))::numeric(20,10) from aggtest;
-- Round the result to limited digits to avoid platform-specific results.
--Testcase 287:
select (percentile_cont(0.5) within group (order by b))::numeric(20,10), sum(b)::numeric(10,3) from aggtest;
-- Round the result to limited digits to avoid platform-specific results.
--Testcase 288:
select percentile_cont(0.5) within group (order by thousand) from tenk1;
--Testcase 289:
select percentile_disc(0.5) within group (order by thousand) from tenk1;

-- mysql_fdw did not supported transactions
-- begin;
-- delete from INT4_TBL;
-- insert into INT4_TBL values (1),(1),(2),(2),(3),(3),(4);
-- select rank(3) within group (order by f1) from INT4_TBL;
-- select cume_dist(3) within group (order by f1) from INT4_TBL;
-- insert into INT4_TBL values (5);
-- -- Round the result to limited digits to avoid platform-specific results.
-- select (percent_rank(3) within group (order by f1))::numeric(20,10) from INT4_TBL;
-- delete from INT4_TBL where f1 = 5;
-- select dense_rank(3) within group (order by f1) from INT4_TBL;
-- rollback;

--Testcase 290:
select percentile_disc(array[0,0.1,0.25,0.5,0.75,0.9,1]) within group (order by thousand)
from tenk1;
--Testcase 291:
select percentile_cont(array[0,0.25,0.5,0.75,1]) within group (order by thousand)
from tenk1;
--Testcase 292:
select percentile_disc(array[[null,1,0.5],[0.75,0.25,null]]) within group (order by thousand)
from tenk1;

--Testcase 293:
create foreign table agg_t21 (x int) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_t21');
-- mysql_fdw did not supported transactions
-- begin;
-- insert into agg_t21 select * from generate_series(1,6);
-- select percentile_cont(array[0,1,0.25,0.75,0.5,1,0.3,0.32,0.35,0.38,0.4]) within group (order by x)
-- from agg_t21;
-- rollback;

--Testcase 294:
select ten, mode() within group (order by string4) from tenk1 group by ten;

--Testcase 295:
create foreign table agg_t20 (x text) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_t20');
-- mysql_fdw did not supported transactions
-- begin;
-- insert into agg_t20 values (unnest('{fred,jim,fred,jack,jill,fred,jill,jim,jim,sheila,jim,sheila}'::text[]));
-- select percentile_disc(array[0.25,0.5,0.75]) within group (order by x) from agg_t20;
-- rollback;

-- -- check collation propagates up in suitable cases:
-- begin;
-- insert into agg_t20 values ('fred'), ('jim');
-- select pg_collation_for(percentile_disc(1) within group (order by x collate "POSIX")) from agg_t20;
-- rollback;

-- ordered-set aggs created with CREATE AGGREGATE
--Testcase 296:
create aggregate my_percentile_disc(float8 ORDER BY anyelement) (
  stype = internal,
  sfunc = ordered_set_transition,
  finalfunc = percentile_disc_final,
  finalfunc_extra = true,
  finalfunc_modify = read_write
);

--Testcase 297:
create aggregate my_rank(VARIADIC "any" ORDER BY VARIADIC "any") (
  stype = internal,
  sfunc = ordered_set_transition_multi,
  finalfunc = rank_final,
  finalfunc_extra = true,
  hypothetical
);

--Testcase 352:
alter aggregate my_percentile_disc(float8 ORDER BY anyelement)
  rename to test_percentile_disc;
  
--Testcase 353:
alter aggregate my_rank(VARIADIC "any" ORDER BY VARIADIC "any")
  rename to test_rank;

-- mysql_fdw did not supported transactions
-- begin;
-- insert into agg_t21 values (1),(1),(2),(2),(3),(3),(4);
-- select test_rank(3) within group (order by x) from agg_t21;
-- rollback;
 
--Testcase 298:
select test_percentile_disc(0.5) within group (order by thousand) from tenk1;

-- -- ordered-set aggs can't use ungrouped vars in direct args:
-- begin;
-- insert into agg_t21 select * from generate_series(1,5);
-- select rank(x) within group (order by x) from agg_t21;
-- rollback;

-- -- outer-level agg can't use a grouped arg of a lower level, either:
-- begin;
-- insert into agg_t21 select * from generate_series(1,5);
-- select array(select percentile_disc(a) within group (order by x)
--                from (values (0.3),(0.7)) v(a) group by a)
--   from agg_t21;
-- rollback;

-- -- agg in the direct args is a grouping violation, too:
-- begin;
-- insert into agg_t21 select * from generate_series(1,5);
-- select rank(sum(x)) within group (order by x) from agg_t21;
-- rollback;

-- -- hypothetical-set type unification and argument-count failures:
-- begin;
-- insert into agg_t20 values ('fred'), ('jim');
-- select rank(3) within group (order by x) from agg_t20;
-- rollback;

--Testcase 299:
select rank(3) within group (order by stringu1,stringu2) from tenk1;

-- begin;
-- insert into agg_t21 select * from generate_series(1,5);
-- select rank('fred') within group (order by x) from agg_t21;
-- rollback;

-- begin;
-- insert into agg_t20 values ('fred'), ('jim');
-- select rank('adam'::text collate "C") within group (order by x collate "POSIX")
--   from agg_t20;
-- rollback;

-- -- hypothetical-set type unification successes:
-- begin;
-- insert into agg_t20 values ('fred'), ('jim');
-- select rank('adam'::varchar) within group (order by x) from agg_t20;
-- rollback;

-- begin;
-- insert into agg_t21 select * from generate_series(1,5);
-- select rank('3') within group (order by x) from agg_t21;
-- rollback;

-- -- divide by zero check
-- begin;
-- insert into agg_t21 select * from generate_series(1,0);
-- select percent_rank(0) within group (order by x) from agg_t21;
-- rollback;

-- deparse and multiple features:
--Testcase 300:
create view aggordview1 as
select ten,
       percentile_disc(0.5) within group (order by thousand) as p50,
       percentile_disc(0.5) within group (order by thousand) filter (where hundred=1) as px,
       rank(5,'AZZZZ',50) within group (order by hundred, string4 desc, hundred)
  from tenk1
 group by ten order by ten;

--Testcase 301:
select pg_get_viewdef('aggordview1');
--Testcase 302:
select * from aggordview1 order by ten;
--Testcase 303:
drop view aggordview1;

-- variadic aggregates
--Testcase 304:
create function least_accum(anyelement, variadic anyarray)
returns anyelement language sql as
  'select least($1, min($2[i])) from generate_subscripts($2,1) g(i)';

--Testcase 305:
create aggregate least_agg(variadic items anyarray) (
  stype = anyelement, sfunc = least_accum
);

--Testcase 306:
create function cleast_accum(anycompatible, variadic anycompatiblearray)
returns anycompatible language sql as
  'select least($1, min($2[i])) from generate_subscripts($2,1) g(i)';

--Testcase 307:
create aggregate cleast_agg(variadic items anycompatiblearray) (
  stype = anycompatible, sfunc = cleast_accum);

--Testcase 308:
select least_agg(q1,q2) from int8_tbl;
--Testcase 309:
select least_agg(variadic array[q1,q2]) from int8_tbl;

--Testcase 310:
select cleast_agg(q1,q2) from int8_tbl;
--Testcase 311:
select cleast_agg(4.5,f1) from int4_tbl;
--Testcase 312:
select cleast_agg(variadic array[4.5,f1]) from int4_tbl;
--Testcase 313:
select pg_typeof(cleast_agg(variadic array[4.5,f1])) from int4_tbl;

-- test aggregates with common transition functions share the same states
--Testcase 314:
create foreign table agg_t10(one int, id int options (key 'true')) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_t10');
--Testcase 315:
create foreign table agg_t11(one int, two int, id int options (key 'true')) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_t11');
--Testcase 316:
create foreign table agg_t12(a int, id int options (key 'true')) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_t12');

-- mysql_fdw did not supported transactions
-- begin work;

-- create type avg_state as (total bigint, count bigint);

-- create or replace function avg_transfn(state avg_state, n int) returns avg_state as
-- $$
-- declare new_state avg_state;
-- begin
-- 	raise notice 'avg_transfn called with %', n;
-- 	if state is null then
-- 		if n is not null then
-- 			new_state.total := n;
-- 			new_state.count := 1;
-- 			return new_state;
-- 		end if;
-- 		return null;
-- 	elsif n is not null then
-- 		state.total := state.total + n;
-- 		state.count := state.count + 1;
-- 		return state;
-- 	end if;

-- 	return null;
-- end
-- $$ language plpgsql;

-- create function avg_finalfn(state avg_state) returns int4 as
-- $$
-- begin
-- 	if state is null then
-- 		return NULL;
-- 	else
-- 		return state.total / state.count;
-- 	end if;
-- end
-- $$ language plpgsql;

-- create function sum_finalfn(state avg_state) returns int4 as
-- $$
-- begin
-- 	if state is null then
-- 		return NULL;
-- 	else
-- 		return state.total;
-- 	end if;
-- end
-- $$ language plpgsql;

-- create aggregate my_avg(int4)
-- (
--    stype = avg_state,
--    sfunc = avg_transfn,
--    finalfunc = avg_finalfn
-- );

-- create aggregate my_sum(int4)
-- (
--    stype = avg_state,
--    sfunc = avg_transfn,
--    finalfunc = sum_finalfn
-- );

-- -- aggregate state should be shared as aggs are the same.
-- delete from agg_t10;
-- insert into agg_t10 values (1), (3);
-- select my_avg(one),my_avg(one) from agg_t10;

-- -- aggregate state should be shared as transfn is the same for both aggs.
-- select my_avg(one),my_sum(one) from agg_t10;

-- -- same as previous one, but with DISTINCT, which requires sorting the input.
-- delete from agg_t10;
-- insert into agg_t10 values (1), (3), (1);
-- select my_avg(distinct one),my_sum(distinct one) from agg_t10;

-- -- shouldn't share states due to the distinctness not matching.
-- delete from agg_t10;
-- insert into agg_t10 values (1), (3);
-- select my_avg(distinct one),my_sum(one) from agg_t10;

-- -- shouldn't share states due to the filter clause not matching.
-- select my_avg(one) filter (where one > 1),my_sum(one) from agg_t10;

-- -- this should not share the state due to different input columns.
-- delete from agg_t11;
-- insert into agg_t11 values (1,2),(3,4);
-- select my_avg(one),my_sum(two) from agg_t11;

-- -- exercise cases where OSAs share state
-- delete from agg_t12;
-- insert into agg_t12 values (1), (3), (5), (7);
-- select
--   percentile_cont(0.5) within group (order by a),
--   percentile_disc(0.5) within group (order by a)
-- from agg_t12;

-- select
--   percentile_cont(0.25) within group (order by a),
--   percentile_disc(0.5) within group (order by a)
-- from agg_t12;

-- -- these can't share state currently
-- select
--   rank(4) within group (order by a),
--   dense_rank(4) within group (order by a)
-- from agg_t12;

-- -- test that aggs with the same sfunc and initcond share the same agg state
-- create aggregate my_sum_init(int4)
-- (
--    stype = avg_state,
--    sfunc = avg_transfn,
--    finalfunc = sum_finalfn,
--    initcond = '(10,0)'
-- );

-- create aggregate my_avg_init(int4)
-- (
--    stype = avg_state,
--    sfunc = avg_transfn,
--    finalfunc = avg_finalfn,
--    initcond = '(10,0)'
-- );

-- create aggregate my_avg_init2(int4)
-- (
--    stype = avg_state,
--    sfunc = avg_transfn,
--    finalfunc = avg_finalfn,
--    initcond = '(4,0)'
-- );

-- -- state should be shared if INITCONDs are matching
-- delete from agg_t10;
-- insert into agg_t10 values (1), (3);
-- select my_sum_init(one),my_avg_init(one) from agg_t10;


-- -- Varying INITCONDs should cause the states not to be shared.
-- select my_sum_init(one),my_avg_init2(one) from agg_t10;

-- rollback;

-- -- test aggregate state sharing to ensure it works if one aggregate has a
-- -- finalfn and the other one has none.
-- begin work;

-- create or replace function sum_transfn(state int4, n int4) returns int4 as
-- $$
-- declare new_state int4;
-- begin
-- 	raise notice 'sum_transfn called with %', n;
-- 	if state is null then
-- 		if n is not null then
-- 			new_state := n;
-- 			return new_state;
-- 		end if;
-- 		return null;
-- 	elsif n is not null then
-- 		state := state + n;
-- 		return state;
-- 	end if;

-- 	return null;
-- end
-- $$ language plpgsql;

-- create function halfsum_finalfn(state int4) returns int4 as
-- $$
-- begin
-- 	if state is null then
-- 		return NULL;
-- 	else
-- 		return state / 2;
-- 	end if;
-- end
-- $$ language plpgsql;

-- create aggregate my_sum(int4)
-- (
--    stype = int4,
--    sfunc = sum_transfn
-- );

-- create aggregate my_half_sum(int4)
-- (
--    stype = int4,
--    sfunc = sum_transfn,
--    finalfunc = halfsum_finalfn
-- );

-- -- Agg state should be shared even though my_sum has no finalfn
-- delete from agg_t10;
-- insert into agg_t10 values (1), (2), (3), (4);
-- select my_sum(one),my_half_sum(one) from agg_t10;

-- rollback;


-- -- test that the aggregate transition logic correctly handles
-- -- transition / combine functions returning NULL

-- -- First test the case of a normal transition function returning NULL
-- BEGIN;
-- CREATE FUNCTION balkifnull(int8, int4)
-- RETURNS int8
-- STRICT
-- LANGUAGE plpgsql AS $$
-- BEGIN
--     IF $1 IS NULL THEN
--        RAISE 'erroneously called with NULL argument';
--     END IF;
--     RETURN NULL;
-- END$$;

-- CREATE AGGREGATE balk(int4)
-- (
--     SFUNC = balkifnull(int8, int4),
--     STYPE = int8,
--     PARALLEL = SAFE,
--     INITCOND = '0'
-- );

-- SELECT balk(hundred) FROM tenk1;

-- ROLLBACK;

-- -- Secondly test the case of a parallel aggregate combiner function
-- -- returning NULL. For that use normal transition function, but a
-- -- combiner function returning NULL.
-- BEGIN ISOLATION LEVEL REPEATABLE READ;
-- CREATE FUNCTION balkifnull(int8, int8)
-- RETURNS int8
-- PARALLEL SAFE
-- STRICT
-- LANGUAGE plpgsql AS $$
-- BEGIN
--     IF $1 IS NULL THEN
--        RAISE 'erroneously called with NULL argument';
--     END IF;
--     RETURN NULL;
-- END$$;

-- CREATE AGGREGATE balk(int4)
-- (
--     SFUNC = int4_sum(int8, int4),
--     STYPE = int8,
--     COMBINEFUNC = balkifnull(int8, int8),
--     PARALLEL = SAFE,
--     INITCOND = '0'
-- );

-- -- force use of parallelism
-- -- Skip this test, cannot alter foreign table tenk1
-- -- ALTER FOREIGN TABLE tenk1 set (parallel_workers = 4);
-- -- SET LOCAL parallel_setup_cost=0;
-- -- SET LOCAL max_parallel_workers_per_gather=4;

-- -- EXPLAIN (COSTS OFF) SELECT balk(hundred) FROM tenk1;
-- -- SELECT balk(hundred) FROM tenk1;

-- ROLLBACK;

-- -- test coverage for aggregate combine/serial/deserial functions
-- BEGIN ISOLATION LEVEL REPEATABLE READ;

-- SET parallel_setup_cost = 0;
-- SET parallel_tuple_cost = 0;
-- SET min_parallel_table_scan_size = 0;
-- SET max_parallel_workers_per_gather = 4;
-- SET parallel_leader_participation = off;
-- SET enable_indexonlyscan = off;

-- -- variance(int4) covers numeric_poly_combine
-- -- sum(int8) covers int8_avg_combine
-- -- regr_count(float8, float8) covers int8inc_float8_float8 and aggregates with > 1 arg
-- EXPLAIN (COSTS OFF, VERBOSE)
-- SELECT variance(unique1::int4), sum(unique1::int8), regr_count(unique1::float8, unique1::float8)
-- FROM (SELECT * FROM tenk1
--       UNION ALL SELECT * FROM tenk1
--       UNION ALL SELECT * FROM tenk1
--       UNION ALL SELECT * FROM tenk1) u;

-- SELECT variance(unique1::int4), sum(unique1::int8), regr_count(unique1::float8, unique1::float8)
-- FROM (SELECT * FROM tenk1
--       UNION ALL SELECT * FROM tenk1
--       UNION ALL SELECT * FROM tenk1
--       UNION ALL SELECT * FROM tenk1) u;

-- -- variance(int8) covers numeric_combine
-- -- avg(numeric) covers numeric_avg_combine
-- EXPLAIN (COSTS OFF, VERBOSE)
-- SELECT variance(unique1::int8), avg(unique1::numeric)
-- FROM (SELECT * FROM tenk1
--       UNION ALL SELECT * FROM tenk1
--       UNION ALL SELECT * FROM tenk1
--       UNION ALL SELECT * FROM tenk1) u;

-- SELECT variance(unique1::int8), avg(unique1::numeric)
-- FROM (SELECT * FROM tenk1
--       UNION ALL SELECT * FROM tenk1
--       UNION ALL SELECT * FROM tenk1
--       UNION ALL SELECT * FROM tenk1) u;

-- ROLLBACK;

-- test coverage for dense_rank
--Testcase 317:
create foreign table agg_t13(x int, id int options (key 'true')) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_t13');
--Testcase 318:
insert into agg_t13 values (1),(1),(2),(2),(3),(3);
--Testcase 319:
SELECT dense_rank(x) WITHIN GROUP (ORDER BY x) FROM agg_t13 GROUP BY (x) ORDER BY 1;
--Testcase 320:
delete from agg_t13;


-- Ensure that the STRICT checks for aggregates does not take NULLness
-- of ORDER BY columns into account. See bug report around
-- 2a505161-2727-2473-7c46-591ed108ac52@email.cz
--Testcase 321:
create foreign table agg_t14(x int, y int, id int options (key 'true')) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_t14');
--Testcase 322:
insert into agg_t14 values (1, NULL);
--Testcase 323:
SELECT min(x ORDER BY y) FROM agg_t14;
--Testcase 324:
delete from agg_t14;
--Testcase 354:
insert into agg_t14 values (1, 2);
--Testcase 355:
SELECT min(x ORDER BY y) FROM agg_t14;

-- mysql_fdw did not supported transactions
-- -- check collation-sensitive matching between grouping expressions
-- begin;
-- insert into agg_t20 values (unnest(array['a','b']));
-- select x||'a', case x||'a' when 'aa' then 1 else 0 end, count(*)
--   from agg_t20 group by x||'a' order by 1;
-- rollback;

-- begin;
-- insert into agg_t20 values (unnest(array['a','b']));
-- select x||'a', case when x||'a' = 'aa' then 1 else 0 end, count(*)
--   from agg_t20 group by x||'a' order by 1;
-- rollback;

-- Make sure that generation of HashAggregate for uniqification purposes
-- does not lead to array overflow due to unexpected duplicate hash keys
-- see CAFeeJoKKu0u+A_A9R9316djW-YW3-+Gtgvy3ju655qRHR3jtdA@mail.gmail.com
--Testcase 356:
set enable_memoize to off;
--Testcase 325:
explain (costs off)
  select 1 from tenk1
   where (hundred, thousand) in (select twothousand, twothousand from onek);
--Testcase 357:
reset enable_memoize;

--
-- Hash Aggregation Spill tests
--

--Testcase 358:
set enable_sort=false;
--Testcase 359:
set work_mem='64kB';

--Testcase 326:
select unique1, count(*), sum(twothousand) from tenk1
group by unique1
having sum(fivethous) > 4975
order by sum(twothousand);

--Testcase 360:
set work_mem to default;
--Testcase 361:
set enable_sort to default;

--
-- Compare results between plans using sorting and plans using hash
-- aggregation. Force spilling in both cases by setting work_mem low.
--

--Testcase 362:
set work_mem='64kB';

--Testcase 327:
create foreign table agg_data_2k(g int, id int options (key 'true')) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_data_2k');
--Testcase 328:
create foreign table agg_data_20k(g int, id int options (key 'true')) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_data_20k');

--Testcase 329:
create foreign table agg_group_1(c1 int, c2 numeric, c3 int) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_group_1');
--Testcase 330:
create foreign table agg_group_2(a int, c1 numeric, c2 text, c3 int) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_group_2');
--Testcase 331:
create foreign table agg_group_3(c1 numeric, c2 int4, c3 int) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_group_3');
--Testcase 332:
create foreign table agg_group_4(c1 numeric, c2 text, c3 int) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_group_4');

--Testcase 333:
create foreign table agg_hash_1(c1 int, c2 numeric, c3 int) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_hash_1');
--Testcase 334:
create foreign table agg_hash_2(a int, c1 numeric, c2 text, c3 int) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_hash_2');
--Testcase 335:
create foreign table agg_hash_3(c1 numeric, c2 int4, c3 int) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_hash_3');
--Testcase 336:
create foreign table agg_hash_4(c1 numeric, c2 text, c3 int) SERVER mysql_svr OPTIONS (dbname 'mysql_fdw_core', table_name 'agg_hash_4');


-- insert into agg_data_2k select g from generate_series(0, 1999) g;
--analyze agg_data_2k;

-- insert into agg_data_20k select g from generate_series(0, 19999) g;
--analyze agg_data_20k;

-- Produce results with sorting.

--Testcase 363:
set enable_hashagg = false;

--Testcase 364:
set jit_above_cost = 0;

--Testcase 337:
explain (costs off)
select g%10000 as c1, sum(g::numeric) as c2, count(*) as c3
  from agg_data_20k group by g%10000;

--Testcase 338:
insert into agg_group_1
select g%10000 as c1, sum(g::numeric) as c2, count(*) as c3
  from agg_data_20k group by g%10000;

--Testcase 339:
insert into agg_group_2
select * from
  (values (100), (300), (500)) as r(a),
  lateral (
    select (g/2)::numeric as c1,
           array_agg(g::numeric) as c2,
	   count(*) as c3
    from agg_data_2k
    where g < r.a
    group by g/2) as s;

--Testcase 365:
set jit_above_cost to default;

--Testcase 340:
insert into agg_group_3
select (g/2)::numeric as c1, sum(7::int4) as c2, count(*) as c3
  from agg_data_2k group by g/2;

--Testcase 341:
insert into agg_group_4
select (g/2)::numeric as c1, array_agg(g::numeric) as c2, count(*) as c3
  from agg_data_2k group by g/2;

-- Produce results with hash aggregation

--Testcase 366:
set enable_hashagg = true;
--Testcase 367:
set enable_sort = false;

--Testcase 368:
set jit_above_cost = 0;

--Testcase 342:
explain (costs off)
select g%10000 as c1, sum(g::numeric) as c2, count(*) as c3
  from agg_data_20k group by g%10000;

--Testcase 343:
insert into agg_hash_1
select g%10000 as c1, sum(g::numeric) as c2, count(*) as c3
  from agg_data_20k group by g%10000;

--Testcase 344:
insert into agg_hash_2
select * from
  (values (100), (300), (500)) as r(a),
  lateral (
    select (g/2)::numeric as c1,
           array_agg(g::numeric) as c2,
	   count(*) as c3
    from agg_data_2k
    where g < r.a
    group by g/2) as s;

--Testcase 369:
set jit_above_cost to default;

--Testcase 345:
insert into agg_hash_3
select (g/2)::numeric as c1, sum(7::int4) as c2, count(*) as c3
  from agg_data_2k group by g/2;

--Testcase 346:
insert into agg_hash_4
select (g/2)::numeric as c1, array_agg(g::numeric) as c2, count(*) as c3
  from agg_data_2k group by g/2;

--Testcase 370:
set enable_sort = true;
--Testcase 371:
set work_mem to default;

-- Compare group aggregation results to hash aggregation results

--Testcase 347:
(select * from agg_hash_1 except select * from agg_group_1)
  union all
(select * from agg_group_1 except select * from agg_hash_1);

--Testcase 348:
(select * from agg_hash_2 except select * from agg_group_2)
  union all
(select * from agg_group_2 except select * from agg_hash_2);

--Testcase 349:
(select * from agg_hash_3 except select * from agg_group_3)
  union all
(select * from agg_group_3 except select * from agg_hash_3);

--Testcase 350:
(select * from agg_hash_4 except select * from agg_group_4)
  union all
(select * from agg_group_4 except select * from agg_hash_4);

-- Clean up
-- DO $d$
-- declare
--   l_rec record;
-- begin
--   for l_rec in (select foreign_table_schema, foreign_table_name 
--                 from information_schema.foreign_tables) loop
--      execute format('drop foreign table %I.%I cascade;', l_rec.foreign_table_schema, l_rec.foreign_table_name);
--   end loop;
-- end;
-- $d$;
-- DROP SERVER mysql_svr CASCADE;
-- DROP EXTENSION mysql_fdw CASCADE;
