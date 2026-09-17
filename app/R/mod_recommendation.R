# =============================================================================
# mod_recommendation.R — the Recommendation tab (nav id "rec"), rewriter-rec
#
# Replaces mod_conclusion.R, which is deleted this pass
# (REVISION_CONTRACT §A, §E.5).
#
# THE WHOLE TAB IS: one recommendation, and the report download. Nothing else.
# No three-step strip, no disagreement panel, no k-of-m tally, no
# insufficient-follow-up routes, no reason-tests-were-not-run line, no
# reproduce-in-R card, no alpha banner, no footer navigation
# (REVISION_CONTRACT §E.5 #38-#47).
#
# Renders state$assess and ca_expert_state(state), and nothing else. Package
# call sites: NONE. Every value here was produced by the single
# cure.appropriateness() call inside ca_assess_once() (helpers.R §B.4), which
# mod_quantitative.R drives automatically off state$prepared. This file
# performs no arithmetic at all — the recommendation is a lookup on two package
# fields plus the human's own answer.
#
# FIELD PROVENANCE (kept as comments, never on screen — §G2):
#   $screening$best_model_type  -> the AIC screening result  ("cure"/"non-cure"/NA)
#   $tests$receus$decision      -> the RECeUS decision string
#   $tests_run                  -> whether the diagnostics ran at all
#
# =============================================================================
# V2_CONTRACT (this pass, owner builder-rec) — FOUR CHANGES, ALL LOAD-BEARING
# =============================================================================
#
# 1. R8 — WHAT DRIVES THE RECOMMENDATION, CHECKED AND CONFIRMED.
#    The lead asked for this to be verified explicitly, so it is written down
#    where it is enforced. The recommendation has exactly three inputs:
#
#        $screening$best_model_type   the AIC screening result
#        $tests$receus$decision       the RECeUS decision
#        ca_expert_state(state)       the human's own answer
#
#    All three come from ONE object: the return of the single
#    cure.appropriateness() call in ca_assess_once() (§B.4), plus two radio
#    buttons the user set themselves. This file computes nothing, crosses
#    nothing and overrides nothing. Audited this pass and found clean: there
#    was no app-side logic inventing or overriding a verdict anywhere in this
#    module — the old `.rec_verdict()` was already a pure lookup on those two
#    package fields. It is now a three-line wrapper over `ca_recommendation()`
#    (helpers.R §C.3) so that the rule exists exactly once in the repository
#    and the baseline, app-v2, app-v3, the batch CSV and report.Rmd cannot
#    drift apart.
#
#    Explicitly NOT inputs, and they must never become inputs: the alpha
#    slider, the tau slider, the RECeUS distribution override, the lognormal
#    toggle's effect on anything other than the assessment itself, the
#    Kaplan-Meier curve, the plateau chip, and the three follow-up statistics
#    read individually. Those are display. The decision is the package's.
#
# 2. §B.1 — THE REPORT GETS THE DEFAULT ASSESSMENT, AND ONLY THAT.
#    `.rec_tests()` and `.rec_report_assess()` are DELETED. They spliced the
#    user's alpha-slider recomputation of Maller-Zhou and Shen into the object
#    handed to report.Rmd. §B.1 makes reactives 4 and 5 (alpha, tau) display-
#    only: "They never write state$assess, never reach ca_recommendation(), and
#    never reach report.Rmd." §H.2.2 says the same of the download. So the
#    report is rendered from `state$assess` straight, at the default alpha, the
#    default tau and the default distribution, whatever the exploration
#    controls currently say. The screen carries the permanent line that makes
#    this honest — "This is an exploration. The decision above, and the report,
#    always use the default." — under the exploration controls in
#    mod_quantitative.R (builder-auto's file, §B.1).
#
# 3. R2 — NO RUN BUTTON TO WAIT FOR. Everything is computed automatically as
#    the mapping changes (§B.2, §B.3), so this tab's empty states no longer
#    tell anyone to go and run anything. The one remaining empty state is the
#    genuine one: no dataset at all.
#
# 4. R7/§C.6 — THE BATCH PANEL LIVES HERE, in one accordion panel closed by
#    default, below the single recommendation and its download. No eighth tab.
#    The engine is builder-batch's `app/R/mod_batch.R`; this file only mounts
#    `mod_batch_ui()` / `mod_batch_server()` and never re-implements any of it.
# =============================================================================


# ---- the one recommendation -------------------------------------------------

