# 📊 Data Dictionary & Data Architecture

This document provides a comprehensive technical overview of the data architecture, dimensional modeling methodology, schema designs, and field-level definitions implemented across the **Financial & Economic Intelligence Platform**.

---

## 1. Architectural Overview & Modeling Approach

The data warehouse follows the **Kimball Dimensional Modeling** methodology. To resolve the temporal granularity variance between domestic high-frequency monthly/quarterly indicators (FRED) and international annual macro series (World Bank), the data warehouse implements a **Fact Constellation Schema (Galaxy Schema)**.

* **Schema `raw`:** The ingestion layer where raw, unmodified payloads landed idempotently via automated Python ELT extractors.
* **Schema `analytics`:** The modeled analytical mart curated and tested via **dbt** (Data Build Tool), housing conformed dimensions, staging views, and narrow fact tables ready for Power BI and econometric modeling.

### Entity Relationship Diagram (Galaxy Schema)

```text
                       +-----------------------+
                       |      dim_country      |
                       +-----------------------+
                       | PK: country_iso3      |
                       |     country_name      |
                       +-----------+-----------+
                                   |
                     +-------------+-------------+
                     |                           |
                     v                           v
        +--------------------------+   +--------------------------+
        |  fct_us_macro_monthly    |   |  fct_global_macro_annual |
        +--------------------------+   +--------------------------+
        | FK: date_id              |   | FK: observation_year     |
        | FK: country_iso3         |   | FK: country_iso3         |
        | FK: indicator_id         |   | FK: indicator_id         |
        |     indicator_value      |   |     indicator_value      |
        +------------+------+------+   +------+-----+-------------+
                     |      |                 |     |
                     |      +--------+ +------+     |
                     |               | |            |
                     v               v v            v
        +-----------------------+   +-----------------------+
        |        dim_date       |   |     dim_indicator     |
        +-----------------------+   +-----------------------+
        | PK: date_id           |   | PK: indicator_id      |
        |     year, quarter,    |   |     indicator_name,   |
        |     month, month_name,|   |     data_source,      |
        |     year_month,       |   |     business_domain   |
        |     year_quarter      |   +-----------------------+
        +-----------------------+
```

---

## 2. Staging Views (`analytics`)

The staging layer sits directly on top of the raw layer, casting data types, standardizing naming conventions, and cleaning missing records.

### `stg_fred_observations`
Standardized view for all Federal Reserve Economic Data (FRED) time-series observations.
* **Materialization:** `view`
* **Grain:** One record per series per observation date.

| Column Name | Data Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `series_id` | `text` | Series ticker code defined by FRED | `FEDFUNDS`, `UNRATE` |
| `observation_date` | `date` | Observation date (YYYY-MM-DD) | `2023-01-01` |
| `indicator_value` | `numeric(18,4)` | Recorded numerical observation value | `4.3300` |

---

### `stg_world_bank_observations`
Standardized view for multilateral country-level development indicators from the World Bank API.
* **Materialization:** `view`
* **Grain:** One record per country per indicator per calendar year.

| Column Name | Data Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `country_iso3` | `text` | ISO 3166-1 alpha-3 standardized country code | `USA`, `EGY`, `SAU` |
| `country_name` | `text` | Standard country name | `United States`, `Egypt` |
| `indicator_code` | `text` | World Bank unique indicator identifier | `NY.GDP.MKTP.KD.ZG` |
| `indicator_name` | `text` | Descriptive indicator metric name | `GDP growth (annual %)` |
| `observation_year` | `integer` | Calendar year of the observation | `2022` |
| `indicator_value` | `numeric(18,4)` | Recorded indicator value | `2.0640` |

---

## 3. Marts Tables (`analytics`)

Shared dimensional entities that integrate the two disparate fact tables across time, geography, and indicator concepts.

### `dim_date`
Uniform temporal reference for time-series aggregation, monthly rollups, and quarterly economic reporting.
* **Materialization:** `table`
* **Grain:** One record per monthly reporting date.
* **Primary Key:** `date_id`

