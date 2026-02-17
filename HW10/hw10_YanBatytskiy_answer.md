#postgresql #otus 
## Домашнее задание

Работа с индексами

Цель:

знать и уметь применять основные виды индексов PostgreSQL;  
строить и анализировать план выполнения запроса;  
оптимизировать запросы для использования индексов;

Описание/Пошаговая инструкция выполнения домашнего задания:

Необходимо:
1. Создать индекс к какой-либо из таблиц вашей БД
Имеем таблицу в базе данных - таблица содержит страницы данных, полученных по Odata из 1С для будущей миграции. Данные скачиваются порциями по 300 строк максимум по разным сущностям (request_id). Skip_value это поле для запроса в Odata для игнорирования уже скачанных строк (пагинация).

```
postgres=# \c erp_staging_odata_test  
You are now connected to database "erp_staging_odata_test" as user "postgres".  
erp_staging_odata_test=# SELECT                 
 n.nspname AS schema_name,  
 c.relname AS table_name,  
 c.reltuples::bigint AS approx_rows,  
 pg_size_pretty(pg_relation_size(c.oid))        AS table_only,  
 pg_size_pretty(pg_indexes_size(c.oid))         AS indexes,  
 pg_size_pretty(pg_total_relation_size(c.oid))  AS total  
FROM pg_class c  
JOIN pg_namespace n ON n.oid = c.relnamespace  
WHERE c.oid = 'rawdata.odata_page'::regclass;  
schema_name | table_name | approx_rows | table_only | indexes | total     
-------------+------------+-------------+------------+---------+--------  
rawdata     | odata_page |         202 | 64 kB      | 56 kB   | 160 kB  
(1 row)
  
erp_staging_odata_test=# select  
   s.n_distinct  
   from pg_stats s  
where s.tablename= 'odata_page'  
and s.attname = 'skip_value';  
n_distinct     
-------------  
-0.17326732  
(1 row)  
  
erp_staging_odata_test=# select  
   s.n_distinct  
   from pg_stats s  
where s.tablename= 'odata_page'  
and s.attname = 'run_id';  
n_distinct    
------------  
-0.4009901  
(1 row)  
  
erp_staging_odata_test=#
```

Делаем два индекса:
```
erp_staging_odata_test=# create index  idx_odata_page_skip_value  
on rawdata.odata_page(skip_value);  
CREATE INDEX  
erp_staging_odata_test=# create index  idx_odata_page_run_id  
on rawdata.odata_page(skip_value);  
CREATE INDEX  
erp_staging_odata_test=#
```

2. Прислать текстом результат команды explain,  
    в которой используется данный индекс
```
erp_staging_odata_test=# 
explain  
select * from rawdata.odata_page  
where skip_value < 1000;  
                         QUERY PLAN                              
---------------------------------------------------------------  
Seq Scan on odata_page  (cost=0.00..10.53 rows=121 width=240)  
  Filter: (skip_value < 1000)  
(2 rows)  
  
erp_staging_odata_test=# 
explain  
select * from rawdata.odata_page  
where skip_value > 60000;  
                                       QUERY PLAN                                           
------------------------------------------------------------------------------------------  
Index Scan using idx_odata_page_run_id on odata_page  (cost=0.14..7.87 rows=1 width=240)  
  Index Cond: (skip_value > 60000)  
(2 rows)  
  
erp_staging_odata_test=#
```

