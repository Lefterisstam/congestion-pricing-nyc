select
    source_file_month,
    round(100.0 * count(*) filter (where not is_valid_trip and payment_type = 0)
          / nullif(count(*) filter (where payment_type = 0), 0), 3)  as pct_rejected_in_type0,
    round(100.0 * count(*) filter (where not is_valid_trip and payment_type <> 0)
          / nullif(count(*) filter (where payment_type <> 0), 0), 3) as pct_rejected_in_other
from {{ ref('int_trips_flagged') }}
group by source_file_month
order by source_file_month