# QA and Verification Plan — cureAssessApp

**Pod B working document.** Owners: Rachael Oluwakamiye Abolade (Data/QA Lead) and
Geethanjalee Mudunkotuwa (Science Lead). Backup for Rachael: Geethanjalee. Backup for
Geethanjalee: Durbadal.

Scope: how Pod B independently verifies the Shiny app against the `cureAssess` package.
The app does not exist yet. Everything below is the plan Pod B executes as Pod A builds,
in blocks W2 through F2.

Tasks covered here: **G-01**, **B-04**, **B-06**, **B-08**, **B-09**, **B-11**, and the
Pod B half of **B-10**.

---

## 1. The principle

**The people who verify are not the people who wrote the app.** Sharon and Rashid build
the tabs (Pod A). Rachael and Geethanjalee check them (Pod B). Nobody signs off on their
own code. If Pod B is short-handed in a block, Durbadal verifies — not the author of the
tab under test.

**The app is correct only if every number it prints equals what the `cureAssess` package
prints for the same input.** The app is a front end. It is allowed to relabel, reformat,
round for display, and add explanation. It is not allowed to produce a different number.
There is no such thing as "close enough" and no such thing as "the app's value is
better" — the package is the definition of the right answer.

**A mismatch is a blocking bug, not a cosmetic one.** This is risk **R5** in the risk
register and **item 3** of the Definition of Done: *every number the app prints matches
the reference oracle for all seven datasets*. A numeric mismatch means the Definition of
Done is not met, which means the feature is not done, which means it gets fixed before
anything new is built. File a GitHub issue immediately (per the conventions in
[team.md](team.md)), label it as blocking, and say it out loud at the next standup (Wed 4:45 pm,
Thu 9:30 am, Thu 4:45 pm, Fri 9:30 am).

Three corollaries worth stating plainly for the non-experts on the team:

- **A wrong number that looks plausible is the worst outcome of this hackathon.** A crash
  is visible and embarrassing for ten seconds. A silently wrong cure fraction is a tool
  that misleads a clinician. Verification is not paperwork; it is the product.
- **"The app agrees with itself" proves nothing.** Comparisons are always app output vs
  the committed oracle file, never app output vs app output, and never app output vs
  somebody's memory of the number.
- **Rounding is a display decision, not a computation.** If the app shows `0.7823` and
  the oracle holds `0.782301...`, that is a pass. If the app shows `0.78` where the spec
  says four decimals, that is a UI issue, not a numeric one — file it, but it does not
  block.

---

## 2. The reference oracle (task G-01)

**Owner: Geethanjalee. Block: W2 (Wed 1:00–3:00). This is the first thing Pod B ships,
because nothing else in this document can be executed until it exists.**

### What it is

A set of CSV files in `tests/reference/` produced by running `cureAssess` in **plain R** —
no Shiny, no app code, nothing from `app/` on the search path. These files are the
right answers. Every later verification pass reads them and compares.

Done looks like: `tests/reference/oracle.csv` exists on `main` with **one row per test
dataset and all seventeen columns below populated**; `tests/reference/aic_<dataset>.csv`
exists for each dataset; `tests/reference/session-info.txt` records the environment; and
the whole thing regenerates from a single committed script with no manual editing.

A full `cure.appropriateness()` run takes 0.1–0.2 s, so regenerating the entire oracle is
a matter of seconds. Regenerate rather than hand-edit, every time.

### Columns to record in `oracle.csv`

| Column | Source in the `cure.appropriateness()` return object |
| --- | --- |
| `dataset` | the corpus label from the script (see §3) |
| `n` | `nrow(res$data)` |
| `events` | `sum(res$data$D == 1)` |
| `censored_proportion` | `res$tests$immune$p_cens` |
| `max_followup` | `max(res$data$Y)` |
| `best_model` | `res$screening$best_model` |
| `best_model_type` | `res$screening$best_model_type` |
| `best_model_aic` | the `AIC` cell of the `best_model` row of `res$screening$aic_table` |
| `pi_hat` | `res$tests$receus$pi_hat` |
| `r_hat` | `res$tests$receus$r_hat` |
| `mz_statistic` | `res$tests$mz$statistic` |
| `qn_statistic` | `res$tests$qn$statistic` |
| `shen_statistic` | `res$tests$shen$statistic` |
| `immune_p_hat` | `res$tests$immune$p_hat` |
| `immune_p_cens` | `res$tests$immune$p_cens` |
| `receus_decision` | `res$tests$receus$decision` |
| `final_recommendation` | `res$final_recommendation` |

`censored_proportion` and `immune_p_cens` are deliberately the same quantity recorded
twice. They must be identical in every row; if they ever differ, the script is wrong, not
the package. It is a free internal consistency check.

### The exact snippet

Commit this as `tests/reference/make_oracle.R`. Run it with `R --vanilla` from the repo
root so no `.Rprofile` and no already-loaded package can influence the result.

