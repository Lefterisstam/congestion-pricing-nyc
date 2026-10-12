-- Σε κάθε μήνα: πόσα NULL, πόσα μηδέν, πόσα θετικά στο cbd_congestion_fee;
select
    source_file_month,
    count(*)                                            as n_trips,
    count(*) filter (where cbd_congestion_fee is null)  as n_null,
    count(*) filter (where cbd_congestion_fee = 0)      as n_zero,
    count(*) filter (where cbd_congestion_fee > 0)      as n_positive
from {{ ref('int_trips_flagged') }}
group by source_file_month
order by source_file_month