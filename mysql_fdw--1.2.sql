/*-------------------------------------------------------------------------
 *
 * mysql_fdw--1.2.sql
 * 			Foreign-data wrapper for remote MySQL servers
 *
 * Portions Copyright (c) 2012-2014, PostgreSQL Global Development Group
 * Portions Copyright (c) 2004-2021, EnterpriseDB Corporation.
 *
 * IDENTIFICATION
 * 			mysql_fdw--1.2.sql
 *
 *-------------------------------------------------------------------------
 */


CREATE FUNCTION mysql_fdw_handler()
RETURNS fdw_handler
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT;

CREATE FUNCTION mysql_fdw_validator(text[], oid)
RETURNS void
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT;

CREATE FOREIGN DATA WRAPPER mysql_fdw
  HANDLER mysql_fdw_handler
  VALIDATOR mysql_fdw_validator;

CREATE OR REPLACE FUNCTION mysql_fdw_version()
  RETURNS pg_catalog.int4 STRICT
  AS 'MODULE_PATHNAME' LANGUAGE C;

CREATE FUNCTION mysql_fdw_get_connections (OUT server_name text,
    OUT valid boolean)
RETURNS SETOF record
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT PARALLEL RESTRICTED;

CREATE FUNCTION mysql_fdw_disconnect (text)
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT PARALLEL RESTRICTED;

CREATE FUNCTION mysql_fdw_disconnect_all ()
RETURNS bool
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT PARALLEL RESTRICTED;

CREATE PROCEDURE mysql_create_or_replace_stub(func_type text, name_arg text, return_type regtype) AS $$
DECLARE
  proname_raw text := split_part(name_arg, '(', 1);
  proname text := ltrim(rtrim(proname_raw));
BEGIN
  IF lower(func_type) = 'aggregation' OR lower(func_type) = 'aggregate' OR lower(func_type) = 'agg' OR lower(func_type) = 'a' THEN
    DECLARE
      proargs_raw text := right(name_arg, length(name_arg) - length(proname_raw));
      proargs text := ltrim(rtrim(proargs_raw));
      proargs_types text := right(left(proargs, length(proargs) - 1), length(proargs) - 2);
      aggproargs text := format('(%s, %s)', return_type, proargs_types);
    BEGIN
      BEGIN
        EXECUTE format('
          CREATE FUNCTION %s_sfunc%s RETURNS %s IMMUTABLE AS $inner$
          BEGIN
            RAISE EXCEPTION ''stub %s_sfunc%s is called'';
            RETURN NULL;
          END $inner$ LANGUAGE plpgsql;',
	  proname, aggproargs, return_type, proname, aggproargs);
      EXCEPTION
        WHEN duplicate_function THEN
          RAISE DEBUG 'stub function for aggregation already exists (ignored)';
      END;
      BEGIN
        EXECUTE format('
          CREATE AGGREGATE %s
          (
            sfunc = %s_sfunc,
            stype = %s
          );', name_arg, proname, return_type);
      EXCEPTION
        WHEN duplicate_function THEN
          RAISE DEBUG 'stub aggregation already exists (ignored)';
        WHEN others THEN
          RAISE EXCEPTION 'stub aggregation exception';
      END;
    END;
  ELSIF lower(func_type) = 'function' OR lower(func_type) = 'func' OR lower(func_type) = 'f' THEN
    BEGIN
      EXECUTE format('
        CREATE FUNCTION %s RETURNS %s IMMUTABLE AS $inner$
        BEGIN
          RAISE EXCEPTION ''stub %s is called'';
          RETURN NULL;
        END $inner$ LANGUAGE plpgsql COST 1;',
        name_arg, return_type, name_arg);
    EXCEPTION
      WHEN duplicate_function THEN
        RAISE DEBUG 'stub already exists (ignored)';
    END;
  ELSEIF lower(func_type) = 'stable function' OR lower(func_type) = 'sfunc' OR lower(func_type) = 'sf' THEN
    BEGIN
      EXECUTE format('
        CREATE FUNCTION %s RETURNS %s STABLE AS $inner$
        BEGIN
          RAISE EXCEPTION ''stub %s is called'';
          RETURN NULL;
        END $inner$ LANGUAGE plpgsql COST 1;',
        name_arg, return_type, name_arg);
    EXCEPTION
      WHEN duplicate_function THEN
        RAISE DEBUG 'stub already exists (ignored)';
    END;
  ELSEIF lower(func_type) = 'volatile function' OR lower(func_type) = 'vfunc' OR lower(func_type) = 'vf' THEN
    BEGIN
      EXECUTE format('
        CREATE FUNCTION %s RETURNS %s VOLATILE AS $inner$
        BEGIN
          RAISE EXCEPTION ''stub %s is called'';
          RETURN NULL;
        END $inner$ LANGUAGE plpgsql COST 1;',
        name_arg, return_type, name_arg);
    EXCEPTION
      WHEN duplicate_function THEN
        RAISE DEBUG 'stub already exists (ignored)';
    END;
  ELSE
    RAISE EXCEPTION 'not supported function type %', func_type;
    BEGIN
      EXECUTE format('
        CREATE FUNCTION %s_sfunc RETURNS %s AS $inner$
        BEGIN
          RAISE EXCEPTION ''stub %s is called'';
          RETURN NULL;
       END $inner$ LANGUAGE plpgsql COST 1;',
        name_arg, return_type, name_arg);
    EXCEPTION
      WHEN duplicate_function THEN
        RAISE DEBUG 'stub already exists (ignored)';
    END;
  END IF;
END
$$ LANGUAGE plpgsql;

-- Create type
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'mysql_string_type') THEN
      CREATE TYPE mysql_string_type as enum ('CHAR', 'BINARY');
    END IF;
