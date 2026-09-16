# Data contract — cureAssessApp

**Task:** B-01 · **Owner:** Rachael Oluwakamiye Abolade · **Backup:** Geethanjalee Mudunkotuwa
**Scheduled in:** W2 (Wed 1:00–3:00) · **Consumed by:** A-02 (Data tab v1), A-03 (CSV upload + column mapper), B-02, B-03

This document defines what a dataset must look like before `cureAssessApp` will analyse it, what the
`cureAssess` package itself enforces, and what the app must therefore enforce on the package's behalf.

The app does not exist yet. Everything below is a specification for Pod A to build against and for
Pod B to test against. Where a decision has not been made, the text says `[to confirm]` rather than
guessing.

Two rules govern the whole document:

1. **Validate in the app, before calling the package.** `.check_surv_data()` is a backstop, not a
   gate. It is weaker than it looks (see section 2) and its failures arrive as raw R errors.
2. **Never silently change a user's data.** Every remap, rescale and dropped row must be visible on
   screen with a count.

---

## 1. What the app needs from a dataset

The minimum is small. One rectangular table, and in it two columns:

| Requirement | Detail |
| --- | --- |
| **One row per subject** | One record per patient/subject. No long-format repeated rows, no multiple episodes per subject, no time-varying covariate rows. |
| **A time-to-event column** | Numeric. The observed follow-up time: time to the event if the event happened, otherwise time to last contact. Must be non-negative. One unit throughout the column. |
| **An event indicator column** | Two levels. One level means "the event was observed", the other means "this subject was censored". The app asks the user which level means *event* (see section 3). |
| **Right-censored data only** | A censored row means: no event up to time `Y`, unknown thereafter. Left-censored, interval-censored, and left-truncated/delayed-entry data are **out of scope** for this app. |
| **One group at a time** | The published methods assess a single group. A dataset spanning several treatment arms must be filtered to one arm before analysis (this is why the `colon` example is restricted to a single arm — see section 7). Side-by-side group comparison is stretch goal **S-3**, not in scope. |

Anything else in the table (covariates, IDs, stage, arm) is ignored by the assessment. It may be
carried along for filtering and display, but no covariate enters any of the models the app fits.

Everything else the app shows — n, event count, censored %, median follow-up, max follow-up, the KM
plot, the AIC table, the five diagnostics, the verdict — is derived from these two columns alone.

---

## 2. The package's own requirements

### What `prepare.surv.data()` does

```r
prepare.surv.data(data, time, status, time_scale = c("none", "days_to_years"))
```

It is a thin wrapper. In order, it:

1. Resolves `time_scale` with `match.arg()`.
2. Copies the column named by `time` into a new column **`Y`** and the column named by `status` into a
   new column **`D`**, with `dplyr::mutate()`. **The original columns are kept.** So a dataset that
   already has a column called `Y` or `D` will have it overwritten in the returned frame — the app
   must warn if the uploaded file already contains a column named `Y` or `D`.
3. If `time_scale = "days_to_years"`, divides `Y` by `365.25`.
4. Calls the internal `.check_surv_data()` and returns the frame.

It does **not** drop missing rows, sort, deduplicate, coerce types, or check that `Y >= 0`. Every
downstream function (`model.fitting()`, `run.cure.tests()`, `mz.test()`, `receus.method()`, …) calls
`.check_surv_data()` again on whatever it is handed, and works from `Y` and `D` only.

### What `.check_surv_data()` enforces

Reading `R/utils.checks.R`, four `stop()` calls exist. In the `prepare.surv.data()` path only **two**
can ever fire — checks 3 and 4 — because step 2 above always creates both `Y` and `D`, and it pipes
`data` into `dplyr::mutate()` before the check runs, so a non-data-frame fails there first:

| # | Condition | Exact message the user sees | Can it fire via `prepare.surv.data()`? |
| --- | --- | --- | --- |
| 1 | `!is.data.frame(data)` | ``Error: `data` must be a data.frame.`` | **No.** Step 2 hands `data` to `dplyr::mutate()` first, so a matrix or a list dies there with a `no applicable method for 'mutate'` error and this message is never reached. Only fires when a bare object is passed straight to `model.fitting()` / `mz.test()` / etc. |
| 2 | `Y` or `D` absent from `names(data)` | ``Error: `data` must contain columns: Y, D. Missing: D`` | **No.** Only fires when a bare data frame is passed straight to `model.fitting()` / `mz.test()` / etc. without going through `prepare.surv.data()` first. The app must never do that. |
| 3 | `!is.numeric(data$Y)` | ``Error: `Y` must be numeric.`` | Yes. |
| 4 | `!all(stats::na.omit(data$D) %in% c(0, 1))` | ``Error: `D` must be coded as 0/1.`` | Yes. |

