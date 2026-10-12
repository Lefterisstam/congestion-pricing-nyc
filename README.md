# Did NYC congestion pricing change yellow-taxi traffic?

On 5 January 2025 New York started charging a fee to vehicles entering Manhattan south of 60th Street. We wanted to know whether, after that date, yellow taxis made fewer (or more) trips in the zone, and whether they moved faster. We used the official TLC trip records from January 2023 to December 2025, and built everything locally with SQL, dbt, DuckDB and Python.

## What we found

**With this data we cannot say that anything changed.** That is not the same as "nothing changed": our method simply cannot tell a change of this size apart from the noise that was already there before the policy.

| Indicator | Average gap after 5 Jan 2025 | Noise band | Verdict |
|---|---|---|---|
| Trips per week (including payment type 0) | −11.0% | ±4.2% | not distinguishable |
| Trips per week (excluding payment type 0) | −1.3% | ±5.4% | not distinguishable |
| Average speed | −2.6% | ±3.6% | not distinguishable |

The −11% in the first row looks like a result, but it does not hold up: with a different set of comparison zones it ranges from −0.2% to −20%. Payment type 0 is also recorded differently over time, which distorts the count on its own. Speed comes out slightly negative in every run, but stays inside the noise. Charts are in `outputs/figures/`, tables in `outputs/tables/` (both explained below).

## The data pipeline (dbt)

Most of the work went into getting the data right, and that lives in the dbt project (`dbt_project/`). Raw TLC parquet files are read directly by DuckDB and go through three layers:

