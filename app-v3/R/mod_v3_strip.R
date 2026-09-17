# =============================================================================
# mod_v3_strip.R — the pinned verdict strip.          V2_CONTRACT §G.2, builder-v3
#
# Row 0 of the canvas. 72px, pinned, never scrolls away:
#   * the headline — one of exactly three strings, from ca_recommendation();
#   * three chips in plain English — expert judgment, best model, follow-up.
#     Those three chips are the whole argument as three objects, visible at all
#     times;
#   * the report download.
#
# While the assessment is stale the chip row is replaced by one "Recomputing"
# micro-label, so a reader never sees a chip that belongs to the previous
# dataset.
#
# THE VERDICT HAS EXACTLY THREE INPUTS (R8), and this file reads no others:
#   $screening$best_model_type   the model-comparison result
#   $tests$receus$decision       the cured-group decision
#   ca_expert_state(state)       the human's own answer
# alpha, the evaluation time and the shape override are display-only and are
# forbidden from reaching ca_recommendation() or the report.
#
# FIELD PROVENANCE (comments only, never on screen — C1):
#   $screening$best_model_type          -> chip 2
#   $tests$qn$statistic                 -> chip 3, against ca_qn_threshold()
#   $tests$receus$decision              -> the headline, via ca_recommendation()
# =============================================================================


mod_v3_strip_ui <- function(id) {
  ns <- NS(id)
  htmltools::div(
    class = "v3-strip",
    htmltools::div(class = "v3-strip__main", uiOutput(ns("verdict"))),
    htmltools::div(class = "v3-strip__aside", uiOutput(ns("download")))
  )
}


