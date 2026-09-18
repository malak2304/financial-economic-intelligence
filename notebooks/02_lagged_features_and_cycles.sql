-- ====================================================================
-- Project: Financial & Economic Business Intelligence
-- File: 02_lagged_features_and_cycles.sql
-- Purpose: Yield curve spread calculation and policy transmission cycles
-- ====================================================================

-- --------------------------------------------------------------------
-- Part 1: Yield Curve Spread (10-Year Treasury minus Fed Funds Rate)
-- Business Value: Detects yield curve inversions (classic recession signal)
-- --------------------------------------------------------------------
WITH us_rates AS (
    SELECT
        date_id,
        MAX(CASE WHEN indicator_id = 'GS10' THEN indicator_value END)      AS treasury_10y,
        MAX(CASE WHEN indicator_id = 'FEDFUNDS' THEN indicator_value END)  AS fed_funds_rate
    FROM analytics.fct_us_macro_monthly
    WHERE indicator_id IN ('GS10', 'FEDFUNDS')
    GROUP BY date_id
)
SELECT
    date_id,
    treasury_10y,
    fed_funds_rate,
    ROUND((treasury_10y - fed_funds_rate)::NUMERIC, 2) AS yield_curve_spread,
    CASE 
        WHEN (treasury_10y - fed_funds_rate) < 0 THEN 'Inverted (Recession Warning)'
        WHEN (treasury_10y - fed_funds_rate) BETWEEN 0 AND 0.5 THEN 'Flat'
        ELSE 'Normal'
    END AS curve_status
FROM us_rates
WHERE treasury_10y IS NOT NULL AND fed_funds_rate IS NOT NULL
ORDER BY date_id DESC;


-- --------------------------------------------------------------------
-- Part 2: Monetary Policy Lag Analysis (Fed Funds vs Subsequent Inflation)
-- Business Value: Evaluates how rate hikes correlate with future CPI moves
-- --------------------------------------------------------------------
WITH monthly_macro AS (
    SELECT
        date_id,
        MAX(CASE WHEN indicator_id = 'FEDFUNDS' THEN indicator_value END) AS fed_funds,
        MAX(CASE WHEN indicator_id = 'CPIAUCSL' THEN indicator_value END) AS cpi
    FROM analytics.fct_us_macro_monthly
    WHERE indicator_id IN ('FEDFUNDS', 'CPIAUCSL')
    GROUP BY date_id
),
macro_with_lead AS (
    SELECT
        date_id,
        fed_funds,
        cpi,
        LEAD(cpi, 6) OVER (ORDER BY date_id)  AS cpi_lead_6m,
        LEAD(cpi, 12) OVER (ORDER BY date_id) AS cpi_lead_12m
    FROM monthly_macro
)
SELECT
    date_id,
    fed_funds,
    cpi,
    ROUND((((cpi_lead_6m - cpi) / NULLIF(cpi, 0)) * 100)::NUMERIC, 2)   AS cpi_change_next_6m_pct,
    ROUND((((cpi_lead_12m - cpi) / NULLIF(cpi, 0)) * 100)::NUMERIC, 2)  AS cpi_change_next_12m_pct
FROM macro_with_lead
WHERE fed_funds IS NOT NULL AND cpi IS NOT NULL
ORDER BY date_id DESC;

