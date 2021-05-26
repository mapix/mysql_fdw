./mysql_init.sh

sed -i 's/REGRESS =.*/REGRESS = server_options connection_validation dml select pushdown selectfunc mysql_fdw_post extra\/aggregates/' Makefile

make clean
make
make check | tee make_check.out
