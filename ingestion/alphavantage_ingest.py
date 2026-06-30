import os
import time

import pandas as pd
import requests
import snowflake.connector
from dotenv import load_dotenv

load_dotenv()

ALPHAVANTAGE_URL = "https://www.alphavantage.co/query"
ALPHAVANTAGE_API_KEY = os.getenv("ALPHAVANTAGE_API_KEY")

SYMBOLS = ["AAPL", "MSFT", "GOOGL", "AMZN", "NVDA", "META", "TSLA", "JPM", "GS", "SPY"]

DAYS = 30
RATE_LIMIT_SLEEP_SECONDS = 12


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
        CREATE TABLE IF NOT EXISTS MARKETPULSE.RAW.ALPHAVANTAGE_DAILY_PRICES (
            symbol      VARCHAR(10)    NOT NULL,
            trade_date  DATE           NOT NULL,
            open        FLOAT,
            high        FLOAT,
            low         FLOAT,
            close       FLOAT,
            volume      NUMBER,
            loaded_at   TIMESTAMP_NTZ  DEFAULT CURRENT_TIMESTAMP(),
            PRIMARY KEY (symbol, trade_date)
        )
    """)


def fetch_daily(symbol: str) -> pd.DataFrame:
    resp = requests.get(ALPHAVANTAGE_URL, params={
        "function": "TIME_SERIES_DAILY",
        "symbol": symbol,
        "apikey": ALPHAVANTAGE_API_KEY,
    })
    resp.raise_for_status()
    payload = resp.json()

    series = payload.get("Time Series (Daily)")
    if series is None:
        raise RuntimeError(f"No time series for {symbol}: {payload}")

    df = pd.DataFrame.from_dict(series, orient="index")
    df.columns = ["open", "high", "low", "close", "volume"]
    df = df.apply(pd.to_numeric)
    df.index.name = "trade_date"
    df = df.reset_index()
    df["trade_date"] = pd.to_datetime(df["trade_date"]).dt.date
    df["symbol"] = symbol

    return df.sort_values("trade_date", ascending=False).head(DAYS)


def upsert_rows(cur, df: pd.DataFrame):
    for _, row in df.iterrows():
        cur.execute("""
            MERGE INTO MARKETPULSE.RAW.ALPHAVANTAGE_DAILY_PRICES tgt
            USING (
                SELECT %s AS symbol, %s::DATE AS trade_date, %s AS open,
                       %s AS high, %s AS low, %s AS close, %s AS volume
            ) src
               ON tgt.symbol = src.symbol
              AND tgt.trade_date = src.trade_date
            WHEN MATCHED THEN UPDATE SET
                open = src.open, high = src.high, low = src.low,
                close = src.close, volume = src.volume,
                loaded_at = CURRENT_TIMESTAMP()
            WHEN NOT MATCHED THEN INSERT (symbol, trade_date, open, high, low, close, volume)
                 VALUES (src.symbol, src.trade_date, src.open, src.high, src.low, src.close, src.volume)
        """, (
            row["symbol"], row["trade_date"], float(row["open"]),
            float(row["high"]), float(row["low"]), float(row["close"]),
            int(row["volume"]),
        ))


def main():
    conn = get_snowflake_conn()
    cur = conn.cursor()
    ensure_table(cur)

    total_rows = 0
    for i, symbol in enumerate(SYMBOLS):
        print(f"Fetching {symbol}...")
        df = fetch_daily(symbol)
        upsert_rows(cur, df)
        total_rows += len(df)
        print(f"  -> {len(df)} rows loaded")

        if i < len(SYMBOLS) - 1:
            time.sleep(RATE_LIMIT_SLEEP_SECONDS)

    conn.close()
    print(f"Done. {total_rows} total rows loaded.")


if __name__ == "__main__":
    main()
