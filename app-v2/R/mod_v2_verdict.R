# =============================================================================
# app-v2/R/mod_v2_verdict.R — the verdict band, the sticky bar, and the
# take-it-away block.                                    owner: builder-v2
#
# §G.1 section 0: the band is full-bleed and is the page's only large colour
# field. It carries the answer, one plain sentence of reason, the dataset name
# and the three descriptive counts, and a provisional marker while the expert
# questions are unanswered.
#
# THE RULE IS NOT RE-IMPLEMENTED HERE. The headline, its variant, its reasons
# and the provisional flag all come from ca_recommendation() (app/R/helpers.R,
# V2_CONTRACT §C.3) — the one recommendation rule in the repository. Its three
# inputs are the AIC screening result, the RECeUS decision and the human's own
# answer, and nothing else in this file reaches it (R8).
#
# FIELD PROVENANCE (code comments only, never on screen — C1):
#   $screening$best_model_type   the AIC screening result, "cure"/"non-cure"/NA
#   $tests$receus$decision       the RECeUS decision string
#   ca_data_summary()            the six descriptive counts, app-side (S1)
# =============================================================================


# ---- the verdict, from the one shared rule ----------------------------------

#' The recommendation for the current state.
#'
#' `state$assess` may legitimately be NULL — a failed fit leaves it NULL — and
#' `NULL$screening$best_model_type` is NULL, which is the rule's own
#' "No recommendation." branch.
#' @noRd
.v2_verdict <- function(state) ca_recommendation(
  aic_type        = state$assess$screening$best_model_type,
  receus_decision = state$assess$tests$receus$decision,
  expert          = ca_expert_state(state)
)


# ---- the downloadable report ------------------------------------------------
# Self-contained on purpose: report/report.Rmd is rendered from a copy in a
# temporary directory, and this version never writes into the repository.

#' Locate report/report.Rmd from wherever the app was launched.
#' @noRd
.v2_report_rmd <- function() {
  cands <- c(file.path("..", "report", "report.Rmd"),
             file.path("report", "report.Rmd"),
             file.path("..", "..", "report", "report.Rmd"))
  for (p in cands) if (file.exists(p)) return(normalizePath(p, winslash = "/", mustWork = FALSE))
  NA_character_
}

#' Make pandoc findable when it is installed but not on the PATH.
#' @noRd
.v2_ensure_pandoc <- function() {
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
#' @noRd
.v2_report_filename <- function(label) {
  slug <- if (is.null(label) || !nzchar(as.character(label)[1])) "assessment" else {
    s <- gsub("-+", "-", gsub("[^A-Za-z0-9]+", "-", as.character(label)[1]))
    s <- gsub("^-|-$", "", s)
    if (nzchar(s)) s else "assessment"
  }
  paste0("cureAssess-report-", slug, "-", Sys.Date(), ".html")
}

#' The page written when the render fails: a diagnostic artefact, never an
#' empty file and never a crash.
#' @noRd
.v2_failure_html <- function(msg) {
  paste0(
    "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">",
    "<title>The report could not be generated</title>",
    "<style>body{font-family:system-ui,sans-serif;max-width:44rem;margin:3rem auto;",
    "padding:0 1.25rem;line-height:1.55;color:#11191C}h1{font-family:Charter,Georgia,serif}",
    "pre{background:#F4F7F8;border:1px solid #DBE2E4;border-radius:6px;padding:.75rem;",
    "white-space:pre-wrap;font-size:.85rem}</style></head><body>",
    "<h1>The report could not be generated</h1>",
    "<p>The recommendation on screen is unchanged. Only this download failed.</p>",
    "<p>The verbatim message was:</p><pre>",
    htmltools::htmlEscape(as.character(msg)), "</pre></body></html>"
  )
}

#' One download handler, mounted twice (§G.1: the bar and section 6).
#'
#' V2_CONTRACT §B.1 / §H.2.2 — the report is rendered from the DEFAULT
#' assessment. The alpha slider, the evaluation-time slider and the
#' distribution override are display-only and never reach this handler.
#' @noRd
.v2_report_handler <- function(state, on_error) {
  downloadHandler(
    filename = function() .v2_report_filename(state$label),
    content = function(file) {
      on_error(NULL)
      ok <- tryCatch({
        rmd <- .v2_report_rmd()
        if (is.na(rmd)) {
          stop("The report template could not be found from the working directory ",
               getwd(), ". Launch from the repository root with ",
               "shiny::runApp(\"app-v2\").")
        }
        if (!.v2_ensure_pandoc()) {
          stop("pandoc was not found on this machine, and the report cannot be ",
               "produced without it.")
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
              label             = state$label,
              source            = state$source,
              map               = state$map,
              prepared          = state$prepared,
              fit               = state$fit,
              assess            = state$assess,
              include_lognormal = isTRUE(state$include_lognormal),
              expert            = ca_expert_state(state)
            ),
            envir = new.env(parent = globalenv()),
            quiet = TRUE
          )
        })
        TRUE
      }, error = function(e) { on_error(conditionMessage(e)); FALSE })

      if (!isTRUE(ok)) writeLines(.v2_failure_html(isolate(on_error())), con = file, useBytes = TRUE)
      invisible(NULL)
    }
  )
}


