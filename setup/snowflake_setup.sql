-- =============================================================
-- MARKETPULSE ANALYTICS — SNOWFLAKE SETUP
-- =============================================================
-- Run these blocks IN ORDER, one at a time, in a Snowflake worksheet.
-- You only ever need to run this once per Snowflake account.
-- If your trial expires and you start a new one, run this again
-- and your entire warehouse structure is restored in minutes.
-- =============================================================
-- !! Use a placeholder and set the real password manually !!
-- =============================================================


-- -------------------------------------------------------------
-- BLOCK 1 — Create the compute warehouse
-- -------------------------------------------------------------
-- AUTO_SUSPEND = 60 shuts it off after 60 seconds of inactivity.
-- Critical on a free trial -- without it you burn credits
-- while not running anything.

CREATE WAREHOUSE IF NOT EXISTS MARKETPULSE_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND   = 60
    AUTO_RESUME    = TRUE
    COMMENT        = 'Warehouse for MarketPulse dbt transformations';


-- -------------------------------------------------------------
-- BLOCK 2 — Create the database
-- -------------------------------------------------------------

CREATE DATABASE IF NOT EXISTS MARKETPULSE
    COMMENT = 'MarketPulse Analytics — financial intelligence pipeline';


-- -------------------------------------------------------------
-- BLOCK 3 — Create all schemas
-- -------------------------------------------------------------
-- RAW:             ingestion scripts write here, dbt only reads from here
-- STAGING:         dbt writes cleaned views here
-- INTERMEDIATE:    dbt writes intermediate models here (if not ephemeral)
-- MARTS_CORE:      dbt writes core fact/dimension tables here
-- MARTS_FINANCE:   dbt writes finance-specific aggregations here

USE DATABASE MARKETPULSE;

CREATE SCHEMA IF NOT EXISTS RAW
    COMMENT = 'Raw API data — ingestion layer, never modified by dbt';

CREATE SCHEMA IF NOT EXISTS STAGING
    COMMENT = 'dbt staging layer — views only, 1:1 with raw sources';

CREATE SCHEMA IF NOT EXISTS INTERMEDIATE
    COMMENT = 'dbt intermediate layer — business logic and joins';

CREATE SCHEMA IF NOT EXISTS MARTS_CORE
    COMMENT = 'dbt marts layer — core business entities (facts and dimensions)';

CREATE SCHEMA IF NOT EXISTS MARTS_FINANCE
    COMMENT = 'dbt marts layer — finance-specific aggregations';

CREATE SCHEMA IF NOT EXISTS SEEDS
    COMMENT = 'dbt seeds layer — static reference data (equity sector mapping)';

CREATE SCHEMA IF NOT EXISTS SNAPSHOTS
    COMMENT = 'dbt snapshots layer — SCD Type 2 history for slowly changing data';


-- -------------------------------------------------------------
-- BLOCK 4 — Create a dedicated role and user for dbt
-- -------------------------------------------------------------
-- Never run dbt as your personal admin account.
-- A dedicated role scoped to only what dbt needs is the
-- professional standard and reduces security risk.

USE ROLE ACCOUNTADMIN;

CREATE ROLE IF NOT EXISTS DBT_ROLE
    COMMENT = 'Role for dbt Core transformations';

-- Grant warehouse access
GRANT USAGE ON WAREHOUSE MARKETPULSE_WH TO ROLE DBT_ROLE;

-- Grant database access
GRANT ALL PRIVILEGES ON DATABASE MARKETPULSE TO ROLE DBT_ROLE;

-- Grant access to all current schemas
GRANT ALL PRIVILEGES ON ALL SCHEMAS IN DATABASE MARKETPULSE TO ROLE DBT_ROLE;

-- Grant access to all existing tables and views
GRANT ALL PRIVILEGES ON ALL TABLES IN DATABASE MARKETPULSE TO ROLE DBT_ROLE;
GRANT ALL PRIVILEGES ON ALL VIEWS  IN DATABASE MARKETPULSE TO ROLE DBT_ROLE;

