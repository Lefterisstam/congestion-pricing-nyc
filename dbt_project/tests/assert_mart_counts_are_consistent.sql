select *
from {{ ref('mart_route_day') }}
where n_trips_excl_type0        > n_trips
   or n_trips_strict            > n_trips
   or n_trips_strict_excl_type0 > n_trips_strict
   or n_trips_speed             > n_trips_strict
   or n_fee_trips_strict        > n_trips_strict