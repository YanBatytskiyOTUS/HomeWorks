#postgresql #otus 
## Домашнее задание

Работа с join
Цель:
знать и уметь применять различные виды join'ов;  
строить и анализировать план выполенения запроса;  
оптимизировать запрос;  
уметь собирать и анализировать статистику для таблицы;

Описание/Пошаговая инструкция выполнения домашнего задания:

Необходимо:

1. Реализовать прямое соединение двух или более таблиц
```
otus=# SET SEARCH_PATH TO hw9;  
SET  
otus=# \pset null [NULL]  
Null display is "[NULL]".  
otus=# select p.chat_id, u.login, u.name  
otus-# from hw9.participants p  
otus-# INNER JOIN hw9.users u ON p.user_id = u.id  
otus-# ORDER BY p.chat_id, u.name;  
chat_id | login |  name     
---------+-------+--------  
      1 | a     | Alex  
      1 | e     | Elena  
      2 | a     | Alex  
      2 | e     | Elena  
      2 | m     | Mariya  
      2 | s     | Sergei  
      2 | y     | Yakov  
(7 rows)  
  
otus=#
```

2. Реализовать левостороннее (или правостороннее)  
    соединение двух или более таблиц
```
otus=# --левосторонне соединение таблиц, пользователи и чаты, в которых они участвуют  
otus=# SELECT u.login, u.name, p.chat_id  
otus-# FROM hw9.users u  
otus-# LEFT JOIN hw9.participants p ON u.id = p.user_id  
otus-# ORDER BY u.name, p.chat_id;  
login |  name   | chat_id    
-------+---------+---------  
a     | Alex    |       1  
a     | Alex    |       2  
e     | Elena   |       1  
e     | Elena   |       2  
f     | Fedor   |  [NULL]  
m     | Mariya  |       2  
s     | Sergei  |       2  
ver   | Vera    |  [NULL]  
v     | Vitaliy |  [NULL]  
y     | Yakov   |       2  
(10 rows)
```

3. Реализовать кросс соединение двух или более таблиц
```
otus=# SELECT * FROM hw9.chats  
otus-# CROSS JOIN hw9.users  
otus-# ORDER BY hw9.chats.id, hw9.users.name;  
id | id | login |  name      
----+----+-------+---------  
 1 |  1 | a     | Alex  
 1 |  2 | e     | Elena  
 1 |  6 | f     | Fedor  
 1 |  5 | m     | Mariya  
 1 |  3 | s     | Sergei  
 1 |  7 | ver   | Vera  
 1 |  4 | v     | Vitaliy  
 1 |  8 | y     | Yakov  
 2 |  1 | a     | Alex  
 2 |  2 | e     | Elena  
 2 |  6 | f     | Fedor  
 2 |  5 | m     | Mariya  
 2 |  3 | s     | Sergei  
 2 |  7 | ver   | Vera  
 2 |  4 | v     | Vitaliy  
 2 |  8 | y     | Yakov  
(16 rows)  
  
otus=#
```

4. Реализовать полное соединение двух или более таблиц
```
-- полное соединение трех таблиц  
SELECT u.name, u.login, p.last_read_message_id, m.message_text  
FROM hw9.users u  
FULL OUTER JOIN hw9.participants p ON u.id = p.user_id  
FULL OUTER JOIN hw9.messages m ON p.last_read_message_id = m.id;
```

```
otus=# -- полное соединение трех таблиц  
otus=# SELECT u.name, u.login, p.last_read_message_id, m.message_text  
otus-# FROM hw9.users u  
otus-# FULL OUTER JOIN hw9.participants p ON u.id = p.user_id  
otus-# FULL OUTER JOIN hw9.messages m ON p.last_read_message_id = m.id;  
 name   | login  | last_read_message_id |                                                                                   message_text                                                                      
                  
---------+--------+----------------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------  
----------------  
Elena   | e      |                    1 | Хорошо, как насчет кофе?  
Alex    | a      |                    2 | Хай! как делишки?  
Elena   | e      |                    4 | Куда идем?  
Alex    | a      |                    5 | Привет, Елена!  
Sergei  | s      |                    6 | Пойдем мы с тобою за тридевять земель, в тридесятое царство, искать там мудрость и счастье, чтобы испытать силу свою и судьбу проверить, а что ждёт впереди — лишь  
дорога покажет  
Mariya  | m      |               [NULL] | [NULL]  
Yakov   | y      |               [NULL] | [NULL]  
Fedor   | f      |               [NULL] | [NULL]  
Vitaliy | v      |               [NULL] | [NULL]  
Vera    | ver    |               [NULL] | [NULL]  
[NULL]  | [NULL] |               [NULL] | Всем Привееет!?  
[NULL]  | [NULL] |               [NULL] | Привет!  
[NULL]  | [NULL] |               [NULL] | Всем здрассьте.  
(13 rows)  
  
otus=#
```

