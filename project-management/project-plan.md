# Project Plan — cureAssessApp

**Team:** KIDS26 Team 9 · **Repo:** `stjude-biohackathon/KIDS26-Team9` (branch `main`)
**Event:** St. Jude BioHackathon 2026, Wed 16 – Fri 18 September 2026
**Team lead:** Durbadal Ghosh (`@Durbadal0`) · **Science lead:** Geethanjalee Mudunkotuwa (`@GeethanjaleeM`)

Nothing in this plan has been built yet. The Shiny app described here does not exist; every section
below is a commitment, not a status report.

---

## 1. Goal

By **Friday 3:00 pm** (the Demo Lightning Session, MTC Room 2 IA 1405) the team will have built and
rehearsed **cureAssessApp**: an interactive Shiny front end for the `cureAssess` R package that walks
a non-statistician from "here is my survival dataset" to a plain-language verdict on whether a cure
model is appropriate, plus a downloadable HTML report.

Concretely, at 3:00 pm Friday we will be able to show, on the demo machine, from a clean clone:

- `shiny::runApp("app")` launching with no errors on the hackathon VM.
- Five tabs — **Data**, **Models**, **Diagnostics**, **Verdict**, **About** — working end to end for
  the three built-in examples and for a CSV the judges hand us.
- The three-step manuscript Figure 1 workflow on screen: **Expert judgment → Visual assessment →
  Quantitative assessment**, with step ① presented as something the *user* confirms, not something the
  software decides.
- Every number the app prints matching Geethanjalee's reference oracle across all seven datasets
  (3 real + 4 simulated).
- A downloadable HTML report containing the data summary, KM plot, AIC table, all five diagnostics,
  the verdict, session info and citations.
- A rehearsed 3-minute lightning pitch and 5-minute booth walkthrough, with screenshots and a
  screen-capture GIF committed as an offline fallback.

The headline demo is the **`gbsg`** dataset: AIC selects a *cure* model (`loglogistic_cure`,
AIC 1719.70), so a naive analyst would stop and fit one — but r̂ = 0.3080 means the cure fraction
cannot be identified, and the verdict is **"Follow-up insufficient for cure modeling."** That gap is
the reason the tool exists.

## 2. Why this project

The method already exists and is published: `cureAssess` implements a peer-review-backed workflow for
deciding whether a cure model is appropriate, and the accompanying tutorial manuscript lays out the
three-step check. But running it today means writing R code and knowing the cure-model literature well
enough to read the output. That gate keeps the decision away from the clinicians and analysts who
actually have the data and actually have to make it.

## 3. Scope

| In scope | Out of scope (explicitly) |
| --- | --- |
| A locally-run Shiny app (`shiny::runApp("app")`) on the hackathon VM / RStudio | **Public hosting or deployment** of any kind — Posit Connect, shinyapps.io, Docker, a URL anyone outside the room can open. Deployment is a documented next step (S-5), not a goal. |
| Wrapping the existing exported `cureAssess` API: `prepare.surv.data()`, `model.fitting()`, `run.cure.tests()`, the five diagnostics, `receus.method()`, `cure.appropriateness()` | **Changing the `cureAssess` package's statistics.** No new estimators, no altered thresholds, no re-derived formulas. If the package's answer looks wrong, that is a conversation with Geethanjalee and a GitHub issue, not a patch. |
| Public + simulated data only: `nwtco` (High risk, stage 3–4), `gbsg`, `colon` (recurrence, `Lev+5FU`), plus the four simulated scenarios A–D | **Restricted or St. Jude clinical data.** No SWOG S1203 data, no BMTCT datasets, nothing identifiable, nothing restricted enters this repo or appears on screen at any point, including during the demo. |
| **Assessing appropriateness** — the app answers "should you fit a cure model on this data?" | **Fitting the final analysis cure model itself.** The app does not produce the downstream cure-model analysis, estimates for publication, treatment-effect inference, or predictions. It ends at the verdict and hands off. |
| Single-group assessment, exactly as the published methods define it | **Covariate-adjusted cure models.** No covariate effects on the cure fraction or on the uncured survival, no regression interface. The published methods assess one group at a time. |
| CSV upload with a column mapper (time column, status column, which level means "event", `days_to_years` scale) | Multi-arm / group-by side-by-side comparison (stretch S-3 only) |
| Parameterised `rmarkdown` HTML report via `downloadHandler` | PDF report output (stretch S-4 only) |
| In-app help for every statistic shown, and an About tab with citations | Any authentication, user accounts, saved sessions, or a database |

