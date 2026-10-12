-- Οι ζώνες με το μεγαλύτερο ποσοστό χρέωσης, με ονόματα.
select
    p.pickup_zone_id,
    z.Borough,
    z.Zone,
    p.n_trips,
    round(p.share_charged, 3) as share_charged
from (
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
) as p
inner join {{ ref('taxi_zone_lookup') }} as z
    on p.pickup_zone_id = z.LocationID
order by p.share_charged desc, p.n_trips desc