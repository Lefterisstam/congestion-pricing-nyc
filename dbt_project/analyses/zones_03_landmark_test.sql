-- Δοκιμή μετατροπής συντεταγμένων: ένα γνωστό σημείο πρέπει να πέσει στη σωστή ζώνη.
-- Το ST_Point παίρνει πρώτα το γεωγραφικό ΜΗΚΟΣ (x) και μετά το ΠΛΑΤΟΣ (y).
WITH landmarks AS (
    SELECT 'Times Square' AS name, -73.9855 AS lon, 40.7580 AS lat, 230 AS expected_zone
    UNION ALL
    SELECT 'JFK Airport', -73.7781, 40.6413, 132
    UNION ALL
    SELECT 'LaGuardia Airport', -73.8740, 40.7769, 138
),
points AS (
    SELECT
        *,
        ST_Transform(ST_Point(lon, lat), 'EPSG:4326', 'EPSG:2263', always_xy := true) AS p
    FROM landmarks
)
SELECT
    points.name,
    points.expected_zone,
    z.LocationID AS found_zone,
    z.zone       AS found_zone_name,
    round(ST_X(points.p)) AS x_ft,
    round(ST_Y(points.p)) AS y_ft
FROM points
LEFT JOIN ST_Read('data/raw/taxi_zones/taxi_zones/taxi_zones.shp') AS z
    ON ST_Contains(z.geom, points.p)