## 4. Tools and stack

| Layer | Choice |
| --- | --- |
| Language | R (>= 4.1; the VM has 4.6.1) |
| App framework | `shiny`, `bslib` (navbar page), `DT` (sortable AIC table) |
| Reporting | `rmarkdown` (parameterised HTML report at `report/report.Rmd`) |
| Statistics | `cureAssess` 0.1.0, vendored into this repo at `cureAssess/` (upstream `https://github.com/GeethanjaleeM/cureAssess`, MIT) |
| Package dependencies | `survival`, `flexsurv`, `flexsurvcure`, `survminer`, `ggplot2`, `dplyr` |
| Verified reference environment | R 4.6.1, `cureAssess` 0.1.0, `flexsurv` 2.3.2, `flexsurvcure` 1.3.3 |
| Where it runs | Locally on the hackathon VM / RStudio. **No public hosting.** |
| Source control | Git + GitHub, `stjude-biohackathon/KIDS26-Team9`. Branch per task `<initials>/<task-id>-<short-slug>`; one PR per task, title starts with the task ID; Sharon merges to `main`. |
| Code layout | Shiny modules in separate files, `app/R/mod_*.R`, **one owner per module file** (this is the merge-conflict mitigation, not a style preference) |
| Verification | `tests/reference/` oracle committed by Geethanjalee (G-01); `scripts/smoke_test.R` for the environment go/no-go |
| AI coding agents | Whatever the event provides (confirmed in T-04). Human-reviewed before merge like any other contribution. |

## 5. First tasks

### W1 — Wed 10:30–12:00 · onboarding only, no feature work

- [ ] **T-01** Confirm VM access and that RStudio opens. *Owner: all. Backup: Durbadal escalates to organisers.* Done when every person has RStudio open on the VM.
- [ ] **T-02** Confirm GitHub access to `stjude-biohackathon/KIDS26-Team9`; clone; each person pushes one trivial commit (add yourself to `team.md`). *Owner: all.* Done when five commits from five authors are on `main`, proving write access.
- [ ] **T-03** Install dependencies and run the environment smoke test (`scripts/smoke_test.R`, then `shiny::runApp("app-scaffold")`). *Owner: all. Backup: Sharon.* Done when the smoke test passes and the scaffold app opens for everyone.
- [ ] **T-04** Confirm access to the AI coding agents available at the event (for example Copilot). *Owner: all.*
- [ ] **T-05** 20-minute walkthrough: what a cure model is, what `cureAssess` does, what the app must reproduce. Uses the onboarding deck. *Owner: Geethanjalee.* Done when the three non-experts can each say, in one sentence, what "sufficient follow-up" means and why a plateau is not proof.
- [ ] **T-06** Confirm pods, roles, comms channel, branch + PR convention, block-end push rule, and the Definition of Done. **Collect Rashid's GitHub handle.** *Owner: Durbadal.* Done when the handle is in `team.md` and the pod assignment is either confirmed or swapped on the record.

### W2 — Wed 1:00–3:00 · app skeleton + data foundations

