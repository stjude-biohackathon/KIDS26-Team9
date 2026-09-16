# Task backlog - KIDS26 Team 9 / cureAssessApp

St. Jude BioHackathon 2026, Wed 16 - Fri 18 September 2026.
Repo: `stjude-biohackathon/KIDS26-Team9` (branch `main`).

**The Shiny app does not exist yet. Everything below is a plan, not a status report.**
Target for the Definition of Done is **Thursday 5:00 pm**; the hard deadline is **Friday 2:45 pm**.

## How to read this file

Task IDs are canonical. Use them in branch names, commit messages, PR titles and issue titles.

| Prefix | Meaning |
| --- | --- |
| `T-` | Onboarding and process checkpoints (whole team) |
| `A-` | Pod A, the app |
| `B-` | Pod B, data and QA |
| `G-` | Science, owned by Geethanjalee |
| `D-` | Demo and documentation |
| `S-` | Stretch, out of scope until the Definition of Done is signed off |

Each task has a checkbox, an owner, a backup, and three lines: **What** (enough to start without
reading the cure-model literature), **Done when** (the testable criterion), and **Notes** (the
gotchas that will bite you).

### Rules that apply to every task

1. **A task is not done until it is pushed.** Unpushed work does not exist. Push at the end of every
   block, without exception. This is what makes the absence tolerance real: any teammate must be able
   to pick up any task from `origin/main` at any block boundary.
2. Branch per task: `<initials>/<task-id>-<short-slug>`, e.g. `sf/A-01-app-skeleton`.
3. One PR per task. The PR title starts with the task ID. A teammate skims it before merge.
   **Sharon merges to `main`.**
4. One owner per Shiny module file (`app/R/mod_*.R`). This is the merge-conflict mitigation; do not
   edit someone else's module file, open an issue instead.
5. Blockers go in a GitHub issue immediately and get said out loud at the next standup
   (Wed 4:45 pm, Thu 9:30 am, Thu 4:45 pm, Fri 9:30 am).
6. Decisions that change the approach go in `project-management/decisions.md` with date, decision, why.
7. A number in the app that differs from Geethanjalee's reference oracle is a **blocking** bug, not a
   cosmetic one.
8. Never commit data that is not public, credentials, or anything identifiable.
9. **Geethanjalee is the first point of contact for both pods.** Ask her before guessing at anything
   statistical. Durbadal is the overflow.
10. Where the backlog below does not name a task-level backup, the roster backup applies:
    Sharon <-> Rashid, Rachael -> Geethanjalee, Geethanjalee -> Durbadal. Backups shown in
    parentheses come from the roster rather than from the task list.

### Block index

| Block | Time | Focus | Tasks |
| --- | --- | --- | --- |
| **W1** | Wed 10:30-12:00 (1.5 h) | Onboarding only, no feature work | T-01 .. T-06 |
| **W2** | Wed 1:00-3:00 (2 h) | App skeleton + data foundations | A-01, A-02, B-01, B-02, G-01 |
| **W3** | Wed 3:20-5:00 (1 h 40) | Wire Stage 1 end to end | A-03, A-04, B-03, B-04, T-07 |
| **T1** | Thu 9:30-10:30 (1 h) | Models / AIC tab | A-05, A-06, B-05, G-02 |
| **T2** | Thu 10:50-12:00 (1 h 10) | Diagnostics tab | A-07, B-06, G-03 |
| **T3** | Thu 1:00-3:00 (up to 2 h) | Verdict tab + report engine | A-08, B-07, G-04 |
| **T4** | Thu 3:20-5:00 (1 h 40) | Integration, report download, regression | A-09, A-10, B-08, B-09, T-08 |
| **F1** | Fri 9:30-10:30 (1 h) | Bug bash only | A-11 / B-10 |
| **F2** | Fri 10:50-12:00 (1 h 10) | Docs, help polish, clean clone, screenshots | D-01 .. D-04, B-11 |
| **F3** | Fri 1:00-2:00 (1 h) | Demo build + two timed dry runs | D-05, D-06, D-07 |
| **F4** | Fri 2:00-2:45 (45 min) | Tag, handoff, final commit | D-08, T-09 |

Breaks are hard stops: Wed 3:00-3:20, Thu 10:30-10:50, Thu 3:00-3:20, Fri 10:30-10:50.

---

## W1 - Wed 10:30-12:00 - onboarding only

**No feature work in this block.** The point of W1 is that nobody discovers a broken environment at
2:00 pm on Wednesday. If the VM is not working by **11:15 am Wed**, Durbadal escalates to the
organisers and the team falls back to local-laptop RStudio.

- [ ] **T-01** Confirm VM access and that RStudio opens - *Owner: all · Backup: Durbadal escalates to organisers*
  - **What:** Log into the hackathon VM with your own credentials and open RStudio. Confirm you can
    create a file, run `sessionInfo()`, and see R 4.6.1 (the package needs R >= 4.1). Say out loud in
    the team channel that you are in, or that you are not.
  - **Done when:** Every one of the five team members has posted "VM + RStudio OK" (or a specific
    failure) in the team channel, and `sessionInfo()` output shows R 4.6.1.
  - **Notes:** This is risk R1 and it is the single most likely way to lose Day 1. Do not debug
    quietly for an hour; a failure at 11:15 goes to the organisers immediately. Local-laptop RStudio
    is an accepted fallback, not a defeat.

- [ ] **T-02** Confirm GitHub write access by pushing one trivial commit each - *Owner: all · Backup: not applicable, each person proves their own access*
  - **What:** Clone `stjude-biohackathon/KIDS26-Team9`, add your own name to
    `project-management/team.md`, commit and push. Pushing is the test; reading the repo proves
    nothing about write access.
  - **Done when:** `git log --oneline` on `main` shows one commit from each of the five people, and
    `team.md` lists all five.
  - **Notes:** Rashid's GitHub handle is not yet recorded (collected in T-06), so check his push
    landed under the handle he expects. If anyone's push is rejected, that is a GitHub org permission
    problem for Durbadal to escalate, not something to work around with a shared account.

- [ ] **T-03** Install dependencies and run the environment smoke test - *Owner: all · Backup: Sharon*
  - **What:** Install `shiny`, `bslib`, `DT`, `rmarkdown` plus the package dependencies `survival`,
    `flexsurv`, `flexsurvcure`, `survminer`, `ggplot2`, `dplyr`, then install the vendored
    `cureAssess` from `cureAssess/`. Run `scripts/smoke_test.R`, then `shiny::runApp("app-scaffold")`.
  - **Done when:** `scripts/smoke_test.R` exits clean on every machine and the scaffold app opens in a
    browser with no console errors. Anyone whose install fails has an issue open with the exact error.
  - **Notes:** `flexsurvcure` and `survminer` are the two most likely to need a compiler or a system
    library, so start with those. The smoke test plus the scaffold app are designed to give a go/no-go
    in about two minutes; if it takes longer than that, something is wrong and it is worth saying so.