All four use `call. = FALSE`, so the console shows `Error: ` followed by the message with no call
prefix.

Note check 4 carefully: **`na.omit()` removes missing values from `D` before the 0/1 test**, so a `D`
column containing `NA` passes this check. The package does not stop you from analysing data with
missing status. See section 5 for what happens next.

### The check is more permissive than it looks

`%in%` coerces before comparing, so all of the following pass check 4 and leave `D` in a non-integer
type:

- logical `TRUE` / `FALSE`
- character `"0"` / `"1"`
- a factor with levels `"0"` / `"1"`

They pass because `all(c(TRUE, FALSE) %in% c(0, 1))` and `all(c("0", "1") %in% c(0, 1))` are both
`TRUE`. **Do not treat "it passed `.check_surv_data()`" as "the status column is clean."** The app
must coerce the event indicator to integer `0L`/`1L` itself, before calling `prepare.surv.data()`.

### Two errors raised *before* the check

These come from `prepare.surv.data()`'s own body, not from `.check_surv_data()`:

| Condition | Message | Source |
| --- | --- | --- |
| `time`/`status` names a column that is not in `data` | ``Column `nope` not found in `.data`.`` (wrapped in ``In argument: `Y = .data[["nope"]]` ``) | dplyr/rlang |
| `time_scale` is anything other than `"none"` or `"days_to_years"` | `'arg' should be one of "none", "days_to_years"` | `match.arg()` |

### How the app maps these to friendly text

Requirement from **A-03**: a `.check_surv_data()` failure must never reach the user as a red Shiny
crash. The mapping table below is the contract between Pod A and Pod B. Pod B tests every row.

| Package error | What actually went wrong | Text the app shows |
| --- | --- | --- |
| `` `Y` must be numeric. `` | The time column was read as text. Usual causes: a decimal comma (`3,5`), a thousands separator (`1,234`), or a text sentinel like `unknown` or `N/A (not reached)` in one cell. | "The time column **{name}** was read as text, not numbers. Check it for commas used as decimal points or thousands separators, and for cells containing words. Column preview: {first 5 distinct non-numeric values}." |
| `` `D` must be coded as 0/1. `` | The event indicator was not remapped to 0/1 before the call. Should be impossible if the column mapper does its job — treat this reaching the user as a **bug in the mapper**, file an issue. | "The event indicator could not be converted to 0 = censored / 1 = event. Please re-pick which value in **{name}** means *event*." |
| `` `data` must be a data.frame. `` | Internal — the app passed something that is not a data frame. | "Internal error preparing the dataset. Please report this." (and log it) |
| `` `data` must contain columns: Y, D. … `` | Internal — a function was called without `prepare.surv.data()` first. | Same as above. Never show the raw message. |
| `` Column `x` not found in `.data`. `` | The chosen column name no longer exists — e.g. the user changed files without re-picking columns. | "Column **{name}** is not in this file. Please choose the time and status columns again." |
| `'arg' should be one of …` | Internal — an unexpected value reached `time_scale`. | Same as internal above. |

Do **not** string-match these messages at runtime. The wording of the dplyr and `match.arg()` errors
depends on package versions. Validate in the app first; wrap the package call in `tryCatch()` and show
a generic friendly failure plus the raw message behind a "technical details" expander for the last
resort.

---

## 3. Event coding

**The package requires `0` = censored and `1` = event.** That is the whole rule, and it is enforced by
check 4 above.

### Why this is the single most likely cause of a failed upload

