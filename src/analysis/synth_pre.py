import argparse
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import statsmodels.api as sm
from scipy.optimize import minimize

sys.path.insert(0, str(Path(__file__).resolve().parent))
from load_donors import INDICATORS, load_pre_weekly  # noqa: E402

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

LAST_TRAIN_WEEK = pd.Timestamp("2024-06-23")   # η τελευταία εβδομάδα εκπαίδευσης (τελειώνει 29/6/2024)
HOLDOUT_START = pd.Timestamp("2024-06-30")     # πρώτη εβδομάδα δοκιμής (έως 4/1/2025)
NW_LAGS = 4                                     # υστέρηση Newey-West (εβδομάδες)
LABELS = {"trips_all": "Πλήθος α (με τύπο 0)", "trips_excl_type0": "Πλήθος β (χωρίς τύπο 0)", "speed": "Ταχύτητα"}


def fit_weights(y_c: np.ndarray, x_c: np.ndarray) -> np.ndarray:
    """Βάρη w >= 0 με άθροισμα 1 που ελαχιστοποιούν Σ (y - X w)^2 (κεντραρισμένες σειρές)."""
    n = x_c.shape[1]
    w0 = np.full(n, 1.0 / n)

    def f(w):
        r = y_c - x_c @ w
        return float(r @ r)

    def g(w):
        return -2.0 * x_c.T @ (y_c - x_c @ w)

    res = minimize(f, w0, jac=g, method="SLSQP", bounds=[(0.0, 1.0)] * n,
                   constraints=[{"type": "eq", "fun": lambda w: w.sum() - 1.0, "jac": lambda w: np.ones(n)}],
                   options={"ftol": 1e-14, "maxiter": 2000})
    if not res.success:
        print(f"  ΠΡΟΣΟΧΗ: ο βελτιστοποιητής δεν συγκλίνει καθαρά ({res.message})")
    w = np.clip(res.x, 0.0, None)
    return w / w.sum()


def run(n_donors: int, keep_gap_weeks: bool, exclude_zones: list) -> None:
    data = load_pre_weekly(n_donors=n_donors, keep_gap_weeks=keep_gap_weeks, exclude_zone_ids=exclude_zones)
    weeks = data["weeks"]
    train = weeks[weeks <= LAST_TRAIN_WEEK]
    hold = weeks[weeks >= HOLDOUT_START]
    donors = data["donors"]

    print(f"Δότες: {n_donors} (μεγαλύτεροι κατά όγκο). Μέσος όγκος του μικρότερου: {donors['avg_trips_day'].min():.0f} διαδρομές/ημέρα.")
    if exclude_zones:
        print(f"Αποκλείστηκαν οι ζώνες: {exclude_zones}")
    print(f"Εβδομάδες: εκπαίδευση {len(train)}, δοκιμή {len(hold)}, αφαιρέθηκαν {len(data['dropped_weeks'])} (ημέρες κενού).")
    print("-" * 78)

    suffix = (f"_{n_donors}donors" + ("_keepgap" if keep_gap_weeks else "")
              + ("_without_" + "_".join(str(z) for z in exclude_zones) if exclude_zones else ""))
    fig, axes = plt.subplots(len(INDICATORS), 2, figsize=(13, 3.4 * len(INDICATORS)), squeeze=False)

    for i, ind in enumerate(INDICATORS):
        y = data["y"][ind]
        X = data["X"][ind]
        y_mean = y.loc[train].mean()
        X_mean = X.loc[train].mean()
        w = fit_weights((y.loc[train] - y_mean).to_numpy(), (X.loc[train] - X_mean).to_numpy())
        synth = y_mean + (X - X_mean).to_numpy() @ w
        synth = pd.Series(synth, index=weeks)
        gap = y - synth

        rmse_tr = float(np.sqrt((gap.loc[train] ** 2).mean()))
        rmse_ho = float(np.sqrt((gap.loc[hold] ** 2).mean()))
        fit = sm.OLS(gap.loc[hold].to_numpy(), np.ones(len(hold))).fit(cov_type="HAC", cov_kwds={"maxlags": NW_LAGS})
        mean_gap = float(fit.params[0])
        lo, hi = (float(v) for v in fit.conf_int()[0])
        passed = lo <= 0.0 <= hi

        print(f"{LABELS[ind]}")
        print(f"  RMSE εκπαίδευσης: {rmse_tr*100:.2f}%   RMSE δοκιμής: {rmse_ho*100:.2f}%   λόγος: {rmse_ho/max(rmse_tr, 1e-12):.2f}")
        print(f"  Μέσο κενό στη δοκιμή: {mean_gap*100:+.2f}%   95% διάστημα [{lo*100:+.2f}, {hi*100:+.2f}]   -> "
              f"{'ΠΕΡΝΑ' if passed else 'ΔΕΝ ΠΕΡΝΑ'}")
        top = pd.Series(w, index=donors["pickup_zone_id"].to_numpy()).sort_values(ascending=False).head(6)
        names = donors.set_index("pickup_zone_id")["pickup_zone_name"]
        print("  Μεγαλύτερα βάρη: " + ", ".join(f"{names[z]} {v*100:.0f}%" for z, v in top.items()))
        print(f"  Δότες με βάρος > 1%: {int((w > 0.01).sum())} από {n_donors}")
        print("-" * 78)

        ax = axes[i, 0]
        ax.plot(weeks, (y - y_mean) * 100, label="Κέντρο", color="#1f4e79")
        ax.plot(weeks, (synth - y_mean) * 100, label="Synthetic", color="#c0504d", linestyle="--")
        ax.axvspan(HOLDOUT_START, weeks.max(), color="grey", alpha=0.12)
        ax.set_title(f"{LABELS[ind]}: Κέντρο και synthetic (% από τον μέσο όρο εκπαίδευσης)", fontsize=9)
        ax.legend(fontsize=8)
        ax = axes[i, 1]
        ax.plot(weeks, gap * 100, color="#4d4d4d")
        ax.axhline(0, color="black", linewidth=0.6)
        ax.axvspan(HOLDOUT_START, weeks.max(), color="grey", alpha=0.12)
        ax.set_title(f"{LABELS[ind]}: κενό (%) — γκρι = δοκιμή", fontsize=9)

    fig.tight_layout()
    out_dir = Path(__file__).resolve().parents[2] / "outputs" / "figures"
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / f"synth_pre{suffix}.png"
    fig.savefig(out, dpi=130)
    print(f"Γράφημα: {out}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--n-donors", type=int, default=25)
    ap.add_argument("--keep-gap-weeks", action="store_true")
    ap.add_argument("--exclude-zones", type=int, nargs="*", default=[])
    a = ap.parse_args()
    run(a.n_donors, a.keep_gap_weeks, a.exclude_zones)