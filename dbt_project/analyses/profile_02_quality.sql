-- Ερώτημα 1: μέγεθος του αρχείου και εύρος ημερομηνιών παραλαβής
SELECT
    count(*)                    AS n_trips,
    min(tpep_pickup_datetime)   AS first_pickup,
    max(tpep_pickup_datetime)   AS last_pickup
FROM read_parquet('data/raw/yellow_tripdata_2024-01.parquet');

-- Ερώτημα 2: πόσες διαδρομές έχουν παραλαβή ΕΞΩ από τον Ιανουάριο 2024;
SELECT
    count(*) FILTER (WHERE tpep_pickup_datetime <  TIMESTAMP '2024-01-01'
                        OR tpep_pickup_datetime >= TIMESTAMP '2024-02-01') AS outside_month,
    count(*)                                                               AS total
FROM read_parquet('data/raw/yellow_tripdata_2024-01.parquet');

-- Ερώτημα 3: πόσες γραμμές έχουν προβληματική διάρκεια, απόσταση ή ταχύτητα;
WITH t AS (
    SELECT
        *,
        date_diff('second', tpep_pickup_datetime, tpep_dropoff_datetime) AS duration_sec
    FROM read_parquet('data/raw/yellow_tripdata_2024-01.parquet')
)
SELECT
    count(*) FILTER (WHERE duration_sec <= 0)        AS non_positive_duration,
    count(*) FILTER (WHERE duration_sec > 4 * 3600)  AS longer_than_4h,
    count(*) FILTER (WHERE trip_distance = 0)        AS zero_distance,
    count(*) FILTER (WHERE trip_distance > 100)      AS over_100_miles,
    count(*) FILTER (WHERE duration_sec > 0
                       AND trip_distance / (duration_sec / 3600.0) > 80) AS speed_over_80mph
FROM t;

-- Ερώτημα 4: πόσα κενά (NULL) έχουν οι σημαντικές στήλες;
SELECT
    count(*) - count(passenger_count)  AS null_passenger_count,
    count(*) - count(PULocationID)     AS null_pickup_zone,
    count(*) - count(DOLocationID)     AS null_dropoff_zone,
    count(*) - count(trip_distance)    AS null_distance,
    count(*) - count(total_amount)     AS null_total_amount
FROM read_parquet('data/raw/yellow_tripdata_2024-01.parquet');

-- Ερώτημα 5: η κατανομή της απόστασης και της διάρκειας (διάμεσος, ακραία)
WITH t AS (
    SELECT
        trip_distance,
        date_diff('second', tpep_pickup_datetime, tpep_dropoff_datetime) / 60.0 AS duration_min
    FROM read_parquet('data/raw/yellow_tripdata_2024-01.parquet')
)
SELECT
    quantile_cont(trip_distance, 0.01) AS dist_p01,
    quantile_cont(trip_distance, 0.50) AS dist_median,
    quantile_cont(trip_distance, 0.99) AS dist_p99,
    max(trip_distance)                 AS dist_max,
    quantile_cont(duration_min, 0.01)  AS dur_p01_min,
    quantile_cont(duration_min, 0.50)  AS dur_median_min,
    quantile_cont(duration_min, 0.99)  AS dur_p99_min,
    max(duration_min)                  AS dur_max_min
FROM t;