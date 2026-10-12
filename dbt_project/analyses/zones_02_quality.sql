-- Ερώτημα 1: βασικοί έλεγχοι. Υπάρχουν διπλότυπα, κενές ή άκυρες γεωμετρίες;
SELECT
    count(*)                              AS n_rows,
    count(DISTINCT LocationID)            AS n_distinct_ids,
    count(*) FILTER (WHERE geom IS NULL)  AS n_null_geom,
    count(*) FILTER (WHERE NOT ST_IsValid(geom)) AS n_invalid_geom
FROM ST_Read('data/raw/taxi_zones/taxi_zones/taxi_zones.shp');

-- Ερώτημα 2: ζώνες του lookup που ΔΕΝ έχουν σχήμα στο shapefile
SELECT l.LocationID, l.Borough, l.Zone
FROM read_csv('dbt_project/seeds/taxi_zone_lookup.csv') AS l
ANTI JOIN ST_Read('data/raw/taxi_zones/taxi_zones/taxi_zones.shp') AS s
    ON l.LocationID = s.LocationID
ORDER BY l.LocationID;

-- Ερώτημα 3: οι τρεις μεγαλύτερες ζώνες και το Newark Airport, με την επιφάνεια
-- που υπολογίζουμε εμείς (τετραγωνικά πόδια και τετραγωνικά μίλια)
SELECT
    LocationID,
    zone,
    Shape_Area                                AS shape_area_column,
    round(ST_Area(geom))                      AS area_sq_ft,
    round(ST_Area(geom) / 27878400.0, 2)      AS area_sq_miles
FROM ST_Read('data/raw/taxi_zones/taxi_zones/taxi_zones.shp')
WHERE LocationID = 1
   OR LocationID IN (
        SELECT LocationID
        FROM ST_Read('data/raw/taxi_zones/taxi_zones/taxi_zones.shp')
        ORDER BY ST_Area(geom) DESC
        LIMIT 3
   )
ORDER BY area_sq_ft DESC