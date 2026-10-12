import numpy as np
import pandas as pd
import pytest

from load_donors import EXPLICIT_GAP_DAYS, _week_start, find_gap_days, load_pre_weekly
from load_post import load_full_weekly
from post_analysis import synth_gap
from synth_pre import fit_weights


def test_week_start_is_sunday():
    d = pd.Series(pd.to_datetime(["2025-01-04", "2025-01-05", "2025-01-06", "2025-01-11"]))
    got = _week_start(d).dt.strftime("%Y-%m-%d").tolist()
    assert got == ["2024-12-29", "2025-01-05", "2025-01-05", "2025-01-05"]


def test_gap_rule_flags_gap_but_not_holidays():
    idx = pd.date_range("2023-01-01", "2023-12-31")
    total = pd.Series(1000.0, index=idx)
    total[pd.Timestamp("2023-09-22"):pd.Timestamp("2023-09-24")] = 40.0   # κενό (4%)
    total[pd.Timestamp("2023-12-25")] = 500.0                              # αργία (50%): ΔΕΝ είναι κενό
    got = find_gap_days(total)
    assert [d.strftime("%Y-%m-%d") for d in got] == ["2023-09-21", "2023-09-22", "2023-09-23", "2023-09-24"]
    assert EXPLICIT_GAP_DAYS[0] in got


def test_fit_weights_recovers_known_mix():
    rng = np.random.default_rng(1)
    X = rng.normal(size=(80, 6))
    true_w = np.array([0.5, 0.3, 0.2, 0.0, 0.0, 0.0])
    y = X @ true_w + rng.normal(0, 0.01, 80)
    w = fit_weights(y - y.mean(), X - X.mean(axis=0))
    assert abs(w.sum() - 1.0) < 1e-9
    assert (w >= 0).all()
    assert np.allclose(w, true_w, atol=0.06)


def test_pre_loader_never_returns_post_weeks(fake_db):
    data = load_pre_weekly(db_path=fake_db)
    assert data["weeks"].max() < pd.Timestamp("2025-01-05")
    assert len(data["weeks"]) == 105 - 2          # 105 εβδομάδες «πριν», 2 αφαιρέθηκαν για το κενό
    assert len(data["gap_days"]) == 4


def test_pre_loader_rejects_mislabelled_post_rows(fake_db_mislabelled):
    # αν το is_post_policy ήταν λάθος και φορτώνονταν ημέρες «μετά», ο κώδικας πρέπει να σταματά
    with pytest.raises(RuntimeError):
        load_pre_weekly(db_path=fake_db_mislabelled)


def test_post_pipeline_recovers_injected_effect(fake_db):
    data = load_full_weekly(db_path=fake_db)
    assert len(data["pre_weeks"]) == 103 and len(data["post_weeks"]) == 51
    gap, _ = synth_gap(data["y"]["trips_all"], data["X"]["trips_all"], data["pre_weeks"])
    mean_post = gap.loc[data["post_weeks"]].mean() * 100
    assert -14.0 < mean_post < -11.5                 # ενσωματώθηκε -12% (λογαριθμικές μονάδες)
    gap_pre = gap.loc[data["pre_weeks"]].abs().mean() * 100
    assert gap_pre < 2.0                              # στο «πριν» το κενό είναι μικρό