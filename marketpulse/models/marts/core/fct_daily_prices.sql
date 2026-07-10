{{
    config(
        materialized='incremental',
        unique_key='price_id',
        incremental_strategy='merge'
    )
}}

with prices as (

    select * from {{ ref('int_prices__combined') }}

),

assets as (

    select * from {{ ref('dim_assets') }}

),

final as (

    select
        -- surrogate key 
        {{ dbt_utils.generate_surrogate_key(['p.asset_id', 'p.price_date']) }}
                                    as price_id,

        -- dimensions
        p.asset_id,
        p.asset_symbol,
        p.asset_name,
        p.asset_class,
        p.price_date,

        -- enrichment from dim_assets
        a.market_cap_tier,
        a.market_cap_rank,

        -- measures
        p.price_usd,
        p.volume_usd,
        p.market_cap_usd,
        p.price_change_pct,

        -- time dimensions for easy filtering
        date_part('year',  p.price_date)    as price_year,
        date_part('month', p.price_date)    as price_month,
        date_part('dow',   p.price_date)    as price_day_of_week

    from prices p
    left join assets a
        on p.asset_id = a.asset_id


    {% if is_incremental() %}

    where p.price_date >= (
        select max(price_date)
        from {{ this }}
    )

    {% endif %}

)

select * from final