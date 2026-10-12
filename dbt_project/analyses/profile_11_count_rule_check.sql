select
    source_file_month,
    count(*)                                                  as n_trips,
    count(*) filter (where is_valid_trip)                     as n_valid_trip,
    count(*) filter (where is_valid_for_count)                as n_valid_for_count,
    count(*) filter (where is_valid_for_count
                       and not is_valid_trip)                 as n_added_back,
    count(*) filter (where vendor_id = 7
                       and duration_sec = 0)                  as n_vendor7_zero_duration
from {{ ref('int_trips_flagged') }}
where source_file_month in ('2024-12', '2025-01', '2025-06')
group by source_file_month
order by source_file_month