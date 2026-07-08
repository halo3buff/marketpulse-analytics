with source as (

    select * from {{ ref('stg_fred__indicators') }}

),

pivoted as (

    select
        observation_date,

        max(case when indicator_id = 'FEDFUNDS'
            then indicator_value end)   as fed_funds_rate,

        max(case when indicator_id = 'CPIAUCSL'
            then indicator_value end)   as cpi,

        max(case when indicator_id = 'UNRATE'
            then indicator_value end)   as unemployment_rate,

        max(case when indicator_id = 'DGS10'
            then indicator_value end)   as treasury_10y_yield,

        max(case when indicator_id = 'DEXUSEU'
            then indicator_value end)   as usd_eur_rate

    from source
    group by observation_date

)

select * from pivoted