import urllib.request
import zipfile
from pathlib import Path

BASE_URL = "https://d37ci6vzurychx.cloudfront.net/misc"
ROOT = Path(__file__).resolve().parents[2]
SEED_DIR = ROOT / "dbt_project" / "seeds"
SHAPE_DIR = ROOT / "data" / "raw" / "taxi_zones"


def fetch(url: str, target: Path) -> None:
    if target.exists():
        print(f"Υπάρχει ήδη, το προσπερνώ: {target.name}")
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    tmp = target.with_suffix(target.suffix + ".part")
    print(f"Κατεβάζω {url}")
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (congestion-project)"})
    try:
        with urllib.request.urlopen(request) as response, open(tmp, "wb") as out:
            out.write(response.read())
    except Exception:
        tmp.unlink(missing_ok=True)
        raise
    tmp.rename(target)
    print(f"Έτοιμο: {target.name} ({target.stat().st_size / 1e3:.0f} KB)")


if __name__ == "__main__":
    fetch(f"{BASE_URL}/taxi_zone_lookup.csv", SEED_DIR / "taxi_zone_lookup.csv")

    zip_path = SHAPE_DIR / "taxi_zones.zip"
    fetch(f"{BASE_URL}/taxi_zones.zip", zip_path)
    with zipfile.ZipFile(zip_path) as z:
        z.extractall(SHAPE_DIR)
    print(f"Αποσυμπιέστηκε στο {SHAPE_DIR}")