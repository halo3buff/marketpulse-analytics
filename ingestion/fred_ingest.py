import os
from datetime import datetime, timedelta

import pandas as pd
import requests
import snowflake.connector
from dotenv import load_dotenv

load_dotenv()

FRED_BASE_URL = "https://api.stlouisfed.org/fred/series/observations"

SERIES = {
    "FEDFUNDS": "Fed Funds Rate",
    "CPIAUCSL": "CPI",
    "UNRATE": "Unemployment Rate",
    "DGS10": "10-Year Treasury",
    "DEXUSEU": "USD/EUR Exchange Rate",
}


def get_snowflake_conn():
    return snowflake.connector.connect(
        account=os.getenv("SNOWFLAKE_ACCOUNT"),
        user=os.getenv("SNOWFLAKE_USER"),
        password=os.getenv("SNOWFLAKE_PASSWORD"),
        database=os.getenv("SNOWFLAKE_DATABASE"),
        warehouse=os.getenv("SNOWFLAKE_WAREHOUSE"),
        schema="RAW",
    )


def ensure_table(cur):
    cur.execute("""
        CREATE TABLE IF NOT EXISTS MARKETPULSE.RAW.FRED_INDICATORS (
            series_id       VARCHAR(20)    NOT NULL,
            observation_date DATE           NOT NULL,
            value            FLOAT,
            loaded_at        TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
            PRIMARY KEY (series_id, observation_date)
        )
    """)


def fetch_series(series_id: str) -> pd.DataFrame:
    start = (datetime.today() - timedelta(days=365)).strftime("%Y-%m-%d")
    resp = requests.get(FRED_BASE_URL, params={
        "series_id": series_id,
        "file_type": "json",
        "observation_start": start,
        "api_key": os.getenv("FRED_API_KEY"),
    })
    resp.raise_for_status()
    observations = resp.json()["observations"]
    df = pd.DataFrame(observations)[["date", "value"]].copy()
    df["series_id"] = series_id
    df["value"] = pd.to_numeric(df["value"], errors="coerce")
    df.rename(columns={"date": "observation_date"}, inplace=True)
    return df.dropna(subset=["value"])


def upsert_series(cur, df: pd.DataFrame):
    for _, row in df.iterrows():
        cur.execute("""
            MERGE INTO MARKETPULSE.RAW.FRED_INDICATORS tgt
            USING (SELECT %s AS series_id, %s::DATE AS observation_date, %s AS value) src
               ON tgt.series_id = src.series_id
              AND tgt.observation_date = src.observation_date
            WHEN MATCHED THEN UPDATE SET value = src.value, loaded_at = CURRENT_TIMESTAMP()
            WHEN NOT MATCHED THEN INSERT (series_id, observation_date, value)
                 VALUES (src.series_id, src.observation_date, src.value)
        """, (row["series_id"], row["observation_date"], float(row["value"])))


def main():
    conn = get_snowflake_conn()
    cur = conn.cursor()
    ensure_table(cur)

    for series_id, label in SERIES.items():
        print(f"Fetching {label} ({series_id})...")
        df = fetch_series(series_id)
        upsert_series(cur, df)
        print(f"  → {len(df)} rows loaded")

    conn.close()
    print("Done.")


if __name__ == "__main__":
    main()
