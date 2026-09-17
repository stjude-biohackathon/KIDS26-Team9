# =============================================================================
# mod_v3_canvas.R — the follow-up timeline and the four Assess panels.
#                                                     V2_CONTRACT §G.2, builder-v3
#
# Under the pinned strip, full-bleed, the follow-up timeline. Then a 2x2 grid of
# panels whose headings are QUESTIONS, not nouns — they cost nothing and carry a
# non-expert through four panels without a glossary:
#
#   1  Does the curve flatten out?     tall, left     Kaplan-Meier + tail band
#   2  Is follow-up long enough?       top right      two threshold tracks (S9)
#   3  Is the cured group real?        bottom right   the plane + the tau slider
#   4  Which model fits best?          full width     the dot plot + the table
#
# Every picture is one of the four shared chart builders in ../app/R/theme.R.
# This file draws; it decides nothing.
#
# FIELD PROVENANCE (comments only, never on screen — C1):
#   state$fit$kmplot                      survminer::ggsurvplot(), from model.fitting()
#   $tests$immune$last_observation_censored  read via ca_last_obs_censored()  (S10)
#   $tests$immune$p_hat                      read via ca_tail_level() as 1 - p_hat
#   $tests$qn$statistic / $interpretation
#   $tests$mz$statistic / $alpha          the companion reading of S9
#   $tests$shen$statistic / $alpha / $interpretation
#   $tests$receus$pi_hat / $r_hat / $decision / $interpretation
#   $screening$aic_table / $best_model / $best_model_type / $initial_decision
#   $selected_receus_dist                 S3 — read, never re-derived
# =============================================================================


# ---- private constants ------------------------------------------------------

# The not-computable line, verbatim, so the screen and the batch CSV say the
# same thing. CA_VOID_LINE is theme.R's copy of the same sentence.
.V3_VOID_LINE <- "Cannot be computed: the longest observed time is an event."
.V3_VOID_RECEUS <- "Cannot be computed: the model behind this number did not converge."
.V3_EXPLORE_BANNER <- "This is an exploration. The verdict above is unchanged."

# The five generic plateau-reading bullets, demoted to a disclosure: they are
# instruction, not evidence.
.V3_PLATEAU_BULLETS <- c(
  "The curve stops stepping down and runs flat.",
  "The flat stretch covers a real share of the follow-up, not just the last moment.",
  "Few or no events fall inside it.",
  "Plenty of people are still being followed there — check the table under the plot.",
  "Heavy censoring alone can flatten a curve, so flatness on its own proves nothing."
)


# ---- private helpers --------------------------------------------------------

#' One canvas panel: a question as its heading, and its contents.
#' @noRd
.v3_panel <- function(title, ..., class = NULL, chip = NULL) {
  htmltools::tags$section(
    class = paste(c("v3-panel", class), collapse = " "),
    htmltools::tags$header(
      class = "v3-panel__head",
      htmltools::h2(class = "v3-panel__title", title),
      chip
    ),
    htmltools::div(class = "v3-panel__body", ...)
  )
}

#' Evaluation times for the tau control: an axis, not an estimate.
#'
#' An evenly spaced ladder of at most 25 candidate evaluation times from the
#' median observed time to the largest observed time, which is the value the
#' cured-group reading uses by default. The median is one of the descriptives
#' rule S1 permits.
#' @noRd
.v3_tau_grid <- function(y, k = 25L) {
  y <- y[is.finite(y) & y > 0]
  if (length(y) < 2L) return(numeric(0))
  hi <- max(y); lo <- stats::median(y)
  if (!(hi > lo)) lo <- hi / 2
  if (!(hi > lo)) return(hi)
  g <- unique(seq(from = lo, to = hi, length.out = min(as.integer(k), 25L)))
  g[is.finite(g)]
}

