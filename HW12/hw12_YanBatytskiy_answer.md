#postgresql #otus 
## Домашнее задание
Триггеры, поддержка заполнения витрин
Цель:
создать триггер для поддержки витрины данных в актуальном состоянии;
Описание/Пошаговая инструкция выполнения домашнего задания:
Скрипт и развернутое описание задачи – в ЛК (файл hw_triggers.sql) или по ссылке: [https://disk.yandex.ru/d/l70AvknAepIJXQ](https://disk.yandex.ru/d/l70AvknAepIJXQ "https://disk.yandex.ru/d/l70AvknAepIJXQ")
В БД создана структура, описывающая товары (таблица goods) и продажи (таблица sales).
Есть запрос для генерации отчета – сумма продаж по каждому товару.
БД была денормализована, создана таблица (витрина), структура которой повторяет структуру отчета.
Создать триггер на таблице продаж, для поддержки данных в витрине в актуальном состоянии (вычисляющий при каждой продаже сумму и записывающий её в витрину)
Подсказка: не забыть, что кроме INSERT есть еще UPDATE и DELETE

Ответ:
1. На мой взгляд в таблице good_sum_mart не хватает поля good_id либо уникального индекса на good_name. На данный момент таблица позволяет вставить несколько строк с одинаковым названием товара. Добавил good_id.
2. Обработана вставка продажи нового товара, продажи уже ранее проданного товара
3. Обработано изменение названия товара в существующей продаже, изменение количества в существующей продаже, при обнулении суммы продаж строка удаляется.
4. Обработано удаление продаж, при обнулении суммы продаж строка также удаляется.

### далее листинг работы потоком:
```bash
otus=# DROP SCHEMA IF EXISTS pract_functions CASCADE;  
NOTICE:  drop cascades to 4 other objects  
DETAIL:  drop cascades to table goods  
drop cascades to table sales  
drop cascades to table good_sum_mart  
drop cascades to function update_good_sum_mart()  
DROP SCHEMA  
otus=# CREATE SCHEMA pract_functions;  
CREATE SCHEMA  
otus=#    
otus=# SET search_path = pract_functions, public;  
SET  
otus=# -- goods  
CREATE TABLE IF NOT EXISTS goods  
(  
   goods_id   integer PRIMARY KEY,  
   good_name  varchar(63)    NOT NULL,  
   good_price numeric(10, 2) NOT NULL CHECK (good_price > 0.0)  
);  
CREATE TABLE  
otus=# INSERT INTO goods (goods_id, good_name, good_price)  
VALUES (1, 'Спички хозяйственные', .50),  
      (2, 'Автомобиль Ferrari FXX K', 18500000.01);  
  
INSERT INTO goods (goods_id, good_name, good_price)  
VALUES (3, 'Мотоцикл Harley', 8);  
INSERT 0 2  
INSERT 0 1  
otus=# -- sells  
CREATE TABLE IF NOT EXISTS sales  
(  
   sales_id   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,  
   good_id    integer REFERENCES goods (goods_id),  
   sales_time timestamp with time zone DEFAULT now(),  
   sales_qty  integer CHECK (sales_qty > 0)  
);  
CREATE TABLE  
otus=# -- denormalization  
CREATE TABLE IF NOT EXISTS good_sum_mart  
(  
   good_id integer NOT NULL UNIQUE REFERENCES goods (goods_id),  
   good_name varchar(63)    NOT NULL,  
   sum_sale  numeric(16, 2) NOT NULL  
);  
CREATE TABLE  
otus=# SELECT * FROM goods;  
goods_id |        good_name         | good_price     
----------+--------------------------+-------------  
       1 | Спички хозяйственные     |        0.50  
       2 | Автомобиль Ferrari FXX K | 18500000.01  
       3 | Мотоцикл Harley          |        8.00  
(3 rows)  
  
otus=# SELECT * FROM goods;  
goods_id |        good_name         | good_price     
----------+--------------------------+-------------  
       1 | Спички хозяйственные     |        0.50  
       2 | Автомобиль Ferrari FXX K | 18500000.01  
       3 | Мотоцикл Harley          |        8.00  
(3 rows)  
  
otus=# SELECT * FROM goods;  
goods_id |        good_name         | good_price     
----------+--------------------------+-------------  
       1 | Спички хозяйственные     |        0.50  
       2 | Автомобиль Ferrari FXX K | 18500000.01  
       3 | Мотоцикл Harley          |        8.00  
(3 rows)  
  
otus=# -- создаем функцию  
CREATE OR REPLACE FUNCTION update_good_sum_mart()  
   RETURNS trigger  
AS  
$$  
BEGIN  
   CASE TG_OP  
       WHEN 'INSERT' THEN  
           WITH price AS (  
               SELECT good_name, good_price FROM goods  
                                 WHERE goods.goods_id = NEW.good_id  
               )  
           INSERT INTO good_sum_mart(good_id, good_name, sum_sale)  
           SELECT NEW.good_id, price.good_name,  
                  NEW.sales_qty * price.good_price  
           FROM price  
           ON CONFLICT (good_id)  
           DO UPDATE SET sum_sale = good_sum_mart.sum_sale +  
                                EXCLUDED.sum_sale;  
           RETURN NULL;  
       WHEN 'UPDATE' THEN  
           -- изменился сам товар  
           IF OLD.good_id != NEW.good_id THEN  
               WITH old_good AS (  
                   SELECT good_name, good_price FROM goods  
                   WHERE goods.goods_id = OLD.good_id  
               ),  
               new_good AS (  
                   SELECT good_name, good_price FROM goods  
                   WHERE goods.goods_id = NEW.good_id  
               ),  
               -- вставляем новый товар по аналогии с INSERT  
               ins_new AS (  
                   INSERT INTO good_sum_mart (good_id, good_name, sum_sale)  
                       SElECT NEW.good_id,  
                              new_good.good_name,  
                              NEW.sales_qty * new_good.good_price  
                       FROM new_good  
                       ON CONFLICT (good_id)  
                           DO UPDATE SET sum_sale = good_sum_mart.sum_sale +  
                                                    EXCLUDED.sum_sale  
               )  
               -- обновляем старый товар  
               UPDATE good_sum_mart SET sum_sale =  
               sum_sale - OLD.sales_qty* old_good.good_price  
               FROM old_good  
               WHERE good_sum_mart.good_id = OLD.good_id;  
          ELSE  
              -- изменилось количество  
               WITH price AS (  
                   SELECT good_price FROM goods  
                                     WHERE goods.goods_id = NEW.good_id  
               )  
               UPDATE good_sum_mart G SET sum_sale =  
                   sum_sale + (NEW.sales_qty - OLD.sales_qty) *  
                   price.good_price  
               FROM price  
               WHERE good_id = NEW.good_id;  
           END IF;  
           IF (SELECT sum_sale FROM good_sum_mart WHERE good_id = OLD  
               .good_id) <= 0 THEN  
               DELETE FROM good_sum_mart WHERE good_id = OLD.good_id;  
           END IF;  
  
           RETURN NULL;  
       WHEN 'DELETE' THEN  
           WITH price AS (  
               SELECT good_price FROM goods  
                                 WHERE goods.goods_id = OLD.good_id  
           )  
           UPDATE good_sum_mart G SET sum_sale =  
               sum_sale - OLD.sales_qty * price.good_price  
           FROM price  
           WHERE good_id = OLD.good_id;  
           IF (SELECT sum_sale FROM good_sum_mart WHERE good_id = OLD  
               .good_id) <= 0 THEN  
               DELETE FROM good_sum_mart WHERE good_id = OLD.good_id;  
           END IF;  
           RETURN NULL;  
       END CASE;  
END;  
$$  
LANGUAGE  plpgsql;  
CREATE FUNCTION  
otus=# --создаем триггер  
CREATE OR REPLACE TRIGGER trg_edit_sales  
   AFTER INSERT OR UPDATE or DELETE ON pract_functions.sales  
   FOR EACH ROW  
   EXECUTE FUNCTION update_good_sum_mart();  
CREATE TRIGGER  
otus=# -- проверяем обычную вставку новых продаж  
INSERT INTO sales (good_id, sales_qty)  
VALUES (1, 10);  
  
INSERT INTO sales (good_id, sales_qty)  
VALUES (1, 120);  
  
INSERT INTO sales (good_id, sales_qty)  
VALUES (2, 1);  
INSERT 0 1  
INSERT 0 1  
INSERT 0 1  
otus=# SELECT G.goods_id, G.good_name, G.good_price, S.sales_qty, S.sales_id FROM  
   pract_functions.sales S  
       INNER JOIN pract_functions.goods G ON S.good_id = G.goods_id  
ORDER BY G.good_name, S.sales_id;  
goods_id |        good_name         | good_price  | sales_qty | sales_id    
----------+--------------------------+-------------+-----------+----------  
       2 | Автомобиль Ferrari FXX K | 18500000.01 |         1 |        3  
       1 | Спички хозяйственные     |        0.50 |        10 |        1  
       1 | Спички хозяйственные     |        0.50 |       120 |        2  
(3 rows)  
  
otus=# WITH sum_qty AS (SELECT good_id, sum(sales.sales_qty) quantity  
                FROM sales  
                GROUP BY good_id  
)  
SELECT SM.good_id, SM.good_name, G.good_price, SQ.quantity, SM  
   .sum_sale FROM  
   pract_functions.good_sum_mart SM  
       INNER JOIN pract_functions.goods G ON SM.good_id = G.goods_id  
       INNER JOIN sum_qty SQ ON SM.good_id = SQ.good_id  
ORDER BY SM.good_name;  
good_id |        good_name         | good_price  | quantity |  sum_sale      
---------+--------------------------+-------------+----------+-------------  
      2 | Автомобиль Ferrari FXX K | 18500000.01 |        1 | 18500000.01  
      1 | Спички хозяйственные     |        0.50 |      130 |       65.00  
(2 rows)  
  
otus=# -- проверяем вставку товара, который ранее не продавали  
INSERT INTO sales (good_id, sales_qty)  
VALUES (3, 5);  
INSERT 0 1  
otus=# SELECT G.goods_id, G.good_name, G.good_price, S.sales_qty, S.sales_id FROM  
   pract_functions.sales S  
       INNER JOIN pract_functions.goods G ON S.good_id = G.goods_id  
ORDER BY G.good_name, S.sales_id;  
goods_id |        good_name         | good_price  | sales_qty | sales_id    
----------+--------------------------+-------------+-----------+----------  
       2 | Автомобиль Ferrari FXX K | 18500000.01 |         1 |        3  
       3 | Мотоцикл Harley          |        8.00 |         5 |        4  
       1 | Спички хозяйственные     |        0.50 |        10 |        1  
       1 | Спички хозяйственные     |        0.50 |       120 |        2  
(4 rows)  
  
otus=# WITH sum_qty AS (SELECT good_id, sum(sales.sales_qty) quantity  
                FROM sales  
                GROUP BY good_id  
)  
SELECT SM.good_id, SM.good_name, G.good_price, SQ.quantity, SM  
   .sum_sale FROM  
   pract_functions.good_sum_mart SM  
INNER JOIN pract_functions.goods G ON SM.good_id = G.goods_id  
INNER JOIN sum_qty SQ ON SM.good_id = SQ.good_id  
ORDER BY SM.good_name;  
good_id |        good_name         | good_price  | quantity |  sum_sale      
---------+--------------------------+-------------+----------+-------------  
      2 | Автомобиль Ferrari FXX K | 18500000.01 |        1 | 18500000.01  
      3 | Мотоцикл Harley          |        8.00 |        5 |       40.00  
      1 | Спички хозяйственные     |        0.50 |      130 |       65.00  
(3 rows)  
  
otus=# -- проверяем вставку продажи товара, который уже продавали ранее  
INSERT INTO sales (good_id, sales_qty)  
VALUES (3, 2);  
INSERT 0 1  
otus=# SELECT G.goods_id, G.good_name, G.good_price, S.sales_qty, S.sales_id FROM  
   pract_functions.sales S  
       INNER JOIN pract_functions.goods G ON S.good_id = G.goods_id  
ORDER BY G.good_name, S.sales_id;  
goods_id |        good_name         | good_price  | sales_qty | sales_id    
----------+--------------------------+-------------+-----------+----------  
       2 | Автомобиль Ferrari FXX K | 18500000.01 |         1 |        3  
       3 | Мотоцикл Harley          |        8.00 |         5 |        4  
       3 | Мотоцикл Harley          |        8.00 |         2 |        5  
       1 | Спички хозяйственные     |        0.50 |        10 |        1  
       1 | Спички хозяйственные     |        0.50 |       120 |        2  
(5 rows)  
  
otus=# WITH sum_qty AS (SELECT good_id, sum(sales.sales_qty) quantity  
                FROM sales  
                GROUP BY good_id  
)  
SELECT SM.good_id, SM.good_name, G.good_price, SQ.quantity, SM  
   .sum_sale FROM  
   pract_functions.good_sum_mart SM  
       INNER JOIN pract_functions.goods G ON SM.good_id = G.goods_id  
       INNER JOIN sum_qty SQ ON SM.good_id = SQ.good_id  
ORDER BY SM.good_name;  
good_id |        good_name         | good_price  | quantity |  sum_sale      
---------+--------------------------+-------------+----------+-------------  
      2 | Автомобиль Ferrari FXX K | 18500000.01 |        1 | 18500000.01  
      3 | Мотоцикл Harley          |        8.00 |        7 |       56.00  
      1 | Спички хозяйственные     |        0.50 |      130 |       65.00  
(3 rows)  
  
otus=# -- проверяем изменение названия проданного товара  
UPDATE sales SET good_id = 3 WHERE sales_id = 3;  
UPDATE 1  
otus=# SELECT G.goods_id, G.good_name, G.good_price, S.sales_qty, S.sales_id FROM  
   pract_functions.sales S  
       INNER JOIN pract_functions.goods G ON S.good_id = G.goods_id  
ORDER BY G.good_name, S.sales_id;  
goods_id |      good_name       | good_price | sales_qty | sales_id    
----------+----------------------+------------+-----------+----------  
       3 | Мотоцикл Harley      |       8.00 |         1 |        3  
       3 | Мотоцикл Harley      |       8.00 |         5 |        4  
       3 | Мотоцикл Harley      |       8.00 |         2 |        5  
       1 | Спички хозяйственные |       0.50 |        10 |        1  
       1 | Спички хозяйственные |       0.50 |       120 |        2  
(5 rows)  
  
otus=# WITH sum_qty AS (SELECT good_id, sum(sales.sales_qty) quantity  
                FROM sales  
                GROUP BY good_id  
)  
SELECT SM.good_id, SM.good_name, G.good_price, SQ.quantity, SM  
   .sum_sale FROM  
   pract_functions.good_sum_mart SM  
       INNER JOIN pract_functions.goods G ON SM.good_id = G.goods_id  
       INNER JOIN sum_qty SQ ON SM.good_id = SQ.good_id  
ORDER BY SM.good_name;  
good_id |      good_name       | good_price | quantity | sum_sale    
---------+----------------------+------------+----------+----------  
      3 | Мотоцикл Harley      |       8.00 |        8 |    64.00  
      1 | Спички хозяйственные |       0.50 |      130 |    65.00  
(2 rows)  
  
otus=# -- проверяем изменение количества проданного товара  
UPDATE sales SET sales_qty = 6 WHERE sales_id = 4;  
UPDATE 1  
otus=# SELECT G.goods_id, G.good_name, G.good_price, S.sales_qty, S.sales_id FROM  
   pract_functions.sales S  
       INNER JOIN pract_functions.goods G ON S.good_id = G.goods_id  
ORDER BY G.good_name, S.sales_id;  
goods_id |      good_name       | good_price | sales_qty | sales_id    
----------+----------------------+------------+-----------+----------  
       3 | Мотоцикл Harley      |       8.00 |         1 |        3  
       3 | Мотоцикл Harley      |       8.00 |         6 |        4  
       3 | Мотоцикл Harley      |       8.00 |         2 |        5  
       1 | Спички хозяйственные |       0.50 |        10 |        1  
       1 | Спички хозяйственные |       0.50 |       120 |        2  
(5 rows)  
  
otus=# WITH sum_qty AS (SELECT good_id, sum(sales.sales_qty) quantity  
                FROM sales  
                GROUP BY good_id  
)  
SELECT SM.good_id, SM.good_name, G.good_price, SQ.quantity, SM  
   .sum_sale FROM  
   pract_functions.good_sum_mart SM  
       INNER JOIN pract_functions.goods G ON SM.good_id = G.goods_id  
       INNER JOIN sum_qty SQ ON SM.good_id = SQ.good_id  
ORDER BY SM.good_name;  
good_id |      good_name       | good_price | quantity | sum_sale    
---------+----------------------+------------+----------+----------  
      3 | Мотоцикл Harley      |       8.00 |        9 |    72.00  
      1 | Спички хозяйственные |       0.50 |      130 |    65.00  
(2 rows)  
  
otus=# -- проверяем удаление конкретной продажи  
DELETE FROM sales WHERE sales_id = 4 OR sales_id = 3;  
DELETE 2  
otus=# SELECT G.goods_id, G.good_name, G.good_price, S.sales_qty, S.sales_id FROM  
   pract_functions.sales S  
       INNER JOIN pract_functions.goods G ON S.good_id = G.goods_id  
ORDER BY G.good_name, S.sales_id;  
goods_id |      good_name       | good_price | sales_qty | sales_id    
----------+----------------------+------------+-----------+----------  
       3 | Мотоцикл Harley      |       8.00 |         2 |        5  
       1 | Спички хозяйственные |       0.50 |        10 |        1  
       1 | Спички хозяйственные |       0.50 |       120 |        2  
(3 rows)  
  
otus=# WITH sum_qty AS (SELECT good_id, sum(sales.sales_qty) quantity  
                FROM sales  
                GROUP BY good_id  
)  
SELECT SM.good_id, SM.good_name, G.good_price, SQ.quantity, SM  
   .sum_sale FROM  
   pract_functions.good_sum_mart SM  
       INNER JOIN pract_functions.goods G ON SM.good_id = G.goods_id  
       INNER JOIN sum_qty SQ ON SM.good_id = SQ.good_id  
ORDER BY SM.good_name;  
good_id |      good_name       | good_price | quantity | sum_sale    
---------+----------------------+------------+----------+----------  
      3 | Мотоцикл Harley      |       8.00 |        2 |    16.00  
      1 | Спички хозяйственные |       0.50 |      130 |    65.00  
(2 rows)  
  
otus=#
```

## отдельно код:
```sql
DROP SCHEMA IF EXISTS pract_functions CASCADE;  
CREATE SCHEMA pract_functions;  
  
SET search_path = pract_functions, public;  
  
-- goods  
CREATE TABLE IF NOT EXISTS goods  
(  
    goods_id   integer PRIMARY KEY,  
    good_name  varchar(63)    NOT NULL,  
    good_price numeric(10, 2) NOT NULL CHECK (good_price > 0.0)  
);  
  
INSERT INTO goods (goods_id, good_name, good_price)  
VALUES (1, 'Спички хозяйственные', .50),  
       (2, 'Автомобиль Ferrari FXX K', 18500000.01);  
  
INSERT INTO goods (goods_id, good_name, good_price)  
VALUES (3, 'Мотоцикл Harley', 8);  
  
-- sells  
CREATE TABLE IF NOT EXISTS sales  
(  
    sales_id   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,  
    good_id    integer REFERENCES goods (goods_id),  
    sales_time timestamp with time zone DEFAULT now(),  
    sales_qty  integer CHECK (sales_qty > 0)  
);  
  
-- denormalization  
CREATE TABLE IF NOT EXISTS good_sum_mart  
(  
    good_id integer NOT NULL UNIQUE REFERENCES goods (goods_id),  
    good_name varchar(63)    NOT NULL,  
    sum_sale  numeric(16, 2) NOT NULL  
);  
  
SELECT * FROM goods;  
  
SELECT * FROM sales;  
  
SELECT * FROM good_sum_mart;  
  
-- создаем функцию  
CREATE OR REPLACE FUNCTION update_good_sum_mart()  
    RETURNS trigger  
AS  
$$  
BEGIN  
    CASE TG_OP  
        WHEN 'INSERT' THEN  
            WITH price AS (  
                SELECT good_name, good_price FROM goods  
                                  WHERE goods.goods_id = NEW.good_id  
                )  
            INSERT INTO good_sum_mart(good_id, good_name, sum_sale)  
            SELECT NEW.good_id, price.good_name,  
                   NEW.sales_qty * price.good_price  
            FROM price  
            ON CONFLICT (good_id)  
            DO UPDATE SET sum_sale = good_sum_mart.sum_sale +  
                                 EXCLUDED.sum_sale;  
            RETURN NULL;  
        WHEN 'UPDATE' THEN  
            -- изменился сам товар  
            IF OLD.good_id != NEW.good_id THEN  
                WITH old_good AS (  
                    SELECT good_name, good_price FROM goods  
                    WHERE goods.goods_id = OLD.good_id  
                ),  
                new_good AS (  
                    SELECT good_name, good_price FROM goods  
                    WHERE goods.goods_id = NEW.good_id  
                ),  
                -- вставляем новый товар по аналогии с INSERT  
                ins_new AS (  
                    INSERT INTO good_sum_mart (good_id, good_name, sum_sale)  
                        SElECT NEW.good_id,  
                               new_good.good_name,  
                               NEW.sales_qty * new_good.good_price  
                        FROM new_good  
                        ON CONFLICT (good_id)  
                            DO UPDATE SET sum_sale = good_sum_mart.sum_sale +  
                                                     EXCLUDED.sum_sale  
                )  
                -- обновляем старый товар  
                UPDATE good_sum_mart SET sum_sale =  
                sum_sale - OLD.sales_qty* old_good.good_price  
                FROM old_good  
                WHERE good_sum_mart.good_id = OLD.good_id;  
           ELSE  
               -- изменилось количество  
                WITH price AS (  
                    SELECT good_price FROM goods  
                                      WHERE goods.goods_id = NEW.good_id  
                )  
                UPDATE good_sum_mart G SET sum_sale =  
                    sum_sale + (NEW.sales_qty - OLD.sales_qty) *  
                    price.good_price  
                FROM price  
                WHERE good_id = NEW.good_id;  
            END IF;  
            IF (SELECT sum_sale FROM good_sum_mart WHERE good_id = OLD  
                .good_id) <= 0 THEN  
                DELETE FROM good_sum_mart WHERE good_id = OLD.good_id;  
            END IF;  
  
            RETURN NULL;  
        WHEN 'DELETE' THEN  
            WITH price AS (  
                SELECT good_price FROM goods  
                                  WHERE goods.goods_id = OLD.good_id  
            )  
            UPDATE good_sum_mart G SET sum_sale =  
                sum_sale - OLD.sales_qty * price.good_price  
            FROM price  
            WHERE good_id = OLD.good_id;  
            IF (SELECT sum_sale FROM good_sum_mart WHERE good_id = OLD  
                .good_id) <= 0 THEN  
                DELETE FROM good_sum_mart WHERE good_id = OLD.good_id;  
            END IF;  
            RETURN NULL;  
        END CASE;  
END;  
$$  
LANGUAGE  plpgsql;  
  
--создаем триггер  
CREATE OR REPLACE TRIGGER trg_edit_sales  
    AFTER INSERT OR UPDATE or DELETE ON pract_functions.sales  
    FOR EACH ROW  
    EXECUTE FUNCTION update_good_sum_mart();  
  
-- проверяем обычную вставку новых продаж  
INSERT INTO sales (good_id, sales_qty)  
VALUES (1, 10);  
  
INSERT INTO sales (good_id, sales_qty)  
VALUES (1, 120);  
  
INSERT INTO sales (good_id, sales_qty)  
VALUES (2, 1);  
  
SELECT G.goods_id, G.good_name, G.good_price, S.sales_qty, S.sales_id FROM  
    pract_functions.sales S  
        INNER JOIN pract_functions.goods G ON S.good_id = G.goods_id  
ORDER BY G.good_name, S.sales_id;  
  
WITH sum_qty AS (SELECT good_id, sum(sales.sales_qty) quantity  
                 FROM sales  
                 GROUP BY good_id  
)  
SELECT SM.good_id, SM.good_name, G.good_price, SQ.quantity, SM  
    .sum_sale FROM  
    pract_functions.good_sum_mart SM  
        INNER JOIN pract_functions.goods G ON SM.good_id = G.goods_id  
        INNER JOIN sum_qty SQ ON SM.good_id = SQ.good_id  
ORDER BY SM.good_name;  
  
-- проверяем вставку товара, который ранее не продавали  
INSERT INTO sales (good_id, sales_qty)  
VALUES (3, 5);  
  
SELECT G.goods_id, G.good_name, G.good_price, S.sales_qty, S.sales_id FROM  
    pract_functions.sales S  
        INNER JOIN pract_functions.goods G ON S.good_id = G.goods_id  
ORDER BY G.good_name, S.sales_id;  
  
  
WITH sum_qty AS (SELECT good_id, sum(sales.sales_qty) quantity  
                 FROM sales  
                 GROUP BY good_id  
)  
SELECT SM.good_id, SM.good_name, G.good_price, SQ.quantity, SM  
    .sum_sale FROM  
    pract_functions.good_sum_mart SM  
INNER JOIN pract_functions.goods G ON SM.good_id = G.goods_id  
INNER JOIN sum_qty SQ ON SM.good_id = SQ.good_id  
ORDER BY SM.good_name;  
  
-- проверяем вставку продажи товара, который уже продавали ранее  
INSERT INTO sales (good_id, sales_qty)  
VALUES (3, 2);  
  
SELECT G.goods_id, G.good_name, G.good_price, S.sales_qty, S.sales_id FROM  
    pract_functions.sales S  
        INNER JOIN pract_functions.goods G ON S.good_id = G.goods_id  
ORDER BY G.good_name, S.sales_id;  
  
WITH sum_qty AS (SELECT good_id, sum(sales.sales_qty) quantity  
                 FROM sales  
                 GROUP BY good_id  
)  
SELECT SM.good_id, SM.good_name, G.good_price, SQ.quantity, SM  
    .sum_sale FROM  
    pract_functions.good_sum_mart SM  
        INNER JOIN pract_functions.goods G ON SM.good_id = G.goods_id  
        INNER JOIN sum_qty SQ ON SM.good_id = SQ.good_id  
ORDER BY SM.good_name;  
  
-- проверяем изменение названия проданного товара  
UPDATE sales SET good_id = 3 WHERE sales_id = 3;  
  
SELECT G.goods_id, G.good_name, G.good_price, S.sales_qty, S.sales_id FROM  
    pract_functions.sales S  
        INNER JOIN pract_functions.goods G ON S.good_id = G.goods_id  
ORDER BY G.good_name, S.sales_id;  
  
WITH sum_qty AS (SELECT good_id, sum(sales.sales_qty) quantity  
                 FROM sales  
                 GROUP BY good_id  
)  
SELECT SM.good_id, SM.good_name, G.good_price, SQ.quantity, SM  
    .sum_sale FROM  
    pract_functions.good_sum_mart SM  
        INNER JOIN pract_functions.goods G ON SM.good_id = G.goods_id  
        INNER JOIN sum_qty SQ ON SM.good_id = SQ.good_id  
ORDER BY SM.good_name;  
  
  
-- проверяем изменение количества проданного товара  
UPDATE sales SET sales_qty = 6 WHERE sales_id = 4;  
  
SELECT G.goods_id, G.good_name, G.good_price, S.sales_qty, S.sales_id FROM  
    pract_functions.sales S  
        INNER JOIN pract_functions.goods G ON S.good_id = G.goods_id  
ORDER BY G.good_name, S.sales_id;  
  
WITH sum_qty AS (SELECT good_id, sum(sales.sales_qty) quantity  
                 FROM sales  
                 GROUP BY good_id  
)  
SELECT SM.good_id, SM.good_name, G.good_price, SQ.quantity, SM  
    .sum_sale FROM  
    pract_functions.good_sum_mart SM  
        INNER JOIN pract_functions.goods G ON SM.good_id = G.goods_id  
        INNER JOIN sum_qty SQ ON SM.good_id = SQ.good_id  
ORDER BY SM.good_name;  
  
-- проверяем удаление конкретной продажи  
DELETE FROM sales WHERE sales_id = 4 OR sales_id = 3;  
  
SELECT G.goods_id, G.good_name, G.good_price, S.sales_qty, S.sales_id FROM  
    pract_functions.sales S  
        INNER JOIN pract_functions.goods G ON S.good_id = G.goods_id  
ORDER BY G.good_name, S.sales_id;  
  
WITH sum_qty AS (SELECT good_id, sum(sales.sales_qty) quantity  
                 FROM sales  
                 GROUP BY good_id  
)  
SELECT SM.good_id, SM.good_name, G.good_price, SQ.quantity, SM  
    .sum_sale FROM  
    pract_functions.good_sum_mart SM  
        INNER JOIN pract_functions.goods G ON SM.good_id = G.goods_id  
        INNER JOIN sum_qty SQ ON SM.good_id = SQ.good_id  
ORDER BY SM.good_name;
```

### отдельно вывод:
```bash
NOTICE:  drop cascades to 4 other objects  
DETAIL:  drop cascades to table goods  
drop cascades to table sales  
drop cascades to table good_sum_mart  
drop cascades to function update_good_sum_mart()  
DROP SCHEMA  
CREATE SCHEMA  
SET  
CREATE TABLE  
INSERT 0 2  
INSERT 0 1  
CREATE TABLE  
CREATE TABLE  
goods_id |        good_name         | good_price     
----------+--------------------------+-------------  
       1 | Спички хозяйственные     |        0.50  
       2 | Автомобиль Ferrari FXX K | 18500000.01  
       3 | Мотоцикл Harley          |        8.00  
(3 rows)  
  
sales_id | good_id | sales_time | sales_qty    
----------+---------+------------+-----------  
(0 rows)  
  
good_id | good_name | sum_sale    
---------+-----------+----------  
(0 rows)  
  
CREATE FUNCTION  
CREATE TRIGGER  
INSERT 0 1  
INSERT 0 1  
INSERT 0 1  
goods_id |        good_name         | good_price  | sales_qty | sales_id    
----------+--------------------------+-------------+-----------+----------  
       2 | Автомобиль Ferrari FXX K | 18500000.01 |         1 |        3  
       1 | Спички хозяйственные     |        0.50 |        10 |        1  
       1 | Спички хозяйственные     |        0.50 |       120 |        2  
(3 rows)  
  
good_id |        good_name         | good_price  | quantity |  sum_sale      
---------+--------------------------+-------------+----------+-------------  
      2 | Автомобиль Ferrari FXX K | 18500000.01 |        1 | 18500000.01  
      1 | Спички хозяйственные     |        0.50 |      130 |       65.00  
(2 rows)  
  
INSERT 0 1  
goods_id |        good_name         | good_price  | sales_qty | sales_id    
----------+--------------------------+-------------+-----------+----------  
       2 | Автомобиль Ferrari FXX K | 18500000.01 |         1 |        3  
       3 | Мотоцикл Harley          |        8.00 |         5 |        4  
       1 | Спички хозяйственные     |        0.50 |        10 |        1  
       1 | Спички хозяйственные     |        0.50 |       120 |        2  
(4 rows)  
  
good_id |        good_name         | good_price  | quantity |  sum_sale      
---------+--------------------------+-------------+----------+-------------  
      2 | Автомобиль Ferrari FXX K | 18500000.01 |        1 | 18500000.01  
      3 | Мотоцикл Harley          |        8.00 |        5 |       40.00  
      1 | Спички хозяйственные     |        0.50 |      130 |       65.00  
(3 rows)  
  
INSERT 0 1  
goods_id |        good_name         | good_price  | sales_qty | sales_id    
----------+--------------------------+-------------+-----------+----------  
       2 | Автомобиль Ferrari FXX K | 18500000.01 |         1 |        3  
       3 | Мотоцикл Harley          |        8.00 |         5 |        4  
       3 | Мотоцикл Harley          |        8.00 |         2 |        5  
       1 | Спички хозяйственные     |        0.50 |        10 |        1  
       1 | Спички хозяйственные     |        0.50 |       120 |        2  
(5 rows)  
  
good_id |        good_name         | good_price  | quantity |  sum_sale      
---------+--------------------------+-------------+----------+-------------  
      2 | Автомобиль Ferrari FXX K | 18500000.01 |        1 | 18500000.01  
      3 | Мотоцикл Harley          |        8.00 |        7 |       56.00  
      1 | Спички хозяйственные     |        0.50 |      130 |       65.00  
(3 rows)  
  
UPDATE 1  
goods_id |      good_name       | good_price | sales_qty | sales_id    
----------+----------------------+------------+-----------+----------  
       3 | Мотоцикл Harley      |       8.00 |         1 |        3  
       3 | Мотоцикл Harley      |       8.00 |         5 |        4  
       3 | Мотоцикл Harley      |       8.00 |         2 |        5  
       1 | Спички хозяйственные |       0.50 |        10 |        1  
       1 | Спички хозяйственные |       0.50 |       120 |        2  
(5 rows)  
  
good_id |      good_name       | good_price | quantity | sum_sale    
---------+----------------------+------------+----------+----------  
      3 | Мотоцикл Harley      |       8.00 |        8 |    64.00  
      1 | Спички хозяйственные |       0.50 |      130 |    65.00  
(2 rows)  
  
UPDATE 1  
goods_id |      good_name       | good_price | sales_qty | sales_id    
----------+----------------------+------------+-----------+----------  
       3 | Мотоцикл Harley      |       8.00 |         1 |        3  
       3 | Мотоцикл Harley      |       8.00 |         6 |        4  
       3 | Мотоцикл Harley      |       8.00 |         2 |        5  
       1 | Спички хозяйственные |       0.50 |        10 |        1  
       1 | Спички хозяйственные |       0.50 |       120 |        2  
(5 rows)  
  
good_id |      good_name       | good_price | quantity | sum_sale    
---------+----------------------+------------+----------+----------  
      3 | Мотоцикл Harley      |       8.00 |        9 |    72.00  
      1 | Спички хозяйственные |       0.50 |      130 |    65.00  
(2 rows)  
  
DELETE 2  
goods_id |      good_name       | good_price | sales_qty | sales_id    
----------+----------------------+------------+-----------+----------  
       3 | Мотоцикл Harley      |       8.00 |         2 |        5  
       1 | Спички хозяйственные |       0.50 |        10 |        1  
       1 | Спички хозяйственные |       0.50 |       120 |        2  
(3 rows)  
  
good_id |      good_name       | good_price | quantity | sum_sale    
---------+----------------------+------------+----------+----------  
      3 | Мотоцикл Harley      |       8.00 |        2 |    16.00  
      1 | Спички хозяйственные |       0.50 |      130 |    65.00  
(2 rows)  
  
otus=#
```

**Задание со звездочкой** *
Чем такая схема (витрина+триггер) предпочтительнее отчета, создаваемого "по требованию" (кроме производительности)? 
Да тут основной момент в том, чтобы дать API фронтенду, чтобы они не лезли со своим monkey patching куда не надо. Это еще один контур защиты данных от кривых рук при наличии прямых рук у DBA

Подсказка: В реальной жизни возможны изменения цен. 