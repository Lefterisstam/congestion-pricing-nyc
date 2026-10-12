select *
from {{ ref('int_trips_flagged') }}
where is_valid_for_speed
  and speed_mph > {{ var('max_speed_mph') }}