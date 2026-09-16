# cureAssessApp — Shiny application specification

Project: **cureAssessApp**, an interactive Shiny front end for the `cureAssess` R package. Team KIDS26 Team 9,
St. Jude BioHackathon 2026 (Wed 16 – Fri 18 September 2026). Repo `stjude-biohackathon/KIDS26-Team9`, branch
`main`. Deployment: **local only**, `shiny::runApp("app")`. Stack: R (>= 4.1; the VM has 4.6.1), `shiny`,
`bslib`, `DT`, `rmarkdown`; via the package, `survival`, `flexsurv`, `flexsurvcure`, `survminer`, `ggplot2`,
`dplyr`. Package under test: `cureAssess` 0.1.0, vendored at `cureAssess/` (MIT; Mudunkotuwa, Ghosh).

**The app does not exist yet. This document is the build target for Pod A.** It is written so a Shiny developer
with no cure-model background can implement every tab without making a statistical judgement call. Where a
statistical judgement is needed, the spec names Geethanjalee's task (`G-01`–`G-04`) instead of asking Pod A to
decide.

---

## 1. Design principles

1. **Guided linear workflow, not a dashboard of knobs.** Tabs run **Data → Models → Diagnostics → Verdict →
   About**, walked left to right. A tab that cannot yet do its job names the missing earlier step and offers a
   control that goes there. No options screen; no tab that assumes the cure-model literature.
2. **The app never computes a statistic.** Every inferential quantity on screen is a field of an object
   returned by an exported `cureAssess` function — no likelihoods, survival formulas, thresholds or p-values in
   app code. If a number the design asks for is not a field of a package return object, change the design
   rather than compute it. Two narrow exceptions are named in §5 (items 9, 10); nothing else is exempt.
3. **Every number is traceable to a package call.** For each displayed value the implementer must be able to
   name call and field, e.g. "`cure.appropriateness()` → `$tests$receus$r_hat`"; review rejects values whose
   origin cannot be named. This is what makes Pod B's oracle comparison (`G-01`, `B-04`, `B-06`, `B-08`)
   meaningful: a mismatch is a blocking bug (risk R5).
4. **Plain language first, the formal statistic second.** Each card leads with a sentence a clinician can read,
   then the statistic, its threshold, and the package's own `interpretation` string. Wording is Geethanjalee's
   deliverable (`G-02`–`G-04`); Pod A wires it in.
5. **No dead ends.** Every empty state names the next action; every failure states what happened, why, and what
   to do, in that order. A red Shiny stack trace is a bug as severe as a wrong number.

---

## 2. File layout

```
app/
  app.R                 # navbar page, server shell, creates the shared state object
  R/
    mod_data.R          # Data tab: dataset choice, upload, column mapping, summary, KM
    mod_models.R        # Models tab: Run button, AIC table, best-model callout, overlay
    mod_diagnostics.R   # Diagnostics tab: the five diagnostic cards
    mod_verdict.R       # Verdict tab: three-step strip, recommendation, report download
    mod_about.R         # About tab: static content, references, citation, licence
    helpers.R           # non-statistical utilities + the fenced interpretation-copy block
    datasets.R          # built-in dataset registry (label, file, time, status, event level, scale)
  www/
    app.css             # the only stylesheet
report/
  report.Rmd            # parameterised HTML report (B-07)
```

**Rule: one person owns one module file** (risk R4, everyone editing one `app.R`, was rated High). Read any
file; edit only the file you own. A change you need elsewhere is a request, not an edit. Sharon owns merges to
`main`; branch per task `<initials>/<task-id>-<short-slug>`; push at every block end.

| File | Owner | Tasks landing here | Cross-edit to sequence |
| --- | --- | --- | --- |
| `app/app.R` | Sharon | `A-01` | None — only Sharon edits it, all week. |
| `app/R/mod_data.R` | Rashid | `A-02`, `A-04` | Sharon's `A-03` (upload + mapper) also lands here; both are W3. `A-03` merges **first**, Rashid rebases `A-04`. Separate the two regions with comment fences. |
| `app/R/mod_models.R` | Sharon | `A-05` | Rashid's `A-06` (overlay). `A-05` merges first. |
| `app/R/mod_diagnostics.R` | Rashid | `A-07` | None. |
| `app/R/mod_verdict.R` | Sharon | `A-08` | Rashid's `A-09` (`downloadHandler`). `A-08` merges first. |
| `app/R/mod_about.R` | Sharon | `A-10` | None. |
| `app/R/helpers.R` | Sharon | `A-10` (tooltip helper) | **Append-only**; nobody edits another person's function. `G-02`/`G-03`/`G-04` copy sits in one fence at the bottom, `# --- interpretation copy: owner Geethanjalee ---`, which Pod A never edits. |
| `app/R/datasets.R` | Rachael | `B-02`, `B-03`, `B-05` | Sharon fixes the registry's column shape in W2 and does not change it after that without a `decisions.md` entry. Rachael is the only person who adds rows. |
| `app/www/app.css` | Sharon | `A-01`, `D-03` | None. |
| `report/report.Rmd` | Rachael | `B-07` | Rashid's `A-09` calls it, does not edit it. |

