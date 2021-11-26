--Testcase 1:
SET datestyle=ISO;
--Testcase 2:
SET timezone='Japan';
\set ECHO none
\ir sql/parameters.conf
\set ECHO all

--Testcase 3:
CREATE EXTENSION mysql_fdw;
--Testcase 4:
CREATE SERVER server1 FOREIGN DATA WRAPPER mysql_fdw
  OPTIONS (host :MYSQL_HOST, port :MYSQL_PORT);
--Testcase 5:
CREATE USER MAPPING FOR CURRENT_USER SERVER server1
  OPTIONS (username :MYSQL_USER_NAME, password :MYSQL_PASS);

--IMPORT FOREIGN SCHEMA public FROM SERVER server1 INTO public OPTIONS(import_time_text 'false');
--Testcase 6:
CREATE FOREIGN TABLE s3(id int, tag1 text, value1 float, value2 int, value3 float, value4 int, str1 text, str2 text) SERVER server1 OPTIONS(dbname 'mysql_fdw_regress', table_name 's3');

--Testcase 7:
CREATE FOREIGN TABLE s4(id int, c1 time without time zone) SERVER server1 OPTIONS(dbname 'mysql_fdw_regress', table_name 's4');

-- s3 (value1 as float8, value2 as bigint)
--Testcase 8:
\d s3;
--Testcase 9:
SELECT * FROM s3;

-- select float8() (not pushdown, remove float8, explain)
--Testcase 10:
EXPLAIN VERBOSE
SELECT float8(value1), float8(value2), float8(value3), float8(value4) FROM s3;

-- select float8() (not pushdown, remove float8, result)
--Testcase 11:
SELECT float8(value1), float8(value2), float8(value3), float8(value4) FROM s3;

-- select abs (builtin function, explain)
--Testcase 12:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3;

-- select abs (buitin function, result)
--Testcase 13:
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3;

-- select abs (builtin function, not pushdown constraints, explain)
--Testcase 14:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE to_hex(value2) != '64';

-- select abs (builtin function, not pushdown constraints, result)
--Testcase 15:
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE to_hex(value2) != '64';

-- select abs (builtin function, pushdown constraints, explain)
--Testcase 16:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE value2 != 200;

-- select abs (builtin function, pushdown constraints, result)
--Testcase 17:
SELECT abs(value1), abs(value2), abs(value3), abs(value4) FROM s3 WHERE value2 != 200;

-- select log (builtin function, numeric cast, explain)
-- log_<base>(v) : postgresql (base, v), mysql (base, v)
--Testcase 18:
EXPLAIN VERBOSE
SELECT value1, log(value1::numeric, value2::numeric) FROM s3 WHERE value1 != 1;

-- select log (builtin function, numeric cast, result)
--Testcase 19:
SELECT value1, log(value1::numeric, value2::numeric) FROM s3 WHERE value1 != 1;

-- select log (builtin function,  float8, explain)
--Testcase 20:
EXPLAIN VERBOSE
SELECT value1, log(value1::numeric, 0.1) FROM s3 WHERE value1 != 1;

-- select log (builtin function, float8, result)
--Testcase 21:
SELECT value1, log(value1::numeric, 0.1) FROM s3 WHERE value1 != 1;

-- select log (builtin function, bigint, explain)
--Testcase 22:
EXPLAIN VERBOSE
SELECT value1, log(value2::numeric, 3) FROM s3 WHERE value1 != 1;

-- select log (builtin function, bigint, result)
--Testcase 23:
SELECT value1, log(value2::numeric, 3) FROM s3 WHERE value1 != 1;

-- select log (builtin function, mix type, explain)
--Testcase 24:
EXPLAIN VERBOSE
SELECT value1, log(value1::numeric, value2::numeric) FROM s3 WHERE value1 != 1;

-- select log (builtin function,  mix type, result)
--Testcase 25:
SELECT value1, log(value1::numeric, value2::numeric) FROM s3 WHERE value1 != 1;

-- select log(v) -- built in function
-- log(v): postgreSQL base 10 logarithm
--Testcase 26:
EXPLAIN VERBOSE
SELECT log(value2) FROM s3 WHERE value1 != 1;
--Testcase 27:
SELECT log(value2) FROM s3 WHERE value1 != 1;

-- select log (builtin function, explain)
--Testcase 28:
EXPLAIN VERBOSE
SELECT log(value1), log(value2), log(0.5) FROM s3;

-- select log (builtin function, result)
--Testcase 29:
SELECT log(value1), log(value2), log(0.5) FROM s3;

-- select log (builtin function, not pushdown constraints, explain)
--Testcase 30:
EXPLAIN VERBOSE
SELECT log(value1), log(value2), log(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select log (builtin function, not pushdown constraints, result)
--Testcase 31:
SELECT log(value1), log(value2), log(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select log (builtin function, pushdown constraints, explain)
--Testcase 32:
EXPLAIN VERBOSE
SELECT log(value1), log(value2), log(0.5) FROM s3 WHERE value2 != 200;

-- select log (builtin function, pushdown constraints, result)
--Testcase 33:
SELECT log(value1), log(value2), log(0.5) FROM s3 WHERE value2 != 200;

-- select log (builtin function, log in constraints, explain)
--Testcase 34:
EXPLAIN VERBOSE
SELECT log(value1), log(value2), log(0.5) FROM s3 WHERE log(value1) != 1;

-- select log (builtin function, log in constraints, result)
--Testcase 35:
SELECT log(value1), log(value2), log(0.5) FROM s3 WHERE log(value1) != 1;

-- select log (builtin function, log in constraints, explain)
--Testcase 36:
EXPLAIN VERBOSE
SELECT log(value1), log(value2), log(0.5) FROM s3 WHERE log(5) > value1;

-- select log (builtin function, log in constraints, result)
--Testcase 37:
SELECT log(value1), log(value2), log(0.5) FROM s3 WHERE log(5) > value1;

-- select log as nest function with agg (pushdown, explain)
--Testcase 38:
EXPLAIN VERBOSE
SELECT sum(value3),log(sum(value2)) FROM s3;

-- select log as nest function with agg (pushdown, result)
--Testcase 39:
SELECT sum(value3),log(sum(value2)) FROM s3;

-- select log as nest with log2 (pushdown, explain)
--Testcase 40:
EXPLAIN VERBOSE
SELECT value1, log(log2(value1)),log(log2(1/value1)) FROM s3;

-- select log as nest with log2 (pushdown, result)
--Testcase 41:
SELECT value1, log(log2(value1)),log(log2(1/value1)) FROM s3;

-- select log with non pushdown func and explicit constant (explain)
--Testcase 42:
EXPLAIN VERBOSE
SELECT log(value2), pi(), 4.1 FROM s3;

-- select log with non pushdown func and explicit constant (result)
--Testcase 43:
SELECT log(value2), pi(), 4.1 FROM s3;

-- select log with order by (explain)
--Testcase 44:
EXPLAIN VERBOSE
SELECT value3, log(1-value3) FROM s3 ORDER BY log(1-value3);

-- select log with order by (result)
--Testcase 45:
SELECT value3, log(1-value3) FROM s3 ORDER BY log(1-value3);

-- select log with order by index (result)
--Testcase 46:
SELECT value3, log(1-value3) FROM s3 ORDER BY 2,1;

-- select log with order by index (result)
--Testcase 47:
SELECT value3, log(1-value3) FROM s3 ORDER BY 1,2;

-- select log with group by (explain)
--Testcase 48:
EXPLAIN VERBOSE
SELECT count(value1), log(1-value3) FROM s3 GROUP BY log(1-value3);

-- select log with group by (result)
--Testcase 49:
SELECT count(value1), log(1-value3) FROM s3 GROUP BY log(1-value3);

-- select log with group by index (result)
--Testcase 50:
SELECT value1, log(1-value3) FROM s3 GROUP BY 2,1;

-- select log with group by index (result)
--Testcase 51:
SELECT value1, log(1-value3) FROM s3 GROUP BY 1,2;

-- select log with group by having (explain)
--Testcase 52:
EXPLAIN VERBOSE
SELECT count(value1), log(1-value3) FROM s3 GROUP BY log(1-value3) HAVING log(avg(value1)) > 0;

-- select log with group by having (result)
--Testcase 53:
SELECT count(value1), log(1-value3) FROM s3 GROUP BY log(1-value3) HAVING log(avg(value1)) > 0;

-- select log with group by index having (result)
--Testcase 54:
SELECT value3, log(1-value3) FROM s3 GROUP BY 2,1 HAVING log(1-value3) < 0;

-- select log with group by index having (result)
--Testcase 55:
SELECT value3, log(1-value3) FROM s3 GROUP BY 1,2 HAVING value3 > 1;

-- select log and as
--Testcase 56:
SELECT log(value1) as log1 FROM s3;

-- select abs as nest function with agg (pushdown, explain)
--Testcase 57:
EXPLAIN VERBOSE
SELECT sum(value3),abs(sum(value3)) FROM s3;

-- select abs as nest function with agg (pushdown, result)
--Testcase 58:
SELECT sum(value3),abs(sum(value3)) FROM s3;

-- test aggregation (sum, count, avg) with time interval
--Testcase 59:
SELECT * FROM s4;
-- sum and time without casting to interval
--Testcase 60:
EXPLAIN VERBOSE
SELECT sum(c1) + '24:10:10'::interval FROM s4 GROUP BY id;
--Testcase 61:
SELECT sum(c1) + '24:10:10'::interval FROM s4 GROUP BY id;

-- sum and time with casting to interval
--Testcase 62:
EXPLAIN VERBOSE
SELECT sum(c1::interval) + '24:10:10'::interval FROM s4 GROUP BY id;
--Testcase 63:
SELECT sum(c1::interval) + '24:10:10'::interval FROM s4 GROUP BY id;

-- sum and time with interval const and without casting to interval
--Testcase 64:
EXPLAIN VERBOSE
SELECT sum(c1 + '24:10:10'::interval) + '24:10:10'::interval FROM s4 GROUP BY id;
--Testcase 65:
SELECT sum(c1 + '24:10:10'::interval) + '24:10:10'::interval FROM s4 GROUP BY id;

-- sum and time with interval const and with casting to interval
--Testcase 66:
EXPLAIN VERBOSE
SELECT sum(c1::interval + '24:10:10'::interval) + '24:10:10'::interval FROM s4 GROUP BY id;
--Testcase 67:
SELECT sum(c1::interval + '24:10:10'::interval) + '24:10:10'::interval FROM s4 GROUP BY id;

-- sum and time with milisecond
--Testcase 68:
EXPLAIN VERBOSE
SELECT sum(c1::interval + '24:10:10.123456'::interval) + '24:10:10'::interval FROM s4 GROUP BY id;
--Testcase 69:
SELECT sum(c1::interval + '24:10:10.123456'::interval) + '24:10:10'::interval FROM s4 GROUP BY id;

-- avg and time without casting to interval
--Testcase 70:
EXPLAIN VERBOSE
SELECT avg(c1) + '24:10:10'::interval FROM s4 GROUP BY id;
--Testcase 71:
SELECT avg(c1) + '24:10:10'::interval FROM s4 GROUP BY id;

-- avg and time with casting to interval
--Testcase 72:
EXPLAIN VERBOSE
SELECT avg(c1::interval) + '24:10:10'::interval FROM s4 GROUP BY id;
--Testcase 73:
SELECT avg(c1::interval) + '24:10:10'::interval FROM s4 GROUP BY id;

-- avg and time with interval const and without casting to interval
--Testcase 74:
EXPLAIN VERBOSE
SELECT avg(c1 + '24:10:10'::interval) + '24:10:10'::interval FROM s4 GROUP BY id;
--Testcase 75:
SELECT avg(c1 + '24:10:10'::interval) + '24:10:10'::interval FROM s4 GROUP BY id;

-- avg and time with interval const and with casting to interval
--Testcase 76:
EXPLAIN VERBOSE
SELECT avg(c1::interval + '24:10:10'::interval) + '24:10:10'::interval FROM s4 GROUP BY id;
--Testcase 77:
SELECT avg(c1::interval + '24:10:10'::interval) + '24:10:10'::interval FROM s4 GROUP BY id;

-- avg and time with milisecond
--Testcase 78:
EXPLAIN VERBOSE
SELECT avg(c1::interval + '24:10:10.123456'::interval) + '24:10:10'::interval FROM s4 GROUP BY id;
--Testcase 79:
SELECT avg(c1::interval + '24:10:10.123456'::interval) + '24:10:10'::interval FROM s4 GROUP BY id;

-- count with cast to interval
--Testcase 80:
EXPLAIN VERBOSE
SELECT count(c1::interval) FROM s4 GROUP BY id;
--Testcase 81:
SELECT count(c1::interval) FROM s4 GROUP BY id;

-- count without cast to interval
--Testcase 82:
EXPLAIN VERBOSE
SELECT count(c1) FROM s4 GROUP BY id;
--Testcase 83:
SELECT count(c1) FROM s4 GROUP BY id;

-- select abs as nest with log2 (pushdown, explain)
--Testcase 84:
EXPLAIN VERBOSE
SELECT value1, abs(log2(value1)),abs(log2(1/value1)) FROM s3;

-- select abs as nest with log2 (pushdown, result)
--Testcase 85:
SELECT value1, abs(log2(value1)),abs(log2(1/value1)) FROM s3;

-- select abs with non pushdown func and explicit constant (explain)
--Testcase 86:
EXPLAIN VERBOSE
SELECT abs(value3), pi(), 4.1 FROM s3;

-- select abs with non pushdown func and explicit constant (result)
--Testcase 87:
SELECT abs(value3), pi(), 4.1 FROM s3;

-- select sqrt as nest function with agg and explicit constant (pushdown, explain)
--Testcase 88:
EXPLAIN VERBOSE
SELECT sqrt(count(value1)), pi(), 4.1 FROM s3;

-- select sqrt as nest function with agg and explicit constant (pushdown, result)
--Testcase 89:
SELECT sqrt(count(value1)), pi(), 4.1 FROM s3;

-- select sqrt as nest function with agg and explicit constant and tag (error, explain)
--Testcase 90:
EXPLAIN VERBOSE
SELECT sqrt(count(value1)), pi(), 4.1, tag1 FROM s3;

-- select abs with order by (explain)
--Testcase 91:
EXPLAIN VERBOSE
SELECT value3, abs(1-value3) FROM s3 ORDER BY abs(1-value3);

-- select abs with order by (result)
--Testcase 92:
SELECT value3, abs(1-value3) FROM s3 ORDER BY abs(1-value3);

-- select abs with order by index (result)
--Testcase 93:
SELECT value3, abs(1-value3) FROM s3 ORDER BY 2,1;

-- select abs with order by index (result)
--Testcase 94:
SELECT value3, abs(1-value3) FROM s3 ORDER BY 1,2;

-- select abs and as
--Testcase 95:
SELECT abs(value3) as abs1 FROM s3;

-- select abs with arithmetic and tag in the middle (explain)
--Testcase 96:
EXPLAIN VERBOSE
SELECT abs(value1) + 1, value2, tag1, sqrt(value2) FROM s3;

-- select abs with arithmetic and tag in the middle (result)
--Testcase 97:
SELECT abs(value1) + 1, value2, tag1, sqrt(value2) FROM s3;

-- select with order by limit (explain)
--Testcase 98:
EXPLAIN VERBOSE
SELECT abs(value1), abs(value3), sqrt(value2) FROM s3 ORDER BY abs(value3) LIMIT 1;

-- select with order by limit (result)
--Testcase 99:
SELECT abs(value1), abs(value3), sqrt(value2) FROM s3 ORDER BY abs(value3) LIMIT 1;

-- select mixing with non pushdown func (all not pushdown, explain)
--Testcase 100:
EXPLAIN VERBOSE
SELECT abs(value1), sqrt(value2), cosd(id+40) FROM s3;

-- select mixing with non pushdown func (result)
--Testcase 101:
SELECT abs(value1), sqrt(value2), cosd(id+40) FROM s3;

-- select conv (stub function, int column, explain)
--Testcase 102:
EXPLAIN VERBOSE
SELECT conv(id, 10, 2), id FROM s3 WHERE value2 != 100 ORDER BY id, conv(id, 10, 2);

-- select conv (stub function, int column, result)
--Testcase 103:
SELECT conv(id, 10, 2), id FROM s3 WHERE value2 != 100 ORDER BY id, conv(id, 10, 2);

-- select conv (stub function, text column, explain)
--Testcase 104:
EXPLAIN VERBOSE
SELECT conv(str1, 18, 8), str1 FROM s3 WHERE value2 != 200;

-- select conv (stub function, text column, result)
--Testcase 105:
SELECT conv(str1, 18, 8), str1 FROM s3 WHERE value2 != 200;

-- select conv (stub function, const integer, explain)
--Testcase 106:
EXPLAIN VERBOSE
SELECT conv(15, 16, 3), tag1 FROM s3 WHERE value2 != 200 LIMIT 1;

-- select conv (stub function, const integer, result)
--Testcase 107:
SELECT conv(15, 16, 3), tag1 FROM s3 WHERE value2 != 200 LIMIT 1;

-- select conv (stub function, const text, explain)
--Testcase 108:
EXPLAIN VERBOSE
SELECT conv('6hE', 30, -9), str2 FROM s3 WHERE value2 != 200 LIMIT 1;

-- select conv (stub function, const text, explain)
--Testcase 109:
SELECT conv('6hE', 30, -9), str2 FROM s3 WHERE value2 != 200 LIMIT 1;

-- select conv (stub function, calculate, explain)
--Testcase 110:
EXPLAIN VERBOSE
SELECT conv(value2 + '10', 10, 10), value2 FROM s3 WHERE value2 != 50;

-- select conv (stub function, calculate, explain)
--Testcase 111:
SELECT conv(value2 + '10', 10, 10), value2 FROM s3 WHERE value2 != 50;

-- conv() in where clause
-- where conv (stub function, int column, explain)
--Testcase 112:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE conv(value2,10,20) = '50';

-- where conv (stub function, int column, result)
--Testcase 113:
SELECT * FROM s3 WHERE conv(value2,10,20) = '50';

-- where conv (stub function, int column, explain)
--Testcase 114:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE conv(value2,10,20) != str1;

-- where conv (stub function, int column, result)
--Testcase 115:
SELECT * FROM s3 WHERE conv(value2,10,20) != str1;

-- order by conv  (stub function, int column)
-- select conv (stub function, text column, explain)
--Testcase 116:
EXPLAIN VERBOSE
SELECT conv(str1, 18, 8), str1 FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select conv (stub function, text column, result)
--Testcase 117:
SELECT conv(str1, 18, 8), str1 FROM s3 WHERE value2 != 200 ORDER BY 1;

-- select crc32 (stub function, int column, explain)
--Testcase 118:
EXPLAIN VERBOSE
SELECT crc32(id), id FROM s3 WHERE value2 != 100 ORDER BY id, crc32(id);

-- select crc32 (stub function, int column, result)
--Testcase 119:
SELECT crc32(id), id FROM s3 WHERE value2 != 100 ORDER BY id, crc32(id);

-- select crc32 (stub function, int column, explain)
--Testcase 120:
EXPLAIN VERBOSE
SELECT crc32(id), id FROM s3 WHERE value2 = 100 ORDER BY id, crc32(id);

-- select crc32 (stub function, int column, result)
--Testcase 121:
SELECT crc32(id), id FROM s3 WHERE value2 = 100 ORDER BY id, crc32(id);

-- select crc32 (stub function, text column, explain)
--Testcase 122:
EXPLAIN VERBOSE
SELECT crc32(str1), str1 FROM s3 WHERE value2 != 200;

-- select crc32 (stub function, text column, result)
--Testcase 123:
SELECT crc32(str1), str1 FROM s3 WHERE value2 != 200;

-- select crc32 (stub function, const integer, explain)
--Testcase 124:
EXPLAIN VERBOSE
SELECT crc32(15), tag1 FROM s3 WHERE value2 != 200 LIMIT 1;

-- select crc32 (stub function, const integer, result)
--Testcase 125:
SELECT crc32(15), tag1 FROM s3 WHERE value2 != 200 LIMIT 1;

-- select crc32 (stub function, const text, explain)
--Testcase 126:
EXPLAIN VERBOSE
SELECT crc32('6hE'), str2 FROM s3 WHERE value2 != 200 LIMIT 1;

-- select crc32 (stub function, const text, explain)
--Testcase 127:
SELECT crc32('6hE'), str2 FROM s3 WHERE value2 != 200 LIMIT 1;

-- select crc32 (stub function, calculate, explain)
--Testcase 128:
EXPLAIN VERBOSE
SELECT crc32(value2 + '10'), value2 FROM s3 WHERE value2 != 50;

-- select crc32 (stub function, calculate, explain)
--Testcase 129:
SELECT crc32(value2 + '10'), value2 FROM s3 WHERE value2 != 50;

-- select crc32 (builtin function, explain)
--Testcase 130:
EXPLAIN VERBOSE
SELECT value1, crc32(value2), crc32(value3), crc32(value4), crc32(0.5) FROM s3;

-- select crc32 (builtin function, result)
--Testcase 131:
SELECT value1, crc32(value2), crc32(value3), crc32(value4), crc32(0.5) FROM s3;

-- select crc32 (builtin function, not pushdown constraints, explain)
--Testcase 132:
EXPLAIN VERBOSE
SELECT crc32(value1), crc32(value2), crc32(value3), crc32(value4), crc32(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select crc32 (builtin function, not pushdown constraints, result)
--Testcase 133:
SELECT crc32(value1), crc32(value2), crc32(value3), crc32(value4), crc32(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select crc32 (builtin function, pushdown constraints, explain)
--Testcase 134:
EXPLAIN VERBOSE
SELECT crc32(value1), crc32(value2), crc32(value3), crc32(value4), crc32(0.5) FROM s3 WHERE value2 != 200;

-- select crc32 (builtin function, pushdown constraints, result)
--Testcase 135:
SELECT crc32(value1), crc32(value2), crc32(value3), crc32(value4), crc32(0.5) FROM s3 WHERE value2 != 200;

-- select crc32 (builtin function, crc32 in constraints, explain)
--Testcase 136:
EXPLAIN VERBOSE
SELECT value1, crc32(value2), crc32(value3), crc32(value4), crc32(0.5) FROM s3 WHERE crc32(value1) != 1;

-- select crc32 (builtin function, crc32 in constraints, result)
--Testcase 137:
SELECT value1, crc32(value2), crc32(value3), crc32(value4), crc32(0.5) FROM s3 WHERE crc32(value1) != 1;

-- select crc32 (builtin function, crc32 in constraints, explain)
--Testcase 138:
EXPLAIN VERBOSE
SELECT value1, crc32(value2), crc32(value3), crc32(value4), crc32(0.5) FROM s3 WHERE crc32(0.5) > value1;

-- select crc32 (builtin function, crc32 in constraints, result)
--Testcase 139:
SELECT value1, crc32(value2), crc32(value3), crc32(value4), crc32(0.5) FROM s3 WHERE crc32(0.5) > value1;

-- select crc32 as nest function with agg (pushdown, explain)
--Testcase 140:
EXPLAIN VERBOSE
SELECT sum(value3),crc32(sum(value3)) FROM s3;

-- select crc32 as nest function with agg (pushdown, result)
--Testcase 141:
SELECT sum(value3),crc32(sum(value3)) FROM s3;

-- select crc32 as nest with log2 (pushdown, explain)
--Testcase 142:
EXPLAIN VERBOSE
SELECT value1, crc32(log2(value1)),crc32(log2(1/value1)) FROM s3;

-- select crc32 as nest with log2 (pushdown, result)
--Testcase 143:
SELECT value1, crc32(log2(value1)),crc32(log2(1/value1)) FROM s3;

-- select crc32 with non pushdown func and explicit conscrc32t (explain)
--Testcase 144:
EXPLAIN VERBOSE
SELECT value1, crc32(value3), pi(), 4.1 FROM s3;

-- select crc32 with non pushdown func and explicit conscrc32t (result)
--Testcase 145:
SELECT value1, crc32(value3), pi(), 4.1 FROM s3;

-- select crc32 with order by (explain)
--Testcase 146:
EXPLAIN VERBOSE
SELECT value3, crc32(1-value3) FROM s3 ORDER BY crc32(1-value3);

-- select crc32 with order by (result)
--Testcase 147:
SELECT value3, crc32(1-value3) FROM s3 ORDER BY crc32(1-value3);

-- select crc32 with order by index (result)
--Testcase 148:
SELECT value3, crc32(1-value3) FROM s3 ORDER BY 2,1;

-- select crc32 with order by index (result)
--Testcase 149:
SELECT value3, crc32(1-value3) FROM s3 ORDER BY 1,2;

-- select crc32 with group by (explain)
--Testcase 150:
EXPLAIN VERBOSE
SELECT value1, crc32(1-value3) FROM s3 GROUP BY value1, crc32(1-value3);

-- select crc32 with group by (result)
--Testcase 151:
SELECT value1, crc32(1-value3) FROM s3 GROUP BY value1, crc32(1-value3);

-- select crc32 with group by index (result)
--Testcase 152:
SELECT value1, crc32(1-value3) FROM s3 GROUP BY 2,1;

-- select crc32 with group by index (result)
--Testcase 153:
SELECT value1, crc32(1-value3) FROM s3 GROUP BY 1,2;

-- select crc32 with group by having (explain)
--Testcase 154:
EXPLAIN VERBOSE
SELECT value1, crc32(1-value3) FROM s3 GROUP BY value1, crc32(1-value3) HAVING avg(value1) > 0;

-- select crc32 with group by having (result)
--Testcase 155:
SELECT value1, crc32(1-value3) FROM s3 GROUP BY value1, crc32(1-value3) HAVING avg(value1) > 0;

-- select crc32 with group by index having (result)
--Testcase 156:
SELECT value3, crc32(1-value3) FROM s3 GROUP BY 1,2 HAVING value3 > 1;

-- select crc32 and as
--Testcase 157:
SELECT value1, crc32(value3) as crc321 FROM s3;

-- select log10 (builtin function, explain)
--Testcase 158:
EXPLAIN VERBOSE
SELECT log10(value1), log10(value2), log10(0.5) FROM s3;

-- select log10 (builtin function, result)
--Testcase 159:
SELECT log10(value1), log10(value2), log10(0.5) FROM s3;

-- select log10 (builtin function, not pushdown constraints, explain)
--Testcase 160:
EXPLAIN VERBOSE
SELECT log10(value1), log10(value2), log10(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select log10 (builtin function, not pushdown constraints, result)
--Testcase 161:
SELECT log10(value1), log10(value2), log10(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select log10 (builtin function, pushdown constraints, explain)
--Testcase 162:
EXPLAIN VERBOSE
SELECT log10(value1), log10(value2), log10(0.5) FROM s3 WHERE value2 != 200;

-- select log10 (builtin function, pushdown constraints, result)
--Testcase 163:
SELECT log10(value1), log10(value2), log10(0.5) FROM s3 WHERE value2 != 200;

-- select log10 (builtin function, log10 in constraints, explain)
--Testcase 164:
EXPLAIN VERBOSE
SELECT log10(value1), log10(value2), log10(0.5) FROM s3 WHERE log10(value1) != 1;

-- select log10 (builtin function, log10 in constraints, result)
--Testcase 165:
SELECT log10(value1), log10(value2), log10(0.5) FROM s3 WHERE log10(value1) != 1;

-- select log10 (builtin function, log10 in constraints, explain)
--Testcase 166:
EXPLAIN VERBOSE
SELECT log10(value1), log10(value2), log10(0.5) FROM s3 WHERE log10(0.5) < value1;

-- select log10 (builtin function, log10 in constraints, result)
--Testcase 167:
SELECT log10(value1), log10(value2), log10(0.5) FROM s3 WHERE log10(0.5) < value1;

-- select log10 as nest function with agg (pushdown, explain)
--Testcase 168:
EXPLAIN VERBOSE
SELECT sum(value3),log10(sum(value2)) FROM s3;

-- select log10 as nest function with agg (pushdown, result)
--Testcase 169:
SELECT sum(value3),log10(sum(value2)) FROM s3;

-- select log10 as nest with log2 (pushdown, explain)
--Testcase 170:
EXPLAIN VERBOSE
SELECT value1, log10(log2(value1)),log10(log2(1/value1)) FROM s3;

-- select log10 as nest with log2 (pushdown, result)
--Testcase 171:
SELECT value1, log10(log2(value1)),log10(log2(1/value1)) FROM s3;

-- select log10 with non pushdown func and explicit constant (explain)
--Testcase 172:
EXPLAIN VERBOSE
SELECT log10(value2), pi(), 4.1 FROM s3;

-- select log10 with non pushdown func and explicit constant (result)
--Testcase 173:
SELECT log10(value2), pi(), 4.1 FROM s3;

-- select log10 with order by (explain)
--Testcase 174:
EXPLAIN VERBOSE
SELECT value3, log10(1-value3) FROM s3 ORDER BY log10(1-value3);

-- select log10 with order by (result)
--Testcase 175:
SELECT value3, log10(1-value3) FROM s3 ORDER BY log10(1-value3);

-- select log10 with order by index (result)
--Testcase 176:
SELECT value3, log10(1-value3) FROM s3 ORDER BY 2,1;

-- select log10 with order by index (result)
--Testcase 177:
SELECT value3, log10(1-value3) FROM s3 ORDER BY 1,2;

-- select log10 with group by (explain)
--Testcase 178:
EXPLAIN VERBOSE
SELECT count(value1), log10(1-value3) FROM s3 GROUP BY log10(1-value3);

-- select log10 with group by (result)
--Testcase 179:
SELECT count(value1), log10(1-value3) FROM s3 GROUP BY log10(1-value3);

-- select log10 with group by index (result)
--Testcase 180:
SELECT value1, log10(1-value3) FROM s3 GROUP BY 2,1;

-- select log10 with group by index (result)
--Testcase 181:
SELECT value1, log10(1-value3) FROM s3 GROUP BY 1,2;

-- select log10 with group by having (explain)
--Testcase 182:
EXPLAIN VERBOSE
SELECT count(value1), log10(1-value3) FROM s3 GROUP BY log10(1-value3) HAVING log10(avg(value1)) > 0;

-- select log10 with group by having (result)
--Testcase 183:
SELECT count(value1), log10(1-value3) FROM s3 GROUP BY log10(1-value3) HAVING log10(avg(value1)) > 0;

-- select log10 with group by index having (result)
--Testcase 184:
SELECT value3, log10(1-value3) FROM s3 GROUP BY 2,1 HAVING log10(1-value3) < 0;

-- select log10 with group by index having (result)
--Testcase 185:
SELECT value3, log10(1-value3) FROM s3 GROUP BY 1,2 HAVING value3 > 1;

-- select log10 and as
--Testcase 186:
SELECT value1, log10(value1) as log101 FROM s3;

-- select log2 (builtin function, explain)
--Testcase 187:
EXPLAIN VERBOSE
SELECT log2(value1), log2(value2), log2(value3 + 1), log2(value4), log2(0.5) FROM s3;

-- select log2 (builtin function, result)
--Testcase 188:
SELECT log2(value1), log2(value2), log2(value3 + 1), log2(value4), log2(0.5) FROM s3;

-- select log2 (builtin function, not pushdown constraints, explain)
--Testcase 189:
EXPLAIN VERBOSE
SELECT log2(value1), log2(value2), log2(value3 + 1), log2(value4), log2(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select log2 (builtin function, not pushdown constraints, result)
--Testcase 190:
SELECT log2(value1), log2(value2), log2(value3 + 1), log2(value4), log2(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select log2 (builtin function, pushdown constraints, explain)
--Testcase 191:
EXPLAIN VERBOSE
SELECT log2(value1), log2(value2), log2(value3 + 1), log2(value4), log2(0.5) FROM s3 WHERE value2 != 200;

-- select log2 (builtin function, pushdown constraints, result)
--Testcase 192:
SELECT log2(value1), log2(value2), log2(value3 + 1), log2(value4), log2(0.5) FROM s3 WHERE value2 != 200;

-- select log2 (builtin function, log2 in constraints, explain)
--Testcase 193:
EXPLAIN VERBOSE
SELECT log2(value1), log2(value2), log2(value3 + 1), log2(value4), log2(0.5) FROM s3 WHERE log2(value1) != 1;

-- select log2 (builtin function, log2 in constraints, result)
--Testcase 194:
SELECT log2(value1), log2(value2), log2(value3 + 1), log2(value4), log2(0.5) FROM s3 WHERE log2(value1) != 1;

-- select log2 (builtin function, log2 in constraints, explain)
--Testcase 195:
EXPLAIN VERBOSE
SELECT log2(value1), log2(value2), log2(value3 + 1), log2(value4), log2(0.5) FROM s3 WHERE log2(0.5) < value1;

-- select log2 (builtin function, log2 in constraints, result)
--Testcase 196:
SELECT log2(value1), log2(value2), log2(value3 + 1), log2(value4), log2(0.5) FROM s3 WHERE log2(0.5) < value1;

-- select log2 as nest function with agg (pushdown, explain)
--Testcase 197:
EXPLAIN VERBOSE
SELECT sum(value3),log2(sum(value3)) FROM s3;

-- select log2 as nest function with agg (pushdown, result)
--Testcase 198:
SELECT sum(value3),log2(sum(value3)) FROM s3;

-- select log2 as nest with log2 (pushdown, explain)
--Testcase 199:
EXPLAIN VERBOSE
SELECT value1, log2(log2(value1)),log2(log2(1/value1)) FROM s3;

-- select log2 as nest with log2 (pushdown, result)
--Testcase 200:
SELECT value1, log2(log2(value1)),log2(log2(1/value1)) FROM s3;

-- select log2 with non pushdown func and explicit constant (explain)
--Testcase 201:
EXPLAIN VERBOSE
SELECT value1, log2(value3 + 1), pi(), 4.1 FROM s3;

-- select log2 with non pushdown func and explicit constant (result)
--Testcase 202:
SELECT value1, log2(value3 + 1), pi(), 4.1 FROM s3;

-- select log2 with order by (explain)
--Testcase 203:
EXPLAIN VERBOSE
SELECT value3, log2(1-value3) FROM s3 ORDER BY log2(1-value3);

-- select log2 with order by (result)
--Testcase 204:
SELECT value3, log2(1-value3) FROM s3 ORDER BY log2(1-value3);

-- select log2 with order by index (result)
--Testcase 205:
SELECT value3, log2(1-value3) FROM s3 ORDER BY 2,1;

-- select log2 with order by index (result)
--Testcase 206:
SELECT value3, log2(1-value3) FROM s3 ORDER BY 1,2;

-- select log2 with group by (explain)
--Testcase 207:
EXPLAIN VERBOSE
SELECT count(value1), log2(1-value3) FROM s3 GROUP BY log2(1-value3);

-- select log2 with group by (result)
--Testcase 208:
SELECT count(value1), log2(1-value3) FROM s3 GROUP BY log2(1-value3);

-- select log2 with group by index (result)
--Testcase 209:
SELECT value1, log2(1-value3) FROM s3 GROUP BY 2,1;

-- select log2 with group by index (result)
--Testcase 210:
SELECT value1, log2(1-value3) FROM s3 GROUP BY 1,2;

-- select log2 with group by having (explain)
--Testcase 211:
EXPLAIN VERBOSE
SELECT count(value1), log2(1-value3) FROM s3 GROUP BY log2(1-value3) HAVING avg(value1) > 0;

-- select log2 with group by having (result)
--Testcase 212:
SELECT count(value1), log2(1-value3) FROM s3 GROUP BY log2(1-value3) HAVING avg(value1) > 0;

-- select log2 with group by index having (result)
--Testcase 213:
SELECT value1, log2(1-value1) FROM s3 GROUP BY 1,2 HAVING value1 < 1;

-- select log2 and as (return NULL with negative number)
--Testcase 214:
SELECT value1, value3 + 1, log2(value3 + 1) as log21 FROM s3;

-- select pi (builtin function, explain)
--Testcase 215:
EXPLAIN VERBOSE
SELECT pi() FROM s3 WHERE value2 != 200 LIMIT 1;

-- select pi (builtin function, result)
--Testcase 216:
SELECT pi() FROM s3 WHERE value2 != 200 LIMIT 1;

-- where pi (builtin function)
--Testcase 217:
EXPLAIN VERBOSE
SELECT id FROM s3 WHERE pi() > id LIMIT 1;
--Testcase 218:
SELECT id FROM s3 WHERE pi() > id LIMIT 1;

-- select pi (stub function, explain)
--Testcase 219:
EXPLAIN VERBOSE
SELECT mysql_pi() FROM s3 WHERE value2 != 200 LIMIT 1;

-- select pi (stub function, result)
--Testcase 220:
SELECT mysql_pi() FROM s3 WHERE value2 != 200 LIMIT 1;

-- where pi (stub function)
--Testcase 221:
EXPLAIN VERBOSE
SELECT value1 FROM s3 WHERE mysql_pi() > value1 LIMIT 1;
--Testcase 222:
SELECT value1 FROM s3 WHERE mysql_pi() > value1 LIMIT 1;

-- where pi (stub function) order by
--Testcase 223:
EXPLAIN VERBOSE
SELECT value1 FROM s3 WHERE mysql_pi() > value1 ORDER BY 1;
--Testcase 224:
SELECT value1 FROM s3 WHERE mysql_pi() > value1 ORDER BY 1;

-- slect stub function, order by pi (stub function)
--Testcase 225:
EXPLAIN VERBOSE
SELECT mysql_pi(), log2(value1) FROM s3 ORDER BY 1,2;
--Testcase 226:
SELECT mysql_pi(), log2(value1) FROM s3 ORDER BY 1,2;

-- select pow (builtin function, explain)
--Testcase 227:
EXPLAIN VERBOSE
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3;

-- select pow (builtin function, result)
--Testcase 228:
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3;

-- select pow (builtin function, not pushdown constraints, explain)
--Testcase 229:
EXPLAIN VERBOSE
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3 WHERE to_hex(value2) != '64';

-- select pow (builtin function, not pushdown constraints, result)
--Testcase 230:
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3 WHERE to_hex(value2) != '64';

-- select pow (builtin function, pushdown constraints, explain)
--Testcase 231:
EXPLAIN VERBOSE
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3 WHERE value2 != 200;

-- select pow (builtin function, pushdown constraints, result)
--Testcase 232:
SELECT pow(value1, 2), pow(value2, 2), pow(value3, 2), pow(value4, 2) FROM s3 WHERE value2 != 200;

-- select pow as nest function with agg (pushdown, explain)
--Testcase 233:
EXPLAIN VERBOSE
SELECT sum(value3),pow(sum(value3), 2) FROM s3;

-- select pow as nest function with agg (pushdown, result)
--Testcase 234:
SELECT sum(value3),pow(sum(value3), 2) FROM s3;

-- select pow as nest with log2 (pushdown, explain)
--Testcase 235:
EXPLAIN VERBOSE
SELECT value1, pow(log2(value1), 2),pow(log2(1/value1), 2) FROM s3;

-- select pow as nest with log2 (pushdown, result)
--Testcase 236:
SELECT value1, pow(log2(value1), 2),pow(log2(1/value1), 2) FROM s3;

-- select pow with non pushdown func and explicit constant (explain)
--Testcase 237:
EXPLAIN VERBOSE
SELECT pow(value3, 2), pi(), 4.1 FROM s3;

-- select pow with non pushdown func and explicit constant (result)
--Testcase 238:
SELECT pow(value3, 2), pi(), 4.1 FROM s3;

-- select pow with order by (explain)
--Testcase 239:
EXPLAIN VERBOSE
SELECT value3, pow(1-value3, 2) FROM s3 ORDER BY pow(1-value3, 2);

-- select pow with order by (result)
--Testcase 240:
SELECT value3, pow(1-value3, 2) FROM s3 ORDER BY pow(1-value3, 2);

-- select pow with order by index (result)
--Testcase 241:
SELECT value3, pow(1-value3, 2) FROM s3 ORDER BY 2,1;

-- select pow with order by index (result)
--Testcase 242:
SELECT value3, pow(1-value3, 2) FROM s3 ORDER BY 1,2;

-- select pow and as
--Testcase 243:
SELECT pow(value3, 2) as pow1 FROM s3;

-- We only test rand with constant and column because it will be stable
-- select rand (stub function, rand with column, explain)
--Testcase 244:
EXPLAIN VERBOSE
SELECT id, rand(id), rand(3) FROM s3 WHERE value2 != 200;

-- select rand (stub function, rand with column, result)
--Testcase 245:
SELECT id, rand(id), rand(3) FROM s3 WHERE value2 != 200;

-- rand() in WHERE clause only EXPLAIN, execute will return different result
--Testcase 246:
EXPLAIN VERBOSE
SELECT id, rand(id), rand(3), rand() FROM s3 WHERE rand() > 0.5;

-- select rand (stub function, explain)
--Testcase 247:
EXPLAIN VERBOSE
SELECT value1, rand(value1), rand(value2), rand(value3), rand(value4) FROM s3;

-- select rand (stub function, result)
--Testcase 248:
SELECT value1, rand(value1), rand(value2), rand(value3), rand(value4) FROM s3;

-- select rand (stub function, not pushdown constraints, explain)
--Testcase 249:
EXPLAIN VERBOSE
SELECT rand(value1), rand(value2), rand(value3), rand(value4), rand(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select rand (stub function, not pushdown constraints, result)
--Testcase 250:
SELECT rand(value1), rand(value2), rand(value3), rand(value4), rand(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select rand (stub function, pushdown constraints, explain)
--Testcase 251:
EXPLAIN VERBOSE
SELECT rand(value1), rand(value2), rand(value3), rand(value4), rand(0.5) FROM s3 WHERE value2 != 200;

-- select rand (stub function, pushdown constraints, result)
--Testcase 252:
SELECT rand(value1), rand(value2), rand(value3), rand(value4), rand(0.5) FROM s3 WHERE value2 != 200;

-- select rand (stub function, rand in constraints, explain)
--Testcase 253:
EXPLAIN VERBOSE
SELECT value1, rand(value1), rand(value2), rand(value3), rand(value4) FROM s3 WHERE rand(value1) != 1;

-- select rand (stub function, rand in constraints, result)
--Testcase 254:
SELECT value1, rand(value1), rand(value2), rand(value3), rand(value4) FROM s3 WHERE rand(value1) != 1;

-- select rand (stub function, rand in constraints, explain)
--Testcase 255:
EXPLAIN VERBOSE
SELECT value1, rand(value1), rand(value2), rand(value3), rand(value4) FROM s3 WHERE rand(0.5) > value1 - 1;

-- select rand (stub function, rand in constraints, result)
--Testcase 256:
SELECT value1, rand(value1), rand(value2), rand(value3), rand(value4) FROM s3 WHERE rand(0.5) > value1 - 1;

-- select rand as nest function with agg (pushdown, explain)
--Testcase 257:
EXPLAIN VERBOSE
SELECT sum(value3),rand(sum(value3)) FROM s3;

-- select rand as nest function with agg (pushdown, result)
--Testcase 258:
SELECT sum(value3),rand(sum(value3)) FROM s3;

-- select rand as nest with log2 (pushdown, explain)
--Testcase 259:
EXPLAIN VERBOSE
SELECT value1, rand(log2(value1)),rand(log2(1/value1)) FROM s3;

-- select rand as nest with log2 (pushdown, result)
--Testcase 260:
SELECT value1, rand(log2(value1)),rand(log2(1/value1)) FROM s3;

-- select rand with non pushdown func and explicit constant (explain)
--Testcase 261:
EXPLAIN VERBOSE
SELECT value1, rand(value3), pi(), 4.1 FROM s3;

-- select rand with non pushdown func and explicit constant (result)
--Testcase 262:
SELECT value1, rand(value3), pi(), 4.1 FROM s3;

-- select rand with order by (explain)
--Testcase 263:
EXPLAIN VERBOSE
SELECT value3, rand(1-value3) FROM s3 ORDER BY rand(1-value3);

-- select rand with order by (result)
--Testcase 264:
SELECT value3, rand(1-value3) FROM s3 ORDER BY rand(1-value3);

-- select rand with order by index (result)
--Testcase 265:
SELECT value3, rand(1-value3) FROM s3 ORDER BY 2,1;

-- select rand with order by index (result)
--Testcase 266:
SELECT value3, rand(1-value3) FROM s3 ORDER BY 1,2;

-- select rand with group by (explain)
--Testcase 267:
EXPLAIN VERBOSE
SELECT value1, rand(1-value3) FROM s3 GROUP BY value1, rand(1-value3);

-- select rand with group by (result)
--Testcase 268:
SELECT value1, rand(1-value3) FROM s3 GROUP BY value1, rand(1-value3);

-- select rand with group by index (result)
--Testcase 269:
SELECT value1, rand(1-value3) FROM s3 GROUP BY 2,1;

-- select rand with group by index (result)
--Testcase 270:
SELECT value1, rand(1-value3) FROM s3 GROUP BY 1,2;

-- select rand with group by having (explain)
--Testcase 271:
EXPLAIN VERBOSE
SELECT value1, rand(1-value3) FROM s3 GROUP BY value1, rand(1-value3) HAVING avg(value1) > 0;

-- select rand with group by having (result)
--Testcase 272:
SELECT value1, rand(1-value3) FROM s3 GROUP BY value1, rand(1-value3) HAVING avg(value1) > 0;

-- select rand with group by index having (result)
--Testcase 273:
SELECT value1, rand(1-value1) FROM s3 GROUP BY 1,2 HAVING value1 < 1;

-- select rand and as
--Testcase 274:
SELECT value1, rand(value3) as rand1 FROM s3;

-- select truncate (stub function, explain)
--Testcase 275:
EXPLAIN VERBOSE
SELECT truncate(value1, 2), truncate(value2, 2), truncate(value3, 2), truncate(value4, 2), truncate(5, 2) FROM s3;

-- select truncate (stub function, result)
--Testcase 276:
SELECT truncate(value1, 2), truncate(value2, 2), truncate(value3, 2), truncate(value4, 2), truncate(5, 2) FROM s3;

-- select truncate (stub function, not pushdown constraints, explain)
--Testcase 277:
EXPLAIN VERBOSE
SELECT truncate(value1, 2), truncate(value2, 2), truncate(value3, 2), truncate(value4, 2), truncate(5, 2) FROM s3 WHERE to_hex(value2) = '64';

-- select truncate (stub function, not pushdown constraints, result)
--Testcase 278:
SELECT truncate(value1, 2), truncate(value2, 2), truncate(value3, 2), truncate(value4, 2), truncate(5, 2) FROM s3 WHERE to_hex(value2) = '64';

-- select truncate (stub function, pushdown constraints, explain)
--Testcase 279:
EXPLAIN VERBOSE
SELECT truncate(value1, 2), truncate(value2, 2), truncate(value3, 2), truncate(value4, 2), truncate(5, 2) FROM s3 WHERE value2 != 200;

-- select truncate (stub function, pushdown constraints, result)
--Testcase 280:
SELECT truncate(value1, 2), truncate(value2, 2), truncate(value3, 2), truncate(value4, 2), truncate(5, 2) FROM s3 WHERE value2 != 200;

-- select truncate (stub function, truncate in constraints, explain)
--Testcase 281:
EXPLAIN VERBOSE
SELECT truncate(value1, 2), truncate(value2, 2), truncate(value3, 2), truncate(value4, 2), truncate(5, 2) FROM s3 WHERE truncate(value1, 2) != 1;

-- select truncate (stub function, truncate in constraints, result)
--Testcase 282:
SELECT truncate(value1, 2), truncate(value2, 2), truncate(value3, 2), truncate(value4, 2), truncate(5, 2) FROM s3 WHERE truncate(value1, 2) != 1;

-- select truncate (stub function, truncate in constraints, explain)
--Testcase 283:
EXPLAIN VERBOSE
SELECT truncate(value1, 2), truncate(value2, 2), truncate(value3, 2), truncate(value4, 2), truncate(5, 2) FROM s3 WHERE truncate(5, 2) > value1;

-- select truncate (stub function, truncate in constraints, result)
--Testcase 284:
SELECT truncate(value1, 2), truncate(value2, 2), truncate(value3, 2), truncate(value4, 2), truncate(5, 2) FROM s3 WHERE truncate(5, 2) > value1;

-- select truncate as nest function with agg (pushdown, explain)
--Testcase 285:
EXPLAIN VERBOSE
SELECT sum(value3),truncate(sum(value3), 2) FROM s3;

-- select truncate as nest function with agg (pushdown, result)
--Testcase 286:
SELECT sum(value3),truncate(sum(value3), 2) FROM s3;

-- select truncate as nest with log2 (pushdown, explain)
--Testcase 287:
EXPLAIN VERBOSE
SELECT truncate(log2(value1), 2),truncate(log2(1/value1), 2) FROM s3;

-- select truncate as nest with log2 (pushdown, result)
--Testcase 288:
SELECT truncate(log2(value1), 2),truncate(log2(1/value1), 2) FROM s3;

-- select truncate with non pushdown func and explicit constant (explain)
--Testcase 289:
EXPLAIN VERBOSE
SELECT truncate(value3, 2), pi(), 4.1 FROM s3;

-- select truncate with non pushdown func and explicit constant (result)
--Testcase 290:
SELECT truncate(value3, 2), pi(), 4.1 FROM s3;

-- select truncate with order by (explain)
--Testcase 291:
EXPLAIN VERBOSE
SELECT value3, truncate(1-value3, 2) FROM s3 ORDER BY truncate(1-value3, 2);

-- select truncate with order by (result)
--Testcase 292:
SELECT value3, truncate(1-value3, 2) FROM s3 ORDER BY truncate(1-value3, 2);

-- select truncate with order by index (result)
--Testcase 293:
SELECT value3, truncate(1-value3, 2) FROM s3 ORDER BY 2,1;

-- select truncate with order by index (result)
--Testcase 294:
SELECT value3, truncate(1-value3, 2) FROM s3 ORDER BY 1,2;

-- select truncate with group by (explain)
--Testcase 295:
EXPLAIN VERBOSE
SELECT count(value1), truncate(1-value3, 2) FROM s3 GROUP BY truncate(1-value3, 2);

-- select truncate with group by (result)
--Testcase 296:
SELECT count(value1), truncate(1-value3, 2) FROM s3 GROUP BY truncate(1-value3, 2);

-- select truncate with group by index (result)
--Testcase 297:
SELECT value3, truncate(1-value3, 2) FROM s3 GROUP BY 2,1;

-- select truncate with group by index (result)
--Testcase 298:
SELECT value3, truncate(1-value3, 2) FROM s3 GROUP BY 1,2;

-- select truncate with group by having (explain)
--Testcase 299:
EXPLAIN VERBOSE
SELECT count(value1), truncate(1-value3, 2) FROM s3 GROUP BY truncate(1-value3, 2) HAVING avg(value1) > 0;

-- select truncate with group by having (result)
--Testcase 300:
SELECT count(value1), truncate(1-value3, 2) FROM s3 GROUP BY truncate(1-value3, 2) HAVING avg(value1) > 0;

-- select truncate with group by index having (result)
--Testcase 301:
SELECT value3, truncate(1-value3, 2) FROM s3 GROUP BY 2,1 HAVING truncate(1-value3, 2) > 0;

-- select truncate with group by index having (result)
--Testcase 302:
SELECT value3, truncate(1-value3, 2) FROM s3 GROUP BY 1,2 HAVING value3 > 1;

-- select truncate and as
--Testcase 303:
SELECT truncate(value3, 2) as truncate1 FROM s3;

-- select round (builtin function, explain)
--Testcase 304:
EXPLAIN VERBOSE
SELECT round(value1), round(value2), round(value3), round(value4), round(0.5) FROM s3;

-- select round (builtin function, result)
--Testcase 305:
SELECT round(value1), round(value2), round(value3), round(value4), round(0.5) FROM s3;

-- select round (builtin function, not pushdown constraints, explain)
--Testcase 306:
EXPLAIN VERBOSE
SELECT round(value1), round(value2), round(value3), round(value4), round(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select round (builtin function, not pushdown constraints, result)
--Testcase 307:
SELECT round(value1), round(value2), round(value3), round(value4), round(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select round (builtin function, pushdown constraints, explain)
--Testcase 308:
EXPLAIN VERBOSE
SELECT round(value1), round(value2), round(value3), round(value4), round(0.5) FROM s3 WHERE value2 != 200;

-- select round (builtin function, pushdown constraints, result)
--Testcase 309:
SELECT round(value1), round(value2), round(value3), round(value4), round(0.5) FROM s3 WHERE value2 != 200;

-- select round (builtin function, round in constraints, explain)
--Testcase 310:
EXPLAIN VERBOSE
SELECT round(value1), round(value2), round(value3), round(value4), round(0.5) FROM s3 WHERE round(value1) != 1;

-- select round (builtin function, round in constraints, result)
--Testcase 311:
SELECT round(value1), round(value2), round(value3), round(value4), round(0.5) FROM s3 WHERE round(value1) != 1;

-- select round (builtin function, round in constraints, explain)
--Testcase 312:
EXPLAIN VERBOSE
SELECT round(value1), round(value2), round(value3), round(value4), round(0.5) FROM s3 WHERE round(0.5) > value1;

-- select round (builtin function, round in constraints, result)
--Testcase 313:
SELECT round(value1), round(value2), round(value3), round(value4), round(0.5) FROM s3 WHERE round(0.5) > value1;

-- select round as nest function with agg (pushdown, explain)
--Testcase 314:
EXPLAIN VERBOSE
SELECT sum(value3),round(sum(value3)) FROM s3;

-- select round as nest function with agg (pushdown, result)
--Testcase 315:
SELECT sum(value3),round(sum(value3)) FROM s3;

-- select round as nest with log2 (pushdown, explain)
--Testcase 316:
EXPLAIN VERBOSE
SELECT round(log2(value1)),round(log2(1/value1)) FROM s3;

-- select round as nest with log2 (pushdown, result)
--Testcase 317:
SELECT round(log2(value1)),round(log2(1/value1)) FROM s3;

-- select round with non pushdown func and explicit constant (explain)
--Testcase 318:
EXPLAIN VERBOSE
SELECT round(value3), pi(), 4.1 FROM s3;

-- select round with non pushdown func and explicit constant (result)
--Testcase 319:
SELECT round(value3), pi(), 4.1 FROM s3;

-- select round with order by (explain)
--Testcase 320:
EXPLAIN VERBOSE
SELECT value1, round(1-value3) FROM s3 ORDER BY round(1-value3);

-- select round with order by (result)
--Testcase 321:
SELECT value1, round(1-value3) FROM s3 ORDER BY round(1-value3);

-- select round with order by index (result)
--Testcase 322:
SELECT value1, round(1-value3) FROM s3 ORDER BY 2,1;

-- select round with order by index (result)
--Testcase 323:
SELECT value1, round(1-value3) FROM s3 ORDER BY 1,2;

-- select round with group by (explain)
--Testcase 324:
EXPLAIN VERBOSE
SELECT count(value1), round(1-value3) FROM s3 GROUP BY round(1-value3);

-- select round with group by (result)
--Testcase 325:
SELECT count(value1), round(1-value3) FROM s3 GROUP BY round(1-value3);

-- select round with group by index (result)
--Testcase 326:
SELECT value1, round(1-value3) FROM s3 GROUP BY 2,1;

-- select round with group by index (result)
--Testcase 327:
SELECT value1, round(1-value3) FROM s3 GROUP BY 1,2;

-- select round with group by having (explain)
--Testcase 328:
EXPLAIN VERBOSE
SELECT count(value1), round(1-value3) FROM s3 GROUP BY round(1-value3) HAVING round(avg(value1)) > 0;

-- select round with group by having (result)
--Testcase 329:
SELECT count(value1), round(1-value3) FROM s3 GROUP BY round(1-value3) HAVING round(avg(value1)) > 0;

-- select round with group by index having (result)
--Testcase 330:
SELECT value1, round(1-value3) FROM s3 GROUP BY 2,1 HAVING round(1-value3) > 0;

-- select round with group by index having (result)
--Testcase 331:
SELECT value1, round(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- select round and as
--Testcase 332:
SELECT round(value3) as round1 FROM s3;

-- select acos (builtin function, explain)
--Testcase 333:
EXPLAIN VERBOSE
SELECT value1, acos(value3), acos(0.5) FROM s3;

-- select acos (builtin function, result)
--Testcase 334:
SELECT value1, acos(value3), acos(0.5) FROM s3;

-- select acos (builtin function, not pushdown constraints, explain)
--Testcase 335:
EXPLAIN VERBOSE
SELECT acos(value1), acos(value3), acos(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select acos (builtin function, not pushdown constraints, result)
--Testcase 336:
SELECT acos(value1), acos(value3), acos(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select acos (builtin function, pushdown constraints, explain)
--Testcase 337:
EXPLAIN VERBOSE
SELECT acos(value1), acos(value3), acos(0.5) FROM s3 WHERE value2 != 200;

-- select acos (builtin function, pushdown constraints, result)
--Testcase 338:
SELECT acos(value1), acos(value3), acos(0.5) FROM s3 WHERE value2 != 200;

-- select acos (builtin function, acos in constraints, explain)
--Testcase 339:
EXPLAIN VERBOSE
SELECT acos(value1), acos(value3), acos(0.5) FROM s3 WHERE acos(value1) != 1;

-- select acos (builtin function, acos in constraints, result)
--Testcase 340:
SELECT acos(value1), acos(value3), acos(0.5) FROM s3 WHERE acos(value1) != 1;

-- select acos (builtin function, acos in constraints, explain)
--Testcase 341:
EXPLAIN VERBOSE
SELECT acos(value1), acos(value3), acos(0.5) FROM s3 WHERE acos(0.5) > value1;

-- select acos (builtin function, acos in constraints, result)
--Testcase 342:
SELECT acos(value1), acos(value3), acos(0.5) FROM s3 WHERE acos(0.5) > value1;

-- select acos as nest function with agg (pushdown, explain)
--Testcase 343:
EXPLAIN VERBOSE
SELECT sum(value3),acos(sum(value1)) FROM s3 WHERE value2 != 200;

-- select acos as nest function with agg (pushdown, result)
--Testcase 344:
SELECT sum(value3),acos(sum(value1)) FROM s3 WHERE value2 != 200;

-- select acos as nest with log2 (pushdown, explain)
--Testcase 345:
EXPLAIN VERBOSE
SELECT value1, acos(log2(value1)),acos(log2(1/value1)) FROM s3;

-- select acos as nest with log2 (pushdown, result)
--Testcase 346:
SELECT value1, acos(log2(value1)),acos(log2(1/value1)) FROM s3;

-- select acos with non pushdown func and explicit constant (explain)
--Testcase 347:
EXPLAIN VERBOSE
SELECT acos(value3), pi(), 4.1 FROM s3;

-- select acos with non pushdown func and explicit constant (result)
--Testcase 348:
SELECT acos(value3), pi(), 4.1 FROM s3;

-- select acos with order by (explain)
--Testcase 349:
EXPLAIN VERBOSE
SELECT value1, acos(1-value1) FROM s3 ORDER BY acos(1-value1);

-- select acos with order by (result)
--Testcase 350:
SELECT value1, acos(1-value1) FROM s3 ORDER BY acos(1-value1);

-- select acos with order by index (result)
--Testcase 351:
SELECT value1, acos(1-value1) FROM s3 ORDER BY 2,1;

-- select acos with order by index (result)
--Testcase 352:
SELECT value1, acos(1-value1) FROM s3 ORDER BY 1,2;

-- select acos with group by (explain)
--Testcase 353:
EXPLAIN VERBOSE
SELECT count(value1), acos(1-value1) FROM s3 GROUP BY acos(1-value1);

-- select acos with group by (result)
--Testcase 354:
SELECT count(value1), acos(1-value1) FROM s3 GROUP BY acos(1-value1);

-- select acos with group by index (result)
--Testcase 355:
SELECT value1, acos(1-value1) FROM s3 GROUP BY 2,1;

-- select acos with group by index (result)
--Testcase 356:
SELECT value1, acos(1-value1) FROM s3 GROUP BY 1,2;

-- select acos with group by having (explain)
--Testcase 357:
EXPLAIN VERBOSE
SELECT count(value1), acos(1-value1) FROM s3 GROUP BY acos(1-value1) HAVING avg(value1) > 0;

-- select acos with group by having (result)
--Testcase 358:
SELECT count(value1), acos(1-value1) FROM s3 GROUP BY acos(1-value1) HAVING avg(value1) > 0;

-- select acos with group by index having (result)
--Testcase 359:
SELECT value1, acos(1-value1) FROM s3 GROUP BY 2,1 HAVING acos(1-value1) > 0;

-- select acos with group by index having (result)
--Testcase 360:
SELECT value1, acos(1-value1) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- select acos and as
--Testcase 361:
SELECT acos(value3) as acos1 FROM s3;

-- select asin (builtin function, explain)
--Testcase 362:
EXPLAIN VERBOSE
SELECT asin(value1), asin(value3), asin(0.5) FROM s3;

-- select asin (builtin function, result)
--Testcase 363:
SELECT asin(value1), asin(value3), asin(0.5) FROM s3;

-- select asin (builtin function, not pushdown constraints, explain)
--Testcase 364:
EXPLAIN VERBOSE
SELECT asin(value1), asin(value3), asin(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select asin (builtin function, not pushdown constraints, result)
--Testcase 365:
SELECT asin(value1), asin(value3), asin(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select asin (builtin function, pushdown constraints, explain)
--Testcase 366:
EXPLAIN VERBOSE
SELECT asin(value1), asin(value3), asin(0.5) FROM s3 WHERE value2 != 200;

-- select asin (builtin function, pushdown constraints, result)
--Testcase 367:
SELECT asin(value1), asin(value3), asin(0.5) FROM s3 WHERE value2 != 200;

-- select asin (builtin function, asin in constraints, explain)
--Testcase 368:
EXPLAIN VERBOSE
SELECT asin(value1), asin(value3), asin(0.5) FROM s3 WHERE asin(value1) != 1;

-- select asin (builtin function, asin in constraints, result)
--Testcase 369:
SELECT asin(value1), asin(value3), asin(0.5) FROM s3 WHERE asin(value1) != 1;

-- select asin (builtin function, asin in constraints, explain)
--Testcase 370:
EXPLAIN VERBOSE
SELECT asin(value1), asin(value3), asin(0.5) FROM s3 WHERE asin(0.5) > value1;

-- select asin (builtin function, asin in constraints, result)
--Testcase 371:
SELECT asin(value1), asin(value3), asin(0.5) FROM s3 WHERE asin(0.5) > value1;

-- select asin as nest function with agg (pushdown, explain)
--Testcase 372:
EXPLAIN VERBOSE
SELECT sum(value3),asin(sum(value1)) FROM s3 WHERE value2 != 200;

-- select asin as nest function with agg (pushdown, result)
--Testcase 373:
SELECT sum(value3),asin(sum(value1)) FROM s3 WHERE value2 != 200;

-- select asin as nest with log2 (pushdown, explain)
--Testcase 374:
EXPLAIN VERBOSE
SELECT value1, asin(log2(value1)),asin(log2(1/value1)) FROM s3;

-- select asin as nest with log2 (pushdown, result)
--Testcase 375:
SELECT value1, asin(log2(value1)),asin(log2(1/value1)) FROM s3;

-- select asin with non pushdown func and explicit constant (explain)
--Testcase 376:
EXPLAIN VERBOSE
SELECT value1, asin(value3), pi(), 4.1 FROM s3;

-- select asin with non pushdown func and explicit constant (result)
--Testcase 377:
SELECT value1, asin(value3), pi(), 4.1 FROM s3;

-- select asin with order by (explain)
--Testcase 378:
EXPLAIN VERBOSE
SELECT value1, asin(1-value1) FROM s3 ORDER BY asin(1-value1);

-- select asin with order by (result)
--Testcase 379:
SELECT value1, asin(1-value1) FROM s3 ORDER BY asin(1-value1);

-- select asin with order by index (result)
--Testcase 380:
SELECT value1, asin(1-value1) FROM s3 ORDER BY 2,1;

-- select asin with order by index (result)
--Testcase 381:
SELECT value1, asin(1-value1) FROM s3 ORDER BY 1,2;

-- select asin with group by (explain)
--Testcase 382:
EXPLAIN VERBOSE
SELECT value1, asin(1-value1) FROM s3 GROUP BY value1, asin(1-value1);

-- select asin with group by (result)
--Testcase 383:
SELECT value1, asin(1-value1) FROM s3 GROUP BY value1, asin(1-value1);

-- select asin with group by index (result)
--Testcase 384:
SELECT value1, asin(1-value1) FROM s3 GROUP BY 2,1;

-- select asin with group by index (result)
--Testcase 385:
SELECT value1, asin(1-value1) FROM s3 GROUP BY 1,2;

-- select asin with group by having (explain)
--Testcase 386:
EXPLAIN VERBOSE
SELECT value1, asin(1-value1) FROM s3 GROUP BY value1, asin(1-value1) HAVING avg(value1) > 0;

-- select asin with group by having (result)
--Testcase 387:
SELECT value1, asin(1-value1) FROM s3 GROUP BY value1, asin(1-value1) HAVING avg(value1) > 0;

-- select asin with group by index having (result)
--Testcase 388:
SELECT value1, asin(1-value1) FROM s3 GROUP BY 2,1 HAVING asin(1-value1) > 0;

-- select asin with group by index having (result)
--Testcase 389:
SELECT value1, asin(1-value1) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- select asin and as
--Testcase 390:
SELECT value1, asin(value3) as asin1 FROM s3;

-- select atan (builtin function, explain)
--Testcase 391:
EXPLAIN VERBOSE
SELECT atan(value1), atan(value2), atan(value3), atan(value4), atan(0.5) FROM s3;

-- select atan (builtin function, result)
--Testcase 392:
SELECT atan(value1), atan(value2), atan(value3), atan(value4), atan(0.5) FROM s3;

-- select atan (builtin function, not pushdown constraints, explain)
--Testcase 393:
EXPLAIN VERBOSE
SELECT atan(value1), atan(value2), atan(value3), atan(value4), atan(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select atan (builtin function, not pushdown constraints, result)
--Testcase 394:
SELECT atan(value1), atan(value2), atan(value3), atan(value4), atan(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select atan (builtin function, pushdown constraints, explain)
--Testcase 395:
EXPLAIN VERBOSE
SELECT atan(value1), atan(value2), atan(value3), atan(value4), atan(0.5) FROM s3 WHERE value2 != 200;

-- select atan (builtin function, pushdown constraints, result)
--Testcase 396:
SELECT atan(value1), atan(value2), atan(value3), atan(value4), atan(0.5) FROM s3 WHERE value2 != 200;

-- select atan (builtin function, atan in constraints, explain)
--Testcase 397:
EXPLAIN VERBOSE
SELECT atan(value1), atan(value2), atan(value3), atan(value4), atan(0.5) FROM s3 WHERE atan(value1) != 1;

-- select atan (builtin function, atan in constraints, result)
--Testcase 398:
SELECT atan(value1), atan(value2), atan(value3), atan(value4), atan(0.5) FROM s3 WHERE atan(value1) != 1;

-- select atan (builtin function, atan in constraints, explain)
--Testcase 399:
EXPLAIN VERBOSE
SELECT atan(value1), atan(value2), atan(value3), atan(value4), atan(0.5) FROM s3 WHERE atan(0.5) > value1;

-- select atan (builtin function, atan in constraints, result)
--Testcase 400:
SELECT atan(value1), atan(value2), atan(value3), atan(value4), atan(0.5) FROM s3 WHERE atan(0.5) > value1;

-- select atan as nest function with agg (pushdown, explain)
--Testcase 401:
EXPLAIN VERBOSE
SELECT sum(value3),atan(sum(value3)) FROM s3;

-- select atan as nest function with agg (pushdown, result)
--Testcase 402:
SELECT sum(value3),atan(sum(value3)) FROM s3;

-- select atan as nest with log2 (pushdown, explain)
--Testcase 403:
EXPLAIN VERBOSE
SELECT atan(log2(value1)),atan(log2(1/value1)) FROM s3;

-- select atan as nest with log2 (pushdown, result)
--Testcase 404:
SELECT atan(log2(value1)),atan(log2(1/value1)) FROM s3;

-- select atan with non pushdown func and explicit constant (explain)
--Testcase 405:
EXPLAIN VERBOSE
SELECT atan(value3), pi(), 4.1 FROM s3;

-- select atan with non pushdown func and explicit constant (result)
--Testcase 406:
SELECT atan(value3), pi(), 4.1 FROM s3;

-- select atan with order by (explain)
--Testcase 407:
EXPLAIN VERBOSE
SELECT value1, atan(1-value3) FROM s3 ORDER BY atan(1-value3);

-- select atan with order by (result)
--Testcase 408:
SELECT value1, atan(1-value3) FROM s3 ORDER BY atan(1-value3);

-- select atan with order by index (result)
--Testcase 409:
SELECT value1, atan(1-value3) FROM s3 ORDER BY 2,1;

-- select atan with order by index (result)
--Testcase 410:
SELECT value1, atan(1-value3) FROM s3 ORDER BY 1,2;

-- select atan with group by (explain)
--Testcase 411:
EXPLAIN VERBOSE
SELECT count(value1), atan(1-value3) FROM s3 GROUP BY atan(1-value3);

-- select atan with group by (result)
--Testcase 412:
SELECT count(value1), atan(1-value3) FROM s3 GROUP BY atan(1-value3);

-- select atan with group by index (result)
--Testcase 413:
SELECT value1, atan(1-value3) FROM s3 GROUP BY 2,1;

-- select atan with group by index (result)
--Testcase 414:
SELECT value1, atan(1-value3) FROM s3 GROUP BY 1,2;

-- select atan with group by having (explain)
--Testcase 415:
EXPLAIN VERBOSE
SELECT count(value1), atan(1-value3) FROM s3 GROUP BY atan(1-value3) HAVING atan(avg(value1)) > 0;

-- select atan with group by having (result)
--Testcase 416:
SELECT count(value1), atan(1-value3) FROM s3 GROUP BY atan(1-value3) HAVING atan(avg(value1)) > 0;

-- select atan with group by index having (result)
--Testcase 417:
SELECT value1, atan(1-value3) FROM s3 GROUP BY 2,1 HAVING atan(1-value3) > 0;

-- select atan with group by index having (result)
--Testcase 418:
SELECT value1, atan(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- select atan and as
--Testcase 419:
SELECT atan(value3) as atan1 FROM s3;

-- select atan2 (builtin function, explain)
--Testcase 420:
EXPLAIN VERBOSE
SELECT atan2(value1, 2), atan2(value2, 2), atan2(value3, 2), atan2(value4, 2), atan2(5, 2) FROM s3;

-- select atan2 (builtin function, result)
--Testcase 421:
SELECT atan2(value1, 2), atan2(value2, 2), atan2(value3, 2), atan2(value4, 2), atan2(5, 2) FROM s3;

-- select atan2 (builtin function, not pushdown constraints, explain)
--Testcase 422:
EXPLAIN VERBOSE
SELECT atan2(value1, 2), atan2(value2, 2), atan2(value3, 2), atan2(value4, 2), atan2(5, 2) FROM s3 WHERE to_hex(value2) = '64';

-- select atan2 (builtin function, not pushdown constraints, result)
--Testcase 423:
SELECT atan2(value1, 2), atan2(value2, 2), atan2(value3, 2), atan2(value4, 2), atan2(5, 2) FROM s3 WHERE to_hex(value2) = '64';

-- select atan2 (builtin function, pushdown constraints, explain)
--Testcase 424:
EXPLAIN VERBOSE
SELECT atan2(value1, 2), atan2(value2, 2), atan2(value3, 2), atan2(value4, 2), atan2(5, 2) FROM s3 WHERE value2 != 200;

-- select atan2 (builtin function, pushdown constraints, result)
--Testcase 425:
SELECT atan2(value1, 2), atan2(value2, 2), atan2(value3, 2), atan2(value4, 2), atan2(5, 2) FROM s3 WHERE value2 != 200;

-- select atan2 (builtin function, atan2 in constraints, explain)
--Testcase 426:
EXPLAIN VERBOSE
SELECT atan2(value1, 2), atan2(value2, 2), atan2(value3, 2), atan2(value4, 2), atan2(5, 2) FROM s3 WHERE atan2(value1, 2) != 1;

-- select atan2 (builtin function, atan2 in constraints, result)
--Testcase 427:
SELECT atan2(value1, 2), atan2(value2, 2), atan2(value3, 2), atan2(value4, 2), atan2(5, 2) FROM s3 WHERE atan2(value1, 2) != 1;

-- select atan2 (builtin function, atan2 in constraints, explain)
--Testcase 428:
EXPLAIN VERBOSE
SELECT atan2(value1, 2), atan2(value2, 2), atan2(value3, 2), atan2(value4, 2), atan2(5, 2) FROM s3 WHERE atan2(5, 2) > value1;

-- select atan2 (builtin function, atan2 in constraints, result)
--Testcase 429:
SELECT atan2(value1, 2), atan2(value2, 2), atan2(value3, 2), atan2(value4, 2), atan2(5, 2) FROM s3 WHERE atan2(5, 2) > value1;

-- select atan2 as nest function with agg (pushdown, explain)
--Testcase 430:
EXPLAIN VERBOSE
SELECT sum(value3),atan2(sum(value3), 2) FROM s3;

-- select atan2 as nest function with agg (pushdown, result)
--Testcase 431:
SELECT sum(value3),atan2(sum(value3), 2) FROM s3;

-- select atan2 as nest with log2 (pushdown, explain)
--Testcase 432:
EXPLAIN VERBOSE
SELECT atan2(log2(value1), 2),atan2(log2(1/value1), 2) FROM s3;

-- select atan2 as nest with log2 (pushdown, result)
--Testcase 433:
SELECT atan2(log2(value1), 2),atan2(log2(1/value1), 2) FROM s3;

-- select atan2 with non pushdown func and atan2licit constant (explain)
--Testcase 434:
EXPLAIN VERBOSE
SELECT atan2(value3, 2), pi(), 4.1 FROM s3;

-- select atan2 with non pushdown func and atan2licit constant (result)
--Testcase 435:
SELECT atan2(value3, 2), pi(), 4.1 FROM s3;

-- select atan2 with order by (explain)
--Testcase 436:
EXPLAIN VERBOSE
SELECT value1, atan2(1-value3, 2) FROM s3 ORDER BY atan2(1-value3, 2);

-- select atan2 with order by (result)
--Testcase 437:
SELECT value1, atan2(1-value3, 2) FROM s3 ORDER BY atan2(1-value3, 2);

-- select atan2 with order by index (result)
--Testcase 438:
SELECT value1, atan2(1-value3, 2) FROM s3 ORDER BY 2,1;

-- select atan2 with order by index (result)
--Testcase 439:
SELECT value1, atan2(1-value3, 2) FROM s3 ORDER BY 1,2;

-- select atan2 with group by (explain)
--Testcase 440:
EXPLAIN VERBOSE
SELECT count(value1), atan2(1-value3, 2) FROM s3 GROUP BY atan2(1-value3, 2);

-- select atan2 with group by (result)
--Testcase 441:
SELECT count(value1), atan2(1-value3, 2) FROM s3 GROUP BY atan2(1-value3, 2);

-- select atan2 with group by index (result)
--Testcase 442:
SELECT value1, atan2(1-value3, 2) FROM s3 GROUP BY 2,1;

-- select atan2 with group by index (result)
--Testcase 443:
SELECT value1, atan2(1-value3, 2) FROM s3 GROUP BY 1,2;

-- select atan2 with group by having (explain)
--Testcase 444:
EXPLAIN VERBOSE
SELECT count(value1), atan2(1-value3, 2) FROM s3 GROUP BY atan2(1-value3, 2) HAVING atan2(avg(value1), 2) > 0;

-- select atan2 with group by having (result)
--Testcase 445:
SELECT count(value1), atan2(1-value3, 2) FROM s3 GROUP BY atan2(1-value3, 2) HAVING atan2(avg(value1), 2) > 0;

-- select atan2 with group by index having (result)
--Testcase 446:
SELECT value1, atan2(1-value3, 2) FROM s3 GROUP BY 2,1 HAVING atan2(1-value3, 2) > 0;

-- select atan2 with group by index having (result)
--Testcase 447:
SELECT value1, atan2(1-value3, 2) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- select atan2 and as
--Testcase 448:
SELECT atan2(value3, 2) as atan21 FROM s3;

-- select atan (stub function, explain)
--Testcase 449:
EXPLAIN VERBOSE
SELECT atan(value1, 2), atan(value2, 2), atan(value3, 2), atan(value4, 2), atan(5, 2) FROM s3;

-- select atan (stub function, result)
--Testcase 450:
SELECT atan(value1, 2), atan(value2, 2), atan(value3, 2), atan(value4, 2), atan(5, 2) FROM s3;

-- select atan (stub function, not pushdown constraints, explain)
--Testcase 451:
EXPLAIN VERBOSE
SELECT atan(value1, 2), atan(value2, 2), atan(value3, 2), atan(value4, 2), atan(5, 2) FROM s3 WHERE to_hex(value2) = '64';

-- select atan (stub function, not pushdown constraints, result)
--Testcase 452:
SELECT atan(value1, 2), atan(value2, 2), atan(value3, 2), atan(value4, 2), atan(5, 2) FROM s3 WHERE to_hex(value2) = '64';

-- select atan (stub function, pushdown constraints, explain)
--Testcase 453:
EXPLAIN VERBOSE
SELECT atan(value1, 2), atan(value2, 2), atan(value3, 2), atan(value4, 2), atan(5, 2) FROM s3 WHERE value2 != 200;

-- select atan (stub function, pushdown constraints, result)
--Testcase 454:
SELECT atan(value1, 2), atan(value2, 2), atan(value3, 2), atan(value4, 2), atan(5, 2) FROM s3 WHERE value2 != 200;

-- select atan (stub function, atan in constraints, explain)
--Testcase 455:
EXPLAIN VERBOSE
SELECT atan(value1, 2), atan(value2, 2), atan(value3, 2), atan(value4, 2), atan(5, 2) FROM s3 WHERE atan(value1, 2) != 1;

-- select atan (stub function, atan in constraints, result)
--Testcase 456:
SELECT atan(value1, 2), atan(value2, 2), atan(value3, 2), atan(value4, 2), atan(5, 2) FROM s3 WHERE atan(value1, 2) != 1;

-- select atan (stub function, atan in constraints, explain)
--Testcase 457:
EXPLAIN VERBOSE
SELECT atan(value1, 2), atan(value2, 2), atan(value3, 2), atan(value4, 2), atan(5, 2) FROM s3 WHERE atan(5, 2) > value1;

-- select atan (stub function, atan in constraints, result)
--Testcase 458:
SELECT atan(value1, 2), atan(value2, 2), atan(value3, 2), atan(value4, 2), atan(5, 2) FROM s3 WHERE atan(5, 2) > value1;

-- select atan as nest function with agg (pushdown, explain)
--Testcase 459:
EXPLAIN VERBOSE
SELECT sum(value3),atan(sum(value3), 2) FROM s3;

-- select atan as nest function with agg (pushdown, result)
--Testcase 460:
SELECT sum(value3),atan(sum(value3), 2) FROM s3;

-- select atan as nest with log2 (pushdown, explain)
--Testcase 461:
EXPLAIN VERBOSE
SELECT atan(log2(value1), 2),atan(log2(1/value1), 2) FROM s3;

-- select atan as nest with log2 (pushdown, result)
--Testcase 462:
SELECT atan(log2(value1), 2),atan(log2(1/value1), 2) FROM s3;

-- select atan with non pushdown func and atanlicit constant (explain)
--Testcase 463:
EXPLAIN VERBOSE
SELECT atan(value3, 2), pi(), 4.1 FROM s3;

-- select atan with non pushdown func and atanlicit constant (result)
--Testcase 464:
SELECT atan(value3, 2), pi(), 4.1 FROM s3;

-- select atan with order by (explain)
--Testcase 465:
EXPLAIN VERBOSE
SELECT value1, atan(1-value3, 2) FROM s3 ORDER BY atan(1-value3, 2);

-- select atan with order by (result)
--Testcase 466:
SELECT value1, atan(1-value3, 2) FROM s3 ORDER BY atan(1-value3, 2);

-- select atan with order by index (result)
--Testcase 467:
SELECT value1, atan(1-value3, 2) FROM s3 ORDER BY 2,1;

-- select atan with order by index (result)
--Testcase 468:
SELECT value1, atan(1-value3, 2) FROM s3 ORDER BY 1,2;

-- select atan with group by (explain)
--Testcase 469:
EXPLAIN VERBOSE
SELECT count(value1), atan(1-value3, 2) FROM s3 GROUP BY atan(1-value3, 2);

-- select atan with group by (result)
--Testcase 470:
SELECT count(value1), atan(1-value3, 2) FROM s3 GROUP BY atan(1-value3, 2);

-- select atan with group by index (result)
--Testcase 471:
SELECT value1, atan(1-value3, 2) FROM s3 GROUP BY 2,1;

-- select atan with group by index (result)
--Testcase 472:
SELECT value1, atan(1-value3, 2) FROM s3 GROUP BY 1,2;

-- select atan with group by having (explain)
--Testcase 473:
EXPLAIN VERBOSE
SELECT count(value1), atan(1-value3, 2) FROM s3 GROUP BY atan(1-value3, 2) HAVING avg(value1) > 0;

-- select atan with group by having (result)
--Testcase 474:
SELECT count(value1), atan(1-value3, 2) FROM s3 GROUP BY atan(1-value3, 2) HAVING avg(value1) > 0;

-- select atan with group by index having (result)
--Testcase 475:
SELECT value3, atan(1-value3, 2) FROM s3 GROUP BY 2,1 HAVING atan(1-value3, 2) > 0;

-- select atan with group by index having (result)
--Testcase 476:
SELECT value1, atan(1-value3, 2) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- select atan and as
--Testcase 477:
SELECT atan(value3, 2) as atan1 FROM s3;

-- select ceil (builtin function, explain)
--Testcase 478:
EXPLAIN VERBOSE
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4), ceil(0.5) FROM s3;

-- select ceil (builtin function, result)
--Testcase 479:
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4), ceil(0.5) FROM s3;

-- select ceil (builtin function, not pushdown constraints, explain)
--Testcase 480:
EXPLAIN VERBOSE
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4), ceil(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select ceil (builtin function, not pushdown constraints, result)
--Testcase 481:
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4), ceil(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select ceil (builtin function, pushdown constraints, explain)
--Testcase 482:
EXPLAIN VERBOSE
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4), ceil(0.5) FROM s3 WHERE value2 != 200;

-- select ceil (builtin function, pushdown constraints, result)
--Testcase 483:
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4), ceil(0.5) FROM s3 WHERE value2 != 200;

-- select ceil (builtin function, ceil in constraints, explain)
--Testcase 484:
EXPLAIN VERBOSE
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4), ceil(0.5) FROM s3 WHERE ceil(value1) != 1;

-- select ceil (builtin function, ceil in constraints, result)
--Testcase 485:
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4), ceil(0.5) FROM s3 WHERE ceil(value1) != 1;

-- select ceil (builtin function, ceil in constraints, explain)
--Testcase 486:
EXPLAIN VERBOSE
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4), ceil(0.5) FROM s3 WHERE ceil(0.5) > value1;

-- select ceil (builtin function, ceil in constraints, result)
--Testcase 487:
SELECT ceil(value1), ceil(value2), ceil(value3), ceil(value4), ceil(0.5) FROM s3 WHERE ceil(0.5) > value1;

-- select ceil as nest function with agg (pushdown, explain)
--Testcase 488:
EXPLAIN VERBOSE
SELECT sum(value3),ceil(sum(value3)) FROM s3;

-- select ceil as nest function with agg (pushdown, result)
--Testcase 489:
SELECT sum(value3),ceil(sum(value3)) FROM s3;

-- select ceil as nest with log2 (pushdown, explain)
--Testcase 490:
EXPLAIN VERBOSE
SELECT ceil(log2(value1)),ceil(log2(1/value1)) FROM s3;

-- select ceil as nest with log2 (pushdown, result)
--Testcase 491:
SELECT ceil(log2(value1)),ceil(log2(1/value1)) FROM s3;

-- select ceil with non pushdown func and explicit constant (explain)
--Testcase 492:
EXPLAIN VERBOSE
SELECT ceil(value3), pi(), 4.1 FROM s3;

-- select ceil with non pushdown func and explicit constant (result)
--Testcase 493:
SELECT ceil(value3), pi(), 4.1 FROM s3;

-- select ceil with order by (explain)
--Testcase 494:
EXPLAIN VERBOSE
SELECT value1, ceil(1-value3) FROM s3 ORDER BY ceil(1-value3);

-- select ceil with order by (result)
--Testcase 495:
SELECT value1, ceil(1-value3) FROM s3 ORDER BY ceil(1-value3);

-- select ceil with order by index (result)
--Testcase 496:
SELECT value1, ceil(1-value3) FROM s3 ORDER BY 2,1;

-- select ceil with order by index (result)
--Testcase 497:
SELECT value1, ceil(1-value3) FROM s3 ORDER BY 1,2;

-- select ceil with group by (explain)
--Testcase 498:
EXPLAIN VERBOSE
SELECT value1, ceil(1-value3) FROM s3 GROUP BY value1, ceil(1-value3);

-- select ceil with group by (result)
--Testcase 499:
SELECT value1, ceil(1-value3) FROM s3 GROUP BY value1, ceil(1-value3);

-- select ceil with group by index (result)
--Testcase 500:
SELECT value1, ceil(1-value3) FROM s3 GROUP BY 2,1;

-- select ceil with group by index (result)
--Testcase 501:
SELECT value1, ceil(1-value3) FROM s3 GROUP BY 1,2;

-- select ceil with group by having (explain)
--Testcase 502:
EXPLAIN VERBOSE
SELECT value1, ceil(1-value3) FROM s3 GROUP BY value1, ceil(1-value3) HAVING ceil(avg(value1)) > 0;

-- select ceil with group by having (result)
--Testcase 503:
SELECT value1, ceil(1-value3) FROM s3 GROUP BY value1, ceil(1-value3) HAVING ceil(avg(value1)) > 0;

-- select ceil with group by index having (result)
--Testcase 504:
SELECT value1, ceil(1-value3) FROM s3 GROUP BY 2,1 HAVING ceil(1-value3) > 0;

-- select ceil with group by index having (result)
--Testcase 505:
SELECT value1, ceil(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- select ceil and as
--Testcase 506:
SELECT ceil(value3) as ceil1 FROM s3;

-- select ceiling (builtin function, explain)
--Testcase 507:
EXPLAIN VERBOSE
SELECT ceiling(value1), ceiling(value2), ceiling(value3), ceiling(value4), ceiling(0.5) FROM s3;

-- select ceiling (builtin function, result)
--Testcase 508:
SELECT ceiling(value1), ceiling(value2), ceiling(value3), ceiling(value4), ceiling(0.5) FROM s3;

-- select ceiling (builtin function, not pushdown constraints, explain)
--Testcase 509:
EXPLAIN VERBOSE
SELECT ceiling(value1), ceiling(value2), ceiling(value3), ceiling(value4), ceiling(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select ceiling (builtin function, not pushdown constraints, result)
--Testcase 510:
SELECT ceiling(value1), ceiling(value2), ceiling(value3), ceiling(value4), ceiling(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select ceiling (builtin function, pushdown constraints, explain)
--Testcase 511:
EXPLAIN VERBOSE
SELECT ceiling(value1), ceiling(value2), ceiling(value3), ceiling(value4), ceiling(0.5) FROM s3 WHERE value2 != 200;

-- select ceiling (builtin function, pushdown constraints, result)
--Testcase 512:
SELECT ceiling(value1), ceiling(value2), ceiling(value3), ceiling(value4), ceiling(0.5) FROM s3 WHERE value2 != 200;

-- select ceiling (builtin function, ceiling in constraints, explain)
--Testcase 513:
EXPLAIN VERBOSE
SELECT ceiling(value1), ceiling(value2), ceiling(value3), ceiling(value4), ceiling(0.5) FROM s3 WHERE ceiling(value1) != 1;

-- select ceiling (builtin function, ceiling in constraints, result)
--Testcase 514:
SELECT ceiling(value1), ceiling(value2), ceiling(value3), ceiling(value4), ceiling(0.5) FROM s3 WHERE ceiling(value1) != 1;

-- select ceiling (builtin function, ceiling in constraints, explain)
--Testcase 515:
EXPLAIN VERBOSE
SELECT ceiling(value1), ceiling(value2), ceiling(value3), ceiling(value4), ceiling(0.5) FROM s3 WHERE ceiling(0.5) > value1;

-- select ceiling (builtin function, ceiling in constraints, result)
--Testcase 516:
SELECT ceiling(value1), ceiling(value2), ceiling(value3), ceiling(value4), ceiling(0.5) FROM s3 WHERE ceiling(0.5) > value1;

-- select ceiling as nest function with agg (pushdown, explain)
--Testcase 517:
EXPLAIN VERBOSE
SELECT sum(value3),ceiling(sum(value3)) FROM s3;

-- select ceiling as nest function with agg (pushdown, result)
--Testcase 518:
SELECT sum(value3),ceiling(sum(value3)) FROM s3;

-- select ceiling as nest with log2 (pushdown, explain)
--Testcase 519:
EXPLAIN VERBOSE
SELECT ceiling(log2(value1)),ceiling(log2(1/value1)) FROM s3;

-- select ceiling as nest with log2 (pushdown, result)
--Testcase 520:
SELECT ceiling(log2(value1)),ceiling(log2(1/value1)) FROM s3;

-- select ceiling with non pushdown func and explicit constant (explain)
--Testcase 521:
EXPLAIN VERBOSE
SELECT ceiling(value3), pi(), 4.1 FROM s3;

-- select ceiling with non pushdown func and explicit constant (result)
--Testcase 522:
SELECT ceiling(value3), pi(), 4.1 FROM s3;

-- select ceiling with order by (explain)
--Testcase 523:
EXPLAIN VERBOSE
SELECT value1, ceiling(1-value3) FROM s3 ORDER BY ceiling(1-value3);

-- select ceiling with order by (result)
--Testcase 524:
SELECT value1, ceiling(1-value3) FROM s3 ORDER BY ceiling(1-value3);

-- select ceiling with order by index (result)
--Testcase 525:
SELECT value1, ceiling(1-value3) FROM s3 ORDER BY 2,1;

-- select ceiling with order by index (result)
--Testcase 526:
SELECT value1, ceiling(1-value3) FROM s3 ORDER BY 1,2;

-- select ceiling with group by (explain)
--Testcase 527:
EXPLAIN VERBOSE
SELECT count(value1), ceiling(1-value3) FROM s3 GROUP BY ceiling(1-value3);

-- select ceiling with group by (result)
--Testcase 528:
SELECT count(value1), ceiling(1-value3) FROM s3 GROUP BY ceiling(1-value3);

-- select ceiling with group by index (result)
--Testcase 529:
SELECT value1, ceiling(1-value3) FROM s3 GROUP BY 2,1;

-- select ceiling with group by index (result)
--Testcase 530:
SELECT value1, ceiling(1-value3) FROM s3 GROUP BY 1,2;

-- select ceiling with group by having (explain)
--Testcase 531:
EXPLAIN VERBOSE
SELECT count(value1), ceiling(1-value3) FROM s3 GROUP BY ceiling(1-value3) HAVING ceiling(avg(value1)) > 0;

-- select ceiling with group by having (result)
--Testcase 532:
SELECT count(value1), ceiling(1-value3) FROM s3 GROUP BY ceiling(1-value3) HAVING ceiling(avg(value1)) > 0;

-- select ceiling with group by index having (result)
--Testcase 533:
SELECT value1, ceiling(1-value3) FROM s3 GROUP BY 2,1 HAVING ceiling(1-value3) > 0;

-- select ceiling with group by index having (result)
--Testcase 534:
SELECT value1, ceiling(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- select ceiling and as
--Testcase 535:
SELECT ceiling(value3) as ceiling1 FROM s3;

-- select cos (builtin function, explain)
--Testcase 536:
EXPLAIN VERBOSE
SELECT value1, cos(value2), cos(value3), cos(value4), cos(0.5) FROM s3;

-- select cos (builtin function, result)
--Testcase 537:
SELECT value1, cos(value2), cos(value3), cos(value4), cos(0.5) FROM s3;

-- select cos (builtin function, not pushdown constraints, explain)
--Testcase 538:
EXPLAIN VERBOSE
SELECT cos(value1), cos(value2), cos(value3), cos(value4), cos(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select cos (builtin function, not pushdown constraints, result)
--Testcase 539:
SELECT cos(value1), cos(value2), cos(value3), cos(value4), cos(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select cos (builtin function, pushdown constraints, explain)
--Testcase 540:
EXPLAIN VERBOSE
SELECT cos(value1), cos(value2), cos(value3), cos(value4), cos(0.5) FROM s3 WHERE value2 != 200;

-- select cos (builtin function, pushdown constraints, result)
--Testcase 541:
SELECT cos(value1), cos(value2), cos(value3), cos(value4), cos(0.5) FROM s3 WHERE value2 != 200;

-- select cos (builtin function, cos in constraints, explain)
--Testcase 542:
EXPLAIN VERBOSE
SELECT value1, cos(value2), cos(value3), cos(value4), cos(0.5) FROM s3 WHERE cos(value1) != 1;

-- select cos (builtin function, cos in constraints, result)
--Testcase 543:
SELECT value1, cos(value2), cos(value3), cos(value4), cos(0.5) FROM s3 WHERE cos(value1) != 1;

-- select cos (builtin function, cos in constraints, explain)
--Testcase 544:
EXPLAIN VERBOSE
SELECT cos(value1), cos(value2), cos(value3), cos(value4), cos(0.5) FROM s3 WHERE cos(0.5) > value1;

-- select cos (builtin function, cos in constraints, result)
--Testcase 545:
SELECT cos(value1), cos(value2), cos(value3), cos(value4), cos(0.5) FROM s3 WHERE cos(0.5) > value1;

-- select cos as nest function with agg (pushdown, explain)
--Testcase 546:
EXPLAIN VERBOSE
SELECT sum(value3),cos(sum(value3)) FROM s3;

-- select cos as nest function with agg (pushdown, result)
--Testcase 547:
SELECT sum(value3),cos(sum(value3)) FROM s3;

-- select cos as nest with log2 (pushdown, explain)
--Testcase 548:
EXPLAIN VERBOSE
SELECT value1, cos(log2(value1)),cos(log2(1/value1)) FROM s3;

-- select cos as nest with log2 (pushdown, result)
--Testcase 549:
SELECT value1, cos(log2(value1)),cos(log2(1/value1)) FROM s3;

-- select cos with non pushdown func and explicit constant (explain)
--Testcase 550:
EXPLAIN VERBOSE
SELECT cos(value3), pi(), 4.1 FROM s3;

-- select cos with non pushdown func and explicit constant (result)
--Testcase 551:
SELECT cos(value3), pi(), 4.1 FROM s3;

-- select cos with order by (explain)
--Testcase 552:
EXPLAIN VERBOSE
SELECT value1, cos(1-value3) FROM s3 ORDER BY cos(1-value3);

-- select cos with order by (result)
--Testcase 553:
SELECT value1, cos(1-value3) FROM s3 ORDER BY cos(1-value3);

-- select cos with order by index (result)
--Testcase 554:
SELECT value1, cos(1-value3) FROM s3 ORDER BY 2,1;

-- select cos with order by index (result)
--Testcase 555:
SELECT value1, cos(1-value3) FROM s3 ORDER BY 1,2;

-- select cos with group by (explain)
--Testcase 556:
EXPLAIN VERBOSE
SELECT value1, cos(1-value3) FROM s3 GROUP BY value1, cos(1-value3);

-- select cos with group by (result)
--Testcase 557:
SELECT value1, cos(1-value3) FROM s3 GROUP BY value1, cos(1-value3);

-- select cos with group by index (result)
--Testcase 558:
SELECT value1, cos(1-value3) FROM s3 GROUP BY 2,1;

-- select cos with group by index (result)
--Testcase 559:
SELECT value1, cos(1-value3) FROM s3 GROUP BY 1,2;

-- select cos with group by having (explain)
--Testcase 560:
EXPLAIN VERBOSE
SELECT value1, cos(1-value3) FROM s3 GROUP BY value1, cos(1-value3) HAVING cos(avg(value1)) > 0;

-- select cos with group by having (result)
--Testcase 561:
SELECT value1, cos(1-value3) FROM s3 GROUP BY value1, cos(1-value3) HAVING cos(avg(value1)) > 0;

-- select cos with group by index having (result)
--Testcase 562:
SELECT value1, cos(1-value3) FROM s3 GROUP BY 2,1 HAVING cos(1-value3) > 0;

-- select cos with group by index having (result)
--Testcase 563:
SELECT value1, cos(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- select cos and as
--Testcase 564:
SELECT cos(value3) as cos1 FROM s3;

-- select cot (builtin function, explain)
--Testcase 565:
EXPLAIN VERBOSE
SELECT value1, cot(value2), cot(value3), cot(value4), cot(0.5) FROM s3;

-- select cot (builtin function, result)
--Testcase 566:
SELECT value1, cot(value2), cot(value3), cot(value4), cot(0.5) FROM s3;

-- select cot (builtin function, not pushdown constraints, explain)
--Testcase 567:
EXPLAIN VERBOSE
SELECT cot(value1), cot(value2), cot(value3), cot(value4), cot(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select cot (builtin function, not pushdown constraints, result)
--Testcase 568:
SELECT cot(value1), cot(value2), cot(value3), cot(value4), cot(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select cot (builtin function, pushdown constraints, explain)
--Testcase 569:
EXPLAIN VERBOSE
SELECT cot(value1), cot(value2), cot(value3), cot(value4), cot(0.5) FROM s3 WHERE value2 != 200;

-- select cot (builtin function, pushdown constraints, result)
--Testcase 570:
SELECT cot(value1), cot(value2), cot(value3), cot(value4), cot(0.5) FROM s3 WHERE value2 != 200;

-- select cot (builtin function, cot in constraints, explain)
--Testcase 571:
EXPLAIN VERBOSE
SELECT value1, cot(value2), cot(value3), cot(value4), cot(0.5) FROM s3 WHERE cot(value1) != 1;

-- select cot (builtin function, cot in constraints, result)
--Testcase 572:
SELECT value1, cot(value2), cot(value3), cot(value4), cot(0.5) FROM s3 WHERE cot(value1) != 1;

-- select cot (builtin function, cot in constraints, explain)
--Testcase 573:
EXPLAIN VERBOSE
SELECT value1, cot(value2), cot(value3), cot(value4), cot(0.5) FROM s3 WHERE cot(0.5) > value1;

-- select cot (builtin function, cot in constraints, result)
--Testcase 574:
SELECT value1, cot(value2), cot(value3), cot(value4), cot(0.5) FROM s3 WHERE cot(0.5) > value1;

-- select cot as nest function with agg (pushdown, explain)
--Testcase 575:
EXPLAIN VERBOSE
SELECT sum(value3),cot(sum(value3)) FROM s3;

-- select cot as nest function with agg (pushdown, result)
--Testcase 576:
SELECT sum(value3),cot(sum(value3)) FROM s3;

-- select cot as nest with log2 (pushdown, explain)
--Testcase 577:
EXPLAIN VERBOSE
SELECT value1, cot(log2(value1)),cot(log2(1/value1)) FROM s3;

-- select cot as nest with log2 (pushdown, result)
--Testcase 578:
SELECT value1, cot(log2(value1)),cot(log2(1/value1)) FROM s3;

-- select cot with non pushdown func and explicit constant (explain)
--Testcase 579:
EXPLAIN VERBOSE
SELECT value1, cot(value3), pi(), 4.1 FROM s3;

-- select cot with non pushdown func and explicit constant (result)
--Testcase 580:
SELECT value1, cot(value3), pi(), 4.1 FROM s3;

-- select cot with order by (explain)
--Testcase 581:
EXPLAIN VERBOSE
SELECT value1, cot(1-value3) FROM s3 ORDER BY cot(1-value3);

-- select cot with order by (result)
--Testcase 582:
SELECT value1, cot(1-value3) FROM s3 ORDER BY cot(1-value3);

-- select cot with order by index (result)
--Testcase 583:
SELECT value1, cot(1-value3) FROM s3 ORDER BY 2,1;

-- select cot with order by index (result)
--Testcase 584:
SELECT value1, cot(1-value3) FROM s3 ORDER BY 1,2;

-- select cot with group by (explain)
--Testcase 585:
EXPLAIN VERBOSE
SELECT value1, cot(1-value3) FROM s3 GROUP BY value1, cot(1-value3);

-- select cot with group by (result)
--Testcase 586:
SELECT value1, cot(1-value3) FROM s3 GROUP BY value1, cot(1-value3);

-- select cot with group by index (result)
--Testcase 587:
SELECT value1, cot(1-value3) FROM s3 GROUP BY 2,1;

-- select cot with group by index (result)
--Testcase 588:
SELECT value1, cot(1-value3) FROM s3 GROUP BY 1,2;

-- select cot with group by having (explain)
--Testcase 589:
EXPLAIN VERBOSE
SELECT value1, cot(1-value3) FROM s3 GROUP BY value1, cot(1-value3) HAVING cot(avg(value1)) > 0;

-- select cot with group by having (result)
--Testcase 590:
SELECT value1, cot(1-value3) FROM s3 GROUP BY value1, cot(1-value3) HAVING cot(avg(value1)) > 0;

-- select cot with group by index having (result)
--Testcase 591:
SELECT value1, cot(1-value3) FROM s3 GROUP BY 2,1 HAVING cot(1-value3) > 0;

-- select cot with group by index having (result)
--Testcase 592:
SELECT value1, cot(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- select cot and as
--Testcase 593:
SELECT value1, cot(value3) as cot1 FROM s3;

-- select degrees (builtin function, explain)
--Testcase 594:
EXPLAIN VERBOSE
SELECT degrees(value1), degrees(value2), degrees(value3), degrees(value4), degrees(0.5) FROM s3;

-- select degrees (builtin function, result)
--Testcase 595:
SELECT degrees(value1), degrees(value2), degrees(value3), degrees(value4), degrees(0.5) FROM s3;

-- select degrees (builtin function, not pushdown constraints, explain)
--Testcase 596:
EXPLAIN VERBOSE
SELECT degrees(value1), degrees(value2), degrees(value3), degrees(value4), degrees(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select degrees (builtin function, not pushdown constraints, result)
--Testcase 597:
SELECT degrees(value1), degrees(value2), degrees(value3), degrees(value4), degrees(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select degrees (builtin function, pushdown constraints, explain)
--Testcase 598:
EXPLAIN VERBOSE
SELECT degrees(value1), degrees(value2), degrees(value3), degrees(value4), degrees(0.5) FROM s3 WHERE value2 != 200;

-- select degrees (builtin function, pushdown constraints, result)
--Testcase 599:
SELECT degrees(value1), degrees(value2), degrees(value3), degrees(value4), degrees(0.5) FROM s3 WHERE value2 != 200;

-- select degrees (builtin function, degrees in constraints, explain)
--Testcase 600:
EXPLAIN VERBOSE
SELECT degrees(value1), degrees(value2), degrees(value3), degrees(value4), degrees(0.5) FROM s3 WHERE degrees(value1) != 1;

-- select degrees (builtin function, degrees in constraints, result)
--Testcase 601:
SELECT degrees(value1), degrees(value2), degrees(value3), degrees(value4), degrees(0.5) FROM s3 WHERE degrees(value1) != 1;

-- select degrees (builtin function, degrees in constraints, explain)
--Testcase 602:
EXPLAIN VERBOSE
SELECT degrees(value1), degrees(value2), degrees(value3), degrees(value4), degrees(0.5) FROM s3 WHERE degrees(0.5) > value1;

-- select degrees (builtin function, degrees in constraints, result)
--Testcase 603:
SELECT degrees(value1), degrees(value2), degrees(value3), degrees(value4), degrees(0.5) FROM s3 WHERE degrees(0.5) > value1;

-- select degrees as nest function with agg (pushdown, explain)
--Testcase 604:
EXPLAIN VERBOSE
SELECT sum(value3),degrees(sum(value3)) FROM s3;

-- select degrees as nest function with agg (pushdown, result)
--Testcase 605:
SELECT sum(value3),degrees(sum(value3)) FROM s3;

-- select degrees as nest with log2 (pushdown, explain)
--Testcase 606:
EXPLAIN VERBOSE
SELECT value1, degrees(log2(value1)),degrees(log2(1/value1)) FROM s3;

-- select degrees as nest with log2 (pushdown, result)
--Testcase 607:
SELECT value1, degrees(log2(value1)),degrees(log2(1/value1)) FROM s3;

-- select degrees with non pushdown func and explicit constant (explain)
--Testcase 608:
EXPLAIN VERBOSE
SELECT degrees(value3), pi(), 4.1 FROM s3;

-- select degrees with non pushdown func and explicit constant (result)
--Testcase 609:
SELECT degrees(value3), pi(), 4.1 FROM s3;

-- select degrees with order by (explain)
--Testcase 610:
EXPLAIN VERBOSE
SELECT value1, degrees(1-value3) FROM s3 ORDER BY degrees(1-value3);

-- select degrees with order by (result)
--Testcase 611:
SELECT value1, degrees(1-value3) FROM s3 ORDER BY degrees(1-value3);

-- select degrees with order by index (result)
--Testcase 612:
SELECT value1, degrees(1-value3) FROM s3 ORDER BY 2,1;

-- select degrees with order by index (result)
--Testcase 613:
SELECT value1, degrees(1-value3) FROM s3 ORDER BY 1,2;

-- select degrees with group by (explain)
--Testcase 614:
EXPLAIN VERBOSE
SELECT count(value1), degrees(1-value3) FROM s3 GROUP BY degrees(1-value3);

-- select degrees with group by (result)
--Testcase 615:
SELECT count(value1), degrees(1-value3) FROM s3 GROUP BY degrees(1-value3);

-- select degrees with group by index (result)
--Testcase 616:
SELECT value1, degrees(1-value3) FROM s3 GROUP BY 2,1;

-- select degrees with group by index (result)
--Testcase 617:
SELECT value1, degrees(1-value3) FROM s3 GROUP BY 1,2;

-- select degrees with group by having (explain)
--Testcase 618:
EXPLAIN VERBOSE
SELECT count(value1), degrees(1-value3) FROM s3 GROUP BY degrees(1-value3) HAVING degrees(avg(value1)) > 0;

-- select degrees with group by having (result)
--Testcase 619:
SELECT count(value1), degrees(1-value3) FROM s3 GROUP BY degrees(1-value3) HAVING degrees(avg(value1)) > 0;

-- select degrees with group by index having (result)
--Testcase 620:
SELECT value1, degrees(1-value3) FROM s3 GROUP BY 2,1 HAVING degrees(1-value3) > 0;

-- select degrees with group by index having (result)
--Testcase 621:
SELECT value1, degrees(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- select degrees and as
--Testcase 622:
SELECT degrees(value3) as degrees1 FROM s3;

-- select div (builtin function, explain)
--Testcase 623:
EXPLAIN VERBOSE
SELECT div(value1::numeric, 2), div(value2::numeric, 2), div(value3::numeric, 2), div(value4::numeric, 2), div(5, 2) FROM s3;

-- select div (builtin function, result)
--Testcase 624:
SELECT div(value1::numeric, 2), div(value2::numeric, 2), div(value3::numeric, 2), div(value4::numeric, 2), div(5, 2) FROM s3;

-- select div (builtin function, not pushdown constraints, explain)
--Testcase 625:
EXPLAIN VERBOSE
SELECT div(value1::numeric, 2), div(value2::numeric, 2), div(value3::numeric, 2), div(value4::numeric, 2), div(5, 2) FROM s3 WHERE to_hex(value2) = '64';

-- select div (builtin function, not pushdown constraints, result)
--Testcase 626:
SELECT div(value1::numeric, 2), div(value2::numeric, 2), div(value3::numeric, 2), div(value4::numeric, 2), div(5, 2) FROM s3 WHERE to_hex(value2) = '64';

-- select div (builtin function, pushdown constraints, explain)
--Testcase 627:
EXPLAIN VERBOSE
SELECT div(value1::numeric, 2), div(value2::numeric, 2), div(value3::numeric, 2), div(value4::numeric, 2), div(5, 2) FROM s3 WHERE value2 != 200;

-- select div (builtin function, pushdown constraints, result)
--Testcase 628:
SELECT div(value1::numeric, 2), div(value2::numeric, 2), div(value3::numeric, 2), div(value4::numeric, 2), div(5, 2) FROM s3 WHERE value2 != 200;

-- select div (builtin function, div in constraints, explain)
--Testcase 629:
EXPLAIN VERBOSE
SELECT div(value1::numeric, 2), div(value2::numeric, 2), div(value3::numeric, 2), div(value4::numeric, 2), div(5, 2) FROM s3 WHERE div(value1::numeric, 2) != 1;

-- select div (builtin function, div in constraints, result)
--Testcase 630:
SELECT div(value1::numeric, 2), div(value2::numeric, 2), div(value3::numeric, 2), div(value4::numeric, 2), div(5, 2) FROM s3 WHERE div(value1::numeric, 2) != 1;

-- select div (builtin function, div in constraints, explain)
--Testcase 631:
EXPLAIN VERBOSE
SELECT div(value1::numeric, 2), div(value2::numeric, 2), div(value3::numeric, 2), div(value4::numeric, 2), div(5, 2) FROM s3 WHERE div(5, 2) > value1;

-- select div (builtin function, div in constraints, result)
--Testcase 632:
SELECT div(value1::numeric, 2), div(value2::numeric, 2), div(value3::numeric, 2), div(value4::numeric, 2), div(5, 2) FROM s3 WHERE div(5, 2) > value1;

-- select div as nest function with agg (pushdown, explain)
--Testcase 633:
EXPLAIN VERBOSE
SELECT sum(value3),div(sum(value3)::numeric, 2) FROM s3;

-- select div as nest function with agg (pushdown, result)
--Testcase 634:
SELECT sum(value3),div(sum(value3)::numeric, 2) FROM s3;

-- select div as nest with log2 (pushdown, explain)
--Testcase 635:
EXPLAIN VERBOSE
SELECT div(log2(value1)::numeric, 2),div(log2(1/value1)::numeric, 2) FROM s3;

-- select div as nest with log2 (pushdown, result)
--Testcase 636:
SELECT div(log2(value1)::numeric, 2),div(log2(1/value1)::numeric, 2) FROM s3;

-- select div with non pushdown func and explicit constant (explain)
--Testcase 637:
EXPLAIN VERBOSE
SELECT div(value3::numeric, 2), pi(), 4.1 FROM s3;

-- select div with non pushdown func and explicit constant (result)
--Testcase 638:
SELECT div(value3::numeric, 2), pi(), 4.1 FROM s3;

-- select div with order by (explain)
--Testcase 639:
EXPLAIN VERBOSE
SELECT value1, div((10-value1)::numeric, 2) FROM s3 ORDER BY value1, div((10-value1)::numeric, 2);

-- select div with order by (result)
--Testcase 640:
SELECT value1, div((10-value1)::numeric, 2) FROM s3 ORDER BY value1, div((10-value1)::numeric, 2);

-- select div with order by index (result)
--Testcase 641:
SELECT value1, div((10-value1)::numeric, 2) FROM s3 ORDER BY 2,1;

-- select div with order by index (result)
--Testcase 642:
SELECT value1, div((10-value1)::numeric, 2) FROM s3 ORDER BY 1,2;

-- select div with group by (explain)
--Testcase 643:
EXPLAIN VERBOSE
SELECT value1, div((10-value1)::numeric, 2) FROM s3 GROUP BY value1, div((10-value1)::numeric, 2);

-- select div with group by (result)
--Testcase 644:
SELECT value1, div((10-value1)::numeric, 2) FROM s3 GROUP BY value1, div((10-value1)::numeric, 2);

-- select div with group by index (result)
--Testcase 645:
SELECT value1, div((10-value1)::numeric, 2) FROM s3 GROUP BY 2,1;

-- select div with group by index (result)
--Testcase 646:
SELECT value1, div((10-value1)::numeric, 2) FROM s3 GROUP BY 1,2;

-- select div with group by having (explain)
--Testcase 647:
EXPLAIN VERBOSE
SELECT value1, div((10-value1)::numeric, 2) FROM s3 GROUP BY value1, div((10-value1)::numeric, 2) HAVING avg(value1) > 0;

-- select div with group by having (result)
--Testcase 648:
SELECT value1, div((10-value1)::numeric, 2) FROM s3 GROUP BY value1, div((10-value1)::numeric, 2) HAVING avg(value1) > 0;

-- select div with group by index having (result)
--Testcase 649:
SELECT value1, div((10-value1)::numeric, 2) FROM s3 GROUP BY 2,1 HAVING div((10-value1)::numeric, 2) > 0;

-- select div with group by index having (result)
--Testcase 650:
SELECT value1, div((10-value1)::numeric, 2) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- select div and as
--Testcase 651:
SELECT div(value3::numeric, 2) as div1 FROM s3;

-- select exp (builtin function, explain)
--Testcase 652:
EXPLAIN VERBOSE
SELECT exp(value1), exp(value2), exp(value3), exp(value4), exp(0.5) FROM s3;

-- select exp (builtin function, result)
--Testcase 653:
SELECT exp(value1), exp(value2), exp(value3), exp(value4), exp(0.5) FROM s3;

-- select exp (builtin function, not pushdown constraints, explain)
--Testcase 654:
EXPLAIN VERBOSE
SELECT exp(value1), exp(value2), exp(value3), exp(value4), exp(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select exp (builtin function, not pushdown constraints, result)
--Testcase 655:
SELECT exp(value1), exp(value2), exp(value3), exp(value4), exp(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select exp (builtin function, pushdown constraints, explain)
--Testcase 656:
EXPLAIN VERBOSE
SELECT exp(value1), exp(value2), exp(value3), exp(value4), exp(0.5) FROM s3 WHERE value2 != 200;

-- select exp (builtin function, pushdown constraints, result)
--Testcase 657:
SELECT exp(value1), exp(value2), exp(value3), exp(value4), exp(0.5) FROM s3 WHERE value2 != 200;

-- select exp (builtin function, exp in constraints, explain)
--Testcase 658:
EXPLAIN VERBOSE
SELECT exp(value1), exp(value2), exp(value3), exp(value4), exp(0.5) FROM s3 WHERE exp(value1) != 1;

-- select exp (builtin function, exp in constraints, result)
--Testcase 659:
SELECT exp(value1), exp(value2), exp(value3), exp(value4), exp(0.5) FROM s3 WHERE exp(value1) != 1;

-- select exp (builtin function, exp in constraints, explain)
--Testcase 660:
EXPLAIN VERBOSE
SELECT exp(value1), exp(value2), exp(value3), exp(value4), exp(0.5) FROM s3 WHERE exp(0.5) > value1;

-- select exp (builtin function, exp in constraints, result)
--Testcase 661:
SELECT exp(value1), exp(value2), exp(value3), exp(value4), exp(0.5) FROM s3 WHERE exp(0.5) > value1;

-- select exp as nest function with agg (pushdown, explain)
--Testcase 662:
EXPLAIN VERBOSE
SELECT sum(value3),exp(sum(value3)) FROM s3;

-- select exp as nest function with agg (pushdown, result)
--Testcase 663:
SELECT sum(value3),exp(sum(value3)) FROM s3;

-- select exp as nest with log2 (pushdown, explain)
--Testcase 664:
EXPLAIN VERBOSE
SELECT exp(log2(value1)),exp(log2(1/value1)) FROM s3;

-- select exp as nest with log2 (pushdown, result)
--Testcase 665:
SELECT exp(log2(value1)),exp(log2(1/value1)) FROM s3;

-- select exp with non pushdown func and explicit constant (explain)
--Testcase 666:
EXPLAIN VERBOSE
SELECT exp(value3), pi(), 4.1 FROM s3;

-- select exp with non pushdown func and explicit constant (result)
--Testcase 667:
SELECT exp(value3), pi(), 4.1 FROM s3;

-- select exp with order by (explain)
--Testcase 668:
EXPLAIN VERBOSE
SELECT value1, exp(1-value3) FROM s3 ORDER BY exp(1-value3);

-- select exp with order by (result)
--Testcase 669:
SELECT value1, exp(1-value3) FROM s3 ORDER BY exp(1-value3);

-- select exp with order by index (result)
--Testcase 670:
SELECT value1, exp(1-value3) FROM s3 ORDER BY 2,1;

-- select exp with order by index (result)
--Testcase 671:
SELECT value1, exp(1-value3) FROM s3 ORDER BY 1,2;

-- select exp with group by (explain)
--Testcase 672:
EXPLAIN VERBOSE
SELECT count(value1), exp(1-value3) FROM s3 GROUP BY exp(1-value3);

-- select exp with group by (result)
--Testcase 673:
SELECT count(value1), exp(1-value3) FROM s3 GROUP BY exp(1-value3);

-- select exp with group by index (result)
--Testcase 674:
SELECT value1, exp(1-value3) FROM s3 GROUP BY 2,1;

-- select exp with group by index (result)
--Testcase 675:
SELECT value1, exp(1-value3) FROM s3 GROUP BY 1,2;

-- select exp with group by having (explain)
--Testcase 676:
EXPLAIN VERBOSE
SELECT count(value1), exp(1-value3) FROM s3 GROUP BY exp(1-value3) HAVING exp(avg(value1)) > 0;

-- select exp with group by having (result)
--Testcase 677:
SELECT count(value1), exp(1-value3) FROM s3 GROUP BY exp(1-value3) HAVING exp(avg(value1)) > 0;

-- select exp with group by index having (result)
--Testcase 678:
SELECT value1, exp(1-value3) FROM s3 GROUP BY 2,1 HAVING exp(1-value3) > 0;

-- select exp with group by index having (result)
--Testcase 679:
SELECT value1, exp(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- select exp and as
--Testcase 680:
SELECT exp(value3) as exp1 FROM s3;

-- select floor (builtin function, explain)
--Testcase 681:
EXPLAIN VERBOSE
SELECT floor(value1), floor(value2), floor(value3), floor(value4), floor(1.5) FROM s3;

-- select floor (builtin function, result)
--Testcase 682:
SELECT floor(value1), floor(value2), floor(value3), floor(value4), floor(1.5) FROM s3;

-- select floor (builtin function, not pushdown constraints, explain)
--Testcase 683:
EXPLAIN VERBOSE
SELECT floor(value1), floor(value2), floor(value3), floor(value4), floor(1.5) FROM s3 WHERE to_hex(value2) = '64';

-- select floor (builtin function, not pushdown constraints, result)
--Testcase 684:
SELECT floor(value1), floor(value2), floor(value3), floor(value4), floor(1.5) FROM s3 WHERE to_hex(value2) = '64';

-- select floor (builtin function, pushdown constraints, explain)
--Testcase 685:
EXPLAIN VERBOSE
SELECT floor(value1), floor(value2), floor(value3), floor(value4), floor(1.5) FROM s3 WHERE value2 != 200;

-- select floor (builtin function, pushdown constraints, result)
--Testcase 686:
SELECT floor(value1), floor(value2), floor(value3), floor(value4), floor(1.5) FROM s3 WHERE value2 != 200;

-- select floor (builtin function, floor in constraints, explain)
--Testcase 687:
EXPLAIN VERBOSE
SELECT floor(value1), floor(value2), floor(value3), floor(value4), floor(1.5) FROM s3 WHERE floor(value1) != 1;

-- select floor (builtin function, floor in constraints, result)
--Testcase 688:
SELECT floor(value1), floor(value2), floor(value3), floor(value4), floor(1.5) FROM s3 WHERE floor(value1) != 1;

-- select floor (builtin function, floor in constraints, explain)
--Testcase 689:
EXPLAIN VERBOSE
SELECT floor(value1), floor(value2), floor(value3), floor(value4), floor(1.5) FROM s3 WHERE floor(1.5) > value1;

-- select floor (builtin function, floor in constraints, result)
--Testcase 690:
SELECT floor(value1), floor(value2), floor(value3), floor(value4), floor(1.5) FROM s3 WHERE floor(1.5) > value1;

-- select floor as nest function with agg (pushdown, explain)
--Testcase 691:
EXPLAIN VERBOSE
SELECT sum(value3),floor(sum(value3)) FROM s3;

-- select floor as nest function with agg (pushdown, result)
--Testcase 692:
SELECT sum(value3),floor(sum(value3)) FROM s3;

-- select floor as nest with log2 (pushdown, explain)
--Testcase 693:
EXPLAIN VERBOSE
SELECT floor(log2(value1)),floor(log2(1/value1)) FROM s3;

-- select floor as nest with log2 (pushdown, result)
--Testcase 694:
SELECT floor(log2(value1)),floor(log2(1/value1)) FROM s3;

-- select floor with non pushdown func and explicit constant (explain)
--Testcase 695:
EXPLAIN VERBOSE
SELECT floor(value3), pi(), 4.1 FROM s3;

-- select floor with non pushdown func and explicit constant (result)
--Testcase 696:
SELECT floor(value3), pi(), 4.1 FROM s3;

-- select floor with order by (explain)
--Testcase 697:
EXPLAIN VERBOSE
SELECT value1, floor(10 - value1) FROM s3 ORDER BY floor(10 - value1);

-- select floor with order by (result)
--Testcase 698:
SELECT value1, floor(10 - value1) FROM s3 ORDER BY floor(10 - value1);

-- select floor with order by index (result)
--Testcase 699:
SELECT value1, floor(10 - value1) FROM s3 ORDER BY 2,1;

-- select floor with order by index (result)
--Testcase 700:
SELECT value1, floor(10 - value1) FROM s3 ORDER BY 1,2;

-- select floor with group by (explain)
--Testcase 701:
EXPLAIN VERBOSE
SELECT value1, floor(10 - value1) FROM s3 GROUP BY value1, floor(10 - value1);

-- select floor with group by (result)
--Testcase 702:
SELECT value1, floor(10 - value1) FROM s3 GROUP BY value1, floor(10 - value1);

-- select floor with group by index (result)
--Testcase 703:
SELECT value1, floor(10 - value1) FROM s3 GROUP BY 2,1;

-- select floor with group by index (result)
--Testcase 704:
SELECT value1, floor(10 - value1) FROM s3 GROUP BY 1,2;

-- select floor with group by having (explain)
--Testcase 705:
EXPLAIN VERBOSE
SELECT value1, floor(10 - value1) FROM s3 GROUP BY value1, floor(10 - value1) HAVING floor(avg(value1)) > 0;

-- select floor with group by having (result)
--Testcase 706:
SELECT value1, floor(10 - value1) FROM s3 GROUP BY value1, floor(10 - value1) HAVING floor(avg(value1)) > 0;

-- select floor with group by index having (result)
--Testcase 707:
SELECT value1, floor(10 - value1) FROM s3 GROUP BY 2,1 HAVING floor(10 - value1) > 0;

-- select floor with group by index having (result)
--Testcase 708:
SELECT value1, floor(10 - value1) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- select floor and as
--Testcase 709:
SELECT floor(value3) as floor1 FROM s3;

-- select ln as nest function with agg (pushdown, explain)
--Testcase 710:
EXPLAIN VERBOSE
SELECT sum(value3),ln(sum(value1)) FROM s3;

-- select ln as nest function with agg (pushdown, result)
--Testcase 711:
SELECT sum(value3),ln(sum(value1)) FROM s3;

-- select ln as nest with log2 (pushdown, explain)
--Testcase 712:
EXPLAIN VERBOSE
SELECT value1, ln(log2(value1)),ln(log2(1/value1)) FROM s3;

-- select ln as nest with log2 (pushdown, result)
--Testcase 713:
SELECT value1, ln(log2(value1)),ln(log2(1/value1)) FROM s3;

-- select ln with non pushdown func and explicit constant (explain)
--Testcase 714:
EXPLAIN VERBOSE
SELECT ln(value2), pi(), 4.1 FROM s3;

-- select ln with non pushdown func and explicit constant (result)
--Testcase 715:
SELECT ln(value2), pi(), 4.1 FROM s3;

-- select ln with order by (explain)
--Testcase 716:
EXPLAIN VERBOSE
SELECT value1, ln(1-value3) FROM s3 ORDER BY ln(1-value3);

-- select ln with order by (result)
--Testcase 717:
SELECT value1, ln(1-value3) FROM s3 ORDER BY ln(1-value3);

-- select ln with order by index (result)
--Testcase 718:
SELECT value1, ln(1-value3) FROM s3 ORDER BY 2,1;

-- select ln with order by index (result)
--Testcase 719:
SELECT value1, ln(1-value3) FROM s3 ORDER BY 1,2;

-- select ln with group by (explain)
--Testcase 720:
EXPLAIN VERBOSE
SELECT count(value1), ln(1-value3) FROM s3 GROUP BY ln(1-value3);

-- select ln with group by (result)
--Testcase 721:
SELECT count(value1), ln(1-value3) FROM s3 GROUP BY ln(1-value3);

-- select ln with group by index (result)
--Testcase 722:
SELECT value1, ln(1-value3) FROM s3 GROUP BY 2,1;

-- select ln with group by index (result)
--Testcase 723:
SELECT value1, ln(1-value3) FROM s3 GROUP BY 1,2;

-- select ln with group by having (explain)
--Testcase 724:
EXPLAIN VERBOSE
SELECT count(value1), ln(1-value3) FROM s3 GROUP BY ln(1-value3) HAVING ln(avg(value1)) > 0;

-- select ln with group by having (result)
--Testcase 725:
SELECT count(value1), ln(1-value3) FROM s3 GROUP BY ln(1-value3) HAVING ln(avg(value1)) > 0;

-- select ln with group by index having (result)
--Testcase 726:
SELECT value1, ln(1-value3) FROM s3 GROUP BY 2,1 HAVING ln(1-value3) < 0;

-- select ln with group by index having (result)
--Testcase 727:
SELECT value1, ln(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- select ln and as
--Testcase 728:
SELECT ln(value1) as ln1 FROM s3;

-- select ln (builtin function, explain)
--Testcase 729:
EXPLAIN VERBOSE
SELECT ln(value1), ln(value2), ln(value3 + 10), ln(0.5) FROM s3;

-- select ln (builtin function, result)
--Testcase 730:
SELECT ln(value1), ln(value2), ln(value3 + 10), ln(0.5) FROM s3;

-- select ln (builtin function, not pushdown constraints, explain)
--Testcase 731:
EXPLAIN VERBOSE
SELECT ln(value1), ln(value2), ln(value3 + 10), ln(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select ln (builtin function, not pushdown constraints, result)
--Testcase 732:
SELECT ln(value1), ln(value2), ln(value3 + 10), ln(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select ln (builtin function, pushdown constraints, explain)
--Testcase 733:
EXPLAIN VERBOSE
SELECT ln(value1), ln(value2), ln(value3 + 10), ln(0.5) FROM s3 WHERE value2 != 200;

-- select ln (builtin function, pushdown constraints, result)
--Testcase 734:
SELECT ln(value1), ln(value2), ln(value3 + 10), ln(0.5) FROM s3 WHERE value2 != 200;

-- select ln (builtin function, ln in constraints, explain)
--Testcase 735:
EXPLAIN VERBOSE
SELECT ln(value1), ln(value2), ln(value3 + 10), ln(0.5) FROM s3 WHERE ln(value1) != 1;

-- select ln (builtin function, ln in constraints, result)
--Testcase 736:
SELECT ln(value1), ln(value2), ln(value3 + 10), ln(0.5) FROM s3 WHERE ln(value1) != 1;

-- select ln (builtin function, ln in constraints, explain)
--Testcase 737:
EXPLAIN VERBOSE
SELECT ln(value1), ln(value2), ln(value3 + 10), ln(0.5) FROM s3 WHERE ln(0.5) < value1;

-- select ln (builtin function, ln in constraints, result)
--Testcase 738:
SELECT ln(value1), ln(value2), ln(value3 + 10), ln(0.5) FROM s3 WHERE ln(0.5) < value1;

-- select mod (builtin function, explain)
--Testcase 739:
EXPLAIN VERBOSE
SELECT value1, mod(value1::numeric, 2), mod(value2::numeric, 2), mod(value3::numeric, 2), mod(value4::numeric, 2), mod(5, 2) FROM s3;

-- select mod (builtin function, result)
--Testcase 740:
SELECT value1, mod(value1::numeric, 2), mod(value2::numeric, 2), mod(value3::numeric, 2), mod(value4::numeric, 2), mod(5, 2) FROM s3;

-- select mod (builtin function, not pushdown constraints, explain)
--Testcase 741:
EXPLAIN VERBOSE
SELECT mod(value1::numeric, 2), mod(value2::numeric, 2), mod(value3::numeric, 2), mod(value4::numeric, 2), mod(5, 2) FROM s3 WHERE to_hex(value2) = '64';

-- select mod (builtin function, not pushdown constraints, result)
--Testcase 742:
SELECT mod(value1::numeric, 2), mod(value2::numeric, 2), mod(value3::numeric, 2), mod(value4::numeric, 2), mod(5, 2) FROM s3 WHERE to_hex(value2) = '64';

-- select mod (builtin function, pushdown constraints, explain)
--Testcase 743:
EXPLAIN VERBOSE
SELECT mod(value1::numeric, 2), mod(value2::numeric, 2), mod(value3::numeric, 2), mod(value4::numeric, 2), mod(5, 2) FROM s3 WHERE value2 != 200;

-- select mod (builtin function, pushdown constraints, result)
--Testcase 744:
SELECT mod(value1::numeric, 2), mod(value2::numeric, 2), mod(value3::numeric, 2), mod(value4::numeric, 2), mod(5, 2) FROM s3 WHERE value2 != 200;

-- select mod (builtin function, mod in constraints, explain)
--Testcase 745:
EXPLAIN VERBOSE
SELECT value1, mod(value1::numeric, 2), mod(value2::numeric, 2), mod(value3::numeric, 2), mod(value4::numeric, 2), mod(5, 2) FROM s3 WHERE mod(value1::numeric, 2) != 1;

-- select mod (builtin function, mod in constraints, result)
--Testcase 746:
SELECT value1, mod(value1::numeric, 2), mod(value2::numeric, 2), mod(value3::numeric, 2), mod(value4::numeric, 2), mod(5, 2) FROM s3 WHERE mod(value1::numeric, 2) != 1;

-- select mod (builtin function, mod in constraints, explain)
--Testcase 747:
EXPLAIN VERBOSE
SELECT mod(value1::numeric, 2), mod(value2::numeric, 2), mod(value3::numeric, 2), mod(value4::numeric, 2), mod(5, 2) FROM s3 WHERE mod(5, 2) > value1;

-- select mod (builtin function, mod in constraints, result)
--Testcase 748:
SELECT mod(value1::numeric, 2), mod(value2::numeric, 2), mod(value3::numeric, 2), mod(value4::numeric, 2), mod(5, 2) FROM s3 WHERE mod(5, 2) > value1;

-- select mod as nest function with agg (pushdown, explain)
--Testcase 749:
EXPLAIN VERBOSE
SELECT sum(value3),mod(sum(value3)::numeric, 2) FROM s3;

-- select mod as nest function with agg (pushdown, result)
--Testcase 750:
SELECT sum(value3),mod(sum(value3)::numeric, 2) FROM s3;

-- select mod as nest with log2 (pushdown, explain)
--Testcase 751:
EXPLAIN VERBOSE
SELECT value1, mod(log2(value1)::numeric, 2),mod(log2(1/value1)::numeric, 2) FROM s3;

-- select mod as nest with log2 (pushdown, result)
--Testcase 752:
SELECT value1, mod(log2(value1)::numeric, 2),mod(log2(1/value1)::numeric, 2) FROM s3;

-- select mod with non pushdown func and explicit constant (explain)
--Testcase 753:
EXPLAIN VERBOSE
SELECT value1, mod(value3::numeric, 2), pi(), 4.1 FROM s3;

-- select mod with non pushdown func and explicit constant (result)
--Testcase 754:
SELECT value1, mod(value3::numeric, 2), pi(), 4.1 FROM s3;

-- select mod with order by (explain)
--Testcase 755:
EXPLAIN VERBOSE
SELECT value1, mod((1-value3)::numeric, 2) FROM s3 ORDER BY mod((1-value3)::numeric, 2);

-- select mod with order by (result)
--Testcase 756:
SELECT value1, mod((1-value3)::numeric, 2) FROM s3 ORDER BY mod((1-value3)::numeric, 2);

-- select mod with order by index (result)
--Testcase 757:
SELECT value1, mod((1-value3)::numeric, 2) FROM s3 ORDER BY 2,1;

-- select mod with order by index (result)
--Testcase 758:
SELECT value1, mod((1-value3)::numeric, 2) FROM s3 ORDER BY 1,2;

-- select mod with group by (explain)
--Testcase 759:
EXPLAIN VERBOSE
SELECT value1, mod((1-value3)::numeric, 2) FROM s3 GROUP BY value1, mod((1-value3)::numeric, 2);

-- select mod with group by (result)
--Testcase 760:
SELECT value1, mod((1-value3)::numeric, 2) FROM s3 GROUP BY value1, mod((1-value3)::numeric, 2);

-- select mod with group by index (result)
--Testcase 761:
SELECT value1, mod((1-value3)::numeric, 2) FROM s3 GROUP BY 2,1;

-- select mod with group by index (result)
--Testcase 762:
SELECT value1, mod((1-value3)::numeric, 2) FROM s3 GROUP BY 1,2;

-- select mod with group by having (explain)
--Testcase 763:
EXPLAIN VERBOSE
SELECT value1, mod((1-value3)::numeric, 2) FROM s3 GROUP BY value1, mod((1-value3)::numeric, 2) HAVING avg(value1) > 0;

-- select mod with group by having (result)
--Testcase 764:
SELECT value1, mod((1-value3)::numeric, 2) FROM s3 GROUP BY value1, mod((1-value3)::numeric, 2) HAVING avg(value1) > 0;

-- select mod with group by index having (result)
--Testcase 765:
SELECT value1, mod((1-value3)::numeric, 2) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- select mod and as
--Testcase 766:
SELECT value1, mod(value3::numeric, 2) as mod1 FROM s3;

-- select power (builtin function, explain)
--Testcase 767:
EXPLAIN VERBOSE
SELECT power(value1, 2), power(value2, 2), power(value3, 2), power(value4, 2), power(5, 2) FROM s3;

-- select power (builtin function, result)
--Testcase 768:
SELECT power(value1, 2), power(value2, 2), power(value3, 2), power(value4, 2), power(5, 2) FROM s3;

-- select power (builtin function, not pushdown constraints, explain)
--Testcase 769:
EXPLAIN VERBOSE
SELECT power(value1, 2), power(value2, 2), power(value3, 2), power(value4, 2), power(5, 2) FROM s3 WHERE to_hex(value2) = '64';

-- select power (builtin function, not pushdown constraints, result)
--Testcase 770:
SELECT power(value1, 2), power(value2, 2), power(value3, 2), power(value4, 2), power(5, 2) FROM s3 WHERE to_hex(value2) = '64';

-- select power (builtin function, pushdown constraints, explain)
--Testcase 771:
EXPLAIN VERBOSE
SELECT power(value1, 2), power(value2, 2), power(value3, 2), power(value4, 2), power(5, 2) FROM s3 WHERE value2 != 200;

-- select power (builtin function, pushdown constraints, result)
--Testcase 772:
SELECT power(value1, 2), power(value2, 2), power(value3, 2), power(value4, 2), power(5, 2) FROM s3 WHERE value2 != 200;

-- select power (builtin function, power in constraints, explain)
--Testcase 773:
EXPLAIN VERBOSE
SELECT power(value1, 2), power(value2, 2), power(value3, 2), power(value4, 2), power(5, 2) FROM s3 WHERE power(value1, 2) != 1;

-- select power (builtin function, power in constraints, result)
--Testcase 774:
SELECT power(value1, 2), power(value2, 2), power(value3, 2), power(value4, 2), power(5, 2) FROM s3 WHERE power(value1, 2) != 1;

-- select power (builtin function, power in constraints, explain)
--Testcase 775:
EXPLAIN VERBOSE
SELECT power(value1, 2), power(value2, 2), power(value3, 2), power(value4, 2), power(5, 2) FROM s3 WHERE power(5, 2) > value1;

-- select power (builtin function, power in constraints, result)
--Testcase 776:
SELECT power(value1, 2), power(value2, 2), power(value3, 2), power(value4, 2), power(5, 2) FROM s3 WHERE power(5, 2) > value1;

-- select power as nest function with agg (pushdown, explain)
--Testcase 777:
EXPLAIN VERBOSE
SELECT sum(value3),power(sum(value3), 2) FROM s3;

-- select power as nest function with agg (pushdown, result)
--Testcase 778:
SELECT sum(value3),power(sum(value3), 2) FROM s3;

-- select power as nest with log2 (pushdown, explain)
--Testcase 779:
EXPLAIN VERBOSE
SELECT value1, power(log2(value1), 2),power(log2(1/value1), 2) FROM s3;

-- select power as nest with log2 (pushdown, result)
--Testcase 780:
SELECT value1, power(log2(value1), 2),power(log2(1/value1), 2) FROM s3;

-- select power with non pushdown func and explicit constant (explain)
--Testcase 781:
EXPLAIN VERBOSE
SELECT power(value3, 2), pi(), 4.1 FROM s3;

-- select power with non pushdown func and explicit constant (result)
--Testcase 782:
SELECT power(value3, 2), pi(), 4.1 FROM s3;

-- select power with order by (explain)
--Testcase 783:
EXPLAIN VERBOSE
SELECT value1, power(1-value3, 2) FROM s3 ORDER BY power(1-value3, 2);

-- select power with order by (result)
--Testcase 784:
SELECT value1, power(1-value3, 2) FROM s3 ORDER BY power(1-value3, 2);

-- select power with order by index (result)
--Testcase 785:
SELECT value1, power(1-value3, 2) FROM s3 ORDER BY 2,1;

-- select power with order by index (result)
--Testcase 786:
SELECT value1, power(1-value3, 2) FROM s3 ORDER BY 1,2;

-- select power with group by (explain)
--Testcase 787:
EXPLAIN VERBOSE
SELECT count(value1), power(1-value3, 2) FROM s3 GROUP BY power(1-value3, 2);

-- select power with group by (result)
--Testcase 788:
SELECT count(value1), power(1-value3, 2) FROM s3 GROUP BY power(1-value3, 2);

-- select power with group by index (result)
--Testcase 789:
SELECT value1, power(1-value3, 2) FROM s3 GROUP BY 2,1;

-- select power with group by index (result)
--Testcase 790:
SELECT value1, power(1-value3, 2) FROM s3 GROUP BY 1,2;

-- select power with group by having (explain)
--Testcase 791:
EXPLAIN VERBOSE
SELECT count(value1), power(1-value3, 2) FROM s3 GROUP BY power(1-value3, 2) HAVING power(avg(value1), 2) > 0;

-- select power with group by having (result)
--Testcase 792:
SELECT count(value1), power(1-value3, 2) FROM s3 GROUP BY power(1-value3, 2) HAVING power(avg(value1), 2) > 0;

-- select power with group by index having (result)
--Testcase 793:
SELECT value1, power(1-value3, 2) FROM s3 GROUP BY 2,1 HAVING power(1-value3, 2) > 0;

-- select power with group by index having (result)
--Testcase 794:
SELECT value1, power(1-value3, 2) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- select power and as
--Testcase 795:
SELECT power(value3, 2) as power1 FROM s3;

-- select radians (builtin function, explain)
--Testcase 796:
EXPLAIN VERBOSE
SELECT radians(value1), radians(value2), radians(value3), radians(value4), radians(0.5) FROM s3;

-- select radians (builtin function, result)
--Testcase 797:
SELECT radians(value1), radians(value2), radians(value3), radians(value4), radians(0.5) FROM s3;

-- select radians (builtin function, not pushdown constraints, explain)
--Testcase 798:
EXPLAIN VERBOSE
SELECT radians(value1), radians(value2), radians(value3), radians(value4), radians(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select radians (builtin function, not pushdown constraints, result)
--Testcase 799:
SELECT radians(value1), radians(value2), radians(value3), radians(value4), radians(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select radians (builtin function, pushdown constraints, explain)
--Testcase 800:
EXPLAIN VERBOSE
SELECT radians(value1), radians(value2), radians(value3), radians(value4), radians(0.5) FROM s3 WHERE value2 != 200;

-- select radians (builtin function, pushdown constraints, result)
--Testcase 801:
SELECT radians(value1), radians(value2), radians(value3), radians(value4), radians(0.5) FROM s3 WHERE value2 != 200;

-- select radians (builtin function, radians in constraints, explain)
--Testcase 802:
EXPLAIN VERBOSE
SELECT radians(value1), radians(value2), radians(value3), radians(value4), radians(0.5) FROM s3 WHERE radians(value1) != 1;

-- select radians (builtin function, radians in constraints, result)
--Testcase 803:
SELECT radians(value1), radians(value2), radians(value3), radians(value4), radians(0.5) FROM s3 WHERE radians(value1) != 1;

-- select radians (builtin function, radians in constraints, explain)
--Testcase 804:
EXPLAIN VERBOSE
SELECT radians(value1), radians(value2), radians(value3), radians(value4), radians(0.5) FROM s3 WHERE radians(0.5) < value1;

-- select radians (builtin function, radians in constraints, result)
--Testcase 805:
SELECT radians(value1), radians(value2), radians(value3), radians(value4), radians(0.5) FROM s3 WHERE radians(0.5) < value1;

-- select radians as nest function with agg (pushdown, explain)
--Testcase 806:
EXPLAIN VERBOSE
SELECT sum(value3),radians(sum(value3)) FROM s3;

-- select radians as nest function with agg (pushdown, result)
--Testcase 807:
SELECT sum(value3),radians(sum(value3)) FROM s3;

-- select radians as nest with log2 (pushdown, explain)
--Testcase 808:
EXPLAIN VERBOSE
SELECT radians(log2(value1)),radians(log2(1/value1)) FROM s3;

-- select radians as nest with log2 (pushdown, result)
--Testcase 809:
SELECT radians(log2(value1)),radians(log2(1/value1)) FROM s3;

-- select radians with non pushdown func and explicit constant (explain)
--Testcase 810:
EXPLAIN VERBOSE
SELECT radians(value3), pi(), 4.1 FROM s3;

-- select radians with non pushdown func and explicit constant (result)
--Testcase 811:
SELECT radians(value3), pi(), 4.1 FROM s3;

-- select radians with order by (explain)
--Testcase 812:
EXPLAIN VERBOSE
SELECT value1, radians(1-value3) FROM s3 ORDER BY radians(1-value3);

-- select radians with order by (result)
--Testcase 813:
SELECT value1, radians(1-value3) FROM s3 ORDER BY radians(1-value3);

-- select radians with order by index (result)
--Testcase 814:
SELECT value1, radians(1-value3) FROM s3 ORDER BY 2,1;

-- select radians with order by index (result)
--Testcase 815:
SELECT value1, radians(1-value3) FROM s3 ORDER BY 1,2;

-- select radians with group by (explain)
--Testcase 816:
EXPLAIN VERBOSE
SELECT count(value1), radians(1-value3) FROM s3 GROUP BY radians(1-value3);

-- select radians with group by (result)
--Testcase 817:
SELECT count(value1), radians(1-value3) FROM s3 GROUP BY radians(1-value3);

-- select radians with group by index (result)
--Testcase 818:
SELECT value1, radians(1-value3) FROM s3 GROUP BY 2,1;

-- select radians with group by index (result)
--Testcase 819:
SELECT value1, radians(1-value3) FROM s3 GROUP BY 1,2;

-- select radians with group by having (explain)
--Testcase 820:
EXPLAIN VERBOSE
SELECT count(value1), radians(1-value3) FROM s3 GROUP BY radians(1-value3) HAVING radians(avg(value1)) > 0;

-- select radians with group by having (result)
--Testcase 821:
SELECT count(value1), radians(1-value3) FROM s3 GROUP BY radians(1-value3) HAVING radians(avg(value1)) > 0;

-- select radians with group by index having (result)
--Testcase 822:
SELECT value1, radians(1-value3) FROM s3 GROUP BY 2,1 HAVING radians(1-value3) > 0;

-- select radians with group by index having (result)
--Testcase 823:
SELECT value1, radians(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- select radians and as
--Testcase 824:
SELECT radians(value3) as radians1 FROM s3;

-- select sign (builtin function, explain)
--Testcase 825:
EXPLAIN VERBOSE
SELECT sign(value1), sign(value2), sign(value3), sign(value4), sign(0.5) FROM s3;

-- select sign (builtin function, result)
--Testcase 826:
SELECT sign(value1), sign(value2), sign(value3), sign(value4), sign(0.5) FROM s3;

-- select sign (builtin function, not pushdown constraints, explain)
--Testcase 827:
EXPLAIN VERBOSE
SELECT sign(value1), sign(value2), sign(value3), sign(value4), sign(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select sign (builtin function, not pushdown constraints, result)
--Testcase 828:
SELECT sign(value1), sign(value2), sign(value3), sign(value4), sign(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select sign (builtin function, pushdown constraints, explain)
--Testcase 829:
EXPLAIN VERBOSE
SELECT sign(value1), sign(value2), sign(value3), sign(value4), sign(0.5) FROM s3 WHERE value2 != 200;

-- select sign (builtin function, pushdown constraints, result)
--Testcase 830:
SELECT sign(value1), sign(value2), sign(value3), sign(value4), sign(0.5) FROM s3 WHERE value2 != 200;

-- select sign (builtin function, sign in constraints, explain)
--Testcase 831:
EXPLAIN VERBOSE
SELECT sign(value1), sign(value2), sign(value3), sign(value4), sign(0.5) FROM s3 WHERE sign(value1) != -1;

-- select sign (builtin function, sign in constraints, result)
--Testcase 832:
SELECT sign(value1), sign(value2), sign(value3), sign(value4), sign(0.5) FROM s3 WHERE sign(value1) != -1;

-- select sign (builtin function, sign in constraints, explain)
--Testcase 833:
EXPLAIN VERBOSE
SELECT sign(value1), sign(value2), sign(value3), sign(value4), sign(0.5) FROM s3 WHERE sign(0.5) > value1;

-- select sign (builtin function, sign in constraints, result)
--Testcase 834:
SELECT sign(value1), sign(value2), sign(value3), sign(value4), sign(0.5) FROM s3 WHERE sign(0.5) > value1;

-- select sign as nest function with agg (pushdown, explain)
--Testcase 835:
EXPLAIN VERBOSE
SELECT sum(value3),sign(sum(value3)) FROM s3;

-- select sign as nest function with agg (pushdown, result)
--Testcase 836:
SELECT sum(value3),sign(sum(value3)) FROM s3;

-- select sign as nest with log2 (pushdown, explain)
--Testcase 837:
EXPLAIN VERBOSE
SELECT sign(log2(value1)),sign(log2(1/value1)) FROM s3;

-- select sign as nest with log2 (pushdown, result)
--Testcase 838:
SELECT sign(log2(value1)),sign(log2(1/value1)) FROM s3;

-- select sign with non pushdown func and explicit constant (explain)
--Testcase 839:
EXPLAIN VERBOSE
SELECT sign(value3), pi(), 4.1 FROM s3;

-- select sign with non pushdown func and explicit constant (result)
--Testcase 840:
SELECT sign(value3), pi(), 4.1 FROM s3;

-- select sign with order by (explain)
--Testcase 841:
EXPLAIN VERBOSE
SELECT value1, sign(1-value3) FROM s3 ORDER BY sign(1-value3);

-- select sign with order by (result)
--Testcase 842:
SELECT value1, sign(1-value3) FROM s3 ORDER BY sign(1-value3);

-- select sign with order by index (result)
--Testcase 843:
SELECT value1, sign(1-value3) FROM s3 ORDER BY 2,1;

-- select sign with order by index (result)
--Testcase 844:
SELECT value1, sign(1-value3) FROM s3 ORDER BY 1,2;

-- select sign with group by (explain)
--Testcase 845:
EXPLAIN VERBOSE
SELECT count(value1), sign(1-value3) FROM s3 GROUP BY sign(1-value3);

-- select sign with group by (result)
--Testcase 846:
SELECT count(value1), sign(1-value3) FROM s3 GROUP BY sign(1-value3);

-- select sign with group by index (result)
--Testcase 847:
SELECT value1, sign(1-value3) FROM s3 GROUP BY 2,1;

-- select sign with group by index (result)
--Testcase 848:
SELECT value1, sign(1-value3) FROM s3 GROUP BY 1,2;

-- select sign with group by having (explain)
--Testcase 849:
EXPLAIN VERBOSE
SELECT count(value1), sign(1-value3) FROM s3 GROUP BY sign(1-value3) HAVING sign(avg(value1)) > 0;

-- select sign with group by having (result)
--Testcase 850:
SELECT count(value1), sign(1-value3) FROM s3 GROUP BY sign(1-value3) HAVING sign(avg(value1)) > 0;

-- select sign with group by index having (result)
--Testcase 851:
SELECT value1, sign(1-value3) FROM s3 GROUP BY 2,1 HAVING sign(1-value3) > 0;

-- select sign with group by index having (result)
--Testcase 852:
SELECT value1, sign(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- select sign and as
--Testcase 853:
SELECT sign(value3) as sign1 FROM s3;

-- select sin (builtin function, explain)
--Testcase 854:
EXPLAIN VERBOSE
SELECT value1, sin(value2), sin(value3), sin(value4), sin(0.5) FROM s3;

-- select sin (builtin function, result)
--Testcase 855:
SELECT value1, sin(value2), sin(value3), sin(value4), sin(0.5) FROM s3;

-- select sin (builtin function, not pushdown constraints, explain)
--Testcase 856:
EXPLAIN VERBOSE
SELECT sin(value1), sin(value2), sin(value3), sin(value4), sin(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select sin (builtin function, not pushdown constraints, result)
--Testcase 857:
SELECT sin(value1), sin(value2), sin(value3), sin(value4), sin(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select sin (builtin function, pushdown constraints, explain)
--Testcase 858:
EXPLAIN VERBOSE
SELECT sin(value1), sin(value2), sin(value3), sin(value4), sin(0.5) FROM s3 WHERE value2 != 200;

-- select sin (builtin function, pushdown constraints, result)
--Testcase 859:
SELECT sin(value1), sin(value2), sin(value3), sin(value4), sin(0.5) FROM s3 WHERE value2 != 200;

-- select sin (builtin function, sin in constraints, explain)
--Testcase 860:
EXPLAIN VERBOSE
SELECT value1, sin(value2), sin(value3), sin(value4), sin(0.5) FROM s3 WHERE sin(value1) != 1;

-- select sin (builtin function, sin in constraints, result)
--Testcase 861:
SELECT value1, sin(value2), sin(value3), sin(value4), sin(0.5) FROM s3 WHERE sin(value1) != 1;

-- select sin (builtin function, sin in constraints, explain)
--Testcase 862:
EXPLAIN VERBOSE
SELECT sin(value1), sin(value2), sin(value3), sin(value4), sin(0.5) FROM s3 WHERE sin(0.5) > value1;

-- select sin (builtin function, sin in constraints, result)
--Testcase 863:
SELECT sin(value1), sin(value2), sin(value3), sin(value4), sin(0.5) FROM s3 WHERE sin(0.5) > value1;

-- select sin as nest function with agg (pushdown, explain)
--Testcase 864:
EXPLAIN VERBOSE
SELECT sum(value3),sin(sum(value3)) FROM s3;

-- select sin as nest function with agg (pushdown, result)
--Testcase 865:
SELECT sum(value3),sin(sum(value3)) FROM s3;

-- select sin as nest with log2 (pushdown, explain)
--Testcase 866:
EXPLAIN VERBOSE
SELECT value1, sin(log2(value1)),sin(log2(1/value1)) FROM s3;

-- select sin as nest with log2 (pushdown, result)
--Testcase 867:
SELECT value1, sin(log2(value1)),sin(log2(1/value1)) FROM s3;

-- select sin with non pushdown func and explicit constant (explain)
--Testcase 868:
EXPLAIN VERBOSE
SELECT value1, sin(value3), pi(), 4.1 FROM s3;

-- select sin with non pushdown func and explicit constant (result)
--Testcase 869:
SELECT value1, sin(value3), pi(), 4.1 FROM s3;

-- select sin with order by (explain)
--Testcase 870:
EXPLAIN VERBOSE
SELECT value1, sin(1-value3) FROM s3 ORDER BY sin(1-value3);

-- select sin with order by (result)
--Testcase 871:
SELECT value1, sin(1-value3) FROM s3 ORDER BY sin(1-value3);

-- select sin with order by index (result)
--Testcase 872:
SELECT value1, sin(1-value3) FROM s3 ORDER BY 2,1;

-- select sin with order by index (result)
--Testcase 873:
SELECT value1, sin(1-value3) FROM s3 ORDER BY 1,2;

-- select sin with group by (explain)
--Testcase 874:
EXPLAIN VERBOSE
SELECT value1, sin(1-value3) FROM s3 GROUP BY value1, sin(1-value3);

-- select sin with group by (result)
--Testcase 875:
SELECT value1, sin(1-value3) FROM s3 GROUP BY value1, sin(1-value3);

-- select sin with group by index (result)
--Testcase 876:
SELECT value1, sin(1-value3) FROM s3 GROUP BY 2,1;

-- select sin with group by index (result)
--Testcase 877:
SELECT value1, sin(1-value3) FROM s3 GROUP BY 1,2;

-- select sin with group by having (explain)
--Testcase 878:
EXPLAIN VERBOSE
SELECT value1, sin(1-value3) FROM s3 GROUP BY value1, sin(1-value3) HAVING sin(avg(value1)) > 0;

-- select sin with group by having (result)
--Testcase 879:
SELECT value1, sin(1-value3) FROM s3 GROUP BY value1, sin(1-value3) HAVING sin(avg(value1)) > 0;

-- select sin with group by index having (result)
--Testcase 880:
SELECT value1, sin(1-value3) FROM s3 GROUP BY 2,1 HAVING sin(1-value3) > 0;

-- select sin with group by index having (result)
--Testcase 881:
SELECT value1, sin(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- select sin and as
--Testcase 882:
SELECT value1, sin(value3) as sin1 FROM s3;

-- select sqrt (builtin function, explain)
--Testcase 883:
EXPLAIN VERBOSE
SELECT sqrt(value1), sqrt(value2), sqrt(0.5) FROM s3;

-- select sqrt (builtin function, result)
--Testcase 884:
SELECT sqrt(value1), sqrt(value2), sqrt(0.5) FROM s3;

-- select sqrt (builtin function, not pushdown constraints, explain)
--Testcase 885:
EXPLAIN VERBOSE
SELECT sqrt(value1), sqrt(value2), sqrt(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select sqrt (builtin function, not pushdown constraints, result)
--Testcase 886:
SELECT sqrt(value1), sqrt(value2), sqrt(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select sqrt (builtin function, pushdown constraints, explain)
--Testcase 887:
EXPLAIN VERBOSE
SELECT sqrt(value1), sqrt(value2), sqrt(0.5) FROM s3 WHERE value2 != 200;

-- select sqrt (builtin function, pushdown constraints, result)
--Testcase 888:
SELECT sqrt(value1), sqrt(value2), sqrt(0.5) FROM s3 WHERE value2 != 200;

-- select sqrt (builtin function, sqrt in constraints, explain)
--Testcase 889:
EXPLAIN VERBOSE
SELECT sqrt(value1), sqrt(value2), sqrt(0.5) FROM s3 WHERE sqrt(value1) != 1;

-- select sqrt (builtin function, sqrt in constraints, result)
--Testcase 890:
SELECT sqrt(value1), sqrt(value2), sqrt(0.5) FROM s3 WHERE sqrt(value1) != 1;

-- select sqrt (builtin function, sqrt in constraints, explain)
--Testcase 891:
EXPLAIN VERBOSE
SELECT sqrt(value1), sqrt(value2), sqrt(0.5) FROM s3 WHERE sqrt(0.5) > value1;

-- select sqrt (builtin function, sqrt in constraints, result)
--Testcase 892:
SELECT sqrt(value1), sqrt(value2), sqrt(0.5) FROM s3 WHERE sqrt(0.5) > value1;

-- select sqrt as nest function with agg (pushdown, explain)
--Testcase 893:
EXPLAIN VERBOSE
SELECT sum(value3),sqrt(sum(value1)) FROM s3;

-- select sqrt as nest function with agg (pushdown, result)
--Testcase 894:
SELECT sum(value3),sqrt(sum(value1)) FROM s3;

-- select sqrt as nest with log2 (pushdown, explain)
--Testcase 895:
EXPLAIN VERBOSE
SELECT value1, sqrt(log2(value1)),sqrt(log2(1/value1)) FROM s3;

-- select sqrt as nest with log2 (pushdown, result)
--Testcase 896:
SELECT value1, sqrt(log2(value1)),sqrt(log2(1/value1)) FROM s3;

-- select sqrt with non pushdown func and explicit constant (explain)
--Testcase 897:
EXPLAIN VERBOSE
SELECT sqrt(value2), pi(), 4.1 FROM s3;

-- select sqrt with non pushdown func and explicit constant (result)
--Testcase 898:
SELECT sqrt(value2), pi(), 4.1 FROM s3;

-- select sqrt with order by (explain)
--Testcase 899:
EXPLAIN VERBOSE
SELECT value1, sqrt(1-value3) FROM s3 ORDER BY sqrt(1-value3);

-- select sqrt with order by (result)
--Testcase 900:
SELECT value1, sqrt(1-value3) FROM s3 ORDER BY sqrt(1-value3);

-- select sqrt with order by index (result)
--Testcase 901:
SELECT value1, sqrt(1-value3) FROM s3 ORDER BY 2,1;

-- select sqrt with order by index (result)
--Testcase 902:
SELECT value1, sqrt(1-value3) FROM s3 ORDER BY 1,2;

-- select sqrt with group by (explain)
--Testcase 903:
EXPLAIN VERBOSE
SELECT count(value1), sqrt(1-value3) FROM s3 GROUP BY sqrt(1-value3);

-- select sqrt with group by (result)
--Testcase 904:
SELECT count(value1), sqrt(1-value3) FROM s3 GROUP BY sqrt(1-value3);

-- select sqrt with group by index (result)
--Testcase 905:
SELECT value1, sqrt(1-value3) FROM s3 GROUP BY 2,1;

-- select sqrt with group by index (result)
--Testcase 906:
SELECT value1, sqrt(1-value3) FROM s3 GROUP BY 1,2;

-- select sqrt with group by having (explain)
--Testcase 907:
EXPLAIN VERBOSE
SELECT count(value1), sqrt(1-value3) FROM s3 GROUP BY sqrt(1-value3) HAVING sqrt(avg(value1)) > 0;

-- select sqrt with group by having (result)
--Testcase 908:
SELECT count(value1), sqrt(1-value3) FROM s3 GROUP BY sqrt(1-value3) HAVING sqrt(avg(value1)) > 0;

-- select sqrt with group by index having (result)
--Testcase 909:
SELECT value1, sqrt(1-value3) FROM s3 GROUP BY 2,1 HAVING sqrt(1-value3) > 0;

-- select sqrt with group by index having (result)
--Testcase 910:
SELECT value1, sqrt(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- select sqrt and as (return null with negative number)
--Testcase 911:
SELECT value1, value3 + 1, sqrt(value1 + 1) as sqrt1 FROM s3;

-- select tan (builtin function, explain)
--Testcase 912:
EXPLAIN VERBOSE
SELECT value1, tan(value2), tan(value3), tan(value4), tan(0.5) FROM s3;

-- select tan (builtin function, result)
--Testcase 913:
SELECT value1, tan(value2), tan(value3), tan(value4), tan(0.5) FROM s3;

-- select tan (builtin function, not pushdown constraints, explain)
--Testcase 914:
EXPLAIN VERBOSE
SELECT tan(value1), tan(value2), tan(value3), tan(value4), tan(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select tan (builtin function, not pushdown constraints, result)
--Testcase 915:
SELECT tan(value1), tan(value2), tan(value3), tan(value4), tan(0.5) FROM s3 WHERE to_hex(value2) = '64';

-- select tan (builtin function, pushdown constraints, explain)
--Testcase 916:
EXPLAIN VERBOSE
SELECT tan(value1), tan(value2), tan(value3), tan(value4), tan(0.5) FROM s3 WHERE value2 != 200;

-- select tan (builtin function, pushdown constraints, result)
--Testcase 917:
SELECT tan(value1), tan(value2), tan(value3), tan(value4), tan(0.5) FROM s3 WHERE value2 != 200;

-- select tan (builtin function, tan in constraints, explain)
--Testcase 918:
EXPLAIN VERBOSE
SELECT value1, tan(value2), tan(value3), tan(value4), tan(0.5) FROM s3 WHERE tan(value1) != 1;

-- select tan (builtin function, tan in constraints, result)
--Testcase 919:
SELECT value1, tan(value2), tan(value3), tan(value4), tan(0.5) FROM s3 WHERE tan(value1) != 1;

-- select tan (builtin function, tan in constraints, explain)
--Testcase 920:
EXPLAIN VERBOSE
SELECT tan(value1), tan(value2), tan(value3), tan(value4), tan(0.5) FROM s3 WHERE tan(0.5) > value1;

-- select tan (builtin function, tan in constraints, result)
--Testcase 921:
SELECT tan(value1), tan(value2), tan(value3), tan(value4), tan(0.5) FROM s3 WHERE tan(0.5) > value1;

-- select tan as nest function with agg (pushdown, explain)
--Testcase 922:
EXPLAIN VERBOSE
SELECT sum(value3),tan(sum(value3)) FROM s3;

-- select tan as nest function with agg (pushdown, result)
--Testcase 923:
SELECT sum(value3),tan(sum(value3)) FROM s3;

-- select tan as nest with log2 (pushdown, explain)
--Testcase 924:
EXPLAIN VERBOSE
SELECT value1, tan(log2(value1)),tan(log2(1/value1)) FROM s3;

-- select tan as nest with log2 (pushdown, result)
--Testcase 925:
SELECT value1, tan(log2(value1)),tan(log2(1/value1)) FROM s3;

-- select tan with non pushdown func and explicit constant (explain)
--Testcase 926:
EXPLAIN VERBOSE
SELECT value1, tan(value3), pi(), 4.1 FROM s3;

-- select tan with non pushdown func and explicit constant (result)
--Testcase 927:
SELECT value1, tan(value3), pi(), 4.1 FROM s3;

-- select tan with order by (explain)
--Testcase 928:
EXPLAIN VERBOSE
SELECT value1, tan(1-value3) FROM s3 ORDER BY tan(1-value3);

-- select tan with order by (result)
--Testcase 929:
SELECT value1, tan(1-value3) FROM s3 ORDER BY tan(1-value3);

-- select tan with order by index (result)
--Testcase 930:
SELECT value1, tan(1-value3) FROM s3 ORDER BY 2,1;

-- select tan with order by index (result)
--Testcase 931:
SELECT value1, tan(1-value3) FROM s3 ORDER BY 1,2;

-- select tan with group by (explain)
--Testcase 932:
EXPLAIN VERBOSE
SELECT value1, tan(1-value3) FROM s3 GROUP BY value1, tan(1-value3);

-- select tan with group by (result)
--Testcase 933:
SELECT value1, tan(1-value3) FROM s3 GROUP BY value1, tan(1-value3);

-- select tan with group by index (result)
--Testcase 934:
SELECT value1, tan(1-value3) FROM s3 GROUP BY 2,1;

-- select tan with group by index (result)
--Testcase 935:
SELECT value1, tan(1-value3) FROM s3 GROUP BY 1,2;

-- select tan with group by having (explain)
--Testcase 936:
EXPLAIN VERBOSE
SELECT value1, tan(1-value3) FROM s3 GROUP BY value1, tan(1-value3) HAVING tan(avg(value1)) > 0;

-- select tan with group by having (result)
--Testcase 937:
SELECT value1, tan(1-value3) FROM s3 GROUP BY value1, tan(1-value3) HAVING tan(avg(value1)) > 0;

-- select tan with group by index having (result)
--Testcase 938:
SELECT value1, tan(1-value3) FROM s3 GROUP BY 2,1 HAVING tan(1-value3) > 0;

-- select tan with group by index having (result)
--Testcase 939:
SELECT value1, tan(1-value3) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- select tan and as
--Testcase 940:
SELECT value1, tan(value3) as tan1 FROM s3;

-- round()

--Testcase 941:
EXPLAIN VERBOSE
SELECT round(value1), round(value3) FROM s3;

--Testcase 942:
SELECT round(value1), round(value3) FROM s3;

--Testcase 943:
EXPLAIN VERBOSE
SELECT round(value1), round(abs(value3)) FROM s3;

--Testcase 944:
SELECT round(value1), round(abs(value3)) FROM s3;

--Testcase 945:
EXPLAIN VERBOSE
SELECT round(abs(value2), 2) FROM s3;

--Testcase 946:
SELECT round(abs(value2), 2) FROM s3;

--Testcase 947:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE round(abs(value2), 2) = 100.00;

--Testcase 948:
SELECT * FROM s3 WHERE round(abs(value2), 2) = 100.00;

--Testcase 949:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE round(value1) = 1;

--Testcase 950:
SELECT * FROM s3 WHERE round(value1) = 1;

--Testcase 951:
EXPLAIN VERBOSE
SELECT * FROM s3 WHERE round(value3) = -1;

--Testcase 952:
SELECT * FROM s3 WHERE round(value3) = -1;

-- select convert (stub function, explain)
--Testcase 953:
EXPLAIN VERBOSE
SELECT convert(value1, 'decimal(1)'), convert(value2, 'decimal(10, 2)'), convert(id, 'YEAR'), convert(value4, 'binary(1)')::bytea FROM s3;

-- select convert (stub function, result)
--Testcase 954:
SELECT convert(value1, 'decimal(1)'), convert(value2, 'decimal(10, 2)'), convert(id, 'YEAR'), convert(value4, 'binary(1)')::bytea FROM s3;

-- select convert (stub function, not pushdown constraints, explain)
--Testcase 955:
EXPLAIN VERBOSE
SELECT convert(value1, 'decimal(1)'), convert(value2, 'decimal(10, 2)'), convert(id, 'YEAR'), convert(value4, 'binary(1)')::bytea FROM s3 WHERE to_hex(value2) != '64';

-- select convert (stub function, not pushdown constraints, result)
--Testcase 956:
SELECT convert(value1, 'decimal(1)'), convert(value2, 'decimal(10, 2)'), convert(id, 'YEAR'), convert(value4, 'binary(1)')::bytea FROM s3 WHERE to_hex(value2) != '64';

-- select convert (stub function, pushdown constraints, explain)
--Testcase 957:
EXPLAIN VERBOSE
SELECT convert(value1, 'decimal(1)'), convert(value2, 'decimal(10, 2)'), convert(id, 'YEAR'), convert(value4, 'binary(1)')::bytea FROM s3 WHERE value2 != 200;

-- select convert (stub function, pushdown constraints, result)
--Testcase 958:
SELECT convert(value1, 'decimal(1)'), convert(value2, 'decimal(10, 2)'), convert(id, 'YEAR'), convert(value4, 'binary(1)')::bytea FROM s3 WHERE value2 != 200;

-- select convert as nest function with agg (pushdown, explain)
--Testcase 959:
EXPLAIN VERBOSE
SELECT sum(id), convert(sum(id), 'YEAR') FROM s3;

-- select convert as nest function with agg (pushdown, result)
--Testcase 960:
SELECT sum(id), convert(sum(id), 'YEAR') FROM s3;

-- select convert as nest with log2 (pushdown, explain)
--Testcase 961:
EXPLAIN VERBOSE
SELECT convert(log2(value1), 'decimal(12,4)')::numeric, convert(log2(1/value1), 'decimal(12,4)')::numeric FROM s3;

-- select convert as nest with log2 (pushdown, result)
--Testcase 962:
SELECT convert(log2(value1), 'decimal(12,4)')::numeric, convert(log2(1/value1), 'decimal(12,4)')::numeric FROM s3;

-- select cast json_extract with type modifier (explain)
--Testcase 963:
EXPLAIN VERBOSE
SELECT convert(json_extract('{"a": "2000-01-01 12:02:01.123456"}', '$.a'), 'datetime(3)')::timestamp, convert(json_extract('{"a": "2000-01-01 12:02:01.123456"}', '$.a'), 'datetime(3)')::timestamptz, convert(json_extract('{"a": "12:10:20.123456"}', '$.a'), 'time(3)')::time, convert(json_extract('{"a": "12:10:20.123456"}', '$.a'), 'time(3)')::timetz FROM s3;

-- select cast json_extract with type modifier (result)
--Testcase 964:
SELECT convert(json_extract('{"a": "2000-01-01 12:02:01.123456"}', '$.a'), 'datetime(3)')::timestamp, convert(json_extract('{"a": "2000-01-01 12:02:01.123456"}', '$.a'), 'datetime(3)')::timestamptz, convert(json_extract('{"a": "12:10:20.123456"}', '$.a'), 'time(3)')::time, convert(json_extract('{"a": "12:10:20.123456"}', '$.a'), 'time(3)')::timetz FROM s3;

-- select cast json_extract with type modifier (explain)
--Testcase 965:
EXPLAIN VERBOSE
SELECT convert(json_extract('{"a": 100}', '$.a'), 'decimal(10,2)')::numeric, convert(json_extract('{"a": 10}', '$.a'), 'YEAR')::decimal, convert(json_unquote(json_extract('{"a": "1.123456"}', '$.a')), 'decimal(10, 3)')::numeric FROM s3;

-- select cast json_extract with type modifier (result)
--Testcase 966:
SELECT convert(json_extract('{"a": 100}', '$.a'), 'decimal(10,2)')::numeric, convert(json_extract('{"a": 10}', '$.a'), 'YEAR')::decimal, convert(json_unquote(json_extract('{"a": "1.123456"}', '$.a')), 'decimal(10, 3)')::numeric FROM s3;

-- select convert with non pushdown func and explicit constant (explain)
--Testcase 967:
EXPLAIN VERBOSE
SELECT convert(id, 'YEAR'), pi(), 4.1 FROM s3;

-- select convert with non pushdown func and explicit constant (result)
--Testcase 968:
SELECT convert(id, 'YEAR'), pi(), 4.1 FROM s3;

-- select convert with order by index (result)
--Testcase 969:
SELECT value1, convert(1.123456 - value1,'char(3)') FROM s3 order by 2,1;

-- select convert with order by index (result)
--Testcase 970:
SELECT value1, convert(1.123456 - value1,'char(3)') FROM s3 order by 1,2;

-- select convert and as
--Testcase 971:
SELECT convert(id, 'YEAR') as convert1 FROM s3;

--Testcase 972:
DROP FOREIGN TABLE s3;
--Testcase 973:
DROP FOREIGN TABLE s4;
-- full text search table
--Testcase 974:
CREATE FOREIGN TABLE ftextsearch(id int, content text) SERVER server1 OPTIONS(dbname 'mysql_fdw_regress', table_name 'ftextsearch');

-- text search (pushdown, explain)
--Testcase 975:
EXPLAIN VERBOSE
SELECT MATCH_AGAINST(content, 'success catches') AS score, content FROM ftextsearch WHERE MATCH_AGAINST(content, 'success catches','IN BOOLEAN MODE') != 0;

-- text search (pushdown, result)
--Testcase 976:
SELECT content FROM (
SELECT MATCH_AGAINST(content, 'success catches') AS score, content FROM ftextsearch WHERE MATCH_AGAINST(content, 'success catches','IN BOOLEAN MODE') != 0) AS t;

--Testcase 977:
DROP FOREIGN TABLE ftextsearch;

--Testcase 978:
CREATE FOREIGN TABLE s7(id int, tag1 text, value1 float, value2 int, value3 float, value4 int, value5 bit, str1 text, str2 text) SERVER server1 OPTIONS(dbname 'mysql_fdw_regress', table_name 's7');

-- ===================================================================
-- test BIT_XOR()
-- ===================================================================
-- select bit_xor (explain)
--Testcase 979:
EXPLAIN VERBOSE
SELECT bit_xor(id), bit_xor(tag1), bit_xor(value1), bit_xor(value2), bit_xor(value3), bit_xor(value4), bit_xor(value5), bit_xor(str1) FROM s7;
-- select bit_xor (result)
--Testcase 980:
SELECT bit_xor(id), bit_xor(tag1), bit_xor(value1), bit_xor(value2), bit_xor(value3), bit_xor(value4), bit_xor(value5), bit_xor(str1) FROM s7;

-- select bit_xor with group by (explain)
--Testcase 981:
EXPLAIN VERBOSE
SELECT tag1, bit_xor(value5) FROM s7 GROUP BY tag1;
-- select bit_xor with group by (result)
--Testcase 982:
SELECT tag1, bit_xor(value5) FROM s7 GROUP BY tag1;

-- select bit_xor with group by having (explain)
--Testcase 983:
EXPLAIN VERBOSE
SELECT id, bit_xor(value5) FROM s7 GROUP BY id, str1 HAVING bit_xor(value5) > 0::bit;
-- select bit_xor with group by having (result)
--Testcase 984:
SELECT id, bit_xor(value5) FROM s7 GROUP BY id, str1 HAVING bit_xor(value5) > 0::bit;

-- ===================================================================
-- test GROUP_CONCAT()
-- ===================================================================
-- select group_concat (explain)
--Testcase 985:
EXPLAIN VERBOSE
SELECT group_concat(id), group_concat(tag1), group_concat(value1), group_concat(value2), group_concat(value3), group_concat(str2) FROM s7;
-- select group_concat (result)
--Testcase 986:
SELECT group_concat(id), group_concat(tag1), group_concat(value1), group_concat(value2), group_concat(value3), group_concat(str2) FROM s7;

-- select group_concat (explain)
--Testcase 987:
EXPLAIN VERBOSE
SELECT group_concat(value1 + 1) FROM s7;
-- select group_concat with group by (result)
--Testcase 988:
SELECT group_concat(value1 + 1) FROM s7;

-- select group_concat with stub function (explain)
--Testcase 989:
EXPLAIN VERBOSE
SELECT id, group_concat(sqrt(value1)) FROM s7 GROUP BY id;
-- select group_concat with stub function (result)
--Testcase 990:
SELECT id, group_concat(sqrt(value1)) FROM s7 GROUP BY id;

-- select group_concat with group by (explain)
--Testcase 991:
EXPLAIN VERBOSE
SELECT id, group_concat(value3) FROM s7 GROUP BY 1;
-- select group_concat with group by(explain)
--Testcase 992:
SELECT id, group_concat(value3) FROM s7 GROUP BY 1;

-- select group_concat with group by having (explain)
--Testcase 993:
EXPLAIN VERBOSE
SELECT id, group_concat(value3) FROM s7 GROUP BY 1, value1 HAVING group_concat(value3) IS NOT NULL;
-- select group_concat with group by having (result)
--Testcase 994:
SELECT id, group_concat(value3) FROM s7 GROUP BY 1, value1 HAVING group_concat(value3) IS NOT NULL;

-- select group_concat with group by having (explain)
--Testcase 995:
EXPLAIN VERBOSE
SELECT id, group_concat(value3) FROM s7 GROUP BY 1, value1 HAVING group_concat(value3 + 1) IS NOT NULL;
-- select group_concat with group by having (result)
--Testcase 996:
SELECT id, group_concat(value3) FROM s7 GROUP BY 1, value1 HAVING group_concat(value3 + 1) IS NOT NULL;

-- select group_concat with group by having (explain)
--Testcase 997:
EXPLAIN VERBOSE
SELECT id, group_concat(value3) FROM s7 GROUP BY 1, value1 HAVING group_concat(abs(value3)) IS NOT NULL;
-- select group_concat with group by having (result)
--Testcase 998:
SELECT id, group_concat(value3) FROM s7 GROUP BY 1, value1 HAVING group_concat(abs(value3)) IS NOT NULL;

-- select group_concat with multiple argument by ROW() expression.
--Testcase 999:
EXPLAIN VERBOSE
SELECT group_concat((id, tag1, value2, str1, value5)) FROM s7;
--Testcase 1000:
SELECT group_concat((id, tag1, value2, str1, value5)) FROM s7;

-- select group_concat with multiple argument by ROW() expression and GROUP BY
--Testcase 1001:
EXPLAIN VERBOSE
SELECT group_concat((id, tag1, value2, str1, value5)) FROM s7 GROUP BY value2;
--Testcase 1002:
SELECT group_concat((id, tag1, value2, str1, value5)) FROM s7 GROUP BY value2;

-- select group_concat with single argument
--Testcase 1003:
EXPLAIN VERBOSE
SELECT group_concat(value1 ORDER BY value1) FROM s7;
--Testcase 1004:
SELECT group_concat(value1 ORDER BY value1) FROM s7;

-- select group_concat with single argument and ORDER BY
--Testcase 1005:
EXPLAIN VERBOSE
SELECT group_concat(value1 ORDER BY value1 ASC) FROM s7;
--Testcase 1006:
SELECT group_concat(value1 ORDER BY value1 ASC) FROM s7;

-- select group_concat with single argument and ORDER BY
--Testcase 1007:
EXPLAIN VERBOSE
SELECT group_concat(value1 ORDER BY value1 DESC) FROM s7;
--Testcase 1008:
SELECT group_concat(value1 ORDER BY value1 DESC) FROM s7;

-- ===================================================================
-- test GROUP_CONCAT(DISTINCT)
-- ===================================================================
-- select group_concat(DISTINCT) (explain)
--Testcase 1009:
EXPLAIN VERBOSE
SELECT group_concat(DISTINCT id), group_concat(DISTINCT tag1), group_concat(DISTINCT value1), group_concat(DISTINCT value2), group_concat(DISTINCT value3), group_concat(DISTINCT value5), group_concat(DISTINCT str2) FROM s7;
-- select group_concat(DISTINCT) (result)
--Testcase 1010:
SELECT group_concat(DISTINCT id), group_concat(DISTINCT tag1), group_concat(DISTINCT value1), group_concat(DISTINCT value2), group_concat(DISTINCT value3), group_concat(DISTINCT value5), group_concat(DISTINCT str2) FROM s7;

-- select group_concat(DISTINCT) (explain)
--Testcase 1011:
EXPLAIN VERBOSE
SELECT group_concat(DISTINCT (value1 + 1)) FROM s7;
-- select group_concat(DISTINCT) (result)
--Testcase 1012:
SELECT group_concat(DISTINCT (value1 + 1)) FROM s7;

-- select group_concat(DISTINCT) with group by (explain)
--Testcase 1013:
EXPLAIN VERBOSE
SELECT value2, group_concat(DISTINCT value3) FROM s7 GROUP BY value2;
-- select group_concat(DISTINCT) with group by (result)
--Testcase 1014:
SELECT value2, group_concat(DISTINCT value3) FROM s7 GROUP BY value2;

--Testcase 1015:
EXPLAIN VERBOSE
SELECT group_concat(DISTINCT (id, tag1, value2, str1, value5)) FROM s7;
--Testcase 1016:
SELECT group_concat(DISTINCT (id, tag1, value2, str1, value5)) FROM s7;

--Testcase 1017:
EXPLAIN VERBOSE
SELECT group_concat(DISTINCT (tag1, value2)) FROM s7;
--Testcase 1018:
SELECT group_concat(DISTINCT (tag1, value2)) FROM s7;

-- select group_concat(DISTINCT) multiple argument with group by (result)
--Testcase 1019:
SELECT value2, group_concat(DISTINCT (tag1, value3, value2)) FROM s7 GROUP BY value2;

-- select group_concat(DISTINCT) with stub function (explain)
--Testcase 1020:
EXPLAIN VERBOSE
SELECT id, group_concat(DISTINCT sqrt(value1)) FROM s7 GROUP BY id;
-- select group_concat(DISTINCT) with stub function (result)
--Testcase 1021:
SELECT id, group_concat(DISTINCT sqrt(value1)) FROM s7 GROUP BY id;

-- select group_concat(DISTINCT) with group by having (explain)
--Testcase 1022:
EXPLAIN VERBOSE
SELECT id, group_concat(DISTINCT value3) FROM s7 GROUP BY 1, value1 HAVING group_concat(DISTINCT value3) IS NOT NULL;
-- select group_concat(DISTINCT) with group by having (result)
--Testcase 1023:
SELECT id, group_concat(DISTINCT value3) FROM s7 GROUP BY 1, value1 HAVING group_concat(DISTINCT value3) IS NOT NULL;

-- select group_concat(DISTINCT) with group by having (explain)
--Testcase 1024:
EXPLAIN VERBOSE
SELECT id, group_concat(DISTINCT value3) FROM s7 GROUP BY 1, value1 HAVING group_concat(DISTINCT (value3 + 1)) IS NOT NULL;
-- select group_concat(DISTINCT) with group by having (result)
--Testcase 1025:
SELECT id, group_concat(DISTINCT value3) FROM s7 GROUP BY 1, value1 HAVING group_concat(DISTINCT (value3 + 1)) IS NOT NULL;

-- select group_concat(DISTINCT) with group by having (explain)
--Testcase 1026:
EXPLAIN VERBOSE
SELECT id, group_concat(DISTINCT value3) FROM s7 GROUP BY 1, value1 HAVING group_concat(DISTINCT abs(value3)) IS NOT NULL;
-- select group_concat(DISTINCT) with group by having (result)
--Testcase 1027:
SELECT id, group_concat(DISTINCT value3) FROM s7 GROUP BY 1, value1 HAVING group_concat(DISTINCT abs(value3)) IS NOT NULL;

-- ===================================================================
-- test COUNT()
-- ===================================================================
-- select count(*)
--Testcase 1028:
EXPLAIN VERBOSE
SELECT COUNT(*) FROM s7;
--Testcase 1029:
SELECT COUNT(*) FROM s7;

-- select COUNT(expr) [over_clause]
--Testcase 1030:
EXPLAIN VERBOSE
SELECT COUNT(tag1) FROM s7;
--Testcase 1031:
SELECT COUNT(tag1) FROM s7;

-- select COUNT(expr) [over_clause]
--Testcase 1032:
EXPLAIN VERBOSE
SELECT COUNT(tag1) FROM s7 GROUP BY tag1;
--Testcase 1033:
SELECT COUNT(tag1) FROM s7 GROUP BY tag1;

-- select COUNT(DISTINCT expr,[expr...])
--Testcase 1034:
EXPLAIN VERBOSE
SELECT COUNT(DISTINCT tag1) FROM s7;
--Testcase 1035:
SELECT COUNT(tag1) FROM s7 GROUP BY tag1;

-- select COUNT(DISTINCT expr,[expr...])
--Testcase 1036:
EXPLAIN VERBOSE
SELECT COUNT(DISTINCT (id, tag1, value2, str1, value5)) FROM s7;
--Testcase 1037:
SELECT COUNT(DISTINCT (id, tag1, value2, str1, value5)) FROM s7;

-- select COUNT(DISTINCT expr,[expr...])
--Testcase 1038:
EXPLAIN VERBOSE
SELECT COUNT(DISTINCT (tag1, value2)) FROM s7;
--Testcase 1039:
SELECT COUNT(DISTINCT (tag1, value2)) FROM s7;


-- ===================================================================
-- test JSON_ARRAYAGG()
-- ===================================================================
-- select json_agg (explain)
--Testcase 1040:
EXPLAIN VERBOSE
SELECT json_agg(id), json_agg(tag1), json_agg(value1), json_agg(value2), json_agg(value3), json_agg(value5), json_agg(str1) FROM s7;
-- select json_agg (result)
--Testcase 1041:
SELECT json_agg(id), json_agg(tag1), json_agg(value1), json_agg(value2), json_agg(value3), json_agg(value5), json_agg(str1) FROM s7;

-- select json_agg with group by (explain)
--Testcase 1042:
EXPLAIN VERBOSE
SELECT tag1, json_agg(value3) FROM s7 GROUP BY tag1;
-- select json_agg with group by (result)
--Testcase 1043:
SELECT tag1, json_agg(value3) FROM s7 GROUP BY tag1;

-- select json_agg with group by (explain)
--Testcase 1044:
EXPLAIN VERBOSE
SELECT tag1, json_agg(value3 + 1) FROM s7 GROUP BY tag1;
-- select json_agg with group by (result)
--Testcase 1045:
SELECT tag1, json_agg(value3 + 1) FROM s7 GROUP BY tag1;

-- select json_agg with stub function (explain)
--Testcase 1046:
EXPLAIN VERBOSE
SELECT tag1, json_agg(abs(value3)) FROM s7 GROUP BY tag1;
-- select json_agg with stub function (result)
--Testcase 1047:
SELECT tag1, json_agg(abs(value3)) FROM s7 GROUP BY tag1;

-- select json_agg with group by having (explain)
--Testcase 1048:
EXPLAIN VERBOSE
SELECT tag1, json_agg(value3) FROM s7 GROUP BY 1, value1 HAVING json_agg(value3) IS NOT NULL;
-- select json_agg with group by having (result)
--Testcase 1049:
SELECT tag1, json_agg(value3) FROM s7 GROUP BY 1, value1 HAVING json_agg(value3) IS NOT NULL;

-- select json_agg with group by having (explain)
--Testcase 1050:
EXPLAIN VERBOSE
SELECT tag1, json_agg(value3 + 1) FROM s7 GROUP BY 1, value1 HAVING json_agg(value3 + 1) IS NOT NULL;
-- select json_agg with group by having (result)
--Testcase 1051:
SELECT tag1, json_agg(value3 + 1) FROM s7 GROUP BY 1, value1 HAVING json_agg(value3 + 1) IS NOT NULL;

-- select json_agg with group by having (explain)
--Testcase 1052:
EXPLAIN VERBOSE
SELECT tag1, json_agg(abs(value3)) FROM s7 GROUP BY 1, value1 HAVING json_agg(abs(value3)) IS NOT NULL;
-- select json_agg with group by having (result)
--Testcase 1053:
SELECT tag1, json_agg(abs(value3)) FROM s7 GROUP BY 1, value1 HAVING json_agg(abs(value3)) IS NOT NULL;

-- ===================================================================
-- test JSON_OBJECTAGG()
-- ===================================================================
-- select json_objectagg (explain)
--Testcase 1054:
EXPLAIN VERBOSE
SELECT json_object_agg(tag1, str1), json_object_agg(id, value4) FROM s7;
-- select json_objectagg (result)
--Testcase 1055:
SELECT json_object_agg(tag1, str1), json_object_agg(id, value4) FROM s7;

-- select json_objectagg with group by (explain)
--Testcase 1056:
EXPLAIN VERBOSE
SELECT id, json_object_agg(tag1, str1) FROM s7 GROUP BY id;
-- select json_objectagg with group by (result)
--Testcase 1057:
SELECT id, json_object_agg(tag1, str1) FROM s7 GROUP BY id;

-- select json_objectagg with group by (explain)
--Testcase 1058:
EXPLAIN VERBOSE
SELECT id, json_object_agg(tag1, value2 + 1) FROM s7 GROUP BY id;
-- select json_objectagg with group by (result)
--Testcase 1059:
SELECT id, json_object_agg(tag1, value2 + 1) FROM s7 GROUP BY id;

-- select json_objectagg with stub function (explain)
--Testcase 1060:
EXPLAIN VERBOSE
SELECT id, json_object_agg(tag1, abs(value2)) FROM s7 GROUP BY id;
-- select json_objectagg with stub function (result)
--Testcase 1061:
SELECT id, json_object_agg(tag1, abs(value2)) FROM s7 GROUP BY id;

-- select json_objectagg with group by having (explain)
--Testcase 1062:
EXPLAIN VERBOSE
SELECT id, json_object_agg(tag1, str1) FROM s7 GROUP BY 1, value1 HAVING json_object_agg(tag1, str1) IS NOT NULL;
-- select json_objectagg with group by having (result)
--Testcase 1063:
SELECT id, json_object_agg(tag1, str1) FROM s7 GROUP BY 1, value1 HAVING json_object_agg(tag1, str1) IS NOT NULL;

-- select json_objectagg with group by having (explain)
--Testcase 1064:
EXPLAIN VERBOSE
SELECT id, json_object_agg(tag1, str1) FROM s7 GROUP BY 1, value1 HAVING json_object_agg(tag1, abs(value2 + 1)) IS NOT NULL;
-- select json_objectagg with group by having (result)
--Testcase 1065:
SELECT id, json_object_agg(tag1, str1) FROM s7 GROUP BY 1, value1 HAVING json_object_agg(tag1, abs(value2 + 1)) IS NOT NULL;

-- ===================================================================
-- test STD()
-- ===================================================================
-- select std (explain)
--Testcase 1066:
EXPLAIN VERBOSE
SELECT std(id), std(tag1), std(value1), std(value2), std(value3), std(str1) FROM s7;
-- select std (result)
--Testcase 1067:
SELECT std(id), std(tag1), std(value1), std(value2), std(value3), std(str1) FROM s7;

-- select std with group by (explain)
--Testcase 1068:
EXPLAIN VERBOSE
SELECT tag1, std(value4) FROM s7 GROUP BY tag1;
-- select std with group by (result)
--Testcase 1069:
SELECT tag1, std(value4) FROM s7 GROUP BY tag1;

-- select std with group by (explain)
--Testcase 1070:
EXPLAIN VERBOSE
SELECT tag1, std(value4 + 1) FROM s7 GROUP BY tag1;
-- select std with group by (result)
--Testcase 1071:
SELECT tag1, std(value4 + 1) FROM s7 GROUP BY tag1;

-- select std with stub function (explain)
--Testcase 1072:
EXPLAIN VERBOSE
SELECT tag1, std(abs(value4 + 1)) FROM s7 GROUP BY tag1;
-- select std with stub function (result)
--Testcase 1073:
SELECT tag1, std(abs(value4 + 1)) FROM s7 GROUP BY tag1;

-- select std with group by having (explain)
--Testcase 1074:
EXPLAIN VERBOSE
SELECT tag1, std(value4) FROM s7 GROUP BY 1 HAVING std(value4) > 0;
-- select std with group by having (result)
--Testcase 1075:
SELECT tag1, std(value4) FROM s7 GROUP BY 1 HAVING std(value4) > 0;

-- select std with group by having (explain)
--Testcase 1076:
EXPLAIN VERBOSE
SELECT tag1, std(value4) FROM s7 GROUP BY 1 HAVING std(abs(value4 + 1)) > 0;
-- select std with group by having (result)
--Testcase 1077:
SELECT tag1, std(value4) FROM s7 GROUP BY 1 HAVING std(abs(value4 + 1)) > 0;

--Testcase 1078:
DROP FOREIGN TABLE s7;

--Testcase 1079:
CREATE FOREIGN TABLE s5(id int, b bit, b8 bit(8), b64 bit(64)) SERVER server1 OPTIONS(dbname 'mysql_fdw_regress', table_name 's5');

--Testcase 1080:
SELECT * FROM s5;

-- select bit_and, bit_or (pushdown, explain)
--Testcase 1081:
EXPLAIN VERBOSE
SELECT bit_and(b), bit_and(b8), bit_or(b), bit_or(b8), bit_and(b64), bit_or(b64) FROM s5;

-- select bit_and, bit_or (pushdown, result)
--Testcase 1082:
SELECT bit_and(b), bit_and(b8), bit_or(b), bit_or(b8), bit_and(b64), bit_or(b64) FROM s5;

--Testcase 1083:
CREATE FOREIGN TABLE s3(id int, tag1 text, value1 float, value2 int, value3 float, value4 int, str1 text, str2 text) SERVER server1 OPTIONS(dbname 'mysql_fdw_regress', table_name 's3');

-- ===============================================================================
-- test ascii()
-- ===============================================================================
-- select ascii (stub function, explain)
--Testcase 1084:
EXPLAIN VERBOSE
SELECT ascii(tag1), ascii(str1), ascii(str2) FROM s3;
-- select ascii (stub function, result)
--Testcase 1085:
SELECT ascii(tag1), ascii(str1), ascii(str2) FROM s3;

-- select ascii (stub function, pushdown constraints, explain)
--Testcase 1086:
EXPLAIN VERBOSE
SELECT ascii(tag1), ascii(str1), ascii(str2) FROM s3 WHERE value2 != 100;
-- select ascii (stub function, pushdown constraints, result)
--Testcase 1087:
SELECT ascii(tag1), ascii(str1), ascii(str2) FROM s3 WHERE value2 != 100;

-- select ascii (stub function, ascii in constraints, explain)
--Testcase 1088:
EXPLAIN VERBOSE
SELECT ascii(tag1), ascii(str1), ascii(str2) FROM s3 WHERE ascii(str1) <= 97;
-- select ascii (stub function, ascii in constraints, explain)
--Testcase 1089:
SELECT ascii(tag1), ascii(str1), ascii(str2) FROM s3 WHERE ascii(str1) <= 97;

-- select ascii with non pushdown func and explicit constant (explain)
--Testcase 1090:
EXPLAIN VERBOSE
SELECT ascii(str1), pi(), 4.1 FROM s3;
-- select ascii with non pushdown func and explicit constant (result)
--Testcase 1091:
SELECT ascii(str1), pi(), 4.1 FROM s3;

-- select ascii with order by (explain)
--Testcase 1092:
EXPLAIN VERBOSE
SELECT value1, ascii(str2) FROM s3 ORDER BY ascii(str2);
-- select ascii with order by (result)
--Testcase 1093:
SELECT value1, ascii(str2) FROM s3 ORDER BY ascii(str2);

-- select ascii with order by index (result)
--Testcase 1094:
SELECT value1, ascii(str2) FROM s3 ORDER BY 2,1;

-- select ascii with group by (explain)
--Testcase 1095:
EXPLAIN VERBOSE
SELECT count(value1), ascii(str1) FROM s3 GROUP BY ascii(str1);
-- select ascii with group by (result)
--Testcase 1096:
SELECT count(value1), ascii(str1) FROM s3 GROUP BY ascii(str1);

-- select ascii with group by index (result)
--Testcase 1097:
SELECT value1, ascii(str1) FROM s3 GROUP BY 2,1;

-- select ascii with group by having (explain)
--Testcase 1098:
EXPLAIN VERBOSE
SELECT count(value1), ascii(str1) FROM s3 GROUP BY ascii(str1) HAVING ascii(str1) IS NOT NULL;
-- select ascii with group by having (explain)
--Testcase 1099:
SELECT count(value1), ascii(str1) FROM s3 GROUP BY ascii(str1) HAVING ascii(str1) IS NOT NULL;

-- select ascii with group by index having (result)
--Testcase 1100:
SELECT value1, ascii(str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test bin()
-- ===============================================================================
-- select bin (stub function, explain)
--Testcase 1101:
EXPLAIN VERBOSE
SELECT id, bin(id), bin(value2), bin(value4) FROM s3;
-- select bin (stub function, result)
--Testcase 1102:
SELECT id, bin(id), bin(value2), bin(value4) FROM s3;

-- select bin (stub function, pushdown constraints, explain)
--Testcase 1103:
EXPLAIN VERBOSE
SELECT bin(id), bin(value2) FROM s3 WHERE value2 != 200;
-- select bin (stub function, pushdown constraints, result)
--Testcase 1104:
SELECT bin(id), bin(value2) FROM s3 WHERE value2 != 200;

-- select bin (stub function, bin in constraints, explain)
--Testcase 1105:
EXPLAIN VERBOSE
SELECT bin(id), bin(value2) FROM s3 WHERE bin(value2) != '1100100';
-- select bin (stub function, bin in constraints, explain)
--Testcase 1106:
SELECT bin(id), bin(value2) FROM s3 WHERE bin(value2) != '1100100';

--select bin as nest function with agg (explain)
--Testcase 1107:
EXPLAIN VERBOSE
SELECT sum(id), bin(sum(value2)) FROM s3;
--select bin as nest function with agg (result)
--Testcase 1108:
SELECT sum(id), bin(sum(value2)) FROM s3;

-- select bin with non pushdown func and explicit constant (explain)
--Testcase 1109:
EXPLAIN VERBOSE
SELECT bin(value2), pi(), 4.1 FROM s3;
-- select bin with non pushdown func and explicit constant (explain)
--Testcase 1110:
SELECT bin(value2), pi(), 4.1 FROM s3;

-- select bin with order by (explain)
--Testcase 1111:
EXPLAIN VERBOSE
SELECT id, bin(value2) FROM s3 ORDER BY bin(value2);
-- select bin with order by (result)
--Testcase 1112:
SELECT id, bin(value2) FROM s3 ORDER BY bin(value2);

-- select bin with order by index (result)
--Testcase 1113:
SELECT value1, bin(value2) FROM s3 ORDER BY 2,1;
-- select bin with order by index (result)
--Testcase 1114:
SELECT value1, bin(value2) FROM s3 ORDER BY 1,2;

-- select bin with group by (explain)
--Testcase 1115:
EXPLAIN VERBOSE
SELECT count(value1), bin(value2) FROM s3 GROUP BY bin(value2);
-- select bin with group by (result)
--Testcase 1116:
SELECT count(value1), bin(value2) FROM s3 GROUP BY bin(value2);

-- select bin with group by index (result)
--Testcase 1117:
SELECT value1, bin(value2) FROM s3 GROUP BY 2,1;

-- select bin with group by having (explain)
--Testcase 1118:
EXPLAIN VERBOSE
SELECT value1, bin(value2 - 1) FROM s3 GROUP BY 1, bin(value2 - 1) HAVING value1 > 1;
-- select bin with group by having (result)
--Testcase 1119:
SELECT value1, bin(value2 - 1) FROM s3 GROUP BY 1, bin(value2 - 1) HAVING value1 > 1;

-- select bin with group by index having (result)
--Testcase 1120:
SELECT value1, bin(value2 - 1) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test bit_length()
-- ===============================================================================
-- select bit_length (stub function, explain)
--Testcase 1121:
EXPLAIN VERBOSE
SELECT bit_length(tag1), bit_length(str1), bit_length(str2) FROM s3;
-- select bit_length (stub function, result)
--Testcase 1122:
SELECT bit_length(tag1), bit_length(str1), bit_length(str2) FROM s3;

-- select bit_length (stub function, pushdown constraints, explain)
--Testcase 1123:
EXPLAIN VERBOSE
SELECT bit_length(tag1), bit_length(str1), bit_length(str2) FROM s3 WHERE value2 != 100;
-- select bit_length (stub function, pushdown constraints, result)
--Testcase 1124:
SELECT bit_length(tag1), bit_length(str1), bit_length(str2) FROM s3 WHERE value2 != 100;

-- select bit_length (stub function, bit_length in constraints, explain)
--Testcase 1125:
EXPLAIN VERBOSE
SELECT bit_length(tag1), bit_length(str1), bit_length(str2) FROM s3 WHERE value2 != 200;
-- select bit_length (stub function, bit_length in constraints, explain)
--Testcase 1126:
SELECT bit_length(tag1), bit_length(str1), bit_length(str2) FROM s3 WHERE value2 != 200;

-- select bit_length with non pushdown func and explicit constant (explain)
--Testcase 1127:
EXPLAIN VERBOSE
SELECT bit_length(str1), pi(), 4.1 FROM s3;
-- select bit_length with non pushdown func and explicit constant (result)
--Testcase 1128:
SELECT bit_length(str1), pi(), 4.1 FROM s3;

-- select bit_length with order by (explain)
--Testcase 1129:
EXPLAIN VERBOSE
SELECT value1, bit_length(str2) FROM s3 ORDER BY bit_length(str2);
-- select bit_length with order by (result)
--Testcase 1130:
SELECT value1, bit_length(str2) FROM s3 ORDER BY bit_length(str2);

-- select bit_length with order by index (result)
--Testcase 1131:
SELECT value1, bit_length(str2) FROM s3 ORDER BY 2,1;

-- select bit_length with group by (explain)
--Testcase 1132:
EXPLAIN VERBOSE
SELECT count(value1), bit_length(str1) FROM s3 GROUP BY bit_length(str1);
-- select bit_length with group by (result)
--Testcase 1133:
SELECT count(value1), bit_length(str1) FROM s3 GROUP BY bit_length(str1);

-- select bit_length with group by index (result)
--Testcase 1134:
SELECT value1, bit_length(str1) FROM s3 GROUP BY 2,1;

-- select bit_length with group by having (explain)
--Testcase 1135:
EXPLAIN VERBOSE
SELECT count(value1), bit_length(str1) FROM s3 GROUP BY bit_length(str1), str1 HAVING bit_length(str1) IS NOT NULL;
-- select bit_length with group by having (explain)
--Testcase 1136:
SELECT count(value1), bit_length(str1) FROM s3 GROUP BY bit_length(str1), str1 HAVING bit_length(str1) IS NOT NULL;

-- select bit_length with group by index having (result)
--Testcase 1137:
SELECT value1, bit_length(str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test char()
-- ===============================================================================
-- select char (stub function, explain)
--Testcase 1138:
EXPLAIN VERBOSE
SELECT mysql_char(value2), mysql_char(value4) FROM s3;
-- select char (stub function, result)
--Testcase 1139:
SELECT mysql_char(value2), mysql_char(value4) FROM s3;

-- select char (stub function, not pushdown constraints, explain)
--Testcase 1140:
EXPLAIN VERBOSE
SELECT value1, mysql_char(value2) FROM s3 WHERE to_hex(value2) = '64';
-- select char (stub function, not pushdown constraints, result)
--Testcase 1141:
SELECT value1, mysql_char(value2) FROM s3 WHERE to_hex(value2) = '64';

-- select char (stub function, pushdown constraints, explain)
--Testcase 1142:
EXPLAIN VERBOSE
SELECT value1, mysql_char(value2) FROM s3 WHERE value2 != 200;
-- select char (stub function, pushdown constraints, result)
--Testcase 1143:
SELECT value1, mysql_char(value2) FROM s3 WHERE value2 != 200;

-- select char with non pushdown func and explicit constant (explain)
--Testcase 1144:
EXPLAIN VERBOSE
SELECT mysql_char(value2), pi(), 4.1 FROM s3;
-- select char with non pushdown func and explicit constant (result)
--Testcase 1145:
SELECT mysql_char(value2), pi(), 4.1 FROM s3;

-- select char with order by (explain)
--Testcase 1146:
EXPLAIN VERBOSE
SELECT value1, mysql_char(value2) FROM s3 ORDER BY mysql_char(value2);
-- select char with order by (result)
--Testcase 1147:
SELECT value1, mysql_char(value2) FROM s3 ORDER BY mysql_char(value2);

-- select char with order by index (result)
--Testcase 1148:
SELECT value1, mysql_char(value2) FROM s3 ORDER BY 1,2;

-- select char with group by (explain)
--Testcase 1149:
EXPLAIN VERBOSE
SELECT value1, mysql_char(value2) FROM s3 GROUP BY value1, mysql_char(value2);
-- select char with group by (result)
--Testcase 1150:
SELECT value1, mysql_char(value2) FROM s3 GROUP BY value1, mysql_char(value2);

-- select char with group by index (result)
--Testcase 1151:
SELECT value1, mysql_char(value2) FROM s3 GROUP BY 2,1;

-- select char with group by having (explain)
--Testcase 1152:
EXPLAIN VERBOSE
SELECT value1, mysql_char(value2) FROM s3 GROUP BY mysql_char(value2), value2, value1 HAVING mysql_char(value2) IS NOT NULL;
-- select char with group by having (result)
--Testcase 1153:
SELECT value1, mysql_char(value2) FROM s3 GROUP BY mysql_char(value2), value2, value1 HAVING mysql_char(value2) IS NOT NULL;

-- select char with group by index having (result)
--Testcase 1154:
SELECT value1, mysql_char(value2) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test char_length()
-- ===============================================================================
-- select char_length (stub function, explain)
--Testcase 1155:
EXPLAIN VERBOSE
SELECT char_length(tag1), char_length(str1), char_length(str2) FROM s3;
-- select char_length (stub function, result)
--Testcase 1156:
SELECT char_length(tag1), char_length(str1), char_length(str2) FROM s3;

-- select char_length (stub function, not pushdown constraints, explain)
--Testcase 1157:
EXPLAIN VERBOSE
SELECT id, char_length(str1) FROM s3 WHERE to_hex(value2) = '64';
-- select char_length (stub function, not pushdown constraints, explain)
--Testcase 1158:
SELECT id, char_length(str1) FROM s3 WHERE to_hex(value2) = '64';

-- select char_length (stub function, char_length in constraints, explain)
--Testcase 1159:
EXPLAIN VERBOSE
SELECT id, char_length(str1) FROM s3 WHERE char_length(str1) > 0;
-- select char_length (stub function, char_length in constraints, result)
--Testcase 1160:
SELECT id, char_length(str1) FROM s3 WHERE char_length(str1) > 0;

-- select char_length with non pushdown func and explicit constant (explain)
--Testcase 1161:
EXPLAIN VERBOSE
SELECT char_length(str1), pi(), 4.1 FROM s3;
-- select char_length with non pushdown func and explicit constant (result)
--Testcase 1162:
SELECT char_length(str1), pi(), 4.1 FROM s3;

-- select char_length with order by (explain)
--Testcase 1163:
EXPLAIN VERBOSE
SELECT value1, char_length(str1) FROM s3 ORDER BY char_length(str1), 1 DESC;
-- select char_length with order by (result)
--Testcase 1164:
SELECT value1, char_length(str1) FROM s3 ORDER BY char_length(str1), 1 DESC;

-- select char_length with group by (explain)
--Testcase 1165:
EXPLAIN VERBOSE
SELECT count(value1), char_length(str1) FROM s3 GROUP BY char_length(str1);
-- select char_length with group by (result)
--Testcase 1166:
SELECT count(value1), char_length(str1) FROM s3 GROUP BY char_length(str1);

-- select char_length with group by index (result)
--Testcase 1167:
SELECT value1, char_length(str1) FROM s3 GROUP BY 2,1;

-- select char_length with group by having (explain)
--Testcase 1168:
EXPLAIN VERBOSE
SELECT count(value1), char_length(str1) FROM s3 GROUP BY char_length(str1), str1 HAVING char_length(str1) > 0;
-- select char_length with group by having (result)
--Testcase 1169:
SELECT count(value1), char_length(str1) FROM s3 GROUP BY char_length(str1), str1 HAVING char_length(str1) > 0;

-- select char_length with group by index having (result)
--Testcase 1170:
SELECT value1, char_length(str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test character_length()
-- ===============================================================================
-- select character_length (stub function, explain)
--Testcase 1171:
EXPLAIN VERBOSE
SELECT character_length(tag1), character_length(str1), character_length(str2) FROM s3;
-- select character_length (stub function, result)
--Testcase 1172:
SELECT character_length(tag1), character_length(str1), character_length(str2) FROM s3;

-- select character_length (stub function, not pushdown constraints, explain)
--Testcase 1173:
EXPLAIN VERBOSE
SELECT id, character_length(str1) FROM s3 WHERE to_hex(value2) = '64';
-- select character_length (stub function, not pushdown constraints, explain)
--Testcase 1174:
SELECT id, character_length(str1) FROM s3 WHERE to_hex(value2) = '64';

-- select character_length (stub function, character_length in constraints, explain)
--Testcase 1175:
EXPLAIN VERBOSE
SELECT id, character_length(str1) FROM s3 WHERE character_length(str1) > 0;
-- select character_length (stub function, character_length in constraints, result)
--Testcase 1176:
SELECT id, character_length(str1) FROM s3 WHERE character_length(str1) > 0;

-- select character_length with non pushdown func and explicit constant (explain)
--Testcase 1177:
EXPLAIN VERBOSE
SELECT character_length(str1), pi(), 4.1 FROM s3;
-- select character_length with non pushdown func and explicit constant (result)
--Testcase 1178:
SELECT character_length(str1), pi(), 4.1 FROM s3;

-- select character_length with order by (explain)
--Testcase 1179:
EXPLAIN VERBOSE
SELECT value1, character_length(str1) FROM s3 ORDER BY character_length(str1), 1 DESC;
-- select character_length with order by (result)
--Testcase 1180:
SELECT value1, character_length(str1) FROM s3 ORDER BY character_length(str1), 1 DESC;

-- select character_length with group by (explain)
--Testcase 1181:
EXPLAIN VERBOSE
SELECT count(value1), character_length(str1) FROM s3 GROUP BY character_length(str1);
-- select character_length with group by (result)
--Testcase 1182:
SELECT count(value1), character_length(str1) FROM s3 GROUP BY character_length(str1);

-- select character_length with group by index (result)
--Testcase 1183:
SELECT value1, character_length(str1) FROM s3 GROUP BY 2,1;

-- select character_length with group by having (explain)
--Testcase 1184:
EXPLAIN VERBOSE
SELECT count(value1), character_length(str1) FROM s3 GROUP BY character_length(str1), str1 HAVING character_length(str1) > 0;
-- select character_length with group by having (result)
--Testcase 1185:
SELECT count(value1), character_length(str1) FROM s3 GROUP BY character_length(str1), str1 HAVING character_length(str1) > 0;

-- select character_length with group by index having (result)
--Testcase 1186:
SELECT value1, character_length(str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test concat()
-- ===============================================================================
-- select concat (stub function, explain)
--Testcase 1187:
EXPLAIN VERBOSE
SELECT concat(id), concat(tag1), concat(value1), concat(value2), concat(str1) FROM s3;
-- select concat (stub function, result)
--Testcase 1188:
SELECT concat(id), concat(tag1), concat(value1), concat(value2), concat(str1) FROM s3;

-- select concat (stub function, pushdown constraints, explain)
--Testcase 1189:
EXPLAIN VERBOSE
SELECT id, concat(str1, str2) FROM s3 WHERE value2 != 100;
-- select concat (stub function, pushdown constraints, result)
--Testcase 1190:
SELECT id, concat(str1, str2) FROM s3 WHERE value2 != 100;

-- select concat (stub function, concat in constraints, explain)
--Testcase 1191:
EXPLAIN VERBOSE
SELECT id, concat(str1, str2) FROM s3 WHERE concat(str1, str2) != 'XYZ';
-- select concat (stub function, concat in constraints, explain)
--Testcase 1192:
SELECT id, concat(str1, str2) FROM s3 WHERE concat(str1, str2) != 'XYZ';

-- select concat as nest function with agg (pushdown, explain)
--Testcase 1193:
EXPLAIN VERBOSE
SELECT id, concat(sum(value1), str1) FROM s3 GROUP BY id, str1;
-- select concat as nest function with agg (pushdown, result)
--Testcase 1194:
SELECT id, concat(sum(value1), str1) FROM s3 GROUP BY id, str1;

-- select concat with non pushdown func and explicit constant (explain)
--Testcase 1195:
EXPLAIN VERBOSE
SELECT concat(str1, str2), pi(), 4.1 FROM s3;
-- select concat with non pushdown func and explicit constant (result)
--Testcase 1196:
SELECT concat(str1, str2), pi(), 4.1 FROM s3;

-- select concat with order by (explain)
--Testcase 1197:
EXPLAIN VERBOSE
SELECT value1, concat(value2, str2) FROM s3 ORDER BY concat(value2, str2);
-- select concat with order by (result)
--Testcase 1198:
SELECT value1, concat(value2, str2) FROM s3 ORDER BY concat(value2, str2);

-- select concat with order by index (result)
--Testcase 1199:
SELECT value1, concat(value2, str2) FROM s3 ORDER BY 2,1;

-- select concat with group by (explain)
--Testcase 1200:
EXPLAIN VERBOSE
SELECT count(value1), concat(str1, str2) FROM s3 GROUP BY concat(str1, str2);
-- select concat with group by (result)
--Testcase 1201:
SELECT count(value1), concat(str1, str2) FROM s3 GROUP BY concat(str1, str2);

-- select concat with group by index (result)
--Testcase 1202:
SELECT value1, concat(str1, str2) FROM s3 GROUP BY 2,1;

-- select concat with group by having (explain)
--Testcase 1203:
EXPLAIN VERBOSE
SELECT count(value1), concat(str1, str2) FROM s3 GROUP BY concat(str1, str2) HAVING concat(str1, str2) IS NOT NULL;
-- select concat with group by having (explain)
--Testcase 1204:
SELECT count(value1), concat(str1, str2) FROM s3 GROUP BY concat(str1, str2) HAVING concat(str1, str2) IS NOT NULL;

-- select concat with group by index having (result)
--Testcase 1205:
SELECT value1, concat(str1, str2, value1, value2) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test concat_ws()
-- ===============================================================================
-- select concat_ws (stub function, explain)
--Testcase 1206:
EXPLAIN VERBOSE
SELECT concat_ws(',', str2, str1, tag1, value2) FROM s3;
-- select concat_ws (stub function, explain)
--Testcase 1207:
SELECT concat_ws(',', str2, str1, tag1, value2) FROM s3;

-- select concat_ws (stub function, not pushdown constraints, explain)
--Testcase 1208:
EXPLAIN VERBOSE
SELECT value1, concat_ws('.', str2, str1) FROM s3 WHERE to_hex(value2) = '64';
-- select concat_ws (stub function, not pushdown constraints, result)
--Testcase 1209:
SELECT value1, concat_ws('.', str2, str1) FROM s3 WHERE to_hex(value2) = '64';

-- select concat_ws (stub function, pushdown constraints, explain)
--Testcase 1210:
EXPLAIN VERBOSE
SELECT value1, concat_ws('.', str2, str1) FROM s3 WHERE value2 != 200;
-- select concat_ws (stub function, pushdown constraints, result)
--Testcase 1211:
SELECT value1, concat_ws('.', str2, str1) FROM s3 WHERE value2 != 200;

-- select concat_ws with non pushdown func and explicit constant (explain)
--Testcase 1212:
EXPLAIN VERBOSE
SELECT concat_ws('.', str2, str1), pi(), 4.1 FROM s3;
-- select concat_ws with non pushdown func and explicit constant (result)
--Testcase 1213:
SELECT concat_ws('.', str2, str1), pi(), 4.1 FROM s3;

-- select concat_ws with order by (explain)
--Testcase 1214:
EXPLAIN VERBOSE
SELECT value1, concat_ws('.', str2, str1) FROM s3 ORDER BY concat_ws('.', str2, str1);
-- select concat_ws with order by (result)
--Testcase 1215:
SELECT value1, concat_ws('.', str2, str1) FROM s3 ORDER BY concat_ws('.', str2, str1);

-- select concat_ws with order by index (result)
--Testcase 1216:
SELECT value1, concat_ws('.', str2, str1) FROM s3 ORDER BY 2,1;
-- select concat_ws with order by index (result)
--Testcase 1217:
SELECT value1, concat_ws('.', value1, value4) FROM s3 ORDER BY 1,2;

-- select concat_ws with group by (explain)
--Testcase 1218:
EXPLAIN VERBOSE
SELECT count(value1), concat_ws('.', str2, str1) FROM s3 GROUP BY concat_ws('.', str2, str1);
-- select concat_ws with group by (result)
--Testcase 1219:
SELECT count(value1), concat_ws('.', str2, str1) FROM s3 GROUP BY concat_ws('.', str2, str1);

-- select concat_ws with group by index (result)
--Testcase 1220:
SELECT value1, concat_ws('.', str2, str1) FROM s3 GROUP BY 2,1;

-- select concat_ws with group by having (explain)
--Testcase 1221:
EXPLAIN VERBOSE
SELECT count(value1), concat_ws('.', str2, str1) FROM s3 GROUP BY concat_ws('.', str2, str1) HAVING concat_ws('.', str2, str1) IS NOT NULL;
-- select concat_ws with group by having (result)
--Testcase 1222:
SELECT count(value1), concat_ws('.', str2, str1) FROM s3 GROUP BY concat_ws('.', str2, str1) HAVING concat_ws('.', str2, str1) IS NOT NULL;

-- select concat_ws with group by index having (result)
--Testcase 1223:
SELECT value1, concat_ws('.', str2, str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test elt()
-- ===============================================================================
-- select elt (stub function, explain)
--Testcase 1224:
EXPLAIN VERBOSE
SELECT elt(1, str2, str1, tag1) FROM s3;
-- select elt (stub function, result)
--Testcase 1225:
SELECT elt(1, str2, str1, tag1) FROM s3;

-- select elt (stub function, not pushdown constraints, explain)
--Testcase 1226:
EXPLAIN VERBOSE
SELECT value1, elt(1, str2, str1) FROM s3 WHERE to_hex(value2) = '64';
-- select elt (stub function, not pushdown constraints, result)
--Testcase 1227:
SELECT value1, elt(1, str2, str1) FROM s3 WHERE to_hex(value2) = '64';

-- select elt (stub function, pushdown constraints, explain)
--Testcase 1228:
EXPLAIN VERBOSE
SELECT value1, elt(1, str2, str1) FROM s3 WHERE value2 != 200;
-- select elt (stub function, pushdown constraints, result)
--Testcase 1229:
SELECT value1, elt(1, str2, str1) FROM s3 WHERE value2 != 200;

-- select elt with non pushdown func and explicit constant (explain)
--Testcase 1230:
EXPLAIN VERBOSE
SELECT elt(1, str2, str1), pi(), 4.1 FROM s3;
-- select elt with non pushdown func and explicit constant (result)
--Testcase 1231:
SELECT elt(1, str2, str1), pi(), 4.1 FROM s3;

-- select elt with order by (explain)
--Testcase 1232:
EXPLAIN VERBOSE
SELECT value1, elt(1, str2, str1) FROM s3 ORDER BY elt(1, str2, str1);
-- select elt with order by (result)
--Testcase 1233:
SELECT value1, elt(1, str2, str1) FROM s3 ORDER BY elt(1, str2, str1);

-- select elt with order by index (result)
--Testcase 1234:
SELECT value1, elt(1, str2, str1) FROM s3 ORDER BY 2,1;
-- select elt with order by index (result)
--Testcase 1235:
SELECT value1, elt(1, str2, str1) FROM s3 ORDER BY 1,2;

-- select elt with group by (explain)
--Testcase 1236:
EXPLAIN VERBOSE
SELECT count(value1), elt(1, str2, str1) FROM s3 GROUP BY elt(1, str2, str1);
-- select elt with group by (result)
--Testcase 1237:
SELECT count(value1), elt(1, str2, str1) FROM s3 GROUP BY elt(1, str2, str1);

-- select elt with group by index (result)
--Testcase 1238:
SELECT value1, elt(1, str2, str1) FROM s3 GROUP BY 2,1;

-- select elt with group by having (explain)
--Testcase 1239:
EXPLAIN VERBOSE
SELECT count(value1), elt(1, str2, str1) FROM s3 GROUP BY elt(1, str2, str1), str1, str2 HAVING elt(1, str2, str1) IS NOT NULL;
-- select elt with group by having (result)
--Testcase 1240:
SELECT count(value1), elt(1, str2, str1) FROM s3 GROUP BY elt(1, str2, str1), str1, str2 HAVING elt(1, str2, str1) IS NOT NULL;

-- select elt with group by index having (result)
--Testcase 1241:
SELECT value1, elt(1, str2, str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test export_set()
-- ===============================================================================
-- select export_set (stub function, explain)
--Testcase 1242:
EXPLAIN VERBOSE
SELECT export_set(5, str2, str1) FROM s3;
-- select export_set (stub function, result)
--Testcase 1243:
SELECT export_set(5, str2, str1) FROM s3;

--Testcase 1244:
EXPLAIN VERBOSE
SELECT export_set(5, str2, str1, ',') FROM s3;
-- select export_set (stub function, result)
--Testcase 1245:
SELECT export_set(5, str2, str1, ',') FROM s3;

-- select export_set (stub function, explain)
--Testcase 1246:
EXPLAIN VERBOSE
SELECT export_set(5, str2, str1, ',', 2) FROM s3;
-- select export_set (stub function, result)
--Testcase 1247:
SELECT export_set(5, str2, str1, ',', 2) FROM s3;

-- select export_set (stub function, not pushdown constraints, explain)
--Testcase 1248:
EXPLAIN VERBOSE
SELECT value1, export_set(5, str2, str1, ',', 2) FROM s3 WHERE to_hex(value2) = '64';
-- select export_set (stub function, not pushdown constraints, result)
--Testcase 1249:
SELECT value1, export_set(5, str2, str1, ',', 2) FROM s3 WHERE to_hex(value2) = '64';

-- select export_set (stub function, pushdown constraints, explain)
--Testcase 1250:
EXPLAIN VERBOSE
SELECT value1, export_set(5, str2, str1, ',', 2) FROM s3 WHERE value2 != 200;
-- select export_set (stub function, pushdown constraints, result)
--Testcase 1251:
SELECT value1, export_set(5, str2, str1, ',', 2) FROM s3 WHERE value2 != 200;

-- select export_set with non pushdown func and explicit constant (explain)
--Testcase 1252:
EXPLAIN VERBOSE
SELECT export_set(5, str2, str1, ',', 2), pi(), 4.1 FROM s3;
-- select export_set with non pushdown func and explicit constant (result)
--Testcase 1253:
SELECT export_set(5, str2, str1, ',', 2), pi(), 4.1 FROM s3;

-- select export_set with order by (explain)
--Testcase 1254:
EXPLAIN VERBOSE
SELECT value1, export_set(5, str2, str1, ',', 2) FROM s3 ORDER BY export_set(5, str2, str1, ',', 2);
-- select export_set with order by (result)
--Testcase 1255:
SELECT value1, export_set(5, str2, str1, ',', 2) FROM s3 ORDER BY export_set(5, str2, str1, ',', 2);

-- select export_set with order by index (result)
--Testcase 1256:
SELECT value1, export_set(5, str2, str1, ',', 2) FROM s3 ORDER BY 2,1;
-- select export_set with order by index (result)
--Testcase 1257:
SELECT value1, export_set(5, str2, str1, ',', 2) FROM s3 ORDER BY 1,2;

-- select export_set with group by (explain)
--Testcase 1258:
EXPLAIN VERBOSE
SELECT count(value1), export_set(5, str2, str1, ',', 2) FROM s3 GROUP BY export_set(5, str2, str1, ',', 2);
-- select export_set with group by (result)
--Testcase 1259:
SELECT count(value1), export_set(5, str2, str1, ',', 2) FROM s3 GROUP BY export_set(5, str2, str1, ',', 2);

-- select export_set with group by index (result)
--Testcase 1260:
SELECT value1, export_set(5, str2, str1, ',', 2) FROM s3 GROUP BY 2,1;

-- select export_set with group by having (explain)
--Testcase 1261:
EXPLAIN VERBOSE
SELECT count(value1), export_set(5, str2, str1, ',', 2) FROM s3 GROUP BY export_set(5, str2, str1, ',', 2), str1, str2 HAVING export_set(5, str2, str1, ',', 2) IS NOT NULL;
-- select export_set with group by having (result)
--Testcase 1262:
SELECT count(value1), export_set(5, str2, str1, ',', 2) FROM s3 GROUP BY export_set(5, str2, str1, ',', 2), str1, str2 HAVING export_set(5, str2, str1, ',', 2) IS NOT NULL;

-- select export_set with group by index having (result)
--Testcase 1263:
SELECT value1, export_set(5, str2, str1, ',', 2) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test field()
-- ===============================================================================
-- select field (stub function, explain)
--Testcase 1264:
EXPLAIN VERBOSE
SELECT field('---XYZ---', str2, str1) FROM s3;
-- select field (stub function, result)
--Testcase 1265:
SELECT field('---XYZ---', str2, str1) FROM s3;

-- select field (stub function, not pushdown constraints, explain)
--Testcase 1266:
EXPLAIN VERBOSE
SELECT value1, field('---XYZ---', str2, str1) FROM s3 WHERE to_hex(value2) = '64';
-- select field (stub function, not pushdown constraints, result)
--Testcase 1267:
SELECT value1, field('---XYZ---', str2, str1) FROM s3 WHERE to_hex(value2) = '64';

-- select field (stub function, pushdown constraints, explain)
--Testcase 1268:
EXPLAIN VERBOSE
SELECT value1, field('---XYZ---', str2, str1) FROM s3 WHERE value2 != 200;
-- select field (stub function, pushdown constraints, result)
--Testcase 1269:
SELECT value1, field('---XYZ---', str2, str1) FROM s3 WHERE value2 != 200;

-- select field with non pushdown func and explicit constant (explain)
--Testcase 1270:
EXPLAIN VERBOSE
SELECT field('---XYZ---', str2, str1), pi(), 4.1 FROM s3;
-- select field with non pushdown func and explicit constant (result)
--Testcase 1271:
SELECT field('---XYZ---', str2, str1), pi(), 4.1 FROM s3;

-- select field with order by (explain)
--Testcase 1272:
EXPLAIN VERBOSE
SELECT value1, field('---XYZ---', str2, str1) FROM s3 ORDER BY field('---XYZ---', str2, str1);
-- select field with order by (result)
--Testcase 1273:
SELECT value1, field('---XYZ---', str2, str1) FROM s3 ORDER BY field('---XYZ---', str2, str1);

-- select field with order by index (result)
--Testcase 1274:
SELECT value1, field('---XYZ---', str2, str1) FROM s3 ORDER BY 2,1;
-- select field with order by index (result)
--Testcase 1275:
SELECT value1, field('---XYZ---', str2, str1) FROM s3 ORDER BY 1,2;

-- select field with group by (explain)
--Testcase 1276:
EXPLAIN VERBOSE
SELECT count(value1), field('---XYZ---', str2, str1) FROM s3 GROUP BY field('---XYZ---', str2, str1);
-- select field with group by (result)
--Testcase 1277:
SELECT count(value1), field('---XYZ---', str2, str1) FROM s3 GROUP BY field('---XYZ---', str2, str1);

-- select field with group by index (result)
--Testcase 1278:
SELECT value1, field('---XYZ---', str2, str1) FROM s3 GROUP BY 2,1;

-- select field with group by having (explain)
--Testcase 1279:
EXPLAIN VERBOSE
SELECT count(value1), field('---XYZ---', str2, str1) FROM s3 GROUP BY field('---XYZ---', str2, str1), str1, str2 HAVING field('---XYZ---', str2, str1) > 0;
-- select field with group by having (result)
--Testcase 1280:
SELECT count(value1), field('---XYZ---', str2, str1) FROM s3 GROUP BY field('---XYZ---', str2, str1), str1, str2 HAVING field('---XYZ---', str2, str1) > 0;

-- select field with group by index having (result)
--Testcase 1281:
SELECT value1, field('---XYZ---', str2, str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test find_in_set()
-- ===============================================================================
-- select find_in_set (stub function, explain)
--Testcase 1282:
EXPLAIN VERBOSE
SELECT find_in_set('---XYZ---', str1) FROM s3;
-- select find_in_set (stub function, result)
--Testcase 1283:
SELECT find_in_set('---XYZ---', str1) FROM s3;

-- select find_in_set (stub function, not pushdown constraints, explain)
--Testcase 1284:
EXPLAIN VERBOSE
SELECT value1, find_in_set('---XYZ---', str1) FROM s3 WHERE to_hex(value2) = '64';
-- select find_in_set (stub function, not pushdown constraints, result)
--Testcase 1285:
SELECT value1, find_in_set('---XYZ---', str1) FROM s3 WHERE to_hex(value2) = '64';

-- select find_in_set (stub function, pushdown constraints, explain)
--Testcase 1286:
EXPLAIN VERBOSE
SELECT value1, find_in_set('---XYZ---', str1) FROM s3 WHERE value2 != 200;
-- select find_in_set (stub function, pushdown constraints, result)
--Testcase 1287:
SELECT value1, find_in_set('---XYZ---', str1) FROM s3 WHERE value2 != 200;

-- select find_in_set with non pushdown func and explicit constant (explain)
--Testcase 1288:
EXPLAIN VERBOSE
SELECT find_in_set('---XYZ---', str1), pi(), 4.1 FROM s3;
-- select find_in_set with non pushdown func and explicit constant (result)
--Testcase 1289:
SELECT find_in_set('---XYZ---', str1), pi(), 4.1 FROM s3;

-- select find_in_set with order by (explain)
--Testcase 1290:
EXPLAIN VERBOSE
SELECT value1, find_in_set('---XYZ---', str1) FROM s3 ORDER BY find_in_set('---XYZ---', str1);
-- select find_in_set with order by (result)
--Testcase 1291:
SELECT value1, find_in_set('---XYZ---', str1) FROM s3 ORDER BY find_in_set('---XYZ---', str1);

-- select find_in_set with order by index (result)
--Testcase 1292:
SELECT value1, find_in_set('---XYZ---', str1) FROM s3 ORDER BY 2,1;
-- select find_in_set with order by index (result)
--Testcase 1293:
SELECT value1, find_in_set('---XYZ---', str1) FROM s3 ORDER BY 1,2;

-- select find_in_set with group by (explain)
--Testcase 1294:
EXPLAIN VERBOSE
SELECT count(value1), find_in_set('---XYZ---', str1) FROM s3 GROUP BY find_in_set('---XYZ---', str1);
-- select find_in_set with group by (result)
--Testcase 1295:
SELECT count(value1), find_in_set('---XYZ---', str1) FROM s3 GROUP BY find_in_set('---XYZ---', str1);

-- select find_in_set with group by index (result)
--Testcase 1296:
SELECT value1, find_in_set('---XYZ---', str1) FROM s3 GROUP BY 2,1;

-- select find_in_set with group by having (explain)
--Testcase 1297:
EXPLAIN VERBOSE
SELECT count(value1), find_in_set('---XYZ---', str1) FROM s3 GROUP BY find_in_set('---XYZ---', str1), str1, str2 HAVING count(find_in_set('---XYZ---', str1)) IS NOT NULL;
-- select find_in_set with group by having (result)
--Testcase 1298:
SELECT count(value1), find_in_set('---XYZ---', str1) FROM s3 GROUP BY find_in_set('---XYZ---', str1), str1, str2 HAVING count(find_in_set('---XYZ---', str1)) IS NOT NULL;

-- select find_in_set with group by index having (result)
--Testcase 1299:
SELECT value1, find_in_set('---XYZ---', str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test format()
-- ===============================================================================
-- select format (stub function, explain)
--Testcase 1300:
EXPLAIN VERBOSE
SELECT format(value1, 4), format(value2, 4), format(value4, 4) FROM s3;
-- select format (stub function, result)
--Testcase 1301:
SELECT format(value1, 4), format(value2, 4), format(value4, 4) FROM s3;

-- select format (stub function, explain)
--Testcase 1302:
EXPLAIN VERBOSE
SELECT format(value1, 4, 'de_DE'), format(value2, 4, 'de_DE'), format(value4, 4, 'de_DE') FROM s3;
-- select format (stub function, result)
--Testcase 1303:
SELECT format(value1, 4, 'de_DE'), format(value2, 4, 'de_DE'), format(value4, 4, 'de_DE') FROM s3;

-- select format (stub function, not pushdown constraints, explain)
--Testcase 1304:
EXPLAIN VERBOSE
SELECT value1, format(value1, 4) FROM s3 WHERE to_hex(value2) = '64';
-- select format (stub function, not pushdown constraints, result)
--Testcase 1305:
SELECT value1, format(value1, 4) FROM s3 WHERE to_hex(value2) = '64';

-- select format (stub function, pushdown constraints, explain)
--Testcase 1306:
EXPLAIN VERBOSE
SELECT value1, format(value1, 4) FROM s3 WHERE value2 != 200;
-- select format (stub function, pushdown constraints, result)
--Testcase 1307:
SELECT value1, format(value1, 4) FROM s3 WHERE value2 != 200;

-- select format with non pushdown func and explicit constant (explain)
--Testcase 1308:
EXPLAIN VERBOSE
SELECT format(value1, 4), pi(), 4.1 FROM s3;
-- select format with non pushdown func and explicit constant (result)
--Testcase 1309:
SELECT format(value1, 4), pi(), 4.1 FROM s3;

-- select format with order by (explain)
--Testcase 1310:
EXPLAIN VERBOSE
SELECT value1, format(value1, 4) FROM s3 ORDER BY format(value1, 4);
-- select format with order by (result)
--Testcase 1311:
SELECT value1, format(value1, 4) FROM s3 ORDER BY format(value1, 4);

-- select format with order by index (result)
--Testcase 1312:
SELECT value1, format(value1, 4) FROM s3 ORDER BY 2,1;
-- select format with order by index (result)
--Testcase 1313:
SELECT value1, format(value1, 4) FROM s3 ORDER BY 1,2;

-- select format with group by (explain)
--Testcase 1314:
EXPLAIN VERBOSE
SELECT count(value1), format(value1, 4) FROM s3 GROUP BY format(value1, 4);
-- select format with group by (result)
--Testcase 1315:
SELECT count(value1), format(value1, 4) FROM s3 GROUP BY format(value1, 4);

-- select format with group by index (result)
--Testcase 1316:
SELECT value1, format(value1, 4) FROM s3 GROUP BY 2,1;

-- select format with group by having (explain)
--Testcase 1317:
EXPLAIN VERBOSE
SELECT count(value1), format(value1, 4) FROM s3 GROUP BY format(value1, 4), value1 HAVING format(value1, 4) IS NOT NULL;
-- select format with group by having (result)
--Testcase 1318:
SELECT count(value1), format(value1, 4) FROM s3 GROUP BY format(value1, 4), value1 HAVING format(value1, 4) IS NOT NULL;

-- select format with group by index having (result)
--Testcase 1319:
SELECT value1, format(value1, 4) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test from_base64()
-- ===============================================================================
-- select from_base64 (stub function, explain)
--Testcase 1320:
EXPLAIN VERBOSE
SELECT from_base64(tag1), from_base64(str1), from_base64(str2) FROM s3;
-- select from_base64 (stub function, result)
--Testcase 1321:
SELECT from_base64(tag1), from_base64(str1), from_base64(str2) FROM s3;

-- select from_base64 (stub function, explain)
--Testcase 1322:
EXPLAIN VERBOSE
SELECT from_base64(to_base64(tag1)), from_base64(to_base64(str1)), from_base64(to_base64(str2)) FROM s3;
-- select from_base64 (stub function, result)
--Testcase 1323:
SELECT from_base64(to_base64(tag1)), from_base64(to_base64(str1)), from_base64(to_base64(str2)) FROM s3;

-- select from_base64 (stub function, not pushdown constraints, explain)
--Testcase 1324:
EXPLAIN VERBOSE
SELECT value1, from_base64(to_base64(str1)) FROM s3 WHERE to_hex(value2) = '64';
-- select from_base64 (stub function, not pushdown constraints, result)
--Testcase 1325:
SELECT value1, from_base64(to_base64(str1)) FROM s3 WHERE to_hex(value2) = '64';

-- select from_base64 (stub function, pushdown constraints, explain)
--Testcase 1326:
EXPLAIN VERBOSE
SELECT value1, from_base64(to_base64(str1)) FROM s3 WHERE value2 != 200;
-- select from_base64 (stub function, pushdown constraints, result)
--Testcase 1327:
SELECT value1, from_base64(to_base64(str1)) FROM s3 WHERE value2 != 200;

-- select from_base64 with non pushdown func and explicit constant (explain)
--Testcase 1328:
EXPLAIN VERBOSE
SELECT from_base64(to_base64(str1)), pi(), 4.1 FROM s3;
-- select from_base64 with non pushdown func and explicit constant (result)
--Testcase 1329:
SELECT from_base64(to_base64(str1)), pi(), 4.1 FROM s3;

-- select from_base64 with order by (explain)
--Testcase 1330:
EXPLAIN VERBOSE
SELECT value1, from_base64(to_base64(str1)) FROM s3 ORDER BY from_base64(to_base64(str1));
-- select from_base64 with order by (result)
--Testcase 1331:
SELECT value1, from_base64(to_base64(str1)) FROM s3 ORDER BY from_base64(to_base64(str1));

-- select from_base64 with order by index (result)
--Testcase 1332:
SELECT value1, from_base64(to_base64(str1)) FROM s3 ORDER BY 2,1;
-- select from_base64 with order by index (result)
--Testcase 1333:
SELECT value1, from_base64(to_base64(str1)) FROM s3 ORDER BY 1,2;

-- select from_base64 with group by (explain)
--Testcase 1334:
EXPLAIN VERBOSE
SELECT count(value1), from_base64(to_base64(str1)) FROM s3 GROUP BY from_base64(to_base64(str1));
-- select from_base64 with group by (result)
--Testcase 1335:
SELECT count(value1), from_base64(to_base64(str1)) FROM s3 GROUP BY from_base64(to_base64(str1));

-- select from_base64 with group by index (result)
--Testcase 1336:
SELECT value1, from_base64(to_base64(str1)) FROM s3 GROUP BY 2,1;

-- select from_base64 with group by having (explain)
--Testcase 1337:
EXPLAIN VERBOSE
SELECT count(value1), from_base64(to_base64(str1)) FROM s3 GROUP BY from_base64(to_base64(str1)), str1 HAVING from_base64(to_base64(str1)) IS NOT NULL;
-- select from_base64 with group by having (result)
--Testcase 1338:
SELECT count(value1), from_base64(to_base64(str1)) FROM s3 GROUP BY from_base64(to_base64(str1)), str1 HAVING from_base64(to_base64(str1)) IS NOT NULL;

-- select from_base64 with group by index having (result)
--Testcase 1339:
SELECT value1, from_base64(to_base64(str1)) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test hex()
-- ===============================================================================
-- select hex (stub function, explain)
--Testcase 1340:
EXPLAIN VERBOSE
SELECT hex(tag1), hex(value2), hex(value4), hex(str1), hex(str2) FROM s3;
-- select hex (stub function, result)
--Testcase 1341:
SELECT hex(tag1), hex(value2), hex(value4), hex(str1), hex(str2) FROM s3;

-- select hex (stub function, not pushdown constraints, explain)
--Testcase 1342:
EXPLAIN VERBOSE
SELECT value1, hex(str1) FROM s3 WHERE to_hex(value2) = '64';
-- select hex (stub function, not pushdown constraints, result)
--Testcase 1343:
SELECT value1, hex(str1) FROM s3 WHERE to_hex(value2) = '64';

-- select hex (stub function, pushdown constraints, explain)
--Testcase 1344:
EXPLAIN VERBOSE
SELECT value1, hex(str1) FROM s3 WHERE value2 != 200;
-- select hex (stub function, pushdown constraints, result)
--Testcase 1345:
SELECT value1, hex(str1) FROM s3 WHERE value2 != 200;

-- select hex with non pushdown func and explicit constant (explain)
--Testcase 1346:
EXPLAIN VERBOSE
SELECT hex(str1), pi(), 4.1 FROM s3;
-- select hex with non pushdown func and explicit constant (result)
--Testcase 1347:
SELECT hex(str1), pi(), 4.1 FROM s3;

-- select hex with order by (explain)
--Testcase 1348:
EXPLAIN VERBOSE
SELECT value1, hex(str1) FROM s3 ORDER BY hex(str1);
-- select hex with order by (result)
--Testcase 1349:
SELECT value1, hex(str1) FROM s3 ORDER BY hex(str1);

-- select hex with order by index (result)
--Testcase 1350:
SELECT value1, hex(str1) FROM s3 ORDER BY 2,1;
-- select hex with order by index (result)
--Testcase 1351:
SELECT value1, hex(str1) FROM s3 ORDER BY 1,2;

-- select hex with group by (explain)
--Testcase 1352:
EXPLAIN VERBOSE
SELECT count(value1), hex(str1) FROM s3 GROUP BY hex(str1);
-- select hex with group by (result)
--Testcase 1353:
SELECT count(value1), hex(str1) FROM s3 GROUP BY hex(str1);

-- select hex with group by index (result)
--Testcase 1354:
SELECT value1, hex(str1) FROM s3 GROUP BY 2,1;

-- select hex with group by having (explain)
--Testcase 1355:
EXPLAIN VERBOSE
SELECT count(value1), hex(str1) FROM s3 GROUP BY hex(str1), str1 HAVING hex(str1) IS NOT NULL;
-- select hex with group by having (result)
--Testcase 1356:
SELECT count(value1), hex(str1) FROM s3 GROUP BY hex(str1), str1 HAVING hex(str1) IS NOT NULL;

-- select hex with group by index having (result)
--Testcase 1357:
SELECT value1, hex(value4) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test insert()
-- ===============================================================================
-- select insert (stub function, explain)
--Testcase 1358:
EXPLAIN VERBOSE
SELECT insert(str1, 3, 4, str2) FROM s3;
-- select hex (stub function, result)
--Testcase 1359:
SELECT insert(str1, 3, 4, str2) FROM s3;

-- select insert (stub function, not pushdown constraints, explain)
--Testcase 1360:
EXPLAIN VERBOSE
SELECT value1, insert(str1, 3, 4, str2) FROM s3 WHERE to_hex(value2) = '64';
-- select insert (stub function, not pushdown constraints, result)
--Testcase 1361:
SELECT value1, insert(str1, 3, 4, str2) FROM s3 WHERE to_hex(value2) = '64';

-- select insert (stub function, pushdown constraints, explain)
--Testcase 1362:
EXPLAIN VERBOSE
SELECT value1, insert(str1, 3, 4, str2) FROM s3 WHERE value2 != 200;
-- select insert (stub function, pushdown constraints, result)
--Testcase 1363:
SELECT value1, insert(str1, 3, 4, str2) FROM s3 WHERE value2 != 200;

-- select insert with non pushdown func and explicit constant (explain)
--Testcase 1364:
EXPLAIN VERBOSE
SELECT insert(str1, 3, 4, str2), pi(), 4.1 FROM s3;
-- select insert with non pushdown func and explicit constant (result)
--Testcase 1365:
SELECT insert(str1, 3, 4, str2), pi(), 4.1 FROM s3;

-- select insert with order by (explain)
--Testcase 1366:
EXPLAIN VERBOSE
SELECT value1, insert(str1, 3, 4, str2) FROM s3 ORDER BY insert(str1, 3, 4, str2);
-- select insert with order by (result)
--Testcase 1367:
SELECT value1, insert(str1, 3, 4, str2) FROM s3 ORDER BY insert(str1, 3, 4, str2);

-- select insert with order by index (result)
--Testcase 1368:
SELECT value1, insert(str1, 3, 4, str2) FROM s3 ORDER BY 2,1;
-- select insert with order by index (result)
--Testcase 1369:
SELECT value1, insert(str1, 3, 4, str2) FROM s3 ORDER BY 1,2;

-- select insert with group by (explain)
--Testcase 1370:
EXPLAIN VERBOSE
SELECT count(value1), insert(str1, 3, 4, str2) FROM s3 GROUP BY insert(str1, 3, 4, str2);
-- select insert with group by (result)
--Testcase 1371:
SELECT count(value1), insert(str1, 3, 4, str2) FROM s3 GROUP BY insert(str1, 3, 4, str2);

-- select insert with group by index (result)
--Testcase 1372:
SELECT value1, insert(str1, 3, 4, str2) FROM s3 GROUP BY 2,1;

-- select insert with group by having (explain)
--Testcase 1373:
EXPLAIN VERBOSE
SELECT count(value1), insert(str1, 3, 4, str2) FROM s3 GROUP BY insert(str1, 3, 4, str2), str1, str2 HAVING insert(str1, 3, 4, str2) IS NOT NULL;
-- select insert with group by having (result)
--Testcase 1374:
SELECT count(value1), insert(str1, 3, 4, str2) FROM s3 GROUP BY insert(str1, 3, 4, str2), str1, str2 HAVING insert(str1, 3, 4, str2) IS NOT NULL;

-- select insert with group by index having (result)
--Testcase 1375:
SELECT value1, insert(str1, 3, 4, str2) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test instr()
-- ===============================================================================
-- select instr (stub function, explain)
--Testcase 1376:
EXPLAIN VERBOSE
SELECT instr(str1, str2) FROM s3;
-- select instr (stub function, result)
--Testcase 1377:
SELECT instr(str1, str2) FROM s3;

-- select instr (stub function, not pushdown constraints, explain)
--Testcase 1378:
EXPLAIN VERBOSE
SELECT value1, instr(str1, str2) FROM s3 WHERE to_hex(value2) = '64';
-- select instr (stub function, not pushdown constraints, result)
--Testcase 1379:
SELECT value1, instr(str1, str2) FROM s3 WHERE to_hex(value2) = '64';

-- select instr (stub function, pushdown constraints, explain)
--Testcase 1380:
EXPLAIN VERBOSE
SELECT value1, instr(str1, str2) FROM s3 WHERE value2 != 200;
-- select instr (stub function, pushdown constraints, result)
--Testcase 1381:
SELECT value1, instr(str1, str2) FROM s3 WHERE value2 != 200;

-- select instr with non pushdown func and explicit constant (explain)
--Testcase 1382:
EXPLAIN VERBOSE
SELECT instr(str1, str2), pi(), 4.1 FROM s3;
-- select instr with non pushdown func and explicit constant (result)
--Testcase 1383:
SELECT instr(str1, str2), pi(), 4.1 FROM s3;

-- select instr with order by (explain)
--Testcase 1384:
EXPLAIN VERBOSE
SELECT value1, instr(str1, str2) FROM s3 ORDER BY instr(str1, str2);
-- select instr with order by (result)
--Testcase 1385:
SELECT value1, instr(str1, str2) FROM s3 ORDER BY instr(str1, str2);

-- select instr with order by index (result)
--Testcase 1386:
SELECT value1, instr(str1, str2) FROM s3 ORDER BY 2,1;
-- select instr with order by index (result)
--Testcase 1387:
SELECT value1, instr(str1, str2) FROM s3 ORDER BY 1,2;

-- select instr with group by (explain)
--Testcase 1388:
EXPLAIN VERBOSE
SELECT count(value1), instr(str1, str2) FROM s3 GROUP BY instr(str1, str2);
-- select instr with group by (result)
--Testcase 1389:
SELECT count(value1), instr(str1, str2) FROM s3 GROUP BY instr(str1, str2);

-- select instr with group by index (result)
--Testcase 1390:
SELECT value1, instr(str1, str2) FROM s3 GROUP BY 2,1;

-- select instr with group by having (explain)
--Testcase 1391:
EXPLAIN VERBOSE
SELECT count(value1), instr(str1, str2) FROM s3 GROUP BY instr(str1, str2), str1, str2 HAVING instr(str1, str2) IS NOT NULL;
-- select instr with group by having (result)
--Testcase 1392:
SELECT count(value1), instr(str1, str2) FROM s3 GROUP BY instr(str1, str2), str1, str2 HAVING instr(str1, str2) IS NOT NULL;

-- select instr with group by index having (result)
--Testcase 1393:
SELECT value1, instr(str1, str2) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test lcase()
-- ===============================================================================
-- select lcase (stub function, explain)
--Testcase 1394:
EXPLAIN VERBOSE
SELECT lcase(tag1), lcase(str1), lcase(str2) FROM s3;
-- select lcase (stub function, result)
--Testcase 1395:
SELECT lcase(tag1), lcase(str1), lcase(str2) FROM s3;

-- select lcase (stub function, not pushdown constraints, explain)
--Testcase 1396:
EXPLAIN VERBOSE
SELECT value1, lcase(str1) FROM s3 WHERE to_hex(value2) = '64';
-- select lcase (stub function, not pushdown constraints, result)
--Testcase 1397:
SELECT value1, lcase(str1) FROM s3 WHERE to_hex(value2) = '64';

-- select lcase (stub function, pushdown constraints, explain)
--Testcase 1398:
EXPLAIN VERBOSE
SELECT value1, lcase(str1) FROM s3 WHERE value2 != 200;
-- select lcase (stub function, pushdown constraints, result)
--Testcase 1399:
SELECT value1, lcase(str1) FROM s3 WHERE value2 != 200;

-- select lcase with non pushdown func and explicit constant (explain)
--Testcase 1400:
EXPLAIN VERBOSE
SELECT lcase(str1), pi(), 4.1 FROM s3;
-- select lcase with non pushdown func and explicit constant (result)
--Testcase 1401:
SELECT lcase(str1), pi(), 4.1 FROM s3;

-- select lcase with order by (explain)
--Testcase 1402:
EXPLAIN VERBOSE
SELECT value1, lcase(str1) FROM s3 ORDER BY lcase(str1);
-- select lcase with order by (result)
--Testcase 1403:
SELECT value1, lcase(str1) FROM s3 ORDER BY lcase(str1);

-- select lcase with order by index (result)
--Testcase 1404:
SELECT value1, lcase(str1) FROM s3 ORDER BY 2,1;
-- select lcase with order by index (result)
--Testcase 1405:
SELECT value1, lcase(str1) FROM s3 ORDER BY 1,2;

-- select lcase with group by (explain)
--Testcase 1406:
EXPLAIN VERBOSE
SELECT count(value1), lcase(str1) FROM s3 GROUP BY lcase(str1);
-- select lcase with group by (result)
--Testcase 1407:
SELECT count(value1), lcase(str1) FROM s3 GROUP BY lcase(str1);

-- select lcase with group by index (result)
--Testcase 1408:
SELECT value1, lcase(str1) FROM s3 GROUP BY 2,1;

-- select lcase with group by having (explain)
--Testcase 1409:
EXPLAIN VERBOSE
SELECT count(value1), lcase(str1) FROM s3 GROUP BY lcase(str1), str1 HAVING lcase(str1) IS NOT NULL;
-- select lcase with group by having (result)
--Testcase 1410:
SELECT count(value1), lcase(str1) FROM s3 GROUP BY lcase(str1), str1 HAVING lcase(str1) IS NOT NULL;

-- select lcase with group by index having (result)
--Testcase 1411:
SELECT value1, lcase(str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test left()
-- ===============================================================================
-- select left (stub function, explain)
--Testcase 1412:
EXPLAIN VERBOSE
SELECT left(str1, 5), left(str2, 5) FROM s3;
-- select left (stub function, result)
--Testcase 1413:
SELECT left(str1, 5), left(str2, 5) FROM s3;

-- select left (stub function, not pushdown constraints, explain)
--Testcase 1414:
EXPLAIN VERBOSE
SELECT value1, left(str1, 5) FROM s3 WHERE to_hex(value2) = '64';
-- select left (stub function, not pushdown constraints, result)
--Testcase 1415:
SELECT value1, left(str1, 5) FROM s3 WHERE to_hex(value2) = '64';

-- select left (stub function, pushdown constraints, explain)
--Testcase 1416:
EXPLAIN VERBOSE
SELECT value1, left(str1, 5) FROM s3 WHERE value2 != 200;
-- select left (stub function, pushdown constraints, result)
--Testcase 1417:
SELECT value1, left(str1, 5) FROM s3 WHERE value2 != 200;

-- select left with non pushdown func and explicit constant (explain)
--Testcase 1418:
EXPLAIN VERBOSE
SELECT left(str1, 5), pi(), 4.1 FROM s3;
-- select left with non pushdown func and explicit constant (result)
--Testcase 1419:
SELECT left(str1, 5), pi(), 4.1 FROM s3;

-- select left with order by (explain)
--Testcase 1420:
EXPLAIN VERBOSE
SELECT value1, left(str1, 5) FROM s3 ORDER BY left(str1, 5);
-- select left with order by (result)
--Testcase 1421:
SELECT value1, left(str1, 5) FROM s3 ORDER BY left(str1, 5);

-- select left with order by index (result)
--Testcase 1422:
SELECT value1, left(str1, 5) FROM s3 ORDER BY 2,1;
-- select left with order by index (result)
--Testcase 1423:
SELECT value1, left(str1, 5) FROM s3 ORDER BY 1,2;

-- select left with group by (explain)
--Testcase 1424:
EXPLAIN VERBOSE
SELECT count(value1), left(str1, 5) FROM s3 GROUP BY left(str1, 5);
-- select left with group by (result)
--Testcase 1425:
SELECT count(value1), left(str1, 5) FROM s3 GROUP BY left(str1, 5);

-- select left with group by index (result)
--Testcase 1426:
SELECT value1, left(str1, 5) FROM s3 GROUP BY 2,1;

-- select left with group by having (explain)
--Testcase 1427:
EXPLAIN VERBOSE
SELECT count(value1), left(str1, 5) FROM s3 GROUP BY left(str1, 5), str1 HAVING left(str1, 5) IS NOT NULL;
-- select left with group by having (result)
--Testcase 1428:
SELECT count(value1), left(str1, 5) FROM s3 GROUP BY left(str1, 5), str1 HAVING left(str1, 5) IS NOT NULL;

-- select left with group by index having (result)
--Testcase 1429:
SELECT value1, left(str1, 5) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test length()
-- ===============================================================================
-- select length (stub function, explain)
--Testcase 1430:
EXPLAIN VERBOSE
SELECT length(str1), length(str2) FROM s3;
-- select length (stub function, result)
--Testcase 1431:
SELECT length(str1), length(str2) FROM s3;

-- select length (stub function, not pushdown constraints, explain)
--Testcase 1432:
EXPLAIN VERBOSE
SELECT value1, length(str1) FROM s3 WHERE to_hex(value2) = '64';
-- select length (stub function, not pushdown constraints, result)
--Testcase 1433:
SELECT value1, length(str1) FROM s3 WHERE to_hex(value2) = '64';

-- select length (stub function, pushdown constraints, explain)
--Testcase 1434:
EXPLAIN VERBOSE
SELECT value1, length(str1) FROM s3 WHERE value2 != 200;
-- select length (stub function, pushdown constraints, result)
--Testcase 1435:
SELECT value1, length(str1) FROM s3 WHERE value2 != 200;

-- select length with non pushdown func and explicit constant (explain)
--Testcase 1436:
EXPLAIN VERBOSE
SELECT length(str1), pi(), 4.1 FROM s3;
-- select length with non pushdown func and explicit constant (result)
--Testcase 1437:
SELECT length(str1), pi(), 4.1 FROM s3;

-- select length with order by (explain)
--Testcase 1438:
EXPLAIN VERBOSE
SELECT value1, length(str1) FROM s3 ORDER BY length(str1);
-- select length with order by (result)
--Testcase 1439:
SELECT value1, length(str1) FROM s3 ORDER BY length(str1);

-- select length with order by index (result)
--Testcase 1440:
SELECT value1, length(str1) FROM s3 ORDER BY 2,1;
-- select length with order by index (result)
--Testcase 1441:
SELECT value1, length(str1) FROM s3 ORDER BY 1,2;

-- select length with group by (explain)
--Testcase 1442:
EXPLAIN VERBOSE
SELECT count(value1), length(str1) FROM s3 GROUP BY length(str1);
-- select length with group by (result)
--Testcase 1443:
SELECT count(value1), length(str1) FROM s3 GROUP BY length(str1);

-- select length with group by index (result)
--Testcase 1444:
SELECT value1, length(str1) FROM s3 GROUP BY 2,1;

-- select length with group by having (explain)
--Testcase 1445:
EXPLAIN VERBOSE
SELECT count(value1), length(str1) FROM s3 GROUP BY length(str1), str1 HAVING length(str1) IS NOT NULL;
-- select length with group by having (result)
--Testcase 1446:
SELECT count(value1), length(str1) FROM s3 GROUP BY length(str1), str1 HAVING length(str1) IS NOT NULL;

-- select length with group by index having (result)
--Testcase 1447:
SELECT value1, length(str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test locate()
-- ===============================================================================
-- select locate (stub function, explain)
--Testcase 1448:
EXPLAIN VERBOSE
SELECT locate(str1, str2), locate(str2, str1, 3) FROM s3;
-- select locate (stub function, result)
--Testcase 1449:
SELECT locate(str1, str2), locate(str2, str1, 3) FROM s3;

-- select locate (stub function, not pushdown constraints, explain)
--Testcase 1450:
EXPLAIN VERBOSE
SELECT value1, locate(str1, str2) FROM s3 WHERE to_hex(value2) = '64';
-- select locate (stub function, not pushdown constraints, result)
--Testcase 1451:
SELECT value1, locate(str1, str2) FROM s3 WHERE to_hex(value2) = '64';

-- select locate (stub function, pushdown constraints, explain)
--Testcase 1452:
EXPLAIN VERBOSE
SELECT value1, locate(str1, str2) FROM s3 WHERE value2 != 200;
-- select locate (stub function, pushdown constraints, result)
--Testcase 1453:
SELECT value1, locate(str1, str2) FROM s3 WHERE value2 != 200;

-- select locate with non pushdown func and explicit constant (explain)
--Testcase 1454:
EXPLAIN VERBOSE
SELECT locate(str1, str2), pi(), 4.1 FROM s3;
-- select locate with non pushdown func and explicit constant (result)
--Testcase 1455:
SELECT locate(str1, str2), pi(), 4.1 FROM s3;

-- select locate with order by (explain)
--Testcase 1456:
EXPLAIN VERBOSE
SELECT value1, locate(str1, str2) FROM s3 ORDER BY locate(str1, str2);
-- select locate with order by (result)
--Testcase 1457:
SELECT value1, locate(str1, str2) FROM s3 ORDER BY locate(str1, str2);

-- select locate with order by index (result)
--Testcase 1458:
SELECT value1, locate(str1, str2) FROM s3 ORDER BY 2,1;
-- select locate with order by index (result)
--Testcase 1459:
SELECT value1, locate(str1, str2) FROM s3 ORDER BY 1,2;

-- select locate with group by (explain)
--Testcase 1460:
EXPLAIN VERBOSE
SELECT count(value1), locate(str1, str2) FROM s3 GROUP BY locate(str1, str2);
-- select locate with group by (result)
--Testcase 1461:
SELECT count(value1), locate(str1, str2) FROM s3 GROUP BY locate(str1, str2);

-- select locate with group by index (result)
--Testcase 1462:
SELECT value1, locate(str1, str2) FROM s3 GROUP BY 2,1;

-- select locate with group by having (explain)
--Testcase 1463:
EXPLAIN VERBOSE
SELECT count(value1), locate(str1, str2) FROM s3 GROUP BY locate(str1, str2), str1, str2 HAVING locate(str1, str2) IS NOT NULL;
-- select locate with group by having (result)
--Testcase 1464:
SELECT count(value1), locate(str1, str2) FROM s3 GROUP BY locate(str1, str2), str1, str2 HAVING locate(str1, str2) IS NOT NULL;

-- select locate with group by index having (result)
--Testcase 1465:
SELECT value1, locate(str1, str2) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test lower()
-- ===============================================================================
-- select lower (stub function, explain)
--Testcase 1466:
EXPLAIN VERBOSE
SELECT lower(str1), lower(str2) FROM s3;
-- select lower (stub function, result)
--Testcase 1467:
SELECT lower(str1), lower(str2) FROM s3;

-- select lower (stub function, not pushdown constraints, explain)
--Testcase 1468:
EXPLAIN VERBOSE
SELECT value1, lower(str1) FROM s3 WHERE to_hex(value2) = '64';
-- select lower (stub function, not pushdown constraints, result)
--Testcase 1469:
SELECT value1, lower(str1) FROM s3 WHERE to_hex(value2) = '64';

-- select lower (stub function, pushdown constraints, explain)
--Testcase 1470:
EXPLAIN VERBOSE
SELECT value1, lower(str1) FROM s3 WHERE value2 != 200;
-- select lower (stub function, pushdown constraints, result)
--Testcase 1471:
SELECT value1, lower(str1) FROM s3 WHERE value2 != 200;

-- select lower with non pushdown func and explicit constant (explain)
--Testcase 1472:
EXPLAIN VERBOSE
SELECT lower(str1), pi(), 4.1 FROM s3;
-- select lower with non pushdown func and explicit constant (result)
--Testcase 1473:
SELECT lower(str1), pi(), 4.1 FROM s3;

-- select lower with order by (explain)
--Testcase 1474:
EXPLAIN VERBOSE
SELECT value1, lower(str1) FROM s3 ORDER BY lower(str1);
-- select lower with order by (result)
--Testcase 1475:
SELECT value1, lower(str1) FROM s3 ORDER BY lower(str1);

-- select lower with order by index (result)
--Testcase 1476:
SELECT value1, lower(str1) FROM s3 ORDER BY 2,1;
-- select lower with order by index (result)
--Testcase 1477:
SELECT value1, lower(str1) FROM s3 ORDER BY 1,2;

-- select lower with group by (explain)
--Testcase 1478:
EXPLAIN VERBOSE
SELECT count(value1), lower(str1) FROM s3 GROUP BY lower(str1);
-- select lower with group by (result)
--Testcase 1479:
SELECT count(value1), lower(str1) FROM s3 GROUP BY lower(str1);

-- select lower with group by index (result)
--Testcase 1480:
SELECT value1, lower(str1) FROM s3 GROUP BY 2,1;

-- select lower with group by having (explain)
--Testcase 1481:
EXPLAIN VERBOSE
SELECT count(value1), lower(str1) FROM s3 GROUP BY lower(str1), str1 HAVING lower(str1) IS NOT NULL;
-- select lower with group by having (result)
--Testcase 1482:
SELECT count(value1), lower(str1) FROM s3 GROUP BY lower(str1), str1 HAVING lower(str1) IS NOT NULL;

-- select lower with group by index having (result)
--Testcase 1483:
SELECT value1, lower(str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test lpad()
-- ===============================================================================
-- select lpad (stub function, explain)
--Testcase 1484:
EXPLAIN VERBOSE
SELECT lpad(str1, 4, 'ABCD'), lpad(str2, 4, 'ABCD') FROM s3;
-- select lpad (stub function, result)
--Testcase 1485:
SELECT lpad(str1, 4, 'ABCD'), lpad(str2, 4, 'ABCD') FROM s3;

-- select lpad (stub function, not pushdown constraints, explain)
--Testcase 1486:
EXPLAIN VERBOSE
SELECT value1, lpad(str1, 4, 'ABCD') FROM s3 WHERE to_hex(value2) = '64';
-- select lpad (stub function, not pushdown constraints, result)
--Testcase 1487:
SELECT value1, lpad(str1, 4, 'ABCD') FROM s3 WHERE to_hex(value2) = '64';

-- select lpad (stub function, pushdown constraints, explain)
--Testcase 1488:
EXPLAIN VERBOSE
SELECT value1, lpad(str1, 4, 'ABCD') FROM s3 WHERE value2 != 200;
-- select lpad (stub function, pushdown constraints, result)
--Testcase 1489:
SELECT value1, lpad(str1, 4, 'ABCD') FROM s3 WHERE value2 != 200;

-- select lpad with non pushdown func and explicit constant (explain)
--Testcase 1490:
EXPLAIN VERBOSE
SELECT lpad(str1, 4, 'ABCD'), pi(), 4.1 FROM s3;
-- select lpad with non pushdown func and explicit constant (result)
--Testcase 1491:
SELECT lpad(str1, 4, 'ABCD'), pi(), 4.1 FROM s3;

-- select lpad with order by (explain)
--Testcase 1492:
EXPLAIN VERBOSE
SELECT value1, lpad(str1, 4, 'ABCD') FROM s3 ORDER BY lpad(str1, 4, 'ABCD');
-- select lpad with order by (result)
--Testcase 1493:
SELECT value1, lpad(str1, 4, 'ABCD') FROM s3 ORDER BY lpad(str1, 4, 'ABCD');

-- select lpad with order by index (result)
--Testcase 1494:
SELECT value1, lpad(str1, 4, 'ABCD') FROM s3 ORDER BY 2,1;
-- select lpad with order by index (result)
--Testcase 1495:
SELECT value1, lpad(str1, 4, 'ABCD') FROM s3 ORDER BY 1,2;

-- select lpad with group by (explain)
--Testcase 1496:
EXPLAIN VERBOSE
SELECT count(value1), lpad(str1, 4, 'ABCD') FROM s3 GROUP BY lpad(str1, 4, 'ABCD');
-- select lpad with group by (result)
--Testcase 1497:
SELECT count(value1), lpad(str1, 4, 'ABCD') FROM s3 GROUP BY lpad(str1, 4, 'ABCD');

-- select lpad with group by index (result)
--Testcase 1498:
SELECT value1, lpad(str1, 4, 'ABCD') FROM s3 GROUP BY 2,1;

-- select lpad with group by having (explain)
--Testcase 1499:
EXPLAIN VERBOSE
SELECT count(value1), lpad(str1, 4, 'ABCD') FROM s3 GROUP BY lpad(str1, 4, 'ABCD'), str1 HAVING lpad(str1, 4, 'ABCD') IS NOT NULL;
-- select lpad with group by having (result)
--Testcase 1500:
SELECT count(value1), lpad(str1, 4, 'ABCD') FROM s3 GROUP BY lpad(str1, 4, 'ABCD'), str1 HAVING lpad(str1, 4, 'ABCD') IS NOT NULL;

-- select lpad with group by index having (result)
--Testcase 1501:
SELECT value1, lpad(str1, 4, 'ABCD') FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test ltrim()
-- ===============================================================================
-- select ltrim (stub function, explain)
--Testcase 1502:
EXPLAIN VERBOSE
SELECT ltrim(str1), ltrim(str2, ' ') FROM s3;
-- select ltrim (stub function, result)
--Testcase 1503:
SELECT ltrim(str1), ltrim(str2, ' ') FROM s3;

-- select ltrim (stub function, not pushdown constraints, explain)
--Testcase 1504:
EXPLAIN VERBOSE
SELECT value1, ltrim(str1, '-') FROM s3 WHERE to_hex(value2) = '64';
-- select ltrim (stub function, not pushdown constraints, result)
--Testcase 1505:
SELECT value1, ltrim(str1, '-') FROM s3 WHERE to_hex(value2) = '64';

-- select ltrim (stub function, pushdown constraints, explain)
--Testcase 1506:
EXPLAIN VERBOSE
SELECT value1, ltrim(str1, '-') FROM s3 WHERE value2 != 200;
-- select ltrim (stub function, pushdown constraints, result)
--Testcase 1507:
SELECT value1, ltrim(str1, '-') FROM s3 WHERE value2 != 200;

-- select ltrim with non pushdown func and explicit constant (explain)
--Testcase 1508:
EXPLAIN VERBOSE
SELECT ltrim(str1, '-'), pi(), 4.1 FROM s3;
-- select ltrim with non pushdown func and explicit constant (result)
--Testcase 1509:
SELECT ltrim(str1, '-'), pi(), 4.1 FROM s3;

-- select ltrim with order by (explain)
--Testcase 1510:
EXPLAIN VERBOSE
SELECT value1, ltrim(str1, '-') FROM s3 ORDER BY ltrim(str1, '-');
-- select ltrim with order by (result)
--Testcase 1511:
SELECT value1, ltrim(str1, '-') FROM s3 ORDER BY ltrim(str1, '-');

-- select ltrim with order by index (result)
--Testcase 1512:
SELECT value1, ltrim(str1, '-') FROM s3 ORDER BY 2,1;
-- select ltrim with order by index (result)
--Testcase 1513:
SELECT value1, ltrim(str1, '-') FROM s3 ORDER BY 1,2;

-- select ltrim with group by (explain)
--Testcase 1514:
EXPLAIN VERBOSE
SELECT count(value1), ltrim(str1, '-') FROM s3 GROUP BY ltrim(str1, '-');
-- select ltrim with group by (result)
--Testcase 1515:
SELECT count(value1), ltrim(str1, '-') FROM s3 GROUP BY ltrim(str1, '-');

-- select ltrim with group by index (result)
--Testcase 1516:
SELECT value1, ltrim(str1, '-') FROM s3 GROUP BY 2,1;

-- select ltrim with group by having (explain)
--Testcase 1517:
EXPLAIN VERBOSE
SELECT count(value1), ltrim(str1, '-') FROM s3 GROUP BY ltrim(str1, '-'), str2 HAVING ltrim(str1, '-') IS NOT NULL;
-- select ltrim with group by having (result)
--Testcase 1518:
SELECT count(value1), ltrim(str1, '-') FROM s3 GROUP BY ltrim(str1, '-'), str2 HAVING ltrim(str1, '-') IS NOT NULL;

-- select ltrim with group by index having (result)
--Testcase 1519:
SELECT value1, ltrim(str2) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test make_set()
-- ===============================================================================
-- select make_set (stub function, explain)
--Testcase 1520:
EXPLAIN VERBOSE
SELECT make_set(1, str1, str2), make_set(1 | 4, str1, str2) FROM s3;
-- select make_set (stub function, result)
--Testcase 1521:
SELECT make_set(1, str1, str2), make_set(1 | 4, str1, str2) FROM s3;

-- select make_set (stub function, not pushdown constraints, explain)
--Testcase 1522:
EXPLAIN VERBOSE
SELECT value1, make_set(1 | 4, str1, str2) FROM s3 WHERE to_hex(value2) = '64';
-- select make_set (stub function, not pushdown constraints, result)
--Testcase 1523:
SELECT value1, make_set(1 | 4, str1, str2) FROM s3 WHERE to_hex(value2) = '64';

-- select make_set (stub function, pushdown constraints, explain)
--Testcase 1524:
EXPLAIN VERBOSE
SELECT value1, make_set(1 | 4, str1, str2) FROM s3 WHERE value2 != 200;
-- select make_set (stub function, pushdown constraints, result)
--Testcase 1525:
SELECT value1, make_set(1 | 4, str1, str2) FROM s3 WHERE value2 != 200;

-- select make_set with non pushdown func and explicit constant (explain)
--Testcase 1526:
EXPLAIN VERBOSE
SELECT make_set(1 | 4, str1, str2), pi(), 4.1 FROM s3;
-- select make_set with non pushdown func and explicit constant (result)
--Testcase 1527:
SELECT make_set(1 | 4, str1, str2), pi(), 4.1 FROM s3;

-- select make_set with order by (explain)
--Testcase 1528:
EXPLAIN VERBOSE
SELECT value1, make_set(1 | 4, str1, str2) FROM s3 ORDER BY make_set(1 | 4, str1, str2);
-- select make_set with order by (result)
--Testcase 1529:
SELECT value1, make_set(1 | 4, str1, str2) FROM s3 ORDER BY make_set(1 | 4, str1, str2);

-- select make_set with order by index (result)
--Testcase 1530:
SELECT value1, make_set(1 | 4, str1, str2) FROM s3 ORDER BY 2,1;
-- select make_set with order by index (result)
--Testcase 1531:
SELECT value1, make_set(1 | 4, str1, str2) FROM s3 ORDER BY 1,2;

-- select make_set with group by (explain)
--Testcase 1532:
EXPLAIN VERBOSE
SELECT count(value1), make_set(1 | 4, str1, str2) FROM s3 GROUP BY make_set(1 | 4, str1, str2);
-- select make_set with group by (result)
--Testcase 1533:
SELECT count(value1), make_set(1 | 4, str1, str2) FROM s3 GROUP BY make_set(1 | 4, str1, str2);

-- select make_set with group by index (result)
--Testcase 1534:
SELECT value1, make_set(1 | 4, str1, str2) FROM s3 GROUP BY 2,1;

-- select make_set with group by having (explain)
--Testcase 1535:
EXPLAIN VERBOSE
SELECT count(value1), make_set(1 | 4, str1, str2) FROM s3 GROUP BY make_set(1 | 4, str1, str2), str1, str2 HAVING make_set(1 | 4, str1, str2) IS NOT NULL;
-- select make_set with group by having (result)
--Testcase 1536:
SELECT count(value1), make_set(1 | 4, str1, str2) FROM s3 GROUP BY make_set(1 | 4, str1, str2), str1, str2 HAVING make_set(1 | 4, str1, str2) IS NOT NULL;

-- select make_set with group by index having (result)
--Testcase 1537:
SELECT value1, make_set(1 | 4, str1, str2) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test mid()
-- ===============================================================================
-- select mid (stub function, explain)
--Testcase 1538:
EXPLAIN VERBOSE
SELECT mid(str1, 2, 4), mid(str2, 2, 4) FROM s3;
-- select mid (stub function, result)
--Testcase 1539:
SELECT mid(str1, 2, 4), mid(str2, 2, 4) FROM s3;

-- select mid (stub function, not pushdown constraints, explain)
--Testcase 1540:
EXPLAIN VERBOSE
SELECT value1, mid(str2, 2, 4) FROM s3 WHERE to_hex(value2) = '64';
-- select mid (stub function, not pushdown constraints, result)
--Testcase 1541:
SELECT value1, mid(str2, 2, 4) FROM s3 WHERE to_hex(value2) = '64';

-- select mid (stub function, pushdown constraints, explain)
--Testcase 1542:
EXPLAIN VERBOSE
SELECT value1, mid(str2, 2, 4) FROM s3 WHERE value2 != 200;
-- select mid (stub function, pushdown constraints, result)
--Testcase 1543:
SELECT value1, mid(str2, 2, 4) FROM s3 WHERE value2 != 200;

-- select mid with non pushdown func and explicit constant (explain)
--Testcase 1544:
EXPLAIN VERBOSE
SELECT mid(str2, 2, 4), pi(), 4.1 FROM s3;
-- select mid with non pushdown func and explicit constant (result)
--Testcase 1545:
SELECT mid(str2, 2, 4), pi(), 4.1 FROM s3;

-- select mid with order by (explain)
--Testcase 1546:
EXPLAIN VERBOSE
SELECT value1, mid(str2, 2, 4) FROM s3 ORDER BY mid(str2, 2, 4);
-- select mid with order by (result)
--Testcase 1547:
SELECT value1, mid(str2, 2, 4) FROM s3 ORDER BY mid(str2, 2, 4);

-- select mid with order by index (result)
--Testcase 1548:
SELECT value1, mid(str2, 2, 4) FROM s3 ORDER BY 2,1;
-- select mid with order by index (result)
--Testcase 1549:
SELECT value1, mid(str2, 2, 4) FROM s3 ORDER BY 1,2;

-- select mid with group by (explain)
--Testcase 1550:
EXPLAIN VERBOSE
SELECT count(value1), mid(str2, 2, 4) FROM s3 GROUP BY mid(str2, 2, 4);
-- select mid with group by (result)
--Testcase 1551:
SELECT count(value1), mid(str2, 2, 4) FROM s3 GROUP BY mid(str2, 2, 4);

-- select mid with group by index (result)
--Testcase 1552:
SELECT value1, mid(str2, 2, 4) FROM s3 GROUP BY 2,1;

-- select mid with group by having (explain)
--Testcase 1553:
EXPLAIN VERBOSE
SELECT count(value1), mid(str2, 2, 4) FROM s3 GROUP BY mid(str2, 2, 4), str2 HAVING mid(str2, 2, 4) IS NOT NULL;
-- select mid with group by having (result)
--Testcase 1554:
SELECT count(value1), mid(str2, 2, 4) FROM s3 GROUP BY mid(str2, 2, 4), str2 HAVING mid(str2, 2, 4) IS NOT NULL;

-- select mid with group by index having (result)
--Testcase 1555:
SELECT value1, mid(str2, 2, 4) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test oct()
-- ===============================================================================
-- select oct (stub function, explain)
--Testcase 1556:
EXPLAIN VERBOSE
SELECT oct(value2), oct(value4) FROM s3;
-- select oct (stub function, result)
--Testcase 1557:
SELECT oct(value2), oct(value4) FROM s3;

-- select oct (stub function, not pushdown constraints, explain)
--Testcase 1558:
EXPLAIN VERBOSE
SELECT value1, oct(value4) FROM s3 WHERE to_hex(value2) = '64';
-- select oct (stub function, not pushdown constraints, result)
--Testcase 1559:
SELECT value1, oct(value4) FROM s3 WHERE to_hex(value2) = '64';

-- select oct (stub function, pushdown constraints, explain)
--Testcase 1560:
EXPLAIN VERBOSE
SELECT value1, oct(value4) FROM s3 WHERE value2 != 200;
-- select oct (stub function, pushdown constraints, result)
--Testcase 1561:
SELECT value1, oct(value4) FROM s3 WHERE value2 != 200;

-- select oct with non pushdown func and explicit constant (explain)
--Testcase 1562:
EXPLAIN VERBOSE
SELECT oct(value4), pi(), 4.1 FROM s3;
-- select oct with non pushdown func and explicit constant (result)
--Testcase 1563:
SELECT oct(value4), pi(), 4.1 FROM s3;

-- select oct with order by (explain)
--Testcase 1564:
EXPLAIN VERBOSE
SELECT value1, oct(value4) FROM s3 ORDER BY oct(value4);
-- select oct with order by (result)
--Testcase 1565:
SELECT value1, oct(value4) FROM s3 ORDER BY oct(value4);

-- select oct with order by index (result)
--Testcase 1566:
SELECT value1, oct(value4) FROM s3 ORDER BY 2,1;
-- select oct with order by index (result)
--Testcase 1567:
SELECT value1, oct(value4) FROM s3 ORDER BY 1,2;

-- select oct with group by (explain)
--Testcase 1568:
EXPLAIN VERBOSE
SELECT count(value1), oct(value4) FROM s3 GROUP BY oct(value4);
-- select oct with group by (result)
--Testcase 1569:
SELECT count(value1), oct(value4) FROM s3 GROUP BY oct(value4);

-- select oct with group by index (result)
--Testcase 1570:
SELECT value1, oct(value4) FROM s3 GROUP BY 2,1;

-- select oct with group by having (explain)
--Testcase 1571:
EXPLAIN VERBOSE
SELECT count(value1), oct(value4) FROM s3 GROUP BY oct(value4), value4 HAVING oct(value4) IS NOT NULL;
-- select oct with group by having (result)
--Testcase 1572:
SELECT count(value1), oct(value4) FROM s3 GROUP BY oct(value4), value4 HAVING oct(value4) IS NOT NULL;

-- select oct with group by index having (result)
--Testcase 1573:
SELECT value1, oct(value4) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test octet_length()
-- ===============================================================================
-- select octet_length (stub function, explain)
--Testcase 1574:
EXPLAIN VERBOSE
SELECT octet_length(str1), octet_length(str2) FROM s3;
-- select octet_length (stub function, result)
--Testcase 1575:
SELECT octet_length(str1), octet_length(str2) FROM s3;

-- select octet_length (stub function, not pushdown constraints, explain)
--Testcase 1576:
EXPLAIN VERBOSE
SELECT value1, octet_length(str1) FROM s3 WHERE to_hex(value2) = '64';
-- select octet_length (stub function, not pushdown constraints, result)
--Testcase 1577:
SELECT value1, octet_length(str1) FROM s3 WHERE to_hex(value2) = '64';

-- select octet_length (stub function, pushdown constraints, explain)
--Testcase 1578:
EXPLAIN VERBOSE
SELECT value1, octet_length(str1) FROM s3 WHERE value2 != 200;
-- select octet_length (stub function, pushdown constraints, result)
--Testcase 1579:
SELECT value1, octet_length(str1) FROM s3 WHERE value2 != 200;

-- select octet_length with non pushdown func and explicit constant (explain)
--Testcase 1580:
EXPLAIN VERBOSE
SELECT octet_length(str1), pi(), 4.1 FROM s3;
-- select octet_length with non pushdown func and explicit constant (result)
--Testcase 1581:
SELECT octet_length(str1), pi(), 4.1 FROM s3;

-- select octet_length with order by (explain)
--Testcase 1582:
EXPLAIN VERBOSE
SELECT value1, octet_length(str1) FROM s3 ORDER BY octet_length(str1);
-- select octet_length with order by (result)
--Testcase 1583:
SELECT value1, octet_length(str1) FROM s3 ORDER BY octet_length(str1);

-- select octet_length with order by index (result)
--Testcase 1584:
SELECT value1, octet_length(str1) FROM s3 ORDER BY 2,1;
-- select octet_length with order by index (result)
--Testcase 1585:
SELECT value1, octet_length(str1) FROM s3 ORDER BY 1,2;

-- select octet_length with group by (explain)
--Testcase 1586:
EXPLAIN VERBOSE
SELECT count(value1), octet_length(str1) FROM s3 GROUP BY octet_length(str1);
-- select octet_length with group by (result)
--Testcase 1587:
SELECT count(value1), octet_length(str1) FROM s3 GROUP BY octet_length(str1);

-- select octet_length with group by index (result)
--Testcase 1588:
SELECT value1, octet_length(str1) FROM s3 GROUP BY 2,1;

-- select octet_length with group by having (explain)
--Testcase 1589:
EXPLAIN VERBOSE
SELECT count(value1), octet_length(str1) FROM s3 GROUP BY octet_length(str1), str1 HAVING octet_length(str1) IS NOT NULL;
-- select octet_length with group by having (result)
--Testcase 1590:
SELECT count(value1), octet_length(str1) FROM s3 GROUP BY octet_length(str1), str1 HAVING octet_length(str1) IS NOT NULL;

-- select octet_length with group by index having (result)
--Testcase 1591:
SELECT value1, octet_length(str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test ord()
-- ===============================================================================
-- select ord (stub function, explain)
--Testcase 1592:
EXPLAIN VERBOSE
SELECT ord(value1), ord(value2), ord(value3), ord(value4), ord(str1), ord(str2) FROM s3;
-- select ord (stub function, result)
--Testcase 1593:
SELECT ord(value1), ord(value2), ord(value3), ord(value4), ord(str1), ord(str2) FROM s3;

-- select ord (stub function, not pushdown constraints, explain)
--Testcase 1594:
EXPLAIN VERBOSE
SELECT value1, ord(str2) FROM s3 WHERE to_hex(value2) = '64';
-- select ord (stub function, not pushdown constraints, result)
--Testcase 1595:
SELECT value1, ord(str2) FROM s3 WHERE to_hex(value2) = '64';

-- select ord (stub function, pushdown constraints, explain)
--Testcase 1596:
EXPLAIN VERBOSE
SELECT value1, ord(str2) FROM s3 WHERE value2 != 200;
-- select ord (stub function, pushdown constraints, result)
--Testcase 1597:
SELECT value1, ord(str2) FROM s3 WHERE value2 != 200;

-- select ord with non pushdown func and explicit constant (explain)
--Testcase 1598:
EXPLAIN VERBOSE
SELECT ord(str2), pi(), 4.1 FROM s3;
-- select ord with non pushdown func and explicit constant (result)
--Testcase 1599:
SELECT ord(str2), pi(), 4.1 FROM s3;

-- select ord with order by (explain)
--Testcase 1600:
EXPLAIN VERBOSE
SELECT value1, ord(str2) FROM s3 ORDER BY ord(str2);
-- select ord with order by (result)
--Testcase 1601:
SELECT value1, ord(str2) FROM s3 ORDER BY ord(str2);

-- select ord with order by index (result)
--Testcase 1602:
SELECT value1, ord(str2) FROM s3 ORDER BY 2,1;
-- select ord with order by index (result)
--Testcase 1603:
SELECT value1, ord(str2) FROM s3 ORDER BY 1,2;

-- select ord with group by (explain)
--Testcase 1604:
EXPLAIN VERBOSE
SELECT count(value1), ord(str2) FROM s3 GROUP BY ord(str2);
-- select ord with group by (result)
--Testcase 1605:
SELECT count(value1), ord(str2) FROM s3 GROUP BY ord(str2);

-- select ord with group by index (result)
--Testcase 1606:
SELECT value1, ord(str2) FROM s3 GROUP BY 2,1;

-- select ord with group by having (explain)
--Testcase 1607:
EXPLAIN VERBOSE
SELECT count(value1), ord(str2) FROM s3 GROUP BY ord(str2), str2 HAVING ord(str2) IS NOT NULL;
-- select ord with group by having (result)
--Testcase 1608:
SELECT count(value1), ord(str2) FROM s3 GROUP BY ord(str2), str2 HAVING ord(str2) IS NOT NULL;

-- select ord with group by index having (result)
--Testcase 1609:
SELECT value1, ord(str2) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test position()
-- ===============================================================================
-- select position (stub function, explain)
--Testcase 1610:
EXPLAIN VERBOSE
SELECT position('XYZ' IN str1), position('XYZ' IN str2) FROM s3;
-- select position (stub function, result)
--Testcase 1611:
SELECT position('XYZ' IN str1), position('XYZ' IN str2) FROM s3;

-- select position (stub function, not pushdown constraints, explain)
--Testcase 1612:
EXPLAIN VERBOSE
SELECT value1, position('XYZ' IN str1) FROM s3 WHERE to_hex(value2) = '64';
-- select position (stub function, not pushdown constraints, result)
--Testcase 1613:
SELECT value1, position('XYZ' IN str1) FROM s3 WHERE to_hex(value2) = '64';

-- select position (stub function, pushdown constraints, explain)
--Testcase 1614:
EXPLAIN VERBOSE
SELECT value1, position('XYZ' IN str1) FROM s3 WHERE value2 != 200;
-- select position (stub function, pushdown constraints, result)
--Testcase 1615:
SELECT value1, position('XYZ' IN str1) FROM s3 WHERE value2 != 200;

-- select position with non pushdown func and explicit constant (explain)
--Testcase 1616:
EXPLAIN VERBOSE
SELECT position('XYZ' IN str1), pi(), 4.1 FROM s3;
-- select position with non pushdown func and explicit constant (result)
--Testcase 1617:
SELECT position('XYZ' IN str1), pi(), 4.1 FROM s3;

-- select position with order by (explain)
--Testcase 1618:
EXPLAIN VERBOSE
SELECT value1, position('XYZ' IN str1) FROM s3 ORDER BY position('XYZ' IN str1);
-- select position with order by (result)
--Testcase 1619:
SELECT value1, position('XYZ' IN str1) FROM s3 ORDER BY position('XYZ' IN str1);

-- select position with order by index (result)
--Testcase 1620:
SELECT value1, position('XYZ' IN str1) FROM s3 ORDER BY 2,1;
-- select position with order by index (result)
--Testcase 1621:
SELECT value1, position('XYZ' IN str1) FROM s3 ORDER BY 1,2;

-- select position with group by (explain)
--Testcase 1622:
EXPLAIN VERBOSE
SELECT count(value1), position('XYZ' IN str1) FROM s3 GROUP BY position('XYZ' IN str1);
-- select position with group by (result)
--Testcase 1623:
SELECT count(value1), position('XYZ' IN str1) FROM s3 GROUP BY position('XYZ' IN str1);

-- select position with group by index (result)
--Testcase 1624:
SELECT value1, position('XYZ' IN str1) FROM s3 GROUP BY 2,1;

-- select position with group by having (explain)
--Testcase 1625:
EXPLAIN VERBOSE
SELECT count(value1), position('XYZ' IN str1) FROM s3 GROUP BY position('XYZ' IN str1), str1 HAVING position('XYZ' IN str1) IS NOT NULL;
-- select position with group by having (result)
--Testcase 1626:
SELECT count(value1), position('XYZ' IN str1) FROM s3 GROUP BY position('XYZ' IN str1), str1 HAVING position('XYZ' IN str1) IS NOT NULL;

-- select position with group by index having (result)
--Testcase 1627:
SELECT value1, position('XYZ' IN str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test quote()
-- ===============================================================================
-- select quote (stub function, explain)
--Testcase 1628:
EXPLAIN VERBOSE
SELECT quote(str1), quote(str2) FROM s3;
-- select quote (stub function, result)
--Testcase 1629:
SELECT quote(str1), quote(str2) FROM s3;

-- select quote (stub function, not pushdown constraints, explain)
--Testcase 1630:
EXPLAIN VERBOSE
SELECT value1, quote(str2) FROM s3 WHERE to_hex(value2) = '64';
-- select quote (stub function, not pushdown constraints, result)
--Testcase 1631:
SELECT value1, quote(str2) FROM s3 WHERE to_hex(value2) = '64';

-- select quote (stub function, pushdown constraints, explain)
--Testcase 1632:
EXPLAIN VERBOSE
SELECT value1, quote(str2) FROM s3 WHERE value2 != 200;
-- select quote (stub function, pushdown constraints, result)
--Testcase 1633:
SELECT value1, quote(str2) FROM s3 WHERE value2 != 200;

-- select quote with non pushdown func and explicit constant (explain)
--Testcase 1634:
EXPLAIN VERBOSE
SELECT quote(str2), pi(), 4.1 FROM s3;
-- select quote with non pushdown func and explicit constant (result)
--Testcase 1635:
SELECT quote(str2), pi(), 4.1 FROM s3;

-- select quote with order by (explain)
--Testcase 1636:
EXPLAIN VERBOSE
SELECT value1, quote(str2) FROM s3 ORDER BY quote(str2);
-- select quote with order by (result)
--Testcase 1637:
SELECT value1, quote(str2) FROM s3 ORDER BY quote(str2);

-- select quote with order by index (result)
--Testcase 1638:
SELECT value1, quote(str2) FROM s3 ORDER BY 2,1;
-- select quote with order by index (result)
--Testcase 1639:
SELECT value1, quote(str2) FROM s3 ORDER BY 1,2;

-- select quote with group by (explain)
--Testcase 1640:
EXPLAIN VERBOSE
SELECT count(value1), quote(str2) FROM s3 GROUP BY quote(str2);
-- select quote with group by (result)
--Testcase 1641:
SELECT count(value1), quote(str2) FROM s3 GROUP BY quote(str2);

-- select quote with group by index (result)
--Testcase 1642:
SELECT value1, quote(str2) FROM s3 GROUP BY 2,1;

-- select quote with group by having (explain)
--Testcase 1643:
EXPLAIN VERBOSE
SELECT count(value1), quote(str2) FROM s3 GROUP BY quote(str2), str2 HAVING quote(str2) IS NOT NULL;
-- select quote with group by having (result)
--Testcase 1644:
SELECT count(value1), quote(str2) FROM s3 GROUP BY quote(str2), str2 HAVING quote(str2) IS NOT NULL;

-- select quote with group by index having (result)
--Testcase 1645:
SELECT value1, quote(str2) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test regexp_instr()
-- ===============================================================================
-- select regexp_instr (stub function, explain)
--Testcase 1646:
EXPLAIN VERBOSE
SELECT regexp_instr(str1, 'XY'), regexp_instr(str2, 'XYZ') FROM s3;
-- select regexp_instr (stub function, result)
--Testcase 1647:
SELECT regexp_instr(str1, 'XY'), regexp_instr(str2, 'XYZ') FROM s3;

-- select regexp_instr (stub function, explain)
--Testcase 1648:
EXPLAIN VERBOSE
SELECT regexp_instr(str1, 'XY', 3), regexp_instr(str2, 'XYZ', 3) FROM s3;
-- select regexp_instr (stub function, result)
--Testcase 1649:
SELECT regexp_instr(str1, 'XY', 3), regexp_instr(str2, 'XYZ', 3) FROM s3;

-- select regexp_instr (stub function, explain)
--Testcase 1650:
EXPLAIN VERBOSE
SELECT regexp_instr(str1, 'XY', 3, 0), regexp_instr(str2, 'XYZ', 3, 0) FROM s3;
-- select regexp_instr (stub function, result)
--Testcase 1651:
SELECT regexp_instr(str1, 'XY', 3, 0), regexp_instr(str2, 'XYZ', 3, 0) FROM s3;

-- select regexp_instr (stub function, explain)
--Testcase 1652:
EXPLAIN VERBOSE
SELECT regexp_instr(str1, 'XY', 3, 0, 1), regexp_instr(str2, 'XYZ', 3, 0, 1) FROM s3;
-- select regexp_instr (stub function, result)
--Testcase 1653:
SELECT regexp_instr(str1, 'XY', 3, 0, 1), regexp_instr(str2, 'XYZ', 3, 0, 1) FROM s3;

-- select regexp_instr (stub function, explain)
--Testcase 1654:
EXPLAIN VERBOSE
SELECT regexp_instr(str1, 'xy', 3, 0, 1, 'i'), regexp_instr(str2, 'xyz', 3, 0, 1, 'i') FROM s3;
-- select regexp_instr (stub function, result)
--Testcase 1655:
SELECT regexp_instr(str1, 'xy', 3, 0, 1, 'i'), regexp_instr(str2, 'xyz', 3, 0, 1, 'i') FROM s3;

-- select regexp_instr (stub function, not pushdown constraints, explain)
--Testcase 1656:
EXPLAIN VERBOSE
SELECT value1, regexp_instr(str2, 'XYZ', 3, 0) FROM s3 WHERE to_hex(value2) = '64';
-- select regexp_instr (stub function, not pushdown constraints, result)
--Testcase 1657:
SELECT value1, regexp_instr(str2, 'XYZ', 3, 0) FROM s3 WHERE to_hex(value2) = '64';

-- select regexp_instr (stub function, pushdown constraints, explain)
--Testcase 1658:
EXPLAIN VERBOSE
SELECT value1, regexp_instr(str2, 'XYZ', 3, 0) FROM s3 WHERE value2 != 200;
-- select regexp_instr (stub function, pushdown constraints, result)
--Testcase 1659:
SELECT value1, regexp_instr(str2, 'XYZ', 3, 0) FROM s3 WHERE value2 != 200;

-- select regexp_instr with non pushdown func and explicit constant (explain)
--Testcase 1660:
EXPLAIN VERBOSE
SELECT regexp_instr(str2, 'XYZ', 3, 0), pi(), 4.1 FROM s3;
-- select regexp_instr with non pushdown func and explicit constant (result)
--Testcase 1661:
SELECT regexp_instr(str2, 'XYZ', 3, 0), pi(), 4.1 FROM s3;

-- select regexp_instr with order by (explain)
--Testcase 1662:
EXPLAIN VERBOSE
SELECT value1, regexp_instr(str2, 'XYZ', 3, 0) FROM s3 ORDER BY regexp_instr(str2, 'XYZ', 3, 0);
-- select regexp_instr with order by (result)
--Testcase 1663:
SELECT value1, regexp_instr(str2, 'XYZ', 3, 0) FROM s3 ORDER BY regexp_instr(str2, 'XYZ', 3, 0);

-- select regexp_instr with order by index (result)
--Testcase 1664:
SELECT value1, regexp_instr(str2, 'XYZ', 3, 0) FROM s3 ORDER BY 2,1;
-- select regexp_instr with order by index (result)
--Testcase 1665:
SELECT value1, regexp_instr(str2, 'XYZ', 3, 0) FROM s3 ORDER BY 1,2;

-- select regexp_instr with group by (explain)
--Testcase 1666:
EXPLAIN VERBOSE
SELECT count(value1), regexp_instr(str2, 'XYZ', 3, 0) FROM s3 GROUP BY regexp_instr(str2, 'XYZ', 3, 0);
-- select regexp_instr with group by (result)
--Testcase 1667:
SELECT count(value1), regexp_instr(str2, 'XYZ', 3, 0) FROM s3 GROUP BY regexp_instr(str2, 'XYZ', 3, 0);

-- select regexp_instr with group by index (result)
--Testcase 1668:
SELECT value1, regexp_instr(str2, 'XYZ', 3, 0) FROM s3 GROUP BY 2,1;

-- select regexp_instr with group by having (explain)
--Testcase 1669:
EXPLAIN VERBOSE
SELECT count(value1), regexp_instr(str2, 'XYZ', 3, 0) FROM s3 GROUP BY regexp_instr(str2, 'XYZ', 3, 0), str2 HAVING regexp_instr(str2, 'XYZ', 3, 0) IS NOT NULL;
-- select regexp_instr with group by having (result)
--Testcase 1670:
SELECT count(value1), regexp_instr(str2, 'XYZ', 3, 0) FROM s3 GROUP BY regexp_instr(str2, 'XYZ', 3, 0), str2 HAVING regexp_instr(str2, 'XYZ', 3, 0) IS NOT NULL;

-- select regexp_instr with group by index having (result)
--Testcase 1671:
SELECT value1, regexp_instr(str2, 'XYZ', 3, 0) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test regexp_like()
-- ===============================================================================
-- select regexp_like (stub function, explain)
--Testcase 1672:
EXPLAIN VERBOSE
SELECT regexp_instr(str1, 'XY'), regexp_instr(str2, 'XYZ') FROM s3;
-- select regexp_like (stub function, result)
--Testcase 1673:
SELECT regexp_instr(str1, 'XY'), regexp_instr(str2, 'XYZ') FROM s3;

-- select regexp_like (stub function, explain)
--Testcase 1674:
EXPLAIN VERBOSE
SELECT regexp_like('   XyZ   ', str2, 'i') FROM s3;
-- select regexp_like (stub function, result)
--Testcase 1675:
SELECT regexp_like('   XyZ   ', str2, 'i') FROM s3;

-- select regexp_like (stub function, not pushdown constraints, explain)
--Testcase 1676:
EXPLAIN VERBOSE
SELECT value1, regexp_like('   XyZ   ', str2, 'i') FROM s3 WHERE to_hex(value2) = '64';
-- select regexp_like (stub function, not pushdown constraints, result)
--Testcase 1677:
SELECT value1, regexp_like('   XyZ   ', str2, 'i') FROM s3 WHERE to_hex(value2) = '64';

-- select regexp_like (stub function, pushdown constraints, explain)
--Testcase 1678:
EXPLAIN VERBOSE
SELECT value1, regexp_like('   XyZ   ', str2, 'i') FROM s3 WHERE value2 != 200;
-- select regexp_like (stub function, pushdown constraints, result)
--Testcase 1679:
SELECT value1, regexp_like('   XyZ   ', str2, 'i') FROM s3 WHERE value2 != 200;

-- select regexp_like with non pushdown func and explicit constant (explain)
--Testcase 1680:
EXPLAIN VERBOSE
SELECT regexp_like('   XyZ   ', str2, 'i'), pi(), 4.1 FROM s3;
-- select regexp_like with non pushdown func and explicit constant (result)
--Testcase 1681:
SELECT regexp_like('   XyZ   ', str2, 'i'), pi(), 4.1 FROM s3;

-- select regexp_like with order by (explain)
--Testcase 1682:
EXPLAIN VERBOSE
SELECT value1, regexp_like('   XyZ   ', str2, 'i') FROM s3 ORDER BY regexp_like('   XyZ   ', str2, 'i');
-- select regexp_like with order by (result)
--Testcase 1683:
SELECT value1, regexp_like('   XyZ   ', str2, 'i') FROM s3 ORDER BY regexp_like('   XyZ   ', str2, 'i');

-- select regexp_like with order by index (result)
--Testcase 1684:
SELECT value1, regexp_like('   XyZ   ', str2, 'i') FROM s3 ORDER BY 2,1;
-- select regexp_like with order by index (result)
--Testcase 1685:
SELECT value1, regexp_like('   XyZ   ', str2, 'i') FROM s3 ORDER BY 1,2;

-- select regexp_like with group by (explain)
--Testcase 1686:
EXPLAIN VERBOSE
SELECT count(value1), regexp_like('   XyZ   ', str2, 'i') FROM s3 GROUP BY regexp_like('   XyZ   ', str2, 'i');
-- select regexp_like with group by (result)
--Testcase 1687:
SELECT count(value1), regexp_like('   XyZ   ', str2, 'i') FROM s3 GROUP BY regexp_like('   XyZ   ', str2, 'i');

-- select regexp_like with group by index (result)
--Testcase 1688:
SELECT value1, regexp_like('   XyZ   ', str2, 'i') FROM s3 GROUP BY 2,1;

-- select regexp_like with group by having (explain)
--Testcase 1689:
EXPLAIN VERBOSE
SELECT count(value1), regexp_like('   XyZ   ', str2, 'i') FROM s3 GROUP BY regexp_like('   XyZ   ', str2, 'i'), str2 HAVING regexp_like('   XyZ   ', str2, 'i') > 0;
-- select regexp_like with group by having (result)
--Testcase 1690:
SELECT count(value1), regexp_like('   XyZ   ', str2, 'i') FROM s3 GROUP BY regexp_like('   XyZ   ', str2, 'i'), str2 HAVING regexp_like('   XyZ   ', str2, 'i') > 0;

-- select regexp_like with group by index having (result)
--Testcase 1691:
SELECT value1, regexp_like('   XyZ   ', str2, 'i') FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test regexp_replace()
-- ===============================================================================
-- select regexp_replace (stub function, explain)
--Testcase 1692:
EXPLAIN VERBOSE
SELECT regexp_replace(str1, 'X', 'x') FROM s3;
-- select regexp_replace (stub function, result)
--Testcase 1693:
SELECT regexp_replace(str1, 'X', 'x') FROM s3;

-- select regexp_replace (stub function, explain)
--Testcase 1694:
EXPLAIN VERBOSE
SELECT regexp_replace(str1, 'Y', 'y', 3) FROM s3;
-- select regexp_replace (stub function, result)
--Testcase 1695:
SELECT regexp_replace(str1, 'Y', 'y', 3) FROM s3;

-- select regexp_replace (stub function, explain)
--Testcase 1696:
EXPLAIN VERBOSE
SELECT regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3;
-- select regexp_replace (stub function, result)
--Testcase 1697:
SELECT regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3;

-- select regexp_replace (stub function, explain)
--Testcase 1698:
EXPLAIN VERBOSE
SELECT regexp_replace(str1, 'y', 'K', 3, 0, 'i') FROM s3;
-- select regexp_replace (stub function, result)
--Testcase 1699:
SELECT regexp_replace(str1, 'y', 'K', 3, 0, 'i') FROM s3;

-- select regexp_replace (stub function, explain)
--Testcase 1700:
EXPLAIN VERBOSE
SELECT regexp_replace(str1, 'y', NULL, 3, 3, 'i') FROM s3;
-- select regexp_replace (stub function, result)
--Testcase 1701:
SELECT regexp_replace(str1, 'y', NULL, 3, 3, 'i') FROM s3;

-- select regexp_replace (stub function, not pushdown constraints, explain)
--Testcase 1702:
EXPLAIN VERBOSE
SELECT value1, regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 WHERE to_hex(value2) = '64';
-- select regexp_replace (stub function, not pushdown constraints, result)
--Testcase 1703:
SELECT value1, regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 WHERE to_hex(value2) = '64';

-- select regexp_replace (stub function, pushdown constraints, explain)
--Testcase 1704:
EXPLAIN VERBOSE
SELECT value1, regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 WHERE value2 != 200;
-- select regexp_replace (stub function, pushdown constraints, result)
--Testcase 1705:
SELECT value1, regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 WHERE value2 != 200;

-- select regexp_replace with non pushdown func and explicit constant (explain)
--Testcase 1706:
EXPLAIN VERBOSE
SELECT regexp_replace(str1, 'Y', 'y', 3, 3), pi(), 4.1 FROM s3;
-- select regexp_replace with non pushdown func and explicit constant (result)
--Testcase 1707:
SELECT regexp_replace(str1, 'Y', 'y', 3, 3), pi(), 4.1 FROM s3;

-- select regexp_replace with order by (explain)
--Testcase 1708:
EXPLAIN VERBOSE
SELECT value1, regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 ORDER BY regexp_replace(str1, 'Y', 'y', 3, 3);
-- select regexp_replace with order by (result)
--Testcase 1709:
SELECT value1, regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 ORDER BY regexp_replace(str1, 'Y', 'y', 3, 3);

-- select regexp_replace with order by index (result)
--Testcase 1710:
SELECT value1, regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 ORDER BY 2,1;
-- select regexp_replace with order by index (result)
--Testcase 1711:
SELECT value1, regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 ORDER BY 1,2;

-- select regexp_replace with group by (explain)
--Testcase 1712:
EXPLAIN VERBOSE
SELECT count(value1), regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 GROUP BY regexp_replace(str1, 'Y', 'y', 3, 3);
-- select regexp_replace with group by (result)
--Testcase 1713:
SELECT count(value1), regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 GROUP BY regexp_replace(str1, 'Y', 'y', 3, 3);

-- select regexp_replace with group by index (result)
--Testcase 1714:
SELECT value1, regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 GROUP BY 2,1;

-- select regexp_replace with group by having (explain)
--Testcase 1715:
EXPLAIN VERBOSE
SELECT count(value1), regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 GROUP BY regexp_replace(str1, 'Y', 'y', 3, 3), str1 HAVING regexp_replace(str1, 'Y', 'y', 3, 3) IS NOT NULL;
-- select regexp_replace with group by having (result)
--Testcase 1716:
SELECT count(value1), regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 GROUP BY regexp_replace(str1, 'Y', 'y', 3, 3), str1 HAVING regexp_replace(str1, 'Y', 'y', 3, 3) IS NOT NULL;

-- select regexp_replace with group by index having (result)
--Testcase 1717:
SELECT value1, regexp_replace(str1, 'Y', 'y', 3, 3) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test regexp_substr()
-- ===============================================================================
-- select regexp_substr (stub function, explain)
--Testcase 1718:
EXPLAIN VERBOSE
SELECT regexp_substr(str1, 'XYZ') FROM s3;
-- select regexp_substr (stub function, result)
--Testcase 1719:
SELECT regexp_substr(str1, 'XYZ') FROM s3;

-- select regexp_substr (stub function, explain)
--Testcase 1720:
EXPLAIN VERBOSE
SELECT regexp_substr(str1, 'XYZ', 3) FROM s3;
-- select regexp_substr (stub function, result)
--Testcase 1721:
SELECT regexp_substr(str1, 'XYZ', 3) FROM s3;

-- select regexp_substr (stub function, explain)
--Testcase 1722:
EXPLAIN VERBOSE
SELECT regexp_substr(str2, 'XYZ', 4, 0) FROM s3;
-- select regexp_substr (stub function, result)
--Testcase 1723:
SELECT regexp_substr(str2, 'XYZ', 4, 0) FROM s3;

-- select regexp_substr (stub function, explain)
--Testcase 1724:
EXPLAIN VERBOSE
SELECT regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3;
-- select regexp_substr (stub function, result)
--Testcase 1725:
SELECT regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3;

-- select regexp_substr (stub function, explain)
--Testcase 1726:
EXPLAIN VERBOSE
SELECT regexp_substr(str1, NULL, 4, 0, 'i') FROM s3;
-- select regexp_substr (stub function, result)
--Testcase 1727:
SELECT regexp_substr(str1, NULL, 4, 0, 'i') FROM s3;

-- select regexp_substr (stub function, not pushdown constraints, explain)
--Testcase 1728:
EXPLAIN VERBOSE
SELECT value1, regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 WHERE to_hex(value2) = '64';
-- select regexp_substr (stub function, not pushdown constraints, result)
--Testcase 1729:
SELECT value1, regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 WHERE to_hex(value2) = '64';

-- select regexp_substr (stub function, pushdown constraints, explain)
--Testcase 1730:
EXPLAIN VERBOSE
SELECT value1, regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 WHERE value2 != 200;
-- select regexp_substr (stub function, pushdown constraints, result)
--Testcase 1731:
SELECT value1, regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 WHERE value2 != 200;

-- select regexp_substr with non pushdown func and explicit constant (explain)
--Testcase 1732:
EXPLAIN VERBOSE
SELECT regexp_substr(str1, 'xyz', 4, 0, 'i'), pi(), 4.1 FROM s3;
-- select regexp_substr with non pushdown func and explicit constant (result)
--Testcase 1733:
SELECT regexp_substr(str1, 'xyz', 4, 0, 'i'), pi(), 4.1 FROM s3;

-- select regexp_substr with order by (explain)
--Testcase 1734:
EXPLAIN VERBOSE
SELECT value1, regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 ORDER BY regexp_substr(str1, 'xyz', 4, 0, 'i');
-- select regexp_substr with order by (result)
--Testcase 1735:
SELECT value1, regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 ORDER BY regexp_substr(str1, 'xyz', 4, 0, 'i');

-- select regexp_substr with order by index (result)
--Testcase 1736:
SELECT value1, regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 ORDER BY 2,1;
-- select regexp_substr with order by index (result)
--Testcase 1737:
SELECT value1, regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 ORDER BY 1,2;

-- select regexp_substr with group by (explain)
--Testcase 1738:
EXPLAIN VERBOSE
SELECT count(value1), regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 GROUP BY regexp_substr(str1, 'xyz', 4, 0, 'i');
-- select regexp_substr with group by (result)
--Testcase 1739:
SELECT count(value1), regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 GROUP BY regexp_substr(str1, 'xyz', 4, 0, 'i');

-- select regexp_substr with group by index (result)
--Testcase 1740:
SELECT value1, regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 GROUP BY 2,1;

-- select regexp_substr with group by having (explain)
--Testcase 1741:
EXPLAIN VERBOSE
SELECT count(value1), regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 GROUP BY regexp_substr(str1, 'xyz', 4, 0, 'i'), str1 HAVING regexp_substr(str1, 'xyz', 4, 0, 'i') IS NOT NULL;
-- select regexp_substr with group by having (result)
--Testcase 1742:
SELECT count(value1), regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 GROUP BY regexp_substr(str1, 'xyz', 4, 0, 'i'), str1 HAVING regexp_substr(str1, 'xyz', 4, 0, 'i') IS NOT NULL;

-- select regexp_substr with group by index having (result)
--Testcase 1743:
SELECT value1, regexp_substr(str1, 'xyz', 4, 0, 'i') FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test repeat()
-- ===============================================================================
-- select repeat (stub function, explain)
--Testcase 1744:
EXPLAIN VERBOSE
SELECT repeat(str1, 3), repeat(str2, 3) FROM s3;
-- select repeat (stub function, result)
--Testcase 1745:
SELECT repeat(str1, 3), repeat(str2, 3) FROM s3;

-- select repeat (stub function, not pushdown constraints, explain)
--Testcase 1746:
EXPLAIN VERBOSE
SELECT value1, repeat(str1, 3) FROM s3 WHERE to_hex(value2) = '64';
-- select repeat (stub function, not pushdown constraints, result)
--Testcase 1747:
SELECT value1, repeat(str1, 3) FROM s3 WHERE to_hex(value2) = '64';

-- select repeat (stub function, pushdown constraints, explain)
--Testcase 1748:
EXPLAIN VERBOSE
SELECT value1, repeat(str1, 3) FROM s3 WHERE value2 != 200;
-- select repeat (stub function, pushdown constraints, result)
--Testcase 1749:
SELECT value1, repeat(str1, 3) FROM s3 WHERE value2 != 200;

-- select repeat with non pushdown func and explicit constant (explain)
--Testcase 1750:
EXPLAIN VERBOSE
SELECT repeat(str1, 3), pi(), 4.1 FROM s3;
-- select repeat with non pushdown func and explicit constant (result)
--Testcase 1751:
SELECT repeat(str1, 3), pi(), 4.1 FROM s3;

-- select repeat with order by (explain)
--Testcase 1752:
EXPLAIN VERBOSE
SELECT value1, repeat(str1, 3) FROM s3 ORDER BY repeat(str1, 3);
-- select repeat with order by (result)
--Testcase 1753:
SELECT value1, repeat(str1, 3) FROM s3 ORDER BY repeat(str1, 3);

-- select repeat with order by index (result)
--Testcase 1754:
SELECT value1, repeat(str1, 3) FROM s3 ORDER BY 2,1;
-- select repeat with order by index (result)
--Testcase 1755:
SELECT value1, repeat(str1, 3) FROM s3 ORDER BY 1,2;

-- select repeat with group by (explain)
--Testcase 1756:
EXPLAIN VERBOSE
SELECT count(value1), repeat(str1, 3) FROM s3 GROUP BY repeat(str1, 3);
-- select repeat with group by (result)
--Testcase 1757:
SELECT count(value1), repeat(str1, 3) FROM s3 GROUP BY repeat(str1, 3);

-- select repeat with group by index (result)
--Testcase 1758:
SELECT value1, repeat(str1, 3) FROM s3 GROUP BY 2,1;

-- select repeat with group by having (explain)
--Testcase 1759:
EXPLAIN VERBOSE
SELECT count(value1), repeat(str1, 3) FROM s3 GROUP BY repeat(str1, 3), str1 HAVING repeat(str1, 3) IS NOT NULL;
-- select repeat with group by having (result)
--Testcase 1760:
SELECT count(value1), repeat(str1, 3) FROM s3 GROUP BY repeat(str1, 3), str1 HAVING repeat(str1, 3) IS NOT NULL;

-- select repeat with group by index having (result)
--Testcase 1761:
SELECT value1, repeat(str1, 3) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test replace()
-- ===============================================================================
-- select replace (stub function, explain)
--Testcase 1762:
EXPLAIN VERBOSE
SELECT replace(str1, 'XYZ', 'ABC'), replace(str2, 'XYZ', 'ABC') FROM s3;
-- select replace (stub function, result)
--Testcase 1763:
SELECT replace(str1, 'XYZ', 'ABC'), replace(str2, 'XYZ', 'ABC') FROM s3;

-- select replace (stub function, not pushdown constraints, explain)
--Testcase 1764:
EXPLAIN VERBOSE
SELECT value1, replace(str1, 'XYZ', 'ABC') FROM s3 WHERE to_hex(value2) = '64';
-- select replace (stub function, not pushdown constraints, result)
--Testcase 1765:
SELECT value1, replace(str1, 'XYZ', 'ABC') FROM s3 WHERE to_hex(value2) = '64';

-- select replace (stub function, pushdown constraints, explain)
--Testcase 1766:
EXPLAIN VERBOSE
SELECT value1, replace(str1, 'XYZ', 'ABC') FROM s3 WHERE value2 != 200;
-- select replace (stub function, pushdown constraints, result)
--Testcase 1767:
SELECT value1, replace(str1, 'XYZ', 'ABC') FROM s3 WHERE value2 != 200;

-- select replace with non pushdown func and explicit constant (explain)
--Testcase 1768:
EXPLAIN VERBOSE
SELECT replace(str1, 'XYZ', 'ABC'), pi(), 4.1 FROM s3;
-- select replace with non pushdown func and explicit constant (result)
--Testcase 1769:
SELECT replace(str1, 'XYZ', 'ABC'), pi(), 4.1 FROM s3;

-- select replace with order by (explain)
--Testcase 1770:
EXPLAIN VERBOSE
SELECT value1, replace(str1, 'XYZ', 'ABC') FROM s3 ORDER BY replace(str1, 'XYZ', 'ABC');
-- select replace with order by (result)
--Testcase 1771:
SELECT value1, replace(str1, 'XYZ', 'ABC') FROM s3 ORDER BY replace(str1, 'XYZ', 'ABC');

-- select replace with order by index (result)
--Testcase 1772:
SELECT value1, replace(str1, 'XYZ', 'ABC') FROM s3 ORDER BY 2,1;
-- select replace with order by index (result)
--Testcase 1773:
SELECT value1, replace(str1, 'XYZ', 'ABC') FROM s3 ORDER BY 1,2;

-- select replace with group by (explain)
--Testcase 1774:
EXPLAIN VERBOSE
SELECT count(value1), replace(str1, 'XYZ', 'ABC') FROM s3 GROUP BY replace(str1, 'XYZ', 'ABC');
-- select replace with group by (result)
--Testcase 1775:
SELECT count(value1), replace(str1, 'XYZ', 'ABC') FROM s3 GROUP BY replace(str1, 'XYZ', 'ABC');

-- select replace with group by index (result)
--Testcase 1776:
SELECT value1, replace(str1, 'XYZ', 'ABC') FROM s3 GROUP BY 2,1;

-- select replace with group by having (explain)
--Testcase 1777:
EXPLAIN VERBOSE
SELECT count(value1), replace(str1, 'XYZ', 'ABC') FROM s3 GROUP BY replace(str1, 'XYZ', 'ABC'), str1 HAVING replace(str1, 'XYZ', 'ABC') IS NOT NULL;
-- select replace with group by having (result)
--Testcase 1778:
SELECT count(value1), replace(str1, 'XYZ', 'ABC') FROM s3 GROUP BY replace(str1, 'XYZ', 'ABC'), str1 HAVING replace(str1, 'XYZ', 'ABC') IS NOT NULL;

-- select replace with group by index having (result)
--Testcase 1779:
SELECT value1, replace(str1, 'XYZ', 'ABC') FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test reverse()
-- ===============================================================================
-- select reverse (stub function, explain)
--Testcase 1780:
EXPLAIN VERBOSE
SELECT reverse(str1), reverse(str2) FROM s3;
-- select reverse (stub function, result)
--Testcase 1781:
SELECT reverse(str1), reverse(str2) FROM s3;

-- select reverse (stub function, not pushdown constraints, explain)
--Testcase 1782:
EXPLAIN VERBOSE
SELECT value1, reverse(str1) FROM s3 WHERE to_hex(value2) = '64';
-- select reverse (stub function, not pushdown constraints, result)
--Testcase 1783:
SELECT value1, reverse(str1) FROM s3 WHERE to_hex(value2) = '64';

-- select reverse (stub function, pushdown constraints, explain)
--Testcase 1784:
EXPLAIN VERBOSE
SELECT value1, reverse(str1) FROM s3 WHERE value2 != 200;
-- select reverse (stub function, pushdown constraints, result)
--Testcase 1785:
SELECT value1, reverse(str1) FROM s3 WHERE value2 != 200;

-- select reverse with non pushdown func and explicit constant (explain)
--Testcase 1786:
EXPLAIN VERBOSE
SELECT reverse(str1), pi(), 4.1 FROM s3;
-- select reverse with non pushdown func and explicit constant (result)
--Testcase 1787:
SELECT reverse(str1), pi(), 4.1 FROM s3;

-- select reverse with order by (explain)
--Testcase 1788:
EXPLAIN VERBOSE
SELECT value1, reverse(str1) FROM s3 ORDER BY reverse(str1);
-- select reverse with order by (result)
--Testcase 1789:
SELECT value1, reverse(str1) FROM s3 ORDER BY reverse(str1);

-- select reverse with order by index (result)
--Testcase 1790:
SELECT value1, reverse(str1) FROM s3 ORDER BY 2,1;
-- select reverse with order by index (result)
--Testcase 1791:
SELECT value1, reverse(str1) FROM s3 ORDER BY 1,2;

-- select reverse with group by (explain)
--Testcase 1792:
EXPLAIN VERBOSE
SELECT count(value1), reverse(str1) FROM s3 GROUP BY reverse(str1);
-- select reverse with group by (result)
--Testcase 1793:
SELECT count(value1), reverse(str1) FROM s3 GROUP BY reverse(str1);

-- select reverse with group by index (result)
--Testcase 1794:
SELECT value1, reverse(str1) FROM s3 GROUP BY 2,1;

-- select reverse with group by having (explain)
--Testcase 1795:
EXPLAIN VERBOSE
SELECT count(value1), reverse(str1) FROM s3 GROUP BY reverse(str1), str1 HAVING reverse(str1) IS NOT NULL;
-- select reverse with group by having (result)
--Testcase 1796:
SELECT count(value1), reverse(str1) FROM s3 GROUP BY reverse(str1), str1 HAVING reverse(str1) IS NOT NULL;

-- select reverse with group by index having (result)
--Testcase 1797:
SELECT value1, reverse(str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test right()
-- ===============================================================================
-- select right (stub function, explain)
--Testcase 1798:
EXPLAIN VERBOSE
SELECT right(str1, 4), right(str2, 4) FROM s3;
-- select right (stub function, result)
--Testcase 1799:
SELECT right(str1, 4), right(str2, 4) FROM s3;

-- select right (stub function, not pushdown constraints, explain)
--Testcase 1800:
EXPLAIN VERBOSE
SELECT value1, right(str1, 6) FROM s3 WHERE to_hex(value2) = '64';
-- select right (stub function, not pushdown constraints, result)
--Testcase 1801:
SELECT value1, right(str1, 6) FROM s3 WHERE to_hex(value2) = '64';

-- select right (stub function, pushdown constraints, explain)
--Testcase 1802:
EXPLAIN VERBOSE
SELECT value1, right(str1, 6) FROM s3 WHERE value2 != 200;
-- select right (stub function, pushdown constraints, result)
--Testcase 1803:
SELECT value1, right(str1, 6) FROM s3 WHERE value2 != 200;

-- select right with non pushdown func and explicit constant (explain)
--Testcase 1804:
EXPLAIN VERBOSE
SELECT right(str1, 6), pi(), 4.1 FROM s3;
-- select right with non pushdown func and explicit constant (result)
--Testcase 1805:
SELECT right(str1, 6), pi(), 4.1 FROM s3;

-- select right with order by (explain)
--Testcase 1806:
EXPLAIN VERBOSE
SELECT value1, right(str1, 6) FROM s3 ORDER BY right(str1, 6);
-- select right with order by (result)
--Testcase 1807:
SELECT value1, right(str1, 6) FROM s3 ORDER BY right(str1, 6);

-- select right with order by index (result)
--Testcase 1808:
SELECT value1, right(str1, 6) FROM s3 ORDER BY 2,1;
-- select right with order by index (result)
--Testcase 1809:
SELECT value1, right(str1, 6) FROM s3 ORDER BY 1,2;

-- select right with group by (explain)
--Testcase 1810:
EXPLAIN VERBOSE
SELECT count(value1), right(str1, 6) FROM s3 GROUP BY right(str1, 6);
-- select right with group by (result)
--Testcase 1811:
SELECT count(value1), right(str1, 6) FROM s3 GROUP BY right(str1, 6);

-- select right with group by index (result)
--Testcase 1812:
SELECT value1, right(str1, 6) FROM s3 GROUP BY 2,1;

-- select right with group by having (explain)
--Testcase 1813:
EXPLAIN VERBOSE
SELECT count(value1), right(str1, 6) FROM s3 GROUP BY right(str1, 6), str1 HAVING right(str1, 6) IS NOT NULL;
-- select right with group by having (result)
--Testcase 1814:
SELECT count(value1), right(str1, 6) FROM s3 GROUP BY right(str1, 6), str1 HAVING right(str1, 6) IS NOT NULL;

-- select right with group by index having (result)
--Testcase 1815:
SELECT value1, right(str1, 6) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test rpad()
-- ===============================================================================
-- select rpad (stub function, explain)
--Testcase 1816:
EXPLAIN VERBOSE
SELECT rpad(str1, 16, str2), rpad(str1, 4, str2) FROM s3;
-- select rpad (stub function, result)
--Testcase 1817:
SELECT rpad(str1, 16, str2), rpad(str1, 4, str2) FROM s3;

-- select rpad (stub function, not pushdown constraints, explain)
--Testcase 1818:
EXPLAIN VERBOSE
SELECT value1, rpad(str1, 16, str2) FROM s3 WHERE to_hex(value2) = '64';
-- select rpad (stub function, not pushdown constraints, result)
--Testcase 1819:
SELECT value1, rpad(str1, 16, str2) FROM s3 WHERE to_hex(value2) = '64';

-- select rpad (stub function, pushdown constraints, explain)
--Testcase 1820:
EXPLAIN VERBOSE
SELECT value1, rpad(str1, 16, str2) FROM s3 WHERE value2 != 200;
-- select rpad (stub function, pushdown constraints, result)
--Testcase 1821:
SELECT value1, rpad(str1, 16, str2) FROM s3 WHERE value2 != 200;

-- select rpad with non pushdown func and explicit constant (explain)
--Testcase 1822:
EXPLAIN VERBOSE
SELECT rpad(str1, 16, str2), pi(), 4.1 FROM s3;
-- select rpad with non pushdown func and explicit constant (result)
--Testcase 1823:
SELECT rpad(str1, 16, str2), pi(), 4.1 FROM s3;

-- select rpad with order by (explain)
--Testcase 1824:
EXPLAIN VERBOSE
SELECT value1, rpad(str1, 16, str2) FROM s3 ORDER BY rpad(str1, 16, str2);
-- select rpad with order by (result)
--Testcase 1825:
SELECT value1, rpad(str1, 16, str2) FROM s3 ORDER BY rpad(str1, 16, str2);

-- select rpad with order by index (result)
--Testcase 1826:
SELECT value1, rpad(str1, 16, str2) FROM s3 ORDER BY 2,1;
-- select rpad with order by index (result)
--Testcase 1827:
SELECT value1, rpad(str1, 16, str2) FROM s3 ORDER BY 1,2;

-- select rpad with group by (explain)
--Testcase 1828:
EXPLAIN VERBOSE
SELECT count(value1), rpad(str1, 16, str2) FROM s3 GROUP BY rpad(str1, 16, str2);
-- select rpad with group by (result)
--Testcase 1829:
SELECT count(value1), rpad(str1, 16, str2) FROM s3 GROUP BY rpad(str1, 16, str2);

-- select rpad with group by index (result)
--Testcase 1830:
SELECT value1, rpad(str1, 16, str2) FROM s3 GROUP BY 2,1;

-- select rpad with group by having (explain)
--Testcase 1831:
EXPLAIN VERBOSE
SELECT count(value1), rpad(str1, 16, str2) FROM s3 GROUP BY rpad(str1, 16, str2) HAVING rpad(str1, 16, str2) IS NOT NULL;
-- select rpad with group by having (result)
--Testcase 1832:
SELECT count(value1), rpad(str1, 16, str2) FROM s3 GROUP BY rpad(str1, 16, str2) HAVING rpad(str1, 16, str2) IS NOT NULL;

-- select rpad with group by index having (result)
--Testcase 1833:
SELECT value1, rpad(str1, 16, str2) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test rtrim()
-- ===============================================================================
-- select rtrim (stub function, explain)
--Testcase 1834:
EXPLAIN VERBOSE
SELECT rtrim(str1), rtrim(str2, ' ') FROM s3;
-- select rtrim (stub function, result)
--Testcase 1835:
SELECT rtrim(str1), rtrim(str2, ' ') FROM s3;

-- select rtrim (stub function, not pushdown constraints, explain)
--Testcase 1836:
EXPLAIN VERBOSE
SELECT value1, rtrim(str1, '-') FROM s3 WHERE to_hex(value2) = '64';
-- select rtrim (stub function, not pushdown constraints, result)
--Testcase 1837:
SELECT value1, rtrim(str1, '-') FROM s3 WHERE to_hex(value2) = '64';

-- select rtrim (stub function, pushdown constraints, explain)
--Testcase 1838:
EXPLAIN VERBOSE
SELECT value1, rtrim(str1, '-') FROM s3 WHERE value2 != 200;
-- select rtrim (stub function, pushdown constraints, result)
--Testcase 1839:
SELECT value1, rtrim(str1, '-') FROM s3 WHERE value2 != 200;

-- select rtrim with non pushdown func and explicit constant (explain)
--Testcase 1840:
EXPLAIN VERBOSE
SELECT rtrim(str1, '-'), pi(), 4.1 FROM s3;
-- select rtrim with non pushdown func and explicit constant (result)
--Testcase 1841:
SELECT rtrim(str1, '-'), pi(), 4.1 FROM s3;

-- select rtrim with order by (explain)
--Testcase 1842:
EXPLAIN VERBOSE
SELECT value1, rtrim(str1, '-') FROM s3 ORDER BY rtrim(str1, '-');
-- select rtrim with order by (result)
--Testcase 1843:
SELECT value1, rtrim(str1, '-') FROM s3 ORDER BY rtrim(str1, '-');

-- select rtrim with order by index (result)
--Testcase 1844:
SELECT value1, rtrim(str1, '-') FROM s3 ORDER BY 2,1;
-- select rtrim with order by index (result)
--Testcase 1845:
SELECT value1, rtrim(str1, '-') FROM s3 ORDER BY 1,2;

-- select rtrim with group by (explain)
--Testcase 1846:
EXPLAIN VERBOSE
SELECT count(value1), rtrim(str1, '-') FROM s3 GROUP BY rtrim(str1, '-');
-- select rtrim with group by (result)
--Testcase 1847:
SELECT count(value1), rtrim(str1, '-') FROM s3 GROUP BY rtrim(str1, '-');

-- select rtrim with group by index (result)
--Testcase 1848:
SELECT value1, rtrim(str2) FROM s3 GROUP BY 2,1;

-- select rtrim with group by having (explain)
--Testcase 1849:
EXPLAIN VERBOSE
SELECT count(value1), rtrim(str1, '-') FROM s3 GROUP BY rtrim(str1, '-') HAVING rtrim(str1, '-') IS NOT NULL;
-- select rtrim with group by having (result)
--Testcase 1850:
SELECT count(value1), rtrim(str1, '-') FROM s3 GROUP BY rtrim(str1, '-') HAVING rtrim(str1, '-') IS NOT NULL;

-- select rtrim with group by index having (result)
--Testcase 1851:
SELECT value1, rtrim(str1, '-') FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test space()
-- ===============================================================================
-- select space (stub function, explain)
--Testcase 1852:
EXPLAIN VERBOSE
SELECT space(value2), space(value4) FROM s3;
-- select space (stub function, result)
--Testcase 1853:
SELECT space(value2), space(value4) FROM s3;

-- select space (stub function, not pushdown constraints, explain)
--Testcase 1854:
EXPLAIN VERBOSE
SELECT value1, space(id) FROM s3 WHERE to_hex(value2) = '64';
-- select space (stub function, not pushdown constraints, result)
--Testcase 1855:
SELECT value1, space(id) FROM s3 WHERE to_hex(value2) = '64';

-- select space (stub function, pushdown constraints, explain)
--Testcase 1856:
EXPLAIN VERBOSE
SELECT value1, space(id) FROM s3 WHERE value2 != 200;
-- select space (stub function, pushdown constraints, result)
--Testcase 1857:
SELECT value1, space(id) FROM s3 WHERE value2 != 200;

-- select space as nest function with agg (pushdown, explain)
--Testcase 1858:
EXPLAIN VERBOSE
SELECT sum(value3), space(sum(id)) FROM s3;
-- select space as nest function with agg (pushdown, result)
--Testcase 1859:
SELECT sum(value3), space(sum(id)) FROM s3;

-- select space with non pushdown func and explicit constant (explain)
--Testcase 1860:
EXPLAIN VERBOSE
SELECT space(id), pi(), 4.1 FROM s3;
-- select space with non pushdown func and explicit constant (result)
--Testcase 1861:
SELECT space(id), pi(), 4.1 FROM s3;

-- select space with order by (explain)
--Testcase 1862:
EXPLAIN VERBOSE
SELECT value1, space(id) FROM s3 ORDER BY space(id);
-- select space with order by (result)
--Testcase 1863:
SELECT value1, space(id) FROM s3 ORDER BY space(id);

-- select space with order by index (result)
--Testcase 1864:
SELECT value1, space(id) FROM s3 ORDER BY 2,1;
-- select space with order by index (result)
--Testcase 1865:
SELECT value1, space(id) FROM s3 ORDER BY 1,2;

-- select space with group by (explain)
--Testcase 1866:
EXPLAIN VERBOSE
SELECT value1, space(id) FROM s3 GROUP BY value1, space(id);
-- select space with group by (result)
--Testcase 1867:
SELECT value1, space(id) FROM s3 GROUP BY value1, space(id);

-- select space with group by index (result)
--Testcase 1868:
SELECT value1, space(id) FROM s3 GROUP BY 2,1;

-- select space with group by having (explain)
--Testcase 1869:
EXPLAIN VERBOSE
SELECT count(value1), space(id) FROM s3 GROUP BY space(id), id HAVING space(id) IS NOT NULL;
-- select space with group by having (result)
--Testcase 1870:
SELECT count(value1), space(id) FROM s3 GROUP BY space(id), id HAVING space(id) IS NOT NULL;

-- select space with group by index having (result)
--Testcase 1871:
SELECT value1, space(id) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test strcmp()
-- ===============================================================================
-- select strcmp (stub function, explain)
--Testcase 1872:
EXPLAIN VERBOSE
SELECT strcmp(str1, str2) FROM s3;
-- select strcmp (stub function, result)
--Testcase 1873:
SELECT strcmp(str1, str2) FROM s3;

-- select strcmp (stub function, not pushdown constraints, explain)
--Testcase 1874:
EXPLAIN VERBOSE
SELECT value1, strcmp(str1, str2) FROM s3 WHERE to_hex(value2) = '64';
-- select strcmp (stub function, not pushdown constraints, result)
--Testcase 1875:
SELECT value1, strcmp(str1, str2) FROM s3 WHERE to_hex(value2) = '64';

-- select strcmp (stub function, pushdown constraints, explain)
--Testcase 1876:
EXPLAIN VERBOSE
SELECT value1, strcmp(str1, str2) FROM s3 WHERE value2 != 200;
-- select strcmp (stub function, pushdown constraints, result)
--Testcase 1877:
SELECT value1, strcmp(str1, str2) FROM s3 WHERE value2 != 200;

-- select strcmp with non pushdown func and explicit constant (explain)
--Testcase 1878:
EXPLAIN VERBOSE
SELECT strcmp(str1, str2), pi(), 4.1 FROM s3;
-- select strcmp with non pushdown func and explicit constant (result)
--Testcase 1879:
SELECT strcmp(str1, str2), pi(), 4.1 FROM s3;

-- select strcmp with order by (explain)
--Testcase 1880:
EXPLAIN VERBOSE
SELECT value1, strcmp(str1, str2) FROM s3 ORDER BY strcmp(str1, str2);
-- select strcmp with order by (result)
--Testcase 1881:
SELECT value1, strcmp(str1, str2) FROM s3 ORDER BY strcmp(str1, str2);

-- select strcmp with order by index (result)
--Testcase 1882:
SELECT value1, strcmp(str1, str2) FROM s3 ORDER BY 2,1;
-- select strcmp with order by index (result)
--Testcase 1883:
SELECT value1, strcmp(str1, str2) FROM s3 ORDER BY 1,2;

-- select strcmp with group by (explain)
--Testcase 1884:
EXPLAIN VERBOSE
SELECT count(value1), strcmp(str1, str2) FROM s3 GROUP BY strcmp(str1, str2);
-- select strcmp with group by (result)
--Testcase 1885:
SELECT count(value1), strcmp(str1, str2) FROM s3 GROUP BY strcmp(str1, str2);

-- select strcmp with group by index (result)
--Testcase 1886:
SELECT value1, strcmp(str1, str2) FROM s3 GROUP BY 2,1;

-- select strcmp with group by having (explain)
--Testcase 1887:
EXPLAIN VERBOSE
SELECT count(value1), strcmp(str1, str2) FROM s3 GROUP BY strcmp(str1, str2), str1, str2 HAVING strcmp(str1, str2) IS NOT NULL;
-- select strcmp with group by having (result)
--Testcase 1888:
SELECT count(value1), strcmp(str1, str2) FROM s3 GROUP BY strcmp(str1, str2), str1, str2 HAVING strcmp(str1, str2) IS NOT NULL;

-- select strcmp with group by index having (result)
--Testcase 1889:
SELECT value1, strcmp(str1, str2) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test substr()
-- ===============================================================================
-- select substr (stub function, explain)
--Testcase 1890:
EXPLAIN VERBOSE
SELECT substr(str1, 3), substr(str2, 3, 4) FROM s3;
-- select substr (stub function, result)
--Testcase 1891:
SELECT substr(str1, 3), substr(str2, 3, 4) FROM s3;

-- select substr (stub function, not pushdown constraints, explain)
--Testcase 1892:
EXPLAIN VERBOSE
SELECT value1, substr(str2, 3, 4) FROM s3 WHERE to_hex(value2) = '64';
-- select substr (stub function, not pushdown constraints, result)
--Testcase 1893:
SELECT value1, substr(str2, 3, 4) FROM s3 WHERE to_hex(value2) = '64';

-- select substr (stub function, pushdown constraints, explain)
--Testcase 1894:
EXPLAIN VERBOSE
SELECT value1, substr(str2, 3, 4) FROM s3 WHERE value2 != 200;
-- select substr (stub function, pushdown constraints, result)
--Testcase 1895:
SELECT value1, substr(str2, 3, 4) FROM s3 WHERE value2 != 200;

-- select substr with non pushdown func and explicit constant (explain)
--Testcase 1896:
EXPLAIN VERBOSE
SELECT substr(str2, 3, 4), pi(), 4.1 FROM s3;
-- select substr with non pushdown func and explicit constant (result)
--Testcase 1897:
SELECT substr(str2, 3, 4), pi(), 4.1 FROM s3;

-- select substr with order by (explain)
--Testcase 1898:
EXPLAIN VERBOSE
SELECT value1, substr(str2, 3, 4) FROM s3 ORDER BY substr(str2, 3, 4);
-- select substr with order by (result)
--Testcase 1899:
SELECT value1, substr(str2, 3, 4) FROM s3 ORDER BY substr(str2, 3, 4);

-- select substr with order by index (result)
--Testcase 1900:
SELECT value1, substr(str2, 3, 4) FROM s3 ORDER BY 2,1;
-- select substr with order by index (result)
--Testcase 1901:
SELECT value1, substr(str2, 3, 4) FROM s3 ORDER BY 1,2;

-- select substr with group by (explain)
--Testcase 1902:
EXPLAIN VERBOSE
SELECT count(value1), substr(str2, 3, 4) FROM s3 GROUP BY substr(str2, 3, 4);
-- select substr with group by (result)
--Testcase 1903:
SELECT count(value1), substr(str2, 3, 4) FROM s3 GROUP BY substr(str2, 3, 4);

-- select substr with group by index (result)
--Testcase 1904:
SELECT value1, substr(str2, 3, 4) FROM s3 GROUP BY 2,1;

-- select substr with group by having (explain)
--Testcase 1905:
EXPLAIN VERBOSE
SELECT count(value1), substr(str2, 3, 4) FROM s3 GROUP BY substr(str2, 3, 4), str2 HAVING substr(str2, 3, 4) IS NOT NULL;
-- select substr with group by having (result)
--Testcase 1906:
SELECT count(value1), substr(str2, 3, 4) FROM s3 GROUP BY substr(str2, 3, 4), str2 HAVING substr(str2, 3, 4) IS NOT NULL;

-- select substr with group by index having (result)
--Testcase 1907:
SELECT value1, substr(str2, 3, 4) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test substring()
-- ===============================================================================
-- select substring (stub function, explain)
--Testcase 1908:
EXPLAIN VERBOSE
SELECT substring(str1, 3), substring(str2, 3, 4) FROM s3;
-- select substring (stub function, result)
--Testcase 1909:
SELECT substring(str1, 3), substring(str2, 3, 4) FROM s3;

-- select substring (stub function, explain)
--Testcase 1910:
EXPLAIN VERBOSE
SELECT substring(str1 FROM 3), substring(str2 FROM 3 FOR 4) FROM s3;
-- select substring (stub function, result)
--Testcase 1911:
SELECT substring(str1 FROM 3), substring(str2 FROM 3 FOR 4) FROM s3;

-- select substring (stub function, not pushdown constraints, explain)
--Testcase 1912:
EXPLAIN VERBOSE
SELECT value1, substring(str2, 3, 4) FROM s3 WHERE to_hex(value2) = '64';
-- select substring (stub function, not pushdown constraints, result)
--Testcase 1913:
SELECT value1, substring(str2, 3, 4) FROM s3 WHERE to_hex(value2) = '64';

-- select substring (stub function, pushdown constraints, explain)
--Testcase 1914:
EXPLAIN VERBOSE
SELECT value1, substring(str2 FROM 3 FOR 4) FROM s3 WHERE value2 != 200;
-- select substring (stub function, pushdown constraints, result)
--Testcase 1915:
SELECT value1, substring(str2 FROM 3 FOR 4) FROM s3 WHERE value2 != 200;

-- select substring with non pushdown func and explicit constant (explain)
--Testcase 1916:
EXPLAIN VERBOSE
SELECT substring(str2 FROM 3 FOR 4), pi(), 4.1 FROM s3;
-- select substring with non pushdown func and explicit constant (result)
--Testcase 1917:
SELECT substring(str2 FROM 3 FOR 4), pi(), 4.1 FROM s3;

-- select substring with order by (explain)
--Testcase 1918:
EXPLAIN VERBOSE
SELECT value1, substring(str2 FROM 3 FOR 4) FROM s3 ORDER BY substring(str2 FROM 3 FOR 4);
-- select substring with order by (result)
--Testcase 1919:
SELECT value1, substring(str2 FROM 3 FOR 4) FROM s3 ORDER BY substring(str2 FROM 3 FOR 4);

-- select substring with order by index (result)
--Testcase 1920:
SELECT value1, substring(str2 FROM 3 FOR 4) FROM s3 ORDER BY 2,1;
-- select substring with order by index (result)
--Testcase 1921:
SELECT value1, substring(str2 FROM 3 FOR 4) FROM s3 ORDER BY 1,2;

-- select substring with group by (explain)
--Testcase 1922:
EXPLAIN VERBOSE
SELECT count(value1), substring(str2, 3, 4) FROM s3 GROUP BY substring(str2, 3, 4);
-- select substring with group by (result)
--Testcase 1923:
SELECT count(value1), substring(str2, 3, 4) FROM s3 GROUP BY substring(str2, 3, 4);

-- select substring with group by index (result)
--Testcase 1924:
SELECT value1, substring(str2, 3, 4) FROM s3 GROUP BY 2,1;

-- select substring with group by having (explain)
--Testcase 1925:
EXPLAIN VERBOSE
SELECT count(value1), substring(str2, 3, 4) FROM s3 GROUP BY substring(str2, 3, 4), str2 HAVING substring(str2, 3, 4) IS NOT NULL;
-- select substring with group by having (result)
--Testcase 1926:
SELECT count(value1), substring(str2, 3, 4) FROM s3 GROUP BY substring(str2, 3, 4), str2 HAVING substring(str2, 3, 4) IS NOT NULL;

-- select substring with group by index having (result)
--Testcase 1927:
SELECT value1, substring(str2, 3, 4) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test substring_index()
-- ===============================================================================
-- select substring_index (stub function, explain)
--Testcase 1928:
EXPLAIN VERBOSE
SELECT substring_index(str1, '-', 5), substring_index(str1, '-', -5) FROM s3;
-- select substring_index (stub function, result)
--Testcase 1929:
SELECT substring_index(str1, '-', 5), substring_index(str1, '-', -5) FROM s3;

-- select substring_index (stub function, not pushdown constraints, explain)
--Testcase 1930:
EXPLAIN VERBOSE
SELECT value1, substring_index(str1, '-', 5) FROM s3 WHERE to_hex(value2) = '64';
-- select substring_index (stub function, not pushdown constraints, result)
--Testcase 1931:
SELECT value1, substring_index(str1, '-', 5) FROM s3 WHERE to_hex(value2) = '64';

-- select substring_index (stub function, pushdown constraints, explain)
--Testcase 1932:
EXPLAIN VERBOSE
SELECT value1, substring_index(str1, '-', 5) FROM s3 WHERE value2 != 200;
-- select substring_index (stub function, pushdown constraints, result)
--Testcase 1933:
SELECT value1, substring_index(str1, '-', 5) FROM s3 WHERE value2 != 200;

-- select substring_index with non pushdown func and explicit constant (explain)
--Testcase 1934:
EXPLAIN VERBOSE
SELECT substring_index(str1, '-', 5), pi(), 4.1 FROM s3;
-- select substring_index with non pushdown func and explicit constant (result)
--Testcase 1935:
SELECT substring_index(str1, '-', 5), pi(), 4.1 FROM s3;

-- select substring_index with order by (explain)
--Testcase 1936:
EXPLAIN VERBOSE
SELECT value1, substring_index(str1, '-', 5) FROM s3 ORDER BY substring_index(str1, '-', 5);
-- select substring_index with order by (result)
--Testcase 1937:
SELECT value1, substring_index(str1, '-', 5) FROM s3 ORDER BY substring_index(str1, '-', 5);

-- select substring_index with order by index (result)
--Testcase 1938:
SELECT value1, substring_index(str1, '-', 5) FROM s3 ORDER BY 2,1;
-- select substring_index with order by index (result)
--Testcase 1939:
SELECT value1, substring_index(str1, '-', 5) FROM s3 ORDER BY 1,2;

-- select substring_index with group by (explain)
--Testcase 1940:
EXPLAIN VERBOSE
SELECT count(value1), substring_index(str1, '-', 5) FROM s3 GROUP BY substring_index(str1, '-', 5);
-- select substring_index with group by (result)
--Testcase 1941:
SELECT count(value1), substring_index(str1, '-', 5) FROM s3 GROUP BY substring_index(str1, '-', 5);

-- select substring_index with group by index (result)
--Testcase 1942:
SELECT value1, substring_index(str1, '-', 5) FROM s3 GROUP BY 2,1;

-- select substring_index with group by having (explain)
--Testcase 1943:
EXPLAIN VERBOSE
SELECT count(value1), substring_index(str1, '-', 5) FROM s3 GROUP BY substring_index(str1, '-', 5), str1 HAVING substring_index(str1, '-', 5) IS NOT NULL;
-- select substring_index with group by having (result)
--Testcase 1944:
SELECT count(value1), substring_index(str1, '-', 5) FROM s3 GROUP BY substring_index(str1, '-', 5), str1 HAVING substring_index(str1, '-', 5) IS NOT NULL;

-- select substring_index with group by index having (result)
--Testcase 1945:
SELECT value1, substring_index(str1, '-', 5) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test to_base64()
-- ===============================================================================
-- select to_base64 (stub function, explain)
--Testcase 1946:
EXPLAIN VERBOSE
SELECT id, to_base64(tag1), to_base64(str1), to_base64(str2) FROM s3;
-- select to_base64 (stub function, result)
--Testcase 1947:
SELECT id, to_base64(tag1), to_base64(str1), to_base64(str2) FROM s3;

-- select to_base64 (stub function, not pushdown constraints, explain)
--Testcase 1948:
EXPLAIN VERBOSE
SELECT value1, to_base64(str1) FROM s3 WHERE to_hex(value2) = '64';
-- select to_base64 (stub function, not pushdown constraints, result)
--Testcase 1949:
SELECT value1, to_base64(str1) FROM s3 WHERE to_hex(value2) = '64';

-- select to_base64 (stub function, pushdown constraints, explain)
--Testcase 1950:
EXPLAIN VERBOSE
SELECT value1, to_base64(str1) FROM s3 WHERE value2 != 200;
-- select to_base64 (stub function, pushdown constraints, result)
--Testcase 1951:
SELECT value1, to_base64(str1) FROM s3 WHERE value2 != 200;

-- select to_base64 with non pushdown func and explicit constant (explain)
--Testcase 1952:
EXPLAIN VERBOSE
SELECT to_base64(str1), pi(), 4.1 FROM s3;
-- select to_base64 with non pushdown func and explicit constant (result)
--Testcase 1953:
SELECT to_base64(str1), pi(), 4.1 FROM s3;

-- select to_base64 with order by (explain)
--Testcase 1954:
EXPLAIN VERBOSE
SELECT value1, to_base64(str1) FROM s3 ORDER BY to_base64(str1);
-- select to_base64 with order by (result)
--Testcase 1955:
SELECT value1, to_base64(str1) FROM s3 ORDER BY to_base64(str1);

-- select to_base64 with order by index (result)
--Testcase 1956:
SELECT value1, to_base64(str1) FROM s3 ORDER BY 2,1;
-- select to_base64 with order by index (result)
--Testcase 1957:
SELECT value1, to_base64(str1) FROM s3 ORDER BY 2,1;

-- select to_base64 with group by (explain)
--Testcase 1958:
EXPLAIN VERBOSE
SELECT count(value1), to_base64(str1) FROM s3 GROUP BY to_base64(str1);
-- select to_base64 with group by (result)
--Testcase 1959:
SELECT count(value1), to_base64(str1) FROM s3 GROUP BY to_base64(str1);

-- select to_base64 with group by index (result)
--Testcase 1960:
SELECT value1, to_base64(str1) FROM s3 GROUP BY 2,1;

-- select to_base64 with group by having (explain)
--Testcase 1961:
EXPLAIN VERBOSE
SELECT count(value1), to_base64(str1) FROM s3 GROUP BY to_base64(str1), str1 HAVING to_base64(str1) IS NOT NULL;
-- select to_base64 with group by having (result)
--Testcase 1962:
SELECT count(value1), to_base64(str1) FROM s3 GROUP BY to_base64(str1), str1 HAVING to_base64(str1) IS NOT NULL;

-- select to_base64 with group by index having (result)
--Testcase 1963:
SELECT value1, to_base64(str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test trim()
-- ===============================================================================
-- select trim (stub function, explain)
--Testcase 1964:
EXPLAIN VERBOSE
SELECT trim(str1), trim(str2) FROM s3;
-- select trim (stub function, result)
--Testcase 1965:
SELECT trim(str1), trim(str2) FROM s3;

-- select trim (stub function, explain)
--Testcase 1966:
EXPLAIN VERBOSE
SELECT trim(LEADING '-' FROM str1), trim(LEADING ' ' FROM str2) FROM s3;
-- select trim (stub function, result)
--Testcase 1967:
SELECT trim(LEADING '-' FROM str1), trim(LEADING ' ' FROM str2) FROM s3;

-- select trim (stub function, explain)
--Testcase 1968:
EXPLAIN VERBOSE
SELECT trim(BOTH '-' FROM str1), trim(BOTH ' ' FROM str2) FROM s3;
-- select trim (stub function, result)
--Testcase 1969:
SELECT trim(BOTH '-' FROM str1), trim(BOTH ' ' FROM str2) FROM s3;

-- select trim (stub function, explain)
--Testcase 1970:
EXPLAIN VERBOSE
SELECT trim(TRAILING '-' FROM str1), trim(TRAILING ' ' FROM str2) FROM s3;
-- select trim (stub function, result)
--Testcase 1971:
SELECT trim(TRAILING '-' FROM str1), trim(TRAILING ' ' FROM str2) FROM s3;

-- select trim (stub function, explain)
--Testcase 1972:
EXPLAIN VERBOSE
SELECT trim('-' FROM str1), trim(' ' FROM str2) FROM s3;
-- select trim (stub function, result)
--Testcase 1973:
SELECT trim('-' FROM str1), trim(' ' FROM str2) FROM s3;

-- select trim (stub function, not pushdown constraints, explain)
--Testcase 1974:
EXPLAIN VERBOSE
SELECT value1, trim('-' FROM str1) FROM s3 WHERE to_hex(value2) = '64';
-- select trim (stub function, not pushdown constraints, result)
--Testcase 1975:
SELECT value1, trim('-' FROM str1)  FROM s3 WHERE to_hex(value2) = '64';

-- select trim (stub function, pushdown constraints, explain)
--Testcase 1976:
EXPLAIN VERBOSE
SELECT value1, trim(TRAILING '-' FROM str1) FROM s3 WHERE value2 != 200;
-- select trim (stub function, pushdown constraints, result)
--Testcase 1977:
SELECT value1, trim(TRAILING '-' FROM str1) FROM s3 WHERE value2 != 200;

-- select trim with non pushdown func and explicit constant (explain)
--Testcase 1978:
EXPLAIN VERBOSE
SELECT trim(TRAILING '-' FROM str1), pi(), 4.1 FROM s3;
-- select trim with non pushdown func and explicit constant (result)
--Testcase 1979:
SELECT trim(TRAILING '-' FROM str1), pi(), 4.1 FROM s3;

-- select trim with order by (explain)
--Testcase 1980:
EXPLAIN VERBOSE
SELECT value1, trim(TRAILING '-' FROM str1) FROM s3 ORDER BY trim(TRAILING '-' FROM str1);
-- select trim with order by (result)
--Testcase 1981:
SELECT value1, trim(TRAILING '-' FROM str1) FROM s3 ORDER BY trim(TRAILING '-' FROM str1);

-- select trim with order by index (result)
--Testcase 1982:
SELECT value1, trim('-' FROM str1) FROM s3 ORDER BY 2,1;
-- select trim with order by index (result)
--Testcase 1983:
SELECT value1, trim('-' FROM str1) FROM s3 ORDER BY 1,2;

-- select trim with group by (explain)
--Testcase 1984:
EXPLAIN VERBOSE
SELECT count(value1), trim('-' FROM str1) FROM s3 GROUP BY trim('-' FROM str1);
-- select trim with group by (result)
--Testcase 1985:
SELECT count(value1), trim('-' FROM str1) FROM s3 GROUP BY trim('-' FROM str1);

-- select trim with group by index (result)
--Testcase 1986:
SELECT value1, trim('-' FROM str1) FROM s3 GROUP BY 2,1;

-- select trim with group by having (explain)
--Testcase 1987:
EXPLAIN VERBOSE
SELECT count(value1), trim('-' FROM str1) FROM s3 GROUP BY trim('-' FROM str1) , str1 HAVING trim('-' FROM str1) IS NOT NULL;
-- select trim with group by having (result)
--Testcase 1988:
SELECT count(value1), trim('-' FROM str1) FROM s3 GROUP BY trim('-' FROM str1) , str1 HAVING trim('-' FROM str1) IS NOT NULL;

-- select trim with group by index having (result)
--Testcase 1989:
SELECT value1, trim('-' FROM str1) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test ucase()
-- ===============================================================================
-- select ucase (stub function, explain)
--Testcase 1990:
EXPLAIN VERBOSE
SELECT ucase(tag1) FROM s3;
-- select ucase (stub function, result)
--Testcase 1991:
SELECT ucase(tag1) FROM s3;

-- select ucase (stub function, not pushdown constraints, explain)
--Testcase 1992:
EXPLAIN VERBOSE
SELECT value1, ucase(tag1) FROM s3 WHERE to_hex(value2) = '64';
-- select ucase (stub function, not pushdown constraints, result)
--Testcase 1993:
SELECT value1, ucase(tag1) FROM s3 WHERE to_hex(value2) = '64';

-- select ucase (stub function, pushdown constraints, explain)
--Testcase 1994:
EXPLAIN VERBOSE
SELECT value1, ucase(tag1) FROM s3 WHERE value2 != 200;
-- select ucase (stub function, pushdown constraints, result)
--Testcase 1995:
SELECT value1, ucase(tag1) FROM s3 WHERE value2 != 200;

-- select ucase with non pushdown func and explicit constant (explain)
--Testcase 1996:
EXPLAIN VERBOSE
SELECT ucase(tag1), pi(), 4.1 FROM s3;
-- select ucase with non pushdown func and explicit constant (result)
--Testcase 1997:
SELECT ucase(tag1), pi(), 4.1 FROM s3;

-- select ucase with order by (explain)
--Testcase 1998:
EXPLAIN VERBOSE
SELECT value1, ucase(tag1) FROM s3 ORDER BY ucase(tag1);
-- select ucase with order by (result)
--Testcase 1999:
SELECT value1, ucase(tag1) FROM s3 ORDER BY ucase(tag1);

-- select ucase with order by index (result)
--Testcase 2000:
SELECT value1, ucase(tag1) FROM s3 ORDER BY 2,1;
-- select ucase with order by index (result)
--Testcase 2001:
SELECT value1, ucase(tag1) FROM s3 ORDER BY 1,2;

-- select ucase with group by (explain)
--Testcase 2002:
EXPLAIN VERBOSE
SELECT count(value1), ucase(tag1) FROM s3 GROUP BY ucase(tag1);
-- select ucase with group by (result)
--Testcase 2003:
SELECT count(value1), ucase(tag1) FROM s3 GROUP BY ucase(tag1);

-- select ucase with group by index (result)
--Testcase 2004:
SELECT value1, ucase(tag1) FROM s3 GROUP BY 2,1;

-- select ucase with group by having (explain)
--Testcase 2005:
EXPLAIN VERBOSE
SELECT count(value1), ucase(tag1) FROM s3 GROUP BY ucase(tag1), tag1 HAVING ucase(tag1) IS NOT NULL;
-- select ucase with group by having (result)
--Testcase 2006:
SELECT count(value1), ucase(tag1) FROM s3 GROUP BY ucase(tag1), tag1 HAVING ucase(tag1) IS NOT NULL;

-- select ucase with group by index having (result)
--Testcase 2007:
SELECT value1, ucase(tag1) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test unhex()
-- ===============================================================================
-- select unhex (stub function, explain)
--Testcase 2008:
EXPLAIN VERBOSE
SELECT unhex(hex(str1)), unhex(hex(str2)) FROM s3;
-- select unhex (stub function, result)
--Testcase 2009:
SELECT unhex(hex(str1)), unhex(hex(str2)) FROM s3;

-- select unhex (stub function, not pushdown constraints, explain)
--Testcase 2010:
EXPLAIN VERBOSE
SELECT value1, unhex(hex(str2)) FROM s3 WHERE to_hex(value2) = '64';
-- select unhex (stub function, not pushdown constraints, result)
--Testcase 2011:
SELECT value1, unhex(hex(str2)) FROM s3 WHERE to_hex(value2) = '64';

-- select unhex (stub function, pushdown constraints, explain)
--Testcase 2012:
EXPLAIN VERBOSE
SELECT value1, unhex(hex(str2)) FROM s3 WHERE value2 != 200;
-- select unhex (stub function, pushdown constraints, result)
--Testcase 2013:
SELECT value1, unhex(hex(str2)) FROM s3 WHERE value2 != 200;

-- select unhex with non pushdown func and explicit constant (explain)
--Testcase 2014:
EXPLAIN VERBOSE
SELECT unhex(hex(str2)), pi(), 4.1 FROM s3;
-- select unhex with non pushdown func and explicit constant (result)
--Testcase 2015:
SELECT unhex(hex(str2)), pi(), 4.1 FROM s3;

-- select unhex with order by (explain)
--Testcase 2016:
EXPLAIN VERBOSE
SELECT value1, unhex(hex(str2)) FROM s3 ORDER BY unhex(hex(str2));
-- select unhex with order by (result)
--Testcase 2017:
SELECT value1, unhex(hex(str2)) FROM s3 ORDER BY unhex(hex(str2));

-- select unhex with order by index (result)
--Testcase 2018:
SELECT value1, unhex(hex(str2)) FROM s3 ORDER BY 2,1;
-- select unhex with order by index (result)
--Testcase 2019:
SELECT value1, unhex(hex(str2)) FROM s3 ORDER BY 1,2;

-- select unhex with group by (explain)
--Testcase 2020:
EXPLAIN VERBOSE
SELECT count(value1), unhex(hex(str2)) FROM s3 GROUP BY unhex(hex(str2));
-- select unhex with group by (result)
--Testcase 2021:
SELECT count(value1), unhex(hex(str2)) FROM s3 GROUP BY unhex(hex(str2));

-- select unhex with group by index (result)
--Testcase 2022:
SELECT value1, unhex(hex(str2)) FROM s3 GROUP BY 2,1;

-- select unhex with group by having (explain)
--Testcase 2023:
EXPLAIN VERBOSE
SELECT count(value1), unhex(hex(str2)) FROM s3 GROUP BY unhex(hex(str2)), str2 HAVING unhex(hex(str2)) IS NOT NULL;
-- select unhex with group by having (result)
--Testcase 2024:
SELECT count(value1), unhex(hex(str2)) FROM s3 GROUP BY unhex(hex(str2)), str2 HAVING unhex(hex(str2)) IS NOT NULL;

-- select unhex with group by index having (result)
--Testcase 2025:
SELECT value1, unhex(hex(str2)) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test upper()
-- ===============================================================================
-- select upper (stub function, explain)
--Testcase 2026:
EXPLAIN VERBOSE
SELECT upper(tag1), upper(str1), upper(str2) FROM s3;
-- select upper (stub function, result)
--Testcase 2027:
SELECT upper(tag1), upper(str1), upper(str2) FROM s3;

-- select upper (stub function, not pushdown constraints, explain)
--Testcase 2028:
EXPLAIN VERBOSE
SELECT value1, upper(tag1) FROM s3 WHERE to_hex(value2) = '64';
-- select upper (stub function, not pushdown constraints, result)
--Testcase 2029:
SELECT value1, upper(tag1) FROM s3 WHERE to_hex(value2) = '64';

-- select upper (stub function, pushdown constraints, explain)
--Testcase 2030:
EXPLAIN VERBOSE
SELECT value1, upper(str1) FROM s3 WHERE value2 != 200;
-- select upper (stub function, pushdown constraints, result)
--Testcase 2031:
SELECT value1, upper(str1) FROM s3 WHERE value2 != 200;

-- select upper with non pushdown func and explicit constant (explain)
--Testcase 2032:
EXPLAIN VERBOSE
SELECT upper(str1), pi(), 4.1 FROM s3;
-- select ucase with non pushdown func and explicit constant (result)
--Testcase 2033:
SELECT upper(str1), pi(), 4.1 FROM s3;

-- select upper with order by (explain)
--Testcase 2034:
EXPLAIN VERBOSE
SELECT value1, upper(str1) FROM s3 ORDER BY upper(str1);
-- select upper with order by (result)
--Testcase 2035:
SELECT value1, upper(str1) FROM s3 ORDER BY upper(str1);

-- select upper with order by index (result)
--Testcase 2036:
SELECT value1, upper(str1) FROM s3 ORDER BY 2,1;
-- select upper with order by index (result)
--Testcase 2037:
SELECT value1, upper(str1) FROM s3 ORDER BY 1,2;

-- select upper with group by (explain)
--Testcase 2038:
EXPLAIN VERBOSE
SELECT count(value1), upper(str1) FROM s3 GROUP BY upper(str1);
-- select upper with group by (result)
--Testcase 2039:
SELECT count(value1), upper(str1) FROM s3 GROUP BY upper(str1);

-- select upper with group by index (result)
--Testcase 2040:
SELECT value1, upper(str1) FROM s3 GROUP BY 2,1;

-- select upper with group by having (explain)
--Testcase 2041:
EXPLAIN VERBOSE
SELECT count(value1), upper(str1) FROM s3 GROUP BY upper(str1), tag1 HAVING upper(str1) IS NOT NULL;
-- select upper with group by having (result)
--Testcase 2042:
SELECT count(value1), upper(str1) FROM s3 GROUP BY upper(str1), tag1 HAVING upper(str1) IS NOT NULL;

-- select upper with group by index having (result)
--Testcase 2043:
SELECT value1, upper(tag1) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

-- ===============================================================================
-- test weight_string()
-- ===============================================================================
-- select weight_string (stub function, explain)
--Testcase 2044:
EXPLAIN VERBOSE
SELECT weight_string('NULL') FROM s3;
-- select weight_string (stub function, result)
--Testcase 2045:
SELECT weight_string('NULL') FROM s3;

-- select weight_string (stub function, explain)
--Testcase 2046:
EXPLAIN VERBOSE
SELECT weight_string(str1), weight_string(str1, 'CHAR', 3), weight_string(str1, 'BINARY', 5) FROM s3;
-- select weight_string (stub function, result)
--Testcase 2047:
SELECT weight_string(str1), weight_string(str1, 'CHAR', 3), weight_string(str1, 'BINARY', 5) FROM s3;

-- select weight_string (stub function, not pushdown constraints, explain)
--Testcase 2048:
EXPLAIN VERBOSE
SELECT value1, weight_string(str1, 'CHAR', 3) FROM s3 WHERE to_hex(value2) = '64';
-- select weight_string (stub function, not pushdown constraints, result)
--Testcase 2049:
SELECT value1, weight_string(str1, 'CHAR', 3) FROM s3 WHERE to_hex(value2) = '64';

-- select weight_string (stub function, pushdown constraints, explain)
--Testcase 2050:
EXPLAIN VERBOSE
SELECT value1, weight_string(str1, 'BINARY', 5) FROM s3 WHERE value2 != 200;
-- select weight_string (stub function, pushdown constraints, result)
--Testcase 2051:
SELECT value1, weight_string(str1, 'BINARY', 5) FROM s3 WHERE value2 != 200;

-- select weight_string with non pushdown func and explicit constant (explain)
--Testcase 2052:
EXPLAIN VERBOSE
SELECT weight_string(str1, 'BINARY', 5), pi(), 4.1 FROM s3;
-- select weight_string with non pushdown func and explicit constant (result)
--Testcase 2053:
SELECT weight_string(str1, 'BINARY', 5), pi(), 4.1 FROM s3;

-- select weight_string with order by (explain)
--Testcase 2054:
EXPLAIN VERBOSE
SELECT value1, weight_string(str1, 'BINARY', 5) FROM s3 ORDER BY weight_string(str1, 'BINARY', 5);
-- select weight_string with order by (result)
--Testcase 2055:
SELECT value1, weight_string(str1, 'BINARY', 5) FROM s3 ORDER BY weight_string(str1, 'BINARY', 5);

-- select weight_string with order by index (result)
--Testcase 2056:
SELECT value1, weight_string(str1, 'CHAR', 3) FROM s3 ORDER BY 2,1;
-- select weight_string with order by index (result)
--Testcase 2057:
SELECT value1, weight_string(str1, 'CHAR', 3) FROM s3 ORDER BY 1,2;

-- select weight_string with group by (explain)
--Testcase 2058:
EXPLAIN VERBOSE
SELECT count(value1), weight_string(str1, 'CHAR', 3) FROM s3 GROUP BY weight_string(str1, 'CHAR', 3);
-- select weight_string with group by (result)
--Testcase 2059:
SELECT count(value1), weight_string(str1, 'CHAR', 3) FROM s3 GROUP BY weight_string(str1, 'CHAR', 3);

-- select weight_string with group by index (result)
--Testcase 2060:
SELECT value1, weight_string(str1, 'CHAR', 3) FROM s3 GROUP BY 2,1;

-- select weight_string with group by having (explain)
--Testcase 2061:
EXPLAIN VERBOSE
SELECT count(value1), weight_string(str1, 'CHAR', 3) FROM s3 GROUP BY weight_string(str1, 'CHAR', 3), str1 HAVING weight_string(str1, 'CHAR', 3) IS NOT NULL;
-- select weight_string with group by having (result)
--Testcase 2062:
SELECT count(value1), weight_string(str1, 'CHAR', 3) FROM s3 GROUP BY weight_string(str1, 'CHAR', 3), str1 HAVING weight_string(str1, 'CHAR', 3) IS NOT NULL;

-- select weight_string with group by index having (result)
--Testcase 2063:
SELECT value1, weight_string(str1, 'CHAR', 3) FROM s3 GROUP BY 1,2 HAVING value1 > 1;

--Testcase 2064:
DROP FOREIGN TABLE s3;

--Testcase 2065:
DROP FOREIGN TABLE s5;


--Testcase 2066:
CREATE FOREIGN TABLE time_tbl(id int, c1 time without time zone, c2 date, c3 timestamp) SERVER server1 OPTIONS(dbname 'mysql_fdw_regress', table_name 'time_tbl');

--Testcase 2067:
SELECT * FROM time_tbl;

--
-- test for date/time function
--

-- ADDDATE()
-- select adddate (stub function, explain)
--Testcase 2068:
EXPLAIN VERBOSE
SELECT adddate(c2, 31), adddate(c2, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, 31) FROM time_tbl;

-- select adddate (stub function, result)
--Testcase 2069:
SELECT adddate(c2, 31), adddate(c2, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, 31) FROM time_tbl;

-- select adddate (stub function, not pushdown constraints, explain)
--Testcase 2070:
EXPLAIN VERBOSE
SELECT adddate(c2, 31), adddate(c2, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, 31) FROM time_tbl WHERE to_hex(id) = '1';

-- select adddate (stub function, not pushdown constraints, result)
--Testcase 2071:
SELECT adddate(c2, 31), adddate(c2, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, 31) FROM time_tbl WHERE to_hex(id) = '1';

-- select adddate (stub function, pushdown constraints, explain)
--Testcase 2072:
EXPLAIN VERBOSE
SELECT adddate(c2, 31), adddate(c2, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, 31) FROM time_tbl WHERE id != 0;

-- select adddate (stub function, pushdown constraints, result)
--Testcase 2073:
SELECT adddate(c2, 31), adddate(c2, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, 31) FROM time_tbl WHERE id != 0;

-- select adddate (stub function, adddate in constraints, explain)
--Testcase 2074:
EXPLAIN VERBOSE
SELECT adddate(c2, 31), adddate(c2, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, 31) FROM time_tbl WHERE adddate(c2, 31) != '2021-01-02';

-- select adddate (stub function, adddate in constraints, result)
--Testcase 2075:
SELECT adddate(c2, 31), adddate(c2, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, 31) FROM time_tbl WHERE adddate(c2, 31) != '2021-01-02';

-- select adddate (stub function, adddate in constraints, explain)
--Testcase 2076:
EXPLAIN VERBOSE
SELECT adddate(c2, 31), adddate(c2, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, 31) FROM time_tbl WHERE adddate('2021-01-02'::date, 31) > '2021-01-02';

-- select adddate (stub function, adddate in constraints, result)
--Testcase 2077:
SELECT adddate(c2, 31), adddate(c2, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes'), adddate('2021-01-02'::date, 31) FROM time_tbl WHERE adddate('2021-01-02'::date, 31) > '2021-01-02';

-- select adddate as nest function with agg (pushdown, explain)
--Testcase 2078:
EXPLAIN VERBOSE
SELECT max(id), adddate('2021-01-02'::date, max(id)) FROM time_tbl;

-- select adddate as nest function with agg (pushdown, result)
--Testcase 2079:
SELECT max(id), adddate('2021-01-02'::date, max(id)) FROM time_tbl;

-- select adddate as nest with stub (pushdown, explain)
--Testcase 2080:
EXPLAIN VERBOSE
SELECT adddate(makedate(2019, id), 31) FROM time_tbl;

-- select adddate as nest with stub (pushdown, result)
--Testcase 2081:
SELECT adddate(makedate(2019, id), 31) FROM time_tbl;

-- select adddate with non pushdown func and explicit constant (explain)
--Testcase 2082:
EXPLAIN VERBOSE
SELECT adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes'), pi(), 4.1 FROM time_tbl;

-- select adddate with non pushdown func and explicit constant (result)
--Testcase 2083:
SELECT adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes'), pi(), 4.1 FROM time_tbl;

-- select adddate with order by (explain)
--Testcase 2084:
EXPLAIN VERBOSE
SELECT id, adddate(c2, id + 5) FROM time_tbl order by adddate(c2, id + 5);

-- select adddate with order by (result)
--Testcase 2085:
SELECT id, adddate(c2, id + 5) FROM time_tbl order by adddate(c2, id + 5);

-- select adddate with order by index (explain)
--Testcase 2086:
EXPLAIN VERBOSE
SELECT id, adddate(c2, id + 5) FROM time_tbl order by 1,2;

-- select adddate with order by index (result)
--Testcase 2087:
SELECT id, adddate(c2, id + 5) FROM time_tbl order by 1,2;

-- select adddate with group by (explain)
--Testcase 2088:
EXPLAIN VERBOSE
SELECT count(id), adddate(c2, id + 5) FROM time_tbl group by adddate(c2, id + 5);

-- select adddate with group by (result)
--Testcase 2089:
SELECT count(id), adddate(c2, id + 5) FROM time_tbl group by adddate(c2, id + 5);

-- select adddate with group by index (result)
--Testcase 2090:
SELECT id, adddate(c2, id + 5) FROM time_tbl group by 2,1;

-- select adddate with group by index (result)
--Testcase 2091:
SELECT id, adddate(c2, id + 5) FROM time_tbl group by 1,2;

-- select adddate with group by having (explain)
--Testcase 2092:
EXPLAIN VERBOSE
SELECT count(id), adddate(c2, id + 5) FROM time_tbl group by adddate(c2, id + 5), id,c2 HAVING adddate(c2, id + 5) > '2000-01-02';

-- select adddate with group by having (result)
--Testcase 2093:
SELECT count(id), adddate(c2, id + 5) FROM time_tbl group by adddate(c2, id + 5), id,c2 HAVING adddate(c2, id + 5) > '2000-01-02';

-- select adddate with group by index having (result)
--Testcase 2094:
SELECT id, adddate(c2, id + 5), c2 FROM time_tbl group by 3,2,1 HAVING adddate(c2, id + 5) > '2000-01-02';

-- select adddate with group by index having (result)
--Testcase 2095:
SELECT id, adddate(c2, id + 5), c2 FROM time_tbl group by 1,2,3 HAVING adddate(c2, id + 5) > '2000-01-02';

-- select adddate and as
--Testcase 2096:
SELECT adddate('2021-01-02'::date, INTERVAL '6 months 2 hours 30 minutes') as adddate1 FROM time_tbl;


-- ADDTIME()
-- select addtime (stub function, explain)
--Testcase 2097:
EXPLAIN VERBOSE
SELECT addtime(c3, '1 12:59:10'), addtime(c3, INTERVAL '6 months 2 hours 30 minutes'), addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), addtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl;

-- select addtime (stub function, result)
--Testcase 2098:
SELECT addtime(c3, '1 12:59:10'), addtime(c3, INTERVAL '6 months 2 hours 30 minutes'), addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), addtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl;

-- select addtime (stub function, not pushdown constraints, explain)
--Testcase 2099:
EXPLAIN VERBOSE
SELECT addtime(c3, '1 12:59:10'), addtime(c3, INTERVAL '6 months 2 hours 30 minutes'), addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), addtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE to_hex(id) = '1';

-- select addtime (stub function, not pushdown constraints, result)
--Testcase 2100:
SELECT addtime(c3, '1 12:59:10'), addtime(c3, INTERVAL '6 months 2 hours 30 minutes'), addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), addtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE to_hex(id) = '1';

-- select addtime (stub function, pushdown constraints, explain)
--Testcase 2101:
EXPLAIN VERBOSE
SELECT addtime(c3, '1 12:59:10'), addtime(c3, INTERVAL '6 months 2 hours 30 minutes'), addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), addtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE id != 0;

-- select addtime (stub function, pushdown constraints, result)
--Testcase 2102:
SELECT addtime(c3, '1 12:59:10'), addtime(c3, INTERVAL '6 months 2 hours 30 minutes'), addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), addtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE id != 0;

-- select addtime (stub function, addtime in constraints, explain)
--Testcase 2103:
EXPLAIN VERBOSE
SELECT addtime(c3, '1 12:59:10'), addtime(c3, INTERVAL '6 months 2 hours 30 minutes'), addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), addtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE addtime(c3, '1 12:59:10') != '2000-01-01';

-- select addtime (stub function, addtime in constraints, result)
--Testcase 2104:
SELECT addtime(c3, '1 12:59:10'), addtime(c3, INTERVAL '6 months 2 hours 30 minutes'), addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), addtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE addtime(c3, '1 12:59:10') != '2000-01-01';

-- select addtime (stub function, addtime in constraints, explain)
--Testcase 2105:
EXPLAIN VERBOSE
SELECT addtime(c3, '1 12:59:10'), addtime(c3, INTERVAL '6 months 2 hours 30 minutes'), addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), addtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE addtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') > '1';

-- select addtime (stub function, addtime in constraints, result)
--Testcase 2106:
SELECT addtime(c3, '1 12:59:10'), addtime(c3, INTERVAL '6 months 2 hours 30 minutes'), addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), addtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE addtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') > '1';

-- select addtime with agg (pushdown, explain)
--Testcase 2107:
EXPLAIN VERBOSE
SELECT max(c1), addtime('2021-01-02'::date, max(c1)) FROM time_tbl;

-- select addtime as nest function with agg (pushdown, result)
--Testcase 2108:
SELECT max(c1), addtime('2021-01-02'::date, max(c1)) FROM time_tbl;

-- select addtime as nest with stub (pushdown, explain)
--Testcase 2109:
EXPLAIN VERBOSE
SELECT addtime(maketime(12, 15, 30), '1 12:59:10') FROM time_tbl;

-- select addtime as nest with stub (pushdown, result)
--Testcase 2110:
SELECT addtime(maketime(12, 15, 30), '1 12:59:10') FROM time_tbl;

-- select addtime with non pushdown func and explicit constant (explain)
--Testcase 2111:
EXPLAIN VERBOSE
SELECT addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), pi(), 4.1 FROM time_tbl;

-- select addtime with non pushdown func and explicit constant (result)
--Testcase 2112:
SELECT addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), pi(), 4.1 FROM time_tbl;

-- select addtime with order by (explain)
--Testcase 2113:
EXPLAIN VERBOSE
SELECT id, addtime(c1, c1 + '1 12:59:10') FROM time_tbl order by addtime(c1, c1 + '1 12:59:10');

-- select addtime with order by (result)
--Testcase 2114:
SELECT id, addtime(c1, c1 + '1 12:59:10') FROM time_tbl order by addtime(c1, c1 + '1 12:59:10');

-- select addtime with order by index (result)
--Testcase 2115:
SELECT id, addtime(c1, c1 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select addtime with order by index (result)
--Testcase 2116:
SELECT id, addtime(c1, c1 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select addtime with group by (explain)
--Testcase 2117:
EXPLAIN VERBOSE
SELECT count(id), addtime(c1, c1 + '1 12:59:10') FROM time_tbl group by addtime(c1, c1 + '1 12:59:10');

-- select addtime with group by (result)
--Testcase 2118:
SELECT count(id), addtime(c1, c1 + '1 12:59:10') FROM time_tbl group by addtime(c1, c1 + '1 12:59:10');

-- select addtime with group by index (result)
--Testcase 2119:
SELECT id, addtime(c1, c1 + '1 12:59:10') FROM time_tbl group by 2,1;

-- select addtime with group by index (result)
--Testcase 2120:
SELECT id, addtime(c1, c1 + '1 12:59:10') FROM time_tbl group by 1,2;

-- select addtime with group by having (explain)
--Testcase 2121:
EXPLAIN VERBOSE
SELECT count(id), addtime(c1, c1 + '1 12:59:10') FROM time_tbl group by addtime(c1, c1 + '1 12:59:10'), c1 HAVING addtime(c1, c1 + '1 12:59:10') > '1 12:59:10';

-- select addtime with group by having (result)
--Testcase 2122:
SELECT count(id), addtime(c1, c1 + '1 12:59:10') FROM time_tbl group by addtime(c1, c1 + '1 12:59:10'), c1 HAVING addtime(c1, c1 + '1 12:59:10') > '1 12:59:10';

-- select addtime and as
--Testcase 2123:
SELECT addtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes') as addtime1 FROM time_tbl;


-- CONVERT_TZ
-- select convert_tz (stub function, explain)
--Testcase 2124:
EXPLAIN VERBOSE
SELECT convert_tz(c3,'+00:00','+10:00'), convert_tz(c3, 'GMT', 'MET'), convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET'), convert_tz('2021-01-01 12:00:00','+00:00','+10:00') FROM time_tbl;

-- select convert_tz (stub function, result)
--Testcase 2125:
SELECT convert_tz(c3,'+00:00','+10:00'), convert_tz(c3, 'GMT', 'MET'), convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET'), convert_tz('2021-01-01 12:00:00','+00:00','+10:00') FROM time_tbl;

-- select convert_tz (stub function, not pushdown constraints, explain)
--Testcase 2126:
EXPLAIN VERBOSE
SELECT convert_tz(c3,'+00:00','+10:00'), convert_tz(c3, 'GMT', 'MET'), convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET'), convert_tz('2021-01-01 12:00:00','+00:00','+10:00') FROM time_tbl WHERE to_hex(id) = '1';

-- select convert_tz (stub function, not pushdown constraints, result)
--Testcase 2127:
SELECT convert_tz(c3,'+00:00','+10:00'), convert_tz(c3, 'GMT', 'MET'), convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET'), convert_tz('2021-01-01 12:00:00','+00:00','+10:00') FROM time_tbl WHERE to_hex(id) = '1';

-- select convert_tz (stub function, pushdown constraints, explain)
--Testcase 2128:
EXPLAIN VERBOSE
SELECT convert_tz(c3,'+00:00','+10:00'), convert_tz(c3, 'GMT', 'MET'), convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET'), convert_tz('2021-01-01 12:00:00','+00:00','+10:00') FROM time_tbl WHERE id != 0;

-- select convert_tz (stub function, pushdown constraints, result)
--Testcase 2129:
SELECT convert_tz(c3,'+00:00','+10:00'), convert_tz(c3, 'GMT', 'MET'), convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET'), convert_tz('2021-01-01 12:00:00','+00:00','+10:00') FROM time_tbl WHERE id != 0;

-- select convert_tz (stub function, convert_tz in constraints, explain)
--Testcase 2130:
EXPLAIN VERBOSE
SELECT convert_tz(c3,'+00:00','+10:00'), convert_tz(c3, 'GMT', 'MET'), convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET'), convert_tz('2021-01-01 12:00:00','+00:00','+10:00') FROM time_tbl WHERE convert_tz(c3,'+00:00','+10:00') != '2000-01-01';

-- select convert_tz (stub function, convert_tz in constraints, result)
--Testcase 2131:
SELECT convert_tz(c3,'+00:00','+10:00'), convert_tz(c3, 'GMT', 'MET'), convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET'), convert_tz('2021-01-01 12:00:00','+00:00','+10:00') FROM time_tbl WHERE convert_tz(c3,'+00:00','+10:00') != '2000-01-01';

-- select convert_tz (stub function, convert_tz in constraints, explain)
--Testcase 2132:
EXPLAIN VERBOSE
SELECT convert_tz(c3,'+00:00','+10:00'), convert_tz(c3, 'GMT', 'MET'), convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET'), convert_tz('2021-01-01 12:00:00','+00:00','+10:00') FROM time_tbl WHERE convert_tz('2021-01-01 12:00:00','+00:00','+10:00') > '2000-01-01';

-- select convert_tz (stub function, convert_tz in constraints, result)
--Testcase 2133:
SELECT convert_tz(c3,'+00:00','+10:00'), convert_tz(c3, 'GMT', 'MET'), convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET'), convert_tz('2021-01-01 12:00:00','+00:00','+10:00') FROM time_tbl WHERE convert_tz('2021-01-01 12:00:00','+00:00','+10:00') > '2000-01-01';

-- select convert_tz with agg (pushdown, explain)
--Testcase 2134:
EXPLAIN VERBOSE
SELECT max(c3), convert_tz(max(c3), '+00:00','+10:00') FROM time_tbl;

-- select convert_tz as nest function with agg (pushdown, result)
--Testcase 2135:
SELECT max(c3), convert_tz(max(c3), '+00:00','+10:00') FROM time_tbl;

-- select convert_tz with non pushdown func and explicit constant (explain)
--Testcase 2136:
EXPLAIN VERBOSE
SELECT convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET'), pi(), 4.1 FROM time_tbl;

-- select convert_tz with non pushdown func and explicit constant (result)
--Testcase 2137:
SELECT convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET'), pi(), 4.1 FROM time_tbl;

-- select convert_tz with order by (explain)
--Testcase 2138:
EXPLAIN VERBOSE
SELECT id, convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') FROM time_tbl order by convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00');

-- select convert_tz with order by (result)
--Testcase 2139:
SELECT id, convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') FROM time_tbl order by convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00');

-- select convert_tz with order by index (result)
--Testcase 2140:
SELECT id, convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') FROM time_tbl order by 2,1;

-- select convert_tz with order by index (result)
--Testcase 2141:
SELECT id, convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') FROM time_tbl order by 1,2;

-- select convert_tz with group by (explain)
--Testcase 2142:
EXPLAIN VERBOSE
SELECT count(id), convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') FROM time_tbl group by convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00');

-- select convert_tz with group by (result)
--Testcase 2143:
SELECT count(id), convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') FROM time_tbl group by convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00');

-- select convert_tz with group by index (result)
--Testcase 2144:
SELECT id, convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') FROM time_tbl group by 2,1;

-- select convert_tz with group by index (result)
--Testcase 2145:
SELECT id, convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') FROM time_tbl group by 1,2;

-- select convert_tz with group by having (explain)
--Testcase 2146:
EXPLAIN VERBOSE
SELECT count(id), convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') FROM time_tbl group by convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00'),id,c3 HAVING convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') > '2000-01-01 12:59:10';

-- select convert_tz with group by having (result)
--Testcase 2147:
SELECT count(id), convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') FROM time_tbl group by convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00'),id,c3 HAVING convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') > '2000-01-01 12:59:10';

-- select convert_tz with group by index having (result)
--Testcase 2148:
SELECT id, c3, convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') FROM time_tbl group by 3,2,1 HAVING convert_tz(c3 + '1 12:59:10' , '+00:00','+10:00') > '2000-01-01 12:59:10';

-- select convert_tz and as
--Testcase 2149:
SELECT convert_tz(date_sub(c3, '1 12:59:10'), 'GMT', 'MET') as convert_tz1 FROM time_tbl;

-- CURDATE()
-- curdate is mutable function, some executes will return different result
-- select curdate (stub function, explain)
--Testcase 2150:
EXPLAIN VERBOSE
SELECT curdate() FROM time_tbl;

-- select curdate (stub function, not pushdown constraints, explain)
--Testcase 2151:
EXPLAIN VERBOSE
SELECT curdate() FROM time_tbl WHERE to_hex(id) > '0';

-- select curdate (stub function, pushdown constraints, explain)
--Testcase 2152:
EXPLAIN VERBOSE
SELECT curdate() FROM time_tbl WHERE id = 1;

-- select curdate (stub function, curdate in constraints, explain)
--Testcase 2153:
EXPLAIN VERBOSE
SELECT curdate() FROM time_tbl WHERE curdate() > '2000-01-01';

-- curdate in constrains (stub function, explain)
--Testcase 2154:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE curdate() > '2000-01-01';

-- curdate in constrains (stub function, result)
--Testcase 2155:
SELECT c1 FROM time_tbl WHERE curdate() > '2000-01-01';

-- curdate as parameter of adddate(stub function, explain)
--Testcase 2156:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE adddate(curdate(), 31) > '2000-01-01';

-- curdate as parameter of adddate(stub function, result)
--Testcase 2157:
SELECT c1 FROM time_tbl WHERE adddate(curdate(), 31) > '2000-01-01';

-- select curdate and agg (pushdown, explain)
--Testcase 2158:
EXPLAIN VERBOSE
SELECT curdate(), sum(id) FROM time_tbl;

-- select curdate and log2 (pushdown, explain)
--Testcase 2159:
EXPLAIN VERBOSE
SELECT curdate(), log2(id) FROM time_tbl;

-- select curdate with non pushdown func and explicit constant (explain)
--Testcase 2160:
EXPLAIN VERBOSE
SELECT curdate(), to_hex(id), 4 FROM time_tbl;

-- select curdate with order by (explain)
--Testcase 2161:
EXPLAIN VERBOSE
SELECT curdate(), c1 FROM time_tbl ORDER BY c1;

-- select curdate with order by index (explain)
--Testcase 2162:
EXPLAIN VERBOSE
SELECT curdate(), c1 FROM time_tbl ORDER BY 2;

-- curdate constraints with order by (explain)
--Testcase 2163:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE adddate(curdate(), 31) > '2000-01-01' ORDER BY c1;

-- curdate constraints with order by (result)
--Testcase 2164:
SELECT c1 FROM time_tbl WHERE adddate(curdate(), 31) > '2000-01-01' ORDER BY c1;

-- select curdate with group by (explain)
--Testcase 2165:
EXPLAIN VERBOSE
SELECT curdate(), c1 FROM time_tbl GROUP BY c1;

-- select curdate with group by index (explain)
--Testcase 2166:
EXPLAIN VERBOSE
SELECT curdate(), c1 FROM time_tbl GROUP BY 2;

-- select curdate with group by having (explain)
--Testcase 2167:
EXPLAIN VERBOSE
SELECT curdate(), c1 FROM time_tbl GROUP BY curdate(),c1 HAVING curdate() > '2000-01-01';

-- select curdate with group by index having (explain)
--Testcase 2168:
EXPLAIN VERBOSE
SELECT curdate(), c1 FROM time_tbl GROUP BY 1,2 HAVING curdate() > '2000-01-01';

-- curdate constraints with group by (explain)
--Testcase 2169:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE adddate(curdate(), 31) > '2000-01-01' GROUP BY c1;

-- curdate constraints with group by (result)
--Testcase 2170:
SELECT c1 FROM time_tbl WHERE adddate(curdate(), 31) > '2000-01-01' GROUP BY c1;

-- select curdate and as
--Testcase 2171:
EXPLAIN VERBOSE
SELECT curdate() as curdate1 FROM time_tbl;

-- CURRENT_DATE()
-- mysql_current_date is mutable function, some executes will return different result
-- select mysql_current_date (stub function, explain)
--Testcase 2172:
EXPLAIN VERBOSE
SELECT mysql_current_date() FROM time_tbl;

-- select mysql_current_date (stub function, not pushdown constraints, explain)
--Testcase 2173:
EXPLAIN VERBOSE
SELECT mysql_current_date() FROM time_tbl WHERE to_hex(id) > '0';

-- select mysql_current_date (stub function, pushdown constraints, explain)
--Testcase 2174:
EXPLAIN VERBOSE
SELECT mysql_current_date() FROM time_tbl WHERE id = 1;

-- select mysql_current_date (stub function, mysql_current_date in constraints, explain)
--Testcase 2175:
EXPLAIN VERBOSE
SELECT mysql_current_date() FROM time_tbl WHERE mysql_current_date() > '2000-01-01';

-- mysql_current_date in constrains (stub function, explain)
--Testcase 2176:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE mysql_current_date() > '2000-01-01';

-- mysql_current_date in constrains (stub function, result)
--Testcase 2177:
SELECT c1 FROM time_tbl WHERE mysql_current_date() > '2000-01-01';

-- mysql_current_date as parameter of adddate(stub function, explain)
--Testcase 2178:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE adddate(mysql_current_date(), 31) > '2000-01-01';

-- mysql_current_date as parameter of adddate(stub function, result)
--Testcase 2179:
SELECT c1 FROM time_tbl WHERE adddate(mysql_current_date(), 31) > '2000-01-01';

-- select mysql_current_date and agg (pushdown, explain)
--Testcase 2180:
EXPLAIN VERBOSE
SELECT mysql_current_date(), sum(id) FROM time_tbl;

-- select mysql_current_date and log2 (pushdown, explain)
--Testcase 2181:
EXPLAIN VERBOSE
SELECT mysql_current_date(), log2(id) FROM time_tbl;

-- select mysql_current_date with non pushdown func and explicit constant (explain)
--Testcase 2182:
EXPLAIN VERBOSE
SELECT mysql_current_date(), to_hex(id), 4 FROM time_tbl;

-- select mysql_current_date with order by (explain)
--Testcase 2183:
EXPLAIN VERBOSE
SELECT mysql_current_date(), c1 FROM time_tbl ORDER BY c1;

-- select mysql_current_date with order by index (explain)
--Testcase 2184:
EXPLAIN VERBOSE
SELECT mysql_current_date(), c1 FROM time_tbl ORDER BY 2;

-- mysql_current_date constraints with order by (explain)
--Testcase 2185:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE adddate(mysql_current_date(), 31) > '2000-01-01' ORDER BY c1;

-- mysql_current_date constraints with order by (result)
--Testcase 2186:
SELECT c1 FROM time_tbl WHERE adddate(mysql_current_date(), 31) > '2000-01-01' ORDER BY c1;

-- select mysql_current_date with group by (explain)
--Testcase 2187:
EXPLAIN VERBOSE
SELECT mysql_current_date(), c1 FROM time_tbl GROUP BY c1;

-- select mysql_current_date with group by index (explain)
--Testcase 2188:
EXPLAIN VERBOSE
SELECT mysql_current_date(), c1 FROM time_tbl GROUP BY 2;

-- select mysql_current_date with group by having (explain)
--Testcase 2189:
EXPLAIN VERBOSE
SELECT mysql_current_date(), c1 FROM time_tbl GROUP BY mysql_current_date(), c1 HAVING mysql_current_date() > '2000-01-01';

-- select mysql_current_date with group by index having (explain)
--Testcase 2190:
EXPLAIN VERBOSE
SELECT mysql_current_date(), c1 FROM time_tbl GROUP BY 2,1 HAVING mysql_current_date() > '2000-01-01';

-- mysql_current_date constraints with group by (explain)
--Testcase 2191:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE adddate(mysql_current_date(), 31) > '2000-01-01' GROUP BY c1;

-- mysql_current_date constraints with group by (result)
--Testcase 2192:
SELECT c1 FROM time_tbl WHERE adddate(mysql_current_date(), 31) > '2000-01-01' GROUP BY c1;

-- select mysql_current_date and as
--Testcase 2193:
EXPLAIN VERBOSE
SELECT mysql_current_date() as mysql_current_date1 FROM time_tbl;


-- CURTIME()
-- curtime is mutable function, some executes will return different result
-- select curtime (stub function, explain)
--Testcase 2194:
EXPLAIN VERBOSE
SELECT curtime() FROM time_tbl;

-- select curtime (stub function, not pushdown constraints, explain)
--Testcase 2195:
EXPLAIN VERBOSE
SELECT curtime() FROM time_tbl WHERE to_hex(id) > '0';

-- select curtime (stub function, pushdown constraints, explain)
--Testcase 2196:
EXPLAIN VERBOSE
SELECT curtime() FROM time_tbl WHERE id = 1;

-- select curtime (stub function, curtime in constraints, explain)
--Testcase 2197:
EXPLAIN VERBOSE
SELECT curtime() FROM time_tbl WHERE curtime() > '00:00:00';

-- curtime in constrains (stub function, explain)
--Testcase 2198:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE curtime() > '00:00:00';

-- curtime in constrains (stub function, result)
--Testcase 2199:
SELECT c1 FROM time_tbl WHERE curtime() > '00:00:00';

-- curtime as parameter of addtime(stub function, explain)
--Testcase 2200:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(curtime(), '1 12:59:10') > '00:00:00';

-- curtime as parameter of addtime(stub function, result)
--Testcase 2201:
SELECT c1 FROM time_tbl WHERE addtime(curtime(), '1 12:59:10') > '00:00:00';

-- select curtime and agg (pushdown, explain)
--Testcase 2202:
EXPLAIN VERBOSE
SELECT curtime(), sum(id) FROM time_tbl;

-- select curtime and log2 (pushdown, explain)
--Testcase 2203:
EXPLAIN VERBOSE
SELECT curtime(), log2(id) FROM time_tbl;

-- select curtime with non pushdown func and explicit constant (explain)
--Testcase 2204:
EXPLAIN VERBOSE
SELECT curtime(), to_hex(id), 4 FROM time_tbl;

-- select curtime with order by (explain)
--Testcase 2205:
EXPLAIN VERBOSE
SELECT curtime(), c1 FROM time_tbl ORDER BY c1;

-- select curtime with order by index (explain)
--Testcase 2206:
EXPLAIN VERBOSE
SELECT curtime(), c1 FROM time_tbl ORDER BY 2;

-- curtime constraints with order by (explain)
--Testcase 2207:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(curtime(), '1 12:59:10') > '00:00:00' ORDER BY c1;

-- curtime constraints with order by (result)
--Testcase 2208:
SELECT c1 FROM time_tbl WHERE addtime(curtime(), '1 12:59:10') > '00:00:00' ORDER BY c1;

-- select curtime with group by (explain)
--Testcase 2209:
EXPLAIN VERBOSE
SELECT curtime(), c1 FROM time_tbl GROUP BY c1;

-- select curtime with group by index (explain)
--Testcase 2210:
EXPLAIN VERBOSE
SELECT curtime(), c1 FROM time_tbl GROUP BY 2;

-- select curtime with group by having (explain)
--Testcase 2211:
EXPLAIN VERBOSE
SELECT curtime(), c1 FROM time_tbl GROUP BY curtime(),c1 HAVING curtime() > '00:00:00';

-- select curtime with group by index having (explain)
--Testcase 2212:
EXPLAIN VERBOSE
SELECT curtime(), c1 FROM time_tbl GROUP BY 2,1 HAVING curtime() > '00:00:00';

-- curtime constraints with group by (explain)
--Testcase 2213:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(curtime(), '1 12:59:10') > '00:00:00' GROUP BY c1;

-- curtime constraints with group by (result)
--Testcase 2214:
SELECT c1 FROM time_tbl WHERE addtime(curtime(), '1 12:59:10') > '00:00:00' GROUP BY c1;

-- select curtime and as
--Testcase 2215:
EXPLAIN VERBOSE
SELECT curtime() as curtime1 FROM time_tbl;


-- CURRENT_TIME()
-- mysql_current_time is mutable function, some executes will return different result
-- select mysql_current_time (stub function, explain)
--Testcase 2216:
EXPLAIN VERBOSE
SELECT mysql_current_time() FROM time_tbl;

-- select mysql_current_time (stub function, not pushdown constraints, explain)
--Testcase 2217:
EXPLAIN VERBOSE
SELECT mysql_current_time() FROM time_tbl WHERE to_hex(id) > '0';

-- select mysql_current_time (stub function, pushdown constraints, explain)
--Testcase 2218:
EXPLAIN VERBOSE
SELECT mysql_current_time() FROM time_tbl WHERE id = 1;

-- select mysql_current_time (stub function, mysql_current_time in constraints, explain)
--Testcase 2219:
EXPLAIN VERBOSE
SELECT mysql_current_time() FROM time_tbl WHERE mysql_current_time() > '00:00:00';

-- mysql_current_time in constrains (stub function, explain)
--Testcase 2220:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE mysql_current_time() > '00:00:00';

-- mysql_current_time in constrains (stub function, result)
--Testcase 2221:
SELECT c1 FROM time_tbl WHERE mysql_current_time() > '00:00:00';

-- mysql_current_time as parameter of addtime(stub function, explain)
--Testcase 2222:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_current_time(), '1 12:59:10') > '00:00:00';

-- mysql_current_time as parameter of addtime(stub function, result)
--Testcase 2223:
SELECT c1 FROM time_tbl WHERE addtime(mysql_current_time(), '1 12:59:10') > '00:00:00';

-- select mysql_current_time and agg (pushdown, explain)
--Testcase 2224:
EXPLAIN VERBOSE
SELECT mysql_current_time(), sum(id) FROM time_tbl;

-- select mysql_current_time and log2 (pushdown, explain)
--Testcase 2225:
EXPLAIN VERBOSE
SELECT mysql_current_time(), log2(id) FROM time_tbl;

-- select mysql_current_time with non pushdown func and explicit constant (explain)
--Testcase 2226:
EXPLAIN VERBOSE
SELECT mysql_current_time(), to_hex(id), 4 FROM time_tbl;

-- select mysql_current_time with order by (explain)
--Testcase 2227:
EXPLAIN VERBOSE
SELECT mysql_current_time(), c1 FROM time_tbl ORDER BY c1;

-- select mysql_current_time with order by index (explain)
--Testcase 2228:
EXPLAIN VERBOSE
SELECT mysql_current_time(), c1 FROM time_tbl ORDER BY 2;

-- mysql_current_time constraints with order by (explain)
--Testcase 2229:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_current_time(), '1 12:59:10') > '00:00:00' ORDER BY c1;

-- mysql_current_time constraints with order by (result)
--Testcase 2230:
SELECT c1 FROM time_tbl WHERE addtime(mysql_current_time(), '1 12:59:10') > '00:00:00' ORDER BY c1;

-- select mysql_current_time with group by (explain)
--Testcase 2231:
EXPLAIN VERBOSE
SELECT mysql_current_time(), c1 FROM time_tbl GROUP BY c1;

-- select mysql_current_time with group by index (explain)
--Testcase 2232:
EXPLAIN VERBOSE
SELECT mysql_current_time(), c1 FROM time_tbl GROUP BY 2;

-- select mysql_current_time with group by having (explain)
--Testcase 2233:
EXPLAIN VERBOSE
SELECT mysql_current_time(), c1 FROM time_tbl GROUP BY mysql_current_time(),c1 HAVING mysql_current_time() > '00:00:00';

-- select mysql_current_time with group by index having (explain)
--Testcase 2234:
EXPLAIN VERBOSE
SELECT mysql_current_time(), c1 FROM time_tbl GROUP BY 2,1 HAVING mysql_current_time() > '00:00:00';

-- mysql_current_time constraints with group by (explain)
--Testcase 2235:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_current_time(), '1 12:59:10') > '00:00:00' GROUP BY c1;

-- mysql_current_time constraints with group by (result)
--Testcase 2236:
SELECT c1 FROM time_tbl WHERE addtime(mysql_current_time(), '1 12:59:10') > '00:00:00' GROUP BY c1;

-- select mysql_current_time and as
--Testcase 2237:
EXPLAIN VERBOSE
SELECT mysql_current_time() as mysql_current_time1 FROM time_tbl;


-- CURRENT_TIMESTAMP
-- mysql_current_timestamp is mutable function, some executes will return different result
-- select mysql_current_timestamp (stub function, explain)
--Testcase 2238:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp() FROM time_tbl;

-- select mysql_current_timestamp (stub function, not pushdown constraints, explain)
--Testcase 2239:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp() FROM time_tbl WHERE to_hex(id) > '0';

-- select mysql_current_timestamp (stub function, pushdown constraints, explain)
--Testcase 2240:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp() FROM time_tbl WHERE id = 1;

-- select mysql_current_timestamp (stub function, mysql_current_timestamp in constraints, explain)
--Testcase 2241:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp() FROM time_tbl WHERE mysql_current_timestamp() > '2000-01-01 00:00:00'::timestamp;

-- mysql_current_timestamp in constrains (stub function, explain)
--Testcase 2242:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE mysql_current_timestamp() > '2000-01-01 00:00:00'::timestamp;

-- mysql_current_timestamp in constrains (stub function, result)
--Testcase 2243:
SELECT c1 FROM time_tbl WHERE mysql_current_timestamp() > '2000-01-01 00:00:00'::timestamp;

-- mysql_current_timestamp as parameter of addtime(stub function, explain)
--Testcase 2244:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_current_timestamp(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp;

-- mysql_current_timestamp as parameter of addtime(stub function, result)
--Testcase 2245:
SELECT c1 FROM time_tbl WHERE addtime(mysql_current_timestamp(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp;

-- select mysql_current_timestamp and agg (pushdown, explain)
--Testcase 2246:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp(), sum(id) FROM time_tbl;

-- select mysql_current_timestamp and log2 (pushdown, explain)
--Testcase 2247:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp(), log2(id) FROM time_tbl;

-- select mysql_current_timestamp with non pushdown func and explicit constant (explain)
--Testcase 2248:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp(), to_hex(id), 4 FROM time_tbl;

-- select mysql_current_timestamp with order by (explain)
--Testcase 2249:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp(), c1 FROM time_tbl ORDER BY mysql_current_timestamp();

-- select mysql_current_timestamp with order by index (explain)
--Testcase 2250:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp(), c1 FROM time_tbl ORDER BY 1;

-- mysql_current_timestamp constraints with order by (explain)
--Testcase 2251:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_current_timestamp(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp ORDER BY c1;

-- mysql_current_timestamp constraints with order by (result)
--Testcase 2252:
SELECT c1 FROM time_tbl WHERE addtime(mysql_current_timestamp(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp ORDER BY c1;

-- select mysql_current_timestamp with group by (explain)
--Testcase 2253:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp(), c1 FROM time_tbl GROUP BY c1;

-- select mysql_current_timestamp with group by index (explain)
--Testcase 2254:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp(), c1 FROM time_tbl GROUP BY 2;

-- select mysql_current_timestamp with group by having (explain)
--Testcase 2255:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp(), c1 FROM time_tbl GROUP BY mysql_current_timestamp(),c1 HAVING mysql_current_timestamp() > '2000-01-01 00:00:00'::timestamp;

-- select mysql_current_timestamp with group by index having (explain)
--Testcase 2256:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp(), c1 FROM time_tbl GROUP BY 2,1 HAVING mysql_current_timestamp() > '2000-01-01 00:00:00'::timestamp;

-- mysql_current_timestamp constraints with group by (explain)
--Testcase 2257:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_current_timestamp(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp GROUP BY c1;

-- mysql_current_timestamp constraints with group by (result)
--Testcase 2258:
SELECT c1 FROM time_tbl WHERE addtime(mysql_current_timestamp(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp GROUP BY c1;

-- select mysql_current_timestamp and as
--Testcase 2259:
EXPLAIN VERBOSE
SELECT mysql_current_timestamp() as mysql_current_timestamp1 FROM time_tbl;


-- DATE()
-- select date (stub function, explain)
--Testcase 2260:
EXPLAIN VERBOSE
SELECT date(c3), date(c2), date(date_sub(c3, '1 12:59:10')), date('2021-01-01 12:00:00') FROM time_tbl;

-- select date (stub function, result)
--Testcase 2261:
SELECT date(c3), date(c2), date(date_sub(c3, '1 12:59:10')), date('2021-01-01 12:00:00') FROM time_tbl;

-- select date (stub function, not pushdown constraints, explain)
--Testcase 2262:
EXPLAIN VERBOSE
SELECT date(c3), date(c2), date(date_sub(c3, '1 12:59:10')), date('2021-01-01 12:00:00') FROM time_tbl WHERE to_hex(id) = '1';

-- select date (stub function, not pushdown constraints, result)
--Testcase 2263:
SELECT date(c3), date(c2), date(date_sub(c3, '1 12:59:10')), date('2021-01-01 12:00:00') FROM time_tbl WHERE to_hex(id) = '1';

-- select date (stub function, pushdown constraints, explain)
--Testcase 2264:
EXPLAIN VERBOSE
SELECT date(c3), date(c2), date(date_sub(c3, '1 12:59:10')), date('2021-01-01 12:00:00') FROM time_tbl WHERE id != 0;

-- select date (stub function, pushdown constraints, result)
--Testcase 2265:
SELECT date(c3), date(c2), date(date_sub(c3, '1 12:59:10')), date('2021-01-01 12:00:00') FROM time_tbl WHERE id != 0;

-- select date (stub function, date in constraints, explain)
--Testcase 2266:
EXPLAIN VERBOSE
SELECT date(c3), date(c2), date(date_sub(c3, '1 12:59:10')), date('2021-01-01 12:00:00') FROM time_tbl WHERE date(c3) != '2000-01-01';

-- select date (stub function, date in constraints, result)
--Testcase 2267:
SELECT date(c3), date(c2), date(date_sub(c3, '1 12:59:10')), date('2021-01-01 12:00:00') FROM time_tbl WHERE date(c3) != '2000-01-01';

-- select date (stub function, date in constraints, explain)
--Testcase 2268:
EXPLAIN VERBOSE
SELECT date(c3), date(c2), date(date_sub(c3, '1 12:59:10')), date('2021-01-01 12:00:00') FROM time_tbl WHERE date('2021-01-01 12:00:00') > '2000-01-01';

-- select date (stub function, date in constraints, result)
--Testcase 2269:
SELECT date(c3), date(c2), date(date_sub(c3, '1 12:59:10')), date('2021-01-01 12:00:00') FROM time_tbl WHERE date('2021-01-01 12:00:00') > '2000-01-01';

-- select date with agg (pushdown, explain)
--Testcase 2270:
EXPLAIN VERBOSE
SELECT max(c3), date(max(c3)) FROM time_tbl;

-- select date as nest function with agg (pushdown, result)
--Testcase 2271:
SELECT max(c3), date(max(c3)) FROM time_tbl;

-- select date with non pushdown func and explicit constant (explain)
--Testcase 2272:
EXPLAIN VERBOSE
SELECT date(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl;

-- select date with non pushdown func and explicit constant (result)
--Testcase 2273:
SELECT date(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl;

-- select date with order by (explain)
--Testcase 2274:
EXPLAIN VERBOSE
SELECT id, date(c3 + '1 12:59:10') FROM time_tbl order by date(c3 + '1 12:59:10');

-- select date with order by (result)
--Testcase 2275:
SELECT id, date(c3 + '1 12:59:10') FROM time_tbl order by date(c3 + '1 12:59:10');

-- select date with order by index (result)
--Testcase 2276:
SELECT id, date(c3 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select date with order by index (result)
--Testcase 2277:
SELECT id, date(c3 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select date with group by (explain)
--Testcase 2278:
EXPLAIN VERBOSE
SELECT max(c3), date(c3 + '1 12:59:10') FROM time_tbl group by date(c3 + '1 12:59:10');

-- select date with group by (result)
--Testcase 2279:
SELECT max(c3), date(c3 + '1 12:59:10') FROM time_tbl group by date(c3 + '1 12:59:10');

-- select date with group by index (result)
--Testcase 2280:
SELECT id, date(c3 + '1 12:59:10') FROM time_tbl group by 2,1;

-- select date with group by index (result)
--Testcase 2281:
SELECT id, date(c3 + '1 12:59:10') FROM time_tbl group by 1,2;

-- select date with group by having (explain)
--Testcase 2282:
EXPLAIN VERBOSE
SELECT max(c3), date(c3 + '1 12:59:10') FROM time_tbl group by date(c3 + '1 12:59:10'), c3 HAVING date(c3) > '2000-01-01';

-- select date with group by having (result)
--Testcase 2283:
SELECT max(c3), date(c3 + '1 12:59:10') FROM time_tbl group by date(c3 + '1 12:59:10'), c3 HAVING date(c3) > '2000-01-01';

-- select date with group by index having (result)
--Testcase 2284:
SELECT id, date(c3 + '1 12:59:10'), c3 FROM time_tbl group by 3, 2, 1 HAVING date(c3 + '1 12:59:10') > '2000-01-01';

-- select date with group by index having (result)
--Testcase 2285:
SELECT id, date(c3 + '1 12:59:10'), c3 FROM time_tbl group by 1, 2, 3 HAVING date(c3 + '1 12:59:10') > '2000-01-01';

-- select date and as
--Testcase 2286:
SELECT date(date_sub(c3, '1 12:59:10')) as date1 FROM time_tbl;


-- DATE_ADD()
-- select date_add (stub function, explain)
--Testcase 2287:
EXPLAIN VERBOSE
SELECT date_add(c2, '1 12:59:10'::interval), date_add('2021-01-02', '1-2'::interval), date_add(date_sub(c3, '1 12:59:10'),  '1-2'::interval), date_add('2021-01-02', '1-2'::interval) FROM time_tbl;

-- select date_add (stub function, result)
--Testcase 2288:
SELECT date_add(c2, '1 12:59:10'::interval), date_add('2021-01-02', '1-2'::interval), date_add(date_sub(c3, '1 12:59:10'),  '1-2'::interval), date_add('2021-01-02', '1-2'::interval) FROM time_tbl;

-- select date_add (stub function, not pushdown constraints, explain)
--Testcase 2289:
EXPLAIN VERBOSE
SELECT date_add(c2, '1 12:59:10'::interval), date_add('2021-01-02', '1-2'::interval), date_add(date_sub(c3, '1 12:59:10'),  '1-2'::interval), date_add('2021-01-02', '1-2'::interval) FROM time_tbl WHERE to_hex(id) = '1';

-- select date_add (stub function, not pushdown constraints, result)
--Testcase 2290:
SELECT date_add(c2, '1 12:59:10'::interval), date_add('2021-01-02', '1-2'::interval), date_add(date_sub(c3, '1 12:59:10'),  '1-2'::interval), date_add('2021-01-02', '1-2'::interval) FROM time_tbl WHERE to_hex(id) = '1';

-- select date_add (stub function, pushdown constraints, explain)
--Testcase 2291:
EXPLAIN VERBOSE
SELECT date_add(c2, '1 12:59:10'::interval), date_add('2021-01-02', '1-2'::interval), date_add(date_sub(c3, '1 12:59:10'),  '1-2'::interval), date_add('2021-01-02', '1-2'::interval) FROM time_tbl WHERE id != 1;

-- select date_add (stub function, pushdown constraints, result)
--Testcase 2292:
SELECT date_add(c2, '1 12:59:10'::interval), date_add('2021-01-02', '1-2'::interval), date_add(date_sub(c3, '1 12:59:10'),  '1-2'::interval), date_add('2021-01-02', '1-2'::interval) FROM time_tbl WHERE id != 1;

-- select date_add (stub function, date_add in constraints, explain)
--Testcase 2293:
EXPLAIN VERBOSE
SELECT date_add(c2, '1 12:59:10'::interval), date_add('2021-01-02', '1-2'::interval), date_add(date_sub(c3, '1 12:59:10'),  '1-2'::interval), date_add('2021-01-02', '1-2'::interval) FROM time_tbl WHERE date_add(c2, '1 12:59:10'::interval) != '2000-01-01';

-- select date_add (stub function, date_add in constraints, result)
--Testcase 2294:
SELECT date_add(c2, '1 12:59:10'::interval), date_add('2021-01-02', '1-2'::interval), date_add(date_sub(c3, '1 12:59:10'),  '1-2'::interval), date_add('2021-01-02', '1-2'::interval) FROM time_tbl WHERE date_add(c2, '1 12:59:10'::interval) != '2000-01-01';

-- select date_add (stub function, date_add in constraints, explain)
--Testcase 2295:
EXPLAIN VERBOSE
SELECT date_add(c2, '1 12:59:10'::interval), date_add('2021-01-02', '1-2'::interval), date_add(date_sub(c3, '1 12:59:10'),  '1-2'::interval), date_add('2021-01-02', '1-2'::interval) FROM time_tbl WHERE date_add('2021-01-02', '1-2'::interval) > '2000-01-01';

-- select date_add (stub function, date_add in constraints, result)
--Testcase 2296:
SELECT date_add(c2, '1 12:59:10'::interval), date_add('2021-01-02', '1-2'::interval), date_add(date_sub(c3, '1 12:59:10'),  '1-2'::interval), date_add('2021-01-02', '1-2'::interval) FROM time_tbl WHERE date_add('2021-01-02', '1-2'::interval) > '2000-01-01';

-- select date_add with agg (pushdown, explain)
--Testcase 2297:
EXPLAIN VERBOSE
SELECT max(c3), date_add(max(c2) , '1-2'::interval) FROM time_tbl;

-- select date_add as nest function with agg (pushdown, result)
--Testcase 2298:
SELECT max(c3), date_add(max(c2) , '1-2'::interval) FROM time_tbl;

-- select date_add with non pushdown func and explicit constant (explain)
--Testcase 2299:
EXPLAIN VERBOSE
SELECT date_add(date_sub(c3, '1 12:59:10'),  '1-2'::interval), pi(), 4.1 FROM time_tbl;

-- select date_add with non pushdown func and explicit constant (result)
--Testcase 2300:
SELECT date_add(date_sub(c3, '1 12:59:10'),  '1-2'::interval), pi(), 4.1 FROM time_tbl;

-- select date_add with order by (explain)
--Testcase 2301:
EXPLAIN VERBOSE
SELECT id, date_add(c2 + '1 d'::interval , '1-2'::interval) FROM time_tbl order by date_add(c2 + '1 d'::interval , '1-2'::interval);

-- select date_add with order by (result)
--Testcase 2302:
SELECT id, date_add(c2 + '1 d'::interval , '1-2'::interval) FROM time_tbl order by date_add(c2 + '1 d'::interval , '1-2'::interval);

-- select date_add with order by index (result)
--Testcase 2303:
SELECT id, date_add(c2 + '1 d'::interval , '1-2'::interval) FROM time_tbl order by 2,1;

-- select date_add with order by index (result)
--Testcase 2304:
SELECT id, date_add(c2 + '1 d'::interval , '1-2'::interval) FROM time_tbl order by 1,2;

-- select date_add with group by (explain)
--Testcase 2305:
EXPLAIN VERBOSE
SELECT max(c3), date_add(c2 + '1 d'::interval , '1-2'::interval) FROM time_tbl group by date_add(c2 + '1 d'::interval , '1-2'::interval);

-- select date_add with group by (result)
--Testcase 2306:
SELECT max(c3), date_add(c2 + '1 d'::interval , '1-2'::interval) FROM time_tbl group by date_add(c2 + '1 d'::interval , '1-2'::interval);

-- select date_add with group by index (result)
--Testcase 2307:
SELECT id, date_add(c2 + '1 d'::interval , '1-2'::interval) FROM time_tbl group by 2,1;

-- select date_add with group by index (result)
--Testcase 2308:
SELECT id, date_add(c2 + '1 d'::interval , '1-2'::interval) FROM time_tbl group by 1,2;

-- select date_add with group by having (explain)
--Testcase 2309:
EXPLAIN VERBOSE
SELECT max(c3), date_add(c2 + '1 d'::interval , '1-2'::interval), c2 FROM time_tbl group by date_add(c2 + '1 d'::interval , '1-2'::interval), c3,c2 HAVING date_add(c2 + '1 d'::interval , '1-2'::interval) > '2000-01-01';

-- select date_add with group by having (result)
--Testcase 2310:
SELECT max(c3), date_add(c2 + '1 d'::interval , '1-2'::interval), c2 FROM time_tbl group by date_add(c2 + '1 d'::interval , '1-2'::interval), c3,c2 HAVING date_add(c2 + '1 d'::interval , '1-2'::interval) > '2000-01-01';

-- select date_add with group by index having (result)
--Testcase 2311:
SELECT c2, date_add(c2 + '1 d'::interval , '1-2'::interval), c3 FROM time_tbl group by 3, 2, 1 HAVING date_add(c2 + '1 d'::interval , '1-2'::interval) > '2000-01-01';

-- select date_add with group by index having (result)
--Testcase 2312:
SELECT c2, date_add(c2 + '1 d'::interval , '1-2'::interval), c3 FROM time_tbl group by 1, 2, 3 HAVING date_add(c2 + '1 d'::interval , '1-2'::interval) > '2000-01-01';

-- select date_add and as
--Testcase 2313:
SELECT date_add(date_sub(c3, '1 12:59:10'),  '1-2'::interval) as date_add1 FROM time_tbl;


-- DATE_FORMAT()
-- select date_format (stub function, explain)
--Testcase 2314:
EXPLAIN VERBOSE
SELECT date_format(c3,'%H %k %I %r %T %S %w'), date_format(c3, '%W %M %Y'), date_format(c2, '%X %V'), date_format('2009-10-04 22:23:00'::timestamp, '%W %M %Y') FROM time_tbl;

-- select date_format (stub function, result)
--Testcase 2315:
SELECT date_format(c3,'%H %k %I %r %T %S %w'), date_format(c3, '%W %M %Y'), date_format(c2, '%X %V'), date_format('2009-10-04 22:23:00'::timestamp, '%W %M %Y') FROM time_tbl;

-- select date_format (stub function, not pushdown constraints, explain)
--Testcase 2316:
EXPLAIN VERBOSE
SELECT date_format(c3,'%H %k %I %r %T %S %w'), date_format(c3, '%W %M %Y'), date_format(c2, '%X %V'), date_format('2009-10-04 22:23:00'::timestamp, '%W %M %Y') FROM time_tbl WHERE to_hex(id) = '1';

-- select date_format (stub function, not pushdown constraints, result)
--Testcase 2317:
SELECT date_format(c3,'%H %k %I %r %T %S %w'), date_format(c3, '%W %M %Y'), date_format(c2, '%X %V'), date_format('2009-10-04 22:23:00'::timestamp, '%W %M %Y') FROM time_tbl WHERE to_hex(id) = '1';

-- select date_format (stub function, pushdown constraints, explain)
--Testcase 2318:
EXPLAIN VERBOSE
SELECT date_format(c3,'%H %k %I %r %T %S %w'), date_format(c3, '%W %M %Y'), date_format(c2, '%X %V'), date_format('2009-10-04 22:23:00'::timestamp, '%W %M %Y') FROM time_tbl WHERE id != 1;

-- select date_format (stub function, pushdown constraints, result)
--Testcase 2319:
SELECT date_format(c3,'%H %k %I %r %T %S %w'), date_format(c3, '%W %M %Y'), date_format(c2, '%X %V'), date_format('2009-10-04 22:23:00'::timestamp, '%W %M %Y') FROM time_tbl WHERE id != 1;

-- select date_format (stub function, date_format in constraints, explain)
--Testcase 2320:
EXPLAIN VERBOSE
SELECT date_format(c3,'%H %k %I %r %T %S %w'), date_format(c3, '%W %M %Y'), date_format(c2, '%X %V'), date_format('2009-10-04 22:23:00'::timestamp, '%W %M %Y') FROM time_tbl WHERE date_format(c3,'%H %k %I %r %T %S %w') NOT LIKE '2000-01-01';

-- select date_format (stub function, date_format in constraints, result)
--Testcase 2321:
SELECT date_format(c3,'%H %k %I %r %T %S %w'), date_format(c3, '%W %M %Y'), date_format(c2, '%X %V'), date_format('2009-10-04 22:23:00'::timestamp, '%W %M %Y') FROM time_tbl WHERE date_format(c3,'%H %k %I %r %T %S %w') NOT LIKE '2000-01-01';

-- select date_format (stub function, date_format in constraints, explain)
--Testcase 2322:
EXPLAIN VERBOSE
SELECT date_format(c3,'%H %k %I %r %T %S %w'), date_format(c3, '%W %M %Y'), date_format(c2, '%X %V'), date_format('2009-10-04 22:23:00'::timestamp, '%W %M %Y') FROM time_tbl WHERE date_format('2009-10-04 22:23:00'::timestamp, '%W %M %Y') IS NOT NULL;

-- select date_format (stub function, date_format in constraints, result)
--Testcase 2323:
SELECT date_format(c3,'%H %k %I %r %T %S %w'), date_format(c3, '%W %M %Y'), date_format(c2, '%X %V'), date_format('2009-10-04 22:23:00'::timestamp, '%W %M %Y') FROM time_tbl WHERE date_format('2009-10-04 22:23:00'::timestamp, '%W %M %Y') IS NOT NULL;

-- select date_format with agg (pushdown, explain)
--Testcase 2324:
EXPLAIN VERBOSE
SELECT max(c3), date_format(max(c3), '%H %k %I %r %T %S %w') FROM time_tbl;

-- select date_format as nest function with agg (pushdown, result)
--Testcase 2325:
SELECT max(c3), date_format(max(c3), '%H %k %I %r %T %S %w') FROM time_tbl;

-- select date_format with non pushdown func and explicit constant (explain)
--Testcase 2326:
EXPLAIN VERBOSE
SELECT date_format(c2, '%X %V'), pi(), 4.1 FROM time_tbl;

-- select date_format with non pushdown func and explicit constant (result)
--Testcase 2327:
SELECT date_format(c2, '%X %V'), pi(), 4.1 FROM time_tbl;

-- select date_format with order by (explain)
--Testcase 2328:
EXPLAIN VERBOSE
SELECT id, date_format(c3 + '1 12:59:10', '%H:%i:%s') FROM time_tbl order by date_format(c3 + '1 12:59:10', '%H:%i:%s');

-- select date_format with order by (result)
--Testcase 2329:
SELECT id, date_format(c3 + '1 12:59:10', '%H:%i:%s') FROM time_tbl order by date_format(c3 + '1 12:59:10', '%H:%i:%s');

-- select date_format with order by index (result)
--Testcase 2330:
SELECT id, date_format(c3 + '1 12:59:10', '%H:%i:%s') FROM time_tbl order by 2,1;

-- select date_format with order by index (result)
--Testcase 2331:
SELECT id, date_format(c3 + '1 12:59:10', '%H:%i:%s') FROM time_tbl order by 1,2;

-- select date_format with group by (explain)
--Testcase 2332:
EXPLAIN VERBOSE
SELECT max(c3), date_format(c3 + '1 12:59:10', '%H:%i:%s') FROM time_tbl group by date_format(c3 + '1 12:59:10', '%H:%i:%s');

-- select date_format with group by (result)
--Testcase 2333:
SELECT max(c3), date_format(c3 + '1 12:59:10', '%H:%i:%s') FROM time_tbl group by date_format(c3 + '1 12:59:10', '%H:%i:%s');

-- select date_format with group by index (result)
--Testcase 2334:
SELECT id, date_format(c3 + '1 12:59:10', '%H:%i:%s') FROM time_tbl group by 2,1;

-- select date_format with group by index (result)
--Testcase 2335:
SELECT id, date_format(c3 + '1 12:59:10', '%H:%i:%s') FROM time_tbl group by 1,2;

-- select date_format with group by having (explain)
--Testcase 2336:
EXPLAIN VERBOSE
SELECT max(c3), date_format(c3 + '1 12:59:10', '%H:%i:%s') FROM time_tbl group by date_format(c3 + '1 12:59:10', '%H:%i:%s'), c3 HAVING date_format(c3 + '1 12:59:10', '%H:%i:%s') > '2000-01-01';

-- select date_format with group by having (result)
--Testcase 2337:
SELECT max(c3), date_format(c3 + '1 12:59:10', '%H:%i:%s') FROM time_tbl group by date_format(c3 + '1 12:59:10', '%H:%i:%s'), c3 HAVING date_format(c3 + '1 12:59:10', '%H:%i:%s') > '2000-01-01';

-- select date_format with group by index having (result)
--Testcase 2338:
SELECT id, date_format(c3 + '1 12:59:10', '%H:%i:%s'), c3 FROM time_tbl group by 3, 2, 1 HAVING date_format(c3 + '1 12:59:10', '%H:%i:%s') IS NOT NULL;

-- select date_format with group by index having (result)
--Testcase 2339:
SELECT id, date_format(c3 + '1 12:59:10', '%H:%i:%s'), c3 FROM time_tbl group by 1, 2, 3 HAVING date_format(c3 + '1 12:59:10', '%H:%i:%s') IS NOT NULL;

-- select date_format and as
--Testcase 2340:
SELECT date_format(c2, '%X %V') as date_format1 FROM time_tbl;


-- DATE_SUB()
-- select date_sub (stub function, explain)
--Testcase 2341:
EXPLAIN VERBOSE
SELECT date_sub(c2, '1 12:59:10'), date_sub(c2, '1-1'), date_sub(date_sub(c3, '1 12:59:10'), '1-1'), date_sub('2021-01-01 12:00:00'::timestamp, '1-1') FROM time_tbl;

-- select date_sub (stub function, result)
--Testcase 2342:
SELECT date_sub(c2, '1 12:59:10'), date_sub(c2, '1-1'), date_sub(date_sub(c3, '1 12:59:10'), '1-1'), date_sub('2021-01-01 12:00:00'::timestamp, '1-1') FROM time_tbl;

-- select date_sub (stub function, not pushdown constraints, explain)
--Testcase 2343:
EXPLAIN VERBOSE
SELECT date_sub(c2, '1 12:59:10'), date_sub(c2, '1-1'), date_sub(date_sub(c3, '1 12:59:10'), '1-1'), date_sub('2021-01-01 12:00:00'::timestamp, '1-1') FROM time_tbl WHERE to_hex(id) = '1';

-- select date_sub (stub function, not pushdown constraints, result)
--Testcase 2344:
SELECT date_sub(c2, '1 12:59:10'), date_sub(c2, '1-1'), date_sub(date_sub(c3, '1 12:59:10'), '1-1'), date_sub('2021-01-01 12:00:00'::timestamp, '1-1') FROM time_tbl WHERE to_hex(id) = '1';

-- select date_sub (stub function, pushdown constraints, explain)
--Testcase 2345:
EXPLAIN VERBOSE
SELECT date_sub(c2, '1 12:59:10'), date_sub(c2, '1-1'), date_sub(date_sub(c3, '1 12:59:10'), '1-1'), date_sub('2021-01-01 12:00:00'::timestamp, '1-1') FROM time_tbl WHERE id != 1;

-- select date_sub (stub function, pushdown constraints, result)
--Testcase 2346:
SELECT date_sub(c2, '1 12:59:10'), date_sub(c2, '1-1'), date_sub(date_sub(c3, '1 12:59:10'), '1-1'), date_sub('2021-01-01 12:00:00'::timestamp, '1-1') FROM time_tbl WHERE id != 1;

-- select date_sub (stub function, date_sub in constraints, explain)
--Testcase 2347:
EXPLAIN VERBOSE
SELECT date_sub(c2, '1 12:59:10'), date_sub(c2, '1-1'), date_sub(date_sub(c3, '1 12:59:10'), '1-1'), date_sub('2021-01-01 12:00:00'::timestamp, '1-1') FROM time_tbl WHERE date_sub(c2, '1 12:59:10') != '2000-01-01';

-- select date_sub (stub function, date_sub in constraints, result)
--Testcase 2348:
SELECT date_sub(c2, '1 12:59:10'), date_sub(c2, '1-1'), date_sub(date_sub(c3, '1 12:59:10'), '1-1'), date_sub('2021-01-01 12:00:00'::timestamp, '1-1') FROM time_tbl WHERE date_sub(c2, '1 12:59:10') != '2000-01-01';

-- select date_sub (stub function, date_sub in constraints, explain)
--Testcase 2349:
EXPLAIN VERBOSE
SELECT date_sub(c2, '1 12:59:10'), date_sub(c2, '1-1'), date_sub(date_sub(c3, '1 12:59:10'), '1-1'), date_sub('2021-01-01 12:00:00'::timestamp, '1-1') FROM time_tbl WHERE date_sub('2021-01-01 12:00:00'::timestamp, '1-1') > '2000-01-01';

-- select date_sub (stub function, date_sub in constraints, result)
--Testcase 2350:
SELECT date_sub(c2, '1 12:59:10'), date_sub(c2, '1-1'), date_sub(date_sub(c3, '1 12:59:10'), '1-1'), date_sub('2021-01-01 12:00:00'::timestamp, '1-1') FROM time_tbl WHERE date_sub('2021-01-01 12:00:00'::timestamp, '1-1') > '2000-01-01';

-- select date_sub with agg (pushdown, explain)
--Testcase 2351:
EXPLAIN VERBOSE
SELECT max(c3), date_sub(max(c3), '1 12:59:10') FROM time_tbl;

-- select date_sub as nest function with agg (pushdown, result)
--Testcase 2352:
SELECT max(c3), date_sub(max(c3), '1 12:59:10') FROM time_tbl;

-- select date_sub with non pushdown func and explicit constant (explain)
--Testcase 2353:
EXPLAIN VERBOSE
SELECT date_sub(date_sub(c3, '1 12:59:10'), '1-1'), pi(), 4.1 FROM time_tbl;

-- select date_sub with non pushdown func and explicit constant (result)
--Testcase 2354:
SELECT date_sub(date_sub(c3, '1 12:59:10'), '1-1'), pi(), 4.1 FROM time_tbl;

-- select date_sub with order by (explain)
--Testcase 2355:
EXPLAIN VERBOSE
SELECT id, date_sub(c3 + '1 12:59:10', '1 12:59:10') FROM time_tbl order by date_sub(c3 + '1 12:59:10', '1 12:59:10');

-- select date_sub with order by (result)
--Testcase 2356:
SELECT id, date_sub(c3 + '1 12:59:10', '1 12:59:10') FROM time_tbl order by date_sub(c3 + '1 12:59:10', '1 12:59:10');

-- select date_sub with order by index (result)
--Testcase 2357:
SELECT id, date_sub(c3 + '1 12:59:10', '1 12:59:10') FROM time_tbl order by 2,1;

-- select date_sub with order by index (result)
--Testcase 2358:
SELECT id, date_sub(c3 + '1 12:59:10', '1 12:59:10') FROM time_tbl order by 1,2;

-- select date_sub with group by (explain)
--Testcase 2359:
EXPLAIN VERBOSE
SELECT max(c3), date_sub(c3 + '1 12:59:10', '1 12:59:10') FROM time_tbl group by date_sub(c3 + '1 12:59:10', '1 12:59:10');

-- select date_sub with group by (result)
--Testcase 2360:
SELECT max(c3), date_sub(c3 + '1 12:59:10', '1 12:59:10') FROM time_tbl group by date_sub(c3 + '1 12:59:10', '1 12:59:10');

-- select date_sub with group by index (result)
--Testcase 2361:
SELECT id, date_sub(c3 + '1 12:59:10', '1 12:59:10') FROM time_tbl group by 2,1;

-- select date_sub with group by index (result)
--Testcase 2362:
SELECT id, date_sub(c3 + '1 12:59:10', '1 12:59:10') FROM time_tbl group by 1,2;

-- select date_sub with group by having (explain)
--Testcase 2363:
EXPLAIN VERBOSE
SELECT max(c3), date_sub(c3 + '1 12:59:10', '1 12:59:10') FROM time_tbl group by date_sub(c3 + '1 12:59:10', '1 12:59:10'), c3 HAVING date_sub(c3 + '1 12:59:10', '1 12:59:10') > '2000-01-01';

-- select date_sub with group by having (result)
--Testcase 2364:
SELECT max(c3), date_sub(c3 + '1 12:59:10', '1 12:59:10') FROM time_tbl group by date_sub(c3 + '1 12:59:10', '1 12:59:10'), c3 HAVING date_sub(c3 + '1 12:59:10', '1 12:59:10') > '2000-01-01';

-- select date_sub with group by index having (result)
--Testcase 2365:
SELECT id, date_sub(c3 + '1 12:59:10', '1 12:59:10'), c3 FROM time_tbl group by 3, 2, 1 HAVING date_sub(c3 + '1 12:59:10', '1 12:59:10') > '2000-01-01';

-- select date_sub with group by index having (result)
--Testcase 2366:
SELECT id, date_sub(c3 + '1 12:59:10', '1 12:59:10'), c3 FROM time_tbl group by 1, 2, 3 HAVING date_sub(c3 + '1 12:59:10', '1 12:59:10') > '2000-01-01';

-- select date_sub and as
--Testcase 2367:
SELECT date_sub(date_sub(c3, '1 12:59:10'), '1-1') as date_sub1 FROM time_tbl;

-- DATEDIFF()
-- select datediff (stub function, explain)
--Testcase 2368:
EXPLAIN VERBOSE
SELECT datediff(c3, c2), datediff(c2, '2004-10-19 10:23:54'::timestamp), datediff(c2, '2007-12-31'::date), datediff('2007-12-31 23:59:59'::timestamp, '2007-12-30') FROM time_tbl;

-- select datediff (stub function, result)
--Testcase 2369:
SELECT datediff(c3, c2), datediff(c2, '2004-10-19 10:23:54'::timestamp), datediff(c2, '2007-12-31'::date), datediff('2007-12-31 23:59:59'::timestamp, '2007-12-30') FROM time_tbl;

-- select datediff (stub function, not pushdown constraints, explain)
--Testcase 2370:
EXPLAIN VERBOSE
SELECT datediff(c3, c2), datediff(c2, '2004-10-19 10:23:54'::timestamp), datediff(c2, '2007-12-31'::date), datediff('2007-12-31 23:59:59'::timestamp, '2007-12-30') FROM time_tbl WHERE to_hex(id) = '1';

-- select datediff (stub function, not pushdown constraints, result)
--Testcase 2371:
SELECT datediff(c3, c2), datediff(c2, '2004-10-19 10:23:54'::timestamp), datediff(c2, '2007-12-31'::date), datediff('2007-12-31 23:59:59'::timestamp, '2007-12-30') FROM time_tbl WHERE to_hex(id) = '1';

-- select datediff (stub function, pushdown constraints, explain)
--Testcase 2372:
EXPLAIN VERBOSE
SELECT datediff(c3, c2), datediff(c2, '2004-10-19 10:23:54'::timestamp), datediff(c2, '2007-12-31'::date), datediff('2007-12-31 23:59:59'::timestamp, '2007-12-30') FROM time_tbl WHERE id != 0;

-- select datediff (stub function, pushdown constraints, result)
--Testcase 2373:
SELECT datediff(c3, c2), datediff(c2, '2004-10-19 10:23:54'::timestamp), datediff(c2, '2007-12-31'::date), datediff('2007-12-31 23:59:59'::timestamp, '2007-12-30') FROM time_tbl WHERE id != 0;

-- select datediff (stub function, datediff in constraints, explain)
--Testcase 2374:
EXPLAIN VERBOSE
SELECT datediff(c3, c2), datediff(c2, '2004-10-19 10:23:54'::timestamp), datediff(c2, '2007-12-31'::date), datediff('2007-12-31 23:59:59'::timestamp, '2007-12-30') FROM time_tbl WHERE datediff(c3, c2) != 0;

-- select datediff (stub function, datediff in constraints, result)
--Testcase 2375:
SELECT datediff(c3, c2), datediff(c2, '2004-10-19 10:23:54'::timestamp), datediff(c2, '2007-12-31'::date), datediff('2007-12-31 23:59:59'::timestamp, '2007-12-30') FROM time_tbl WHERE datediff(c3, c2) != 0;

-- select datediff (stub function, datediff in constraints, explain)
--Testcase 2376:
EXPLAIN VERBOSE
SELECT datediff(c3, c2), datediff(c2, '2004-10-19 10:23:54'::timestamp), datediff(c2, '2007-12-31'::date), datediff('2007-12-31 23:59:59'::timestamp, '2007-12-30') FROM time_tbl WHERE datediff('2007-12-31 23:59:59'::timestamp, '2007-12-30') > 0;

-- select datediff (stub function, datediff in constraints, result)
--Testcase 2377:
SELECT datediff(c3, c2), datediff(c2, '2004-10-19 10:23:54'::timestamp), datediff(c2, '2007-12-31'::date), datediff('2007-12-31 23:59:59'::timestamp, '2007-12-30') FROM time_tbl WHERE datediff('2007-12-31 23:59:59'::timestamp, '2007-12-30') > 0;

-- select datediff as nest function with agg (pushdown, explain)
--Testcase 2378:
EXPLAIN VERBOSE
SELECT max(c2), datediff('2021-01-02'::date, max(c2)) FROM time_tbl;

-- select datediff as nest function with agg (pushdown, result)
--Testcase 2379:
SELECT max(c2), datediff('2021-01-02'::date, max(c2)) FROM time_tbl;

-- select datediff as nest with stub (pushdown, explain)
--Testcase 2380:
EXPLAIN VERBOSE
SELECT datediff(makedate(2019, id), c2) FROM time_tbl;

-- select datediff as nest with stub (pushdown, result)
--Testcase 2381:
SELECT datediff(makedate(2019, id), c2) FROM time_tbl;

-- select datediff with non pushdown func and explicit constant (explain)
--Testcase 2382:
EXPLAIN VERBOSE
SELECT datediff(c2, '2007-12-31'::date), pi(), 4.1 FROM time_tbl;

-- select datediff with non pushdown func and explicit constant (result)
--Testcase 2383:
SELECT datediff(c2, '2007-12-31'::date), pi(), 4.1 FROM time_tbl;

-- select datediff with order by (explain)
--Testcase 2384:
EXPLAIN VERBOSE
SELECT id, datediff(c3 + '1 12:59:10', c2 ) FROM time_tbl order by datediff(c3 + '1 12:59:10', c2 );

-- select datediff with order by (result)
--Testcase 2385:
SELECT id, datediff(c3 + '1 12:59:10', c2 ) FROM time_tbl order by datediff(c3 + '1 12:59:10', c2 );

-- select datediff with order by index (result)
--Testcase 2386:
SELECT id, datediff(c3 + '1 12:59:10', c2 ) FROM time_tbl order by 2,1;

-- select datediff with order by index (result)
--Testcase 2387:
SELECT id, datediff(c3 + '1 12:59:10', c2 ) FROM time_tbl order by 1,2;

-- select datediff with group by (explain)
--Testcase 2388:
EXPLAIN VERBOSE
SELECT count(id), datediff(c3 + '1 12:59:10', c2 ) FROM time_tbl group by datediff(c3 + '1 12:59:10', c2 );

-- select datediff with group by (result)
--Testcase 2389:
SELECT count(id), datediff(c3 + '1 12:59:10', c2 ) FROM time_tbl group by datediff(c3 + '1 12:59:10', c2 );

-- select datediff with group by index (result)
--Testcase 2390:
SELECT id, datediff(c3 + '1 12:59:10', c2 ) FROM time_tbl group by 2,1;

-- select datediff with group by index (result)
--Testcase 2391:
SELECT id, datediff(c3 + '1 12:59:10', c2 ) FROM time_tbl group by 1,2;

-- select datediff with group by having (explain)
--Testcase 2392:
EXPLAIN VERBOSE
SELECT count(id), datediff(c3 + '1 12:59:10', c2 ), c2, c3 FROM time_tbl group by datediff(c3 + '1 12:59:10', c2 ), id,c2,c3 HAVING datediff(c3 + '1 12:59:10', c2 ) > 0;

-- select datediff with group by having (result)
--Testcase 2393:
SELECT count(id), datediff(c3 + '1 12:59:10', c2 ), c2, c3 FROM time_tbl group by datediff(c3 + '1 12:59:10', c2 ), id,c2,c3 HAVING datediff(c3 + '1 12:59:10', c2 ) > 0;

-- select datediff with group by index having (result)
--Testcase 2394:
SELECT id, datediff(c3 + '1 12:59:10', c2 ), c2, c3 FROM time_tbl group by 4,3,2,1 HAVING datediff(c3 + '1 12:59:10', c2 ) > 0;

-- select datediff with group by index having (result)
--Testcase 2395:
SELECT id, datediff(c3 + '1 12:59:10', c2 ), c2, c3 FROM time_tbl group by 1,2,3,4 HAVING datediff(c3 + '1 12:59:10', c2 ) > 0;

-- select datediff and as
--Testcase 2396:
SELECT datediff(c2, '2007-12-31'::date) as datediff1 FROM time_tbl;

-- YEARWEEK()
-- select yearweek (stub function, explain)
--Testcase 2397:
EXPLAIN VERBOSE
SELECT yearweek(c3), yearweek(c2), yearweek(date_sub(c3, '1 12:59:10')), yearweek('2021-01-01 12:00:00'::timestamp) FROM time_tbl;

-- select yearweek (stub function, result)
--Testcase 2398:
SELECT yearweek(c3), yearweek(c2), yearweek(date_sub(c3, '1 12:59:10')), yearweek('2021-01-01 12:00:00'::timestamp) FROM time_tbl;

-- select yearweek (stub function, not pushdown constraints, explain)
--Testcase 2399:
EXPLAIN VERBOSE
SELECT yearweek(c3), yearweek(c2), yearweek(date_sub(c3, '1 12:59:10')), yearweek('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select yearweek (stub function, not pushdown constraints, result)
--Testcase 2400:
SELECT yearweek(c3), yearweek(c2), yearweek(date_sub(c3, '1 12:59:10')), yearweek('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select yearweek (stub function, pushdown constraints, explain)
--Testcase 2401:
EXPLAIN VERBOSE
SELECT yearweek(c3), yearweek(c2), yearweek(date_sub(c3, '1 12:59:10')), yearweek('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200;

-- select yearweek (stub function, pushdown constraints, result)
--Testcase 2402:
SELECT yearweek(c3), yearweek(c2), yearweek(date_sub(c3, '1 12:59:10')), yearweek('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200;

-- select yearweek (stub function, yearweek in constraints, explain)
--Testcase 2403:
EXPLAIN VERBOSE
SELECT yearweek(c3), yearweek(c2), yearweek(date_sub(c3, '1 12:59:10')), yearweek('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE yearweek(c3) != yearweek('2000-01-01'::timestamp);

-- select yearweek (stub function, yearweek in constraints, result)
--Testcase 2404:
SELECT yearweek(c3), yearweek(c2), yearweek(date_sub(c3, '1 12:59:10')), yearweek('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE yearweek(c3) != yearweek('2000-01-01'::timestamp);

-- select yearweek (stub function, yearweek in constraints, explain)
--Testcase 2405:
EXPLAIN VERBOSE
SELECT yearweek(c3), yearweek(c2), yearweek(date_sub(c3, '1 12:59:10')), yearweek('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE yearweek('2021-01-01 12:00:00'::timestamp) > '1';

-- select yearweek (stub function, yearweek in constraints, result)
--Testcase 2406:
SELECT yearweek(c3), yearweek(c2), yearweek(date_sub(c3, '1 12:59:10')), yearweek('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE yearweek('2021-01-01 12:00:00'::timestamp) > '1';

-- select yearweek with agg (pushdown, explain)
--Testcase 2407:
EXPLAIN VERBOSE
SELECT max(c3), yearweek(max(c3)) FROM time_tbl;

-- select yearweek as nest function with agg (pushdown, result)
--Testcase 2408:
SELECT max(c3), yearweek(max(c3)) FROM time_tbl;

-- select yearweek with non pushdown func and explicit constant (explain)
--Testcase 2409:
EXPLAIN VERBOSE
SELECT yearweek(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl;

-- select yearweek with non pushdown func and explicit constant (result)
--Testcase 2410:
SELECT yearweek(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl;

-- select yearweek with order by (explain)
--Testcase 2411:
EXPLAIN VERBOSE
SELECT id, yearweek(c3 + '1 12:59:10') FROM time_tbl order by yearweek(c3 + '1 12:59:10');

-- select yearweek with order by (result)
--Testcase 2412:
SELECT id, yearweek(c3 + '1 12:59:10') FROM time_tbl order by yearweek(c3 + '1 12:59:10');

-- select yearweek with order by index (result)
--Testcase 2413:
SELECT id, yearweek(c3 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select yearweek with order by index (result)
--Testcase 2414:
SELECT id, yearweek(c3 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select yearweek with group by (explain)
--Testcase 2415:
EXPLAIN VERBOSE
SELECT max(c3), yearweek(c3 + '1 12:59:10') FROM time_tbl group by yearweek(c3 + '1 12:59:10');

-- select yearweek with group by (result)
--Testcase 2416:
SELECT max(c3), yearweek(c3 + '1 12:59:10') FROM time_tbl group by yearweek(c3 + '1 12:59:10');

-- select yearweek with group by index (result)
--Testcase 2417:
SELECT id, yearweek(c3 + '1 12:59:10') FROM time_tbl group by 2,1;

-- select yearweek with group by index (result)
--Testcase 2418:
SELECT id, yearweek(c3 + '1 12:59:10') FROM time_tbl group by 1,2;

-- select yearweek with group by having (explain)
--Testcase 2419:
EXPLAIN VERBOSE
SELECT max(c3), yearweek(c3 + '1 12:59:10') FROM time_tbl group by yearweek(c3 + '1 12:59:10'), c3 HAVING yearweek(c3 + '1 12:59:10') > 201010;

-- select yearweek with group by having (result)
--Testcase 2420:
SELECT max(c3), yearweek(c3 + '1 12:59:10') FROM time_tbl group by yearweek(c3 + '1 12:59:10'), c3 HAVING yearweek(c3 + '1 12:59:10') > 201010;

-- select yearweek with group by index having (result)
--Testcase 2421:
SELECT id, yearweek(c3 + '1 12:59:10'), c3 FROM time_tbl group by 3, 2, 1 HAVING yearweek(c3 + '1 12:59:10') > 201010;

-- select yearweek with group by index having (result)
--Testcase 2422:
SELECT id, yearweek(c3 + '1 12:59:10'), c3 FROM time_tbl group by 1, 2, 3 HAVING yearweek(c3 + '1 12:59:10') > 201010;

-- select yearweek and as
--Testcase 2423:
SELECT yearweek(date_sub(c3, '1 12:59:10')) as yearweek1 FROM time_tbl;



-- YEAR()
-- select year (stub function, explain)
--Testcase 2424:
EXPLAIN VERBOSE
SELECT year(c3), year(c2), year(date_sub(c3, '1 12:59:10')), year('2021-01-01 12:00:00'::timestamp) FROM time_tbl;

-- select year (stub function, result)
--Testcase 2425:
SELECT year(c3), year(c2), year(date_sub(c3, '1 12:59:10')), year('2021-01-01 12:00:00'::timestamp) FROM time_tbl;

-- select year (stub function, not pushdown constraints, explain)
--Testcase 2426:
EXPLAIN VERBOSE
SELECT year(c3), year(c2), year(date_sub(c3, '1 12:59:10')), year('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select year (stub function, not pushdown constraints, result)
--Testcase 2427:
SELECT year(c3), year(c2), year(date_sub(c3, '1 12:59:10')), year('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select year (stub function, pushdown constraints, explain)
--Testcase 2428:
EXPLAIN VERBOSE
SELECT year(c3), year(c2), year(date_sub(c3, '1 12:59:10')), year('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200;

-- select year (stub function, pushdown constraints, result)
--Testcase 2429:
SELECT year(c3), year(c2), year(date_sub(c3, '1 12:59:10')), year('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200;

-- select year (stub function, year in constraints, explain)
--Testcase 2430:
EXPLAIN VERBOSE
SELECT year(c3), year(c2), year(date_sub(c3, '1 12:59:10')), year('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE year(c3) != year('2000-01-01'::timestamp);

-- select year (stub function, year in constraints, result)
--Testcase 2431:
SELECT year(c3), year(c2), year(date_sub(c3, '1 12:59:10')), year('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE year(c3) != year('2000-01-01'::timestamp);

-- select year (stub function, year in constraints, explain)
--Testcase 2432:
EXPLAIN VERBOSE
SELECT year(c3), year(c2), year(date_sub(c3, '1 12:59:10')), year('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE year('2021-01-01 12:00:00'::timestamp) > '1';

-- select year (stub function, year in constraints, result)
--Testcase 2433:
SELECT year(c3), year(c2), year(date_sub(c3, '1 12:59:10')), year('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE year('2021-01-01 12:00:00'::timestamp) > '1';

-- select year with agg (pushdown, explain)
--Testcase 2434:
EXPLAIN VERBOSE
SELECT max(c3), year(max(c3)) FROM time_tbl;

-- select year as nest function with agg (pushdown, result)
--Testcase 2435:
SELECT max(c3), year(max(c3)) FROM time_tbl;

-- select year with non pushdown func and explicit constant (explain)
--Testcase 2436:
EXPLAIN VERBOSE
SELECT year(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl;

-- select year with non pushdown func and explicit constant (result)
--Testcase 2437:
SELECT year(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl;

-- select year with order by (explain)
--Testcase 2438:
EXPLAIN VERBOSE
SELECT id, year(c3 + '1 12:59:10') FROM time_tbl order by year(c3 + '1 12:59:10');

-- select year with order by (result)
--Testcase 2439:
SELECT id, year(c3 + '1 12:59:10') FROM time_tbl order by year(c3 + '1 12:59:10');

-- select year with order by index (result)
--Testcase 2440:
SELECT id, year(c3 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select year with order by index (result)
--Testcase 2441:
SELECT id, year(c3 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select year with group by (explain)
--Testcase 2442:
EXPLAIN VERBOSE
SELECT max(c3), year(c3 + '1 12:59:10') FROM time_tbl group by year(c3 + '1 12:59:10');

-- select year with group by (result)
--Testcase 2443:
SELECT max(c3), year(c3 + '1 12:59:10') FROM time_tbl group by year(c3 + '1 12:59:10');

-- select year with group by index (result)
--Testcase 2444:
SELECT id, year(c3 + '1 12:59:10') FROM time_tbl group by 2,1;

-- select year with group by index (result)
--Testcase 2445:
SELECT id, year(c3 + '1 12:59:10') FROM time_tbl group by 1,2;

-- select year with group by having (explain)
--Testcase 2446:
EXPLAIN VERBOSE
SELECT max(c3), year(c3 + '1 12:59:10') FROM time_tbl group by year(c3 + '1 12:59:10'), c3 HAVING year(c3 + '1 12:59:10') > 2000;

-- select year with group by having (result)
--Testcase 2447:
SELECT max(c3), year(c3 + '1 12:59:10') FROM time_tbl group by year(c3 + '1 12:59:10'), c3 HAVING year(c3 + '1 12:59:10') > 2000;

-- select year with group by index having (result)
--Testcase 2448:
SELECT id, year(c3 + '1 12:59:10'), c3 FROM time_tbl group by 3, 2, 1 HAVING year(c3 + '1 12:59:10') > 2000;

-- select year with group by index having (result)
--Testcase 2449:
SELECT id, year(c3 + '1 12:59:10'), c3 FROM time_tbl group by 1, 2, 3 HAVING year(c3 + '1 12:59:10') > 2000;

-- select year and as
--Testcase 2450:
SELECT year(date_sub(c3, '1 12:59:10')) as year1 FROM time_tbl;



-- WEEKFORYEAR()
-- select weekofyear (stub function, explain)
--Testcase 2451:
EXPLAIN VERBOSE
SELECT weekofyear(c3), weekofyear(c2), weekofyear(date_sub(c3, '1 12:59:10')), weekofyear('2021-01-01 12:00:00'::timestamp) FROM time_tbl;

-- select weekofyear (stub function, result)
--Testcase 2452:
SELECT weekofyear(c3), weekofyear(c2), weekofyear(date_sub(c3, '1 12:59:10')), weekofyear('2021-01-01 12:00:00'::timestamp) FROM time_tbl;

-- select weekofyear (stub function, not pushdown constraints, explain)
--Testcase 2453:
EXPLAIN VERBOSE
SELECT weekofyear(c3), weekofyear(c2), weekofyear(date_sub(c3, '1 12:59:10')), weekofyear('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select weekofyear (stub function, not pushdown constraints, result)
--Testcase 2454:
SELECT weekofyear(c3), weekofyear(c2), weekofyear(date_sub(c3, '1 12:59:10')), weekofyear('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select weekofyear (stub function, pushdown constraints, explain)
--Testcase 2455:
EXPLAIN VERBOSE
SELECT weekofyear(c3), weekofyear(c2), weekofyear(date_sub(c3, '1 12:59:10')), weekofyear('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200;

-- select weekofyear (stub function, pushdown constraints, result)
--Testcase 2456:
SELECT weekofyear(c3), weekofyear(c2), weekofyear(date_sub(c3, '1 12:59:10')), weekofyear('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200;

-- select weekofyear (stub function, weekofyear in constraints, explain)
--Testcase 2457:
EXPLAIN VERBOSE
SELECT weekofyear(c3), weekofyear(c2), weekofyear(date_sub(c3, '1 12:59:10')), weekofyear('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE weekofyear(c3) != weekofyear('2000-01-01'::timestamp);

-- select weekofyear (stub function, weekofyear in constraints, result)
--Testcase 2458:
SELECT weekofyear(c3), weekofyear(c2), weekofyear(date_sub(c3, '1 12:59:10')), weekofyear('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE weekofyear(c3) != weekofyear('2000-01-01'::timestamp);

-- select weekofyear (stub function, weekofyear in constraints, explain)
--Testcase 2459:
EXPLAIN VERBOSE
SELECT weekofyear(c3), weekofyear(c2), weekofyear(date_sub(c3, '1 12:59:10')), weekofyear('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE weekofyear('2021-01-01 12:00:00'::timestamp) > '1';

-- select weekofyear (stub function, weekofyear in constraints, result)
--Testcase 2460:
SELECT weekofyear(c3), weekofyear(c2), weekofyear(date_sub(c3, '1 12:59:10')), weekofyear('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE weekofyear('2021-01-01 12:00:00'::timestamp) > '1';

-- select weekofyear with agg (pushdown, explain)
--Testcase 2461:
EXPLAIN VERBOSE
SELECT max(c3), weekofyear(max(c3)) FROM time_tbl;

-- select weekofyear as nest function with agg (pushdown, result)
--Testcase 2462:
SELECT max(c3), weekofyear(max(c3)) FROM time_tbl;

-- select weekofyear with non pushdown func and explicit constant (explain)
--Testcase 2463:
EXPLAIN VERBOSE
SELECT weekofyear(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl;

-- select weekofyear with non pushdown func and explicit constant (result)
--Testcase 2464:
SELECT weekofyear(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl;

-- select weekofyear with order by (explain)
--Testcase 2465:
EXPLAIN VERBOSE
SELECT id, weekofyear(c3 + '1 12:59:10') FROM time_tbl order by weekofyear(c3 + '1 12:59:10');

-- select weekofyear with order by (result)
--Testcase 2466:
SELECT id, weekofyear(c3 + '1 12:59:10') FROM time_tbl order by weekofyear(c3 + '1 12:59:10');

-- select weekofyear with order by index (result)
--Testcase 2467:
SELECT id, weekofyear(c3 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select weekofyear with order by index (result)
--Testcase 2468:
SELECT id, weekofyear(c3 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select weekofyear with group by (explain)
--Testcase 2469:
EXPLAIN VERBOSE
SELECT max(c3), weekofyear(c3 + '1 12:59:10') FROM time_tbl group by weekofyear(c3 + '1 12:59:10');

-- select weekofyear with group by (result)
--Testcase 2470:
SELECT max(c3), weekofyear(c3 + '1 12:59:10') FROM time_tbl group by weekofyear(c3 + '1 12:59:10');

-- select weekofyear with group by index (result)
--Testcase 2471:
SELECT id, weekofyear(c3 + '1 12:59:10') FROM time_tbl group by 2,1;

-- select weekofyear with group by index (result)
--Testcase 2472:
SELECT id, weekofyear(c3 + '1 12:59:10') FROM time_tbl group by 1,2;

-- select weekofyear with group by having (explain)
--Testcase 2473:
EXPLAIN VERBOSE
SELECT max(c3), weekofyear(c3 + '1 12:59:10') FROM time_tbl group by weekofyear(c3 + '1 12:59:10'), c3 HAVING weekofyear(c3 + '1 12:59:10') > 0;

-- select weekofyear with group by having (result)
--Testcase 2474:
SELECT max(c3), weekofyear(c3 + '1 12:59:10') FROM time_tbl group by weekofyear(c3 + '1 12:59:10'), c3 HAVING weekofyear(c3 + '1 12:59:10') > 0;

-- select weekofyear with group by index having (result)
--Testcase 2475:
SELECT id, weekofyear(c3 + '1 12:59:10'), c3 FROM time_tbl group by 3, 2, 1 HAVING weekofyear(c3 + '1 12:59:10') > 0;

-- select weekofyear with group by index having (result)
--Testcase 2476:
SELECT id, weekofyear(c3 + '1 12:59:10'), c3 FROM time_tbl group by 1, 2, 3 HAVING weekofyear(c3 + '1 12:59:10') > 0;

-- select weekofyear and as
--Testcase 2477:
SELECT weekofyear(date_sub(c3, '1 12:59:10')) as weekofyear1 FROM time_tbl;


-- WEEKDAY()
-- select weekday (stub function, explain)
--Testcase 2478:
EXPLAIN VERBOSE
SELECT weekday(c3), weekday(c2), weekday(date_sub(c3, '1 12:59:10')), weekday('2021-01-01 12:00:00'::timestamp) FROM time_tbl;

-- select weekday (stub function, result)
--Testcase 2479:
SELECT weekday(c3), weekday(c2), weekday(date_sub(c3, '1 12:59:10')), weekday('2021-01-01 12:00:00'::timestamp) FROM time_tbl;

-- select weekday (stub function, not pushdown constraints, explain)
--Testcase 2480:
EXPLAIN VERBOSE
SELECT weekday(c3), weekday(c2), weekday(date_sub(c3, '1 12:59:10')), weekday('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select weekday (stub function, not pushdown constraints, result)
--Testcase 2481:
SELECT weekday(c3), weekday(c2), weekday(date_sub(c3, '1 12:59:10')), weekday('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select weekday (stub function, pushdown constraints, explain)
--Testcase 2482:
EXPLAIN VERBOSE
SELECT weekday(c3), weekday(c2), weekday(date_sub(c3, '1 12:59:10')), weekday('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200;

-- select weekday (stub function, pushdown constraints, result)
--Testcase 2483:
SELECT weekday(c3), weekday(c2), weekday(date_sub(c3, '1 12:59:10')), weekday('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200;

-- select weekday (stub function, weekday in constraints, explain)
--Testcase 2484:
EXPLAIN VERBOSE
SELECT weekday(c3), weekday(c2), weekday(date_sub(c3, '1 12:59:10')), weekday('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE weekday(c3) != weekday('2000-01-01'::timestamp);

-- select weekday (stub function, weekday in constraints, result)
--Testcase 2485:
SELECT weekday(c3), weekday(c2), weekday(date_sub(c3, '1 12:59:10')), weekday('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE weekday(c3) != weekday('2000-01-01'::timestamp);

-- select weekday (stub function, weekday in constraints, explain)
--Testcase 2486:
EXPLAIN VERBOSE
SELECT weekday(c3), weekday(c2), weekday(date_sub(c3, '1 12:59:10')), weekday('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE weekday('2021-01-01 12:00:00'::timestamp) > '1';

-- select weekday (stub function, weekday in constraints, result)
--Testcase 2487:
SELECT weekday(c3), weekday(c2), weekday(date_sub(c3, '1 12:59:10')), weekday('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE weekday('2021-01-01 12:00:00'::timestamp) > '1';

-- select weekday with agg (pushdown, explain)
--Testcase 2488:
EXPLAIN VERBOSE
SELECT max(c3), weekday(max(c3)) FROM time_tbl;

-- select weekday as nest function with agg (pushdown, result)
--Testcase 2489:
SELECT max(c3), weekday(max(c3)) FROM time_tbl;

-- select weekday with non pushdown func and explicit constant (explain)
--Testcase 2490:
EXPLAIN VERBOSE
SELECT weekday(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl;

-- select weekday with non pushdown func and explicit constant (result)
--Testcase 2491:
SELECT weekday(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl;

-- select weekday with order by (explain)
--Testcase 2492:
EXPLAIN VERBOSE
SELECT id, weekday(c3 + '1 12:59:10') FROM time_tbl order by weekday(c3 + '1 12:59:10');

-- select weekday with order by (result)
--Testcase 2493:
SELECT id, weekday(c3 + '1 12:59:10') FROM time_tbl order by weekday(c3 + '1 12:59:10');

-- select weekday with order by index (result)
--Testcase 2494:
SELECT id, weekday(c3 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select weekday with order by index (result)
--Testcase 2495:
SELECT id, weekday(c3 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select weekday with group by (explain)
--Testcase 2496:
EXPLAIN VERBOSE
SELECT max(c3), weekday(c3 + '1 12:59:10') FROM time_tbl group by weekday(c3 + '1 12:59:10');

-- select weekday with group by (result)
--Testcase 2497:
SELECT max(c3), weekday(c3 + '1 12:59:10') FROM time_tbl group by weekday(c3 + '1 12:59:10');

-- select weekday with group by index (result)
--Testcase 2498:
SELECT id, weekday(c3 + '1 12:59:10') FROM time_tbl group by 2,1;

-- select weekday with group by index (result)
--Testcase 2499:
SELECT id, weekday(c3 + '1 12:59:10') FROM time_tbl group by 1,2;

-- select weekday with group by having (explain)
--Testcase 2500:
EXPLAIN VERBOSE
SELECT max(c3), weekday(c3 + '1 12:59:10') FROM time_tbl group by weekday(c3 + '1 12:59:10'), c3 HAVING weekday(c3 + '1 12:59:10') > 0;

-- select weekday with group by having (result)
--Testcase 2501:
SELECT max(c3), weekday(c3 + '1 12:59:10') FROM time_tbl group by weekday(c3 + '1 12:59:10'), c3 HAVING weekday(c3 + '1 12:59:10') > 0;

-- select weekday with group by index having (result)
--Testcase 2502:
SELECT id, weekday(c3 + '1 12:59:10'), c3 FROM time_tbl group by 3, 2, 1 HAVING weekday(c3 + '1 12:59:10') > 0;

-- select weekday with group by index having (result)
--Testcase 2503:
SELECT id, weekday(c3 + '1 12:59:10'), c3 FROM time_tbl group by 1, 2, 3 HAVING weekday(c3 + '1 12:59:10') > 0;

-- select weekday and as
--Testcase 2504:
SELECT weekday(date_sub(c3, '1 12:59:10')) as weekday1 FROM time_tbl;



-- WEEK()
-- select week (stub function, explain)
--Testcase 2505:
EXPLAIN VERBOSE
SELECT id, week(c2, 7), week(c2, 1), week('2021-01-02'::date, 1), week('2021-01-02'::date, 7) FROM time_tbl;

-- select week (stub function, result)
--Testcase 2506:
SELECT id, week(c2, 7), week(c2, 1), week('2021-01-02'::date, 1), week('2021-01-02'::date, 7) FROM time_tbl;

-- select week (stub function, not pushdown constraints, explain)
--Testcase 2507:
EXPLAIN VERBOSE
SELECT week(c2, 7), week(c2, 1), week('2021-01-02'::date, 1), week('2021-01-02'::date, 7) FROM time_tbl WHERE to_hex(id) = '1';

-- select week (stub function, not pushdown constraints, result)
--Testcase 2508:
SELECT week(c2, 7), week(c2, 1), week('2021-01-02'::date, 1), week('2021-01-02'::date, 7) FROM time_tbl WHERE to_hex(id) = '1';

-- select week (stub function, pushdown constraints, explain)
--Testcase 2509:
EXPLAIN VERBOSE
SELECT id, week(c2, 7), week(c2, 1), week('2021-01-02'::date, 1), week('2021-01-02'::date, 7) FROM time_tbl WHERE id != 0;

-- select week (stub function, pushdown constraints, result)
--Testcase 2510:
SELECT id, week(c2, 7), week(c2, 1), week('2021-01-02'::date, 1), week('2021-01-02'::date, 7) FROM time_tbl WHERE id != 0;

-- select week (stub function, week in constraints, explain)
--Testcase 2511:
EXPLAIN VERBOSE
SELECT id, week(c2, 7), week(c2, 1), week('2021-01-02'::date, 1), week('2021-01-02'::date, 7) FROM time_tbl WHERE week(c2, 7) != week('2021-01-02'::timestamp, 1);

-- select week (stub function, week in constraints, result)
--Testcase 2512:
SELECT id, week(c2, 7), week(c2, 1), week('2021-01-02'::date, 1), week('2021-01-02'::date, 7) FROM time_tbl WHERE week(c2, 7) != week('2021-01-02'::timestamp, 1);

-- select week (stub function, week in constraints, explain)
--Testcase 2513:
EXPLAIN VERBOSE
SELECT id, week(c2, 7), week(c2, 1), week('2021-01-02'::date, 1), week('2021-01-02'::date, 7) FROM time_tbl WHERE week('2021-01-02'::date, 7) > week('2021-01-02'::timestamp, 1);

-- select week (stub function, week in constraints, result)
--Testcase 2514:
SELECT id, week(c2, 7), week(c2, 1), week('2021-01-02'::date, 1), week('2021-01-02'::date, 7) FROM time_tbl WHERE week('2021-01-02'::date, 7) > week('2021-01-02'::timestamp, 1);

-- select week as nest function with agg (pushdown, explain)
--Testcase 2515:
EXPLAIN VERBOSE
SELECT max(id), week('2021-01-02'::date, max(id)) FROM time_tbl;

-- select week as nest function with agg (pushdown, result)
--Testcase 2516:
SELECT max(id), week('2021-01-02'::date, max(id)) FROM time_tbl;

-- select week as nest with stub (pushdown, explain)
--Testcase 2517:
EXPLAIN VERBOSE
SELECT id, week(makedate(2019, id), 7) FROM time_tbl;

-- select week as nest with stub (pushdown, result)
--Testcase 2518:
SELECT id, week(makedate(2019, id), 7) FROM time_tbl;

-- select week with non pushdown func and explicit constant (explain)
--Testcase 2519:
EXPLAIN VERBOSE
SELECT week('2021-01-02'::date, 1), pi(), 4.1 FROM time_tbl;

-- select week with non pushdown func and explicit constant (result)
--Testcase 2520:
SELECT week('2021-01-02'::date, 1), pi(), 4.1 FROM time_tbl;

-- select week with order by (explain)
--Testcase 2521:
EXPLAIN VERBOSE
SELECT id, week(c2, id + 5) FROM time_tbl order by id,week(c2, id + 5);

-- select week with order by (result)
--Testcase 2522:
SELECT id, week(c2, id + 5) FROM time_tbl order by id,week(c2, id + 5);

-- select week with order by index (result)
--Testcase 2523:
SELECT id, week(c2, id + 5) FROM time_tbl order by 2,1;

-- select week with order by index (result)
--Testcase 2524:
SELECT id, week(c2, id + 5) FROM time_tbl order by 1,2;

-- select week with group by (explain)
--Testcase 2525:
EXPLAIN VERBOSE
SELECT id, week(c2, id + 5) FROM time_tbl group by id, week(c2, id + 5);

-- select week with group by (result)
--Testcase 2526:
SELECT id, week(c2, id + 5) FROM time_tbl group by id, week(c2, id + 5);

-- select week with group by index (result)
--Testcase 2527:
SELECT id, week(c2, id + 5) FROM time_tbl group by 2,1;

-- select week with group by index (result)
--Testcase 2528:
SELECT id, week(c2, id + 5) FROM time_tbl group by 1,2;

-- select week with group by having (explain)
--Testcase 2529:
EXPLAIN VERBOSE
SELECT count(id), week(c2, id + 5) FROM time_tbl group by week(c2, id + 5), id,c2 HAVING week(c2, id + 5) = 0;

-- select week with group by having (result)
--Testcase 2530:
SELECT count(id), week(c2, id + 5) FROM time_tbl group by week(c2, id + 5), id,c2 HAVING week(c2, id + 5) = 0;

-- select week with group by index having (result)
--Testcase 2531:
SELECT id, week(c2, id + 5), c2 FROM time_tbl group by 3,2,1 HAVING week(c2, id + 5) > 0;

-- select week with group by index having (result)
--Testcase 2532:
SELECT id, week(c2, id + 5), c2 FROM time_tbl group by 1,2,3 HAVING id > 1;

-- select week and as
--Testcase 2533:
SELECT week('2021-01-02'::date, 53) as week1 FROM time_tbl;


-- UTC_TIMESTAMP()
-- select utc_timestamp (stub function, explain)
--Testcase 2534:
EXPLAIN VERBOSE
SELECT utc_timestamp() FROM time_tbl;

-- select utc_timestamp (stub function, not pushdown constraints, explain)
--Testcase 2535:
EXPLAIN VERBOSE
SELECT utc_timestamp() FROM time_tbl WHERE to_hex(id) > '0';

-- select utc_timestamp (stub function, pushdown constraints, explain)
--Testcase 2536:
EXPLAIN VERBOSE
SELECT utc_timestamp() FROM time_tbl WHERE id = 1;

-- select utc_timestamp (stub function, utc_timestamp in constraints, explain)
--Testcase 2537:
EXPLAIN VERBOSE
SELECT utc_timestamp() FROM time_tbl WHERE utc_timestamp() > '1997-10-14 00:00:00'::timestamp;

-- utc_timestamp in constrains (stub function, explain)
--Testcase 2538:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE utc_timestamp() > '1997-10-14 00:00:00'::timestamp;

-- utc_timestamp in constrains (stub function, result)
--Testcase 2539:
SELECT c1 FROM time_tbl WHERE utc_timestamp() > '1997-10-14 00:00:00'::timestamp;

-- utc_timestamp as parameter of addtime(stub function, explain)
--Testcase 2540:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(utc_timestamp(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp;

-- utc_timestamp as parameter of addtime(stub function, result)
--Testcase 2541:
SELECT c1 FROM time_tbl WHERE addtime(utc_timestamp(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp;

-- select utc_timestamp and agg (pushdown, explain)
--Testcase 2542:
EXPLAIN VERBOSE
SELECT utc_timestamp(), sum(id) FROM time_tbl;

-- select utc_timestamp and log2 (pushdown, explain)
--Testcase 2543:
EXPLAIN VERBOSE
SELECT utc_timestamp(), log2(id) FROM time_tbl;

-- select utc_timestamp with non pushdown func and explicit constant (explain)
--Testcase 2544:
EXPLAIN VERBOSE
SELECT utc_timestamp(), to_hex(id), 4 FROM time_tbl;

-- select utc_timestamp with order by (explain)
--Testcase 2545:
EXPLAIN VERBOSE
SELECT utc_timestamp(), c1 FROM time_tbl ORDER BY c1;

-- select utc_timestamp with order by index (explain)
--Testcase 2546:
EXPLAIN VERBOSE
SELECT utc_timestamp(), c1 FROM time_tbl ORDER BY 2;

-- utc_timestamp constraints with order by (explain)
--Testcase 2547:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(utc_timestamp(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp ORDER BY c1;

-- utc_timestamp constraints with order by (result)
--Testcase 2548:
SELECT c1 FROM time_tbl WHERE addtime(utc_timestamp(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp ORDER BY c1;

-- select utc_timestamp with group by (explain)
--Testcase 2549:
EXPLAIN VERBOSE
SELECT utc_timestamp(), c1 FROM time_tbl GROUP BY c1;

-- select utc_timestamp with group by index (explain)
--Testcase 2550:
EXPLAIN VERBOSE
SELECT utc_timestamp(), c1 FROM time_tbl GROUP BY 2;

-- select utc_timestamp with group by having (explain)
--Testcase 2551:
EXPLAIN VERBOSE
SELECT utc_timestamp(), c1 FROM time_tbl GROUP BY utc_timestamp(),c1 HAVING utc_timestamp() > '1997-10-14 00:00:00'::timestamp;

-- select utc_timestamp with group by index having (explain)
--Testcase 2552:
EXPLAIN VERBOSE
SELECT utc_timestamp(), c1 FROM time_tbl GROUP BY 2,1 HAVING utc_timestamp() > '1997-10-14 00:00:00'::timestamp;

-- utc_timestamp constraints with group by (explain)
--Testcase 2553:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(utc_timestamp(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp GROUP BY c1;

-- utc_timestamp constraints with group by (result)
--Testcase 2554:
SELECT c1 FROM time_tbl WHERE addtime(utc_timestamp(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp GROUP BY c1;

-- select utc_timestamp and as
--Testcase 2555:
EXPLAIN VERBOSE
SELECT utc_timestamp() as utc_timestamp1 FROM time_tbl;



-- UTC_TIME()
-- select utc_time (stub function, explain)
--Testcase 2556:
EXPLAIN VERBOSE
SELECT utc_time() FROM time_tbl;

-- select utc_time (stub function, not pushdown constraints, explain)
--Testcase 2557:
EXPLAIN VERBOSE
SELECT utc_time() FROM time_tbl WHERE to_hex(id) > '0';

-- select utc_time (stub function, pushdown constraints, explain)
--Testcase 2558:
EXPLAIN VERBOSE
SELECT utc_time() FROM time_tbl WHERE id = 1;

-- select utc_time (stub function, utc_time in constraints, explain)
--Testcase 2559:
EXPLAIN VERBOSE
SELECT utc_time() FROM time_tbl WHERE utc_time() > '1997-10-14 00:00:00'::time;

-- utc_time in constrains (stub function, explain)
--Testcase 2560:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE utc_time() > '1997-10-14 00:00:00'::time;

-- utc_time in constrains (stub function, result)
--Testcase 2561:
SELECT c1 FROM time_tbl WHERE utc_time() > '1997-10-14 00:00:00'::time;

-- utc_time as parameter of second(stub function, explain)
--Testcase 2562:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE (60-second(utc_time())) >= 0;

-- utc_time as parameter of second(stub function, result)
--Testcase 2563:
SELECT c1 FROM time_tbl WHERE (60-second(utc_time())) >= 0;

-- select utc_time and agg (pushdown, explain)
--Testcase 2564:
EXPLAIN VERBOSE
SELECT utc_time(), sum(id) FROM time_tbl;

-- select utc_time and log2 (pushdown, explain)
--Testcase 2565:
EXPLAIN VERBOSE
SELECT utc_time(), log2(id) FROM time_tbl;

-- select utc_time with non pushdown func and explicit constant (explain)
--Testcase 2566:
EXPLAIN VERBOSE
SELECT utc_time(), to_hex(id), 4 FROM time_tbl;

-- select utc_time with order by (explain)
--Testcase 2567:
EXPLAIN VERBOSE
SELECT utc_time(), c1 FROM time_tbl ORDER BY c1;

-- select utc_time with order by index (explain)
--Testcase 2568:
EXPLAIN VERBOSE
SELECT utc_time(), c1 FROM time_tbl ORDER BY 2;

-- utc_time constraints with order by (explain)
--Testcase 2569:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE (60-second(utc_time())) >= 0 ORDER BY c1;

-- utc_time constraints with order by (result)
--Testcase 2570:
SELECT c1 FROM time_tbl WHERE (60-second(utc_time())) >= 0 ORDER BY c1;

-- select utc_time with group by (explain)
--Testcase 2571:
EXPLAIN VERBOSE
SELECT utc_time(), c1 FROM time_tbl GROUP BY c1;

-- select utc_time with group by index (explain)
--Testcase 2572:
EXPLAIN VERBOSE
SELECT utc_time(), c1 FROM time_tbl GROUP BY 2;

-- select utc_time with group by having (explain)
--Testcase 2573:
EXPLAIN VERBOSE
SELECT utc_time(), c1 FROM time_tbl GROUP BY utc_time(),c1 HAVING utc_time() > '1997-10-14 00:00:00'::time;

-- select utc_time with group by index having (explain)
--Testcase 2574:
EXPLAIN VERBOSE
SELECT utc_time(), c1 FROM time_tbl GROUP BY 2,1 HAVING utc_time() > '1997-10-14 00:00:00'::time;

-- utc_time constraints with group by (explain)
--Testcase 2575:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE (60-second(utc_time())) >= 0 GROUP BY c1;

-- utc_time constraints with group by (result)
--Testcase 2576:
SELECT c1 FROM time_tbl WHERE (60-second(utc_time())) >= 0 GROUP BY c1;

-- select utc_time and as
--Testcase 2577:
EXPLAIN VERBOSE
SELECT utc_time() as utc_time1 FROM time_tbl;



-- UTC_DATE()
-- select utc_date (stub function, explain)
--Testcase 2578:
EXPLAIN VERBOSE
SELECT utc_date() FROM time_tbl;

-- select utc_date (stub function, not pushdown constraints, explain)
--Testcase 2579:
EXPLAIN VERBOSE
SELECT utc_date() FROM time_tbl WHERE to_hex(id) > '0';

-- select utc_date (stub function, pushdown constraints, explain)
--Testcase 2580:
EXPLAIN VERBOSE
SELECT utc_date() FROM time_tbl WHERE id = 1;

-- select utc_date (stub function, utc_date in constraints, explain)
--Testcase 2581:
EXPLAIN VERBOSE
SELECT utc_date() FROM time_tbl WHERE utc_date() > '1997-10-14 00:00:00'::date;

-- utc_date in constrains (stub function, explain)
--Testcase 2582:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE utc_date() > '1997-10-14 00:00:00'::date;

-- utc_date in constrains (stub function, result)
--Testcase 2583:
SELECT c1 FROM time_tbl WHERE utc_date() > '1997-10-14 00:00:00'::date;

-- utc_date as parameter of addtime(stub function, explain)
--Testcase 2584:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(utc_date(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::date;

-- utc_date as parameter of addtime(stub function, result)
--Testcase 2585:
SELECT c1 FROM time_tbl WHERE addtime(utc_date(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::date;

-- select utc_date and agg (pushdown, explain)
--Testcase 2586:
EXPLAIN VERBOSE
SELECT utc_date(), sum(id) FROM time_tbl;

-- select utc_date and log2 (pushdown, explain)
--Testcase 2587:
EXPLAIN VERBOSE
SELECT utc_date(), log2(id) FROM time_tbl;

-- select utc_date with non pushdown func and explicit constant (explain)
--Testcase 2588:
EXPLAIN VERBOSE
SELECT utc_date(), to_hex(id), 4 FROM time_tbl;

-- select utc_date with order by (explain)
--Testcase 2589:
EXPLAIN VERBOSE
SELECT utc_date(), c1 FROM time_tbl ORDER BY c1;

-- select utc_date with order by index (explain)
--Testcase 2590:
EXPLAIN VERBOSE
SELECT utc_date(), c1 FROM time_tbl ORDER BY 2;

-- utc_date constraints with order by (explain)
--Testcase 2591:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(utc_date(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp ORDER BY c1;

-- utc_date constraints with order by (result)
--Testcase 2592:
SELECT c1 FROM time_tbl WHERE addtime(utc_date(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp ORDER BY c1;

-- select utc_date with group by (explain)
--Testcase 2593:
EXPLAIN VERBOSE
SELECT utc_date(), c1 FROM time_tbl GROUP BY c1;

-- select utc_date with group by index (explain)
--Testcase 2594:
EXPLAIN VERBOSE
SELECT utc_date(), c1 FROM time_tbl GROUP BY 2;

-- select utc_date with group by having (explain)
--Testcase 2595:
EXPLAIN VERBOSE
SELECT utc_date(), c1 FROM time_tbl GROUP BY utc_date(),c1 HAVING utc_date() > '1997-10-14 00:00:00'::timestamp;

-- select utc_date with group by index having (explain)
--Testcase 2596:
EXPLAIN VERBOSE
SELECT utc_date(), c1 FROM time_tbl GROUP BY 2,1 HAVING utc_date() > '1997-10-14 00:00:00'::timestamp;

-- utc_date constraints with group by (explain)
--Testcase 2597:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(utc_date(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp GROUP BY c1;

-- utc_date constraints with group by (result)
--Testcase 2598:
SELECT c1 FROM time_tbl WHERE addtime(utc_date(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp GROUP BY c1;

-- select utc_date and as
--Testcase 2599:
EXPLAIN VERBOSE
SELECT utc_date() as utc_date1 FROM time_tbl;



-- UNIX_TIMESTAMP()
-- select unix_timestamp (stub function, explain)
--Testcase 2600:
EXPLAIN VERBOSE
SELECT unix_timestamp(), unix_timestamp(c3), unix_timestamp(c2) FROM time_tbl;

-- select unix_timestamp (stub function, not pushdown constraints, explain)
--Testcase 2601:
EXPLAIN VERBOSE
SELECT unix_timestamp(), unix_timestamp(c3), unix_timestamp(c2) FROM time_tbl WHERE to_hex(id) > '0';

-- select unix_timestamp (stub function, pushdown constraints, explain)
--Testcase 2602:
EXPLAIN VERBOSE
SELECT unix_timestamp(), unix_timestamp(c3), unix_timestamp(c2) FROM time_tbl WHERE id = 1;

-- select unix_timestamp (stub function, unix_timestamp in constraints, explain)
--Testcase 2603:
EXPLAIN VERBOSE
SELECT unix_timestamp(), unix_timestamp(c3), unix_timestamp(c2) FROM time_tbl WHERE unix_timestamp() > unix_timestamp('1997-10-14 00:00:00'::timestamp);

-- unix_timestamp in constrains (stub function, explain)
--Testcase 2604:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE unix_timestamp() > unix_timestamp('1997-10-14 00:00:00'::timestamp);

-- unix_timestamp in constrains (stub function, result)
--Testcase 2605:
SELECT c1 FROM time_tbl WHERE unix_timestamp() > unix_timestamp('1997-10-14 00:00:00'::timestamp);

-- select unix_timestamp and agg (pushdown, explain)
--Testcase 2606:
EXPLAIN VERBOSE
SELECT unix_timestamp(), sum(id) FROM time_tbl;

-- select unix_timestamp and log2 (pushdown, explain)
--Testcase 2607:
EXPLAIN VERBOSE
SELECT unix_timestamp(), unix_timestamp(c3), unix_timestamp(c2), log2(id) FROM time_tbl;

-- select unix_timestamp with non pushdown func and explicit constant (explain)
--Testcase 2608:
EXPLAIN VERBOSE
SELECT unix_timestamp(), unix_timestamp(c3), unix_timestamp(c2), to_hex(id), 4 FROM time_tbl;

-- select unix_timestamp with order by (explain)
--Testcase 2609:
EXPLAIN VERBOSE
SELECT unix_timestamp(), unix_timestamp(c3), unix_timestamp(c2), c1 FROM time_tbl ORDER BY c1;

-- select unix_timestamp with order by index (explain)
--Testcase 2610:
EXPLAIN VERBOSE
SELECT unix_timestamp(), unix_timestamp(c3), unix_timestamp(c2), c1 FROM time_tbl ORDER BY 2;

-- select unix_timestamp with group by (explain)
--Testcase 2611:
EXPLAIN VERBOSE
SELECT unix_timestamp(), unix_timestamp(c3), unix_timestamp(c2), c1 FROM time_tbl GROUP BY c1,c2,c3;

-- select unix_timestamp with group by index (explain)
--Testcase 2612:
EXPLAIN VERBOSE
SELECT unix_timestamp(), unix_timestamp(c3), unix_timestamp(c2), c1 FROM time_tbl GROUP BY 1,2,3,4;

-- select unix_timestamp with group by having (explain)
--Testcase 2613:
EXPLAIN VERBOSE
SELECT unix_timestamp(), c1 FROM time_tbl GROUP BY unix_timestamp(),c1 HAVING unix_timestamp() > 100000;

-- select unix_timestamp with group by index having (explain)
--Testcase 2614:
EXPLAIN VERBOSE
SELECT unix_timestamp(), c1 FROM time_tbl GROUP BY 2,1 HAVING unix_timestamp() > 100000;

-- select unix_timestamp and as
--Testcase 2615:
EXPLAIN VERBOSE
SELECT unix_timestamp(), unix_timestamp(c3), unix_timestamp(c2) as unix_timestamp1 FROM time_tbl;


-- TO_SECONDS()
-- select to_seconds (stub function, explain)
--Testcase 2616:
EXPLAIN VERBOSE
SELECT to_seconds(id + 200719), to_seconds(c3), to_seconds(c2) FROM time_tbl;

-- select to_seconds (stub function, not pushdown constraints, explain)
--Testcase 2617:
EXPLAIN VERBOSE
SELECT to_seconds(id + 200719), to_seconds(c3), to_seconds(c2) FROM time_tbl WHERE to_hex(id) > '0';

-- select to_seconds (stub function, pushdown constraints, explain)
--Testcase 2618:
EXPLAIN VERBOSE
SELECT to_seconds(id + 200719), to_seconds(c3), to_seconds(c2) FROM time_tbl WHERE id = 1;

-- select to_seconds (stub function, to_seconds in constraints, explain)
--Testcase 2619:
EXPLAIN VERBOSE
SELECT to_seconds(id + 200719), to_seconds(c3), to_seconds(c2) FROM time_tbl WHERE to_seconds(id + 200719) > to_seconds('1997-10-14 00:00:00'::timestamp);

-- to_seconds in constrains (stub function, explain)
--Testcase 2620:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE to_seconds(id + 200719) > to_seconds('1997-10-14 00:00:00'::timestamp);

-- to_seconds in constrains (stub function, result)
--Testcase 2621:
SELECT c1 FROM time_tbl WHERE to_seconds(id + 200719) > to_seconds('1997-10-14 00:00:00'::timestamp);

-- select to_seconds and agg (pushdown, explain)
--Testcase 2622:
EXPLAIN VERBOSE
SELECT to_seconds('1997-10-14 00:00:00'::timestamp), to_seconds('1997-10-14 00:00:00'::date), sum(id) FROM time_tbl;

-- select to_seconds and log2 (pushdown, explain)
--Testcase 2623:
EXPLAIN VERBOSE
SELECT to_seconds('1997-10-14 00:00:00'::timestamp), to_seconds(c3), to_seconds(c2), log2(id) FROM time_tbl;

-- select to_seconds with non pushdown func and explicit constant (explain)
--Testcase 2624:
EXPLAIN VERBOSE
SELECT to_seconds('1997-10-14 00:00:00'::timestamp), to_seconds(c3), to_seconds(c2), to_hex(id), 4 FROM time_tbl;

-- select to_seconds with order by (explain)
--Testcase 2625:
EXPLAIN VERBOSE
SELECT to_seconds(id + 200719), to_seconds(c3), to_seconds(c2), c1 FROM time_tbl ORDER BY c1;

-- select to_seconds with order by index (explain)
--Testcase 2626:
EXPLAIN VERBOSE
SELECT to_seconds(id + 200719), to_seconds(c3), to_seconds(c2), c1 FROM time_tbl ORDER BY 2;

-- to_seconds constraints with order by (explain)
--Testcase 2627:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE to_seconds('2020-10-14 00:00:00'::timestamp) > to_seconds('1997-10-14 00:00:00'::timestamp) ORDER BY c1;

-- to_seconds constraints with order by (result)
--Testcase 2628:
SELECT c1 FROM time_tbl WHERE to_seconds('2020-10-14 00:00:00'::timestamp) > to_seconds('1997-10-14 00:00:00'::timestamp) ORDER BY c1;

-- select to_seconds with group by (explain)
--Testcase 2629:
EXPLAIN VERBOSE
SELECT to_seconds(971014), to_seconds(c3), to_seconds(c2), c1 FROM time_tbl GROUP BY c1,c2,c3;

-- select to_seconds with group by index (explain)
--Testcase 2630:
EXPLAIN VERBOSE
SELECT to_seconds(971014), to_seconds(c3), to_seconds(c2), c1 FROM time_tbl GROUP BY 1,2,3,4;

-- select to_seconds with group by having (explain)
--Testcase 2631:
EXPLAIN VERBOSE
SELECT to_seconds(971014), c1 FROM time_tbl GROUP BY to_seconds(971014),c1 HAVING to_seconds(971014) > 100000;

-- select to_seconds with group by index having (explain)
--Testcase 2632:
EXPLAIN VERBOSE
SELECT to_seconds(971014), c1 FROM time_tbl GROUP BY 2,1 HAVING to_seconds(971014) > 100000;

-- select to_seconds and as
--Testcase 2633:
EXPLAIN VERBOSE
SELECT to_seconds(971014), to_seconds(c3), to_seconds(c2) as to_seconds1 FROM time_tbl;


-- TO_DAYS()
-- select to_days (stub function, explain)
--Testcase 2634:
EXPLAIN VERBOSE
SELECT to_days(id + 200719), to_days(c2) FROM time_tbl;

-- select to_days (stub function, not pushdown constraints, explain)
--Testcase 2635:
EXPLAIN VERBOSE
SELECT to_days(id + 200719), to_days(c2) FROM time_tbl WHERE to_hex(id) > '0';

-- select to_days (stub function, pushdown constraints, explain)
--Testcase 2636:
EXPLAIN VERBOSE
SELECT to_days(id + 200719), to_days(c2) FROM time_tbl WHERE id = 1;

-- select to_days (stub function, to_days in constraints, explain)
--Testcase 2637:
EXPLAIN VERBOSE
SELECT to_days(id + 200719), to_days(c2) FROM time_tbl WHERE to_days(id + 200719) > to_days('1997-10-14 00:00:00'::date);

-- to_days in constrains (stub function, explain)
--Testcase 2638:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE to_days(id + 200719) > to_days('1997-10-14 00:00:00'::date);

-- to_days in constrains (stub function, result)
--Testcase 2639:
SELECT c1 FROM time_tbl WHERE to_days(id + 200719) > to_days('1997-10-14 00:00:00'::date);

-- select to_days and agg (pushdown, explain)
--Testcase 2640:
EXPLAIN VERBOSE
SELECT to_days('1997-10-14 00:00:00'::date), to_days('1997-10-14 00:00:00'::date), sum(id) FROM time_tbl;

-- select to_days and log2 (pushdown, explain)
--Testcase 2641:
EXPLAIN VERBOSE
SELECT to_days('1997-10-14 00:00:00'::date), to_days(c2), log2(id) FROM time_tbl;

-- select to_days with non pushdown func and explicit constant (explain)
--Testcase 2642:
EXPLAIN VERBOSE
SELECT to_days('1997-10-14 00:00:00'::date), to_days(c2), to_hex(id), 4 FROM time_tbl;

-- select to_days with order by (explain)
--Testcase 2643:
EXPLAIN VERBOSE
SELECT to_days(id + 200719), to_days(c2), c1 FROM time_tbl ORDER BY c1;

-- select to_days with order by index (explain)
--Testcase 2644:
EXPLAIN VERBOSE
SELECT to_days(id + 200719), to_days(c2), c1 FROM time_tbl ORDER BY 2;

-- to_days constraints with order by (explain)
--Testcase 2645:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE to_days('2020-10-14 00:00:00'::date) > to_days('1997-10-14 00:00:00'::date) ORDER BY c1;

-- to_days constraints with order by (result)
--Testcase 2646:
SELECT c1 FROM time_tbl WHERE to_days('2020-10-14 00:00:00'::date) > to_days('1997-10-14 00:00:00'::date) ORDER BY c1;

-- select to_days with group by (explain)
--Testcase 2647:
EXPLAIN VERBOSE
SELECT to_days(971014), to_days(c2), c1 FROM time_tbl GROUP BY c1,c2;

-- select to_days with group by index (explain)
--Testcase 2648:
EXPLAIN VERBOSE
SELECT to_days(971014), to_days(c2), c1 FROM time_tbl GROUP BY 1,2,3;

-- select to_days with group by having (explain)
--Testcase 2649:
EXPLAIN VERBOSE
SELECT to_days(971014), c1 FROM time_tbl GROUP BY c1,to_days(971014) HAVING to_days(971014) > 1000;

-- select to_days with group by index having (explain)
--Testcase 2650:
EXPLAIN VERBOSE
SELECT to_days(971014), c1 FROM time_tbl GROUP BY 2,1 HAVING to_days(971014) > 1000;

-- select to_days and as
--Testcase 2651:
EXPLAIN VERBOSE
SELECT to_days(971014), to_days(c2) as to_days1 FROM time_tbl;


-- TIMESTAMPDIFF()
-- select timestampdiff (stub function, explain)
--Testcase 2652:
EXPLAIN VERBOSE
SELECT timestampdiff('MINUTE', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('MONTH', c2, '2080-01-01'::date), timestampdiff('YEAR', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl;

-- select timestampdiff (stub function, result)
--Testcase 2653:
SELECT timestampdiff('MINUTE', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('MONTH', c2, '2080-01-01'::date), timestampdiff('YEAR', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl;

-- select timestampdiff (stub function, not pushdown constraints, explain)
--Testcase 2654:
EXPLAIN VERBOSE
SELECT timestampdiff('DAY', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('YEAR', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select timestampdiff (stub function, not pushdown constraints, result)
--Testcase 2655:
SELECT timestampdiff('DAY', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('YEAR', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select timestampdiff (stub function, pushdown constraints, explain)
--Testcase 2656:
EXPLAIN VERBOSE
SELECT timestampdiff('YEAR', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('YEAR', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200;

-- select timestampdiff (stub function, pushdown constraints, result)
--Testcase 2657:
SELECT timestampdiff('YEAR', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('YEAR', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200;

-- select timestampdiff (stub function, timestampdiff in constraints, explain)
--Testcase 2658:
EXPLAIN VERBOSE
SELECT timestampdiff('YEAR', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('YEAR', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl WHERE timestampdiff('YEAR', c3, '2080-01-01 12:00:00'::timestamp) < 100;

-- select timestampdiff (stub function, timestampdiff in constraints, result)
--Testcase 2659:
SELECT timestampdiff('YEAR', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('YEAR', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl WHERE timestampdiff('YEAR', c3, '2080-01-01 12:00:00'::timestamp) < 100;

-- select timestampdiff with agg (pushdown, explain)
--Testcase 2660:
EXPLAIN VERBOSE
SELECT max(c3), timestampdiff('DAY', max(c2), max(c3)), timestampdiff('MONTH', min(c2), min(c3)) FROM time_tbl;

-- select timestampdiff as nest function with agg (pushdown, result)
--Testcase 2661:
SELECT max(c3), timestampdiff('DAY', max(c2), max(c3)), timestampdiff('MONTH', min(c2), min(c3)) FROM time_tbl;

-- select timestampdiff with non pushdown func and explicit constant (explain)
--Testcase 2662:
EXPLAIN VERBOSE
SELECT timestampdiff('MONTH', c2, '2080-01-01'::date), timestampdiff('DAY', c3, '2080-01-01 12:00:00'::timestamp), pi(), 4.1 FROM time_tbl;

-- select timestampdiff with non pushdown func and explicit constant (result)
--Testcase 2663:
SELECT timestampdiff('MONTH', c2, '2080-01-01'::date), timestampdiff('DAY', c3, '2080-01-01 12:00:00'::timestamp), pi(), 4.1 FROM time_tbl;

-- select timestampdiff with order by (explain)
--Testcase 2664:
EXPLAIN VERBOSE
SELECT id, timestampdiff('DAY', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('DAY', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl order by timestampdiff('DAY', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('DAY', c3, '2080-01-01 12:00:00'::timestamp);

-- select timestampdiff with order by (result)
--Testcase 2665:
SELECT id, timestampdiff('DAY', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('DAY', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl order by timestampdiff('DAY', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('DAY', c3, '2080-01-01 12:00:00'::timestamp);

-- select timestampdiff with order by index (result)
--Testcase 2666:
SELECT id, timestampdiff('DAY', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('DAY', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl order by 5,4,3,2,1;

-- select timestampdiff with order by index (result)
--Testcase 2667:
SELECT id, timestampdiff('DAY', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('DAY', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl order by 1,2,3,4,5;

-- select timestampdiff with group by (explain)
--Testcase 2668:
EXPLAIN VERBOSE
SELECT max(c3), timestampdiff('DAY', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('DAY', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl group by timestampdiff('DAY', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('DAY', c3, '2080-01-01 12:00:00'::timestamp);

-- select timestampdiff with group by (result)
--Testcase 2669:
SELECT max(c3), timestampdiff('DAY', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('DAY', c3, '2080-01-01 12:00:00'::timestamp) FROM time_tbl group by timestampdiff('DAY', c2, c3), timestampdiff('DAY', c3, c2), timestampdiff('DAY', c2, '2080-01-01'::date), timestampdiff('DAY', c3, '2080-01-01 12:00:00'::timestamp);

-- select timestampdiff with group by index (result)
--Testcase 2670:
SELECT id, timestampdiff('DAY', '2021-01-01 12:00:00'::timestamp, '2080-01-01'::date), timestampdiff('DAY', '2019-01-01'::date, '2080-01-01 12:00:00'::timestamp) FROM time_tbl group by 3,2,1;

-- select timestampdiff with group by index (result)
--Testcase 2671:
SELECT id, timestampdiff('DAY', '2021-01-01 12:00:00'::timestamp, '2080-01-01'::date), timestampdiff('DAY', '2019-01-01'::date, '2080-01-01 12:00:00'::timestamp) FROM time_tbl group by 1,2,3;

-- select timestampdiff and as
--Testcase 2672:
SELECT timestampdiff('MINUTE', c2, c3) as timestampdiff1, timestampdiff('DAY', c3, c2) as timestampdiff2, timestampdiff('MONTH', c2, '2080-01-01'::date) as timestampdiff3, timestampdiff('YEAR', c3, '2080-01-01 12:00:00'::timestamp) as timestampdiff4 FROM time_tbl;



-- TIMESTAMPADD()
-- select timestampadd (stub function, explain)
--Testcase 2673:
EXPLAIN VERBOSE
SELECT timestampadd('MINUTE', 5, c3), timestampadd('DAY', 5, c2) FROM time_tbl;

-- select timestampadd (stub function, result)
--Testcase 2674:
SELECT timestampadd('MINUTE', 5, c3), timestampadd('DAY', 5, c2) FROM time_tbl;

-- select timestampadd (stub function, not pushdown constraints, explain)
--Testcase 2675:
EXPLAIN VERBOSE
SELECT timestampadd('MINUTE', 10, c3), timestampadd('YEAR', 5, c2) FROM time_tbl WHERE to_hex(id) = '1';

-- select timestampadd (stub function, not pushdown constraints, result)
--Testcase 2676:
SELECT timestampadd('MINUTE', 10, c3), timestampadd('YEAR', 5, c2) FROM time_tbl WHERE to_hex(id) = '1';

-- select timestampadd (stub function, pushdown constraints, explain)
--Testcase 2677:
EXPLAIN VERBOSE
SELECT timestampadd('MINUTE', 6, c3), timestampadd('YEAR', 5, c2) FROM time_tbl WHERE id != 200;

-- select timestampadd (stub function, pushdown constraints, result)
--Testcase 2678:
SELECT timestampadd('MINUTE', 6, c3), timestampadd('YEAR', 5, c2) FROM time_tbl WHERE id != 200;

-- select timestampadd (stub function, timestampadd in constraints, explain)
--Testcase 2679:
EXPLAIN VERBOSE
SELECT timestampadd('MINUTE', 6, c3), timestampadd('YEAR', 10, c2) FROM time_tbl WHERE timestampadd('YEAR', 1, c2) > '1997-01-01 12:00:00'::timestamp;

-- select timestampadd (stub function, timestampadd in constraints, result)
--Testcase 2680:
SELECT timestampadd('MINUTE', 6, c3), timestampadd('YEAR', 10, c2) FROM time_tbl WHERE timestampadd('YEAR', 1, c2) > '1997-01-01 12:00:00'::timestamp;

-- select timestampadd with agg (pushdown, explain)
--Testcase 2681:
EXPLAIN VERBOSE
SELECT max(c3), timestampadd('DAY', 2, max(c3)), timestampadd('MONTH', 2, min(c2)) FROM time_tbl;

-- select timestampadd as nest function with agg (pushdown, result)
--Testcase 2682:
SELECT max(c3), timestampadd('DAY', 2, max(c3)), timestampadd('MONTH', 2, min(c2)) FROM time_tbl;

-- select timestampadd with non pushdown func and explicit constant (explain)
--Testcase 2683:
EXPLAIN VERBOSE
SELECT timestampadd('MINUTE', 2, max(c3)), timestampadd('MONTH', 60, min(c2)), pi(), 4.1 FROM time_tbl;

-- select timestampadd with non pushdown func and explicit constant (result)
--Testcase 2684:
SELECT timestampadd('MINUTE', 2, max(c3)), timestampadd('MONTH', 60, min(c2)), pi(), 4.1 FROM time_tbl;

-- select timestampadd with order by (explain)
--Testcase 2685:
EXPLAIN VERBOSE
SELECT id, timestampadd('MINUTE', 60, c3), timestampadd('YEAR', 10, c2) FROM time_tbl order by timestampadd('MINUTE', 60, c3), timestampadd('YEAR', 10, c2);

-- select timestampadd with order by (result)
--Testcase 2686:
SELECT id, timestampadd('MINUTE', 60, c3), timestampadd('YEAR', 10, c2) FROM time_tbl order by timestampadd('MINUTE', 60, c3), timestampadd('YEAR', 10, c2);

-- select timestampadd with order by index (result)
--Testcase 2687:
SELECT id,timestampadd('MINUTE', 60, c3), timestampadd('YEAR', 10, c2) FROM time_tbl order by 3,2,1;

-- select timestampadd with order by index (result)
--Testcase 2688:
SELECT id, timestampadd('MINUTE', 60, c3), timestampadd('YEAR', 10, c2) FROM time_tbl order by 1,2,3;

-- select timestampadd with group by (explain)
--Testcase 2689:
EXPLAIN VERBOSE
SELECT max(c3), timestampadd('YEAR', 2, '1997-01-01 12:00:00'::timestamp), timestampadd('MONTH', 12, '1997-01-01'::date) FROM time_tbl group by timestampadd('YEAR', 2, '1997-01-01 12:00:00'::timestamp), timestampadd('MONTH', 12, '1997-01-01'::date);

-- select timestampadd with group by (result)
--Testcase 2690:
SELECT max(c3), timestampadd('YEAR', 2, '1997-01-01 12:00:00'::timestamp), timestampadd('MONTH', 12, '1997-01-01'::date) FROM time_tbl group by timestampadd('YEAR', 2, '1997-01-01 12:00:00'::timestamp), timestampadd('MONTH', 12, '1997-01-01'::date);

-- select timestampadd with group by index (result)
--Testcase 2691:
SELECT id, timestampadd('YEAR', 2, '1997-01-01 12:00:00'::timestamp), timestampadd('MONTH', 12, '1997-01-01'::date) FROM time_tbl group by 3,2,1;

-- select timestampadd with group by index (result)
--Testcase 2692:
SELECT id, timestampadd('YEAR', 2, '1997-01-01 12:00:00'::timestamp), timestampadd('MONTH', 12, '1997-01-01'::date) FROM time_tbl group by 1,2,3;

-- select timestampadd and as
--Testcase 2693:
SELECT timestampadd('MINUTE', 60, c2) as timestampadd1, timestampadd('MONTH', 12, '2080-01-01 12:01:00'::timestamp) as timestampadd2 FROM time_tbl;



-- TIMESTAMP()
-- select mysql_timestamp (stub function, explain)
--Testcase 2694:
EXPLAIN VERBOSE
SELECT mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl;

-- select mysql_timestamp (stub function, result)
--Testcase 2695:
SELECT mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl;

-- select mysql_timestamp (stub function, not pushdown constraints, explain)
--Testcase 2696:
EXPLAIN VERBOSE
SELECT mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl WHERE to_hex(id) = '1';

-- select mysql_timestamp (stub function, not pushdown constraints, result)
--Testcase 2697:
SELECT mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl WHERE to_hex(id) = '1';

-- select mysql_timestamp (stub function, pushdown constraints, explain)
--Testcase 2698:
EXPLAIN VERBOSE
SELECT mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl WHERE id != 200;

-- select mysql_timestamp (stub function, pushdown constraints, result)
--Testcase 2699:
SELECT mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl WHERE id != 200;

-- select mysql_timestamp (stub function, mysql_timestamp in constraints, explain)
--Testcase 2700:
EXPLAIN VERBOSE
SELECT mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl WHERE mysql_timestamp(c3, '23:11:59.123456'::time) < '2080-01-01 12:00:00'::timestamp;

-- select mysql_timestamp (stub function, mysql_timestamp in constraints, result)
--Testcase 2701:
SELECT mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl WHERE mysql_timestamp(c3, '23:11:59.123456'::time) < '2080-01-01 12:00:00'::timestamp;

-- select mysql_timestamp with agg (pushdown, explain)
--Testcase 2702:
EXPLAIN VERBOSE
SELECT max(c3), mysql_timestamp(max(c2)), mysql_timestamp(max(c3)), mysql_timestamp(max(c3), '11:12:12.112233'::time) FROM time_tbl;

-- select mysql_timestamp as nest function with agg (pushdown, result)
--Testcase 2703:
SELECT max(c3), mysql_timestamp(max(c2)), mysql_timestamp(max(c3)), mysql_timestamp(max(c3), '11:12:12.112233'::time) FROM time_tbl;

-- select mysql_timestamp with non pushdown func and explicit constant (explain)
--Testcase 2704:
EXPLAIN VERBOSE
SELECT mysql_timestamp(max(c2)), mysql_timestamp(max(c3)), mysql_timestamp(max(c3), '11:12:12.112233'::time), pi(), 4.1 FROM time_tbl;

-- select mysql_timestamp with non pushdown func and explicit constant (result)
--Testcase 2705:
SELECT mysql_timestamp(max(c2)), mysql_timestamp(max(c3)), mysql_timestamp(max(c3), '11:12:12.112233'::time), pi(), 4.1 FROM time_tbl;

-- select mysql_timestamp with order by (explain)
--Testcase 2706:
EXPLAIN VERBOSE
SELECT id, mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl order by mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1);

-- select mysql_timestamp with order by (result)
--Testcase 2707:
SELECT id, mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl order by mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1);

-- select mysql_timestamp with order by index (result)
--Testcase 2708:
SELECT id, mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl order by 4,3,2,1;

-- select mysql_timestamp with order by index (result)
--Testcase 2709:
SELECT id, mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl order by 1,2,3,4;

-- select mysql_timestamp with group by (explain)
--Testcase 2710:
EXPLAIN VERBOSE
SELECT max(c3), mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl group by mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1);

-- select mysql_timestamp with group by (result)
--Testcase 2711:
SELECT max(c3), mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl group by mysql_timestamp('2080-01-01 12:00:00'::date), c1, c2, c3;

-- select mysql_timestamp with group by index (result)
--Testcase 2712:
SELECT id, mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl group by 4,3,2,1;

-- select mysql_timestamp with group by index (result)
--Testcase 2713:
SELECT id, mysql_timestamp(c2), mysql_timestamp(c3), mysql_timestamp(c3, c1) FROM time_tbl group by 1,2,3,4;

-- select mysql_timestamp with group by index having (result)
--Testcase 2714:
SELECT id, mysql_timestamp(c2), c2 FROM time_tbl group by 3, 2, 1 HAVING mysql_timestamp(c2) > '2019-01-01'::date;

-- select mysql_timestamp with group by index having (result)
--Testcase 2715:
SELECT id, mysql_timestamp(c2), c2 FROM time_tbl group by 1, 2, 3 HAVING mysql_timestamp(c2) > '2019-01-01'::date;

-- select mysql_timestamp and as
--Testcase 2716:
SELECT mysql_timestamp(c2) as mysql_timestamp1, mysql_timestamp(c3) as mysql_timestamp2,  mysql_timestamp(c3, c1) as mysql_timestamp3 FROM time_tbl;

-- TIMEDIFF()
-- select timediff (stub function, explain)
--Testcase 2717:
EXPLAIN VERBOSE
SELECT timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl;

-- select timediff (stub function, result)
--Testcase 2718:
SELECT timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl;

-- select timediff (stub function, not pushdown constraints, explain)
--Testcase 2719:
EXPLAIN VERBOSE
SELECT timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select timediff (stub function, not pushdown constraints, result)
--Testcase 2720:
SELECT timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select timediff (stub function, pushdown constraints, explain)
--Testcase 2721:
EXPLAIN VERBOSE
SELECT timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200;

-- select timediff (stub function, pushdown constraints, result)
--Testcase 2722:
SELECT timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200;

-- select timediff (stub function, timediff in constraints, explain)
--Testcase 2723:
EXPLAIN VERBOSE
SELECT timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl WHERE timediff(c1, '23:11:59.123456'::time) > '1 day 01:00:00'::interval;

-- select timediff (stub function, timediff in constraints, result)
--Testcase 2724:
SELECT timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl WHERE timediff(c1, '23:11:59.123456'::time) > '1 day 01:00:00'::interval;

-- select timediff with agg (pushdown, explain)
--Testcase 2725:
EXPLAIN VERBOSE
SELECT max(c3), timediff('12:12:12.051555'::time, max(c1)), timediff('1997-01-01 12:00:00'::timestamp, max(c3)) FROM time_tbl;

-- select timediff as nest function with agg (pushdown, result)
--Testcase 2726:
SELECT max(c3), timediff('12:12:12.051555'::time, max(c1)), timediff('1997-01-01 12:00:00'::timestamp, max(c3)) FROM time_tbl;

-- select timediff with non pushdown func and explicit constant (explain)
--Testcase 2727:
EXPLAIN VERBOSE
SELECT timediff('12:12:12.051555'::time, max(c1)), timediff('1997-01-01 12:00:00'::timestamp, max(c3)), pi(), 4.1 FROM time_tbl;

-- select timediff with non pushdown func and explicit constant (result)
--Testcase 2728:
SELECT timediff('12:12:12.051555'::time, max(c1)), timediff('1997-01-01 12:00:00'::timestamp, max(c3)), pi(), 4.1 FROM time_tbl;

-- select timediff with order by (explain)
--Testcase 2729:
EXPLAIN VERBOSE
SELECT id, timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl order by timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp);

-- select timediff with order by (result)
--Testcase 2730:
SELECT id, timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl order by timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp);

-- select timediff with order by index (result)
--Testcase 2731:
SELECT id, timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl order by 3,2,1;

-- select timediff with order by index (result)
--Testcase 2732:
SELECT id, timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl order by 1,2,3;

-- select timediff with group by (explain)
--Testcase 2733:
EXPLAIN VERBOSE
SELECT max(c3), timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl group by timediff('2080-01-01 12:00:00'::timestamp, c3), c1, c3;

-- select timediff with group by (result)
--Testcase 2734:
SELECT max(c3), timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl group by timediff('2080-01-01 12:00:00'::timestamp, c3), c1, c3;

-- select timediff with group by index (result)
--Testcase 2735:
SELECT id, timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl group by 3,2,1;

-- select timediff with group by index (result)
--Testcase 2736:
SELECT id, timediff(c1, '12:12:12.051555'::time), timediff(c3, '1997-01-01 12:00:00'::timestamp) FROM time_tbl group by 1,2,3;

-- select timediff with group by index having (result)
--Testcase 2737:
SELECT id, timediff(c1, '12:12:12.051555'::time), c1 FROM time_tbl group by 3, 2, 1 HAVING timediff(c1, '12:12:12.051555'::time) < '1 days'::interval;

-- select timediff with group by index having (result)
--Testcase 2738:
SELECT id, timediff(c1, '12:12:12.051555'::time), c1 FROM time_tbl group by 1, 2, 3 HAVING timediff(c1, '12:12:12.051555'::time) < '1 days'::interval;

-- select timediff and as
--Testcase 2739:
SELECT timediff(c1, '12:12:12.051555'::time) as timediff1, timediff(c3, '1997-01-01 12:00:00'::timestamp) as timediff2 FROM time_tbl;


-- TIME_TO_SEC()
-- select time_to_sec (stub function, explain)
--Testcase 2740:
EXPLAIN VERBOSE
SELECT time_to_sec(c1), time_to_sec(mysql_time(c3)), time_to_sec('01:02:03.040505'::time) FROM time_tbl;

-- select time_to_sec (stub function, result)
--Testcase 2741:
SELECT time_to_sec(c1), time_to_sec(mysql_time(c3)), time_to_sec('01:02:03.040505'::time) FROM time_tbl;

-- select time_to_sec (stub function, not pushdown constraints, explain)
--Testcase 2742:
EXPLAIN VERBOSE
SELECT time_to_sec(c1), time_to_sec(mysql_time(c3)), time_to_sec('01:02:03.040505'::time) FROM time_tbl WHERE to_hex(id) = '2';

-- select time_to_sec (stub function, not pushdown constraints, result)
--Testcase 2743:
SELECT time_to_sec(c1), time_to_sec(mysql_time(c3)), time_to_sec('01:02:03.040505'::time) FROM time_tbl WHERE to_hex(id) = '2';

-- select time_to_sec (stub function, pushdown constraints, explain)
--Testcase 2744:
EXPLAIN VERBOSE
SELECT time_to_sec(c1), time_to_sec(mysql_time(c3)), time_to_sec('01:02:03.040505'::time) FROM time_tbl WHERE id != 200;

-- select time_to_sec (stub function, pushdown constraints, result)
--Testcase 2745:
SELECT time_to_sec(c1), time_to_sec(mysql_time(c3)), time_to_sec('01:02:03.040505'::time) FROM time_tbl WHERE id != 200;

-- select time_to_sec (stub function, time_to_sec in constraints, explain)
--Testcase 2746:
EXPLAIN VERBOSE
SELECT time_to_sec(c1), time_to_sec(mysql_time(c3)), time_to_sec('01:02:03.040505'::time) FROM time_tbl WHERE time_to_sec(c1) != 12345;

-- select time_to_sec (stub function, time_to_sec in constraints, result)
--Testcase 2747:
SELECT time_to_sec(c1), time_to_sec(mysql_time(c3)), time_to_sec('01:02:03.040505'::time) FROM time_tbl WHERE time_to_sec(c1) != 12345;

-- select time_to_sec (stub function, time_to_sec in constraints, explain)
--Testcase 2748:
EXPLAIN VERBOSE
SELECT time_to_sec(c1), time_to_sec(mysql_time(c3)), time_to_sec('01:02:03.040505'::time) FROM time_tbl WHERE time_to_sec('06:05:04.030201'::time) > 1;

-- select time_to_sec (stub function, time_to_sec in constraints, result)
--Testcase 2749:
SELECT time_to_sec(c1), time_to_sec(mysql_time(c3)), time_to_sec('01:02:03.040505'::time) FROM time_tbl WHERE time_to_sec('06:05:04.030201'::time) > 1;

-- select time_to_sec with agg (pushdown, explain)
--Testcase 2750:
EXPLAIN VERBOSE
SELECT max(c3), time_to_sec(max(c1)) FROM time_tbl;

-- select time_to_sec as nest function with agg (pushdown, result)
--Testcase 2751:
SELECT max(c3), time_to_sec(max(c1)) FROM time_tbl;

-- select time_to_sec with non pushdown func and explicit constant (explain)
--Testcase 2752:
EXPLAIN VERBOSE
SELECT time_to_sec(mysql_time(c3)), pi(), 4.1 FROM time_tbl;

-- select time_to_sec with non pushdown func and explicit constant (result)
--Testcase 2753:
SELECT time_to_sec(mysql_time(c3)), pi(), 4.1 FROM time_tbl;

-- select time_to_sec with order by (explain)
--Testcase 2754:
EXPLAIN VERBOSE
SELECT id, time_to_sec(c1) FROM time_tbl order by time_to_sec(c1);

-- select time_to_sec with order by (result)
--Testcase 2755:
SELECT id, time_to_sec(c1) FROM time_tbl order by time_to_sec(c1);

-- select time_to_sec with order by index (result)
--Testcase 2756:
SELECT id, time_to_sec(c1) FROM time_tbl order by 2,1;

-- select time_to_sec with order by index (result)
--Testcase 2757:
SELECT id, time_to_sec(c1) FROM time_tbl order by 1,2;

-- select time_to_sec with group by (explain)
--Testcase 2758:
EXPLAIN VERBOSE
SELECT max(c3), time_to_sec(c1) FROM time_tbl group by c1, time_to_sec('06:05:04.030201'::time);

-- select time_to_sec with group by (result)
--Testcase 2759:
SELECT max(c3), time_to_sec(c1) FROM time_tbl group by c1, time_to_sec('06:05:04.030201'::time);

-- select time_to_sec with group by index (result)
--Testcase 2760:
SELECT id, time_to_sec(c1) FROM time_tbl group by 2,1;

-- select time_to_sec with group by index (result)
--Testcase 2761:
SELECT id, time_to_sec(c1) FROM time_tbl group by 1,2;

-- select time_to_sec with group by having (explain)
--Testcase 2762:
EXPLAIN VERBOSE
SELECT max(c3), time_to_sec(c1), c1 FROM time_tbl group by time_to_sec(c1), c3, c1 HAVING time_to_sec(c1) > 100;

-- select time_to_sec with group by having (result)
--Testcase 2763:
SELECT max(c3), time_to_sec(c1), c1 FROM time_tbl group by time_to_sec(c1), c3, c1 HAVING time_to_sec(c1) > 100;

-- select time_to_sec with group by index having (result)
--Testcase 2764:
SELECT id, time_to_sec(c1), c1 FROM time_tbl group by 3, 2, 1 HAVING time_to_sec(c1) > 100;

-- select time_to_sec with group by index having (result)
--Testcase 2765:
SELECT id, time_to_sec(c1), c1 FROM time_tbl group by 1, 2, 3 HAVING time_to_sec(c1) > 100;

-- select time_to_sec and as
--Testcase 2766:
SELECT time_to_sec(c1) as time_to_sec1 FROM time_tbl;


-- TIME_FORMAT()
-- select time_format (stub function, explain)
--Testcase 2767:
EXPLAIN VERBOSE
SELECT time_format(c1, '%H %k %h %I %l'), time_format(mysql_time(c3), '%H %k %h %I %l'), time_format('01:02:03.040505'::time, '%H %k %h %I %l') FROM time_tbl;

-- select time_format (stub function, result)
--Testcase 2768:
SELECT time_format(c1, '%H %k %h %I %l'), time_format(mysql_time(c3), '%H %k %h %I %l'), time_format('01:02:03.040505'::time, '%H %k %h %I %l') FROM time_tbl;

-- select time_format (stub function, not pushdown constraints, explain)
--Testcase 2769:
EXPLAIN VERBOSE
SELECT time_format(c1, '%H %k %h %I %l'), time_format(mysql_time(c3), '%H %k %h %I %l'), time_format('01:02:03.040505'::time, '%H %k %h %I %l') FROM time_tbl WHERE to_hex(id) = '2';

-- select time_format (stub function, not pushdown constraints, result)
--Testcase 2770:
SELECT time_format(c1, '%H %k %h %I %l'), time_format(mysql_time(c3), '%H %k %h %I %l'), time_format('01:02:03.040505'::time, '%H %k %h %I %l') FROM time_tbl WHERE to_hex(id) = '2';

-- select time_format (stub function, pushdown constraints, explain)
--Testcase 2771:
EXPLAIN VERBOSE
SELECT time_format(c1, '%H %k %h %I %l'), time_format(mysql_time(c3), '%H %k %h %I %l'), time_format('01:02:03.040505'::time, '%H %k %h %I %l') FROM time_tbl WHERE id != 200;

-- select time_format (stub function, pushdown constraints, result)
--Testcase 2772:
SELECT time_format(c1, '%H %k %h %I %l'), time_format(mysql_time(c3), '%H %k %h %I %l'), time_format('01:02:03.040505'::time, '%H %k %h %I %l') FROM time_tbl WHERE id != 200;

-- select time_format (stub function, time_format in constraints, explain)
--Testcase 2773:
EXPLAIN VERBOSE
SELECT time_format(c1, '%H %k %h %I %l'), time_format(mysql_time(c3), '%H %k %h %I %l'), time_format('01:02:03.040505'::time, '%H %k %h %I %l') FROM time_tbl WHERE time_format(c1, '%H %k %h %I %l') != '100 100 04 04 4';

-- select time_format (stub function, time_format in constraints, result)
--Testcase 2774:
SELECT time_format(c1, '%H %k %h %I %l'), time_format(mysql_time(c3), '%H %k %h %I %l'), time_format('01:02:03.040505'::time, '%H %k %h %I %l') FROM time_tbl WHERE time_format(c1, '%H %k %h %I %l') != '100 100 04 04 4';

-- select time_format (stub function, time_format in constraints, explain)
--Testcase 2775:
EXPLAIN VERBOSE
SELECT time_format(c1, '%H %k %h %I %l'), time_format(mysql_time(c3), '%H %k %h %I %l'), time_format('01:02:03.040505'::time, '%H %k %h %I %l') FROM time_tbl WHERE time_format(c1, '%H %k %h %I %l') = '12 12 12 12 12';

-- select time_format (stub function, time_format in constraints, result)
--Testcase 2776:
SELECT time_format(c1, '%H %k %h %I %l'), time_format(mysql_time(c3), '%H %k %h %I %l'), time_format('01:02:03.040505'::time, '%H %k %h %I %l') FROM time_tbl WHERE time_format(c1, '%H %k %h %I %l') = '12 12 12 12 12';

-- select time_format with agg (pushdown, explain)
--Testcase 2777:
EXPLAIN VERBOSE
SELECT max(c3), time_format(max(c1), '%H %k %h %I %l') FROM time_tbl;

-- select time_format as nest function with agg (pushdown, result)
--Testcase 2778:
SELECT max(c3), time_format(max(c1), '%H %k %h %I %l') FROM time_tbl;

-- select time_format with non pushdown func and explicit constant (explain)
--Testcase 2779:
EXPLAIN VERBOSE
SELECT time_format(mysql_time(c3), '%H %k %h %I %l'), pi(), 4.1 FROM time_tbl;

-- select time_format with non pushdown func and explicit constant (result)
--Testcase 2780:
SELECT time_format(mysql_time(c3), '%H %k %h %I %l'), pi(), 4.1 FROM time_tbl;

-- select time_format with order by (explain)
--Testcase 2781:
EXPLAIN VERBOSE
SELECT id, time_format(c1, '%H %k %h %I %l') FROM time_tbl order by time_format(c1, '%H %k %h %I %l');

-- select time_format with order by (result)
--Testcase 2782:
SELECT id, time_format(c1, '%H %k %h %I %l') FROM time_tbl order by time_format(c1, '%H %k %h %I %l');

-- select time_format with order by index (result)
--Testcase 2783:
SELECT id, time_format(c1, '%H %k %h %I %l') FROM time_tbl order by 2,1;

-- select time_format with order by index (result)
--Testcase 2784:
SELECT id, time_format(c1, '%H %k %h %I %l') FROM time_tbl order by 1,2;

-- select time_format with group by (explain)
--Testcase 2785:
EXPLAIN VERBOSE
SELECT max(c3), time_format(c1, '%H %k %h %I %l') FROM time_tbl group by c1, time_format('06:05:04.030201'::time, '%H %k %h %I %l');

-- select time_format with group by (result)
--Testcase 2786:
SELECT max(c3), time_format(c1, '%H %k %h %I %l') FROM time_tbl group by c1, time_format('06:05:04.030201'::time, '%H %k %h %I %l');

-- select time_format with group by index (result)
--Testcase 2787:
SELECT id, time_format(c1, '%H %k %h %I %l') FROM time_tbl group by 2,1;

-- select time_format with group by index (result)
--Testcase 2788:
SELECT id, time_format(c1, '%H %k %h %I %l') FROM time_tbl group by 1,2;

-- select time_format with group by having (explain)
--Testcase 2789:
EXPLAIN VERBOSE
SELECT max(c3), time_format(c1, '%H %k %h %I %l') FROM time_tbl group by time_format(c1, '%H %k %h %I %l'), c3, c1 HAVING time_format(c1, '%H %k %h %I %l') != '100 100 04 04 4';

-- select time_format with group by having (result)
--Testcase 2790:
SELECT max(c3), time_format(c1, '%H %k %h %I %l') FROM time_tbl group by time_format(c1, '%H %k %h %I %l'), c3, c1 HAVING time_format(c1, '%H %k %h %I %l') != '100 100 04 04 4';

-- select time_format with group by index having (result)
--Testcase 2791:
SELECT id, c1, time_format(c1, '%H %k %h %I %l'), c3 FROM time_tbl group by 4, 3, 2, 1 HAVING time_format(c1, '%H %k %h %I %l') != '100 100 04 04 4';

-- select time_format with group by index having (result)
--Testcase 2792:
SELECT id, c1, time_format(c1, '%H %k %h %I %l'), c3 FROM time_tbl group by 1, 2, 3, 4 HAVING time_format(c1, '%H %k %h %I %l') != '100 100 04 04 4';

-- select time_format and as
--Testcase 2793:
SELECT time_format(c1, '%H %k %h %I %l') as time_format1 FROM time_tbl;



-- TIME()
-- select mysql_time (stub function, explain)
--Testcase 2794:
EXPLAIN VERBOSE
SELECT mysql_time(c3), mysql_time(c2), mysql_time(date_sub(c3, '1 12:59:10')), mysql_time('2021-01-01 12:00:00') FROM time_tbl;

-- select mysql_time (stub function, result)
--Testcase 2795:
SELECT mysql_time(c3), mysql_time(c2), mysql_time(date_sub(c3, '1 12:59:10')), mysql_time('2021-01-01 12:00:00') FROM time_tbl;

-- select mysql_time (stub function, not pushdown constraints, explain)
--Testcase 2796:
EXPLAIN VERBOSE
SELECT mysql_time(c3), mysql_time(c2), mysql_time(date_sub(c3, '1 12:59:10')), mysql_time('2021-01-01 12:00:00') FROM time_tbl WHERE to_hex(id) = '0';

-- select mysql_time (stub function, not pushdown constraints, result)
--Testcase 2797:
SELECT mysql_time(c3), mysql_time(c2), mysql_time(date_sub(c3, '1 12:59:10')), mysql_time('2021-01-01 12:00:00') FROM time_tbl WHERE to_hex(id) = '0';

-- select mysql_time (stub function, pushdown constraints, explain)
--Testcase 2798:
EXPLAIN VERBOSE
SELECT mysql_time(c3), mysql_time(c2), mysql_time(date_sub(c3, '1 12:59:10')), mysql_time('2021-01-01 12:00:00') FROM time_tbl WHERE id != 200;

-- select mysql_time (stub function, pushdown constraints, result)
--Testcase 2799:
SELECT mysql_time(c3), mysql_time(c2), mysql_time(date_sub(c3, '1 12:59:10')), mysql_time('2021-01-01 12:00:00') FROM time_tbl WHERE id != 200;

-- select mysql_time (stub function, mysql_time in constraints, explain)
--Testcase 2800:
EXPLAIN VERBOSE
SELECT mysql_time(c3), mysql_time(c2), mysql_time(date_sub(c3, '1 12:59:10')), mysql_time('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE mysql_time(c3) != '06:05:04.030201'::time;

-- select mysql_time (stub function, mysql_time in constraints, result)
--Testcase 2801:
SELECT mysql_time(c3), mysql_time(c2), mysql_time(date_sub(c3, '1 12:59:10')), mysql_time('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE mysql_time(c3) != '06:05:04.030201'::time;

-- select mysql_time (stub function, mysql_time in constraints, explain)
--Testcase 2802:
EXPLAIN VERBOSE
SELECT mysql_time(c3), mysql_time(c2), mysql_time(date_sub(c3, '1 12:59:10')), mysql_time('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE mysql_time('2021-01-01 12:00:00'::timestamp) > '06:05:04.030201'::time;

-- select mysql_time (stub function, mysql_time in constraints, result)
--Testcase 2803:
SELECT mysql_time(c3), mysql_time(c2), mysql_time(date_sub(c3, '1 12:59:10')), mysql_time('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE mysql_time('2021-01-01 12:00:00'::timestamp) > '06:05:04.030201'::time;

-- select mysql_time with agg (pushdown, explain)
--Testcase 2804:
EXPLAIN VERBOSE
SELECT max(c3), mysql_time(max(c3)) FROM time_tbl;

-- select mysql_time as nest function with agg (pushdown, result)
--Testcase 2805:
SELECT max(c3), mysql_time(max(c3)) FROM time_tbl;

-- select mysql_time with non pushdown func and explicit constant (explain)
--Testcase 2806:
EXPLAIN VERBOSE
SELECT mysql_time(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl;

-- select mysql_time with non pushdown func and explicit constant (result)
--Testcase 2807:
SELECT mysql_time(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl;

-- select mysql_time with order by (explain)
--Testcase 2808:
EXPLAIN VERBOSE
SELECT id, mysql_time(c3 + '1 12:59:10') FROM time_tbl order by mysql_time(c3 + '1 12:59:10');

-- select mysql_time with order by (result)
--Testcase 2809:
SELECT id, mysql_time(c3 + '1 12:59:10') FROM time_tbl order by mysql_time(c3 + '1 12:59:10');

-- select mysql_time with order by index (result)
--Testcase 2810:
SELECT id, mysql_time(c3 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select mysql_time with order by index (result)
--Testcase 2811:
SELECT id, mysql_time(c3 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select mysql_time with group by (explain)
--Testcase 2812:
EXPLAIN VERBOSE
SELECT max(c3), mysql_time(c3 + '1 12:59:10') FROM time_tbl group by mysql_time(c3 + '1 12:59:10');

-- select mysql_time with group by (result)
--Testcase 2813:
SELECT max(c3), mysql_time(c3 + '1 12:59:10') FROM time_tbl group by mysql_time(c3 + '1 12:59:10');

-- select mysql_time with group by index (result)
--Testcase 2814:
SELECT id, mysql_time(c3 + '1 12:59:10') FROM time_tbl group by 2,1;

-- select mysql_time with group by index (result)
--Testcase 2815:
SELECT id, mysql_time(c3 + '1 12:59:10') FROM time_tbl group by 1,2;

-- select mysql_time with group by having (explain)
--Testcase 2816:
EXPLAIN VERBOSE
SELECT max(c3), mysql_time(c3 + '1 12:59:10') FROM time_tbl group by mysql_time(c3 + '1 12:59:10'), c3 HAVING mysql_time(c3 + '1 12:59:10') > '06:05:04.030201'::time;

-- select mysql_time with group by having (result)
--Testcase 2817:
SELECT max(c3), mysql_time(c3 + '1 12:59:10') FROM time_tbl group by mysql_time(c3 + '1 12:59:10'), c3 HAVING mysql_time(c3 + '1 12:59:10') > '06:05:04.030201'::time;

-- select mysql_time with group by index having (result)
--Testcase 2818:
SELECT id, mysql_time(c3 + '1 12:59:10'), c3 FROM time_tbl group by 3, 2, 1 HAVING mysql_time(c3 + '1 12:59:10') > '06:05:04.030201'::time;

-- select mysql_time with group by index having (result)
--Testcase 2819:
SELECT id, mysql_time(c3 + '1 12:59:10'), c3 FROM time_tbl group by 1, 2, 3 HAVING mysql_time(c3 + '1 12:59:10') > '06:05:04.030201'::time;

-- select mysql_time and as
--Testcase 2820:
SELECT mysql_time(date_sub(c3, '1 12:59:10')) as mysql_time1 FROM time_tbl;


-- SYSDATE()
-- select sysdate (stub function, explain)
--Testcase 2821:
EXPLAIN VERBOSE
SELECT datediff(sysdate(), sysdate()) FROM time_tbl;

-- select sysdate (stub function, result)
--Testcase 2822:
SELECT datediff(sysdate(), sysdate()) FROM time_tbl;

-- select sysdate (stub function, not pushdown constraints, explain)
--Testcase 2823:
EXPLAIN VERBOSE
SELECT datediff(sysdate(), sysdate()) FROM time_tbl WHERE to_hex(id) > '0';

-- select sysdate (stub function, not pushdown constraints, result)
--Testcase 2824:
SELECT datediff(sysdate(), sysdate()) FROM time_tbl WHERE to_hex(id) > '0';

-- select sysdate (stub function, pushdown constraints, explain)
--Testcase 2825:
EXPLAIN VERBOSE
SELECT datediff(sysdate(), sysdate()) FROM time_tbl WHERE id = 1;

-- select sysdate (stub function, pushdown constraints, result)
--Testcase 2826:
SELECT datediff(sysdate(), sysdate()) FROM time_tbl WHERE id = 1;

-- select sysdate (stub function, sysdate in constraints, explain)
--Testcase 2827:
EXPLAIN VERBOSE
SELECT datediff(sysdate(), sysdate()) FROM time_tbl WHERE sysdate() > '1997-10-14 00:00:00'::timestamp;

-- select sysdate (stub function, sysdate in constraints, result)
--Testcase 2828:
SELECT datediff(sysdate(), sysdate()) FROM time_tbl WHERE sysdate() > '1997-10-14 00:00:00'::timestamp;

-- sysdate in constrains (stub function, explain)
--Testcase 2829:
EXPLAIN VERBOSE
SELECT id, c1 FROM time_tbl WHERE sysdate() > '1997-10-14 00:00:00'::timestamp;

-- sysdate in constrains (stub function, result)
--Testcase 2830:
SELECT id, c1 FROM time_tbl WHERE sysdate() > '1997-10-14 00:00:00'::timestamp;

-- sysdate as parameter of addtime(stub function, explain)
--Testcase 2831:
EXPLAIN VERBOSE
SELECT id, c1 FROM time_tbl WHERE addtime(sysdate(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp;

-- sysdate as parameter of addtime(stub function, result)
--Testcase 2832:
SELECT id, c1 FROM time_tbl WHERE addtime(sysdate(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp;

-- select sysdate and agg (pushdown, explain)
--Testcase 2833:
EXPLAIN VERBOSE
SELECT datediff(sysdate(), sysdate()), sum(id) FROM time_tbl;

-- select sysdate and agg (pushdown, result)
--Testcase 2834:
SELECT datediff(sysdate(), sysdate()), sum(id) FROM time_tbl;

-- select sysdate and log2 (pushdown, explain)
--Testcase 2835:
EXPLAIN VERBOSE
SELECT id, datediff(sysdate(), sysdate()), log2(id) FROM time_tbl;

-- select sysdate and log2 (pushdown, result)
--Testcase 2836:
SELECT id, datediff(sysdate(), sysdate()), log2(id) FROM time_tbl;

-- select sysdate with non pushdown func and explicit constant (explain)
--Testcase 2837:
EXPLAIN VERBOSE
SELECT datediff(sysdate(), sysdate()), to_hex(id), 4 FROM time_tbl;

-- select sysdate with non pushdown func and explicit constant (result)
--Testcase 2838:
SELECT datediff(sysdate(), sysdate()), to_hex(id), 4 FROM time_tbl;

-- select sysdate with order by (explain)
--Testcase 2839:
EXPLAIN VERBOSE
SELECT datediff(sysdate(), sysdate()), c1 FROM time_tbl ORDER BY datediff(sysdate(), sysdate()),c1;

-- select sysdate with order by (result)
--Testcase 2840:
SELECT datediff(sysdate(), sysdate()), c1 FROM time_tbl ORDER BY datediff(sysdate(), sysdate()),c1;

-- select sysdate with order by index (explain)
--Testcase 2841:
EXPLAIN VERBOSE
SELECT datediff(sysdate(), sysdate()), c1 FROM time_tbl ORDER BY 1,2;

-- select sysdate with order by index (result)
--Testcase 2842:
SELECT datediff(sysdate(), sysdate()), c1 FROM time_tbl ORDER BY 1,2;

-- sysdate constraints with order by (explain)
--Testcase 2843:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(sysdate(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp ORDER BY c1;

-- sysdate constraints with order by (result)
--Testcase 2844:
SELECT c1 FROM time_tbl WHERE addtime(sysdate(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp ORDER BY c1;

-- select sysdate with group by (explain)
--Testcase 2845:
EXPLAIN VERBOSE
SELECT id, datediff(sysdate(), sysdate()), c1 FROM time_tbl GROUP BY id,datediff(sysdate(), sysdate()),c1;

-- select sysdate with group by (result)
--Testcase 2846:
SELECT id, datediff(sysdate(), sysdate()), c1 FROM time_tbl GROUP BY id,datediff(sysdate(), sysdate()),c1;

-- select sysdate with group by index (explain)
--Testcase 2847:
EXPLAIN VERBOSE
SELECT id, datediff(sysdate(), sysdate()), c1 FROM time_tbl GROUP BY 1,2,3;

-- select sysdate with group by index (result)
--Testcase 2848:
SELECT id, datediff(sysdate(), sysdate()), c1 FROM time_tbl GROUP BY 1,2,3;

-- select sysdate with group by having (explain)
--Testcase 2849:
EXPLAIN VERBOSE
SELECT id, datediff(sysdate(), sysdate()), c1 FROM time_tbl GROUP BY datediff(sysdate(), sysdate()),c1,id HAVING datediff(sysdate(), sysdate()) >= 0;

-- select sysdate with group by having (result)
--Testcase 2850:
SELECT id, datediff(sysdate(), sysdate()), c1 FROM time_tbl GROUP BY datediff(sysdate(), sysdate()),c1,id HAVING datediff(sysdate(), sysdate()) >= 0;

-- select sysdate with group by index having (explain)
--Testcase 2851:
EXPLAIN VERBOSE
SELECT id, datediff(sysdate(), sysdate()), c1 FROM time_tbl GROUP BY 3,2,1 HAVING datediff(sysdate(), sysdate()) >= 0;

-- select sysdate with group by index having (result)
--Testcase 2852:
SELECT id, datediff(sysdate(), sysdate()), c1 FROM time_tbl GROUP BY 3,2,1 HAVING datediff(sysdate(), sysdate()) >= 0;

-- sysdate constraints with group by (explain)
--Testcase 2853:
EXPLAIN VERBOSE
SELECT id, c1 FROM time_tbl WHERE addtime(sysdate(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp GROUP BY id,c1;

-- sysdate constraints with group by (result)
--Testcase 2854:
SELECT id, c1 FROM time_tbl WHERE addtime(sysdate(), '1 12:59:10'::interval) > '1997-10-14 00:00:00'::timestamp GROUP BY id,c1;

-- select sysdate and as (explain)
--Testcase 2855:
EXPLAIN VERBOSE
SELECT datediff(sysdate(), sysdate()) as sysdate1 FROM time_tbl;

-- select sysdate and as (result)
--Testcase 2856:
SELECT datediff(sysdate(), sysdate()) as sysdate1 FROM time_tbl;

-- SUBTIME()
-- select subtime (stub function, explain)
--Testcase 2857:
EXPLAIN VERBOSE
SELECT subtime(c3, '1 12:59:10'), subtime(c3, INTERVAL '6 months 2 hours 30 minutes'), subtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl;

-- select subtime (stub function, result)
--Testcase 2858:
SELECT subtime(c3, '1 12:59:10'), subtime(c3, INTERVAL '6 months 2 hours 30 minutes'), subtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl;

-- select subtime (stub function, not pushdown constraints, explain)
--Testcase 2859:
EXPLAIN VERBOSE
SELECT subtime(c3, '1 12:59:10'), subtime(c3, INTERVAL '6 months 2 hours 30 minutes'), subtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE to_hex(id) = '1';

-- select subtime (stub function, not pushdown constraints, result)
--Testcase 2860:
SELECT subtime(c3, '1 12:59:10'), subtime(c3, INTERVAL '6 months 2 hours 30 minutes'), subtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE to_hex(id) = '1';

-- select subtime (stub function, pushdown constraints, explain)
--Testcase 2861:
EXPLAIN VERBOSE
SELECT subtime(c3, '1 12:59:10'), subtime(c3, INTERVAL '6 months 2 hours 30 minutes'), subtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE id != 0;

-- select subtime (stub function, pushdown constraints, result)
--Testcase 2862:
SELECT subtime(c3, '1 12:59:10'), subtime(c3, INTERVAL '6 months 2 hours 30 minutes'), subtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE id != 0;

-- select subtime (stub function, subtime in constraints, explain)
--Testcase 2863:
EXPLAIN VERBOSE
SELECT subtime(c3, '1 12:59:10'), subtime(c3, INTERVAL '6 months 2 hours 30 minutes'), subtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE subtime(c3, '1 12:59:10') != '2000-01-01';

-- select subtime (stub function, subtime in constraints, result)
--Testcase 2864:
SELECT subtime(c3, '1 12:59:10'), subtime(c3, INTERVAL '6 months 2 hours 30 minutes'), subtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE subtime(c3, '1 12:59:10') != '2000-01-01';

-- select subtime (stub function, subtime in constraints, explain)
--Testcase 2865:
EXPLAIN VERBOSE
SELECT subtime(c3, '1 12:59:10'), subtime(c3, INTERVAL '6 months 2 hours 30 minutes'), subtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') > '-902:00:49'::interval;

-- select subtime (stub function, subtime in constraints, result)
--Testcase 2866:
SELECT subtime(c3, '1 12:59:10'), subtime(c3, INTERVAL '6 months 2 hours 30 minutes'), subtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') > '-902:00:49'::interval;

-- select subtime with agg (pushdown, explain)
--Testcase 2867:
EXPLAIN VERBOSE
SELECT max(c1), subtime(max(c1), '1 12:59:10'::interval) FROM time_tbl;

-- select subtime as nest function with agg (pushdown, result)
--Testcase 2868:
SELECT max(c1), subtime(max(c1), '1 12:59:10'::interval) FROM time_tbl;

-- select subtime as nest with stub (pushdown, explain)
--Testcase 2869:
EXPLAIN VERBOSE
SELECT subtime(mysql_timestamp(c2), '1 12:59:10'::interval) FROM time_tbl;

-- select subtime as nest with stub (pushdown, result)
--Testcase 2870:
SELECT subtime(mysql_timestamp(c2), '1 12:59:10'::interval) FROM time_tbl;

-- select subtime with non pushdown func and explicit constant (explain)
--Testcase 2871:
EXPLAIN VERBOSE
SELECT subtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), pi(), 4.1 FROM time_tbl;

-- select subtime with non pushdown func and explicit constant (result)
--Testcase 2872:
SELECT subtime(timediff(c3, '2008-01-01 00:00:00.000001'), INTERVAL '6 months 2 hours 30 minutes'), pi(), 4.1 FROM time_tbl;

-- select subtime with order by (explain)
--Testcase 2873:
EXPLAIN VERBOSE
SELECT id, subtime(c1, c1 + '1 12:59:10') FROM time_tbl order by subtime(c1, c1 + '1 12:59:10');

-- select subtime with order by (result)
--Testcase 2874:
SELECT id, subtime(c1, c1 + '1 12:59:10') FROM time_tbl order by subtime(c1, c1 + '1 12:59:10');

-- select subtime with order by index (result)
--Testcase 2875:
SELECT id, subtime(c1, c1 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select subtime with order by index (result)
--Testcase 2876:
SELECT id, subtime(c1, c1 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select subtime with group by (explain)
--Testcase 2877:
EXPLAIN VERBOSE
SELECT count(id), subtime(c1, c1 + '1 12:59:10') FROM time_tbl group by subtime(c1, c1 + '1 12:59:10');

-- select subtime with group by (result)
--Testcase 2878:
SELECT count(id), subtime(c1, c1 + '1 12:59:10') FROM time_tbl group by subtime(c1, c1 + '1 12:59:10');

-- select subtime with group by index (result)
--Testcase 2879:
SELECT id, subtime(c1, c1 + '1 12:59:10') FROM time_tbl group by 2,1;

-- select subtime with group by index (result)
--Testcase 2880:
SELECT id, subtime(c1, c1 + '1 12:59:10') FROM time_tbl group by 1,2;

-- select subtime with group by having (explain)
--Testcase 2881:
EXPLAIN VERBOSE
SELECT count(id), subtime(c3, '1 12:59:10') FROM time_tbl group by subtime(c3, '1 12:59:10'), c3 HAVING subtime(c3, '1 12:59:10') < '2080-01-01'::timestamp;

-- select subtime with group by having (result)
--Testcase 2882:
SELECT count(id), subtime(c3, '1 12:59:10') FROM time_tbl group by subtime(c3, '1 12:59:10'), c3 HAVING subtime(c3, '1 12:59:10') < '2080-01-01'::timestamp;

-- select subtime and as
--Testcase 2883:
SELECT subtime(c3, '1 12:59:10') as subtime1, subtime(c3, INTERVAL '6 months 2 hours 30 minutes') as subtime2, subtime(timediff(c3, '2008-01-01 00:00:00.000001') , INTERVAL '6 months 2 hours 30 minutes') as subtime3, subtime('1 12:59:10', INTERVAL '6 months 2 hours 30 minutes') as subtime4 FROM time_tbl;



-- SUBDATE()
-- select subdate (stub function, explain)
--Testcase 2884:
EXPLAIN VERBOSE
SELECT subdate(c2, '1 12:59:10'), subdate(c3, INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl;

-- select subdate (stub function, result)
--Testcase 2885:
SELECT subdate(c2, '1 12:59:10'), subdate(c3, INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl;

-- select subdate (stub function, not pushdown constraints, explain)
--Testcase 2886:
EXPLAIN VERBOSE
SELECT subdate(c2, '1 12:59:10'), subdate(c3, INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE to_hex(id) = '1';

-- select subdate (stub function, not pushdown constraints, result)
--Testcase 2887:
SELECT subdate(c2, '1 12:59:10'), subdate(c3, INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE to_hex(id) = '1';

-- select subdate (stub function, pushdown constraints, explain)
--Testcase 2888:
EXPLAIN VERBOSE
SELECT subdate(c2, '1 12:59:10'), subdate(c3, INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE id != 0;

-- select subdate (stub function, pushdown constraints, result)
--Testcase 2889:
SELECT subdate(c2, '1 12:59:10'), subdate(c3, INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE id != 0;

-- select subdate (stub function, subdate in constraints, explain)
--Testcase 2890:
EXPLAIN VERBOSE
SELECT subdate(c2, '1 12:59:10'), subdate(c3, INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE subdate(c3, '1 12:59:10') != '2000-01-01';

-- select subdate (stub function, subdate in constraints, result)
--Testcase 2891:
SELECT subdate(c2, '1 12:59:10'), subdate(c3, INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE subdate(c3, '1 12:59:10') != '2000-01-01';

-- select subdate (stub function, subdate in constraints, explain)
--Testcase 2892:
EXPLAIN VERBOSE
SELECT subdate(c2, '1 12:59:10'), subdate(c3, INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE subdate(c2, INTERVAL '6 months 2 hours 30 minutes') > '2008-01-01 00:00:00.000001'::timestamp;

-- select subdate (stub function, subdate in constraints, result)
--Testcase 2893:
SELECT subdate(c2, '1 12:59:10'), subdate(c3, INTERVAL '6 months 2 hours 30 minutes') FROM time_tbl WHERE subdate(c2, INTERVAL '6 months 2 hours 30 minutes') > '2008-01-01 00:00:00.000001'::timestamp;

-- select subdate with agg (pushdown, explain)
--Testcase 2894:
EXPLAIN VERBOSE
SELECT max(c1), subdate(max(c3), '1 12:59:10'::interval) FROM time_tbl;

-- select subdate as nest function with agg (pushdown, result)
--Testcase 2895:
SELECT max(c1), subdate(max(c3), '1 12:59:10'::interval) FROM time_tbl;

-- select subdate as nest with stub (pushdown, explain)
--Testcase 2896:
EXPLAIN VERBOSE
SELECT subdate(adddate(c3, INTERVAL '6 months 2 hours 30 minutes'), '1 12:59:10'::interval) FROM time_tbl;

-- select subdate as nest with stub (pushdown, result)
--Testcase 2897:
SELECT subdate(adddate(c3, INTERVAL '6 months 2 hours 30 minutes'), '1 12:59:10'::interval) FROM time_tbl;

-- select subdate with non pushdown func and explicit constant (explain)
--Testcase 2898:
EXPLAIN VERBOSE
SELECT subdate(adddate(c3, INTERVAL '6 months 2 hours 30 minutes'), INTERVAL '6 months 2 hours 30 minutes'), pi(), 4.1 FROM time_tbl;

-- select subdate with non pushdown func and explicit constant (result)
--Testcase 2899:
SELECT subdate(adddate(c3, INTERVAL '6 months 2 hours 30 minutes'), INTERVAL '6 months 2 hours 30 minutes'), pi(), 4.1 FROM time_tbl;

-- select subdate with order by (explain)
--Testcase 2900:
EXPLAIN VERBOSE
SELECT id, subdate(c3, '1 12:59:10'::interval) FROM time_tbl order by subdate(c3, '1 12:59:10'::interval);

-- select subdate with order by (result)
--Testcase 2901:
SELECT id, subdate(c3, '1 12:59:10'::interval) FROM time_tbl order by subdate(c3, '1 12:59:10'::interval);

-- select subdate with order by index (result)
--Testcase 2902:
SELECT id, subdate(c3, '1 12:59:10'::interval) FROM time_tbl order by 2,1;

-- select subdate with order by index (result)
--Testcase 2903:
SELECT id, subdate(c3, '1 12:59:10'::interval) FROM time_tbl order by 1,2;

-- select subdate with group by (explain)
--Testcase 2904:
EXPLAIN VERBOSE
SELECT count(id), subdate(c3, '1 12:59:10'::interval) FROM time_tbl group by subdate(c3, '1 12:59:10'::interval);

-- select subdate with group by (result)
--Testcase 2905:
SELECT count(id), subdate(c3, '1 12:59:10'::interval) FROM time_tbl group by subdate(c3, '1 12:59:10'::interval);

-- select subdate with group by index (result)
--Testcase 2906:
SELECT id, subdate(c3, '1 12:59:10'::interval) FROM time_tbl group by 2,1;

-- select subdate with group by index (result)
--Testcase 2907:
SELECT id, subdate(c3, '1 12:59:10'::interval) FROM time_tbl group by 1,2;

-- select subdate with group by having (explain)
--Testcase 2908:
EXPLAIN VERBOSE
SELECT count(id), subdate(c3, '1 12:59:10') FROM time_tbl group by subdate(c3, '1 12:59:10'), c3 HAVING subdate(c3, '1 12:59:10') < '2080-01-01'::timestamp;

-- select subdate with group by having (result)
--Testcase 2909:
SELECT count(id), subdate(c3, '1 12:59:10') FROM time_tbl group by subdate(c3, '1 12:59:10'), c3 HAVING subdate(c3, '1 12:59:10') < '2080-01-01'::timestamp;

-- select subdate and as
--Testcase 2910:
SELECT subdate(c3, '1 12:59:10') as subdate1, subdate(c3, INTERVAL '6 months 2 hours 30 minutes') as subdate2 FROM time_tbl;

-- STR_TO_DATE()
-- select str_to_date (stub function, explain)
--Testcase 2911:
EXPLAIN VERBOSE
SELECT str_to_date(c1, '%H:%i:%s'), str_to_date(c2, '%Y-%m-%d'), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl;
-- select str_to_date (stub function, explain)
--Testcase 2912:
SELECT str_to_date(c1, '%H:%i:%s'), str_to_date(c2, '%Y-%m-%d'), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl;

-- select str_to_date (stub function, not pushdown constraints, explain)
--Testcase 2913:
EXPLAIN VERBOSE
SELECT str_to_date(c1, '%H:%i:%s'), str_to_date(c2, '%Y-%m-%d'), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl WHERE to_hex(id) = '1';
-- select str_to_date (stub function, not pushdown constraints, result)
--Testcase 2914:
SELECT str_to_date(c1, '%H:%i:%s'), str_to_date(c2, '%Y-%m-%d'), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl WHERE to_hex(id) = '1';

-- select str_to_date (stub function, pushdown constraints, explain)
--Testcase 2915:
EXPLAIN VERBOSE
SELECT str_to_date(c1, '%H:%i:%s'), str_to_date(c2, '%Y-%m-%d'), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl WHERE id != 200;
-- select str_to_date (stub function, pushdown constraints, result)
--Testcase 2916:
SELECT str_to_date(c1, '%H:%i:%s'), str_to_date(c2, '%Y-%m-%d'), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl WHERE id != 200;

-- select str_to_date (stub function, year in constraints, explain)
--Testcase 2917:
EXPLAIN VERBOSE
SELECT str_to_date(c1, '%H:%i:%s'), str_to_date(c2, '%Y-%m-%d'), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl WHERE str_to_date(c1, '%H:%i:%s') > '02:00:00'::time;
-- select str_to_date (stub function, year in constraints, result)
--Testcase 2918:
SELECT str_to_date(c1, '%H:%i:%s'), str_to_date(c2, '%Y-%m-%d'), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl WHERE str_to_date(c1, '%H:%i:%s') > '02:00:00'::time;

-- select str_to_date with agg (pushdown, explain)
--Testcase 2919:
EXPLAIN VERBOSE
SELECT max(c3), str_to_date(max(c1), '%H:%i:%s') FROM time_tbl;
-- select str_to_date as nest function with agg (pushdown, result)
--Testcase 2920:
SELECT max(c3), str_to_date(max(c1), '%H:%i:%s') FROM time_tbl;

-- select str_to_date with non pushdown func and explicit constant (explain)
--Testcase 2921:
EXPLAIN VERBOSE
SELECT str_to_date(c1, '%H:%i:%s'), str_to_date(c2, '%Y-%m-%d'), str_to_date(c3, '%Y-%m-%d %H:%i:%s'), pi(), 4.1 FROM time_tbl;
-- -- select str_to_date with non pushdown func and explicit constant (result)
--Testcase 2922:
SELECT str_to_date(c1, '%H:%i:%s'), str_to_date(c2, '%Y-%m-%d'), str_to_date(c3, '%Y-%m-%d %H:%i:%s'), pi(), 4.1 FROM time_tbl;

-- select str_to_date with order by (explain)
--Testcase 2923:
EXPLAIN VERBOSE
SELECT id, str_to_date(c1, '%H:%i:%s'), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl order by str_to_date(c1, '%H:%i:%s'), str_to_date(c3, '%Y-%m-%d %H:%i:%s');
-- select str_to_date with order by (result)
--Testcase 2924:
SELECT id, str_to_date(c1, '%H:%i:%s'), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl order by str_to_date(c1, '%H:%i:%s'), str_to_date(c3, '%Y-%m-%d %H:%i:%s');

-- select str_to_date with order by index (result)
--Testcase 2925:
SELECT id, str_to_date(c1, '%H:%i:%s'), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl order by 3,2,1;
-- select str_to_date with order by index (result)
--Testcase 2926:
SELECT id, str_to_date(c1, '%H:%i:%s'), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl order by 1,2,3;

-- select str_to_date with group by (explain)
--Testcase 2927:
EXPLAIN VERBOSE
SELECT max(c1), str_to_date(c1, '%H:%i:%s') FROM time_tbl group by str_to_date(c1, '%H:%i:%s');
-- select str_to_date with group by (result)
--Testcase 2928:
SELECT max(c3), str_to_date(c1, '%H:%i:%s') FROM time_tbl group by str_to_date(c1, '%H:%i:%s');

-- select str_to_date with group by index (result)
--Testcase 2929:
SELECT id, str_to_date(c1, '%H:%i:%s') FROM time_tbl group by 2,1;

-- select str_to_date with group by index (result)
--Testcase 2930:
SELECT id, str_to_date(c1, '%H:%i:%s') FROM time_tbl group by 1,2;

-- select str_to_date with group by having (explain)
--Testcase 2931:
EXPLAIN VERBOSE
SELECT max(c3), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl group by str_to_date(c3, '%Y-%m-%d %H:%i:%s'),c3 HAVING str_to_date(c3, '%Y-%m-%d %H:%i:%s') < '2021-01-03 13:00:00'::timestamp;
-- select str_to_date with group by having (result)
--Testcase 2932:
SELECT max(c3), str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl group by str_to_date(c3, '%Y-%m-%d %H:%i:%s'),c3 HAVING str_to_date(c3, '%Y-%m-%d %H:%i:%s') < '2021-01-03 13:00:00'::timestamp;

-- select str_to_date with group by index having (result)
--Testcase 2933:
SELECT id, str_to_date(c3, '%Y-%m-%d %H:%i:%s') FROM time_tbl group by 1, 2 HAVING id > 1;

-- SECOND()
-- select second (stub function, explain)
--Testcase 2934:
EXPLAIN VERBOSE
SELECT second(c1), second(c3) FROM time_tbl;
--Testcase 2935:
SELECT second(c1), second(c3) FROM time_tbl;

-- select second (stub function, not pushdown constraints, explain)
--Testcase 2936:
EXPLAIN VERBOSE
SELECT second(c1), second(c3) FROM time_tbl WHERE to_hex(id) > '0';
--Testcase 2937:
SELECT second(c1), second(c3) FROM time_tbl WHERE to_hex(id) > '0';

-- select second (stub function, pushdown constraints, explain)
--Testcase 2938:
EXPLAIN VERBOSE
SELECT second(c1), second(c3) FROM time_tbl WHERE id = 1;
--Testcase 2939:
SELECT second(c1), second(c3) FROM time_tbl WHERE id = 1;

-- select second (stub function, second in constraints, explain)
--Testcase 2940:
EXPLAIN VERBOSE
SELECT second(c1), second(c3) FROM time_tbl WHERE second(c2) < second(c3);
--Testcase 2941:
SELECT second(c1), second(c3) FROM time_tbl WHERE second(c2) < second(c3);

-- second in constrains (stub function, explain)
--Testcase 2942:
EXPLAIN VERBOSE
SELECT second(c1), second(c3) FROM time_tbl WHERE second(c2) < id;

-- second in constrains (stub function, result)
--Testcase 2943:
SELECT second(c1), second(c3) FROM time_tbl WHERE second(c2) < id;

-- select second as nest function with agg (pushdown, explain)
--Testcase 2944:
EXPLAIN VERBOSE
SELECT max(c1), second(max(c3)) FROM time_tbl;

-- select second as nest function with agg (pushdown, result)
--Testcase 2945:
SELECT max(c1), second(max(c3)) FROM time_tbl;

-- select second and agg (pushdown, explain)
--Testcase 2946:
EXPLAIN VERBOSE
SELECT second('1997-10-14 00:01:01'::timestamp), second('00:01:59'::time), sum(id) FROM time_tbl;

-- select second and log2 (pushdown, explain)
--Testcase 2947:
EXPLAIN VERBOSE
SELECT second('1997-10-14 00:01:01'::timestamp), second('00:01:59'::time), log2(id) FROM time_tbl;

-- select second with non pushdown func and explicit constant (explain)
--Testcase 2948:
EXPLAIN VERBOSE
SELECT second('1997-10-14 00:00:00'::timestamp), second('00:01:59'::time), to_hex(id), 4 FROM time_tbl;

-- select second with order by (explain)
--Testcase 2949:
EXPLAIN VERBOSE
SELECT second(c1), second(c3), c1 FROM time_tbl ORDER BY c1;

-- select second with order by index (result)
--Testcase 2950:
SELECT second(c1), second(c3), c1 FROM time_tbl ORDER BY 1,2;

-- second constraints with order by (explain)
--Testcase 2951:
EXPLAIN VERBOSE
SELECT second(c1), second(c3) FROM time_tbl WHERE second('2020-10-14 00:39:05'::timestamp) > second('1997-10-14 00:00:00'::timestamp) ORDER BY second(c1), second(c3);

-- second constraints with order by (result)
--Testcase 2952:
SELECT second(c1), second(c3) FROM time_tbl WHERE second('2020-10-14 00:39:05'::timestamp) > second('1997-10-14 00:00:00'::timestamp) ORDER BY second(c1), second(c3);

-- select second with group by (explain)
--Testcase 2953:
EXPLAIN VERBOSE
SELECT second(c1), second(c3), c1 FROM time_tbl GROUP BY c1,c3;

-- select second with group by index (explain)
--Testcase 2954:
EXPLAIN VERBOSE
SELECT second(c1), second(c3), c1 FROM time_tbl GROUP BY 1,2,3;

-- select second with group by having (explain)
--Testcase 2955:
EXPLAIN VERBOSE
SELECT second(c1), c1 FROM time_tbl GROUP BY second(c1),c1 HAVING second(c1) > 1;

-- select second with group by index having (result)
--Testcase 2956:
SELECT second(c1), c1 FROM time_tbl GROUP BY second(c1),c1 HAVING second(c1) > 1;

-- select second and as
--Testcase 2957:
EXPLAIN VERBOSE
SELECT second(c1) as second1, second(c3) as second2 FROM time_tbl;



-- SEC_TO_TIME()
-- select sec_to_time (stub function, explain)
--Testcase 2958:
EXPLAIN VERBOSE
SELECT sec_to_time(id) FROM time_tbl;
--Testcase 2959:
SELECT sec_to_time(id) FROM time_tbl;

-- select sec_to_time (stub function, not pushdown constraints, explain)
--Testcase 2960:
EXPLAIN VERBOSE
SELECT sec_to_time(id) FROM time_tbl WHERE to_hex(id) > '0';
--Testcase 2961:
SELECT sec_to_time(id) FROM time_tbl WHERE to_hex(id) > '0';

-- select sec_to_time (stub function, pushdown constraints, explain)
--Testcase 2962:
EXPLAIN VERBOSE
SELECT sec_to_time(id) FROM time_tbl WHERE id = 1;
--Testcase 2963:
SELECT sec_to_time(id) FROM time_tbl WHERE id = 1;

-- select sec_to_time (stub function, sec_to_time in constraints, explain)
--Testcase 2964:
EXPLAIN VERBOSE
SELECT sec_to_time(id) FROM time_tbl WHERE sec_to_time(id) < c1;
--Testcase 2965:
SELECT sec_to_time(id) FROM time_tbl WHERE sec_to_time(id) < c1;

-- sec_to_time in constrains (stub function, explain)
--Testcase 2966:
EXPLAIN VERBOSE
SELECT sec_to_time(id) FROM time_tbl WHERE sec_to_time(id) < c1;

-- sec_to_time in constrains (stub function, result)
--Testcase 2967:
SELECT sec_to_time(id) FROM time_tbl WHERE sec_to_time(id) < c1;

-- select sec_to_time as nest function with agg (pushdown, explain)
--Testcase 2968:
EXPLAIN VERBOSE
SELECT max(c1), sec_to_time(max(id)) FROM time_tbl;

-- select sec_to_time as nest function with agg (pushdown, result)
--Testcase 2969:
SELECT max(c1), sec_to_time(max(id)) FROM time_tbl;

-- select sec_to_time and agg (pushdown, explain)
--Testcase 2970:
EXPLAIN VERBOSE
SELECT max(id), sec_to_time(max(id)) FROM time_tbl;

-- select sec_to_time and log2 (pushdown, explain)
--Testcase 2971:
EXPLAIN VERBOSE
SELECT sec_to_time(id), log2(id) FROM time_tbl;

-- select sec_to_time with non pushdown func and explicit constant (explain)
--Testcase 2972:
EXPLAIN VERBOSE
SELECT sec_to_time(id), to_hex(id), 4 FROM time_tbl;

-- select sec_to_time with order by (explain)
--Testcase 2973:
EXPLAIN VERBOSE
SELECT sec_to_time(id), c1 FROM time_tbl ORDER BY sec_to_time(id);

-- select sec_to_time with order by index (result)
--Testcase 2974:
SELECT sec_to_time(id), c1 FROM time_tbl ORDER BY 1;

-- sec_to_time constraints with order by (explain)
--Testcase 2975:
EXPLAIN VERBOSE
SELECT sec_to_time(id) FROM time_tbl WHERE sec_to_time(id) < c1 ORDER BY 1;

-- sec_to_time constraints with order by (result)
--Testcase 2976:
SELECT sec_to_time(id) FROM time_tbl WHERE sec_to_time(id) < c1 ORDER BY sec_to_time(id);

-- select sec_to_time with group by (explain)
--Testcase 2977:
EXPLAIN VERBOSE
SELECT sec_to_time(id), c1 FROM time_tbl GROUP BY id,c1;

-- select sec_to_time with group by index (explain)
--Testcase 2978:
EXPLAIN VERBOSE
SELECT sec_to_time(id), c1 FROM time_tbl GROUP BY 1,2;

-- select sec_to_time with group by having (explain)
--Testcase 2979:
EXPLAIN VERBOSE
SELECT sec_to_time(id), c1 FROM time_tbl GROUP BY sec_to_time(id), id, c1 HAVING sec_to_time(id) < c1;

-- select sec_to_time with group by index having (result)
--Testcase 2980:
SELECT sec_to_time(id), c1 FROM time_tbl GROUP BY sec_to_time(id), id, c1 HAVING sec_to_time(id) < c1;

-- select sec_to_time and as
--Testcase 2981:
EXPLAIN VERBOSE
SELECT sec_to_time(id) as sec_to_time1 FROM time_tbl;


-- QUARTER()
-- select quarter (stub function, explain)
--Testcase 2982:
EXPLAIN VERBOSE
SELECT quarter(c3), quarter(c2), quarter(date_sub(c3, '1 12:59:10')), quarter('2021-01-01 12:00:00'::timestamp) FROM time_tbl;

-- select quarter (stub function, result)
--Testcase 2983:
SELECT quarter(c3), quarter(c2), quarter(date_sub(c3, '1 12:59:10')), quarter('2021-01-01 12:00:00'::timestamp) FROM time_tbl;

-- select quarter (stub function, not pushdown constraints, explain)
--Testcase 2984:
EXPLAIN VERBOSE
SELECT quarter(c3), quarter(c2), quarter(date_sub(c3, '1 12:59:10')), quarter('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select quarter (stub function, not pushdown constraints, result)
--Testcase 2985:
SELECT quarter(c3), quarter(c2), quarter(date_sub(c3, '1 12:59:10')), quarter('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select quarter (stub function, pushdown constraints, explain)
--Testcase 2986:
EXPLAIN VERBOSE
SELECT quarter(c3), quarter(c2), quarter(date_sub(c3, '1 12:59:10')), quarter('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200;

-- select quarter (stub function, pushdown constraints, result)
--Testcase 2987:
SELECT quarter(c3), quarter(c2), quarter(date_sub(c3, '1 12:59:10')), quarter('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200;

-- select quarter (stub function, quarter in constraints, explain)
--Testcase 2988:
EXPLAIN VERBOSE
SELECT quarter(c3), quarter(c2), quarter(date_sub(c3, '1 12:59:10')), quarter('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE quarter(c3) = quarter('2000-01-01'::timestamp);

-- select quarter (stub function, quarter in constraints, result)
--Testcase 2989:
SELECT quarter(c3), quarter(c2), quarter(date_sub(c3, '1 12:59:10')), quarter('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE quarter(c3) = quarter('2000-01-01'::timestamp);

-- select quarter (stub function, quarter in constraints, explain)
--Testcase 2990:
EXPLAIN VERBOSE
SELECT quarter(c3), quarter(c2), quarter(date_sub(c3, '1 12:59:10')), quarter('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE quarter('2021-01-01 12:00:00'::timestamp) = '1';

-- select quarter (stub function, quarter in constraints, result)
--Testcase 2991:
SELECT quarter(c3), quarter(c2), quarter(date_sub(c3, '1 12:59:10')), quarter('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE quarter('2021-01-01 12:00:00'::timestamp) = '1';

-- select quarter with agg (pushdown, explain)
--Testcase 2992:
EXPLAIN VERBOSE
SELECT max(c3), quarter(max(c3)) FROM time_tbl;

-- select quarter as nest function with agg (pushdown, result)
--Testcase 2993:
SELECT max(c3), quarter(max(c3)) FROM time_tbl;

-- select quarter with non pushdown func and explicit constant (explain)
--Testcase 2994:
EXPLAIN VERBOSE
SELECT quarter(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl;

-- select quarter with non pushdown func and explicit constant (result)
--Testcase 2995:
SELECT quarter(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl;

-- select quarter with order by (explain)
--Testcase 2996:
EXPLAIN VERBOSE
SELECT id, quarter(c3 + '1 12:59:10') FROM time_tbl order by quarter(c3 + '1 12:59:10');

-- select quarter with order by (result)
--Testcase 2997:
SELECT id, quarter(c3 + '1 12:59:10') FROM time_tbl order by quarter(c3 + '1 12:59:10');

-- select quarter with order by index (result)
--Testcase 2998:
SELECT id, quarter(c3 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select quarter with order by index (result)
--Testcase 2999:
SELECT id, quarter(c3 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select quarter with group by (explain)
--Testcase 3000:
EXPLAIN VERBOSE
SELECT max(c3), quarter(c3 + '1 12:59:10') FROM time_tbl group by quarter(c3 + '1 12:59:10');

-- select quarter with group by (result)
--Testcase 3001:
SELECT max(c3), quarter(c3 + '1 12:59:10') FROM time_tbl group by quarter(c3 + '1 12:59:10');

-- select quarter with group by index (result)
--Testcase 3002:
SELECT id, quarter(c3 + '1 12:59:10') FROM time_tbl group by 2,1;

-- select quarter with group by index (result)
--Testcase 3003:
SELECT id, quarter(c3 + '1 12:59:10') FROM time_tbl group by 1,2;

-- select quarter with group by having (explain)
--Testcase 3004:
EXPLAIN VERBOSE
SELECT max(c3), quarter(c3 + '1 12:59:10') FROM time_tbl group by quarter(c3 + '1 12:59:10'), c3 HAVING quarter(c3 + '1 12:59:10') > '0';

-- select quarter with group by having (result)
--Testcase 3005:
SELECT max(c3), quarter(c3 + '1 12:59:10') FROM time_tbl group by quarter(c3 + '1 12:59:10'), c3 HAVING quarter(c3 + '1 12:59:10') > '0';

-- select quarter with group by index having (result)
--Testcase 3006:
SELECT id, quarter(c3 + '1 12:59:10'), c3 FROM time_tbl group by 3, 2, 1 HAVING quarter(c3 + '1 12:59:10') > '0';

-- select quarter with group by index having (result)
--Testcase 3007:
SELECT id, quarter(c3 + '1 12:59:10'), c3 FROM time_tbl group by 1, 2, 3 HAVING quarter(c3 + '1 12:59:10') > '0';

-- select quarter and as
--Testcase 3008:
SELECT quarter(date_sub(c3, '1 12:59:10')) as quarter1 FROM time_tbl;



-- PERIOD_DIFF()
-- select period_diff (stub function, explain)
--Testcase 3009:
EXPLAIN VERBOSE
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl;

-- select period_diff (stub function, result)
--Testcase 3010:
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl;

-- select period_diff (stub function, not pushdown constraints, explain)
--Testcase 3011:
EXPLAIN VERBOSE
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl WHERE to_hex(id) = '1';

-- select period_diff (stub function, not pushdown constraints, result)
--Testcase 3012:
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl WHERE to_hex(id) = '1';

-- select period_diff (stub function, pushdown constraints, explain)
--Testcase 3013:
EXPLAIN VERBOSE
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl WHERE id != 200;

-- select period_diff (stub function, pushdown constraints, result)
--Testcase 3014:
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl WHERE id != 200;

-- select period_diff (stub function, period_diff in constraints, explain)
--Testcase 3015:
EXPLAIN VERBOSE
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl WHERE period_diff(mysql_extract('YEAR_MONTH', c3 ), 199710) > id;

-- select period_diff (stub function, period_diff in constraints, result)
--Testcase 3016:
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl WHERE period_diff(mysql_extract('YEAR_MONTH', c3 ), 199710) > id;

-- select period_diff with agg (pushdown, explain)
--Testcase 3017:
EXPLAIN VERBOSE
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl;

-- select period_diff as nest function with agg (pushdown, result)
--Testcase 3018:
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl;

-- select period_diff with non pushdown func and explicit constant (explain)
--Testcase 3019:
EXPLAIN VERBOSE
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), pi(), 4.1 FROM time_tbl;

-- select period_diff with non pushdown func and explicit constant (result)
--Testcase 3020:
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), pi(), 4.1 FROM time_tbl;

-- select period_diff with order by (explain)
--Testcase 3021:
EXPLAIN VERBOSE
SELECT id, period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl order by period_diff(mysql_extract('YEAR_MONTH', c3 ), 199710);

-- select period_diff with order by (result)
--Testcase 3022:
SELECT id, period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl order by period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907);

-- select period_diff with order by index (result)
--Testcase 3023:
SELECT id, period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl order by 2,1;

-- select period_diff with order by index (result)
--Testcase 3024:
SELECT id, period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl order by 1,2;

-- select period_diff with group by index (result)
--Testcase 3025:
SELECT id, period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl group by 2,1;

-- select period_diff with group by index (result)
--Testcase 3026:
SELECT id, period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl group by 1,2;

-- select period_diff with group by having (explain)
--Testcase 3027:
EXPLAIN VERBOSE
SELECT max(c3), period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl group by  period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907),c3 HAVING period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) > 0;

-- select period_diff with group by having (result)
--Testcase 3028:
SELECT max(c3), period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl group by  period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907),c3 HAVING period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) > 0;

-- select period_diff with group by index having (result)
--Testcase 3029:
SELECT id, c3, period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl group by 3, 2, 1 HAVING period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) > 0;

-- select period_diff with group by index having (result)
--Testcase 3030:
SELECT id, c3, period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl group by 1, 2, 3 HAVING period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) > 0;

-- select period_diff and as
--Testcase 3031:
SELECT period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907) as period_diff1 FROM time_tbl;



-- PERIOD_ADD()
-- select period_add (stub function, explain)
--Testcase 3032:
EXPLAIN VERBOSE
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl;

-- select period_add (stub function, result)
--Testcase 3033:
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl;

-- select period_add (stub function, not pushdown constraints, explain)
--Testcase 3034:
EXPLAIN VERBOSE
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl WHERE to_hex(id) = '1';

-- select period_add (stub function, not pushdown constraints, result)
--Testcase 3035:
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl WHERE to_hex(id) = '1';

-- select period_add (stub function, pushdown constraints, explain)
--Testcase 3036:
EXPLAIN VERBOSE
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl WHERE id != 200;

-- select period_add (stub function, pushdown constraints, result)
--Testcase 3037:
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl WHERE id != 200;

-- select period_add (stub function, period_add in constraints, explain)
--Testcase 3038:
EXPLAIN VERBOSE
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl WHERE period_add(mysql_extract('YEAR_MONTH', c3 ), 199710) > id;

-- select period_add (stub function, period_add in constraints, result)
--Testcase 3039:
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl WHERE period_add(mysql_extract('YEAR_MONTH', c3 ), 199710) > id;

-- select period_add with agg (pushdown, explain)
--Testcase 3040:
EXPLAIN VERBOSE
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl;

-- select period_add as nest function with agg (pushdown, result)
--Testcase 3041:
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl;

-- select period_add with non pushdown func and explicit constant (explain)
--Testcase 3042:
EXPLAIN VERBOSE
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907), pi(), 4.1 FROM time_tbl;

-- select period_add with non pushdown func and explicit constant (result)
--Testcase 3043:
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907), pi(), 4.1 FROM time_tbl;

-- select period_add with order by (explain)
--Testcase 3044:
EXPLAIN VERBOSE
SELECT id, period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl order by period_add(mysql_extract('YEAR_MONTH', c3 ), 199710);

-- select period_add with order by (result)
--Testcase 3045:
SELECT id, period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl order by period_add(mysql_extract('YEAR_MONTH', c3 ), 201907);

-- select period_add with order by index (result)
--Testcase 3046:
SELECT id, period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl order by 2,1;

-- select period_add with order by index (result)
--Testcase 3047:
SELECT id, period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl order by 1,2;

-- select period_add with group by index (result)
--Testcase 3048:
SELECT id, period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl group by 2,1;

-- select period_add with group by index (result)
--Testcase 3049:
SELECT id, period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl group by 1,2;

-- select period_add with group by having (explain)
--Testcase 3050:
EXPLAIN VERBOSE
SELECT max(c3), period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl group by period_add(mysql_extract('YEAR_MONTH', c3 ), 201907),c3 HAVING period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) > 0;

-- select period_add with group by having (result)
--Testcase 3051:
SELECT max(c3), period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl group by period_add(mysql_extract('YEAR_MONTH', c3 ), 201907),c3 HAVING period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) > 0;
-- select period_add with group by index having (result)
--Testcase 3052:
SELECT id, c3, period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl group by 3, 2, 1 HAVING period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) > 0;

-- select period_add with group by index having (result)
--Testcase 3053:
SELECT id, c3, period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) FROM time_tbl group by 1, 2, 3 HAVING period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) > 0;

-- select period_add and as
--Testcase 3054:
SELECT period_add(mysql_extract('YEAR_MONTH', c3 ), 201907) as period_add1 FROM time_tbl;



-- NOW()
-- mysql_now is mutable function, some executes will return different result
-- select mysql_now (stub function, explain)
--Testcase 3055:
EXPLAIN VERBOSE
SELECT mysql_now() FROM time_tbl;

-- select mysql_now (stub function, not pushdown constraints, explain)
--Testcase 3056:
EXPLAIN VERBOSE
SELECT mysql_now() FROM time_tbl WHERE to_hex(id) > '0';

-- select mysql_now (stub function, pushdown constraints, explain)
--Testcase 3057:
EXPLAIN VERBOSE
SELECT mysql_now() FROM time_tbl WHERE id = 1;

-- select mysql_now (stub function, mysql_now in constraints, explain)
--Testcase 3058:
EXPLAIN VERBOSE
SELECT mysql_now() FROM time_tbl WHERE mysql_now() > '2000-01-01 00:00:00'::timestamp;

-- mysql_now in constrains (stub function, explain)
--Testcase 3059:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE mysql_now() > '2000-01-01 00:00:00'::timestamp;

-- mysql_now in constrains (stub function, result)
--Testcase 3060:
SELECT c1 FROM time_tbl WHERE mysql_now() > '2000-01-01 00:00:00'::timestamp;

-- mysql_now as parameter of addtime(stub function, explain)
--Testcase 3061:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_now(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp;

-- mysql_now as parameter of addtime(stub function, result)
--Testcase 3062:
SELECT c1 FROM time_tbl WHERE addtime(mysql_now(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp;

-- select mysql_now and agg (pushdown, explain)
--Testcase 3063:
EXPLAIN VERBOSE
SELECT mysql_now(), sum(id) FROM time_tbl;

-- select mysql_now and log2 (pushdown, explain)
--Testcase 3064:
EXPLAIN VERBOSE
SELECT mysql_now(), log2(id) FROM time_tbl;

-- select mysql_now with non pushdown func and explicit constant (explain)
--Testcase 3065:
EXPLAIN VERBOSE
SELECT mysql_now(), to_hex(id), 4 FROM time_tbl;

-- select mysql_now with order by (explain)
--Testcase 3066:
EXPLAIN VERBOSE
SELECT mysql_now(), c1 FROM time_tbl ORDER BY mysql_now();

-- select mysql_now with order by index (explain)
--Testcase 3067:
EXPLAIN VERBOSE
SELECT mysql_now(), c1 FROM time_tbl ORDER BY 1;

-- mysql_now constraints with order by (explain)
--Testcase 3068:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_now(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp ORDER BY c1;

-- mysql_now constraints with order by (result)
--Testcase 3069:
SELECT c1 FROM time_tbl WHERE addtime(mysql_now(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp ORDER BY c1;

-- select mysql_now with group by (explain)
--Testcase 3070:
EXPLAIN VERBOSE
SELECT mysql_now(), c1 FROM time_tbl GROUP BY c1;

-- select mysql_now with group by index (explain)
--Testcase 3071:
EXPLAIN VERBOSE
SELECT mysql_now(), c1 FROM time_tbl GROUP BY 2;

-- select mysql_now with group by having (explain)
--Testcase 3072:
EXPLAIN VERBOSE
SELECT mysql_now(), c1 FROM time_tbl GROUP BY mysql_now(),c1 HAVING mysql_now() > '2000-01-01 00:00:00'::timestamp;

-- select mysql_now with group by index having (explain)
--Testcase 3073:
EXPLAIN VERBOSE
SELECT mysql_now(), c1 FROM time_tbl GROUP BY 2,1 HAVING mysql_now() > '2000-01-01 00:00:00'::timestamp;

-- mysql_now constraints with group by (explain)
--Testcase 3074:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_now(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp GROUP BY c1;

-- mysql_now constraints with group by (result)
--Testcase 3075:
SELECT c1 FROM time_tbl WHERE addtime(mysql_now(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp GROUP BY c1;

-- select mysql_now and as
--Testcase 3076:
EXPLAIN VERBOSE
SELECT mysql_now() as mysql_now1 FROM time_tbl;



-- MONTHNAME()
-- select monthname (stub function, explain)
--Testcase 3077:
EXPLAIN VERBOSE
SELECT monthname(c3), monthname(c2), monthname(date_sub(c3, '1 12:59:10')), monthname('2021-01-01 12:00:00'::timestamp) FROM time_tbl;

-- select monthname (stub function, result)
--Testcase 3078:
SELECT monthname(c3), monthname(c2), monthname(date_sub(c3, '1 12:59:10')), monthname('2021-01-01 12:00:00'::timestamp) FROM time_tbl;

-- select monthname (stub function, not pushdown constraints, explain)
--Testcase 3079:
EXPLAIN VERBOSE
SELECT monthname(c3), monthname(c2), monthname(date_sub(c3, '1 12:59:10')), monthname('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select monthname (stub function, not pushdown constraints, result)
--Testcase 3080:
SELECT monthname(c3), monthname(c2), monthname(date_sub(c3, '1 12:59:10')), monthname('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select monthname (stub function, pushdown constraints, explain)
--Testcase 3081:
EXPLAIN VERBOSE
SELECT monthname(c3), monthname(c2), monthname(date_sub(c3, '1 12:59:10')), monthname('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200;

-- select monthname (stub function, pushdown constraints, result)
--Testcase 3082:
SELECT monthname(c3), monthname(c2), monthname(date_sub(c3, '1 12:59:10')), monthname('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200;

-- select monthname (stub function, monthname in constraints, explain)
--Testcase 3083:
EXPLAIN VERBOSE
SELECT monthname(c3), monthname(c2), monthname(date_sub(c3, '1 12:59:10')), monthname('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE monthname(c3) = monthname('2000-01-01'::timestamp);

-- select monthname (stub function, monthname in constraints, result)
--Testcase 3084:
SELECT monthname(c3), monthname(c2), monthname(date_sub(c3, '1 12:59:10')), monthname('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE monthname(c3) = monthname('2000-01-01'::timestamp);

-- select monthname (stub function, monthname in constraints, explain)
--Testcase 3085:
EXPLAIN VERBOSE
SELECT monthname(c3), monthname(c2), monthname(date_sub(c3, '1 12:59:10')), monthname('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE monthname('2021-01-01 12:00:00'::timestamp) = 'January';

-- select monthname (stub function, monthname in constraints, result)
--Testcase 3086:
SELECT monthname(c3), monthname(c2), monthname(date_sub(c3, '1 12:59:10')), monthname('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE monthname('2021-01-01 12:00:00'::timestamp) = 'January';

-- select monthname with agg (pushdown, explain)
--Testcase 3087:
EXPLAIN VERBOSE
SELECT max(c3), monthname(max(c3)) FROM time_tbl;

-- select monthname as nest function with agg (pushdown, result)
--Testcase 3088:
SELECT max(c3), monthname(max(c3)) FROM time_tbl;

-- select monthname with non pushdown func and explicit constant (explain)
--Testcase 3089:
EXPLAIN VERBOSE
SELECT monthname(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl;

-- select monthname with non pushdown func and explicit constant (result)
--Testcase 3090:
SELECT monthname(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl;

-- select monthname with order by (explain)
--Testcase 3091:
EXPLAIN VERBOSE
SELECT id, monthname(c3 + '1 12:59:10') FROM time_tbl order by monthname(c3 + '1 12:59:10');

-- select monthname with order by (result)
--Testcase 3092:
SELECT id, monthname(c3 + '1 12:59:10') FROM time_tbl order by monthname(c3 + '1 12:59:10');

-- select monthname with order by index (result)
--Testcase 3093:
SELECT id, monthname(c3 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select monthname with order by index (result)
--Testcase 3094:
SELECT id, monthname(c3 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select monthname with group by (explain)
--Testcase 3095:
EXPLAIN VERBOSE
SELECT max(c3), monthname(c3 + '1 12:59:10') FROM time_tbl group by monthname(c3 + '1 12:59:10');

-- select monthname with group by (result)
--Testcase 3096:
SELECT max(c3), monthname(c3 + '1 12:59:10') FROM time_tbl group by monthname(c3 + '1 12:59:10');

-- select monthname with group by index (result)
--Testcase 3097:
SELECT id, monthname(c3 + '1 12:59:10') FROM time_tbl group by 2,1;

-- select monthname with group by index (result)
--Testcase 3098:
SELECT id, monthname(c3 + '1 12:59:10') FROM time_tbl group by 1,2;

-- select monthname with group by having (explain)
--Testcase 3099:
EXPLAIN VERBOSE
SELECT max(c3), monthname(c3 + '1 12:59:10') FROM time_tbl group by monthname(c3 + '1 12:59:10'), c3 HAVING monthname(c3 + '1 12:59:10') = 'January';

-- select monthname with group by having (result)
--Testcase 3100:
SELECT max(c3), monthname(c3 + '1 12:59:10') FROM time_tbl group by monthname(c3 + '1 12:59:10'), c3 HAVING monthname(c3 + '1 12:59:10') = 'January';

-- select monthname with group by index having (result)
--Testcase 3101:
SELECT id, monthname(c3 + '1 12:59:10'), c3 FROM time_tbl group by 3, 2, 1 HAVING monthname(c3 + '1 12:59:10') = 'January';

-- select monthname with group by index having (result)
--Testcase 3102:
SELECT id, monthname(c3 + '1 12:59:10'), c3 FROM time_tbl group by 1, 2, 3 HAVING monthname(c3 + '1 12:59:10') = 'January';

-- select monthname and as
--Testcase 3103:
SELECT monthname(date_sub(c3, '1 12:59:10')) as monthname1 FROM time_tbl;



-- MONTH()
-- select month (stub function, explain)
--Testcase 3104:
EXPLAIN VERBOSE
SELECT month(c3), month(c2), month(date_sub(c3, '1 12:59:10')), month('2021-01-01 12:00:00'::timestamp) FROM time_tbl;

-- select month (stub function, result)
--Testcase 3105:
SELECT month(c3), month(c2), month(date_sub(c3, '1 12:59:10')), month('2021-01-01 12:00:00'::timestamp) FROM time_tbl;

-- select month (stub function, not pushdown constraints, explain)
--Testcase 3106:
EXPLAIN VERBOSE
SELECT month(c3), month(c2), month(date_sub(c3, '1 12:59:10')), month('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select month (stub function, not pushdown constraints, result)
--Testcase 3107:
SELECT month(c3), month(c2), month(date_sub(c3, '1 12:59:10')), month('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select month (stub function, pushdown constraints, explain)
--Testcase 3108:
EXPLAIN VERBOSE
SELECT month(c3), month(c2), month(date_sub(c3, '1 12:59:10')), month('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200;

-- select month (stub function, pushdown constraints, result)
--Testcase 3109:
SELECT month(c3), month(c2), month(date_sub(c3, '1 12:59:10')), month('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200;

-- select month (stub function, month in constraints, explain)
--Testcase 3110:
EXPLAIN VERBOSE
SELECT month(c3), month(c2), month(date_sub(c3, '1 12:59:10')), month('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE month(c3) = month('2000-01-01'::timestamp);

-- select month (stub function, month in constraints, result)
--Testcase 3111:
SELECT month(c3), month(c2), month(date_sub(c3, '1 12:59:10')), month('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE month(c3) = month('2000-01-01'::timestamp);

-- select month (stub function, month in constraints, explain)
--Testcase 3112:
EXPLAIN VERBOSE
SELECT month(c3), month(c2), month(date_sub(c3, '1 12:59:10')), month('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE month('2021-01-01 12:00:00'::timestamp) = '1';

-- select month (stub function, month in constraints, result)
--Testcase 3113:
SELECT month(c3), month(c2), month(date_sub(c3, '1 12:59:10')), month('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE month('2021-01-01 12:00:00'::timestamp) = '1';

-- select month with agg (pushdown, explain)
--Testcase 3114:
EXPLAIN VERBOSE
SELECT max(c3), month(max(c3)) FROM time_tbl;

-- select month as nest function with agg (pushdown, result)
--Testcase 3115:
SELECT max(c3), month(max(c3)) FROM time_tbl;

-- select month with non pushdown func and explicit constant (explain)
--Testcase 3116:
EXPLAIN VERBOSE
SELECT month(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl;

-- select month with non pushdown func and explicit constant (result)
--Testcase 3117:
SELECT month(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl;

-- select month with order by (explain)
--Testcase 3118:
EXPLAIN VERBOSE
SELECT id, month(c3 + '1 12:59:10') FROM time_tbl order by month(c3 + '1 12:59:10');

-- select month with order by (result)
--Testcase 3119:
SELECT id, month(c3 + '1 12:59:10') FROM time_tbl order by month(c3 + '1 12:59:10');

-- select month with order by index (result)
--Testcase 3120:
SELECT id, month(c3 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select month with order by index (result)
--Testcase 3121:
SELECT id, month(c3 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select month with group by (explain)
--Testcase 3122:
EXPLAIN VERBOSE
SELECT max(c3), month(c3 + '1 12:59:10') FROM time_tbl group by month(c3 + '1 12:59:10');

-- select month with group by (result)
--Testcase 3123:
SELECT max(c3), month(c3 + '1 12:59:10') FROM time_tbl group by month(c3 + '1 12:59:10');

-- select month with group by index (result)
--Testcase 3124:
SELECT id, month(c3 + '1 12:59:10') FROM time_tbl group by 2,1;

-- select month with group by index (result)
--Testcase 3125:
SELECT id, month(c3 + '1 12:59:10') FROM time_tbl group by 1,2;

-- select month with group by having (explain)
--Testcase 3126:
EXPLAIN VERBOSE
SELECT max(c3), month(c3 + '1 12:59:10') FROM time_tbl group by month(c3 + '1 12:59:10'), c3 HAVING month(c3 + '1 12:59:10') < 12;

-- select month with group by having (result)
--Testcase 3127:
SELECT max(c3), month(c3 + '1 12:59:10') FROM time_tbl group by month(c3 + '1 12:59:10'), c3 HAVING month(c3 + '1 12:59:10') < 12;

-- select month with group by index having (result)
--Testcase 3128:
SELECT id, month(c3 + '1 12:59:10'), c3 FROM time_tbl group by 3, 2, 1 HAVING month(c3 + '1 12:59:10') < 12;

-- select month with group by index having (result)
--Testcase 3129:
SELECT id, month(c3 + '1 12:59:10'), c3 FROM time_tbl group by 1, 2, 3 HAVING month(c3 + '1 12:59:10') < 12;

-- select month and as
--Testcase 3130:
SELECT month(date_sub(c3, '1 12:59:10')) as month1 FROM time_tbl;



-- MINUTE()
-- select minute (stub function, explain)
--Testcase 3131:
EXPLAIN VERBOSE
SELECT minute(c3), minute(c2), minute(date_sub(c3, '1 12:59:10')), minute('2021-01-01 12:00:00'::timestamp) FROM time_tbl;

-- select minute (stub function, result)
--Testcase 3132:
SELECT minute(c3), minute(c2), minute(date_sub(c3, '1 12:59:10')), minute('2021-01-01 12:00:00'::timestamp) FROM time_tbl;

-- select minute (stub function, not pushdown constraints, explain)
--Testcase 3133:
EXPLAIN VERBOSE
SELECT minute(c3), minute(c2), minute(date_sub(c3, '1 12:59:10')), minute('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select minute (stub function, not pushdown constraints, result)
--Testcase 3134:
SELECT minute(c3), minute(c2), minute(date_sub(c3, '1 12:59:10')), minute('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select minute (stub function, pushdown constraints, explain)
--Testcase 3135:
EXPLAIN VERBOSE
SELECT minute(c3), minute(c2), minute(date_sub(c3, '1 12:59:10')), minute('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200;

-- select minute (stub function, pushdown constraints, result)
--Testcase 3136:
SELECT minute(c3), minute(c2), minute(date_sub(c3, '1 12:59:10')), minute('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200;

-- select minute (stub function, minute in constraints, explain)
--Testcase 3137:
EXPLAIN VERBOSE
SELECT minute(c3), minute(c2), minute(date_sub(c3, '1 12:59:10')), minute('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE minute(c3) > minute('2000-01-01'::timestamp);

-- select minute (stub function, minute in constraints, result)
--Testcase 3138:
SELECT minute(c3), minute(c2), minute(date_sub(c3, '1 12:59:10')), minute('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE minute(c3) > minute('2000-01-01'::timestamp);

-- select minute (stub function, minute in constraints, explain)
--Testcase 3139:
EXPLAIN VERBOSE
SELECT minute(c3), minute(c2), minute(date_sub(c3, '1 12:59:10')), minute('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE minute('2021-01-01 12:00:00'::timestamp) < 1;

-- select minute (stub function, minute in constraints, result)
--Testcase 3140:
SELECT minute(c3), minute(c2), minute(date_sub(c3, '1 12:59:10')), minute('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE minute('2021-01-01 12:00:00'::timestamp) < 1;

-- select minute with agg (pushdown, explain)
--Testcase 3141:
EXPLAIN VERBOSE
SELECT max(c3), minute(max(c3)) FROM time_tbl;

-- select minute as nest function with agg (pushdown, result)
--Testcase 3142:
SELECT max(c3), minute(max(c3)) FROM time_tbl;

-- select minute with non pushdown func and explicit constant (explain)
--Testcase 3143:
EXPLAIN VERBOSE
SELECT minute(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl;

-- select minute with non pushdown func and explicit constant (result)
--Testcase 3144:
SELECT minute(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl;

-- select minute with order by (explain)
--Testcase 3145:
EXPLAIN VERBOSE
SELECT id, minute(c3 + '1 12:59:10') FROM time_tbl order by minute(c3 + '1 12:59:10');

-- select minute with order by (result)
--Testcase 3146:
SELECT id, minute(c3 + '1 12:59:10') FROM time_tbl order by minute(c3 + '1 12:59:10');

-- select minute with order by index (result)
--Testcase 3147:
SELECT id, minute(c3 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select minute with order by index (result)
--Testcase 3148:
SELECT id, minute(c3 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select minute with group by (explain)
--Testcase 3149:
EXPLAIN VERBOSE
SELECT max(c3), minute(c3 + '1 12:59:10') FROM time_tbl group by minute(c3 + '1 12:59:10');

-- select minute with group by (result)
--Testcase 3150:
SELECT max(c3), minute(c3 + '1 12:59:10') FROM time_tbl group by minute(c3 + '1 12:59:10');

-- select minute with group by index (result)
--Testcase 3151:
SELECT id, minute(c3 + '1 12:59:10') FROM time_tbl group by 2,1;

-- select minute with group by index (result)
--Testcase 3152:
SELECT id, minute(c3 + '1 12:59:10') FROM time_tbl group by 1,2;

-- select minute with group by having (explain)
--Testcase 3153:
EXPLAIN VERBOSE
SELECT max(c3), minute(c3 + '1 12:59:10') FROM time_tbl group by minute(c3 + '1 12:59:10'), c3 HAVING minute(c3 + '1 12:59:10') < 60;

-- select minute with group by having (result)
--Testcase 3154:
SELECT max(c3), minute(c3 + '1 12:59:10') FROM time_tbl group by minute(c3 + '1 12:59:10'), c3 HAVING minute(c3 + '1 12:59:10') < 60;

-- select minute with group by index having (result)
--Testcase 3155:
SELECT id, minute(c3 + '1 12:59:10'), c3 FROM time_tbl group by 3, 2, 1 HAVING minute(c3 + '1 12:59:10') < 60;

-- select minute with group by index having (result)
--Testcase 3156:
SELECT id, minute(c3 + '1 12:59:10'), c3 FROM time_tbl group by 1, 2, 3 HAVING minute(c3 + '1 12:59:10') < 60;

-- select minute and as
--Testcase 3157:
SELECT minute(date_sub(c3, '1 12:59:10')) as minute1 FROM time_tbl;



-- MICROSECOND()
-- select microsecond (stub function, explain)
--Testcase 3158:
EXPLAIN VERBOSE
SELECT microsecond(c3), microsecond(c2), microsecond(date_sub(c3, '1 12:59:10.154')), microsecond('2021-01-01 12:00:00.986'::timestamp) FROM time_tbl;

-- select microsecond (stub function, result)
--Testcase 3159:
SELECT microsecond(c3), microsecond(c2), microsecond(date_sub(c3, '1 12:59:10.154')), microsecond('2021-01-01 12:00:00.986'::timestamp) FROM time_tbl;

-- select microsecond (stub function, not pushdown constraints, explain)
--Testcase 3160:
EXPLAIN VERBOSE
SELECT microsecond(c3), microsecond(c2), microsecond(date_sub(c3, '1 12:59:10.154')), microsecond('2021-01-01 12:00:00.986'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select microsecond (stub function, not pushdown constraints, result)
--Testcase 3161:
SELECT microsecond(c3), microsecond(c2), microsecond(date_sub(c3, '1 12:59:10.154')), microsecond('2021-01-01 12:00:00.986'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select microsecond (stub function, pushdown constraints, explain)
--Testcase 3162:
EXPLAIN VERBOSE
SELECT microsecond(c3), microsecond(c2), microsecond(date_sub(c3, '1 12:59:10.154')), microsecond('2021-01-01 12:00:00.986'::timestamp) FROM time_tbl WHERE id != 200;

-- select microsecond (stub function, pushdown constraints, result)
--Testcase 3163:
SELECT microsecond(c3), microsecond(c2), microsecond(date_sub(c3, '1 12:59:10.154')), microsecond('2021-01-01 12:00:00.986'::timestamp) FROM time_tbl WHERE id != 200;

-- select microsecond (stub function, microsecond in constraints, explain)
--Testcase 3164:
EXPLAIN VERBOSE
SELECT microsecond(c3), microsecond(c2), microsecond(date_sub(c3, '1 12:59:10.154')), microsecond('2021-01-01 12:00:00.986'::timestamp) FROM time_tbl WHERE microsecond(c3) = microsecond('2000-01-01'::timestamp);

-- select microsecond (stub function, microsecond in constraints, result)
--Testcase 3165:
SELECT microsecond(c3), microsecond(c2), microsecond(date_sub(c3, '1 12:59:10.154')), microsecond('2021-01-01 12:00:00.986'::timestamp) FROM time_tbl WHERE microsecond(c3) = microsecond('2000-01-01'::timestamp);

-- select microsecond (stub function, microsecond in constraints, explain)
--Testcase 3166:
EXPLAIN VERBOSE
SELECT microsecond(c3), microsecond(c2), microsecond(date_sub(c3, '1 12:59:10.154')), microsecond('2021-01-01 12:00:00.986'::timestamp) FROM time_tbl WHERE microsecond('2021-01-01 12:00:00'::timestamp) = '0';

-- select microsecond (stub function, microsecond in constraints, result)
--Testcase 3167:
SELECT microsecond(c3), microsecond(c2), microsecond(date_sub(c3, '1 12:59:10.154')), microsecond('2021-01-01 12:00:00.986'::timestamp) FROM time_tbl WHERE microsecond('2021-01-01 12:00:00'::timestamp) = '0';

-- select microsecond with agg (pushdown, explain)
--Testcase 3168:
EXPLAIN VERBOSE
SELECT max(c3), microsecond(max(c3)) FROM time_tbl;

-- select microsecond as nest function with agg (pushdown, result)
--Testcase 3169:
SELECT max(c3), microsecond(max(c3)) FROM time_tbl;

-- select microsecond with non pushdown func and explicit constant (explain)
--Testcase 3170:
EXPLAIN VERBOSE
SELECT microsecond(date_sub(c3, '1 12:59:10.999')), pi(), 4.1 FROM time_tbl;

-- select microsecond with non pushdown func and explicit constant (result)
--Testcase 3171:
SELECT microsecond(date_sub(c3, '1 12:59:10.999')), pi(), 4.1 FROM time_tbl;

-- select microsecond with order by (explain)
--Testcase 3172:
EXPLAIN VERBOSE
SELECT id, microsecond(c3 + '1 12:59:10.999') FROM time_tbl order by microsecond(c3 + '1 12:59:10.999');

-- select microsecond with order by (result)
--Testcase 3173:
SELECT id, microsecond(c3 + '1 12:59:10.999') FROM time_tbl order by microsecond(c3 + '1 12:59:10.999');

-- select microsecond with order by index (result)
--Testcase 3174:
SELECT id, microsecond(c3 + '1 12:59:10.999') FROM time_tbl order by 2,1;

-- select microsecond with order by index (result)
--Testcase 3175:
SELECT id, microsecond(c3 + '1 12:59:10.999') FROM time_tbl order by 1,2;

-- select microsecond with group by (explain)
--Testcase 3176:
EXPLAIN VERBOSE
SELECT max(c3), microsecond(c3 + '1 12:59:10.999') FROM time_tbl group by microsecond(c3 + '1 12:59:10.999');

-- select microsecond with group by (result)
--Testcase 3177:
SELECT max(c3), microsecond(c3 + '1 12:59:10.999') FROM time_tbl group by microsecond(c3 + '1 12:59:10.999');

-- select microsecond with group by index (result)
--Testcase 3178:
SELECT id, microsecond(c3 + '1 12:59:10.999') FROM time_tbl group by 2,1;

-- select microsecond with group by index (result)
--Testcase 3179:
SELECT id, microsecond(c3 + '1 12:59:10.999') FROM time_tbl group by 1,2;

-- select microsecond with group by having (explain)
--Testcase 3180:
EXPLAIN VERBOSE
SELECT max(c3), microsecond(c3 + '1 12:59:10.999') FROM time_tbl group by microsecond(c3 + '1 12:59:10.999'), c3 HAVING microsecond(c3 + '1 12:59:10.999') > 1000;

-- select microsecond with group by having (result)
--Testcase 3181:
SELECT max(c3), microsecond(c3 + '1 12:59:10.999') FROM time_tbl group by microsecond(c3 + '1 12:59:10.999'), c3 HAVING microsecond(c3 + '1 12:59:10.999') > 1000;

-- select microsecond with group by index having (result)
--Testcase 3182:
SELECT id, microsecond(c3 + '1 12:59:10.999'), c3 FROM time_tbl group by 3, 2, 1 HAVING microsecond(c3 + '1 12:59:10.999') > 1000;

-- select microsecond with group by index having (result)
--Testcase 3183:
SELECT id, microsecond(c3 + '1 12:59:10.999'), c3 FROM time_tbl group by 1, 2, 3 HAVING microsecond(c3 + '1 12:59:10.999') > 1000;

-- select microsecond and as
--Testcase 3184:
SELECT microsecond(date_sub(c3, '1 12:59:10.999')) as microsecond1 FROM time_tbl;



-- MAKETIME()
-- select maketime (stub function, explain)
--Testcase 3185:
EXPLAIN VERBOSE
SELECT maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl;

-- select maketime (stub function, result)
--Testcase 3186:
SELECT maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl;

-- select maketime (stub function, not pushdown constraints, explain)
--Testcase 3187:
EXPLAIN VERBOSE
SELECT maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl WHERE to_hex(id) = '1';

-- select maketime (stub function, not pushdown constraints, result)
--Testcase 3188:
SELECT maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl WHERE to_hex(id) = '1';

-- select maketime (stub function, pushdown constraints, explain)
--Testcase 3189:
EXPLAIN VERBOSE
SELECT maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl WHERE id != 200;

-- select maketime (stub function, pushdown constraints, result)
--Testcase 3190:
SELECT maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl WHERE id != 200;

-- select maketime (stub function, maketime in constraints, explain)
--Testcase 3191:
EXPLAIN VERBOSE
SELECT maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl WHERE maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) > '12:59:10'::time;

-- select maketime (stub function, maketime in constraints, result)
--Testcase 3192:
SELECT maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl WHERE maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) > '12:59:10'::time;
-- select maketime with agg (pushdown, explain)
--Testcase 3193:
EXPLAIN VERBOSE
SELECT max(c3), maketime(18, 15, 30) FROM time_tbl;

-- select maketime as nest function with agg (pushdown, result)
--Testcase 3194:
SELECT max(c3), maketime(18, 15, 30) FROM time_tbl;

-- select maketime with non pushdown func and explicit constant (explain)
--Testcase 3195:
EXPLAIN VERBOSE
SELECT maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30), pi(), 4.1 FROM time_tbl;

-- select maketime with non pushdown func and explicit constant (result)
--Testcase 3196:
SELECT maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30), pi(), 4.1 FROM time_tbl;

-- select maketime with order by (explain)
--Testcase 3197:
EXPLAIN VERBOSE
SELECT id, maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl order by maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30);

-- select maketime with order by (result)
--Testcase 3198:
SELECT id, maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl order by maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30);

-- select maketime with order by index (result)
--Testcase 3199:
SELECT id, maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl order by 2,1;

-- select maketime with order by index (result)
--Testcase 3200:
SELECT id, maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl order by 1,2;

-- select maketime with group by (explain)
--Testcase 3201:
EXPLAIN VERBOSE
SELECT max(c3), maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl group by maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30), c3;

-- select maketime with group by (result)
--Testcase 3202:
SELECT max(c3), maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl group by maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30), c3;

-- select maketime with group by index (result)
--Testcase 3203:
SELECT id, maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl group by 2,1;

-- select maketime with group by index (result)
--Testcase 3204:
SELECT id, maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl group by 1,2;

-- select maketime with group by index having (result)
--Testcase 3205:
SELECT id, c3, maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl group by 3, 2, 1 HAVING maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) > '12:00:00'::time;

-- select maketime with group by index having (result)
--Testcase 3206:
SELECT id, c3, maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) FROM time_tbl group by 1, 2, 3 HAVING maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) > '12:00:00'::time;

-- select maketime and as
--Testcase 3207:
SELECT maketime(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 15, 30) as maketime1 FROM time_tbl;



-- MAKEDATE()
-- select makedate (stub function, explain)
--Testcase 3208:
EXPLAIN VERBOSE
SELECT makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl;

-- select makedate (stub function, result)
--Testcase 3209:
SELECT makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl;

-- select makedate (stub function, not pushdown constraints, explain)
--Testcase 3210:
EXPLAIN VERBOSE
SELECT makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl WHERE to_hex(id) = '1';

-- select makedate (stub function, not pushdown constraints, result)
--Testcase 3211:
SELECT makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl WHERE to_hex(id) = '1';

-- select makedate (stub function, pushdown constraints, explain)
--Testcase 3212:
EXPLAIN VERBOSE
SELECT makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl WHERE id != 200;

-- select makedate (stub function, pushdown constraints, result)
--Testcase 3213:
SELECT makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl WHERE id != 200;

-- select makedate (stub function, makedate in constraints, explain)
--Testcase 3214:
EXPLAIN VERBOSE
SELECT makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl WHERE makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) < '2021-01-02'::date;

-- select makedate (stub function, makedate in constraints, result)
--Testcase 3215:
SELECT makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl WHERE makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) < '2021-01-02'::date;
-- select makedate with agg (pushdown, explain)
--Testcase 3216:
EXPLAIN VERBOSE
SELECT max(c3), makedate(18, 90) FROM time_tbl;

-- select makedate as nest function with agg (pushdown, result)
--Testcase 3217:
SELECT max(c3), makedate(18, 90) FROM time_tbl;

-- select makedate with non pushdown func and explicit constant (explain)
--Testcase 3218:
EXPLAIN VERBOSE
SELECT makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90), pi(), 4.1 FROM time_tbl;

-- select makedate with non pushdown func and explicit constant (result)
--Testcase 3219:
SELECT makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90), pi(), 4.1 FROM time_tbl;

-- select makedate with order by (explain)
--Testcase 3220:
EXPLAIN VERBOSE
SELECT id, makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl order by makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90);

-- select makedate with order by (result)
--Testcase 3221:
SELECT id, makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl order by makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90);

-- select makedate with order by index (result)
--Testcase 3222:
SELECT id, makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl order by 2,1;

-- select makedate with order by index (result)
--Testcase 3223:
SELECT id, makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl order by 1,2;

-- select makedate with group by (explain)
--Testcase 3224:
EXPLAIN VERBOSE
SELECT max(c3), makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl group by makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90), c3;

-- select makedate with group by (result)
--Testcase 3225:
SELECT max(c3), makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl group by makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90), c3;

-- select makedate with group by index (result)
--Testcase 3226:
SELECT id, makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl group by 2,1;

-- select makedate with group by index (result)
--Testcase 3227:
SELECT id, makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl group by 1,2;

-- select makedate with group by index having (result)
--Testcase 3228:
SELECT id, c3, makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl group by 3, 2, 1 HAVING makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) > '2008-03-31'::date;

-- select makedate with group by index having (result)
--Testcase 3229:
SELECT id, c3, makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) FROM time_tbl group by 1, 2, 3 HAVING makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) > '2008-03-31'::date;

-- select makedate and as
--Testcase 3230:
SELECT makedate(period_diff(mysql_extract('YEAR_MONTH', c3 ), 201907), 90) as makedate1 FROM time_tbl;



-- LOCALTIMESTAMP, LOCALTIMESTAMP()
-- mysql_localtimestamp is mutable function, some executes will return different result
-- select mysql_localtimestamp (stub function, explain)
--Testcase 3231:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp() FROM time_tbl;

-- select mysql_localtimestamp (stub function, not pushdown constraints, explain)
--Testcase 3232:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp() FROM time_tbl WHERE to_hex(id) > '0';

-- select mysql_localtimestamp (stub function, pushdown constraints, explain)
--Testcase 3233:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp() FROM time_tbl WHERE id = 1;

-- select mysql_localtimestamp (stub function, mysql_localtimestamp in constraints, explain)
--Testcase 3234:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp() FROM time_tbl WHERE mysql_localtimestamp() > '2000-01-01 00:00:00'::timestamp;

-- mysql_localtimestamp in constrains (stub function, explain)
--Testcase 3235:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE mysql_localtimestamp() > '2000-01-01 00:00:00'::timestamp;

-- mysql_localtimestamp in constrains (stub function, result)
--Testcase 3236:
SELECT c1 FROM time_tbl WHERE mysql_localtimestamp() > '2000-01-01 00:00:00'::timestamp;

-- mysql_localtimestamp as parameter of addtime(stub function, explain)
--Testcase 3237:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_localtimestamp(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp;

-- mysql_localtimestamp as parameter of addtime(stub function, result)
--Testcase 3238:
SELECT c1 FROM time_tbl WHERE addtime(mysql_localtimestamp(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp;

-- select mysql_localtimestamp and agg (pushdown, explain)
--Testcase 3239:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp(), sum(id) FROM time_tbl;

-- select mysql_localtimestamp and log2 (pushdown, explain)
--Testcase 3240:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp(), log2(id) FROM time_tbl;

-- select mysql_localtimestamp with non pushdown func and explicit constant (explain)
--Testcase 3241:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp(), to_hex(id), 4 FROM time_tbl;

-- select mysql_localtimestamp with order by (explain)
--Testcase 3242:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp(), c1 FROM time_tbl ORDER BY mysql_localtimestamp();

-- select mysql_localtimestamp with order by index (explain)
--Testcase 3243:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp(), c1 FROM time_tbl ORDER BY 1;

-- mysql_localtimestamp constraints with order by (explain)
--Testcase 3244:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_localtimestamp(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp ORDER BY c1;

-- mysql_localtimestamp constraints with order by (result)
--Testcase 3245:
SELECT c1 FROM time_tbl WHERE addtime(mysql_localtimestamp(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp ORDER BY c1;

-- select mysql_localtimestamp with group by (explain)
--Testcase 3246:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp(), c1 FROM time_tbl GROUP BY c1;

-- select mysql_localtimestamp with group by index (explain)
--Testcase 3247:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp(), c1 FROM time_tbl GROUP BY 2;

-- select mysql_localtimestamp with group by having (explain)
--Testcase 3248:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp(), c1 FROM time_tbl GROUP BY mysql_localtimestamp(),c1 HAVING mysql_localtimestamp() > '2000-01-01 00:00:00'::timestamp;

-- select mysql_localtimestamp with group by index having (explain)
--Testcase 3249:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp(), c1 FROM time_tbl GROUP BY 2,1 HAVING mysql_localtimestamp() > '2000-01-01 00:00:00'::timestamp;

-- mysql_localtimestamp constraints with group by (explain)
--Testcase 3250:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_localtimestamp(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp GROUP BY c1;

-- mysql_localtimestamp constraints with group by (result)
--Testcase 3251:
SELECT c1 FROM time_tbl WHERE addtime(mysql_localtimestamp(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp GROUP BY c1;

-- select mysql_localtimestamp and as
--Testcase 3252:
EXPLAIN VERBOSE
SELECT mysql_localtimestamp() as mysql_localtimestamp1 FROM time_tbl;



-- LOCALTIME(), LOCALTIME
-- mysql_localtime is mutable function, some executes will return different result
-- select mysql_localtime (stub function, explain)
--Testcase 3253:
EXPLAIN VERBOSE
SELECT mysql_localtime() FROM time_tbl;

-- select mysql_localtime (stub function, not pushdown constraints, explain)
--Testcase 3254:
EXPLAIN VERBOSE
SELECT mysql_localtime() FROM time_tbl WHERE to_hex(id) > '0';

-- select mysql_localtime (stub function, pushdown constraints, explain)
--Testcase 3255:
EXPLAIN VERBOSE
SELECT mysql_localtime() FROM time_tbl WHERE id = 1;

-- select mysql_localtime (stub function, mysql_localtime in constraints, explain)
--Testcase 3256:
EXPLAIN VERBOSE
SELECT mysql_localtime() FROM time_tbl WHERE mysql_localtime() > '2000-01-01 00:00:00'::timestamp;

-- mysql_localtime in constrains (stub function, explain)
--Testcase 3257:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE mysql_localtime() > '2000-01-01 00:00:00'::timestamp;

-- mysql_localtime in constrains (stub function, result)
--Testcase 3258:
SELECT c1 FROM time_tbl WHERE mysql_localtime() > '2000-01-01 00:00:00'::timestamp;

-- mysql_localtime as parameter of addtime(stub function, explain)
--Testcase 3259:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_localtime(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp;

-- mysql_localtime as parameter of addtime(stub function, result)
--Testcase 3260:
SELECT c1 FROM time_tbl WHERE addtime(mysql_localtime(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp;

-- select mysql_localtime and agg (pushdown, explain)
--Testcase 3261:
EXPLAIN VERBOSE
SELECT mysql_localtime(), sum(id) FROM time_tbl;

-- select mysql_localtime and log2 (pushdown, explain)
--Testcase 3262:
EXPLAIN VERBOSE
SELECT mysql_localtime(), log2(id) FROM time_tbl;

-- select mysql_localtime with non pushdown func and explicit constant (explain)
--Testcase 3263:
EXPLAIN VERBOSE
SELECT mysql_localtime(), to_hex(id), 4 FROM time_tbl;

-- select mysql_localtime with order by (explain)
--Testcase 3264:
EXPLAIN VERBOSE
SELECT mysql_localtime(), c1 FROM time_tbl ORDER BY mysql_localtime();

-- select mysql_localtime with order by index (explain)
--Testcase 3265:
EXPLAIN VERBOSE
SELECT mysql_localtime(), c1 FROM time_tbl ORDER BY 1;

-- mysql_localtime constraints with order by (explain)
--Testcase 3266:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_localtime(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp ORDER BY c1;

-- mysql_localtime constraints with order by (result)
--Testcase 3267:
SELECT c1 FROM time_tbl WHERE addtime(mysql_localtime(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp ORDER BY c1;

-- select mysql_localtime with group by (explain)
--Testcase 3268:
EXPLAIN VERBOSE
SELECT mysql_localtime(), c1 FROM time_tbl GROUP BY c1;

-- select mysql_localtime with group by index (explain)
--Testcase 3269:
EXPLAIN VERBOSE
SELECT mysql_localtime(), c1 FROM time_tbl GROUP BY 2;

-- select mysql_localtime with group by having (explain)
--Testcase 3270:
EXPLAIN VERBOSE
SELECT mysql_localtime(), c1 FROM time_tbl GROUP BY mysql_localtime(),c1 HAVING mysql_localtime() > '2000-01-01 00:00:00'::timestamp;

-- select mysql_localtime with group by index having (explain)
--Testcase 3271:
EXPLAIN VERBOSE
SELECT mysql_localtime(), c1 FROM time_tbl GROUP BY 2,1 HAVING mysql_localtime() > '2000-01-01 00:00:00'::timestamp;

-- mysql_localtime constraints with group by (explain)
--Testcase 3272:
EXPLAIN VERBOSE
SELECT c1 FROM time_tbl WHERE addtime(mysql_localtime(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp GROUP BY c1;

-- mysql_localtime constraints with group by (result)
--Testcase 3273:
SELECT c1 FROM time_tbl WHERE addtime(mysql_localtime(), '1 12:59:10') > '2000-01-01 00:00:00'::timestamp GROUP BY c1;

-- select mysql_localtime and as
--Testcase 3274:
EXPLAIN VERBOSE
SELECT mysql_localtime() as mysql_localtime1 FROM time_tbl;



-- LAST_DAY()
-- select last_day (stub function, explain)
--Testcase 3275:
EXPLAIN VERBOSE
SELECT last_day(c3), last_day(c2), last_day(date_sub(c3, '1 12:59:10')), last_day('2021-01-01 12:00:00'::timestamp) FROM time_tbl;

-- select last_day (stub function, result)
--Testcase 3276:
SELECT last_day(c3), last_day(c2), last_day(date_sub(c3, '1 12:59:10')), last_day('2021-01-01 12:00:00'::timestamp) FROM time_tbl;

-- select last_day (stub function, not pushdown constraints, explain)
--Testcase 3277:
EXPLAIN VERBOSE
SELECT last_day(c3), last_day(c2), last_day(date_sub(c3, '1 12:59:10')), last_day('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select last_day (stub function, not pushdown constraints, result)
--Testcase 3278:
SELECT last_day(c3), last_day(c2), last_day(date_sub(c3, '1 12:59:10')), last_day('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select last_day (stub function, pushdown constraints, explain)
--Testcase 3279:
EXPLAIN VERBOSE
SELECT last_day(c3), last_day(c2), last_day(date_sub(c3, '1 12:59:10')), last_day('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200;

-- select last_day (stub function, pushdown constraints, result)
--Testcase 3280:
SELECT last_day(c3), last_day(c2), last_day(date_sub(c3, '1 12:59:10')), last_day('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE id != 200;

-- select last_day (stub function, last_day in constraints, explain)
--Testcase 3281:
EXPLAIN VERBOSE
SELECT last_day(c3), last_day(c2), last_day(date_sub(c3, '1 12:59:10')), last_day('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE last_day(c3) > last_day('2000-01-01'::timestamp);

-- select last_day (stub function, last_day in constraints, result)
--Testcase 3282:
SELECT last_day(c3), last_day(c2), last_day(date_sub(c3, '1 12:59:10')), last_day('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE last_day(c3) > last_day('2000-01-01'::timestamp);

-- select last_day (stub function, last_day in constraints, explain)
--Testcase 3283:
EXPLAIN VERBOSE
SELECT last_day(c3), last_day(c2), last_day(date_sub(c3, '1 12:59:10')), last_day('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE last_day('2021-01-01 12:00:00'::timestamp) = '2021-01-31';

-- select last_day (stub function, last_day in constraints, result)
--Testcase 3284:
SELECT last_day(c3), last_day(c2), last_day(date_sub(c3, '1 12:59:10')), last_day('2021-01-01 12:00:00'::timestamp) FROM time_tbl WHERE last_day('2021-01-01 12:00:00'::timestamp) = '2021-01-31';

-- select last_day with agg (pushdown, explain)
--Testcase 3285:
EXPLAIN VERBOSE
SELECT max(c3), last_day(max(c3)) FROM time_tbl;

-- select last_day as nest function with agg (pushdown, result)
--Testcase 3286:
SELECT max(c3), last_day(max(c3)) FROM time_tbl;

-- select last_day with non pushdown func and explicit constant (explain)
--Testcase 3287:
EXPLAIN VERBOSE
SELECT last_day(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl;

-- select last_day with non pushdown func and explicit constant (result)
--Testcase 3288:
SELECT last_day(date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl;

-- select last_day with order by (explain)
--Testcase 3289:
EXPLAIN VERBOSE
SELECT id, last_day(c3 + '1 12:59:10') FROM time_tbl order by last_day(c3 + '1 12:59:10');

-- select last_day with order by (result)
--Testcase 3290:
SELECT id, last_day(c3 + '1 12:59:10') FROM time_tbl order by last_day(c3 + '1 12:59:10');

-- select last_day with order by index (result)
--Testcase 3291:
SELECT id, last_day(c3 + '1 12:59:10') FROM time_tbl order by 2,1;

-- select last_day with order by index (result)
--Testcase 3292:
SELECT id, last_day(c3 + '1 12:59:10') FROM time_tbl order by 1,2;

-- select last_day with group by (explain)
--Testcase 3293:
EXPLAIN VERBOSE
SELECT max(c3), last_day(c3 + '1 12:59:10') FROM time_tbl group by last_day(c3 + '1 12:59:10');

-- select last_day with group by (result)
--Testcase 3294:
SELECT max(c3), last_day(c3 + '1 12:59:10') FROM time_tbl group by last_day(c3 + '1 12:59:10');

-- select last_day with group by index (result)
--Testcase 3295:
SELECT id, last_day(c3 + '1 12:59:10') FROM time_tbl group by 2,1;

-- select last_day with group by index (result)
--Testcase 3296:
SELECT id, last_day(c3 + '1 12:59:10') FROM time_tbl group by 1,2;

-- select last_day with group by having (explain)
--Testcase 3297:
EXPLAIN VERBOSE
SELECT max(c3), last_day(c3 + '1 12:59:10') FROM time_tbl group by last_day(c3 + '1 12:59:10'), c3 HAVING last_day(c3 + '1 12:59:10') > '2001-01-31'::date;

-- select last_day with group by having (result)
--Testcase 3298:
SELECT max(c3), last_day(c3 + '1 12:59:10') FROM time_tbl group by last_day(c3 + '1 12:59:10'), c3 HAVING last_day(c3 + '1 12:59:10') > '2001-01-31'::date;

-- select last_day with group by index having (result)
--Testcase 3299:
SELECT id, last_day(c3 + '1 12:59:10'), c3 FROM time_tbl group by 3, 2, 1 HAVING last_day(c3 + '1 12:59:10') > '2001-01-31'::date;

-- select last_day with group by index having (result)
--Testcase 3300:
SELECT id, last_day(c3 + '1 12:59:10'), c3 FROM time_tbl group by 1, 2, 3 HAVING last_day(c3 + '1 12:59:10') > '2001-01-31'::date;

-- select last_day and as
--Testcase 3301:
SELECT last_day(date_sub(c3, '1 12:59:10')) as last_day1 FROM time_tbl;



-- HOUR()
-- select hour (stub function, explain)
--Testcase 3302:
EXPLAIN VERBOSE
SELECT hour(c1), hour('23:00:00'::time) FROM time_tbl;

-- select hour (stub function, result)
--Testcase 3303:
SELECT hour(c1), hour('23:00:00'::time) FROM time_tbl;

-- select hour (stub function, not pushdown constraints, explain)
--Testcase 3304:
EXPLAIN VERBOSE
SELECT hour(c1), hour('23:00:00'::time) FROM time_tbl WHERE to_hex(id) = '1';

-- select hour (stub function, not pushdown constraints, result)
--Testcase 3305:
SELECT hour(c1), hour('23:00:00'::time) FROM time_tbl WHERE to_hex(id) = '1';

-- select hour (stub function, pushdown constraints, explain)
--Testcase 3306:
EXPLAIN VERBOSE
SELECT hour(c1), hour('23:00:00'::time) FROM time_tbl WHERE id != 200;

-- select hour (stub function, pushdown constraints, result)
--Testcase 3307:
SELECT hour(c1), hour('23:00:00'::time) FROM time_tbl WHERE id != 200;

-- select hour (stub function, hour in constraints, explain)
--Testcase 3308:
EXPLAIN VERBOSE
SELECT hour(c1), hour('23:00:00'::time) FROM time_tbl WHERE hour(c1) = 12;

-- select hour (stub function, hour in constraints, result)
--Testcase 3309:
SELECT hour(c1), hour('23:00:00'::time) FROM time_tbl WHERE hour(c1) = 12;

-- select hour (stub function, hour in constraints, explain)
--Testcase 3310:
EXPLAIN VERBOSE
SELECT hour(c1), hour('23:00:00'::time) FROM time_tbl WHERE hour('22:00:00'::time) > '12';

-- select hour (stub function, hour in constraints, result)
--Testcase 3311:
SELECT hour(c1), hour('23:00:00'::time) FROM time_tbl WHERE hour('22:00:00'::time) > '12';

-- select hour with agg (pushdown, explain)
--Testcase 3312:
EXPLAIN VERBOSE
SELECT max(c1), hour(max(c1)) FROM time_tbl;

-- select hour as nest function with agg (pushdown, result)
--Testcase 3313:
SELECT max(c1), hour(max(c1)) FROM time_tbl;

-- select hour with non pushdown func and explicit constant (explain)
--Testcase 3314:
EXPLAIN VERBOSE
SELECT hour(maketime(18, 15, 30)), pi(), 4.1 FROM time_tbl;

-- select hour with non pushdown func and explicit constant (result)
--Testcase 3315:
SELECT hour(maketime(18, 15, 30)), pi(), 4.1 FROM time_tbl;

-- select hour with order by (explain)
--Testcase 3316:
EXPLAIN VERBOSE
SELECT id, hour(c1), hour('23:00:00'::time) FROM time_tbl order by hour(c1), hour('23:00:00'::time);

-- select hour with order by (result)
--Testcase 3317:
SELECT id, hour(c1), hour('23:00:00'::time) FROM time_tbl order by hour(c1), hour('23:00:00'::time);

-- select hour with order by index (result)
--Testcase 3318:
SELECT id, hour(c1), hour('23:00:00'::time) FROM time_tbl order by 3,2,1;

-- select hour with order by index (result)
--Testcase 3319:
SELECT id, hour(c1), hour('23:00:00'::time) FROM time_tbl order by 1,2,3;

-- select hour with group by (explain)
--Testcase 3320:
EXPLAIN VERBOSE
SELECT max(c3), hour('23:00:00'::time) FROM time_tbl group by hour('05:00:00'::time);

-- select hour with group by (result)
--Testcase 3321:
SELECT max(c3), hour('23:00:00'::time) FROM time_tbl group by hour('05:00:00'::time);

-- select hour with group by index (result)
--Testcase 3322:
SELECT id, hour(c1), hour('23:00:00'::time) FROM time_tbl group by 3,2,1;

-- select hour with group by index (result)
--Testcase 3323:
SELECT id, hour(c1), hour('23:00:00'::time) FROM time_tbl group by 1,2,3;

-- select hour with group by having (explain)
--Testcase 3324:
EXPLAIN VERBOSE
SELECT max(c3), hour(c1), hour('23:00:00'::time) FROM time_tbl group by hour(c1),hour('23:00:00'::time), c1,c3 HAVING hour(c1) < 24;

-- select hour with group by having (result)
--Testcase 3325:
SELECT max(c3), hour(c1), hour('23:00:00'::time) FROM time_tbl group by hour(c1),hour('23:00:00'::time), c1,c3 HAVING hour(c1) < 24;

-- select hour with group by index having (result)
--Testcase 3326:
SELECT id, c1, hour(c1), hour('23:00:00'::time) FROM time_tbl group by 4, 3, 2, 1 HAVING hour(c1) < 24;

-- select hour with group by index having (result)
--Testcase 3327:
SELECT id, c1, hour(c1), hour('23:00:00'::time) FROM time_tbl group by 1, 2, 3, 4 HAVING hour(c1) < 24;

-- select hour and as
--Testcase 3328:
SELECT hour(c1) as hour1, hour('23:00:00'::time) as hour2 FROM time_tbl;

-- GET_FORMAT()
-- Returns a format string. This function is useful in combination with the DATE_FORMAT() and the STR_TO_DATE() functions.

-- select get_format (stub function, explain)
--Testcase 3329:
EXPLAIN VERBOSE
SELECT get_format('date', 'usa'), date_format(c2, get_format('date', 'usa')), get_format('datetime', 'jis'), date_format(c3, get_format('datetime', 'jis')) FROM time_tbl;

-- select get_format (stub function, result)
--Testcase 3330:
SELECT get_format('date', 'usa'), date_format(c2, get_format('date', 'usa')), get_format('datetime', 'jis'), date_format(c3, get_format('datetime', 'jis')) FROM time_tbl;

-- select get_format (stub function, not pushdown constraints, explain)
--Testcase 3331:
EXPLAIN VERBOSE
SELECT get_format('date', 'usa'), date_format(c2, get_format('date', 'usa')), get_format('datetime', 'jis'), date_format(c3, get_format('datetime', 'jis')) FROM time_tbl WHERE to_hex(id) = '1';

-- select get_format (stub function, not pushdown constraints, result)
--Testcase 3332:
SELECT get_format('date', 'usa'), date_format(c2, get_format('date', 'usa')), get_format('datetime', 'jis'), date_format(c3, get_format('datetime', 'jis')) FROM time_tbl WHERE to_hex(id) = '1';

-- select get_format (stub function, pushdown constraints, explain)
--Testcase 3333:
EXPLAIN VERBOSE
SELECT get_format('date', 'usa'), date_format(c2, get_format('date', 'usa')), get_format('datetime', 'jis'), date_format(c3, get_format('datetime', 'jis')) FROM time_tbl WHERE id != 0;

-- select get_format (stub function, pushdown constraints, result)
--Testcase 3334:
SELECT get_format('date', 'usa'), date_format(c2, get_format('date', 'usa')), get_format('datetime', 'jis'), date_format(c3, get_format('datetime', 'jis')) FROM time_tbl WHERE id != 0;

-- select get_format (stub function, get_format in constraints, explain)
--Testcase 3335:
EXPLAIN VERBOSE
SELECT get_format('date', 'usa'), date_format(c2, get_format('date', 'usa')), get_format('datetime', 'jis'), date_format(c3, get_format('datetime', 'jis')) FROM time_tbl WHERE get_format('date', 'usa') IS NOT NULL;

-- select get_format (stub function, get_format in constraints, result)
--Testcase 3336:
SELECT get_format('date', 'usa'), date_format(c2, get_format('date', 'usa')), get_format('datetime', 'jis'), date_format(c3, get_format('datetime', 'jis')) FROM time_tbl WHERE get_format('date', 'usa') IS NOT NULL;

-- select get_format (stub function, get_format in constraints, explain)
--Testcase 3337:
EXPLAIN VERBOSE
SELECT get_format('date', 'usa'), date_format(c2, get_format('date', 'usa')), get_format('datetime', 'jis'), date_format(c3, get_format('datetime', 'jis')) FROM time_tbl WHERE date_format(c3, get_format('datetime', 'jis')) IS NOT NULL;

-- select get_format (stub function, get_format in constraints, result)
--Testcase 3338:
SELECT get_format('date', 'usa'), date_format(c2, get_format('date', 'usa')), get_format('datetime', 'jis'), date_format(c3, get_format('datetime', 'jis')) FROM time_tbl WHERE date_format(c3, get_format('datetime', 'jis')) IS NOT NULL;

-- select get_format as nest function with agg (pushdown, explain)
--Testcase 3339:
EXPLAIN VERBOSE
SELECT max(c2), date_format(max(c3), get_format('datetime', 'jis')) FROM time_tbl;

-- select get_format as nest function with agg (pushdown, result)
--Testcase 3340:
SELECT max(c2), date_format(max(c3), get_format('datetime', 'jis')) FROM time_tbl;

-- select get_format with non pushdown func and explicit constant (explain)
--Testcase 3341:
EXPLAIN VERBOSE
SELECT get_format('datetime', 'jis'), pi(), 4.1 FROM time_tbl;

-- select get_format with non pushdown func and explicit constant (result)
--Testcase 3342:
SELECT get_format('datetime', 'jis'), pi(), 4.1 FROM time_tbl;

-- select get_format with order by (explain)
--Testcase 3343:
EXPLAIN VERBOSE
SELECT id, date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')) FROM time_tbl order by date_format(c3 + '1 12:59:10', get_format('datetime', 'jis'));

-- select get_format with order by (result)
--Testcase 3344:
SELECT id, date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')) FROM time_tbl order by date_format(c3 + '1 12:59:10', get_format('datetime', 'jis'));

-- select get_format with order by index (result)
--Testcase 3345:
SELECT id, date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')) FROM time_tbl order by 2,1;

-- select get_format with order by index (result)
--Testcase 3346:
SELECT id, date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')) FROM time_tbl order by 1,2;

-- select get_format with group by (explain)
--Testcase 3347:
EXPLAIN VERBOSE
SELECT count(id), date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')) FROM time_tbl group by date_format(c3 + '1 12:59:10', get_format('datetime', 'jis'));

-- select get_format with group by (result)
--Testcase 3348:
SELECT count(id), date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')) FROM time_tbl group by date_format(c3 + '1 12:59:10', get_format('datetime', 'jis'));

-- select get_format with group by index (result)
--Testcase 3349:
SELECT id, date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')) FROM time_tbl group by 2,1;

-- select get_format with group by index (result)
--Testcase 3350:
SELECT id, date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')) FROM time_tbl group by 1,2;

-- select get_format with group by index having (result)
--Testcase 3351:
SELECT id, date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')), c3 FROM time_tbl group by 3,2,1 HAVING date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')) > '2000-01-02';

-- select get_format with group by index having (result)
--Testcase 3352:
SELECT id, date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')), c3 FROM time_tbl group by 1,2,3 HAVING date_format(c3 + '1 12:59:10', get_format('datetime', 'jis')) > '2000-01-02';

-- select get_format and as
--Testcase 3353:
SELECT get_format('datetime', 'jis') as get_format1 FROM time_tbl;

-- FROM_UNIXTIME()
-- select from_unixtime (stub function, explain)
--Testcase 3354:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x') FROM time_tbl;

-- select from_unixtime (stub function, result)
--Testcase 3355:
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x') FROM time_tbl;

-- select from_unixtime (stub function, not pushdown constraints, explain)
--Testcase 3356:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x') FROM time_tbl WHERE to_hex(id) > '0';

-- select from_unixtime (stub function, not pushdown constraints, result)
--Testcase 3357:
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x') FROM time_tbl WHERE to_hex(id) > '0';

-- select from_unixtime (stub function, pushdown constraints, explain)
--Testcase 3358:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x') FROM time_tbl WHERE id = 1;

-- select from_unixtime (stub function, pushdown constraints, result)
--Testcase 3359:
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x') FROM time_tbl WHERE id = 1;

-- select from_unixtime (stub function, from_unixtime in constraints, explain)
--Testcase 3360:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x') FROM time_tbl WHERE from_unixtime(id + 1447430881) > from_unixtime(1447430881);

-- select from_unixtime (stub function, from_unixtime in constraints, result)
--Testcase 3361:
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x') FROM time_tbl WHERE from_unixtime(id + 1447430881) > from_unixtime(1447430881);

-- select from_unixtime and agg (pushdown, explain)
--Testcase 3362:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881), sum(id) FROM time_tbl;

-- select from_unixtime and log2 (pushdown, result)
--Testcase 3363:
SELECT from_unixtime(1447430881), log2(id) FROM time_tbl;

-- select from_unixtime with non pushdown func and explicit constant (explain)
--Testcase 3364:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881), to_hex(id), 4 FROM time_tbl;

-- select from_unixtime with order by (explain)
--Testcase 3365:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x'), c1 FROM time_tbl ORDER BY from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x');

-- select from_unixtime with order by index (explain)
--Testcase 3366:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x'), c1 FROM time_tbl ORDER BY 1,2,3;

-- from_unixtime constraints with order by (explain)
--Testcase 3367:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x') FROM time_tbl WHERE from_unixtime(id + 1447430881) > from_unixtime(1447430881) ORDER BY from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x');

-- from_unixtime constraints with order by (result)
--Testcase 3368:
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x') FROM time_tbl WHERE from_unixtime(id + 1447430881) > from_unixtime(1447430881) ORDER BY from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x');

-- select from_unixtime with group by (explain)
--Testcase 3369:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x'), c1 FROM time_tbl GROUP BY c1,id;

-- select from_unixtime with group by index (explain)
--Testcase 3370:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x'), c1 FROM time_tbl GROUP BY 1,2,3;

-- select from_unixtime with group by index having (explain)
--Testcase 3371:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x'), c1 FROM time_tbl GROUP BY 1,2,3 HAVING from_unixtime(1447430881) = '2015-11-13 08:08:01';

-- select from_unixtime with group by index having (result)
--Testcase 3372:
SELECT from_unixtime(1447430881), from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x'), c1 FROM time_tbl GROUP BY 1,2,3 HAVING from_unixtime(1447430881) = '2015-11-13 08:08:01';

-- select from_unixtime and as
--Testcase 3373:
EXPLAIN VERBOSE
SELECT from_unixtime(1447430881) as from_unixtime1, from_unixtime(id + 1447430881, '%Y %D %M %h:%i:%s %x') as from_unixtime2 FROM time_tbl;



-- FROM_DAYS()
-- select from_days (stub function, explain)
--Testcase 3374:
EXPLAIN VERBOSE
SELECT from_days(id + 200719) FROM time_tbl;

-- select from_days (stub function, result)
--Testcase 3375:
SELECT from_days(id + 200719) FROM time_tbl;

-- select from_days (stub function, not pushdown constraints, explain)
--Testcase 3376:
EXPLAIN VERBOSE
SELECT from_days(id + 200719) FROM time_tbl WHERE to_hex(id) > '0';

-- select from_days (stub function, not pushdown constraints, result)
--Testcase 3377:
SELECT from_days(id + 200719) FROM time_tbl WHERE to_hex(id) > '0';

-- select from_days (stub function, pushdown constraints, explain)
--Testcase 3378:
EXPLAIN VERBOSE
SELECT from_days(id + 200719) FROM time_tbl WHERE id = 1;

-- select from_days (stub function, pushdown constraints, result)
--Testcase 3379:
SELECT from_days(id + 200719) FROM time_tbl WHERE id = 1;

-- from_days in constrains (stub function, explain)
--Testcase 3380:
EXPLAIN VERBOSE
SELECT from_days(id + 200719) FROM time_tbl WHERE from_days(id + 200719) > from_days(day('2001-01-01'::date));

-- from_days in constrains (stub function, result)
--Testcase 3381:
SELECT from_days(id + 200719) FROM time_tbl WHERE from_days(id + 200719) > from_days(day('2001-01-01'::date));

-- select from_days and agg (pushdown, explain)
--Testcase 3382:
EXPLAIN VERBOSE
SELECT from_days(max(id) + 200719), sum(id) FROM time_tbl;

-- select from_days and agg (pushdown, result)
--Testcase 3383:
SELECT from_days(max(id) + 200719), sum(id) FROM time_tbl;

-- select from_days and log2 (pushdown, explain)
--Testcase 3384:
EXPLAIN VERBOSE
SELECT from_days(id + 200719), log2(id) FROM time_tbl;

-- select from_days and log2 (pushdown, result)
--Testcase 3385:
SELECT from_days(id + 200719), log2(id) FROM time_tbl;

-- select from_days with non pushdown func and explicit constant (explain)
--Testcase 3386:
EXPLAIN VERBOSE
SELECT from_days(id + 200719), to_hex(id), 4 FROM time_tbl;

-- select from_days with order by (explain)
--Testcase 3387:
EXPLAIN VERBOSE
SELECT from_days(id + 200719), c1 FROM time_tbl ORDER BY from_days(id + 200719);

-- select from_days with order by index (explain)
--Testcase 3388:
EXPLAIN VERBOSE
SELECT from_days(id + 200719), c1 FROM time_tbl ORDER BY 1,2;

-- from_days constraints with order by (explain)
--Testcase 3389:
EXPLAIN VERBOSE
SELECT from_days(id + 200719) FROM time_tbl WHERE from_days(id + 200719) > from_days(day('2001-01-01'::date)) ORDER BY from_days(id + 200719);

-- from_days constraints with order by (result)
--Testcase 3390:
SELECT from_days(id + 200719) FROM time_tbl WHERE from_days(id + 200719) > from_days(day('2001-01-01'::date)) ORDER BY from_days(id + 200719);

-- select from_days with group by (explain)
--Testcase 3391:
EXPLAIN VERBOSE
SELECT from_days(id + 200719), c1 FROM time_tbl GROUP BY c1,id;

-- select from_days with group by index (explain)
--Testcase 3392:
EXPLAIN VERBOSE
SELECT from_days(id + 200719), c1 FROM time_tbl GROUP BY 1,2;

-- select from_days with group by having (explain)
--Testcase 3393:
EXPLAIN VERBOSE
SELECT from_days(id + 200719), c1 FROM time_tbl GROUP BY from_days(id + 200719),c1,id HAVING from_days(id + 200719) > '0549-07-21';

-- select from_days with group by index having (result)
--Testcase 3394:
SELECT id, from_days(id + 200719), c1 FROM time_tbl GROUP BY 1,2,3 HAVING from_days(id + 200719) > '0549-07-21';

-- select from_days and as
--Testcase 3395:
EXPLAIN VERBOSE
SELECT from_days(id + 200719) as from_days1 FROM time_tbl;



-- EXTRACT()
-- select mysql_extract (stub function, explain)
--Testcase 3396:
EXPLAIN VERBOSE
SELECT mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl;

-- select mysql_extract (stub function, result)
--Testcase 3397:
SELECT mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl;

-- select mysql_extract (stub function, not pushdown constraints, explain)
--Testcase 3398:
EXPLAIN VERBOSE
SELECT mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl WHERE to_hex(id) = '1';

-- select mysql_extract (stub function, not pushdown constraints, result)
--Testcase 3399:
SELECT mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl WHERE to_hex(id) = '1';

-- select mysql_extract (stub function, pushdown constraints, explain)
--Testcase 3400:
EXPLAIN VERBOSE
SELECT mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl WHERE id != 200;

-- select mysql_extract (stub function, pushdown constraints, result)
--Testcase 3401:
SELECT mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl WHERE id != 200;

-- select mysql_extract (stub function, mysql_extract in constraints, explain)
--Testcase 3402:
EXPLAIN VERBOSE
SELECT mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl WHERE mysql_extract('YEAR_MONTH', c3 ) != mysql_extract('YEAR_MONTH', '2000-01-01'::timestamp);

-- select mysql_extract (stub function, mysql_extract in constraints, result)
--Testcase 3403:
SELECT mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl WHERE mysql_extract('YEAR_MONTH', c3 ) != mysql_extract('YEAR_MONTH', '2000-01-01'::timestamp);

-- select mysql_extract (stub function, mysql_extract in constraints, explain)
--Testcase 3404:
EXPLAIN VERBOSE
SELECT mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl WHERE mysql_extract('YEAR_MONTH', c3 ) > '1';

-- select mysql_extract (stub function, mysql_extract in constraints, result)
--Testcase 3405:
SELECT mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl WHERE mysql_extract('YEAR_MONTH', c3 ) > '1';

-- select mysql_extract with agg (pushdown, explain)
--Testcase 3406:
EXPLAIN VERBOSE
SELECT max(c3), mysql_extract('YEAR', max(c3)) FROM time_tbl;

-- select mysql_extract as nest function with agg (pushdown, result)
--Testcase 3407:
SELECT max(c3), mysql_extract('YEAR', max(c3)) FROM time_tbl;

-- select mysql_extract with non pushdown func and explicit constant (explain)
--Testcase 3408:
EXPLAIN VERBOSE
SELECT mysql_extract('YEAR', date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl;

-- select mysql_extract with non pushdown func and explicit constant (result)
--Testcase 3409:
SELECT mysql_extract('YEAR', date_sub(c3, '1 12:59:10')), pi(), 4.1 FROM time_tbl;

-- select mysql_extract with order by (explain)
--Testcase 3410:
EXPLAIN VERBOSE
SELECT id, mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl order by mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3);

-- select mysql_extract with order by (result)
--Testcase 3411:
SELECT id, mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl order by mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3);

-- select mysql_extract with order by index (result)
--Testcase 3412:
SELECT id, mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl order by 4,3,2,1;

-- select mysql_extract with order by index (result)
--Testcase 3413:
SELECT id, mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl order by 1,2,3,4;

-- select mysql_extract with group by (explain)
--Testcase 3414:
EXPLAIN VERBOSE
SELECT max(c3), mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl group by mysql_extract('DAY_MINUTE', c3),c2;

-- select mysql_extract with group by (result)
--Testcase 3415:
SELECT max(c3), mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl group by mysql_extract('DAY_MINUTE', c3),c2;

-- select mysql_extract with group by index (result)
--Testcase 3416:
SELECT id, mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl group by 4,3,2,1;

-- select mysql_extract with group by index (result)
--Testcase 3417:
SELECT id, mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3) FROM time_tbl group by 1,2,3,4;

-- select mysql_extract with group by index having (result)
--Testcase 3418:
SELECT id, mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3), c2 FROM time_tbl group by 5, 4, 3, 2, 1 HAVING mysql_extract('YEAR', c2) > 2000;

-- select mysql_extract with group by index having (result)
--Testcase 3419:
SELECT id, mysql_extract('YEAR', c2), mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp), mysql_extract('DAY_MINUTE', c3), c2 FROM time_tbl group by 1, 2, 3, 4, 5 HAVING mysql_extract('YEAR', c2) > 2000;

-- select mysql_extract and as
--Testcase 3420:
SELECT mysql_extract('YEAR', c2) as mysql_extract1, mysql_extract('MICROSECOND', '2021-01-03 12:10:30.123456'::timestamp) as mysql_extract2, mysql_extract('DAY_MINUTE', c3) as mysql_extract3 FROM time_tbl;



-- DAYOFYEAR()
-- select dayofyear (stub function, explain)
--Testcase 3421:
EXPLAIN VERBOSE
SELECT dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl;

-- select dayofyear (stub function, result)
--Testcase 3422:
SELECT dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl;

-- select dayofyear (stub function, not pushdown constraints, explain)
--Testcase 3423:
EXPLAIN VERBOSE
SELECT dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl WHERE to_hex(id) = '1';

-- select dayofyear (stub function, not pushdown constraints, result)
--Testcase 3424:
SELECT dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl WHERE to_hex(id) = '1';

-- select dayofyear (stub function, pushdown constraints, explain)
--Testcase 3425:
EXPLAIN VERBOSE
SELECT dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl WHERE id != 200;

-- select dayofyear (stub function, pushdown constraints, result)
--Testcase 3426:
SELECT dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl WHERE id != 200;

-- select dayofyear (stub function, dayofyear in constraints, explain)
--Testcase 3427:
EXPLAIN VERBOSE
SELECT dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl WHERE dayofyear(c2) != dayofyear('2000-01-01'::date);

-- select dayofyear (stub function, dayofyear in constraints, result)
--Testcase 3428:
SELECT dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl WHERE dayofyear(c2) != dayofyear('2000-01-01'::date);

-- select dayofyear (stub function, dayofyear in constraints, explain)
--Testcase 3429:
EXPLAIN VERBOSE
SELECT dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl WHERE dayofyear('2021-01-01 12:00:00'::date) > 0;

-- select dayofyear (stub function, dayofyear in constraints, result)
--Testcase 3430:
SELECT dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl WHERE dayofyear('2021-01-01 12:00:00'::date) > 0;

-- select dayofyear with agg (pushdown, explain)
--Testcase 3431:
EXPLAIN VERBOSE
SELECT max(c2), dayofyear(max(c2)) FROM time_tbl;

-- select dayofyear as nest function with agg (pushdown, result)
--Testcase 3432:
SELECT max(c2), dayofyear(max(c2)) FROM time_tbl;

-- select dayofyear with non pushdown func and explicit constant (explain)
--Testcase 3433:
EXPLAIN VERBOSE
SELECT dayofyear(c2), dayofyear('2021-01-01'::date), pi(), 4.1 FROM time_tbl;

-- select dayofyear with non pushdown func and explicit constant (result)
--Testcase 3434:
SELECT dayofyear(c2), dayofyear('2021-01-01'::date), pi(), 4.1 FROM time_tbl;

-- select dayofyear with order by (explain)
--Testcase 3435:
EXPLAIN VERBOSE
SELECT id, dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl order by dayofyear(c2), dayofyear('2021-01-01'::date);

-- select dayofyear with order by (result)
--Testcase 3436:
SELECT id, dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl order by dayofyear(c2), dayofyear('2021-01-01'::date);

-- select dayofyear with order by index (result)
--Testcase 3437:
SELECT id, dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl order by 3,2,1;

-- select dayofyear with order by index (result)
--Testcase 3438:
SELECT id, dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl order by 1,2,3;

-- select dayofyear with group by (explain)
--Testcase 3439:
EXPLAIN VERBOSE
SELECT max(c3), dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl group by dayofyear(c2);

-- select dayofyear with group by (result)
--Testcase 3440:
SELECT max(c3), dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl group by dayofyear(c2);

-- select dayofyear with group by index (result)
--Testcase 3441:
SELECT id, dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl group by 3,2,1;

-- select dayofyear with group by index (result)
--Testcase 3442:
SELECT id, dayofyear(c2), dayofyear('2021-01-01'::date) FROM time_tbl group by 1,2,3;

-- select dayofyear with group by index having (result)
--Testcase 3443:
SELECT id, dayofyear(c2), dayofyear('2021-01-01'::date), c2 FROM time_tbl group by 4, 3, 2, 1 HAVING dayofyear(c2) > 0;

-- select dayofyear with group by index having (result)
--Testcase 3444:
SELECT id, dayofyear(c2), dayofyear('2021-01-01'::date), c2 FROM time_tbl group by 1, 2, 3, 4 HAVING dayofyear(c2) > 0;

-- select dayofyear and as
--Testcase 3445:
SELECT dayofyear(c2) as dayofyear1, dayofyear('2021-01-01'::date) as dayofyear2 FROM time_tbl;



-- DAYOFWEEK()
-- select dayofweek (stub function, explain)
--Testcase 3446:
EXPLAIN VERBOSE
SELECT dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl;

-- select dayofweek (stub function, result)
--Testcase 3447:
SELECT dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl;

-- select dayofweek (stub function, not pushdown constraints, explain)
--Testcase 3448:
EXPLAIN VERBOSE
SELECT dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl WHERE to_hex(id) = '1';

-- select dayofweek (stub function, not pushdown constraints, result)
--Testcase 3449:
SELECT dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl WHERE to_hex(id) = '1';

-- select dayofweek (stub function, pushdown constraints, explain)
--Testcase 3450:
EXPLAIN VERBOSE
SELECT dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl WHERE id != 200;

-- select dayofweek (stub function, pushdown constraints, result)
--Testcase 3451:
SELECT dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl WHERE id != 200;

-- select dayofweek (stub function, dayofweek in constraints, explain)
--Testcase 3452:
EXPLAIN VERBOSE
SELECT dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl WHERE dayofweek(c2) != dayofweek('2000-01-01'::date);

-- select dayofweek (stub function, dayofweek in constraints, result)
--Testcase 3453:
SELECT dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl WHERE dayofweek(c2) != dayofweek('2000-01-01'::date);

-- select dayofweek (stub function, dayofweek in constraints, explain)
--Testcase 3454:
EXPLAIN VERBOSE
SELECT dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl WHERE dayofweek('2021-01-01 12:00:00'::date) > 0;

-- select dayofweek (stub function, dayofweek in constraints, result)
--Testcase 3455:
SELECT dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl WHERE dayofweek('2021-01-01 12:00:00'::date) > 0;

-- select dayofweek with agg (pushdown, explain)
--Testcase 3456:
EXPLAIN VERBOSE
SELECT max(c2), dayofweek(max(c2)) FROM time_tbl;

-- select dayofweek as nest function with agg (pushdown, result)
--Testcase 3457:
SELECT max(c2), dayofweek(max(c2)) FROM time_tbl;

-- select dayofweek with non pushdown func and explicit constant (explain)
--Testcase 3458:
EXPLAIN VERBOSE
SELECT dayofweek(c2), dayofweek('2021-01-01'::date), pi(), 4.1 FROM time_tbl;

-- select dayofweek with non pushdown func and explicit constant (result)
--Testcase 3459:
SELECT dayofweek(c2), dayofweek('2021-01-01'::date), pi(), 4.1 FROM time_tbl;

-- select dayofweek with order by (explain)
--Testcase 3460:
EXPLAIN VERBOSE
SELECT id, dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl order by dayofweek(c2), dayofweek('2021-01-01'::date);

-- select dayofweek with order by (result)
--Testcase 3461:
SELECT id, dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl order by dayofweek(c2), dayofweek('2021-01-01'::date);

-- select dayofweek with order by index (result)
--Testcase 3462:
SELECT id, dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl order by 3,2,1;

-- select dayofweek with order by index (result)
--Testcase 3463:
SELECT id, dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl order by 1,2,3;

-- select dayofweek with group by (explain)
--Testcase 3464:
EXPLAIN VERBOSE
SELECT max(c3), dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl group by dayofweek(c2);

-- select dayofweek with group by (result)
--Testcase 3465:
SELECT max(c3), dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl group by dayofweek(c2);

-- select dayofweek with group by index (result)
--Testcase 3466:
SELECT id, dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl group by 3,2,1;

-- select dayofweek with group by index (result)
--Testcase 3467:
SELECT id, dayofweek(c2), dayofweek('2021-01-01'::date) FROM time_tbl group by 1,2,3;

-- select dayofweek with group by index having (result)
--Testcase 3468:
SELECT id, dayofweek(c2), dayofweek('2021-01-01'::date), c2 FROM time_tbl group by 4, 3, 2, 1 HAVING dayofweek(c2) > 0;

-- select dayofweek with group by index having (result)
--Testcase 3469:
SELECT id, dayofweek(c2), dayofweek('2021-01-01'::date), c2 FROM time_tbl group by 1, 2, 3, 4 HAVING dayofweek(c2) > 0;

-- select dayofweek and as
--Testcase 3470:
SELECT dayofweek(c2) as dayofweek1, dayofweek('2021-01-01'::date) as dayofweek2 FROM time_tbl;



-- DAYOFMONTH()
-- select dayofmonth (stub function, explain)
--Testcase 3471:
EXPLAIN VERBOSE
SELECT dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl;

-- select dayofmonth (stub function, result)
--Testcase 3472:
SELECT dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl;

-- select dayofmonth (stub function, not pushdown constraints, explain)
--Testcase 3473:
EXPLAIN VERBOSE
SELECT dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl WHERE to_hex(id) = '1';

-- select dayofmonth (stub function, not pushdown constraints, result)
--Testcase 3474:
SELECT dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl WHERE to_hex(id) = '1';

-- select dayofmonth (stub function, pushdown constraints, explain)
--Testcase 3475:
EXPLAIN VERBOSE
SELECT dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl WHERE id != 200;

-- select dayofmonth (stub function, pushdown constraints, result)
--Testcase 3476:
SELECT dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl WHERE id != 200;

-- select dayofmonth (stub function, dayofmonth in constraints, explain)
--Testcase 3477:
EXPLAIN VERBOSE
SELECT dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl WHERE dayofmonth(c2) != dayofmonth('2000-01-01'::date);

-- select dayofmonth (stub function, dayofmonth in constraints, result)
--Testcase 3478:
SELECT dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl WHERE dayofmonth(c2) != dayofmonth('2000-01-01'::date);

-- select dayofmonth (stub function, dayofmonth in constraints, explain)
--Testcase 3479:
EXPLAIN VERBOSE
SELECT dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl WHERE dayofmonth('2021-01-01 12:00:00'::date) > 0;

-- select dayofmonth (stub function, dayofmonth in constraints, result)
--Testcase 3480:
SELECT dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl WHERE dayofmonth('2021-01-01 12:00:00'::date) > 0;

-- select dayofmonth with agg (pushdown, explain)
--Testcase 3481:
EXPLAIN VERBOSE
SELECT max(c2), dayofmonth(max(c2)) FROM time_tbl;

-- select dayofmonth as nest function with agg (pushdown, result)
--Testcase 3482:
SELECT max(c2), dayofmonth(max(c2)) FROM time_tbl;

-- select dayofmonth with non pushdown func and explicit constant (explain)
--Testcase 3483:
EXPLAIN VERBOSE
SELECT dayofmonth(c2), dayofmonth('2021-01-01'::date), pi(), 4.1 FROM time_tbl;

-- select dayofmonth with non pushdown func and explicit constant (result)
--Testcase 3484:
SELECT dayofmonth(c2), dayofmonth('2021-01-01'::date), pi(), 4.1 FROM time_tbl;

-- select dayofmonth with order by (explain)
--Testcase 3485:
EXPLAIN VERBOSE
SELECT id, dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl order by dayofmonth(c2), dayofmonth('2021-01-01'::date);

-- select dayofmonth with order by (result)
--Testcase 3486:
SELECT id, dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl order by dayofmonth(c2), dayofmonth('2021-01-01'::date);

-- select dayofmonth with order by index (result)
--Testcase 3487:
SELECT id, dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl order by 3,2,1;

-- select dayofmonth with order by index (result)
--Testcase 3488:
SELECT id, dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl order by 1,2,3;

-- select dayofmonth with group by (explain)
--Testcase 3489:
EXPLAIN VERBOSE
SELECT max(c3), dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl group by dayofmonth(c2);

-- select dayofmonth with group by (result)
--Testcase 3490:
SELECT max(c3), dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl group by dayofmonth(c2);

-- select dayofmonth with group by index (result)
--Testcase 3491:
SELECT id, dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl group by 3,2,1;

-- select dayofmonth with group by index (result)
--Testcase 3492:
SELECT id, dayofmonth(c2), dayofmonth('2021-01-01'::date) FROM time_tbl group by 1,2,3;

-- select dayofmonth with group by index having (result)
--Testcase 3493:
SELECT id, dayofmonth(c2), dayofmonth('2021-01-01'::date), c2 FROM time_tbl group by 4, 3, 2, 1 HAVING dayofmonth(c2) > 0;

-- select dayofmonth with group by index having (result)
--Testcase 3494:
SELECT id, dayofmonth(c2), dayofmonth('2021-01-01'::date), c2 FROM time_tbl group by 1, 2, 3, 4 HAVING dayofmonth(c2) > 0;

-- select dayofmonth and as
--Testcase 3495:
SELECT dayofmonth(c2) as dayofmonth1, dayofmonth('2021-01-01'::date) as dayofmonth2 FROM time_tbl;



-- DAYNAME()
-- select dayname (stub function, explain)
--Testcase 3496:
EXPLAIN VERBOSE
SELECT dayname(c2), dayname('2021-01-01'::date) FROM time_tbl;

-- select dayname (stub function, result)
--Testcase 3497:
SELECT dayname(c2), dayname('2021-01-01'::date) FROM time_tbl;

-- select dayname (stub function, not pushdown constraints, explain)
--Testcase 3498:
EXPLAIN VERBOSE
SELECT dayname(c2), dayname('2021-01-01'::date) FROM time_tbl WHERE to_hex(id) = '1';

-- select dayname (stub function, not pushdown constraints, result)
--Testcase 3499:
SELECT dayname(c2), dayname('2021-01-01'::date) FROM time_tbl WHERE to_hex(id) = '1';

-- select dayname (stub function, pushdown constraints, explain)
--Testcase 3500:
EXPLAIN VERBOSE
SELECT dayname(c2), dayname('2021-01-01'::date) FROM time_tbl WHERE id != 200;

-- select dayname (stub function, pushdown constraints, result)
--Testcase 3501:
SELECT dayname(c2), dayname('2021-01-01'::date) FROM time_tbl WHERE id != 200;

-- select dayname (stub function, dayname in constraints, explain)
--Testcase 3502:
EXPLAIN VERBOSE
SELECT dayname(c2), dayname('2021-01-01'::date) FROM time_tbl WHERE dayname(c2) != dayname('2000-01-01'::date);

-- select dayname (stub function, dayname in constraints, result)
--Testcase 3503:
SELECT dayname(c2), dayname('2021-01-01'::date) FROM time_tbl WHERE dayname(c2) != dayname('2000-01-01'::date);

-- select dayname (stub function, dayname in constraints, explain)
--Testcase 3504:
EXPLAIN VERBOSE
SELECT dayname(c2), dayname('2021-01-01'::date) FROM time_tbl WHERE dayname('2021-01-01 12:00:00'::date) = 'Friday';

-- select dayname (stub function, dayname in constraints, result)
--Testcase 3505:
SELECT dayname(c2), dayname('2021-01-01'::date) FROM time_tbl WHERE dayname('2021-01-01 12:00:00'::date) > 'Friday';

-- select dayname with agg (pushdown, explain)
--Testcase 3506:
EXPLAIN VERBOSE
SELECT max(c2), dayname(max(c2)) FROM time_tbl;

-- select dayname as nest function with agg (pushdown, result)
--Testcase 3507:
SELECT max(c2), dayname(max(c2)) FROM time_tbl;

-- select dayname with non pushdown func and explicit constant (explain)
--Testcase 3508:
EXPLAIN VERBOSE
SELECT dayname(c2), dayname('2021-01-01'::date), pi(), 4.1 FROM time_tbl;

-- select dayname with non pushdown func and explicit constant (result)
--Testcase 3509:
SELECT dayname(c2), dayname('2021-01-01'::date), pi(), 4.1 FROM time_tbl;

-- select dayname with order by (explain)
--Testcase 3510:
EXPLAIN VERBOSE
SELECT id, dayname(c2), dayname('2021-01-01'::date) FROM time_tbl order by dayname(c2), dayname('2021-01-01'::date);

-- select dayname with order by (result)
--Testcase 3511:
SELECT id, dayname(c2), dayname('2021-01-01'::date) FROM time_tbl order by dayname(c2), dayname('2021-01-01'::date);

-- select dayname with order by index (result)
--Testcase 3512:
SELECT id, dayname(c2), dayname('2021-01-01'::date) FROM time_tbl order by 3,2,1;

-- select dayname with order by index (result)
--Testcase 3513:
SELECT id, dayname(c2), dayname('2021-01-01'::date) FROM time_tbl order by 1,2,3;

-- select dayname with group by (explain)
--Testcase 3514:
EXPLAIN VERBOSE
SELECT max(c3), dayname(c2), dayname('2021-01-01'::date) FROM time_tbl group by dayname(c2);

-- select dayname with group by (result)
--Testcase 3515:
SELECT max(c3), dayname(c2), dayname('2021-01-01'::date) FROM time_tbl group by dayname(c2);

-- select dayname with group by index (result)
--Testcase 3516:
SELECT id, dayname(c2), dayname('2021-01-01'::date) FROM time_tbl group by 3,2,1;

-- select dayname with group by index (result)
--Testcase 3517:
SELECT id, dayname(c2), dayname('2021-01-01'::date) FROM time_tbl group by 1,2,3;

-- select dayname with group by index having (result)
--Testcase 3518:
SELECT id, dayname(c2), dayname('2021-01-01'::date), c2 FROM time_tbl group by 4, 3, 2, 1 HAVING dayname(c2) = 'Friday';

-- select dayname with group by index having (result)
--Testcase 3519:
SELECT id, dayname(c2), dayname('2021-01-01'::date), c2 FROM time_tbl group by 1, 2, 3, 4 HAVING dayname(c2) > 'Friday';

-- select dayname and as
--Testcase 3520:
SELECT dayname(c2) as dayname1, dayname('2021-01-01'::date) as dayname2 FROM time_tbl;



-- DAY()
-- select day (stub function, explain)
--Testcase 3521:
EXPLAIN VERBOSE
SELECT day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl;

-- select day (stub function, result)
--Testcase 3522:
SELECT day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl;

-- select day (stub function, not pushdown constraints, explain)
--Testcase 3523:
EXPLAIN VERBOSE
SELECT day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select day (stub function, not pushdown constraints, result)
--Testcase 3524:
SELECT day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl WHERE to_hex(id) = '1';

-- select day (stub function, pushdown constraints, explain)
--Testcase 3525:
EXPLAIN VERBOSE
SELECT day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl WHERE id != 200;

-- select day (stub function, pushdown constraints, result)
--Testcase 3526:
SELECT day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl WHERE id != 200;

-- select day (stub function, day in constraints, explain)
--Testcase 3527:
EXPLAIN VERBOSE
SELECT day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl WHERE day(c2) != day('2000-01-01'::date);

-- select day (stub function, day in constraints, result)
--Testcase 3528:
SELECT day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl WHERE day(c2) != day('2000-01-01'::date);

-- select day (stub function, day in constraints, explain)
--Testcase 3529:
EXPLAIN VERBOSE
SELECT day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl WHERE day('2021-01-01 12:00:00'::date) > 0;

-- select day (stub function, day in constraints, result)
--Testcase 3530:
SELECT day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl WHERE day('2021-01-01 12:00:00'::date) > 0;

-- select day with agg (pushdown, explain)
--Testcase 3531:
EXPLAIN VERBOSE
SELECT max(c2), day(max(c2)) FROM time_tbl;

-- select day as nest function with agg (pushdown, result)
--Testcase 3532:
SELECT max(c2), day(max(c2)) FROM time_tbl;

-- select day with non pushdown func and explicit constant (explain)
--Testcase 3533:
EXPLAIN VERBOSE
SELECT day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp), pi(), 4.1 FROM time_tbl;

-- select day with non pushdown func and explicit constant (result)
--Testcase 3534:
SELECT day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp), pi(), 4.1 FROM time_tbl;

-- select day with order by (explain)
--Testcase 3535:
EXPLAIN VERBOSE
SELECT id, day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl order by day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp);

-- select day with order by (result)
--Testcase 3536:
SELECT id, day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl order by day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp);

-- select day with order by index (result)
--Testcase 3537:
SELECT id, day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl order by 5,4,3,2,1;

-- select day with order by index (result)
--Testcase 3538:
SELECT id, day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl order by 1,2,3,4,5;

-- select day with group by (explain)
--Testcase 3539:
EXPLAIN VERBOSE
SELECT max(c3), day(c2), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl group by day(c2), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp);

-- select day with group by (result)
--Testcase 3540:
SELECT max(c3), day(c2), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl group by day(c2);

-- select day with group by index (result)
--Testcase 3541:
SELECT id, day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl group by 5,4,3,2,1;

-- select day with group by index (result)
--Testcase 3542:
SELECT id, day(c2), day(c3), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp) FROM time_tbl group by 1,2,3,4,5;

-- select day with group by index having (result)
--Testcase 3543:
SELECT id, day(c2), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp), c2 FROM time_tbl group by 5,4,3,2,1 HAVING day(c2) > 0;

-- select day with group by index having (result)
--Testcase 3544:
SELECT id, day(c2), day('2021-01-01'::date), day('1997-01-31 12:00:00'::timestamp), c2 FROM time_tbl group by 1,2,3,4,5 HAVING day(c2) > 0;

-- select day and as
--Testcase 3545:
SELECT day(c2) as day1, day(c3) as day2, day('2021-01-01'::date) as day3, day('1997-01-31 12:00:00'::timestamp) as day4 FROM time_tbl;



--Testcase 3546:
DROP FOREIGN TABLE time_tbl;

-- JSON functions
--Testcase 3547:
CREATE FOREIGN TABLE s8(id int, c1 json, c2 int, c3 text) SERVER server1 OPTIONS(dbname 'mysql_fdw_regress', table_name 's8');
--Testcase 3548:
CREATE FOREIGN TABLE s9(id int, c1 json) SERVER server1 OPTIONS(dbname 'mysql_fdw_regress', table_name 's9');

--Testcase 3549:
SELECT * FROM s8;
--Testcase 3550:
SELECT * FROM s9;

-- select json_build_array (builtin function, explain)
--Testcase 3551:
EXPLAIN VERBOSE
SELECT json_build_array(c1, c2), json_build_array(c1, c3), json_build_array(c1, 1), json_build_array(c1, 'a'), json_build_array(c1, mysql_pi()) FROM s8;

-- select json_build_array (builtin function, result)
--Testcase 3552:
SELECT json_build_array(c1, c2), json_build_array(c1, c3), json_build_array(c1, 1), json_build_array(c1, 'a'), json_build_array(c1, mysql_pi()) FROM s8;

-- select json_build_array (builtin function, not pushdown constraints, explain)
--Testcase 3553:
EXPLAIN VERBOSE
SELECT json_build_array(c1, c2), json_build_array(c1, c3), json_build_array(c1, NULL), json_build_array(c1, TRUE), json_build_array(c1, mysql_pi()) FROM s8 WHERE to_hex(id) = '1';

-- select json_build_array (builtin function, not pushdown constraints, result)
--Testcase 3554:
SELECT json_build_array(c1, c2), json_build_array(c1, c3), json_build_array(c1, NULL), json_build_array(c1, TRUE), json_build_array(c1, mysql_pi()) FROM s8 WHERE to_hex(id) = '1';

-- select json_build_array (builtin function, pushdown constraints, explain)
--Testcase 3555:
EXPLAIN VERBOSE
SELECT json_build_array(c1, c2), json_build_array(c1, c3), json_build_array(c1, 1), json_build_array(c1, 'a'), json_build_array(c1, '[true, false]'::json) FROM s8 WHERE id = 1;

-- select json_build_array (builtin function, pushdown constraints, result)
--Testcase 3556:
SELECT json_build_array(c1, c2), json_build_array(c1, c3), json_build_array(c1, 1), json_build_array(c1, 'a'), json_build_array(c1, '[true, false]'::json) FROM s8 WHERE id = 1;

-- select json_build_array (builtin function, builtin in constraints, explain)
--Testcase 3557:
EXPLAIN VERBOSE
SELECT json_build_array(c1, c2), json_build_array(c1, c3), json_build_array(c1, NULL), json_build_array(c1, TRUE), json_build_array(c1, '[true, false]') FROM s8 WHERE json_length(json_build_array(c1, c2)) > 1;

-- select json_build_array (builtin function, builtin in constraints, result)
--Testcase 3558:
SELECT json_build_array(c1, c2), json_build_array(c1, c3), json_build_array(c1, NULL), json_build_array(c1, TRUE), json_build_array(c1, '[true, false]') FROM s8 WHERE json_length(json_build_array(c1, c2)) > 1;

-- select json_build_array (builtin function, builtin in constraints, explain)
--Testcase 3559:
EXPLAIN VERBOSE
SELECT json_build_array(c1, c2), json_build_array(c1, c3), json_build_array(c1, 1), json_build_array(c1, 'a'), json_build_array(c1, mysql_pi()) FROM s8 WHERE json_length(json_build_array(c1, c2)) > id;

-- select json_build_array (builtin function, builtin in constraints, result)
--Testcase 3560:
SELECT json_build_array(c1, c2), json_build_array(c1, c3), json_build_array(c1, 1), json_build_array(c1, 'a'), json_build_array(c1, mysql_pi()) FROM s8 WHERE json_length(json_build_array(c1, c2)) > id;

-- select json_build_array as nest function with agg (pushdown, explain)
--Testcase 3561:
EXPLAIN VERBOSE
SELECT sum(id),json_build_array('["a", ["b", "c"], "d"]',  sum(id)) FROM s8;

-- select json_build_array as nest function with agg (pushdown, result)
--Testcase 3562:
SELECT sum(id),json_build_array('["a", ["b", "c"], "d"]',  sum(id)) FROM s8;

-- select json_build_array with non pushdown func and explicit constant (explain)
--Testcase 3563:
EXPLAIN VERBOSE
SELECT json_build_array(c1, c2), pi(), 4.1 FROM s8;

-- select json_build_array with non pushdown func and explicit constant (result)
--Testcase 3564:
SELECT json_build_array(c1, c2), pi(), 4.1 FROM s8;

-- select json_build_array with order by (explain)
--Testcase 3565:
EXPLAIN VERBOSE
SELECT json_length(json_build_array(c1, c2)) FROM s8 ORDER BY 1;

-- select json_build_array with order by (result)
--Testcase 3566:
SELECT json_length(json_build_array(c1, c2)) FROM s8 ORDER BY 1;

-- select json_build_array with group by (explain)
--Testcase 3567:
EXPLAIN VERBOSE
SELECT json_length(json_build_array('["a", ["b", "c"], "d"]',  id)) FROM s8 GROUP BY 1;

-- select json_build_array with group by (result)
--Testcase 3568:
SELECT json_length(json_build_array('["a", ["b", "c"], "d"]',  id)) FROM s8 GROUP BY 1;

-- select json_build_array with group by having (explain)
--Testcase 3569:
EXPLAIN VERBOSE
SELECT json_length(json_build_array('["a", ["b", "c"], "d"]',  c2)), c2 FROM s8 GROUP BY 1, 2 HAVING count(c2) > 1;

-- select json_build_array with group by having (result)
--Testcase 3570:
SELECT json_length(json_build_array('["a", ["b", "c"], "d"]',  c2)), c2 FROM s8 GROUP BY 1, 2 HAVING count(c2) > 1;

-- select json_build_array and as
--Testcase 3571:
SELECT json_build_array(c1, c2) AS json_build_array1 FROM s8;

-- json_array_append
-- select json_array_append (stub function, explain)
--Testcase 3572:
EXPLAIN VERBOSE
SELECT json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()') FROM s8;

-- select json_array_append (stub function, result)
--Testcase 3573:
SELECT json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()') FROM s8;

-- select json_array_append (stub function, not pushdown constraints, explain)
--Testcase 3574:
EXPLAIN VERBOSE
SELECT json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], NULL', '$[1], TRUE', '$[1], pi()') FROM s8 WHERE to_hex(id) = '1';

-- select json_array_append (stub function, not pushdown constraints, result)
--Testcase 3575:
SELECT json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], NULL', '$[1], TRUE', '$[1], pi()') FROM s8 WHERE to_hex(id) = '1';

-- select json_array_append (stub function, pushdown constraints, explain)
--Testcase 3576:
EXPLAIN VERBOSE
SELECT json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], CAST("[true, false]" AS JSON)') FROM s8 WHERE id = 1;

-- select json_array_append (stub function, pushdown constraints, result)
--Testcase 3577:
SELECT json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], CAST("[true, false]" AS JSON)') FROM s8 WHERE id = 1;

-- select json_array_append (stub function, stub in constraints, explain)
--Testcase 3578:
EXPLAIN VERBOSE
SELECT json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], NULL', '$[1], TRUE', '$[1], "[true, false]"') FROM s8 WHERE log2(id) > 1;

-- select json_array_append (stub function, stub in constraints, result)
--Testcase 3579:
SELECT json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], NULL', '$[1], TRUE', '$[1], "[true, false]"') FROM s8 WHERE log2(id) > 1;

-- select json_array_append (stub function, stub in constraints, explain)
--Testcase 3580:
EXPLAIN VERBOSE
SELECT json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()') FROM s8 WHERE json_depth(json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()')) > 0;

-- select json_array_append (stub function, stub in constraints, result)
--Testcase 3581:
SELECT json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()') FROM s8 WHERE json_depth(json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()')) > 0;

-- json_array_append with 1 arg explain
--Testcase 3582:
EXPLAIN VERBOSE
SELECT json_array_append(c1, '$[1], c2') FROM s8;

-- json_array_append with 1 arg result
--Testcase 3583:
SELECT json_array_append(c1, '$[1], c2') FROM s8;

-- json_array_append with 2 args explain
--Testcase 3584:
EXPLAIN VERBOSE
SELECT json_array_append(c1, '$[1], c2', '$[1], c3') FROM s8;

-- json_array_append with 2 args result
--Testcase 3585:
SELECT json_array_append(c1, '$[1], c2', '$[1], c3') FROM s8;

-- json_array_append with 3 args explain
--Testcase 3586:
EXPLAIN VERBOSE
SELECT json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1') FROM s8;

-- json_array_append with 3 args result
--Testcase 3587:
SELECT json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1') FROM s8;

-- json_array_append with 4 args explain
--Testcase 3588:
EXPLAIN VERBOSE
SELECT json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"') FROM s8;

-- json_array_append with 4 args result
--Testcase 3589:
SELECT json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"') FROM s8;

-- json_array_append with 5 args explain
--Testcase 3590:
EXPLAIN VERBOSE
SELECT json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()') FROM s8;

-- json_array_append with 5 args result
--Testcase 3591:
SELECT json_array_append(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()') FROM s8;

-- select json_array_append as nest function with agg (pushdown, explain)
--Testcase 3592:
EXPLAIN VERBOSE
SELECT sum(id),json_array_append('["a", ["b", "c"], "d"]', '$[1], sum(id)') FROM s8;

-- select json_array_append as nest function with agg (pushdown, result)
--Testcase 3593:
SELECT sum(id),json_array_append('["a", ["b", "c"], "d"]', '$[1], sum(id)') FROM s8;

-- select json_array_append as nest function with json_build_array (pushdown, explain)
--Testcase 3594:
EXPLAIN VERBOSE
SELECT json_array_append(json_build_array('["a", ["b", "c"], "d"]', c1), '$[1], log2(id)') FROM s8;

-- select json_array_append as nest function with agg (pushdown, result)
--Testcase 3595:
SELECT json_array_append(json_build_array('["a", ["b", "c"], "d"]', c1), '$[1], log2(id)') FROM s8;

-- select json_array_append with non pushdown func and explicit constant (explain)
--Testcase 3596:
EXPLAIN VERBOSE
SELECT json_array_append(c1, '$[1], c2'), pi(), 4.1 FROM s8;

-- select json_array_append with non pushdown func and explicit constant (result)
--Testcase 3597:
SELECT json_array_append(c1, '$[1], c2'), pi(), 4.1 FROM s8;

-- select json_array_append with order by (explain)
--Testcase 3598:
EXPLAIN VERBOSE
SELECT json_length(json_array_append(c1, '$[1], c2')) FROM s8 ORDER BY 1;

-- select json_array_append with order by (result)
--Testcase 3599:
SELECT json_length(json_array_append(c1, '$[1], c2')) FROM s8 ORDER BY 1;

-- select json_array_append with group by (explain)
--Testcase 3600:
EXPLAIN VERBOSE
SELECT json_length(json_array_append('["a", ["b", "c"], "d"]', '$[1], id')) FROM s8 GROUP BY 1;

-- select json_array_append with group by (result)
--Testcase 3601:
SELECT json_length(json_array_append('["a", ["b", "c"], "d"]', '$[1], id')) FROM s8 GROUP BY 1;

-- select json_array_append with group by having (explain)
--Testcase 3602:
EXPLAIN VERBOSE
SELECT json_depth(json_array_append('["a", ["b", "c"], "d"]', '$[1], c2')) FROM s8 GROUP BY c2, 1 HAVING count(c2) > 1;

-- select json_array_append with group by having (result)
--Testcase 3603:
SELECT json_depth(json_array_append('["a", ["b", "c"], "d"]', '$[1], c2')) FROM s8 GROUP BY c2, 1 HAVING count(c2) > 1;

-- select json_array_append and as
--Testcase 3604:
SELECT json_array_append(c1, '$[1], c2') AS json_array_append1 FROM s8;

-- json_array_insert

-- select json_array_insert (stub function, explain)
--Testcase 3605:
EXPLAIN VERBOSE
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()') FROM s8;

-- select json_array_insert (stub function, result)
--Testcase 3606:
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()') FROM s8;

-- select json_array_insert (stub function, not pushdown constraints, explain)
--Testcase 3607:
EXPLAIN VERBOSE
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], NULL', '$[1], TRUE', '$[1], pi()') FROM s8 WHERE to_hex(id) = '1';

-- select json_array_insert (stub function, not pushdown constraints, result)
--Testcase 3608:
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], NULL', '$[1], TRUE', '$[1], pi()') FROM s8 WHERE to_hex(id) = '1';

-- select json_array_insert (stub function, pushdown constraints, explain)
--Testcase 3609:
EXPLAIN VERBOSE
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], CAST("[true, false]" AS JSON)') FROM s8 WHERE id = 1;

-- select json_array_insert (stub function, pushdown constraints, result)
--Testcase 3610:
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], CAST("[true, false]" AS JSON)') FROM s8 WHERE id = 1;

-- select json_array_insert (stub function, stub in constraints, explain)
--Testcase 3611:
EXPLAIN VERBOSE
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], NULL', '$[1], TRUE', '$[1], "[true, false]"') FROM s8 WHERE log2(id) > 1;

-- select json_array_insert (stub function, stub in constraints, result)
--Testcase 3612:
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], NULL', '$[1], TRUE', '$[1], "[true, false]"') FROM s8 WHERE log2(id) > 1;

-- select json_array_insert (stub function, stub in constraints, explain)
--Testcase 3613:
EXPLAIN VERBOSE
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()') FROM s8 WHERE json_depth(json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()')) > 0;

-- select json_array_insert (stub function, stub in constraints, result)
--Testcase 3614:
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()') FROM s8 WHERE json_depth(json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()')) > 0;

-- json_array_insert with 1 arg explain
--Testcase 3615:
EXPLAIN VERBOSE
SELECT json_array_insert(c1, '$[1], c2') FROM s8;

-- json_array_insert with 1 arg result
--Testcase 3616:
SELECT json_array_insert(c1, '$[1], c2') FROM s8;

-- json_array_insert with 2 args explain
--Testcase 3617:
EXPLAIN VERBOSE
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3') FROM s8;

-- json_array_insert with 2 args result
--Testcase 3618:
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3') FROM s8;

-- json_array_insert with 3 args explain
--Testcase 3619:
EXPLAIN VERBOSE
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1') FROM s8;

-- json_array_insert with 3 args result
--Testcase 3620:
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1') FROM s8;

-- json_array_insert with 4 args explain
--Testcase 3621:
EXPLAIN VERBOSE
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"') FROM s8;

-- json_array_insert with 4 args result
--Testcase 3622:
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"') FROM s8;

-- json_array_insert with 5 args explain
--Testcase 3623:
EXPLAIN VERBOSE
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()') FROM s8;

-- json_array_insert with 5 args result
--Testcase 3624:
SELECT json_array_insert(c1, '$[1], c2', '$[1], c3', '$[1], 1', '$[1], "a"', '$[1], pi()') FROM s8;

-- select json_array_insert as nest function with agg (pushdown, explain)
--Testcase 3625:
EXPLAIN VERBOSE
SELECT sum(id),json_array_insert('["a", ["b", "c"], "d"]', '$[1], sum(id)') FROM s8;

-- select json_array_insert as nest function with agg (pushdown, result)
--Testcase 3626:
SELECT sum(id),json_array_insert('["a", ["b", "c"], "d"]', '$[1], sum(id)') FROM s8;

-- select json_array_insert as nest function with json_build_array (pushdown, explain)
--Testcase 3627:
EXPLAIN VERBOSE
SELECT json_array_insert(json_build_array('["a", ["b", "c"], "d"]', c1), '$[1], log2(id)') FROM s8;

-- select json_array_insert as nest function with agg (pushdown, result)
--Testcase 3628:
SELECT json_array_insert(json_build_array('["a", ["b", "c"], "d"]', c1), '$[1], log2(id)') FROM s8;

-- select json_array_insert with non pushdown func and explicit constant (explain)
--Testcase 3629:
EXPLAIN VERBOSE
SELECT json_array_insert(c1, '$[1], c2'), pi(), 4.1 FROM s8;

-- select json_array_insert with non pushdown func and explicit constant (result)
--Testcase 3630:
SELECT json_array_insert(c1, '$[1], c2'), pi(), 4.1 FROM s8;

-- select json_array_insert with order by (explain)
--Testcase 3631:
EXPLAIN VERBOSE
SELECT json_length(json_array_insert(c1, '$[1], c2')) FROM s8 ORDER BY 1;

-- select json_array_insert with order by (result)
--Testcase 3632:
SELECT json_length(json_array_insert(c1, '$[1], c2')) FROM s8 ORDER BY 1;

-- select json_array_insert with group by (explain)
--Testcase 3633:
EXPLAIN VERBOSE
SELECT json_length(json_array_insert('["a", ["b", "c"], "d"]', '$[1], id')) FROM s8 GROUP BY id, 1;

-- select json_array_insert with group by (result)
--Testcase 3634:
SELECT json_length(json_array_insert('["a", ["b", "c"], "d"]', '$[1], id')) FROM s8 GROUP BY id, 1;

-- select json_array_insert with group by having (explain)
--Testcase 3635:
EXPLAIN VERBOSE
SELECT json_depth(json_array_insert('["a", ["b", "c"], "d"]', '$[1], c2')) FROM s8 GROUP BY c2, 1 HAVING count(c2) > 1;

-- select json_array_insert with group by having (result)
--Testcase 3636:
SELECT json_depth(json_array_insert('["a", ["b", "c"], "d"]', '$[1], c2')) FROM s8 GROUP BY c2, 1 HAVING count(c2) > 1;

-- select json_array_insert and as
--Testcase 3637:
SELECT json_array_insert(c1, '$[1], c2') AS json_array_insert1 FROM s8;

-- select  json_contains (stub function, explain)
--Testcase 3638:
EXPLAIN VERBOSE
SELECT json_contains(c1, '1', '$.a'), json_contains(c1, '{"a": 1}', '$.a'), json_contains(c1, c1, '$.a'), json_contains(c1,'1'), json_contains('{"a": 1, "b": 2, "c": {"d": 4}}','1', '$.a') FROM s8;

-- select  json_contains (stub function, result)
--Testcase 3639:
SELECT json_contains(c1, '1', '$.a'), json_contains(c1, '{"a": 1}', '$.a'), json_contains(c1, c1, '$.a'), json_contains(c1,'1'), json_contains('{"a": 1, "b": 2, "c": {"d": 4}}','1', '$.a') FROM s8;

-- select  json_contains (stub function, not pushdown constraints, explain)
--Testcase 3640:
EXPLAIN VERBOSE
SELECT json_contains(c1, '1', '$.a'), json_contains(c1, '{"a": 1}', '$.a'), json_contains(c1, c1, '$.a'), json_contains(c1,'1'), json_contains('{"a": 1, "b": 2, "c": {"d": 4}}','1', '$.a') FROM s8 WHERE to_hex(id) = '2';

-- select  json_contains (stub function, not pushdown constraints, result)
--Testcase 3641:
SELECT json_contains(c1, '1', '$.a'), json_contains(c1, '{"a": 1}', '$.a'), json_contains(c1, c1, '$.a'), json_contains(c1,'1'), json_contains('{"a": 1, "b": 2, "c": {"d": 4}}','1', '$.a') FROM s8 WHERE to_hex(id) = '2';

-- select  json_contains (stub function, pushdown constraints, explain)
--Testcase 3642:
EXPLAIN VERBOSE
SELECT json_contains(c1, '1', '$.a'), json_contains(c1, '{"a": 1}', '$.a'), json_contains(c1, c1, '$.a'), json_contains(c1,'1'), json_contains('{"a": 1, "b": 2, "c": {"d": 4}}','1', '$.a') FROM s8 WHERE id != 0;

-- select  json_contains (stub function, pushdown constraints, result)
--Testcase 3643:
SELECT json_contains(c1, '1', '$.a'), json_contains(c1, '{"a": 1}', '$.a'), json_contains(c1, c1, '$.a'), json_contains(c1,'1'), json_contains('{"a": 1, "b": 2, "c": {"d": 4}}','1', '$.a') FROM s8 WHERE id != 0;

-- select  json_contains (stub function, json_contains in constraints, explain)
--Testcase 3644:
EXPLAIN VERBOSE
SELECT json_contains(c1, '1', '$.a'), json_contains(c1, '{"a": 1}', '$.a'), json_contains(c1, c1, '$.a'), json_contains(c1,'1'), json_contains('{"a": 1, "b": 2, "c": {"d": 4}}','1', '$.a') FROM s8 WHERE json_contains(c1, '1', '$.a') != 1;

-- select  json_contains (stub function, json_contains in constraints, result)
--Testcase 3645:
SELECT json_contains(c1, '1', '$.a'), json_contains(c1, '{"a": 1}', '$.a'), json_contains(c1, c1, '$.a'), json_contains(c1,'1'), json_contains('{"a": 1, "b": 2, "c": {"d": 4}}','1', '$.a') FROM s8 WHERE json_contains(c1, '1', '$.a') != 1;

-- select  json_contains (stub function, json_contains in constraints, explain)
--Testcase 3646:
EXPLAIN VERBOSE
SELECT json_contains(c1, '1', '$.a'), json_contains(c1, '{"a": 1}', '$.a'), json_contains(c1, c1, '$.a'), json_contains(c1,'1'), json_contains('{"a": 1, "b": 2, "c": {"d": 4}}','1', '$.a') FROM s8 WHERE json_contains('{"a": 1, "b": 2, "c": {"d": 4}}','1', '$.a') = 1;

-- select  json_contains (stub function, json_contains in constraints, result)
--Testcase 3647:
SELECT json_contains(c1, '1', '$.a'), json_contains(c1, '{"a": 1}', '$.a'), json_contains(c1, c1, '$.a'), json_contains(c1,'1'), json_contains('{"a": 1, "b": 2, "c": {"d": 4}}','1', '$.a') FROM s8 WHERE json_contains('{"a": 1, "b": 2, "c": {"d": 4}}','1', '$.a') = 1;

-- select json_contains as nest function with agg (pushdown, explain)
--Testcase 3648:
EXPLAIN VERBOSE
SELECT sum(id),json_contains('{"a": 1, "b": 2, "c": {"d": 4}}', '1') FROM s8;

-- select json_contains as nest function with agg (pushdown, result)
--Testcase 3649:
SELECT sum(id),json_contains('{"a": 1, "b": 2, "c": {"d": 4}}', '1') FROM s8;

-- select json_contains with non pushdown func and explicit constant (EXPLAIN)
--Testcase 3650:
EXPLAIN VERBOSE
SELECT json_contains(c1, c1, '$.a'), pi(), 4.1 FROM s8;

-- select json_contains with non pushdown func and explicit constant (result)
--Testcase 3651:
SELECT json_contains(c1, c1, '$.a'), pi(), 4.1 FROM s8;

-- select json_contains with order by index (result)
--Testcase 3652:
SELECT id,  json_contains(c1, '1', '$.a') FROM s8 ORDER BY 2, 1;

-- select json_contains with order by index (result)
--Testcase 3653:
SELECT id,  json_contains(c1, '1', '$.a') FROM s8 ORDER BY 1, 2;

-- select json_contains with group by (EXPLAIN)
--Testcase 3654:
EXPLAIN VERBOSE
SELECT count(id), json_contains(c1, '1', '$.a') FROM s8 group by json_contains(c1, '1', '$.a');

-- select json_contains with group by (result)
--Testcase 3655:
SELECT count(id), json_contains(c1, '1', '$.a') FROM s8 group by json_contains(c1, '1', '$.a');

-- select json_contains with group by index (result)
--Testcase 3656:
SELECT id,  json_contains(c1, '1', '$.a') FROM s8 group by 2, 1;

-- select json_contains with group by index (result)
--Testcase 3657:
SELECT id,  json_contains(c1, '1', '$.a') FROM s8 group by 1, 2;

-- select json_contains with group by having (EXPLAIN)
--Testcase 3658:
EXPLAIN VERBOSE
SELECT count(c2), json_contains(c1, '1', '$.a') FROM s8 group by json_contains(c1, '1', '$.a') HAVING count(c2) > 0;

-- select json_contains with group by having (result)
--Testcase 3659:
SELECT count(c2), json_contains(c1, '1', '$.a') FROM s8 group by json_contains(c1, '1', '$.a') HAVING count(c2) > 0;

-- select json_contains with group by index having (result)
--Testcase 3660:
SELECT c2,  json_contains(c1, '1', '$.a') FROM s8 group by 2, 1 HAVING count(c2) > 0;

-- select json_contains with group by index having (result)
--Testcase 3661:
SELECT c2,  json_contains(c1, '1', '$.a') FROM s8 group by 1, 2 HAVING count(c2) > 0;

-- select json_contains and as
--Testcase 3662:
SELECT json_contains(c1, c1, '$.a') as json_contains1 FROM s8;

-- select json_contains_path (builtin function, explain)
--Testcase 3663:
EXPLAIN VERBOSE
SELECT json_contains_path(c1, 'one', '$.a', '$.e'), json_contains_path(c1, 'all', '$.a', '$.x'), json_contains_path(c1, 'all', '$.a'), json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') FROM s8;

-- select json_contains_path (builtin function, result)
--Testcase 3664:
SELECT json_contains_path(c1, 'one', '$.a', '$.e'), json_contains_path(c1, 'all', '$.a', '$.x'), json_contains_path(c1, 'all', '$.a'), json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') FROM s8;

-- select json_contains_path (builtin function, not pushdown constraints, explain)
--Testcase 3665:
EXPLAIN VERBOSE
SELECT json_contains_path(c1, 'one', '$.a', '$.e'), json_contains_path(c1, 'all', '$.a', '$.x'), json_contains_path(c1, 'all', '$.a'), json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') FROM s8 WHERE to_hex(id) = '2';

-- select json_contains_path (builtin function, not pushdown constraints, result)
--Testcase 3666:
SELECT json_contains_path(c1, 'one', '$.a', '$.e'), json_contains_path(c1, 'all', '$.a', '$.x'), json_contains_path(c1, 'all', '$.a'), json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') FROM s8 WHERE to_hex(id) = '2';

-- select json_contains_path (builtin function, pushdown constraints, explain)
--Testcase 3667:
EXPLAIN VERBOSE
SELECT json_contains_path(c1, 'one', '$.a', '$.e'), json_contains_path(c1, 'all', '$.a', '$.x'), json_contains_path(c1, 'all', '$.a'), json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') FROM s8 WHERE id != 0;

-- select json_contains_path (builtin function, pushdown constraints, result)
--Testcase 3668:
SELECT json_contains_path(c1, 'one', '$.a', '$.e'), json_contains_path(c1, 'all', '$.a', '$.x'), json_contains_path(c1, 'all', '$.a'), json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') FROM s8 WHERE id != 0;

-- select json_contains_path (builtin function, json_contains_path in constraints, explain)
--Testcase 3669:
EXPLAIN VERBOSE
SELECT json_contains_path(c1, 'one', '$.a', '$.e'), json_contains_path(c1, 'all', '$.a', '$.x'), json_contains_path(c1, 'all', '$.a'), json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') FROM s8 WHERE json_contains_path(c1, 'one', '$.a', '$.e') != 0;

-- select json_contains_path (builtin function, json_contains_path in constraints, result)
--Testcase 3670:
SELECT json_contains_path(c1, 'one', '$.a', '$.e'), json_contains_path(c1, 'all', '$.a', '$.x'), json_contains_path(c1, 'all', '$.a'), json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') FROM s8 WHERE json_contains_path(c1, 'one', '$.a', '$.e') != 0;

-- select json_contains_path (builtin function, json_contains_path in constraints, explain)
--Testcase 3671:
EXPLAIN VERBOSE
SELECT json_contains_path(c1, 'one', '$.a', '$.e'), json_contains_path(c1, 'all', '$.a', '$.x'), json_contains_path(c1, 'all', '$.a'), json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') FROM s8 WHERE json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') = 1;

-- select json_contains_path (builtin function, json_contains_path in constraints, result)
--Testcase 3672:
SELECT json_contains_path(c1, 'one', '$.a', '$.e'), json_contains_path(c1, 'all', '$.a', '$.x'), json_contains_path(c1, 'all', '$.a'), json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') FROM s8 WHERE json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') = 1;

-- select json_contains_path as nest function with agg (pushdown, explain)
--Testcase 3673:
EXPLAIN VERBOSE
SELECT sum(id),json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') FROM s8;

-- select json_contains_path as nest function with agg (pushdown, result)
--Testcase 3674:
SELECT sum(id),json_contains_path('{"a": 1, "b": 2, "c": {"d": 4}}', 'one', '$.c.d') FROM s8;

-- select json_contains_path with non pushdown func and explicit constant (EXPLAIN)
--Testcase 3675:
EXPLAIN VERBOSE
SELECT json_contains_path(c1, 'all', '$.a'), pi(), 4.1 FROM s8;

-- select json_contains_path with non pushdown func and explicit constant (result)
--Testcase 3676:
SELECT json_contains_path(c1, 'all', '$.a'), pi(), 4.1 FROM s8;

-- select json_contains_path with order by index (result)
--Testcase 3677:
SELECT id,  json_contains_path(c1, 'one', '$.a', '$.e') FROM s8 ORDER BY 2, 1;

-- select json_contains_path with order by index (result)
--Testcase 3678:
SELECT id,  json_contains_path(c1, 'one', '$.a', '$.e') FROM s8 ORDER BY 1, 2;

-- select json_contains_path with group by (EXPLAIN)
--Testcase 3679:
EXPLAIN VERBOSE
SELECT count(id), json_contains_path(c1, 'one', '$.a', '$.e') FROM s8 group by json_contains_path(c1, 'one', '$.a', '$.e');

-- select json_contains_path with group by (result)
--Testcase 3680:
SELECT count(id), json_contains_path(c1, 'one', '$.a', '$.e') FROM s8 group by json_contains_path(c1, 'one', '$.a', '$.e');

-- select json_contains_path with group by index (result)
--Testcase 3681:
SELECT id,  json_contains_path(c1, 'one', '$.a', '$.e') FROM s8 group by 2, 1;

-- select json_contains_path with group by index (result)
--Testcase 3682:
SELECT id,  json_contains_path(c1, 'one', '$.a', '$.e') FROM s8 group by 1, 2;

-- select json_contains_path with group by having (EXPLAIN)
--Testcase 3683:
EXPLAIN VERBOSE
SELECT count(c2), json_contains_path(c1, 'one', '$.a', '$.e') FROM s8 group by json_contains_path(c1, 'one', '$.a', '$.e') HAVING count(c2) > 0;

-- select json_contains_path with group by having (result)
--Testcase 3684:
SELECT count(c2), json_contains_path(c1, 'one', '$.a', '$.e') FROM s8 group by json_contains_path(c1, 'one', '$.a', '$.e') HAVING count(c2) > 0;

-- select json_contains_path with group by index having (result)
--Testcase 3685:
SELECT c2,  json_contains_path(c1, 'one', '$.a', '$.e') FROM s8 group by 2, 1 HAVING count(c2) > 0;

-- select json_contains_path with group by index having (result)
--Testcase 3686:
SELECT c2,  json_contains_path(c1, 'one', '$.a', '$.e') FROM s8 group by 1, 2 HAVING count(c2) > 0;

-- select json_contains_path and as
--Testcase 3687:
SELECT json_contains_path(c1, 'all', '$.a') as json_contains_path1 FROM s8;

-- select json_depth (builtin function, explain)
--Testcase 3688:
EXPLAIN VERBOSE
SELECT json_depth(c1), json_depth(json_build_array(c1, c2)), json_depth('[10, {"a": 20}]'), json_depth('1'), json_depth('true') FROM s8;

-- select json_depth (builtin function, result)
--Testcase 3689:
SELECT json_depth(c1), json_depth(json_build_array(c1, c2)), json_depth('[10, {"a": 20}]'), json_depth('1'), json_depth('true') FROM s8;

-- select json_depth (builtin function, not pushdown constraints, explain)
--Testcase 3690:
EXPLAIN VERBOSE
SELECT json_depth(c1), json_depth(json_build_array(c1, c2)), json_depth('[10, {"a": 20}]'), json_depth('1'), json_depth('true') FROM s8 WHERE to_hex(id) = '2';

-- select json_depth (builtin function, not pushdown constraints, result)
--Testcase 3691:
SELECT json_depth(c1), json_depth(json_build_array(c1, c2)), json_depth('[10, {"a": 20}]'), json_depth('1'), json_depth('true') FROM s8 WHERE to_hex(id) = '2';

-- select json_depth (builtin function, pushdown constraints, explain)
--Testcase 3692:
EXPLAIN VERBOSE
SELECT json_depth(c1), json_depth(json_build_array(c1, c2)), json_depth('[10, {"a": 20}]'), json_depth('1'), json_depth('true') FROM s8 WHERE id != 0;

-- select json_depth (builtin function, pushdown constraints, result)
--Testcase 3693:
SELECT json_depth(c1), json_depth(json_build_array(c1, c2)), json_depth('[10, {"a": 20}]'), json_depth('1'), json_depth('true') FROM s8 WHERE id != 0;

-- select json_depth (builtin function, json_depth in constraints, explain)
--Testcase 3694:
EXPLAIN VERBOSE
SELECT json_depth(c1), json_depth(json_build_array(c1, c2)), json_depth('[10, {"a": 20}]'), json_depth('1'), json_depth('true') FROM s8 WHERE json_depth(c1) != 1;

-- select json_depth (builtin function, json_depth in constraints, result)
--Testcase 3695:
SELECT json_depth(c1), json_depth(json_build_array(c1, c2)), json_depth('[10, {"a": 20}]'), json_depth('1'), json_depth('true') FROM s8 WHERE json_depth(c1) != 1;

-- select json_depth (builtin function, json_depth in constraints, explain)
--Testcase 3696:
EXPLAIN VERBOSE
SELECT json_depth(c1), json_depth(json_build_array(c1, c2)), json_depth('[10, {"a": 20}]'), json_depth('1'), json_depth('true') FROM s8 WHERE json_depth('true') = 1;

-- select json_depth (builtin function, json_depth in constraints, result)
--Testcase 3697:
SELECT json_depth(c1), json_depth(json_build_array(c1, c2)), json_depth('[10, {"a": 20}]'), json_depth('1'), json_depth('true') FROM s8 WHERE json_depth('true') = 1;

-- select json_depth with non pushdown func and explicit constant (EXPLAIN)
--Testcase 3698:
EXPLAIN VERBOSE
SELECT json_depth('[10, {"a": 20}]'), pi(), 4.1 FROM s8;

-- select json_depth with non pushdown func and explicit constant (result)
--Testcase 3699:
SELECT json_depth('[10, {"a": 20}]'), pi(), 4.1 FROM s8;


-- select json_depth with order by index (result)
--Testcase 3700:
SELECT id,  json_depth(c1) FROM s8 ORDER BY 2, 1;

-- select json_depth with order by index (result)
--Testcase 3701:
SELECT id,  json_depth(c1) FROM s8 ORDER BY 1, 2;

-- select json_depth with group by (EXPLAIN)
--Testcase 3702:
EXPLAIN VERBOSE
SELECT count(id), json_depth(c1) FROM s8 group by json_depth(c1);

-- select json_depth with group by (result)
--Testcase 3703:
SELECT count(id), json_depth(c1) FROM s8 group by json_depth(c1);

-- select json_depth with group by index (result)
--Testcase 3704:
SELECT id,  json_depth(c1) FROM s8 group by 2, 1;

-- select json_depth with group by index (result)
--Testcase 3705:
SELECT id,  json_depth(c1) FROM s8 group by 1, 2;

-- select json_depth with group by having (EXPLAIN)
--Testcase 3706:
EXPLAIN VERBOSE
SELECT count(c2), json_depth(c1) FROM s8 group by json_depth(c1) HAVING count(c2) > 0;

-- select json_depth with group by having (result)
--Testcase 3707:
SELECT count(c2), json_depth(c1) FROM s8 group by json_depth(c1) HAVING count(c2) > 0;

-- select json_depth with group by index having (result)
--Testcase 3708:
SELECT c2,  json_depth(c1) FROM s8 group by 2, 1 HAVING count(c2) > 0;

-- select json_depth with group by index having (result)
--Testcase 3709:
SELECT c2,  json_depth(c1) FROM s8 group by 1, 2 HAVING count(c2) > 0;

-- select json_depth and as
--Testcase 3710:
SELECT json_depth('[10, {"a": 20}]') as json_depth1 FROM s8;

-- select json_extract (builtin function, explain)
--Testcase 3711:
EXPLAIN VERBOSE
SELECT json_extract(c1, '$[1]'), json_extract(json_extract(c1, '$[1]', '$[0]')::json, '$[0]'), json_extract(c1, '$.a'), json_extract(json_build_array(c1, c3), '$[0]'), json_extract('{"id": 1, "b": {"c": 30}}', '$.id') FROM s8;

-- select json_extract (builtin function, result)
--Testcase 3712:
SELECT json_extract(c1, '$[1]'), json_extract(json_extract(c1, '$[1]', '$[0]')::json, '$[0]'), json_extract(c1, '$.a'), json_extract(json_build_array(c1, c3), '$[0]'), json_extract('{"id": 1, "b": {"c": 30}}', '$.id') FROM s8;

-- select json_extract (builtin function, not pushdown constraints, explain)
--Testcase 3713:
EXPLAIN VERBOSE
SELECT json_extract(c1, '$[1]'), json_extract(json_extract(c1, '$[1]', '$[0]')::json, '$[0]'), json_extract(c1, '$.a'), json_extract(json_build_array(c1, c3), '$[0]'), json_extract('{"id": 1, "b": {"c": 30}}', '$.id') FROM s8 WHERE to_hex(id) = '2';

-- select json_extract (builtin function, not pushdown constraints, result)
--Testcase 3714:
SELECT json_extract(c1, '$[1]'), json_extract(json_extract(c1, '$[1]', '$[0]')::json, '$[0]'), json_extract(c1, '$.a'), json_extract(json_build_array(c1, c3), '$[0]'), json_extract('{"id": 1, "b": {"c": 30}}', '$.id') FROM s8 WHERE to_hex(id) = '2';

-- select json_extract (builtin function, pushdown constraints, explain)
--Testcase 3715:
EXPLAIN VERBOSE
SELECT json_extract(c1, '$[1]'), json_extract(json_extract(c1, '$[1]', '$[0]')::json, '$[0]'), json_extract(c1, '$.a'), json_extract(json_build_array(c1, c3), '$[0]'), json_extract('{"id": 1, "b": {"c": 30}}', '$.id') FROM s8 WHERE id != 0;

-- select json_extract (builtin function, pushdown constraints, result)
--Testcase 3716:
SELECT json_extract(c1, '$[1]'), json_extract(json_extract(c1, '$[1]', '$[0]')::json, '$[0]'), json_extract(c1, '$.a'), json_extract(json_build_array(c1, c3), '$[0]'), json_extract('{"id": 1, "b": {"c": 30}}', '$.id') FROM s8 WHERE id != 0;

-- select json_extract (builtin function, json_extract in constraints, explain)
--Testcase 3717:
EXPLAIN VERBOSE
SELECT json_extract(c1, '$[1]'), json_extract(json_extract(c1, '$[1]', '$[0]')::json, '$[0]'), json_extract(c1, '$.a'), json_extract(json_build_array(c1, c3), '$[0]'), json_extract('{"id": 1, "b": {"c": 30}}', '$.id') FROM s8 WHERE json_extract(c1, '$[1]')::numeric != 1;

-- select json_extract (builtin function, json_extract in constraints, result)
--Testcase 3718:
SELECT json_extract(c1, '$[1]'), json_extract(json_extract(c1, '$[1]', '$[0]')::json, '$[0]'), json_extract(c1, '$.a'), json_extract(json_build_array(c1, c3), '$[0]'), json_extract('{"id": 1, "b": {"c": 30}}', '$.id') FROM s8 WHERE json_extract(c1, '$[1]')::numeric != 1;

-- select json_extract (builtin function, json_extract in constraints, explain)
--Testcase 3719:
EXPLAIN VERBOSE
SELECT json_extract(c1, '$[1]'), json_extract(json_extract(c1, '$[1]', '$[0]')::json, '$[0]'), json_extract(c1, '$.a'), json_extract(json_build_array(c1, c3), '$[0]'), json_extract('{"id": 1, "b": {"c": 30}}', '$.id') FROM s8 WHERE json_extract('{"id": 1, "b": {"c": 30}}', '$.id')::numeric = 1;

-- select json_extract (builtin function, json_extract in constraints, result)
--Testcase 3720:
SELECT json_extract(c1, '$[1]'), json_extract(json_extract(c1, '$[1]', '$[0]')::json, '$[0]'), json_extract(c1, '$.a'), json_extract(json_build_array(c1, c3), '$[0]'), json_extract('{"id": 1, "b": {"c": 30}}', '$.id') FROM s8 WHERE json_extract('{"id": 1, "b": {"c": 30}}', '$.id')::numeric = 1;

-- select json_extract as nest function with agg (pushdown, explain)
--Testcase 3721:
EXPLAIN VERBOSE
SELECT sum(id),json_extract(json_build_array('{"id": 1, "b": {"c": 30}}', sum(id)), '$.id') FROM s8;

-- select json_extract as nest function with agg (pushdown, result)
--Testcase 3722:
SELECT sum(id),json_extract(json_build_array('{"id": 1, "b": {"c": 30}}', sum(id)), '$.id') FROM s8;

-- select json_extract with abnormal cast
--Testcase 3723:
SELECT json_extract(c1, '$.a')::int FROM s8;  -- should fail

-- select json_extract with normal cast
--Testcase 3724:
SELECT json_extract('{"a": "2000-01-01"}', '$.a')::timestamp, json_extract('{"a": "2000-01-01"}', '$.a')::date , json_extract('{"a": 1234}', '$.a')::bigint, json_extract('{"a": "b"}', '$.a')::text FROM s8;

-- select json_extract with normal cast
--Testcase 3725:
SELECT json_extract('{"a": "2000-01-01"}', '$.a')::timestamptz, json_extract('{"a": "12:10:20.123456"}', '$.a')::time , json_extract('{"a": "12:10:20.123456"}', '$.a')::timetz FROM s8;

-- select json_extract with type modifier (explain)
--Testcase 3726:
EXPLAIN VERBOSE
SELECT json_extract('{"a": "2000-01-01 12:02:01.123456"}', '$.a')::timestamp(3), json_extract('{"a": "2000-01-01 12:02:01.123456"}', '$.a')::timestamptz(3), json_extract('{"a": "12:10:20.123456"}', '$.a')::time(3), json_extract('{"a": "12:10:20.123456"}', '$.a')::timetz(3) FROM s8;

-- select json_extract with type modifier (result)
--Testcase 3727:
SELECT json_extract('{"a": "2000-01-01 12:02:01.123456"}', '$.a')::timestamp(3), json_extract('{"a": "2000-01-01 12:02:01.123456"}', '$.a')::timestamptz(3), json_extract('{"a": "12:10:20.123456"}', '$.a')::time(3), json_extract('{"a": "12:10:20.123456"}', '$.a')::timetz(3) FROM s8;

-- select json_extract with type modifier (explain)
--Testcase 3728:
EXPLAIN VERBOSE
SELECT json_extract('{"a": 100}', '$.a')::numeric(10, 2), json_extract('{"a": 100}', '$.a')::decimal(10, 2), json_unquote(json_extract('{"a": "1.123456"}', '$.a'))::numeric(10, 3) FROM s8;

-- select json_extract with type modifier (result)
--Testcase 3729:
SELECT json_extract('{"a": 100}', '$.a')::numeric(10, 2), json_extract('{"a": 100}', '$.a')::decimal(10, 2), json_unquote(json_extract('{"a": "1.123456"}', '$.a'))::numeric(10, 3) FROM s8;

-- select json_extract with non pushdown func and explicit constant (EXPLAIN)
--Testcase 3730:
EXPLAIN VERBOSE
SELECT json_extract(c1, '$.a'), pi(), 4.1 FROM s8;

-- select json_extract with non pushdown func and explicit constant (result)
--Testcase 3731:
SELECT json_extract(c1, '$.a'), pi(), 4.1 FROM s8;


-- select json_extract with order by index (result)
--Testcase 3732:
SELECT id,  json_extract(c1, '$[1]') FROM s8 ORDER BY 2, 1;

-- select json_extract with order by index (result)
--Testcase 3733:
SELECT id,  json_extract(c1, '$[1]') FROM s8 ORDER BY 1, 2;

-- select json_extract with group by (EXPLAIN)
--Testcase 3734:
EXPLAIN VERBOSE
SELECT count(id), json_extract(c1, '$[1]') FROM s8 group by json_extract(c1, '$[1]');

-- select json_extract with group by (result)
--Testcase 3735:
SELECT count(id), json_extract(c1, '$[1]') FROM s8 group by json_extract(c1, '$[1]');

-- select json_extract with group by index (result)
--Testcase 3736:
SELECT id,  json_extract(c1, '$[1]') FROM s8 group by 2, 1;

-- select json_extract with group by index (result)
--Testcase 3737:
SELECT id,  json_extract(c1, '$[1]') FROM s8 group by 1, 2;

-- select json_extract with group by having (EXPLAIN)
--Testcase 3738:
EXPLAIN VERBOSE
SELECT count(c2), json_extract(c1, '$[1]') FROM s8 group by json_extract(c1, '$[1]') HAVING count(c2) > 0;

-- select json_extract with group by having (result)
--Testcase 3739:
SELECT count(c2), json_extract(c1, '$[1]') FROM s8 group by json_extract(c1, '$[1]') HAVING count(c2) > 0;

-- select json_extract with group by index having (result)
--Testcase 3740:
SELECT c2,  json_extract(c1, '$[1]') FROM s8 group by 2, 1 HAVING count(c2) > 0;

-- select json_extract with group by index having (result)
--Testcase 3741:
SELECT c2,  json_extract(c1, '$[1]') FROM s8 group by 1, 2 HAVING count(c2) > 0;

-- select json_extract and as
--Testcase 3742:
SELECT json_extract(c1, '$.a') as json_extract1 FROM s8;
-- JSON_INSERT()
-- select json_insert (stub function, explain)
--Testcase 3743:
EXPLAIN VERBOSE
SELECT json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8;

-- select json_insert (stub function, result)
--Testcase 3744:
SELECT json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8;

-- select json_insert (stub function, not pushdown constraints, explain)
--Testcase 3745:
EXPLAIN VERBOSE
SELECT json_insert(c1, '$.a, c2', '$.b, c3', '$.c, NULL', '$, TRUE', '$, pi()') FROM s8 WHERE to_hex(id) = '1';

-- select json_insert (stub function, not pushdown constraints, result)
--Testcase 3746:
SELECT json_insert(c1, '$.a, c2', '$.b, c3', '$.c, NULL', '$, TRUE', '$, pi()') FROM s8 WHERE to_hex(id) = '1';

-- select json_insert (stub function, pushdown constraints, explain)
--Testcase 3747:
EXPLAIN VERBOSE
SELECT json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, CAST("[true, false]" AS JSON)') FROM s8 WHERE id = 1;

-- select json_insert (stub function, pushdown constraints, result)
--Testcase 3748:
SELECT json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, CAST("[true, false]" AS JSON)') FROM s8 WHERE id = 1;

-- select json_insert (stub function, stub in constraints, explain)
--Testcase 3749:
EXPLAIN VERBOSE
SELECT json_insert(c1, '$.a, c2', '$.b, c3', '$.c, NULL', '$, TRUE', '$, "[true, false]"') FROM s8 WHERE log2(id) > 1;

-- select json_insert (stub function, stub in constraints, result)
--Testcase 3750:
SELECT json_insert(c1, '$.a, c2', '$.b, c3', '$.c, NULL', '$, TRUE', '$, "[true, false]"') FROM s8 WHERE log2(id) > 1;

-- select json_insert (stub function, stub in constraints, explain)
--Testcase 3751:
EXPLAIN VERBOSE
SELECT json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8 WHERE json_depth(json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()')) > 0;

-- select json_insert (stub function, stub in constraints, result)
--Testcase 3752:
SELECT json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8 WHERE json_depth(json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()')) > 0;

-- json_insert with 1 arg explain
--Testcase 3753:
EXPLAIN VERBOSE
SELECT json_insert(c1, '$.a, c2') FROM s8;

-- json_insert with 1 arg result
--Testcase 3754:
SELECT json_insert(c1, '$.a, c2') FROM s8;

-- json_insert with 2 args explain
--Testcase 3755:
EXPLAIN VERBOSE
SELECT json_insert(c1, '$.a, c2', '$.b, c3') FROM s8;

-- json_insert with 2 args result
--Testcase 3756:
SELECT json_insert(c1, '$.a, c2', '$.b, c3') FROM s8;

-- json_insert with 3 args explain
--Testcase 3757:
EXPLAIN VERBOSE
SELECT json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1') FROM s8;

-- json_insert with 3 args result
--Testcase 3758:
SELECT json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1') FROM s8;

-- json_insert with 4 args explain
--Testcase 3759:
EXPLAIN VERBOSE
SELECT json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"') FROM s8;

-- json_insert with 4 args result
--Testcase 3760:
SELECT json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"') FROM s8;

-- json_insert with 5 args explain
--Testcase 3761:
EXPLAIN VERBOSE
SELECT json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8;

-- json_insert with 5 args result
--Testcase 3762:
SELECT json_insert(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8;

-- select json_insert as nest function with agg (pushdown, explain)
--Testcase 3763:
EXPLAIN VERBOSE
SELECT sum(id),json_insert('["a", ["b", "c"], "d"]', '$, sum(id)') FROM s8;

-- select json_insert as nest function with agg (pushdown, result)
--Testcase 3764:
SELECT sum(id),json_insert('["a", ["b", "c"], "d"]', '$, sum(id)') FROM s8;

-- select json_insert as nest function with json_build_array (pushdown, explain)
--Testcase 3765:
EXPLAIN VERBOSE
SELECT json_insert(json_build_array('["a", ["b", "c"], "d"]', c1), '$, log2(id)') FROM s8;

-- select json_insert as nest function with agg (pushdown, result)
--Testcase 3766:
SELECT json_insert(json_build_array('["a", ["b", "c"], "d"]', c1), '$, log2(id)') FROM s8;

-- select json_insert with non pushdown func and explicit constant (explain)
--Testcase 3767:
EXPLAIN VERBOSE
SELECT json_insert(c1, '$.a, c2'), pi(), 4.1 FROM s8;

-- select json_insert with non pushdown func and explicit constant (result)
--Testcase 3768:
SELECT json_insert(c1, '$.a, c2'), pi(), 4.1 FROM s8;

-- select json_insert with order by (explain)
--Testcase 3769:
EXPLAIN VERBOSE
SELECT json_length(json_insert(c1, '$.a, c2')) FROM s8 ORDER BY 1;

-- select json_insert with order by (result)
--Testcase 3770:
SELECT json_length(json_insert(c1, '$.a, c2')) FROM s8 ORDER BY 1;

-- select json_insert with group by (explain)
--Testcase 3771:
EXPLAIN VERBOSE
SELECT json_length(json_insert('["a", ["b", "c"], "d"]', '$, id')) FROM s8 GROUP BY id, 1;

-- select json_insert with group by (result)
--Testcase 3772:
SELECT json_length(json_insert('["a", ["b", "c"], "d"]', '$, id')) FROM s8 GROUP BY id, 1;

-- select json_insert with group by having (explain)
--Testcase 3773:
EXPLAIN VERBOSE
SELECT json_depth(json_insert('["a", ["b", "c"], "d"]', '$, c2')) FROM s8 GROUP BY c2, 1 HAVING count(c2) > 1;

-- select json_insert with group by having (result)
--Testcase 3774:
SELECT json_depth(json_insert('["a", ["b", "c"], "d"]', '$, c2')) FROM s8 GROUP BY c2, 1 HAVING count(c2) > 1;

-- select json_insert and as
--Testcase 3775:
SELECT json_insert(c1, '$.a, c2') AS json_insert1 FROM s8;

-- JSON_KEYS()
-- select json_keys (builtin function, explain)
--Testcase 3776:
EXPLAIN VERBOSE
SELECT json_keys(c1), json_keys(c1, '$'), json_keys(json_build_object('a', c3)), json_keys(json_build_object('a', c3), '$.a'), json_keys('{"a": 1, "b": {"c": 30}}', '$.a') FROM s8;

-- select json_keys (builtin function, result)
--Testcase 3777:
SELECT json_keys(c1), json_keys(c1, '$'), json_keys(json_build_object('a', c3)), json_keys(json_build_object('a', c3), '$.a'), json_keys('{"a": 1, "b": {"c": 30}}', '$.a') FROM s8;

-- select json_keys (builtin function, not pushdown constraints, explain)
--Testcase 3778:
EXPLAIN VERBOSE
SELECT json_keys(c1), json_keys(c1, '$'), json_keys(json_build_object('a', c3)), json_keys(json_build_object('a', c3), '$.a'), json_keys('{"a": 1, "b": {"c": 30}}', '$.a') FROM s8 WHERE to_hex(id) = '2';

-- select json_keys (builtin function, not pushdown constraints, result)
--Testcase 3779:
SELECT json_keys(c1), json_keys(c1, '$'), json_keys(json_build_object('a', c3)), json_keys(json_build_object('a', c3), '$.a'), json_keys('{"a": 1, "b": {"c": 30}}', '$.a') FROM s8 WHERE to_hex(id) = '2';

-- select json_keys (builtin function, pushdown constraints, explain)
--Testcase 3780:
EXPLAIN VERBOSE
SELECT json_keys(c1), json_keys(c1, '$'), json_keys(json_build_object('a', c3)), json_keys(json_build_object('a', c3), '$.a'), json_keys('{"a": 1, "b": {"c": 30}}', '$.a') FROM s8 WHERE id != 0;

-- select json_keys (builtin function, pushdown constraints, result)
--Testcase 3781:
SELECT json_keys(c1), json_keys(c1, '$'), json_keys(json_build_object('a', c3)), json_keys(json_build_object('a', c3), '$.a'), json_keys('{"a": 1, "b": {"c": 30}}', '$.a') FROM s8 WHERE id != 0;

-- select json_keys (builtin function, json_keys in constraints, explain)
--Testcase 3782:
EXPLAIN VERBOSE
SELECT json_keys(c1), json_keys(c1, '$'), json_keys(json_build_object('a', c3)), json_keys(json_build_object('a', c3), '$.a'), json_keys('{"a": 1, "b": {"c": 30}}', '$.b') FROM s8 WHERE json_length(json_keys(c1)) != 1;

-- select json_keys (builtin function, json_keys in constraints, result)
--Testcase 3783:
SELECT json_keys(c1), json_keys(c1, '$'), json_keys(json_build_object('a', c3)), json_keys(json_build_object('a', c3), '$.a'), json_keys('{"a": 1, "b": {"c": 30}}', '$.b') FROM s8 WHERE json_length(json_keys(c1)) != 1;

-- select json_keys (builtin function, json_keys in constraints, explain)
--Testcase 3784:
EXPLAIN VERBOSE
SELECT json_keys(c1), json_keys(c1, '$'), json_keys(json_build_object('a', c3)), json_keys(json_build_object('a', c3), '$.a'), json_keys('{"a": 1, "b": {"c": 30}}', '$.b') FROM s8 WHERE json_length(json_keys('{"a": 1, "b": {"c": 30}}', '$.b')) = 1;

-- select json_keys (builtin function, json_keys in constraints, result)
--Testcase 3785:
SELECT json_keys(c1), json_keys(c1, '$'), json_keys(json_build_object('a', c3)), json_keys(json_build_object('a', c3), '$.a'), json_keys('{"a": 1, "b": {"c": 30}}', '$.b') FROM s8 WHERE json_length(json_keys('{"a": 1, "b": {"c": 30}}', '$.b')) = 1;

-- select json_keys as nest function with agg (pushdown, explain)
--Testcase 3786:
EXPLAIN VERBOSE
SELECT sum(id),json_keys('{"a": 1, "b": {"c": 30}}', '$.b') FROM s8;

-- select json_keys as nest function with agg (pushdown, result)
--Testcase 3787:
SELECT sum(id),json_keys('{"a": 1, "b": {"c": 30}}', '$.b') FROM s8;

-- select json_keys with non pushdown func and explicit constant (EXPLAIN)
--Testcase 3788:
EXPLAIN VERBOSE
SELECT json_keys(json_build_object('a', c3)), pi(), 4.1 FROM s8;

-- select json_keys with non pushdown func and explicit constant (result)
--Testcase 3789:
SELECT json_keys(json_build_object('a', c3)), pi(), 4.1 FROM s8;


-- select json_keys with order by index (result)
--Testcase 3790:
SELECT id,  json_length(json_keys(c1)) FROM s8 ORDER BY 2, 1;

-- select json_keys with order by index (result)
--Testcase 3791:
SELECT id,  json_length(json_keys(c1)) FROM s8 ORDER BY 1, 2;

-- select json_keys with group by (EXPLAIN)
--Testcase 3792:
EXPLAIN VERBOSE
SELECT count(id), json_length(json_keys(c1)) FROM s8 group by json_length(json_keys(c1));

-- select json_keys with group by (result)
--Testcase 3793:
SELECT count(id), json_length(json_keys(c1)) FROM s8 group by json_length(json_keys(c1));

-- select json_keys with group by index (result)
--Testcase 3794:
SELECT id,  json_length(json_keys(c1)) FROM s8 group by 2, 1;

-- select json_keys with group by index (result)
--Testcase 3795:
SELECT id,  json_length(json_keys(c1)) FROM s8 group by 1, 2;

-- select json_keys with group by having (EXPLAIN)
--Testcase 3796:
EXPLAIN VERBOSE
SELECT count(c2), json_length(json_keys(c1)) FROM s8 group by json_length(json_keys(c1)) HAVING count(c2) > 0;

-- select json_keys with group by having (result)
--Testcase 3797:
SELECT count(c2), json_length(json_keys(c1)) FROM s8 group by json_length(json_keys(c1)) HAVING count(c2) > 0;

-- select json_keys with group by index having (result)
--Testcase 3798:
SELECT c2,  json_length(json_keys(c1)) FROM s8 group by 2, 1 HAVING count(c2) > 0;

-- select json_keys with group by index having (result)
--Testcase 3799:
SELECT c2,  json_length(json_keys(c1)) FROM s8 group by 1, 2 HAVING count(c2) > 0;

-- select json_keys and as
--Testcase 3800:
SELECT json_keys(json_build_object('a', c3)) as json_keys1 FROM s8;

-- select json_length (builtin function, explain)
--Testcase 3801:
EXPLAIN VERBOSE
SELECT json_length(c1), json_length(json_build_array(c1, 'a', c2)), json_length('{"a": 1, "b": {"c": 30}}') FROM s8;

-- select json_length (builtin function, result)
--Testcase 3802:
SELECT json_length(c1), json_length(json_build_array(c1, 'a', c2)), json_length('{"a": 1, "b": {"c": 30}}') FROM s8;

-- select json_length (builtin function, not pushdown constraints, explain)
--Testcase 3803:
EXPLAIN VERBOSE
SELECT json_length(c1), json_length(json_build_array(c1, 'a', c2)), json_length('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE to_hex(id) = '2';

-- select json_length (builtin function, not pushdown constraints, result)
--Testcase 3804:
SELECT json_length(c1), json_length(json_build_array(c1, 'a', c2)), json_length('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE to_hex(id) = '2';

-- select json_length (builtin function, pushdown constraints, explain)
--Testcase 3805:
EXPLAIN VERBOSE
SELECT json_length(c1), json_length(json_build_array(c1, 'a', c2)), json_length('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE id != 0;

-- select json_length (builtin function, pushdown constraints, result)
--Testcase 3806:
SELECT json_length(c1), json_length(json_build_array(c1, 'a', c2)), json_length('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE id != 0;

-- select json_length (builtin function, json_length in constraints, explain)
--Testcase 3807:
EXPLAIN VERBOSE
SELECT json_length(c1), json_length(json_build_array(c1, 'a', c2)), json_length('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE json_length(c1) != 1;

-- select json_length (builtin function, json_length in constraints, result)
--Testcase 3808:
SELECT json_length(c1), json_length(json_build_array(c1, 'a', c2)), json_length('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE json_length(c1) != 1;

-- select json_length (builtin function, json_length in constraints, explain)
--Testcase 3809:
EXPLAIN VERBOSE
SELECT json_length(c1), json_length(json_build_array(c1, 'a', c2)), json_length('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE json_length('{"a": 1, "b": {"c": 30}}') = 2;

-- select json_length (builtin function, json_length in constraints, result)
--Testcase 3810:
SELECT json_length(c1), json_length(json_build_array(c1, 'a', c2)), json_length('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE json_length('{"a": 1, "b": {"c": 30}}') = 2;

-- select json_length as nest function with agg (pushdown, explain)
--Testcase 3811:
EXPLAIN VERBOSE
SELECT sum(id),json_length('{"a": 1, "b": {"c": 30}}') FROM s8;

-- select json_length as nest function with agg (pushdown, result)
--Testcase 3812:
SELECT sum(id),json_length('{"a": 1, "b": {"c": 30}}') FROM s8;

-- select json_length with non pushdown func and explicit constant (EXPLAIN)
--Testcase 3813:
EXPLAIN VERBOSE
SELECT json_length(json_build_array(c1, 'a', c2)), pi(), 4.1 FROM s8;

-- select json_length with non pushdown func and explicit constant (result)
--Testcase 3814:
SELECT json_length(json_build_array(c1, 'a', c2)), pi(), 4.1 FROM s8;


-- select json_length with order by index (result)
--Testcase 3815:
SELECT id, json_length(c1) FROM s8 ORDER BY 2, 1;

-- select json_length with order by index (result)
--Testcase 3816:
SELECT id, json_length(c1) FROM s8 ORDER BY 1, 2;

-- select json_length with group by (EXPLAIN)
--Testcase 3817:
EXPLAIN VERBOSE
SELECT count(id), json_length(c1) FROM s8 group by json_length(c1);

-- select json_length with group by (result)
--Testcase 3818:
SELECT count(id), json_length(c1) FROM s8 group by json_length(c1);

-- select json_length with group by index (result)
--Testcase 3819:
SELECT id, json_length(c1) FROM s8 group by 2, 1;

-- select json_length with group by index (result)
--Testcase 3820:
SELECT id, json_length(c1) FROM s8 group by 1, 2;

-- select json_length with group by having (EXPLAIN)
--Testcase 3821:
EXPLAIN VERBOSE
SELECT count(c2), json_length(c1) FROM s8 group by json_length(c1) HAVING count(c2) > 0;

-- select json_length with group by having (result)
--Testcase 3822:
SELECT count(c2), json_length(c1) FROM s8 group by json_length(c1) HAVING count(c2) > 0;

-- select json_length with group by index having (result)
--Testcase 3823:
SELECT c2, json_length(c1) FROM s8 group by 2, 1 HAVING count(c2) > 0;

-- select json_length with group by index having (result)
--Testcase 3824:
SELECT c2, json_length(c1) FROM s8 group by 1, 2 HAVING count(c2) > 0;

-- select json_length and as
--Testcase 3825:
SELECT json_length(json_build_array(c1, 'a', c2)) as json_length1 FROM s8;

-- select json_merge (builtin function, explain)
--Testcase 3826:
EXPLAIN VERBOSE
SELECT json_merge(c1, '[1, 2]'), json_merge(c1, '[1, 2]', '[true, false]'), json_merge(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge('[1, 2]', '[true, false]') FROM s8;

-- select json_merge (builtin function, result)
--Testcase 3827:
SELECT json_merge(c1, '[1, 2]'), json_merge(c1, '[1, 2]', '[true, false]'), json_merge(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge('[1, 2]', '[true, false]') FROM s8;

-- select json_merge (builtin function, not pushdown constraints, explain)
--Testcase 3828:
EXPLAIN VERBOSE
SELECT json_merge(c1, '[1, 2]'), json_merge(c1, '[1, 2]', '[true, false]'), json_merge(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge('[1, 2]', '[true, false]') FROM s8 WHERE to_hex(id) = '2';

-- select json_merge (builtin function, not pushdown constraints, result)
--Testcase 3829:
SELECT json_merge(c1, '[1, 2]'), json_merge(c1, '[1, 2]', '[true, false]'), json_merge(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge('[1, 2]', '[true, false]') FROM s8 WHERE to_hex(id) = '2';

-- select json_merge (builtin function, pushdown constraints, explain)
--Testcase 3830:
EXPLAIN VERBOSE
SELECT json_merge(c1, '[1, 2]'), json_merge(c1, '[1, 2]', '[true, false]'), json_merge(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge('[1, 2]', '[true, false]') FROM s8 WHERE id != 0;

-- select json_merge (builtin function, pushdown constraints, result)
--Testcase 3831:
SELECT json_merge(c1, '[1, 2]'), json_merge(c1, '[1, 2]', '[true, false]'), json_merge(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge('[1, 2]', '[true, false]') FROM s8 WHERE id != 0;

-- select json_merge (builtin function, json_merge in constraints, explain)
--Testcase 3832:
EXPLAIN VERBOSE
SELECT json_merge(c1, '[1, 2]'), json_merge(c1, '[1, 2]', '[true, false]'), json_merge(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge('[1, 2]', '[true, false]') FROM s8 WHERE json_length(json_merge(c1, '[1, 2]')) != 1;

-- select json_merge (builtin function, json_merge in constraints, result)
--Testcase 3833:
SELECT json_merge(c1, '[1, 2]'), json_merge(c1, '[1, 2]', '[true, false]'), json_merge(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge('[1, 2]', '[true, false]') FROM s8 WHERE json_length(json_merge(c1, '[1, 2]')) != 1;

-- select json_merge (builtin function, json_merge in constraints, explain)
--Testcase 3834:
EXPLAIN VERBOSE
SELECT json_merge(c1, '[1, 2]'), json_merge(c1, '[1, 2]', '[true, false]'), json_merge(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge('[1, 2]', '[true, false]') FROM s8 WHERE json_length(json_merge('[1, 2]', '[true, false]')) = 4;

-- select json_merge (builtin function, json_merge in constraints, result)
--Testcase 3835:
SELECT json_merge(c1, '[1, 2]'), json_merge(c1, '[1, 2]', '[true, false]'), json_merge(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge('[1, 2]', '[true, false]') FROM s8 WHERE json_length(json_merge('[1, 2]', '[true, false]')) = 4;

-- select json_merge as nest function with agg (pushdown, explain)
--Testcase 3836:
EXPLAIN VERBOSE
SELECT sum(id),json_merge('[1, 2]', '[true, false]') FROM s8;

-- select json_merge as nest function with agg (pushdown, result)
--Testcase 3837:
SELECT sum(id),json_merge('[1, 2]', '[true, false]') FROM s8;

-- select json_merge with non pushdown func and explicit constant (EXPLAIN)
--Testcase 3838:
EXPLAIN VERBOSE
SELECT json_merge(json_build_array(c1, '[1, 2]'), '[true, false]'), pi(), 4.1 FROM s8;

-- select json_merge with non pushdown func and explicit constant (result)
--Testcase 3839:
SELECT json_merge(json_build_array(c1, '[1, 2]'), '[true, false]'), pi(), 4.1 FROM s8;

-- select json_merge with order by index (result)
--Testcase 3840:
SELECT id, json_length(json_merge(c1, '[1, 2]')) FROM s8 ORDER BY 2, 1;

-- select json_merge with order by index (result)
--Testcase 3841:
SELECT id, json_length(json_merge(c1, '[1, 2]')) FROM s8 ORDER BY 1, 2;

-- select json_merge with group by (EXPLAIN)
--Testcase 3842:
EXPLAIN VERBOSE
SELECT count(id), json_length(json_merge(c1, '[1, 2]')) FROM s8 group by json_length(json_merge(c1, '[1, 2]'));

-- select json_merge with group by (result)
--Testcase 3843:
SELECT count(id), json_length(json_merge(c1, '[1, 2]')) FROM s8 group by json_length(json_merge(c1, '[1, 2]'));

-- select json_merge with group by index (result)
--Testcase 3844:
SELECT id, json_length(json_merge(c1, '[1, 2]')) FROM s8 group by 2, 1;

-- select json_merge with group by index (result)
--Testcase 3845:
SELECT id, json_length(json_merge(c1, '[1, 2]')) FROM s8 group by 1, 2;

-- select json_merge with group by having (EXPLAIN)
--Testcase 3846:
EXPLAIN VERBOSE
SELECT count(c2), json_length(json_merge(c1, '[1, 2]')) FROM s8 group by json_length(json_merge(c1, '[1, 2]')) HAVING count(c2) > 0;

-- select json_merge with group by having (result)
--Testcase 3847:
SELECT count(c2), json_length(json_merge(c1, '[1, 2]')) FROM s8 group by json_length(json_merge(c1, '[1, 2]')) HAVING count(c2) > 0;

-- select json_merge with group by index having (result)
--Testcase 3848:
SELECT c2, json_length(json_merge(c1, '[1, 2]')) FROM s8 group by 2, 1 HAVING count(c2) > 0;

-- select json_merge with group by index having (result)
--Testcase 3849:
SELECT c2, json_length(json_merge(c1, '[1, 2]')) FROM s8 group by 1, 2 HAVING count(c2) > 0;

-- select json_merge and as
--Testcase 3850:
SELECT json_merge(json_build_array(c1, '[1, 2]'), '[true, false]') as json_merge1 FROM s8;

-- select json_merge_patch (builtin function, explain)
--Testcase 3851:
EXPLAIN VERBOSE
SELECT json_merge_patch(c1, '[1, 2]'), json_merge_patch(c1, '[1, 2]', '[true, false]'), json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_patch('[1, 2]', '[true, false]') FROM s8;

-- select json_merge_patch (builtin function, result)
--Testcase 3852:
SELECT json_merge_patch(c1, '[1, 2]'), json_merge_patch(c1, '[1, 2]', '[true, false]'), json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_patch('[1, 2]', '[true, false]') FROM s8;

-- select json_merge_patch (builtin function, not pushdown constraints, explain)
--Testcase 3853:
EXPLAIN VERBOSE
SELECT json_merge_patch(c1, '[1, 2]'), json_merge_patch(c1, '[1, 2]', '[true, false]'), json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_patch('[1, 2]', '[true, false]') FROM s8 WHERE to_hex(id) = '2';

-- select json_merge_patch (builtin function, not pushdown constraints, result)
--Testcase 3854:
SELECT json_merge_patch(c1, '[1, 2]'), json_merge_patch(c1, '[1, 2]', '[true, false]'), json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_patch('[1, 2]', '[true, false]') FROM s8 WHERE to_hex(id) = '2';

-- select json_merge_patch (builtin function, pushdown constraints, explain)
--Testcase 3855:
EXPLAIN VERBOSE
SELECT json_merge_patch(c1, '[1, 2]'), json_merge_patch(c1, '[1, 2]', '[true, false]'), json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_patch('[1, 2]', '[true, false]') FROM s8 WHERE id != 0;

-- select json_merge_patch (builtin function, pushdown constraints, result)
--Testcase 3856:
SELECT json_merge_patch(c1, '[1, 2]'), json_merge_patch(c1, '[1, 2]', '[true, false]'), json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_patch('[1, 2]', '[true, false]') FROM s8 WHERE id != 0;

-- select json_merge_patch (builtin function, json_merge_patch in constraints, explain)
--Testcase 3857:
EXPLAIN VERBOSE
SELECT json_merge_patch(c1, '[1, 2]'), json_merge_patch(c1, '[1, 2]', '[true, false]'), json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_patch('[1, 2]', '[true, false]') FROM s8 WHERE json_length(json_merge_patch(c1, '[1, 2]')) != 1;

-- select json_merge_patch (builtin function, json_merge_patch in constraints, result)
--Testcase 3858:
SELECT json_merge_patch(c1, '[1, 2]'), json_merge_patch(c1, '[1, 2]', '[true, false]'), json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_patch('[1, 2]', '[true, false]') FROM s8 WHERE json_length(json_merge_patch(c1, '[1, 2]')) != 1;

-- select json_merge_patch (builtin function, json_merge_patch in constraints, explain)
--Testcase 3859:
EXPLAIN VERBOSE
SELECT json_merge_patch(c1, '[1, 2]'), json_merge_patch(c1, '[1, 2]', '[true, false]'), json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_patch('[1, 2]', '[true, false]') FROM s8 WHERE json_length(json_merge_patch('[1, 2]', '[true, false]')) = 2;

-- select json_merge_patch (builtin function, json_merge_patch in constraints, result)
--Testcase 3860:
SELECT json_merge_patch(c1, '[1, 2]'), json_merge_patch(c1, '[1, 2]', '[true, false]'), json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_patch('[1, 2]', '[true, false]') FROM s8 WHERE json_length(json_merge_patch('[1, 2]', '[true, false]')) = 2;

-- select json_merge_patch as nest function with agg (pushdown, explain)
--Testcase 3861:
EXPLAIN VERBOSE
SELECT sum(id),json_merge_patch('[1, 2]', '[true, false]') FROM s8;

-- select json_merge_patch as nest function with agg (pushdown, result)
--Testcase 3862:
SELECT sum(id),json_merge_patch('[1, 2]', '[true, false]') FROM s8;

-- select json_merge_patch with non pushdown func and explicit constant (EXPLAIN)
--Testcase 3863:
EXPLAIN VERBOSE
SELECT json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]'), pi(), 4.1 FROM s8;

-- select json_merge_patch with non pushdown func and explicit constant (result)
--Testcase 3864:
SELECT json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]'), pi(), 4.1 FROM s8;

-- select json_merge_patch with order by index (result)
--Testcase 3865:
SELECT id, json_length(json_merge_patch(c1, '[1, 2]')) FROM s8 ORDER BY 2, 1;

-- select json_merge_patch with order by index (result)
--Testcase 3866:
SELECT id, json_length(json_merge_patch(c1, '[1, 2]')) FROM s8 ORDER BY 1, 2;

-- select json_merge_patch with group by (EXPLAIN)
--Testcase 3867:
EXPLAIN VERBOSE
SELECT count(id), json_length(json_merge_patch(c1, '[1, 2]')) FROM s8 group by json_length(json_merge_patch(c1, '[1, 2]'));

-- select json_merge_patch with group by (result)
--Testcase 3868:
SELECT count(id), json_length(json_merge_patch(c1, '[1, 2]')) FROM s8 group by json_length(json_merge_patch(c1, '[1, 2]'));

-- select json_merge_patch with group by index (result)
--Testcase 3869:
SELECT id, json_length(json_merge_patch(c1, '[1, 2]')) FROM s8 group by 2, 1;

-- select json_merge_patch with group by index (result)
--Testcase 3870:
SELECT id, json_length(json_merge_patch(c1, '[1, 2]')) FROM s8 group by 1, 2;

-- select json_merge_patch with group by having (EXPLAIN)
--Testcase 3871:
EXPLAIN VERBOSE
SELECT count(c2), json_length(json_merge_patch(c1, '[1, 2]')) FROM s8 group by json_length(json_merge_patch(c1, '[1, 2]')) HAVING count(c2) > 0;

-- select json_merge_patch with group by having (result)
--Testcase 3872:
SELECT count(c2), json_length(json_merge_patch(c1, '[1, 2]')) FROM s8 group by json_length(json_merge_patch(c1, '[1, 2]')) HAVING count(c2) > 0;

-- select json_merge_patch with group by index having (result)
--Testcase 3873:
SELECT c2, json_length(json_merge_patch(c1, '[1, 2]')) FROM s8 group by 2, 1 HAVING count(c2) > 0;

-- select json_merge_patch with group by index having (result)
--Testcase 3874:
SELECT c2, json_length(json_merge_patch(c1, '[1, 2]')) FROM s8 group by 1, 2 HAVING count(c2) > 0;

-- select json_merge_patch and as
--Testcase 3875:
SELECT json_merge_patch(json_build_array(c1, '[1, 2]'), '[true, false]') as json_merge_patch1 FROM s8;

-- select json_merge_preserve (builtin function, explain)
--Testcase 3876:
EXPLAIN VERBOSE
SELECT json_merge_preserve(c1, '[1, 2]'), json_merge_preserve(c1, '[1, 2]', '[true, false]'), json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_preserve('[1, 2]', '[true, false]') FROM s8;

-- select json_merge_preserve (builtin function, result)
--Testcase 3877:
SELECT json_merge_preserve(c1, '[1, 2]'), json_merge_preserve(c1, '[1, 2]', '[true, false]'), json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_preserve('[1, 2]', '[true, false]') FROM s8;

-- select json_merge_preserve (builtin function, not pushdown constraints, explain)
--Testcase 3878:
EXPLAIN VERBOSE
SELECT json_merge_preserve(c1, '[1, 2]'), json_merge_preserve(c1, '[1, 2]', '[true, false]'), json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_preserve('[1, 2]', '[true, false]') FROM s8 WHERE to_hex(id) = '2';

-- select json_merge_preserve (builtin function, not pushdown constraints, result)
--Testcase 3879:
SELECT json_merge_preserve(c1, '[1, 2]'), json_merge_preserve(c1, '[1, 2]', '[true, false]'), json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_preserve('[1, 2]', '[true, false]') FROM s8 WHERE to_hex(id) = '2';

-- select json_merge_preserve (builtin function, pushdown constraints, explain)
--Testcase 3880:
EXPLAIN VERBOSE
SELECT json_merge_preserve(c1, '[1, 2]'), json_merge_preserve(c1, '[1, 2]', '[true, false]'), json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_preserve('[1, 2]', '[true, false]') FROM s8 WHERE id != 0;

-- select json_merge_preserve (builtin function, pushdown constraints, result)
--Testcase 3881:
SELECT json_merge_preserve(c1, '[1, 2]'), json_merge_preserve(c1, '[1, 2]', '[true, false]'), json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_preserve('[1, 2]', '[true, false]') FROM s8 WHERE id != 0;

-- select json_merge_preserve (builtin function, json_merge_preserve in constraints, explain)
--Testcase 3882:
EXPLAIN VERBOSE
SELECT json_merge_preserve(c1, '[1, 2]'), json_merge_preserve(c1, '[1, 2]', '[true, false]'), json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_preserve('[1, 2]', '[true, false]') FROM s8 WHERE json_length(json_merge_preserve(c1, '[1, 2]')) != 1;

-- select json_merge_preserve (builtin function, json_merge_preserve in constraints, result)
--Testcase 3883:
SELECT json_merge_preserve(c1, '[1, 2]'), json_merge_preserve(c1, '[1, 2]', '[true, false]'), json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_preserve('[1, 2]', '[true, false]') FROM s8 WHERE json_length(json_merge_preserve(c1, '[1, 2]')) != 1;

-- select json_merge_preserve (builtin function, json_merge_preserve in constraints, explain)
--Testcase 3884:
EXPLAIN VERBOSE
SELECT json_merge_preserve(c1, '[1, 2]'), json_merge_preserve(c1, '[1, 2]', '[true, false]'), json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_preserve('[1, 2]', '[true, false]') FROM s8 WHERE json_length(json_merge_preserve('[1, 2]', '[true, false]')) = 4;

-- select json_merge_preserve (builtin function, json_merge_preserve in constraints, result)
--Testcase 3885:
SELECT json_merge_preserve(c1, '[1, 2]'), json_merge_preserve(c1, '[1, 2]', '[true, false]'), json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]'), json_merge_preserve('[1, 2]', '[true, false]') FROM s8 WHERE json_length(json_merge_preserve('[1, 2]', '[true, false]')) = 4;

-- select json_merge_preserve as nest function with agg (pushdown, explain)
--Testcase 3886:
EXPLAIN VERBOSE
SELECT sum(id),json_merge_preserve('[1, 2]', '[true, false]') FROM s8;

-- select json_merge_preserve as nest function with agg (pushdown, result)
--Testcase 3887:
SELECT sum(id),json_merge_preserve('[1, 2]', '[true, false]') FROM s8;

-- select json_merge_preserve with non pushdown func and explicit constant (EXPLAIN)
--Testcase 3888:
EXPLAIN VERBOSE
SELECT json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]'), pi(), 4.1 FROM s8;

-- select json_merge_preserve with non pushdown func and explicit constant (result)
--Testcase 3889:
SELECT json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]'), pi(), 4.1 FROM s8;

-- select json_merge_preserve with order by index (result)
--Testcase 3890:
SELECT id, json_length(json_merge_preserve(c1, '[1, 2]')) FROM s8 ORDER BY 2, 1;

-- select json_merge_preserve with order by index (result)
--Testcase 3891:
SELECT id, json_length(json_merge_preserve(c1, '[1, 2]')) FROM s8 ORDER BY 1, 2;

-- select json_merge_preserve with group by (EXPLAIN)
--Testcase 3892:
EXPLAIN VERBOSE
SELECT count(id), json_length(json_merge_preserve(c1, '[1, 2]')) FROM s8 group by json_length(json_merge_preserve(c1, '[1, 2]'));

-- select json_merge_preserve with group by (result)
--Testcase 3893:
SELECT count(id), json_length(json_merge_preserve(c1, '[1, 2]')) FROM s8 group by json_length(json_merge_preserve(c1, '[1, 2]'));

-- select json_merge_preserve with group by index (result)
--Testcase 3894:
SELECT id, json_length(json_merge_preserve(c1, '[1, 2]')) FROM s8 group by 2, 1;

-- select json_merge_preserve with group by index (result)
--Testcase 3895:
SELECT id, json_length(json_merge_preserve(c1, '[1, 2]')) FROM s8 group by 1, 2;

-- select json_merge_preserve with group by having (EXPLAIN)
--Testcase 3896:
EXPLAIN VERBOSE
SELECT count(c2), json_length(json_merge_preserve(c1, '[1, 2]')) FROM s8 group by json_length(json_merge_preserve(c1, '[1, 2]')) HAVING count(c2) > 0;

-- select json_merge_preserve with group by having (result)
--Testcase 3897:
SELECT count(c2), json_length(json_merge_preserve(c1, '[1, 2]')) FROM s8 group by json_length(json_merge_preserve(c1, '[1, 2]')) HAVING count(c2) > 0;

-- select json_merge_preserve with group by index having (result)
--Testcase 3898:
SELECT c2, json_length(json_merge_preserve(c1, '[1, 2]')) FROM s8 group by 2, 1 HAVING count(c2) > 0;

-- select json_merge_preserve with group by index having (result)
--Testcase 3899:
SELECT c2, json_length(json_merge_preserve(c1, '[1, 2]')) FROM s8 group by 1, 2 HAVING count(c2) > 0;

-- select json_merge_preserve and as
--Testcase 3900:
SELECT json_merge_preserve(json_build_array(c1, '[1, 2]'), '[true, false]') as json_merge_preserve1 FROM s8;

-- json_build_object --> json_object in mysql
-- select json_build_object (builtin function, explain)
--Testcase 3901:
EXPLAIN VERBOSE
SELECT json_build_object('a', c1, 'b', c2, 'c', c3, 'd', 1, 'e', 'this is ''text'' value', 'f', mysql_pi(), 'g', NULL, 'h', TRUE) FROM s8;

-- select json_build_object (builtin function, result)
--Testcase 3902:
SELECT json_build_object('a', c1, 'b', c2, 'c', c3, 'd', 1, 'e', 'this is ''text'' value', 'f', mysql_pi(), 'g', NULL, 'h', TRUE) FROM s8;

-- select json_build_object (builtin function, not pushdown constraints, explain)
--Testcase 3903:
EXPLAIN VERBOSE
SELECT json_build_object('a', c1, 'b', c2, 'c', c3, 'd', 1, 'e', 'this is ''text'' value', 'f', mysql_pi(), 'g', NULL, 'h', TRUE) FROM s8 WHERE to_hex(id) = '1';

-- select json_build_object (builtin function, not pushdown constraints, result)
--Testcase 3904:
SELECT json_build_object('a', c1, 'b', c2, 'c', c3, 'd', 1, 'e', 'this is ''text'' value', 'f', mysql_pi(), 'g', NULL, 'h', TRUE) FROM s8 WHERE to_hex(id) = '1';

-- select json_build_object (builtin function, pushdown constraints, explain)
--Testcase 3905:
EXPLAIN VERBOSE
SELECT json_build_object('a', c1, 'b', c2, 'c', c3, 'd', 1, 'e', 'this is ''text'' value', 'f', mysql_pi(), 'g', NULL, 'h', TRUE) FROM s8 WHERE id = 1;

-- select json_build_object (builtin function, pushdown constraints, result)
--Testcase 3906:
SELECT json_build_object('a', c1, 'b', c2, 'c', c3, 'd', 1, 'e', 'this is ''text'' value', 'f', mysql_pi(), 'g', NULL, 'h', TRUE) FROM s8 WHERE id = 1;

-- select json_build_object (builtin function, stub in constraints, explain)
--Testcase 3907:
EXPLAIN VERBOSE
SELECT json_build_object('a', c1, 'b', c2, 'c', c3, 'd', 1, 'e', 'this is ''text'' value', 'f', mysql_pi(), 'g', NULL, 'h', TRUE) FROM s8 WHERE log2(id) > 1;

-- select json_build_object (builtin function, stub in constraints, result)
--Testcase 3908:
SELECT json_build_object('a', c1, 'b', c2, 'c', c3, 'd', 1, 'e', 'this is ''text'' value', 'f', mysql_pi(), 'g', NULL, 'h', TRUE) FROM s8 WHERE log2(id) > 1;

-- select json_build_object (builtin function, stub in constraints, explain)
--Testcase 3909:
EXPLAIN VERBOSE
SELECT json_build_object('a', c1, 'b', c2, 'c', c3, 'd', 1, 'e', 'this is ''text'' value', 'f', mysql_pi(), 'g', NULL, 'h', TRUE) FROM s8 WHERE json_depth(json_build_object('a', c1, 'b', c2, 'c', c3, 'd', 1, 'e', 'this is ''text'' value', 'f', mysql_pi(), 'g', NULL, 'h', TRUE)) > 0;

-- select json_build_object (builtin function, stub in constraints, result)
--Testcase 3910:
SELECT json_build_object('a', c1, 'b', c2, 'c', c3, 'd', 1, 'e', 'this is ''text'' value', 'f', mysql_pi(), 'g', NULL, 'h', TRUE) FROM s8 WHERE json_depth(json_build_object('a', c1, 'b', c2, 'c', c3, 'd', 1, 'e', 'this is ''text'' value', 'f', mysql_pi(), 'g', NULL, 'h', TRUE)) > 0;

-- select json_build_object as nest function with agg (pushdown, explain)
--Testcase 3911:
EXPLAIN VERBOSE
SELECT sum(id),json_build_object('sum', sum(id)) FROM s8;

-- select json_build_object as nest function with agg (pushdown, result)
--Testcase 3912:
SELECT sum(id),json_build_object('sum', sum(id)) FROM s8;

-- select json_build_object as nest function with stub (pushdown, explain)
--Testcase 3913:
EXPLAIN VERBOSE
SELECT json_build_object('json_val', '{"a": 100}'::json, 'stub_log2', log2(id)) FROM s8;

-- select json_build_object as nest function with agg (pushdown, result)
--Testcase 3914:
SELECT json_build_object('json_val', '{"a": 100}'::json, 'stub_log2', log2(id)) FROM s8;

-- select json_build_object with non pushdown func and explicit constant (explain)
--Testcase 3915:
EXPLAIN VERBOSE
SELECT json_build_object('val1', '100'), cosd(id), 4.1 FROM s8;

-- select json_build_object with non pushdown func and explicit constant (result)
--Testcase 3916:
SELECT json_build_object('val1', '100'), cosd(id), 4.1 FROM s8;

-- select json_build_object with order by (explain)
--Testcase 3917:
EXPLAIN VERBOSE
SELECT json_length(json_build_object(c1, '$[1], c2')) FROM s8 ORDER BY 1;

-- select json_build_object with order by (result)
--Testcase 3918:
SELECT json_length(json_build_object(c1, '$[1], c2')) FROM s8 ORDER BY 1;

-- select json_build_object with group by (explain)
--Testcase 3919:
EXPLAIN VERBOSE
SELECT json_length(json_build_object('a', c1, 'b', c2, 'c', c3)) FROM s8 GROUP BY 1;

-- select json_build_object with group by (result)
--Testcase 3920:
SELECT json_length(json_build_object('a', c1, 'b', c2, 'c', c3)) FROM s8 GROUP BY 1;

-- select json_build_object with group by having (explain)
--Testcase 3921:
EXPLAIN VERBOSE
SELECT json_depth(json_build_object('a', c1, 'b', c2, 'c', c3)) FROM s8 GROUP BY c2, 1 HAVING count(c2) > 1;

-- select json_build_object with group by having (result)
--Testcase 3922:
SELECT json_depth(json_build_object('a', c1, 'b', c2, 'c', c3)) FROM s8 GROUP BY c2, 1 HAVING count(c2) > 1;

-- select json_build_object and as
--Testcase 3923:
SELECT json_build_object('a', c1, 'b', c2, 'c', c3) AS json_build_object1 FROM s8;

-- select json_overlaps (builtin function, explain)
--Testcase 3924:
EXPLAIN VERBOSE
SELECT json_overlaps(c1, '[[1, 2], [3, 4], 5]'), json_overlaps(json_build_array(c1, '1'), '[[1, 2], [3, 4], 5]'), json_overlaps(c1, c1),json_overlaps('{"a":1,"b":10,"d":10}', '{"c":1,"e":10,"f":1,"d":10}'),json_overlaps('[1,3,5,7]', '[2,5,7]') FROM s8;

-- select json_overlaps (builtin function, result)
--Testcase 3925:
SELECT json_overlaps(c1, '[[1, 2], [3, 4], 5]'), json_overlaps(json_build_array(c1, '1'), '[[1, 2], [3, 4], 5]'), json_overlaps(c1, c1),json_overlaps('{"a":1,"b":10,"d":10}', '{"c":1,"e":10,"f":1,"d":10}'),json_overlaps('[1,3,5,7]', '[2,5,7]') FROM s8;

-- select json_overlaps (builtin function, not pushdown constraints, explain)
--Testcase 3926:
EXPLAIN VERBOSE
SELECT json_overlaps(c1, '[[1, 2], [3, 4], 5]'), json_overlaps(json_build_array(c1, '1'), '[[1, 2], [3, 4], 5]'), json_overlaps(c1, c1),json_overlaps('{"a":1,"b":10,"d":10}', '{"c":1,"e":10,"f":1,"d":10}'),json_overlaps('[1,3,5,7]', '[2,5,7]') FROM s8 WHERE to_hex(id) = '2';

-- select json_overlaps (builtin function, not pushdown constraints, result)
--Testcase 3927:
SELECT json_overlaps(c1, '[[1, 2], [3, 4], 5]'), json_overlaps(json_build_array(c1, '1'), '[[1, 2], [3, 4], 5]'), json_overlaps(c1, c1),json_overlaps('{"a":1,"b":10,"d":10}', '{"c":1,"e":10,"f":1,"d":10}'),json_overlaps('[1,3,5,7]', '[2,5,7]') FROM s8 WHERE to_hex(id) = '2';

-- select json_overlaps (builtin function, pushdown constraints, explain)
--Testcase 3928:
EXPLAIN VERBOSE
SELECT json_overlaps(c1, '[[1, 2], [3, 4], 5]'), json_overlaps(json_build_array(c1, '1'), '[[1, 2], [3, 4], 5]'), json_overlaps(c1, c1),json_overlaps('{"a":1,"b":10,"d":10}', '{"c":1,"e":10,"f":1,"d":10}'),json_overlaps('[1,3,5,7]', '[2,5,7]') FROM s8 WHERE id != 0;

-- select json_overlaps (builtin function, pushdown constraints, result)
--Testcase 3929:
SELECT json_overlaps(c1, '[[1, 2], [3, 4], 5]'), json_overlaps(json_build_array(c1, '1'), '[[1, 2], [3, 4], 5]'), json_overlaps(c1, c1),json_overlaps('{"a":1,"b":10,"d":10}', '{"c":1,"e":10,"f":1,"d":10}'),json_overlaps('[1,3,5,7]', '[2,5,7]') FROM s8 WHERE id != 0;

-- select json_overlaps (builtin function, json_overlaps in constraints, explain)
--Testcase 3930:
EXPLAIN VERBOSE
SELECT json_overlaps(c1, '[[1, 2], [3, 4], 5]'), json_overlaps(json_build_array(c1, '1'), '[[1, 2], [3, 4], 5]'), json_overlaps(c1, c1),json_overlaps('{"a":1,"b":10,"d":10}', '{"c":1,"e":10,"f":1,"d":10}'),json_overlaps('[1,3,5,7]', '[2,5,7]') FROM s8 WHERE json_overlaps(c1, '[[1, 2], [3, 4], 5]') != 1;

-- select json_overlaps (builtin function, json_overlaps in constraints, result)
--Testcase 3931:
SELECT json_overlaps(c1, '[[1, 2], [3, 4], 5]'), json_overlaps(json_build_array(c1, '1'), '[[1, 2], [3, 4], 5]'), json_overlaps(c1, c1),json_overlaps('{"a":1,"b":10,"d":10}', '{"c":1,"e":10,"f":1,"d":10}'),json_overlaps('[1,3,5,7]', '[2,5,7]') FROM s8 WHERE json_overlaps(c1, '[[1, 2], [3, 4], 5]') != 1;

-- select json_overlaps (builtin function, json_overlaps in constraints, explain)
--Testcase 3932:
EXPLAIN VERBOSE
SELECT json_overlaps(c1, '[[1, 2], [3, 4], 5]'), json_overlaps(json_build_array(c1, '1'), '[[1, 2], [3, 4], 5]'), json_overlaps(c1, c1),json_overlaps('{"a":1,"b":10,"d":10}', '{"c":1,"e":10,"f":1,"d":10}'),json_overlaps('[1,3,5,7]', '[2,5,7]') FROM s8 WHERE json_overlaps('[1,3,5,7]', '[2,5,7]') = 1;

-- select json_overlaps (builtin function, json_overlaps in constraints, result)
--Testcase 3933:
SELECT json_overlaps(c1, '[[1, 2], [3, 4], 5]'), json_overlaps(json_build_array(c1, '1'), '[[1, 2], [3, 4], 5]'), json_overlaps(c1, c1),json_overlaps('{"a":1,"b":10,"d":10}', '{"c":1,"e":10,"f":1,"d":10}'),json_overlaps('[1,3,5,7]', '[2,5,7]') FROM s8 WHERE json_overlaps('[1,3,5,7]', '[2,5,7]') = 1;

-- select json_overlaps with non pushdown func and explicit constant (EXPLAIN)
--Testcase 3934:
EXPLAIN VERBOSE
SELECT json_overlaps(c1, c1), pi(), 4.1 FROM s8;

-- select json_overlaps with non pushdown func and explicit constant (result)
--Testcase 3935:
SELECT json_overlaps(c1, c1), pi(), 4.1 FROM s8;

-- select json_overlaps with order by index (result)
--Testcase 3936:
SELECT id,  json_overlaps(c1, '[[1, 2], [3, 4], 5]') FROM s8 ORDER BY 2, 1;

-- select json_overlaps with order by index (result)
--Testcase 3937:
SELECT id,  json_overlaps(c1, '[[1, 2], [3, 4], 5]') FROM s8 ORDER BY 1, 2;

-- select json_overlaps with group by (EXPLAIN)
--Testcase 3938:
EXPLAIN VERBOSE
SELECT count(id), json_overlaps(c1, '[[1, 2], [3, 4], 5]') FROM s8 group by json_overlaps(c1, '[[1, 2], [3, 4], 5]');

-- select json_overlaps with group by (result)
--Testcase 3939:
SELECT count(id), json_overlaps(c1, '[[1, 2], [3, 4], 5]') FROM s8 group by json_overlaps(c1, '[[1, 2], [3, 4], 5]');

-- select json_overlaps with group by index (result)
--Testcase 3940:
SELECT id,  json_overlaps(c1, '[[1, 2], [3, 4], 5]') FROM s8 group by 2, 1;

-- select json_overlaps with group by index (result)
--Testcase 3941:
SELECT id,  json_overlaps(c1, '[[1, 2], [3, 4], 5]') FROM s8 group by 1, 2;

-- select json_overlaps with group by having (EXPLAIN)
--Testcase 3942:
EXPLAIN VERBOSE
SELECT count(c2), json_overlaps(c1, '[[1, 2], [3, 4], 5]') FROM s8 group by json_overlaps(c1, '[[1, 2], [3, 4], 5]') HAVING count(c2) > 0;

-- select json_overlaps with group by having (result)
--Testcase 3943:
SELECT count(c2), json_overlaps(c1, '[[1, 2], [3, 4], 5]') FROM s8 group by json_overlaps(c1, '[[1, 2], [3, 4], 5]') HAVING count(c2) > 0;

-- select json_overlaps with group by index having (result)
--Testcase 3944:
SELECT c2,  json_overlaps(c1, '[[1, 2], [3, 4], 5]') FROM s8 group by 2, 1 HAVING count(c2) > 0;

-- select json_overlaps with group by index having (result)
--Testcase 3945:
SELECT c2,  json_overlaps(c1, '[[1, 2], [3, 4], 5]') FROM s8 group by 1, 2 HAVING count(c2) > 0;

-- select json_overlaps and as
--Testcase 3946:
SELECT json_overlaps(c1, c1) as json_overlaps1 FROM s8;

-- select json_pretty (builtin function, explain)
--Testcase 3947:
EXPLAIN VERBOSE
SELECT json_pretty(c1), json_pretty(json_build_array(c1, 1)), json_pretty('[1,3,5]'),  json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]') FROM s8;

-- select json_pretty (builtin function, result)
--Testcase 3948:
SELECT json_pretty(c1), json_pretty(json_build_array(c1, 1)), json_pretty('[1,3,5]'),  json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]') FROM s8;

-- select json_pretty (builtin function, not pushdown constraints, explain)
--Testcase 3949:
EXPLAIN VERBOSE
SELECT json_pretty(c1), json_pretty(json_build_array(c1, 1)), json_pretty('[1,3,5]'),  json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]') FROM s8 WHERE to_hex(id) = '2';

-- select json_pretty (builtin function, not pushdown constraints, result)
--Testcase 3950:
SELECT json_pretty(c1), json_pretty(json_build_array(c1, 1)), json_pretty('[1,3,5]'),  json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]') FROM s8 WHERE to_hex(id) = '2';

-- select json_pretty (builtin function, pushdown constraints, explain)
--Testcase 3951:
EXPLAIN VERBOSE
SELECT json_pretty(c1), json_pretty(json_build_array(c1, 1)), json_pretty('[1,3,5]'),  json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]') FROM s8 WHERE id != 0;

-- select json_pretty (builtin function, pushdown constraints, result)
--Testcase 3952:
SELECT json_pretty(c1), json_pretty(json_build_array(c1, 1)), json_pretty('[1,3,5]'),  json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]') FROM s8 WHERE id != 0;

-- select json_pretty (builtin function, json_pretty in constraints, explain)
--Testcase 3953:
EXPLAIN VERBOSE
SELECT json_pretty(c1), json_pretty(json_build_array(c1, 1)), json_pretty('[1,3,5]'),  json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]') FROM s8 WHERE json_length(json_pretty(c1)) != 1;

-- select json_pretty (builtin function, json_pretty in constraints, result)
--Testcase 3954:
SELECT json_pretty(c1), json_pretty(json_build_array(c1, 1)), json_pretty('[1,3,5]'),  json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]') FROM s8 WHERE json_length(json_pretty(c1)) != 1;

-- select json_pretty (builtin function, json_pretty in constraints, explain)
--Testcase 3955:
EXPLAIN VERBOSE
SELECT json_pretty(c1), json_pretty(json_build_array(c1, 1)), json_pretty('[1,3,5]'),  json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]') FROM s8 WHERE json_length( json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]')) = 8;

-- select json_pretty (builtin function, json_pretty in constraints, result)
--Testcase 3956:
SELECT json_pretty(c1), json_pretty(json_build_array(c1, 1)), json_pretty('[1,3,5]'),  json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]') FROM s8 WHERE json_length( json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]')) = 8;

-- select json_pretty as nest function with agg (pushdown, explain)
--Testcase 3957:
EXPLAIN VERBOSE
SELECT sum(id), json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]') FROM s8;

-- select json_pretty as nest function with agg (pushdown, result)
--Testcase 3958:
SELECT sum(id), json_pretty('["a",1,{"key1":"value1"},"5","77",{"key2":["value3","valuex","valuey"]},"j","2"]') FROM s8;

-- select json_pretty with non pushdown func and explicit constant (EXPLAIN)
--Testcase 3959:
EXPLAIN VERBOSE
SELECT json_pretty('[1,3,5]'), pi(), 4.1 FROM s8;

-- select json_pretty with non pushdown func and explicit constant (result)
--Testcase 3960:
SELECT json_pretty('[1,3,5]'), pi(), 4.1 FROM s8;

-- select json_pretty with order by index (result)
--Testcase 3961:
SELECT id, json_length(json_pretty(c1)) FROM s8 ORDER BY 2, 1;

-- select json_pretty with order by index (result)
--Testcase 3962:
SELECT id, json_length(json_pretty(c1)) FROM s8 ORDER BY 1, 2;

-- select json_pretty with group by (EXPLAIN)
--Testcase 3963:
EXPLAIN VERBOSE
SELECT count(id), json_length(json_pretty(c1)) FROM s8 group by json_length(json_pretty(c1));

-- select json_pretty with group by (result)
--Testcase 3964:
SELECT count(id), json_length(json_pretty(c1)) FROM s8 group by json_length(json_pretty(c1));

-- select json_pretty with group by index (result)
--Testcase 3965:
SELECT id, json_length(json_pretty(c1)) FROM s8 group by 2, 1;

-- select json_pretty with group by index (result)
--Testcase 3966:
SELECT id, json_length(json_pretty(c1)) FROM s8 group by 1, 2;

-- select json_pretty with group by having (EXPLAIN)
--Testcase 3967:
EXPLAIN VERBOSE
SELECT count(c2), json_length(json_pretty(c1)) FROM s8 group by json_length(json_pretty(c1)) HAVING count(c2) > 0;

-- select json_pretty with group by having (result)
--Testcase 3968:
SELECT count(c2), json_length(json_pretty(c1)) FROM s8 group by json_length(json_pretty(c1)) HAVING count(c2) > 0;

-- select json_pretty with group by index having (result)
--Testcase 3969:
SELECT c2, json_length(json_pretty(c1)) FROM s8 group by 2, 1 HAVING count(c2) > 0;

-- select json_pretty with group by index having (result)
--Testcase 3970:
SELECT c2, json_length(json_pretty(c1)) FROM s8 group by 1, 2 HAVING count(c2) > 0;

-- select json_pretty and as
--Testcase 3971:
SELECT json_pretty('[1,3,5]') as json_pretty1 FROM s8;

-- select json_quote (builtin function, explain)
--Testcase 3972:
EXPLAIN VERBOSE
SELECT json_quote(c3), json_quote('null'), json_quote('"null"'), json_quote('[1, 2, 3]') FROM s8;

-- select json_quote (builtin function, result)
--Testcase 3973:
SELECT json_quote(c3), json_quote('null'), json_quote('"null"'), json_quote('[1, 2, 3]') FROM s8;

-- select json_quote (builtin function, not pushdown constraints, explain)
--Testcase 3974:
EXPLAIN VERBOSE
SELECT json_quote(c3), json_quote('null'), json_quote('"null"'), json_quote('[1, 2, 3]') FROM s8 WHERE to_hex(id) = '2';

-- select json_quote (builtin function, not pushdown constraints, result)
--Testcase 3975:
SELECT json_quote(c3), json_quote('null'), json_quote('"null"'), json_quote('[1, 2, 3]') FROM s8 WHERE to_hex(id) = '2';

-- select json_quote (builtin function, pushdown constraints, explain)
--Testcase 3976:
EXPLAIN VERBOSE
SELECT json_quote(c3), json_quote('null'), json_quote('"null"'), json_quote('[1, 2, 3]') FROM s8 WHERE id != 0;

-- select json_quote (builtin function, pushdown constraints, result)
--Testcase 3977:
SELECT json_quote(c3), json_quote('null'), json_quote('"null"'), json_quote('[1, 2, 3]') FROM s8 WHERE id != 0;

-- select json_quote (builtin function, json_quote in constraints, explain)
--Testcase 3978:
EXPLAIN VERBOSE
SELECT json_quote(c3), json_quote('null'), json_quote('"null"'), json_quote('[1, 2, 3]') FROM s8 WHERE json_length(json_quote(c3)) != 0;

-- select json_quote (builtin function, json_quote in constraints, result)
--Testcase 3979:
SELECT json_quote(c3), json_quote('null'), json_quote('"null"'), json_quote('[1, 2, 3]') FROM s8 WHERE json_length(json_quote(c3)) != 0;

-- select json_quote (builtin function, json_quote in constraints, explain)
--Testcase 3980:
EXPLAIN VERBOSE
SELECT json_quote(c3), json_quote('null'), json_quote('"null"'), json_quote('[1, 2, 3]') FROM s8 WHERE json_length(json_quote('[1, 2, 3]')) = 1;

-- select json_quote (builtin function, json_quote in constraints, result)
--Testcase 3981:
SELECT json_quote(c3), json_quote('null'), json_quote('"null"'), json_quote('[1, 2, 3]') FROM s8 WHERE json_length(json_quote('[1, 2, 3]')) = 1;

-- select json_quote as nest function with agg (pushdown, explain)
--Testcase 3982:
EXPLAIN VERBOSE
SELECT sum(id), json_quote('[1, 2, 3]') FROM s8;

-- select json_quote as nest function with agg (pushdown, result)
--Testcase 3983:
SELECT sum(id), json_quote('[1, 2, 3]') FROM s8;

-- select json_quote with non pushdown func and explicit constant (EXPLAIN)
--Testcase 3984:
EXPLAIN VERBOSE
SELECT json_quote('null'), pi(), 4.1 FROM s8;

-- select json_quote with non pushdown func and explicit constant (result)
--Testcase 3985:
SELECT json_quote('null'), pi(), 4.1 FROM s8;

-- select json_quote with order by index (result)
--Testcase 3986:
SELECT id,  json_length(json_quote(c3)) FROM s8 ORDER BY 2, 1;

-- select json_quote with order by index (result)
--Testcase 3987:
SELECT id,  json_length(json_quote(c3)) FROM s8 ORDER BY 1, 2;

-- select json_quote with group by (EXPLAIN)
--Testcase 3988:
EXPLAIN VERBOSE
SELECT count(id), json_length(json_quote(c3)) FROM s8 group by json_length(json_quote(c3));

-- select json_quote with group by (result)
--Testcase 3989:
SELECT count(id), json_length(json_quote(c3)) FROM s8 group by json_length(json_quote(c3));

-- select json_quote with group by index (result)
--Testcase 3990:
SELECT id,  json_length(json_quote(c3)) FROM s8 group by 2, 1;

-- select json_quote with group by index (result)
--Testcase 3991:
SELECT id,  json_length(json_quote(c3)) FROM s8 group by 1, 2;

-- select json_quote with group by having (EXPLAIN)
--Testcase 3992:
EXPLAIN VERBOSE
SELECT count(c2), json_length(json_quote(c3)) FROM s8 group by json_length(json_quote(c3)) HAVING count(c2) > 0;

-- select json_quote with group by having (result)
--Testcase 3993:
SELECT count(c2), json_length(json_quote(c3)) FROM s8 group by json_length(json_quote(c3)) HAVING count(c2) > 0;

-- select json_quote with group by index having (result)
--Testcase 3994:
SELECT c2,  json_length(json_quote(c3)) FROM s8 group by 2, 1 HAVING count(c2) > 0;

-- select json_quote with group by index having (result)
--Testcase 3995:
SELECT c2,  json_length(json_quote(c3)) FROM s8 group by 1, 2 HAVING count(c2) > 0;

-- select json_quote and as
--Testcase 3996:
SELECT json_quote('null') as json_quote1 FROM s8;

-- select json_remove (builtin function, explain)
--Testcase 3997:
EXPLAIN VERBOSE
SELECT json_remove(c1, '$[1]'), json_remove(c1, '$[1]', '$[2]'),json_remove(json_build_array(c1, '1'), '$[1]', '$[2]'), json_remove('{ "a": 1, "b": [2, 3]}', '$.a'), json_remove('["a", ["b", "c"], "d"]', '$.a') FROM s8;

-- select json_remove (builtin function, result)
--Testcase 3998:
SELECT json_remove(c1, '$[1]'), json_remove(c1, '$[1]', '$[2]'), json_remove(json_build_array(c1, '1'), '$[1]', '$[2]'), json_remove('{ "a": 1, "b": [2, 3]}', '$.a'), json_remove('["a", ["b", "c"], "d"]', '$.a') FROM s8;

-- select json_remove (builtin function, not pushdown constraints, explain)
--Testcase 3999:
EXPLAIN VERBOSE
SELECT json_remove(c1, '$[1]'), json_remove(c1, '$[1]', '$[2]'), json_remove(json_build_array(c1, '1'), '$[1]', '$[2]'), json_remove('{ "a": 1, "b": [2, 3]}', '$.a'), json_remove('["a", ["b", "c"], "d"]', '$.a') FROM s8 WHERE to_hex(id) = '2';

-- select json_remove (builtin function, not pushdown constraints, result)
--Testcase 4000:
SELECT json_remove(c1, '$[1]'), json_remove(c1, '$[1]', '$[2]'), json_remove(json_build_array(c1, '1'), '$[1]', '$[2]'), json_remove('{ "a": 1, "b": [2, 3]}', '$.a'), json_remove('["a", ["b", "c"], "d"]', '$.a') FROM s8 WHERE to_hex(id) = '2';

-- select json_remove (builtin function, pushdown constraints, explain)
--Testcase 4001:
EXPLAIN VERBOSE
SELECT json_remove(c1, '$[1]'), json_remove(c1, '$[1]', '$[2]'), json_remove(json_build_array(c1, '1'), '$[1]', '$[2]'), json_remove('{ "a": 1, "b": [2, 3]}', '$.a'), json_remove('["a", ["b", "c"], "d"]', '$.a') FROM s8 WHERE id != 0;

-- select json_remove (builtin function, pushdown constraints, result)
--Testcase 4002:
SELECT json_remove(c1, '$[1]'), json_remove(c1, '$[1]', '$[2]'), json_remove(json_build_array(c1, '1'), '$[1]', '$[2]'), json_remove('{ "a": 1, "b": [2, 3]}', '$.a'), json_remove('["a", ["b", "c"], "d"]', '$.a') FROM s8 WHERE id != 0;

-- select json_remove (builtin function, json_remove in constraints, explain)
--Testcase 4003:
EXPLAIN VERBOSE
SELECT json_remove(c1, '$[1]'), json_remove(c1, '$[1]', '$[2]'), json_remove(json_build_array(c1, '1'), '$[1]', '$[2]'), json_remove('{ "a": 1, "b": [2, 3]}', '$.a'), json_remove('["a", ["b", "c"], "d"]', '$.a') FROM s8 WHERE json_length(json_remove(c1, '$[1]')) != 1;

-- select json_remove (builtin function, json_remove in constraints, result)
--Testcase 4004:
SELECT json_remove(c1, '$[1]'), json_remove(c1, '$[1]', '$[2]'), json_remove(json_build_array(c1, '1'), '$[1]', '$[2]'), json_remove('{ "a": 1, "b": [2, 3]}', '$.a'), json_remove('["a", ["b", "c"], "d"]', '$.a') FROM s8 WHERE json_length(json_remove(c1, '$[1]')) != 1;

-- select json_remove (builtin function, json_remove in constraints, explain)
--Testcase 4005:
EXPLAIN VERBOSE
SELECT json_remove(c1, '$[1]'), json_remove(c1, '$[1]', '$[2]'), json_remove(json_build_array(c1, '1'), '$[1]', '$[2]'), json_remove('{ "a": 1, "b": [2, 3]}', '$.a'), json_remove('["a", ["b", "c"], "d"]', '$.a') FROM s8 WHERE json_length(json_remove('{ "a": 1, "b": [2, 3]}', '$.a')) = 1;

-- select json_remove (builtin function, json_remove in constraints, result)
--Testcase 4006:
SELECT json_remove(c1, '$[1]'), json_remove(c1, '$[1]', '$[2]'), json_remove(json_build_array(c1, '1'), '$[1]', '$[2]'), json_remove('{ "a": 1, "b": [2, 3]}', '$.a'), json_remove('["a", ["b", "c"], "d"]', '$.a') FROM s8 WHERE json_length(json_remove('{ "a": 1, "b": [2, 3]}', '$.a')) = 1;

-- select json_remove as nest function with agg (pushdown, explain)
--Testcase 4007:
EXPLAIN VERBOSE
SELECT sum(id), json_remove('{ "a": 1, "b": [2, 3]}', '$.a') FROM s8;

-- select json_remove as nest function with agg (pushdown, result)
--Testcase 4008:
SELECT sum(id), json_remove('{ "a": 1, "b": [2, 3]}', '$.a') FROM s8;

-- select json_remove with non pushdown func and explicit constant (EXPLAIN)
--Testcase 4009:
EXPLAIN VERBOSE
SELECT json_remove(json_build_array(c1, '1'), '$[1]', '$[2]'), pi(), 4.1 FROM s8;

-- select json_remove with non pushdown func and explicit constant (result)
--Testcase 4010:
SELECT json_remove(json_build_array(c1, '1'), '$[1]', '$[2]'), pi(), 4.1 FROM s8;

-- select json_remove with order by index (result)
--Testcase 4011:
SELECT id,  json_length(json_remove(c1, '$[1]')) FROM s8 ORDER BY 2, 1;

-- select json_remove with order by index (result)
--Testcase 4012:
SELECT id,  json_length(json_remove(c1, '$[1]')) FROM s8 ORDER BY 1, 2;

-- select json_remove with group by (EXPLAIN)
--Testcase 4013:
EXPLAIN VERBOSE
SELECT count(id), json_length(json_remove(c1, '$[1]')) FROM s8 group by json_length(json_remove(c1, '$[1]'));

-- select json_remove with group by (result)
--Testcase 4014:
SELECT count(id), json_length(json_remove(c1, '$[1]')) FROM s8 group by json_length(json_remove(c1, '$[1]'));

-- select json_remove with group by index (result)
--Testcase 4015:
SELECT id,  json_length(json_remove(c1, '$[1]')) FROM s8 group by 2, 1;

-- select json_remove with group by index (result)
--Testcase 4016:
SELECT id,  json_length(json_remove(c1, '$[1]')) FROM s8 group by 1, 2;

-- select json_remove with group by having (EXPLAIN)
--Testcase 4017:
EXPLAIN VERBOSE
SELECT count(c2), json_length(json_remove(c1, '$[1]')) FROM s8 group by json_length(json_remove(c1, '$[1]')) HAVING count(c2) > 0;

-- select json_remove with group by having (result)
--Testcase 4018:
SELECT count(c2), json_length(json_remove(c1, '$[1]')) FROM s8 group by json_length(json_remove(c1, '$[1]')) HAVING count(c2) > 0;

-- select json_remove with group by index having (result)
--Testcase 4019:
SELECT c2,  json_length(json_remove(c1, '$[1]')) FROM s8 group by 2, 1 HAVING count(c2) > 0;

-- select json_remove with group by index having (result)
--Testcase 4020:
SELECT c2,  json_length(json_remove(c1, '$[1]')) FROM s8 group by 1, 2 HAVING count(c2) > 0;

-- select json_remove and as
--Testcase 4021:
SELECT json_remove(json_build_array(c1, '1'), '$[1]', '$[2]') as json_remove1 FROM s8;

-- select json_replace (stub function, explain)
--Testcase 4022:
EXPLAIN VERBOSE
SELECT json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8;

-- select json_replace (stub function, result)
--Testcase 4023:
SELECT json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8;

-- select json_replace (stub function, not pushdown constraints, explain)
--Testcase 4024:
EXPLAIN VERBOSE
SELECT json_replace(c1, '$.a, c2', '$.b, c3', '$.c, NULL', '$, TRUE', '$, pi()') FROM s8 WHERE to_hex(id) = '1';

-- select json_replace (stub function, not pushdown constraints, result)
--Testcase 4025:
SELECT json_replace(c1, '$.a, c2', '$.b, c3', '$.c, NULL', '$, TRUE', '$, pi()') FROM s8 WHERE to_hex(id) = '1';

-- select json_replace (stub function, pushdown constraints, explain)
--Testcase 4026:
EXPLAIN VERBOSE
SELECT json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, CAST("[true, false]" AS JSON)') FROM s8 WHERE id = 1;

-- select json_replace (stub function, pushdown constraints, result)
--Testcase 4027:
SELECT json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, CAST("[true, false]" AS JSON)') FROM s8 WHERE id = 1;

-- select json_replace (stub function, stub in constraints, explain)
--Testcase 4028:
EXPLAIN VERBOSE
SELECT json_replace(c1, '$.a, c2', '$.b, c3', '$.c, NULL', '$, TRUE', '$, "[true, false]"') FROM s8 WHERE log2(id) > 1;

-- select json_replace (stub function, stub in constraints, result)
--Testcase 4029:
SELECT json_replace(c1, '$.a, c2', '$.b, c3', '$.c, NULL', '$, TRUE', '$, "[true, false]"') FROM s8 WHERE log2(id) > 1;

-- select json_replace (stub function, stub in constraints, explain)
--Testcase 4030:
EXPLAIN VERBOSE
SELECT json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8 WHERE json_depth(json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()')) > 0;

-- select json_replace (stub function, stub in constraints, result)
--Testcase 4031:
SELECT json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8 WHERE json_depth(json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()')) > 0;

-- json_replace with 1 arg explain
--Testcase 4032:
EXPLAIN VERBOSE
SELECT json_replace(c1, '$.a, c2') FROM s8;

-- json_replace with 1 arg result
--Testcase 4033:
SELECT json_replace(c1, '$.a, c2') FROM s8;

-- json_replace with 2 args explain
--Testcase 4034:
EXPLAIN VERBOSE
SELECT json_replace(c1, '$.a, c2', '$.b, c3') FROM s8;

-- json_replace with 2 args result
--Testcase 4035:
SELECT json_replace(c1, '$.a, c2', '$.b, c3') FROM s8;

-- json_replace with 3 args explain
--Testcase 4036:
EXPLAIN VERBOSE
SELECT json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1') FROM s8;

-- json_replace with 3 args result
--Testcase 4037:
SELECT json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1') FROM s8;

-- json_replace with 4 args explain
--Testcase 4038:
EXPLAIN VERBOSE
SELECT json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"') FROM s8;

-- json_replace with 4 args result
--Testcase 4039:
SELECT json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"') FROM s8;

-- json_replace with 5 args explain
--Testcase 4040:
EXPLAIN VERBOSE
SELECT json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8;

-- json_replace with 5 args result
--Testcase 4041:
SELECT json_replace(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8;

-- select json_replace as nest function with agg (pushdown, explain)
--Testcase 4042:
EXPLAIN VERBOSE
SELECT sum(id),json_replace('["a", ["b", "c"], "d"]', '$, sum(id)') FROM s8;

-- select json_replace as nest function with agg (pushdown, result)
--Testcase 4043:
SELECT sum(id),json_replace('["a", ["b", "c"], "d"]', '$, sum(id)') FROM s8;

-- select json_replace as nest function with json_build_array (pushdown, explain)
--Testcase 4044:
EXPLAIN VERBOSE
SELECT json_replace(json_build_array('["a", ["b", "c"], "d"]', c1), '$, log2(id)') FROM s8;

-- select json_replace as nest function with agg (pushdown, result)
--Testcase 4045:
SELECT json_replace(json_build_array('["a", ["b", "c"], "d"]', c1), '$, log2(id)') FROM s8;

-- select json_replace with non pushdown func and explicit constant (explain)
--Testcase 4046:
EXPLAIN VERBOSE
SELECT json_replace(c1, '$.a, c2'), pi(), 4.1 FROM s8;

-- select json_replace with non pushdown func and explicit constant (result)
--Testcase 4047:
SELECT json_replace(c1, '$.a, c2'), pi(), 4.1 FROM s8;

-- select json_replace with order by (explain)
--Testcase 4048:
EXPLAIN VERBOSE
SELECT json_length(json_replace(c1, '$.a, c2')) FROM s8 ORDER BY 1;

-- select json_replace with order by (result)
--Testcase 4049:
SELECT json_length(json_replace(c1, '$.a, c2')) FROM s8 ORDER BY 1;

-- select json_replace with group by (explain)
--Testcase 4050:
EXPLAIN VERBOSE
SELECT json_length(json_replace('["a", ["b", "c"], "d"]', '$, id')) FROM s8 GROUP BY 1;

-- select json_replace with group by (result)
--Testcase 4051:
SELECT json_length(json_replace('["a", ["b", "c"], "d"]', '$, id')) FROM s8 GROUP BY 1;

-- select json_replace with group by having (explain)
--Testcase 4052:
EXPLAIN VERBOSE
SELECT json_depth(json_replace('["a", ["b", "c"], "d"]', '$, c2')) FROM s8 GROUP BY c2, 1 HAVING count(c2) > 1;

-- select json_replace with group by having (result)
--Testcase 4053:
SELECT json_depth(json_replace('["a", ["b", "c"], "d"]', '$, c2')) FROM s8 GROUP BY c2, 1 HAVING count(c2) > 1;

-- select json_replace and as
--Testcase 4054:
SELECT json_replace(c1, '$.a, c2') AS json_replace1 FROM s8;

-- select json_schema_valid (builtin function, explain)
--Testcase 4055:
EXPLAIN VERBOSE
SELECT json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 9}'::json), json_schema_valid(c1, json_quote('null')), json_schema_valid(c1, '{}'), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9;

-- select json_schema_valid (builtin function, result)
--Testcase 4056:
SELECT json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 9}'::json), json_schema_valid(c1, json_quote('null')), json_schema_valid(c1, '{}'), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9;

-- select json_schema_valid (builtin function, not pushdown constraints, explain)
--Testcase 4057:
EXPLAIN VERBOSE
SELECT json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 9}'::json), json_schema_valid(c1, json_quote('null')), json_schema_valid(c1, '{}'), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE to_hex(id) = '1';

-- select json_schema_valid (builtin function, not pushdown constraints, result)
--Testcase 4058:
SELECT json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 9}'::json), json_schema_valid(c1, json_quote('null')), json_schema_valid(c1, '{}'), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE to_hex(id) = '1';

-- select json_schema_valid (builtin function, pushdown constraints, explain)
--Testcase 4059:
EXPLAIN VERBOSE
SELECT json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 9}'::json), json_schema_valid(c1, json_quote('null')), json_schema_valid(c1, '{}'), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE id != 0;

-- select json_schema_valid (builtin function, pushdown constraints, result)
--Testcase 4060:
SELECT json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 9}'::json), json_schema_valid(c1, json_quote('null')), json_schema_valid(c1, '{}'), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE id != 0;

-- select json_schema_valid (builtin function, json_schema_valid in constraints, explain)
--Testcase 4061:
EXPLAIN VERBOSE
SELECT json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 9}'::json), json_schema_valid(c1, json_quote('null')), json_schema_valid(c1, '{}'), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) != 0;

-- select json_schema_valid (builtin function, json_schema_valid in constraints, result)
--Testcase 4062:
SELECT json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 9}'::json), json_schema_valid(c1, json_quote('null')), json_schema_valid(c1, '{}'), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) != 0;

-- select json_schema_valid (builtin function, json_schema_valid in constraints, explain)
--Testcase 4063:
EXPLAIN VERBOSE
SELECT json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 9}'::json), json_schema_valid(c1, json_quote('null')), json_schema_valid(c1, '{}'), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 30}'::json) = 1;

-- select json_schema_valid (builtin function, json_schema_valid in constraints, result)
--Testcase 4064:
SELECT json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 9}'::json), json_schema_valid(c1, json_quote('null')), json_schema_valid(c1, '{}'), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 30}'::json) = 1;

-- select json_schema_valid as nest function with agg (pushdown, explain)
--Testcase 4065:
EXPLAIN VERBOSE
SELECT sum(id),json_schema_valid(json_build_object('latitude', sum(id), 'longitude', avg(id)), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9;

-- select json_schema_valid as nest function with agg (pushdown, result)
--Testcase 4066:
SELECT sum(id),json_schema_valid(json_build_object('latitude', sum(id), 'longitude', avg(id)), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9;

-- select json_schema_valid with non pushdown func and explicit constant (EXPLAIN)
--Testcase 4067:
EXPLAIN VERBOSE
SELECT json_schema_valid(c1, json_quote('null')), pi(), 4.1 FROM s9;

-- select json_schema_valid with non pushdown func and explicit constant (result)
--Testcase 4068:
SELECT json_schema_valid(c1, json_quote('null')), pi(), 4.1 FROM s9;

-- select json_schema_valid with order by index (result)
--Testcase 4069:
SELECT id,  json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) FROM s9 order by 2, 1;

-- select json_schema_valid with order by index (result)
--Testcase 4070:
SELECT id,  json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) FROM s9 order by 1, 2;

-- select json_schema_valid with group by (EXPLAIN)
--Testcase 4071:
EXPLAIN VERBOSE
SELECT count(id), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) FROM s9 group by json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json);

-- select json_schema_valid with group by (result)
--Testcase 4072:
SELECT count(id), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) FROM s9 group by json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json);

-- select json_schema_valid with group by index (result)
--Testcase 4073:
SELECT id,  json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) FROM s9 group by 2, 1;

-- select json_schema_valid with group by index (result)
--Testcase 4074:
SELECT id,  json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) FROM s9 group by 1, 2;

-- select json_schema_valid with group by having (EXPLAIN)
--Testcase 4075:
EXPLAIN VERBOSE
SELECT count(id), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) FROM s9 group by json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) HAVING count(id) > 0;

-- select json_schema_valid with group by having (result)
--Testcase 4076:
SELECT count(id), json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) FROM s9 group by json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) HAVING count(id) > 0;

-- select json_schema_valid with group by index having (result)
--Testcase 4077:
SELECT id,  json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) FROM s9 group by 2, 1 HAVING count(id) > 0;

-- select json_schema_valid with group by index having (result)
--Testcase 4078:
SELECT id,  json_schema_valid(c1, '{"latitude": 63.444697,"longitude": 10.445118}'::json) FROM s9 group by 1, 2 HAVING count(id) > 0;

-- select json_schema_valid and as
--Testcase 4079:
SELECT json_schema_valid(c1, json_quote('null')) as json_schema_valid1 FROM s9;

-- select json_schema_validation_report (builtin function, explain)
--Testcase 4080:
EXPLAIN VERBOSE
SELECT json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}'), json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.5}'), json_schema_validation_report(c1, json_quote('null')), json_schema_validation_report(c1, '{}'), json_schema_validation_report(json_build_object('latitude', 63, 'longitude', 30), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9;

-- select json_schema_validation_report (builtin function, result)
--Testcase 4081:
SELECT json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}'), json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.5}'), json_schema_validation_report(c1, json_quote('null')), json_schema_validation_report(c1, '{}'), json_schema_validation_report(json_build_object('latitude', 63, 'longitude', 30), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9;

-- select json_schema_validation_report (builtin function, not pushdown constraints, explain)
--Testcase 4082:
EXPLAIN VERBOSE
SELECT json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}'), json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.5}'), json_schema_validation_report(c1, json_quote('null')), json_schema_validation_report(c1, '{}'), json_schema_validation_report(json_build_object('latitude', 63, 'longitude', 30), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE to_hex(id) = '1';

-- select json_schema_validation_report (builtin function, not pushdown constraints, result)
--Testcase 4083:
SELECT json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}'), json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.5}'), json_schema_validation_report(c1, json_quote('null')), json_schema_validation_report(c1, '{}'), json_schema_validation_report(json_build_object('latitude', 63, 'longitude', 30), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE to_hex(id) = '1';

-- select json_schema_validation_report (builtin function, pushdown constraints, explain)
--Testcase 4084:
EXPLAIN VERBOSE
SELECT json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}'), json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.5}'), json_schema_validation_report(c1, json_quote('null')), json_schema_validation_report(c1, '{}'), json_schema_validation_report(json_build_object('latitude', 63, 'longitude', 30), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE id != 0;

-- select json_schema_validation_report (builtin function, pushdown constraints, result)
--Testcase 4085:
SELECT json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}'), json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.5}'), json_schema_validation_report(c1, json_quote('null')), json_schema_validation_report(c1, '{}'), json_schema_validation_report(json_build_object('latitude', 63, 'longitude', 30), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE id != 0;

-- select json_schema_validation_report (builtin function, json_schema_validation_report in constraints, explain)
--Testcase 4086:
EXPLAIN VERBOSE
SELECT json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}'), json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.5}'), json_schema_validation_report(c1, json_quote('null')), json_schema_validation_report(c1, '{}'), json_schema_validation_report(json_build_object('latitude', 63, 'longitude', 30), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) != 0;

-- select json_schema_validation_report (builtin function, json_schema_validation_report in constraints, result)
--Testcase 4087:
SELECT json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}'), json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.5}'), json_schema_validation_report(c1, json_quote('null')), json_schema_validation_report(c1, '{}'), json_schema_validation_report(json_build_object('latitude', 63, 'longitude', 30), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) != 0;

-- select json_schema_validation_report (builtin function, json_schema_validation_report in constraints, explain)
--Testcase 4088:
EXPLAIN VERBOSE
SELECT json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}'), json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.5}'), json_schema_validation_report(c1, json_quote('null')), json_schema_validation_report(c1, '{}'), json_schema_validation_report(json_build_object('latitude', 63, 'longitude', 30), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE json_length(json_schema_validation_report(json_build_object('latitude', 63, 'longitude', 30), '{"latitude": 63.444697,"longitude": 30}'::json)) = 1;

-- select json_schema_validation_report (builtin function, json_schema_validation_report in constraints, result)
--Testcase 4089:
SELECT json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}'), json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.5}'), json_schema_validation_report(c1, json_quote('null')), json_schema_validation_report(c1, '{}'), json_schema_validation_report(json_build_object('latitude', 63, 'longitude', 30), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9 WHERE json_length(json_schema_validation_report(json_build_object('latitude', 63, 'longitude', 30), '{"latitude": 63.444697,"longitude": 30}'::json)) = 1;

-- select json_schema_validation_report as nest function with agg (pushdown, explain)
--Testcase 4090:
EXPLAIN VERBOSE
SELECT sum(id),json_schema_validation_report(json_build_object('latitude', 63, 'longitude', sum(id)), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9;

-- select json_schema_validation_report as nest function with agg (pushdown, result)
--Testcase 4091:
SELECT sum(id),json_schema_validation_report(json_build_object('latitude', 63, 'longitude', sum(id)), '{"latitude": 63.444697,"longitude": 30}'::json) FROM s9;

-- select json_schema_validation_report with non pushdown func and explicit constant (EXPLAIN)
--Testcase 4092:
EXPLAIN VERBOSE
SELECT json_schema_validation_report(c1, json_quote('null')), pi(), 4.1 FROM s9;

-- select json_schema_validation_report with non pushdown func and explicit constant (result)
--Testcase 4093:
SELECT json_schema_validation_report(c1, json_quote('null')), pi(), 4.1 FROM s9;

-- select json_schema_validation_report with order by index (result)
--Testcase 4094:
SELECT id,  json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) FROM s9 order by 2, 1;

-- select json_schema_validation_report with order by index (result)
--Testcase 4095:
SELECT id,  json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) FROM s9 order by 1, 2;

-- select json_schema_validation_report with group by (EXPLAIN)
--Testcase 4096:
EXPLAIN VERBOSE
SELECT count(id), json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) FROM s9 group by json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}'));

-- select json_schema_validation_report with group by (result)
--Testcase 4097:
SELECT count(id), json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) FROM s9 group by json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}'));

-- select json_schema_validation_report with group by index (result)
--Testcase 4098:
SELECT id,  json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) FROM s9 group by 2, 1;

-- select json_schema_validation_report with group by index (result)
--Testcase 4099:
SELECT id,  json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) FROM s9 group by 1, 2;

-- select json_schema_validation_report with group by having (EXPLAIN)
--Testcase 4100:
EXPLAIN VERBOSE
SELECT count(id), json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) FROM s9 group by json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) HAVING count(id) > 0;

-- select json_schema_validation_report with group by having (result)
--Testcase 4101:
SELECT count(id), json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) FROM s9 group by json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) HAVING count(id) > 0;

-- select json_schema_validation_report with group by index having (result)
--Testcase 4102:
SELECT id,  json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) FROM s9 group by 2, 1 HAVING count(id) > 0;

-- select json_schema_validation_report with group by index having (result)
--Testcase 4103:
SELECT id,  json_length(json_schema_validation_report(c1, '{"latitude": 63.444697,"longitude": 10.445118}')) FROM s9 group by 1, 2 HAVING count(id) > 0;

-- select json_schema_validation_report and as
--Testcase 4104:
SELECT json_schema_validation_report(c1, json_quote('null')) as json_schema_validation_report1 FROM s9;

-- select json_search (builtin function, explain)
--Testcase 4105:
EXPLAIN VERBOSE
SELECT json_search(c1, 'one', 'abc'), json_search(json_build_array(c1, '1'), 'all', 'abc'), json_search(c1, 'one', '%a%'),json_search('{"a":1,"b":10,"d":10}', 'all', '%1%'),json_search('[1,3,5,7]', 'one', '[2,5,7]') FROM s8;

-- select json_search (builtin function, result)
--Testcase 4106:
SELECT json_search(c1, 'one', 'abc'), json_search(json_build_array(c1, '1'), 'all', 'abc'), json_search(c1, 'one', '%a%'),json_search('{"a":1,"b":10,"d":10}', 'all', '%1%'),json_search('[1,3,5,7]', 'one', '[2,5,7]') FROM s8;

-- select json_search (builtin function, not pushdown constraints, explain)
--Testcase 4107:
EXPLAIN VERBOSE
SELECT json_search(c1, 'one', 'abc'), json_search(json_build_array(c1, '1'), 'all', 'abc'), json_search(c1, 'one', '%a%'),json_search('{"a":1,"b":10,"d":10}', 'all', '%1%'),json_search('[1,3,5,7]', 'one', '[2,5,7]') FROM s8 WHERE to_hex(id) = '2';

-- select json_search (builtin function, not pushdown constraints, result)
--Testcase 4108:
SELECT json_search(c1, 'one', 'abc'), json_search(json_build_array(c1, '1'), 'all', 'abc'), json_search(c1, 'one', '%a%'),json_search('{"a":1,"b":10,"d":10}', 'all', '%1%'),json_search('[1,3,5,7]', 'one', '[2,5,7]') FROM s8 WHERE to_hex(id) = '2';

-- select json_search (builtin function, pushdown constraints, explain)
--Testcase 4109:
EXPLAIN VERBOSE
SELECT json_search(c1, 'one', 'abc'), json_search(json_build_array(c1, '1'), 'all', 'abc'), json_search(c1, 'one', '%a%'),json_search('{"a":1,"b":10,"d":10}', 'all', '%1%'),json_search('[1,3,5,7]', 'one', '[2,5,7]') FROM s8 WHERE id != 0;

-- select json_search (builtin function, pushdown constraints, result)
--Testcase 4110:
SELECT json_search(c1, 'one', 'abc'), json_search(json_build_array(c1, '1'), 'all', 'abc'), json_search(c1, 'one', '%a%'),json_search('{"a":1,"b":10,"d":10}', 'all', '%1%'),json_search('[1,3,5,7]', 'one', '[2,5,7]') FROM s8 WHERE id != 0;

-- select json_search (builtin function, json_search in constraints, explain)
--Testcase 4111:
EXPLAIN VERBOSE
SELECT json_search(c1, 'one', 'abc'), json_search(json_build_array(c1, '1'), 'all', 'abc'), json_search(c1, 'one', '%a%'),json_search('{"a":1,"b":10,"d":10}', 'all', '%1%'),json_search('[1,3,5,7]', 'one', '[2,5,7]') FROM s8 WHERE json_search(c1, 'one', 'abc') NOT LIKE '$';

-- select json_search (builtin function, json_search in constraints, result)
--Testcase 4112:
SELECT json_search(c1, 'one', 'abc'), json_search(json_build_array(c1, '1'), 'all', 'abc'), json_search(c1, 'one', '%a%'),json_search('{"a":1,"b":10,"d":10}', 'all', '%1%'),json_search('[1,3,5,7]', 'one', '[2,5,7]') FROM s8 WHERE json_search(c1, 'one', 'abc') NOT LIKE '$';

-- select json_search (builtin function, json_search in constraints, explain)
--Testcase 4113:
EXPLAIN VERBOSE
SELECT json_search(c1, 'one', 'abc'), json_search(json_build_array(c1, '1'), 'all', 'abc'), json_search(c1, 'one', '%a%'),json_search('{"a":1,"b":10,"d":10}', 'all', '%1%'),json_search('[1,3,5,7]', 'one', '[2,5,7]') FROM s8 where json_search('[1,3,5,7]', 'one', '[2,5,7]') IS NULL;

-- select json_search (builtin function, json_search in constraints, result)
--Testcase 4114:
SELECT json_search(c1, 'one', 'abc'), json_search(json_build_array(c1, '1'), 'all', 'abc'), json_search(c1, 'one', '%a%'),json_search('{"a":1,"b":10,"d":10}', 'all', '%1%'),json_search('[1,3,5,7]', 'one', '[2,5,7]') FROM s8 where json_search('[1,3,5,7]', 'one', '[2,5,7]') IS NULL;

-- select json_search as nest function with agg (pushdown, explain)
--Testcase 4115:
EXPLAIN VERBOSE
SELECT sum(id),json_search(json_build_array('{"a":1,"b":10,"d":10}', sum(id)), 'all', 'a') FROM s8;

-- select json_search as nest function with agg (pushdown, result)
--Testcase 4116:
SELECT sum(id),json_search(json_build_array('{"a":1,"b":10,"d":10}', sum(id)), 'all', 'a') FROM s8;

-- select json_search with non pushdown func and explicit constant (EXPLAIN)
--Testcase 4117:
EXPLAIN VERBOSE
SELECT json_search(c1, 'one', '%a%'), pi(), 4.1 FROM s8;

-- select json_search with non pushdown func and explicit constant (result)
--Testcase 4118:
SELECT json_search(c1, 'one', '%a%'), pi(), 4.1 FROM s8;


-- select json_search with order by index (result)
--Testcase 4119:
SELECT id, json_search(c1, 'one', 'abc') FROM s8 ORDER BY 2, 1;

-- select json_search with order by index (result)
--Testcase 4120:
SELECT id, json_search(c1, 'one', 'abc') FROM s8 ORDER BY 1, 2;

-- select json_search with group by (EXPLAIN)
--Testcase 4121:
EXPLAIN VERBOSE
SELECT count(id), json_search(c1, 'one', 'abc') FROM s8 group by json_search(c1, 'one', 'abc');

-- select json_search with group by (result)
--Testcase 4122:
SELECT count(id), json_search(c1, 'one', 'abc') FROM s8 group by json_search(c1, 'one', 'abc');

-- select json_search with group by index (result)
--Testcase 4123:
SELECT id, json_search(c1, 'one', 'abc') FROM s8 group by 2, 1;

-- select json_search with group by index (result)
--Testcase 4124:
SELECT id, json_search(c1, 'one', 'abc') FROM s8 group by 1, 2;

-- select json_search with group by having (EXPLAIN)
--Testcase 4125:
EXPLAIN VERBOSE
SELECT count(c2), json_search(c1, 'one', 'abc') FROM s8 group by json_search(c1, 'one', 'abc') HAVING count(c2) > 0;

-- select json_search with group by having (result)
--Testcase 4126:
SELECT count(c2), json_search(c1, 'one', 'abc') FROM s8 group by json_search(c1, 'one', 'abc') HAVING count(c2) > 0;

-- select json_search with group by index having (result)
--Testcase 4127:
SELECT c2, json_search(c1, 'one', 'abc') FROM s8 group by 2, 1 HAVING count(c2) > 0;

-- select json_search with group by index having (result)
--Testcase 4128:
SELECT c2, json_search(c1, 'one', 'abc') FROM s8 group by 1, 2 HAVING count(c2) > 0;

-- select json_search and as
--Testcase 4129:
SELECT json_search(c1, 'one', '%a%') as json_search1 FROM s8;

-- JSON_SET()
-- select json_set (stub function, explain)
--Testcase 4130:
EXPLAIN VERBOSE
SELECT json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8;

-- select json_set (stub function, result)
--Testcase 4131:
SELECT json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8;

-- select json_set (stub function, not pushdown constraints, explain)
--Testcase 4132:
EXPLAIN VERBOSE
SELECT json_set(c1, '$.a, c2', '$.b, c3', '$.c, NULL', '$, TRUE', '$, pi()') FROM s8 WHERE to_hex(id) = '1';

-- select json_set (stub function, not pushdown constraints, result)
--Testcase 4133:
SELECT json_set(c1, '$.a, c2', '$.b, c3', '$.c, NULL', '$, TRUE', '$, pi()') FROM s8 WHERE to_hex(id) = '1';

-- select json_set (stub function, pushdown constraints, explain)
--Testcase 4134:
EXPLAIN VERBOSE
SELECT json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, CAST("[true, false]" AS JSON)') FROM s8 WHERE id = 1;

-- select json_set (stub function, pushdown constraints, result)
--Testcase 4135:
SELECT json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, CAST("[true, false]" AS JSON)') FROM s8 WHERE id = 1;

-- select json_set (stub function, stub in constraints, explain)
--Testcase 4136:
EXPLAIN VERBOSE
SELECT json_set(c1, '$.a, c2', '$.b, c3', '$.c, NULL', '$, TRUE', '$, "[true, false]"') FROM s8 WHERE log2(id) > 1;

-- select json_set (stub function, stub in constraints, result)
--Testcase 4137:
SELECT json_set(c1, '$.a, c2', '$.b, c3', '$.c, NULL', '$, TRUE', '$, "[true, false]"') FROM s8 WHERE log2(id) > 1;

-- select json_set (stub function, stub in constraints, explain)
--Testcase 4138:
EXPLAIN VERBOSE
SELECT json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8 WHERE json_depth(json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()')) > 0;

-- select json_set (stub function, stub in constraints, result)
--Testcase 4139:
SELECT json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8 WHERE json_depth(json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()')) > 0;

-- json_set with 1 arg explain
--Testcase 4140:
EXPLAIN VERBOSE
SELECT json_set(c1, '$.a, c2') FROM s8;

-- json_set with 1 arg result
--Testcase 4141:
SELECT json_set(c1, '$.a, c2') FROM s8;

-- json_set with 2 args explain
--Testcase 4142:
EXPLAIN VERBOSE
SELECT json_set(c1, '$.a, c2', '$.b, c3') FROM s8;

-- json_set with 2 args result
--Testcase 4143:
SELECT json_set(c1, '$.a, c2', '$.b, c3') FROM s8;

-- json_set with 3 args explain
--Testcase 4144:
EXPLAIN VERBOSE
SELECT json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1') FROM s8;

-- json_set with 3 args result
--Testcase 4145:
SELECT json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1') FROM s8;

-- json_set with 4 args explain
--Testcase 4146:
EXPLAIN VERBOSE
SELECT json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"') FROM s8;

-- json_set with 4 args result
--Testcase 4147:
SELECT json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"') FROM s8;

-- json_set with 5 args explain
--Testcase 4148:
EXPLAIN VERBOSE
SELECT json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8;

-- json_set with 5 args result
--Testcase 4149:
SELECT json_set(c1, '$.a, c2', '$.b, c3', '$.c, 1', '$, "a"', '$, pi()') FROM s8;

-- select json_set as nest function with agg (pushdown, explain)
--Testcase 4150:
EXPLAIN VERBOSE
SELECT sum(id),json_set('["a", ["b", "c"], "d"]', '$, sum(id)') FROM s8;

-- select json_set as nest function with agg (pushdown, result)
--Testcase 4151:
SELECT sum(id),json_set('["a", ["b", "c"], "d"]', '$, sum(id)') FROM s8;

-- select json_set as nest function with json_build_array (pushdown, explain)
--Testcase 4152:
EXPLAIN VERBOSE
SELECT json_set(json_build_array('["a", ["b", "c"], "d"]', c1), '$, log2(id)') FROM s8;

-- select json_set as nest function with agg (pushdown, result)
--Testcase 4153:
SELECT json_set(json_build_array('["a", ["b", "c"], "d"]', c1), '$, log2(id)') FROM s8;

-- select json_set with non pushdown func and explicit constant (explain)
--Testcase 4154:
EXPLAIN VERBOSE
SELECT json_set(c1, '$.a, c2'), pi(), 4.1 FROM s8;

-- select json_set with non pushdown func and explicit constant (result)
--Testcase 4155:
SELECT json_set(c1, '$.a, c2'), pi(), 4.1 FROM s8;

-- select json_set with order by (explain)
--Testcase 4156:
EXPLAIN VERBOSE
SELECT json_length(json_set(c1, '$.a, c2')) FROM s8 ORDER BY 1;

-- select json_set with order by (result)
--Testcase 4157:
SELECT json_length(json_set(c1, '$.a, c2')) FROM s8 ORDER BY 1;

-- select json_set with group by (explain)
--Testcase 4158:
EXPLAIN VERBOSE
SELECT json_length(json_set('["a", ["b", "c"], "d"]', '$, id')) FROM s8 GROUP BY id, 1;

-- select json_set with group by (result)
--Testcase 4159:
SELECT json_length(json_set('["a", ["b", "c"], "d"]', '$, id')) FROM s8 GROUP BY id, 1;

-- select json_set with group by having (explain)
--Testcase 4160:
EXPLAIN VERBOSE
SELECT json_depth(json_set('["a", ["b", "c"], "d"]', '$, c2')) FROM s8 GROUP BY c2, 1 HAVING count(c2) > 1;

-- select json_set with group by having (result)
--Testcase 4161:
SELECT json_depth(json_set('["a", ["b", "c"], "d"]', '$, c2')) FROM s8 GROUP BY c2, 1 HAVING count(c2) > 1;

-- select json_set and as
--Testcase 4162:
SELECT json_set(c1, '$.a, c2') AS json_set1 FROM s8;

-- json_storage_free()
-- insert new value for test json_storage_free()
--Testcase 4163:
INSERT INTO s8 VALUES (6, '{"a": 10, "b": "wxyz", "c": "[true, false]"}', 1, 'Text');
-- select json_storage_free (stub function, explain)
--Testcase 4164:
EXPLAIN VERBOSE
SELECT json_storage_free(c1), json_storage_free('{"a": 10, "b": "wxyz", "c": "[true, false]"}') FROM s8 WHERE id = 6;

-- select json_storage_free (stub function, result)
--Testcase 4165:
SELECT json_storage_free(c1), json_storage_free('{"a": 10, "b": "wxyz", "c": "[true, false]"}') FROM s8 WHERE id = 6;

-- update new value for json value of table s8
--Testcase 4166:
UPDATE s8 SET c1 = json_set(c1, '$.a, 10', '$.b, "wx"') WHERE id = 6;

-- select json_storage_free (stub function, explain)
--Testcase 4167:
EXPLAIN VERBOSE
SELECT json_storage_free(c1), json_storage_free('{"a": 10, "b": "wxyz", "c": "[true, false]"}') FROM s8 WHERE id = 6;

-- select json_storage_free (stub function, result)
--Testcase 4168:
SELECT json_storage_free(c1), json_storage_free('{"a": 10, "b": "wxyz", "c": "[true, false]"}') FROM s8 WHERE id = 6;

-- revert change
--Testcase 4169:
DELETE FROM s8 WHERE id = 6;

-- json_storage_size()
-- select json_storage_size (builtin function, explain)
--Testcase 4170:
EXPLAIN VERBOSE
SELECT json_storage_size(c1), json_storage_size(json_build_array(c1, 'a', c2)), json_storage_size('{"a": 1, "b": {"c": 30}}') FROM s8;

-- select json_storage_size (builtin function, result)
--Testcase 4171:
SELECT json_storage_size(c1), json_storage_size(json_build_array(c1, 'a', c2)), json_storage_size('{"a": 1, "b": {"c": 30}}') FROM s8;

-- select json_storage_size (builtin function, not pushdown constraints, explain)
--Testcase 4172:
EXPLAIN VERBOSE
SELECT json_storage_size(c1), json_storage_size(json_build_array(c1, 'a', c2)), json_storage_size('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE to_hex(id) = '2';

-- select json_storage_size (builtin function, not pushdown constraints, result)
--Testcase 4173:
SELECT json_storage_size(c1), json_storage_size(json_build_array(c1, 'a', c2)), json_storage_size('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE to_hex(id) = '2';

-- select json_storage_size (builtin function, pushdown constraints, explain)
--Testcase 4174:
EXPLAIN VERBOSE
SELECT json_storage_size(c1), json_storage_size(json_build_array(c1, 'a', c2)), json_storage_size('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE id != 0;

-- select json_storage_size (builtin function, pushdown constraints, result)
--Testcase 4175:
SELECT json_storage_size(c1), json_storage_size(json_build_array(c1, 'a', c2)), json_storage_size('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE id != 0;

-- select json_storage_size (builtin function, json_storage_size in constraints, explain)
--Testcase 4176:
EXPLAIN VERBOSE
SELECT json_storage_size(c1), json_storage_size(json_build_array(c1, 'a', c2)), json_storage_size('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE json_storage_size(c1) != 1;

-- select json_storage_size (builtin function, json_storage_size in constraints, result)
--Testcase 4177:
SELECT json_storage_size(c1), json_storage_size(json_build_array(c1, 'a', c2)), json_storage_size('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE json_storage_size(c1) != 1;

-- select json_storage_size (builtin function, json_storage_size in constraints, explain)
--Testcase 4178:
EXPLAIN VERBOSE
SELECT json_storage_size(c1), json_storage_size(json_build_array(c1, 'a', c2)), json_storage_size('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE json_storage_size('{"a": 1, "b": {"c": 30}}') = 33;

-- select json_storage_size (builtin function, json_storage_size in constraints, result)
--Testcase 4179:
SELECT json_storage_size(c1), json_storage_size(json_build_array(c1, 'a', c2)), json_storage_size('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE json_storage_size('{"a": 1, "b": {"c": 30}}') = 33;

-- select json_storage_size as nest function with agg (pushdown, explain)
--Testcase 4180:
EXPLAIN VERBOSE
SELECT sum(id),json_storage_size('{"a": 1, "b": {"c": 30}}') FROM s8;

-- select json_storage_size as nest function with agg (pushdown, result)
--Testcase 4181:
SELECT sum(id),json_storage_size('{"a": 1, "b": {"c": 30}}') FROM s8;

-- select json_storage_size with non pushdown func and explicit constant (EXPLAIN)
--Testcase 4182:
EXPLAIN VERBOSE
SELECT json_storage_size(json_build_array(c1, 'a', c2)), pi(), 4.1 FROM s8;

-- select json_storage_size with non pushdown func and explicit constant (result)
--Testcase 4183:
SELECT json_storage_size(json_build_array(c1, 'a', c2)), pi(), 4.1 FROM s8;

-- select json_storage_size with order by (EXPLAIN)
--Testcase 4184:
EXPLAIN VERBOSE
SELECT id, json_storage_size(c1) FROM s8 ORDER BY json_storage_size(c1);

-- select json_storage_size with order by (result)
--Testcase 4185:
SELECT id, json_storage_size(c1) FROM s8 ORDER BY json_storage_size(c1);

-- select json_storage_size with order by index (result)
--Testcase 4186:
SELECT id, json_storage_size(c1) FROM s8 ORDER BY 2, 1;

-- select json_storage_size with order by index (result)
--Testcase 4187:
SELECT id, json_storage_size(c1) FROM s8 ORDER BY 1, 2;

-- select json_storage_size with group by (EXPLAIN)
--Testcase 4188:
EXPLAIN VERBOSE
SELECT count(id), json_storage_size(c1) FROM s8 group by json_storage_size(c1);

-- select json_storage_size with group by (result)
--Testcase 4189:
SELECT count(id), json_storage_size(c1) FROM s8 group by json_storage_size(c1);

-- select json_storage_size with group by index (result)
--Testcase 4190:
SELECT id, json_storage_size(c1) FROM s8 group by 2, 1;

-- select json_storage_size with group by index (result)
--Testcase 4191:
SELECT id, json_storage_size(c1) FROM s8 group by 1, 2;

-- select json_storage_size with group by having (EXPLAIN)
--Testcase 4192:
EXPLAIN VERBOSE
SELECT count(c2), json_storage_size(c1) FROM s8 group by json_storage_size(c1) HAVING count(c2) > 0;

-- select json_storage_size with group by having (result)
--Testcase 4193:
SELECT count(c2), json_storage_size(c1) FROM s8 group by json_storage_size(c1) HAVING count(c2) > 0;

-- select json_storage_size with group by index having (result)
--Testcase 4194:
SELECT c2, json_storage_size(c1) FROM s8 group by 2, 1 HAVING count(c2) > 0;

-- select json_storage_size with group by index having (result)
--Testcase 4195:
SELECT c2, json_storage_size(c1) FROM s8 group by 1, 2 HAVING count(c2) > 0;

-- select json_storage_size and as
--Testcase 4196:
SELECT json_storage_size(json_build_array(c1, 'a', c2)) as json_storage_size1 FROM s8;

-- mysql_json_table
-- select mysql_json_table (explain)
--Testcase 4197:
EXPLAIN VERBOSE
SELECT mysql_json_table(c1,'$',
       ARRAY['id VARCHAR(100) PATH "$.id"', '_type text PATH "$.type"', '_schema text PATH "$.$schema"', '_required json PATH "$.required"', '_properties json PATH "$.properties"', '_description text PATH "$.description"'],
       ARRAY['id', '_type', '_schema', '_required', '_properties', '_description'])
       FROM s9;
-- select mysql_json_table (result)
--Testcase 4198:
SELECT mysql_json_table(c1,'$',
       ARRAY['id VARCHAR(100) PATH "$.id"', '_type text PATH "$.type"', '_schema text PATH "$.$schema"', '_required json PATH "$.required"', '_properties json PATH "$.properties"', '_description text PATH "$.description"'],
       ARRAY['id', '_type', '_schema', '_required', '_properties', '_description'])
       FROM s9;

--Testcase 4199:
CREATE TABLE loc_tbl (
  id text,
  _type text,
  _schema text,
  _required json,
  _properties json,
  _description text
);
-- select mysql_json_table (result, access record)
--Testcase 4200:
SELECT * FROM (
  SELECT (mysql_json_table(c1,'$',
          ARRAY['id VARCHAR(100) PATH "$.id"', '_type text PATH "$.type"', '_schema text PATH "$.$schema"', '_required json PATH "$.required"', '_properties json PATH "$.properties"', '_description text PATH "$.description"'],
          ARRAY['id', '_type', '_schema', '_required', '_properties', '_description'])::loc_tbl).*
          FROM s9
) t;

--Testcase 4201:
DROP TABLE loc_tbl;

-- select mysql_json_table (pushed down constraints, explain)
--Testcase 4202:
EXPLAIN VERBOSE
SELECT mysql_json_table(c1,'$',
       ARRAY['id VARCHAR(100) PATH "$.id"', '_type text PATH "$.type"', '_schema text PATH "$.$schema"', '_required json PATH "$.required"', '_properties json PATH "$.properties"', '_description text PATH "$.description"'],
       ARRAY['id', '_type', '_schema', '_required', '_properties', '_description'])
       FROM s9 WHERE json_depth(c1) > 1;

-- select mysql_json_table (pushed down constraints, result)
--Testcase 4203:
SELECT mysql_json_table(c1,'$',
       ARRAY['id VARCHAR(100) PATH "$.id"', '_type text PATH "$.type"', '_schema text PATH "$.$schema"', '_required json PATH "$.required"', '_properties json PATH "$.properties"', '_description text PATH "$.description"'],
       ARRAY['id', '_type', '_schema', '_required', '_properties', '_description'])
       FROM s9 WHERE json_depth(c1) > 1;

--Testcase 4204:
CREATE TABLE loc_tbl (
  id text,
  _type text,
  _schema text,
  _required json,
  _properties json,
  _description text
);
-- select mysql_json_table (pushed down constraints, result, access record)
--Testcase 4205:
SELECT id, _type FROM (
  SELECT (mysql_json_table(c1,'$',
          ARRAY['id VARCHAR(100) PATH "$.id"', '_type text PATH "$.type"', '_schema text PATH "$.$schema"', '_required json PATH "$.required"', '_properties json PATH "$.properties"', '_description text PATH "$.description"'],
          ARRAY['id', '_type', '_schema', '_required', '_properties', '_description'])::loc_tbl).*
          FROM s9 WHERE json_depth(c1) > 1
) t;

--Testcase 4206:
DROP TABLE loc_tbl;

-- mysql_json_table with nested path (explain)
--Testcase 4207:
EXPLAIN VERBOSE
SELECT mysql_json_table(c1,'$',
       ARRAY['id VARCHAR(100) PATH "$.id"', 'NESTED PATH "$.properties.*" COLUMNS(maximum int PATH "$.maximum", minimum int PATH "$.minimum")'],
       ARRAY['id', 'maximum', 'minimum']), c1
       FROM s9;

-- mysql_json_table with nested path (value)
--Testcase 4208:
SELECT mysql_json_table(c1,'$',
       ARRAY['id VARCHAR(100) PATH "$.id"', 'NESTED PATH "$.properties.*" COLUMNS(maximum int PATH "$.maximum", minimum int PATH "$.minimum")'],
       ARRAY['id', 'maximum', 'minimum']), c1
       FROM s9;

--Testcase 4209:
CREATE TABLE loc_tbl (
  id text,
  maximum int,
  minimum int
);

-- mysql_json_table with nested path (value, access record)
--Testcase 4210:
SELECT (t1::loc_tbl).*, c1 FROM (
SELECT mysql_json_table(c1,'$',
       ARRAY['id VARCHAR(100) PATH "$.id"', 'NESTED PATH "$.properties.*" COLUMNS(maximum int PATH "$.maximum", minimum int PATH "$.minimum")'],
       ARRAY['id', 'maximum', 'minimum']) AS t1, c1
       FROM s9
) t;
--Testcase 4211:
DROP TABLE loc_tbl;

-- select mysql_json_table constant argument (explain)
--Testcase 4212:
EXPLAIN VERBOSE
SELECT id, mysql_json_table('[{"x":2,"y":"8"},{"x":"3","y":"7"},{"x":"4","y":6}]','$[*]',
       ARRAY['xval VARCHAR(100) PATH "$.x"', ' yval VARCHAR(100) PATH "$.y"'],
       ARRAY['xval', 'yval'])
       FROM s9 WHERE id = 0;

-- select mysql_json_table constant argument (result)
--Testcase 4213:
SELECT id, mysql_json_table('[{"x":2,"y":"8"},{"x":"3","y":"7"},{"x":"4","y":6}]','$[*]',
       ARRAY['xval VARCHAR(100) PATH "$.x"', ' yval VARCHAR(100) PATH "$.y"'],
       ARRAY['xval', 'yval'])
       FROM s9 WHERE id = 0;

--Testcase 4214:
CREATE TABLE loc_tbl (
  xval int,
  yval int
);
-- select mysql_json_table constant argument (result)
--Testcase 4215:
SELECT (t1::loc_tbl).*, id FROM (
SELECT id, mysql_json_table('[{"x":2,"y":"8"},{"x":"3","y":"7"},{"x":"4","y":6}]','$[*]',
       ARRAY['xval VARCHAR(100) PATH "$.x"', ' yval VARCHAR(100) PATH "$.y"'],
       ARRAY['xval', 'yval']) AS t1, c1
       FROM s9 WHERE id = 0
) t;

--Testcase 4216:
DROP TABLE loc_tbl;

-- JSON_TYPE()
-- select json_type (builtin function, explain)
--Testcase 4217:
EXPLAIN VERBOSE
SELECT json_type(c1), json_type(json_build_array(c1, '1')), json_type(json_build_object('a', '1', 'b', c2)),json_type('{"a":1,"b":10,"d":10}'),json_type('[1,3,5,7]') FROM s8;

-- select json_type (builtin function, result)
--Testcase 4218:
SELECT json_type(c1), json_type(json_build_array(c1, '1')), json_type(json_build_object('a', '1', 'b', c2)),json_type('{"a":1,"b":10,"d":10}'),json_type('[1,3,5,7]') FROM s8;

-- select json_type (builtin function, not pushdown constraints, explain)
--Testcase 4219:
EXPLAIN VERBOSE
SELECT json_type(c1), json_type(json_build_array(c1, '1')), json_type(json_build_object('a', '1', 'b', c2)),json_type('{"a":1,"b":10,"d":10}'),json_type('[1,3,5,7]') FROM s8 WHERE to_hex(id) = '2';

-- select json_type (builtin function, not pushdown constraints, result)
--Testcase 4220:
SELECT json_type(c1), json_type(json_build_array(c1, '1')), json_type(json_build_object('a', '1', 'b', c2)),json_type('{"a":1,"b":10,"d":10}'),json_type('[1,3,5,7]') FROM s8 WHERE to_hex(id) = '2';

-- select json_type (builtin function, pushdown constraints, explain)
--Testcase 4221:
EXPLAIN VERBOSE
SELECT json_type(c1), json_type(json_build_array(c1, '1')), json_type(json_build_object('a', '1', 'b', c2)),json_type('{"a":1,"b":10,"d":10}'),json_type('[1,3,5,7]') FROM s8 WHERE id != 0;

-- select json_type (builtin function, pushdown constraints, result)
--Testcase 4222:
SELECT json_type(c1), json_type(json_build_array(c1, '1')), json_type(json_build_object('a', '1', 'b', c2)),json_type('{"a":1,"b":10,"d":10}'),json_type('[1,3,5,7]') FROM s8 WHERE id != 0;

-- select json_type (builtin function, json_type in constraints, explain)
--Testcase 4223:
EXPLAIN VERBOSE
SELECT json_type(c1), json_type(json_build_array(c1, '1')), json_type(json_build_object('a', '1', 'b', c2)),json_type('{"a":1,"b":10,"d":10}'),json_type('[1,3,5,7]') FROM s8 WHERE json_type(c1) NOT LIKE '$';

-- select json_type (builtin function, json_type in constraints, result)
--Testcase 4224:
SELECT json_type(c1), json_type(json_build_array(c1, '1')), json_type(json_build_object('a', '1', 'b', c2)),json_type('{"a":1,"b":10,"d":10}'),json_type('[1,3,5,7]') FROM s8 WHERE json_type(c1) NOT LIKE '$';

-- select json_type (builtin function, json_type in constraints, explain)
--Testcase 4225:
EXPLAIN VERBOSE
SELECT json_type(c1), json_type(json_build_array(c1, '1')), json_type(json_build_object('a', '1', 'b', c2)),json_type('{"a":1,"b":10,"d":10}'),json_type('[1,3,5,7]') FROM s8 where json_type('[1,3,5,7]') LIKE 'ARRAY';

-- select json_type (builtin function, json_type in constraints, result)
--Testcase 4226:
SELECT json_type(c1), json_type(json_build_array(c1, '1')), json_type(json_build_object('a', '1', 'b', c2)),json_type('{"a":1,"b":10,"d":10}'),json_type('[1,3,5,7]') FROM s8 where json_type('[1,3,5,7]') LIKE 'ARRAY';

-- select json_type as nest function with agg (pushdown, explain)
--Testcase 4227:
EXPLAIN VERBOSE
SELECT sum(id),json_type(json_build_object('a', '1', 'b',sum(id))) FROM s8;

-- select json_type as nest function with agg (pushdown, result)
--Testcase 4228:
SELECT sum(id),json_type(json_build_object('a', '1', 'b',sum(id))) FROM s8;

-- select json_type with non pushdown func and explicit constant (EXPLAIN)
--Testcase 4229:
EXPLAIN VERBOSE
SELECT json_type(json_build_object('a', '1', 'b', c2)), pi(), 4.1 FROM s8;

-- select json_type with non pushdown func and explicit constant (result)
--Testcase 4230:
SELECT json_type(json_build_object('a', '1', 'b', c2)), pi(), 4.1 FROM s8;


-- select json_type with order by index (result)
--Testcase 4231:
SELECT id, json_type(c1) FROM s8 ORDER BY 2, 1;

-- select json_type with order by index (result)
--Testcase 4232:
SELECT id, json_type(c1) FROM s8 ORDER BY 1, 2;

-- select json_type with group by (EXPLAIN)
--Testcase 4233:
EXPLAIN VERBOSE
SELECT count(id), json_type(c1) FROM s8 group by json_type(c1);

-- select json_type with group by (result)
--Testcase 4234:
SELECT count(id), json_type(c1) FROM s8 group by json_type(c1);

-- select json_type with group by index (result)
--Testcase 4235:
SELECT id, json_type(c1) FROM s8 group by 2, 1;

-- select json_type with group by index (result)
--Testcase 4236:
SELECT id, json_type(c1) FROM s8 group by 1, 2;

-- select json_type with group by having (EXPLAIN)
--Testcase 4237:
EXPLAIN VERBOSE
SELECT count(c2), json_type(c1) FROM s8 group by json_type(c1) HAVING count(c2) > 0;

-- select json_type with group by having (result)
--Testcase 4238:
SELECT count(c2), json_type(c1) FROM s8 group by json_type(c1) HAVING count(c2) > 0;

-- select json_type with group by index having (result)
--Testcase 4239:
SELECT c2, json_type(c1) FROM s8 group by 2, 1 HAVING count(c2) > 0;

-- select json_type with group by index having (result)
--Testcase 4240:
SELECT c2, json_type(c1) FROM s8 group by 1, 2 HAVING count(c2) > 0;

-- select json_type and as
--Testcase 4241:
SELECT json_type(json_build_object('a', '1', 'b', c2)) as json_type1 FROM s8;

-- select json_unquote (builtin function, explain)
--Testcase 4242:
EXPLAIN VERBOSE
SELECT json_unquote(c3), json_unquote('null'), json_unquote('"null"'), json_unquote('[1, 2, 3]') FROM s8;

-- select json_unquote (builtin function, result)
--Testcase 4243:
SELECT json_unquote(c3), json_unquote('null'), json_unquote('"null"'), json_unquote('[1, 2, 3]') FROM s8;

-- select json_unquote (builtin function, not pushdown constraints, explain)
--Testcase 4244:
EXPLAIN VERBOSE
SELECT json_unquote(c3), json_unquote('null'), json_unquote('"null"'), json_unquote('[1, 2, 3]') FROM s8 WHERE to_hex(id) = '2';

-- select json_unquote (builtin function, not pushdown constraints, result)
--Testcase 4245:
SELECT json_unquote(c3), json_unquote('null'), json_unquote('"null"'), json_unquote('[1, 2, 3]') FROM s8 WHERE to_hex(id) = '2';

-- select json_unquote (builtin function, pushdown constraints, explain)
--Testcase 4246:
EXPLAIN VERBOSE
SELECT json_unquote(c3), json_unquote('null'), json_unquote('"null"'), json_unquote('[1, 2, 3]') FROM s8 WHERE id != 0;

-- select json_unquote (builtin function, pushdown constraints, result)
--Testcase 4247:
SELECT json_unquote(c3), json_unquote('null'), json_unquote('"null"'), json_unquote('[1, 2, 3]') FROM s8 WHERE id != 0;

-- select json_unquote (builtin function, json_unquote in constraints, explain)
--Testcase 4248:
EXPLAIN VERBOSE
SELECT json_unquote(c3), json_unquote('null'), json_unquote('"null"'), json_unquote('[1, 2, 3]') FROM s8 WHERE json_unquote(c3) NOT LIKE 'text';

-- select json_unquote (builtin function, json_unquote in constraints, result)
--Testcase 4249:
SELECT json_unquote(c3), json_unquote('null'), json_unquote('"null"'), json_unquote('[1, 2, 3]') FROM s8 WHERE json_unquote(c3) NOT LIKE 'text';

-- select json_unquote (builtin function, json_unquote in constraints, explain)
--Testcase 4250:
EXPLAIN VERBOSE
SELECT json_unquote(c3), json_unquote('null'), json_unquote('"null"'), json_unquote('[1, 2, 3]') FROM s8 WHERE json_unquote('[1, 2, 3]') LIKE '[1, 2, 3]';

-- select json_unquote (builtin function, json_unquote in constraints, result)
--Testcase 4251:
SELECT json_unquote(c3), json_unquote('null'), json_unquote('"null"'), json_unquote('[1, 2, 3]') FROM s8 WHERE json_unquote('[1, 2, 3]') LIKE '[1, 2, 3]';

-- select json_unquote as nest function with agg (pushdown, explain)
--Testcase 4252:
EXPLAIN VERBOSE
SELECT sum(id), json_unquote('[1, 2, 3]') FROM s8;

-- select json_unquote as nest function with agg (pushdown, result)
--Testcase 4253:
SELECT sum(id), json_unquote('[1, 2, 3]') FROM s8;

-- select json_unquote with non pushdown func and explicit constant (EXPLAIN)
--Testcase 4254:
EXPLAIN VERBOSE
SELECT json_unquote('null'), pi(), 4.1 FROM s8;

-- select json_unquote with non pushdown func and explicit constant (result)
--Testcase 4255:
SELECT json_unquote('null'), pi(), 4.1 FROM s8;

-- select json_unquote with order by (EXPLAIN)
--Testcase 4256:
EXPLAIN VERBOSE
SELECT id,  json_unquote(c3) FROM s8 ORDER BY json_unquote(c3);

-- select json_unquote with order by (result)
--Testcase 4257:
SELECT id,  json_unquote(c3) FROM s8 ORDER BY json_unquote(c3);

-- select json_unquote with order by index (result)
--Testcase 4258:
SELECT id,  json_unquote(c3) FROM s8 ORDER BY 2, 1;

-- select json_unquote with order by index (result)
--Testcase 4259:
SELECT id,  json_unquote(c3) FROM s8 ORDER BY 1, 2;

-- select json_unquote with group by (EXPLAIN)
--Testcase 4260:
EXPLAIN VERBOSE
SELECT count(id), json_unquote(c3) FROM s8 group by json_unquote(c3);

-- select json_unquote with group by (result)
--Testcase 4261:
SELECT count(id), json_unquote(c3) FROM s8 group by json_unquote(c3);

-- select json_unquote with group by index (result)
--Testcase 4262:
SELECT id,  json_unquote(c3) FROM s8 group by 2, 1;

-- select json_unquote with group by index (result)
--Testcase 4263:
SELECT id,  json_unquote(c3) FROM s8 group by 1, 2;

-- select json_unquote with group by having (EXPLAIN)
--Testcase 4264:
EXPLAIN VERBOSE
SELECT count(c2), json_unquote(c3) FROM s8 group by json_unquote(c3) HAVING count(c2) > 0;

-- select json_unquote with group by having (result)
--Testcase 4265:
SELECT count(c2), json_unquote(c3) FROM s8 group by json_unquote(c3) HAVING count(c2) > 0;

-- select json_unquote with group by index having (result)
--Testcase 4266:
SELECT c2,  json_unquote(c3) FROM s8 group by 2, 1 HAVING count(c2) > 0;

-- select json_unquote with group by index having (result)
--Testcase 4267:
SELECT c2,  json_unquote(c3) FROM s8 group by 1, 2 HAVING count(c2) > 0;

-- select json_unquote and as
--Testcase 4268:
SELECT json_unquote('null') as json_unquote1 FROM s8;

-- select json_valid (builtin function, explain)
--Testcase 4269:
EXPLAIN VERBOSE
SELECT json_valid(c1), json_valid(json_build_array(c1, 'a', c2)), json_valid('{"a": 1, "b": {"c": 30}}') FROM s8;

-- select json_valid (builtin function, result)
--Testcase 4270:
SELECT json_valid(c1), json_valid(json_build_array(c1, 'a', c2)), json_valid('{"a": 1, "b": {"c": 30}}') FROM s8;

-- select json_valid (builtin function, not pushdown constraints, explain)
--Testcase 4271:
EXPLAIN VERBOSE
SELECT json_valid(c1), json_valid(json_build_array(c1, 'a', c2)), json_valid('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE to_hex(id) = '2';

-- select json_valid (builtin function, not pushdown constraints, result)
--Testcase 4272:
SELECT json_valid(c1), json_valid(json_build_array(c1, 'a', c2)), json_valid('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE to_hex(id) = '2';

-- select json_valid (builtin function, pushdown constraints, explain)
--Testcase 4273:
EXPLAIN VERBOSE
SELECT json_valid(c1), json_valid(json_build_array(c1, 'a', c2)), json_valid('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE id != 0;

-- select json_valid (builtin function, pushdown constraints, result)
--Testcase 4274:
SELECT json_valid(c1), json_valid(json_build_array(c1, 'a', c2)), json_valid('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE id != 0;

-- select json_valid (builtin function, json_valid in constraints, explain)
--Testcase 4275:
EXPLAIN VERBOSE
SELECT json_valid(c1), json_valid(json_build_array(c1, 'a', c2)), json_valid('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE json_valid(c1) != 0;

-- select json_valid (builtin function, json_valid in constraints, result)
--Testcase 4276:
SELECT json_valid(c1), json_valid(json_build_array(c1, 'a', c2)), json_valid('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE json_valid(c1) != 0;

-- select json_valid (builtin function, json_valid in constraints, explain)
--Testcase 4277:
EXPLAIN VERBOSE
SELECT json_valid(c1), json_valid(json_build_array(c1, 'a', c2)), json_valid('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE json_valid('{"a": 1, "b": {"c": 30}}') = 1;

-- select json_valid (builtin function, json_valid in constraints, result)
--Testcase 4278:
SELECT json_valid(c1), json_valid(json_build_array(c1, 'a', c2)), json_valid('{"a": 1, "b": {"c": 30}}') FROM s8 WHERE json_valid('{"a": 1, "b": {"c": 30}}') = 1;

-- select json_valid as nest function with agg (pushdown, explain)
--Testcase 4279:
EXPLAIN VERBOSE
SELECT sum(id),json_valid('{"a": 1, "b": {"c": 30}}') FROM s8;

-- select json_valid as nest function with agg (pushdown, result)
--Testcase 4280:
SELECT sum(id),json_valid('{"a": 1, "b": {"c": 30}}') FROM s8;

-- select json_valid with non pushdown func and explicit constant (EXPLAIN)
--Testcase 4281:
EXPLAIN VERBOSE
SELECT json_valid(json_build_array(c1, 'a', c2)), pi(), 4.1 FROM s8;

-- select json_valid with non pushdown func and explicit constant (result)
--Testcase 4282:
SELECT json_valid(json_build_array(c1, 'a', c2)), pi(), 4.1 FROM s8;

-- select json_valid with order by index (result)
--Testcase 4283:
SELECT id, json_valid(c1) FROM s8 ORDER BY 2, 1;

-- select json_valid with order by index (result)
--Testcase 4284:
SELECT id, json_valid(c1) FROM s8 ORDER BY 1, 2;

-- select json_valid with group by (EXPLAIN)
--Testcase 4285:
EXPLAIN VERBOSE
SELECT count(id), json_valid(c1) FROM s8 group by json_valid(c1);

-- select json_valid with group by (result)
--Testcase 4286:
SELECT count(id), json_valid(c1) FROM s8 group by json_valid(c1);

-- select json_valid with group by index (result)
--Testcase 4287:
SELECT id, json_valid(c1) FROM s8 group by 2, 1;

-- select json_valid with group by index (result)
--Testcase 4288:
SELECT id, json_valid(c1) FROM s8 group by 1, 2;

-- select json_valid with group by having (EXPLAIN)
--Testcase 4289:
EXPLAIN VERBOSE
SELECT count(c2), json_valid(c1) FROM s8 group by json_valid(c1) HAVING count(c2) > 0;

-- select json_valid with group by having (result)
--Testcase 4290:
SELECT count(c2), json_valid(c1) FROM s8 group by json_valid(c1) HAVING count(c2) > 0;

-- select json_valid with group by index having (result)
--Testcase 4291:
SELECT c2, json_valid(c1) FROM s8 group by 2, 1 HAVING count(c2) > 0;

-- select json_valid with group by index having (result)
--Testcase 4292:
SELECT c2, json_valid(c1) FROM s8 group by 1, 2 HAVING count(c2) > 0;

-- select json_valid and as
--Testcase 4293:
SELECT json_valid(json_build_array(c1, 'a', c2)) as json_valid1 FROM s8;

-- select json_value (stub function, explain)
--Testcase 4294:
EXPLAIN VERBOSE
SELECT json_value(c1, '$.a'), json_value(c1, '$[1]'), json_value('{"item": "shoes", "price": "49.95"}', '$.price', 'returning decimal(10, 1)')::numeric FROM s8;

-- select json_value (stub function, result)
--Testcase 4295:
SELECT json_value(c1, '$.a'), json_value(c1, '$[1]'), json_value('{"item": "shoes", "price": "49.95"}', '$.price', 'returning decimal(10, 1)')::numeric FROM s8;

-- select json_value (stub function, not pushdown constraints, explain)
--Testcase 4296:
EXPLAIN VERBOSE
SELECT json_value(c1, '$.a'), json_value(c1, '$[1]'), json_value('{"item": "shoes", "price": "49.95"}', '$.price', 'returning decimal(10, 1)')::numeric FROM s8 WHERE to_hex(id) = '2';

-- select json_value (stub function, not pushdown constraints, result)
--Testcase 4297:
SELECT json_value(c1, '$.a'), json_value(c1, '$[1]'), json_value('{"item": "shoes", "price": "49.95"}', '$.price', 'returning decimal(10, 1)')::numeric FROM s8 WHERE to_hex(id) = '2';

-- select json_value (stub function, pushdown constraints, explain)
--Testcase 4298:
EXPLAIN VERBOSE
SELECT json_value(c1, '$.a'), json_value(c1, '$[1]'), json_value('{"item": "shoes", "price": "49.95"}', '$.price', 'returning decimal(10, 1)')::numeric FROM s8 WHERE id != 0;

-- select json_value (stub function, pushdown constraints, result)
--Testcase 4299:
SELECT json_value(c1, '$.a'), json_value(c1, '$[1]'), json_value('{"item": "shoes", "price": "49.95"}', '$.price', 'returning decimal(10, 1)')::numeric FROM s8 WHERE id != 0;

-- select json_value (stub function, json_value in constraints, explain)
--Testcase 4300:
EXPLAIN VERBOSE
SELECT json_value(c1, '$.a'), json_value(c1, '$[1]'), json_value('{"item": "shoes", "price": "49.95"}', '$.price', 'returning decimal(10, 1)')::numeric FROM s8 WHERE json_value(c1, '$.a', 'default 0 on empty')::int > 1;

-- select json_value (stub function, json_value in constraints, result)
--Testcase 4301:
SELECT json_value(c1, '$.a'), json_value(c1, '$[1]'), json_value('{"item": "shoes", "price": "49.95"}', '$.price', 'returning decimal(10, 1)')::numeric FROM s8 WHERE json_value(c1, '$.a', 'default 0 on empty')::int > 1;

-- select json_value (stub function, json_value in constraints, explain)
--Testcase 4302:
EXPLAIN VERBOSE
SELECT json_value(c1, '$.a'), json_value(c1, '$[1]'), json_value('{"item": "shoes", "price": "49.95"}', '$.price', 'returning decimal(10, 1)')::numeric FROM s8 WHERE json_value('{"item": "shoes", "price": "49.95"}', '$.price', 'returning decimal(10, 2)')::decimal = 49.95;

-- select json_value (stub function, json_value in constraints, result)
--Testcase 4303:
SELECT json_value(c1, '$.a'), json_value(c1, '$[1]'), json_value('{"item": "shoes", "price": "49.95"}', '$.price', 'returning decimal(10, 1)')::numeric FROM s8 WHERE json_value('{"item": "shoes", "price": "49.95"}', '$.price', 'returning decimal(10, 2)')::decimal = 49.95;

-- select json_value (stub function, abnormal cast, explain)
--Testcase 4304:
EXPLAIN VERBOSE
SELECT json_value(c1, '$.a')::date FROM s8;

-- select json_value (stub function, abnormal cast, result)
--Testcase 4305:
SELECT json_value(c1, '$.a')::date FROM s8; -- should fail

-- select json_value (stub function, abnormal cast, explain)
--Testcase 4306:
EXPLAIN VERBOSE
SELECT json_value(c1, '$.a', 'returning date')::date FROM s8;

-- select json_value (stub function, abnormal cast, result)
--Testcase 4307:
SELECT json_value(c1, '$.a', 'returning date')::date FROM s8; --empty result

-- select json_value (stub function, abnormal cast, explain)
--Testcase 4308:
EXPLAIN VERBOSE
SELECT json_value(c1, '$.a', 'returning date', 'error on error')::date FROM s8;

-- select json_value (stub function, abnormal cast, result)
--Testcase 4309:
SELECT json_value(c1, '$.a', 'returning date', 'error on error')::date FROM s8; -- should fail

-- select json_value with normal cast
--Testcase 4310:
SELECT json_value('{"a": "2000-01-01"}', '$.a')::timestamp, json_value('{"a": "2000-01-01"}', '$.a')::date , json_value('{"a": 1234}', '$.a')::bigint, json_value('{"a": "b"}', '$.a')::text FROM s8;

-- select json_value with normal cast
--Testcase 4311:
SELECT json_value('{"a": "2000-01-01"}', '$.a')::timestamptz, json_value('{"a": "12:10:20.123456"}', '$.a')::time , json_value('{"a": "12:10:20.123456"}', '$.a')::timetz FROM s8;

-- select json_value with type modifier (explain)
--Testcase 4312:
EXPLAIN VERBOSE
SELECT json_value('{"a": "2000-01-01 12:02:01.123456"}', '$.a')::timestamp(3), json_value('{"a": "2000-01-01 12:02:01.123456"}', '$.a')::timestamptz(3), json_value('{"a": "12:10:20.123456"}', '$.a')::time(3), json_value('{"a": "12:10:20.123456"}', '$.a')::timetz(3) FROM s8;

-- select json_value with type modifier (result)
--Testcase 4313:
SELECT json_value('{"a": "2000-01-01 12:02:01.123456"}', '$.a')::timestamp(3), json_value('{"a": "2000-01-01 12:02:01.123456"}', '$.a')::timestamptz(3), json_value('{"a": "12:10:20.123456"}', '$.a')::time(3), json_value('{"a": "12:10:20.123456"}', '$.a')::timetz(3) FROM s8;

-- select json_value with type modifier (explain)
--Testcase 4314:
EXPLAIN VERBOSE
SELECT json_value('{"a": 100}', '$.a')::numeric(10, 2), json_value('{"a": 100}', '$.a')::decimal(10, 2), json_unquote(json_value('{"a": "1.123456"}', '$.a'))::numeric(10, 3) FROM s8;

-- select json_value with type modifier (result)
--Testcase 4315:
SELECT json_value('{"a": 100}', '$.a')::numeric(10, 2), json_value('{"a": 100}', '$.a')::decimal(10, 2), json_unquote(json_value('{"a": "1.123456"}', '$.a'))::numeric(10, 3) FROM s8;

-- select json_value as nest function with agg (pushdown, explain)
--Testcase 4316:
EXPLAIN VERBOSE
SELECT sum(id), json_value(json_build_object('item', 'shoe', 'price', sum(id)), '$.price')::int FROM s8;

-- select json_value as nest function with agg (pushdown, result)
--Testcase 4317:
SELECT sum(id), json_value(json_build_object('item', 'shoe', 'price', sum(id)), '$.price')::int FROM s8;

-- select json_value with non pushdown func and explicit constant (EXPLAIN)
--Testcase 4318:
EXPLAIN VERBOSE
SELECT json_value(c1, '$[1]'), pi(), 4.1 FROM s8;

-- select json_value with non pushdown func and explicit constant (result)
--Testcase 4319:
SELECT json_value(c1, '$[1]'), pi(), 4.1 FROM s8;


-- select json_value with order by index (result)
--Testcase 4320:
SELECT id, json_value(c1, '$.a') FROM s8 ORDER BY 2, 1;

-- select json_value with order by index (result)
--Testcase 4321:
SELECT id, json_value(c1, '$.a') FROM s8 ORDER BY 1, 2;

-- select json_value with group by (EXPLAIN)
--Testcase 4322:
EXPLAIN VERBOSE
SELECT count(id), json_value(c1, '$.a') FROM s8 group by json_value(c1, '$.a');

-- select json_value with group by (result)
--Testcase 4323:
SELECT count(id), json_value(c1, '$.a') FROM s8 group by json_value(c1, '$.a');

-- select json_value with group by index (result)
--Testcase 4324:
SELECT id, json_value(c1, '$.a') FROM s8 group by 2, 1;

-- select json_value with group by index (result)
--Testcase 4325:
SELECT id, json_value(c1, '$.a') FROM s8 group by 1, 2;

-- select json_value with group by having (EXPLAIN)
--Testcase 4326:
EXPLAIN VERBOSE
SELECT count(c2), json_value(c1, '$.a') FROM s8 group by json_value(c1, '$.a') HAVING count(c2) > 0;

-- select json_value with group by having (result)
--Testcase 4327:
SELECT count(c2), json_value(c1, '$.a') FROM s8 group by json_value(c1, '$.a') HAVING count(c2) > 0;

-- select json_value with group by index having (result)
--Testcase 4328:
SELECT c2, json_value(c1, '$.a') FROM s8 group by 2, 1 HAVING count(c2) > 0;

-- select json_value with group by index having (result)
--Testcase 4329:
SELECT c2, json_value(c1, '$.a') FROM s8 group by 1, 2 HAVING count(c2) > 0;

-- select json_value and as
--Testcase 4330:
SELECT json_value(c1, '$[1]') as json_value1 FROM s8;

-- select member_of (builtin function, explain)
--Testcase 4331:
EXPLAIN VERBOSE
SELECT member_of(5, c1), member_of('ab'::text, c1), member_of('[3,4]'::json, c1), member_of(json_build_object('item', 'shoes'), '{"item": "shoes", "price": "49.95"}') FROM s8;

-- select member_of (builtin function, result)
--Testcase 4332:
SELECT member_of(5, c1), member_of('ab'::text, c1), member_of('[3,4]'::json, c1), member_of(json_build_object('item', 'shoes'), '{"item": "shoes", "price": "49.95"}') FROM s8;

-- select member_of (builtin function, not pushdown constraints, explain)
--Testcase 4333:
EXPLAIN VERBOSE
SELECT member_of(5, c1), member_of('ab'::text, c1), member_of('[3,4]'::json, c1), member_of(json_build_object('item', 'shoes'), '{"item": "shoes", "price": "49.95"}') FROM s8 WHERE to_hex(id) = '2';

-- select member_of (builtin function, not pushdown constraints, result)
--Testcase 4334:
SELECT member_of(5, c1), member_of('ab'::text, c1), member_of('[3,4]'::json, c1), member_of(json_build_object('item', 'shoes'), '{"item": "shoes", "price": "49.95"}') FROM s8 WHERE to_hex(id) = '2';

-- select member_of (builtin function, pushdown constraints, explain)
--Testcase 4335:
EXPLAIN VERBOSE
SELECT member_of(5, c1), member_of('ab'::text, c1), member_of('[3,4]'::json, c1), member_of(json_build_object('item', 'shoes'), '{"item": "shoes", "price": "49.95"}') FROM s8 WHERE id != 0;

-- select member_of (builtin function, pushdown constraints, result)
--Testcase 4336:
SELECT member_of(5, c1), member_of('ab'::text, c1), member_of('[3,4]'::json, c1), member_of(json_build_object('item', 'shoes'), '{"item": "shoes", "price": "49.95"}') FROM s8 WHERE id != 0;

-- select member_of (builtin function, member_of in constraints, explain)
--Testcase 4337:
EXPLAIN VERBOSE
SELECT member_of(5, c1), member_of('ab'::text, c1), member_of('[3,4]'::json, c1), member_of(json_build_object('item', 'shoes'), '{"item": "shoes", "price": "49.95"}') FROM s8 WHERE member_of(5, c1) != 0;

-- select member_of (builtin function, member_of in constraints, result)
--Testcase 4338:
SELECT member_of(5, c1), member_of('ab'::text, c1), member_of('[3,4]'::json, c1), member_of(json_build_object('item', 'shoes'), '{"item": "shoes", "price": "49.95"}') FROM s8 WHERE member_of(5, c1) != 0;

-- select member_of (builtin function, member_of in constraints, explain)
--Testcase 4339:
EXPLAIN VERBOSE
SELECT member_of(5, c1), member_of('ab'::text, c1), member_of('[3,4]'::json, c1), member_of(json_build_object('item', 'shoes'), '{"item": "shoes", "price": "49.95"}') FROM s8 WHERE member_of(json_build_object('item', 'shoes', 'price', '49.95'), '{"item": "shoes", "price": "49.95"}') = 1;

-- select member_of (builtin function, member_of in constraints, result)
--Testcase 4340:
SELECT member_of(5, c1), member_of('ab'::text, c1), member_of('[3,4]'::json, c1), member_of(json_build_object('item', 'shoes'), '{"item": "shoes", "price": "49.95"}') FROM s8 WHERE member_of(json_build_object('item', 'shoes', 'price', '49.95'), '{"item": "shoes", "price": "49.95"}') = 1;

-- select member_of as nest function with agg (pushdown, explain)
--Testcase 4341:
EXPLAIN VERBOSE
SELECT sum(id), member_of(json_build_object('item', 'shoes'), '{"item": "shoes", "price": "49.95"}') FROM s8;

-- select member_of as nest function with agg (pushdown, result)
--Testcase 4342:
SELECT sum(id), member_of(json_build_object('item', 'shoes'), '{"item": "shoes", "price": "49.95"}') FROM s8;

-- select member_of with non pushdown func and explicit constant (EXPLAIN)
--Testcase 4343:
EXPLAIN VERBOSE
SELECT member_of('ab'::text, c1), member_of('[3,4]'::json, c1), pi(), 4.1 FROM s8;

-- select member_of with non pushdown func and explicit constant (result)
--Testcase 4344:
SELECT member_of('ab'::text, c1), member_of('[3,4]'::json, c1), pi(), 4.1 FROM s8;

-- select member_of with order by index (result)
--Testcase 4345:
SELECT id, member_of(5, c1) FROM s8 ORDER BY 2, 1;

-- select member_of with order by index (result)
--Testcase 4346:
SELECT id, member_of(5, c1) FROM s8 ORDER BY 1, 2;

-- select member_of with group by (EXPLAIN)
--Testcase 4347:
EXPLAIN VERBOSE
SELECT count(id), member_of(5, c1) FROM s8 group by member_of(5, c1);

-- select member_of with group by (result)
--Testcase 4348:
SELECT count(id), member_of(5, c1) FROM s8 group by member_of(5, c1);

-- select member_of with group by index (result)
--Testcase 4349:
SELECT id, member_of(5, c1) FROM s8 group by 2, 1;

-- select member_of with group by index (result)
--Testcase 4350:
SELECT id, member_of(5, c1) FROM s8 group by 1, 2;

-- select member_of with group by having (EXPLAIN)
--Testcase 4351:
EXPLAIN VERBOSE
SELECT count(c2), member_of(5, c1) FROM s8 group by member_of(5, c1) HAVING count(c2) > 0;

-- select member_of with group by having (result)
--Testcase 4352:
SELECT count(c2), member_of(5, c1) FROM s8 group by member_of(5, c1) HAVING count(c2) > 0;

-- select member_of with group by index having (result)
--Testcase 4353:
SELECT c2, member_of(5, c1) FROM s8 group by 2, 1 HAVING count(c2) > 0;

-- select member_of with group by index having (result)
--Testcase 4354:
SELECT c2, member_of(5, c1) FROM s8 group by 1, 2 HAVING count(c2) > 0;

-- select member_of and as
--Testcase 4355:
SELECT member_of('ab'::text, c1), member_of('[3,4]'::json, c1) as member_of1 FROM s8;

--Testcase 4356:
DROP FOREIGN TABLE s8;
--Testcase 4357:
DROP FOREIGN TABLE s9;
--Testcase 4358:
DROP USER MAPPING FOR CURRENT_USER SERVER server1;
--Testcase 4359:
DROP SERVER server1;
--Testcase 4360:
DROP EXTENSION mysql_fdw;
