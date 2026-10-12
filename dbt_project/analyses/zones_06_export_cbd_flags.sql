-- Παράγει το seed cbd_zone_flags.csv: μία γραμμή ανά ζώνη του TLC (265 συνολικά).
-- Αν αλλάξουν τα δύο σημεία της 60ής ή τα όρια, τρέξε το ξανά και ξαναφόρτωσε το seed.
COPY (
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
    ),
    vec AS (
        SELECT
            ST_X(w) AS wx, ST_Y(w) AS wy,
            (ST_X(e) - ST_X(w)) / sqrt(power(ST_X(e) - ST_X(w), 2) + power(ST_Y(e) - ST_Y(w), 2)) AS ux,
            (ST_Y(e) - ST_Y(w)) / sqrt(power(ST_X(e) - ST_X(w), 2) + power(ST_Y(e) - ST_Y(w), 2)) AS uy
        FROM pts
    ),
    half_plane AS (
        SELECT ST_GeomFromText(format(
            'POLYGON(({} {}, {} {}, {} {}, {} {}, {} {}))',
            wx - ux * 200000,                 wy - uy * 200000,
            wx + ux * 200000,                 wy + uy * 200000,
            wx + ux * 200000 + uy * 200000,   wy + uy * 200000 - ux * 200000,
            wx - ux * 200000 + uy * 200000,   wy - uy * 200000 - ux * 200000,
            wx - ux * 200000,                 wy - uy * 200000
        )) AS poly
        FROM vec
    ),
    shares AS (
        SELECT
            z.LocationID AS location_id,
            ST_Area(ST_Intersection(z.geom, h.poly)) / ST_Area(z.geom) AS share_south
        FROM ST_Read('data/raw/taxi_zones/taxi_zones/taxi_zones.shp') AS z
        CROSS JOIN half_plane AS h
        WHERE z.borough = 'Manhattan'
    )
    SELECT
        l.LocationID                 AS location_id,
        l.Zone                       AS zone_name,
        l.Borough                    AS borough,
        round(s.share_south, 3)      AS share_south,
        CASE
            WHEN l.LocationID IN (264, 265) THEN 'unknown'
            WHEN s.share_south >= 0.5       THEN 'inside'
            WHEN s.share_south >= 0.01      THEN 'near_border'
            ELSE 'outside'
        END                          AS cbd_group
    FROM read_csv('dbt_project/seeds/taxi_zone_lookup.csv') AS l
    LEFT JOIN shares AS s ON s.location_id = l.LocationID
    ORDER BY l.LocationID
) TO 'dbt_project/seeds/cbd_zone_flags.csv' (HEADER, DELIMITER ',')