---

## 3. Shared state contract

`app.R` creates exactly one `reactiveValues` object, `state`, and passes it to every module server:
`mod_data_server("data", state)`. Modules communicate **only** through `state` — no module reads another's
inputs, none returns a reactive to another. This contract is what lets four people work in parallel; it is
agreed in W2 (`A-01`) and renaming a field afterwards needs a `decisions.md` entry.

| Field | Type | Meaning | Written by | Read by |
| --- | --- | --- | --- | --- |
| `raw` | `data.frame` / `NULL` | The dataset exactly as loaded, built-in CSV or upload. Never modified. | Data | Data |
| `label` | `character(1)` / `NULL` | Dataset name for the header, KM title and report. | Data | all |
| `source` | `"builtin"` / `"upload"` / `NULL` | Provenance line in the report. | Data | Verdict |
| `map` | `list` / `NULL` | `time` (chr column), `status` (chr column), `event_level` (the status value meaning "event"), `time_scale` (`"none"` / `"days_to_years"`). | Data | Data, Verdict |
| `prepared` | `data.frame` / `NULL` | Output of `prepare.surv.data()`; guaranteed numeric `Y` and `D` in {0,1}. **The only data frame passed to any package function.** | Data | all |
| `fit` | `cure.model.fit` / `NULL` | Output of `model.fitting(plot_km = TRUE)`. Needed because it is the **only** object carrying the fitted model objects at `$fits[[m]]$fit`, which the overlay requires. | Models | Data (KM), Models |
| `assess` | `cure.appropriateness` / `NULL` | Output of `cure.appropriateness(run_tests = "yes")`: `$screening$aic_table`, `$screening$initial_decision`, `$selected_receus_dist`, `$tests`, `$tests_run`, `$tests_reason`, `$final_recommendation`. | Models | Models, Diagnostics, Verdict |
| `include_lognormal` | `logical(1)` | The toggle value that produced `fit` and `assess`, so table and report can state the candidate set. Initial `FALSE`. | Models | Models, Verdict |
| `expert_confirmed` | `logical(1)` | Whether the user ticked Verdict step 1. Initial `FALSE`. Software never sets it `TRUE`. | Verdict | Verdict |
| `status` | `character(1)` | `"empty"`, `"data_loaded"`, `"prepared"`, `"assessed"`, `"error"`. Drives every empty state. Initial `"empty"`. | Data, Models | all |
| `last_error` | `character(1)` / `NULL` | Message from the most recent caught failure, shown verbatim in a friendly frame. Cleared on success. | Data, Models | all |

Transitions: a successful Prepare sets `raw`/`label`/`source`/`map`/`prepared`/`fit` and `status = "prepared"`;
a successful Run sets `fit`/`assess`/`include_lognormal` and `status = "assessed"`. Changing dataset or
re-preparing **must** null `assess` and return `status` to `"prepared"`, so no stale verdict survives a data
change.

---

## 4. Tab specifications

IDs below are module-internal: wrap in `ns()` in UI, use bare in the server. Module ids: `"data"`, `"models"`,
`"diagnostics"`, `"verdict"`, `"about"`.

### 4.1 Data tab — `mod_data.R` (Rashid: `A-02`, `A-04`; Sharon: `A-03`)

**Purpose.** Get one dataset into `state$prepared` with `Y` and `D` correctly coded, and show enough for the
user to believe it worked.

| Input ID | Widget | Detail |
| --- | --- | --- |
| `source` | `radioButtons` | `"builtin"` (default) / `"upload"`. |
| `builtin` | `selectInput` | Seven registry choices: curated `nwtco_high_risk`, `gbsg`, `colon_lev5fu` (`B-02`) plus the four simulated scenarios A–D (`B-03`, `B-05`). Keys for the simulated four are **[to confirm]** at the T1 handover and must match the committed file names. Default: `gbsg`. |
| `file` | `fileInput` | `accept = ".csv"`, single file, shown only when `source == "upload"`. |
| `col_time` | `selectInput` | The numeric columns of `raw`. |
| `col_status` | `selectInput` | All columns of `raw`. |
| `event_level` | `selectInput` | Distinct values of the chosen status column with row counts, e.g. `1 (299 rows)`. The user picks the level meaning **event**. |
| `time_scale` | `radioButtons` | `"none"` / `"days_to_years"`, with the line "choose days-to-years if your time column is recorded in days". |
| `prepare` | `actionButton` | "Prepare data", primary styling. |

| Output ID | Type | Content |
| --- | --- | --- |
| `summary_card` | `uiOutput` | n, events, censored %, median follow-up, max follow-up, time unit in force. |
| `head_table` | `DT::DTOutput` | `head(state$prepared)`, `Y` and `D` as the first two columns. |
| `km_plot` | `plotOutput` | The package's own KM plot with risk table, `state$fit$kmplot`. Height >= 480 px. |
| `data_msg` | `uiOutput` | Empty state and error states. |

**Package calls** — inside `observeEvent(input$prepare, ...)`, in this order:

