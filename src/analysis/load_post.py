import numpy as np
import pandas as pd
import duckdb

from load_donors import (DB_PATH, EXPECTED_GAP_DAYS, INDICATORS, N_PRE_WEEKS, POLICY_START,
                         _week_start, find_gap_days)

N_POST_WEEKS = 51
N_DAYS_ALL = 1096


def _connect(db_path):
    return duckdb.connect(str(db_path or DB_PATH), read_only=True)


def load_full_weekly(n_donors: int = 25, keep_gap_weeks: bool = False, exclude_zone_ids=(), db_path=None) -> dict:
    con = _connect(db_path)
    try:
        treated = con.execute("""
            select pickup_date,
                   cast(sum(n_trips) as double)                  as n_trips,
                   cast(sum(n_trips_excl_type0) as double)       as n_trips_excl_type0,
                   cast(sum(sum_distance_miles_speed) as double) as dist,
                   cast(sum(sum_duration_sec_speed) as double)   as dur
            from mart_route_day
            where route_group = 'treated'
            group by pickup_date order by pickup_date
        """).df()
        total = con.execute("""
            select pickup_date, cast(sum(n_trips) as double) as total
            from mart_route_day
            group by pickup_date order by pickup_date
        """).df()
        donors_daily = con.execute("""
            select pickup_date, pickup_zone_id, pickup_zone_name,
                   cast(n_trips as double)                  as n_trips,
                   cast(n_trips_excl_type0 as double)       as n_trips_excl_type0,
                   cast(sum_distance_miles_speed as double) as dist,
                   cast(sum_duration_sec_speed as double)   as dur
            from mart_control_zone_day
        """).df()
    finally:
        con.close()

    for df in (treated, total, donors_daily):
        df["pickup_date"] = pd.to_datetime(df["pickup_date"])
    if len(treated) != N_DAYS_ALL or len(total) != N_DAYS_ALL:
        raise RuntimeError(f"Αναμενόμενες {N_DAYS_ALL} ημέρες, βρέθηκαν {len(treated)} / {len(total)}.")

    # --- ημέρες κενού: ο ίδιος κανόνας για «πριν» και «μετά»
    gap_days = find_gap_days(total.set_index("pickup_date")["total"])
    gap_pre = [d for d in gap_days if d < POLICY_START]
    gap_post = [d for d in gap_days if d >= POLICY_START]
    if gap_pre != EXPECTED_GAP_DAYS:
        raise RuntimeError(f"Οι ημέρες κενού «πριν» άλλαξαν: {[str(d.date()) for d in gap_pre]}")

    # --- δότες: οι μεγαλύτεροι κατά μέσο όγκο ΜΟΝΟ στο «πριν»
    pre_daily = donors_daily[donors_daily["pickup_date"] < POLICY_START]
    zone_avg = (pre_daily.groupby(["pickup_zone_id", "pickup_zone_name"])["n_trips"].mean()
                .rename("avg_trips_day").reset_index().sort_values("avg_trips_day", ascending=False))
    zone_avg = zone_avg[~zone_avg["pickup_zone_id"].isin(list(exclude_zone_ids))]
    donors = zone_avg.head(n_donors).reset_index(drop=True)
    donors_daily = donors_daily[donors_daily["pickup_zone_id"].isin(donors["pickup_zone_id"])].copy()

    # --- εβδομαδιαία αθροίσματα (μόνο πλήρεις εβδομάδες των 7 ημερών)
    treated["week"] = _week_start(treated["pickup_date"])
    donors_daily["week"] = _week_start(donors_daily["pickup_date"])
    cols = ["n_trips", "n_trips_excl_type0", "dist", "dur"]
    t_week = treated.groupby("week")[cols].sum()
    n_days = treated.groupby("week")["pickup_date"].count()
    t_week = t_week[n_days == 7]
    d_week = donors_daily.groupby(["week", "pickup_zone_id"])[cols].sum()
    n_pre = int((t_week.index < POLICY_START).sum())
    n_post = int((t_week.index >= POLICY_START).sum())
    if n_pre != N_PRE_WEEKS or n_post != N_POST_WEEKS:
        raise RuntimeError(f"Αναμενόμενες {N_PRE_WEEKS} + {N_POST_WEEKS} εβδομάδες, βρέθηκαν {n_pre} + {n_post}.")

    def _logs(df):
        return {"trips_all": np.log(df["n_trips"]), "trips_excl_type0": np.log(df["n_trips_excl_type0"]),
                "speed": np.log(df["dist"] / df["dur"] * 3600.0)}

    y_all = _logs(t_week)
    x_all = {ind: pd.DataFrame({z: _logs(d_week.xs(z, level="pickup_zone_id").loc[t_week.index])[ind]
                                for z in donors["pickup_zone_id"]}) for ind in INDICATORS}

    gap_weeks = sorted(set(_week_start(pd.Series(gap_days))))
    keep = t_week.index if keep_gap_weeks else t_week.index.difference(pd.DatetimeIndex(gap_weeks))
    out = {"weeks": keep, "pre_weeks": keep[keep < POLICY_START], "post_weeks": keep[keep >= POLICY_START],
           "gap_days": gap_days, "gap_days_post": gap_post, "dropped_weeks": [] if keep_gap_weeks else gap_weeks,
           "donors": donors, "y": {}, "X": {}}
    for ind in INDICATORS:
        out["y"][ind] = y_all[ind].loc[keep]
        out["X"][ind] = x_all[ind].loc[keep]
        bad = (~np.isfinite(out["y"][ind])).sum() + (~np.isfinite(out["X"][ind].to_numpy())).sum()
        if bad:
            raise RuntimeError(f"Μη πεπερασμένες τιμές στον δείκτη {ind} ({bad}).")
    return out


