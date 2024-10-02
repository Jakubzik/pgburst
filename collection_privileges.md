# Functions

There are also grants on functions, e.g. grant all on function su.fn_student_auflagen_add(...) to web_anon;

# Tables:

+----------+----------------+------------------------------------------+------------------------+
| user     | table_schema   | table_name                               | grants                 |
|----------+----------------+------------------------------------------+------------------------|
| postgres | public         | _shjSkala                                | ALL                    |
| postgres | su             | as_kvv                                   | ALL                    |
| web_anon | su             | as_kvv                                   | SELECT                 |
| postgres | statistik      | as_polyvalenter_ba_lao                   | ALL                    |
| postgres | su             | as_seminarstatistik                      | ALL                    |
| web_anon | su             | as_seminarstatistik                      | SELECT                 |
| postgres | statistik      | as_statistik_studiengaenge               | ALL                    |
| postgres | su             | diagnose_err_double_immatriculation_as   | ALL                    |
| postgres | su             | diagnose_err_double_immatriculation_gs   | ALL                    |
| postgres | su             | dozent                                   | ALL                    |
| postgres | up_med         | dozent                                   | ALL                    |
| web_anon | up_med         | dozent                                   | ALL                    |
| postgres | su_rust_urlaub | dozent_liste                             | ALL                    |
| postgres | su_rust        | dozent_publikationen                     | ALL                    |
| postgres | su_rust_urlaub | dozent_urlaubstage                       | ALL                    |
| postgres | public         | fach_as                                  | ALL                    |
| postgres | su             | fach_natural                             | ALL                    |
| postgres | su             | get_modulhandbuch                        | ALL                    |
| web_anon | su             | get_modulhandbuch                        | UPDATE, SELECT         |
...
SELECT grantee AS user, table_schema, table_name,
     CASE
         WHEN COUNT(privilege_type) = 7 THEN 'ALL'
         ELSE ARRAY_TO_STRING(ARRAY_AGG(privilege_type), ', ')
     END AS grants
 FROM information_schema.role_table_grants where table_schema not in ('information_schema','pg_catalog')


# Table Ownership
+------------+----------------------------------+------------+------------+------------+----------+-------------+-------------+
| schemaname | tablename                        | tableowner | tablespace | hasindexes | hasrules | hastriggers | rowsecurity |
|------------+----------------------------------+------------+------------+------------+----------+-------------+-------------|
| public     | tblBdAnmeldungSwap               | postgres   | <null>     | True       | False    | True        | False       |
| public     | _shjSkala                        | postgres   | <null>     | False      | False    | False       | False       |
| public     | pj                               | postgres   | <null>     | False      | False    | False       | False       |
| public     | t_statistik_studierende          | postgres   | <null>     | True       | False    | False       | False       |
| public     | tblBdDozentPublikation           | postgres   | <null>     | True       | False    | True        | False       |

select * from pg_tables where schemaname not in ('information_schema', 'pg_catalog');

# Schemas
====================================================

+----------+----------+--------------------+----------------+--------------+
| grantor  | grantee  | schema             | privilege_type | is_grantable |
|----------+----------+--------------------+----------------+--------------|
| postgres | postgres | pg_catalog         | USAGE          | False        |
| postgres | postgres | pg_catalog         | CREATE         | False        |
| postgres | PUBLIC   | pg_catalog         | USAGE          | False        |
| postgres | postgres | information_schema | USAGE          | False        |
...
| postgres | postgres | su                 | USAGE          | False        |
| postgres | postgres | su                 | CREATE         | False        |
| postgres | web_anon | su                 | USAGE          | False        |
| postgres | postgres | up_med             | USAGE          | False        |
| postgres | postgres | up_med             | CREATE         | False        |
| postgres | web_anon | up_med             | USAGE          | False        |
| postgres | web_anon | up_med             | CREATE         | False        |
+----------+----------+--------------------+----------------+--------------+

WITH users AS (select rolname, oid
               from pg_roles
               union
               select 'PUBLIC', 0)
SELECT r.rolname AS grantor,
       e.rolname AS grantee,
       nspname   as schema,
       privilege_type,
       is_grantable
FROM pg_namespace,
     aclexplode(nspacl) AS a
     JOIN users AS e
          ON a.grantee = e.oid
     JOIN users AS r
          ON a.grantor = r.oid;

===============================================

+----------------+-----------------------------------+-----------+
| Column         | Type                              | Modifiers |
|----------------+-----------------------------------+-----------|
| grantor        | information_schema.sql_identifier |           |
| grantee        | information_schema.sql_identifier |           |
| table_catalog  | information_schema.sql_identifier |           |
| table_schema   | information_schema.sql_identifier |           |
| table_name     | information_schema.sql_identifier |           |
| privilege_type | information_schema.character_data |           |
| is_grantable   | information_schema.yes_or_no      |           |
| with_hierarchy | information_schema.yes_or_no      |           |
+----------------+-----------------------------------+-----------+

- table_name enthält auch Views
- privilege_type ist Elem. (Truncate, References, Trigger, Select, Update, Insert, Delete)

SELECT * FROM information_schema.role_table_grants WHERE grantee = 'web_anon';

================================================================
+---------------+----------+------------+---------------+-------------+-------------+--------------+---------------+-----------------------+----------------+--------------+
| rolname       | rolsuper | rolinherit | rolcreaterole | rolcreatedb | rolcanlogin | rolconnlimit | rolvaliduntil | memberof              | rolreplication | rolbypassrls |
|---------------+----------+------------+---------------+-------------+-------------+--------------+---------------+-----------------------+----------------+--------------|
| anon          | False    | False      | False         | False       | False       | -1           | <null>        | []                    | False          | False        |
| authenticator | False    | True       | False         | False       | True        | -1           | <null>        | ['anon', 'sf_editor'] | False          | False        |
| heiko         | True     | True       | False         | False       | True        | -1           | <null>        | []                    | False          | False        |
| postgres      | True     | True       | True          | True        | True        | -1           | <null>        | ['web_anon']          | True           | True         |
| sf_editor     | False    | True       | False         | False       | False       | -1           | <null>        | []                    | False          | False        |
| web_anon      | False    | True       | False         | False       | False       | -1           | <null>        | []                    | False          | False        |
+---------------+----------+------------+---------------+-------------+-------------+--------------+---------------+-----------------------+----------------+--------------+
SELECT r.rolname, r.rolsuper, r.rolinherit,
  r.rolcreaterole, r.rolcreatedb, r.rolcanlogin,
  r.rolconnlimit, r.rolvaliduntil,
  ARRAY(SELECT b.rolname
        FROM pg_catalog.pg_auth_members m
        JOIN pg_catalog.pg_roles b ON (m.roleid = b.oid)
        WHERE m.member = r.oid) as memberof
, r.rolreplication
, r.rolbypassrls
FROM pg_catalog.pg_roles r
WHERE r.rolname !~ '^pg_'
ORDER BY 1;
