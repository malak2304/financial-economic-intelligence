-- ====================================================================
-- Project: Financial & Economic Business Intelligence
-- File: 03_cross_country_analysis.sql
-- Purpose: Global Cross-Country Macroeconomic & FinTech Market Opportunity Analysis
-- ====================================================================

-- --------------------------------------------------------------------
-- Part 1: Cross-Country Macroeconomic Summary (2000 - 2024 Benchmarking)
-- Business Value: Evaluates market stability, economic expansion, and inflation risks
-- --------------------------------------------------------------------
SELECT
    c.country_name,
    f.country_iso3,
    ROUND(AVG(CASE WHEN f.indicator_id = 'NY.GDP.MKTP.KD.ZG' THEN f.indicator_value END)::NUMERIC, 2) AS avg_gdp_growth_pct,
    ROUND(AVG(CASE WHEN f.indicator_id = 'FP.CPI.TOTL.ZG' THEN f.indicator_value END)::NUMERIC, 2)    AS avg_inflation_pct,
    ROUND(AVG(CASE WHEN f.indicator_id = 'FS.AST.PRVT.GD.ZS' THEN f.indicator_value END)::NUMERIC, 2) AS avg_private_credit_pct_gdp,
    ROUND(AVG(CASE WHEN f.indicator_id = 'FB.AST.NPL.ZS' THEN f.indicator_value END)::NUMERIC, 2)     AS avg_npl_pct,
    ROUND(AVG(CASE WHEN f.indicator_id = 'BX.TRF.PWKR.DT.GD.ZS' THEN f.indicator_value END)::NUMERIC, 2) AS avg_remittances_pct_gdp
FROM analytics.fct_global_macro_annual f
JOIN analytics.dim_country c
    ON f.country_iso3 = c.country_iso3
GROUP BY c.country_name, f.country_iso3
ORDER BY avg_gdp_growth_pct DESC;


-- --------------------------------------------------------------------
-- Part 2: Recent 5-Year FinTech Market Dynamics (2019 - 2023 Pivot)
-- Business Value: Assesses modern credit penetration vs alternative financial flows
-- --------------------------------------------------------------------
SELECT
    f.observation_year,
    c.country_name,
    MAX(CASE WHEN f.indicator_id = 'FS.AST.PRVT.GD.ZS' THEN ROUND(f.indicator_value::NUMERIC, 2) END) AS domestic_credit_pct_gdp,
    MAX(CASE WHEN f.indicator_id = 'BX.TRF.PWKR.DT.GD.ZS' THEN ROUND(f.indicator_value::NUMERIC, 2) END) AS remittances_pct_gdp,
    MAX(CASE WHEN f.indicator_id = 'FB.AST.NPL.ZS' THEN ROUND(f.indicator_value::NUMERIC, 2) END) AS bank_npl_pct
FROM analytics.fct_global_macro_annual f
JOIN analytics.dim_country c
    ON f.country_iso3 = c.country_iso3
WHERE f.observation_year >= 2019
GROUP BY f.observation_year, c.country_name
ORDER BY f.observation_year DESC, domestic_credit_pct_gdp DESC NULLS LAST;