```r
df <- state$raw                                          # 1. recode to 0/1 BEFORE the package sees it
df$.D01 <- as.integer(df[[input$col_status]] == input$event_level)

state$prepared <- cureAssess::prepare.surv.data(         # 2. the only preparation call in the app
  data = df, time = input$col_time, status = ".D01",
  time_scale = input$time_scale                          # "none" or "days_to_years"
)

state$fit <- cureAssess::model.fitting(                  # 3. KM plot + risk table come from the package
  state$prepared, plot_km = TRUE, include_lognormal = state$include_lognormal
)
```

The six summary numbers are descriptive counts on `state$prepared` from `helpers.R::data_summary()`:
`n = nrow`, `events = sum(D)`, `censored % = 100 * (1 - mean(D))`, `median follow-up = median(Y)`,
`max follow-up = max(Y)` — counts of the prepared columns, not cure-model statistics, which is why they are
permitted (§5 item 10). Label median follow-up "median of observed follow-up times, all subjects" so the
definition is unambiguous. `max follow-up` must equal `state$assess$tests$immune$last_observation` once the
assessment has run; `B-06` checks it.

**Layout.** Sidebar (width 4): source, dataset or upload, the four mapping controls, Prepare. Main (width 8):
summary card, KM plot, `head()` table.

**Empty state.** On launch `gbsg` is preselected and Prepare runs once automatically, so a real summary card
and KM curve are on screen immediately (§8). If the selection is cleared: "Pick a built-in example or upload a
CSV, then press Prepare data."

**Error states** — wrap the calls in `tryCatch`, render into `data_msg`, never crash. Every message shows the
package's own text in a collapsed technical-detail block underneath.

- Unreadable CSV: "That file could not be read as CSV. Check that it is comma-separated with a header row."
- `` `Y` must be numeric``: "The time column you chose is not numeric. Pick a numeric column."
- `` `D` must be coded as 0/1``: "The event indicator could not be reduced to 0/1. Check which level you marked
  as the event." Unreachable if the recode ran — if it appears it is a recode bug, not user error.
- Event level matching zero rows: "No rows have that value, so there would be no events. Pick a different
  level." Block Prepare.
- `sum(D) == 0` or `nrow(df) < 2` after preparation: "This dataset has no events (or too few rows) to assess.
  Cure-model diagnostics need both events and censored observations."
- Anything else: "Preparing the data failed", plus the verbatim message.

**Acceptance.** (1) Built-in "nwtco — High risk" plus Prepare shows **n = 1404** (`A-02`). (2) Uploading
`gbsg.csv` with `time = rfstime`, `status = status`, event level `1`, scale `days_to_years` reproduces the
built-in `gbsg` path exactly (`A-03`). (3) KM plot renders with a risk table (`A-04`). (4) Every error case
above has been triggered by hand and produced the stated panel. (5) Changing dataset after an assessment clears
`state$assess` and the Verdict tab returns to empty.

### 4.2 Models tab — `mod_models.R` (Sharon: `A-05`; Rashid: `A-06`)

**Purpose.** Show which of the eight (or ten) candidate models fits best by AIC, and make it unmistakable that
"a cure model won on AIC" is initial support only.

| Input ID | Widget | Detail |
| --- | --- | --- |
| `include_lognormal` | `checkboxInput` | Default `FALSE`. Label "Also fit lognormal models". Helper text: "Off by default. The lognormal distribution has a heavy tail that can change both the selected model and the RECeUS conclusion." |
| `run` | `actionButton` | "Run assessment". **Nothing fits on input change** — only on this click (§6). |
| `overlay_model` | `selectInput` | Which fitted model to overlay: AIC-table rows with empty `error`; default `state$fit$best_model`. Disabled until a run exists. |

| Output ID | Type | Content |
| --- | --- | --- |
| `aic_table` | `DT::DTOutput` | `state$assess$screening$aic_table`, sortable, default ascending by AIC; columns model / model_type badge / AIC / parameter_estimates / **error always visible** (§5 item 4). |
| `best_callout` | `uiOutput` | Best model and type, `state$assess$screening$initial_decision` verbatim, plus `G-02`'s "AIC is initial support only" copy. |
| `overlay_plot` | `plotOutput` | KM curve with the selected fitted survival curve overlaid. |
| `models_msg` | `uiOutput` | Empty and error states. |

**Package calls** — one `observeEvent(input$run, ...)` inside `withProgress`:

```r
state$include_lognormal <- isTRUE(input$include_lognormal)

state$fit <- cureAssess::model.fitting(
  state$prepared, plot_km = TRUE, include_lognormal = state$include_lognormal
)

state$assess <- cureAssess::cure.appropriateness(
  data = state$prepared, time = "Y", status = "D",
  time_scale        = "none",   # already scaled by prepare.surv.data — never scale twice
  run_tests         = "yes",    # never "auto" — §5 item 2
  plot_km           = TRUE,
  include_lognormal = state$include_lognormal
)
state$status <- "assessed"
```

