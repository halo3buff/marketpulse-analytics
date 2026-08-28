import os
import sys
from datetime import datetime, timezone

import snowflake.connector
from dotenv import load_dotenv

load_dotenv()


def main():
    conn = snowflake.connector.connect(
        account=os.getenv("SNOWFLAKE_ACCOUNT"),
        user=os.getenv("SNOWFLAKE_USER"),
        password=os.getenv("SNOWFLAKE_PASSWORD"),
        database=os.getenv("SNOWFLAKE_DATABASE"),
        warehouse=os.getenv("SNOWFLAKE_WAREHOUSE"),
        schema="MARTS_CORE",
    )
    cur = conn.cursor()
    cur.execute("""
        select max(price_date)
        from fct_daily_prices
        where asset_class = 'crypto'
    """)
    latest_crypto_date = cur.fetchone()[0]
    conn.close()

    today = datetime.now(timezone.utc).date()
    print(f"Latest crypto price_date: {latest_crypto_date} (today: {today})")

    if latest_crypto_date is None or latest_crypto_date < today:
        # crypto trades every day, so it's the freshest possible signal -
        # if it's stale, last night's pipeline run didn't happen
        raise SystemExit(f"Data is stale - latest crypto date is {latest_crypto_date}, expected {today}")


if __name__ == "__main__":
    main()
