
{% snapshot snapshot_crypto_market_cap_tier %}

{{
    config(
        target_schema='snapshots',
        unique_key='asset_id',
        strategy='check',
        check_cols=['market_cap_tier', 'market_cap_rank', 'market_cap_usd'],
    )
}}

select
    asset_id,
    asset_symbol,
    asset_name,
    market_cap_rank,
    market_cap_usd,
    market_cap_tier
from {{ ref('dim_assets') }}
where asset_class = 'crypto'

{% endsnapshot %}