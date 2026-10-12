from pathlib import Path

import duckdb
import numpy as np
import pandas as pd

# src/analysis/load_donors.py -> parents[2] = ρίζα του project
DB_PATH = Path(__file__).resolve().parents[2] / "data" / "congestion.duckdb"

POLICY_START = pd.Timestamp("2025-01-05")
N_PRE_WEEKS = 105

# Ημέρες κενού: κανόνας < 25% του κανονικού + ρητή εξαίρεση της 21/9/2023
GAP_THRESHOLD = 0.25
EXPLICIT_GAP_DAYS = [pd.Timestamp("2023-09-21")]
EXPECTED_GAP_DAYS = [pd.Timestamp(d) for d in ["2023-09-21", "2023-09-22", "2023-09-23", "2023-09-24"]]

INDICATORS = ["trips_all", "trips_excl_type0", "speed"]


def _week_start(dates: pd.Series) -> pd.Series:
    """Η Κυριακή της εβδομάδας (Κυριακή–Σάββατο). dayofweek: Δευτέρα=0 ... Κυριακή=6."""
    return dates - pd.to_timedelta((dates.dt.dayofweek + 1) % 7, unit="D")


def find_gap_days(total_daily: pd.Series) -> list:
    """total_daily: συνολικές διαδρομές όλων των ομάδων ανά ημέρα (index = ημερομηνία).

    Μια ημέρα είναι κενό αν total < 25% της διαμέσου των ίδιων ημερών της εβδομάδας 1-4 εβδομάδες πριν ή μετά.
    Ίδιος κανόνας με το profile_16d."""
    gap = set(EXPLICIT_GAP_DAYS)
    for d, total in total_daily.items():
        neigh = [d + pd.Timedelta(days=7 * k) for k in (-4, -3, -2, -1, 1, 2, 3, 4)]
        vals = [total_daily[n] for n in neigh if n in total_daily.index]
        if vals and total < GAP_THRESHOLD * float(np.median(vals)):
            gap.add(d)
    return sorted(gap)


