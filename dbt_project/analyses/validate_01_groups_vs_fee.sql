-- Ground truth: οι κατηγορίες που ορίσαμε από τη γεωγραφία, αντιστοιχούν σε χρεώσεις;
-- Χρησιμοποιούμε cbd_congestion_fee <> 0 ώστε να μετρούν και οι αντιλογισμοί (-0.75),
-- γιατί και αυτές οι διαδρομές άγγιξαν το CBD.
with trips as (

    select
        p.cbd_group as pickup_group,
        d.cbd_group as dropoff_group,
        t.cbd_congestion_fee
    from {{ ref('int_trips_flagged') }} as t
    inner join {{ ref('cbd_zone_flags') }} as p on t.pickup_zone_id  = p.location_id
    inner join {{ ref('cbd_zone_flags') }} as d on t.dropoff_zone_id = d.location_id
    where t.source_file_month = '2025-01'
      and t.is_valid_trip
      and t.pickup_date >= date '2025-01-05'

)

select
    pickup_group,
    dropoff_group,
    count(*) as n_trips,
    round(100.0 * count(*) filter (where cbd_congestion_fee <> 0) / count(*), 2) as pct_fee
from trips
group by pickup_group, dropoff_group
order by n_trips desc