{{ config(materialized='table') }}

WITH fred_indicators AS (
    SELECT DISTINCT
        series_id AS indicator_id,
        CASE 
            WHEN series_id = 'FEDFUNDS' THEN 'Federal Funds Effective Rate'
            WHEN series_id = 'CPIAUCSL' THEN 'Consumer Price Index for All Urban Consumers'
            WHEN series_id = 'UNRATE'   THEN 'Unemployment Rate'
            WHEN series_id = 'GDPC1'    THEN 'Real Gross Domestic Product'
            WHEN series_id = 'GS10'     THEN '10-Year Treasury Constant Maturity Rate'
            WHEN series_id = 'M2SL'     THEN 'M2 Money Supply'
            ELSE series_id
        END AS indicator_name,
        'FRED' AS data_source,
        CASE 
            WHEN series_id IN ('FEDFUNDS', 'GS10') THEN 'Interest Rates & Monetary Policy'
            WHEN series_id = 'CPIAUCSL' THEN 'Inflation & Prices'
            WHEN series_id = 'UNRATE' THEN 'Labor Market'
            WHEN series_id = 'GDPC1' THEN 'Economic Growth'
            WHEN series_id = 'M2SL' THEN 'Liquidity & Money Supply'
            ELSE 'Macroeconomic'
        END AS business_domain
    FROM {{ ref('stg_fred_observations') }}
),

world_bank_indicators AS (
    SELECT DISTINCT
        indicator_code AS indicator_id,
        indicator_name,
        'World Bank' AS data_source,
        CASE 
            WHEN indicator_code = 'NY.GDP.MKTP.KD.ZG' THEN 'Economic Growth'
            WHEN indicator_code = 'FP.CPI.TOTL.ZG' THEN 'Inflation & Prices'
            WHEN indicator_code = 'FS.AST.PRVT.GD.ZS' THEN 'Financial Depth'
            WHEN indicator_code = 'FB.AST.NPL.ZS' THEN 'Financial Health & Credit Risk'
            WHEN indicator_code = 'BX.TRF.PWKR.DT.GD.ZS' THEN 'Remittances & Inflows'
            ELSE 'Development'
        END AS business_domain
    FROM {{ ref('stg_world_bank_observations') }}
)

SELECT * FROM fred_indicators
UNION ALL
SELECT * FROM world_bank_indicators
