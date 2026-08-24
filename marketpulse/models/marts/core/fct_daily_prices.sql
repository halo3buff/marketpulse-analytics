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

-- int_prices__combined is ephemeral (always full history), so this lag()
-- runs over the complete series before any incremental filtering happens
-- below - it always sees the true prior day, live or backfilled, with no
-- dependency on a manually-run backfill script staying fresh.
with_change as (

    select
        *,
        case
            when asset_class = 'crypto' then
                round(
                    (price_usd - lag(price_usd) over (partition by asset_id order by price_date))
                    / nullif(lag(price_usd) over (partition by asset_id order by price_date), 0) * 100
                , 4)
            else price_change_pct
        end as price_change_pct_calc

    from prices

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
        p.price_change_pct_calc          as price_change_pct,

        -- time dimensions for easy filtering
        date_part('year',  p.price_date)    as price_year,
        date_part('month', p.price_date)    as price_month,
        date_part('dow',   p.price_date)    as price_day_of_week

    from with_change p
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