| Coding found in the wild | What happens | Why |
| --- | --- | --- |
| `0` / `1` | Works. | The required coding. |
| **`1` / `2`** (1 = censored/alive, 2 = event/dead) | **Errors:** `` `D` must be coded as 0/1. `` | Extremely common in clinical datasets and in SAS-derived exports. This is the case the column mapper exists for. |
| `"Yes"` / `"No"`, `"Dead"` / `"Alive"`, `"Relapse"` / `"Censored"` | **Errors:** `` `D` must be coded as 0/1. `` | Character levels are not 0/1. |
| `TRUE` / `FALSE` | **Passes the check**, but `D` stays logical. | `%in%` coerces logicals. It happens to survive the downstream fits, but it is unchecked territory and must not be relied on. The `nwtco` dataset ships a logical column (`in.subcohort`), so a user really can pick one by mistake. |
| `"0"` / `"1"` as text, or a factor with those levels | **Passes the check**, but `D` stays character/factor. | Same coercion. Same reason not to rely on it. |
| Three or more levels, e.g. `0` / `1` / `2` with 2 = death from another cause | Errors, or silently collapses if the app is careless. | Competing risks. See the escalation rule below. |

**The consequence for the app:** the app must not guess. It must ask the user which level means
*event*, do the remap itself, and only then call `prepare.surv.data()`. This is part of **A-03**.

### Remapping recipe

```r
# --- in the column mapper -----------------------------------------------------
raw <- df[[status_col]]                       # whatever the user picked
levs <- sort(unique(raw[!is.na(raw)]))        # show these to the user with counts

# The user chooses exactly one level as "event"; everything else is censored.
status01 <- ifelse(as.character(raw) == as.character(event_level), 1L, 0L)
status01[is.na(raw)] <- NA_integer_           # keep missing missing — see section 5

df$.cureassess_status <- status01

dat <- prepare.surv.data(
  data       = df,
  time       = time_col,
  status     = ".cureassess_status",
  time_scale = time_scale                     # "none" or "days_to_years"
)
```

Rules that go with the recipe:

- **Compare as character.** `as.character()` on both sides makes the same code work for numeric,
  character, factor and logical status columns without a type-by-type branch.
- **Never infer the event level from the values.** "The larger value is the event" is wrong for
  datasets where 0 = event, and "non-zero means event" is catastrophically wrong for 1/2 coding — it
  would mark every subject as an event. Always ask.
- **Show the levels with counts before and after.** The mapper must display, e.g., `2 → event
  (n = 299), 1 → censored (n = 387)` and then the resulting event count and censored %, so the user
  can see at a glance whether they picked the wrong level. A dataset that comes out 100 % events or
  0 % events is almost always a mis-pick, and the app should say so.
- **Preserve `NA`.** Do not let a missing status become a censored row. `ifelse` on an `NA` input
  returns `NA`, but write the explicit line anyway so the intent is legible.
- **Escalate more than two levels.** If the status column has three or more distinct non-missing
  values, the app must stop and explain that collapsing competing events into one indicator is a
  statistical decision, not a data-cleaning one. Route the user to the in-app help; route the team
  question to Geethanjalee.
- **Two levels is not "exactly two required".** A column that is all events or all censored is legal
  input to the package but will not produce a useful assessment. Warn, do not block. If nothing is
  censored, all three follow-up diagnostics will be `NA` (section 6).

---

## 4. Time units and scaling

`time_scale` has exactly two allowed values:

| Value | Effect on `Y` |
| --- | --- |
| `"none"` | `Y` is used exactly as supplied. |
| `"days_to_years"` | `Y <- Y / 365.25` |

Nothing else is accepted; anything else is a `match.arg()` error.

### Why the unit matters even though the thresholds do not

The diagnostic thresholds are **unitless**. Maller–Zhou < 0.05, Shen < 0.05, the `qn` threshold
`1 - 0.05^(1/n)`, and the RECeUS rule (π̂ > 0.025 **and** r̂ < 0.05) are all comparisons between
probabilities or proportions. Rescaling time does not move any of them.

But **every number the app reports with a time in it is in the input unit**: median follow-up, max
follow-up, the KM plot's x-axis, `receus.method()`'s `whichTau` (which defaults to the maximum
observed time), and the follow-up truncation slider if stretch goal **S-1** is built. A dataset in
days that is analysed as if it were years produces a verdict that is numerically correct and an
interpretation that is nonsense — "median follow-up 1,124" reads as a millennium.

So:

- The app must display the unit next to every time it prints, and the unit must come from what the
  user declared, not from a guess.
- The Data tab summary card (**A-02**) must label the unit explicitly, e.g. "median follow-up 4.65
  **years**".
- All three real example datasets record time in **days** and are analysed with
  `time_scale = "days_to_years"`; all four simulated scenarios are already in abstract time units and
  are analysed with `time_scale = "none"` (sections 7 and 8). Pod B's expected values are tied to
  those settings — changing the scale invalidates every reported follow-up time in the oracle.

