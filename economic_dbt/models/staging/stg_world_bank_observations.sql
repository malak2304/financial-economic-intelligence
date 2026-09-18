{{ config(materialized='view') }}

WITH source AS (
    SELECT * FROM {{ source('raw', 'world_bank_indicators') }}
),

renamed AS (
    SELECT
        country_iso3,
        country_name,
        indicator_code,
        indicator_name,
        observation_year::INTEGER               AS observation_year,
        value::NUMERIC(18, 4)                  AS indicator_value
    FROM source
    WHERE value IS NOT NULL
)

SELECT * FROM renamed
