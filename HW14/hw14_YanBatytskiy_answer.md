#postgresql #otus 
## Домашнее задание
Репликация
Цель:
реализовать свой миникластер на трех виртуальных машинах;
Описание/Пошаговая инструкция выполнения домашнего задания:
**1. Настройте ВМ1:**
- Создайте таблицу test, которая будет для операций записи
- Создайте таблицу test2, которая будет для чтения
- Настройте публикацию таблицы test

Ответ:
```sql

postgres=# \l
                                                     List of databases
   Name    |  Owner   | Encoding | Locale Provider |   Collate   |    Ctype    | Locale | ICU Rules |   Access privileges   
-----------+----------+----------+-----------------+-------------+-------------+--------+-----------+-----------------------
 postgres  | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           | 
 template0 | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           | =c/postgres          +
           |          |          |                 |             |             |        |           | postgres=CTc/postgres
 template1 | postgres | UTF8     | libc            | en_US.UTF-8 | en_US.UTF-8 |        |           | =c/postgres          +
           |          |          |                 |             |             |        |           | postgres=CTc/postgres
(3 rows)

postgres=# create database otus;
CREATE DATABASE
postgres=# 
postgres=# \c
You are now connected to database "postgres" as user "postgres".
postgres=# \c otus
You are now connected to database "otus" as user "postgres".
otus=# create table test as select generate_series(1,10) as id, md5(random()::text)::char(10) as fio;
SELECT 10
otus=# create user vm1 password 'otuspassword';
CREATE ROLE
otus=# grant select on table test to vm1;
GRANT
otus=#
otus=# create table test2 (id int, fio char(10));
CREATE TABLE
otus=# GRANT ALL PRIVILEGES ON TABLE test2 TO vm1;
GRANT
otus=# 
otus=# create publication test_pub for table test;
WARNING:  "wal_level" is insufficient to publish logical changes
HINT:  Set "wal_level" to "logical" before creating subscriptions.
CREATE PUBLICATION
otus=# 
```

```zsh
Last login: Sun Mar  8 15:51:23 2026 from 77.125.33.239
root@otus:~# sudo nano /etc/postgresql/18/main/postgresql.conf 
root@otus:~# pg_lsclusters
Ver Cluster Port  Status Owner     Data directory              Log file
18  chk     55433 down   <unknown> /mnt/data/18/chk            /var/log/postgresql/postgresql-18-chk.log
18  main    5432  online postgres  /var/lib/postgresql/18/main log/postgresql-%Y-%m-%d_%H%M%S.log
root@otus:~# pg_ctlcluster 18 main restart
root@otus:~#
```

```bash
postgres=# show wal_level;
 wal_level 
-----------
 logical
(1 row)

postgres=# 
postgres=# \c otus
You are now connected to database "otus" as user "postgres".
otus=# create publication test_pub for table test;
ERROR:  publication "test_pub" already exists
otus=# select * from pg_publication;
  oid  | pubname  | pubowner | puballtables | pubinsert | pubupdate | pubdelete | pubtruncate | pubviaroot | pubgencols 
-------+----------+----------+--------------+-----------+-----------+-----------+-------------+------------+------------
 17603 | test_pub |       10 | f            | t         | t         | t         | t           | f          | n
(1 row)

otus=# select * from pg_publication_tables;
 pubname  | schemaname | tablename | attnames | rowfilter 
----------+------------+-----------+----------+-----------
 test_pub | public     | test      | {id,fio} | 
(1 row)

otus=# 
```