### Months are not supported

There is no `months_to_years`. A dataset in months must be handled in one of two ways:

1. **Convert before upload.** Divide the time column by 12 in the source file, and select
   `time_scale = "none"`.
2. **Convert in the app.** If a months option is added to the mapper, the app divides `Y` by 12
   itself and then calls `prepare.surv.data(..., time_scale = "none")`.

**Never double-scale.** If the app performs its own division, `time_scale` must be `"none"`. Whether
a months option ships in v1.0 is a scope call for the lead — `[to confirm]`. If it does not ship, the
user guide (**D-02**) must say so in one sentence, and the mapper must offer only the two values the
package accepts.

Also worth stating in the in-app help: mixed units inside one column (some rows in days, some in
months) cannot be detected by any check in this pipeline. It is the user's responsibility.

---

## 5. Missing values

### Policy

> **Rows with a missing time or a missing status are dropped before analysis, and the app reports how
> many rows were dropped and why.**

Dropping is complete-case on the two analysis columns only — `Y` and the remapped status. Missing
values in covariates are irrelevant and must not cause a row to be dropped.

### Why the app has to do this, not the package

The package does not filter. Reading the source:

- `prepare.surv.data()` performs no `na.omit()`, no `complete.cases()`.
- `.check_surv_data()` calls `stats::na.omit()` only *inside* the 0/1 test, so a missing status passes
  validation untouched.
- An `NA` in `Y` is numeric, so it passes the `is.numeric()` test.

The `NA` then reaches the diagnostics. `mz.test()` computes `max(dat$Y[dat$D == 1])` and `max(dat$Y)`
with no `na.rm` and branches on `if (maxAll > maxE)`, so a single missing time or missing status
propagates an `NA` into that condition and R raises:

```
Error in if (maxAll > maxE) { : missing value where TRUE/FALSE needed
```

That is a raw internal error with no relationship to the user's actual problem, and it is exactly the
class of failure **A-03** exists to prevent. Drop the rows first.

### What the app must show

- A visible line on the Data tab: "Dropped **k** of **N** rows with a missing time or status
  (missing time: `a`; missing status: `b`)." Counts are reported separately so the user can tell
  which column is the problem.
- The dropped count must also appear in the downloadable HTML report (**B-07**), in the data summary
  section, so a report can never overstate its own sample size.
- `n` shown everywhere in the app is the analysed `n` — after dropping. Never mix the two.
- If dropping removes every row, or leaves a dataset with no events, the app shows a clear message
  and stops; it does not attempt to fit.
- Non-finite times (`Inf`, `-Inf`) and negative times are not `NA` and will not be caught by any
  package check. The app rejects them with an explicit message. Note that `simulate_cure_data()`
  deliberately uses `Inf` internally for cured subjects' latent event times, but the `Y` it returns is
  always finite because of the `pmin` with the censoring time — so a finite-time check is safe against
  the simulated corpus.

---

## 6. Minimum viable dataset

There is **no minimum `n` enforced anywhere in the package**, and this project has not set one.
Do not hard-code a threshold in the app until Geethanjalee has signed one off — `[to confirm]`.
What can be said is what actually breaks, and in which direction.

### Too few events: the fits fail

`model.fitting()` fits a cure **and** a non-cure model for exponential, Weibull, gamma and
log-logistic (plus lognormal when `include_lognormal = TRUE`), all by maximum likelihood. Mixture
cure models estimate a cure fraction and an uncured survival distribution at the same time, so they
need enough events to pin down the uncured part and enough long-term censored survivors to pin down
the plateau. With too few of either, the optimiser does not converge.

`model.fitting()` **never throws** on a failed fit. It records the message in the `error` column and
sets `AIC = NA` for that row. The Models tab (**A-05**) therefore must display the `error` column
rather than hide it — a sparse AIC table with populated error strings is the app working correctly,
not the app broken. `cure.appropriateness()` picks the best model from rows where `AIC` is not `NA`.

### Too little censoring: the follow-up diagnostics are undefined

Maller–Zhou, `qn` and Shen can only be computed when **the largest observed time is a censored
observation**. The logic in `mz.test()` is explicit: it takes `maxE` = the largest event time and
`maxAll` = the largest observed time, and only computes a statistic when `maxAll > maxE`. Otherwise
it returns `statistic = NA_real_` with the interpretation string

> "The test cannot be computed because the largest observed time corresponds to an event rather than a
> censored observation."