- [ ] **T-04** Confirm access to the AI coding agents available at the event - *Owner: all · Backup: not applicable, each person proves their own access*
  - **What:** Sign in to whichever coding assistants the event provides (for example Copilot) and confirm
    they work inside your editor on this repo.
  - **Done when:** Each person has confirmed access or reported that they do not have it.
  - **Notes:** Nobody's task is blocked on this. Anything these tools produce still goes through the
    normal PR review, and any number they print is worthless until it matches the oracle (rule 7).

- [ ] **T-05** 20-minute walkthrough: cure models, `cureAssess`, and what the app must reproduce - *Owner: Geethanjalee · Backup: (Durbadal)*
  - **What:** Using the onboarding deck, cover: why ordinary survival analysis assumes everyone
    eventually has the event and why modern therapy broke that; what a mixture cure model is
    (`S(t) = (1 - p) + p * Su(t)`, the cure fraction is `1 - p`, and on a KM curve it looks like a
    plateau above zero); the two extra assumptions (a genuinely non-zero cured fraction, and follow-up
    long enough to identify it); and the three-step check from manuscript Figure 1 that the app has to
    put on screen: expert judgment, then visual assessment, then quantitative assessment.
  - **Done when:** Sharon, Rashid and Rachael can each state, unprompted, what a plateau above zero
    means, why a plateau is not proof of cure, and which of the three steps the software cannot decide.
  - **Notes:** The audience has no cure-model background, and that is by design. Twenty minutes is the
    budget; deeper questions go to the channel during W2, not into this block. The one idea that has to
    land is the last one: heavy censoring alone manufactures a plateau, which is exactly why the
    diagnostics exist.

- [ ] **T-06** Confirm pods, roles, conventions, Definition of Done; collect Rashid's GitHub handle - *Owner: Durbadal · Backup: [to confirm]*
  - **What:** Confirm Pod A (Sharon, Rashid) and Pod B (Rachael, Geethanjalee floating), the comms
    channel, the branch and PR convention, the block-end push rule, and read the Definition of Done out
    loud so all eight items are shared. Record Rashid's GitHub handle in `team.md`.
  - **Done when:** `project-management/team.md` lists all five people with GitHub handles and pods,
    `decisions.md` has a dated entry for the pod split, and Rashid's handle is no longer "TBD".
  - **Notes:** The Pod A / Pod B placement for Sharon, Rashid and Rachael is a starting guess made
    without knowledge of their individual skills. **Swap freely here.** Also re-balance if Pod A looks
    starved: Geethanjalee is counted in Pod B but roughly half her time is reserved for answering
    Pod A, and that split is an honest compromise, not a rule.

---

## W2 - Wed 1:00-3:00 - app skeleton and data foundations

- [ ] **A-01** App skeleton: `app/` with a `bslib` navbar and five tabs - *Owner: Sharon · Backup: Rashid*
  - **What:** Create `app/` containing an app entry point and a `bslib::page_navbar()` with five
    `nav_panel()`s in this order: **Data**, **Models**, **Diagnostics**, **Verdict**, **About**. Create
    one empty module file per tab under `app/R/` (`mod_data.R`, `mod_models.R`, `mod_diagnostics.R`,
    `mod_verdict.R`, `mod_about.R`) with the standard UI/server function pair wired up, so each later
    task has a file of its own to work in.
  - **Done when:** `shiny::runApp("app")` opens, all five tabs navigate, and the R console shows zero
    errors and zero warnings.
  - **Notes:** This is the mitigation for risk R4 (merge conflicts from everyone editing one `app.R`).
    Get the module files created and pushed early in the block even if they are empty stubs, because
    A-02, A-03 and A-04 all land in different files during W2/W3 and the conflict cost is paid only
    once. Write down in the PR which module file belongs to whom.

- [ ] **A-02** Data tab v1: built-in dataset picker, summary card, `head()` table - *Owner: Rashid · Backup: Sharon*
  - **What:** In `mod_data.R`, add a `selectInput` listing the three built-in examples from B-02. On
    selection, call `prepare.surv.data(data, time = <time col>, status = <status col>, time_scale =
    "days_to_years")` and render a summary card showing n, number of events, censored percentage,
    median follow-up and maximum follow-up, plus a `head()` table of the prepared data.
  - **Done when:** Selecting "nwtco - High risk" shows **n = 1404**. The other two examples render
    without error, and the card states in words how median follow-up is defined so Pod B can verify it.
  - **Notes:** `prepare.surv.data()` returns your original data frame with `Y` (time) and `D`
    (event 1/0) added by `dplyr::mutate()`, so if the incoming data already has a column called `Y` or
    `D` it gets overwritten silently. It also divides by 365.25 when `time_scale = "days_to_years"`, so
    the summary card's follow-up numbers are in years, and the card must say so. This task depends on
    B-02 landing; until it does, work against the raw `survival` datasets and swap the source to the
    curated CSVs when they appear.

- [ ] **B-01** Write the data contract, `docs/data-contract.md` - *Owner: Rachael · Backup: Geethanjalee*
  - **What:** Document exactly what a dataset must look like to get through the package: the required
    columns, the event coding, the time units, the missing-value policy, the minimum n, and every error
    `.check_surv_data()` can raise. The four errors, verbatim from the source, are: "`data` must be a
    data.frame."; "`data` must contain columns: Y, D. Missing: ..."; "`Y` must be numeric."; and
    "`D` must be coded as 0/1." Give each one a plain-language translation that a clinician would
    understand, because A-03 will display those translations.
  - **Done when:** `docs/data-contract.md` is committed, lists all four errors with their friendly
    translations, states the event coding rule and the remapping requirement, and Sharon can implement
    A-03's error handling from the document alone without asking a question.
  - **Notes:** Two things the source shows that are easy to miss. First, the 0/1 check runs on
    `na.omit(D)`, so **`NA` values in the status column pass the check** and fail later inside the model
    fitting instead; the missing-value policy has to say what the app does about that. Second,
    `time_scale` accepts only `"none"` or `"days_to_years"`, nothing else. Minimum n is a judgement
    call: agree it with Geethanjalee rather than inventing a number.

- [ ] **B-02** Curate the three built-in examples to `data/examples/` - *Owner: Rachael · Backup: Geethanjalee*
  - **What:** Write three CSVs plus a `README.md`: (1) `nwtco_high_risk`, the stage 3-4 subset;
    (2) `gbsg`; (3) `colon_lev5fu`, recurrence as the endpoint, filtered to `etype == 1` and
    `rx == "Lev+5FU"`. The README records provenance (which R package each comes from) and licence for
    each one.
  - **Done when:** The three CSVs exist with row counts **1404**, **686** and **304** respectively,
    matching the reference table; the README names the source and licence for each; and `A-02` can read
    them.
  - **Notes:** Public data only. Nothing restricted, nothing identifiable, and nothing from St. Jude
    clinical datasets enters this repo or appears on screen. Record which column is the time and which
    is the status for each dataset in the README, because A-02, A-03 and G-01 all need to agree on that
    choice: `edrel`/`rel` for nwtco, `rfstime`/`status` for gbsg, and the recurrence time/status pair
    for colon.

