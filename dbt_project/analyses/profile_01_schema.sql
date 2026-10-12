-- Ερώτημα 1: ποιες στήλες και τι τύπους έχει το αρχείο του Ιανουαρίου 2024;
DESCRIBE SELECT * FROM read_parquet('data/raw/yellow_tripdata_2024-01.parquet');

-- Ερώτημα 2: το ίδιο για τον Ιανουάριο 2025
DESCRIBE SELECT * FROM read_parquet('data/raw/yellow_tripdata_2025-01.parquet');

-- Ερώτημα 3: ποιες στήλες υπάρχουν μόνο στο ένα έτος, ή έχουν διαφορετικό τύπο;
WITH y2024 AS (
    SELECT column_name, column_type
    FROM (DESCRIBE SELECT * FROM read_parquet('data/raw/yellow_tripdata_2024-01.parquet'))
),
y2025 AS (
    SELECT column_name, column_type
    FROM (DESCRIBE SELECT * FROM read_parquet('data/raw/yellow_tripdata_2025-01.parquet'))
)
SELECT
    column_name,
    y2024.column_type AS type_2024,
    y2025.column_type AS type_2025
FROM y2024
FULL OUTER JOIN y2025 USING (column_name)
WHERE y2024.column_type IS DISTINCT FROM y2025.column_type
ORDER BY column_name;