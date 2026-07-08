with crypto_prices as (

    select
        coin_id                         as asset_id,
        coin_symbol                     as asset_symbol,
        coin_name                       as asset_name,
        'crypto'                        as asset_class,
        cast(price_updated_at as date)  as price_date,
        price_usd,
        volume_usd_24h                  as volume_usd,
        market_cap_usd,
        price_change_pct_24h            as price_change_pct

    from {{ ref('stg_coingecko__prices') }}

),

equity_prices as (

    select
        ticker_symbol                   as asset_id,
        ticker_symbol                   as asset_symbol,
        ticker_symbol                   as asset_name,
        'equity'                        as asset_class,
        trade_date                      as price_date,
        close_usd                       as price_usd,
        null                            as volume_usd,
        null                            as market_cap_usd,
        price_change_pct                as price_change_pct

    from {{ ref('stg_alphavantage__daily_prices') }}

),

combined as (

    select * from crypto_prices
    union all
    select * from equity_prices

)

select * from combined