def load_full_daily(db_path=None) -> pd.DataFrame:
    """Ημερήσια διαφορά D = log(Κέντρο) - log(Αναφορά χωρίς αεροδρόμια) για τους τρεις δείκτες, όλες οι ημέρες.
    Οι ημέρες κενού γίνονται κενές τιμές."""
    con = _connect(db_path)
    try:
        df = con.execute("""
            select pickup_date,
                   route_group,
                   cast(sum(n_trips) as double)                  as n_trips,
                   cast(sum(n_trips_excl_type0) as double)       as n_trips_excl_type0,
                   cast(sum(sum_distance_miles_speed) as double) as dist,
                   cast(sum(sum_duration_sec_speed) as double)   as dur
            from mart_route_day
            where route_group = 'treated' or (route_group = 'control' and not touches_airport)
            group by pickup_date, route_group
        """).df()
        total = con.execute("""
            select pickup_date, cast(sum(n_trips) as double) as total
            from mart_route_day group by pickup_date order by pickup_date
        """).df()
    finally:
        con.close()
    df["pickup_date"] = pd.to_datetime(df["pickup_date"])
    total["pickup_date"] = pd.to_datetime(total["pickup_date"])
    gap_days = find_gap_days(total.set_index("pickup_date")["total"])

    t = df[df["route_group"] == "treated"].set_index("pickup_date").sort_index()
    c = df[df["route_group"] == "control"].set_index("pickup_date").sort_index()
    if len(t) != N_DAYS_ALL or len(c) != N_DAYS_ALL:
        raise RuntimeError("Λείπουν ημέρες στις σειρές Κέντρου / Αναφοράς.")
    out = pd.DataFrame(index=t.index)
    out["D_trips_all"] = np.log(t["n_trips"]) - np.log(c["n_trips"])
    out["D_trips_excl_type0"] = np.log(t["n_trips_excl_type0"]) - np.log(c["n_trips_excl_type0"])
    out["D_speed"] = np.log(t["dist"] / t["dur"]) - np.log(c["dist"] / c["dur"])
    out.loc[out.index.isin(gap_days), :] = np.nan
    out["post"] = (out.index >= POLICY_START).astype(int)
    out["dow"] = out.index.dayofweek
    out["month"] = out.index.month
    out["k"] = np.floor((out.index - POLICY_START).days / 28).astype(int)   # διάστημα 4 εβδομάδων σε σχέση με 5/1/2025
    return out