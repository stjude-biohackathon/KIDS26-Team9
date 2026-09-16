# `app/` — the Shiny application

**Empty by design.** The real application is built here during the hackathon, from the
specification in [`docs/shiny-app-spec.md`](../docs/shiny-app-spec.md).

Do not grow `app-scaffold/app.R` into this. That scaffold exists only to prove the environment
works (task **T-03**) and has none of the module structure the spec requires.

Expected layout once **A-01** lands:

```text
app/
  app.R                 entry point; assembles the five tabs      (Sharon, A-01)
  R/mod_data.R          Data tab: dataset picker, upload, mapper   (Rashid, A-02/A-03)
  R/mod_models.R        Models tab: AIC table, fitted overlay      (Sharon, A-05/A-06)
  R/mod_diagnostics.R   Diagnostics tab: the five cards            (Rashid, A-07)
  R/mod_verdict.R       Verdict tab: three-step strip, report      (Sharon, A-08)
  R/mod_about.R         About tab: references, how to cite         (Sharon, A-10)
  R/helpers.R           shared formatting and validation helpers
  R/datasets.R          built-in example + simulated dataset registry
  www/                  CSS and static assets
```

**One person owns one module file.** Four people editing a single `app.R` is how a three-day
project loses a morning to merge conflicts. See `docs/shiny-app-spec.md` section 3 for the shared
reactive-state contract that lets the modules be built in parallel.

Run it with:

```r
shiny::runApp("app")
```