- [ ] **G-01** Build the reference oracle in plain R and commit `tests/reference/` - *Owner: Geethanjalee · Backup: (Durbadal)*
  - **What:** In a plain R script with no Shiny involved, run
    `cure.appropriateness(data, time, status, time_scale = "days_to_years", run_tests = "yes")` on each
    of the three curated examples and commit the AIC table, all five diagnostics and the verdict to
    `tests/reference/`, one file per dataset. Commit the script too, so anyone can re-run it.
  - **Done when:** `tests/reference/` holds the three result sets and every value matches the verified
    table below. These are the numbers the app must reproduce exactly.

    | Dataset | n | AIC best model | pi-hat | r-hat | MZ (1994) | qn | Shen (2000) | RECeUS verdict |
    | --- | --- | --- | --- | --- | --- | --- | --- | --- |
    | `nwtco` High risk (stage 3-4), `edrel`/`rel` | 1404 | `loglogistic_cure` (AIC 1928.38) | 0.7823 | 0.0041 | 1.04e-140 | 0.2051 | 0.0496 | Cure model appropriate |
    | `gbsg`, `rfstime`/`status` | 686 | `loglogistic_cure` (AIC 1719.70) | 0.3238 | 0.3080 | 0.0495 | 0.0044 | 0.3676 | Follow-up insufficient for cure modeling |
    | `colon` recurrence, `Lev+5FU` arm | 304 | `loglogistic_cure` (AIC 741.52) | 0.5736 | 0.0640 | 5.25e-13 | 0.0888 | 0.0065 | Follow-up insufficient |

  - **Notes:** These were produced on 2026-09-15 with R 4.6.1, `cureAssess` 0.1.0, `flexsurv` 2.3.2 and
    `flexsurvcure` 1.3.3. Record the same version block in `tests/reference/` so a future mismatch can
    be diagnosed as a version drift rather than an app bug. A full `cure.appropriateness()` run takes
    0.1-0.2 s, so the whole oracle is a few seconds of compute; the work here is care, not runtime.
    Use `run_tests = "yes"`, never `"auto"`. Let `cure.appropriateness()` choose and map the RECeUS
    distribution itself, and record its `selected_receus_dist` in the output; **do not call the internal
    `.map_model_to_receus_dist()`** and do not hand-translate model names, because the package uses two
    different naming schemes (`model.fitting()` returns names like `weibull_cure`, while
    `receus.method()` wants short codes such as `"exp"`, `"wei"`, `"gam"`, `"llogis"`, `"lnorm"` and
    their `...Unc` non-cure variants).

---

## W3 - Wed 3:20-5:00 - wire Stage 1 end to end

- [ ] **A-03** CSV upload plus column mapper with friendly validation - *Owner: Sharon · Backup: Rashid*
  - **What:** Add a `fileInput` for a user CSV, then four controls: time column (numeric columns only),
    status column, **which level of the status column means "event"**, and time scale (`none` /
    `days_to_years`). Build a 0/1 event indicator from the chosen level before calling
    `prepare.surv.data()`. Wrap that call in `tryCatch()` and surface any failure as the plain-language
    message from B-01's data contract.
  - **Done when:** Uploading `gbsg.csv` from `data/examples/` and mapping its columns reproduces the
    built-in gbsg path **exactly**: same n = 686, same summary card, same KM plot. Separately, uploading
    a file with a status column coded 1/2 and mapping "2" as the event succeeds, and uploading a file
    with a text time column shows a readable message.
  - **Notes:** **`.check_surv_data()` requires `D` to be exactly 0/1 and `Y` to be numeric.** A dataset
    coded 1/2 is very common and will error outright, which is the entire reason the mapper has to ask
    which level means "event"; handle 1/2, `TRUE`/`FALSE`, and character levels such as
    "Dead"/"Alive". **Never let a red Shiny crash reach the screen** (Definition of Done item 7): every
    validation failure renders a helpful message that says which column is wrong and what is expected.
    Note also that `NA` in the status column slips past the 0/1 check, so decide explicitly what the app
    does with those rows and tell the user. And remember `prepare.surv.data()` overwrites any existing
    `Y` or `D` column in the upload.

- [ ] **A-04** KM plot with risk table on the Data tab - *Owner: Rashid · Backup: (Sharon)*
  - **What:** On the Data tab, fit `survival::survfit(survival::Surv(Y, D) ~ 1, data = dat)` on the
    prepared data and render it with `survminer::ggsurvplot(..., conf.int = TRUE, risk.table = TRUE)`.
    Label the x axis in the units the prepared data is actually in (years when
    `time_scale = "days_to_years"`).
  - **Done when:** All three built-in examples and an uploaded CSV each draw a KM curve with a risk
    table underneath, no console warnings, and the gbsg curve visibly flattens toward the right-hand end
    of follow-up.
  - **Notes:** `ggsurvplot()` returns a composite object, not a plain ggplot, so the risk table only
    appears if you `print()` it inside `renderPlot()`. Do **not** call `model.fitting()` just to get its
    KM plot on this tab: it fits eight models (ten with lognormal on) as a side effect, and the Data tab
    should not pay for that. `model.fitting(plot_km = TRUE)` is the right source for the Models tab
    only, and it builds the same `ggsurvplot` with confidence interval and risk table.

- [ ] **B-03** Implement `simulate_cure_data()` and the four-scenario matrix - *Owner: Rachael · Backup: Geethanjalee*
  - **What:** Commit the reference implementation below as-is, then drive it with the four parameter
    sets in B-05. Each call returns a data frame with `Y` (observed time), `D` (event 0/1) and `.cured`
    (the unobservable truth).

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

  - **Done when:** Sourcing the file and running the four scenarios with `n = 300`, `shape = 1.2`,
    `scale = 1`, `seed = 11` and `time_scale = "none"` reproduces the pi-hat and r-hat values in B-05 to
    the digits shown there.
  - **Notes:** The function's own defaults (`shape = 1.0`, `admin_followup = 5`,
    `dropout_rate = 0.05`) are **not** the verified scenario settings. The verified numbers come from
    `shape = 1.2`, `scale = 1`, `seed = 11`, so pass those explicitly every time and never rely on the
    defaults. `.cured` is ground truth that is not observable in real data: keep it for teaching and
    verification, but it must never be offered to the app as the status column.

- [ ] **B-04** Verification pass #1: Stage-1 numbers, app versus oracle, three datasets - *Owner: Rachael · Backup: (Geethanjalee)*
  - **What:** With the app running, compare what the Data tab prints against `tests/reference/` for all
    three curated examples: n, event count, censored percentage, median and maximum follow-up, and the
    shape of the KM curve. File one GitHub issue per mismatch, with the app value, the oracle value and
    the dataset named in the title.
  - **Done when:** A short table is committed with one row per dataset and a tick or an issue link for
    each checked quantity. n = 1404 / 686 / 304 must match.
  - **Notes:** This is risk R5. A mismatch is a **blocking** bug: say it at the 4:45 standup, do not
    leave it in the issue tracker to be noticed. The most likely cause of an off-by-a-factor follow-up
    number is `time_scale`: days versus years is a 365.25x difference and it is silent.