Both calls are deliberate. `cure.appropriateness()` keeps `$screening$aic_table` but **discards the fitted
model objects**, while `model.fitting()` keeps them at `$fits[[m]]$fit`, which `A-06` needs to draw a curve.
The two fit the same models to the same data with the same options and the fitting is deterministic, so their
AIC values agree. **The displayed AIC table must come from `state$assess$screening$aic_table`** — one source of
truth; `state$fit` supplies only curve geometry and the KM plot. Disagreement between them is a blocking bug.
Badge: read `model_type` (`"cure"` / `"non-cure"`) from the table, never infer it from the model name, and show
the word, not just a colour (§8).

**Overlay (`A-06`).** Take `state$fit$fits[[input$overlay_model]]$fit` and get its survival curve from the
fitting package's own summary method (`summary(fit, type = "survival", t = grid)`); do not hand-code a
parametric survival function. Draw it over the KM estimate with a legend naming both curves. If the selected
model's `error` is non-empty: "This model did not fit, so there is no curve to draw", and show KM alone.

**Empty state.** Before the first run: "Press Run assessment to fit the candidate models." If `state$prepared`
is `NULL`: "Prepare a dataset on the Data tab first", with a button that goes there.

**Error states.** `model.fitting()` never throws on a failed fit — it records the reason in `error` and sets
`AIC = NA` (§5 item 4), so per-model failures are a display concern, not an error state. Two real error states
remain: every model failed, so `best_model` is `NA` ("No candidate model could be fitted to this dataset", plus
the `error` column); or `cure.appropriateness()` threw ("The assessment could not be completed", plus the
verbatim message — §5 item 11).

**Acceptance.** (1) Built-in `gbsg`, default toggle: top row `loglogistic_cure`, AIC **1719.70**, badged
"cure". (2) nwtco High risk: `loglogistic_cure`, AIC **1928.38**. (3) colon recurrence `Lev+5FU`:
`loglogistic_cure`, AIC **741.52**. (4) Table sorts by AIC and by model, `error` visible without horizontal
scrolling at 1440 px, `AIC = NA` rows sort last. (5) Flipping the lognormal toggle refits nothing until Run is
pressed. (6) The overlay renders for the default best model on all three curated examples.

### 4.3 Diagnostics tab — `mod_diagnostics.R` (Rashid: `A-07`)

**Purpose.** Show all five diagnostics side by side — statistic, threshold, chip, the package's own words —
including the case where three of them cannot be computed at all.

| Input ID | Widget | Detail |
| --- | --- | --- |
| `dist_override` | `selectInput` | Advanced, in a collapsed panel. RECeUS short codes only: `exp`, `wei`, `gam`, `llogis`, `lnorm`, `expUnc`, `weiUnc`, `gamUnc`, `llogisUnc`, `lnormUnc`. Default empty = "use the distribution `cure.appropriateness()` selected". |
| `rerun` | `actionButton` | "Re-run diagnostics with this distribution". Enabled only when `dist_override` is non-empty. |

**Outputs.** Five `uiOutput` cards — `card_mz`, `card_qn`, `card_shen`, `card_immune`, `card_receus` — plus
`diag_msg` for empty and error states.

**Package calls.** By default the tab **calls nothing**: it reads `state$assess$tests`, which
`cure.appropriateness(run_tests = "yes")` already populated — that is how the app avoids the internal
name-mapping trap (§5 item 3). Only the advanced override calls a function, with a short code the user picked:
`cureAssess::run.cure.tests(state$prepared, dist = input$dist_override)`. Override results render in the same
five cards behind a visible banner — "Showing diagnostics for distribution `<code>`, chosen by hand. The
Verdict tab still uses the automatically selected distribution `<state$assess$selected_receus_dist>`" — and
never write to `state`. Each card shows: title, one plain-language sentence from `G-03`, the statistic, the
threshold, the chip, and the package's `interpretation` string in full.

| Card | Statistic field(s) | Threshold shown | Chip rule |
| --- | --- | --- | --- |
| Maller–Zhou 1994 | `tests$mz$statistic` | `tests$mz$alpha` (0.05) | `< alpha` → "Follow-up looks sufficient"; else "Not sufficient". |
| `qn` | `tests$qn$statistic` | `1 - 0.05^(1/n)`; **larger `qn` is better** (§5 item 9) | `>` threshold → "Follow-up looks sufficient"; else "Not sufficient". |
| Shen 2000 | `tests$shen$statistic` | `tests$shen$alpha` (0.05) | `< alpha` → "Follow-up looks sufficient"; else "Not sufficient". |
| Immune summary | `p_hat`, `p_cens`, `last_observation`, `last_observation_censored` | none — there is no threshold | Neutral chip reading **"Descriptive, not a test"**. Never pass/fail (§5 item 6). |
| RECeUS | `pi_hat`, `r_hat` | `pi_hat > 0.025` **and** `r_hat < 0.05` | Chip is `tests$receus$decision` verbatim: "Cure model appropriate", "Cure model not supported", or "Follow-up insufficient for cure modeling". Show `cure_fraction_condition` and `followup_condition` as two separate ticks, and `tau` labelled "evaluated at the largest observed time" (§5 item 8). |

