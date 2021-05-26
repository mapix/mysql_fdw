SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS `FLOAT4_TBL`;
DROP TABLE IF EXISTS `FLOAT4_TMP`;
DROP TABLE IF EXISTS `FLOAT8_TBL`;
DROP TABLE IF EXISTS `FLOAT8_TMP`;
DROP TABLE IF EXISTS `INT2_TBL`;
DROP TABLE IF EXISTS `INT4_TBL`;
DROP TABLE IF EXISTS `INT4_TMP`;
DROP TABLE IF EXISTS `INT8_TBL`;
DROP TABLE IF EXISTS `INT8_TMP`;
DROP TABLE IF EXISTS `J1_TBL`;
DROP TABLE IF EXISTS `J2_TBL`;
DROP TABLE IF EXISTS `TEXT_TBL`;
DROP TABLE IF EXISTS `VARCHAR_TBL`;
DROP TABLE IF EXISTS `a1`;
DROP TABLE IF EXISTS `a2`;
DROP TABLE IF EXISTS `a3`;
DROP TABLE IF EXISTS `a4`;
DROP TABLE IF EXISTS `agg_data_20k`;
DROP TABLE IF EXISTS `agg_data_2k`;
DROP TABLE IF EXISTS `agg_group_1`;
DROP TABLE IF EXISTS `agg_group_2`;
DROP TABLE IF EXISTS `agg_group_3`;
DROP TABLE IF EXISTS `agg_group_4`;
DROP TABLE IF EXISTS `agg_hash_1`;
DROP TABLE IF EXISTS `agg_hash_2`;
DROP TABLE IF EXISTS `agg_hash_3`;
DROP TABLE IF EXISTS `agg_hash_4`;
DROP TABLE IF EXISTS `agg_t1`;
DROP TABLE IF EXISTS `agg_t10`;
DROP TABLE IF EXISTS `agg_t11`;
DROP TABLE IF EXISTS `agg_t12`;
DROP TABLE IF EXISTS `agg_t13`;
DROP TABLE IF EXISTS `agg_t14`;
DROP TABLE IF EXISTS `agg_t15`;
DROP TABLE IF EXISTS `agg_t16`;
DROP TABLE IF EXISTS `agg_t17`;
DROP TABLE IF EXISTS `agg_t18`;
DROP TABLE IF EXISTS `agg_t19`;
DROP TABLE IF EXISTS `agg_t2`;
DROP TABLE IF EXISTS `agg_t20`;
DROP TABLE IF EXISTS `agg_t21`;
DROP TABLE IF EXISTS `agg_t3`;
DROP TABLE IF EXISTS `agg_t4`;
DROP TABLE IF EXISTS `agg_t5`;
DROP TABLE IF EXISTS `agg_t6`;
DROP TABLE IF EXISTS `agg_t7`;
DROP TABLE IF EXISTS `agg_t8`;
DROP TABLE IF EXISTS `agg_t9`;
DROP TABLE IF EXISTS `aggtest`;
DROP TABLE IF EXISTS `b1`;
DROP TABLE IF EXISTS `b2`;
DROP TABLE IF EXISTS `b3`;
DROP TABLE IF EXISTS `b4`;
DROP TABLE IF EXISTS `bitwise_test`;
DROP TABLE IF EXISTS `bool_test`;
DROP TABLE IF EXISTS `bool_test_tmp`;
DROP TABLE IF EXISTS `bytea_test_table`;
DROP TABLE IF EXISTS `c2`;
DROP TABLE IF EXISTS `c3`;
DROP TABLE IF EXISTS `ceil_floor_round`;
DROP TABLE IF EXISTS `child`;
DROP TABLE IF EXISTS `d3`;
DROP TABLE IF EXISTS `dates`;
DROP TABLE IF EXISTS `fkest`;
DROP TABLE IF EXISTS `fkest1`;
DROP TABLE IF EXISTS `foo`;
DROP TABLE IF EXISTS `fract_only`;
DROP TABLE IF EXISTS `innertab`;
DROP TABLE IF EXISTS `inserttest01`;
DROP TABLE IF EXISTS `j11`;
DROP TABLE IF EXISTS `j12`;
DROP TABLE IF EXISTS `j21`;
DROP TABLE IF EXISTS `j22`;
DROP TABLE IF EXISTS `j31`;
DROP TABLE IF EXISTS `j32`;
DROP TABLE IF EXISTS `join_pt1`;
DROP TABLE IF EXISTS `minmaxtest`;
DROP TABLE IF EXISTS `multi_arg_agg`;
DROP TABLE IF EXISTS `nt1`;
DROP TABLE IF EXISTS `nt2`;
DROP TABLE IF EXISTS `nt3`;
DROP TABLE IF EXISTS `num_data`;
DROP TABLE IF EXISTS `num_exp_add`;
DROP TABLE IF EXISTS `num_exp_div`;
DROP TABLE IF EXISTS `num_exp_ln`;
DROP TABLE IF EXISTS `num_exp_log10`;
DROP TABLE IF EXISTS `num_exp_mul`;
DROP TABLE IF EXISTS `num_exp_power_10_ln`;
DROP TABLE IF EXISTS `num_exp_sqrt`;
DROP TABLE IF EXISTS `num_exp_sub`;
DROP TABLE IF EXISTS `num_input_test`;
DROP TABLE IF EXISTS `num_result`;
DROP TABLE IF EXISTS `num_tmp`;
DROP TABLE IF EXISTS `numeric_tmp`;
DROP TABLE IF EXISTS `onek`;
DROP TABLE IF EXISTS `onek2`;
DROP TABLE IF EXISTS `parent`;
DROP TABLE IF EXISTS `person`;
DROP TABLE IF EXISTS `q1`;
DROP TABLE IF EXISTS `q2`;
DROP TABLE IF EXISTS `regr_test`;
DROP TABLE IF EXISTS `road`;
DROP TABLE IF EXISTS `road_tmp`;
DROP TABLE IF EXISTS `student`;
DROP TABLE IF EXISTS `sub_tbl`;
DROP TABLE IF EXISTS `t1`;
DROP TABLE IF EXISTS `t11`;
DROP TABLE IF EXISTS `t12`;
DROP TABLE IF EXISTS `t2`;
DROP TABLE IF EXISTS `t21`;
DROP TABLE IF EXISTS `t22`;
DROP TABLE IF EXISTS `t31`;
DROP TABLE IF EXISTS `t32`;
DROP TABLE IF EXISTS `tenk1`;
DROP TABLE IF EXISTS `tenk2`;
DROP TABLE IF EXISTS `test_having`;
DROP TABLE IF EXISTS `testdata`;
DROP TABLE IF EXISTS `to_number_tbl`;
DROP TABLE IF EXISTS `tt1`;
DROP TABLE IF EXISTS `tt2`;
DROP TABLE IF EXISTS `tt3`;
DROP TABLE IF EXISTS `tt4`;
DROP TABLE IF EXISTS `tt4x`;
DROP TABLE IF EXISTS `tt5`;
DROP TABLE IF EXISTS `tt6`;
DROP TABLE IF EXISTS `uniquetbl`;
DROP TABLE IF EXISTS `update_test`;
DROP TABLE IF EXISTS `upsert_test`;
DROP TABLE IF EXISTS `width_bucket_tbl`;
DROP TABLE IF EXISTS `width_bucket_test`;
DROP TABLE IF EXISTS `x`;
DROP TABLE IF EXISTS `xx`;
DROP TABLE IF EXISTS `y`;
DROP TABLE IF EXISTS `yy`;
DROP TABLE IF EXISTS `zt1`;
DROP TABLE IF EXISTS `zt2`;
DROP TABLE IF EXISTS `zt3`;
SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE FLOAT4_TBL (f1  REAL);
CREATE TABLE FLOAT4_TMP (f1  REAL, id integer primary key auto_increment);
CREATE TABLE FLOAT8_TBL(f1 DOUBLE PRECISION);
CREATE TABLE FLOAT8_TMP (f1 DOUBLE PRECISION, f2 DOUBLE PRECISION, id integer primary key auto_increment);
CREATE TABLE INT4_TBL(f1 int4);
CREATE TABLE INT4_TMP (f1 int4, f2 int,  id integer primary key auto_increment);
CREATE TABLE INT8_TBL(
	q1 int8,
	q2 int8,
	CONSTRAINT t1_pkey PRIMARY KEY (q1, q2)
);
CREATE TABLE INT8_TMP(
	q1 int8,
	q2 int8,
	q3 int4,
	q4 int2,
	q5 text,
	id integer primary key auto_increment
);

