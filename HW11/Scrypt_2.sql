DROP TABLE bookings.bookings_copy CASCADE;

select count(*) from bookings;

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

explain
select * FROM
bookings.bookings
WHERE book_date >= '2026-05-03' AND book_date < '2026-05-31';

explain
select * FROM
bookings.bookings_copy
WHERE book_date >= '2026-05-03' AND book_date < '2026-05-31';

explain
select * FROM
 bookings.bookings
WHERE book_date = '2026-05-03';

explain
select * FROM
 bookings.bookings_copy
WHERE book_date = '2026-05-03';

CREATE INDEX ON bookings.bookings_copy (book_date);

select * from bookings.bookings_copy
where book_ref =  'A12345';