**The not-computable state (mandatory — risk R7, rated High).** Maller–Zhou, `qn` and Shen return `NA` whenever
the largest observed time is an **event** rather than a censored observation; all three are gated by the same
condition in the package source, so they go `NA` together. Simulated scenarios C and D are exactly this case.
When `is.na(statistic)` the card renders:

- The statistic slot shows an em dash — never the text `NA`, never a blank cell.
- Chip: **"Cannot be computed"**, neutral grey, with a dash glyph so colour is not the only signal.
- Body line, exactly: **"Cannot be computed — the longest observed time is an event, so there is no plateau to
  test."**
- Second line: "This is a property of the data, not an error. All three follow-up tests need follow-up to
  extend past the last event."
- The package's own `interpretation` string underneath, in technical-detail style.
- Immune and RECeUS still render normally — they are not gated by that condition. Do not hide them.

RECeUS has a **separate** not-computable state: if the maximum-likelihood fit behind it fails, `pi_hat` and
`r_hat` come back `NA`. Render "Cannot be computed — the model fit behind RECeUS did not converge for this
dataset." That case can also make the assessment call itself throw (§5 item 11), which is why Run is wrapped.

**Layout.** Two-column card grid at desktop width, single column below 768 px, fixed order Maller–Zhou, `qn`,
Shen, Immune, RECeUS. Above the grid, one line naming the RECeUS distribution used and stating that the
diagnostics are shown even when a non-cure model won on AIC (§5 item 2).

**Empty state.** "Run the assessment on the Models tab to see the diagnostics", with a button that goes there.
If `state$prepared` is `NULL`, point at the Data tab instead.

**Acceptance.** (1) Built-in `gbsg`: MZ **0.0495**, `qn` **0.0044**, Shen **0.3676**, π̂ **0.3238**, r̂
**0.3080**, RECeUS chip "Follow-up insufficient for cure modeling". (2) nwtco High risk: MZ **1.04e-140**, `qn`
**0.2051**, Shen **0.0496**, π̂ **0.7823**, r̂ **0.0041**, chip "Cure model appropriate". (3) colon `Lev+5FU`:
MZ **5.25e-13**, `qn` **0.0888**, Shen **0.0065**, π̂ **0.5736**, r̂ **0.0640**, chip "Follow-up insufficient".
(4) Simulated scenarios C and D render three not-computable cards with the exact wording above and still render
Immune and RECeUS — no `NA` text, no blank cell, no crash. (5) Every statistic matches `tests/reference/`
(`G-01`) to the digits printed.

### 4.4 Verdict tab — `mod_verdict.R` (Sharon: `A-08`; Rashid: `A-09`)

**Purpose.** Put the tutorial's Figure 1 three-step check on one screen, be explicit that step 1 belongs to a
human, and let the user take the whole thing away as a report.

| Input ID | Widget | Detail |
| --- | --- | --- |
| `expert_ok` | `checkboxInput` | Default `FALSE`. Label: "I have confirmed with subject-matter knowledge that cure is biologically plausible for this population and endpoint." Writes `state$expert_confirmed`. |
| `download_report` | `downloadButton` | "Download HTML report". Disabled until `state$status == "assessed"`. |

| Output ID | Type | Content |
| --- | --- | --- |
| `step_strip` | `uiOutput` | **① Expert judgment → ② Visual assessment → ③ Quantitative assessment**. |
| `recommendation` | `uiOutput` | `G-04`'s plain-language recommendation, then `state$assess$final_recommendation` verbatim. |
| `disagree_panel` | `uiOutput` | "The diagnostics can disagree — here is what to do." |
| `tests_reason` | `textOutput` | `state$assess$tests_reason` verbatim. |
| `verdict_msg` | `uiOutput` | Empty and error states. |

**Package calls.** None. This tab renders `state$assess`; all its numbers come from the single
`cure.appropriateness(run_tests = "yes")` call made on the Models tab.

| Step | Source | Chip |
| --- | --- | --- |
| ① Expert judgment | `state$expert_confirmed` — **the user's checkbox, nothing else** | Unticked "Waiting on you" / ticked "Confirmed by user". The strip carries: "Software cannot judge clinical plausibility. This step is a conversation with a clinician." |
| ② Visual assessment | `state$assess$tests$immune$last_observation_censored`, beside a thumbnail of the KM plot | `TRUE` → "Plateau possible: the last observation is censored"; `FALSE` → "No clear plateau: the last observation is an event". Quote `tests$immune$interpretation` underneath; label the step a visual aid, not a test. |
| ③ Quantitative assessment | `state$assess$tests$receus$decision` verbatim, plus a tally of the follow-up tests | Chip = the RECeUS decision string. Support line: "Of the three follow-up tests, `<k>` of `<m>` computable tests indicated sufficient follow-up", and where `m < 3`, "the other `<3 - m>` could not be computed on this dataset". **This is a tally of chips already shown on the Diagnostics tab, not a new statistic. Do not build a composite score and do not weight the tests.** |

If step ① is unticked, steps ② and ③ still render their findings and the recommendation block carries a banner:
"Steps 2 and 3 are shown below, but a cure model is only appropriate if all three steps pass. Step 1 is still
open." Failing any step means a cure model is inappropriate.

