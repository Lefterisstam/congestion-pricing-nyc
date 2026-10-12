from pathlib import Path

import matplotlib

matplotlib.use("Agg")  # χωρίς παράθυρο, αποθηκεύει σε αρχείο
import matplotlib.pyplot as plt
import pandas as pd
import statsmodels.formula.api as smf

from load_series import load_pre_period
import argparse

parser = argparse.ArgumentParser()
parser.add_argument("--control-no-airports", action="store_true",
                    help="Η Αναφορά χωρίς διαδρομές που αγγίζουν αεροδρόμιο")
args = parser.parse_args()
suffix = "_control_no_airports" if args.control_no_airports else ""

OUTCOMES = {
    "trips_all": "Διαδρομές (εκδοχή α, με τύπο 0)",
    "trips_excl_type0": "Διαδρομές (εκδοχή β, χωρίς τύπο 0)",
    "speed": "Μέση ταχύτητα",
}
FIG_DIR = Path(__file__).resolve().parents[2] / "outputs" / "figures"

d = load_pre_period(control_excludes_airports=args.control_no_airports)
print("Αναφορά:", "ΧΩΡΙΣ αεροδρόμια" if args.control_no_airports else "όλες οι διαδρομές outside -> outside")
d["dow"] = d.index.dayofweek
d["month"] = d.index.month
d["t_years"] = (d.index - d.index[0]).days / 365.25
d["block"] = (d.index - d.index[0]).days // 28  # μπλοκ 4 εβδομάδων

block_tables = {}
for col, label in OUTCOMES.items():
    # 1) Τάση: προσθέτουμε γραμμική τάση στο μοντέλο. Σφάλματα HAC, υστέρηση 14 ημερών.
    m_trend = smf.ols(f"{col} ~ C(dow) + C(month) + t_years", data=d).fit(
        cov_type="HAC", cov_kwds={"maxlags": 14}
    )
    b = m_trend.params["t_years"] * 100          # σε ποσοστιαίες μονάδες ανά έτος
    lo, hi = m_trend.conf_int().loc["t_years"] * 100
    verdict = "ΠΕΡΝΑ" if lo <= 0 <= hi else "ΔΕΝ ΠΕΡΝΑ"
    print(f"\n==== {label} ====")
    print(f"Τάση της διαφοράς Κέντρου-Αναφοράς: {b:+.2f}% ανά έτος (95% ΔΕ: {lo:+.2f}% έως {hi:+.2f}%)  ->  {verdict}")

    # 2) Μπλοκ 4 εβδομάδων: μέση διαφορά μετά την αφαίρεση ημέρας εβδομάδας και μήνα
    m0 = smf.ols(f"{col} ~ C(dow) + C(month)", data=d).fit()
    d["adj"] = m0.resid * 100
    tbl = d.groupby("block").agg(start=("adj", lambda s: s.index.min().date()), n_days=("adj", "size"), mean=("adj", "mean"))
    block_tables[col] = tbl[tbl["n_days"] == 28]  # κρατάμε μόνο πλήρη μπλοκ

summary = pd.DataFrame({col: tbl["mean"] for col, tbl in block_tables.items()})
summary.insert(0, "start", block_tables["trips_all"]["start"])
print("\nΜέση διαφορά ανά μπλοκ 4 εβδομάδων (ποσοστιαίες μονάδες, μετά την αφαίρεση ημέρας/μήνα):")
print(summary.to_string(float_format=lambda x: f"{x:6.2f}"))

FIG_DIR.mkdir(parents=True, exist_ok=True)
fig, axes = plt.subplots(len(OUTCOMES), 1, figsize=(9, 8), sharex=True)
for ax, (col, label) in zip(axes, OUTCOMES.items()):
    ax.plot(summary["start"], summary[col], marker="o")
    ax.axhline(0, color="grey", linewidth=0.8)
    ax.set_title(label)
    ax.set_ylabel("% μονάδες")
fig.tight_layout()
fig.savefig(FIG_DIR / f"pretrend_blocks{suffix}.png", dpi=120)
print(f"\nΤο γράφημα αποθηκεύτηκε στο {FIG_DIR / f'pretrend_blocks{suffix}.png'}")