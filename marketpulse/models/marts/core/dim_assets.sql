with crypto_assets as (

    select
        coin_id                     as asset_id,
        coin_symbol                 as asset_symbol,
        coin_name                   as asset_name,
        'crypto'                    as asset_class,
        market_cap_rank,
        market_cap_usd,

        case
            when market_cap_usd >= 10000000000  then 'large_cap'
            when market_cap_usd >= 1000000000   then 'mid_cap'
            when market_cap_usd >= 100000000    then 'small_cap'
            else 'micro_cap'
        end                         as market_cap_tier,

        all_time_high_usd,
        all_time_high_date,
        circulating_supply,
        max_supply,

        null                        as company_name,
        null                        as sector

    from {{ ref('stg_coingecko__prices') }}

),

equity_assets as (

    select distinct
        stg.ticker_symbol           as asset_id,
        stg.ticker_symbol           as asset_symbol,
        stg.ticker_symbol           as asset_name,
        'equity'                    as asset_class,
        null                        as market_cap_rank,
        null                        as market_cap_usd,
        null                        as market_cap_tier,
        null                        as all_time_high_usd,
        null                        as all_time_high_date,
        null                        as circulating_supply,
        null                        as max_supply,

        seed.company_name,
        seed.sector

    from {{ ref('stg_alphavantage__daily_prices') }} stg
    left join {{ ref('seed_equity_reference') }} seed
        on stg.ticker_symbol = seed.ticker_symbol

),

final as (

    select * from crypto_assets
    union all
    select * from equity_assets

)

select * from final