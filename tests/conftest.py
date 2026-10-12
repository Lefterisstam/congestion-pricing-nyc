import sys
from pathlib import Path

import duckdb
import numpy as np
import pandas as pd
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src" / "analysis"))


def build_fake_db(path, post_effect: float = -0.12, mislabel_post: bool = False, seed: int = 0) -> str:
    """Ψεύτικοι πίνακες mart_route_day και mart_control_zone_day, 2023-01-01 έως 2025-12-31.
    post_effect: πολλαπλασιαστικό αποτέλεσμα στο Κέντρο μετά την 5/1/2025 (σε λογαριθμικές μονάδες).
    Ημέρες κενού: 21-24/9/2023 (όπως στα πραγματικά δεδομένα)."""
    rng = np.random.default_rng(seed)
    days = pd.date_range("2023-01-01", "2025-12-31")
    post = np.asarray(days >= pd.Timestamp("2025-01-05"))
    flag_post = np.zeros(len(days), dtype=bool) if mislabel_post else post
    common = np.sin(np.arange(len(days)) / 58.0) * 0.08 + np.where(days.dayofweek >= 5, -0.05, 0.0)

    def gap_factor(d):
        if pd.Timestamp("2023-09-22") <= d <= pd.Timestamp("2023-09-24"):
            return 0.04
        return 0.33 if d == pd.Timestamp("2023-09-21") else 1.0

    zones = [(100 + i, f"Zone {i}", float(rng.choice([200, 500, 1500, 3000]))) for i in range(30)]
    zrows = []
    for zid, zn, base in zones:
        lvl = base * np.exp(common + rng.normal(0, 0.04, len(days)))
        for d, v, fp in zip(days, lvl, flag_post):
            n = int(v * gap_factor(d))
            zrows.append((d.date(), zid, zn, n, int(n * 0.9), int(n * 0.95), n * 0.95 * 3.0 * (1 + 0.03 * np.sin(d.dayofyear / 20)),
                          n * 0.95 * 900.0, bool(fp)))
    dz = pd.DataFrame(zrows, columns=["pickup_date", "pickup_zone_id", "pickup_zone_name", "n_trips", "n_trips_excl_type0",
                                      "n_trips_speed", "sum_distance_miles_speed", "sum_duration_sec_speed", "is_post_policy"])
    rrows = []
    for d, c, p, fp in zip(days, common, post, flag_post):
        f = gap_factor(d)
        eff = np.exp(post_effect) if p else 1.0
        n = int(70000 * np.exp(c + rng.normal(0, 0.03)) * f * eff)
        rrows.append((d.date(), "treated", False, bool(fp), n, int(n * 0.9), n * 0.95 * 2.5 * (1 + 0.03 * np.sin(d.dayofyear / 20)), n * 0.95 * 900.0))
        o = int(9000 * f * np.exp(c + rng.normal(0, 0.03)))
        rrows.append((d.date(), "control", False, bool(fp), o, int(o * 0.9), o * 3.0 * (1 + 0.03 * np.sin(d.dayofyear / 20)), o * 900.0))
    mr = pd.DataFrame(rrows, columns=["pickup_date", "route_group", "touches_airport", "is_post_policy", "n_trips",
                                      "n_trips_excl_type0", "sum_distance_miles_speed", "sum_duration_sec_speed"])
    con = duckdb.connect(str(path))
    con.execute("create table mart_control_zone_day as select * from dz")
    con.execute("create table mart_route_day as select * from mr")
    con.close()
    return str(path)


@pytest.fixture(scope="session")
def fake_db(tmp_path_factory):
    return build_fake_db(tmp_path_factory.mktemp("db") / "fake.duckdb")


@pytest.fixture(scope="session")
def fake_db_mislabelled(tmp_path_factory):
    return build_fake_db(tmp_path_factory.mktemp("db2") / "fake_bad.duckdb", mislabel_post=True)