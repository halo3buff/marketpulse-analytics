select
    price_date,
    round(avg(indexed_price), 4)                                                   as market_pulse_index,
    round(avg(case when asset_class = 'crypto' then indexed_price end), 4)         as crypto_pulse_index,
    round(avg(case when asset_class = 'equity' then indexed_price end), 4)         as equity_pulse_index

from {{ ref('fct_price_index') }}
group by price_date