#' The recommendation, delegated.
#'
#' V2_CONTRACT §C.3: `ca_recommendation()` in `app/R/helpers.R` is the ONE
#' implementation of the rule in the repository. This wrapper exists only to
#' turn two `state` reads into its two arguments, so that reading this file
#' tells you precisely which two package fields decide the verdict (R8).
#'
#' Returns `list(headline, variant, reasons, provisional)`. `variant` is NULL
#' for "No recommendation." — that outcome carries no banner colour.
#'
#' The rules and their order live in `ca_recommendation()` and are unchanged:
#' (1) an expert "no" overrides everything; (2) no fitted model gives
#' "No recommendation."; (3) the screening result crossed with the RECeUS
#' decision; (4) an unanswered expert step makes 2 and 3 provisional. An
#' absent or NA decision also returns "No recommendation."; an *unrecognised*
#' decision string still stops loudly, because a verdict the app cannot parse
#' is a verdict it must not state.
#'
#' `state$assess` may legitimately be NULL here — a failed fit leaves it NULL
#' (§B.7) — and `NULL$screening$best_model_type` is NULL, which is rule 2.
.rec_verdict <- function(state) ca_recommendation(
  aic_type        = state$assess$screening$best_model_type,  # reads $screening$best_model_type
  receus_decision = state$assess$tests$receus$decision,      # reads $tests$receus$decision
  expert          = ca_expert_state(state))                  # helpers.R N.1


# ---- the downloadable report ------------------------------------------------
# FIXPASS: the downloadable HTML report was in scope (docs/shiny-app-spec.md §7,
# Definition-of-Done item 4) and was never built: this tab had no
# downloadButton and no downloadHandler, and report/report.Rmd did not exist.
# Both now exist. The Rmd computes nothing; it receives the finished objects and
# prints their fields, so screen and report cannot drift.

#' Locate `report/report.Rmd`, whichever directory the app was launched from.
#'
#' `shiny::runApp("app")` from the repo root and `runApp()` from inside `app/`
#' both leave the working directory at the app directory, so the sibling path is
#' tried first; the repo-root path is tried too, for a session that sets the
#' working directory itself. Returns `NA_character_` when the file is missing,
#' which the handler turns into a friendly message rather than a crash.
.rec_report_rmd <- function() {
  cands <- c(
    file.path("..", "report", "report.Rmd"),
    file.path("report", "report.Rmd"),
    file.path("..", "..", "report", "report.Rmd")
  )
  for (p in cands) {
    if (file.exists(p)) return(normalizePath(p, winslash = "/", mustWork = FALSE))
  }
  NA_character_
}

#' Make pandoc findable if it is installed but not on the PATH.
#'
#' `rmarkdown::render()` needs pandoc, and a plain `Rscript` session does not
#' inherit RStudio's copy. This looks in the usual places and tells
#' `rmarkdown` about whatever it finds. It installs nothing and it never
#' pretends: the return value is the honest answer to "can we render?", and the
#' handler fails with a helpful message when it is FALSE.
.rec_ensure_pandoc <- function() {
  if (rmarkdown::pandoc_available()) return(TRUE)
  dirs <- c(
    Sys.getenv("RSTUDIO_PANDOC"),
    Sys.glob(file.path(path.expand("~"), "Library", "Application Support", "r-pandoc", "*")),
    Sys.glob("/Applications/RStudio.app/Contents/Resources/app/quarto/bin/tools/*"),
    "/usr/local/bin", "/opt/homebrew/bin", "/usr/bin"
  )
  dirs <- unique(dirs[nzchar(dirs)])
  dirs <- dirs[dir.exists(dirs)]
  if (length(dirs)) try(rmarkdown::find_pandoc(cache = FALSE, dir = dirs), silent = TRUE)
  isTRUE(rmarkdown::pandoc_available())
}

#' A filename that names the dataset it describes.
.rec_report_filename <- function(label) {
  slug <- if (is.null(label) || !nzchar(as.character(label)[1])) {
    "assessment"
  } else {
    s <- gsub("[^A-Za-z0-9]+", "-", as.character(label)[1])
    s <- gsub("-+", "-", s)
    s <- gsub("^-|-$", "", s)
    if (nzchar(s)) s else "assessment"
  }
  paste0("cureAssess-report-", slug, "-", Sys.Date(), ".html")
}

#' The file written when the render fails.
#'
#' A failed download must not crash the app and must not hand the user a broken
#' or empty file. They get the on-screen wording plus the verbatim message, in a
#' page that opens like any other. This is a diagnostic artefact, not a screen:
#' the REVISION_CONTRACT names neither its keep nor its delete, so it is carried
#' over unchanged (reported as a gap).
.rec_report_failure_html <- function(msg) {
  esc <- function(x) htmltools::htmlEscape(as.character(x))
  paste0(
    "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">",
    "<title>The report could not be generated</title>",
    "<style>body{font-family:system-ui,-apple-system,Segoe UI,Roboto,sans-serif;",
    "max-width:44rem;margin:3rem auto;padding:0 1.25rem;line-height:1.55;color:#11191C}",
    "h1{font-family:Charter,Georgia,serif;font-size:1.6rem}",
    "pre{background:#F4F7F8;border:1px solid #DBE2E4;border-radius:6px;padding:.75rem;",
    "white-space:pre-wrap;font-size:.85rem}</style></head><body>",
    "<h1>The report could not be generated</h1>",
    "<p>The recommendation on screen in the app is unchanged. ",
    "Only this download failed.</p>",
    "<p>The verbatim message was:</p><pre>", esc(msg), "</pre>",
    "<p>If the message mentions pandoc, the machine has R and rmarkdown but no pandoc ",
    "installed; installing pandoc, or running the app from RStudio, fixes it.</p>",
    "</body></html>"
  )
}


