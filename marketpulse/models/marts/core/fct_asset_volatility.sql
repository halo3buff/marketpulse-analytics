{{
    config(
        materialized='incremental',
        unique_key='price_id',
        incremental_strategy='merge'
    )
}}

with daily_prices as (

    select * from {{ ref('fct_daily_prices') }}

    {% if is_incremental() %}
    where price_date >= (
        select max(price_date) from {{ this }}
    )
    {% endif %}
    
),

volatility as (

    select
        price_id,
        asset_id,
        asset_symbol,
        asset_name,
        asset_class,
        market_cap_tier,
        price_date,
        price_usd,
        price_change_pct,

        -- rolling volatility windows using window functions
        round(
            stddev(price_change_pct) over (
                partition by asset_id
                order by price_date
                rows between 6 preceding and current row
            ), 4
        )                               as volatility_7d,

        round(
            stddev(price_change_pct) over (
                partition by asset_id
                order by price_date
                rows between 29 preceding and current row
            ), 4
        )                               as volatility_30d,

        round(
            stddev(price_change_pct) over (
                partition by asset_id
                order by price_date
                rows between 89 preceding and current row
            ), 4
        )                               as volatility_90d,

        -- rank assets by volatility on each date
        rank() over (
            partition by price_date
            order by abs(price_change_pct) desc
        )                               as volatility_rank_daily

    from daily_prices
    where price_change_pct is not null

)

select * from volatility