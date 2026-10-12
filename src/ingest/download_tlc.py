import shutil
import sys
import urllib.request
from pathlib import Path

BASE_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data"
RAW_DIR = Path(__file__).resolve().parents[2] / "data" / "raw"


def download(service: str, month: str) -> Path:
    filename = f"{service}_tripdata_{month}.parquet"
    target = RAW_DIR / filename

    if target.exists():
        print(f"Υπάρχει ήδη, το προσπερνώ: {filename}")
        return target

    RAW_DIR.mkdir(parents=True, exist_ok=True)
    tmp = target.with_suffix(".parquet.part")
    url = f"{BASE_URL}/{filename}"
    print(f"Κατεβάζω {url}")

    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (congestion-project)"})
    try:
        with urllib.request.urlopen(request) as response, open(tmp, "wb") as out:
            shutil.copyfileobj(response, out)
    except Exception:
        tmp.unlink(missing_ok=True)
        raise

    tmp.rename(target)
    print(f"Έτοιμο: {filename} ({target.stat().st_size / 1e6:.1f} MB)")
    return target


if __name__ == "__main__":
    service = sys.argv[1]
    for month in sys.argv[2:]:
        download(service, month)