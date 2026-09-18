import os
import sys
import time
import logging
import subprocess
import requests
import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

# -------------------------------------------------------------------------
# Logging Configuration
# -------------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger("ELT_Pipeline")

# -------------------------------------------------------------------------
# Environment & DB Setup
# -------------------------------------------------------------------------
load_dotenv()

DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "******")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "economic_bi_db")
FRED_API_KEY = os.getenv("FRED_API_KEY", "*********")

DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
engine = create_engine(DATABASE_URL)

# -------------------------------------------------------------------------
# 1. Extraction: FRED API
# -------------------------------------------------------------------------
FRED_SERIES = [
   "FEDFUNDS", 
    "CPIAUCSL",  
    "UNRATE",   
    "GDPC1",    
    "GS10",      
    "M2SL"       
]

def extract_fred_data(api_key: str, series_list: list) -> pd.DataFrame:
    """Extract macroeconomic series observations from FRED API."""
    logger.info("Starting extraction from FRED API...")
    base_url = "https://api.stlouisfed.org/fred/series/observations"
    all_records = []

    for series_id in series_list:
        params = {
            "series_id": series_id,
            "api_key": api_key,
            "file_type": "json",
            "observation_start": "2000-01-01"
        }
        try:
            res = requests.get(base_url, params=params, timeout=15)
            res.raise_for_status()
            data = res.json().get("observations", [])
            
            for item in data:
                val = item.get("value")
                if val and val != ".":
                    all_records.append({
                        "series_id": series_id,
                        "observation_date": item.get("date"),
                        "value": float(val)
                    })
        except Exception as e:
            logger.error(f"Failed to fetch FRED series '{series_id}': {e}")
            raise

    df = pd.DataFrame(all_records)
    logger.info(f"FRED extraction complete: {len(df):,} records retrieved.")
    return df

# -------------------------------------------------------------------------
# 2. Extraction: World Bank API
# -------------------------------------------------------------------------
WB_COUNTRIES = ["USA", "EGY", "SAU", "ARE", "GBR"]
WB_INDICATORS = [
       "NY.GDP.MKTP.KD.ZG",
        "FP.CPI.TOTL.ZG",
        "FS.AST.PRVT.GD.ZS",
        "FB.AST.NPL.ZS",
        "BX.TRF.PWKR.DT.GD.ZS"
]

def extract_world_bank_data(countries: list, indicators: list) -> pd.DataFrame:
    """Extract cross-country indicators from World Bank API with retry logic."""
    logger.info("Starting extraction from World Bank API...")
    countries_param = ";".join(countries)
    all_records = []
    session = requests.Session()

    for ind in indicators:
        url = f"https://api.worldbank.org/v2/country/{countries_param}/indicator/{ind}"
        params = {
            "date": "2000:2024",
            "format": "json",
            "per_page": 1000
        }
        
        success = False
        for attempt in range(1, 4):
            try:
                logger.info(f"Fetching World Bank indicator '{ind}' (Attempt {attempt}/3)...")
                res = session.get(url, params=params, timeout=45)
                res.raise_for_status()
                payload = res.json()
                
                if len(payload) > 1 and payload[1]:
                    for item in payload[1]:
                        val = item.get("value")
                        if val is not None:
                            all_records.append({
                                "country_iso3": item.get("countryiso3code"),
                                "country_name": item.get("country", {}).get("value"),
                                "indicator_code": item.get("indicator", {}).get("id"),
                                "indicator_name": item.get("indicator", {}).get("value"),
                                "observation_year": int(item.get("date")),
                                "value": float(val)
                            })
                success = True
                break
            except (requests.exceptions.RequestException, requests.exceptions.Timeout) as err:
                logger.warning(f"Attempt {attempt} failed for indicator '{ind}': {err}")
                time.sleep(3)

        if not success:
            logger.error(f"Permanently failed to fetch indicator '{ind}' after 3 attempts.")
            raise RuntimeError(f"World Bank API timeout for indicator: {ind}")

    df = pd.DataFrame(all_records)
    logger.info(f"World Bank extraction complete: {len(df):,} records retrieved.")
    return df

# -------------------------------------------------------------------------
# 3. Loading (ELT Staging to raw schema)
# -------------------------------------------------------------------------
def load_raw_tables(engine, df_fred: pd.DataFrame, df_wb: pd.DataFrame):
    """Load extracted dataframes into PostgreSQL raw schema safely using truncate & append."""
    logger.info("Loading datasets into PostgreSQL raw schema...")
    
    with engine.begin() as conn:
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS raw;"))
        # Truncate tables to safely refresh data without dropping table structure or breaking dependent views
        conn.execute(text("TRUNCATE TABLE raw.fred_observations;"))
        conn.execute(text("TRUNCATE TABLE raw.world_bank_indicators;"))
        logger.info("Truncated raw tables successfully.")

    df_fred.to_sql(
        name="fred_observations",
        schema="raw",
        con=engine,
        if_exists="append",
        index=False,
        method="multi",
        chunksize=1000
    )
    logger.info("Loaded raw.fred_observations successfully.")

    df_wb.to_sql(
        name="world_bank_indicators",
        schema="raw",
        con=engine,
        if_exists="append",
        index=False,
        method="multi",
        chunksize=1000
    )
    logger.info("Loaded raw.world_bank_indicators successfully.")

# -------------------------------------------------------------------------
# 4. Transformation & Testing Orchestration (dbt)
# -------------------------------------------------------------------------
def execute_dbt_command(command: list, dbt_dir: str):
    """Execute a dbt CLI command and stream stdout/stderr logs directly."""
    cmd_str = " ".join(command)
    logger.info(f"Executing: {cmd_str} in directory: {dbt_dir}")
    
    result = subprocess.run(
        command,
        cwd=dbt_dir,
        capture_output=True,
        text=True,
        shell=True if sys.platform == "win32" else False
    )
    
    if result.stdout:
        print("\n--- DBT OUTPUT ---")
        print(result.stdout)
        print("------------------\n")
        
    if result.returncode != 0:
        if result.stderr:
            print("\n--- DBT STDERR ---")
            print(result.stderr)
            print("------------------\n")
        logger.error(f"dbt execution failed for: {cmd_str}")
        raise RuntimeError(f"dbt command failed with exit code {result.returncode}")
    
    logger.info(f"Successfully completed: {cmd_str}")

# -------------------------------------------------------------------------
# Main Pipeline Entrypoint
# -------------------------------------------------------------------------
def main():
    logger.info("==========================================================")
    logger.info("Starting Automated Financial Intelligence ELT Pipeline")
    logger.info("==========================================================")
    
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    dbt_dir = os.path.join(project_root, "economic_dbt")
    
    try:
        # Step 1: Extract
        df_fred = extract_fred_data(FRED_API_KEY, FRED_SERIES)
        df_wb = extract_world_bank_data(WB_COUNTRIES, WB_INDICATORS)
        
        # Step 2: Load into raw
        load_raw_tables(engine, df_fred, df_wb)
        
        # Step 3: Transform via dbt run
        logger.info("Triggering dbt models compilation and execution...")
        execute_dbt_command(["dbt", "run"], dbt_dir)
        
        # Step 4: Validate Data via dbt test
        logger.info("Running dbt automated data quality tests...")
        execute_dbt_command(["dbt", "test"], dbt_dir)
        
        logger.info("==========================================================")
        logger.info("[SUCCESS] Pipeline finished end-to-end without any errors!")
        logger.info("==========================================================")
        
    except Exception as e:
        logger.critical(f"Pipeline execution aborted due to error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
