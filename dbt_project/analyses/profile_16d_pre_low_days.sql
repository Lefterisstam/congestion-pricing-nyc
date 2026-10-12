-- Ημέρες με ύποπτα χαμηλό συνολικό αριθμό διαδρομών (πιθανό κενό στα δεδομένα). ΜΟΝΟ δεδομένα «πριν».
-- Σύγκριση κάθε ημέρας με τη διάμεσο των ίδιων ημερών της εβδομάδας, 1 έως 4 εβδομάδες πριν ή μετά.
-- Μετράμε ΟΛΕΣ τις διαδρομές όλων των ομάδων (όχι ανά ομάδα και όχι δείκτη αποτελέσματος).
with daily as (
    select
        pickup_date,
        sum(n_trips) as total
    from {{ ref('mart_route_day') }}
    where pickup_date < date '{{ var("policy_start_date") }}'
    group by 1
),

ref as (
    select
        a.pickup_date,
        median(b.total) as ref_total
    from daily a
    join daily b
      on dayofweek(a.pickup_date) = dayofweek(b.pickup_date)
     and abs(date_diff('day', a.pickup_date, b.pickup_date)) between 7 and 28
    group by 1
)

select
    d.pickup_date,
    dayname(d.pickup_date)                 as dow,
    d.total,
    round(r.ref_total)                     as ref_total,
    round(d.total * 1.0 / r.ref_total, 2)  as share_of_normal
from daily d
join ref r using (pickup_date)
where d.total < 0.6 * r.ref_total
order by d.pickup_date