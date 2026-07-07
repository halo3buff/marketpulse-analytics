with source as (

    select * from {{ source('alphavantage', 'ALPHAVANTAGE_DAILY_PRICES') }}

),

renamed as (

    select
        -- identifiers
        symbol                                  as ticker_symbol,
        trade_date,

        -- ohlcv
        open                                    as open_usd,
        high                                    as high_usd,
        low                                     as low_usd,
        close                                   as close_usd,
        volume                                  as shares_traded,

        -- derived metrics
        close - open                            as price_change_usd,
        round(
            (close - open) / nullif(open, 0) * 100
        , 4)                                    as price_change_pct,
        high - low                              as intraday_range_usd,

        -- timestamps
        loaded_at

    from source

)

select * from renamed