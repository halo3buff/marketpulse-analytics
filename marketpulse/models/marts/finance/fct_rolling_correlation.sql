with daily as (

    select
        price_date,
        avg(case when asset_class = 'crypto' then price_change_pct end) as crypto_avg_pct_change,
        avg(case when asset_class = 'equity' then price_change_pct end) as equity_avg_pct_change,
        max(fed_funds_rate)                                             as fed_funds_rate

    from {{ ref('fct_macro_correlation') }}
    group by price_date

),

-- Snowflake's CORR() doesn't support sliding window frames (only cumulative),
-- so the 30-day rolling correlation is built from the raw Pearson formula
-- using SUM/COUNT, which do support `rows between 29 preceding and current row`.
paired as (

    select
        price_date,
        crypto_avg_pct_change,
        equity_avg_pct_change,
        fed_funds_rate,

        case when crypto_avg_pct_change is not null and fed_funds_rate is not null
             then crypto_avg_pct_change end as crypto_x,
        case when crypto_avg_pct_change is not null and fed_funds_rate is not null
             then fed_funds_rate end         as crypto_y,

        case when equity_avg_pct_change is not null and fed_funds_rate is not null
             then equity_avg_pct_change end as equity_x,
        case when equity_avg_pct_change is not null and fed_funds_rate is not null
             then fed_funds_rate end         as equity_y

    from daily

),

windowed as (

    select
        price_date,
        crypto_avg_pct_change,
        equity_avg_pct_change,
        fed_funds_rate,

        count(crypto_x) over (order by price_date rows between 29 preceding and current row) as n_crypto,
        sum(crypto_x)   over (order by price_date rows between 29 preceding and current row) as sum_crypto_x,
        sum(crypto_y)   over (order by price_date rows between 29 preceding and current row) as sum_crypto_y,
        sum(crypto_x * crypto_y) over (order by price_date rows between 29 preceding and current row) as sum_crypto_xy,
        sum(crypto_x * crypto_x) over (order by price_date rows between 29 preceding and current row) as sum_crypto_x2,
        sum(crypto_y * crypto_y) over (order by price_date rows between 29 preceding and current row) as sum_crypto_y2,

        count(equity_x) over (order by price_date rows between 29 preceding and current row) as n_equity,
        sum(equity_x)   over (order by price_date rows between 29 preceding and current row) as sum_equity_x,
        sum(equity_y)   over (order by price_date rows between 29 preceding and current row) as sum_equity_y,
        sum(equity_x * equity_y) over (order by price_date rows between 29 preceding and current row) as sum_equity_xy,
        sum(equity_x * equity_x) over (order by price_date rows between 29 preceding and current row) as sum_equity_x2,
        sum(equity_y * equity_y) over (order by price_date rows between 29 preceding and current row) as sum_equity_y2

    from paired

)

select
    price_date,
    crypto_avg_pct_change,
    equity_avg_pct_change,
    fed_funds_rate,

    (n_crypto * sum_crypto_xy - sum_crypto_x * sum_crypto_y)
        / nullif(sqrt(greatest((n_crypto * sum_crypto_x2 - sum_crypto_x * sum_crypto_x)
                    * (n_crypto * sum_crypto_y2 - sum_crypto_y * sum_crypto_y), 0)), 0)
        as crypto_fedfunds_rolling_corr_30d,

    (n_equity * sum_equity_xy - sum_equity_x * sum_equity_y)
        / nullif(sqrt(greatest((n_equity * sum_equity_x2 - sum_equity_x * sum_equity_x)
                    * (n_equity * sum_equity_y2 - sum_equity_y * sum_equity_y), 0)), 0)
        as equity_fedfunds_rolling_corr_30d

from windowed
