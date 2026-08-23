from . import alphavantage_ingest
from . import coingecko_ingest
from . import fred_ingest

PIPELINE = [
    ("CoinGecko", coingecko_ingest),
    ("Alpha Vantage", alphavantage_ingest),
    ("FRED", fred_ingest),
]


def main():
    failures = []
    for label, module in PIPELINE:
        print(f"\n{'=' * 40}\n{label}\n{'=' * 40}")
        try:
            module.main()
        except Exception as e:
            print(f"{label} failed: {e}")
            failures.append(label)

    if failures:
        raise SystemExit(f"Pipeline finished with failures: {', '.join(failures)}")


if __name__ == "__main__":
    main()
