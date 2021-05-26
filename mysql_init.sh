#!/bin/sh
export MYSQL_PWD="edb"
MYSQL_HOST="localhost"
MYSQL_PORT="3306"
MYSQL_USER_NAME="edb"

# Below commands must be run first time to create mysql_fdw_regress and mysql_fdw_regress1 databases
# used in regression tests with edb user and edb password.
# --connect to mysql with root user
# mysql -u root -p

# --run below
# CREATE DATABASE mysql_fdw_regress;
# CREATE DATABASE mysql_fdw_regress1;
# CREATE DATABASE mysql_fdw_post;
# CREATE DATABASE mysql_fdw_core;
# SET GLOBAL validate_password.policy = LOW;
# SET GLOBAL validate_password.length = 1;
# SET GLOBAL validate_password.mixed_case_count = 0;
# SET GLOBAL validate_password.number_count = 0;
# SET GLOBAL validate_password.special_char_count = 0;
# CREATE USER 'edb'@'localhost' IDENTIFIED BY 'edb';
# GRANT ALL PRIVILEGES ON mysql_fdw_regress.* TO 'edb'@'localhost';
# GRANT ALL PRIVILEGES ON mysql_fdw_regress1.* TO 'edb'@'localhost';
# GRANT ALL PRIVILEGES ON mysql_fdw_post.* TO 'edb'@'localhost';
# GRANT ALL PRIVILEGES ON mysql_fdw_core.* TO 'edb'@'localhost';
# GRANT SUPER ON *.* TO 'edb'@localhost;

# Set time zone to default time zone of make check PST.
# SET GLOBAL time_zone = '-8:00';
# SET GLOBAL log_bin_trust_function_creators = 1;
# SET GLOBAL local_infile=1;

