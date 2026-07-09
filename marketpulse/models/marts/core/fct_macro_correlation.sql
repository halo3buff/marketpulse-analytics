with prices as (

    select * from {{ ref('fct_daily_prices') }}

),

macro as (

    select * from {{ ref('int_macro__daily') }}

),

joined as (

    select
        -- identifiers
        p.price_id,
        p.asset_id,
        p.asset_symbol,
        p.asset_name,
        p.asset_class,
        p.market_cap_tier,

        -- time
        p.price_date,
        p.price_year,
        p.price_month,

        -- asset metrics
        p.price_usd,
        p.price_change_pct,
        p.volume_usd,

        -- macro indicators on the same date
        m.fed_funds_rate,
        m.cpi,
        m.unemployment_rate,
        m.treasury_10y_yield,
        m.usd_eur_rate,

        -- flag whether macro data was available for this date
        case
            when m.observation_date is not null then true
            else false
        end                         as has_macro_data

    from prices p
    left join macro m
        on p.price_date = m.observation_date

    where p.price_change_pct is not null

)

select * from joined