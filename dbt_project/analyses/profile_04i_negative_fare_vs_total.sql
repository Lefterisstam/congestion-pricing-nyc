-- Πότε είναι το κόμιστρο αρνητικό ενώ το σύνολο δεν είναι, και με ποιον τρόπο πληρωμής;
select
    source_file_month,
    payment_type,
    count(*) filter (where fare_amount < 0)                          as n_negative_fare,
    count(*) filter (where fare_amount < 0 and total_amount >= 0)    as n_negative_fare_nonneg_total
from {{ ref('int_trips_flagged') }}
group by source_file_month, payment_type
having count(*) filter (where fare_amount < 0) > 0
order by source_file_month, n_negative_fare desc