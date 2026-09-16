# `data/examples/` — curated example datasets

**Empty by design.** Filled by task **B-02** (Rachael, Wednesday block W2).

Three real datasets, exported as CSV from the `survival` package, each with its exact derivation
recorded so anyone can regenerate it:

| File | Source | Derivation | Verified headline result |
| --- | --- | --- | --- |
| `nwtco_high_risk.csv` | `survival::nwtco` | `stage %in% c(3, 4)`; time `edrel`, status `rel`, `time_scale = "days_to_years"` | **Cure model appropriate** |
| `gbsg.csv` | `survival::gbsg` | all rows; time `rfstime`, status `status`, `time_scale = "days_to_years"` | **Follow-up insufficient for cure modeling** |
| `colon_lev5fu.csv` | `survival::colon` | `etype == 1 & rx == "Lev+5FU"`; time `time`, status `status`, `time_scale = "days_to_years"` | **Follow-up insufficient** (borderline) |

Plus the four simulated scenarios from `simulate_cure_data()` (task **B-03**), which are generated
by committed code with a fixed seed rather than stored as data.

Full specification, licences and provenance requirements: [`docs/data-contract.md`](../../docs/data-contract.md).

**Public and simulated data only.** No restricted, clinical, or identifiable data enters this
repository — the app is demonstrated in a public room and this repository is public.
