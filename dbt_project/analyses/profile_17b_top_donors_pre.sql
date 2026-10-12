-- Οι 20 μεγαλύτερες ζώνες-δότες στο «πριν» (έλεγχος λογικής των ονομάτων). ΜΟΝΟ δεδομένα «πριν».
select
    pickup_zone_id,
    pickup_zone_name,
    round(sum(n_trips) * 1.0 / count(*)) as avg_trips_day,
    count(*) filter (where n_trips = 0)  as zero_days,
    round(sum(n_type0_trips) * 1.0 / nullif(sum(n_trips), 0), 3) as type0_share
from {{ ref('mart_control_zone_day') }}
where pickup_date < date '{{ var("policy_start_date") }}'
group by pickup_zone_id, pickup_zone_name
order by avg_trips_day desc