**The "diagnostics can disagree" panel** is always visible, never collapsed; copy from `G-04`. It must state
that the five diagnostics are descriptive aids to be read with subject-matter knowledge, not a single decision
rule; that they can and do disagree; and that thresholds such as 0.05, 0.025 and the r̂ cut-off are conventions,
not laws. Use built-in `gbsg` as the worked illustration — Maller–Zhou (0.0495) says follow-up is sufficient
while `qn`, Shen and RECeUS all say it is not — and built-in `colon` as the borderline case, r̂ = 0.064 against
the 0.05 threshold. When the displayed diagnostics actually disagree, lead with a line saying so for this
dataset. The "follow-up looks insufficient — what now?" guidance is also `G-04`'s: use a non-cure model; or the
extreme-value estimators of Escobar-Bach & Van Keilegom; or Yuen & Musta's relaxed condition; or collect more
follow-up.

**Layout.** Step strip full width at the top, recommendation below, disagreement panel below that,
`tests_reason` and the download button at the bottom.

**Empty state.** "Run the assessment on the Models tab to get a verdict", with a button that goes there. The
expert-judgment checkbox stays usable before any run — it is the one step needing no computation.

**Error states.** If `state$assess$tests_run` is `FALSE`, render `tests_reason` verbatim under the heading "The
diagnostics were not run" and do not fabricate steps ② or ③. If report rendering fails: "The report could not
be generated", plus the verbatim message, leaving the on-screen verdict intact.

**Acceptance.** (1) All three curated examples render three steps, step ① "Waiting on you" until ticked. (2) On
`gbsg`, step ③ reads "Follow-up insufficient for cure modeling" and the disagreement panel is surfaced with its
lead line. (3) Toggling `expert_ok` changes only step ①, and the change appears in a freshly downloaded report.
(4) The download button is disabled before a run and produces a self-contained HTML file after one. (5) No
number on this tab was computed in app code.

### 4.5 About tab — `mod_about.R` (Sharon: `A-10`)

Static content, no inputs, one `uiOutput` (`about_body`). Sections in order:

1. **What this app does.** It walks a dataset through the published two-stage check for whether a *cure model*
   is appropriate — Kaplan-Meier plus AIC model comparison, then five follow-up and cure-fraction diagnostics —
   and returns a plain-language verdict plus a downloadable report.
2. **What it does not do**, verbatim: "This app assesses whether a cure model is *appropriate*. It does not fit
   your final analysis model, and it does not produce treatment-effect estimates."
3. **The package.** `cureAssess` 0.1.0, MIT licensed; authors Geethanjalee Mudunkotuwa (author, creator,
   copyright holder) and Durbadal Ghosh (author); upstream `https://github.com/GeethanjaleeM/cureAssess`,
   vendored here at `cureAssess/`. The app is a front end; every statistic is the package's.
4. **The four key references** (Definition of Done item 5), each with the DOI printed in the package
   documentation: Maller & Zhou (1992), *Biometrika* 79(4), 731–739; Maller & Zhou (1994), *JASA* 89(428),
   1499–1506; Shen (2000), *Statistics & Probability Letters* 49(4), 313–322; Selukar & Othus (2023),
   *Statistics in Medicine* 42(3), 209–227.
5. **The tutorial manuscript**: "A Tutorial for Evaluating Cure Model Appropriateness" — Mudunkotuwa, Ghosh,
   Triplett, Selukar (in preparation). The app operationalises its Figure 1 workflow; the manuscript is not
   distributed with this repo.
6. **How to cite**, in a copyable block: the citation for `cureAssess` 0.1.0 and for this app; exact text
   **[to confirm]** with Geethanjalee before F2 (`D-03`). **Licence:** the package is MIT, the app's licence is
   the repo's `LICENSE.md`. **Data note:** built-in examples are public or simulated data only, with provenance
   and licence for each in `data/examples/README.md` (`B-02`); no restricted or identifiable data is here.

**Acceptance.** All four references present with DOIs; the "does not fit your final model" sentence present;
every statistic shown anywhere in the app has a tooltip or popover (`A-10`); the package version is named.

---

## 5. Behaviour rules that are easy to get wrong

Verified properties of `cureAssess` 0.1.0. Each is a requirement, with its reason.

1. **Recode status to 0/1 before the package sees it, and let the user say which level means "event".**
   `.check_surv_data()` requires `D` to be exactly 0/1 and `Y` numeric. A 1/2 coding is very common and errors;
   `TRUE`/`FALSE` must be remapped too. Hence the `event_level` selector and the `.D01` column in §4.1. Never
   guess the event level from the data.
2. **`run_tests` must be `"yes"`, never `"auto"`.** With `"auto"` the package silently skips Stage 2 whenever
   the smallest-AIC model is a non-cure model: the user would see no diagnostics and not be told why. Always
   pass `"yes"` and say on screen why they appear even though a non-cure model won — "a non-cure model fits
   better" and "there is no cure fraction to find" are different claims.
