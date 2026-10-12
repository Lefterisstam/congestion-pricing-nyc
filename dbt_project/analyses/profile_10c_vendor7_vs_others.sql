select
    case when t.vendor_id = 7 then 'vendor_7' else 'other_vendors' end as vendor_class,
    p.cbd_group                                  as pickup_group,
    count(*)                                     as n_trips,
    round(median(t.trip_distance_miles), 2)      as median_distance_miles,
    round(median(t.fare_amount), 2)              as median_fare
from {{ ref('int_trips_flagged') }} as t
inner join {{ ref('cbd_zone_flags') }} as p
    on t.pickup_zone_id = p.location_id
where t.source_file_month = '2025-06'
group by 1, 2
order by 1, 2