-- Grant access to all future objects automatically
-- All three lines are required -- tables, views, and schemas
GRANT ALL PRIVILEGES ON FUTURE SCHEMAS IN DATABASE MARKETPULSE TO ROLE DBT_ROLE;
GRANT ALL PRIVILEGES ON FUTURE TABLES  IN DATABASE MARKETPULSE TO ROLE DBT_ROLE;
GRANT ALL PRIVILEGES ON FUTURE VIEWS   IN DATABASE MARKETPULSE TO ROLE DBT_ROLE;

-- Grant DBT_ROLE up to SYSADMIN so ACCOUNTADMIN inherits all object access
-- Without this, ACCOUNTADMIN cannot query views/tables owned by DBT_ROLE
GRANT ROLE DBT_ROLE TO ROLE SYSADMIN;

-- Create the dbt service user
-- !! REPLACE 'your_strong_password_here' with a real password before running !!
CREATE USER IF NOT EXISTS DBT_USER
    PASSWORD          = 'your_strong_password_here'
    DEFAULT_ROLE      = DBT_ROLE
    DEFAULT_WAREHOUSE = MARKETPULSE_WH
    DEFAULT_NAMESPACE = MARKETPULSE
    COMMENT           = 'Service user for dbt Core';

GRANT ROLE DBT_ROLE TO USER DBT_USER;


-- -------------------------------------------------------------
-- VERIFY — Run this at the end to confirm everything exists
-- -------------------------------------------------------------

SHOW WAREHOUSES LIKE 'MARKETPULSE_WH';
SHOW DATABASES  LIKE 'MARKETPULSE';
SHOW SCHEMAS    IN DATABASE MARKETPULSE;
SHOW ROLES      LIKE 'DBT_ROLE';
SHOW USERS      LIKE 'DBT_USER';

-- =============================================================
-- TO RESTORE AFTER A NEW SNOWFLAKE TRIAL:
-- 1. Run all blocks above
-- 2. Set real password in Block 4 (never commit it)
-- 3. Update profiles.yml with new account identifier
-- 4. Update .env with new password
-- 5. Update GitHub repo secrets too, not just local files - Settings >
--    Secrets and variables > Actions - update SNOWFLAKE_ACCOUNT,
--    SNOWFLAKE_USER, SNOWFLAKE_PASSWORD, SNOWFLAKE_DATABASE,
--    SNOWFLAKE_WAREHOUSE. Both daily_pipeline.yml and
--    freshness_check.yml read from these, not from .env - miss this
--    and the nightly job + freshness alert keep silently pointing at
--    the dead trial account.
-- 6. Run: dbt debug  (from inside the marketpulse/ folder, confirms connection)
-- 7. Run: dbt deps  (from inside marketpulse/ - dbt_packages/ is gitignored,
--    build fails immediately without this)
-- 8. Run: python -m ingestion.run_all
--    (loads today's live snapshot - crypto, equity, FRED macro.
--    fred_ingest.py already pulls a full trailing year on every run,
--    so macro history needs no separate backfill step)
-- 9. Run: python -m ingestion.backfill_coingecko_history
--    (365 days of crypto history - takes ~10 min, CoinGecko rate limits)
-- 10. Run: python -m ingestion.backfill_yfinance_history
--    (365 days of equity history - Alpha Vantage's daily pull only ever
--    gives ~100 days, this is the only source for the full year)
-- 11. Run: dbt build  (from inside marketpulse/ - do this AFTER both
--    backfills above, not before: fct_daily_prices is incremental and
--    only ever looks forward from its own max date, so if it builds
--    first on thin data, the backfilled history added afterward gets
--    silently skipped and needs a --full-refresh to ever be picked up)
-- 12. Reconnect Looker Studio to the new Snowflake connection
--
-- NOTE: snapshot_crypto_market_cap_tier (tier-change history) restarts
-- fresh on a new account - it's SCD tracking accumulated over time, not
-- raw data any API can re-supply, so this one piece of history is
-- genuinely unrecoverable. Everything else above fully restores.
-- Total time: ~20-30 minutes (mostly waiting on the two backfills)
-- =============================================================