rm -rf /tmp/*.data
cp -a sql/init_data/*.data /tmp/

mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "DROP TABLE IF EXISTS mysql_test;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "DROP TABLE IF EXISTS empdata;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "DROP TABLE IF EXISTS numbers;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "DROP TABLE IF EXISTS test_tbl2;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "DROP TABLE IF EXISTS test_tbl1;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress1 -e "DROP TABLE IF EXISTS student;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress1 -e "DROP TABLE IF EXISTS numbers;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "DROP TABLE IF EXISTS enum_t1;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress1 -e "DROP TABLE IF EXISTS student1;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "DROP TABLE IF EXISTS enum_t2;"

mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "CREATE TABLE mysql_test(a int primary key, b int);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO mysql_test(a,b) VALUES (1,1);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "CREATE TABLE empdata (emp_id int, emp_dat blob, PRIMARY KEY (emp_id));"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "CREATE TABLE numbers (a int PRIMARY KEY, b varchar(255));"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "CREATE TABLE test_tbl1 (c1 INT primary key, c2 VARCHAR(10), c3 CHAR(9), c4 MEDIUMINT, c5 DATE, c6 DECIMAL(10,5), c7 INT, c8 SMALLINT);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "CREATE TABLE test_tbl2 (c1 INT primary key, c2 TEXT, c3 TEXT);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress1 -e "CREATE TABLE student (stu_id int PRIMARY KEY, stu_name text, stu_dept int);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress1 -e "CREATE TABLE numbers (a int, b varchar(255));"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "CREATE TABLE enum_t1 (id int PRIMARY KEY, size ENUM('small', 'medium', 'large'));"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress1 -e "CREATE TABLE student1 (stu_id varchar(10) PRIMARY KEY, stu_name text, stu_dept int);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "CREATE TABLE enum_t2 (id int PRIMARY KEY, size ENUM('S', 'M', 'L'));"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO enum_t2 VALUES (10, 'S'),(20, 'M'),(30, 'M');"

mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "DROP TABLE IF EXISTS s3;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "CREATE TABLE s3(id int PRIMARY KEY, tag1 text, value1 float, value2 int, value3 float, value4 int, str1 text, str2 text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s3 VALUES (0, 'a', 0.1, 100, -0.1, -100, '---XYZ---', '   XYZ   ');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s3 VALUES (1, 'a', 0.2, 100, -0.2, -100, '---XYZ---', '   XYZ   ');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s3 VALUES (2, 'a', 0.3, 100, -0.3, -100, '---XYZ---', '   XYZ   ');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s3 VALUES (3, 'b', 1.1, 200, -1.1, -200, '---XYZ---', '   XYZ   ');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s3 VALUES (4, 'b', 2.2, 200, -2.2, -200, '---XYZ---', '   XYZ   ');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s3 VALUES (5, 'b', 3.3, 200, -3.3, -200, '---XYZ---', '   XYZ   ');"

mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "DROP TABLE IF EXISTS s4;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "CREATE TABLE s4(id int PRIMARY KEY, c1 time);"

mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s4 VALUES (0, '12:10:30.123456');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s4 VALUES (1, '23:12:12.654321');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s4 VALUES (2, '11:12:12.112233');"

mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "DROP TABLE IF EXISTS s5;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "CREATE TABLE s5(id int PRIMARY KEY, b bit, b8 bit(8), b64 bit(64));"

mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s5 VALUES (0, b'1', b'1101', b'0111111111111111111111111111111111111111111111111100000000000001');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s5 VALUES (1, b'0', b'1001', b'0111111111111111111111111111111111111111111000001100000111000001');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s5 VALUES (2, b'1', b'1110', b'0111111111111111111111111111111111101010101111111100000000000001');"

mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "DROP TABLE IF EXISTS ftextsearch;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "CREATE TABLE ftextsearch(id int UNSIGNED AUTO_INCREMENT NOT NULL PRIMARY KEY, content TEXT, FULLTEXT (content));"

mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO ftextsearch (content) VALUES ('So many men, so many minds.');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO ftextsearch (content) VALUES ('Failure teaches success.');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO ftextsearch (content) VALUES ('It is no use cring over spilt mik.');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO ftextsearch (content) VALUES ('The early bird catches the worm.');"

mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS \`T 0\`;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS \`T 1\`;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS test;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS \`T 2\`;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS \`T 3\`;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS \`T 4\`;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS base_tbl;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loc1;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loct;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loct1;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loct2;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loct3;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loct4;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loct5;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loct6;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loct7;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loct8;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS gloc1;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS a;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loct9;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS parent_tbl;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loct31;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loct41;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loct42;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE \`T 0\` (\`C 1\` int PRIMARY KEY, c2 int NOT NULL, c3 text, c4 timestamp, c5 timestamp, c6 varchar(10), c7 char(10), c8 text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE \`T 1\` (\`C 1\` int PRIMARY KEY, c2 int NOT NULL, c3 text, c4 timestamp, c5 timestamp, c6 varchar(10), c7 char(10), c8 text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE test (c1 int PRIMARY KEY, c2 int NOT NULL, c3 text, c4 timestamp, c5 timestamp, c6 varchar(10), c7 char(10), c8 text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE \`T 2\` (c1 int, c2 text, CONSTRAINT t2_pkey PRIMARY KEY (c1));"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE \`T 3\` (c1 int, c2 int NOT NULL, c3 text, CONSTRAINT t3_pkey PRIMARY KEY (c1));"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE \`T 4\` (c1 int, c2 int NOT NULL, c3 text, CONSTRAINT t4_pkey PRIMARY KEY (c1));"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE base_tbl (a int, b int);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loc1 (f1 INTEGER, f2 text, id integer primary key auto_increment);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct (id integer primary key auto_increment,aa TEXT, bb TEXT);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct1 (id integer primary key auto_increment, f1 int, f2 int, f3 int);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct2 (id integer primary key auto_increment, f1 int, f2 int, f3 int);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct3 (a int, b text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct4 (a int, b text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct5 (a int check (a in (1)), b text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct6 (a int check (a in (2)), b text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct7 (a int check (a in (1)), b text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct8 (f1 text, f2 text, f3 text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE gloc1 (a int PRIMARY KEY, b int);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE a (aa TEXT);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct9 (aa TEXT, bb TEXT);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE parent_tbl (a int, b int);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct31 (f1 text, f2 text, f3 varchar(10));"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct41 (f1 int, f2 text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct42 (f1 int, f2 text);"

mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_core --local-infile=1 < sql/init_data/init_core.sql
