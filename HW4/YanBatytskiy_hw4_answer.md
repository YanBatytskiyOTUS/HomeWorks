#postgresql #otus 
## Домашнее задание

Работа с базами данных, пользователями и правами

Цель:

- создание новой базы данных, схемы и таблицы
- создание роли для чтения данных из созданной схемы созданной базы данных
- создание роли для чтения и записи из созданной схемы созданной базы данных

  

Описание/Пошаговая инструкция выполнения домашнего задания:

1. создайте новый кластер PostgresSQL 14
2. зайдите в созданный кластер под пользователем postgres
3. создайте новую базу данных testdb
4. зайдите в созданную базу данных под пользователем postgres
5. создайте новую схему testnm
6. создайте новую таблицу t1 с одной колонкой c1 типа integer
7. вставьте строку со значением c1=1
8. создайте новую роль readonly
9. дайте новой роли право на подключение к базе данных testdb
10. дайте новой роли право на использование схемы testnm
11. дайте новой роли право на select для всех таблиц схемы testnm
12. создайте пользователя testread с паролем test123
13. дайте роль readonly пользователю testread
```
postgres=# create database testdb
postgres-# ;
CREATE DATABASE
postgres=# \c testdb
You are now connected to database "testdb" as user "postgres".
testdb=# create schema testnm;
CREATE SCHEMA
testdb=# create table t1(c1 int);
CREATE TABLE
testdb=# insert into t1 values (1);
INSERT 0 1
testdb=# create role readonly;
CREATE ROLE
testdb=# grant connect on database testdb;
ERROR:  syntax error at or near ";"
LINE 1: grant connect on database testdb;
                                        ^
testdb=# grant connect on database testdb to readonly;
GRANT
testdb=# grant usage on schema testnm to readonly;
GRANT
testdb=# grant select on all tables in testnm to readonly;
ERROR:  syntax error at or near "testnm"
LINE 1: grant select on all tables in testnm to readonly;
                                      ^
testdb=# grant select on all tables in schema testnm to readonly;
GRANT
testdb=# create role testread with login password 'test123';
CREATE ROLE
testdb=# grant readonly to testread;
GRANT ROLE
testdb=# \q
```
14. зайдите под пользователем testread в базу данных testdb
15. сделайте select * from t1;
16. получилось? (могло если вы делали сами не по шпаргалке и не упустили один существенный момент про который позже)
```
root@otus:/etc/postgresql/18/main# psql -U testread -d testdb
Password for user testread: 
psql (18.1 (Ubuntu 18.1-1.pgdg24.04+2))
Type "help" for help.
testdb=> select * from t1;
ERROR:  permission denied for table t1
testdb=>
```
17. напишите что именно произошло в тексте домашнего задания
	потому что в пункте 6 не было сказано создать таблицу в новой схеме и таблица создалась в public, а права на public мы не давали

18. у вас есть идеи почему? ведь права то дали?
	потому что в пункте 6 не было сказано создать таблицу в новой схеме и таблица создалась в public, а права на public мы не давали
19. посмотрите на список таблиц
20. подсказка в шпаргалке под пунктом 20
21. а почему так получилось с таблицей (если делали сами и без шпаргалки то может у вас все нормально)

	потому что в пункте 6 не было сказано создать таблицу в новой схеме и таблица создалась в public, а права на public мы не давали

22. вернитесь в базу данных testdb под пользователем postgres
23. удалите таблицу t1
24. создайте ее заново но уже с явным указанием имени схемы testnm
25. вставьте строку со значением c1=1
26. зайдите под пользователем testread в базу данных testdb
27. сделайте select * from testnm.t1;
28. получилось?
29. есть идеи почему? если нет - смотрите шпаргалку
```
testdb=> select * from testnm.t1;
ERROR:  permission denied for table t1
testdb=>
```
потому что схема не в path и потому что set search_path выдается только на сеесию

30. как сделать так чтобы такое больше не повторялось? если нет идей - смотрите шпаргалку
добавить search_path через ALTER DATABASE

31. сделайте select * from testnm.t1;
32. получилось?
33. есть идеи почему? если нет - смотрите шпаргалку
34. сделайте select * from testnm.t1;
35. получилось?
```
estdb=> \dt
Did not find any tables.
testdb=> show search_path
testdb-> ;
   search_path   
-----------------
 "$user", public
(1 row)
testdb=> set search_path to "user", testnm, public, pg_catalog;
SET
testdb=> \dt
          List of tables
 Schema | Name | Type  |  Owner   
--------+------+-------+----------
 testnm | t1   | table | postgres
(1 row)
testdb=> select * from testnm.t1;
ERROR:  permission denied for table t1
testdb=>
```

так как права выдаются на объект, то при создании новой таблицы надо заново раздавать права либо закрепить привилегии пользователя глобально
```
postgres=# \c testdb
You are now connected to database "testdb" as user "postgres".
testdb=# alter default privileges in schema testnm grant select on tables to testread;
ALTER DEFAULT PRIVILEGES
testdb=#
```

36. ура!
37. теперь попробуйте выполнить команду create table t2(c1 integer); insert into t2 values (2);
в таком виде таблица в public не создается, потому что прав на create для testread не давали

38. а как так? нам же никто прав на создание таблиц и insert в них под ролью readonly?

39. есть идеи как убрать эти права? если нет - смотрите шпаргалку
в данной конфигурации команды прав, собственно говоря и нет. readonly не создаст в public таблицу.
- [ ] если только не сделать дополнительно:
```
alter role testread set search_path = testnm, public, pg_catalog;
```
но все равно надо раздать права на create
```
testdb=# grant create on schema testnm to readonly;
GRANT
testdb=# \q
root@otus:/etc/postgresql/18/main# psql -U testread -d testdb
Password for user testread: 
psql (18.1 (Ubuntu 18.1-1.pgdg24.04+2))
Type "help" for help.
testdb=> \q
root@otus:/etc/postgresql/18/main# sudo -u postgres psql
psql (18.1 (Ubuntu 18.1-1.pgdg24.04+2))
Type "help" for help.
postgres=# \c testdb
You are now connected to database "testdb" as user "postgres".
testdb=# \q
root@otus:/etc/postgresql/18/main# psql -U testread -d testdb
Password for user testread: 
psql (18.1 (Ubuntu 18.1-1.pgdg24.04+2))
Type "help" for help.
testdb=> set search_path to testnm, public, pg_catalog;
SET
testdb=> create table t2(c1 int); insert into t2 values(2);
CREATE TABLE
INSERT 0 1
testdb=>
```

40. если вы справились сами то расскажите что сделали и почему, если смотрели шпаргалку - объясните что сделали и почему выполнив указанные в ней команды
41. теперь попробуйте выполнить команду create table t3(c1 integer); insert into t2 values (2);
```
testdb=> create table t3(c1 integer); insert into t2 values (2);
CREATE TABLE
INSERT 0 1
testdb=>
```

42. расскажите что получилось и почему
потому что права по уму раздали