**!!!тут по результату видна ошибка в заполнении таблицы participants в части поля last_read_message_id - не хватает данных**

5. Реализовать запрос, в котором будут использованы  разные типы соединений
```
-- соединение разных join  
SELECT p.chat_id,  
       u.login,  
       u.name,  
       p.last_read_message_id,  
       m.message_text  
FROM hw9.participants p  
    INNER JOIN hw9.users u ON p.user_id = u.id  
    RIGHT JOIN hw9.messages m ON p.last_read_message_id = m.id  
ORDER BY p.chat_id, u.name;
```

```
otus=# -- соединение разных join  
otus=# SELECT p.chat_id,  
otus-#        u.login,  
otus-#        u.name,  
otus-#        p.last_read_message_id,  
otus-#        m.message_text  
otus-# FROM hw9.participants p  
otus-#     INNER JOIN hw9.users u ON p.user_id = u.id  
otus-#     RIGHT JOIN hw9.messages m ON p.last_read_message_id = m.id  
otus-# ORDER BY p.chat_id, u.name;  
chat_id | login  |  name  | last_read_message_id |                                                                                   message_text                                                             
                           
---------+--------+--------+----------------------+----------------------------------------------------------------------------------------------------------------------------------------------------------  
-------------------------  
      1 | a      | Alex   |                    2 | Хай! как делишки?  
      1 | e      | Elena  |                    1 | Хорошо, как насчет кофе?  
      2 | a      | Alex   |                    5 | Привет, Елена!  
      2 | e      | Elena  |                    4 | Куда идем?  
      2 | s      | Sergei |                    6 | Пойдем мы с тобою за тридевять земель, в тридесятое царство, искать там мудрость и счастье, чтобы испытать силу свою и судьбу проверить, а что ждёт впере  
ди — лишь дорога покажет  
 [NULL] | [NULL] | [NULL] |               [NULL] | Всем Привееет!?  
 [NULL] | [NULL] | [NULL] |               [NULL] | Привет!  
 [NULL] | [NULL] | [NULL] |               [NULL] | Всем здрассьте.  
(8 rows)  
  
otus=#
```

6. Сделать комментарии на каждый запрос

7. К работе приложить структуру таблиц, для которых  
    выполнялись соединения
