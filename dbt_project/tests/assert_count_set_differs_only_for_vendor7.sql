select *
from {{ ref('int_trips_flagged') }}
where (is_valid_trip and not is_valid_for_count)
   or (
        is_valid_for_count
        and not is_valid_trip
        and not (coalesce(vendor_id, -1) = 7 and duration_sec = 0)
      )