3. **Two naming schemes; do not call `.map_model_to_receus_dist()`.** `model.fitting()` returns names like
   `weibull_cure`; `receus.method()` wants short codes (`"exp"`, `"wei"`, `"gam"`, `"llogis"`, `"lnorm"`, and
   the `...Unc` non-cure variants). The translation is an **internal** function, so calling it means depending
   on an unexported symbol. Let `cure.appropriateness()` map (the default path) or expose a dropdown of short
   codes (§4.3). The mapped code is readable at `state$assess$selected_receus_dist` — show it on screen.
4. **`model.fitting()` never throws on a failed fit, so display the `error` column.** A failure is recorded as
   a message in `error` with `AIC = NA`. Hiding the column turns a silent failure into an invisible one — the
   user sees a short table and no reason. `AIC = NA` rows sort last; never filter failed rows out (risk R6).
5. **Three diagnostics return `NA` when the largest observed time is an event.** Maller–Zhou, `qn` and Shen all
   need follow-up to extend past the last event. Render the exact wording in §4.3: "Cannot be computed — the
   longest observed time is an event, so there is no plateau to test." Not a blank, not `NA`, not a crash
   (risk R7, rated High; simulated scenarios C and D hit it).
6. **`immune.test()` is a descriptive summary, not a test, despite the name.** It reports the KM-based event
   probability at the end of follow-up, the censoring proportion, and whether the last observation was
   censored. No threshold, no null hypothesis: a neutral "Descriptive, not a test" chip, never pass/fail.
7. **`include_lognormal` is opt-in and can change the conclusion.** It defaults to `FALSE` so the candidate set
   matches the tutorial's four distributions. Because the RECeUS distribution is chosen as the smallest-AIC
   cure model, switching lognormal on can change both the selected model and the RECeUS conclusion. The toggle
   carries that warning; the value used is recorded in `state$include_lognormal` and printed in the report.
8. **`receus.method()`'s `whichTau` defaults to the maximum observed time.** The app does not set `whichTau`.
   Label `tau` "evaluated at the largest observed time" so nobody reads it as a tuning choice. The RECeUS rule
   is π̂ > 0.025 **and** r̂ < 0.05 — both conditions, two ticks.
9. **The `qn` threshold is the one statistic-adjacent value the app may compute.** `qn.test()` returns only
   `method`, `statistic` and `interpretation`; the threshold `1 - 0.05^(1/n)` sits inside the interpretation
   text, not in a field. The app may render it via `helpers.R::qn_threshold(n) <- 1 - 0.05^(1/n)` because it is
   a closed form in the sample size alone, provided Geethanjalee signs it off in `G-03` and `B-06` checks it
   against the number inside the package's own string. Mind the direction — for `qn`, **larger is better**, the
   opposite of Maller–Zhou and Shen.
10. **Descriptive data counts are the other permitted computation:** n, events, censored %, median follow-up,
    max follow-up (§4.1). Nothing inferential joins that list.
11. **Wrap the assessment call in `tryCatch`.** `cure.appropriateness(run_tests = "yes")` can throw when the
    maximum-likelihood fit behind RECeUS fails and returns `NA` estimates, because the decision branch then
    tests a missing value. Treat it as an expected failure mode with a friendly message (§4.2).
12. **`prepare.surv.data()` keeps the original columns and adds `Y` and `D`.** Pass `time_scale = "none"` to
    `cure.appropriateness()` when handing it an already-prepared frame, or the division by 365.25 happens twice.

---

## 6. Performance

A full `cure.appropriateness()` run — Stage 1 plus all five Stage 2 diagnostics — was measured at **0.1 to 0.2
seconds** on datasets up to **n = 1404** (reference runs of 2026-09-15, R 4.6.1, `cureAssess` 0.1.0, `flexsurv`
2.3.2, `flexsurvcure` 1.3.3). The Models tab makes two such calls, so budget a few tenths of a second.

- **No async machinery.** No `future`, no `promises`, no `shiny::ExtendedTask`, no `callr`. At this cost they
  buy nothing and add a failure surface, a second mental model, and debugging that does not fit in a 16.5-hour
  event.
- **Still use an explicit action button.** `input$run` gates every fit — not because fitting is slow, but
  because the user should decide when a model is fitted. A table that silently re-ranks itself while someone is
  reading it is worse than a button.
