# =============================================================================
# mod_conclusion.R — the Conclusion tab (nav id "conclusion"), builder-tabs-b
#
# Renders state$assess and nothing else. Package call sites: NONE. Every number
# here was produced by the single cure.appropriateness() call on the
# Quantitative tab (contract §I.6); the only arithmetic this file performs is
# comparing statistics already on screen against thresholds already on screen,
# which is the chip tally, not a new statistic.
#
# The tab order runs Quantitative before Qualitative. This tab always presents
# the three steps in the published order (1) expert, (2) visual, (3) quantitative.
# =============================================================================


# ---- private helpers --------------------------------------------------------

#' Pull a length-1 finite numeric out of a package field, or NA.
#'
#' Package statistics come back NA when a diagnostic is not computable, and
#' NULL when `tests_run` is FALSE. Both must land on `ca_dash()`, never on the
#' text "NA" (contract §L.11).
.concl_stat <- function(x) {
  if (is.null(x) || length(x) != 1L) return(NA_real_)
  v <- suppressWarnings(as.numeric(x))
  if (length(v) != 1L || !is.finite(v)) NA_real_ else v
}

#' The diagnostic objects to display.
#'
#' When the user moved alpha off the package default, `state$alpha_tests` holds
#' Maller-Zhou and Shen recomputed at that alpha (contract §I.7, §I.8) and those
#' are the objects on screen. `qn` has no alpha argument and always comes from
#' the assessment. A NULL `alpha_tests` means alpha is 0.05.
.concl_tests <- function(state) {
  tests <- if (ca_has_tests(state)) state$assess$tests else NULL
  if (is.null(tests)) return(NULL)
  at <- state$alpha_tests
  if (!is.null(at)) {
    if (!is.null(at$mz))   tests$mz <- at$mz
    if (!is.null(at$shen)) tests$shen <- at$shen
  }
  tests
}

#' The assessment object to hand to `report/report.Rmd`.
#'
#' FIXPASS (reverifier): the report took `state$assess` straight, which is the
#' assessment at the package-default alpha, while the screen shows
#' `.concl_tests(state)` — Maller-Zhou and Shen recomputed at the user's alpha
#' when the slider has been moved. A report downloaded at a non-default alpha
#' therefore contradicted the page it came from. This splices the same merged
#' `$tests` list back onto the assessment, so screen and report are one object.
#' Nothing is computed here: `$mz` and `$shen` are whole objects returned by
#' `cureAssess::mz.test()` / `cureAssess::shen.test()`, and `$qn` is untouched
#' because `qn.test()` takes no alpha.
.concl_report_assess <- function(state) {
  a <- state$assess
  if (is.null(a)) return(NULL)
  tests <- .concl_tests(state)
  if (!is.null(tests)) a$tests <- tests
  a
}

#' Alpha actually in force.
.concl_alpha <- function(state) {
  a <- .concl_stat(state$alpha)
  if (is.na(a)) 0.05 else a
}

#' The three follow-up tests, each with its statistic, whether it could be
#' computed, and whether it reads "sufficient follow-up".
#'
#' Directions are the contract's (§J.6): Maller-Zhou and Shen are smaller is
#' better against alpha; qn is LARGER is better against `1 - alpha^(1/n)`, the
#' one closed form the app is permitted to evaluate (§F.4). Getting qn's
#' direction backwards is a blocking bug.
.concl_followup <- function(state) {
  tests <- .concl_tests(state)
  if (is.null(tests)) return(NULL)

  alpha <- .concl_alpha(state)
  n <- if (!is.null(state$prepared)) nrow(state$prepared) else NA_integer_
  qn_thr <- ca_qn_threshold(n, alpha)

  a_mz <- .concl_stat(tests$mz$alpha);     if (is.na(a_mz)) a_mz <- alpha
  a_sh <- .concl_stat(tests$shen$alpha);   if (is.na(a_sh)) a_sh <- alpha

  mz <- .concl_stat(tests$mz$statistic)
  qn <- .concl_stat(tests$qn$statistic)
  sh <- .concl_stat(tests$shen$statistic)

  list(
    list(name = "Maller–Zhou", stat = mz, threshold = a_mz,
         computable = !is.na(mz), sufficient = !is.na(mz) && mz < a_mz),
    list(name = "qn", stat = qn, threshold = qn_thr,
         computable = !is.na(qn),
         sufficient = !is.na(qn) && !is.na(qn_thr) && qn > qn_thr),
    list(name = "Shen", stat = sh, threshold = a_sh,
         computable = !is.na(sh), sufficient = !is.na(sh) && sh < a_sh)
  )
}

