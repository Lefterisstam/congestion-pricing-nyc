with source as (

    select *
    from read_parquet(
        '../data/raw/yellow_tripdata_*.parquet',
        union_by_name = true,
        filename = true
    )

),

renamed as (

    select
        -- από ποιο αρχείο προήλθε η γραμμή (π.χ. '2024-01')
        regexp_extract(filename, 'yellow_tripdata_([0-9]{4}-[0-9]{2})', 1)  as source_file_month,

        -- χρόνος
        tpep_pickup_datetime                                                as pickup_at,
        tpep_dropoff_datetime                                               as dropoff_at,

        -- τοποθεσία (ζώνες του TLC)
        PULocationID                                                        as pickup_zone_id,
        DOLocationID                                                        as dropoff_zone_id,

        -- διαδρομή
        trip_distance                                                       as trip_distance_miles,
        cast(passenger_count as integer)                                    as passenger_count,
        cast(VendorID as integer)                                           as vendor_id,
        cast(RatecodeID as integer)                                         as rate_code_id,
        cast(payment_type as integer)                                       as payment_type,
        store_and_fwd_flag,

        -- χρεώσεις
        fare_amount,
        extra,
        mta_tax,
        tip_amount,
        tolls_amount,
        improvement_surcharge,
        congestion_surcharge,
        Airport_fee                                                         as airport_fee,
        cbd_congestion_fee,
        total_amount

    from source

)

select * from renamed