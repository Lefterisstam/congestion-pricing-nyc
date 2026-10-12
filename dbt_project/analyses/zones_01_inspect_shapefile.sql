-- Ερώτημα 1: ποιες στήλες έχει το shapefile;
DESCRIBE SELECT * FROM ST_Read('data/raw/taxi_zones/taxi_zones/taxi_zones.shp');

-- Ερώτημα 2: πώς μοιάζουν οι πρώτες γραμμές (χωρίς τη γεωμετρία);
SELECT * EXCLUDE (geom)
FROM ST_Read('data/raw/taxi_zones/taxi_zones/taxi_zones.shp')
LIMIT 5;

-- Ερώτημα 3: σε ποιο εύρος τιμών κινούνται οι συντεταγμένες;
SELECT
    count(*)               AS n_shapes,
    min(ST_XMin(geom))     AS x_min,
    max(ST_XMax(geom))     AS x_max,
    min(ST_YMin(geom))     AS y_min,
    max(ST_YMax(geom))     AS y_max
FROM ST_Read('data/raw/taxi_zones/taxi_zones/taxi_zones.shp');