- [ ] **T-07** 4:45-5:00 standup, everyone pushes, decisions recorded - *Owner: whole team · Backup: Durbadal records `decisions.md`*
  - **What:** Ten minutes, standing up. Each person says what landed, what is pushed, and what is
    blocking. Then everyone pushes their branch, open or not.
  - **Done when:** `git log origin/main` and the open branch list together account for every person's
    Wednesday work, and `decisions.md` has a dated entry for any decision taken today.
  - **Notes:** Push even half-finished work, to a branch, with a WIP commit message. This is the R2
    mitigation: a teammate who is absent on Thursday morning must not take their work with them.

---

## T1 - Thu 9:30-10:30 - Models / AIC tab

- [ ] **A-05** Models tab: AIC table, cure badge, best-model callout, lognormal toggle, error column - *Owner: Sharon · Backup: Rashid*
  - **What:** Add an explicit **Run** `actionButton` that calls
    `model.fitting(dat, plot_km = FALSE, include_lognormal = input$lognormal)` and renders
    `fit$aic_table` as a sortable `DT` table with its five columns: `model`, `model_type`, `AIC`,
    `parameter_estimates` and `error`. Add a cure / non-cure badge driven by `model_type`, a callout
    naming `fit$best_model` and `fit$best_model_type`, and an `include_lognormal` toggle that defaults
    to off.
  - **Done when:** With gbsg selected and lognormal off, the top row is `loglogistic_cure` with
    **AIC 1719.70** and the callout says a cure model has the smallest AIC. The `error` column is
    visible in the default view. Deliberately feeding a fit that fails shows its message in the `error`
    column with a blank AIC, and the app does not crash.
  - **Notes:** Two package behaviours drive this task. (1) **`model.fitting()` never throws on a failed
    fit.** It catches the error, records the message in the `error` column and sets `AIC = NA`. The app
    must **display that column, not hide it**, and must not silently drop `AIC = NA` rows, because a
    user whose model failed needs to see why. The package already sorts the table by AIC ascending with
    `NA` rows at the bottom and picks the best model from the first non-`NA` row, so do not re-sort in a
    way that breaks that. (2) **`include_lognormal` defaults to `FALSE` deliberately:** lognormal's
    heavy tail can change both the selected model and the RECeUS conclusion. Expose it as an opt-in
    toggle and put that warning next to the toggle in words, not just in the docs. Pass
    `plot_km = FALSE` here so the Models tab does not re-render the KM plot A-04 already draws. The Run
    button exists for explicitness, not speed: a full assessment takes 0.1-0.2 s.

- [ ] **A-06** Overlay the fitted survival curve for the selected model on the KM curve - *Owner: Rashid · Backup: (Sharon)*
  - **What:** Let the user select one model (single-row selection on the `DT`, or a dropdown of the
    models that fitted successfully). Pull the fit object from `fit$fits[[model]]$fit`, get predicted
    survival on a time grid spanning the observed follow-up, and draw it as a line over the KM curve.
  - **Done when:** Selecting `loglogistic_cure` on gbsg draws a smooth curve that tracks the KM step
    function and flattens at the right-hand end. Selecting a model whose `error` column is non-empty
    shows "this model did not fit" rather than an empty or broken plot.
  - **Notes:** For any row where `AIC` is `NA`, `fit$fits[[model]]$fit` is `NULL`; guard for that before
    predicting. The model names you get here (`weibull_cure`, `loglogistic`, and so on) belong to
    `model.fitting()`'s naming scheme and are **not** the short codes the RECeUS function wants; keep
    the two apart and do not translate between them by hand.

- [ ] **B-05** Commit the four simulated scenario datasets and their expected verdicts - *Owner: Rachael · Backup: (Geethanjalee)*
  - **What:** Using B-03 with `n = 300`, `shape = 1.2`, `scale = 1`, `seed = 11` and
    `time_scale = "none"`, write the four scenario datasets to the repo along with a machine-readable
    file of their expected results, reproducing this verified matrix exactly.

    | Scenario | True cure fraction | Admin follow-up | Dropout rate | AIC best | pi-hat | r-hat | Verdict | What it teaches |
    | --- | --- | --- | --- | --- | --- | --- | --- | --- |
    | **A** | 0.40 | 10 | 0.03 | `weibull_cure` (cure) | 0.358 | 0.0000 | Cure model appropriate | The happy path: real cure fraction plus mature follow-up. |
    | **B** | 0.40 | 1.5 | 0.03 | `loglogistic` (non-cure) | 0.020 | 0.9786 | Cure model not supported | A real cure fraction is invisible when follow-up is short. |
    | **C** | 0.00 | 10 | 0.03 | `weibull` (non-cure) | 0.000 | 0.9992 | Cure model not supported | True negative, and MZ / `qn` / Shen are all `NA` here. |
    | **D** | 0.00 | 10 | 0.45 | `weibull` (non-cure) | 0.000 | 0.9973 | Cure model not supported | Heavy dropout makes a plateau that is a censoring artifact. |

  - **Done when:** Four datasets plus the expected-verdict file are committed, the values match the
    table above, and the file records explicitly that **Maller-Zhou, `qn` and Shen are `NA` in scenarios
    C and D** so A-07's `NA` handling has a concrete test case.
  - **Notes:** Scenario C has only about 4 % censoring, which is why its largest observed time is an
    event and the follow-up tests are undefined rather than merely uninteresting. Scenario D is the
    teaching case that matters most for the science: heavy dropout manufactures a KM plateau that looks
    exactly like cure, and the diagnostics correctly refuse it. Together with B-02's three real
    datasets these four make the seven-dataset regression set required by the Definition of Done.

- [ ] **G-02** Help copy for Stage 1: what AIC is and what "a cure model won" does not prove - *Owner: Geethanjalee · Backup: (Durbadal)*
  - **What:** Write the user-facing copy for the Models tab: what AIC measures, that lower is better,
    that the values are only comparable within one dataset, and that a cure model having the smallest
    AIC is **initial support only, not proof**. Write it as short strings that Sharon can paste without
    editing.
  - **Done when:** Copy exists for the AIC table, the cure / non-cure badge, the best-model callout and
    the `include_lognormal` toggle, all committed in one place, and one of the non-experts can read each
    string and restate it correctly.
  - **Notes:** gbsg is the example that makes this copy necessary: AIC picks a cure model there, so a
    naive analyst would stop and fit one, yet r-hat = 0.3080 means about 31 % of uncured patients are
    still censored at the end of follow-up and the cure fraction cannot be estimated reliably. **A
    better AIC fit is not evidence that a cure model is identifiable.** The package's own
    `initial_decision` string already says "This provides initial support for cure model
    appropriateness"; keep the app's wording consistent with it rather than inventing a second voice.

---

## T2 - Thu 10:50-12:00 - Diagnostics tab