#' Put the shaded follow-up band behind the package's own Kaplan-Meier figure.
#'
#' `ca_style_survplot()` repaints the curve and its risk table into the app's
#' palette without recomputing anything; the band layers are prepended to
#' `$layers` so the shading sits behind the curve rather than washing over it.
#' The dotted level line is drawn with NO label: it marks the height the curve
#' settles at, and no statistic is printed beside it.
#' @noRd
.v3_annotate_km <- function(sp, prepared, level = NA_real_, dark = FALSE) {
  if (is.null(sp) || is.null(sp$plot)) return(sp)
  sp <- ca_style_survplot(sp, dark)
  p <- sp$plot

  # Two removals, both about repetition rather than statistics. The figure's own
  # title repeats the panel heading immediately above it, and a one-group
  # survival figure carries a legend whose only key reads "All". Neither changes
  # a single drawn value.
  p <- p + ggplot2::labs(title = NULL, subtitle = NULL) +
    ggplot2::theme(legend.position = "none")

  facts <- ca_tail_facts(prepared)              # helpers.R F.2, descriptives only
  if (!is.null(facts) && isTRUE(is.finite(facts$last_event)) &&
      isTRUE(is.finite(facts$max_time)) && !isTRUE(facts$zero_width)) {
    layers <- ca_followup_tail(facts$last_event, facts$max_time, dark,
                               min_time = 0, label = "follow-up tail")
    if (length(layers)) {
      behind  <- layers[seq_len(min(2L, length(layers)))]
      infront <- if (length(layers) > 2L) layers[-seq_len(2L)] else list()
      p$layers <- c(behind, p$layers)
      for (lyr in infront) p <- p + lyr
    }
  }
  if (is.numeric(level) && length(level) == 1L && is.finite(level)) {
    for (lyr in ca_level_line(level, dark, label = NULL)) p <- p + lyr
  }
  sp$plot <- p
  sp
}

#' Display name for a model key, with the shared fallback idiom.
#' @noRd
.v3_model_label <- function(key) {
  if (is.null(key) || length(key) < 1L || is.na(key[[1L]])) return(NULL)
  key <- as.character(key[[1L]])
  lab <- unname(CA_MODEL_LABELS[key])
  if (is.na(lab)) key else lab
}

#' Chip variant for a cured-group decision string.
#'
#' Fixed lookup; an unrecognised string stops loudly rather than falling through
#' to a neutral chip, because a silently-neutral verdict is worse than a crash.
#' @noRd
.v3_receus_variant <- function(decision) {
  switch(as.character(decision),
         "Cure model appropriate" = "pass",
         "Cure model not supported" = "fail",
         "Follow-up insufficient for cure modeling" = "fail",
         stop("Unrecognised RECeUS decision string: ", decision, call. = FALSE))
}

#' A plain bullet list, or nothing.
#' @noRd
.v3_bullets <- function(items) {
  if (!length(items)) return(NULL)
  htmltools::tags$ul(class = "v3-bullets", lapply(items, htmltools::tags$li))
}


# =============================================================================
# UI
# =============================================================================

mod_v3_canvas_ui <- function(id) {
  ns <- NS(id)

  htmltools::div(
    class = "v3-canvas__inner",

    # ---- full-bleed: where the last event sits inside follow-up ------------
    # One word of label, because an unlabelled bar of numbers is a puzzle to
    # anyone meeting it cold, and the caption underneath does the rest.
    htmltools::div(
      class = "v3-timeline",
      htmltools::div(class = "v3-timeline__eyebrow", "Follow-up"),
      uiOutput(ns("timeline"))
    ),

    uiOutput(ns("gate")),

    htmltools::div(
      class = "v3-grid",

      # ---- 1. the curve ---------------------------------------------------
      .v3_panel(
        "Does the curve flatten out?",
        class = "v3-panel--curve",
        # height = "100%": the curve panel spans both rows of the grid, so its
        # box is as tall as the two panels beside it. Letting the figure take
        # that height uses the space instead of leaving a void under the
        # captions. The CSS gives the container a floor so the plot is never
        # asked to draw itself at zero.
        htmltools::div(class = "ca-plot", plotOutput(ns("km"), height = "100%")),
        uiOutput(ns("plateau")),
        uiOutput(ns("curve_facts")),
        htmltools::tags$details(
          class = "v3-fold",
          htmltools::tags$summary("How to spot a plateau"),
          htmltools::div(class = "v3-fold__body", .v3_bullets(.V3_PLATEAU_BULLETS))
        )
      ),

      # ---- 2. the two threshold tracks (never three — S9) -----------------
      .v3_panel(
        "Is follow-up long enough?",
        class = "v3-panel--tracks",
        uiOutput(ns("tracks"))
      ),

      # ---- 3. the cured-group plane, with the evaluation time beneath -----
      .v3_panel(
        "Is the cured group real?",
        class = "v3-panel--plane",
        uiOutput(ns("plane_head")),
        htmltools::div(class = "ca-plot", plotOutput(ns("plane"), height = "360px")),
        htmltools::div(
          class = "v3-dial",
          sliderInput(ns("tau_idx"), "Evaluation time (earliest to latest)",
                      min = 1, max = 25, value = 25, step = 1, ticks = FALSE,
                      width = "100%"),
          uiOutput(ns("tau_label")),
          htmltools::p(class = "ca-provenance", .V3_TAU_CAVEAT)
        ),
        uiOutput(ns("plane_tech"))
      ),

      # ---- 4. model comparison --------------------------------------------
      .v3_panel(
        "Which model fits best?",
        class = "v3-panel--models",
        uiOutput(ns("best_line")),
        htmltools::div(class = "ca-plot", plotOutput(ns("aic_dots"), height = "300px")),
        htmltools::tags$details(
          class = "v3-fold",
          htmltools::tags$summary("Every candidate, as a table"),
          htmltools::div(class = "v3-fold__body", DT::DTOutput(ns("aic_table")))
        ),
        uiOutput(ns("models_tech"))
      )
    )
  )
}


