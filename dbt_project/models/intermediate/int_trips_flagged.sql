with trips as (

    select * from {{ ref('stg_yellow_trips') }}

),

with_metrics as (

    select
        *,
        cast(pickup_at as date)                                  as pickup_date,
        date_diff('second', pickup_at, dropoff_at)               as duration_sec,
        strftime(pickup_at, '%Y-%m') = source_file_month         as is_pickup_in_file_month
    from trips

),

with_speed as (

    select
        *,
        -- ταχύτητα σε μίλια/ώρα. Αν η διάρκεια δεν είναι θετική, η ταχύτητα είναι άγνωστη (NULL)
        case
            when duration_sec > 0
            then trip_distance_miles / (duration_sec / 3600.0)
        end                                                      as speed_mph
    from with_metrics

),

with_trip_reason as (

    select
        *,
        -- ο ΠΡΩΤΟΣ κανόνας που αποτυγχάνει κερδίζει, ώστε κάθε γραμμή να έχει το πολύ ένα λόγο
        case
            when not is_pickup_in_file_month                                 then 'pickup_outside_file_month'
            when duration_sec <= 0                                           then 'non_positive_duration'
            when duration_sec > {{ var('max_duration_hours') }} * 3600       then 'duration_too_long'
        end                                                      as trip_rejection_reason
    from with_speed

),

with_speed_reason as (

    select
        *,
        -- ισχύει μόνο για γραμμές που πέρασαν ήδη τον πρώτο έλεγχο
        case
            when trip_rejection_reason is not null                           then null
            when trip_distance_miles <= 0                                    then 'zero_distance'
            when trip_distance_miles > {{ var('max_distance_miles') }}       then 'distance_too_long'
            when speed_mph > {{ var('max_speed_mph') }}                      then 'speed_too_high'
        end                                                      as speed_exclusion_reason
    from with_trip_reason

),

final as (

    select
        *,
        (trip_rejection_reason is null)                                      as is_valid_trip,
        (trip_rejection_reason is null and speed_exclusion_reason is null)   as is_valid_for_speed,
        -- για το ΠΛΗΘΟΣ διαδρομών: όπως is_valid_trip, αλλά οι διαδρομές της
        -- εταιρείας 7 με διάρκεια ακριβώς 0 ΔΕΝ απορρίπτονται
        (
            trip_rejection_reason is null
            or (
                trip_rejection_reason = 'non_positive_duration'
                and coalesce(vendor_id, -1) = 7
                and duration_sec = 0
            )
        )                                                                    as is_valid_for_count
    from with_speed_reason

)

select * from final