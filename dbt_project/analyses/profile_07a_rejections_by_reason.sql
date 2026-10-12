select
    source_file_month,
    count(*) as n_trips,
    count(*) filter (where trip_rejection_reason = 'pickup_outside_file_month') as n_outside_month,
    count(*) filter (where trip_rejection_reason = 'non_positive_duration')     as n_nonpos_duration,
    count(*) filter (where trip_rejection_reason = 'duration_too_long')         as n_too_long
from {{ ref('int_trips_flagged') }}
group by source_file_month
order by source_file_month