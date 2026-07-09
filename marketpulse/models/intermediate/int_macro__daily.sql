
with source as (
    select * from {{ ref('stg_fred__indicators') }}
),

pivoted as (
    select
        observation_date,
        max(case when indicator_id = 'FEDFUNDS'
            then indicator_value end)   as fed_funds_rate_raw,
        max(case when indicator_id = 'CPIAUCSL'
            then indicator_value end)   as cpi_raw,
        max(case when indicator_id = 'UNRATE'
            then indicator_value end)   as unemployment_rate_raw,
        max(case when indicator_id = 'DGS10'
            then indicator_value end)   as treasury_10y_yield_raw,
        max(case when indicator_id = 'DEXUSEU'
            then indicator_value end)   as usd_eur_rate_raw
    from source
    group by observation_date
),

forward_filled as (
    select
        observation_date,

        last_value(fed_funds_rate_raw ignore nulls) over (
            order by observation_date
            rows between unbounded preceding and current row
        )                               as fed_funds_rate,

        last_value(cpi_raw ignore nulls) over (
            order by observation_date
            rows between unbounded preceding and current row
        )                               as cpi,

        last_value(unemployment_rate_raw ignore nulls) over (
            order by observation_date
            rows between unbounded preceding and current row
        )                               as unemployment_rate,

        last_value(treasury_10y_yield_raw ignore nulls) over (
            order by observation_date
            rows between unbounded preceding and current row
        )                               as treasury_10y_yield,

        last_value(usd_eur_rate_raw ignore nulls) over (
            order by observation_date
            rows between unbounded preceding and current row
        )                               as usd_eur_rate

    from pivoted
)

select * from forward_filled