**2. Настройте ВМ2:**
- Создайте таблицу test2, которая будет для операций записи
- Создайте таблицу test, которая будет для чтения
- Настройте публикацию таблицы test2
- Сделайте подписку таблицы test на публикацию таблицы test с ВМ1

 Ответ:
 ```sql
 otus=# select * from pg_publication;
  oid  |  pubname  | pubowner | puballtables | pubinsert | pubupdate | pubdelete | pubtruncate | pubviaroot | pubgencols 
-------+-----------+----------+--------------+-----------+-----------+-----------+-------------+------------+------------
 17606 | test2_pub |       10 | f            | t         | t         | t         | t           | f          | n
(1 row)
otus=# \dt+
                                     List of tables
 Schema | Name  | Type  |  Owner   | Persistence | Access method |  Size   | Description 
--------+-------+-------+----------+-------------+---------------+---------+-------------
 public | test  | table | postgres | permanent   | heap          | 0 bytes | 
 public | test2 | table | postgres | permanent   | heap          | 0 bytes | 
(2 rows)
otus=# \pset pager off
Pager usage is off.
otus=# select * from test2;
 id | fio 
----+-----
(0 rows)
otus=# select * from test;
 id | fio 
----+-----
(0 rows)
otus=# insert into test2 (1, 'test2-vm2');
ERROR:  syntax error at or near "1"
LINE 1: insert into test2 (1, 'test2-vm2');
                           ^
otus=# insert into test2 values (1, 'test2-vm2');
INSERT 0 1
otus=# 
otus=# CREATE SUBSCRIPTION test_sub_from_vm1
CONNECTION 'host=91.226.72.214 port=5432 user=vm1 
password=otuspassword dbname=otus' PUBLICATION test_pub WITH
(copy_data = true);
ERROR:  subscription "test_sub_from_vm1" could not connect to the publisher: connection to server at "91.226.72.214", port 5432 failed: FATAL:  permission denied to start WAL sender
DETAIL:  Only roles with the REPLICATION attribute may start a WAL sender process.
otus=# 
 ```

```sql
postgres=# alter role vm1 with login replication;
ALTER ROLE
postgres=# 
```

после танцев с бубном
```sql
otus=# CREATE SUBSCRIPTION test_sub_from_vm1
CONNECTION 'host=91.226.72.214 port=5432 user=vm1 password=otuspassword dbname=otus sslmode=disable gssencmode=disable connect_timeout=15'
PUBLICATION test_pub
WITH (copy_data = false);
NOTICE:  created replication slot "test_sub_from_vm1" on publisher
CREATE SUBSCRIPTION
otus=# 

otus=# ALTER SUBSCRIPTION test_sub_from_vm1 SET (slot_name = NONE);
DROP SUBSCRIPTION test_sub_from_vm1;
ALTER SUBSCRIPTION
DROP SUBSCRIPTION
otus=# CREATE SUBSCRIPTION test_sub_from_vm1
CONNECTION 'host=91.226.72.214 port=5432 user=vm1 password=otuspassword dbname=otus sslmode=disable gssencmode=disable connect_timeout=15'
PUBLICATION test_pub
WITH (copy_data = true);
ERROR:  could not create replication slot "test_sub_from_vm1": ERROR:  replication slot "test_sub_from_vm1" already exists
otus=# CREATE SUBSCRIPTION test_sub_from_vm1
CONNECTION 'host=91.226.72.214 port=5432 user=vm1 password=otuspassword dbname=otus sslmode=disable gssencmode=disable connect_timeout=15'
PUBLICATION test_pub
WITH (copy_data = true);
NOTICE:  created replication slot "test_sub_from_vm1" on publisher
CREATE SUBSCRIPTION
otus=# 

otus=# SELECT * FROM pg_stat_subscription \gx
-[ RECORD 1 ]---------+------------------------------
subid                 | 17612
subname               | test_sub_from_vm1
worker_type           | apply
pid                   | 10815
leader_pid            | 
relid                 | 
received_lsn          | 
last_msg_send_time    | 2026-03-08 19:24:55.535899+00
last_msg_receipt_time | 2026-03-08 19:24:55.535899+00
latest_end_lsn        | 
latest_end_time       | 2026-03-08 19:24:55.535899+00

otus=# 
otus=# select * from test;
 id |    fio     
----+------------
  1 | 6ab526872d
  2 | d08ea0dd97
  3 | 054a71c91f
  4 | d42d51b541
  5 | 87588e5b4a
  6 | bd73fa8a3d
  7 | 5ee229e300
  8 | 047b182022
  9 | 676d2b4116
 10 | db7b3a76d4
(10 rows)

otus=# 
```

```sql
otus=# insert into test values (11, 'test1 vm2');
INSERT 0 1
otus=# 
```

```sql
otus=# select * from test;
 id |    fio     
----+------------
  1 | 6ab526872d
  2 | d08ea0dd97
  3 | 054a71c91f
  4 | d42d51b541
  5 | 87588e5b4a
  6 | bd73fa8a3d
  7 | 5ee229e300
  8 | 047b182022
  9 | 676d2b4116
 10 | db7b3a76d4
 11 | test1 vm2 
(11 rows)

otus=# 
```

