with source as (
    select * from {{ source('coingecko', 'COINGECKO_HISTORICAL_PRICES') }}
),

coin_lookup as (
    select distinct coin_id, coin_symbol, coin_name
    from {{ ref('stg_coingecko__prices') }}
),

with_change as (
    select
        coin_id,
        price_date,
        price_usd,
        market_cap_usd,
        volume_usd,
        (price_usd - lag(price_usd) over (partition by coin_id order by price_date))
            / nullif(lag(price_usd) over (partition by coin_id order by price_date), 0) * 100
            as price_change_pct
    from source
)

select
    w.coin_id                            as asset_id,
    coalesce(l.coin_symbol, w.coin_id)   as asset_symbol,
    coalesce(l.coin_name, w.coin_id)     as asset_name,
    'crypto'                             as asset_class,
    w.price_date,
    w.price_usd,
    w.volume_usd,
    w.market_cap_usd,
    w.price_change_pct
from with_change w
left join coin_lookup l on w.coin_id = l.coin_id