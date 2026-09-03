with daily as (

    select
        price_date,
        round(avg(indexed_price), 4)                                                   as market_pulse_index,
        round(avg(case when asset_class = 'crypto' then indexed_price end), 4)         as crypto_pulse_index,
        round(avg(case when asset_class = 'equity' then indexed_price end), 4)         as equity_pulse_index

    from {{ ref('fct_price_index') }}
    group by price_date

)

select
    price_date,
    market_pulse_index,
    crypto_pulse_index,
    equity_pulse_index,

    -- day-over-day change in the blended index, for the up/down dot strip -
    -- Looker Studio can't compute row-to-row deltas on its own
    round(
        (market_pulse_index - lag(market_pulse_index) over (order by price_date))
        / nullif(lag(market_pulse_index) over (order by price_date), 0) * 100
    , 4) as market_pulse_change_pct

from daily
