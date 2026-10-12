select
    source_file_month,
    count(*)                                             as n_vendor7_trips,
    count(*) filter (where duration_sec = 0)             as n_zero_duration,
    count(*) filter (where duration_sec < 0)             as n_negative_duration,
    round(100.0 * count(*) filter (where duration_sec = 0)
          / count(*), 2)                                 as pct_zero_duration
from {{ ref('int_trips_flagged') }}
where vendor_id = 7
group by source_file_month
order by source_file_month