- [ ] **A-01** App skeleton: `app/` directory, `bslib` navbar page, five tabs — **Data**, **Models**, **Diagnostics**, **Verdict**, **About**. *Owner: Sharon. Backup: Rashid.* **Acceptance:** `shiny::runApp("app")` opens, all tabs navigate, zero console errors.
- [ ] **A-02** Data tab v1: built-in dataset picker → `prepare.surv.data()` → summary card (n, events, censored %, median follow-up, max follow-up) + `head()` table. *Owner: Rashid. Backup: Sharon.* **Acceptance:** "nwtco — High risk" shows n = 1404.
- [ ] **B-01** Write the **data contract** (`docs/data-contract.md`): required columns, event coding (0/1 required by the package; must remap 1/2 and TRUE/FALSE), time units, missing-value policy, minimum n, and every error `.check_surv_data()` can raise. *Owner: Rachael. Backup: Geethanjalee.* **Acceptance:** the file lists each raisable error verbatim alongside the friendly message the app will show instead.
- [ ] **B-02** Curate the three built-in examples to `data/examples/` as CSV + `README.md` with provenance and licence: (1) `nwtco_high_risk` (stage 3–4), (2) `gbsg`, (3) `colon_lev5fu` (recurrence, `etype == 1`, `rx == "Lev+5FU"`). *Owner: Rachael. Backup: Geethanjalee.* **Acceptance:** row counts are 1404, 686 and 304 respectively.
- [ ] **G-01** Build the **reference oracle**: run `cure.appropriateness(..., run_tests = "yes")` on all three examples in plain R and commit `tests/reference/` (AIC table + all five diagnostics + verdict). *Owner: Geethanjalee.* **Acceptance:** the committed values match the verified reference numbers in this plan exactly; these are what the app must reproduce.

## 6. Milestones

Total hack time is **16.5 h**. Subtract the 1.5 h Wednesday onboarding block and **~15 h of build time**
remain. Breaks are hard stops — work stops, we walk away, we come back. Blocks are named W1–W3, T1–T4,
F1–F4 and those names are used in every issue, PR and standup.

### Day 1 — Wednesday 16 September (5.5 h hack)

| Block | Time | Focus |
| --- | --- | --- |
| — | 8:30–9:30 | Breakfast & check-in (MTC Atrium) |
| — | 9:30–10:30 | Welcome (MTC Board Room IA 1500) |
| **W1** | **10:30–12:00 (1.5 h)** | **Onboarding only — no feature work.** VM access, GitHub access, R + dependency install, smoke test, AI-agent access, 20-min package walkthrough, role/convention confirmation. |
| — | 12:00–1:00 | Lunch |
| **W2** | **1:00–3:00 (2 h)** | App skeleton + data foundations |
| — | 3:00–3:20 | PM break (ARC Lobby) — hard stop |
| **W3** | **3:20–5:00 (1 h 40)** | Wire Stage 1 end to end. **4:45–5:00 standup + push everything.** |
| — | 5:30–7:00 | Reception (ARC Lobby) — optional, no work |

**W3 tasks:** **A-03** CSV upload + column mapper (time column, status column, which level means
"event", time scale `none` / `days_to_years`), surfacing `.check_surv_data()` failures as friendly
messages and never a red Shiny crash — *acceptance: uploading `gbsg.csv` reproduces the built-in gbsg
path exactly* (Sharon, backup Rashid) · **A-04** KM plot on the Data tab with risk table (Rashid,
backup Sharon) · **B-03** implement `simulate_cure_data()` and the four-scenario matrix (Rachael,
backup Geethanjalee) · **B-04** verification pass #1, Stage-1 numbers, app vs oracle, three datasets,
one GitHub issue per mismatch (Rachael) · **T-07** 4:45–5:00 standup, everyone pushes, Durbadal records
decisions in `decisions.md`.

**Wednesday exit criteria (5:00 pm):**

1. Everyone has VM access, repo write access, dependencies installed, and a passing smoke test.
2. `shiny::runApp("app")` opens a five-tab skeleton with zero console errors.
3. The Data tab loads all three built-in examples and shows n = 1404 for nwtco High risk.
4. CSV upload of `gbsg.csv` reproduces the built-in gbsg path exactly.
5. A KM plot with a risk table renders on the Data tab.
6. `docs/data-contract.md`, `data/examples/` (3 CSVs + provenance README), `tests/reference/` (the
   oracle) and the four-scenario simulation code are all committed.
7. Verification pass #1 is run and every mismatch is a filed GitHub issue.
8. Rashid's GitHub handle, the comms channel, the pod assignment and the Definition of Done are
   confirmed in writing. Everything is pushed.

### Day 2 — Thursday 17 September (6.5 h hack) — the Definition of Done lands here