This is not an error. It is a correct refusal, and it is common: it happens on **any** dataset whose
longest-followed subject had the event. It is logged as risk **R7** with likelihood High.

### The concrete example: simulated scenario C

Scenario C (section 8) is the verified case to test against. True cured proportion 0.00, admin
follow-up 10, dropout rate 0.03 — which leaves only **4 % censoring**, so the largest observed time is
an event, and **the Maller–Zhou, `qn` and Shen statistics all come back `NA`**. This is recorded
outcome for scenarios C and D; C is the cleanest illustration because the cause is unambiguous, the
verdict is a true negative (`weibull`, non-cure, π̂ = 0.000, r̂ = 0.9992, "Cure model not supported"),
and nothing else is going wrong at the same time.

The Diagnostics tab (**A-07**) must render, for each `NA` statistic, an explanatory state — the
package's own interpretation string plus plain wording along the lines of "cannot be computed — the
longest observed time is an event, so there is no plateau to test" — **not** a blank cell, not the
literal text `NA`, and not a crash. Scenario C is the regression test for that state.

### Practical guidance

- Every dataset in the verified corpus has `n >= 300`: the smallest is `colon_lev5fu` at
  **n = 304**, and all four simulated scenarios use **n = 300**. Treat that as the empirically
  exercised range, not as a proven lower bound.
- Below roughly that size, expect failed cure fits, wide or unstable RECeUS estimates, and diagnostics
  that are individually computable but not worth much. The app should warn, not block — the honest
  message is that the assessment is unreliable, not that it is impossible.
- A dataset with **0 events**, **0 censored**, or **1 row** must be rejected before any fit is
  attempted, with a specific reason.
- A `[to confirm]` warning threshold (a soft "this dataset is small" notice) is a good F2 polish item
  if Geethanjalee supplies a number.

---

## 7. The built-in example datasets

Three real, public datasets. All three ship with the **`survival`** R package — verified on the
development machine as `survival` **3.8-6**, licence **LGPL (>= 2)**. Nothing here is restricted or
identifiable; all three are long-published teaching datasets redistributed with a standard open-source
R package. Confirm the licence string on the hackathon VM with
`packageDescription("survival")$License` before committing, and record it in
`data/examples/README.md` (task **B-02**).

Curation target (**B-02**): each is written to `data/examples/` as a CSV with a `README.md` giving
provenance, licence, the exact derivation code, and the column meanings.

| ID | Source | Derivation | Time / status columns | Verified headline result |
| --- | --- | --- | --- | --- |
| `nwtco_high_risk` | `survival::nwtco` | High-risk subset: **stage 3–4** | `edrel` (days) / `rel` (0/1) | **n = 1404.** AIC best `loglogistic_cure` (AIC 1928.38). π̂ = 0.7823, r̂ = 0.0041. MZ 1.04e-140, `qn` 0.2051, Shen 0.0496. Verdict: **Cure model appropriate**. |
| `gbsg` | `survival::gbsg` | Whole dataset, no filtering | `rfstime` (days) / `status` (0/1) | **n = 686.** AIC best `loglogistic_cure` (AIC 1719.70). π̂ = 0.3238, r̂ = 0.3080. MZ 0.0495, `qn` 0.0044, Shen 0.3676. Verdict: **Follow-up insufficient for cure modeling**. |
| `colon_lev5fu` | `survival::colon` | Recurrence endpoint (`etype == 1`), Lev+5FU arm (`rx == "Lev+5FU"`) | `time` (days) / `status` (0/1) | **n = 304.** AIC best `loglogistic_cure` (AIC 741.52). π̂ = 0.5736, r̂ = 0.0640. MZ 5.25e-13, `qn` 0.0888, Shen 0.0065. Verdict: **Follow-up insufficient** — borderline, r̂ = 0.064 against the 0.05 threshold. |

**Provenance of the numbers.** Produced 2026-09-15 with R 4.6.1, `cureAssess` 0.1.0, `flexsurv` 2.3.2,
`flexsurvcure` 1.3.3, via `cure.appropriateness(time_scale = "days_to_years", run_tests = "yes")`.
These are the oracle targets for **G-01**; a full `cure.appropriateness()` run takes 0.1–0.2 s. Any
app output that disagrees with a number in this table is a **blocking** bug (risk **R5**), not a
cosmetic one.

**Column notes worth writing into `data/examples/README.md`:**

