-- Διάγνωση του «άλματος» Δεκ 2023 / Ιαν 2024. ΜΟΝΟ δεδομένα «πριν» (< policy_start_date).
-- Μηνιαία μέση ημερήσια τιμή ανά σειρά: Κέντρο, Αναφορά χωρίς αεροδρόμια, Αναφορά αεροδρομίων.
-- Ταχύτητα (mph) = Σαπόσταση / Σδιάρκεια * 3600, από τις γραμμές που μετράνε για ταχύτητα.
with pre as (
    select
        pickup_date,
        n_trips,
        n_trips_excl_type0,
        n_trips_speed,
        sum_distance_miles_speed,
        sum_duration_sec_speed,
        n_type0_trips,
        case
            when route_group = 'treated'                          then 'treated'
            when route_group = 'control' and not touches_airport  then 'control_no_air'
            when route_group = 'control' and touches_airport      then 'control_air'
        end as series
    from {{ ref('mart_route_day') }}
    where pickup_date < date '{{ var("policy_start_date") }}'
      and route_group in ('treated', 'control')
),

monthly as (
    select
        date_trunc('month', pickup_date)::date as month,
        count(distinct pickup_date) as days,
        sum(n_trips)            filter (where series = 'treated')        / count(distinct pickup_date) as t_trips_day,
        sum(n_trips)            filter (where series = 'control_no_air') / count(distinct pickup_date) as c_trips_day,
        sum(n_trips)            filter (where series = 'control_air')    / count(distinct pickup_date) as ca_trips_day,
        sum(n_trips_excl_type0) filter (where series = 'treated')        / count(distinct pickup_date) as t_trips_b_day,
        sum(n_trips_excl_type0) filter (where series = 'control_no_air') / count(distinct pickup_date) as c_trips_b_day,
        sum(sum_distance_miles_speed) filter (where series = 'treated')
            / sum(sum_duration_sec_speed) filter (where series = 'treated') * 3600        as t_mph,
        sum(sum_distance_miles_speed) filter (where series = 'control_no_air')
            / sum(sum_duration_sec_speed) filter (where series = 'control_no_air') * 3600 as c_mph,
        sum(n_type0_trips) filter (where series = 'treated')        * 1.0
            / sum(n_trips) filter (where series = 'treated')        as t_type0_share,
        sum(n_type0_trips) filter (where series = 'control_no_air') * 1.0
            / sum(n_trips) filter (where series = 'control_no_air') as c_type0_share
    from pre
    group by 1
)

select
    month,
    days,
    round(t_trips_day)                       as treated_trips_day,
    round(c_trips_day)                       as ctrl_noair_trips_day,
    round(ca_trips_day)                      as ctrl_air_trips_day,
    round(t_trips_day / c_trips_day, 3)      as ratio_a,
    round(t_trips_b_day / c_trips_b_day, 3)  as ratio_b,
    round(t_mph, 2)                          as treated_mph,
    round(c_mph, 2)                          as ctrl_noair_mph,
    round(t_mph / c_mph, 3)                  as ratio_mph,
    round(t_type0_share, 4)                  as treated_type0,
    round(c_type0_share, 4)                  as ctrl_type0
from monthly
order by month