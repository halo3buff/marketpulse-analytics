from . import alphavantage_ingest
from . import coingecko_ingest
from . import fred_ingest

PIPELINE = [
    ("CoinGecko", coingecko_ingest),
    ("Alpha Vantage", alphavantage_ingest),
    ("FRED", fred_ingest),
]


def main():
    for label, module in PIPELINE:
        print(f"\n{'=' * 40}\n{label}\n{'=' * 40}")
        module.main()


if __name__ == "__main__":
    main()
