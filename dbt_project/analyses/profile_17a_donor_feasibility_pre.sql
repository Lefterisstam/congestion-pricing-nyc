-- Εφικτότητα του synthetic control. ΜΟΝΟ δεδομένα «πριν».
-- Πόσες ζώνες-δότες έχουν μέσο όρο τουλάχιστον Χ διαδρομές ανά ημέρα, και τι μερίδιο του όγκου της Αναφοράς καλύπτουν.
with zone_pre as (

    select
        pickup_zone_id,
        sum(n_trips) * 1.0 / count(*) as avg_trips_day
    from {{ ref('mart_control_zone_day') }}
    where pickup_date < date '{{ var("policy_start_date") }}'
    group by pickup_zone_id

)

select
    t.threshold                                                    as min_trips_per_day,
    count(z.pickup_zone_id)                                        as n_zones,
    round(sum(z.avg_trips_day) / (select sum(avg_trips_day) from zone_pre), 3) as share_of_control_volume
from (values (20), (50), (100), (200), (500)) as t(threshold)
left join zone_pre as z
    on z.avg_trips_day >= t.threshold
group by t.threshold
order by t.threshold