- **Wrap the Run handler in `withProgress`** with two named steps ("Fitting candidate models", "Running
  diagnostics"), so the user gets feedback instead of a frozen tab.
- **Cache nothing.** Re-running on the same inputs is cheap, and a cache is a way to show a stale number.

An upload large enough to make this feel slow is a line for `docs/handoff.md` (`D-08`), not a reason to add
async before the Definition of Done is met.

---

## 7. The report

**File** `report/report.Rmd`, owner Rachael (`B-07`), rendered by Rashid's `downloadHandler` (`A-09`). Output:
self-contained HTML (`html_document`, `self_contained: true`) so it can be emailed and opened offline.

**Params**, declared in the YAML header with safe defaults so the Rmd also knits by hand: `label`
(`state$label`), `source` (`state$source`), `map` (`state$map` — time column, status column, event level, time
scale), `prepared` (`state$prepared`), `fit` (`state$fit`), `assess` (`state$assess`), `include_lognormal`
(`state$include_lognormal`), `expert_confirmed` (`state$expert_confirmed`).

**Sections** in order: dataset label and provenance (built-in or uploaded, plus the mapping choices); data
summary (the same six numbers as the Data tab); KM plot with risk table; the AIC table including the `error`
column and the candidate set actually used; the five diagnostics with statistic, threshold, chip and
`interpretation`, including any not-computable cards with their full explanation; the three-step verdict with
expert judgment shown as confirmed or still open; the "diagnostics can disagree" text; `tests_reason` and
`final_recommendation` verbatim; the four key references and how to cite; `sessionInfo()`.

The report recomputes nothing — it receives finished objects and prints their fields, so screen and report
cannot drift.

**Render call.** Copy the Rmd to a temporary directory and give `rmarkdown::render()` a temp input and an
`intermediates_dir`, so nothing is written beside the app and the render works where the app directory is
read-only or the working directory is not writable:

```r
output$download_report <- downloadHandler(
  filename = function() paste0("cureAssess-report-", Sys.Date(), ".html"),
  content = function(file) {
    td  <- tempfile("report"); dir.create(td)
    rmd <- file.path(td, "report.Rmd")
    file.copy("report/report.Rmd", rmd, overwrite = TRUE)
    withProgress(message = "Building the report", {
      rmarkdown::render(
        input = rmd, output_file = file,
        intermediates_dir = td, knit_root_dir = td,
        params = list(
          label = state$label, source = state$source, map = state$map,
          prepared = state$prepared, fit = state$fit, assess = state$assess,
          include_lognormal = state$include_lognormal,
          expert_confirmed  = state$expert_confirmed
        ),
        envir = new.env(parent = globalenv()), quiet = TRUE
      )
    })
  }
)
```

Wrap the render in `tryCatch` and surface failures per §4.4. Acceptance (Definition of Done item 4): the file
downloads and contains the KM plot, the AIC table, all five diagnostics, the verdict, and session info.

---

## 8. Accessibility and demo readiness

The app is driven on a projector for the 3-minute lightning session and on a laptop at a booth for two hours.
Build for that from the start; it is cheaper than a Friday retrofit.

1. **Readable from three metres.** Base font >= 16 px, card headings >= 20 px, the headline statistic in each
   diagnostic card >= 24 px and bold. No dense multi-column text; the AIC table shows 10 rows without scrolling.
2. **Colour is never the only signal.** Every chip carries a word — "Follow-up looks sufficient", "Not
   sufficient", "Cannot be computed", "Descriptive, not a test" — and a glyph (check, cross, dash); the badge
   carries the word `cure` or `non-cure`. Anyone who cannot distinguish the colours, and any grayscale
   screenshot in the slides, must still read correctly.
3. **Something real on screen at launch.** The app opens on the Data tab with `gbsg` preselected and already
   prepared, so the summary card and KM plot are visible in the first second — no blank panels, no "please
   select a dataset" as the first impression. The Models tab still waits for Run.
4. **Contrast and focus.** Text meets WCAG AA contrast in the `bslib` theme chosen in `A-01`; every control is
   keyboard reachable with a visible focus ring; Run and Prepare are the most prominent controls on their tabs.
5. **Tooltips wherever a statistic appears** (`A-10`), copy from `G-02`/`G-03`, so a judge can hover any number
   and learn what it is without the presenter speaking.
6. **Offline fallback.** Screenshots and a screen-capture GIF are committed Friday morning (`D-04`), so the
   layout must look correct at a fixed 1440 px width — that is what gets captured.

---

## 9. Out of scope for this build

Not built, and the app must not imply otherwise. Each is a line in `docs/handoff.md` (`D-08`), not a gap to
fill quietly during the event.

| Out of scope | Why, and where it goes |
| --- | --- |
| Covariates / regression models | The assessment is unadjusted, one group, no covariates. No covariate selector; the About tab says so. |
| Treatment-arm comparison, side by side | **The published methods assess one group at a time.** A two-arm view would invite a comparison the statistics do not support. Recorded as stretch goal **S-3** with that caveat attached; not started before the Definition of Done is signed off. |
| Non-mixture cure models | The package fits mixture cure models, `S(t) = (1 − p) + p · Su(t)`. Non-mixture formulations are a different model family. |
| Changing, tuning or re-deriving any package statistic | No alternative thresholds, no composite score, no re-weighted verdict, no bootstrap. A statistic that looks wrong is a `cureAssess` issue for Geethanjalee, not an app change. |
| Authentication, accounts, saved sessions | Local `shiny::runApp()`, single user, no public hosting, no login, no server-side storage. Public and simulated data only, so there is nothing to protect behind a login. |
| Deployment to Posit Connect / shinyapps.io | Documented next step (**S-5**), not a goal of this build. |

Stretch goals stay parked until the Definition of Done is met, then are worked in order — **S-1**, the
follow-up truncation slider, first: it re-runs the whole assessment on truncated follow-up and shows the verdict
flip from appropriate to insufficient follow-up live, at roughly 0.2 s per run. Feature freeze is Thursday 17:00
(`T-08`, the lead's call); code lock is Friday 2:45 pm (`T-09`).