# =============================================================================
# UI
# =============================================================================

#' Recommendation tab UI: one recommendation, the report control, and — closed —
#' the same question asked of many datasets at once.
mod_recommendation_ui <- function(id) {
  ns <- NS(id)

  htmltools::tagList(

    htmltools::tags$section(
      class = "ca-section",
      htmltools::h1("Recommendation"),
      uiOutput(ns("status_msg")),
      uiOutput(ns("recommendation"))
    ),

    htmltools::tags$section(
      class = "ca-section",
      ca_card(
        title = "Report",
        body = htmltools::tagList(
          uiOutput(ns("download_ui")),
          uiOutput(ns("download_msg"))
        )
      )
    ),

    # V2_CONTRACT §C.6: the batch panel is one accordion panel on THIS tab,
    # closed by default — "this tab is one recommendation and a download; batch
    # is many recommendations and a download". There is no eighth tab; the
    # seven-tab structure is the one the lead approved (§H.2.10).
    #
    # `open = FALSE` keeps it shut on arrival, so the tab still reads as one
    # verdict. Everything inside belongs to builder-batch's app/R/mod_batch.R:
    # this file supplies the panel and the module id, and nothing else.
    htmltools::tags$section(
      class = "ca-section",
      bslib::accordion(
        id = ns("batch_accordion"),
        open = FALSE,
        bslib::accordion_panel(
          title = "Assess several datasets at once",
          value = "batch",
          mod_batch_ui(ns("batch"))
        )
      )
    )
  )
}


# =============================================================================
# SERVER
# =============================================================================

