#postgresql #otus 
## Домашнее задание

Нагрузочное тестирование и тюнинг PostgreSQL

Цель:

- сделать нагрузочное тестирование PostgreSQL
- настроить параметры PostgreSQL для достижения максимальной производительности

Описание/Пошаговая инструкция выполнения домашнего задания:

- развернуть виртуальную машину любым удобным способом
![](attachments/1.png)
- поставить на неё PostgreSQL 18 любым способом
- настроить кластер PostgreSQL 18 на максимальную производительность не обращая внимание на возможные проблемы с надежностью в случае аварийной перезагрузки виртуальной машины
	Тут нам нужно:
		1. Максимально отключить механизмы WAL и ему подобные
		2. Настроить максимально агрессивно параметры памяти, процессора и т. д.

	Настройки делаем через postgresql.auto.conf через команду ALTER
1. Дисковые настройки:
	ALTER SYSTEM SET fsync=off; отключаем запись на диск write ahead log
	ALTER SYSTEM SET synchronous_commit= off; отключаем режим batch при работе с WAL. Транзакция считается подтвержденной до того как накопленный batch скидывается на диск по fsync
	ALTER SYSTEM SET full_page_writes=off; не пишет полные страницы, делает wal меньше
	ALTER SYSTEM SET wal_level=minimal;
	- checkpoint_completion_target  - ставим 0.9
	- random_page_cost 1.1


2. Память:
![](attachments/3.png)

- shared_buffers = 25%–40% RAM - берем 512MB
- effective_cache_size = ~2/3 RAM - берем 1536MB
- work_mem 64MB для одной обработки
- maintenance_work_mem берем 256MB для индексов и пылесосущего
- temp_buffers = 64MB - временные таблицы

2. Процессор:
	- max_worker_processes = 1 - у меня всего один CPU
	- max_parallel_workers = 1 -
	- max_parallel_workers_per_gather = 1
	- max_parallel_maintenance_workers = 1

3. Оптимизатор
	- default_statistics_target = 200 
	- join_collapse_limit = 8
	
![](4.png)

при перезагрузке получил проблему из-за настройки wal_level = minimal:
включён streaming (т.к. max_wal_senders > 0), из-за этого кластер **не стартует**:
```
FATAL: WAL streaming ("max_wal_senders" > 0) requires "wal_level" to be "replica" or "logical".
```
соотвественно кластер лег до исправления этого пункта в postgresql.auto.conf
сбрасываем все настройки для чистоты эксперимента через ALTER SYSTEM reset all; 

- нагрузить кластер через утилиту через утилиту pgbench ([https://postgrespro.ru/docs/postgrespro/18/pgbench](https://postgrespro.ru/docs/postgrespro/18/pgbench "https://postgrespro.ru/docs/postgrespro/18/pgbench"))

сначала сбрасываем все настройки для чистоты эксперимента через ALTER SYSTEM reset all; 
с командой из урока pgbench -c 50 -j 2 -P 10 -T 60 мы получили tps:
```
tps = 1242.150821 (without initial connection time)
```

затем мы снова применяем настройки и запускаем тест снова с командой из урока pgbench -c 50 -j 2 -P 10 -T 60:
```
tps = 1926.620706 (without initial connection time)
```

затем выставляем в команде настройки согласно нашему железу
pgbench -c 25 -j 1 -P 10 -T 60
```
tps = 2493.971208 (without initial connection time)
```
- написать какого значения tps удалось достичь, показать какие параметры в какие значения устанавливали и почему
**один CPU - один worker и меньше одновременных подключений**

  
Задание со *: аналогично протестировать через утилиту [https://github.com/Percona-Lab/sysbench-tpcc](https://github.com/Percona-Lab/sysbench-tpcc "https://github.com/Percona-Lab/sysbench-tpcc") (требует установки  
[https://github.com/akopytov/sysbench](https://github.com/akopytov/sysbench "https://github.com/akopytov/sysbench"))
```
root@otus:~/volume1/sysbench/sysbench-tpcc# sysbench --help | grep pgsql
  **pgsql** - PostgreSQL driver
**pgsql** options:
  --**pgsql**-host=STRING     PostgreSQL server host [localhost]
  --**pgsql**-port=N          PostgreSQL server port [5432]
  --**pgsql**-user=STRING     PostgreSQL user [sbtest]
  --**pgsql**-password=STRING PostgreSQL password []
  --**pgsql**-db=STRING       PostgreSQL database name [sbtest]

root@otus:~/volume1/sysbench/sysbench-tpcc#

sysbench tpcc.lua \
  --db-driver=pgsql \
  --pgsql-host=127.0.0.1 \
  --pgsql-port=5432 \
  --pgsql-user=tpcc \
  --pgsql-password=tpcc \
  --pgsql-db=tpcc \
  --threads=8 \
  --time=60 \
  --report-interval=10 \
  --scale=1 \
  run
```


результат:
```
SQL statistics:

    queries performed:

        read:                            248117

        write:                           250639

        other:                           61074

        total:                           559830

    transactions:                        16323  (271.78 per sec.)

    queries:                             559830 (9321.25 per sec.)

    ignored errors:                      14278  (237.73 per sec.)

    reconnects:                          0      (0.00 per sec.)

  

General statistics:

    total time:                          60.0572s

    total number of events:              16323

  

Latency (ms):

         min:                                    0.39

         avg:                                   29.42

         max:                                  340.11

         95th percentile:                       71.83

         sum:                               480174.57

  

Threads fairness:

    events (avg/stddev):           2040.3750/42.82

    execution time (avg/stddev):   60.0218/0.02
```

**вывод: pgbench в корзину**