- [ ] **A-07** Diagnostics tab: five cards with statistic, threshold, chip and interpretation - *Owner: Rashid · Backup: Sharon*
  - **What:** Call `run.cure.tests(dat, dist = <short code>)` once and render five cards from
    `res$mz`, `res$qn`, `res$shen`, `res$immune` and `res$receus`. Each card shows the statistic, the
    threshold it is compared against, a pass/fail chip, and **the package's own `interpretation` string
    verbatim**. The thresholds are: Maller-Zhou statistic `< 0.05` means follow-up looks sufficient;
    `qn` is better when **larger** and is compared against the sample-size-dependent threshold
    `1 - 0.05^(1/n)`; Shen `< 0.05` means sufficient; RECeUS needs **pi-hat > 0.025 AND r-hat < 0.05**.
    The Immune card shows the event probability at the end of follow-up, the censoring proportion and
    whether the last observation was censored.
  - **Done when:** On gbsg the cards show MZ **0.0495**, `qn` **0.0044**, Shen **0.3676**, and RECeUS
    pi-hat **0.3238** / r-hat **0.3080** with the verdict "Follow-up insufficient for cure modeling".
    On simulated scenarios **C and D** the MZ, `qn` and Shen cards each render an explanatory
    **"cannot be computed"** state with the reason, not a blank cell, not the text `NA`, and not a crash.
  - **Notes:** **The `NA` case is not hypothetical.** The diagnostics return `NA` whenever the largest
    observed time is an event rather than a censored observation, because there is no plateau to test,
    and this happens on **simulated scenarios C and D** (scenario C has only about 4 % censoring). This
    is risk R7 and it is rated high likelihood. The package hands you the explanation already: each test
    returns an `interpretation` string saying the statistic "cannot be computed because the largest
    observed time corresponds to an event rather than a censored observation" even when `statistic` is
    `NA`, so render the string and suppress the chip rather than writing your own message. Three more
    things. **`immune.test()` is a descriptive KM-tail summary, not a hypothesis test**, despite the
    name: label it as a summary, give it no pass/fail chip, and do not print a p-value-shaped number for
    it. **`receus.method()` defaults `whichTau` to the maximum observed time**, so state the tau used on
    the RECeUS card. And on naming: `run.cure.tests()` and `receus.method()` want **short distribution
    codes** (`"exp"`, `"wei"`, `"gam"`, `"llogis"`, `"lnorm"`, plus the `...Unc` non-cure variants),
    while `model.fitting()` returns names like `weibull_cure`. These are two different schemes. **Do not
    call the internal `.map_model_to_receus_dist()`** to bridge them; either call
    `cure.appropriateness()` and read the `selected_receus_dist` it chose, or give the user a dropdown of
    the short codes. Also note `run.cure.tests()` errors outright if `dist` is `NULL`, so always pass one.

- [ ] **B-06** Verification pass #2: AIC tables, app versus oracle, seven datasets - *Owner: Rachael · Backup: (Geethanjalee)*
  - **What:** Compare the app's AIC table against the oracle for the three real datasets and the four
    simulated scenarios: best model name, best model type, and the AIC value of the winning row.
  - **Done when:** A committed sign-off table has one row per dataset showing the app's best model and
    AIC against the expected value, with every mismatch linked to an issue. The three real targets are
    `loglogistic_cure` at 1928.38 (nwtco), 1719.70 (gbsg) and 741.52 (colon), and the simulated ones are
    `weibull_cure` (A), `loglogistic` (B), `weibull` (C) and `weibull` (D).
  - **Notes:** Check the lognormal toggle is **off** before comparing, because turning it on can change
    which model wins. Check `time_scale` too: the three real datasets were run with
    `"days_to_years"`, the four simulated ones with `"none"`.

- [ ] **G-03** Help copy for all five diagnostics, two plain-language sentences each - *Owner: Geethanjalee · Backup: (Durbadal)*
  - **What:** Write two sentences for each of Maller-Zhou (1994), `qn`, Shen (2000), the Immune summary
    and RECeUS: what it looks at, and which direction of the number supports a cure model. State the
    threshold and its direction in words, since two of the five point the opposite way from the others.
  - **Done when:** Five strings exist, each at most two sentences, each naming its threshold direction,
    and a non-expert reading only these strings can correctly say whether a given card is good news.
  - **Notes:** The direction traps are the point of this task: MZ and Shen are "smaller is better"
    against 0.05, `qn` is "larger is better" against a threshold that depends on n, and RECeUS needs two
    conditions at once. The Immune card is a **descriptive summary, not a test**, so its copy must not
    imply a decision. RECeUS is Selukar and Othus (2023) and its two conditions are pi-hat above 0.025
    and r-hat below 0.05.

---

## T3 - Thu 1:00-3:00 - Verdict tab and report engine

**Thu 1:00-2:00 is the designated flex and absence hour** (campus tours are optional in that slot).
Anyone who skips the tour starts T3 early. **Nothing on the critical path may be scheduled in that
hour**, so plan T3 as if it began at 2:00 and treat anything achieved before then as a bonus.

- [ ] **A-08** Verdict tab: three-step status strip, recommendation, and a disagreement panel - *Owner: Sharon · Backup: Rashid*
  - **What:** Call `cure.appropriateness(data, time, status, time_scale, plot_km = FALSE,
    run_tests = "yes", include_lognormal = <toggle>)` and build a three-step status strip mirroring
    manuscript Figure 1: **Expert judgment -> Visual assessment -> Quantitative assessment**. Step one
    is a control the **user** confirms (is cure biologically plausible for this disease and endpoint?),
    not something the software decides. Then show the plain-language recommendation from the result
    object, and an explicit panel headed along the lines of "the diagnostics can disagree, here is what
    to do".
  - **Done when:** On gbsg the tab simultaneously shows that a cure model has the smallest AIC **and**
    that follow-up is insufficient, the disagreement panel names Maller-Zhou at 0.0495 (which says
    follow-up is sufficient) against `qn` at 0.0044, Shen at 0.3676 and RECeUS r-hat at 0.3080 (which
    say it is not), and the Expert judgment step cannot be ticked by the app itself. Failing any of the
    three steps is presented as making a cure model inappropriate.
  - **Notes:** **Default `run_tests = "yes"`, not `"auto"`, and explain why on screen.** With `"auto"`
    the package silently skips Stage 2 whenever the smallest-AIC model is a non-cure model, which is
    exactly what happens on simulated scenarios B, C and D, so the user would be shown a "not
    supported" conclusion with no diagnostics behind it. With `"yes"` the diagnostics always run and the
    screen has to say why they are shown even though a non-cure model won. One edge case to render
    rather than hide: if no cure model fits at all, the selected distribution is `NA` and the tests do
    not run even under `"yes"`, and the package tells you so in its `tests_reason` field, so display
    that string. On naming, let `cure.appropriateness()` pick and map the RECeUS distribution itself and
    read back `selected_receus_model` and `selected_receus_dist` for display; the package uses two
    naming schemes (`weibull_cure` from the fitting side, short codes like `"wei"` on the RECeUS side)
    and **you must not call the internal `.map_model_to_receus_dist()`** to bridge them. Finally, the
    disagreement panel is not an apology for a bug: the diagnostics are descriptive aids to be read
    together with subject-matter knowledge, not a single decision rule, and the app must say so.

