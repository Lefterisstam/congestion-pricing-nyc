-- Δότες για το synthetic control.
-- Grain: μία γραμμή ανά (pickup_date, pickup_zone_id), μόνο για διαδρομές της ομάδας ΑΝΑΦΟΡΑΣ
-- χωρίς αεροδρόμια: και τα δύο άκρα είναι ζώνες 'outside' που δεν είναι αεροδρόμιο.
-- Είναι δηλαδή η ομάδα route_group = 'control' και touches_airport = false του mart_route_day,
-- σπασμένη ανά ζώνη επιβίβασης.

with control_zones as (

    select
        location_id as zone_id,
        zone_name
    from {{ ref('cbd_zone_flags') }}
    where cbd_group = 'outside'
      and zone_name not like '%Airport%'

),

-- ημερολόγιο: ΟΛΕΣ οι ημέρες × ΟΛΕΣ οι ζώνες-δότες, ώστε να μην υπάρχουν κενά
spine as (

    select
        cast(d.dt as date) as pickup_date,
        z.zone_id          as pickup_zone_id,
        z.zone_name        as pickup_zone_name
    from generate_series(date '2023-01-01', date '2025-12-31', interval 1 day) as d(dt)
    cross join control_zones as z

),

trips as (

    select t.*
    from {{ ref('int_trips_flagged') }} as t
    inner join control_zones as p on t.pickup_zone_id  = p.zone_id
    inner join control_zones as q on t.dropoff_zone_id = q.zone_id
    where t.is_pickup_in_file_month

),

daily as (

    select
        pickup_date,
        pickup_zone_id,

        count(*)                                                                    as n_rows_in_month,
        count(*) filter (where is_valid_for_count)                                  as n_trips,
        count(*) filter (where is_valid_for_count
                           and payment_type is distinct from 0)                     as n_trips_excl_type0,

        count(*) filter (where is_valid_for_speed)                                  as n_trips_speed,
        sum(trip_distance_miles) filter (where is_valid_for_speed)                  as sum_distance_miles_speed,
        sum(duration_sec) filter (where is_valid_for_speed)                         as sum_duration_sec_speed,

        count(*) filter (where is_valid_for_count and payment_type = 0)             as n_type0_trips

    from trips
    group by pickup_date, pickup_zone_id

)

select
    s.pickup_date,
    s.pickup_zone_id,
    s.pickup_zone_name,
    s.pickup_date >= cast('{{ var("policy_start_date") }}' as date)  as is_post_policy,

    coalesce(d.n_rows_in_month, 0)             as n_rows_in_month,
    coalesce(d.n_trips, 0)                     as n_trips,
    coalesce(d.n_trips_excl_type0, 0)          as n_trips_excl_type0,
    coalesce(d.n_trips_speed, 0)               as n_trips_speed,
    coalesce(d.sum_distance_miles_speed, 0)    as sum_distance_miles_speed,
    coalesce(d.sum_duration_sec_speed, 0)      as sum_duration_sec_speed,
    coalesce(d.n_type0_trips, 0)               as n_type0_trips

from spine as s
left join daily as d
    on  s.pickup_date    = d.pickup_date
    and s.pickup_zone_id = d.pickup_zone_id