-- Έχουν τα νησιά του λιμανιού (103-105) ουσιαστικές διαδρομές;
select 'pickup' as side, source_file_month, pickup_zone_id as zone_id, count(*) as n_trips
from {{ ref('int_trips_flagged') }}
where pickup_zone_id in (103, 104, 105)
group by 1, 2, 3
union all
select 'dropoff', source_file_month, dropoff_zone_id, count(*)
from {{ ref('int_trips_flagged') }}
where dropoff_zone_id in (103, 104, 105)
group by 1, 2, 3
order by 1, 2, 3