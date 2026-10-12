-- Το ποσοστό των διαδρομών τύπου 0 ανά ημέρα, και για τους δύο μήνες.
-- Αν η αύξηση γίνεται απότομα γύρω στις 5/1, συμπίπτει με την πολιτική.
select
    pickup_date,
    count(*)                                                             as n_trips,
    round(100.0 * count(*) filter (where payment_type = 0) / count(*), 2) as pct_type0
from {{ ref('int_trips_flagged') }}
where is_valid_trip
group by pickup_date
order by pickup_date