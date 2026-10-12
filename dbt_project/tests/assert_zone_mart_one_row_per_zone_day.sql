select
    pickup_zone_id,
    count(*)                    as n_rows,
    count(distinct pickup_date) as n_distinct_days
from {{ ref('mart_control_zone_day') }}
group by pickup_zone_id
having count(*) <> 1096
    or count(distinct pickup_date) <> count(*)
    or min(pickup_date) <> date '2023-01-01'
    or max(pickup_date) <> date '2025-12-31'