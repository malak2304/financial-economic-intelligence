{{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('raw', 'fred_observations') }}
),

renamed AS (
    SELECT
        series_id,
        observation_date::DATE                  AS observation_date,
        value::NUMERIC(18, 4)                  AS indicator_value
    FROM source
    WHERE value IS NOT NULL
)

SELECT * FROM renamed
