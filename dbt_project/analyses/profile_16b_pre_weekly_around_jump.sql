-- Ίδια διάγνωση, αλλά ανά εβδομάδα, γύρω από το «άλμα» (Νοέμβριος 2023 – Μάρτιος 2024).
-- ΜΟΝΟ δεδομένα «πριν».
with pre as (
    select
        pickup_date,
        n_trips,
        sum_distance_miles_speed,
        sum_duration_sec_speed,
        case
            when route_group = 'treated'                          then 'treated'
            when route_group = 'control' and not touches_airport  then 'control_no_air'
        end as series
    from {{ ref('mart_route_day') }}
    where pickup_date >= date '2023-11-01'
      and pickup_date <  date '2024-04-01'
      and pickup_date <  date '{{ var("policy_start_date") }}'
      and route_group in ('treated', 'control')
      and not (route_group = 'control' and touches_airport)
),

weekly as (
    select
        date_trunc('week', pickup_date)::date as week_start,
        count(distinct pickup_date) as days,
        sum(n_trips) filter (where series = 'treated')        / count(distinct pickup_date) as t_trips_day,
        sum(n_trips) filter (where series = 'control_no_air') / count(distinct pickup_date) as c_trips_day,
        sum(sum_distance_miles_speed) filter (where series = 'treated')
            / sum(sum_duration_sec_speed) filter (where series = 'treated') * 3600        as t_mph,
        sum(sum_distance_miles_speed) filter (where series = 'control_no_air')
            / sum(sum_duration_sec_speed) filter (where series = 'control_no_air') * 3600 as c_mph
    from pre
    group by 1
)

select
    week_start,
    days,
    round(t_trips_day)                  as treated_trips_day,
    round(c_trips_day)                  as ctrl_noair_trips_day,
    round(t_trips_day / c_trips_day, 3) as ratio_a,
    round(t_mph, 2)                     as treated_mph,
    round(c_mph, 2)                     as ctrl_noair_mph,
    round(t_mph / c_mph, 3)             as ratio_mph
from weekly
order by week_start