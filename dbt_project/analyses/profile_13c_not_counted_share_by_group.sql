select
    cast(date_trunc('month', pickup_date) as date) as month,
    round(100.0 * (sum(n_rows_in_month) filter (where route_group = 'treated')
                 - sum(n_trips)         filter (where route_group = 'treated'))
          / sum(n_rows_in_month) filter (where route_group = 'treated'), 3)  as treated,
    round(100.0 * (sum(n_rows_in_month) filter (where route_group = 'buffer')
                 - sum(n_trips)         filter (where route_group = 'buffer'))
          / sum(n_rows_in_month) filter (where route_group = 'buffer'), 3)   as buffer,
    round(100.0 * (sum(n_rows_in_month) filter (where route_group = 'control')
                 - sum(n_trips)         filter (where route_group = 'control'))
          / sum(n_rows_in_month) filter (where route_group = 'control'), 3)  as control
from {{ ref('mart_route_day') }}
group by 1
order by 1