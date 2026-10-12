-- Είναι οι αρνητικές τιμές γενικό φαινόμενο (και το 2024) ή αφορούν μόνο το fee;
select
    source_file_month,
    count(*) filter (where total_amount < 0)         as n_negative_total,
    count(*) filter (where fare_amount < 0)          as n_negative_fare,
    count(*) filter (where cbd_congestion_fee < 0)   as n_negative_fee
from {{ ref('int_trips_flagged') }}
group by source_file_month
order by source_file_month