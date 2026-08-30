import os
import time
import pandas as pd
import requests
import snowflake.connector
from dotenv import load_dotenv

load_dotenv()

COINGECKO_HISTORY_URL = "https://api.coingecko.com/api/v3/coins/{id}/market_chart"

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
        CREATE TABLE IF NOT EXISTS MARKETPULSE.RAW.COINGECKO_HISTORICAL_PRICES (
            coin_id        VARCHAR       NOT NULL,
            price_date     DATE          NOT NULL,
            price_usd      FLOAT,
            market_cap_usd FLOAT,
            volume_usd     FLOAT,
            loaded_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
            PRIMARY KEY (coin_id, price_date)
        )
    """)

def get_tracked_coin_ids(cur):
    cur.execute("SELECT DISTINCT ID FROM MARKETPULSE.RAW.COINGECKO_PRICES")
    return [row[0] for row in cur.fetchall()]

def fetch_history(coin_id: str) -> pd.DataFrame:
    for attempt in range(4):
        resp = requests.get(COINGECKO_HISTORY_URL.format(id=coin_id), params={
            "vs_currency": "usd",
            "days": "365",
        })
        if resp.status_code == 429 and attempt < 3:
            time.sleep(15 * (attempt + 1))  # 15s, 30s, 45s - back off harder each retry
            continue
        resp.raise_for_status()
        break
    data = resp.json()

    prices = pd.DataFrame(data["prices"], columns=["ts", "price_usd"])
    caps = pd.DataFrame(data["market_caps"], columns=["ts", "market_cap_usd"])
    vols = pd.DataFrame(data["total_volumes"], columns=["ts", "volume_usd"])

    df = prices.merge(caps, on="ts").merge(vols, on="ts")
    df["price_date"] = pd.to_datetime(df["ts"], unit="ms").dt.date
    df = df.sort_values("ts").groupby("price_date", as_index=False).last()  # one row per day
    df["coin_id"] = coin_id
    return df[["coin_id", "price_date", "price_usd", "market_cap_usd", "volume_usd"]]

def load_rows(cur, df: pd.DataFrame):
    rows = list(df.itertuples(index=False, name=None))
    cur.executemany("""
        INSERT INTO MARKETPULSE.RAW.COINGECKO_HISTORICAL_PRICES
            (coin_id, price_date, price_usd, market_cap_usd, volume_usd)
        VALUES (%s, %s, %s, %s, %s)
    """, rows)

def main():
    conn = get_conn()
    cur = conn.cursor()
    ensure_table(cur)
    cur.execute("TRUNCATE TABLE MARKETPULSE.RAW.COINGECKO_HISTORICAL_PRICES")

    coin_ids = get_tracked_coin_ids(cur)
    print(f"Backfilling {len(coin_ids)} coins...")

    total_rows = 0
    for i, coin_id in enumerate(coin_ids):
        try:
            df = fetch_history(coin_id)
            load_rows(cur, df)
            total_rows += len(df)
            print(f"  {coin_id}: {len(df)} rows")
        except Exception as e:
            print(f"  Skipped {coin_id}: {e}")
        if i < len(coin_ids) - 1:
            time.sleep(10)  # 6s was still hitting 429s in practice

    conn.close()
    print(f"Done. {total_rows} total rows loaded.")

if __name__ == "__main__":
    main()