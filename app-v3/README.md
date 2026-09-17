# app-v3 — "The Bench"

An alternative front end to the same assessment, for the lead to compare against the
baseline in `app/` and against `app-v2/`.

```r
shiny::runApp("app-v3")        # from the repository root
```

`gbsg` is prepared and assessed before first paint, so the page is never empty and there
is nothing to press.

---

## The concept

A fixed two-pane instrument that never scrolls as a page.

**Left, 360px: every control the app has**, in five hairline-separated sections — the
dataset, the columns, your judgment, the optional dials, the take-away. **Right: a live
canvas** that redraws the instant any of them changes, with the verdict pinned across its
top and never scrolling away.

Nothing is ever *run*, because the canvas always shows the answer for whatever the left
pane currently says. There is no Run button, no Prepare button and no Re-run button. The
only things a person does are: choose data and columns, answer two questions, and
download.

Three things carry the design:

1. **The pinned verdict strip.** The headline — one of exactly three sentences — plus
   three chips in plain English: *your judgment*, *best model*, *follow-up*. Those three
   chips are the whole argument as three objects, and they are on screen at every scroll
   position.
2. **Panel headings are questions, not nouns.** *Does the curve flatten out? · Is
   follow-up long enough? · Is the cured group real? · Which model fits best?* They cost
   nothing and carry a reader who has never met a cure model through four panels without a
   glossary.
3. **The dial sits under the picture it moves.** The evaluation-time slider is directly
   beneath the cured-group plane, so moving it moves the dot, with a permanent line saying
   that the verdict and the report always use the default.

Three modes, and that is the entire navigation: **Assess · Compare · Method**. Compare
keeps the frame — the control pane becomes the batch chooser and the canvas becomes the
results table. Method collapses the control pane to a table of contents and gives the
canvas the technical documentation, which is why Method is a mode and not an overlay.

## Who it is for

The subject-matter expert and the room. Everything is one glance away, nothing is hidden
behind a step, and the verdict is legible from the back of a lecture theatre while the
evidence behind it is legible from a seat. A non-expert is carried by the four questions
and by the plain-English chips; an expert is served by the dials, by the technical
disclosures under every panel, and by Method.

## Where every baseline feature went

| baseline | here |
|---|---|
| data loading, upload, variable mapping | control pane §1 Dataset and §2 Columns. The 19 examples are radio rows grouped by scenario family; the chosen one shows its teaching note. The mapping collapses to a one-line summary and opening the line is the edit. |
| expert judgment | control pane §3, and the first chip in the pinned strip |
| Kaplan-Meier visual check | canvas panel 1, with the shaded follow-up tail, the plateau chip, the per-dataset captions, and the plateau reading guide as a disclosure |
| follow-up diagnostics, including the not-computable path | canvas panel 2 — **two threshold tracks, never three**, with the companion reading stated in one sentence underneath the first. When the three readings go missing together, both tracks show a "Cannot be computed" panel and the strip's third chip goes grey. |
| the cured-group reading | canvas panel 3, as a plane, with the two values printed large above it |
| model comparison | canvas panel 4 — the dot plot, plus the full sortable table in a disclosure with its error column visible and failed rows never filtered |
| the recommendation | the pinned strip |
| sensitivity (α, evaluation time, distribution, lognormal) | control pane §4 Explore, plus the evaluation-time dial under the plane |
| batch assessment and its CSV | **Compare** mode |
| report download | the pinned strip; its failure message renders in control pane §5 |
| technical documentation | **Method** mode |
| the intro material — what a cure model is, the flowchart, the mixture equation | the first block of Method, and the first entry in its contents list |

## Better than the baseline

- **Nothing is more than one glance away.** Seven tabs become one screen; a reader never
  has to remember which tab held which number.
- **The verdict is always visible**, and so is the argument behind it, as three chips.
- **Cause and effect are adjacent.** Answering a question changes the strip you are looking
  at; moving the evaluation time moves the dot directly above the slider.
- **Compare is a first-class mode**, sharing the app's single control surface, instead of a
  closed accordion at the bottom of a tab.
- **Denser.** A whole assessment fits in one viewport on a laptop; the baseline needs five
  tab changes to see the same thing.
- **Questions instead of nouns.** "Is follow-up long enough?" teaches more than
  "Quantitative assessment" and costs the same space.

## Honestly worse than the baseline

- It is an **expert's instrument first**, and nothing in the layout says where to start.
- **No guided order**, so it teaches the method less than a sequence that *is* the
  argument. The baseline's rail walks a newcomer through the reasoning; this does not.
- **Viewport-locked.** It degrades below about 1100px wide (the grid folds to one column)
  and badly below 900px or 700px tall, where it gives up and scrolls like an ordinary page.
  On a phone, use the baseline.
- **Denser and busier.** A hostile reader will call four simultaneous panels cluttered.
- **The live canvas invites fiddling.** A user who drags the evaluation time until the
  verdict turns green has done something the method does not sanction. The permanent caveat
  line and the default-only report are mitigations, not cures.
- **Heaviest recomputation of the three**, because everything on screen is live at once.
- **No room for the wide data preview.** It is a ten-row disclosure in a 360px pane, which
  is a genuine regression against the baseline's full-width table.

---

## Coupling to the shared engine

> This version owns only its UI. Every number on screen comes from the shared engine in
> `app/R/`: the single assessment call and the recommendation rule from `helpers.R`, every
> colour, ggplot theme, plot helper and chart builder from `theme.R`, every component
> builder from `helpers.R`, the example registry from `datasets.R`, the batch engine and
> its CSV writer from `mod_batch.R`, the technical documentation text from `mod_docs.R`,
> and the base stylesheet and images from `app/www/`, served here at the `shared` resource
> path. Editing any of those changes all three versions at once — which is the point. This
> version's builder **reads them and never edits them**, and never copies them into this
> directory.

