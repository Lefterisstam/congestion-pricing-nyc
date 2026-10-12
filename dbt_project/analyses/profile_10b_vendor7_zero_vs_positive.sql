select
    case
        when duration_sec = 0 then 'zero_duration'
        when duration_sec > 0 then 'positive_duration'
        else 'negative_duration'
    end                                                  as duration_class,
    count(*)                                             as n_trips,
    round(median(trip_distance_miles), 2)                as median_distance_miles,
    round(median(fare_amount), 2)                        as median_fare,
    round(100.0 * count(*) filter (where trip_distance_miles = 0)
          / count(*), 2)                                 as pct_zero_distance
from {{ ref('int_trips_flagged') }}
where vendor_id = 7
  and source_file_month = '2025-06'
group by 1
order by 1