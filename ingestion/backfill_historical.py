import os
import time
import pandas as pd
import requests
import snowflake.connector
from dotenv import load_dotenv
from datetime import datetime, timedelta

load_dotenv()

def get_conn():
    return snowflake.connector.connect(
        account=os.getenv("SNOWFLAKE_ACCOUNT"),
        user=os.getenv("SNOWFLAKE_USER"),
        password=os.getenv("SNOWFLAKE_PASSWORD"),
        database=os.getenv("SNOWFLAKE_DATABASE"),
        warehouse=os.getenv("SNOWFLAKE_WAREHOUSE"),
        schema="RAW",
    )

# --- Alpha Vantage backfill: full history, per symbol ---
SYMBOLS = ["AAPL", "MSFT", "GOOGL", "AMZN", "NVDA", "META", "TSLA", "JPM", "GS", "SPY"]
ALPHAVANTAGE_API_KEY = os.getenv("ALPHAVANTAGE_API_KEY")

def backfill_alphavantage(cur):
    for symbol in SYMBOLS:
        print(f"Backfilling {symbol}...")
        resp = requests.get("https://www.alphavantage.co/query", params={
            "function": "TIME_SERIES_DAILY",
            "symbol": symbol,
            "apikey": ALPHAVANTAGE_API_KEY,
        })
        resp.raise_for_status()
        series = resp.json().get("Time Series (Daily)")
        if series is None:
            print(f"  Skipped {symbol}: {resp.json()}")
            continue
        df = pd.DataFrame.from_dict(series, orient="index")
        df.columns = ["open", "high", "low", "close", "volume"]
        df = df.apply(pd.to_numeric)
        df.index.name = "trade_date"
        df = df.reset_index()
        df["trade_date"] = pd.to_datetime(df["trade_date"]).dt.date
        df["symbol"] = symbol

        for _, row in df.iterrows():
            cur.execute("""
                MERGE INTO MARKETPULSE.RAW.ALPHAVANTAGE_DAILY_PRICES tgt
                USING (SELECT %s AS symbol, %s::DATE AS trade_date, %s AS open,
                              %s AS high, %s AS low, %s AS close, %s AS volume) src
                ON tgt.symbol = src.symbol AND tgt.trade_date = src.trade_date
                WHEN MATCHED THEN UPDATE SET open=src.open, high=src.high, low=src.low,
                    close=src.close, volume=src.volume, loaded_at=CURRENT_TIMESTAMP()
                WHEN NOT MATCHED THEN INSERT (symbol, trade_date, open, high, low, close, volume)
                     VALUES (src.symbol, src.trade_date, src.open, src.high, src.low, src.close, src.volume)
            """, (row["symbol"], row["trade_date"], float(row["open"]), float(row["high"]),
                  float(row["low"]), float(row["close"]), int(row["volume"])))
        print(f"  -> {len(df)} rows")
        time.sleep(12)  # same rate-limit spacing as your daily script

# --- FRED backfill: 1 year back, all 5 series ---
FRED_SERIES = {"FEDFUNDS": "Fed Funds Rate", "CPIAUCSL": "CPI", "UNRATE": "Unemployment Rate",
               "DGS10": "10-Year Treasury", "DEXUSEU": "USD/EUR Exchange Rate"}
FRED_API_KEY = os.getenv("FRED_API_KEY")

def backfill_fred(cur):
    start = (datetime.today() - timedelta(days=365)).strftime("%Y-%m-%d")
    for series_id, label in FRED_SERIES.items():
        print(f"Backfilling {label}...")
        resp = requests.get("https://api.stlouisfed.org/fred/series/observations", params={
            "series_id": series_id, "file_type": "json",
            "observation_start": start, "api_key": FRED_API_KEY,
        })
        resp.raise_for_status()
        df = pd.DataFrame(resp.json()["observations"])[["date", "value"]]
        df["series_id"] = series_id
        df["series_name"] = label
        df["value"] = pd.to_numeric(df["value"], errors="coerce")
        df = df.dropna(subset=["value"]).rename(columns={"date": "observation_date"})
        for _, row in df.iterrows():
            cur.execute("""
                MERGE INTO MARKETPULSE.RAW.FRED_INDICATORS tgt
                USING (SELECT %s AS series_id, %s AS series_name, %s::DATE AS observation_date, %s AS value) src
                ON tgt.series_id = src.series_id AND tgt.observation_date = src.observation_date
                WHEN MATCHED THEN UPDATE SET value=src.value, series_name=src.series_name, loaded_at=CURRENT_TIMESTAMP()
                WHEN NOT MATCHED THEN INSERT (series_id, series_name, observation_date, value)
                     VALUES (src.series_id, src.series_name, src.observation_date, src.value)
            """, (row["series_id"], row["series_name"], row["observation_date"], float(row["value"])))
        print(f"  -> {len(df)} rows")

if __name__ == "__main__":
    conn = get_conn()
    cur = conn.cursor()
    backfill_alphavantage(cur)
    backfill_fred(cur)
    conn.close()
    print("Done.")