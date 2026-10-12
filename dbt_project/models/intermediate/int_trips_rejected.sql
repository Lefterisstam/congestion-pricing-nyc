with trips as (

    select
        source_file_month,
        trip_rejection_reason,
        speed_exclusion_reason
    from {{ ref('int_trips_flagged') }}

),

totals as (

    select
        source_file_month,
        count(*) as n_total_trips
    from trips
    group by source_file_month

),

rejections as (

    select
        source_file_month,
        'trip'                  as rule_set,
        trip_rejection_reason   as reason,
        count(*)                as n_rows
    from trips
    where trip_rejection_reason is not null
    group by source_file_month, trip_rejection_reason

    union all

    select
        source_file_month,
        'speed'                 as rule_set,
        speed_exclusion_reason  as reason,
        count(*)                as n_rows
    from trips
    where speed_exclusion_reason is not null
    group by source_file_month, speed_exclusion_reason

)

select
    r.source_file_month,
    r.rule_set,
    r.reason,
    r.n_rows,
    t.n_total_trips,
    round(100.0 * r.n_rows / t.n_total_trips, 4) as pct_of_month
from rejections as r
inner join totals as t
    on r.source_file_month = t.source_file_month
order by r.source_file_month, r.rule_set, r.n_rows desc