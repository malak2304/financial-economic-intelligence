{{ config(materialized='table') }}

WITH us_fred_annual AS (
    SELECT
        EXTRACT(YEAR FROM observation_date)::INT AS observation_year,
        'USA'                                    AS country_iso3,
        series_id                                AS indicator_id,
        AVG(indicator_value)::NUMERIC(18, 4)     AS indicator_value
    FROM {{ ref('stg_fred_observations') }}
    GROUP BY 1, 2, 3
),

world_bank_annual AS (
    SELECT
        observation_year,
        country_iso3,
        indicator_code  AS indicator_id,
        indicator_value
    FROM {{ ref('stg_world_bank_observations') }}
)

SELECT * FROM us_fred_annual
UNION ALL
SELECT * FROM world_bank_annual
