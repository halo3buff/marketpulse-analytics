import json
import os

import pandas as pd
import requests
import snowflake.connector
from dotenv import load_dotenv

load_dotenv()

COINGECKO_URL = "https://api.coingecko.com/api/v3/coins/markets"


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
        CREATE TABLE IF NOT EXISTS MARKETPULSE.RAW.COINGECKO_PRICES (
            id                                VARCHAR,
            symbol                            VARCHAR,
            name                              VARCHAR,
            image                             VARCHAR,
            current_price                     FLOAT,
            market_cap                        FLOAT,
            market_cap_rank                   INT,
            fully_diluted_valuation           FLOAT,
            total_volume                      FLOAT,
            high_24h                          FLOAT,
            low_24h                           FLOAT,
            price_change_24h                  FLOAT,
            price_change_percentage_24h       FLOAT,
            market_cap_change_24h             FLOAT,
            market_cap_change_percentage_24h  FLOAT,
            circulating_supply                FLOAT,
            total_supply                      FLOAT,
            max_supply                        FLOAT,
            ath                               FLOAT,
            ath_change_percentage             FLOAT,
            ath_date                          TIMESTAMP_NTZ,
            atl                               FLOAT,
            atl_change_percentage             FLOAT,
            atl_date                          TIMESTAMP_NTZ,
            roi                               VARIANT,
            last_updated                      TIMESTAMP_NTZ,
            loaded_at                         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
        )
    """)


def fetch_markets() -> pd.DataFrame:
    resp = requests.get(COINGECKO_URL, params={
        "vs_currency": "usd",
        "order": "market_cap_desc",
        "per_page": 50,
        "page": 1,
        "sparkline": "false",
        "price_change_percentage": "24h",
    })
    resp.raise_for_status()
    return pd.DataFrame(resp.json())


COLUMNS = [
    "id", "symbol", "name", "image", "current_price", "market_cap",
    "market_cap_rank", "fully_diluted_valuation", "total_volume",
    "high_24h", "low_24h", "price_change_24h", "price_change_percentage_24h",
    "market_cap_change_24h", "market_cap_change_percentage_24h",
    "circulating_supply", "total_supply", "max_supply", "ath",
    "ath_change_percentage", "ath_date", "atl", "atl_change_percentage",
    "atl_date", "roi", "last_updated",
]


def load_rows(cur, df: pd.DataFrame):
    cur.execute("TRUNCATE TABLE MARKETPULSE.RAW.COINGECKO_PRICES")

    insert_sql = f"""
        INSERT INTO MARKETPULSE.RAW.COINGECKO_PRICES
            ({", ".join(COLUMNS)})
        SELECT {", ".join('%s' if c != 'roi' else 'PARSE_JSON(%s)' for c in COLUMNS)}
    """

    rows = []
    for record in df[COLUMNS].to_dict(orient="records"):
        record["roi"] = json.dumps(record["roi"]) if record["roi"] is not None else None
        rows.append(tuple(record[c] for c in COLUMNS))

    cur.executemany(insert_sql, rows)


def main():
    conn = get_snowflake_conn()
    cur = conn.cursor()
    ensure_table(cur)

    df = fetch_markets()
    print(f"Columns: {list(df.columns)}")

    load_rows(cur, df)
    print(f"{len(df)} rows loaded")

    conn.close()
    print("Done.")


if __name__ == "__main__":
    main()