### How that is wired

`app-v3/R/aa_shared.R` sorts first under Shiny's alphabetical auto-load of `R/`, and
sources every `../app/R/*.R` file before this version's own modules. Nothing under `app/`
is copied or edited. The stylesheet and images are mounted as resource paths in `app.R`.

**Two small deviations from the contract's §G.0, both forced and both local:**

1. The resource prefix is **`cashared`**, not `shared`. Shiny reserves that exact word —
   `addResourcePath("shared", …)` refuses with *"called with the reserved prefix
   'shared'"*. `app/www/img` is additionally mounted at `img`, because the shared
   documentation markup writes `<img src="img/…">` and that path has to resolve from here
   too. Still nothing is copied.
2. **FIXED UPSTREAM, workaround removed.** The batch results table used to build its
   display frame with `vapply()` over character columns, so those columns arrived *named*;
   `data.frame()` then adopted the first named component as row names, and a row that was
   not assessed carries `best_model = NA`, which killed the render with **"row names
   contain missing values"**. It reproduced in the baseline too — ticking *Cure fraction
   0%* alone was enough, because that dataset has 2 censored observations against the batch
   minimum of 5. `app/R/mod_batch.R` now passes `USE.NAMES = FALSE` on those calls, so the
   local `data.frame()` shim `aa_shared.R` used to install is gone and this file rebinds
   nothing.

### Shared functions this version calls, and does not re-implement

`ca_assess_once()` · `ca_recommendation()` · `ca_clean_surv()` · `ca_data_summary()` ·
`ca_tail_facts()` · `ca_tail_level()` · `ca_qn_threshold()` · `ca_expert_state()` ·
`ca_last_obs_censored()` · `ca_has_tests()` · `ca_reset_assessment()` · `ca_status_line()` ·
`CA_MODEL_LABELS` · `CA_BATCH_*` · `ca_dataset_load()` · `CA_DATASETS` ·
`CA_DATASET_FAMILIES` · `ca_bs_theme()` · `ca_tokens()` · `theme_cure_assess()` ·
`ca_style_survplot()` · `ca_followup_tail()` · `ca_level_line()` · `ca_icon()` ·
`ca_chip()` / `ca_note()` / `ca_tech()` / `ca_empty()` / `ca_banner()` / `ca_kv()` /
`ca_num()` / `ca_pct()` / `ca_dash()` · the four chart builders `ca_viz_timeline()`,
`ca_viz_threshold_track()`, `ca_viz_receus_plane()`, `ca_viz_aic_dots()` ·
`ca_tests_at_alpha()` · `ca_receus_at_tau()` · `ca_docs_sections()` ·
`ca_batch_assess()` / `ca_batch_csv()` / `mod_batch_ui()` / `mod_batch_server()` ·
`report/report.Rmd`.

The statistics are the package's throughout. `cure.appropriateness()` is called in exactly
one place in the repository, `ca_assess_once()` in `app/R/helpers.R`, and this version
calls it through that function and nowhere else. The recommendation reads exactly three
things — the model-comparison result, the cured-group decision, and the human's answer.
The evaluation time, α and the distribution override are display-only and never reach the
verdict or the report.

## Files

```
app-v3/app.R                  entry: libraries, resource paths, state, mode switch, module servers
app-v3/R/aa_shared.R          sources ../app/R; nothing else
app-v3/R/mod_v3_controls.R    the whole left pane, and the two automatic computations
app-v3/R/mod_v3_strip.R       the pinned verdict strip and the report download
app-v3/R/mod_v3_canvas.R      the timeline and the four Assess panels
app-v3/R/mod_v3_method.R      Method mode
app-v3/www/v3.css             density, chrome and frame overrides only
app-v3/README.md
```

## Notes for the integrator

- **Verified numbers.** `gbsg` 686 / log-logistic cure / AIC 1719.70 / MZ 0.0495 / qn
  0.004373 / Shen 0.3676 / π̂ 0.3238 / r̂ 0.3080 / *Follow-up insufficient*; `nwtco` 1404 /
  π̂ 0.7823 / r̂ 0.0041 / *Cure model appropriate*; `sim_c`, `sim_d`, `sim_lastevent` render
  the not-computable path with no literal `NA` anywhere. The batch table reproduces the
  same values row for row.
- **Clean console.** No warning, no message and no error on launch, on a dataset switch, on
  a mapping change, on a batch of seven built-ins, or on the exploration dials.
- **The report renders** from this directory, at the default evaluation time and the default
  distribution, whatever the dials say.
- **One shared chart wants a fix, and it is not mine to make.** `ca_viz_receus_plane()` in
  `app/R/theme.R` direct-labels its dot to the *right* of the dot. When the ratio sits near
  the top of the axis — `gbsg` at 0.308 of a 0.36 axis — that label runs off the panel and
  ggplot2 clips it. This version mitigates it by drawing that one figure at `res = 92`
  instead of 108 and by giving the plane the wider of the two grid columns; the two values
  are also printed in full, large, directly above the chart, so nothing is lost. The proper
  fix is to flip the label's justification once the dot passes about 70% of the axis.
- **Two contract details deliberately resolved.** (a) The evaluation-time slider exists
  once, under the plane, not also in Explore — two sliders for one number would be the
  repetition the lead asked us to remove. (b) The report download exists once, in the
  pinned strip, which never scrolls away; §5 Take away carries the data preview and the
  download's failure message.
- **Compare's per-arm curve multiples are not built.** `ca_batch_assess()` returns a data
  frame, not fitted objects, and the batch module exposes no frames, so drawing a curve per
  arm would mean re-implementing the batch engine — which §C.0 forbids. The table is the
  feature.