- **Staging** (`stg_yellow_trips`): reads all monthly parquet files, renames columns, and keeps track of which file each row came from.
- **Intermediate** (`int_trips_flagged`, `int_trips_rejected`): every trip gets validity flags instead of being silently dropped. There is one rule for trips in general (pickup inside its file's month, positive duration, at most 4 hours), a stricter one for speed (non-zero distance, at most 100 miles, at most 80 mph), and a separate one for counting trips. `int_trips_rejected` shows what each rule removes, month by month. The thresholds are dbt variables, not hard-coded.
- **Marts** (`mart_route_day`, `mart_control_zone_day`): one row per day and route group (35,072 rows), and one row per day and comparison zone. Trips are grouped by the geography of *both* ends, not by whether a fee was charged, so the policy cannot decide who ends up in which group. Zones are classified from the taxi-zone shapefile with DuckDB spatial and stored as a seed (`cbd_zone_flags`).

`dbt build` runs 47 nodes: 5 models, 2 seeds and 40 tests. Eight of the tests are custom SQL checks, for example that every group has exactly one row per day, that the marts add up to the cleaned trips, that the zone mart reconciles with the route mart, and that fee amounts are missing only before 2025. About fifty profiling queries in `dbt_project/analyses/` are how we investigated the data. They turned up the things that shaped the analysis: payment type 0 growing in steps and unevenly, vendor 7 reporting zero-duration trips, an outage on 21–24 September 2023, and airport trips distorting the comparison group's speed.

## How we measured it

We compared the trips in the Center with a "synthetic Center" built as a weighted mix of zones outside the charging area (synthetic control). Before the policy the two lines should move together; afterwards, the gap between them shows what changed. To avoid reading noise as a finding, we measured how far apart the lines already were *before* the policy, and that became the noise band in the table. We set this rule before looking at the 2025 data. There is no machine learning here; it is statistical analysis.

## Things to keep in mind

- We only see yellow taxis, not Uber, Lyft or private cars, so nothing here describes overall traffic in the city.
- There is no clean comparison group: some drivers may have changed behaviour before the policy started, and its effect may have reached neighbouring zones.
- The indicators already had a trend before 5 January 2025, so the simple before/after comparison (DiD) is shown for description only.
- We tried one definition of the groups (the comparison group excludes airport trips) and did not test others.

## What each file is for

```
congestion-pricing-nyc/
├── src/
│   ├── ingest/
│   │   ├── download_tlc.py       downloads the monthly TLC trip files into data/raw/
│   │   └── download_zones.py     downloads the taxi-zone lookup (seed) and shapefile
│   └── analysis/
│       ├── load_series.py        reads the daily series from DuckDB, pre-policy days only
│       ├── pretrend_check.py     checks whether Center and comparison moved in parallel before the policy
│       ├── load_donors.py        reads the weekly series of each comparison zone, pre-policy only
│       ├── synth_pre.py          builds the synthetic Center on pre-policy data and tests it on weeks it did not see; this is where the noise band comes from
│       ├── load_post.py          reads the same series including 2025 (used only by post_analysis.py)
│       ├── post_analysis.py      the final analysis: five synthetic-control runs, placebo test, the decision rule, DiD and event study
│       └── run_sql.py            small helper to run any file from dbt_project/analyses/ and print the result
├── dbt_project/
│   ├── models/                   staging, intermediate and mart SQL, plus schema.yml with column tests
│   ├── seeds/                    taxi_zone_lookup.csv and cbd_zone_flags.csv (which zones are in the charging area)
│   ├── tests/                    the 8 custom SQL tests
│   ├── analyses/                 the profiling and validation queries (profile_*, validate_*, reconcile_*, zones_*)
│   ├── dbt_project.yml           project settings and the cleaning thresholds
│   └── profiles.yml              connection to the local DuckDB file
├── outputs/
│   ├── figures/                  charts, listed below
│   └── tables/                   result tables, listed below
├── tests/
│   ├── conftest.py               builds a small fake DuckDB so tests never need the real data
│   └── test_analysis.py          6 tests for the analysis code
├── pyproject.toml, uv.lock       dependencies (uv)
├── pytest.ini                    tells pytest to look in tests/
├── .python-version               Python 3.12
└── .gitignore                    keeps data, the database and build folders out of the repo
```

Folders you will see after running things, which are not in the repo: `data/` (raw parquet files, the DuckDB database built by dbt) and `dbt_project/target/` and `dbt_project/logs/` (dbt's own output).

**Why the analyses folder is there.** The `profile_*` queries look at the raw and cleaned data (missing fees, payment types, vendors, group sizes). `validate_*` and `reconcile_*` check that the groups and the cleaning behave as intended. `zones_*` is how the zone classification was built and checked, and `zones_06_export_cbd_flags.sql` produces the `cbd_zone_flags` seed. They are kept because they are the evidence behind the cleaning rules and the group definitions.

**Charts in `outputs/figures/`**

| File | Shows |
|---|---|
| `pretrend_blocks.png`, `pretrend_blocks_control_no_airports.png` | Center vs comparison group in 28-day blocks before the policy (the second excludes airport trips). This is the check that showed they do not move in parallel. |
| `synth_pre_25donors.png` | The main synthetic Center (25 comparison zones) against the real one, with the weeks it was tested on. |
| `synth_pre_12donors.png`, `synth_pre_40donors.png`, `synth_pre_25donors_keepgap.png`, `synth_pre_25donors_without_70.png` | The same test with 12 or 40 zones, with the outage weeks kept, and without zone 70. They show how much the result depends on those choices. |
| `synth_post_main.png` | Real vs synthetic Center after 5 Jan 2025, with the noise band. |
| `did_event_study.png` | The before/after comparison (DiD) and the event study, descriptive only. |

**Tables in `outputs/tables/`**

| File | Contains |
|---|---|
| `synth_post_summary.csv` | The average gap per indicator in each of the five runs. |
| `synth_post_weekly_main.csv` | Week by week, real vs synthetic Center for the main run. |
| `synth_post_rules.csv` | The three conditions of the decision rule and the verdict for each indicator. |
| `did_summary.csv`, `event_study.csv` | DiD estimates and the 28-day event-study estimates. |

## How to run

You need [uv](https://docs.astral.sh/uv/) and Python 3.12 or newer. The data goes in `data/raw/`, which is not in the repo.

```bash
uv sync

# data (one month per argument, 2023-01 to 2025-12)
uv run python src/ingest/download_tlc.py yellow 2023-01 2023-02 2023-03
uv run python src/ingest/download_zones.py

# tables and data-quality tests
cd dbt_project && uv run dbt build && cd ..

# analysis (this loads the 2025 data)
uv run python src/analysis/post_analysis.py

# Python tests
uv run pytest -q

# optional: run any profiling query
uv run python src/analysis/run_sql.py dbt_project/analyses/profile_01_schema.sql
```

`synth_pre.py` and `pretrend_check.py` can be run on their own (`uv run python src/analysis/synth_pre.py`) and produce the `pretrend_*` and `synth_pre_*` charts.