mod_v3_strip_server <- function(id, state) {
  moduleServer(id, function(input, output, session) {

    # ---- the three chips --------------------------------------------------

    chip_expert <- function() {
      st <- ca_expert_state(state)                 # helpers.R N.1
      if (identical(st, "yes")) return(ca_chip("pass", "You: cure is plausible"))
      if (identical(st, "no"))  return(ca_chip("fail", "You: not plausible"))
      ca_chip("neutral", "Your judgment: not answered")
    }

    chip_model <- function() {
      a <- state$assess
      if (is.null(a)) return(ca_chip("void", "Best model: none"))
      ty <- a$screening$best_model_type            # $screening$best_model_type
      if (is.null(ty) || length(ty) != 1L || is.na(ty)) {
        return(ca_chip("void", "Best model: none"))
      }
      if (identical(as.character(ty), "cure")) {
        ca_chip("pass", "Best fit allows a cured group")
      } else {
        ca_chip("fail", "Best fit has no cured group")
      }
    }

    # WHICH FIELD ANSWERS "is follow-up long enough?", and why the order matters.
    #
    # Two package outputs speak to follow-up, and a chip must not contradict the
    # headline standing beside it. So the package's OWN decision is read first
    # wherever it names follow-up, and the reading is only consulted when it does
    # not:
    #   1. the three follow-up statistics are NA together (S6) -> cannot be
    #      computed, never a red fail;
    #   2. the decision is "Follow-up insufficient for cure modeling" (the
    #      package sets this when the censored-uncured ratio is at or above its
    #      cut-off) -> too short;
    #   3. the decision is "Cure model appropriate" (both of its conditions hold,
    #      one of which IS the follow-up condition) -> long enough;
    #   4. the decision is "Cure model not supported", which the package sets on
    #      the cure fraction alone and which therefore says nothing about
    #      follow-up. Only here does the chip fall back to the reading against
    #      its threshold, larger is better (S8) — the same comparison the
    #      baseline's own follow-up card makes.
    # Two readings are drawn as two tracks in the canvas; only one decision
    # exists behind them (S9), so the strip states it once.
    chip_followup <- function() {
      if (!ca_has_tests(state) || is.null(state$prepared)) {
        return(ca_chip("void", "Follow-up: not measured"))
      }
      qn  <- state$assess$tests$qn                 # $tests$qn$statistic
      thr <- ca_qn_threshold(nrow(state$prepared), .V3_ALPHA_DEFAULT)
      st  <- if (is.null(qn)) NA_real_ else qn$statistic
      if (is.null(st) || length(st) != 1L || !is.finite(st) || !is.finite(thr)) {
        return(ca_chip("void", "Follow-up: cannot be computed"))
      }
      dec <- state$assess$tests$receus$decision    # $tests$receus$decision
      dec <- if (is.null(dec) || length(dec) != 1L || is.na(dec)) "" else as.character(dec)
      if (identical(dec, "Follow-up insufficient for cure modeling")) {
        return(ca_chip("fail", "Follow-up too short"))
      }
      if (identical(dec, "Cure model appropriate")) {
        return(ca_chip("pass", "Follow-up long enough"))
      }
      if (st > thr) ca_chip("pass", "Follow-up long enough")
      else ca_chip("fail", "Follow-up too short")
    }

    # ---- the strip --------------------------------------------------------

    output$verdict <- renderUI({
      if (is.null(state$prepared)) {
        return(htmltools::div(
          class = "v3-strip__headline is-quiet",
          "Choose a dataset on the left."
        ))
      }

      # §B.6 consequence 2: between a mapping change and the assessment that
      # replaces it, both state$assess and state$last_error are NULL. The strip
      # says so in one micro-label rather than showing the previous dataset's
      # chips.
      if (is.null(state$assess) && is.null(state$last_error)) {
        return(htmltools::tagList(
          htmltools::div(class = "v3-strip__headline is-quiet", "Working…"),
          htmltools::div(class = "v3-strip__recalc", "Recomputing")
        ))
      }

      v <- ca_recommendation(                                   # helpers.R F.23
        aic_type        = state$assess$screening$best_model_type,
        receus_decision = state$assess$tests$receus$decision,
        expert          = ca_expert_state(state)
      )

      htmltools::tagList(
        htmltools::div(
          class = paste(c("v3-strip__headline", v$variant), collapse = " "),
          v$headline,
          if (isTRUE(v$provisional)) {
            htmltools::span(class = "v3-strip__prov", "provisional")
          }
        ),
        htmltools::div(
          class = "v3-strip__chips",
          chip_expert(), chip_model(), chip_followup()
        )
      )
    })

    # ---- the report download ---------------------------------------------
    # The verdict strip is pinned, so this is the one download control on the
    # Assess canvas; its failure message renders in the pane's Take away
    # section, beside the data preview.

    output$download <- renderUI({
      ready <- identical(state$status, "assessed") && !is.null(state$assess)
      btn <- downloadButton(
        session$ns("report"), "Report",
        class = if (ready) "btn-primary btn-sm" else "btn-secondary btn-sm"
      )
      if (ready) return(btn)
      htmltools::tagAppendAttributes(btn, `data-shiny-disable-auto-enable` = "true",
                                     title = "Available once an assessment has run.")
    })

    output$report <- downloadHandler(
      filename = function() .rec_report_filename(state$label),
      content = function(file) {
        state$report_error <- NULL
        ok <- tryCatch({
          rmd <- .rec_report_rmd()
          if (is.na(rmd)) {
            stop("report/report.Rmd could not be found from the working directory ",
                 getwd(), ". Run the app from the repository root with ",
                 "shiny::runApp(\"app-v3\") so that report/ is a sibling of app-v3/.")
          }
          if (!.rec_ensure_pandoc()) {
            stop("pandoc was not found on this machine, and rmarkdown::render() ",
                 "cannot produce HTML without it.")
          }
          td <- tempfile("ca_report"); dir.create(td)
          local_rmd <- file.path(td, "report.Rmd")
          if (!file.copy(rmd, local_rmd, overwrite = TRUE)) {
            stop("The report template could not be copied to a temporary directory.")
          }
          withProgress(message = "Building the report", value = 0.3, {
            rmarkdown::render(
              input = local_rmd, output_file = file,
              intermediates_dir = td, knit_root_dir = td,
              params = list(
                label = state$label, source = state$source, map = state$map,
                prepared = state$prepared, fit = state$fit,
                # §B.1 / §H.2.2 — THE DEFAULT ASSESSMENT, STRAIGHT. The alpha,
                # evaluation-time and shape controls are display-only and never
                # reach the report, whatever they currently say.
                assess = state$assess,
                include_lognormal = isTRUE(state$include_lognormal),
                expert = ca_expert_state(state)
              ),
              envir = new.env(parent = globalenv()), quiet = TRUE
            )
          })
          TRUE
        }, error = function(e) {
          state$report_error <- conditionMessage(e)
          FALSE
        })
        if (!isTRUE(ok)) {
          writeLines(.rec_report_failure_html(state$report_error),
                     con = file, useBytes = TRUE)
        }
        invisible(NULL)
      }
    )

    invisible(NULL)
  })
}
