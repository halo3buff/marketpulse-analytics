-- explicit UTC conversion, not current_date() - the pipeline's own
-- date logic (Python ingestion, cast(price_updated_at as date)) is
-- implicitly UTC throughout, but current_date() reflects the
-- account's TIMEZONE parameter, which defaults to America/Los_Angeles
-- on a fresh Snowflake account and can lag UTC by up to 7 hours
select
    price_id,
    asset_id,
    price_date,
    price_usd
from {{ ref('fct_daily_prices') }}
where price_date > convert_timezone('UTC', current_timestamp())::date