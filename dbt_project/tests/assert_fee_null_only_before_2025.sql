select *
from {{ ref('stg_yellow_trips') }}
where (source_file_month >= '2025-01' and cbd_congestion_fee is null)
   or (source_file_month <  '2025-01' and cbd_congestion_fee is not null)