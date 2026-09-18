{{ config(materialized='table') }}

WITH date_spine AS (
    SELECT 
        GENERATE_SERIES(
            '2000-01-01'::DATE, 
            '2026-12-31'::DATE, 
            '1 day'::INTERVAL
        )::DATE AS date_actual
)

SELECT
    date_actual                                 AS date_id,
    EXTRACT(YEAR FROM date_actual)::INT         AS year,
    EXTRACT(QUARTER FROM date_actual)::INT      AS quarter,
    EXTRACT(MONTH FROM date_actual)::INT        AS month,
    TO_CHAR(date_actual, 'Month')               AS month_name,
    TO_CHAR(date_actual, 'YYYY-MM')             AS year_month,
    CONCAT('Q', EXTRACT(QUARTER FROM date_actual)::TEXT, '-', EXTRACT(YEAR FROM date_actual)::TEXT) AS year_quarter
FROM date_spine
