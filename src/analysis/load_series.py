from pathlib import Path

import duckdb
import numpy as np
import pandas as pd

# src/analysis/load_series.py -> parents[2] = ρίζα του project
DB_PATH = Path(__file__).resolve().parents[2] / "data" / "congestion.duckdb"


def _pre_sql(control_excludes_airports: bool) -> str:
    # Αν ζητηθεί, η Αναφορά χάνει τις διαδρομές που αγγίζουν αεροδρόμιο
    extra = "and not (route_group = 'control' and touches_airport)" if control_excludes_airports else ""
    return f"""
        select
            pickup_date,
            route_group,
            cast(sum(n_trips)                  as double) as n_trips,
            cast(sum(n_trips_excl_type0)       as double) as n_trips_excl_type0,
            cast(sum(sum_distance_miles_speed) as double) as dist_miles,
            cast(sum(sum_duration_sec_speed)   as double) as dur_sec
        from main.mart_route_day
        where route_group in ('treated', 'control')
          and not is_post_policy
          {extra}
        group by pickup_date, route_group
        order by pickup_date, route_group
    """


def load_pre_period(control_excludes_airports: bool = False) -> pd.DataFrame:
    """Επιστρέφει D = log(Κέντρο) - log(Αναφορά) ανά ημέρα, για τρεις δείκτες."""
    con = duckdb.connect(str(DB_PATH), read_only=True)
    try:
        long = con.execute(_pre_sql(control_excludes_airports)).df()
    finally:
        con.close()

    long["pickup_date"] = pd.to_datetime(long["pickup_date"])
    wide = long.pivot(index="pickup_date", columns="route_group")

    def speed(group: str) -> pd.Series:
        # Σ απόσταση / Σ διάρκεια (σε ώρες), όπως ορίζει το σχέδιο
        return wide["dist_miles"][group] / (wide["dur_sec"][group] / 3600.0)

    d = pd.DataFrame(index=wide.index)
    d["trips_all"] = np.log(wide["n_trips"]["treated"]) - np.log(wide["n_trips"]["control"])
    d["trips_excl_type0"] = (
        np.log(wide["n_trips_excl_type0"]["treated"]) - np.log(wide["n_trips_excl_type0"]["control"])
    )
    d["speed"] = np.log(speed("treated")) - np.log(speed("control"))

    # Έλεγχοι ασφαλείας: δεν πρέπει να υπάρχουν ημέρες από 5/1/2025 και μετά
    assert d.index.max() < pd.Timestamp("2025-01-05"), "Φορτώθηκαν ημέρες του «μετά»!"
    assert len(d) == 735, f"Αναμενόμενες 735 ημέρες, βρέθηκαν {len(d)}"
    assert not d.isna().any().any(), "Υπάρχουν κενές τιμές"
    return d