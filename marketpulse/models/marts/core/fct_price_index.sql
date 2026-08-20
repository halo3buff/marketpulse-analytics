with prices as (

    select * from {{ ref('fct_daily_prices') }}

)

select
    price_id,
    asset_id,
    asset_symbol,
    asset_class,
    price_date,
    price_usd,
    round(
        price_usd / first_value(price_usd) over (
            partition by asset_id order by price_date
        ) * 100, 4
    ) as indexed_price

from prices
