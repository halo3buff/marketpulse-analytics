with crypto_prices as (

    -- price_change_pct computed the same way as crypto_historical_prices below
    -- (today's close vs yesterday's stored close) instead of CoinGecko's own
    -- price_change_pct_24h, which is a rolling window from the API call time,
    -- not a calendar-day close-to-close change - mixing the two methodologies
    -- made "today" look inflated relative to every other day in the series.
    select
        c.coin_id                         as asset_id,
        c.coin_symbol                     as asset_symbol,
        c.coin_name                       as asset_name,
        'crypto'                          as asset_class,
        cast(c.price_updated_at as date)  as price_date,
        c.price_usd,
        c.volume_usd_24h                  as volume_usd,
        c.market_cap_usd,
        (c.price_usd - y.price_usd) / nullif(y.price_usd, 0) * 100
                                           as price_change_pct

    from {{ ref('stg_coingecko__prices') }} c
    left join {{ ref('stg_coingecko__historical_prices') }} y
        on y.asset_id = c.coin_id
        and y.price_date = dateadd(day, -1, cast(c.price_updated_at as date))

),

equity_prices as (

    select
        ticker_symbol                   as asset_id,
        ticker_symbol                   as asset_symbol,
        ticker_symbol                   as asset_name,
        'equity'                        as asset_class,
        trade_date                      as price_date,
        close_usd                       as price_usd,
        shares_traded * close_usd       as volume_usd,
        null                            as market_cap_usd,
        price_change_pct                as price_change_pct

    from {{ ref('stg_alphavantage__daily_prices') }}

),

crypto_historical_prices as (

    select
        h.asset_id,
        h.asset_symbol,
        h.asset_name,
        h.asset_class,
        h.price_date,
        h.price_usd,
        h.volume_usd,
        h.market_cap_usd,
        h.price_change_pct

    from {{ ref('stg_coingecko__historical_prices') }} h
    where not exists (
        select 1
        from {{ ref('stg_coingecko__prices') }} c
        where c.coin_id = h.asset_id
          and cast(c.price_updated_at as date) = h.price_date
    )

),

equity_historical_prices as (

    select
        h.asset_id,
        h.asset_symbol,
        h.asset_name,
        h.asset_class,
        h.price_date,
        h.price_usd,
        h.volume_usd,
        null            as market_cap_usd,
        h.price_change_pct

    from {{ ref('stg_yfinance__historical_prices') }} h
    where not exists (
        select 1
        from {{ ref('stg_alphavantage__daily_prices') }} d
        where d.ticker_symbol = h.asset_id
          and d.trade_date = h.price_date
    )

),

combined as (

    select * from crypto_prices
    union all
    select * from equity_prices
    union all
    select * from crypto_historical_prices
    union all
    select * from equity_historical_prices

)

select * from combined