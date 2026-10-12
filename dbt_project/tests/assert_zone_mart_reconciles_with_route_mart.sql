with z as (

    select
        pickup_date,
        sum(n_rows_in_month)            as n_rows_in_month,
        sum(n_trips)                    as n_trips,
        sum(n_trips_excl_type0)         as n_trips_excl_type0,
        sum(n_trips_speed)              as n_trips_speed,
        sum(sum_distance_miles_speed)   as sum_distance_miles_speed,
        sum(sum_duration_sec_speed)     as sum_duration_sec_speed,
        sum(n_type0_trips)              as n_type0_trips
    from {{ ref('mart_control_zone_day') }}
    group by pickup_date

),

r as (

    select
        pickup_date,
        sum(n_rows_in_month)            as n_rows_in_month,
        sum(n_trips)                    as n_trips,
        sum(n_trips_excl_type0)         as n_trips_excl_type0,
        sum(n_trips_speed)              as n_trips_speed,
        sum(sum_distance_miles_speed)   as sum_distance_miles_speed,
        sum(sum_duration_sec_speed)     as sum_duration_sec_speed,
        sum(n_type0_trips)              as n_type0_trips
    from {{ ref('mart_route_day') }}
    where route_group = 'control'
      and not touches_airport
    group by pickup_date

)

select
    coalesce(z.pickup_date, r.pickup_date) as pickup_date,
    z.n_trips                              as zone_mart_trips,
    r.n_trips                              as route_mart_trips
from z
full outer join r on z.pickup_date = r.pickup_date
where z.pickup_date is null
   or r.pickup_date is null
   or z.n_rows_in_month is distinct from r.n_rows_in_month
   or z.n_trips is distinct from r.n_trips
   or z.n_trips_excl_type0 is distinct from r.n_trips_excl_type0
   or z.n_trips_speed is distinct from r.n_trips_speed
   or z.n_type0_trips is distinct from r.n_type0_trips
   or abs(coalesce(z.sum_distance_miles_speed, 0) - coalesce(r.sum_distance_miles_speed, 0)) > 0.001
   or abs(coalesce(z.sum_duration_sec_speed, 0)   - coalesce(r.sum_duration_sec_speed, 0))   > 0.001