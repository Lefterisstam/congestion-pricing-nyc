select cbd_group, count(*) as n_zones
from {{ ref('cbd_zone_flags') }}
group by cbd_group
order by n_zones desc