- [ ] **B-07** `report/report.Rmd`: parameterised HTML report - *Owner: Rachael · Backup: Rashid*
  - **What:** Write a parameterised R Markdown report whose `params` carry the dataset label, the
    prepared data and the assessment result, and whose body has seven sections: dataset label, data
    summary, KM plot, AIC table, the five diagnostics, the verdict, and session info, plus citations.
    It must render from a plain R session, not only from inside Shiny.
  - **Done when:** `rmarkdown::render("report/report.Rmd", params = list(...))` run from a fresh R
    session produces a single self-contained HTML file containing all seven sections, and the gbsg
    numbers in it match the oracle (AIC 1719.70, MZ 0.0495, `qn` 0.0044, Shen 0.3676, pi-hat 0.3238,
    r-hat 0.3080).
  - **Notes:** Build it standalone first so that A-09 is a thin wrapper rather than the only way to run
    it; that also makes the report testable when the app is broken. Do not read Shiny reactives or
    global-environment objects inside the document, pass everything through `params`. Use a
    self-contained output so the HTML can be emailed as one file. The diagnostics sections must print
    the "cannot be computed" sentence when a statistic is `NA`, because the report will be run on
    scenarios C and D during B-08. If the report needs the RECeUS distribution, take it from the
    assessment object's `selected_receus_dist`, not from a hand-written lookup, and **do not call the
    internal `.map_model_to_receus_dist()`**.

- [ ] **G-04** Verdict copy plus the "follow-up looks insufficient, what now?" guidance - *Owner: Geethanjalee · Backup: (Durbadal)*
  - **What:** Write the copy for the three-step strip and the recommendation, and a short guidance block
    listing the options when follow-up is insufficient: use a non-cure model; or the extreme-value
    estimators of Escobar-Bach and Van Keilegom; or Yuen and Musta's relaxed condition; or collect more
    follow-up.
  - **Done when:** The four options are written as a list with one sentence each, the three-step strip
    has its labels and one-line explanations, and A-08 and B-07 both use these exact strings.
  - **Notes:** The reason this guidance matters is that the problem cannot be fixed after the fact:
    Othus et al. re-analysed six SWOG trials at two follow-up times, cure-model estimates of mean
    survival shifted materially, and **the direction of the shift was not predictable**. The copy should
    also say that step one, expert judgment, is a conversation with a clinician, which is why the app
    asks the user to confirm it. For mortality endpoints, "cure" is best read as long-term
    survivorship, the hazard becoming negligible, not literal immunity to death.

---

## T4 - Thu 3:20-5:00 - integration, report download, regression

- [ ] **A-09** Wire `downloadHandler` to render and download the HTML report - *Owner: Rashid · Backup: (Sharon)*
  - **What:** Add a download button that calls B-07's report with the current dataset label, prepared
    data and assessment result, renders it to a temporary file and returns it with a sensible filename.
    Show a progress indicator while it renders.
  - **Done when:** Clicking Download produces an `.html` file that opens in a browser and is identical
    in content to what B-07 renders standalone for the same dataset. Clicking it before any assessment
    has run gives a message rather than an error.
  - **Notes:** Render to `tempfile()` and copy to the handler's `file` argument; rendering in place
    inside the app directory will fail or litter the repo. Pass everything the report needs through
    `params` explicitly. Rendering is the slowest thing the app does, so the progress indicator is not
    optional polish, it is what stops a judge clicking twice.

- [ ] **A-10** In-app help on every statistic, plus the About tab - *Owner: Sharon · Backup: (Rashid)*
  - **What:** Attach a tooltip or popover to every statistic the app prints, using the copy from G-02,
    G-03 and G-04 verbatim. Fill in the About tab with the key references and how to cite the package.
  - **Done when:** Every number on screen has a help affordance, and the About tab cites Maller and Zhou
    (1992, 1994), Shen (2000) and Selukar and Othus (2023), plus how to cite `cureAssess` (version
    0.1.0, MIT licensed, authors Geethanjalee Mudunkotuwa and Durbadal Ghosh, upstream
    `https://github.com/GeethanjaleeM/cureAssess`). This closes Definition of Done item 5.
  - **Notes:** Do not write new statistical wording here. If a tooltip needs copy that G-02/G-03/G-04 do
    not cover, that is a question for Geethanjalee, not a gap to fill in yourself. The About tab may
    also note that the workflow operationalises the Figure 1 workflow of the tutorial manuscript
    "A Tutorial for Evaluating Cure Model Appropriateness" (Mudunkotuwa, Ghosh, Triplett, Selukar,
    in preparation); the manuscript itself is not in this repo.

- [ ] **B-08** Full regression: every tab, all seven datasets, app versus oracle - *Owner: Rachael + Geethanjalee · Backup: (Durbadal)*
  - **What:** Walk every tab for all seven datasets, the three real plus the four simulated, checking
    the data summary, the KM plot, the AIC table, all five diagnostics, the verdict and the downloaded
    report against the oracle. Commit the sign-off table.
  - **Done when:** A committed table has seven rows and one column per checked artefact, every cell is
    a tick or an issue link, and both Rachael and Geethanjalee have signed it.
  - **Notes:** This is the evidence for Definition of Done item 3, and any mismatch is blocking, not
    cosmetic. Scenarios C and D are where the `NA` rendering gets its real test, so check those cards
    explicitly rather than skimming them. Keep the lognormal toggle off for the comparison runs, and use
    `run_tests = "yes"` throughout. The RECeUS distribution shown must be the one
    `cure.appropriateness()` selected, and nothing in this pass should involve hand-mapping model names
    or calling the internal `.map_model_to_receus_dist()`.

- [ ] **B-09** Clean-clone test on a machine that has never run the app - *Owner: Geethanjalee · Backup: (Durbadal)*
  - **What:** On a machine with no prior setup, `git clone` the repo, follow the README literally with
    no insider knowledge, and time how long it takes to get to a running app. Write down every step the
    README left out.
  - **Done when:** Clone to running app is under 10 minutes on the stopwatch, and any missing step is
    either fixed in the README in this block or filed as an issue for D-01.
  - **Notes:** Definition of Done items 1 and 6 both depend on this. The usual failures are an
    uninstalled dependency, a working-directory assumption in `runApp()`, and a data path that only
    exists on the author's machine. Do not help the clean machine from memory; if you had to know
    something, the README is wrong.

- [ ] **T-08** 17:00 feature freeze - *Owner: Durbadal · Backup: [to confirm]*
  - **What:** At 5:00 pm Thursday the lead closes scope. Only bug fixes after this point. Triage the
    open issue list into must-fix and nice-to-have for Friday's bug bash.
  - **Done when:** `decisions.md` records the freeze with its time and the state of the eight Definition
    of Done items, and every open issue carries a must-fix or nice-to-have label.
  - **Notes:** This is the risk R3 mitigation and it is deliberately a full day before judging. The
    stretch list stays written down and explicitly out of scope; anything new after the freeze needs the
    lead's **written** approval in `decisions.md`.

---

## F1 - Fri 9:30-10:30 - bug bash only

