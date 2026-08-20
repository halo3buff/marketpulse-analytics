with daily as (

    select
        price_date,
        avg(case when asset_class = 'crypto' then price_change_pct end) as crypto_avg_pct_change,
        avg(case when asset_class = 'equity' then price_change_pct end) as equity_avg_pct_change,
        max(fed_funds_rate)                                             as fed_funds_rate,
        max(cpi)                                                        as cpi,
        max(unemployment_rate)                                          as unemployment_rate,
        max(treasury_10y_yield)                                         as treasury_10y_yield,
        max(usd_eur_rate)                                               as usd_eur_rate

    from {{ ref('fct_macro_correlation') }}
    group by price_date

),

pairs as (

    select
        'crypto_avg_pct_change'                                          as metric_a,
        'equity_avg_pct_change'                                          as metric_b,
        corr(crypto_avg_pct_change, equity_avg_pct_change)               as correlation_value
    from daily

    union all

    select
        'crypto_avg_pct_change'                                          as metric_a,
        'fed_funds_rate'                                                 as metric_b,
        corr(crypto_avg_pct_change, fed_funds_rate)                      as correlation_value
    from daily

    union all

    select
        'crypto_avg_pct_change'                                          as metric_a,
        'cpi'                                                            as metric_b,
        corr(crypto_avg_pct_change, cpi)                                 as correlation_value
    from daily

    union all

    select
        'crypto_avg_pct_change'                                          as metric_a,
        'unemployment_rate'                                              as metric_b,
        corr(crypto_avg_pct_change, unemployment_rate)                   as correlation_value
    from daily

    union all

    select
        'crypto_avg_pct_change'                                          as metric_a,
        'treasury_10y_yield'                                             as metric_b,
        corr(crypto_avg_pct_change, treasury_10y_yield)                  as correlation_value
    from daily

    union all

    select
        'crypto_avg_pct_change'                                          as metric_a,
        'usd_eur_rate'                                                   as metric_b,
        corr(crypto_avg_pct_change, usd_eur_rate)                        as correlation_value
    from daily

    union all

    select
        'equity_avg_pct_change'                                          as metric_a,
        'fed_funds_rate'                                                 as metric_b,
        corr(equity_avg_pct_change, fed_funds_rate)                      as correlation_value
    from daily

    union all

    select
        'equity_avg_pct_change'                                          as metric_a,
        'cpi'                                                            as metric_b,
        corr(equity_avg_pct_change, cpi)                                 as correlation_value
    from daily

    union all

    select
        'equity_avg_pct_change'                                          as metric_a,
        'unemployment_rate'                                              as metric_b,
        corr(equity_avg_pct_change, unemployment_rate)                   as correlation_value
    from daily

    union all

    select
        'equity_avg_pct_change'                                          as metric_a,
        'treasury_10y_yield'                                             as metric_b,
        corr(equity_avg_pct_change, treasury_10y_yield)                  as correlation_value
    from daily

    union all

    select
        'equity_avg_pct_change'                                          as metric_a,
        'usd_eur_rate'                                                   as metric_b,
        corr(equity_avg_pct_change, usd_eur_rate)                        as correlation_value
    from daily

    union all

    select
        'fed_funds_rate'                                                 as metric_a,
        'cpi'                                                            as metric_b,
        corr(fed_funds_rate, cpi)                                        as correlation_value
    from daily

    union all

    select
        'fed_funds_rate'                                                 as metric_a,
        'unemployment_rate'                                              as metric_b,
        corr(fed_funds_rate, unemployment_rate)                          as correlation_value
    from daily

    union all

    select
        'fed_funds_rate'                                                 as metric_a,
        'treasury_10y_yield'                                             as metric_b,
        corr(fed_funds_rate, treasury_10y_yield)                         as correlation_value
    from daily

    union all

    select
        'fed_funds_rate'                                                 as metric_a,
        'usd_eur_rate'                                                   as metric_b,
        corr(fed_funds_rate, usd_eur_rate)                               as correlation_value
    from daily

    union all

    select
        'cpi'                                                            as metric_a,
        'unemployment_rate'                                              as metric_b,
        corr(cpi, unemployment_rate)                                     as correlation_value
    from daily

    union all

    select
        'cpi'                                                            as metric_a,
        'treasury_10y_yield'                                             as metric_b,
        corr(cpi, treasury_10y_yield)                                    as correlation_value
    from daily

    union all

    select
        'cpi'                                                            as metric_a,
        'usd_eur_rate'                                                   as metric_b,
        corr(cpi, usd_eur_rate)                                          as correlation_value
    from daily

    union all

    select
        'unemployment_rate'                                              as metric_a,
        'treasury_10y_yield'                                             as metric_b,
        corr(unemployment_rate, treasury_10y_yield)                      as correlation_value
    from daily

    union all

    select
        'unemployment_rate'                                              as metric_a,
        'usd_eur_rate'                                                   as metric_b,
        corr(unemployment_rate, usd_eur_rate)                            as correlation_value
    from daily

    union all

    select
        'treasury_10y_yield'                                             as metric_a,
        'usd_eur_rate'                                                   as metric_b,
        corr(treasury_10y_yield, usd_eur_rate)                           as correlation_value
    from daily

)

select metric_a, metric_b, correlation_value from pairs

union all

select metric_b as metric_a, metric_a as metric_b, correlation_value from pairs