```r
# tests/reference/make_oracle.R  —  task G-01
# Run from the repo root:  R --vanilla -f tests/reference/make_oracle.R
# Regenerates every file in tests/reference/. Never hand-edit the outputs.

library(survival)
library(cureAssess)

## ---- the simulator (verified reference implementation) ----
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

sim <- function(cure_fraction, admin_followup, dropout_rate) {
  simulate_cure_data(n = 300, cure_fraction = cure_fraction, shape = 1.2,
                     scale = 1, admin_followup = admin_followup,
                     dropout_rate = dropout_rate, seed = 11)
}

## ---- the seven-dataset corpus (section 3 of the QA plan) ----
corpus <- list(
  list(dataset = "nwtco_high_risk",
       data = subset(survival::nwtco, stage %in% c(3, 4)),
       time = "edrel", status = "rel", time_scale = "days_to_years"),
  list(dataset = "gbsg",
       data = survival::gbsg,
       time = "rfstime", status = "status", time_scale = "days_to_years"),
  list(dataset = "colon_lev5fu",
       data = subset(survival::colon, etype == 1 & rx == "Lev+5FU"),
       time = "time", status = "status", time_scale = "days_to_years"),
  list(dataset = "sim_A", data = sim(0.40, 10.0, 0.03),
       time = "Y", status = "D", time_scale = "none"),
  list(dataset = "sim_B", data = sim(0.40,  1.5, 0.03),
       time = "Y", status = "D", time_scale = "none"),
  list(dataset = "sim_C", data = sim(0.00, 10.0, 0.03),
       time = "Y", status = "D", time_scale = "none"),
  list(dataset = "sim_D", data = sim(0.00, 10.0, 0.45),
       time = "Y", status = "D", time_scale = "none")
)

dir.create("tests/reference", recursive = TRUE, showWarnings = FALSE)

rows <- list()

for (spec in corpus) {

  res <- cure.appropriateness(
    data       = spec$data,
    time       = spec$time,
    status     = spec$status,
    time_scale = spec$time_scale,
    plot_km    = FALSE,        # no plot object in the oracle
    run_tests  = "yes"         # always "yes", never "auto" — see gotcha 2
  )

  aic <- res$screening$aic_table
  tt  <- res$tests
  d   <- res$data

  rows[[spec$dataset]] <- data.frame(
    dataset              = spec$dataset,
    n                    = nrow(d),
    events               = sum(d$D == 1),
    censored_proportion  = tt$immune$p_cens,
    max_followup         = max(d$Y),
    best_model           = res$screening$best_model,
    best_model_type      = res$screening$best_model_type,
    best_model_aic       = aic$AIC[match(res$screening$best_model, aic$model)],
    pi_hat               = tt$receus$pi_hat,
    r_hat                = tt$receus$r_hat,
    mz_statistic         = tt$mz$statistic,
    qn_statistic         = tt$qn$statistic,
    shen_statistic       = tt$shen$statistic,
    immune_p_hat         = tt$immune$p_hat,
    immune_p_cens        = tt$immune$p_cens,
    receus_decision      = tt$receus$decision,
    final_recommendation = res$final_recommendation,
    stringsAsFactors     = FALSE
  )

  # full AIC table, so the Models tab can be checked row by row
  write.csv(aic,
            file.path("tests/reference",
                      paste0("aic_", spec$dataset, ".csv")),
            row.names = FALSE)

  # the package's own wording, so the app can be checked for paraphrasing
  writeLines(
    c(paste0("dataset: ", spec$dataset),
      paste0("receus_dist: ", res$selected_receus_dist),
      paste0("receus_model: ", res$selected_receus_model),
      "", "[mz]",     tt$mz$interpretation,
      "", "[qn]",     tt$qn$interpretation,
      "", "[shen]",   tt$shen$interpretation,
      "", "[immune]", tt$immune$interpretation,
      "", "[receus]", tt$receus$interpretation,
      "", "[decision]", tt$receus$decision,
      "", "[initial]",  res$screening$initial_decision,
      "", "[tests_reason]", res$tests_reason,
      "", "[final]",    res$final_recommendation),
    file.path("tests/reference",
              paste0("interpretation_", spec$dataset, ".txt"))
  )
}

oracle <- do.call(rbind, rows)
write.csv(oracle, "tests/reference/oracle.csv", row.names = FALSE)

writeLines(capture.output(sessionInfo()), "tests/reference/session-info.txt")

print(oracle[, c("dataset", "n", "best_model", "best_model_aic",
                 "pi_hat", "r_hat", "receus_decision")])
```

### Notes on the snippet that matter for correctness

- **`run_tests = "yes"`, never `"auto"`.** With `"auto"` the package silently skips
  Stage 2 whenever the smallest-AIC model is a non-cure model — which is exactly what
  happens in simulated scenarios B, C and D. An oracle built with `"auto"` would have
  empty diagnostics for three of the seven datasets. This is a documented gotcha in [`docs/shiny-app-spec.md`](../docs/shiny-app-spec.md), and
  it is also why the app itself defaults to `"yes"` (task A-08).
- **Do not call `.map_model_to_receus_dist()`.** It is internal. Let
  `cure.appropriateness()` pick the RECeUS distribution by leaving `dist = NULL`, and
  record what it picked in the interpretation file (`res$selected_receus_dist`). The app
  must be checked against *that* choice.
- **`include_lognormal` is left at its default `FALSE`.** The verified numbers in this document
  were produced with the four-distribution candidate set. If Pod A exposes the lognormal
  toggle (A-05), the toggle's **off** state is what the oracle covers; the **on** state
  needs its own oracle rows before it can be verified, which is a nice-to-have, not a
  Definition-of-Done item.
- **`write.csv()` writes full precision.** Do not round in the script. Rounding happens
  only in the app's display layer and only in this document's tables.
- **`plot_km = FALSE`** in the oracle. The KM plot is verified visually against the KM
  curve rendered by the app (§5), not by file comparison.

### Comparison rule

The authoritative comparison is **app value vs the committed `oracle.csv` at full
precision**, not app value vs a table in this document.

| App displays | Pass when |
| --- | --- |
| a value to 4 decimals | the oracle value rounds to the same 4 decimals (absolute difference below 5e-5) |
| a value in scientific notation | same mantissa to 3 significant figures and the same exponent |
| an AIC to 2 decimals | the oracle value rounds to the same 2 decimals |
| a model name | exact string match, including the `_cure` suffix |
| a decision or verdict | exact string match with `receus_decision`, or a paraphrase Geethanjalee has explicitly approved in writing |
| `NA` | the oracle cell is `NA` **and** the app shows the explanatory state, not a blank or the literal text `NA` |

