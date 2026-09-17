# app-v2 — "The Verdict Page"

    shiny::runApp("app-v2")     # from the repository root

An alternative front end to the same assessment. It is one of three versions —
`app/` (the baseline the lead approved), `app-v2/` and `app-v3/` — that differ
in structure and presentation and **not at all** in statistics.

---

## The concept

**One page. The answer is the first thing on it, and everything below exists to
explain it or to let you attack it.**

A full-bleed verdict band carries the recommendation from the moment a dataset
is loaded — before the reader has clicked anything, because nothing needs
clicking. Under it the page runs in the order a sceptic asks:

| | | |
|---|---|---|
| 0 | **Verdict** | the answer, one sentence of reason, the dataset and its three counts |
| 1 | **Your judgment** | the two expert questions, directly under the band so the reader sees their answer change it |
| 2 | **The data** | the mapping in a sentence, the follow-up timeline, and *Change data or columns* |
| 3 | **Does the curve flatten?** | the Kaplan-Meier figure, full-bleed, with the tail band and the level rule |
| 4 | **Which model fits best?** | the comparison dot plot; every model and its score behind a disclosure |
| 5 | **Do the readings agree?** | the follow-up track, then the cured-group plane; the dials behind *Push on this* |
| 6 | **Take it away** | the report download, and the way into Method |

Off the column, because neither is part of the argument: the **data drawer** (a
right-hand slide-over holding the source, the upload, the four mapping controls
and the ten-row preview) and **Method** (a full-screen reading view with a
floating table of contents). A sticky 48px bar appears the moment the band
scrolls away, carrying the verdict, the dataset name, a jump menu, the
*One dataset · Many* switch, Method and the dark toggle.

No tabs. No rail. **No Run button, no Prepare button, no Re-run button.** The
only things anyone does here are choose data and map its columns, answer the two
questions, and download.

## Who it is for

The clinician or analyst who wants a decision rather than a tour, and anyone
handed the screen with no explanation. The page states its conclusion in one
line of display type and then earns it, so a reader who knows no survival
analysis learns what the question is by scrolling, and a reader who does know
can go straight to the model table or open *Push on this* and move the
significance level, the evaluation time and the distribution themselves.

## Better than the baseline

- **The answer is never more than one screen away.** The baseline puts the
  recommendation on the sixth of seven tabs; here it is the first thing on the
  page and it is repeated in the sticky bar for the whole scroll.
- **Nothing is hidden behind navigation.** Every piece of evidence is on one
  page in a fixed order, so the argument reads as an argument. In the baseline
  the same material is seven destinations with no narrative between them.
- **Answering the expert questions visibly changes the verdict**, because the
  questions sit immediately under the band that changes.
- **Fewer boxes.** Card edges are dropped in the evidence column: sections
  separate by a hairline and by space. Only the verdict band, the cured-group
  plane and the batch table keep a border.
- **Figures get room.** The Kaplan-Meier curve, the plane and the batch table
  escape the reading column to the full bleed; the batch table shows all nine
  columns without sideways scrolling, which it cannot do inside the baseline's
  accordion.
- **Method is a reading view, not a tab** — full screen, with a contents rail
  built from the document itself.
- **One display line, used once.** The page has exactly one piece of large type
  and it is the verdict.
- **An uploaded file arrives mapped.** See note 4 below: the baseline proposes
  the first column of the file as the status column, which on a two-column file
  is the time column.

## Honestly worse than the baseline

State these plainly when comparing:

- **No random access.** An expert who wants only the model table scrolls past
  four sections. The jump menu mitigates that; it does not equal a rail.
- **Completion state is gone.** The baseline's rail told you at a glance that
  expert judgment was unanswered. Here that is one chip inside the band.
- **Harder to drive in a demo.** "Scroll to Models" is a worse instruction than
  "go to the Quantitative tab".
- **The verdict precedes the evidence**, which is rhetorically backwards for a
  statistician, and invites a reader to stop at the headline.
- **Sensitivity loses its room.** The significance level, the evaluation-time
  ladder, the distribution override, the fitted overlay and the cut-off what-if
  are all stacked inside one disclosure rather than given a screen.
- **A full-bleed curve plus a 420px plane is cramped under about 700px wide.**
  Below 62rem the plane stacks and the contents rail in Method disappears.
- **The page now *is* the report**, which makes the download look redundant even
  though it remains the shareable artefact.

---

## The coupling statement

> This version owns only its UI. Every number on screen comes from the shared
> engine in `app/R/`: the single assessment call and the recommendation rule from
> `helpers.R`, every colour, ggplot theme, plot helper and chart builder from
> `theme.R`, every component builder from `helpers.R`, the example registry from
> `datasets.R`, the batch engine and its CSV writer from `mod_batch.R`, the
> technical documentation text from `mod_docs.R`, and the base stylesheet and
> images from `app/www/`, served here at the `shared` resource path. Editing any
> of those changes all three versions at once — which is the point. This
> version's builder **reads them and never edits them**, and never copies them
> into this directory.

### What is taken from where

