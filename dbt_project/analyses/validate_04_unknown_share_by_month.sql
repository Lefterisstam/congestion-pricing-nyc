select
    t.source_file_month,
    count(*) as n_trips,
    round(100.0 * count(*) filter (where p.cbd_group = 'unknown' or d.cbd_group = 'unknown')
          / count(*), 3) as pct_unknown
from {{ ref('int_trips_flagged') }} as t
inner join {{ ref('cbd_zone_flags') }} as p on t.pickup_zone_id  = p.location_id
inner join {{ ref('cbd_zone_flags') }} as d on t.dropoff_zone_id = d.location_id
where t.is_valid_trip
group by t.source_file_month
order by t.source_file_month