| Column Name | Data Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `date_id` | `date` | Primary Key representing the observation date | `2023-06-01` |
| `year` | `integer` | Calendar year | `2023` |
| `quarter` | `integer` | Calendar quarter (1 to 4) | `2` |
| `month` | `integer` | Calendar month number (1 to 12) | `6` |
| `month_name` | `text` | Full name of the calendar month | `June` |
| `year_month` | `text` | Year-month period format (`YYYY-MM`) | `2023-06` |
| `year_quarter` | `text` | Year-quarter formatted label (`YYYY-Q#`) | `2023-Q2` |

---

### `dim_country`
Conformed country dimension standardizing sovereign jurisdiction codes and names.
* **Materialization:** `table`
* **Grain:** One record per country.
* **Primary Key:** `country_iso3`

| Column Name | Data Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `country_iso3` | `text` | ISO 3166-1 alpha-3 country code (Primary Key) | `USA`, `EGY`, `GBR` |
| `country_name` | `text` | Full sovereign name of the country | `United States`, `Egypt` |

---

### `dim_indicator`
Conformed metric repository standardizing business domain taxonomy, reporting data source, and metric identifiers across FRED and World Bank.
* **Materialization:** `table`
* **Grain:** One record per unique economic indicator series.
* **Primary Key:** `indicator_id`

| Column Name | Data Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `indicator_id` | `text` | Unique indicator code or series ID (Primary Key) | `FEDFUNDS`, `NY.GDP.MKTP.KD.ZG` |
| `indicator_name` | `text` | Human-readable economic indicator label | `Federal Funds Effective Rate` |
| `data_source` | `text` | Originating data provider / platform | `FRED`, `World Bank` |
| `business_domain` | `text` | Financial/Economic domain classification | `Monetary Policy`, `Economic Growth` |

---

## 4. Fact Tables (`analytics`)

Narrow, normalized fact tables storing time-series measurements with explicit foreign key relationships.

### `fct_us_macro_monthly`
High-frequency monthly time series tracking US monetary policy rates, inflation gauges, labor statistics, bond yields, and liquidity measures.
* **Materialization:** `table`
* **Grain:** One record per indicator per month for the United States.
* **Foreign Keys:** `date_id` ➔ `dim_date`, `country_iso3` ➔ `dim_country`, `indicator_id` ➔ `dim_indicator`

| Column Name | Data Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `date_id` | `date` | Foreign Key referencing `dim_date.date_id` | `2023-08-01` |
| `country_iso3` | `text` | Foreign Key referencing `dim_country.country_iso3` (`USA`) | `USA` |
| `indicator_id` | `text` | Foreign Key referencing `dim_indicator.indicator_id` | `FEDFUNDS` |
| `indicator_value` | `numeric(18,4)` | Recorded numerical observation value | `5.3300` |

---

### `fct_global_macro_annual`
Annual panel data combining cross-country macroeconomic metrics from World Bank along with annualized US metrics from FRED.
* **Materialization:** `table`
* **Grain:** One record per indicator per country per calendar year.
* **Foreign Keys:** `observation_year` ➔ `dim_date.year`, `country_iso3` ➔ `dim_country`, `indicator_id` ➔ `dim_indicator`

| Column Name | Data Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `observation_year` | `integer` | Reference calendar year | `2023` |
| `country_iso3` | `text` | Foreign Key referencing `dim_country.country_iso3` | `EGY` |
| `indicator_id` | `text` | Foreign Key referencing `dim_indicator.indicator_id` | `FP.CPI.TOTL.ZG` |
| `indicator_value` | `numeric(18,4)` | Annual indicator value or aggregated annual average | `33.8800` |

---

## 5. Ingestion Raw Layer (`raw`)

* **`raw.fred_observations`:** Stored observation payloads from the Federal Reserve Economic Data API.
* **`raw.world_bank_indicators`:** Ingested country development indicators from the World Bank API.