- All three time columns are in **days** and are analysed with `time_scale = "days_to_years"`.
- `colon` carries two endpoint rows per subject: `etype == 1` is recurrence, `etype == 2` is death.
  Filtering to `etype == 1` is what makes it one row per subject, which the contract in section 1
  requires. `rx` is a factor with levels `Obs`, `Lev`, `Lev+5FU`; restricting to one arm is what
  section 1's "one group at a time" rule requires.
- `nwtco$stage` is an integer 1–4, so the high-risk subset is `stage %in% c(3, 4)`.
- `nwtco` also contains `in.subcohort`, a **logical** column. It is a realistic trap for the column
  mapper (section 3): a user who picks it as the status column gets past `.check_surv_data()` and
  analyses nonsense. The mapper must show the chosen column's levels and counts so this is visible.

**Teaching value — these are the demo, not just test fixtures:**

1. **`gbsg` is the money example.** AIC picks a *cure* model, so a naive analyst would stop there and
   fit one. But r̂ = 0.3080 means about 31 % of uncured patients are still censored at the end of
   follow-up, so the cure fraction cannot be estimated reliably. A better AIC fit is not evidence that
   a cure model is identifiable — which is exactly why Stage 1 alone is not enough.
2. **The diagnostics disagree on `gbsg`, and that is not a bug.** Maller–Zhou (0.0495 < 0.05) says
   follow-up is sufficient; `qn`, Shen and RECeUS all say it is not. They are descriptive aids to be
   read together with subject-matter knowledge, not one decision rule. The app must say so (**A-08**).
3. **`colon_lev5fu` is the borderline case** — r̂ = 0.064 sits just above the 0.05 threshold. Good for
   showing that thresholds are conventions, not laws.

---

## 8. The simulated scenarios

Four synthetic datasets, generated in-repo, no provenance questions, full control of ground truth.
Implementation is **B-03** (W3); committing the datasets and expected verdicts is **B-05** (T1).

### Reference implementation

Reproduce this exactly. It is already validated, and the verified outcomes below depend on it
character for character — in particular on `set.seed()` being called first.

```r
simulate_cure_data <- function(n = 300, cure_fraction = 0.3, shape = 1.0,
                               scale = 1.0, admin_followup = 5,
                               dropout_rate = 0.05, seed = 1) {
  set.seed(seed)
  cured   <- rbinom(n, 1, cure_fraction)
  T_event <- ifelse(cured == 1, Inf, rweibull(n, shape = shape, scale = scale))
  C_drop  <- if (dropout_rate > 0) rexp(n, rate = dropout_rate) else rep(Inf, n)
  C       <- pmin(C_drop, admin_followup)
  data.frame(Y = pmin(T_event, C), D = as.integer(T_event <= C), .cured = cured)
}
```

How to read it:

- `cure_fraction` is the probability a subject is **cured**. A cured subject gets a latent event time
  of `Inf`, so they can only ever be censored.
- Censoring is the earlier of random dropout (`rexp(dropout_rate)`) and administrative end of
  follow-up (`admin_followup`).
- The returned frame is **already in the package's own naming scheme** — `Y` and `D`, with `D`
  integer 0/1 — so it satisfies the data contract by construction and needs no column mapping.
- `.cured` is the ground-truth cured indicator. It is **for Pod B's verification only**. It must never
  be passed as a covariate, must never be selectable as the status column, and should be dropped or
  clearly flagged in any CSV the app can load, so nobody ever assesses `.cured` by accident.
- `time_scale` for all four scenarios is `"none"` — these are abstract time units (read them as years
  against `admin_followup`), not days.

### Parameter matrix and verified outcomes

Fixed across all four: `n = 300`, `shape = 1.2`, `scale = 1`, `seed = 11`, `time_scale = "none"`.

| Scenario | `cure_fraction` (true cured proportion) | `admin_followup` | `dropout_rate` | AIC best | π̂ | r̂ | Verdict |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **A** | 0.40 | 10 | 0.03 | `weibull_cure` (cure) | 0.358 | 0.0000 | **Cure model appropriate** |
| **B** | 0.40 | 1.5 | 0.03 | `loglogistic` (**non-cure**) | 0.020 | 0.9786 | Cure model not supported |
| **C** | 0.00 | 10 | 0.03 | `weibull` (**non-cure**) | 0.000 | 0.9992 | Cure model not supported |
| **D** | 0.00 | 10 | 0.45 | `weibull` (**non-cure**) | 0.000 | 0.9973 | Cure model not supported |

