#postgresql #otus 
## Домашнее задание

Работа с журналами

Цель:
уметь работать с журналами и контрольными точками;  
уметь настраивать параметры журналов;


Описание/Пошаговая инструкция выполнения домашнего задания:

1. Настройте выполнение контрольной точки раз в 30 секунд.
2. 10 минут c помощью утилиты pgbench подавайте нагрузку.
3. Измерьте, какой объем журнальных файлов был сгенерирован за это время. Оцените, какой объем приходится в среднем на одну контрольную точку.
	1. cоздали тестовую базу jornal, поставили checkpoint на 30 секунд
		ALTER SYSTEM SET checkpoint_timeout = '30s';
		ALTER SYSTEM SET max_wal_size = '10GB';
```
postgres=# SELECT wal_bytes FROM pg_stat_wal;  
wal_bytes    
-----------  
103031649  
(1 row)  
```

	1. нагрузили sudo -u postgres pgbench -c 25 -j 1 -P 60 -T 600 -U postgres -d jornal

```
latency average = 14.428 ms  
latency stddev = 15.012 ms  
initial connection time = 55.534 ms  
tps = 1732.331413 (without initial connection time)

postgres=# SELECT wal_bytes FROM pg_stat_wal;  
wal_bytes    
-----------  
971285724  
(1 row)
```

итого: примерно 870 мб при примерно 20 чекпойнтах

3. Проверьте данные статистики: все ли контрольные точки выполнялись точно по расписанию. Почему так произошло?
```
postgres=# SELECT  
   num_timed,  
   num_requested,  
   write_time,  
   sync_time,  
   buffers_written  
FROM pg_stat_checkpointer;  
num_timed | num_requested | write_time | sync_time | buffers_written    
-----------+---------------+------------+-----------+-----------------  
      335 |            27 |    4152494 |       512 |          284954  
(1 row)  
  
postgres=#
```
3. Сравните tps в синхронном/асинхронном режиме утилитой pgbench. Объясните полученный результат.
```
ALTER SYSTEM SET synchronous_commit = off;

latency average = 13.817 ms  
latency stddev = 14.037 ms  
initial connection time = 53.720 ms  
tps = 1809.023985 (without initial connection time)  
root@otus:~#
```
видимо, потому что не ждет fsync на каждую транзакцию

3. Создайте новый кластер с включенной контрольной суммой страниц. Создайте таблицу. Вставьте несколько значений. Выключите кластер. Измените пару байт в таблице. Включите кластер и сделайте выборку из таблицы. Что и почему произошло? как проигнорировать ошибку и продолжить работу?

результат:
```
postgres=# select * from t;  
ERROR:  invalid page in block 0 of relation "base/5/16384"  
postgres=#
```
сбой проверки контрольных сумм.
Дальше либо игнорировать ошибку либо стирать кусок данных - целиком страницу