Any other difference is a mismatch. Record it in the verification log (§7), file an issue,
and treat it as blocking.

---

## 3. The test corpus

Seven datasets: three real, four simulated. Definition-of-Done item 3 requires all seven
to match. Rachael curates the real ones to `data/examples/` as CSV with provenance and
licence (**B-02**, W2) and the simulated ones as committed CSVs with their expected
verdicts (**B-03** W3, **B-05** T1).

| # | Label | Kind | Derivation | `time` | `status` | `time_scale` | n |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `nwtco_high_risk` | real | `survival::nwtco` filtered to `stage %in% c(3, 4)` | `edrel` | `rel` | `days_to_years` | 1404 |
| 2 | `gbsg` | real | `survival::gbsg`, no filtering | `rfstime` | `status` | `days_to_years` | 686 |
| 3 | `colon_lev5fu` | real | `survival::colon` filtered to `etype == 1 & rx == "Lev+5FU"` | `time` | `status` | `days_to_years` | 304 |
| 4 | `sim_A` | simulated | `simulate_cure_data(n = 300, cure_fraction = 0.40, shape = 1.2, scale = 1, admin_followup = 10, dropout_rate = 0.03, seed = 11)` | `Y` | `D` | `none` | 300 |
| 5 | `sim_B` | simulated | same, `admin_followup = 1.5` | `Y` | `D` | `none` | 300 |
| 6 | `sim_C` | simulated | same as `sim_A` but `cure_fraction = 0.00` | `Y` | `D` | `none` | 300 |
| 7 | `sim_D` | simulated | same as `sim_C` but `dropout_rate = 0.45` | `Y` | `D` | `none` | 300 |

The three real datasets in words, for anyone mapping columns by hand in the app's
column mapper (A-03):

- **`nwtco` High risk** — the National Wilms Tumor Study cohort shipped with the
  `survival` package, restricted to **disease stage 3 and 4** (`stage %in% c(3, 4)`).
  Time column **`edrel`**, status column **`rel`**, both in days, so `time_scale` is
  **`"days_to_years"`**. This is the dataset whose n must read **1404** on the Data tab
  (the A-02 acceptance criterion).
- **`gbsg`** — the German Breast Cancer Study Group data shipped with `survival`, used
  **whole, with no filtering**. Time column **`rfstime`** (recurrence-free survival
  time), status column **`status`**, in days, so `time_scale` is **`"days_to_years"`**.
- **`colon_lev5fu`** — the adjuvant colon cancer trial shipped with `survival`,
  restricted to the **recurrence** endpoint (`etype == 1`) and the **Lev+5FU** treatment
  arm (`rx == "Lev+5FU"`). Time column **`time`**, status column **`status`**, in days,
  so `time_scale` is **`"days_to_years"`**.

The four simulated scenarios all use `n = 300`, `shape = 1.2`, `scale = 1`, `seed = 11`,
and `time_scale = "none"` — the times are already in the model's own units, so
converting them would be wrong. They vary only in true cure fraction, administrative
follow-up length, and dropout rate, which is the point: each one isolates one failure
mode. The `.cured` column the simulator emits is the ground truth and must **never** be
handed to `prepare.surv.data()` — it exists so Pod B can say what the right answer is,
not as an input.

**Verification cadence over the corpus:**

| Task | Block | Scope |
| --- | --- | --- |
| **B-04** | W3 (Wed 3:20–5:00) | Stage-1 numbers, app vs oracle, 3 real datasets |
| **B-06** | T2 (Thu 10:50–12:00) | AIC tables, app vs oracle, 3 real + 4 simulated |
| **B-08** | T4 (Thu 3:20–5:00) | Full regression: every tab, all seven datasets; commit the sign-off table |
| **B-09** | T4 (Thu 3:20–5:00) | Clean-clone test (§8) |
| **B-10** | F1 (Fri 9:30–10:30) | Work the issue list by severity; re-verify each fix |
| **B-11** | F2 (Fri 10:50–12:00) | Clean-clone re-test after all Friday changes (§8) |

File a GitHub issue per mismatch as it is found, not in a batch at the end of the block.

---

## 4. Verified expected results

These are the expected values. They were **produced on 2026-09-15 under R 4.6.1,
`cureAssess` 0.1.0, `flexsurv` 2.3.2, `flexsurvcure` 1.3.3**, via
`cure.appropriateness(time_scale = "days_to_years", run_tests = "yes")` for the real
datasets and `time_scale = "none"` for the simulated ones.

**Geethanjalee must regenerate and confirm these in G-01 rather than trusting them
blindly.** The hackathon VM is stated to carry R 4.6.1, but package versions on the VM
have not been checked, and a different `flexsurv` or `flexsurvcure` version can move an
optimiser to a different local maximum. If a regenerated value disagrees with the table
below, the **regenerated** value wins, `tests/reference/oracle.csv` is the record, and the
disagreement goes in `project-management/decisions.md` with the version numbers from
`tests/reference/session-info.txt` — because the deck, the booth script and the user
guide all quote these numbers and would all need updating.

### 4.1 Real datasets

| Dataset | n | AIC best model | π̂ (cure fraction) | r̂ | MZ (1994) | qn | Shen (2000) | RECeUS verdict |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `nwtco` High risk (stage 3–4), `edrel`/`rel` | 1404 | `loglogistic_cure` (AIC 1928.38) | 0.7823 | 0.0041 | 1.04e-140 | 0.2051 | 0.0496 | **Cure model appropriate** |
| `gbsg`, `rfstime`/`status` | 686 | `loglogistic_cure` (AIC 1719.70) | 0.3238 | 0.3080 | 0.0495 | 0.0044 | 0.3676 | **Follow-up insufficient for cure modeling** |
| `colon` recurrence, `Lev+5FU` arm | 304 | `loglogistic_cure` (AIC 741.52) | 0.5736 | 0.0640 | 5.25e-13 | 0.0888 | 0.0065 | **Follow-up insufficient** (borderline: r̂ = 0.064 vs the 0.05 threshold) |

