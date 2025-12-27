## Домашнее задание

Нагрузочное тестирование и тюнинг PostgreSQL

Цель:

- сделать нагрузочное тестирование PostgreSQL
- настроить параметры PostgreSQL для достижения максимальной производительности

Описание/Пошаговая инструкция выполнения домашнего задания:

- развернуть виртуальную машину любым удобным способом
- поставить на неё PostgreSQL 18 любым способом
- настроить кластер PostgreSQL 18 на максимальную производительность не обращая внимание на возможные проблемы с надежностью в случае аварийной перезагрузки виртуальной машины
- нагрузить кластер через утилиту через утилиту pgbench ([https://postgrespro.ru/docs/postgrespro/18/pgbench](https://postgrespro.ru/docs/postgrespro/18/pgbench "https://postgrespro.ru/docs/postgrespro/18/pgbench"))
- написать какого значения tps удалось достичь, показать какие параметры в какие значения устанавливали и почему

  
Задание со *: аналогично протестировать через утилиту [https://github.com/Percona-Lab/sysbench-tpcc](https://github.com/Percona-Lab/sysbench-tpcc "https://github.com/Percona-Lab/sysbench-tpcc") (требует установки  
[https://github.com/akopytov/sysbench](https://github.com/akopytov/sysbench "https://github.com/akopytov/sysbench"))