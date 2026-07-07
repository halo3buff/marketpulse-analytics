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
-- 5. Run: dbt debug  (from inside the marketpulse/ folder)
-- 6. Run: python -m ingestion.run_all  (reload raw data)
-- 7. Run: dbt run
-- 8. Reconnect Looker Studio to the new Snowflake connection
-- Total time: ~20 minutes
-- =============================================================