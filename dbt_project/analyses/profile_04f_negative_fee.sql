-- Ποιες τιμές έχουν οι αρνητικές χρεώσεις, με ποιον τρόπο πληρωμής,
-- και τι ποσά έχουν οι υπόλοιπες στήλες στις ίδιες γραμμές;
select
    cbd_congestion_fee,
    payment_type,
    count(*)                       as n_trips,
    min(total_amount)              as min_total,
    max(total_amount)              as max_total,
    round(avg(fare_amount), 2)     as avg_fare
from {{ ref('int_trips_flagged') }}
where source_file_month = '2025-01'
  and cbd_congestion_fee < 0
group by cbd_congestion_fee, payment_type
order by n_trips desc