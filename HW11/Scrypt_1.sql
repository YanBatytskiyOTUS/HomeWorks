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
                    LOOP
                        SELECT partition_next_year, partition_next_month
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

INSERT INTO bookings.bookings_copy (book_ref, book_date, total_amount)
SELECT book_ref, book_date, total_amount
FROM bookings.bookings;