3. Реализовать индекс для полнотекстового поиска
```
--для полнотекстового поиска  
select odata_request.request_id, odata_request.request_name, odata_request.entity_set  
from rawdata.odata_request  
limit 10;

1,Контрагенты все,Catalog_Контрагенты
2,Контрагенты ИсторияКонтактнойИнформации все,Catalog_Контрагенты_ИсторияКонтактнойИнформации
3,Контрагенты ИсторияКПП все,Catalog_Контрагенты_ИсторияКПП
4,Контрагенты ИсторияНаименований все,Catalog_Контрагенты_ИсторияНаименований
5,Контрагенты РеквизитыИзменение все,Catalog_Контрагенты_РеквизитыИзменение
6,Контрагенты ТЧУсловияПереходаПраваСобственности все,Catalog_Контрагенты_ТЧУсловияПереходаПраваСобственности
7,Страны все,Catalog_Страны
8,Города все,Catalog_Города
9,Организации все,Catalog_Организации
10,Холдинги все,Catalog_Холдинги
11...

erp_staging_odata_test=# 
create index idx_odata_request  
on rawdata.odata_request  
using gin (to_tsvector('russian', rawdata.odata_request.entity_set));  
CREATE INDEX  
erp_staging_odata_test=#

erp_staging_odata_test=# set enable_seqscan = off;  
  
explain  
select odata_request.request_id, odata_request.request_name, odata_request.entity_set  
from rawdata.odata_request  
where entity_set like '%Города%';  
SET  
                          QUERY PLAN                              
----------------------------------------------------------------  
Seq Scan on odata_request  (cost=0.00..21.59 rows=1 width=101)  
  Disabled: true  
  Filter: (entity_set ~~ '%Города%'::text)  
(3 rows)  
  
erp_staging_odata_test=#

```

4. Реализовать индекс на часть таблицы или индекс  
    на поле с функцией
```sql
--- без индекса
erp_staging_odata_test=# explain  
select odata_page.request_id,  
      (odata_page.rows_collected::numeric /1000) as rows_in_thousand  
from rawdata.odata_page  
where (odata_page.rows_collected::numeric /1000) = 0.3;  
                          QUERY PLAN                               
-----------------------------------------------------------------  
Seq Scan on odata_page  (cost=0.00..11.54 rows=1 width=40)  
  Disabled: true  
  Filter: (((rows_collected)::numeric / '1000'::numeric) = 0.3)  
(3 rows)  
  
erp_staging_odata_test=#

--с индексом    

erp_staging_odata_test=# 
create index  
func_idx_odata_page_rows_collected  
on rawdata.odata_page ((rows_collected::numeric / 1000));  
CREATE INDEX  
erp_staging_odata_test=# 
explain  
select odata_page.request_id,  
      (odata_page.rows_collected::numeric /1000) as rows_in_thousand  
from rawdata.odata_page  
where (odata_page.rows_collected::numeric /1000) = 0.3;  
                                             QUERY PLAN                                                 
------------------------------------------------------------------------------------------------------  
Index Scan using func_idx_odata_page_rows_collected on odata_page  (cost=0.14..8.17 rows=1 width=40)  
  Index Cond: (((rows_collected)::numeric / '1000'::numeric) = 0.3)  
(2 rows)  
  
erp_staging_odata_test=#
```

5. Создать индекс на несколько полей
```sql
erp_staging_odata_test=# explain  
select * from rawdata.odata_page  
where skip_value > 6000  
and request_id = 1;  
                                     QUERY PLAN                                          
---------------------------------------------------------------------------------------  
Bitmap Heap Scan on odata_page  (cost=8.72..17.07 rows=2 width=240)  
  Recheck Cond: (request_id = 1)  
  Filter: (skip_value > 6000)  
  ->  Bitmap Index Scan on request_run_page_no_unq  (cost=0.00..8.72 rows=23 width=0)  
        Index Cond: (request_id = 1)  
(5 rows)  
  
erp_staging_odata_test=# create index  idx_odata_page_run_id  
on rawdata.odata_page(skip_value, request_id);  
CREATE INDEX  
erp_staging_odata_test=# explain  
select * from rawdata.odata_page  
where skip_value > 6000  
and request_id = 1;  
                                    QUERY PLAN                                        
------------------------------------------------------------------------------------  
Bitmap Heap Scan on odata_page  (cost=4.30..9.33 rows=2 width=240)  
  Recheck Cond: ((skip_value > 6000) AND (request_id = 1))  
  ->  Bitmap Index Scan on idx_odata_page_run_id  (cost=0.00..4.29 rows=2 width=0)  
        Index Cond: ((skip_value > 6000) AND (request_id = 1))  
(4 rows)  
  
erp_staging_odata_test=#
```

5. Написать комментарии к каждому из индексов

6. Описать что и как делали, с какими проблемами столкнулись
- была проблема с индексом GIN на обычном текстовом поле, нужно было сначала преобразовать тект в вектор