#' The fixed decision-string to banner-variant lookup (contract §J.8).
#'
#' An unrecognised decision string stops loudly rather than falling through to a
#' neutral banner: a verdict the app cannot name is a verdict it must not style.
.CONCL_REC_CLASS <- c(
  "Cure model appropriate"                    = "ca-rec--appropriate",
  "Cure model not supported"                  = "ca-rec--unsupported",
  "Follow-up insufficient for cure modeling"  = "ca-rec--insufficient"
)

.concl_rec_class <- function(decision) {
  if (is.null(decision) || length(decision) != 1L || is.na(decision) ||
      !(decision %in% names(.CONCL_REC_CLASS))) {
    stop("Unrecognised RECeUS decision string: ", paste(decision, collapse = " "))
  }
  unname(.CONCL_REC_CLASS[[decision]])
}

#' One condition tick in the recommendation banner (contract §J.8, R10).
.concl_cond <- function(label, met) {
  htmltools::div(
    class = "ca-rec__cond",
    # Glyph comes from CSS via data-ca-met; a unicode tick here doubled it.
    `data-ca-met` = if (isTRUE(met)) "true" else "false",
    htmltools::tags$span(label)
  )
}

#' One panel of the three-step strip.
#'
#' `state_word` is the `data-ca-state` attribute on `.ca-step`, one of
#' pending / pass / fail / void.
.concl_step <- function(marker, title, state_word, chip, body) {
  htmltools::div(
    class = "ca-step",
    `data-ca-state` = state_word,
    htmltools::div(class = "ca-step__marker", marker),
    htmltools::div(
      class = "ca-step__body",
      htmltools::h3(class = "ca-step__title", title),
      chip,
      body
    )
  )
}

#' The reproduce-in-R script (contract §J.9).
#'
#' Assembled with paste0() from `state$map`, `state$include_lognormal` and
#' `state$alpha`. It is a string the user can paste, not a computation: nothing
#' here is evaluated.
.concl_repro <- function(state) {
  map <- state$map
  time_col   <- if (!is.null(map$time)) map$time else "<time column>"
  status_col <- if (!is.null(map$status)) map$status else "<status column>"
  event_lvl  <- if (!is.null(map$event_level)) map$event_level else "<event level>"
  tscale     <- if (!is.null(map$time_scale)) map$time_scale else "none"
  label      <- if (!is.null(state$label)) state$label else "<your dataset>"
  lognorm    <- if (isTRUE(state$include_lognormal)) "TRUE" else "FALSE"
  alpha      <- .concl_alpha(state)

  lines <- c(
    "library(cureAssess)",
    "",
    paste0("# Dataset: ", label),
    paste0("# The app recodes the status column app-side before the package sees it:"),
    paste0("#   D <- as.integer(as.character(raw[[\"", status_col,
           "\"]]) == \"", event_lvl, "\")"),
    "# and drops rows with a missing time or status.",
    "",
    "dat <- prepare.surv.data(",
    "  data       = <your data frame, with the recoded 0/1 status>,",
    paste0("  time       = \"", time_col, "\","),
    paste0("  status     = \"", status_col, "\","),
    paste0("  time_scale = \"", tscale, "\""),
    ")",
    "",
    "res <- cure.appropriateness(",
    "  data              = dat,",
    "  time              = \"Y\",",
    "  status            = \"D\",",
    "  time_scale        = \"none\",",
    "  dist              = NULL,",
    "  plot_km           = TRUE,",
    "  run_tests         = \"yes\",",
    paste0("  include_lognormal = ", lognorm),
    ")",
    "",
    "res$final_recommendation",
    "res$tests$receus$decision",
    "res$screening$aic_table"
  )

  if (!isTRUE(all.equal(alpha, 0.05))) {
    lines <- c(
      lines, "",
      paste0("# Maller-Zhou and Shen re-run at the alpha you chose (",
             ca_num(alpha, 3), "):"),
      paste0("mz.test(dat, alpha = ", ca_num(alpha, 3), ")"),
      paste0("shen.test(dat, alpha = ", ca_num(alpha, 3), ")")
    )
  }

  paste(lines, collapse = "\n")
}


