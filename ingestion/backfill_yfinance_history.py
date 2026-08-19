import os
import time
import pandas as pd
import snowflake.connector
from dotenv import load_dotenv

load_dotenv()

SYMBOLS = ["AAPL", "MSFT", "GOOGL", "AMZN", "NVDA", "META", "TSLA", "JPM", "GS", "SPY"]

def get_conn():
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
        CREATE TABLE IF NOT EXISTS MARKETPULSE.RAW.YFINANCE_HISTORICAL_PRICES (
            symbol     VARCHAR       NOT NULL,
            trade_date DATE          NOT NULL,
            open       FLOAT,
            high       FLOAT,
            low        FLOAT,
            close      FLOAT,
            volume     NUMBER,
            loaded_at  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
            PRIMARY KEY (symbol, trade_date)
        )
    """)

def fetch_history(symbol: str) -> pd.DataFrame:
    import yfinance as yf
    df = yf.Ticker(symbol).history(period="1y", interval="1d")
    df = df.reset_index()
    df["symbol"] = symbol
    df["trade_date"] = pd.to_datetime(df["Date"]).dt.date
    return df[["symbol", "trade_date", "Open", "High", "Low", "Close", "Volume"]]

def load_rows(cur, df: pd.DataFrame):
    rows = list(df.itertuples(index=False, name=None))
    cur.executemany("""
        INSERT INTO MARKETPULSE.RAW.YFINANCE_HISTORICAL_PRICES
            (symbol, trade_date, open, high, low, close, volume)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, rows)

def main():
    conn = get_conn()
    cur = conn.cursor()
    ensure_table(cur)
    cur.execute("TRUNCATE TABLE MARKETPULSE.RAW.YFINANCE_HISTORICAL_PRICES")

    print(f"Backfilling {len(SYMBOLS)} equities...")
    total_rows = 0
    for i, symbol in enumerate(SYMBOLS):
        try:
            df = fetch_history(symbol)
            load_rows(cur, df)
            total_rows += len(df)
            print(f"  {symbol}: {len(df)} rows")
        except Exception as e:
            print(f"  Skipped {symbol}: {e}")
        if i < len(SYMBOLS) - 1:
            time.sleep(1)

    conn.close()
    print(f"Done. {total_rows} total rows loaded.")

if __name__ == "__main__":
    main()
