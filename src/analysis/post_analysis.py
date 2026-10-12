import re
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import statsmodels.formula.api as smf

sys.path.insert(0, str(Path(__file__).resolve().parent))
from load_donors import INDICATORS, POLICY_START  # noqa: E402
from load_post import load_full_daily, load_full_weekly  # noqa: E402
from synth_pre import LABELS, fit_weights  # noqa: E402

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

ROOT = Path(__file__).resolve().parents[2]

# Ζώνη θορύβου B ανά δείκτη, σε % λογαριθμικές μονάδες. Προέρχεται από τα δεδομένα «πριν» (synth_pre.py).
B = {"trips_all": 4.21, "trips_excl_type0": 5.42, "speed": 3.58}
P_MAX = 0.05

ANALYSES = [
    ("main",     dict(n_donors=25, keep_gap_weeks=False, exclude_zone_ids=())),
    ("12donors", dict(n_donors=12, keep_gap_weeks=False, exclude_zone_ids=())),
    ("40donors", dict(n_donors=40, keep_gap_weeks=False, exclude_zone_ids=())),
    ("keepgap",  dict(n_donors=25, keep_gap_weeks=True,  exclude_zone_ids=())),
    ("without70", dict(n_donors=25, keep_gap_weeks=False, exclude_zone_ids=(70,))),
]


def synth_gap(y: pd.Series, X: pd.DataFrame, pre_weeks) -> tuple:
    """Προσαρμογή με όλο το «πριν». Επιστρέφει (κενό ανά εβδομάδα, βάρη)."""
    y_mean = y.loc[pre_weeks].mean()
    X_mean = X.loc[pre_weeks].mean()
    w = fit_weights((y.loc[pre_weeks] - y_mean).to_numpy(), (X.loc[pre_weeks] - X_mean).to_numpy())
    synth = pd.Series(y_mean + (X - X_mean).to_numpy() @ w, index=y.index)
    return y - synth, w


def run_synthetic() -> tuple:
    rows, weekly, main_data, main_gaps = [], [], None, {}
    for name, kw in ANALYSES:
        data = load_full_weekly(**kw)
        if name == "main":
            main_data = data
            print(f"Ημέρες κενού «μετά» που βρέθηκαν με τον κανόνα: "
                  f"{[str(d.date()) for d in data['gap_days_post']] or 'καμία'}")
        for ind in INDICATORS:
            gap, w = synth_gap(data["y"][ind], data["X"][ind], data["pre_weeks"])
            post = gap.loc[data["post_weeks"]]
            rows.append({"analysis": name, "indicator": ind, "n_post_weeks": len(post),
                         "mean_post_gap_logpct": float(post.mean() * 100),
                         "mean_post_gap_pct": float((np.exp(post.mean()) - 1) * 100),
                         "top_donor": data["donors"].set_index("pickup_zone_id")["pickup_zone_name"][
                             pd.Series(w, index=data["donors"]["pickup_zone_id"]).idxmax()],
                         "top_weight_pct": float(w.max() * 100)})
            if name == "main":
                main_gaps[ind] = gap
                for wk in data["weeks"]:
                    weekly.append({"week": wk, "indicator": ind, "treated_log": data["y"][ind].loc[wk],
                                   "gap_log": gap.loc[wk], "is_post": wk >= POLICY_START})
    return pd.DataFrame(rows), pd.DataFrame(weekly), main_data, main_gaps


def run_placebo(data: dict) -> tuple:
    """Placebo σε χώρο: κάθε δότης ως ψεύτικο Κέντρο, με τους υπόλοιπους ως μείγμα."""
    means, paths = {}, {}
    for ind in INDICATORS:
        X = data["X"][ind]
        m, p = [], {}
        for z in X.columns:
            gap, _ = synth_gap(X[z], X.drop(columns=z), data["pre_weeks"])
            m.append(float(gap.loc[data["post_weeks"]].mean() * 100))
            p[z] = gap
        means[ind], paths[ind] = np.array(m), p
    return means, paths


