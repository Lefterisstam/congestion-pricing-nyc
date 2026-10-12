-- Η χρέωση ανά ημέρα στο αρχείο του Ιανουαρίου 2025:
-- πότε ξεκινά και ποιες τιμές παίρνει;
select
    pickup_date,
    count(*)                                                       as n_trips,
    count(*) filter (where cbd_congestion_fee > 0)                 as n_charged,
    round(100.0 * count(*) filter (where cbd_congestion_fee > 0)
          / count(*), 2)                                           as pct_charged,
    min(cbd_congestion_fee) filter (where cbd_congestion_fee > 0)  as min_positive_fee,
    max(cbd_congestion_fee)                                        as max_fee,
    count(*) filter (where cbd_congestion_fee is null)             as n_null_fee
from {{ ref('int_trips_flagged') }}
where source_file_month = '2025-01'
  and is_valid_trip
group by pickup_date
order by pickup_date