END$$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'time_unit') THEN
      CREATE TYPE time_unit as enum ('YEAR', 'QUARTER', 'MONTH', 'WEEK', 'DAY', 'HOUR', 'MINUTE', 'SECOND', 'MILLISECOND', 'MICROSECOND');
    END IF;
END$$;

-- ===============================================================================
-- Common functions
-- ===============================================================================
CALL mysql_create_or_replace_stub('vf', 'atan(float8, float8)', 'float8');
CALL mysql_create_or_replace_stub('vf', 'log2(float8)', 'float8');

-- ===============================================================================
-- MySQL special functions
-- ===============================================================================
CALL mysql_create_or_replace_stub('f', 'match_against(variadic text[])', 'float');

-- numeric functions
CALL mysql_create_or_replace_stub('vf', 'conv(anyelement, int, int)', 'text');
CALL mysql_create_or_replace_stub('vf', 'conv(text, int, int)', 'text');
CALL mysql_create_or_replace_stub('vf', 'crc32(anyelement)', 'bigint');
CALL mysql_create_or_replace_stub('vf', 'crc32(text)', 'bigint');
CALL mysql_create_or_replace_stub('vf', 'mysql_pi()', 'float8');
CALL mysql_create_or_replace_stub('vf', 'rand(float8)', 'float8');
CALL mysql_create_or_replace_stub('vf', 'rand()', 'float8');
CALL mysql_create_or_replace_stub('vf', 'truncate(float8, int)', 'float8');

