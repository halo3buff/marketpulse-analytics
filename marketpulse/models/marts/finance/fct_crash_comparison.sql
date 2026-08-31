-- Benchmarked against SPY specifically, not the blended crypto+equity
-- index - crypto has no meaningful history before ~2013, so comparing
-- it against 2008 or the dot-com crash would be dishonest. SPY is a
-- real S&P 500 ETF with a real historical analog to compare against.
with spy_prices as (

    select price_date, indexed_price
    from {{ ref('fct_price_index') }}
    where asset_id = 'SPY'

),

spy_drawdown as (

    select
        price_date,
        indexed_price,
        round(
            (indexed_price - max(indexed_price) over (order by price_date rows unbounded preceding))
            / max(indexed_price) over (order by price_date rows unbounded preceding) * 100
        , 2) as drawdown_pct

    from spy_prices

),

current_drawdown as (

    select
        'Current (since tracking began)' as label,
        drawdown_pct

    from spy_drawdown
    where price_date = (select max(price_date) from spy_drawdown)

),

historical_crashes as (

    -- stored as a positive magnitude in the seed, negated here so the
    -- sign convention matches current_drawdown (0 = no decline, negative = decline)
    select
        crash_name as label,
        -peak_to_trough_pct as drawdown_pct

    from {{ ref('seed_market_crashes') }}

)

select * from current_drawdown
union all
select * from historical_crashes
order by drawdown_pct asc