CREATE TABLE INT2_TBL(f1 int2);
INSERT INTO INT2_TBL(f1) VALUES ('0   ');
INSERT INTO INT2_TBL(f1) VALUES ('  1234 ');
INSERT INTO INT2_TBL(f1) VALUES ('    -1234');
INSERT INTO INT2_TBL(f1) VALUES ('34.5');
-- largest and smallest values
INSERT INTO INT2_TBL(f1) VALUES ('32767');
INSERT INTO INT2_TBL(f1) VALUES ('-32767');

CREATE TABLE test_having (a int, b int, c char(8), d char);
CREATE TABLE onek (
	unique1		int4,
	unique2		int4,
	two			int4,
	four		int4,
	ten			int4,
	twenty		int4,
	hundred		int4,
	thousand	int4,
	twothousand	int4,
	fivethous	int4,
	tenthous	int4,
	odd			int4,
	even		int4,
	stringu1	varchar(64),
	stringu2	varchar(64),
	string4		varchar(64)
);

CREATE TABLE onek2 (
	unique1		int4,
	unique2		int4,
	two			int4,
	four		int4,
	ten			int4,
	twenty		int4,
	hundred		int4,
	thousand	int4,
	twothousand	int4,
	fivethous	int4,
	tenthous	int4,
	odd			int4,
	even		int4,
	stringu1	varchar(64),
	stringu2	varchar(64),
	string4		varchar(64)
);

