

with source as (
    select * from {{ source('fred', 'FRED_INDICATORS') }}
),

renamed as (
select
    --identifiers
    series_id as indicator_id,
    series_name as indicator_name,

    --id labels
    case series_id
        when 'FEDFUNDS' then 'interest_rate'
        when 'CPIAUCSL' then 'inflation'
        when 'UNRATE' then 'employment'
        when 'DGS10' then 'interest_rate'
        when 'DEXUSEU' then 'fx_rate'
        else 'other'
    end as indicator_category,

    --data
    observation_date,
    value as indicator_value,

    --timestamps
    loaded_at
from source

)

select * from renamed