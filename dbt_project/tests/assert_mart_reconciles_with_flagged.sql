with mart as (
    select
        sum(n_rows_in_month) as m_rows,
        sum(n_trips)         as m_count,
        sum(n_trips_strict)  as m_strict,
        sum(n_trips_speed)   as m_speed
    from {{ ref('mart_route_day') }}
),

flagged as (
    select
        count(*) filter (where is_pickup_in_file_month) as f_rows,
        count(*) filter (where is_valid_for_count)      as f_count,
        count(*) filter (where is_valid_trip)           as f_strict,
        count(*) filter (where is_valid_for_speed)      as f_speed
    from {{ ref('int_trips_flagged') }}
)

select *
from mart
cross join flagged
where m_rows   <> f_rows
   or m_count  <> f_count
   or m_strict <> f_strict
   or m_speed  <> f_speed