"""Shared HTTP session for the ingestion scripts.

Free-tier upstreams (CoinGecko, Alpha Vantage, FRED) rate-limit and throw
transient 5xx. Retry with backoff instead of failing the nightly run.
"""

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

SESSION = requests.Session()
SESSION.mount("https://", HTTPAdapter(max_retries=Retry(
    total=5,
    backoff_factor=2,
    status_forcelist=[429, 500, 502, 503, 504],
    allowed_methods=["GET"],
    respect_retry_after_header=True,
)))
