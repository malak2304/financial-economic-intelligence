# 📊 Data Dictionary & Data Architecture

This document provides a comprehensive overview of the data architecture, data modeling methodology, schemas, and detailed descriptions of all entities and attributes used in the **Financial & Economic Intelligence Platform**.

---

## 1. Architectural Overview & Modeling Approach

The data warehouse is designed following the **Kimball Dimensional Modeling** methodology. Due to differing temporal granularities between domestic high-frequency series (monthly) and international indicators (annual), the warehouse implements a **Fact Constellation Schema (Galaxy Schema)**.

* **Schema `raw`:** Ingestion staging area where raw payloads from FRED and World Bank APIs are landed idempotently without alteration.
* **Schema `analytics`:** The analytical data mart modeled and validated via **dbt** (Data Build Tool), housing conformed dimensions and granular fact tables optimized for analytical SQL and Power BI dashboards.

### Entity Relationship Diagram (Galaxy Schema)

```text
               +-----------------------+
               |      dim_country      |
               +-----------------------+
               | PK: country_iso3      |
               +-----------+-----------+
                           |
             +-------------+-------------+
             |                           |
             v                           v
+--------------------------+   +--------------------------+
|  fct_us_macro_monthly    |   |  fct_global_macro_annual |
+--------------------------+   +--------------------------+
| PK: record_id            |   | PK: record_id            |
| FK: date_key             |   | FK: year_key             |
| FK: country_iso3         |   | FK: country_iso3         |
| Measures: fed_funds,     |   | Measures: gdp_growth,    |
|   cpi, unemp, 10y, 2y,   |   |   inflation, lending_rate|
|   yield_spread, etc.     |   +-------------+------------+
+------------+-------------+                 |
             |                               |
             +-------------+-----------------+
                           |
                           v
               +-----------------------+
               |        dim_date       |
               +-----------------------+
               | PK: date_key          |
               | Attributes: year,     |
               |   month, quarter, etc |
               +-----------------------+
```

---

## 2. Conformed Dimensions (`analytics`)

### `dim_date`
Provides a uniform temporal reference for all analytical and time-series rollups.
* **Grain:** One record per calendar month / observation date.
* **Primary Key:** `date_key`

| Column Name | Data Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `date_key` | `DATE` | Primary Key representing the observation date (YYYY-MM-DD) | `2023-01-01` |
| `full_date` | `DATE` | Full calendar date representation | `2023-01-01` |
| `year` | `INTEGER` | Calendar year | `2023` |
| `quarter` | `INTEGER` | Calendar quarter (1 to 4) | `1` |
| `quarter_name` | `VARCHAR` | Quarter display label | `Q1-2023` |
| `month` | `INTEGER` | Calendar month number (1 to 12) | `1` |
| `month_name` | `VARCHAR` | Full name of the calendar month | `January` |
| `year_month` | `VARCHAR` | Standardized monthly period string (YYYY-MM) | `2023-01` |

---

### `dim_country`
Conformed geographical dimension standardizing country attributes and regional classifications across US-specific and cross-country comparisons.
* **Grain:** One record per sovereign country.
* **Primary Key:** `country_iso3`

| Column Name | Data Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `country_iso3` | `VARCHAR(3)` | ISO 3166-1 alpha-3 standardized country code (Primary Key) | `USA`, `EGY`, `ARE` |
| `country_name` | `VARCHAR` | Official common name of the sovereign entity | `United States`, `Egypt` |
| `region` | `VARCHAR` | Geographic and economic regional classification | `North America`, `MENA` |
| `income_group` | `VARCHAR` | World Bank income bracket classification | `High income`, `Lower middle income` |

---

### `dim_indicator`
Metadata repository defining economic series definitions, reporting frequency, and measurement units.
* **Grain:** One record per macro metric.
* **Primary Key:** `indicator_id`

| Column Name | Data Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `indicator_id` | `VARCHAR` | Unique metric identifier / series code | `FEDFUNDS`, `FP.CPI.TOTL.ZG` |
| `indicator_name`| `VARCHAR` | Standardized descriptive name of the indicator | `Federal Funds Effective Rate` |
| `category` | `VARCHAR` | Economic domain (Monetary Policy, Labor, Inflation, Output) | `Monetary Policy` |
| `unit` | `VARCHAR` | Unit of measure | `Percent`, `Index (2015=100)` |
| `data_source` | `VARCHAR` | Source reporting institution / API platform | `FRED`, `World Bank` |

---

## 3. Fact Tables (`analytics`)

### `fct_us_macro_monthly`
High-frequency US macroeconomic data combining monetary policy rates, inflation metrics, labor statistics, and sovereign debt yields.
* **Grain:** One record per month for the United States.
* **Primary Key:** `record_id` (Surrogate MD5 hash key)

| Column Name | Data Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `record_id` | `VARCHAR(32)` | Unique surrogate MD5 hash key (`date_key` + `country_iso3`) | `e4d909c290d0fb1ca068ffaddf22cbd0` |
| `date_key` | `DATE` | Foreign key referencing `dim_date` | `2023-06-01` |
| `country_iso3` | `VARCHAR(3)` | Foreign key referencing `dim_country` (default: `USA`) | `USA` |
| `fed_funds_rate` | `NUMERIC(6,3)`| Federal Funds Effective Rate (%) | `5.080` |
| `cpi_index` | `NUMERIC(8,3)`| Consumer Price Index for All Urban Consumers | `304.382` |
| `unemployment_rate` | `NUMERIC(4,2)`| Civilian Unemployment Rate (%) | `3.60` |
| `treasury_10y_yield` | `NUMERIC(6,3)`| 10-Year Treasury Constant Maturity Rate (%) | `3.750` |
| `treasury_2y_yield` | `NUMERIC(6,3)`| 2-Year Treasury Constant Maturity Rate (%) | `4.640` |
| `yield_spread_10y_2y`| `NUMERIC(6,3)`| Yield curve slope (`10y - 2y`). Inversion (< 0) signals recession risk | `-0.890` |

---

### `fct_global_macro_annual`
Annual macroeconomic panel data tracking cross-border growth, trade balances, and financial health indicators across comparative economies.
* **Grain:** One record per country per calendar year.
* **Primary Key:** `record_id` (Surrogate MD5 hash key)

| Column Name | Data Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `record_id` | `VARCHAR(32)` | Unique surrogate MD5 hash key (`year` + `country_iso3`) | `b94d27b9934d3e08a52e52d7da7dabfa` |
| `year_key` | `INTEGER` | Reference year matching `dim_date.year` | `2023` |
| `country_iso3` | `VARCHAR(3)` | Foreign key referencing `dim_country` | `EGY` |
| `gdp_growth_pct` | `NUMERIC(6,3)`| Annual percentage growth rate of GDP at market prices | `3.760` |
| `inflation_cpi_pct` | `NUMERIC(6,3)`| Annual inflation rate, consumer prices (%) | `33.880` |
| `domestic_credit_pct_gdp` | `NUMERIC(6,3)`| Domestic credit provided to private sector (% of GDP) | `27.450` |
| `bank_npl_pct` | `NUMERIC(6,3)`| Bank non-performing loans to gross loans (%) | `3.400` |
| `remittances_pct_gdp` | `NUMERIC(6,3)`| Personal remittances received (% of GDP) | `6.120` |

---

## 4. Staging & Raw Source Data (`raw`)

Raw data ingested directly via automated Python ELT workers:
* **`raw.fred_observations`:** Stored observation payloads from Federal Reserve Economic Data API.
* **`raw.world_bank_indicators`:** Multilateral indicator series retrieved via the World Bank Data API.
