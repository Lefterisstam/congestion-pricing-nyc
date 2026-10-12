-- Έλεγχος των δύο σημείων που ορίζουν την 60ή οδό.
-- Αλλάζεις ΜΟΝΟ τις 4 τιμές στο CTE "input".
WITH input AS (
    SELECT
        -73.99077272182181 AS west_lon, 40.77258385138044  AS west_lat,
        -73.98257589148098 AS east_lon, 40.76908999693613  AS east_lat
),
pts AS (
    SELECT
        ST_Transform(ST_Point(west_lon, west_lat), 'EPSG:4326', 'EPSG:2263', always_xy := true) AS w,
        ST_Transform(ST_Point(east_lon, east_lat), 'EPSG:4326', 'EPSG:2263', always_xy := true) AS e
    FROM input
)
SELECT
    round(ST_X(w)) AS west_x_ft,  round(ST_Y(w)) AS west_y_ft,
    round(ST_X(e)) AS east_x_ft,  round(ST_Y(e)) AS east_y_ft,
    round(sqrt(power(ST_X(e) - ST_X(w), 2) + power(ST_Y(e) - ST_Y(w), 2))) AS length_ft,
    round(degrees(atan2(ST_Y(e) - ST_Y(w), ST_X(e) - ST_X(w))), 1)          AS angle_deg,
    (SELECT zone FROM ST_Read('data/raw/taxi_zones/taxi_zones/taxi_zones.shp') z
      WHERE ST_Contains(z.geom, w) LIMIT 1) AS west_zone,
    (SELECT zone FROM ST_Read('data/raw/taxi_zones/taxi_zones/taxi_zones.shp') z
      WHERE ST_Contains(z.geom, e) LIMIT 1) AS east_zone
FROM pts