CREATE TABLE tenk1 (
	unique1		int4,
	unique2		int4,
	two			int4,
	four		int4,
	ten			int4,
	twenty		int4,
	hundred		int4,
	thousand	int4,
	twothousand	int4,
	fivethous	int4,
	tenthous	int4,
	odd			int4,
	even		int4,
	stringu1	varchar(64),
	stringu2	varchar(64),
	string4		varchar(64)
);

CREATE TABLE tenk2 (
	unique1 	int4,
	unique2 	int4,
	two 	 	int4,
	four 		int4,
	ten			int4,
	twenty 		int4,
	hundred 	int4,
	thousand 	int4,
	twothousand int4,
	fivethous 	int4,
	tenthous	int4,
	odd			int4,
	even		int4,
	stringu1	varchar(64),
	stringu2	varchar(64),
	string4		varchar(64)
);

CREATE TABLE aggtest (
	a 			int2,
	b			float4
);

CREATE TABLE student (
	name 		text,
	age			int4,
	location 	point,
	gpa 		float8
);

CREATE TABLE person (
	name 		text,
	age			int4,
	location 	point
);

-- FOR prepare.sql

CREATE TABLE road (
	name		text,
	thepath 	LINESTRING
);

create table road_tmp (a int, b int, id integer primary key auto_increment);

CREATE TABLE dates (
	name			TEXT,
	date_as_text	TEXT,
	date_as_number	FLOAT8
);

-- import data from csv file
LOAD DATA LOCAL INFILE '/tmp/onek.data' INTO TABLE onek FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\n';
LOAD DATA LOCAL INFILE '/tmp/onek.data' INTO TABLE onek2 FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\n';
LOAD DATA LOCAL INFILE '/tmp/tenk.data' INTO TABLE tenk1 FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\n';
LOAD DATA LOCAL INFILE '/tmp/agg.data' INTO TABLE aggtest FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\n';

INSERT INTO student VALUES('fred', 28, POINT(3.1,-1.5), 3.70000000000000020e+00);
INSERT INTO student VALUES('larry', 60, POINT(21.8,4.9), 3.10000000000000010e+00);