#' Recommendation tab server. Writes nothing to `state`.
mod_recommendation_server <- function(id, state, go_to) {
  moduleServer(id, function(input, output, session) {

    # The batch panel (§C.6). builder-batch owns everything it renders; this
    # line is the whole of this file's involvement.
    mod_batch_server("batch", state, go_to = go_to)

    # The only two controls on this tab: the empty-state exit to Data, and the
    # Rule 4 button to Expert judgment. No footer navigation.
    #
    # R2: the "Quantitative →" empty-state exit is GONE with the Run button it
    # used to send people to. There is nothing to go and press.
    ca_on_click(input, "to_data_empty", function() go_to("data"))
    ca_on_click(input, "to_expert",     function() go_to("expert"))

    # ---- the one empty state that is still real ---------------------------
    # With auto-assessment there is no "not run yet" state and no stale state:
    # ca_reset_assessment() nulls the old verdict synchronously and the new one
    # lands ~0.15 s later (§B.6). A failed fit is not empty either — it is a
    # verdict of "No recommendation." (§B.7, rule 2), rendered below like any
    # other. So the only thing left to say here is that there is no data.

    output$status_msg <- renderUI({
      if (is.null(state$prepared)) {
        return(ca_empty(
          "There is no recommendation yet. Choose a dataset first.",
          action_id = session$ns("to_data_empty"), action_label = "Data →"
        ))
      }
      NULL
    })

    # ---- the one recommendation -------------------------------------------

    output$recommendation <- renderUI({
      req(state$prepared)
      # §B.6 consequence 2: during the ~150 ms between a mapping change and the
      # new assessment, `state$assess` is NULL and `state$last_error` is NULL
      # too, and this render is skipped — the card keeps its previous value at
      # 45% opacity (Shiny's own .recalculating) rather than flashing a verdict
      # that belongs to neither dataset. A NULL assessment WITH an error is a
      # real outcome and does render, as "No recommendation." (§B.7).
      req(!is.null(state$assess) || !is.null(state$last_error))
      v <- .rec_verdict(state)

      htmltools::div(
        class = paste(c("ca-rec", v$variant), collapse = " "),

        # The headline is the largest type on the tab and is one of exactly
        # three strings (§G.6). The banner colour is set from the headline, not
        # from the package decision string.
        htmltools::div(class = "ca-rec__decision", v$headline),

        htmltools::div(
          class = "ca-rec__body",
          lapply(v$reasons, function(r) {
            htmltools::tags$p(class = "ca-rec__plain", r)
          }),
          if (isTRUE(v$provisional)) {
            htmltools::tagList(
              htmltools::tags$p(
                class = "ca-rec__plain",
                "Expert judgment is not answered yet, so this is provisional."
              ),
              actionButton(session$ns("to_expert"), "Answer it →")
            )
          }
        )
      )
    })

    # ---- the downloadable HTML report -------------------------------------
    # This writes nothing to `state` — the failure message is a local
    # reactiveVal, so a failed download leaves the recommendation on screen
    # untouched.

    report_error <- reactiveVal(NULL)

    output$download_ui <- renderUI({
      ready <- identical(state$status, "assessed") && !is.null(state$assess)
      btn <- downloadButton(
        session$ns("download_report"), "Download HTML report",
        class = if (ready) "btn-primary" else "btn-secondary"
      )
      if (ready) return(btn)
      # Disabled, not hidden: the user should see what becomes available and
      # why. shiny::downloadButton() already emits class="disabled",
      # aria-disabled and tabindex="-1", and `.btn.disabled` in Bootstrap 5
      # blocks the click outright. Shiny's own JS strips all three the moment
      # the download output registers, so `data-shiny-disable-auto-enable` is
      # what actually keeps it disabled (shiny.min.js, download-link binding).
      htmltools::tagList(
        htmltools::tagAppendAttributes(btn, `data-shiny-disable-auto-enable` = "true"),
        htmltools::tags$p(class = "ca-lede", "Available once an assessment has run.")
      )
    })

    output$download_msg <- renderUI({
      msg <- report_error()
      if (is.null(msg)) return(NULL)
      ca_note(
        "warning", "The report could not be generated",
        htmltools::tagList(
          htmltools::tags$p("The recommendation above is unchanged."),
          ca_tech(htmltools::tags$p(msg))
        )
      )
    })

    output$download_report <- downloadHandler(
      filename = function() .rec_report_filename(state$label),
      content = function(file) {
        report_error(NULL)

        ok <- tryCatch({
          rmd <- .rec_report_rmd()
          if (is.na(rmd)) {
            stop("report/report.Rmd could not be found from the working directory ",
                 getwd(), ". Run the app from the repository root with ",
                 "shiny::runApp(\"app\") so that report/ is a sibling of app/.")
          }
          if (!.rec_ensure_pandoc()) {
            stop("pandoc was not found on this machine, and rmarkdown::render() ",
                 "cannot produce HTML without it. Install pandoc (or run the app ",
                 "from RStudio, which ships a copy) and try again.")
          }

          # Render in a temporary directory: the app never writes into the repo,
          # and the render works where the app directory is read-only.
          td <- tempfile("ca_report")
          dir.create(td)
          local_rmd <- file.path(td, "report.Rmd")
          if (!file.copy(rmd, local_rmd, overwrite = TRUE)) {
            stop("The report template could not be copied to a temporary directory.")
          }

          withProgress(message = "Building the report", value = 0.3, {
            rmarkdown::render(
              input             = local_rmd,
              output_file       = file,
              intermediates_dir = td,
              knit_root_dir     = td,
              params = list(
                label             = state$label,
                source            = state$source,
                map               = state$map,
                prepared          = state$prepared,
                fit               = state$fit,
                # V2_CONTRACT §B.1 / §H.2.2 — THE DEFAULT ASSESSMENT, STRAIGHT.
                # This deliberately reverses an earlier fix that spliced
                # `state$alpha_tests` (Maller-Zhou and Shen recomputed at the
                # user's alpha) into the object handed to the Rmd. §B.1 makes
                # the alpha, tau and distribution controls display-only and
                # says in terms that they "never reach report.Rmd"; §H.2.2
                # requires the download to use the default tau and the default
                # distribution regardless of any exploration state. So the
                # report is the assessment the recommendation above rests on,
                # and nothing else. The exploration controls carry their own
                # permanent caveat line on the Quantitative tab.
                assess            = state$assess,
                include_lognormal = isTRUE(state$include_lognormal),
                # The three-way expert state, not a two-state boolean. The
                # report reproduces all four recommendation rules, rule 1
                # included, so it can no longer print a verdict the screen does
                # not show. One source: ca_expert_state() (helpers.R N.1).
                expert            = ca_expert_state(state)
              ),
              envir = new.env(parent = globalenv()),
              quiet = TRUE
            )
          })
          TRUE
        }, error = function(e) {
          report_error(conditionMessage(e))
          FALSE
        })

        # A failed download must not crash the app and must not hand back an
        # empty file: the user gets the on-screen wording and the verbatim
        # message.
        if (!isTRUE(ok)) {
          writeLines(
            .rec_report_failure_html(report_error()),
            con = file, useBytes = TRUE
          )
        }
        invisible(NULL)
      }
    )

    invisible(NULL)
  })
}
