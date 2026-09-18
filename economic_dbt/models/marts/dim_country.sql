{{ config(materialized='table') }}

WITH countries_from_wb AS (
    SELECT DISTINCT
        country_iso3,
        country_name
    FROM {{ ref('stg_world_bank_observations') }}
)

SELECT
    country_iso3,
    country_name
FROM countries_from_wb
