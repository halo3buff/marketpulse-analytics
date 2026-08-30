# MarketPulse Analytics

*Daily-refreshed pipeline tracking 60 assets (50 cryptocurrencies and 10 equities) against five macroeconomic indicators*

![Python](https://img.shields.io/badge/Python-3.11-3776AB?logo=python&logoColor=white)
![dbt](https://img.shields.io/badge/dbt-Core-FF694B?logo=dbt&logoColor=white)
![Snowflake](https://img.shields.io/badge/Snowflake-Cloud_Warehouse-29B5E8?logo=snowflake&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-Orchestration-2088FF?logo=githubactions&logoColor=white)
![Looker Studio](https://img.shields.io/badge/Looker_Studio-Dashboard-4285F4?logo=looker&logoColor=white)
![Streamlit](https://img.shields.io/badge/Streamlit-Ask_Your_Data-FF4B4B?logo=streamlit&logoColor=white)

---

## Why this exists

Crypto, equities, and macro data each get tracked plenty on their own, but rarely sit together on the same grain where you can actually query how they relate. This project pulls all three from independent free-tier APIs into one warehouse, so a question like "does crypto actually move with the Fed Funds rate" has a real, checkable answer instead of a guess.

---

## Key Findings

**1. Crypto and equities move mostly independently of each other**

Full-history correlation between average daily crypto returns and average daily equity returns is **0.14**. Weak positive. The "everything crashes together" assumption doesn't hold up here.

**2. Even within a "top 50" crypto universe, the market cap spread is enormous**

Bitcoin sits at roughly **$1.57 trillion**. The smallest asset in the same tracked list, Ondo, sits at about **$1.72 billion**. Same "top 50 by market cap" universe, a ~900x gap between the biggest and smallest names in it.

**3. Volatility inside crypto varies more than volatility between crypto and equities**

On the same day, 30-day volatility across tracked crypto assets ranges from **0.00%** (BUIDL, a tokenized money market fund) to **7.96%** (PUMP). Lumping "crypto" into one risk bucket hides more than it reveals; the internal spread is bigger than the crypto-vs-equity gap most people assume matters most.

**4. The Fed Funds rate sat completely flat for four straight months (Jan-Apr)**

Flat enough that a 30-day rolling correlation against it becomes mathematically undefined for that whole window, since the formula divides by variance and there was none to divide by. This surfaced as a real division-by-zero bug during development. The fix (clamping the correlation math to a valid range) is documented directly in the model and now guards against the same case anywhere else it could recur.

---

## Architecture

```
CoinGecko API ──┐
Alpha Vantage ───┼──→ Python ingestion ──→ Snowflake RAW ──→ dbt staging (views)
FRED API ────────┘                                                  │
                                                                     ▼
                                                     dbt intermediate (ephemeral)
                                                                     │
                                                                     ▼
                                                  dbt marts (core + finance + ml)
                                                                     │
                                              ┌──────────────────────┴──────────────────────┐
                                              ▼                                              ▼
                                     Looker Studio dashboard                    Streamlit + Gemini (ask-your-data)
```

GitHub Actions orchestrates the nightly run (`.github/workflows/daily_pipeline.yml`). A separate freshness-check workflow runs a few hours later and fails loudly, with an email, if a scheduled run silently didn't fire.

## Stack

| Layer | Tool |
|---|---|
| Ingestion | Python (`requests`, `yfinance`, `snowflake-connector-python`) |
| Warehouse | Snowflake |
| Transformation | dbt (staging → intermediate → marts), `dbt_utils`, `dbt_expectations` |
| Orchestration | GitHub Actions (scheduled pipeline + freshness monitoring) |
| BI | Looker Studio |
| Natural-language query | Streamlit + Google Gemini (text-to-SQL over the warehouse) |
| ML experiment | scikit-learn (Random Forest / Linear Regression, volatility forecasting) |

## Dashboard

*(screenshot placeholder)*

KPI strip, gainers and losers, a rebased cross-asset price index, a 7-day risk-vs-return scatter, rolling and full-history correlation views, and a 7-day performance grid. All of it reads directly from the marts layer described below.

## dbt lineage

*(screenshot placeholder, generate with `dbt docs generate && dbt docs serve` from `marketpulse/`, then export the lineage graph from the docs UI)*

## Data model

- **`dim_assets`**: one row per asset (crypto and equity), market-cap tier, sector for equities.
- **`fct_daily_prices`**: the core fact table. One row per asset per day, incremental, a full year of history. Everything else in the marts layer builds on top of this table.
- **`fct_asset_volatility`**: 7/30/90-day rolling volatility and daily volatility ranking per asset.
- **`fct_price_index`**: every asset rebased to 100 on its first tracked day, so a $60k coin and a $200 stock land on the same chart.
- **`fct_macro_correlation`**: daily prices joined to forward-filled macro indicators.
- **`fct_rolling_correlation`** / **`fct_correlation_matrix`**: 30-day rolling and full-history pairwise correlation across crypto returns, equity returns, and every macro indicator.
- **`fct_volatility_features`**: feature table behind the ML experiment below.

## Data quality

Every model gets tested on every build: schema tests (`not_null`, `unique`, `accepted_values`, `relationships`) plus singular tests for business-rule sanity (no negative prices, no future-dated rows, macro indicators within plausible bounds, correlation values bounded to [-1, 1]). `dbt build` runs models and tests together, so bad data gets caught before it reaches a chart.

The freshness-check workflow adds a second layer on top: it runs a few hours after the nightly pipeline and fails if the most recent trading data genuinely isn't there yet, catching a silently-skipped schedule before it shows up as a stale dashboard.

## ML experiment

An attempt at forecasting next-day 7-day volatility. The first version scored well in testing, but only because of a random train/test split on time-series data, which let the model train on rolling windows that nearly duplicated the ones it was being tested against. Switching to a chronological split (train on older dates, test on newer ones the model has never seen) fixed the leak. The honest result afterward: none of the models, Random Forest or Linear Regression, with or without a trend feature, beat a naive "tomorrow looks like today" baseline. Volatility is strongly autocorrelated, so persistence is a genuinely hard baseline to clear, and this counts as a real finding rather than a dead end. The code stays in the repo as an experiment with a documented result, not a feature pretending to work.

## Project structure

```
ingestion/          Python scripts - daily pulls + one-time historical backfills
marketpulse/
  models/
    staging/        1:1 cleaned views over raw API data, one folder per source
    intermediate/    ephemeral - unions crypto+equity, forward-fills macro gaps
    marts/
      core/          dim_assets, fct_daily_prices, fct_asset_volatility, fct_price_index
      finance/       fct_macro_correlation, fct_rolling_correlation, fct_correlation_matrix
      ml/            fct_volatility_features (feature table for the ML experiment)
  seeds/             static equity sector/company reference data
  snapshots/         SCD Type 2 tracking of crypto market-cap tier changes
  tests/             singular SQL tests (positive prices, no future dates, sane macro ranges)
  ml/                train_volatility_model.py, the forecasting experiment
  app/               streamlit_app.py, natural-language query interface
setup/               one-shot Snowflake account setup/restore script
.github/workflows/   daily pipeline + freshness check
```

## How to run

### Prerequisites

- Python 3.11+
- A Snowflake account
- API keys: Alpha Vantage, FRED, Google (Gemini), all free tier

### Setup

```bash
git clone https://github.com/halo3buff/marketpulse-analytics
cd marketpulse-analytics

python -m venv venv
venv\Scripts\activate      # Windows
source venv/bin/activate   # Mac/Linux

pip install -r requirements.txt
```

Run `setup/snowflake_setup.sql` in a Snowflake worksheet once. It creates the warehouse, database, schemas, and a dedicated `dbt` role/user.

Create a `.env` in the project root with Snowflake credentials and the three API keys. See `ingestion/*.py` and `marketpulse/app/streamlit_app.py` for the exact variable names each one expects.

### Run the pipeline

```bash
python -m ingestion.run_all                        # daily live snapshot: crypto, equity, macro
python -m ingestion.backfill_coingecko_history      # 365 days of crypto history
python -m ingestion.backfill_yfinance_history       # 365 days of equity history

cd marketpulse
dbt deps
dbt build
```

### Run the natural-language query app

```bash
cd marketpulse/app
streamlit run streamlit_app.py
```

## Data sources

- [CoinGecko API](https://www.coingecko.com/en/api): crypto market data, top 50 by market cap
- [Alpha Vantage](https://www.alphavantage.co/): daily equity prices
- [yfinance](https://github.com/ranaroussi/yfinance): historical equity backfill (Alpha Vantage's free tier caps at roughly 100 days)
- [FRED](https://fred.stlouisfed.org/): Fed Funds Rate, CPI, unemployment, 10-year Treasury yield, USD/EUR rate
