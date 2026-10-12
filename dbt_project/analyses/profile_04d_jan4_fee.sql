-- Οι 401 χρεωμένες διαδρομές της 4/1: ποια ώρα ξεκίνησαν και πότε τελείωσαν;
select
    extract(hour from pickup_at)  as pickup_hour,
    cast(dropoff_at as date)      as dropoff_date,
    count(*)                      as n_charged_trips
from {{ ref('int_trips_flagged') }}
where pickup_date = date '2025-01-04'
  and cbd_congestion_fee > 0
group by pickup_hour, dropoff_date
order by pickup_hour, dropoff_date