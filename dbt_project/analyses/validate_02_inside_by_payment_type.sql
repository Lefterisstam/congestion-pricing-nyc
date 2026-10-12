-- Στις διαδρομές inside -> inside: πώς κατανέμεται η χρέωση ανά τύπο πληρωμής;
select
    t.payment_type,
    count(*) as n_trips,
    round(100.0 * count(*) filter (where t.cbd_congestion_fee <> 0) / count(*), 2) as pct_fee
from {{ ref('int_trips_flagged') }} as t
inner join {{ ref('cbd_zone_flags') }} as p on t.pickup_zone_id  = p.location_id
inner join {{ ref('cbd_zone_flags') }} as d on t.dropoff_zone_id = d.location_id
where t.source_file_month = '2025-01'
  and t.is_valid_trip
  and t.pickup_date >= date '2025-01-05'
  and p.cbd_group = 'inside'
  and d.cbd_group = 'inside'
group by t.payment_type
order by n_trips desc