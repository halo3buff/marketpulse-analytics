-- =============================================================
-- MARKETPULSE ANALYTICS — SNOWFLAKE SETUP
-- =============================================================
-- Run these blocks IN ORDER, one at a time, in a Snowflake worksheet.
-- You only ever need to run this once per Snowflake account.
-- If your trial expires and you start a new one, run this again
-- and your entire warehouse structure is restored in minutes.
-- =============================================================


-- -------------------------------------------------------------
-- BLOCK 1 — Create the compute warehouse
-- -------------------------------------------------------------
-- AUTO_SUSPEND = 60 shuts it off after 60 seconds of inactivity.
-- This is critical on a free trial -- without it you burn credits
-- while not running anything.

CREATE WAREHOUSE IF NOT EXISTS MARKETPULSE_WH
    WAREHOUSE_SIZE = 'X-SMALL'
    AUTO_SUSPEND   = 60
    AUTO_RESUME    = TRUE
    COMMENT        = 'Warehouse for MarketPulse dbt transformations';


-- -------------------------------------------------------------
-- BLOCK 2 — Create the database
-- -------------------------------------------------------------
-- One database for the entire project.
-- All schemas (RAW, STAGING, MARTS) live inside this one database.

CREATE DATABASE IF NOT EXISTS MARKETPULSE
    COMMENT = 'MarketPulse Analytics — financial intelligence pipeline';


-- -------------------------------------------------------------
-- BLOCK 3 — Create all schemas
-- -------------------------------------------------------------
-- Each schema represents one layer of the pipeline.
-- RAW:            ingestion scripts write here, dbt only reads from here
-- STAGING:        dbt writes cleaned views here
-- INTERMEDIATE:   dbt writes intermediate models here (if not ephemeral)
-- MARTS_CORE:     dbt writes core fact/dimension tables here
-- MARTS_FINANCE:  dbt writes finance-specific aggregations here

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

-- Grant access to all future schemas and tables automatically
GRANT ALL PRIVILEGES ON FUTURE SCHEMAS IN DATABASE MARKETPULSE TO ROLE DBT_ROLE;
GRANT ALL PRIVILEGES ON FUTURE TABLES  IN DATABASE MARKETPULSE TO ROLE DBT_ROLE;

-- Create the dbt service user
-- !! CHANGE 'yourpassword' to something strong before running !!
CREATE USER IF NOT EXISTS DBT_USER
    PASSWORD          = 'yourpassword'
    DEFAULT_ROLE      = DBT_ROLE
    DEFAULT_WAREHOUSE = MARKETPULSE_WH
    DEFAULT_NAMESPACE = MARKETPULSE
    COMMENT           = 'Service user for dbt Core';

GRANT ROLE DBT_ROLE TO USER DBT_USER;


-- -------------------------------------------------------------
-- BLOCK 5 — Placeholder raw table for connection testing
-- -------------------------------------------------------------
-- This gives dbt something to read during initial setup and testing.
-- The Python ingestion scripts will replace this with real data.

USE DATABASE MARKETPULSE;
USE SCHEMA RAW;

CREATE TABLE IF NOT EXISTS RAW.COINGECKO_PRICES (
    ID                VARCHAR,
    SYMBOL            VARCHAR,
    NAME              VARCHAR,
    CURRENT_PRICE     FLOAT,
    MARKET_CAP        FLOAT,
    TOTAL_VOLUME      FLOAT,
    PRICE_CHANGE_24H  FLOAT,
    LAST_UPDATED      TIMESTAMP_TZ,
    LOADED_AT         TIMESTAMP_TZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO RAW.COINGECKO_PRICES
    (ID, SYMBOL, NAME, CURRENT_PRICE, MARKET_CAP, TOTAL_VOLUME, PRICE_CHANGE_24H, LAST_UPDATED)
VALUES
    ('bitcoin',  'btc', 'Bitcoin',  67500.00, 1330000000000, 28000000000, 2.3, CURRENT_TIMESTAMP()),
    ('ethereum', 'eth', 'Ethereum',  3520.00,  423000000000, 14000000000, 1.8, CURRENT_TIMESTAMP());


-- -------------------------------------------------------------
-- VERIFY — Run this at the end to confirm everything exists
-- -------------------------------------------------------------

SHOW WAREHOUSES  LIKE 'MARKETPULSE_WH';
SHOW DATABASES   LIKE 'MARKETPULSE';
SHOW SCHEMAS     IN DATABASE MARKETPULSE;
SHOW ROLES       LIKE 'DBT_ROLE';
SHOW USERS       LIKE 'DBT_USER';
SELECT * FROM RAW.COINGECKO_PRICES;

-- =============================================================
-- TO RESTORE AFTER A NEW SNOWFLAKE TRIAL:
-- 1. Run all blocks above (change password in Block 4)
-- 2. Update profiles.yml with your new account identifier
-- 3. Run: dbt debug  (from inside the marketpulse/ folder)
-- 4. Run: dbt run
-- 5. Reconnect Looker Studio to the new Snowflake connection
-- Total time: ~20 minutes
-- =============================================================