### 4.2 Simulated scenarios

Verified with `n = 300, shape = 1.2, scale = 1, seed = 11` and `time_scale = "none"`.

| Scenario | True cure fraction | Admin follow-up | Dropout rate | AIC best | π̂ | r̂ | Verdict | What it teaches |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **A** | 0.40 | 10 | 0.03 | `weibull_cure` (cure) | 0.358 | 0.0000 | **Cure model appropriate** | The happy path: real cure fraction + mature follow-up. |
| **B** | 0.40 | 1.5 | 0.03 | `loglogistic` (**non-cure**) | 0.020 | 0.9786 | Cure model not supported | A real cure fraction is *invisible* when follow-up is short. Truncating follow-up loses it. |
| **C** | 0.00 | 10 | 0.03 | `weibull` (**non-cure**) | 0.000 | 0.9992 | Cure model not supported | True negative. **MZ, qn and Shen are all `NA` here** — only 4 % censored, so the largest observed time is an *event* and the follow-up tests are undefined. |
| **D** | 0.00 | 10 | 0.45 | `weibull` (**non-cure**) | 0.000 | 0.9973 | Cure model not supported | Heavy dropout creates a KM plateau that is a *censoring artifact*, not cure. The diagnostics correctly refuse it. |

### 4.3 What Pod B must be able to explain about these numbers

Anyone verifying needs to know which "wrong-looking" results are actually right, or they
will file three bad issues an hour.

- **`gbsg` is the money example.** AIC picks a *cure* model, so a naive analyst would
  stop there and fit one. But r̂ = 0.31 means ~31 % of uncured patients are still
  censored at the end of follow-up, so the cure fraction cannot be estimated reliably.
  **A better AIC fit is not evidence that a cure model is identifiable.** An app that
  shows "cure model won on AIC" and "follow-up insufficient" side by side is behaving
  correctly. Do not file that as a contradiction.
