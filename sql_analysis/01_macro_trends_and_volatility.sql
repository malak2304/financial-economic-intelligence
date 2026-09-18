-- ====================================================================
-- Project: Financial & Economic Business Intelligence
-- File: 01_macro_trends_and_volatility.sql
-- Purpose: Descriptive statistics, dispersion (volatility), and time-series momentum
-- ====================================================================

-- --------------------------------------------------------------------
-- Part 1: Overall Summary Statistics & Volatility (Descriptive Stats)
-- Business Value: Identifies the most volatile indicators to evaluate macro risk
-- --------------------------------------------------------------------
SELECT
    dim.indicator_id,
    dim.indicator_name,
    dim.data_source,
    dim.business_domain,
    COUNT(fct.indicator_value)                                      AS observation_count,
    ROUND(AVG(fct.indicator_value)::NUMERIC, 2)                     AS mean_value,
    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY fct.indicator_value
        )::NUMERIC, 2
    )                                                               AS median_value,
    ROUND(STDDEV_SAMP(fct.indicator_value)::NUMERIC, 2)             AS std_deviation,
    ROUND(MIN(fct.indicator_value)::NUMERIC, 2)                     AS min_value,
    ROUND(MAX(fct.indicator_value)::NUMERIC, 2)                     AS max_value,
    ROUND((MAX(fct.indicator_value) - MIN(fct.indicator_value))::NUMERIC, 2) AS value_range
FROM analytics.fct_us_macro_monthly fct
JOIN analytics.dim_indicator dim
    ON fct.indicator_id = dim.indicator_id
GROUP BY dim.indicator_id, dim.indicator_name, dim.data_source, dim.business_domain
ORDER BY std_deviation DESC;

-- --------------------------------------------------------------------
-- Part 2: Monthly & Annual Momentum (MoM & YoY Changes for CPI & M2)
-- Business Value: Pinpoints rapid inflation acceleration & liquidity shocks
-- --------------------------------------------------------------------
WITH lagged_data AS (
    SELECT
        date_id,
        indicator_id,
        indicator_value,
        LAG(indicator_value, 1) OVER (
            PARTITION BY indicator_id 
            ORDER BY date_id
        ) AS val_prev_month,
        LAG(indicator_value, 12) OVER (
            PARTITION BY indicator_id 
            ORDER BY date_id
        ) AS val_prev_year
    FROM analytics.fct_us_macro_monthly
    WHERE indicator_id IN ('CPIAUCSL', 'M2SL', 'FEDFUNDS')
)
SELECT
    date_id,
    indicator_id,
    indicator_value,
    ROUND(
        CASE 
            WHEN val_prev_month IS NOT NULL AND val_prev_month <> 0 
            THEN ((indicator_value - val_prev_month) / val_prev_month) * 100 
        END::NUMERIC, 2
    ) AS mom_growth_pct,
    ROUND(
        CASE 
            WHEN val_prev_year IS NOT NULL AND val_prev_year <> 0 
            THEN ((indicator_value - val_prev_year) / val_prev_year) * 100 
        END::NUMERIC, 2
    ) AS yoy_growth_pct,
    ROUND((indicator_value - val_prev_month)::NUMERIC, 2) AS mom_rate_change_abs
FROM lagged_data
ORDER BY indicator_id, date_id DESC;

-- --------------------------------------------------------------------
-- Part 3: Historical Inflation Extremes (Summary of the 900+ Rows)
-- Business Value: Identifies historical peak and trough inflation regimes
-- --------------------------------------------------------------------
WITH cpi_yoy AS (
    SELECT 
        date_id, 
        indicator_id,
        ROUND(
            (
                (indicator_value - LAG(indicator_value, 12) OVER (PARTITION BY indicator_id ORDER BY date_id)) 
                / NULLIF(LAG(indicator_value, 12) OVER (PARTITION BY indicator_id ORDER BY date_id), 0)
            )::NUMERIC * 100, 2
        ) AS yoy_growth_pct
    FROM analytics.fct_us_macro_monthly
    WHERE indicator_id = 'CPIAUCSL'
)
SELECT 
    indicator_id,
    (ARRAY_AGG(date_id ORDER BY yoy_growth_pct DESC NULLS LAST))[1] AS peak_inflation_date,
    MAX(yoy_growth_pct) AS max_yoy_inflation_pct,
    (ARRAY_AGG(date_id ORDER BY yoy_growth_pct ASC NULLS LAST))[1] AS lowest_inflation_date,
    MIN(yoy_growth_pct) AS min_yoy_inflation_pct,
    ROUND(AVG(yoy_growth_pct)::NUMERIC, 2) AS overall_avg_inflation_pct
FROM cpi_yoy
GROUP BY indicator_id;

