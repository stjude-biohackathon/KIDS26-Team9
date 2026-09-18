# CureCheck: An R Shiny Application for Evaluating Cure Model Appropriateness — KIDS26 Team 9

**CureCheck** is a guided, point-and-click [Shiny](https://shiny.posit.co/) app for running the
`cureAssess` R package. Deciding whether a *cure model* is appropriate for a survival dataset
currently requires writing R code and knowing the cure-model literature, and that gate keeps the
method away from the clinicians and analysts who need it. The app wraps the published,
peer-review-backed `cureAssess` workflow so that a non-statistician can go from "here is my dataset"
to a plain-language verdict plus a downloadable HTML report — without writing a line of R. This
repository contains code for a functional app prototype created during the **St. Jude BioHackathon 2026**, Wednesday 16 – Friday 18 September 2026.

Under construction: adding a guided manual walking through using the Shiny app.

## Project Profile

| Field | Detail |
| --- | --- |
| **Project name** | CureCheck — an interactive Shiny app for the `cureAssess` R package |
| **Question / problem** | To make checking cure model appropriateness easily accessible. Checking that a cure model is appropriate is an important step to ensure that the model used is valid for exploration and inference.  |
| **Data and inputs** |  CSV format with columns for time and event status.  |
| **App capabilities** | The app allows users to explore qualitative and quantitative metrics to asses cure model appropriateness, using published literature and methods. |
| **Expected package dependencies** |  `shiny`, `bslib`, `DT`, `rmarkdown`, `survival`, `flexsurv`, `flexsurvcure`, `survminer`, `ggplot2`, `dplyr`. |
| **Current deployment** | **Local only** — `shiny::runApp()` R/RStudio. A future improvement is to create a publicly available web app. |
| **Team lead** | Durbadal Ghosh, PhD ([@Durbadal0](https://github.com/Durbadal0)) |
| **Team members** | Geethanjalee Mudunkotuwa, PhD ([@GeethanjaleeM](https://github.com/GeethanjaleeM)); Sharon Freshour, PhD; Rashid Mehmood, PhD |

## Why cure model appropriateness matters

Ordinary survival analysis assumes everyone eventually has the event. Modern therapy broke that
assumption: some patients are effectively cured and never relapse. A **mixture cure model** splits
the population in two, `S(t) = (1 − p) + p · Su(t)`, where `(1 − p)` is the **cure fraction** and
`Su(t)` is survival among the uncured. On a Kaplan-Meier curve, a cure fraction looks like a plateau
that flattens out above zero.

That model carries two extra assumptions: a non-zero cured fraction exists, and follow-up
runs long enough to *identify* it (formally, `τ_F0 ≤ τ_G` — follow-up must extend past the time by
which all susceptible patients would have had the event). If the second fails, late censored
patients could be cured or uncured-and-not-yet-relapsed, and the two are observationally
indistinguishable. Othus et al. re-analysed six SWOG trials at two follow-up times and found
cure-model estimates of mean survival shifted materially — and the direction of the shift was not
predictable, so it cannot be corrected after the fact.

**A plateau is not proof.** Heavy censoring alone manufactures a plateau that is a censoring
artifact, not cure. That is exactly what the diagnostics are for. The manuscript's three-step check
is ① expert judgment, ② visual assessment, ③ quantitative assessment. `cureAssess` automates ② and ③. Step ① is a conversation with a clinician,
so the app must present it as something the *user* confirms, never something the software decides.

## What the app will do

Under construction: **Add screenshot of tabs from the app itself**. Briefly explain.

## Repository layout

```text
KIDS26-Team9/
├── README.md                  
├── LICENSE.md                 
├── app/                       
│   ├── app.R                  
│   └── R/              
├── cureAssess/
├── data-raw/              
├── data/examples/             
├── docs/                      
└── report/                    
```

## Getting started

The user can clone the repo locally to their desired location.

```bash
git clone https://github.com/stjude-biohackathon/KIDS26-Team9.git
cd KIDS26-Team9
```

```r
# 1. R >= 4.5.3 is required.
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

# 4.  Run the app.
shiny::runApp("app")
```

## About the `cureAssess` package

`cureAssess` 0.1.0 — *Assessing Cure Model Appropriateness for Survival Data*. Author, maintainer
and copyright holder: **Geethanjalee Mudunkotuwa**. Author: **Durbadal Ghosh**. MIT licensed.
Upstream: <https://github.com/GeethanjaleeM/cureAssess>.

A companion tutorial manuscript, *"A Tutorial for Evaluating Cure Model Appropriateness"*
(Mudunkotuwa, Ghosh, Triplett, Selukar), is in preparation and available on [arXiv](https://arxiv.org/pdf/2605.04999). The app makes the workflow described in Figure 1 of this manuscript
into an interactive workflow.

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
Jude clinical datasets enters this repository or appears on screen during the demo.
