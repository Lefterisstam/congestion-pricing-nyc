select
    source_file_month,
    vendor_id,
    payment_type,
    count(*)                                 as n_nonpos_duration,
    count(*) filter (where duration_sec = 0) as n_exactly_zero
from {{ ref('int_trips_flagged') }}
where trip_rejection_reason = 'non_positive_duration'
  and source_file_month in ('2024-12', '2025-06')
group by source_file_month, vendor_id, payment_type
order by source_file_month, n_nonpos_duration desc