def load_pre_weekly(n_donors: int = 25, keep_gap_weeks: bool = False, exclude_zone_ids=(), db_path=None) -> dict:
    """Επιστρέφει λεξικό με:
      weeks      : DatetimeIndex των εβδομάδων που μένουν (Κυριακές)
      y[ind]     : Series, log του Κέντρου ανά εβδομάδα
      X[ind]     : DataFrame, log κάθε δότη ανά εβδομάδα (στήλες = pickup_zone_id)
      donors     : DataFrame με τους δότες (id, όνομα, μέσος όγκος/ημέρα)
      gap_days   : ημέρες κενού που βρέθηκαν
      dropped_weeks : εβδομάδες που αφαιρέθηκαν
    """
    con = duckdb.connect(str(db_path or DB_PATH), read_only=True)
    try:
        treated = con.execute("""
            select pickup_date,
                   cast(sum(n_trips) as double)                  as n_trips,
                   cast(sum(n_trips_excl_type0) as double)       as n_trips_excl_type0,
                   cast(sum(sum_distance_miles_speed) as double) as dist,
                   cast(sum(sum_duration_sec_speed) as double)   as dur
            from mart_route_day
            where route_group = 'treated' and not is_post_policy
            group by pickup_date order by pickup_date
        """).df()
        total = con.execute("""
            select pickup_date, cast(sum(n_trips) as double) as total
            from mart_route_day
            where not is_post_policy
            group by pickup_date order by pickup_date
        """).df()
        donors_daily = con.execute("""
            select pickup_date, pickup_zone_id, pickup_zone_name,
                   cast(n_trips as double)                  as n_trips,
                   cast(n_trips_excl_type0 as double)       as n_trips_excl_type0,
                   cast(sum_distance_miles_speed as double) as dist,
                   cast(sum_duration_sec_speed as double)   as dur
            from mart_control_zone_day
            where not is_post_policy
        """).df()
    finally:
        con.close()

    for name, df in [("treated", treated), ("total", total), ("donors", donors_daily)]:
        df["pickup_date"] = pd.to_datetime(df["pickup_date"])
        if df["pickup_date"].max() >= POLICY_START:
            raise RuntimeError(f"Φορτώθηκαν ημέρες «μετά» στο {name}. Σταματάμε.")
    if len(treated) != 735 or len(total) != 735:
        raise RuntimeError(f"Αναμενόμενες 735 ημέρες «πριν», βρέθηκαν {len(treated)} / {len(total)}.")

    # --- ημέρες κενού
    gap_days = find_gap_days(total.set_index("pickup_date")["total"])
    if gap_days != EXPECTED_GAP_DAYS:
        raise RuntimeError(
            "Οι ημέρες κενού δεν είναι οι αναμενόμενες (21-24/9/2023). Βρέθηκαν: "
            f"{[str(d.date()) for d in gap_days]}. Ενημέρωσε με πριν συνεχίσεις."
        )

    # --- δότες: οι n_donors μεγαλύτεροι κατά μέσο όγκο ανά ημέρα στο «πριν»
    zone_avg = (
        donors_daily.groupby(["pickup_zone_id", "pickup_zone_name"])["n_trips"].mean()
        .rename("avg_trips_day").reset_index()
        .sort_values("avg_trips_day", ascending=False)
    )
    # προαιρετικά: αποκλεισμός συγκεκριμένων ζωνών ΠΡΙΝ την επιλογή των n_donors μεγαλύτερων (έλεγχος ευαισθησίας)
    zone_avg = zone_avg[~zone_avg["pickup_zone_id"].isin(list(exclude_zone_ids))]
    donors = zone_avg.head(n_donors).reset_index(drop=True)
    donors_daily = donors_daily[donors_daily["pickup_zone_id"].isin(donors["pickup_zone_id"])].copy()

    # --- εβδομαδιαία αθροίσματα
    treated["week"] = _week_start(treated["pickup_date"])
    donors_daily["week"] = _week_start(donors_daily["pickup_date"])
    t_week = treated.groupby("week")[["n_trips", "n_trips_excl_type0", "dist", "dur"]].sum()
    n_days = treated.groupby("week")["pickup_date"].count()
    if len(t_week) != N_PRE_WEEKS or not (n_days == 7).all():
        raise RuntimeError(f"Αναμενόμενες {N_PRE_WEEKS} πλήρεις εβδομάδες, βρέθηκαν {len(t_week)}.")
    d_week = donors_daily.groupby(["week", "pickup_zone_id"])[["n_trips", "n_trips_excl_type0", "dist", "dur"]].sum()

    def _log_series(df: pd.DataFrame) -> dict:
        return {
            "trips_all": np.log(df["n_trips"]),
            "trips_excl_type0": np.log(df["n_trips_excl_type0"]),
            "speed": np.log(df["dist"] / df["dur"] * 3600.0),
        }

    y = _log_series(t_week)
    x = {ind: pd.DataFrame({z: _log_series(d_week.xs(z, level="pickup_zone_id"))[ind]
                            for z in donors["pickup_zone_id"]}) for ind in INDICATORS}

    # --- αφαίρεση εβδομάδων με ημέρες κενού
    gap_weeks = sorted(set(_week_start(pd.Series(gap_days))))
    keep = t_week.index if keep_gap_weeks else t_week.index.difference(pd.DatetimeIndex(gap_weeks))
    out = {"weeks": keep, "gap_days": gap_days, "dropped_weeks": [] if keep_gap_weeks else gap_weeks, "donors": donors, "y": {}, "X": {}}
    for ind in INDICATORS:
        out["y"][ind] = y[ind].loc[keep]
        out["X"][ind] = x[ind].loc[keep]
        bad = (~np.isfinite(out["y"][ind])).sum() + (~np.isfinite(out["X"][ind].to_numpy())).sum()
        if bad:
            raise RuntimeError(f"Μη πεπερασμένες τιμές στον δείκτη {ind} ({bad}). Έλεγξε τους δότες.")
    return out