#postgresql #otus 
## Домашнее задание

Бэкапы
Цель:
применить логический бэкап;  
восстановиться из бэкапа;
Описание/Пошаговая инструкция выполнения домашнего задания:
1. Развернуть PostgreSQL (ВМ/Docker).
2. В БД test_db создать схему my_schema и две одинаковые таблицы (table1, table2).
3. Заполнить table1 100 строками с помощью generate_series.
### Ответ
```bash
postgres=# DROP DATABASE IF EXISTS test_db;
CREATE DATABASE test_db;
NOTICE:  database "test_db" does not exist, skipping
DROP DATABASE
CREATE DATABASE
postgres=# \c test_db
You are now connected to database "test_db" as user "postgres".
test_db=# CREATE SCHEMA my_schema;
SET SEARCH_PATH = my_schema, public;
CREATE TABLE table1
(
    id   integer PRIMARY KEY,
    name VARCHAR(15) NOT NULL
);
INSERT INTO table1 (id, name)
SELECT
    generate_series(1,100) AS id,
    md5(random()::text)::char(15) AS fio;
SELECT * FROM table1 LIMIT 10;
CREATE SCHEMA
SET
CREATE TABLE
INSERT 0 100
 id |      name       
----+-----------------
  1 | f835daa294ce205
  2 | 111fb6724725251
  3 | bb7a1c173d77954
  4 | efd96dd3e6c268c
  5 | 878834166416a3e
  6 | bc8aad091fa32eb
  7 | 006ffbbf1158a27
  8 | 518bd2c44e15fa6
  9 | b5da4b30c488c3a
 10 | 6fbbc288cb91f43
(10 rows)
test_db=#
```

4. Создать каталог /var/lib/postgresql/backups/ под пользователем postgres.
### Ответ
PostgreSQL в данном случае развернут в Docker на NAS Synology, база лежит в /var/lib/postgresql/pgdata_otus
```bash
root@fb04a301dc7a:/var/lib/postgresql/pgdata_otus# chown postgres:postgres backups/
root@fb04a301dc7a:/var/lib/postgresql/pgdata_otus# ls -la
total 56
drwx------ 1 postgres root       498 Mar  2 17:57 .
drwxrwxrwt 1       70       70   108 Mar  2 17:57 ..
-rw------- 1 postgres postgres     3 Feb 21 21:23 PG_VERSION
drwxr-xr-x 1 postgres postgres     0 Mar  2 17:57 backups
drwx------ 1 postgres postgres    16 Feb 21 21:23 base
drwx------ 1 postgres postgres   600 Feb 21 21:27 global
drwx------ 1 postgres postgres     0 Feb 21 21:23 pg_commit_ts
drwx------ 1 postgres postgres     0 Feb 21 21:23 pg_dynshmem
-rw------- 1 postgres postgres  5753 Feb 21 21:23 pg_hba.conf
-rw------- 1 postgres postgres  2681 Feb 21 21:23 pg_ident.conf
drwx------ 1 postgres postgres    76 Feb 21 21:31 pg_logical
drwx------ 1 postgres postgres    28 Feb 21 21:23 pg_multixact
drwx------ 1 postgres postgres     0 Feb 21 21:23 pg_notify
drwx------ 1 postgres postgres     0 Feb 21 21:23 pg_replslot
drwx------ 1 postgres postgres     0 Feb 21 21:23 pg_serial
drwx------ 1 postgres postgres     0 Feb 21 21:23 pg_snapshots
drwx------ 1 postgres postgres    22 Feb 21 21:31 pg_stat
drwx------ 1 postgres postgres     0 Feb 21 21:23 pg_stat_tmp
drwx------ 1 postgres postgres     8 Feb 21 21:23 pg_subtrans
drwx------ 1 postgres postgres     0 Feb 21 21:23 pg_tblspc
drwx------ 1 postgres postgres     0 Feb 21 21:23 pg_twophase
drwx------ 1 postgres postgres    94 Feb 21 21:23 pg_wal
drwx------ 1 postgres postgres     8 Feb 21 21:23 pg_xact
-rw------- 1 postgres postgres    88 Feb 21 21:23 postgresql.auto.conf
-rw------- 1 postgres postgres 32310 Feb 21 21:23 postgresql.conf
-rw------- 1 postgres postgres    36 Feb 21 21:23 postmaster.opts
root@fb04a301dc7a:/var/lib/postgresql/pgdata_otus#
```