INSERT INTO person VALUES ('mike',40,POINT(3.1,6.2));
INSERT INTO person VALUES ('joe',20,POINT(5.5,2.5));
INSERT INTO person VALUES ('sally',34,POINT(3.8,45.8));
INSERT INTO person VALUES ('sandra',19,POINT(9.345,09.6));
INSERT INTO person VALUES ('alex',30,POINT(1.352,8.2));
INSERT INTO person VALUES ('sue',50,POINT(8.34,7.375));
INSERT INTO person VALUES ('denise',24,POINT(3.78,87.90));
INSERT INTO person VALUES ('sarah',88,POINT(8.4,2.3));
INSERT INTO person VALUES ('teresa',38,POINT(7.7,1.8));
INSERT INTO person VALUES ('nan',28,POINT(6.35,0.43));
INSERT INTO person VALUES ('leah',68,POINT(0.6,3.37));
INSERT INTO person VALUES ('wendy',78,POINT(2.62,03.3));
INSERT INTO person VALUES ('melissa',28,POINT(3.089,087.23));
INSERT INTO person VALUES ('joan',18,POINT(9.4,47.04));
INSERT INTO person VALUES ('mary',08,POINT(3.7,39.20));
INSERT INTO person VALUES ('jane',58,POINT(1.34,0.44));
INSERT INTO person VALUES ('liza',38,POINT(9.76,6.90));
INSERT INTO person VALUES ('jean',28,POINT(8.561,7.3));
INSERT INTO person VALUES ('jenifer',38,POINT(6.6,23.3));
INSERT INTO person VALUES ('juanita',58,POINT(4.57,35.8));
INSERT INTO person VALUES ('susan',78,POINT(6.579,3));
INSERT INTO person VALUES ('zena',98,POINT(0.35,0));
INSERT INTO person VALUES ('martie',88,POINT(8.358,.93));
INSERT INTO person VALUES ('chris',78,POINT(9.78,2));
INSERT INTO person VALUES ('pat',18,POINT(1.19,0.6));
INSERT INTO person VALUES ('zola',58,POINT(2.56,4.3));
INSERT INTO person VALUES ('louise',98,POINT(5.0,8.7));
INSERT INTO person VALUES ('edna',18,POINT(1.53,3.5));
INSERT INTO person VALUES ('bertha',88,POINT(2.75,9.4));
INSERT INTO person VALUES ('sumi',38,POINT(1.15,0.6));
INSERT INTO person VALUES ('koko',88,POINT(1.7,5.5));
INSERT INTO person VALUES ('gina',18,POINT(9.82,7.5));
INSERT INTO person VALUES ('rean',48,POINT(8.5,5.0));
INSERT INTO person VALUES ('sharon',78,POINT(9.237,8.8));
INSERT INTO person VALUES ('paula',68,POINT(0.5,0.5));
INSERT INTO person VALUES ('julie',68,POINT(3.6,7.2));
INSERT INTO person VALUES ('belinda',38,POINT(8.9,1.7));
INSERT INTO person VALUES ('karen',48,POINT(8.73,0.0));
INSERT INTO person VALUES ('carina',58,POINT(4.27,8.8));
INSERT INTO person VALUES ('diane',18,POINT(5.912,5.3));
INSERT INTO person VALUES ('esther',98,POINT(5.36,7.6));
INSERT INTO person VALUES ('trudy',88,POINT(6.01,0.5));
INSERT INTO person VALUES ('fanny',08,POINT(1.2,0.9));
INSERT INTO person VALUES ('carmen',78,POINT(3.8,8.2));
INSERT INTO person VALUES ('lita',25,POINT(1.3,8.7));
INSERT INTO person VALUES ('pamela',48,POINT(8.21,9.3));
INSERT INTO person VALUES ('sandy',38,POINT(3.8,0.2));
INSERT INTO person VALUES ('trisha',88,POINT(1.29,2.2));
INSERT INTO person VALUES ('uma',78,POINT(9.73,6.4));
INSERT INTO person VALUES ('velma',68,POINT(8.8,8.9));

-- LOAD DATA LOCAL INFILE '/tmp/streets.data' INTO TABLE road FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\n';
LOAD DATA LOCAL INFILE '/tmp/datetimes.data' INTO TABLE dates FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\n';

INSERT INTO tenk2 SELECT * FROM tenk1;

CREATE TABLE bitwise_test(
  i2 INT2,
  i4 INT4,
  i8 INT8,
  i INTEGER,
  x INT2,
  id integer primary key auto_increment
);

CREATE TABLE bool_test(
  b1 BOOL,
  b2 BOOL,
  b3 BOOL,
  b4 BOOL,
  id integer primary key auto_increment);

CREATE TABLE bool_test_tmp(
  b1 BOOL,
  b2 BOOL, primary key (b1, b2));

-- FOR AGGREGATEQ.SQL

create table minmaxtest(f1 int, id integer primary key auto_increment);

