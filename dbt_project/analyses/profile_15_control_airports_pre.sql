-- Διαγνωστικό ΜΟΝΟ για το «πριν». Ρωτά: εξηγούν τα αεροδρόμια την τάση της Αναφοράς;
with airports as (

    select location_id
    from {{ ref('cbd_zone_flags') }}
    where zone_name like '%Airport%'

),

control_trips as (

    select
        t.pickup_date,
        t.is_valid_for_count,
        t.is_valid_for_speed,
        t.trip_distance_miles,
        t.duration_sec,
        (   t.pickup_zone_id  in (select location_id from airports)
         or t.dropoff_zone_id in (select location_id from airports)) as touches_airport
    from {{ ref('int_trips_flagged') }} as t
    inner join {{ ref('cbd_zone_flags') }} as p on t.pickup_zone_id  = p.location_id
    inner join {{ ref('cbd_zone_flags') }} as q on t.dropoff_zone_id = q.location_id
    where p.cbd_group = 'outside'
      and q.cbd_group = 'outside'
      and t.is_pickup_in_file_month
      and t.pickup_date < cast('{{ var("policy_start_date") }}' as date)

)

select
    cast(date_trunc('month', pickup_date) as date)                                   as month,
    count(*) filter (where is_valid_for_count)                                       as n_control_trips,
    round(100.0 * count(*) filter (where is_valid_for_count and touches_airport)
          / count(*) filter (where is_valid_for_count), 1)                           as pct_airport,
    round(sum(trip_distance_miles) filter (where is_valid_for_speed)
          / (sum(duration_sec) filter (where is_valid_for_speed) / 3600.0), 2)       as speed_all,
    round(sum(trip_distance_miles) filter (where is_valid_for_speed and not touches_airport)
          / (sum(duration_sec) filter (where is_valid_for_speed and not touches_airport) / 3600.0), 2)
                                                                                     as speed_no_airport
from control_trips
group by 1
order by 1