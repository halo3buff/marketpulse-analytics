with source as (
    select * from {{ source('yfinance', 'YFINANCE_HISTORICAL_PRICES') }}
),

with_change as (
    select
        symbol,
        trade_date,
        close as price_usd,
        volume as volume_usd,
        (close - lag(close) over (partition by symbol order by trade_date))
            / nullif(lag(close) over (partition by symbol order by trade_date), 0) * 100
            as price_change_pct
    from source
)

select
    symbol       as asset_id,
    symbol       as asset_symbol,
    symbol       as asset_name,
    'equity'     as asset_class,
    trade_date   as price_date,
    price_usd,
    volume_usd,
    price_change_pct
from with_change