| Block | Time | Focus |
| --- | --- | --- |
| — | 8:30–9:30 | Breakfast & check-in (ARC Lobby) |
| **T1** | **9:30–10:30 (1 h)** | Models / AIC tab |
| — | 10:30–10:50 | AM break — hard stop |
| **T2** | **10:50–12:00 (1 h 10)** | Diagnostics tab |
| — | 12:00–1:00 | Lunch (ARC Lobby) |
| **FLEX** | **1:00–2:00** | **Campus tours / designated flex + absence hour.** Optional. Anyone who skips the tour starts T3 early. Nothing on the critical path may be scheduled here. |
| **T3** | **1:00–3:00 (up to 2 h)** | Verdict tab + report engine |
| — | 3:00–3:20 | PM break — hard stop |
| **T4** | **3:20–5:00 (1 h 40)** | Integration, report download, full regression. **17:00 = FEATURE FREEZE (lead's call).** 4:45–5:00 standup. |

**T1 tasks:** **A-05** Models tab — `model.fitting()` → sortable `DT` AIC table with a cure / non-cure
badge, best-model callout, `include_lognormal` toggle, explicit **Run** button, and the `error` column
shown when a fit fails (Sharon, backup Rashid) · **A-06** overlay the fitted survival curve for the
selected model on the KM curve (Rashid) · **B-05** commit the four simulated scenario datasets + their
expected verdicts (Rachael) · **G-02** help copy for Stage 1: what AIC is, why "a cure model won on
AIC" is *initial support only* and not proof (Geethanjalee).

**T2 tasks:** **A-07** Diagnostics tab — five cards (Maller–Zhou 1994, `qn`, Shen 2000, Immune summary,
RECeUS), each with statistic, threshold, pass/fail chip and the package's own `interpretation` string,
and **an explanatory "cannot be computed" state when the statistic is `NA`** (Rashid, backup Sharon) ·
**B-06** verification pass #2, AIC tables, app vs oracle, three real + four simulated datasets
(Rachael) · **G-03** help copy for all five diagnostics, two plain-language sentences each
(Geethanjalee).

**T3 tasks:** **A-08** Verdict tab — `cure.appropriateness(run_tests = "yes")` → three-step status
strip mirroring manuscript Figure 1 (**Expert judgment → Visual assessment → Quantitative
assessment**), the plain-language recommendation, and an explicit "the diagnostics can disagree — here
is what to do" panel; default `run_tests = "yes"`, **not** `"auto"`, so users always see the
diagnostics, with the reason stated on screen (Sharon, backup Rashid) · **B-07** `report/report.Rmd`
parameterised HTML report: dataset label, data summary, KM plot, AIC table, five diagnostics, verdict,
session info, citations (Rachael, backup Rashid) · **G-04** verdict copy plus the "follow-up looks
insufficient — what now?" guidance (use a non-cure model; or the extreme-value estimators of
Escobar-Bach & Van Keilegom; or Yuen & Musta's relaxed condition; collect more follow-up)
(Geethanjalee).

**T4 tasks:** **A-09** wire `downloadHandler` to render and download the HTML report (Rashid) ·
**A-10** in-app help — a tooltip/popover on every statistic, About tab with the four key references and
how to cite the package (Sharon) · **B-08** full regression across every tab and all seven datasets,
app vs oracle, sign-off table committed (Rachael + Geethanjalee) · **B-09** clean-clone test, fresh
`git clone` on a machine that has never run the app (Geethanjalee) · **T-08** **17:00 FEATURE FREEZE**,
Durbadal's call — scope closes, only bug fixes after this.

**Thursday exit criteria are the Definition of Done** (section 7 below), signed off at the 4:45 pm
standup. Items 1–7 must hold at 17:00 Thursday. Item 8 — the two rehearsals on the real machine — is
scheduled into Friday F3 by design, because rehearsing before the code is frozen wastes the rehearsal.
Anything in items 1–7 that is not true at 17:00 becomes a GitHub issue with a severity, and Friday F1
exists to work that list.

### Day 3 — Friday 18 September (4.5 h hack, then demos)

| Block | Time | Focus |
| --- | --- | --- |
| — | 8:30–9:00 | Breakfast & check-in (ARC Lobby) |
| — | 9:00–9:30 | Announcements (ARC Lobby) |
| **F1** | **9:30–10:30 (1 h)** | **Bug bash only.** Triage Thursday's issues. No new features without the lead's explicit approval. |
| — | 10:30–10:50 | AM break — hard stop |
| **F2** | **10:50–12:00 (1 h 10)** | Docs, in-app help polish, clean-clone test, screenshots/GIF for slides |
| — | 12:00–1:00 | Lunch |
| **F3** | **1:00–2:00 (1 h)** | Demo build: lightning deck + booth script + **two timed dry runs** on the real machine |
| **F4** | **2:00–2:45 (45 min)** | Tag `v1.0`, handoff doc (limitations + next steps), final commit. **2:45 = CODE LOCK.** |
| — | 2:45–3:00 | Walk to MTC Room 2 (IA 1405) |
| — | 3:00–4:00 | **Demo Lightning Session** (MTC Room 2, IA 1405) |
| — | 4:00–6:00 | **Demos / Judging Reception** (MTC Atrium) — booth rotation, nobody stuck the whole 2 h |
| — | 6:00 | Winners announced & closing remarks (MTC Atrium) |

**F1 tasks:** **A-11 / B-10** work the issue list by severity. No new features without the lead's
written approval in `decisions.md`. *Owners: whole team.*

**F2 tasks:** **D-01** `README.md` final — what it is, install, run in under 10 minutes, screenshot
(Rachael) · **D-02** `docs/user-guide.md`, the guided walkthrough with the gbsg teaching example
(Rachael, backup Geethanjalee) · **D-03** in-app help / label polish pass (Sharon + Rashid) ·
**D-04** screenshots plus a short screen-capture GIF for the slides and as offline demo fallback
(Rashid) · **B-11** clean-clone re-test after all Friday changes (Geethanjalee).

**F3 tasks:** **D-05** lightning deck, **5 slides, 3 minutes** (Durbadal, content from the team) ·
**D-06** booth script, **5 minutes**, plus answers to the six questions judges will ask (Rachael) ·
**D-07** **two timed dry runs** on the actual demo machine with the actual app (whole team).

**F4 tasks:** **D-08** tag `v1.0`, write `docs/handoff.md` with known limitations and next steps, final
push (Sharon) · **T-09** **2:45 CODE LOCK** — laptops closed, walk to MTC Room 2 (IA 1405).

**Friday exit criteria (2:45 pm code lock):**

1. The issue list from Thursday is worked by severity and every remaining open issue is a *known
   limitation* written down in `docs/handoff.md`, not a surprise.
2. `README.md` gets a new user from clone to running app in under 10 minutes, with a screenshot.
3. `docs/user-guide.md` walks the gbsg teaching example start to finish.
4. Screenshots and a screen-capture GIF are committed and openable without the app running.
5. The clean-clone re-test passes *after* all Friday changes.
6. The 5-slide / 3-minute deck and the 5-minute booth script exist, and two timed dry runs have been
   completed on the actual demo machine.
7. `v1.0` is tagged and pushed; `docs/handoff.md` lists limitations and next steps.
8. Demo-day assignments are confirmed: **lightning pitch** — Durbadal presents, Sharon drives the app;
   **booth (4:00–6:00, rotate every 30 min)** — Rachael narrates the 5-minute walkthrough, Sharon
   drives, Geethanjalee fields statistical questions, Rashid owns the backup laptop + screenshot
   fallback, Durbadal floats and closes.

## 7. Definition of Done

**Target Thursday 5:00 pm. Hard deadline Friday 2:45 pm.**

1. From a **clean clone** on the VM, `shiny::runApp("app")` launches with no errors.
2. All three built-in examples **and** a user-uploaded CSV each produce: data summary, KM plot, AIC
   table, all five diagnostics, and a plain-language verdict.
3. **Every number the app prints matches the reference oracle** for all seven datasets (3 real + 4
   simulated).
4. The HTML report downloads and contains the KM plot, AIC table, all five diagnostics, the verdict,
   and session info.
5. In-app help exists for every statistic shown; the About tab cites Maller & Zhou (1992, 1994),
   Shen (2000) and Selukar & Othus (2023), plus how to cite `cureAssess`.
6. `README.md` gets a new user from clone to running app in under 10 minutes.
7. `NA` / failed-fit / bad-upload states all render a helpful message rather than an error.
8. The 3-minute lightning deck and the 5-minute booth script have each been rehearsed **twice** on the
   real machine, with a screenshot fallback committed.

Item 3 is the unusual one and it is not negotiable: a number in the app that disagrees with the oracle
is a **blocking** bug, not a cosmetic one. Item 7 is the one people forget — in simulation scenarios C
and D the Maller–Zhou, `qn` and Shen statistics come back `NA`, because the package can only compute
them when the largest observed time is censored. The Diagnostics tab must say "cannot be computed — the
longest observed time is an event, so there is no plateau to test", not show a blank cell, an `NA`, or a
crash.

## 8. Stretch goals

**These are gated.** No stretch goal is started until the Definition of Done is signed off by the lead.
The Thursday 17:00 feature freeze applies to stretch goals too: a stretch goal not merged before the
freeze does not ship, and Friday F1–F4 are not available for it without Durbadal's written approval in
`decisions.md`. They are written down here precisely so they stay out of scope until then.

Work them in this order:

1. **S-1 — Follow-up truncation slider.** A slider that restricts follow-up to `t` years, re-runs the
   whole assessment, and shows the verdict flip from "appropriate" to "insufficient follow-up" live.
   **Why it is first:** it is the single most persuasive thing the app can do in front of a judge. It
   takes the abstract claim "follow-up length changes the answer" and makes it happen on screen in one
   drag — it recreates Figure 2 of the tutorial manuscript, and it is exactly the lesson simulation
   scenario B teaches (a real cure fraction of 0.40 becomes invisible, π̂ = 0.020, r̂ = 0.9786, when
   follow-up is cut to 1.5). It is also the cheapest of the five: **a full `cure.appropriateness()` run
   takes 0.1–0.2 s**, so the slider can re-run live with no caching tricks, and it reuses the reactive
   chain A-08 already builds — one input, one existing call, no new package functions.
2. **S-2 — Simulation lab panel.** Sliders for cure fraction, follow-up length and censoring rate
   feeding the assessment live. **Why:** turns the app from a checker into a teaching tool, which is a
   second audience for free. **Cost:** moderate — `simulate_cure_data()` already exists from B-03, so
   this is a new panel and a new reactive path rather than new statistics.
3. **S-3 — Multi-arm / group-by comparison, side by side.** **Why:** the first thing a trialist will
   ask for. **Cost:** moderate to high, and it carries a scientific caveat that must be shown on
   screen: the published methods assess one group at a time, so a side-by-side view is two independent
   assessments displayed together, not a joint test.
4. **S-4 — PDF report in addition to HTML.** **Why:** PDF is what gets attached to an email and shown
   to a committee. **Cost:** low to moderate but with the highest risk-to-value ratio of the five,
   because it depends on a LaTeX toolchain being present on the VM — a dependency we have deliberately
   avoided everywhere else.
5. **S-5 — Deploy to Posit Connect / shinyapps.io.** **Why:** removes the install step for real users
   entirely. **Cost:** not a code cost. It is out of scope by decision (section 3), needs approval and
   an account we do not have, and the data policy would have to be re-examined before anything is
   hosted. Documented as a next step in `docs/handoff.md`, not attempted during the event.

## 9. Deliberate slack

Three places in this plan are intentionally empty. They are not spare capacity to be filled in on
Wednesday afternoon when someone feels behind.

| Where | What is protected | Why |
| --- | --- | --- |
| **Thursday 1:00–2:00 FLEX** | Campus tours / designated flex + absence hour. **Nothing on the critical path may be scheduled here.** Anyone who skips the tour starts T3 early. | The lead has flagged that not everyone will be present the whole time. This hour is where an absence, a late arrival or a blown-up morning gets absorbed without touching the Definition of Done. If we schedule work here, an absence becomes slippage instead of a non-event. |
| **Friday F1, 9:30–10:30** | Bug bash only. Triage Thursday's issues by severity. **No new features without the lead's explicit written approval in `decisions.md`.** | Every project of this shape discovers on the last morning that something is broken on a path nobody rehearsed. This hour exists to have somewhere to put that discovery. An hour reserved for bugs we have not found yet is worth more than an hour of features. |
| **The Definition of Done targets Thursday 5:00 pm** | A full day of margin before judging. Friday's hard deadline is 2:45 pm code lock. | Finishing the day before judging is the whole absence-and-risk strategy in one decision. It means Friday is troubleshooting, docs and rehearsal — **not building**. It also means the two timed dry runs in F3 happen against frozen code, so what we rehearse is what the judges see. |

The three structural habits that make the slack usable: every task has a **named backup**, nothing on
the critical path has a single owner, and **everything is pushed at the end of every block** — unpushed
work does not exist, and a teammate who disappears mid-block must not take the work with them.

## 10. Risks and open questions

The full risk register — ten risks with likelihood, mitigation and a named owner — lives in
**`project-management/risks.md`**. Read it before W1 ends. The three rated **High** are worth naming
here because they shape the plan above: a teammate being absent for part of the event (R2, mitigated by
backups + block-end pushes + the Thursday flex hour), merge conflicts from everyone editing one `app.R`
(R4, mitigated by `app/R/mod_*.R` with one owner per module file and Sharon owning merges), and
diagnostics returning `NA` so the UI looks broken (R7, mitigated by specifying the "cannot be computed"
state up front rather than discovering it in testing).

### Open questions — answer these on Day 1

These are genuinely unknown right now. They are not rhetorical, and W1 is where they get closed.

| # | Question | Who answers | Why it matters | Resolve by |
| --- | --- | --- | --- | --- |
| Q1 | **Rashid's GitHub handle** — currently **[to confirm]**. | Rashid, collected by Durbadal in **T-06** | He cannot be added to the repo, assigned issues, or credited until we have it, and he owns six tasks (A-02, A-04, A-06, A-07, A-09, D-04). | W1, Wed 12:00 |
| Q2 | **Which comms channel is the team's** — the Slack channel (or equivalent) is **[to confirm]**. | Durbadal, in **T-06** | Blockers are supposed to be raised immediately, and "immediately" needs a place to go that is not a hallway. Also needed so an absent teammate can be reached mid-block. | W1, Wed 12:00 |
| Q3 | **Who is strongest at Shiny?** The Pod A / Pod B placement of Sharon, Rashid and Rachael is a starting guess made with no knowledge of their individual skills. | Sharon, Rashid, Rachael — self-declared at the Day-1 standup; Durbadal makes the call | This determines the pod swap. Pod A carries the Shiny-heavy tasks (A-01 through A-11); putting the strongest Shiny hand outside it is a self-inflicted bottleneck. **Swap freely at the Day-1 standup.** | W1, Wed 12:00 |
| Q4 | **Does anyone have known absences** — tours, meetings, travel, partial days? | Everyone, asked directly by Durbadal in **T-06** | Absence tolerance is a hard requirement. Known absences can be routed around by scheduling that person's tasks away from their gap and by pre-briefing their backup; unknown ones cannot. | W1, Wed 12:00 |
| Q5 | **Is Pod A starved of statistical support?** Geethanjalee is counted in Pod B because verification is where statistical judgement is needed most, with roughly half her time reserved for answering Pod A. | Durbadal, re-checked at the Day-1 standup and every standup after | With four pairs of hands this is the honest reading of "the expert oversees both groups", but it is a guess about where the questions will come from. If Pod A is waiting on her, re-balance. | Reviewed at every standup |

Standups are **Wed 4:45 pm, Thu 9:30 am, Thu 4:45 pm, Fri 9:30 am** — ten minutes, standing up.
Blockers go in a GitHub issue immediately and get said out loud at the next standup. Decisions that
change the approach go in `project-management/decisions.md` with date, decision, and why.
