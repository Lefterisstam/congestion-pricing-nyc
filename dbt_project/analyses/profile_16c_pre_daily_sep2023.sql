-- Διάγνωση: ο Σεπτέμβριος 2023 φαίνεται χαμηλός σε όλες τις σειρές. ΜΟΝΟ δεδομένα «πριν».
-- Ημερήσια πλήθη, 20/8/2023 – 10/10/2023.
with pre as (
    select
        pickup_date,
        sum(n_trips) filter (where route_group = 'treated')                                  as treated,
        sum(n_trips) filter (where route_group = 'control' and not touches_airport)          as ctrl_noair,
        sum(n_rows_in_month) as rows_in_month_col
    from {{ ref('mart_route_day') }}
    where pickup_date >= date '2023-08-20'
      and pickup_date <  date '2023-10-11'
      and pickup_date <  date '{{ var("policy_start_date") }}'
    group by 1
)

select
    pickup_date,
    dayname(pickup_date) as dow,
    treated,
    ctrl_noair,
    round(treated * 1.0 / ctrl_noair, 2) as ratio_a
from pre
order by pickup_date