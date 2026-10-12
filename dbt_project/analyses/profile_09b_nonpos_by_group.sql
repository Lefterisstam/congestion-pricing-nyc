select
    t.source_file_month,
    p.cbd_group                                   as pickup_group,
    count(*)                                      as n_trips,
    round(100.0 * count(*) filter (where t.trip_rejection_reason = 'non_positive_duration')
          / count(*), 2)                          as pct_nonpos_duration
from {{ ref('int_trips_flagged') }} as t
inner join {{ ref('cbd_zone_flags') }} as p on t.pickup_zone_id = p.location_id
where t.source_file_month in ('2024-12', '2025-06')
group by t.source_file_month, p.cbd_group
order by t.source_file_month, p.cbd_group