```
DROP TABLE IF EXISTS hw9.participants CASCADE;  
DROP TABLE IF EXISTS hw9.messages CASCADE;  
DROP TABLE IF EXISTS hw9.users CASCADE;  
DROP TABLE IF EXISTS hw9.chats CASCADE;  
BEGIN;  
create table if not exists hw9.chats (  
    id bigserial primary key  
);  
create table if not exists hw9.users (  
    id bigserial primary key,  
    login varchar(30) not null unique,  
    name varchar(30) not null DEFAULT ''  
);  
create table if not exists hw9.messages (  
    id bigserial not null,  
    chat_id bigint not null references hw9.chats(id) on delete cascade,  
    sender_id bigint not null references hw9.users(id) on delete restrict,  
    message_text text not null,  
    time_stamp bigint not null,  
    constraint messages_pk primary key (chat_id, id),  
    constraint messages_id_uq unique (id)  
);  
create table if not exists hw9.participants (  
    chat_id bigint not null references hw9.chats(id) on delete cascade,  
    user_id bigint not null references hw9.users(id) on delete cascade,  
    last_read_message_id bigint null,  
    constraint participants_pk primary key (chat_id, user_id),  
    constraint participants_last_read_fk foreign key (chat_id, last_read_message_id)  
        references hw9.messages(chat_id, id)  
);  
insert into hw9.users (login, name)  
values ('a', 'Alex'),  
('e', 'Elena'),  
('s', 'Sergei'),  
('v', 'Vitaliy'),  
('m', 'Mariya'),  
('f', 'Fedor'),  
('ver', 'Vera'),  
('y', 'Yakov')  
;  
COMMIT;  
BEGIN;  
with  
    user_e_record as (  
       select id as user_id  
       from hw9.users  
       where login = 'e'  
    ),  
    user_a_record as (  
       select id as user_id  
       from hw9.users  
       where login = 'a'  
    ),  
    chat_created as (  
       insert into hw9.chats default values  
       returning id as chat_id  
    ),  
    message1_insert as (  
       insert into hw9.messages (chat_id, sender_id, message_text, time_stamp)  
       select chat_created.chat_id, user_e_record.user_id, 'Привет!', 1743508800000  
       from chat_created cross join user_e_record  
       returning id as message_id  
    ),  
    message2_insert as (  
       insert into hw9.messages (chat_id, sender_id, message_text, time_stamp)  
       select chat_created.chat_id, user_a_record.user_id, 'Хай! как делишки?', 1743509100000  
       from chat_created cross join user_a_record  
       returning id as message_id  
    ),  
    message3_insert as (  
       insert into hw9.messages (chat_id, sender_id, message_text, time_stamp)  
       select chat_created.chat_id, user_e_record.user_id, 'Хорошо, как насчет кофе?', 1743509220000  
       from chat_created cross join user_e_record  
       returning id as message_id  
    ),  
        participants_insert as (  
       insert into hw9.participants (chat_id, user_id, last_read_message_id)  
       select chat_created.chat_id, user_e_record.user_id, message3_insert.message_id  
       from chat_created, user_e_record, message3_insert  
       union all  
       select chat_created.chat_id, user_a_record.user_id, message2_insert.message_id  
       from chat_created, user_a_record, message2_insert  
       returning chat_id  
    )  
SELECT 1;  
COMMIT;  
BEGIN;  
WITH  
  user_elena AS (  
    SELECT id AS user_id FROM hw9.users WHERE login = 'e'  
  ),  
  user_alex AS (  
    SELECT id AS user_id FROM hw9.users WHERE login = 'a'  
  ),  
  user_sergei AS (  
    SELECT id AS user_id FROM hw9.users WHERE login = 's'  
  ),  
  user_mariya AS (  
    SELECT id AS user_id FROM hw9.users WHERE login = 'm'  
  ),  
  user_yakov AS (  
    SELECT id AS user_id FROM hw9.users WHERE login = 'y'  
  ),  
  chat_created AS (  
    INSERT INTO hw9.chats DEFAULT VALUES  
    RETURNING id AS chat_id  
  ),  
  message1_insert AS (  
    INSERT INTO hw9.messages (chat_id, sender_id, message_text, time_stamp)  
    SELECT chat_created.chat_id, user_elena.user_id, 'Всем Привееет!?', 1743512400000  
    FROM chat_created CROSS JOIN user_elena  
    RETURNING id AS message_id  
  ),  
    message2_insert AS (  
        INSERT INTO hw9.messages (chat_id, sender_id, message_text, time_stamp)  
        SELECT chat_created.chat_id, user_alex.user_id, 'Привет, Елена!', 1743512700000  
        FROM chat_created CROSS JOIN user_alex  
        RETURNING id AS message_id  
    ),  
  message3_insert AS (  
    INSERT INTO hw9.messages (chat_id, sender_id, message_text, time_stamp)  
    SELECT chat_created.chat_id, user_sergei.user_id, 'Всем здрассьте.', 1743513015000  
    FROM chat_created CROSS JOIN user_sergei  
    RETURNING id AS message_id  
  ),  
  message4_insert AS (  
    INSERT INTO hw9.messages (chat_id, sender_id, message_text, time_stamp)  
    SELECT chat_created.chat_id, user_elena.user_id, 'Куда идем?', 1743513129000  
    FROM chat_created CROSS JOIN user_elena  
    RETURNING id AS message_id  
  ),  
  message5_insert AS (  
    INSERT INTO hw9.messages (chat_id, sender_id, message_text, time_stamp)  
    SELECT chat_created.chat_id, user_sergei.user_id,  
           'Пойдем мы с тобою за тридевять земель, в тридесятое царство, искать там мудрость и счастье, чтобы испытать силу свою и судьбу проверить, а что ждёт впереди — лишь дорога покажет',  
           1743514380000  
    FROM chat_created CROSS JOIN user_sergei  
    RETURNING id AS message_id  
  ),  
  participants_insert AS (  
    INSERT INTO hw9.participants (chat_id, user_id, last_read_message_id)  
    (  
      SELECT chat_created.chat_id, user_elena.user_id, message4_insert.message_id  
        FROM chat_created, user_elena, message4_insert  
      UNION ALL  
      SELECT chat_created.chat_id, user_alex.user_id, message2_insert.message_id  
        FROM chat_created, user_alex, message2_insert  
      UNION ALL  
      SELECT chat_created.chat_id, user_sergei.user_id, message5_insert.message_id  
        FROM chat_created, user_sergei, message5_insert  
      UNION ALL  
      SELECT chat_created.chat_id, user_mariya.user_id, NULL::bigint  
        FROM chat_created, user_mariya  
      UNION ALL  
      SELECT chat_created.chat_id, user_yakov.user_id, NULL::bigint  
        FROM chat_created, user_yakov  
    )  
    RETURNING 1 AS ok  
)  
SELECT 1;  
COMMIT;
```