| Scenario | What it teaches |
| --- | --- |
| **A** | The happy path: a real cure fraction plus mature follow-up. |
| **B** | A real cure fraction is *invisible* when follow-up is short. Truncating follow-up loses it. This is the mechanism stretch goal **S-1** dramatises live. |
| **C** | True negative. **MZ, `qn` and Shen are all `NA`** — only 4 % censored, so the largest observed time is an event and the follow-up tests are undefined. |
| **D** | Heavy dropout creates a KM plateau that is a *censoring artifact*, not cure. The diagnostics correctly refuse it. |

**Spec consequence, found by testing and repeated here because it drives UI work:** in scenarios C and
D the Maller–Zhou, `qn` and Shen statistics come back `NA`, because the package can only compute them
when the largest observed time is censored. The Diagnostics tab must render a clear "cannot be
computed — the longest observed time is an event, so there is no plateau to test" message rather than a
blank cell, an `NA`, or a crash. Scenarios C and D are the acceptance tests for that state.

Together with the three real datasets this is the **seven-dataset corpus** that the Definition of Done
requires the app to reproduce exactly, and that **B-08** signs off in T4.

---

## 9. CSV format for uploads

The upload path (**A-03**) accepts a single CSV file. Acceptance criterion for that task: uploading
`gbsg.csv` reproduces the built-in `gbsg` path exactly — same n, same AIC table, same diagnostics, same
verdict.

### Required format

| Rule | Detail |
| --- | --- |
| **Delimiter** | Comma. Not semicolon, not tab, not pipe. |
| **Header row** | Exactly one, the first line. Column names must be unique and non-empty — the mapper's dropdowns are built from them. |
| **One row per subject** | See section 1. |
| **Numbers** | Decimal **point**. `4.65`, never `4,65`. |
| **No thousands separators** | `1234`, never `1,234` or `1 234`. A quoted `"1,234"` survives parsing as text and then fails with `` `Y` must be numeric. ``; an unquoted `1,234` splits into two fields and corrupts every column after it. |
| **Missing values** | Empty cells or `NA`. Avoid `.`, `-`, `999`, `unknown`, `N/A (not reached)` — sentinel values either force the column to text or, worse, get analysed as real times. |
| **Encoding** | UTF-8 preferred, plain ASCII is safest. |
| **Reserved names** | If the file already has a column named `Y` or `D`, warn the user: `prepare.surv.data()` overwrites both. |

### What the app does with a file that does not comply

- **Unexpected delimiter.** Before parsing, sniff the first line. If it contains no comma but does
  contain a semicolon or a tab, stop and say so: "This file looks semicolon-delimited, not
  comma-delimited. Please save it as a comma-separated CSV and upload again." Do not silently try
  other separators, and do not proceed with a single mangled column — a one-column parse is the
  symptom users find hardest to diagnose themselves.
- **Only one column parsed.** Treat as a delimiter problem and show the same message, plus the first
  line of the file verbatim so the user can see what was read.
- **Encoding.** Read with an explicit encoding rather than the session default, so behaviour is the
  same on every machine. Strip a UTF-8 byte-order mark before parsing — an Excel "CSV UTF-8" export
  leaves one, and it corrupts the **first column's name**, which then does not match anything in the
  dropdowns. If names arrive with non-printing characters, trim them and tell the user the names were
  cleaned.
- **Ragged rows.** If rows have differing field counts, reject the file with the offending line number
  rather than analysing a partly-shifted table.
- **Anything else unparseable.** Friendly message plus the raw parser message behind a "technical
  details" expander. Never a red crash (**R6**, **A-03**).
- **File size.** No limit is set — `[to confirm]` with the lead. Shiny's default upload cap applies
  unless changed; if it is raised, say so in the user guide.

The app should always show a `head()` preview of the parsed table plus the detected column types
before the user maps columns, so a malformed parse is caught by eye in two seconds rather than by a
confusing error three clicks later.

---

## 10. Data we will not accept

**No restricted, clinical, or identifiable data of any kind enters this repository or this app during
the event.** Public and simulated data only. This is not a guideline to weigh against convenience; it
is a hard boundary.

Not permitted, at any point, in any form:

- Any St. Jude clinical or operational dataset, including the BMTCT datasets.
- The SWOG S1203 data.
- Any dataset under a data use agreement, IRB protocol, or institutional access control.
- Any dataset containing direct or indirect identifiers — names, MRNs, dates of birth, exact dates of
  service, ZIP codes, free-text notes.