- [ ] **A-11 / B-10** Work the issue list by severity - *Owner: whole team · Backup: Durbadal arbitrates severity*
  - **What:** Take the triaged list from T-08 and work it top down, most severe first. A wrong number is
    more severe than a wrong label. Pair up where a bug crosses a pod boundary.
  - **Done when:** Every open issue is either closed, relabelled won't-fix with a written reason, or
    moved to the Parking lot at the bottom of this file. No commit in this block adds a feature.
  - **Notes:** **No new features without the lead's explicit written approval in `decisions.md`.** If a
    fix starts to look like a feature, stop and ask. Re-run the affected rows of B-08's sign-off table
    after each fix rather than assuming the fix was clean.

---

## F2 - Fri 10:50-12:00 - docs and polish

- [ ] **D-01** `README.md` final: what it is, install, run, screenshot - *Owner: Rachael · Backup: (Geethanjalee)*
  - **What:** Rewrite the README so a stranger can go from clone to running app without asking anyone:
    what the project is in two sentences, the dependency list, the install steps, the single command
    that starts the app, and one screenshot. Fold in whatever B-09 found missing.
  - **Done when:** B-11 confirms clone to running app in under 10 minutes following the README alone,
    and the screenshot is committed and renders on the GitHub page.
  - **Notes:** State plainly that the app runs locally via `shiny::runApp()` on the hackathon VM or in
    RStudio and that there is no public hosting; deployment to Posit Connect or shinyapps.io is a
    documented next step (S-5), not something the reader should expect to find. Say that the bundled
    data is public and simulated only.

- [ ] **D-02** `docs/user-guide.md`: guided walkthrough with the gbsg teaching example - *Owner: Rachael · Backup: Geethanjalee*
  - **What:** Write the walkthrough a non-statistician can follow: load gbsg, read the data summary,
    read the KM curve, run the models, read the AIC table, read the five diagnostics, read the verdict,
    download the report. Use gbsg throughout so the reader sees one story end to end.
  - **Done when:** The guide covers all five tabs in order with the gbsg numbers shown, and states the
    teaching point explicitly: AIC picks a cure model, yet r-hat = 0.3080, so follow-up is insufficient
    and the cure fraction cannot be estimated reliably.
  - **Notes:** Say out loud in the guide that the diagnostics disagree on gbsg and that this is not a
    bug: Maller-Zhou at 0.0495 says follow-up is sufficient while `qn`, Shen and RECeUS all say it is
    not. They are descriptive aids to be read together with subject-matter knowledge, not a single
    decision rule. The colon example is worth a short paragraph as the borderline case, r-hat = 0.0640
    against a 0.05 threshold, which shows that thresholds are conventions rather than laws.

- [ ] **D-03** In-app help and label polish pass - *Owner: Sharon + Rashid · Backup: (each other)*
  - **What:** Read every string the app displays, in order, as a first-time user would. Fix labels that
    assume knowledge, units that are not stated, buttons whose effect is unclear, and any place where a
    statistic appears without its help affordance.
  - **Done when:** A full pass through all five tabs produces no unexplained abbreviation, every time
    axis and follow-up figure names its units, and every statistic still has its tooltip after Friday's
    changes.
  - **Notes:** Do not reword statistical claims during a polish pass; wording changes to interpretation
    text go through Geethanjalee. Watch for units in particular: with `time_scale = "days_to_years"` the
    numbers on screen are years, and a label still saying days is a wrong number, not a typo.

- [ ] **D-04** Screenshots and a short screen-capture GIF - *Owner: Rashid · Backup: (Sharon)*
  - **What:** Capture a still of each of the five tabs on the gbsg example, plus a short screen-capture
    GIF of the full walkthrough, and commit them. These serve both the slides and the offline demo
    fallback.
  - **Done when:** Stills of all five tabs and one GIF are committed, they render in the README and the
    deck, and Rashid can talk through the whole demo from the stills alone with the app closed.
  - **Notes:** This is the risk R8 mitigation, so it must be finished Friday morning, not Friday
    afternoon. Capture at a resolution that is readable on a projector. Nothing identifiable and nothing
    non-public may appear in a screenshot.

- [ ] **B-11** Clean-clone re-test after all Friday changes - *Owner: Geethanjalee · Backup: (Durbadal)*
  - **What:** Repeat B-09 against the final state of the repo, following the rewritten README from
    D-01, on a machine that has not run the newest code.
  - **Done when:** Clone to running app is confirmed under 10 minutes on the current `main`, and at
    least one of the built-in examples produces a verdict and a downloaded report on that fresh machine.
  - **Notes:** Friday's docs and polish commits are exactly the kind of change that breaks a path or a
    dependency list, which is why this runs after them rather than before. Anything found here is a
    must-fix before F4's code lock.

---

## F3 - Fri 1:00-2:00 - demo build

- [ ] **D-05** Lightning deck: 5 slides, 3 minutes - *Owner: Durbadal, content from the team · Backup: [to confirm]*
  - **What:** Build five slides for the 3-minute lightning session: the problem, the solution, the live
    demo moment, the gbsg finding, and next steps. Pull the screenshots from D-04 and the numbers from
    the oracle.
  - **Done when:** Five slides exist, committed, and a run-through lands inside 3 minutes in D-07.
  - **Notes:** The strongest slide is the gbsg one, because it is a result rather than a feature list:
    AIC picks a cure model, so a naive analyst would fit one, but r-hat = 0.3080 means the cure fraction
    is not identifiable. Say what the app does not do as well: the published methods assess one group at
    a time, and step one of the three-step check is a conversation with a clinician, not a computation.

- [ ] **D-06** Booth script: 5 minutes, plus answers to the six questions judges will ask - *Owner: Rachael · Backup: (Geethanjalee)*
  - **What:** Write the 5-minute booth walkthrough as a script with the clicks in order, and a short
    written answer to each of the six questions the team expects from judges. Agree the six with the lead
    before writing the answers; **this plan does not enumerate them, so which six is
    [to confirm]**.
  - **Done when:** The script is committed, the six questions each have a written answer of two or three
    sentences, and the walkthrough lands inside 5 minutes in D-07.
  - **Notes:** Script the gbsg contradiction deliberately: a judge may read it as a bug, and the answer
    is that it is the headline finding and the clearest demonstration of why the tool is needed (risk
    R10). Statistical questions at the booth go to Geethanjalee, so the script should hand off rather
    than have the narrator improvise.

- [ ] **D-07** Two timed dry runs on the actual demo machine with the actual app - *Owner: whole team · Backup: Durbadal calls the timings*
  - **What:** Run the 3-minute lightning pitch and the 5-minute booth walkthrough twice each, on the
    machine that will be used in the room, with the app that is on `main`, with a stopwatch.
  - **Done when:** Both scripts have been rehearsed **twice** on the real machine and both land inside
    their time limits, with the screenshot fallback from D-04 committed. This closes Definition of Done
    item 8.
  - **Notes:** Rehearse the failure path too, at least once: app closed, talk from the stills. Note how
    long the report download takes on that machine so nobody stands in silence waiting for it during the
    real thing. Anything that breaks here becomes a must-fix for F4, which is only 45 minutes long, so
    do the dry runs early in the block rather than at 1:50.

---

## F4 - Fri 2:00-2:45 - freeze

