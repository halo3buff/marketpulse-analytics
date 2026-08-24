
with volatility as (
    select * from {{ ref('fct_asset_volatility') }}
),

macro as (
    select * from {{ ref('fct_macro_correlation') }}
),

assets as (
    select * from {{ ref('dim_assets') }}
),

joined as (
    select
        v.asset_id,
        v.price_date,


        v.volatility_7d               as today_volatility_7d,
        v.volatility_30d              as today_volatility_30d,
        m.fed_funds_rate,
        a.asset_class,


        m.price_change_pct            as today_price_change_pct,


        lead(v.volatility_7d) over (
            partition by v.asset_id
            order by v.price_date
        )                              as target_next_day_volatility_7d

    from volatility v
    left join macro m
        on v.asset_id = m.asset_id
        and v.price_date = m.price_date
    left join assets a
        on v.asset_id = a.asset_id
)

select * from joined
where target_next_day_volatility_7d is not null