**3. на ВМ1:**
- Сделайте подписку таблицы test2 на публикацию таблицы test2 с ВМ2
Ответ:
```sql
otus=# create publication test2_pub_from_vm2_to_vm1 for table test2;
CREATE PUBLICATION
otus=# \dRp+

                             Publication test2_pub_from_vm2_to_vm1
  Owner   | All tables | Inserts | Updates | Deletes | Truncates | Generated columns | Via root 
----------+------------+---------+---------+---------+-----------+-------------------+----------
 postgres | f          | t       | t       | t       | t         | none              | f
Tables:
    "public.test2"

otus=# 
otus=# select * from test2;
 id |    fio     
----+------------
  1 | test2-vm2 
(1 row)

otus=# insert into test2 values (2, 'test3-vm2');
INSERT 0 1
otus=# 
```

```sql
otus=# CREATE SUBSCRIPTION test2_sub_from_vm2
CONNECTION 'host=83.229.70.52 port=5432 user=vm2 password=otuspassword dbname=otus '
PUBLICATION test2_pub_from_vm2_to_vm1
WITH (copy_data = true);
NOTICE:  created replication slot "test2_sub_from_vm2" on publisher
CREATE SUBSCRIPTION
otus=# 
```

```sql
otus=# select * from test2;
 id |    fio     
----+------------
  1 | test2-vm2 
  2 | test3-vm2 
(2 rows)

otus=# 
```

**4. Настройте ВМ3:**
- Создайте таблицы: test и test2
- Подпишите test на публикацию таблицы test с ВМ1
- Подпишите test2 на публикацию таблицы test2 с ВМ2
- Используйте этот узел для чтения объединённых данных и резервного копирования

Ответ:
VM3
```sql
oot@otus-vm3:~# sudo -u postgres psql
psql (18.3 (Ubuntu 18.3-1.pgdg24.04+1))
Type "help" for help.

postgres=# \l
postgres=# \pset pager off
Pager usage is off.
postgres=# create database otus;
CREATE DATABASE
postgres=# \c otus
You are now connected to database "otus" as user "postgres".
otus=# create table test (id integer, fio char(10));
CREATE TABLE
otus=# create table test2 (id integer, fio char(10));
CREATE TABLE
otus=# create user vm3 with login password 'otuspassword';
CREATE ROLE
otus=# alter role vm3 with replication;
ALTER ROLE
otus=# 
```

VM1
```sql
otus-# \dt+
                                       List of tables
 Schema | Name  | Type  |  Owner   | Persistence | Access method |    Size    | Description 
--------+-------+-------+----------+-------------+---------------+------------+-------------
 public | test  | table | postgres | permanent   | heap          | 8192 bytes | 
 public | test2 | table | postgres | permanent   | heap          | 8192 bytes | 
(2 rows)

otus-# create publication test_pub_from_vm1 for table test;
ERROR:  syntax error at or near "create"
LINE 2: create publication test_pub_from_vm1 for table test;
        ^
otus=# create publication test_pub_from_vm1 for table test;
CREATE PUBLICATION
otus=# 
```

VM2
```sql
otus=# select * from pg_stat_subscription \gx
-[ RECORD 1 ]---------+------------------------------
subid                 | 17612
subname               | test_sub_from_vm1
worker_type           | apply
pid                   | 10838
leader_pid            | 
relid                 | 
received_lsn          | 1/AE499088
last_msg_send_time    | 2026-03-08 20:13:00.651068+00
last_msg_receipt_time | 2026-03-08 20:12:59.98333+00
latest_end_lsn        | 1/AE499088
latest_end_time       | 2026-03-08 20:13:00.651068+00

otus=# create publication test2_pub_from_vm2 for table test2;
CREATE PUBLICATION
otus=# \dRp+
                                 Publication test2_pub_from_vm2
  Owner   | All tables | Inserts | Updates | Deletes | Truncates | Generated columns | Via root 
----------+------------+---------+---------+---------+-----------+-------------------+----------
 postgres | f          | t       | t       | t       | t         | none              | f
Tables:
    "public.test2"

                             Publication test2_pub_from_vm2_to_vm1
  Owner   | All tables | Inserts | Updates | Deletes | Truncates | Generated columns | Via root 
----------+------------+---------+---------+---------+-----------+-------------------+----------
 postgres | f          | t       | t       | t       | t         | none              | f
Tables:
    "public.test2"

otus=# 
```

