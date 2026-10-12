select
    cast(date_trunc('month', pickup_date) as date) as month,
    round(100.0 * sum(n_fee_trips_strict) filter (where route_group = 'treated')
          / sum(n_trips_strict) filter (where route_group = 'treated'), 2)  as treated,
    round(100.0 * sum(n_fee_trips_strict) filter (where route_group = 'buffer')
          / sum(n_trips_strict) filter (where route_group = 'buffer'), 2)   as buffer,
    round(100.0 * sum(n_fee_trips_strict) filter (where route_group = 'control')
          / sum(n_trips_strict) filter (where route_group = 'control'), 2)  as control
from {{ ref('mart_route_day') }}
where is_post_policy
group by 1
order by 1