# =============================================================================
# UI
# =============================================================================

#' Section 0 — the verdict band. Full-bleed, and the page's only large colour
#' field.
#'
#' The whole band is rendered, not just its contents, because the tint is the
#' verdict: the variant class returned by ca_recommendation() has to land on the
#' element that bleeds, and that element is the section.
mod_v2_band_ui <- function(id) {
  # The mount carries a class of its own because it is the one element on the
  # page that is always there and always where the band is: the sticky bar
  # watches it to know when the band has gone.
  uiOutput(NS(id)("band"), class = "v2-bandmount")
}

#' The 48px sticky bar. It carries the verdict only once the band has scrolled
#' away, so the headline is never printed twice on one screen.
mod_v2_bar_ui <- function(id) {
  ns <- NS(id)

  jump <- htmltools::tags$nav(
    class = "v2-bar__jump", `aria-label` = "Jump to a section",
    htmltools::tags$a(href = "#v2-verdict", "Verdict"),
    htmltools::tags$a(href = "#v2-data", "Data"),
    htmltools::tags$a(href = "#v2-curve", "Curve"),
    htmltools::tags$a(href = "#v2-models", "Models"),
    htmltools::tags$a(href = "#v2-diagnostics", "Diagnostics")
  )

  htmltools::div(
    class = "v2-bar",
    htmltools::div(
      class = "v2-bar__inner",
      htmltools::tags$span(class = "v2-bar__verdict", uiOutput(ns("bar_verdict"),
                                                              inline = TRUE)),
      htmltools::tags$span(class = "v2-bar__dataset",
                           textOutput(ns("bar_dataset"), inline = TRUE)),
      jump,
      htmltools::div(
        class = "v2-bar__right",
        htmltools::div(
          class = "v2-seg",
          radioButtons(ns("mode"), NULL, inline = TRUE,
                       choices = c("One dataset" = "one", "Many" = "many"),
                       selected = "one")
        ),
        htmltools::tags$label(class = "v2-linkbtn", `for` = "v2-method-open", "Method"),
        bslib::input_dark_mode(id = "ca_mode", mode = "light")
      )
    )
  )
}

#' Section 6 — take it away. The report download and the way into the method.
mod_v2_takeaway_ui <- function(id) {
  ns <- NS(id)
  htmltools::tags$section(
    class = "v2-sec v2-sec--takeaway", id = "v2-takeaway",
    htmltools::tags$h2(class = "v2-sec__title", "Take it away"),
    htmltools::div(
      class = "v2-takeaway__row",
      downloadButton(ns("report_main"), "Download the report", class = "btn-primary"),
      htmltools::tags$label(class = "v2-linkbtn v2-linkbtn--lg", `for` = "v2-method-open",
                            "How each reading is defined")
    ),
    uiOutput(ns("report_msg"))
  )
}


# =============================================================================
# SERVER
# =============================================================================

