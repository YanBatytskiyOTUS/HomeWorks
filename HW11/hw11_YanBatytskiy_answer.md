#postgresql #otus 
## Домашнее задание
Секционирование таблицы
Цель:
научиться выполнять секционирование таблиц в PostgreSQL;  
повысить производительность запросов и упростив управление данными;
Описание/Пошаговая инструкция выполнения домашнего задания:
На основе готовой базы данных примените один из методов секционирования в зависимости от структуры данных.  
[https://postgrespro.ru/education/demodb](https://postgrespro.ru/education/demodb "https://postgrespro.ru/education/demodb")  

**Шаги выполнения домашнего задания:**  
**Анализ структуры данных:**
- Ознакомьтесь с таблицами базы данных, особенно с таблицами bookings, tickets, ticket_flights, flights, boarding_passes, seats, airports, aircrafts.
- Определите, какие данные в таблице bookings или других таблицах имеют логическую привязку к диапазонам, по которым можно провести секционирование (например, дата бронирования, рейсы).

**Выбор таблицы для секционирования:**  
Основной акцент делается на секционировании таблицы bookings. Но вы можете выбрать и другие таблицы, если видите в этом смысл для оптимизации производительности (например, flights, boarding_passes).  
Обоснуйте свой выбор: почему именно эта таблица требует секционирования? Какой тип данных является ключевым для секционирования?  

Ответ:
На самом деле секционировать надо и booking и посадочные, потому что базовая привязка к датам у них одна и та же. 
С рейсами сложнее, потому что они имеют несколько видов дат, да еще в разных таймзонах и тут надо разбивать скорее всего не по датам а по каким-то спискам.
В любом случае, все, что накапливается по датам имеет смысл разбиения на куски по периодам.
Возьмем стандартно бронирования для тренировки по дате бронирования

**Определение типа секционирования:**  
Определитесь с типом секционирования, которое наилучшим образом подходит для ваших данных:
- По диапазону (например, по дате бронирования или дате рейса).
- По списку (например, по пунктам отправления или по номерам рейсов).
- По хэшированию (для равномерного распределения данных).  

Ответ:
Хэш нам нужен чтобы равномерно разбросать большой объем на части для решения по большей  части технических задач (ускорение пылесоса, обслуживания индекосов и т. д., нежели оптимизации логики запросов), тем более, что хэш по своей сути связан не с диапазонами значений, а с математическим вычислением ключа.

Списки в данном случае тоже не нужны, потому что здесь просто RANGE по датам.

Поэтому просто диапазон по годам и далее по месяцам.

**Создание секционированной таблицы:**  
Преобразуйте таблицу в секционированную с выбранным типом секционирования.  
Например, если вы выбрали секционирование по диапазону дат бронирования, создайте секции по месяцам или годам.  

1. выясняем существующий диапазон:
```sql
demo=# select min(bookings.book_date), max(bookings.book_date) from bookings;
              min              |              max              
-------------------------------+-------------------------------

 2025-09-01 00:00:06.265219+00 | 2027-08-31 23:59:58.579152+00
(1 row)

demo=#
```

```sql
-- создаем таблицу для копирования данных из основной таблицы, которая будет разбита на партиции по месяцам  
create table bookings.bookings_copy  
(  
    book_ref     char(6),  
    book_date    timestamp with time zone,  
    total_amount numeric(10, 2),  
  
    PRIMARY KEY (book_ref, book_date)  
)  
    partition by range (book_date);  
  
-- создаем default партицию верхнего уровня  
create table bookings.bookings_copy_default  
    partition of bookings.bookings_copy  
        default;  
  
-- функция для получения следующего месяца и года  
create or replace function bookings.make_next_month(  
    partition_year int, partition_month int,  
    OUT partition_next_year int, OUT partition_next_month int)  
AS  
$$  
BEGIN  
    partition_next_year = partition_year;  
    partition_next_month = partition_month + 1;  
    IF partition_next_month > 12 THEN  
        partition_next_month = 1;  
        partition_next_year = partition_next_year + 1;  
    END IF;  
END;  
$$ language plpgsql  
    IMMUTABLE;  
  
-- создаем партиции для каждого месяца, который есть в данных  
DO  
$$  
    DECLARE  
        current_year  int;  
        current_month int;  
        next_year     int;  
        next_month    int;  
        Query         text;  
    BEGIN  
        --внешний цикл по годам  
        FOR current_year  
            IN (SELECT DISTINCT EXTRACT(YEAR FROM book_date) AS year  
                FROM bookings.bookings  
                ORDER BY year)  
            LOOP  
  
                query = format(  
                        $frmt$  
                        CREATE TABLE bookings.bookings_copy_%s                        
                        PARTITION OF bookings.bookings_copy                        
                        FOR VALUES                        
                        FROM ('%s-01-01 00:00:00')                        
                        TO ('%s-01-01 00:00:00')                        
                        PARTITION BY RANGE (book_date);                        
                        $frmt$,  
                        current_year, current_year, current_year + 1  
                        );  
  
                RAISE NOTICE '%', query;  
                EXECUTE query;  
  
                --внутренний цикл по месяцам  
                FOR current_month  
                    IN  
                    SELECT DISTINCT EXTRACT(month FROM book_date) AS month  
                    FROM bookings.bookings  
                    WHERE EXTRACT(year FROM book_date) = current_year  
                    ORDER BY month  
                    LOOP                        SELECT partition_next_year, partition_next_month  
                        INTO next_year, next_month  
                        FROM bookings.make_next_month(current_year, current_month);  
                        query = format(  
                                $frmt$  
                        CREATE TABLE bookings.bookings_copy_%s_%s                        
                        PARTITION OF bookings.bookings_copy_%s                        
                        FOR VALUES                        
                        FROM ('%s-%s-01 00:00:00')                        
                        TO ('%s-%s-01 00:00:00');                        
                        $frmt$,  
                                current_year, current_month,  
                                current_year,  
                                current_year, lpad(current_month::text, 2, '0'),  
                                next_year, lpad(next_month::text, 2, '0')  
                                );  
                        RAISE NOTICE '%', query;  
                        EXECUTE query;  
                    END LOOP;  
  
                --создаем default партицию для текущего года  
                query = format(  
                        $frmt$  
                        CREATE TABLE bookings.bookings_copy_%s_default                        
                        PARTITION OF bookings.bookings_copy_%s                        
                        DEFAULT;                        
                        $frmt$,  
                        current_year,  
                        current_year  
                        );  
  
                RAISE NOTICE '%', query;  
                EXECUTE query;  
  
  
            END LOOP;  
    END;  
$$;
```

результат:
```bash

demo=# \d+ bookings.bookings_copy
                                           Partitioned table "bookings.bookings_copy"

    Column    |           Type           | Collation | Nullable | Default | Storage  | Compression | Stats target | Description 
--------------+--------------------------+-----------+----------+---------+----------+-------------+--------------+-------------
 book_ref     | character(6)             |           | not null |         | extended |             |              | 
 book_date    | timestamp with time zone |           | not null |         | plain    |             |              | 
 total_amount | numeric(10,2)            |           |          |         | main     |             |              | 

Partition key: RANGE (book_date)
Indexes:
    "bookings_copy_pkey" PRIMARY KEY, btree (book_ref, book_date)
Not-null constraints:
    "bookings_copy_book_ref_not_null" NOT NULL "book_ref"
    "bookings_copy_book_date_not_null" NOT NULL "book_date"
Partitions: bookings_copy_2025 FOR VALUES FROM ('2025-01-01 00:00:00+00') TO ('2026-01-01 00:00:00+00'), PARTITIONED,
            bookings_copy_2026 FOR VALUES FROM ('2026-01-01 00:00:00+00') TO ('2027-01-01 00:00:00+00'), PARTITIONED,
            bookings_copy_2027 FOR VALUES FROM ('2027-01-01 00:00:00+00') TO ('2028-01-01 00:00:00+00'), PARTITIONED,
            bookings_copy_default DEFAULT

demo=# SELECT * FROM pg_partition_tree('bookings.bookings_copy');
           relid            |    parentrelid     | isleaf | level 
----------------------------+--------------------+--------+-------
 bookings_copy              |                    | f      |     0
 bookings_copy_default      | bookings_copy      | t      |     1
 bookings_copy_2025         | bookings_copy      | f      |     1
 bookings_copy_2026         | bookings_copy      | f      |     1
 bookings_copy_2027         | bookings_copy      | f      |     1
 bookings_copy_2025_9       | bookings_copy_2025 | t      |     2
 bookings_copy_2025_10      | bookings_copy_2025 | t      |     2
 bookings_copy_2025_11      | bookings_copy_2025 | t      |     2
 bookings_copy_2025_12      | bookings_copy_2025 | t      |     2
 bookings_copy_2025_default | bookings_copy_2025 | t      |     2
 bookings_copy_2026_1       | bookings_copy_2026 | t      |     2
 bookings_copy_2026_2       | bookings_copy_2026 | t      |     2
 bookings_copy_2026_3       | bookings_copy_2026 | t      |     2
 bookings_copy_2026_4       | bookings_copy_2026 | t      |     2
 bookings_copy_2026_5       | bookings_copy_2026 | t      |     2
 bookings_copy_2026_6       | bookings_copy_2026 | t      |     2
 bookings_copy_2026_7       | bookings_copy_2026 | t      |     2
 bookings_copy_2026_8       | bookings_copy_2026 | t      |     2
 bookings_copy_2026_9       | bookings_copy_2026 | t      |     2
 bookings_copy_2026_10      | bookings_copy_2026 | t      |     2
 bookings_copy_2026_11      | bookings_copy_2026 | t      |     2
 bookings_copy_2026_12      | bookings_copy_2026 | t      |     2
 bookings_copy_2026_default | bookings_copy_2026 | t      |     2
 bookings_copy_2027_1       | bookings_copy_2027 | t      |     2
 bookings_copy_2027_2       | bookings_copy_2027 | t      |     2
 bookings_copy_2027_3       | bookings_copy_2027 | t      |     2
 bookings_copy_2027_4       | bookings_copy_2027 | t      |     2
 bookings_copy_2027_5       | bookings_copy_2027 | t      |     2
 bookings_copy_2027_6       | bookings_copy_2027 | t      |     2
 bookings_copy_2027_7       | bookings_copy_2027 | t      |     2
 bookings_copy_2027_8       | bookings_copy_2027 | t      |     2
 bookings_copy_2027_default | bookings_copy_2027 | t      |     2
(32 rows)
demo=#
```

**Миграция данных:**
- Перенесите существующие данные из исходной таблицы в секционированную структуру.
- Убедитесь, что все данные правильно распределены по секциям.
``` bash
demo=# INSERT INTO bookings.bookings_copy (book_ref, book_date, total_amount)
demo-# SELECT book_ref, book_date, total_amount
demo-# FROM bookings.bookings;
INSERT 0 9706657
demo=#
```

```bash
(  
  SELECT book_ref, book_date, total_amount FROM bookings.bookings  
  EXCEPT ALL  
  SELECT book_ref, book_date, total_amount FROM bookings.bookings_copy  
)  
UNION ALL  
(  
  SELECT book_ref, book_date, total_amount FROM bookings.bookings_copy  
  EXCEPT ALL  
  SELECT book_ref, book_date, total_amount FROM bookings.bookings  
);

вернуло 0
```

**Оптимизация запросов:**
- Проверьте, как секционирование влияет на производительность запросов. Выполните несколько выборок данных до и после секционирования для оценки времени выполнения.
```bash
demo=# explain
demo-# select * FROM
demo-#  bookings.bookings
demo-# WHERE book_date >= '2026-05-03' AND book_date < '2027-01-12';
                                                                     QUERY PLAN                                                                     
----------------------------------------------------------------------------------------------------------------------------------------------------
 Seq Scan on bookings  (cost=0.00..207471.85 rows=3323159 width=21)
   Filter: ((book_date >= '2026-05-03 00:00:00+00'::timestamp with time zone) AND (book_date < '2027-01-12 00:00:00+00'::timestamp with time zone))
 JIT:
   Functions: 2
   Options: Inlining false, Optimization false, Expressions true, Deforming true
(5 rows)

demo=# explain
demo-# select * FROM
demo-#  bookings.bookings_copy
demo-# WHERE book_date >= '2026-05-03' AND book_date < '2027-01-12';
                                                                        QUERY PLAN                                                                        
----------------------------------------------------------------------------------------------------------------------------------------------------------
 Append  (cost=0.00..94595.93 rows=3360903 width=21)
   ->  Seq Scan on bookings_copy_2026_5 bookings_copy_1  (cost=0.00..8539.94 rows=374488 width=21)
         Filter: ((book_date >= '2026-05-03 00:00:00+00'::timestamp with time zone) AND (book_date < '2027-01-12 00:00:00+00'::timestamp with time zone))
   ->  Seq Scan on bookings_copy_2026_6 bookings_copy_2  (cost=0.00..8617.56 rows=403156 width=21)
         Filter: ((book_date >= '2026-05-03 00:00:00+00'::timestamp with time zone) AND (book_date < '2027-01-12 00:00:00+00'::timestamp with time zone))
   ->  Seq Scan on bookings_copy_2026_7 bookings_copy_3  (cost=0.00..8791.88 rows=411310 width=21)
         Filter: ((book_date >= '2026-05-03 00:00:00+00'::timestamp with time zone) AND (book_date < '2027-01-12 00:00:00+00'::timestamp with time zone))
   ->  Seq Scan on bookings_copy_2026_8 bookings_copy_4  (cost=0.00..8815.68 rows=412429 width=21)
         Filter: ((book_date >= '2026-05-03 00:00:00+00'::timestamp with time zone) AND (book_date < '2027-01-12 00:00:00+00'::timestamp with time zone))
   ->  Seq Scan on bookings_copy_2026_9 bookings_copy_5  (cost=0.00..8496.24 rows=397469 width=21)
         Filter: ((book_date >= '2026-05-03 00:00:00+00'::timestamp with time zone) AND (book_date < '2027-01-12 00:00:00+00'::timestamp with time zone))
   ->  Seq Scan on bookings_copy_2026_10 bookings_copy_6  (cost=0.00..8806.02 rows=411986 width=21)
         Filter: ((book_date >= '2026-05-03 00:00:00+00'::timestamp with time zone) AND (book_date < '2027-01-12 00:00:00+00'::timestamp with time zone))
   ->  Seq Scan on bookings_copy_2026_11 bookings_copy_7  (cost=0.00..8371.98 rows=391654 width=21)
         Filter: ((book_date >= '2026-05-03 00:00:00+00'::timestamp with time zone) AND (book_date < '2027-01-12 00:00:00+00'::timestamp with time zone))
   ->  Seq Scan on bookings_copy_2026_12 bookings_copy_8  (cost=0.00..8731.30 rows=408471 width=21)
         Filter: ((book_date >= '2026-05-03 00:00:00+00'::timestamp with time zone) AND (book_date < '2027-01-12 00:00:00+00'::timestamp with time zone))
   ->  Seq Scan on bookings_copy_2027_1 bookings_copy_9  (cost=0.00..8620.83 rows=149940 width=21)
         Filter: ((book_date >= '2026-05-03 00:00:00+00'::timestamp with time zone) AND (book_date < '2027-01-12 00:00:00+00'::timestamp with time zone))
(19 rows)
demo=# explain
demo-# select * FROM
demo-#  bookings.bookings
demo-# WHERE book_date = '2026-05-03';
                                    QUERY PLAN                                    
----------------------------------------------------------------------------------
 Gather  (cost=1000.00..113427.61 rows=1 width=21)
   Workers Planned: 2
   ->  Parallel Seq Scan on bookings  (cost=0.00..112427.51 rows=1 width=21)
         Filter: (book_date = '2026-05-03 00:00:00+00'::timestamp with time zone)
 JIT:
   Functions: 2
   Options: Inlining false, Optimization false, Expressions true, Deforming true
(7 rows)

demo=# explain
demo-# select * FROM
demo-#  bookings.bookings_copy
demo-# WHERE book_date = '2026-05-03';
                                             QUERY PLAN                                              
-----------------------------------------------------------------------------------------------------
 Gather  (cost=1000.00..6484.31 rows=1 width=21)
   Workers Planned: 1
   ->  Parallel Seq Scan on bookings_copy_2026_5 bookings_copy  (cost=0.00..5484.21 rows=1 width=21)
         Filter: (book_date = '2026-05-03 00:00:00+00'::timestamp with time zone)
(4 rows)

demo=#
```

- Оптимизируйте запросы при необходимости (например, добавьте индексы на ключевые столбцы).
```bash
demo=# CREATE INDEX ON bookings.bookings_copy (book_date);
CREATE INDEX
demo=#
demo=# explain
demo-# select * FROM
demo-# bookings.bookings
demo-# WHERE book_date >= '2026-05-03' AND book_date < '2026-05-31';
                                                                        QUERY PLAN                                                                        
----------------------------------------------------------------------------------------------------------------------------------------------------------
 Gather  (cost=1000.00..156862.31 rows=333237 width=21)
   Workers Planned: 2
   ->  Parallel Seq Scan on bookings  (cost=0.00..122538.61 rows=138849 width=21)
         Filter: ((book_date >= '2026-05-03 00:00:00+00'::timestamp with time zone) AND (book_date < '2026-05-31 00:00:00+00'::timestamp with time zone))
 JIT:
   Functions: 2
   Options: Inlining false, Optimization false, Expressions true, Deforming true
(7 rows)

demo=# explain
demo-# select * FROM
demo-# bookings.bookings_copy
demo-# WHERE book_date >= '2026-05-03' AND book_date < '2026-05-31';
                                                                     QUERY PLAN                                                                     
----------------------------------------------------------------------------------------------------------------------------------------------------
 Seq Scan on bookings_copy_2026_5 bookings_copy  (cost=0.00..8539.94 rows=362325 width=21)
   Filter: ((book_date >= '2026-05-03 00:00:00+00'::timestamp with time zone) AND (book_date < '2026-05-31 00:00:00+00'::timestamp with time zone))
(2 rows)
demo=#

```

**Тестирование решения:**  
Протестируйте секционирование, выполняя несколько запросов к секционированной таблице.  
Проверьте, что операции вставки, обновления и удаления работают корректно.  
```bash
demo=# INSERT INTO bookings.bookings_copy (book_ref, book_date, total_amount)
demo-# VALUES
demo-# ('A12345', '2026-03-15 10:30:00+00', 150.00),
demo-# ('B54321', '2025-12-01 08:00:00+00', 220.50);
INSERT 0 2
demo=# UPDATE bookings.bookings_copy
demo-# SET total_amount = total_amount + 50
demo-# WHERE book_ref = 'A12345'
demo-#   AND book_date = '2026-03-15 10:30:00+00';
UPDATE 1
demo=# DELETE FROM bookings.bookings_copy
demo-# WHERE book_ref = 'B54321'
demo-#   AND book_date = '2025-12-01 08:00:00+00';
DELETE 1
demo=# select * from bookings.bookings_copy
demo-# where book_ref =  'A12345';

 book_ref |       book_date        | total_amount 
----------+------------------------+--------------
 A12345   | 2026-03-15 10:30:00+00 |       200.00
(1 row)

demo=#
```


**Документирование:**
- Добавьте комментарии к коду, поясняющие выбранный тип секционирования и шаги его реализации.
- Опишите, как секционирование улучшает производительность запросов и как оно может быть полезно в реальных условиях.

**Формат сдачи:**
- SQL-скрипты с реализованным секционированием.
- Краткий отчет с описанием процесса и результатами тестирования.
- Пример запросов и результаты до и после секционирования.

Критерии оценки:
Корректность секционирования – таблица должна быть разделена логично и эффективно.  
Выбор типа секционирования – обоснование выбранного типа (например, секционирование по диапазону дат рейсов или по месту отправления/прибытия).  
Работоспособность решения – код должен успешно выполнять секционирование без ошибок.  
Оптимизация запросов – после секционирования, запросы к таблице должны быть оптимизированы (например, быстрее выполняться для конкретных диапазонов).  
Комментирование – код должен содержать поясняющие комментарии, объясняющие выбор секционирования и основные шаги.