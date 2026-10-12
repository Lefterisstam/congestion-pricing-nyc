-- Πώς κατανέμονται οι τύποι πληρωμής ανά μήνα, και τι χαρακτηριστικά έχει ο καθένας;
select
    source_file_month,
    payment_type,
    count(*)                                                     as n_trips,
    round(100.0 * count(*)
          / sum(count(*)) over (partition by source_file_month), 2) as pct_of_month,
    round(100.0 * count(*) filter (where passenger_count is null)
          / count(*), 1)                                         as pct_null_passengers,
    round(100.0 * count(*) filter (where fare_amount < 0)
          / count(*), 1)                                         as pct_negative_fare
from {{ ref('int_trips_flagged') }}
group by source_file_month, payment_type
order by source_file_month, n_trips desc