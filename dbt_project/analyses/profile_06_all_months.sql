-- Όλοι οι μήνες δίπλα-δίπλα: όγκος, καθαρισμός, τύπος πληρωμής 0, fee.
select
    source_file_month,
    count(*)                                                                        as n_trips,
    round(100.0 * count(*) filter (where payment_type = 0) / count(*), 2)           as pct_type0,
    round(100.0 * count(*) filter (where not is_valid_trip) / count(*), 3)          as pct_trip_rejected,
    round(100.0 * count(*) filter (where is_valid_trip and not is_valid_for_speed)
          / count(*), 3)                                                            as pct_speed_excluded,
    count(*) filter (where cbd_congestion_fee is null)                              as n_null_fee
from {{ ref('int_trips_flagged') }}
group by source_file_month
order by source_file_month