- **The diagnostics disagree on `gbsg`, and that is not a bug.** Maller–Zhou
  (0.0495 < 0.05) says follow-up is sufficient; `qn`, Shen and RECeUS all say it is not.
  They are descriptive aids to be read together with subject-matter knowledge, not a
  single decision rule. The app must say so on screen (A-08's "the diagnostics can
  disagree" panel). If that panel is missing, *that* is the bug.
- **`colon` is the borderline case** — r̂ = 0.064 sits just above the 0.05 threshold.
  Useful for showing that thresholds are conventions, not laws. It also makes `colon` the
  dataset most sensitive to a version change, so check it first when regenerating.
- **Scenarios C and D return `NA` for MZ, `qn` and Shen by design.** The package can only
  compute those three when the largest observed time is censored; when it is an event
  there is no plateau to test. `NA` here is the correct answer, and the app must render
  the explanation rather than a blank cell. See edge case 4 in §6 and risk **R7**.

---

## 5. What to test on each tab

One checklist per tab. Every line is a thing to look at with the oracle open beside the
app. Tick per dataset, not per tab — a tab that works on `gbsg` and breaks on `sim_C` is
a broken tab.

### 5.1 Data tab (A-02 Data tab v1, A-03 upload + column mapper, A-04 KM plot)

- [ ] The built-in dataset picker lists exactly the three curated real examples from
      `data/examples/` (B-02) with the labels Pod B chose, and the four simulated
      scenarios (B-05).
- [ ] Selecting "nwtco — High risk" shows **n = 1404**. This is A-02's stated acceptance
      criterion; if it reads anything else, the filter or the CSV is wrong.
- [ ] `n` matches `oracle.csv` `n` for all seven datasets.
- [ ] Event count matches `events`.
- [ ] Censored percentage matches `censored_proportion` (the app shows a percentage; the
      oracle stores a proportion — 0.5 in the oracle must read 50 %, not 0.5 %).
- [ ] Max follow-up matches `max_followup`, **and is in years for the three real
      datasets** — if the real datasets show max follow-up in the thousands, the
      `days_to_years` conversion is not being applied.
- [ ] Median follow-up is shown (A-02 requires it) — note this is **not** one of the
      G-01 oracle columns, so it has to be checked by an independent hand computation in
      plain R, not against `oracle.csv`. Its definition needs to be pinned down first:
      median of all observed times, or reverse-Kaplan–Meier median follow-up?
      **[to confirm with Geethanjalee]** Whatever she decides, the on-screen label must
      say which one it is.
- [ ] The `head()` table shows the standardised `Y` and `D` columns, so the user can see
      what `prepare.surv.data()` actually did to their input.
- [ ] Uploading `gbsg.csv` from `data/examples/` and mapping `rfstime` / `status` /
      event level / `days_to_years` reproduces the built-in `gbsg` path **exactly** —
      same n, same events, same max follow-up, and (once the other tabs exist) the same
      AIC table and the same verdict. This is A-03's acceptance criterion and the most
      valuable single check on the Data tab, because it proves the upload path and the
      built-in path share one code path.
- [ ] Switching `time_scale` between `none` and `days_to_years` changes max follow-up by
      a factor of 365.25 and nothing else structural.
- [ ] Choosing the wrong level as "event" flips the event count to n minus events. The
      mapper must make the choice explicit, not guess.
- [ ] KM plot renders with a risk table (A-04); the curve starts at 1.0, is monotone
      non-increasing, and its final plateau height is visually consistent with
      `1 - immune_p_hat` from the oracle.
- [ ] KM x-axis units match the chosen time scale and the axis is labelled with them.
- [ ] Switching datasets clears the previous dataset's summary and plot. Stale state from
      the previously selected dataset is a mismatch class of its own and easy to miss.

### 5.2 Models tab (A-05 AIC table, A-06 fitted-curve overlay)

- [ ] The table has one row per candidate model: eight rows with `include_lognormal`
      off, ten with it on.
- [ ] Every row's AIC matches the corresponding row of
      `tests/reference/aic_<dataset>.csv` — row by row, not just the winner.
- [ ] `best_model` and `best_model_type` match the oracle, including the `_cure` suffix.
      The best-model callout names the same model the table sorts to the top.
- [ ] The cure / non-cure badge agrees with `model_type` in the oracle AIC table for
      every row. `loglogistic_cure` is a cure model; `loglogistic` is not.
- [ ] Sorting the `DT` table by AIC ascending puts the oracle's `best_model` first, and
      rows with `AIC = NA` sort to the end rather than to the top.
- [ ] The **`error` column is visible**, not hidden. `model.fitting()` never throws on a
      failed fit — it records the message and sets `AIC = NA` (gotcha 4). A hidden error
      column means a silently missing model.
- [ ] The explicit **Run** button is required before any fitting happens; nothing fits on
      tab load.
- [ ] The `include_lognormal` toggle is **off by default** and carries the warning that
      lognormal's heavy tail can change both the selected model and the RECeUS
      conclusion (gotcha 6). Verify the off state against the oracle; the on state is
      out of scope for Definition-of-Done item 3 unless Geethanjalee generates oracle
      rows for it.
- [ ] For `sim_B`, `sim_C` and `sim_D` the winner is a **non-cure** model and the app
      still lets the user continue to the diagnostics. A non-cure winner must not be a
      dead end.
- [ ] The A-06 overlay: selecting a model draws that model's fitted survival curve on the
      KM curve; selecting a different model redraws it; the overlaid curve for a cure
      model flattens above zero and for a non-cure model decays toward zero.

### 5.3 Diagnostics tab (A-07 five cards)

Check all five cards on all seven datasets. The cards are Maller–Zhou (1994), `qn`,
Shen (2000), Immune summary, and RECeUS.

- [ ] Maller–Zhou statistic matches `mz_statistic`; the stated threshold is
      `< 0.05 ⇒ follow-up looks sufficient`; the pass/fail chip agrees with that rule.
- [ ] `qn` statistic matches `qn_statistic`. **The direction is inverted relative to the
      other two: larger is better**, and it is compared against a sample-size-dependent
      threshold `1 - 0.05^(1/n)`, not against 0.05. A chip that treats `qn < 0.05` as
      "good" is a bug even when the number itself is right. Check the threshold the app
      prints against the threshold in the package's own `interpretation` string in
      `tests/reference/interpretation_<dataset>.txt`.
- [ ] Shen statistic matches `shen_statistic`; threshold `< 0.05 ⇒ sufficient`; chip
      agrees.
- [ ] Immune card shows `p_hat` matching `immune_p_hat` and `p_cens` matching
      `immune_p_cens`, and is **labelled as a descriptive summary, not a hypothesis
      test** (gotcha 7) — the function is called `immune.test()` but it is not a test.
      A p-value-style presentation of this card is a bug.
- [ ] RECeUS card shows π̂ matching `pi_hat` and r̂ matching `r_hat`, states both
      conditions (π̂ > 0.025 **and** r̂ < 0.05), and shows which of the two failed when
      the decision is negative.
- [ ] The RECeUS card names the distribution used, and it matches
      `receus_dist` in the interpretation file. The app must not display an internally
      mapped short code it computed itself (gotcha 1).
- [ ] Each card shows the package's own `interpretation` string, verbatim or in a
      paraphrase Geethanjalee has approved. Diff the on-screen text against
      `tests/reference/interpretation_<dataset>.txt`.
- [ ] **`sim_C`: MZ, `qn` and Shen all render the explanatory "cannot be computed"
      state** — "the longest observed time is an event, so there is no plateau to test" —
      and not a blank cell, not the literal `NA`, not a crash. Immune and RECeUS still
      compute and still show numbers. Same check on `sim_D`.
- [ ] On the same `NA` datasets the pass/fail chips show a neutral "not computed" state
      rather than defaulting to fail. An `NA` is not a failure; it is an absence.
- [ ] Every statistic has a tooltip or popover (A-10), and the tooltip text is
      Geethanjalee's copy from G-03 — two plain-language sentences each.

### 5.4 Verdict tab (A-08)

- [ ] The three-step status strip mirrors manuscript Figure 1 in this order:
      **① Expert judgment → ② Visual assessment → ③ Quantitative assessment**.
- [ ] Step ① is something the **user confirms**, not something the app decides. The app
      cannot know whether cure is biologically plausible. If the app asserts step ①, that
      is a correctness bug about the science, not a UI preference.
- [ ] The plain-language recommendation is consistent with `receus_decision` and
      `final_recommendation` in the oracle for all seven datasets. The app may expand the
      wording; it may not invert the conclusion.
- [ ] `run_tests` defaults to **`"yes"`, not `"auto"`**, and the screen explains why the
      diagnostics are shown even when a non-cure model won on AIC (gotcha 2). Confirm on
      `sim_B`, `sim_C` and `sim_D`, where `"auto"` would have skipped Stage 2 entirely.
- [ ] The "the diagnostics can disagree — here is what to do" panel is present and is
      reachable on `gbsg`, the dataset where they actually do disagree.
- [ ] When the verdict is "follow-up insufficient", G-04's guidance is shown: use a
      non-cure model; or the extreme-value estimators of Escobar-Bach & Van Keilegom; or
      Yuen & Musta's relaxed condition; or collect more follow-up.
- [ ] Verdict for `nwtco_high_risk` reads as **cure model appropriate**; for `gbsg` and
      `colon_lev5fu` as **follow-up insufficient**; for `sim_A` appropriate; for `sim_B`,
      `sim_C`, `sim_D` not supported. Seven datasets, seven verdicts, all against
      `oracle.csv`.
- [ ] Re-running the same dataset twice in one session gives the same verdict. Any
      run-to-run drift means a seed or a state bug.

### 5.5 Report download (B-07 the `.Rmd`, A-09 the `downloadHandler`)

- [ ] The download button produces an HTML file that opens in a browser with no missing
      images and no broken layout.
- [ ] The report contains every required element from Definition-of-Done item 4 plus
      B-07's list: dataset label, data summary, KM plot, AIC table, all five diagnostics,
      the verdict, session info, and citations.
- [ ] **Every number in the report matches the same number on screen, and both match
      `oracle.csv`.** The report is a second rendering path and is the most likely place
      for a stale or recomputed value to appear.
- [ ] The dataset label in the report is the dataset the user actually ran, including for
      an uploaded CSV.
- [ ] Session info in the report shows the versions actually in use, and they match
      `tests/reference/session-info.txt` on the demo machine — or the discrepancy is
      recorded.
- [ ] Citations include Maller & Zhou (1992, 1994), Shen (2000), Selukar & Othus (2023),
      and how to cite `cureAssess` (Definition-of-Done item 5, A-10's About tab).
- [ ] The report renders for a dataset whose diagnostics are `NA` (`sim_C`) without
      failing the render, and carries the same "cannot be computed" explanation as the
      Diagnostics tab.
- [ ] Downloading twice in a row works, and the second file is not the first file's
      contents.
- [ ] Filename is meaningful and includes the dataset label.

---

## 6. Edge cases that must not crash

Definition-of-Done item 7: `NA`, failed-fit and bad-upload states all render a helpful
message rather than an error. "Helpful" means it names the problem, names the column or
value at fault where possible, and says what the user should do next. A red Shiny error
banner, a greyed-out page, or a browser console stack trace is a failure of this item
regardless of how correct the underlying computation was.

Rachael produces each case; Rashid and Sharon own the handling (A-03 surfaces
`.check_surv_data()` failures as friendly messages; A-07 owns the `NA` states). These
belong in `docs/data-contract.md` (B-01) as well, which is the canonical list of every
error `.check_surv_data()` can raise.

1. **Status coded 1/2 instead of 0/1.**
   *Produce:* take `data/examples/gbsg.csv` and recode `status` with
   `status <- status + 1`, giving values 1 and 2. Save as
   `gbsg_status_1_2.csv`. (This coding is very common in real trial exports, which is
   why it is case 1.)
   *Expected:* the column mapper asks which level means "event", the user picks `2`, and
   the app remaps to 0/1 internally and then reproduces the `gbsg` oracle row exactly.
   If the user does not pick, the app must refuse to run and explain that
   `cureAssess` requires the event indicator to be exactly 0/1 — never pass 1/2 through
   to `prepare.surv.data()`, which raises `` `D` must be coded as 0/1. ``

2. **A non-numeric time column.**
   *Produce:* in `gbsg.csv`, replace one `rfstime` value with the text `unknown`, so the
   whole column reads in as character. Save as `gbsg_time_text.csv`.
   *Expected:* the app rejects the mapping before calling the package, names the column
   and says it must be numeric, and ideally names the offending row. The package's own
   error is `` `Y` must be numeric. `` — the app must catch that condition rather than
   let it surface as a Shiny crash. The mapper should also not offer an obviously
   non-numeric column as a time candidate in the first place.

3. **Time in days without setting `days_to_years`.**
   *Produce:* upload `gbsg.csv` and map `rfstime` / `status` correctly but leave
   `time_scale` at `none`.
   *Expected:* this is **not** an error — it is a legitimate run on a different time
   unit, and it must not be blocked. The app must (a) succeed, (b) show max follow-up in
   the thousands with the axis labelled in the user's own units, and (c) show a
   non-blocking hint that values this large often mean days and offer the
   `days_to_years` conversion. Pod B records the resulting numbers as a separate,
   non-oracle run; they will not match the `gbsg` oracle row, and that is correct, since
   the input genuinely differs. The failure mode to catch here is an app that silently
   converts anyway, or one that prints a year-scaled follow-up next to a day-scaled axis.

4. **A dataset whose longest observation is an event, so the follow-up diagnostics are
   `NA`.**
   *Produce:* simulated **scenario C** —
   `simulate_cure_data(n = 300, cure_fraction = 0.00, shape = 1.2, scale = 1, admin_followup = 10, dropout_rate = 0.03, seed = 11)`,
   run with `time_scale = "none"`. Only about 4 % of observations are censored, so the
   largest observed time is an event. `sim_D` is the second instance of the same
   condition.
   *Expected:* Maller–Zhou, `qn` and Shen all show the explicit **"cannot be computed —
   the longest observed time is an event, so there is no plateau to test"** state, with
   neutral chips. Immune and RECeUS still show their numbers. The Verdict tab still
   reaches a verdict (cure model not supported) and explains that it did so without the
   three follow-up statistics. The report renders. This is risk **R7**, rated **High**,
   and it is the single most likely way for the app to look broken while being right.

5. **A dataset so small or so heavily censored that a `flexsurvcure` fit fails.**
   *Produce:* two variants. (a) Small: `head(sim_A, 10)` — then walk n down until a fit
   first fails, and record the n at which it does; do not assume a threshold.
   **[to confirm]** what the smallest workable n is on the VM's package versions; that
   number belongs in `docs/data-contract.md` as the app's minimum n. (b) Heavily
   censored: `simulate_cure_data(n = 300, cure_fraction = 0.00, shape = 1.2, scale = 1, admin_followup = 10, dropout_rate = 3, seed = 11)`,
   which pushes nearly everything to a dropout time.
   *Expected:* `model.fitting()` does not throw — it records the message in the `error`
   column and sets that row's `AIC = NA` (gotcha 4). So the app must show the AIC table
   with the failed rows present, their errors readable, and the best model chosen from
   whatever did fit. If **every** model fails, the package reports that no candidate
   model could be fitted and cure appropriateness could not be assessed from AIC
   comparison; the app must display that rather than an empty table. Below the minimum n
   in the data contract, the app should refuse before calling the package at all and say
   why.

6. **Missing values in time or status.**
   *Produce:* blank out three `rfstime` cells and three `status` cells in `gbsg.csv`,
   in different rows. Save as `gbsg_missing.csv`.
   *Expected:* the app detects missingness **before** calling the package, reports how
   many rows are affected in each column, and applies the missing-value policy written
   in `docs/data-contract.md` (B-01) — with the rows-dropped count shown on the Data tab
   summary so the user knows n changed. This case is not optional politeness:
   `.check_surv_data()` tolerates `NA` in `D` (it checks `na.omit(D)`), so a missing
   value can get past validation, and the follow-up diagnostics take `max()` over `Y`,
   which returns `NA` when any `Y` is `NA` — the comparison that decides whether the
   statistic is computable then gets an `NA` and the call fails deep inside the package
   with an unhelpful message. Filter at the door.

7. **A CSV with the wrong delimiter.**
   *Produce:* `write.csv2()` on `gbsg` (semicolon-separated, comma decimal mark), saved
   as `gbsg_semicolon.csv`; and a tab-separated copy saved with a `.csv` extension.
   *Expected:* the app either detects the delimiter or tells the user the file parsed as
   a single column and names the delimiter it expected. It must not proceed to a column
   mapper listing one giant column, and it must not offer that single column as a time
   column. Show the first few parsed rows so the user can see what went wrong.

8. **An empty upload.**
   *Produce:* three variants — a zero-byte `.csv`; a file with a header row and no data
   rows; and cancelling the file dialog so nothing is selected.
   *Expected:* a plain message that the file contains no rows, with the upload control
   still usable and the previously loaded dataset either retained or explicitly cleared —
   not a half-cleared screen showing the old summary next to an empty plot. Cancelling
   must be a no-op.

9. **A single-row dataset.**
   *Produce:* `data.frame(Y = 1, D = 0)` written to CSV; and the same with `D = 1`.
   *Expected:* the app refuses before calling the package, citing the minimum n from the
   data contract. This guard has to live in the app: with a single censored row there are
   no events at all, and the diagnostics compute the largest event time as a maximum over
   an empty vector, which in R returns `-Inf` with a warning rather than an error — so
   the package will hand back a number rather than refusing. A number computed from no
   events is meaningless and must never reach the screen. The same reasoning applies to
   any dataset with zero events, single-row or not; add that to the data contract.

**For every case above, "done" means:** the case is committed as a fixture under
`data/examples/edge-cases/` (or as a one-line recipe in this file where committing the
file makes no sense, as in case 8's cancelled dialog), it has a row in the verification
log with the observed message, and the app's message has been read by Geethanjalee for
accuracy of wording. A friendly message that says the wrong thing about the statistics is
still a bug.

---

## 7. Verification log

Append one row per check. Keep it in this file so it is in the same PR as the plan it
implements. `Expected` cites the oracle; `Observed` is what the screen actually showed —
paste the value, not "fine". For a fail, the `Issue link` is the GitHub issue URL and is
mandatory; for a pass, use an em dash.

| Date | Block | Dataset | Tab | Expected | Observed | Pass/Fail | Issue link | Verified by |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |  |  |
|  |  |  |  |  |  |  |  |  |

Use the block names exactly as they appear in the schedule — `W1`, `W2`, `W3`, `T1`,
`T2`, `T3`, `T4`, `F1`, `F2`, `F3`, `F4` — so a row can be traced back to the task that
was being verified.

**B-08 sign-off (T4, Thu 3:20–5:00) requires:** a log row for every tab in §5 crossed
with every dataset in §3, every edge case in §6 exercised at least once, and Rachael's
and Geethanjalee's names against the final rows. This table, committed, *is* the B-08
sign-off table. Nothing about the Definition of Done can be declared met with blank rows
here.

---

## 8. The clean-clone test (B-09 and B-11)

**Owner: Geethanjalee. B-09 in T4 (Thu 3:20–5:00). B-11 in F2 (Fri 10:50–12:00), after
every Friday change has landed.**

This is the single best predictor of whether the Friday demo works. It is also the check
that most often gets skipped, because the app already runs on the machine that built it.
Definition-of-Done item 1 is specifically *from a clean clone*, and item 6 is
*clone to running app in under 10 minutes* — this procedure measures both.

**Rules before you start.** The clone goes into a **new directory outside any existing
copy of the repo** — never a subdirectory of the working copy. The machine must be one
that has **never run the app**, or as close as the event allows: if no such machine is
available, say so in the log and use a fresh R session started with `R --vanilla` in a
new directory, which at least removes `.Rprofile`, the dev session's loaded packages, and
any `renv` state. Do not reuse a shell that has `cd`-ed through the dev copy.
**[to confirm]** which physical machine is used for each run, and whether the
demo machine itself can be the B-11 target — ideally it is.

### Procedure

**Step 0 — start the clock.** Note the wall-clock time. Item 6 of the Definition of Done
is a ten-minute claim and this is the only measurement of it.

**Step 1 — fresh clone into a new directory.**

```sh
mkdir -p ~/cleanclone-$(date +%m%d-%H%M) && cd ~/cleanclone-$(date +%m%d-%H%M)
git clone https://github.com/stjude-biohackathon/KIDS26-Team9.git
cd KIDS26-Team9
git log -1 --oneline        # record this commit hash in the log
git status                  # must be clean; anything uncommitted is not being tested
```

Record the commit hash. A clean-clone pass is a pass **for that commit** and says nothing
about work that was still sitting unpushed on somebody's laptop. This is the practical
teeth behind the "push at the end of every block" rule.

**Step 2 — install dependencies, following `README.md` and nothing else.**

Follow the README literally, as a new user would. If you have to deviate — an extra
package, a system library, a flag the README does not mention — that deviation **is** the
finding: fix the README (D-01), do not just fix your machine.

```r
# in R, started in the clone's root
install.packages(c("shiny", "bslib", "DT", "rmarkdown",
                   "survival", "flexsurv", "flexsurvcure",
                   "survminer", "ggplot2", "dplyr"))

# cureAssess is vendored in this repo, not on CRAN
install.packages("cureAssess", repos = NULL, type = "source")   # from ./cureAssess
library(cureAssess)
packageVersion("cureAssess")    # expect 0.1.0
```

**Step 3 — smoke test (the same `scripts/smoke_test.R` used in T-03).**

```sh
Rscript scripts/smoke_test.R
```

Expected: it completes and reports every dependency present. This is the two-minute
go/no-go from risk **R1**. If it fails here, stop and fix the install path before
touching the app.

**Step 4 — regenerate the oracle on this machine and diff it.**

```sh
R --vanilla -f tests/reference/make_oracle.R
git diff --stat tests/reference/
```

Expected: **no diff**, or only `session-info.txt`. A diff in `oracle.csv` on a clean
clone means the numbers depend on the machine, which is a finding in its own right —
record the versions from both `session-info.txt` files in `decisions.md` before anything
else, because the deck and the user guide quote these numbers.

**Step 5 — launch the app.**

```r
shiny::runApp("app")
```

Expected: the app opens, all five tabs (**Data**, **Models**, **Diagnostics**,
**Verdict**, **About**) navigate, and the R console shows **zero errors** — the A-01
acceptance criterion. Warnings get noted, not ignored.

**Step 6 — walk one dataset end to end, reading the browser console as well as the R
console.**

Use **`gbsg`** for this walk. It is the teaching example in the user guide (D-02) and the
one whose diagnostics disagree, so it exercises the most interesting paths.

1. Data tab: pick `gbsg`; confirm **n = 686**, events, censored proportion and max
   follow-up against `oracle.csv`; confirm the KM plot and risk table render.
2. Models tab: press **Run**; confirm the winner is **`loglogistic_cure`** with
   **AIC 1719.70**; confirm the cure badge; confirm the `error` column is visible;
   overlay the fitted curve.
3. Diagnostics tab: confirm **MZ 0.0495**, **`qn` 0.0044**, **Shen 0.3676**, the immune
   summary, and **π̂ 0.3238 / r̂ 0.3080** with the verdict **follow-up insufficient for
   cure modeling**; confirm the disagreement between MZ and the other three is explained
   and not hidden.
4. Verdict tab: confirm the three-step strip, the user-confirmed expert-judgment step,
   the plain-language recommendation, and the "diagnostics can disagree" panel.
5. **Then repeat steps 1–4 with `sim_C`**, because a clean clone that only ever sees a
   well-behaved dataset has not tested the `NA` path that risk **R7** is about. This
   second walk can be fast; it is the `NA` rendering you are looking at.

**Step 7 — download the report.**

Press the download button; open the HTML in a browser on that machine; confirm the KM
plot, AIC table, all five diagnostics, the verdict, session info and citations are all
present; confirm **every number in it matches what step 6 showed on screen**.

**Step 8 — stop the clock and log it.**

Record in the verification log (§7), as a row with `Tab` = `clean-clone`:

- commit hash tested;
- machine and OS, and whether it had genuinely never run the app;
- elapsed clone-to-running-app time, against the ten-minute claim;
- every README deviation, each as its own issue against D-01;
- whether step 4 produced a diff;
- pass/fail, and your name.

### Pass criteria

A clean-clone run is a **pass** only when all of these hold:

- [ ] `git status` clean at the tested commit.
- [ ] Install completed by following `README.md` alone, with no undocumented steps.
- [ ] `scripts/smoke_test.R` reports all dependencies present.
- [ ] `tests/reference/` regenerates with no diff outside `session-info.txt`.
- [ ] `shiny::runApp("app")` launches with zero console errors.
- [ ] All five tabs navigate.
- [ ] `gbsg` walks end to end and every displayed number matches `oracle.csv`.
- [ ] `sim_C` renders the "cannot be computed" state on MZ, `qn` and Shen.
- [ ] The HTML report downloads, opens, and agrees with the screen.
- [ ] Clone to running app took under ten minutes.

Anything short of that is a fail and gets an issue before the block ends.

### Why B-11 exists as well as B-09

B-09 proves the clone works at the Thursday 5:00 pm feature freeze. B-11 proves the same
thing after Friday's bug bash (F1) and docs pass (F2) have edited the code and the README.
Friday's changes are exactly the ones nobody has time to test, and a README edited for
clarity at 11:30 am on Friday is a README nobody has followed literally. Run the whole
procedure again — not a subset — and finish it inside F2, before F3's dry runs
(D-07) start, so that the two timed rehearsals happen on a configuration that has been
verified from scratch.
