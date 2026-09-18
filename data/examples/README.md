# `data/examples/` — curated example datasets

Three real datasets, exported as CSV from the `survival` package, each with its exact derivation
recorded so anyone can regenerate it:

| File | Source | Derivation | Verified headline result |
| --- | --- | --- | --- |
| `nwtco_high_risk.csv` | `survival::nwtco` | `stage %in% c(3, 4)`; time `edrel`, status `rel`, `time_scale = "days_to_years"` | **Cure model appropriate** |
| `gbsg.csv` | `survival::gbsg` | all rows; time `rfstime`, status `status`, `time_scale = "days_to_years"` | **Follow-up insufficient for cure modeling** |
| `colon_lev5fu.csv` | `survival::colon` | `etype == 1 & rx == "Lev+5FU"`; time `time`, status `status`, `time_scale = "days_to_years"` | **Follow-up insufficient** (borderline) |

---

## Simulated data sets

The app includes four examples of simulated data sets. See `data-raw/make_examples.R` for more details. 

| File | Source | Derivation | Verified headline result |
| --- | --- | --- | --- |
| `sim_a.csv` | `simulate_cure_data()` | `n = 300`, `shape = 1.2`, `scale = 1`, `seed = 11`, `cure_fraction = 0.40`, `admin_followup = 10`, `dropout_rate = 0.03`; `time_scale = "none"` | **Cure model appropriate** |
| `sim_b.csv` | `simulate_cure_data()` | as above with `cure_fraction = 0.40`, `admin_followup = 1.5`, `dropout_rate = 0.03` | **Cure model not supported** |
| `sim_c.csv` | `simulate_cure_data()` | as above with `cure_fraction = 0.00`, `admin_followup = 10`, `dropout_rate = 0.03` | **Cure model not supported** — MZ, `qn` and Shen all `NA` |
| `sim_d.csv` | `simulate_cure_data()` | as above with `cure_fraction = 0.00`, `admin_followup = 10`, `dropout_rate = 0.45` | **Cure model not supported** — MZ, `qn` and Shen all `NA` |

We also include several additional simulated data sets which provide examples with various follow up times and cure fractions.
