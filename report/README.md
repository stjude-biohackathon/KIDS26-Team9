# `report/` — the downloadable HTML report

**Empty by design.** Filled by task **B-07** (Rachael, Thursday block T3), wired to the app's
download button by **A-09** (Rashid, block T4).

`report.Rmd` is a parameterised R Markdown document. The app passes it the current analysis and
renders it to a standalone HTML file the user can save and share.

Sections: dataset label and provenance · data summary · Kaplan-Meier plot · AIC comparison table ·
all five diagnostics with thresholds and interpretations · the plain-language verdict ·
`sessionInfo()` · citations.

Render it with `intermediates_dir` set to a temporary directory, so it works in a locked-down
environment where the app's own directory may not be writable. Specification:
[`docs/shiny-app-spec.md`](../docs/shiny-app-spec.md), section 7.
