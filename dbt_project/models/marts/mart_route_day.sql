-- Grain: μία γραμμή ανά (pickup_date, pickup_group, dropoff_group, touches_airport).
-- Το route_group προκύπτει από το ζεύγος (pickup_group, dropoff_group).

with zone_groups as (

    select distinct cbd_group as zone_group
    from {{ ref('cbd_zone_flags') }}

),

airports as (

    select location_id
    from {{ ref('cbd_zone_flags') }}
    where zone_name like '%Airport%'

),

-- ημερολόγιο: ΟΛΕΣ οι ημέρες × ΟΛΑ τα ζεύγη × (αεροδρόμιο ναι/όχι), ώστε να μην υπάρχουν κενά
spine as (

    select
        cast(d.dt as date)  as pickup_date,
        p.zone_group        as pickup_group,
        q.zone_group        as dropoff_group,
        a.touches_airport   as touches_airport
    from generate_series(date '2023-01-01', date '2025-12-31', interval 1 day) as d(dt)
    cross join zone_groups as p
    cross join zone_groups as q
    cross join (select true as touches_airport union all select false) as a

),

trips as (

    select
        t.*,
        p.cbd_group as pickup_group,
        q.cbd_group as dropoff_group,
        (   t.pickup_zone_id  in (select location_id from airports)
         or t.dropoff_zone_id in (select location_id from airports)) as touches_airport
    from {{ ref('int_trips_flagged') }} as t
    left join {{ ref('cbd_zone_flags') }} as p on t.pickup_zone_id  = p.location_id
    left join {{ ref('cbd_zone_flags') }} as q on t.dropoff_zone_id = q.location_id
    where t.is_pickup_in_file_month

),

daily as (

    select
        pickup_date,
        pickup_group,
        dropoff_group,
        touches_airport,

        count(*)                                                                    as n_rows_in_month,

        -- Δείκτης 1: πλήθος (κύριος κανόνας is_valid_for_count)
        count(*) filter (where is_valid_for_count)                                  as n_trips,
        count(*) filter (where is_valid_for_count
                           and payment_type is distinct from 0)                     as n_trips_excl_type0,

        -- Έλεγχος ευαισθησίας: αυστηρός κανόνας
        count(*) filter (where is_valid_trip)                                       as n_trips_strict,
        count(*) filter (where is_valid_trip
                           and payment_type is distinct from 0)                     as n_trips_strict_excl_type0,

        -- Έκθεση στο τέλος (έχει νόημα μόνο από 5/1/2025)
        count(*) filter (where is_valid_trip
                           and cbd_congestion_fee <> 0)                             as n_fee_trips_strict,

        -- Δείκτης 2: ταχύτητα (αθροίσματα, ώστε να συγκεντρώνονται σωστά)
        count(*) filter (where is_valid_for_speed)                                  as n_trips_speed,
        sum(trip_distance_miles) filter (where is_valid_for_speed)                  as sum_distance_miles_speed,
        sum(duration_sec) filter (where is_valid_for_speed)                         as sum_duration_sec_speed,

        -- Διάγνωση σύνθεσης
        count(*) filter (where is_valid_for_count and payment_type = 0)             as n_type0_trips,
        count(*) filter (where is_valid_for_count and vendor_id = 7)                as n_vendor7_trips

    from trips
    group by pickup_date, pickup_group, dropoff_group, touches_airport

)

select
    s.pickup_date,
    s.pickup_group,
    s.dropoff_group,
    s.touches_airport,
    case
        when s.pickup_group = 'unknown'     or s.dropoff_group = 'unknown'     then 'excluded'
        when s.pickup_group = 'inside'      or s.dropoff_group = 'inside'      then 'treated'
        when s.pickup_group = 'near_border' or s.dropoff_group = 'near_border' then 'buffer'
        else 'control'
    end                                                                          as route_group,
    s.pickup_date >= cast('{{ var("policy_start_date") }}' as date)              as is_post_policy,

    coalesce(d.n_rows_in_month, 0)             as n_rows_in_month,
    coalesce(d.n_trips, 0)                     as n_trips,
    coalesce(d.n_trips_excl_type0, 0)          as n_trips_excl_type0,
    coalesce(d.n_trips_strict, 0)              as n_trips_strict,
    coalesce(d.n_trips_strict_excl_type0, 0)   as n_trips_strict_excl_type0,
    coalesce(d.n_fee_trips_strict, 0)          as n_fee_trips_strict,
    coalesce(d.n_trips_speed, 0)               as n_trips_speed,
    coalesce(d.sum_distance_miles_speed, 0)    as sum_distance_miles_speed,
    coalesce(d.sum_duration_sec_speed, 0)      as sum_duration_sec_speed,
    coalesce(d.n_type0_trips, 0)               as n_type0_trips,
    coalesce(d.n_vendor7_trips, 0)             as n_vendor7_trips

from spine as s
left join daily as d
    on  s.pickup_date     = d.pickup_date
    and s.pickup_group    = d.pickup_group
    and s.dropoff_group   = d.dropoff_group
    and s.touches_airport = d.touches_airport