| shared file | what this version uses |
|---|---|
| `app/R/helpers.R` | `ca_assess_once()` (the one assessment call in the repository), `ca_recommendation()` (the one recommendation rule), `ca_clean_surv()`, `ca_data_summary()`, `ca_tail_facts()`, `ca_tail_level()`, `ca_qn_threshold()`, `ca_expert_state()`, `ca_last_obs_censored()`, `ca_has_tests()`, `ca_reset_assessment()`, `ca_chip()`, `ca_note()`, `ca_tech()`, `ca_empty()`, `ca_banner()`, `ca_num()`, `ca_pct()`, `ca_dash()`, `CA_MODEL_LABELS` |
| `app/R/theme.R` | `ca_bs_theme()`, every `--ca-*` token and the dark ramp, `theme_cure_assess()`, `ca_tokens()`, `ca_km_overlay_plot()`, `ca_style_survplot()`, `ca_followup_tail()`, `ca_level_line()`, and all four chart builders — `ca_viz_timeline()`, `ca_viz_threshold_track()`, `ca_viz_receus_plane()`, `ca_viz_aic_dots()` |
| `app/R/datasets.R` | `CA_DATASETS`, `CA_DATASET_FAMILIES`, `ca_dataset_load()` |
| `app/R/mod_batch.R` | `mod_batch_ui()` / `mod_batch_server()` whole, and with them the batch engine, the size gate, the provenance cache and the CSV writer. **Many mode mounts them; it re-implements none of it.** |
| `app/R/mod_docs.R` | `ca_docs_sections()` — the entire technical documentation, rendered in this version's Method view. Not one sentence of it is rewritten here. |
| `app/R/mod_quantitative.R` | `ca_tests_at_alpha()`, `ca_receus_at_tau()` — the two display-only exploration calls |
| `app/R/mod_data.R` | `.data_read_csv()`, `.data_sentence()` — the strict upload reader and its refusal wording, so an upload fails here with exactly the baseline's words |
| `app/www/app.css`, `app/www/img/**` | the base stylesheet and the images, served, never copied |
| `report/report.Rmd` | rendered by the download handler, from the **default** assessment |

`app-v2/www/v2.css` overrides layout only and contains no hex literal: every
colour is a `--ca-*` token, so light and dark are inherited rather than
re-declared.

### This version's own files

```
app-v2/app.R                 entry: libraries, resource paths, state, the two views
app-v2/R/aa_shared.R         sources ../app/R (V2_CONTRACT §G.0, verbatim)
app-v2/R/mod_v2_verdict.R    the band, the sticky bar, take-it-away, the report download
app-v2/R/mod_v2_data.R       section 2, the drawer, and the prepare/fit reactives
app-v2/R/mod_v2_expert.R     section 1, the two questions
app-v2/R/mod_v2_evidence.R   sections 3-5, the assessment, the explorations, Many
app-v2/R/mod_v2_method.R     the Method overlay (renders ca_docs_sections())
app-v2/www/v2.css
```

---

## Notes for the other builders

Three things found while building against the shared engine. None is fixed
here — this version reads the shared files and never edits them.

1. **`shiny::addResourcePath("shared", …)` is refused.** Shiny reserves the
   prefix `shared` for its own assets, so `app.R` mounts `app/www` at
   **`cashared`** instead (and `app/www/img` at `img`, which is the path
   `ca_docs_sections()` uses for the QR image). The contract's §G.0 wording says
   `shared`; the resource path is the only difference.
2. **`ca_viz_aic_dots()` loses its shape encoding** (`app/R/theme.R`). The
   geometry sets `shape = ..cure` with `values = c(TRUE = 19, FALSE = 21)` but
   also passes `fill = petrol`, so the hollow ring for a non-cure model is
   filled with the same colour as the solid dot and the two read identically.
   This version's copy therefore does not claim a filled/hollow distinction; the
   model names in the axis labels carry it instead. Dropping `fill` (or setting
   `fill = NA` / the surface colour) would restore it.
3. **`ca_viz_receus_plane()` clips its direct label** when the ratio sits near
   the right-hand end of its axis: on `gbsg` the first line of the label runs off
   the panel, and on `sim_c` the "supported" corner label is clipped instead.
   Widening the right expansion, or `hjust`-ing the label inward when the point
   is past about 70% of the axis, would fix both. Mitigated here by printing both
   values at display size beside the figure.

4. **An uploaded CSV is mapped badly by default** in `app/R/mod_data.R`'s
   `refresh_mapping()`: with no registry entry it proposes the first numeric
   column as the time and the **first column of the file** as the status. On a
   two-column `time,status` file that proposes `time` as the status column as
   well, and the reader is shown a confident verdict computed from one event
   until they notice. This version guesses instead — `.v2_guess_map()` in
   `app-v2/R/mod_v2_data.R` reads column names and level counts only, and it is
   still only a suggestion the drawer can override. The same eight lines would
   port to `mod_data.R` unchanged, and the two versions would then behave
   identically on an upload. **This is the one behavioural difference between
   this version and the baseline**, and it is non-statistical.

One cosmetic point that is the baseline's too: in dark mode the "Number at risk"
numbers under the Kaplan-Meier curve are drawn very dim by `ca_style_survplot()`.
