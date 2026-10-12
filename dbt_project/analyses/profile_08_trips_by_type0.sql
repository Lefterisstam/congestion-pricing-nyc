select
    source_file_month,
    count(*)                                 as n_trips,
    count(*) filter (where payment_type = 0) as n_type0,
    count(*) filter (where payment_type <> 0) as n_other
from {{ ref('int_trips_flagged') }}
group by source_file_month
order by source_file_month