-- string functions
CALL mysql_create_or_replace_stub('vf', 'bin(numeric)', 'text');
CALL mysql_create_or_replace_stub('vf', 'mysql_char(bigint)', 'text');
CALL mysql_create_or_replace_stub('vf', 'elt(int, variadic text[])', 'text');
CALL mysql_create_or_replace_stub('vf', 'export_set(int, text, text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'export_set(int, text, text, text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'export_set(int, text, text, text, int)', 'text');
CALL mysql_create_or_replace_stub('vf', 'field(text, variadic text[])', 'int');
CALL mysql_create_or_replace_stub('vf', 'find_in_set(text, text)', 'int');
CALL mysql_create_or_replace_stub('vf', 'format(double precision, int)', 'text');
CALL mysql_create_or_replace_stub('vf', 'format(double precision, int, text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'from_base64(text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'hex(text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'hex(bigint)', 'text');
CALL mysql_create_or_replace_stub('vf', 'insert(text, int, int, text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'instr(text, text)', 'bigint');
CALL mysql_create_or_replace_stub('vf', 'lcase(text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'locate(text, text)', 'bigint');
CALL mysql_create_or_replace_stub('vf', 'locate(text, text, bigint)', 'bigint');
CALL mysql_create_or_replace_stub('vf', 'make_set(bigint, variadic text[])', 'text');
CALL mysql_create_or_replace_stub('vf', 'mid(text, bigint, bigint)', 'text');
CALL mysql_create_or_replace_stub('vf', 'oct(bigint)', 'text');
CALL mysql_create_or_replace_stub('vf', 'ord(anyelement)', 'int');
CALL mysql_create_or_replace_stub('vf', 'quote(text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'regexp_instr(text, text)', 'int');
CALL mysql_create_or_replace_stub('vf', 'regexp_instr(text, text, int)', 'int');
CALL mysql_create_or_replace_stub('vf', 'regexp_instr(text, text, int, int)', 'int');
CALL mysql_create_or_replace_stub('vf', 'regexp_instr(text, text, int, int, int)', 'int');
CALL mysql_create_or_replace_stub('vf', 'regexp_instr(text, text, int, int, int, text)', 'int');
CALL mysql_create_or_replace_stub('vf', 'regexp_like(text, text)', 'int');
CALL mysql_create_or_replace_stub('vf', 'regexp_like(text, text, text)', 'int');
CALL mysql_create_or_replace_stub('vf', 'regexp_replace(text, text, text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'regexp_replace(text, text, text, int)', 'text');
CALL mysql_create_or_replace_stub('vf', 'regexp_replace(text, text, text, int, int)', 'text');
CALL mysql_create_or_replace_stub('vf', 'regexp_replace(text, text, text, int, int, text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'regexp_substr(text, text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'regexp_substr(text, text, int)', 'text');
CALL mysql_create_or_replace_stub('vf', 'regexp_substr(text, text, int, int)', 'text');
CALL mysql_create_or_replace_stub('vf', 'regexp_substr(text, text, int, int, text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'space(bigint)', 'text');
CALL mysql_create_or_replace_stub('vf', 'strcmp(text, text)', 'int');
CALL mysql_create_or_replace_stub('vf', 'substring_index(text, text, bigint)', 'text');
CALL mysql_create_or_replace_stub('vf', 'to_base64(text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'ucase(text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'unhex(text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'weight_string(text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'weight_string(text, mysql_string_type, int)', 'text');

-- Date and Time Functions
CALL mysql_create_or_replace_stub('vf', 'adddate(timestamp, int)', 'date');
CALL mysql_create_or_replace_stub('vf', 'adddate(timestamp, interval)', 'timestamp');
CALL mysql_create_or_replace_stub('vf', 'addtime(timestamp, interval)', 'timestamp');
CALL mysql_create_or_replace_stub('vf', 'addtime(interval, interval)', 'interval');
CALL mysql_create_or_replace_stub('vf', 'convert_tz(timestamp, text, text)', 'timestamp'); -- need load timezone table
CALL mysql_create_or_replace_stub('vf', 'curdate()', 'date');
CALL mysql_create_or_replace_stub('vf', 'mysql_current_date()', 'date');
CALL mysql_create_or_replace_stub('vf', 'curtime()', 'time');
CALL mysql_create_or_replace_stub('vf', 'mysql_current_time()', 'time');
CALL mysql_create_or_replace_stub('vf', 'mysql_current_timestamp()', 'timestamp');
CALL mysql_create_or_replace_stub('vf', 'date_add(timestamp, interval)', 'timestamp');
CALL mysql_create_or_replace_stub('vf', 'date_format(timestamp, text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'date_sub(date, interval)', 'date');
CALL mysql_create_or_replace_stub('vf', 'date_sub(timestamp, interval)', 'timestamp');
CALL mysql_create_or_replace_stub('vf', 'datediff(timestamp, timestamp)', 'integer');
CALL mysql_create_or_replace_stub('vf', 'day(timestamp)', 'integer');
CALL mysql_create_or_replace_stub('vf', 'dayname(date)', 'text');
CALL mysql_create_or_replace_stub('vf', 'dayofmonth(date)', 'integer');
CALL mysql_create_or_replace_stub('vf', 'dayofweek(date)', 'integer');
CALL mysql_create_or_replace_stub('vf', 'dayofyear(date)', 'integer');
CALL mysql_create_or_replace_stub('vf', 'mysql_extract(text, timestamp)', 'integer');
CALL mysql_create_or_replace_stub('vf', 'from_days(integer)', 'date');
CALL mysql_create_or_replace_stub('vf', 'from_unixtime(bigint)', 'timestamp');
CALL mysql_create_or_replace_stub('vf', 'from_unixtime(bigint, text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'get_format(text, text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'hour(time without time zone)', 'int');
CALL mysql_create_or_replace_stub('vf', 'last_day(timestamp)', 'date');
CALL mysql_create_or_replace_stub('vf', 'mysql_localtime()', 'timestamp');
CALL mysql_create_or_replace_stub('vf', 'mysql_localtimestamp()', 'timestamp');
CALL mysql_create_or_replace_stub('vf', 'makedate(integer, integer)', 'date');
CALL mysql_create_or_replace_stub('vf', 'maketime(integer, integer, integer)', 'time');
CALL mysql_create_or_replace_stub('vf', 'microsecond(time)', 'integer');
CALL mysql_create_or_replace_stub('vf', 'microsecond(timestamp)', 'integer');
CALL mysql_create_or_replace_stub('vf', 'minute(time)', 'integer');
CALL mysql_create_or_replace_stub('vf', 'minute(timestamp)', 'integer');
CALL mysql_create_or_replace_stub('vf', 'month(timestamp)', 'integer');
CALL mysql_create_or_replace_stub('vf', 'monthname(timestamp)', 'text');
CALL mysql_create_or_replace_stub('vf', 'mysql_now()', 'timestamp');
CALL mysql_create_or_replace_stub('vf', 'period_add(integer, integer)', 'integer');
CALL mysql_create_or_replace_stub('vf', 'period_diff(integer, integer)', 'integer');
CALL mysql_create_or_replace_stub('vf', 'quarter(timestamp)', 'text');
CALL mysql_create_or_replace_stub('vf', 'sec_to_time(int)', 'time');
CALL mysql_create_or_replace_stub('vf', 'second(time)', 'integer');
CALL mysql_create_or_replace_stub('vf', 'second(timestamp)', 'integer');
CALL mysql_create_or_replace_stub('vf', 'str_to_date(text, text)', 'date');
CALL mysql_create_or_replace_stub('vf', 'str_to_date(time, text)', 'time');
CALL mysql_create_or_replace_stub('vf', 'str_to_date(timestamp, text)', 'timestamp');
CALL mysql_create_or_replace_stub('vf', 'subdate(timestamp, interval)', 'timestamp');
CALL mysql_create_or_replace_stub('vf', 'subtime(timestamp, interval)', 'timestamp');
CALL mysql_create_or_replace_stub('vf', 'subtime(time, time)', 'interval');
CALL mysql_create_or_replace_stub('vf', 'subtime(interval, interval)', 'interval');
CALL mysql_create_or_replace_stub('vf', 'sysdate()', 'timestamp');
CALL mysql_create_or_replace_stub('vf', 'mysql_time(timestamp)', 'time');
CALL mysql_create_or_replace_stub('vf', 'time_format(time, text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'time_to_sec(time)', 'integer');
CALL mysql_create_or_replace_stub('vf', 'timediff(time, time)', 'interval');
CALL mysql_create_or_replace_stub('vf', 'timediff(timestamp, timestamp)', 'interval');
CALL mysql_create_or_replace_stub('vf', 'mysql_timestamp(timestamp)', 'timestamp');
CALL mysql_create_or_replace_stub('vf', 'mysql_timestamp(timestamp, time)', 'timestamp');
CALL mysql_create_or_replace_stub('vf', 'timestampadd(time_unit, integer, timestamp)', 'timestamp');
CALL mysql_create_or_replace_stub('vf', 'timestampdiff(time_unit, timestamp, timestamp)', 'double precision');
CALL mysql_create_or_replace_stub('vf', 'to_days(date)', 'integer');
CALL mysql_create_or_replace_stub('vf', 'to_days(integer)', 'integer');
CALL mysql_create_or_replace_stub('vf', 'to_seconds(integer)', 'bigint');
CALL mysql_create_or_replace_stub('vf', 'to_seconds(timestamp)', 'bigint');
CALL mysql_create_or_replace_stub('vf', 'unix_timestamp()', 'numeric');
CALL mysql_create_or_replace_stub('vf', 'unix_timestamp(timestamp)', 'numeric');
CALL mysql_create_or_replace_stub('vf', 'utc_date()', 'date');
CALL mysql_create_or_replace_stub('vf', 'utc_time()', 'time');
CALL mysql_create_or_replace_stub('vf', 'utc_timestamp()', 'timestamp');
CALL mysql_create_or_replace_stub('vf', 'week(timestamp)', 'integer');
CALL mysql_create_or_replace_stub('vf', 'week(timestamp, integer)', 'integer');
CALL mysql_create_or_replace_stub('vf', 'weekday(timestamp)', 'integer');
CALL mysql_create_or_replace_stub('vf', 'weekofyear(timestamp)', 'integer');
CALL mysql_create_or_replace_stub('vf', 'year(timestamp)', 'integer');
CALL mysql_create_or_replace_stub('vf', 'yearweek(timestamp)', 'integer');
-- ===============================================================================
-- MySQL aggregate functions
-- ===============================================================================
CALL mysql_create_or_replace_stub('a', 'bit_xor(anyelement)', 'numeric');
CALL mysql_create_or_replace_stub('a', 'group_concat(anyelement)', 'text');
CALL mysql_create_or_replace_stub('a', 'json_agg(anyelement)', 'text');
CALL mysql_create_or_replace_stub('a', 'json_object_agg(text, anyelement)', 'text');
CALL mysql_create_or_replace_stub('a', 'std(anyelement)', 'double precision');

-- json function
-- custom type for [path, value]
--create types
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'path_value') THEN
      CREATE TYPE path_value;

      CREATE FUNCTION path_value_in(cstring)
        RETURNS path_value
        AS 'MODULE_PATHNAME'
        LANGUAGE C IMMUTABLE STRICT;

      CREATE FUNCTION path_value_out(path_value)
        RETURNS cstring
        AS 'MODULE_PATHNAME'
        LANGUAGE C IMMUTABLE STRICT;

      CREATE TYPE path_value (
        internallength = VARIABLE,
        input = path_value_in,
        output = path_value_out
      );
    END IF;
END$$;

CALL mysql_create_or_replace_stub('vf', 'json_array_append(json, variadic path_value[])', 'json');
CALL mysql_create_or_replace_stub('vf', 'json_array_insert(json, variadic path_value[])', 'json');
CALL mysql_create_or_replace_stub('vf', 'json_contains(json, json)', 'int');
CALL mysql_create_or_replace_stub('vf', 'json_contains(json, text)', 'int');
CALL mysql_create_or_replace_stub('vf', 'json_contains(json, json, text)', 'int');
CALL mysql_create_or_replace_stub('vf', 'json_contains_path(json, variadic text[])', 'int');
CALL mysql_create_or_replace_stub('vf', 'json_depth(json)', 'int');
CALL mysql_create_or_replace_stub('vf', 'json_extract(json, variadic text[])', 'text');
CALL mysql_create_or_replace_stub('vf', 'json_insert(json, variadic path_value[])', 'json');
CALL mysql_create_or_replace_stub('vf', 'json_keys(json)', 'json');
CALL mysql_create_or_replace_stub('vf', 'json_keys(json, text)', 'json');
CALL mysql_create_or_replace_stub('vf', 'json_length(json)', 'int');
CALL mysql_create_or_replace_stub('vf', 'json_length(json, text)', 'int');
CALL mysql_create_or_replace_stub('vf', 'json_merge(variadic json[])', 'json');
CALL mysql_create_or_replace_stub('vf', 'json_merge_patch(variadic json[])', 'json');
CALL mysql_create_or_replace_stub('vf', 'json_merge_preserve(variadic json[])', 'json');
CALL mysql_create_or_replace_stub('vf', 'json_overlaps(json, json)', 'int');
CALL mysql_create_or_replace_stub('vf', 'json_pretty(json)', 'json');
CALL mysql_create_or_replace_stub('vf', 'json_quote(text)', 'json');
CALL mysql_create_or_replace_stub('vf', 'json_remove(json, variadic text[])', 'json');
CALL mysql_create_or_replace_stub('vf', 'json_replace(json, variadic path_value[])', 'json');
CALL mysql_create_or_replace_stub('vf', 'json_schema_valid(json, json)', 'int');
CALL mysql_create_or_replace_stub('vf', 'json_schema_validation_report(json, json)', 'json');
CALL mysql_create_or_replace_stub('vf', 'json_search(json, text, text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'json_search(json, text, text, text, variadic text[])', 'text');
CALL mysql_create_or_replace_stub('vf', 'json_set(json, variadic path_value[])', 'json');
CALL mysql_create_or_replace_stub('vf', 'json_storage_free(json)', 'int');
CALL mysql_create_or_replace_stub('vf', 'json_storage_size(json)', 'int');
CALL mysql_create_or_replace_stub('vf', 'mysql_json_table(json, text, text[], text[])', 'text');
CALL mysql_create_or_replace_stub('vf', 'json_type(json)', 'text');
CALL mysql_create_or_replace_stub('vf', 'json_unquote(text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'json_valid(text)', 'int');
CALL mysql_create_or_replace_stub('vf', 'json_valid(json)', 'int');
CALL mysql_create_or_replace_stub('vf', 'json_value(json, text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'json_value(json, text, text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'json_value(json, text, text, text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'json_value(json, text, text, text, text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'member_of(anyelement, json)', 'int');
CALL mysql_create_or_replace_stub('vf', 'member_of(text, json)', 'int');

-- Cast function
CALL mysql_create_or_replace_stub('vf', 'convert(text, text)', 'text');
CALL mysql_create_or_replace_stub('vf', 'convert(anyelement, text)', 'text');
