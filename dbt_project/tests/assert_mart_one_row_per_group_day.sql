select
    pickup_group,
    dropoff_group,
    touches_airport,
    count(*)                    as n_rows,
    count(distinct pickup_date) as n_distinct_days
from {{ ref('mart_route_day') }}
group by pickup_group, dropoff_group, touches_airport
having count(*) <> 1096
    or count(distinct pickup_date) <> count(*)
    or min(pickup_date) <> date '2023-01-01'
    or max(pickup_date) <> date '2025-12-31'