-- Συμφωνία του intermediate με το profiling, Ιανουάριος 2024.
-- Αναμένουμε: nonpos_dist_and_rejected - negative_distance = 786
--             fast_but_other_reason = 30
select
    count(*) filter (where trip_distance_miles <= 0
                       and trip_rejection_reason is not null)      as nonpos_dist_and_rejected,
    count(*) filter (where trip_distance_miles < 0)                as negative_distance,
    count(*) filter (where speed_mph > 80
                       and (trip_rejection_reason is not null
                            or trip_distance_miles > 100))         as fast_but_other_reason
from {{ ref('int_trips_flagged') }}
where source_file_month = '2024-01'