- De-identified extracts of restricted data. "We removed the names" does not change the answer.
- Screenshots, printouts, or report files derived from any of the above.

Two reasons, both concrete:

1. **The app is demonstrated in a public room.** The lightning session (MTC Room 2, IA 1405) and the
   judging reception (MTC Atrium) put the screen in front of people outside the team. Anything loaded
   into the app is on display, and anything in the downloadable HTML report leaves the room with
   whoever downloaded it.
2. **The repository is public.** `stjude-biohackathon/KIDS26-Team9` is public and the app runs from a
   clean clone. A committed file cannot be un-published; deleting it later does not remove it from git
   history.

Operational consequences:

- The upload widget is for **public or synthetic files only**. This must be stated in the UI next to
  the file input, not buried in the About tab, because a demo audience member may well ask "can I try
  my own data?" during the booth rotation. The honest answer at the booth is: not on this machine, not
  today; the app runs locally, so it can be pointed at real data later in an appropriate environment,
  by them, under their own governance.
- `data/examples/` contains only the files described in sections 7 and 8.
- No test fixture, no scratch CSV, no "just for debugging" copy. Use the simulated scenarios — that is
  what they are for.
- If restricted data is committed by accident, that is an immediate stop-work: tell Durbadal at once,
  do not push further, do not try to fix it quietly with a follow-up commit.
- `[to confirm]` with the lead whether a `.gitignore` rule and a pre-commit guard on `*.csv` outside
  `data/examples/` is worth the ten minutes in W2. It probably is.

---

## 11. Validation checklist

Pod B runs this on **every** dataset before it enters the corpus — the three real ones (**B-02**), the
four simulated ones (**B-05**), and any file added later. Record the result in
`data/examples/README.md` next to the dataset.

**Provenance and permission**

- [ ] The dataset is public or synthetic. Nothing from section 10 is present.
- [ ] Source is named exactly: package and version, or the generating script and its seed.
- [ ] Licence recorded, with the command used to check it.
- [ ] Derivation is a committed, runnable code snippet — not a prose description.

**Structure**

- [ ] One row per subject. Confirmed, not assumed.
- [ ] If the source has multiple endpoint rows or multiple groups, the filter is explicit in the
      derivation code and the reason is written down.
- [ ] No column named `Y` or `D` unless it is intentional (the simulated scenarios ship `Y`/`D`
      deliberately).
- [ ] Ground-truth columns such as `.cured` are flagged as verification-only and cannot be selected as
      time or status.

**The two analysis columns**

- [ ] Time column identified by name, numeric, all values finite and non-negative.
- [ ] Time **unit** recorded, and the matching `time_scale` recorded with it.
- [ ] Status column identified by name; its distinct levels listed with counts.
- [ ] Which level means *event* is written down explicitly.
- [ ] After remapping, the status column is integer `0`/`1` — checked with `class()`, not by eye.
- [ ] Event count and censored % recorded.

**Missing and edge cases**

- [ ] Count of rows with missing time recorded.
- [ ] Count of rows with missing status recorded.
- [ ] Analysed `n` after complete-case dropping recorded, and it is the `n` quoted everywhere else.
- [ ] Checked whether the largest observed time is an event. If it is, the expected outcome records
      Maller–Zhou, `qn` and Shen as `NA` (section 6) and the dataset is used as a test of the
      "cannot be computed" UI state.
- [ ] Dataset has at least one event and at least one censored observation.

**Package round-trip**

- [ ] `prepare.surv.data()` runs without error or warning at the recorded `time_scale`.
- [ ] `model.fitting()` runs; the `error` column is inspected and any failed fits are recorded as
      expected outcomes rather than treated as surprises.
- [ ] `cure.appropriateness(run_tests = "yes")` runs end to end and its full output is committed to
      `tests/reference/` (**G-01**).
- [ ] The recorded expected values — AIC best model and value, π̂, r̂, all five diagnostics, verdict —
      match the oracle exactly. A mismatch is blocking (**R5**).

**Upload path**

- [ ] Exported to CSV and re-imported through the app's own upload path, producing identical output to
      the built-in path (the **A-03** acceptance criterion).
- [ ] CSV inspected as plain text: one header row, comma-delimited, decimal points, no thousands
      separators, no BOM.
