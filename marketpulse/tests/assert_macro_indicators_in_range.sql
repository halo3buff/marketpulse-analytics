select
    price_id,
    price_date,
    fed_funds_rate,
    cpi,
    unemployment_rate,
    treasury_10y_yield,
    usd_eur_rate
from {{ ref('fct_macro_correlation') }}
where fed_funds_rate not between 0 and 20
   or cpi not between 0 and 500
   or unemployment_rate not between 0 and 30
   or treasury_10y_yield not between 0 and 20
   or usd_eur_rate not between 0.5 and 2