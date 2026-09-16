# cureAssessApp — KIDS26 Team 9

**cureAssessApp** is a guided, point-and-click [Shiny](https://shiny.posit.co/) front end for the
`cureAssess` R package. Deciding whether a *cure model* is appropriate for a survival dataset
currently requires writing R code and knowing the cure-model literature, and that gate keeps the
method away from the clinicians and analysts who need it. The app wraps the published,
peer-review-backed `cureAssess` workflow so that a non-statistician can go from "here is my dataset"
to a plain-language verdict plus a downloadable HTML report — without writing a line of R. This
repository holds the plan, and will hold the example data, the verification oracle and the app
itself as the event produces them. **The app does not exist yet; everything in `app/` is to be built
during the event.**

Built at the **St. Jude BioHackathon 2026**, Wednesday 16 – Friday 18 September 2026.

> **Team leads:** start with the [team lead checklist](project-management/CHECKLIST.md).

## Project Profile

| Field | Detail |
| --- | --- |
| **Project name** | cureAssessApp — an interactive Shiny front end for the `cureAssess` R package |
| **Question / problem** | Assessing cure-model appropriateness requires R code and literature knowledge. Non-statisticians cannot run the check, so it often gets skipped — and a cure model fitted without it can be badly wrong. |
| **Data and inputs** | Public + simulated data only. Three built-in examples (`nwtco` high risk, `gbsg`, `colon` recurrence `Lev+5FU` arm) curated to `data/examples/`; four simulated scenarios from the scenario matrix; plus any CSV the user uploads at run time. |
| **Expected output** | By Friday 3:00 pm: a locally-run Shiny app, example data, a downloadable HTML report, a user guide, and a rehearsed demo. |
| **Tools and stack** | R (>= 4.1; the VM has 4.6.1), `shiny`, `bslib`, `DT`, `rmarkdown`. Package dependencies: `survival`, `flexsurv`, `flexsurvcure`, `survminer`, `ggplot2`, `dplyr`. |
| **Deployment** | **Local only** — `shiny::runApp()` on the hackathon VM / RStudio. No public hosting. Deploying to Posit Connect or shinyapps.io is a documented next step, not a goal. |
| **Team lead** | Durbadal Ghosh ([@Durbadal0](https://github.com/Durbadal0)) |
| **Team members and roles** | [project-management/team.md](project-management/team.md) |
| **Communication** | Slack: [team channel to confirm] · General event channel: <https://stjudebiohackathon.slack.com/archives/C04JD4M3TCM> |

## Vision and Mission

**Vision.** A cure model should be chosen because the data support it, not because it fits better on
one number. We want the appropriateness check — expert judgment, visual assessment, quantitative
diagnostics — to be a two-minute step that any analyst or clinician can run and understand, so that
long-term-survivorship analyses of paediatric and adult cancer data rest on an assumption that has
actually been tested.

**Mission.** In three days, build a local Shiny app that drives the existing `cureAssess` workflow
end to end: load or upload a dataset, map its columns, see the Kaplan-Meier curve and the AIC
comparison, see all five follow-up diagnostics with plain-language interpretation, and get a verdict
plus a report. We add no new statistics. Every number the app prints must match the package exactly,
verified against a reference oracle on seven datasets.

## About — why this matters

Ordinary survival analysis assumes everyone eventually has the event. Modern therapy broke that
assumption: some patients are effectively cured and never relapse. A **mixture cure model** splits
the population in two, `S(t) = (1 − p) + p · Su(t)`, where `(1 − p)` is the **cure fraction** and
`Su(t)` is survival among the uncured. On a Kaplan-Meier curve, a cure fraction looks like a plateau
that flattens out above zero.

That model carries two extra assumptions: a genuinely non-zero cured fraction exists, and follow-up
runs long enough to *identify* it (formally, `τ_F0 ≤ τ_G` — follow-up must extend past the time by
which all susceptible patients would have had the event). If the second fails, late censored
patients could be cured or uncured-and-not-yet-relapsed, and the two are observationally
indistinguishable. Othus et al. re-analysed six SWOG trials at two follow-up times and found
cure-model estimates of mean survival shifted materially — and the direction of the shift was not
predictable, so it cannot be corrected after the fact.

**A plateau is not proof.** Heavy censoring alone manufactures a plateau that is a censoring
artifact, not cure. That is exactly what the diagnostics are for. The manuscript's three-step check
is ① expert judgment, ② visual assessment, ③ quantitative assessment; failing any step means a cure
model is inappropriate. `cureAssess` automates ② and ③. Step ① is a conversation with a clinician,
so the app must present it as something the *user* confirms, never something the software decides.

## What the app will do

Five tabs, in the order a user should walk them:

1. **Data** — pick a built-in example or upload a CSV, map the time and status columns (including
   which level means "event") and the time scale, then see a summary card (n, events, censored %,
   median and max follow-up), a preview table, and the Kaplan-Meier curve with a risk table.
2. **Models** — run `model.fitting()` and show the AIC ranking of matched cure and non-cure models
   as a sortable table with a cure / non-cure badge, a best-model callout, an opt-in lognormal
   toggle, and the `error` column when a fit fails.
3. **Diagnostics** — five cards: Maller-Zhou (1994), `qn`, Shen (2000), the immune summary, and
   RECeUS. Each shows its statistic, threshold, a pass/fail chip and the package's own
   interpretation string — and an explicit "cannot be computed" state with the reason when the
   statistic is `NA`.
4. **Verdict** — the three-step status strip (expert judgment → visual assessment → quantitative
   assessment), the plain-language recommendation, an honest panel on what to do when the
   diagnostics disagree, and a download button for the HTML report.
5. **About** — what the tool does and does not claim, the key references, and how to cite the
   package.

## Repository layout

```text
KIDS26-Team9/
├── README.md                  (exists — this file)
├── LICENSE.md                 (exists — MIT)
├── app/                       (TO BUILD — the Shiny app; A-01 onward)
│   ├── app.R                  (TO BUILD — bslib navbar page, five tabs)
│   └── R/mod_*.R              (TO BUILD — one Shiny module per tab, one owner per file)
├── app-scaffold/              (exists — app.R, the scaffold app run during the smoke test; T-03)
├── cureAssess/                (VENDORED — upstream package copy; do not edit, fix upstream)
│   ├── R/                     (package source — read this when you need exact behaviour)
│   └── cureAssess_0.1.0.tar.gz
├── data/examples/             (TO BUILD — three curated CSVs + provenance README; B-02)
├── docs/                      (exists — event guidance; team adds data-contract.md,
│                               user-guide.md, handoff.md)
├── project-management/        (exists — team.md, project-plan.md, CHECKLIST.md,
│                               decisions.md to be added)
├── report/                    (TO BUILD — report.Rmd, the parameterised HTML report; B-07)
├── scripts/                   (exists — smoke_test.R, run during onboarding; T-03)
└── tests/reference/           (TO BUILD — the reference oracle: AIC tables, all five
                                diagnostics and verdicts the app must reproduce; G-01)
```

`cureAssess/` is an upstream copy, not team-authored code. Treat it as read-only: if something in
the package needs to change, raise it with Geethanjalee and fix it upstream.

## Getting started

Target: clone to running app in under 10 minutes on the hackathon VM.

```bash
git clone https://github.com/stjude-biohackathon/KIDS26-Team9.git
cd KIDS26-Team9
```

```r
# 1. R >= 4.1 is required. The hackathon VM has 4.6.1.
R.version.string

# 2. App and package dependencies.
install.packages(c(
  "shiny", "bslib", "DT", "rmarkdown",
  "survival", "flexsurv", "flexsurvcure", "survminer", "ggplot2", "dplyr"
))

# 3. Install the vendored cureAssess package (version 0.1.0).
install.packages("cureAssess/cureAssess_0.1.0.tar.gz", repos = NULL, type = "source")
# ...or, for development without installing:
# devtools::load_all("cureAssess")

# 4. Environment smoke test — a go/no-go in about two minutes.
source("scripts/smoke_test.R")
shiny::runApp("app-scaffold")

# 5. Run the app.
shiny::runApp("app")
```

Step 4 runs from the start: `scripts/smoke_test.R` and the scaffold app are already in the
repository, and the Wednesday onboarding block (T-03) is where everyone runs them. Step 5 depends on
`app/`, which the team creates in the first build block (A-01); until then, steps 1-4 will run. If
install fails on the VM, running locally in RStudio is an accepted fallback —
escalate to the organisers rather than losing the block.

## Roadmap and milestones

| Day | Blocks | Focus | Exit criteria |
| --- | --- | --- | --- |
| **Day 1** — Wed 16 Sep | W1 10:30-12:00 (onboarding only), W2 1:00-3:00, W3 3:20-5:00 | Everyone has VM, GitHub and dependency access and has pushed a trivial commit; 20-minute package walkthrough; app skeleton with all five tabs; Data tab v1 with the built-in dataset picker; data contract; three curated examples; the reference oracle | Stage 1 runs end to end for a built-in dataset: `shiny::runApp("app")` opens with zero console errors, all five tabs navigate, and the Data tab shows a summary and a KM plot. CSV upload with column mapping works. The oracle is committed to `tests/reference/`. Standup 4:45-5:00 and **everything pushed** |
| **Day 2** — Thu 17 Sep | T1 9:30-10:30, T2 10:50-12:00, flex 1:00-2:00, T3 1:00-3:00, T4 3:20-5:00 | Models / AIC tab with fitted-curve overlay; Diagnostics tab with all five cards and the `NA` state; Verdict tab and the parameterised report; simulated scenario datasets; integration, report download, full regression | The Definition of Done is met one day early: from a clean clone the app launches, all three built-in examples plus an uploaded CSV each produce a summary, KM plot, AIC table, five diagnostics and a verdict, every printed number matches the oracle across all seven datasets, and the HTML report downloads complete. **17:00 = feature freeze** (lead's call); only bug fixes after this |
| **Day 3** — Fri 18 Sep | F1 9:30-10:30 (bug bash), F2 10:50-12:00, F3 1:00-2:00, F4 2:00-2:45 | Triage Thursday's issues by severity, no new features without written approval; final README, user guide, in-app help polish, clean-clone re-test, screenshots and a fallback GIF; demo build with two timed dry runs on the real machine; tag and handoff | Issue list worked down; docs complete; the 3-minute lightning deck and the 5-minute booth script each rehearsed twice on the actual demo machine with a screenshot fallback committed; `v1.0` tagged and `docs/handoff.md` written. **2:45 = code lock** |

Friday exists for troubleshooting, docs and rehearsal — not for building. Deliberate slack: the
Thursday flex hour, all of F1, and a Definition of Done targeted a full day before judging.

The goal is not a perfect production system. It is a clear, honest, useful result the team can
explain and others can build on.

## About the `cureAssess` package

`cureAssess` 0.1.0 — *Assessing Cure Model Appropriateness for Survival Data*. Author, maintainer
and copyright holder: **Geethanjalee Mudunkotuwa**. Author: **Durbadal Ghosh**. MIT licensed.
Upstream: <https://github.com/GeethanjaleeM/cureAssess>.

The package implements a two-stage workflow — AIC screening of matched cure and non-cure parametric
models, then formal diagnostics for sufficient follow-up and for a cured fraction — behind a single
wrapper, `cure.appropriateness()`. The app calls that wrapper and re-implements nothing.
Geethanjalee is the authority on package behaviour and owns every word of statistical interpretation
the app prints.

A companion tutorial manuscript, *"A Tutorial for Evaluating Cure Model Appropriateness"*
(Mudunkotuwa, Ghosh, Triplett, Selukar), is in preparation; the app operationalises its Figure 1
workflow. The manuscript is **not** in this repository.

## References

- Maller RA, Zhou S (1992). *Estimating the proportion of immunes in a censored sample.*
  Biometrika, 79(4), 731-739. [doi:10.1093/biomet/79.4.731](https://doi.org/10.1093/biomet/79.4.731)
- Maller RA, Zhou S (1994). *Testing for sufficient follow-up and outliers in survival data.*
  Journal of the American Statistical Association, 89(428), 1499-1506.
  [doi:10.1080/01621459.1994.10476889](https://doi.org/10.1080/01621459.1994.10476889)
- Shen P-S (2000). *Testing for sufficient follow-up in survival data.* Statistics & Probability
  Letters, 49(4), 313-322.
  [doi:10.1016/S0167-7152(00)00063-8](https://doi.org/10.1016/S0167-7152(00)00063-8)
- Selukar S, Othus M (2023). *RECeUS: Ratio estimation of censored uncured subjects, a different
  approach for assessing cure model appropriateness in studies with long-term survivors.*
  Statistics in Medicine, 42(3), 209-227. [doi:10.1002/sim.9610](https://doi.org/10.1002/sim.9610)

## Data and ethics note

**Public and simulated data only.** Nothing restricted, nothing identifiable, and nothing from St.
Jude clinical datasets enters this repository or appears on screen during the demo. The built-in
examples come from public R packages and ship with their provenance and licence recorded in
`data/examples/README.md`; the simulated datasets are generated by committed code with a fixed seed.
Never commit credentials, and never commit data that is not public. Datasets a user uploads while
running the app locally stay on that machine — the app does not transmit or store them.