create table agg_t1 (a int, b int, c int, d int, primary key (a, b));
create table agg_t2 (x int, y int, z int, primary key (x, y));
create table agg_t3 (a float8, b float8, id integer primary key auto_increment);
create table agg_t4 (a float4, b float4, id integer primary key auto_increment);
create table agg_t5 (a numeric, b numeric, id integer primary key auto_increment);
create table agg_t6 (a float8, id integer primary key auto_increment);
create table agg_t7 (a float8, b float8, c float8, d float8, id integer primary key auto_increment);
create table agg_t8 (a varchar(14), b text, primary key (a));
CREATE TABLE regr_test (x float8, y float8, id integer primary key auto_increment);
create table agg_t9 (a int, b int, c int, primary key (a, b));
create table agg_t10(one int, id integer primary key auto_increment);
create table agg_t11(one int, two int, id integer primary key auto_increment);
create table agg_t12(a int, id integer primary key auto_increment);
create table agg_t13(x int, id integer primary key auto_increment);
create table agg_t14(x int, y int, id integer primary key auto_increment);
create table agg_data_2k(g int , id integer primary key auto_increment);
create table agg_data_20k(g int , id integer primary key auto_increment);
create table t1(f1 int4, f2 int8, id integer primary key auto_increment);
create table t2(f1 int8, f22 int8, id integer primary key auto_increment);
create table agg_t15(a text, b int, c int, id integer primary key auto_increment);
create table agg_t16(a text, b text, id integer primary key auto_increment);
create table agg_t17(foo text, bar text, id integer primary key auto_increment);
create table agg_t18 (inner_c int, id integer primary key auto_increment);
create table agg_t19 (outer_c int, id integer primary key auto_increment);
create table agg_t20 (x text, id integer primary key auto_increment);
create table agg_t21 (x int, id integer primary key auto_increment);

-- multi-arg aggs
create table multi_arg_agg (a int, b int, c text, id integer primary key auto_increment);

create table agg_group_1 (c1 int, c2 numeric, c3 int, id integer primary key auto_increment);
create table agg_group_2 (a int , c1 numeric, c2 text, c3 int, id integer primary key auto_increment);
create table agg_group_3 (c1 numeric, c2 int, c3 int, id integer primary key auto_increment);
create table agg_group_4 (c1 numeric, c2 text, c3 int, id integer primary key auto_increment);

create table agg_hash_1 (c1 int, c2 numeric, c3 int, id integer primary key auto_increment);
create table agg_hash_2 (a int , c1 numeric, c2 text, c3 int, id integer primary key auto_increment);
create table agg_hash_3 (c1 numeric, c2 int, c3 int, id integer primary key auto_increment);
create table agg_hash_4 (c1 numeric, c2 text, c3 int, id integer primary key auto_increment);

-- FOR float4.sql
create table testdata(bits text, id integer primary key auto_increment);

-- FOR int4.sql
create table numeric_tmp(f1 numeric, f2 numeric , id integer primary key auto_increment);

CREATE TABLE VARCHAR_TBL(f1 varchar(4));

INSERT INTO VARCHAR_TBL (f1) VALUES ('a');
INSERT INTO VARCHAR_TBL (f1) VALUES ('ab');
INSERT INTO VARCHAR_TBL (f1) VALUES ('abcd');

create table bytea_test_table(v LONGBLOB, id integer primary key auto_increment);

-- FOR numeric.sql

CREATE TABLE num_data (id int4, val numeric, primary key (id));
CREATE TABLE num_exp_add (id1 int4, id2 int4, expected numeric, primary key (id1, id2));
CREATE TABLE num_exp_sub (id1 int4, id2 int4, expected numeric, primary key (id1, id2));
CREATE TABLE num_exp_div (id1 int4, id2 int4, expected numeric, primary key (id1, id2));
CREATE TABLE num_exp_mul (id1 int4, id2 int4, expected numeric, primary key (id1, id2));
CREATE TABLE num_exp_sqrt (id int4, expected numeric, primary key (id));
CREATE TABLE num_exp_ln (id int4, expected numeric, primary key (id));
CREATE TABLE num_exp_log10 (id int4, expected numeric, primary key (id));
CREATE TABLE num_exp_power_10_ln (id int4, expected numeric, primary key (id));

CREATE TABLE num_result (id1 int4, id2 int4, result numeric, primary key (id1, id2));
CREATE TABLE fract_only (id int, val numeric(4,4));
CREATE TABLE ceil_floor_round (a numeric primary key);
CREATE TABLE width_bucket_tbl (id1 numeric, id2 numeric, id3 numeric, id4 int, id integer primary key auto_increment);
CREATE TABLE width_bucket_test (operand_num numeric, operand_f8 float8);
CREATE TABLE num_input_test (n1 numeric);