#' The band, the bar and the two download mounts. Writes nothing to `state`.
mod_v2_verdict_server <- function(id, state) {
  moduleServer(id, function(input, output, session) {

    report_error <- reactiveVal(NULL)

    # ---- the band ---------------------------------------------------------
    # One helper, so the section element and its id are written once.
    band <- function(variant, ...) {
      htmltools::tags$section(
        id = "v2-verdict",
        class = paste(c("v2-band", variant), collapse = " "),
        htmltools::div(class = "v2-band__inner", ...)
      )
    }

    output$band <- renderUI({
      if (is.null(state$raw)) {
        return(band(NULL,
          htmltools::tags$p(class = "v2-band__eyebrow", "Is a cure model appropriate?"),
          htmltools::tags$h1(class = "v2-band__headline", "Choose some data."),
          htmltools::tags$p(
            class = "v2-band__reason",
            "This page answers one question about one group of patients: can the",
            "survival data support a model with a permanently event-free group?"
          ),
          htmltools::tags$label(class = "v2-linkbtn v2-linkbtn--lg",
                                `for` = "v2-drawer-open", "Choose data")
        ))
      }

      # §B.6 consequence 2: between a mapping change and the assessment that
      # replaces it, both are NULL and this render is skipped — the band keeps
      # its previous value at 45% opacity rather than flashing a verdict that
      # belongs to neither dataset.
      req(!is.null(state$assess) || !is.null(state$last_error))
      v <- .v2_verdict(state)
      s <- ca_data_summary(state$prepared)

      band(
        v$variant,
        htmltools::tags$p(class = "v2-band__eyebrow", "Is a cure model appropriate?"),
        htmltools::tags$h1(class = "v2-band__headline", v$headline),
        lapply(v$reasons, function(r) htmltools::tags$p(class = "v2-band__reason", r)),
        htmltools::tags$p(
          class = "v2-band__meta",
          htmltools::tags$strong(state$label),
          htmltools::HTML("&ensp;&middot;&ensp;"),
          htmltools::tags$span(class = "ca-mono", format(s$n, big.mark = ",", trim = TRUE)),
          " people",
          htmltools::HTML("&ensp;&middot;&ensp;"),
          htmltools::tags$span(class = "ca-mono", format(s$events, big.mark = ",", trim = TRUE)),
          " had the event",
          htmltools::HTML("&ensp;&middot;&ensp;"),
          htmltools::tags$span(class = "ca-mono", paste0(ca_num(s$censored_pct, 1), "%")),
          " censored"
        ),
        if (isTRUE(v$provisional)) {
          htmltools::tags$p(
            class = "v2-band__provisional",
            ca_chip("neutral", "Provisional"),
            htmltools::tags$span("Nobody has answered the two questions below yet.")
          )
        }
      )
    })

    # ---- the sticky bar ---------------------------------------------------
    output$bar_dataset <- renderText({
      if (is.null(state$label)) "No data yet" else as.character(state$label)
    })

    output$bar_verdict <- renderUI({
      req(state$raw)
      req(!is.null(state$assess) || !is.null(state$last_error))
      v <- .v2_verdict(state)
      variant <- if (identical(v$variant, "ca-rec--appropriate")) "pass"
                 else if (identical(v$variant, "ca-rec--unsupported")) "fail"
                 else "neutral"
      ca_chip(variant, v$headline)
    })

    # ---- the report, mounted twice ----------------------------------------
    output$report_main <- .v2_report_handler(state, report_error)

    output$report_msg <- renderUI({
      msg <- report_error()
      ready <- identical(state$status, "assessed") && !is.null(state$assess)
      htmltools::tagList(
        if (!ready) {
          htmltools::tags$p(class = "ca-provenance", "Available once an assessment has run.")
        } else {
          htmltools::tags$p(
            class = "ca-provenance",
            "One page: the verdict, the data, the curve, the models and the readings."
          )
        },
        if (!is.null(msg)) {
          ca_note("warning", "The report could not be generated",
                  htmltools::tagList(
                    htmltools::tags$p("The verdict above is unchanged."),
                    ca_tech(htmltools::tags$p(msg))
                  ))
        }
      )
    })

    invisible(NULL)
  })
}