def event_study_plot(daily: pd.DataFrame, out: Path) -> pd.DataFrame:
    rows = []
    fig, axes = plt.subplots(len(INDICATORS), 1, figsize=(10, 3.2 * len(INDICATORS)), squeeze=False)
    for i, ind in enumerate(INDICATORS):
        col = f"D_{ind}"
        d = daily[[col, "k", "dow", "month", "post"]].dropna()
        m = smf.ols(f"{col} ~ C(k, Treatment(reference=-1)) + C(dow) + C(month)", data=d).fit(
            cov_type="HAC", cov_kwds={"maxlags": 14})
        ks, est, lo, hi = [], [], [], []
        for name, val in m.params.items():
            mt = re.search(r"\[T\.(-?\d+)\]", name)
            if mt and name.startswith("C(k"):
                ci = m.conf_int().loc[name]
                ks.append(int(mt.group(1))); est.append(val * 100); lo.append(ci[0] * 100); hi.append(ci[1] * 100)
        ks, est, lo, hi = map(np.array, (ks, est, lo, hi))
        order = np.argsort(ks)
        ks, est, lo, hi = ks[order], est[order], lo[order], hi[order]
        ax = axes[i, 0]
        ax.errorbar(ks, est, yerr=[est - lo, hi - est], fmt="o", color="#1f4e79", ecolor="#8fb3d9", capsize=2, markersize=3)
        ax.axhline(0, color="black", linewidth=0.6)
        ax.axvline(-0.5, color="#c0504d", linestyle="--", linewidth=0.8)
        ax.set_title(f"{LABELS[ind]}: event study (% διαφορά Κέντρου–Αναφοράς, σε σχέση με τις 4 εβδομάδες πριν)", fontsize=9)
        ax.set_xlabel("Διάστημα 4 εβδομάδων σε σχέση με 5/1/2025", fontsize=8)
        for k_, e_, l_, h_ in zip(ks, est, lo, hi):
            rows.append({"indicator": ind, "k": int(k_), "estimate_logpct": e_, "ci_low": l_, "ci_high": h_})
    fig.tight_layout()
    fig.savefig(out, dpi=130)
    return pd.DataFrame(rows)