5. Бэкап через COPY: Выгрузить table1 в CSV командой \copy.
### Ответ
```bash
test_db=# \copy table1 to '/var/lib/postgresql/pgdata_otus/backups/std.csv' with delimiter ',';
COPY 100
test_db=#
```

6. Восстановление из COPY: Загрузить данные из CSV в table2.
### Ответ
```bash
test_db=# CREATE TABLE table2
(
    id   integer PRIMARY KEY,
    name VARCHAR(15) NOT NULL
);
CREATE TABLE
test_db=# \copy table2 from '/var/lib/postgresql/pgdata_otus/backups/std.csv' WITH (FORMAT csv, DELIMITER ',');
COPY 100
test_db=# SELECT * FROM table2 LIMIT 10;
 id |      name       
----+-----------------
  1 | f835daa294ce205
  2 | 111fb6724725251
  3 | bb7a1c173d77954
  4 | efd96dd3e6c268c
  5 | 878834166416a3e
  6 | bc8aad091fa32eb
  7 | 006ffbbf1158a27
  8 | 518bd2c44e15fa6
  9 | b5da4b30c488c3a
 10 | 6fbbc288cb91f43
(10 rows)
test_db=#
```

6. Бэкап через pg_dump: создать кастомный сжатый дамп (-Fc) только схемы my_schema.
### Ответ
```bash
root@fb04a301dc7a:/var/lib/postgresql/pgdata_otus/backups# pg_dump -U postgres -d test_db --create -Fc -n my_schema -f /var/lib/postgresql/pgdata_otus/backups/arch.dump
root@fb04a301dc7a:/var/lib/postgresql/pgdata_otus/backups# ls -la
total 12
drwxr-xr-x 1 postgres postgres   32 Mar  2 19:26 .
drwx------ 1 postgres root      498 Mar  2 17:57 ..
-rw-r--r-- 1 root     root     4824 Mar  2 19:26 arch.dump
-rw-r--r-- 1 root     root     1892 Mar  2 19:06 std.csv
root@fb04a301dc7a:/var/lib/postgresql/pgdata_otus/backups#
```


7. Восстановление через pg_restore: В новую БД restored_db восстановить только table2 из дампа.
### Ответ
```sql
test_db=# \c postgres
You are now connected to database "postgres" as user "postgres".
postgres=# DROP DATABASE IF EXISTS restore_db;
CREATE DATABASE restore_db;
NOTICE:  database "restore_db" does not exist, skipping
DROP DATABASE
CREATE DATABASE
postgres=# \c restore_db
You are now connected to database "restore_db" as user "postgres".
restore_db=# CREATE SCHEMA my_schema;
CREATE SCHEMA
restore_db=#
```

```bash
root@fb04a301dc7a:/var/lib/postgresql/pgdata_otus/backups# pg_restore -v -U postgres -d restore_db -n my_schema -t table2 /var/lib/postgresql/pgdata_otus/backups/arch.dump

root@fb04a301dc7a:/var/lib/postgresql/pgdata_otus/backups#
```

```sql
restore_db=# SET SEARCH_PATH = my_schema, public;
SET
restore_db=# \dt+
                                         List of tables
  Schema   |  Name  | Type  |  Owner   | Persistence | Access method |    Size    | Description 
-----------+--------+-------+----------+-------------+---------------+------------+-------------
 my_schema | table2 | table | postgres | permanent   | heap          | 8192 bytes | 
(1 row)
restore_db=# select * from table2 limit 20;
 id |      name       
----+-----------------
  1 | f835daa294ce205
  2 | 111fb6724725251
  3 | bb7a1c173d77954
  4 | efd96dd3e6c268c
  5 | 878834166416a3e
  6 | bc8aad091fa32eb
  7 | 006ffbbf1158a27
  8 | 518bd2c44e15fa6
  9 | b5da4b30c488c3a
 10 | 6fbbc288cb91f43
 11 | 9707c2847a4558b
 12 | 7b131955b8c4f82
 13 | 744452e252e519b
 14 | cace8cc291248f0
 15 | 5f97bd07ea3e8a8
 16 | 7583e29537b080c
 17 | f07f15998769864
 18 | 517f2f2610c0366
 19 | 51ca47afe5b9b22
 20 | a1bb218380af23a
(20 rows)
  
restore_db=#
```

**Важно:** Предварительно создать схему my_schema в restored_db.

**Формат сдачи:** Отчет в README.md на GitHub с командами, пояснениями и списком решенных проблем.