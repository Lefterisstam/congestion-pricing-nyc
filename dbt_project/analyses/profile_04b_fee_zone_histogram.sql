-- Για κάθε ζώνη παραλαβής: ποιο ποσοστό των διαδρομών χρεώθηκε;
-- Μετά ομαδοποιούμε τις ζώνες ανά ποσοστό (histogram).
with per_zone as (

    select
        pickup_zone_id,
        count(*) as n_trips,
        avg(case when cbd_congestion_fee > 0 then 1.0 else 0.0 end) as share_charged
    from {{ ref('int_trips_flagged') }}
    where source_file_month = '2025-01'
      and is_valid_trip
      and pickup_date >= date '2025-01-05'
    group by pickup_zone_id
    having count(*) >= 100

)

select
    round(share_charged * 10) / 10   as share_bucket,
    count(*)                         as n_zones,
    sum(n_trips)                     as n_trips
from per_zone
group by share_bucket
order by share_bucket