def run_did(daily: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for ind in INDICATORS:
        col = f"D_{ind}"
        d = daily[[col, "post", "dow", "month"]].dropna()
        m = smf.ols(f"{col} ~ post + C(dow) + C(month)", data=d).fit(cov_type="HAC", cov_kwds={"maxlags": 14})
        lo, hi = m.conf_int().loc["post"]
        rows.append({"indicator": ind, "beta_logpct": m.params["post"] * 100, "ci_low": lo * 100, "ci_high": hi * 100,
                     "n_days": int(m.nobs)})
    return pd.DataFrame(rows)


def main() -> None:
    tables = ROOT / "outputs" / "tables"
    figs = ROOT / "outputs" / "figures"
    tables.mkdir(parents=True, exist_ok=True)
    figs.mkdir(parents=True, exist_ok=True)

    print("=" * 78)
    print("1. SYNTHETIC CONTROL, μέσο κενό «μετά» (51 εβδομάδες, 5/1–27/12/2025) σε % λογαριθμικές μονάδες")
    print("=" * 78)
    summary, weekly, main_data, main_gaps = run_synthetic()
    piv = summary.pivot(index="analysis", columns="indicator", values="mean_post_gap_logpct").loc[[a for a, _ in ANALYSES]]
    print(piv[INDICATORS].round(2).to_string())
    print("\nΜεγαλύτερος δότης στην κύρια ανάλυση:")
    print(summary[summary["analysis"] == "main"][["indicator", "top_donor", "top_weight_pct"]].round(1).to_string(index=False))

    print("\n" + "=" * 78)
    print("2. PLACEBO ΣΕ ΧΩΡΟ (κύρια ανάλυση, κάθε δότης ως ψεύτικο Κέντρο)")
    print("=" * 78)
    placebo_means, placebo_paths = run_placebo(main_data)
    n_donors = main_data["X"][INDICATORS[0]].shape[1]
    pvals = {}
    for ind in INDICATORS:
        real = float(piv.loc["main", ind])
        pvals[ind] = (1 + int((np.abs(placebo_means[ind]) >= abs(real)).sum())) / (1 + n_donors)
        print(f"{LABELS[ind]}: μέσο κενό Κέντρου {real:+.2f}%, p = {pvals[ind]:.3f} "
              f"(διάμεσος |κενού| δοτών {np.median(np.abs(placebo_means[ind])):.2f}%)")

    print("\n" + "=" * 78)
    print("3. ΚΑΝΟΝΑΣ ΖΩΝΗΣ ΘΟΡΥΒΟΥ")
    print("=" * 78)
    rules_rows = []
    for ind in INDICATORS:
        vals = piv[ind].to_numpy()
        c1 = abs(piv.loc["main", ind]) > B[ind]
        c2 = bool(np.all(np.sign(vals) == np.sign(vals[0])) and np.all(np.abs(vals) > B[ind]))
        c3 = pvals[ind] <= P_MAX
        verdict = ("ΕΝΔΕΙΞΗ ΑΛΛΑΓΗΣ (όχι αιτιώδης εκτίμηση)" if (c1 and c2 and c3)
                   else f"ΔΕΝ ΔΙΑΚΡΙΝΕΤΑΙ από την προϋπάρχουσα απόκλιση (αποτέλεσμα μικρότερο από ±{B[ind]}% ή όχι σταθερό)")
        print(f"{LABELS[ind]}  B = {B[ind]}%")
        print(f"   (1) κύρια |κενό| > B: {'ναι' if c1 else 'όχι'}   "
              f"(2) ίδιο πρόσημο και |κενό| > B στις 5: {'ναι' if c2 else 'όχι'}   "
              f"(3) p ≤ {P_MAX}: {'ναι' if c3 else 'όχι'}")
        print(f"   -> {verdict}")
        rules_rows.append({"indicator": ind, "B": B[ind], "main_gap_logpct": float(piv.loc["main", ind]),
                           "min_abs_gap_5": float(np.abs(vals).min()), "max_abs_gap_5": float(np.abs(vals).max()),
                           "c1_main_gt_B": bool(c1), "c2_all5_same_sign_gt_B": bool(c2), "c3_p_le_max": bool(c3),
                           "p_value": float(pvals[ind]),
                           "median_abs_placebo_logpct": float(np.median(np.abs(placebo_means[ind]))),
                           "n_donors": int(n_donors), "evidence_of_change": bool(c1 and c2 and c3)})

    print("\n" + "=" * 78)
    print("4. DiD (ΜΟΝΟ περιγραφικό, ο έλεγχος «πριν» απέτυχε) και event study")
    print("=" * 78)
    daily = load_full_daily()
    did = run_did(daily)
    for _, r in did.iterrows():
        print(f"{LABELS[r['indicator']]}: β = {r['beta_logpct']:+.2f}%  95% [{r['ci_low']:+.2f}, {r['ci_high']:+.2f}]  (ημέρες: {r['n_days']})")
    es = event_study_plot(daily, figs / "did_event_study.png")

    # --- αρχεία και γράφημα synthetic control
    summary.to_csv(tables / "synth_post_summary.csv", index=False)
    weekly.to_csv(tables / "synth_post_weekly_main.csv", index=False)
    did.to_csv(tables / "did_summary.csv", index=False)
    es.to_csv(tables / "event_study.csv", index=False)
    # Πίνακας με τον κανόνα ανά δείκτη (συνθήκες, τιμή p, συμπέρασμα)
    pd.DataFrame(rules_rows).to_csv(tables / "synth_post_rules.csv", index=False)

    fig, axes = plt.subplots(len(INDICATORS), 1, figsize=(10, 3.4 * len(INDICATORS)), squeeze=False)
    for i, ind in enumerate(INDICATORS):
        ax = axes[i, 0]
        for z, g in placebo_paths[ind].items():
            ax.plot(g.index, g * 100, color="#bbbbbb", linewidth=0.6)
        ax.plot(main_gaps[ind].index, main_gaps[ind] * 100, color="#1f4e79", linewidth=1.8, label="Κέντρο")
        ax.axvline(POLICY_START, color="#c0504d", linestyle="--", linewidth=0.9)
        ax.axhline(0, color="black", linewidth=0.6)
        ax.axhspan(-B[ind], B[ind], color="#f2c94c", alpha=0.18, label="ζώνη θορύβου ±B")
        ax.set_ylim(-max(40, 3 * B[ind]), max(40, 3 * B[ind]))
        ax.set_title(f"{LABELS[ind]}: κενό Κέντρου (μπλε) και placebo δοτών (γκρι), % — κόκκινη γραμμή = 5/1/2025", fontsize=9)
        ax.legend(fontsize=8, loc="upper left")
    fig.tight_layout()
    fig.savefig(figs / "synth_post_main.png", dpi=130)
    print(f"\nΑρχεία: {tables}\\*.csv και {figs}\\did_event_study.png, synth_post_main.png")


if __name__ == "__main__":
    main()
