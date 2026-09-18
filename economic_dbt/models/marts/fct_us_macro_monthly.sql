{{ config(materialized='table') }}

WITH fred_data AS (
    SELECT 
        observation_date,
        series_id,
        indicator_value
    FROM {{ ref('stg_fred_observations') }}
)

SELECT
    observation_date AS date_id,
    'USA'            AS country_iso3,
    series_id        AS indicator_id,
    indicator_value
FROM fred_data
