-- Για κάθε γραμμή με αρνητικό fee: υπάρχει θετική γραμμή που ταιριάζει
-- (ίδια ώρες, ίδιες ζώνες, αντίθετο σύνολο);
with neg as (

    select *
    from {{ ref('int_trips_flagged') }}
    where source_file_month = '2025-01'
      and cbd_congestion_fee < 0

),

pos as (

    select pickup_at, dropoff_at, pickup_zone_id, dropoff_zone_id, total_amount
    from {{ ref('int_trips_flagged') }}
    where source_file_month = '2025-01'
      and total_amount > 0

)

select
    count(*)                                              as n_negative_fee_rows,
    count(*) filter (where exists (
        select 1
        from pos
        where pos.pickup_at       = neg.pickup_at
          and pos.dropoff_at      = neg.dropoff_at
          and pos.pickup_zone_id  = neg.pickup_zone_id
          and pos.dropoff_zone_id = neg.dropoff_zone_id
          and pos.total_amount    = -neg.total_amount
    ))                                                    as n_with_matching_positive
from neg