# =============================================================================
# SERVER
# =============================================================================

#' @param receus_dist a reactive returning the shape override from the control
#'   pane, `""` for "the one the assessment selected" (S3).
mod_v3_canvas_server <- function(id, state, receus_dist = shiny::reactive("")) {
  moduleServer(id, function(input, output, session) {

    ns <- session$ns

    # ---- the test list every panel reads ---------------------------------
    # Canonical = state$assess$tests, with the alpha-recomputed follow-up
    # readings merged over it, because alpha is a genuine argument of those two
    # package functions. Nothing else overrides a panel.
    tests_r <- reactive({
      if (!ca_has_tests(state)) return(NULL)
      base <- state$assess$tests
      at <- state$alpha_tests
      if (is.null(at)) return(base)
      if (!is.null(at$mz)) base$mz <- at$mz
      if (!is.null(at$shen)) base$shen <- at$shen
      base
    })

    # ---- the follow-up timeline, full bleed ------------------------------
    output$timeline <- renderUI({
      req(state$prepared)
      f <- ca_tail_facts(state$prepared)         # helpers.R F.2
      if (is.null(f)) return(NULL)
      unit <- if (identical(state$map$time_scale, "days_to_years")) "years" else NULL
      ca_viz_timeline(                            # theme.R F.4.1
        last_event = f$last_event, max_time = f$max_time,
        gap_pct = f$gap_pct, n_cens_after = f$n_cens_after,
        zero_width = f$zero_width, unit = unit
      )
    })

    # ---- the one gate, and the one failure surface -----------------------
    output$gate <- renderUI({
      if (is.null(state$prepared)) {
        return(ca_empty("Choose a dataset in the Dataset section on the left."))
      }
      if (is.null(state$assess) && !is.null(state$last_error)) {
        # §B.7 — a package failure is a normal outcome. No sentence names the
        # package; the raw text sits in the technical disclosure.
        return(ca_note(
          "warning", "The models could not be fitted for this dataset.",
          ca_tech(htmltools::tags$pre(class = "ca-mono", state$last_error))
        ))
      }
      if (!is.null(state$assess) && !isTRUE(state$assess$tests_run)) {
        return(ca_note(
          "warning", "The follow-up and cured-group readings were not run.",
          ca_tech(htmltools::p(state$assess$tests_reason))   # $tests_reason
        ))
      }
      NULL
    })

    # =====================================================================
    # PANEL 1 — the curve
    # =====================================================================

    output$km <- renderPlot({
      req(state$prepared)
      sp <- state$fit$kmplot
      req(!is.null(sp))
      # $tests$immune$p_hat, read as 1 - p_hat by ca_tail_level(). Drawn as an
      # unlabelled rule: no statistic is printed beside it (S10).
      level <- if (ca_has_tests(state)) ca_tail_level(state$assess$tests$immune) else NA_real_
      ann <- try(.v3_annotate_km(sp, state$prepared, level, isTRUE(state$dark)), silent = TRUE)
      suppressMessages(print(if (inherits(ann, "try-error")) sp else ann))
    }, res = 108, bg = "transparent",
       alt = "Kaplan-Meier survival curve for the prepared dataset, with the follow-up tail after the last event shaded.")

    # A statement about the data: always the neutral chip, never a pass, never
    # a fail, and nothing is printed beside it (S10).
    output$plateau <- renderUI({
      req(state$prepared)
      censored <- ca_last_obs_censored(state)      # helpers.R N.2
      label <- if (isTRUE(censored)) {
        "The last observed time is censored, so a plateau is possible"
      } else if (identical(censored, FALSE)) {
        "The last observed time is an event, so there is no clear plateau"
      } else {
        return(NULL)
      }
      ca_chip("neutral", label)
    })

    # The figure's own captions: between one and three finished sentences,
    # generated from descriptive quantities only.
    output$curve_facts <- renderUI({
      req(state$prepared)
      facts <- ca_tail_facts(state$prepared)       # helpers.R F.2
      sm    <- ca_data_summary(state$prepared)     # helpers.R F.1
      out <- character(0)
      no_tail <- is.null(facts) || isTRUE(facts$zero_width)

      if (!no_tail) {
        level <- if (ca_has_tests(state)) ca_tail_level(state$assess$tests$immune) else NA_real_
        if (length(level) == 1L && is.finite(level)) {
          out <- c(out, paste0("The curve settles near ", ca_num(level, 2),
                               " after ", ca_num(facts$last_event, 2),
                               " and stays there to ", ca_num(facts$max_time, 2), "."))
        }
        # One decimal place, not none: the timeline's own caption directly above
        # this panel prints the same share to one place, and two roundings of one
        # number a few hundred pixels apart read as a contradiction.
        out <- c(out, paste0(ca_pct(facts$gap_pct / 100, 1),
                             " of the follow-up comes after the last event, with ",
                             format(facts$n_cens_after),
                             " people still being followed in it."))
      }
      out <- c(out, paste0(format(sm$events), " of ", format(sm$n),
                           " people had the event, and ",
                           ca_pct(sm$censored_pct / 100, 0), " were censored."))
      if (no_tail) {
        out <- c(out, "The longest follow-up time is an event, so there is no flat stretch to read.")
      }
      .v3_bullets(out)
    })

    # =====================================================================
    # PANEL 2 — two threshold tracks, never three (S9)
    # =====================================================================

    output$tracks <- renderUI({
      tt <- tests_r()
      if (is.null(tt) || is.null(state$prepared)) {
        return(ca_empty("Available once an assessment has run."))
      }

      qn   <- tt$qn                                # $tests$qn$statistic
      mz   <- tt$mz                                # $tests$mz$statistic, $alpha
      shen <- tt$shen                              # $tests$shen$statistic, $alpha
      n    <- nrow(state$prepared)
      # S1 — the single closed form the app is permitted to evaluate.
      thr  <- ca_qn_threshold(n, state$alpha)      # helpers.R F.4

      qn_stat <- if (is.null(qn)) NA_real_ else qn$statistic
      mz_stat <- if (is.null(mz)) NA_real_ else mz$statistic
      mz_a    <- if (is.null(mz)) NA_real_ else mz$alpha

      # S9 — the two readings are algebraically the same test, so the companion
      # is one sentence under the first track, never a second vote.
      companion <- if (is.finite(mz_stat) && is.finite(mz_a)) {
        paste0("The companion reading is ", ca_num(mz_stat, 4), " against ",
               ca_num(mz_a, 3), " on its own scale — the same test, ",
               "expressed the other way round.")
      } else NULL

      htmltools::tagList(
        # Track 1: qn. LARGER is better (S8).
        ca_viz_threshold_track(                    # theme.R F.4.2
          stat = qn_stat, threshold = thr, larger_is_better = TRUE,
          label = "Is there enough follow-up after the last event?",
          companion_line = companion, void_line = .V3_VOID_LINE
        ),
        # Track 2: Shen, its own scale and its own direction. SMALLER is better.
        ca_viz_threshold_track(
          stat = if (is.null(shen)) NA_real_ else shen$statistic,
          threshold = if (is.null(shen)) NA_real_ else shen$alpha,
          larger_is_better = FALSE,
          label = "Does a second reading agree?",
          void_line = .V3_VOID_LINE
        ),
        if (!is.null(state$alpha_tests)) ca_banner(.V3_EXPLORE_BANNER, "override"),
        ca_tech(htmltools::tagList(
          htmltools::p(class = "ca-tech__body", if (is.null(qn)) NULL else qn$interpretation),
          htmltools::p(class = "ca-tech__body", if (is.null(mz)) NULL else mz$interpretation),
          htmltools::p(class = "ca-tech__body", if (is.null(shen)) NULL else shen$interpretation)
        ))
      )
    })

    # =====================================================================
    # PANEL 3 — the cured-group plane, and the evaluation time beneath it
    # =====================================================================

    tau_grid_r <- reactive({
      if (is.null(state$prepared)) return(numeric(0))
      .v3_tau_grid(state$prepared$Y)               # prepare.surv.data() column Y
    })

    observeEvent(tau_grid_r(), {
      k <- max(length(tau_grid_r()), 1L)
      updateSliderInput(session, "tau_idx", max = k, value = k)
    }, ignoreInit = FALSE)

    tau_value_r <- reactive({
      g <- tau_grid_r(); i <- input$tau_idx
      if (!length(g) || is.null(i) || !is.finite(i)) return(NA_real_)
      g[[max(1L, min(length(g), as.integer(i)))]]
    })

    # Only the cheap triggers are debounced (§B.1 reactive 5, 250 ms).
    tau_idx_d <- debounce(reactive(input$tau_idx), 250)
    dist_d    <- debounce(reactive({
      d <- receus_dist()
      if (is.null(d)) "" else as.character(d)
    }), 250)

    # Is the reader exploring, or looking at the assessment itself?
    exploring_r <- reactive({
      g <- tau_grid_r()
      moved <- length(g) > 0L && !is.null(tau_idx_d()) &&
        as.integer(tau_idx_d()) != length(g)
      isTRUE(moved) || (nzchar(dist_d()))
    })

    # The exploration result. DISPLAY ONLY: it never writes state$assess, never
    # reaches ca_recommendation() and never reaches the report (§B.1).
    tau_r <- reactive({
      if (!isTRUE(exploring_r())) return(NULL)
      if (is.null(state$prepared) || !ca_has_tests(state)) return(NULL)
      d <- dist_d()
      if (!nzchar(d)) d <- state$assess$selected_receus_dist   # S3
      if (is.null(d) || !nzchar(d)) return(NULL)
      ca_receus_at_tau(state$prepared, d, isolate(tau_value_r()))  # §F.3
    })

    observeEvent(tau_r(), { state$tau_result <- tau_r() }, ignoreNULL = FALSE)

    # The pair of numbers the plane draws: the exploration when one is running,
    # the assessment otherwise.
    plane_values_r <- reactive({
      ex <- tau_r()
      if (!is.null(ex)) {
        return(list(pi = ex$pi_hat, r = ex$r_hat, decision = ex$decision,
                    interpretation = ex$interpretation, explored = TRUE))
      }
      tt <- tests_r()
      if (is.null(tt) || is.null(tt$receus)) return(NULL)
      rc <- tt$receus                              # $tests$receus$*
      list(pi = rc$pi_hat, r = rc$r_hat, decision = rc$decision,
           interpretation = rc$interpretation, explored = FALSE)
    })

    output$plane_head <- renderUI({
      v <- plane_values_r()
      if (is.null(v)) return(ca_empty("Available once an assessment has run."))
      void <- !is.finite(v$pi) || !is.finite(v$r)
      htmltools::tagList(
        if (void) ca_chip("void", "Cannot be computed", glyph = "dash")
        else ca_chip(.v3_receus_variant(v$decision), v$decision),
        htmltools::div(
          class = "v3-kv",
          ca_kv("share never having the event",
                if (void) ca_dash() else ca_num(v$pi)),
          ca_kv("censored uncured, as a ratio",
                if (void) ca_dash() else ca_num(v$r))
        ),
        if (void) htmltools::p(class = "ca-provenance", .V3_VOID_RECEUS),
        if (isTRUE(v$explored)) ca_banner(.V3_EXPLORE_BANNER, "override")
      )
    })

    output$plane <- renderPlot({
      v <- plane_values_r()
      req(!is.null(v))
      p <- ca_viz_receus_plane(v$pi, v$r, extra = NULL, dark = isTRUE(state$dark))
      req(!is.null(p))
      p
      # res = 92, not the 108 every other figure here uses, and deliberately.
      # The shared plane direct-labels its dot to the RIGHT of the dot, and a
      # dataset whose ratio sits near the top of the axis — gbsg at 0.308 of an
      # 0.36 axis — pushes that label off the panel, where ggplot2 clips it.
      # Dropping the resolution shrinks the label relative to the panel and it
      # fits. The proper fix is in the shared chart builder (flip the label's
      # justification once the dot passes ~70% of the axis); that file belongs
      # to builder-shell and is not edited here. See the handoff note.
    }, res = 92, bg = "transparent",
       alt = "The estimated cure fraction plotted against the uncured censored ratio, with the region that supports a cure model shaded.")

    output$tau_label <- renderUI({
      tv <- tau_value_r()
      if (!is.finite(tv)) return(NULL)
      unit <- if (identical(state$map$time_scale, "days_to_years")) " years" else ""
      htmltools::p(class = "v3-dial__read",
                   htmltools::span(class = "ca-num", ca_num(tv, 3)), unit)
    })

    output$plane_tech <- renderUI({
      v <- plane_values_r()
      if (is.null(v) || is.null(v$interpretation)) return(NULL)
      ca_tech(htmltools::p(class = "ca-tech__body", v$interpretation))
    })

    # =====================================================================
    # PANEL 4 — model comparison
    # =====================================================================

    output$best_line <- renderUI({
      if (is.null(state$assess)) return(ca_empty("Available once an assessment has run."))
      lab <- .v3_model_label(state$assess$screening$best_model)   # $screening$best_model
      if (is.null(lab)) return(htmltools::p("No model could be fitted to these data."))
      htmltools::p(class = "v3-best",
                   htmltools::strong("Best fit: "), paste0(lab, "."))
    })

    output$aic_dots <- renderPlot({
      req(state$assess)
      p <- ca_viz_aic_dots(                        # theme.R F.4.4
        state$assess$screening$aic_table,          # $screening$aic_table
        best = state$assess$screening$best_model,
        dark = isTRUE(state$dark)
      )
      req(!is.null(p))
      p
    }, res = 108, bg = "transparent",
       alt = "Model comparison scores, one dot per candidate model, smaller to the left; a filled dot allows a cured group and a hollow ring does not.")

    output$aic_table <- DT::renderDT({
      req(state$assess)
      tbl <- state$assess$screening$aic_table

      disp <- data.frame(
        # USE.NAMES = FALSE: a character input would otherwise name the result
        # and data.frame() would take those names as row names.
        model = vapply(tbl$model, function(x) {
          lab <- .v3_model_label(x); if (is.null(lab)) as.character(x) else lab
        }, character(1), USE.NAMES = FALSE),
        type = vapply(tbl$model_type,
                      function(x) as.character(ca_chip("neutral", x)), character(1), USE.NAMES = FALSE),
        AIC = vapply(tbl$AIC, function(x) ca_num(x, 2), character(1)),
        # UPSTREAM QUIRK: a one-parameter fit arrives with its parameter name
        # dropped, as the orphan string "=0.1416". The dangling "=" is stripped;
        # no number is altered.
        parameter_estimates = vapply(tbl$parameter_estimates, function(x) {
          if (is.na(x)) return(ca_dash())
          sub("^=", "", as.character(x))
        }, character(1)),
        error = vapply(tbl$error, function(x) {
          if (!nzchar(x)) ca_dash() else as.character(x)
        }, character(1)),
        stringsAsFactors = FALSE
      )
      # Hidden sort key: the row order the package returned, AIC ascending with
      # the missing rows last, so em-dash cells never sort lexically and failed
      # fits stay at the bottom (S4). The error column stays visible and no row
      # is ever filtered.
      disp$.aic_order <- seq_len(nrow(disp))

      DT::datatable(
        disp, rownames = FALSE, selection = "none", escape = -2,
        colnames = c("Model", "Type", "AIC", "Parameters", "Problem", "order"),
        class = "compact stripe hover",
        options = list(
          dom = "t", paging = FALSE, ordering = TRUE, scrollX = TRUE,
          autoWidth = FALSE, order = list(list(2L, "asc")),
          columnDefs = list(
            list(targets = 5L, visible = FALSE, searchable = FALSE),
            list(targets = 2L, orderData = 5L, className = "dt-right"),
            list(targets = 3L, className = "ca-mono")
          )
        )
      )
    })

    output$models_tech <- renderUI({
      if (is.null(state$assess)) return(NULL)
      ca_tech(htmltools::p(class = "ca-tech__body",
                           state$assess$screening$initial_decision))  # $screening$initial_decision
    })

    invisible(NULL)
  })
}