CREATE TABLE num_tmp (n1 numeric, n2 numeric, id integer primary key auto_increment);
CREATE TABLE to_number_tbl(a text, id integer primary key auto_increment);

-- FOR join.sql

create table q1 (i int);
create table q2 (i int);
CREATE TABLE foo (f1 int);

CREATE TABLE J1_TBL (
  i integer,
  j integer,
  t text
);

CREATE TABLE J2_TBL (
  i integer,
  k integer
);

create table sub_tbl (key1 int, key3 int, key5 int, key6 int, value1 int, id integer primary key auto_increment);

CREATE TABLE t11 (name TEXT, n INTEGER);
CREATE TABLE t21 (name TEXT, n INTEGER);
CREATE TABLE t31 (name TEXT, n INTEGER);
create table x (x1 int, x2 int);
create table y (y1 int, y2 int);

CREATE TABLE t12 (a int, b int);
CREATE TABLE t22 (a int, b int);
CREATE TABLE t32 (x int, y int);

CREATE TABLE tt1 ( tt1_id int4, joincol int4 );
CREATE TABLE tt2 ( tt2_id int4, joincol int4 );
create table tt3(f1 int, f2 text);
create table tt4(f1 int);
create table tt4x(c1 int, c2 int, c3 int);
create table tt5(f1 int, f2 int);
create table tt6(f1 int, f2 int);
create table xx (pkxx int);
create table yy (pkyy int, pkxx int);
create table zt1 (f1 int primary key);
create table zt2 (f2 int primary key);
create table zt3 (f3 int primary key);

create table a1 (i integer);
create table b1 (x integer, y integer);

create table a2 (
     code char not null,
     primary key (code)
);
create table b2 (
     a char not null,
     num integer not null,
     primary key (a, num)
);
create table c2 (
     name char not null,
     a char,
     primary key (name)
);

create table nt1 (
  id int primary key,
  a1 boolean,
  a2 boolean
);
create table nt2 (
  id int primary key,
  nt1_id int,
  b1 boolean,
  b2 boolean,
  foreign key (nt1_id) references nt1(id)
);
create table nt3 (
  id int primary key,
  nt2_id int,
  c1 boolean,
  foreign key (nt2_id) references nt2(id)
);

CREATE TABLE TEXT_TBL (f1 text);

INSERT INTO TEXT_TBL VALUES ('doh!');
INSERT INTO TEXT_TBL VALUES ('hi de ho neighbor');

CREATE TABLE a3 (id int PRIMARY KEY, b_id int);
CREATE TABLE b3 (id int PRIMARY KEY, c_id int);
CREATE TABLE c3 (id int PRIMARY KEY);
CREATE TABLE d3 (a int, b int);

create table parent (k int primary key, pd int);
create table child (k int unique, cd int);

CREATE TABLE a4 (id int PRIMARY KEY);
CREATE TABLE b4 (id int PRIMARY KEY, a_id int);

create table innertab (id int8 primary key, dat1 int8);
create table uniquetbl (f1 varchar(14) unique);

create table join_pt1 (a int, b int, c varchar(14));

create table fkest (a int, b int, c int unique, primary key(a,b));
create table fkest1 (a int, b int, primary key(a,b), foreign key (a,b) references fkest(a,b));

create table j11 (id int primary key);
create table j21 (id int primary key);
create table j31 (id int);

create table j12 (id1 int, id2 int, primary key(id1,id2));
create table j22 (id1 int, id2 int, primary key(id1,id2));
create table j32 (id1 int, id2 int, primary key(id1,id2));

create table inserttest01 (col1 int4, col2 int4 NOT NULL, col3 text null);
CREATE TRIGGER inserttest01_insert
BEFORE INSERT ON inserttest01
FOR EACH ROW
SET NEW.`col3` = CASE WHEN NEW.col3 IS NULL THEN 'testing' ELSE NEW.col3 END
;

CREATE TABLE update_test (
	i   INT PRIMARY KEY,
    a   INT DEFAULT 10,
    b   INT,
    c   TEXT
);

create table upsert_test (a int primary key, b text);

