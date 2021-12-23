#!/bin/sh
export MYSQL_PWD="edb"
MYSQL_HOST="localhost"
MYSQL_PORT="3306"
MYSQL_USER_NAME="edb"

# Below commands must be run first time to create mysql_fdw_regress and mysql_fdw_regress1 databases
# used in regression tests with edb user and edb password.

# load timezone table
# mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql -u root -p mysql

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
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "DROP TABLE IF EXISTS test1;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "DROP TABLE IF EXISTS test2;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "DROP TABLE IF EXISTS test3;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "DROP TABLE IF EXISTS test4;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "DROP TABLE IF EXISTS test5;"

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
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "CREATE TABLE test1 (c1 int PRIMARY KEY, c2 int, c3 varchar(255), c4 ENUM ('foo', 'bar', 'buz'))"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "CREATE TABLE test2 (c1 int PRIMARY KEY, c2 int, c3 varchar(255), c4 ENUM ('foo', 'bar', 'buz'))"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "CREATE TABLE test3 (c1 int PRIMARY KEY, c2 int, c3 varchar(255))"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "CREATE TABLE test4 (c1 int PRIMARY KEY, c2 int, c3 varchar(255))"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "CREATE TABLE test5 (c1 int primary key, c2 binary, c3 binary(3), c4 binary(1), c5 binary(10), c6 varbinary(3), c7 varbinary(1), c8 varbinary(10), c9 binary(0), c10 varbinary(0));"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO test5 VALUES (1, 'c', 'c3c', 't', 'c5c5c5', '04', '1', '01-10-2021', NULL, '');"

mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "DROP TABLE IF EXISTS s3;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "CREATE TABLE s3(id int PRIMARY KEY, tag1 text, value1 float, value2 int, value3 float, value4 int, str1 text, str2 text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s3 VALUES (0, 'a', 0.1, 100, -0.1, -100, '---XYZ---', '   XYZ   ');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s3 VALUES (1, 'a', 0.2, 100, -0.2, -100, '---XYZ---', '   XYZ   ');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s3 VALUES (2, 'a', 0.3, 100, -0.3, -100, '---XYZ---', '   XYZ   ');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s3 VALUES (3, 'b', 1.1, 200, -1.1, -200, '---XYZ---', '   XYZ   ');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s3 VALUES (4, 'b', 2.2, 200, -2.2, -200, '---XYZ---', '   XYZ   ');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s3 VALUES (5, 'b', 3.3, 200, -3.3, -200, '---XYZ---', '   XYZ   ');"

mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "DROP TABLE IF EXISTS s4;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "CREATE TABLE s4(id int PRIMARY KEY, c1 time(6));"

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

mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "DROP TABLE IF EXISTS s6;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "CREATE TABLE s6(id int PRIMARY KEY, c1 int, c2 int, c3 text);"

mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "DROP TABLE IF EXISTS time_tbl;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "CREATE TABLE time_tbl (id int PRIMARY KEY, c1 time, c2 date, c3 timestamp);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO time_tbl VALUES (0, '12:10:30.123456', '2021-01-02', '2021-01-03 12:10:30.123456');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO time_tbl VALUES (1, '23:12:12.654321', '2021-01-01', '2021-01-04 23:12:12.654321');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO time_tbl VALUES (2, '11:12:12.112233', '2021-01-10', '2021-01-05 11:12:12.112233');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO time_tbl VALUES (3, '15:59:59.654321', '2021-01-15', '2021-01-06 15:59:59.654321');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO time_tbl VALUES (4, '00:59:59.000102', '2021-01-29', '2021-01-07 00:59:59.000102');"

mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "DROP TABLE IF EXISTS s7;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "CREATE TABLE s7(id int PRIMARY KEY, tag1 text, value1 float, value2 int, value3 float, value4 int, value5 bit(16), str1 text, str2 text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s7 VALUES (0, 'a', 0.1, 100, -0.1, -100, X'1234', '---XYZ---', '   XYZ   ');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s7 VALUES (1, 'a', 0.2, 100, -0.2, -101, X'FF34', '---XYZ---', '   XYZ   ');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s7 VALUES (2, 'a', 0.3, 100, -0.3, -102, NULL, '---XYZ---', '   XYZ   ');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s7 VALUES (3, 'b', 1.1, 200, -1.1, -200, X'FA34', '---XYZ---', '   XYZ   ');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s7 VALUES (4, 'b', 2.2, 200, -2.2, -210, X'CD34', '---XYZ---', '   XYZ   ');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s7 VALUES (5, 'b', 3.3, 200, -3.3, -220, X'AB34', '---XYZ---', '   XYZ   ');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "DROP TABLE IF EXISTS s8;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "CREATE TABLE s8(id int PRIMARY KEY, c1 json, c2 int, c3 text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s8 VALUES (0, '[[1,2],[3,4],5]', 1, 'This');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s8 VALUES (1, '[]', 2, 'is');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s8 VALUES (2, '{}', 3, 'text');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s8 VALUES (3, '{\"a\":\"10\",\"b\":\"15\",\"x\":25}', 4, 'scalar');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s8 VALUES (4, '{\"a\": 1, \"b\": 2, \"c\": {\"d\": 4}}', 5, 'scalar');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s8 VALUES (5, '[\"abc\", [{\"k\": \"10\"}, \"def\"], {\"x\":\"abc\"}, {\"y\":\"bcd\"}]', 5, 'scalar');"

mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_regress -e "DROP TABLE IF EXISTS s9;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "CREATE TABLE s9(id int PRIMARY KEY, c1 json);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s9 VALUES (0, '{\
                                                                                \"id\": \"http://json-schema.org/geo\",\
                                                                                \"\$schema\": \"http://json-schema.org/draft-04/schema#\",\
                                                                                \"description\": \"A geographical coordinate\",\
                                                                                \"type\": \"object\",\
                                                                                \"properties\": {\
                                                                                \"latitude\": {\
                                                                                    \"type\": \"number\",\
                                                                                    \"minimum\": -90,\
                                                                                    \"maximum\": 90\
                                                                                },\
                                                                                \"longitude\": {\
                                                                                    \"type\": \"number\",\
                                                                                    \"minimum\": -180,\
                                                                                    \"maximum\": 180\
                                                                                }\
                                                                                },\
                                                                                \"required\": [\"latitude\", \"longitude\"]\
                                                                                }');"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_regress -e "INSERT INTO s9 VALUES (1, '{   \"id\": \"http://json-schema.org/geo\",\
                                                                            \"\$schema\": \"http://json-schema.org/draft-04/schema#\",\
                                                                            \"description\": \"A geographical coordinate\",\
                                                                            \"type\": \"object\",\
                                                                            \"properties\": {\
                                                                            \"latitude\": {\
                                                                                \"type\": \"number\",\
                                                                                \"minimum\": -9,\
                                                                                \"maximum\": 9\
                                                                            },\
                                                                            \"longitude\": {\
                                                                                \"type\": \"number\",\
                                                                                \"minimum\": -18,\
                                                                                \"maximum\": 18\
                                                                            }\
                                                                            }\
                                                                            }');"

mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS \`T 0\`;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS \`T 1\`;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS test;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS \`T 2\`;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS \`T 3\`;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS \`T 4\`;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS t1_constraint;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS base_tbl;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS position_data1;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS position_data2;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS table_data;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loct_empty;"
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
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loct10;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loct11;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loct12;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loct13;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loc2;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loc3;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loc4;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS gloc1;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS gloc1_post14;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS a;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loct9;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS child_tbl;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loct31;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loct41;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS loct42;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS batch_table;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS tru_rtable;"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "DROP TABLE IF EXISTS tru_rtable2;"

mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE \`T 0\` (\`C 1\` int PRIMARY KEY, c2 int NOT NULL, c3 text, c4 timestamp, c5 timestamp, c6 varchar(10), c7 char(10), c8 text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE \`T 1\` (\`C 1\` int PRIMARY KEY, c2 int NOT NULL, c3 text, c4 timestamp, c5 timestamp, c6 varchar(10), c7 char(10), c8 text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE test (c1 int PRIMARY KEY, c2 int NOT NULL, c3 text, c4 timestamp, c5 timestamp, c6 varchar(10), c7 char(10), c8 text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE \`T 2\` (c1 int, c2 text, CONSTRAINT t2_pkey PRIMARY KEY (c1));"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE \`T 3\` (c1 int, c2 int NOT NULL, c3 text, CONSTRAINT t3_pkey PRIMARY KEY (c1));"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE \`T 4\` (c1 int, c2 int NOT NULL, c3 text, CONSTRAINT t4_pkey PRIMARY KEY (c1));"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE base_tbl (id int primary key auto_increment, a int, b int);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct_empty (c1 int PRIMARY KEY NOT NULL, c2 text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loc1 (f1 INTEGER, f2 text, id integer primary key auto_increment);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct (id integer primary key auto_increment,aa TEXT, bb TEXT);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct1 (id integer primary key auto_increment, f1 int, f2 int, f3 int);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct2 (id integer primary key auto_increment, f1 int, f2 int, f3 int);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct3 (a int, b text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct4 (a int, b text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct5 (id int primary key auto_increment, a int check (a in (1)), b text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct6 (id int primary key auto_increment, a int check (a in (2)), b text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct7 (a int check (a in (1)), b text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct8 (f1 text, f2 text, f3 text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct10 (id int primary key auto_increment, a int check (a in (1)), b text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct11 (id int primary key auto_increment, a int check (a in (3)), b text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct12 (id int primary key auto_increment, a int check (a in (1)), b text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct13 (id int primary key auto_increment, a int check (a in (2)), b text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loc2 (id int primary key auto_increment, f1 int, f2 text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loc3 (id int primary key auto_increment, f1 int, f2 text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loc4 (id int primary key auto_increment, f1 int, f2 text, CONSTRAINT loc4_f1positive CHECK ((f1 >= 0)));"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE gloc1 (id int primary key auto_increment, a int, b int);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE gloc1_post14 (id int primary key auto_increment, a int, b int generated always as (\`a\` * 2) stored);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE a (aa TEXT);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct9 (aa TEXT, bb TEXT);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE child_tbl (id integer primary key auto_increment, a integer, b integer);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct31 (f1 text, f2 text, f3 varchar(10));"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct41 (f1 int, f2 text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE loct42 (f1 int, f2 text);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE t1_constraint (c1 int primary key, c2 int NOT NULL check (c2 >= 0), c3 text, c4 timestamp, c5 timestamp, c6 varchar(10), c7 char(10), c8 text check (c8 IN ('foo','bar', 'buz')));"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE position_data1 (c1 INT primary key, c2 INT, c3 CHAR(9), c4 timestamp, c5 timestamp, c6 DECIMAL(10,5), c7 INT, c8 SMALLINT);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -P $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE position_data2 (c1 INT primary key, c2 INT, c3 CHAR(9), c4 timestamp, c5 timestamp, c6 DECIMAL(10,5), c7 INT, c8 SMALLINT);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE table_data (i int, b bool);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "INSERT INTO table_data VALUE (1, true);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "INSERT INTO table_data VALUE (2, false);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "INSERT INTO table_data VALUE (null, true);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "INSERT INTO table_data VALUE (null, false);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "INSERT INTO table_data VALUE (3, null);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE batch_table ( x int PRIMARY KEY);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE tru_rtable (id int PRIMARY KEY);"
mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_post -e "CREATE TABLE tru_rtable2 (id int PRIMARY KEY);"

mysql -h $MYSQL_HOST -u $MYSQL_USER_NAME -D $MYSQL_PORT -D mysql_fdw_core --local-infile=1 < sql/init_data/init_core.sql
