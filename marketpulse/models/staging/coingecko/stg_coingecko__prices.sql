with source as (

    select * from {{ source('coingecko', 'COINGECKO_PRICES') }}

),

renamed as (

    select
        -- identifiers
        id                                      as coin_id,
        symbol                                  as coin_symbol,
        upper(symbol)                           as coin_symbol_upper,
        name                                    as coin_name,
        market_cap_rank,

        -- pricing
        current_price                           as price_usd,
        high_24h                                as high_usd_24h,
        low_24h                                 as low_usd_24h,
        price_change_24h                        as price_change_usd_24h,
        price_change_percentage_24h             as price_change_pct_24h,

        -- market size
        market_cap                              as market_cap_usd,
        fully_diluted_valuation                 as fully_diluted_valuation_usd,
        market_cap_change_24h                   as market_cap_change_usd_24h,
        market_cap_change_percentage_24h        as market_cap_change_pct_24h,

        -- supply
        circulating_supply,
        total_supply,
        max_supply,

        -- all time high / low
        ath                                     as all_time_high_usd,
        ath_change_percentage                   as pct_below_ath,
        ath_date                                as all_time_high_date,
        atl                                     as all_time_low_usd,
        atl_change_percentage                   as pct_above_atl,
        atl_date                                as all_time_low_date,

        -- volume
        total_volume                            as volume_usd_24h,

        -- timestamps
        last_updated                            as price_updated_at,
        loaded_at

    from source

)

select * from renamed