VM3
```sql
otus=# CREATE SUBSCRIPTION sub_test_from_vm1
CONNECTION 'host=91.226.72.214 port=5432 user=vm1 password=otuspassword dbname=otus connect_timeout=5 application_name=sub_test_from_vm1_vm3'
PUBLICATION test_pub_from_vm1
WITH (copy_data = false);
NOTICE:  created replication slot "sub_test_from_vm1" on publisher
CREATE SUBSCRIPTION
otus=# 
otus=# CREATE SUBSCRIPTION sub_test_from_vm1
CONNECTION 'host=91.226.72.214 port=5432 user=vm1 password=otuspassword dbname=otus'
PUBLICATION test_pub_from_vm1
WITH (copy_data = true);
NOTICE:  created replication slot "sub_test_from_vm1" on publisher
CREATE SUBSCRIPTION
otus=# select * from test;
 id | fio 
----+-----
(0 rows)

otus=# 
otus=# CREATE SUBSCRIPTION sub_test2_from_vm2
CONNECTION 'host=83.229.70.52 port=5432 user=vm2 password=otuspassword dbname=otus connect_timeout=5'
PUBLICATION test2_pub_from_vm2
WITH (copy_data = true);
NOTICE:  created replication slot "sub_test2_from_vm2" on publisher
CREATE SUBSCRIPTION
otus=# select * from test2;
 id |    fio     
----+------------
  1 | test2-vm2 
  2 | test3-vm2 
(2 rows)

otus=# 

otus=# CREATE OR REPLACE VIEW v_all_data AS
SELECT 'vm1' AS src, id, fio FROM public.test
UNION ALL
SELECT 'vm2' AS src, id, fio FROM public.test2;
CREATE VIEW
otus=# select * from v_all_data;
 src | id |    fio     
-----+----+------------
 vm2 |  1 | test2-vm2 
 vm2 |  2 | test3-vm2 
(2 rows)

otus=# 
```

VM1
```sql
otus=# insert into test values (12, 'view vm2');
INSERT 0 1
otus=# insert into test values (13, 'view f vm1');
INSERT 0 1
otus=# select * from test;
 id |    fio     
----+------------
  1 | 6ab526872d
  2 | d08ea0dd97
  3 | 054a71c91f
  4 | d42d51b541
  5 | 87588e5b4a
  6 | bd73fa8a3d
  7 | 5ee229e300
  8 | 047b182022
  9 | 676d2b4116
 10 | db7b3a76d4
 11 | test1 vm2 
 12 | view vm2  
 13 | view f vm1
(13 rows)

otus=# 
```

VM2
```sql
otus=# insert into test2 values (101, 'from vm3');
INSERT 0 1

otus=# select * from test2;
 id  |    fio     
-----+------------
   1 | test2-vm2 
   2 | test3-vm2 
 101 | from vm3  
(3 rows)

otus=# 
```

VM3
```sql
otus=# select * from v_all_data;
 src | id  |    fio     
-----+-----+------------
 vm1 |   1 | 6ab526872d
 vm1 |   2 | d08ea0dd97
 vm1 |   3 | 054a71c91f
 vm1 |   4 | d42d51b541
 vm1 |   5 | 87588e5b4a
 vm1 |   6 | bd73fa8a3d
 vm1 |   7 | 5ee229e300
 vm1 |   8 | 047b182022
 vm1 |   9 | 676d2b4116
 vm1 |  10 | db7b3a76d4
 vm1 |  11 | test1 vm2 
 vm1 |  12 | view vm2  
 vm1 |  13 | view f vm1
 vm2 |   1 | test2-vm2 
 vm2 |   2 | test3-vm2 
 vm2 | 101 | from vm3  
(16 rows)

otus=# 
```

**Проверьте работу системы:**
- Выполните вставку в test на ВМ1 — убедитесь, что данные появились в test на ВМ2 и ВМ3
- Выполните вставку в test2 на ВМ2 — убедитесь, что данные появились в test2 на ВМ1 и ВМ3
**Задание повышенной сложности(*):**  
Настройте физическую репликацию с ВМ4, используя ВМ3 в качестве источника.