# ---- the downloadable report (spec §7, §4.4) --------------------------------
# FIXPASS: the downloadable HTML report was in scope (docs/shiny-app-spec.md §7,
# Definition-of-Done item 4) and was never built: this file had no
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
.concl_report_rmd <- function() {
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
.concl_ensure_pandoc <- function() {
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
.concl_report_filename <- function(label) {
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
#' or empty file. They get the spec's wording plus the verbatim message, in a
#' page that opens like any other.
.concl_report_failure_html <- function(msg) {
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
    "<p>The assessment on screen in the app is unchanged and still correct. ",
    "Only this download failed.</p>",
    "<p>The verbatim message was:</p><pre>", esc(msg), "</pre>",
    "<p>If the message mentions pandoc, the machine has R and rmarkdown but no pandoc ",
    "installed; installing pandoc, or running the app from RStudio, fixes it.</p>",
    "</body></html>"
  )
}


# ---- verbatim copy blocks (contract §J.8) -----------------------------------

#' The disagreement panel's standing text. Always visible, never collapsed.
.concl_disagree_body <- function() {
  htmltools::tags$p(
    htmltools::tags$strong("Disagreement is information, not a malfunction."),
    " These five diagnostics ask overlapping but different questions, and they were published by different authors to catch different failures. Do not count them and take the majority — they are not votes. Maller–Zhou and qn are the same underlying count presented two ways, so they always agree with each other and are never independent confirmation of one another. Shen uses a narrower window precisely because Maller–Zhou can over-declare sufficiency, so Maller–Zhou passing while Shen fails is Shen working as designed. RECeUS asks the identifiability question most directly, through r̂. When they split: check how close each statistic sits to its threshold, prefer the stricter test when the pattern is the known one, weigh r̂, and look back at the curve."
  )
}

#' "Follow-up looks insufficient — what now?" — the four routes.
.concl_options_body <- function() {
  htmltools::tagList(
    htmltools::tags$p(
      "This is not a dead end, and it is not a verdict on your data quality. It means the follow-up you have cannot separate “cured” from “not yet relapsed”, so a cure model would return a number that looks precise and is not identified. Four routes:"
    ),
    htmltools::tags$p(
      htmltools::tags$strong("1. Fit a non-cure model instead."),
      " The most common and usually the right answer. Standard survival models — Cox, Weibull, whatever fits — remain valid and interpretable; you simply do not report a cure fraction. You lose a quantity the data could not support anyway."
    ),
    htmltools::tags$p(
      htmltools::tags$strong("2. Use the extreme-value estimators of Escobar-Bach and Van Keilegom (2019)."),
      " Non-parametric cure-rate estimation designed specifically for insufficient follow-up, using extreme-value theory to extrapolate the tail rather than assuming the plateau is complete. Not implemented in cureAssess — you would fit this outside the app."
    ),
    htmltools::tags$p(
      htmltools::tags$strong("3. Use Yuen and Musta's relaxed condition (2024)."),
      " A weaker sufficient-follow-up requirement than the classical condition used by the tests here, so some datasets that fail the classical condition are still workable under theirs. Also outside this app."
    ),
    htmltools::tags$p(
      htmltools::tags$strong("4. Collect more follow-up."),
      " If the study is ongoing, or a later data cut exists, this is the only route that fixes the problem at source rather than working around it. It is worth taking seriously: Othus et al. refitted cure models on six SWOG trials at an early and a later follow-up time, found the mean-survival estimates shifted materially, and found the ",
      htmltools::tags$strong("direction of the shift was not predictable"),
      ". There is no post-hoc correction to apply — which is why this check happens before you fit, not after."
    ),
    htmltools::tags$p("References for 2, 3 and 4 are on the Documentation tab.")
  )
  # [SIGN-OFF: G] the ordering of the four routes and the "not implemented in
  # cureAssess" wording.
}


# =============================================================================
# UI
# =============================================================================

#' Conclusion tab UI: the three-step strip, the recommendation, the
#' disagreement panel, and the reproduce-in-R block.
mod_conclusion_ui <- function(id) {
  ns <- NS(id)

  htmltools::tagList(

    htmltools::div(
      class = "ca-section",
      htmltools::h2(class = "ca-section__title",
                    "The three-step check, in the published order"),
      htmltools::p(
        class = "ca-lede",
        "The tabs run Quantitative before Qualitative for workflow convenience. The order of checking is not the order of reasoning — below is the published order."
      ),
      uiOutput(ns("status_msg")),
      uiOutput(ns("banners"))
    ),

    htmltools::div(class = "ca-section", uiOutput(ns("step_strip"))),

    htmltools::div(class = "ca-section", uiOutput(ns("recommendation"))),

    htmltools::div(class = "ca-section", uiOutput(ns("package_says"))),

    htmltools::div(class = "ca-section", uiOutput(ns("disagree_panel"))),

    htmltools::div(class = "ca-section", uiOutput(ns("options_panel"))),

    htmltools::div(
      class = "ca-section",
      ca_card(
        title = "Reproduce this in R",
        lede = "Everything on this screen comes from these calls. Paste them into R to reproduce it.",
        body = verbatimTextOutput(ns("repro")),
        foot = ca_provenance("cure.appropriateness(run_tests = \"yes\")")
      )
    ),

    # FIXPASS: the download button and its handler did not exist. Spec §4.4
    # puts them at the bottom of this tab, after tests_reason.
    htmltools::div(
      class = "ca-section",
      ca_card(
        title = "Take this away",
        lede = "One self-contained HTML file: dataset and provenance, the data summary, the Kaplan-Meier curve with its risk table, the AIC table with its error column, all five diagnostics with their thresholds and the package's own words, the three-step verdict, and sessionInfo(). It opens offline and can be emailed.",
        body = htmltools::tagList(
          uiOutput(ns("download_ui")),
          uiOutput(ns("download_msg"))
        ),
        foot = ca_provenance("report/report.Rmd renders the same objects this screen shows")
      )
    ),

    htmltools::div(
      class = "ca-section",
      actionButton(ns("to_quant"), "Go to Quantitative →"),
      actionButton(ns("to_qual"), "Go to Qualitative →")
    )
  )
}


# =============================================================================
# SERVER
# =============================================================================

#' Conclusion tab server. Writes nothing to `state`.
mod_conclusion_server <- function(id, state, go_to) {
  moduleServer(id, function(input, output, session) {

    ca_on_click(input, "to_quant", function() go_to("quant"))
    ca_on_click(input, "to_qual", function() go_to("qual"))
    ca_on_click(input, "to_quant_empty", function() go_to("quant"))
    ca_on_click(input, "to_data_empty", function() go_to("data"))
    ca_on_click(input, "to_qual_step1", function() go_to("qual"))
    ca_on_click(input, "alpha_reset_link", function() go_to("quant"))

    # ---- empty and stale states (contract §J.10, Conclusion) ---------------

    output$status_msg <- renderUI({
      if (is.null(state$prepared)) {
        return(ca_empty(
          "There is no verdict yet. Start by preparing a dataset.",
          action_id = session$ns("to_data_empty"), action_label = "Go to Data →"
        ))
      }
      if (is.null(state$assess)) {
        txt <- if (identical(state$status, "data_loaded")) {
          "The dataset changed, so the previous verdict was cleared. Run the assessment again."
        } else {
          "Run the assessment on the Quantitative step to get a verdict. Step ① below is yours and you can answer it now."
        }
        return(ca_empty(
          txt,
          action_id = session$ns("to_quant_empty"),
          action_label = "Go to Quantitative →"
        ))
      }
      if (!isTRUE(state$assess$tests_run)) {
        return(htmltools::div(
          htmltools::h3("The diagnostics were not run"),
          htmltools::tags$p(state$assess$tests_reason),
          ca_empty(
            "Steps ② and ③ are not shown, because there is nothing to show.",
            action_id = session$ns("to_quant_empty"),
            action_label = "Go to Quantitative →"
          )
        ))
      }
      NULL
    })

    # ---- the two banners ---------------------------------------------------

    output$banners <- renderUI({
      out <- list()

      # Step 1 unticked: shown whenever there is anything below to qualify.
      if (!isTRUE(state$expert_confirmed) && !is.null(state$prepared)) {
        out <- c(out, list(ca_note(
          "warning",
          "Step 1 is still open",
          htmltools::tagList(
            htmltools::tags$p(
              "Steps 2 and 3 are shown below, but a cure model is only appropriate if all three steps pass. Step 1 is still open."
            ),
            actionButton(session$ns("to_qual_step1"),
                         "Answer step ① on Qualitative →")
          )
        )))
      }

      # Alpha moved off the package default.
      alpha <- .concl_alpha(state)
      if (!isTRUE(all.equal(alpha, 0.05))) {
        out <- c(out, list(ca_note(
          "info",
          "Shown at a non-default alpha",
          htmltools::tagList(
            htmltools::tags$p(paste0(
              "Steps shown at α = ", ca_num(alpha, 3),
              " for Maller–Zhou and Shen, and for the app-computed qn threshold. The package default is 0.05."
            )),
            actionLink(session$ns("alpha_reset_link"),
                       "Reset α on the Quantitative step →")
          )
        )))
      }

      if (!length(out)) return(NULL)
      do.call(htmltools::tagList, out)
    })

    # ---- the three-step strip, always in manuscript order -----------------

    output$step_strip <- renderUI({
      req(state$prepared)
      has <- ca_has_tests(state)
      im <- if (has) state$assess$tests$immune else NULL
      rc <- if (has) state$assess$tests$receus else NULL
      # `assess` exists but the package declined to run the diagnostics: say so
      # rather than implying a run is still pending (contract §J.10).
      not_run <- !is.null(state$assess) && !isTRUE(state$assess$tests_run)
      waiting <- if (not_run) {
        "The diagnostics were not run, so this step has nothing to report."
      } else {
        "Run the assessment on the Quantitative step."
      }

      # Step 1 — the user's checkbox and nothing else.
      step1 <- .concl_step(
        "①", "Expert judgment",
        if (isTRUE(state$expert_confirmed)) "pass" else "pending",
        if (isTRUE(state$expert_confirmed)) {
          ca_chip("pass", "Confirmed by user")
        } else {
          ca_chip("neutral", "Waiting on you")
        },
        htmltools::tagList(
          htmltools::tags$p(
            "Software cannot judge clinical plausibility. Is there a clinical reason to expect that some patients in this population are cured? This step is a conversation with a clinician, and this app will never answer it for you."
          ),
          if (isTRUE(state$expert_confirmed) &&
              !is.null(state$expert_note) && nzchar(state$expert_note)) {
            htmltools::tags$blockquote(htmltools::tags$p(state$expert_note))
          }
        )
      )

      # Step 2 — descriptive. Never a pass/fail chip (contract §L.12); the strip
      # state is "void" once rendered, meaning "this step returns no verdict".
      step2 <- if (is.null(im)) {
        .concl_step(
          "②", "Visual assessment",
          if (not_run) "void" else "pending",
          ca_chip("neutral", if (not_run) "Not available" else "Waiting on the assessment"),
          htmltools::tagList(
            htmltools::tags$p("This is a visual aid, not a test."),
            htmltools::tags$p(waiting)
          )
        )
      } else {
        .concl_step(
          "②", "Visual assessment", "void",
          if (isTRUE(im$last_observation_censored)) {
            ca_chip("neutral", "Plateau possible")
          } else {
            ca_chip("neutral", "No clear plateau")
          },
          htmltools::tagList(
            htmltools::tags$p("This is a visual aid, not a test."),
            htmltools::tags$blockquote(htmltools::tags$p(im$interpretation)),
            ca_provenance("cure.appropriateness() -> $tests$immune$last_observation_censored")
          )
        )
      }

      # Step 3 — the RECeUS decision, verbatim.
      step3 <- if (is.null(rc) || is.null(rc$decision)) {
        .concl_step(
          "③", "Quantitative assessment",
          if (not_run) "void" else "pending",
          ca_chip("neutral", if (not_run) "Not available" else "Waiting on the assessment"),
          htmltools::tags$p(waiting)
        )
      } else {
        .concl_step(
          "③", "Quantitative assessment",
          if (identical(rc$decision, "Cure model appropriate")) "pass" else "fail",
          ca_chip(
            if (identical(rc$decision, "Cure model appropriate")) "pass" else "fail",
            rc$decision
          ),
          ca_provenance("cure.appropriateness() -> $tests$receus$decision")
        )
      }

      htmltools::div(class = "ca-steps", step1, step2, step3)
    })

    # ---- the recommendation ------------------------------------------------

    output$recommendation <- renderUI({
      req(ca_has_tests(state))
      rc <- state$assess$tests$receus
      req(!is.null(rc), !is.null(rc$decision))

      variant <- .concl_rec_class(rc$decision)
      pi_hat <- .concl_stat(rc$pi_hat)
      r_hat  <- .concl_stat(rc$r_hat)
      tau    <- .concl_stat(rc$tau)

      fu <- .concl_followup(state)
      m <- sum(vapply(fu, function(x) isTRUE(x$computable), logical(1)))
      k <- sum(vapply(fu, function(x) isTRUE(x$sufficient), logical(1)))
      tally <- paste0(
        "Of the three follow-up tests, ", k, " of ", m,
        " computable tests indicated sufficient follow-up"
      )
      tally <- if (m < 3L) {
        paste0(tally, "; the other ", 3L - m,
               " could not be computed on this dataset.")
      } else {
        paste0(tally, ".")
      }

      htmltools::div(
        class = paste("ca-rec", variant),

        # The decision string is the headline, verbatim and in the largest type
        # on the tab. The app does not paraphrase a package verdict.
        htmltools::div(class = "ca-rec__decision", rc$decision),

        htmltools::div(
          class = "ca-rec__conditions",
          .concl_cond(
            paste0("π̂ = ", ca_num(pi_hat, 4), " > 0.025"),
            isTRUE(rc$cure_fraction_condition)
          ),
          .concl_cond(
            paste0("r̂ = ", ca_num(r_hat, 4), " < 0.05"),
            isTRUE(rc$followup_condition)
          )
        ),

        htmltools::tags$p(paste0(
          "Evaluated at τ = ", ca_num(tau, 4), ", the largest observed time."
        )),

        # A tally of chips already on screen. Not a score, and not weighted.
        htmltools::tags$p(class = "ca-key", tally),
        htmltools::tags$p(
          class = "ca-lede",
          "That line counts chips you have already seen on the Quantitative tab. It is not a composite score, the tests are not weighted, and a majority does not decide anything."
        ),
        ca_provenance("cure.appropriateness() -> $tests$receus$pi_hat, $r_hat, $decision")
      )
    })

    # ---- what the package says ---------------------------------------------

    output$package_says <- renderUI({
      req(state$assess)
      ca_card(
        title = "What the package says",
        body = htmltools::tagList(
          htmltools::tags$blockquote(
            htmltools::tags$p(state$assess$final_recommendation)
          ),
          htmltools::tags$p(
            class = "ca-lede",
            "This sentence summarises the model comparison only — it does not mention RECeUS, π̂ or r̂. The RECeUS recommendation is step ③ above."
          ),
          ca_tech(htmltools::tags$p(state$assess$tests_reason))
        ),
        foot = ca_provenance("cure.appropriateness() -> $final_recommendation, $tests_reason")
      )
    })

    # ---- the diagnostics-can-disagree panel --------------------------------
    # Always visible, never collapsed. The lead line is assembled at runtime
    # from the chips on screen (contract §J.0 / §L.13) — never from a docs table.

    output$disagree_panel <- renderUI({
      req(ca_has_tests(state))
      fu <- .concl_followup(state)
      rc <- state$assess$tests$receus
      r_hat <- .concl_stat(rc$r_hat)

      rows <- fu
      if (!is.na(r_hat)) {
        rows <- c(rows, list(list(
          name = "RECeUS", computable = TRUE,
          sufficient = isTRUE(rc$followup_condition)
        )))
      }
      computable <- Filter(function(x) isTRUE(x$computable), rows)
      yes <- vapply(Filter(function(x) isTRUE(x$sufficient), computable),
                    function(x) x$name, character(1))
      no  <- vapply(Filter(function(x) !isTRUE(x$sufficient), computable),
                    function(x) x$name, character(1))

      lead <- if (length(yes) && length(no)) {
        htmltools::tags$p(
          htmltools::tags$strong("On this dataset the diagnostics disagree."),
          paste0(" ", paste(yes, collapse = ", "),
                 " indicate sufficient follow-up; ",
                 paste(no, collapse = ", "),
                 " do not. This is expected — read on.")
        )
      } else {
        NULL
      }

      ca_card(
        title = "The diagnostics can disagree",
        lede = "Five diagnostics, five questions. They are descriptive aids to be read with subject-matter knowledge, not a single decision rule, and the thresholds 0.05, 0.025 and the r̂ cut-off are conventions rather than laws.",
        body = htmltools::tagList(
          lead,
          .concl_disagree_body(),
          htmltools::h4("Worked illustration — gbsg, the disagreement case"),
          .qual_worked_reading("gbsg", parts = c("numbers", "extra")),
          htmltools::h4("Worked illustration — colon (Lev+5FU), the borderline case"),
          .qual_worked_reading("colon", parts = c("numbers", "extra"))
        )
      )
    })

    # ---- "follow-up looks insufficient — what now?" ------------------------

    output$options_panel <- renderUI({
      req(ca_has_tests(state))
      decision <- state$assess$tests$receus$decision
      open <- identical(decision, "Follow-up insufficient for cure modeling")
      bslib::accordion(
        open = open,
        bslib::accordion_panel(
          "The diagnostics say follow-up is insufficient. What are my options?",
          .concl_options_body()
        )
      )
    })

    # ---- reproduce in R ----------------------------------------------------

    output$repro <- renderText({
      req(state$prepared)
      .concl_repro(state)
    })

    # ---- the downloadable HTML report --------------------------------------
    # FIXPASS: there was no downloadButton and no downloadHandler on this tab,
    # and report/report.Rmd did not exist. Spec §7 and §4.4, Definition-of-Done
    # item 4. This writes nothing to `state` — the failure message is a local
    # reactiveVal, so a failed download leaves the verdict on screen untouched.

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
        htmltools::tags$p(
          class = "ca-lede",
          "The report is available once an assessment has run. Run it on the Quantitative step."
        )
      )
    })

    output$download_msg <- renderUI({
      msg <- report_error()
      if (is.null(msg)) return(NULL)
      ca_note(
        "warning", "The report could not be generated",
        htmltools::tagList(
          htmltools::tags$p(
            "The report could not be generated. The verdict on this screen is unchanged — only the download failed."
          ),
          ca_tech(htmltools::tags$p(msg), title = "The verbatim message")
        )
      )
    })

    output$download_report <- downloadHandler(
      filename = function() .concl_report_filename(state$label),
      content = function(file) {
        report_error(NULL)

        ok <- tryCatch({
          rmd <- .concl_report_rmd()
          if (is.na(rmd)) {
            stop("report/report.Rmd could not be found from the working directory ",
                 getwd(), ". Run the app from the repository root with ",
                 "shiny::runApp(\"app\") so that report/ is a sibling of app/.")
          }
          if (!.concl_ensure_pandoc()) {
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
                # FIXPASS (reverifier): was `assess = state$assess`, which is the
                # assessment at the PACKAGE-DEFAULT alpha. When the user has moved
                # the alpha slider, `state$alpha_tests` holds Maller-Zhou and Shen
                # recomputed at the chosen alpha, and those are the objects the
                # Quantitative and Conclusion screens show. The downloaded report
                # showed the package-default ones instead, so a report taken at a
                # non-default alpha disagreed with the screen it was taken from.
                # `.concl_tests()` is the module's existing merge (it replaces
                # $mz and $shen only, and leaves qn alone because qn.test() has no
                # alpha argument); splicing its result back into $tests fixes the
                # drift without adding a ninth param, and the report keeps reading
                # alpha off $tests$mz$alpha / $tests$shen$alpha as it already does.
                # R1 is untouched: these are still package objects from
                # cureAssess::mz.test() and cureAssess::shen.test().
                assess            = .concl_report_assess(state),
                include_lognormal = isTRUE(state$include_lognormal),
                expert_confirmed  = isTRUE(state$expert_confirmed)
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
        # empty file: the user gets the spec's wording and the verbatim message.
        if (!isTRUE(ok)) {
          writeLines(
            .concl_report_failure_html(report_error()),
            con = file, useBytes = TRUE
          )
        }
        invisible(NULL)
      }
    )

    invisible(NULL)
  })
}
