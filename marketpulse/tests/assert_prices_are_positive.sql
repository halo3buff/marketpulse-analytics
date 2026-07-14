select
    price_id,
    asset_id,
    price_date,
    price_usd
from {{ ref('fct_daily_prices') }}
where price_usd <= 0