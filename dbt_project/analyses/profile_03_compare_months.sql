-- Ερώτημα 1: τα ίδια ποσοστά προβλημάτων, δίπλα-δίπλα για κάθε μήνα
WITH t AS (
    SELECT
        regexp_extract(filename, 'yellow_tripdata_([0-9]{4}-[0-9]{2})', 1) AS file_month,
        tpep_pickup_datetime                                               AS pickup_at,
        trip_distance,
        passenger_count,
        date_diff('second', tpep_pickup_datetime, tpep_dropoff_datetime)   AS duration_sec
    FROM read_parquet('data/raw/yellow_tripdata_*.parquet', union_by_name = true, filename = true)
)
SELECT
    file_month,
    count(*) AS n_trips,
    round(100.0 * count(*) FILTER (WHERE strftime(pickup_at, '%Y-%m') <> file_month) / count(*), 4) AS pct_outside_month,
    round(100.0 * count(*) FILTER (WHERE duration_sec <= 0) / count(*), 4)                          AS pct_non_positive_duration,
    round(100.0 * count(*) FILTER (WHERE duration_sec > 4 * 3600) / count(*), 4)                    AS pct_longer_than_4h,
    round(100.0 * count(*) FILTER (WHERE trip_distance = 0) / count(*), 4)                          AS pct_zero_distance,
    round(100.0 * count(*) FILTER (WHERE duration_sec > 0
                                     AND trip_distance / (duration_sec / 3600.0) > 80) / count(*), 4) AS pct_speed_over_80,
    round(100.0 * count(*) FILTER (WHERE passenger_count IS NULL) / count(*), 4)                    AS pct_null_passengers
FROM t
GROUP BY file_month
ORDER BY file_month;

-- Ερώτημα 2: σε ποιον πάροχο (VendorID) ανήκουν τα NULL επιβάτες;
SELECT
    regexp_extract(filename, 'yellow_tripdata_([0-9]{4}-[0-9]{2})', 1) AS file_month,
    VendorID,
    count(*)                                              AS n_trips,
    count(*) FILTER (WHERE passenger_count IS NULL)       AS null_passengers
FROM read_parquet('data/raw/yellow_tripdata_*.parquet', union_by_name = true, filename = true)
GROUP BY file_month, VendorID
ORDER BY file_month, VendorID;