with latest as (

    select
        asset_class,
        max(price_date) as latest_price_date

    from {{ ref('fct_daily_prices') }}
    group by asset_class

)

select p.*

from {{ ref('fct_daily_prices') }} p
inner join latest l
    on p.asset_class = l.asset_class
    and p.price_date = l.latest_price_date