- [ ] **D-08** Tag `v1.0`, write `docs/handoff.md`, final push - *Owner: Sharon · Backup: (Rashid)*
  - **What:** Write `docs/handoff.md` listing known limitations and next steps, then tag `v1.0` on
    `main` and push the tag.
  - **Done when:** `git tag` shows `v1.0` on `origin/main`, `docs/handoff.md` is committed, and nothing
    is left unpushed on anyone's machine.
  - **Notes:** The limitations section should say what is genuinely true rather than what sounds modest:
    local-only, no hosting; public and simulated data only; one group at a time, which is the published
    methods' own caveat; and any Definition of Done item that is not fully met. Next steps are the
    stretch list S-1 to S-5, in that order, with S-1 first.

- [ ] **T-09** 2:45 code lock, walk to MTC Room 2 (IA 1405) - *Owner: whole team · Backup: [to confirm]*
  - **What:** At 2:45 pm laptops close. No commits, no fixes, no "one more thing". Walk to MTC Room 2
    (IA 1405) for the 3:00 lightning session.
  - **Done when:** The last commit timestamp on `main` is before 2:45 pm and the whole team is in the
    room before 3:00.
  - **Notes:** This plan does not assign an individual owner to this checkpoint, so someone should be
    asked at the Friday standup to call the time. A fix committed at 2:50 that nobody has run is a worse
    demo risk than the bug it fixes.

---

## Demo day, Fri 3:00-6:00

These are assigned by name rather than by task ID, so the labels below are roles, **not** task IDs.

- [ ] **Lightning pitch** 3 minutes, MTC Room 2 (IA 1405), 3:00-4:00 - *Owner: Durbadal presents · Backup: Sharon drives the app*
  - **What:** Durbadal presents the five-slide deck from D-05; Sharon drives the app live for the demo
    moment. Both roles were rehearsed twice in D-07 on this machine.
  - **Done when:** The pitch is delivered inside 3 minutes with the live demo working, or with the D-04
    stills if the machine or projector fails.
  - **Notes:** Agree beforehand on the one sentence that triggers Sharon's click, so the demo does not
    drift out of sync with the slides. If the projector fails, switch to stills without narrating the
    failure.

- [ ] **Booth** MTC Atrium, 4:00-6:00, rotate every 30 minutes - *Owner: whole team on rotation · Backup: Durbadal floats and closes*
  - **What:** Rachael narrates the 5-minute walkthrough from D-06; Sharon drives; Geethanjalee fields
    statistical questions; Rashid owns the backup laptop and the screenshot fallback; Durbadal floats and
    closes. Rotate every 30 minutes so nobody is stuck for the full two hours.
  - **Done when:** The rotation has actually rotated, the backup laptop has the app already running for
    the whole two hours, and every statistical question has been answered by Geethanjalee rather than
    improvised.
  - **Notes:** Judges may read the gbsg contradiction as a bug; the scripted answer from D-06 reframes it
    as the headline finding. Winners and closing remarks are at 6:00 in the MTC Atrium.

---

## Stretch goals

**Out of scope until the Definition of Done is signed off.** They are written down here so they stop
competing for attention, which is the point of writing them down (risk R3). Work them in order, S-1
first. Owners are unassigned until the freeze is lifted.

- [ ] **S-1** Follow-up truncation slider, highest value, do this one first - *Owner: [to confirm] · Backup: [to confirm]*
  - **What:** Add a slider that restricts follow-up to `t` years, re-runs the whole assessment on the
    truncated data, and shows the verdict flip from "appropriate" to "insufficient follow-up" live.
  - **Done when:** Dragging the slider on a dataset that starts out appropriate visibly flips the verdict
    and moves the diagnostics with it, and the numbers at the untruncated end of the slider still match
    the oracle exactly.
  - **Notes:** This recreates Figure 2 of the tutorial manuscript and is the single most persuasive
    thing the app can do in front of a judge. It costs about 0.2 s per run, so it can be live rather than
    behind a button. Truncating follow-up is exactly what turns simulated scenario A into scenario B, so
    those two datasets are the built-in test. Note that `receus.method()` defaults `whichTau` to the
    maximum observed time, which moves as the slider moves, and that the RECeUS distribution must still
    come from `cure.appropriateness()`'s own selection rather than from a hand-written mapping or the
    internal `.map_model_to_receus_dist()`.

- [ ] **S-2** Simulation lab panel - *Owner: [to confirm] · Backup: [to confirm]*
  - **What:** Expose sliders for cure fraction, follow-up length and censoring rate that feed
    `simulate_cure_data()` and run the assessment live, turning the app into a teaching tool.
  - **Done when:** Setting the sliders to the four scenario parameter sets from B-05 reproduces those
    scenarios' verdicts, including the `NA` diagnostics in C and D.
  - **Notes:** Keep the seed exposed and fixed by default, or the panel will not be reproducible and
    cannot be checked against B-05. Same RECeUS naming caution as S-1: do not hand-map model names and
    do not call the internal mapper.

- [ ] **S-3** Multi-arm / group-by comparison side by side - *Owner: [to confirm] · Backup: [to confirm]*
  - **What:** Let the user pick a grouping column and show the assessment for each group side by side.
  - **Done when:** Two arms of one dataset render complete, independent assessments, each matching what
    the app produces when that arm is uploaded on its own.
  - **Notes:** Carry the manuscript's caveat on screen: the published methods assess **one group at a
    time**. Side-by-side panels must not imply a formal between-group test.

- [ ] **S-4** PDF report in addition to HTML - *Owner: [to confirm] · Backup: [to confirm]*
  - **What:** Add a PDF output format to B-07's report and a second download button.
  - **Done when:** The PDF contains the same seven sections as the HTML with readable plots and tables.
  - **Notes:** PDF output needs a LaTeX toolchain that the VM may not have, so check that before
    starting. HTML stays the primary format.

- [ ] **S-5** Deploy to Posit Connect or shinyapps.io - *Owner: [to confirm] · Backup: [to confirm]*
  - **What:** Publish the app to a hosted service.
  - **Done when:** A URL loads the app and runs one built-in example end to end.
  - **Notes:** The deployment decision for this event is **local only**, so this is documented as a next
    step in `docs/handoff.md` rather than attempted during the hackathon. Anything hosted changes the
    data question, and only public and simulated data may ever be involved.

---

## Parking lot

Ideas raised during the event that are **not in scope** go here, not into the app. Anything in this
table is explicitly not a commitment. Add a row, say it at the next standup, and move on; after the
Thursday 5:00 pm feature freeze this table is the only legitimate destination for a new idea that is
not a bug fix.

| Date | Idea | Raised by | Why it is not in scope now | Where it goes instead |
| --- | --- | --- | --- | --- |
|  |  |  |  |  |

Rules for this table:

- An idea that is really a bug belongs in a GitHub issue, not here.
- An idea that is really one of S-1 to S-5 belongs in the stretch list above, not here.
- An idea that changes the approach rather than adding to it belongs in `decisions.md` with a date and
  a reason.
- Nothing moves out of the parking lot and into the app without the lead's written approval in
  `decisions.md`.
