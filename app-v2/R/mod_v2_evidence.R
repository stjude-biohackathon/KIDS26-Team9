# =============================================================================
# app-v2/R/mod_v2_evidence.R — sections 3, 4 and 5 of the column, plus the
# many-datasets view.                                     owner: builder-v2
#
# §G.1, in the order a sceptic asks:
#   3  Does the curve flatten?      the Kaplan-Meier figure, full-bleed
#   4  Which model fits best?       the comparison dot plot, table beneath it
#   5  Do the diagnostics agree?    two threshold tracks, then the plane
#
# This module also owns the assessment half of the auto-compute contract
# (V2_CONTRACT §B.1 reactive 2, coded as §B.3). There is no Run button:
#
#   state$prepared or the candidate set changes
#     -> tryCatch(withProgress(ca_assess_once(...)))     S7, and §B.4's ONE
#        cure.appropriateness() call site, which lives in app/R/helpers.R
#     -> state$assess, or a NULL assessment with the raw text kept for the
#        technical disclosure (§B.7)
#
# Reactives 4 (the significance level) and 5 (the evaluation time and the
# distribution override) are DISPLAY ONLY. They never write state$assess, never
# reach ca_recommendation() and never reach the report (§B.1, R8). The
# permanent caveat line under the evaluation-time control says so on screen.
#
# FIELD PROVENANCE (code comments only, never on screen — C1):
#   $screening$aic_table $model $model_type $AIC $parameter_estimates $error
#   $screening$best_model, $screening$best_model_type, $screening$initial_decision
#   $tests_run, $tests_reason
#   $tests$mz$statistic $alpha, $tests$qn$statistic, $tests$shen$statistic $alpha
#   $tests$receus$pi_hat $r_hat $decision $interpretation
#   $tests$immune$p_hat                 read via ca_tail_level(), silently (S10)
#   $tests$immune$last_observation_censored   read via ca_last_obs_censored()
#   $selected_receus_dist               S3: read, never re-derived
# =============================================================================


# ---- private constants ------------------------------------------------------

# The package default significance level for the two follow-up tests.
.V2_ALPHA_DEFAULT <- 0.05

# The two RECeUS cutoffs. Drawn, never applied: the decision string the package
# returns is what every verdict in this version actually reads.
.V2_PI_CUT <- 0.025
.V2_R_CUT  <- 0.05

# The distribution codes the exploration may ask for. The VALUES are the
# package's own short codes; the LABELS are plain display names, because C1
# keeps argument spellings off the screen. "" means "use the distribution the
# assessment selected" (S3 — read $selected_receus_dist, never re-map a name).
.V2_RECEUS_DISTS <- c(
  "Automatic" = "",
  "exponential cure model" = "exp",
  "Weibull cure model" = "wei",
  "gamma cure model" = "gam",
  "log-logistic cure model" = "llogis",
  "lognormal cure model" = "lnorm",
  "exponential" = "expUnc",
  "Weibull" = "weiUnc",
  "gamma" = "gamUnc",
  "log-logistic" = "llogisUnc",
  "lognormal" = "lnormUnc"
)

# The cured-group reading has its own not-computable line; the three follow-up
# readings share CA_VOID_LINE, which theme.R owns.
.V2_VOID_RECEUS <- "Cannot be computed: the model behind this number did not converge."

# §B.1 — the permanent line under the evaluation-time control, in all three
# versions.
.V2_TAU_CAVEAT <- "This is an exploration. The decision above, and the report, always use the default."


# ---- private helpers --------------------------------------------------------

#' Display name for a model key, never the key itself in prose.
#' @noRd
.v2_model_label <- function(key) {
  if (is.null(key) || length(key) < 1L || is.na(key[[1L]])) return(NULL)
  key <- as.character(key[[1L]])
  lab <- unname(CA_MODEL_LABELS[key])
  if (is.na(lab)) key else lab
}

#' Kaplan-Meier step data, read straight off the survfit object. Recomputes
#' nothing.
#' @noRd
.v2_km_frame <- function(kmfit) {
  if (is.null(kmfit) || is.null(kmfit$time) || !length(kmfit$time)) return(NULL)
  if (is.null(kmfit$surv) || length(kmfit$surv) != length(kmfit$time)) return(NULL)
  out <- data.frame(time = c(0, kmfit$time), surv = c(1, kmfit$surv))
  if (!is.null(kmfit$lower) && length(kmfit$lower) == length(kmfit$time) &&
      !is.null(kmfit$upper) && length(kmfit$upper) == length(kmfit$time)) {
    out$lower <- c(1, kmfit$lower); out$upper <- c(1, kmfit$upper)
  }
  if (!is.null(kmfit$n.censor) && length(kmfit$n.censor) == length(kmfit$time)) {
    out$n_censor <- c(0, kmfit$n.censor)
  }
  out
}

#' The fitted curve, taken from the fitting package's own summary method.
#' Never a hand-coded parametric survival function.
#' @noRd
.v2_overlay_frame <- function(fit, grid) {
  if (is.null(fit) || !length(grid)) return(NULL)
  s <- try(summary(fit, type = "survival", t = grid, ci = FALSE), silent = TRUE)
  if (inherits(s, "try-error")) return(NULL)
  d <- if (is.data.frame(s)) s else s[[1L]]
  if (is.null(d) || !nrow(d)) return(NULL)
  tcol <- if ("time" %in% names(d)) "time" else ".time"
  ecol <- if ("est" %in% names(d)) "est" else ".est"
  if (!all(c(tcol, ecol) %in% names(d))) return(NULL)
  data.frame(time = as.numeric(d[[tcol]]), surv = as.numeric(d[[ecol]]))
}

#' Evaluation times for the exploration slider: an axis, not an estimate.
#' The median is one of the descriptives S1 permits.
#' @noRd
.v2_tau_grid <- function(y, k = 25L) {
  y <- y[is.finite(y) & y > 0]
  if (length(y) < 2L) return(numeric(0))
  hi <- max(y); lo <- stats::median(y)
  if (!(hi > lo)) lo <- hi / 2
  if (!(hi > lo)) return(hi)
  g <- unique(seq(from = lo, to = hi, length.out = min(as.integer(k), 25L)))
  g[is.finite(g)]
}

#' Chip variant for a decision string. An unrecognised string stops loudly: a
#' silently-neutral verdict is worse than a crash in review.
#' @noRd
.v2_receus_variant <- function(decision) {
  switch(as.character(decision),
         "Cure model appropriate" = "pass",
         "Cure model not supported" = "fail",
         "Follow-up insufficient for cure modeling" = "fail",
         stop("Unrecognised RECeUS decision string: ", decision, call. = FALSE))
}

#' The Kaplan-Meier figure the package drew, restyled and annotated.
#'
#' Recomputes nothing: it repaints the object the package handed us and puts the
#' follow-up band behind it, so the curve and the risk table stay exactly what
#' was drawn. The level rule carries no label, no method name and no threshold.
#' @noRd
.v2_annotate_km <- function(sp, prepared, level = NA_real_, dark = FALSE) {
  if (is.null(sp) || is.null(sp$plot)) return(sp)
  sp <- ca_style_survplot(sp, dark)
  p <- sp$plot

  facts <- ca_tail_facts(prepared)   # app-side descriptives on Y and D only
  if (!is.null(facts) && isTRUE(is.finite(facts$last_event)) &&
      isTRUE(is.finite(facts$max_time)) && !isTRUE(facts$zero_width)) {
    tail_layers <- ca_followup_tail(facts$last_event, facts$max_time, dark,
                                    min_time = 0, label = "follow-up tail")
    if (length(tail_layers)) {
      behind  <- tail_layers[seq_len(min(2L, length(tail_layers)))]
      infront <- if (length(tail_layers) > 2L) tail_layers[-seq_len(2L)] else list()
      p$layers <- c(behind, p$layers)
      for (lyr in infront) p <- p + lyr
    }
  }
  for (lyr in ca_level_line(level, dark, label = NULL)) p <- p + lyr

  sp$plot <- p
  sp
}


# =============================================================================
# UI
# =============================================================================

#' Sections 3, 4 and 5.
mod_v2_evidence_ui <- function(id) {
  ns <- NS(id)

  htmltools::tagList(

    # ---- 3. Does the curve flatten? --------------------------------------
    htmltools::tags$section(
      class = "v2-sec", id = "v2-curve",
      htmltools::tags$h2(class = "v2-sec__title", "Does the curve flatten?"),
      htmltools::tags$p(
        class = "v2-sec__lede",
        "If some people are permanently free of the event, the survival curve stops",
        "falling and runs flat while people are still being watched."
      ),
      htmltools::div(class = "ca-bleed v2-figure",
                     plotOutput(ns("km"), height = "540px")),
      uiOutput(ns("curve_read")),
      htmltools::tags$details(
        class = "ca-more",
        htmltools::tags$summary("How to spot a plateau"),
        htmltools::div(
          class = "ca-more__body",
          htmltools::tags$ul(
            htmltools::tags$li("The curve stops stepping down and runs flat."),
            htmltools::tags$li("The flat stretch covers a real share of the follow-up, not just the last moment."),
            htmltools::tags$li("Few or no events fall inside it."),
            htmltools::tags$li("Plenty of people are still being followed there — check the table under the plot."),
            htmltools::tags$li("Heavy censoring alone can flatten a curve, so flatness on its own proves nothing.")
          )
        )
      )
    ),

    # ---- 4. Which model fits best? ---------------------------------------
    htmltools::tags$section(
      class = "v2-sec", id = "v2-models",
      htmltools::tags$h2(class = "v2-sec__title", "Which model fits best?"),
      htmltools::tags$p(
        class = "v2-sec__lede",
        "Eight descriptions are fitted — four shapes for the event times, each",
        "with and without a permanently event-free group — and ranked on one",
        "scale. Further left is a better description."
      ),
      uiOutput(ns("aic_msg")),
      uiOutput(ns("aic_plot_wrap")),
      uiOutput(ns("best_line")),
      htmltools::tags$details(
        class = "ca-more",
        htmltools::tags$summary("Every model, with its score"),
        htmltools::div(class = "ca-more__body",
                       DT::DTOutput(ns("aic_table")),
                       uiOutput(ns("aic_tech")))
      )
    ),

    # ---- 5. Do the diagnostics agree? ------------------------------------
    htmltools::tags$section(
      class = "v2-sec", id = "v2-diagnostics",
      htmltools::tags$h2(class = "v2-sec__title", "Do the readings agree?"),
      htmltools::tags$p(
        class = "v2-sec__lede",
        "Two questions, asked of the numbers rather than the picture: has anyone",
        "been watched long enough, and is the event-free group large enough to model?"
      ),
      uiOutput(ns("diag_msg")),
      uiOutput(ns("tracks")),
      htmltools::div(class = "v2-plane ca-bleed",
                     htmltools::div(class = "v2-plane__fig",
                                    plotOutput(ns("plane"), height = "420px")),
                     uiOutput(ns("plane_side"))),
      htmltools::tags$details(
        class = "ca-more v2-push",
        htmltools::tags$summary("Push on this"),
        htmltools::div(
          class = "ca-more__body",
          uiOutput(ns("explore_msg")),

          htmltools::tags$h4("The candidate set"),
          checkboxInput(ns("include_lognormal"), "Also fit lognormal models", value = FALSE),

          htmltools::tags$h4("How strict the follow-up readings are"),
          sliderInput(ns("alpha"),
                      label = htmltools::tags$span(htmltools::tags$span(class = "ca-nocaps", "α"),
                                                   " for the two follow-up readings"),
                      min = 0.01, max = 0.20, value = .V2_ALPHA_DEFAULT, step = 0.005,
                      width = "22rem"),
          uiOutput(ns("alpha_msg")),

          htmltools::tags$h4("Where the cured group is measured"),
          selectInput(ns("receus_dist"), "Distribution behind the cured-group reading",
                      choices = .V2_RECEUS_DISTS, selected = "", width = "26rem"),
          sliderInput(ns("tau_idx"), "Evaluation time τ (earliest to latest)",
                      min = 1, max = 25, value = 25, step = 1, ticks = FALSE,
                      width = "22rem"),
          uiOutput(ns("tau_label")),
          htmltools::tags$p(class = "ca-provenance", .V2_TAU_CAVEAT),
          uiOutput(ns("tau_msg")),
          uiOutput(ns("tau_plot_wrap")),

          htmltools::tags$h4("A fitted curve over the estimate"),
          selectInput(ns("overlay_model"), "Model to draw", choices = character(0),
                      width = "22rem"),
          uiOutput(ns("overlay_msg")),
          plotOutput(ns("overlay_plot"), height = "360px"),

          htmltools::tags$h4("Your own cutoffs — for discussion only"),
          uiOutput(ns("sens_head")),
          htmltools::div(
            class = "v2-sens__row",
            sliderInput(ns("sens_pi_cut"),
                        htmltools::tags$span(htmltools::tags$span(class = "ca-nocaps", "π̂"),
                                             " cutoff (yours)"),
                        min = 0, max = 0.5, value = .V2_PI_CUT, step = 0.005, width = "20rem"),
            sliderInput(ns("sens_r_cut"),
                        htmltools::tags$span(htmltools::tags$span(class = "ca-nocaps", "r̂"),
                                             " cutoff (yours)"),
                        min = 0, max = 0.5, value = .V2_R_CUT, step = 0.005, width = "20rem")
          ),
          uiOutput(ns("sens_panel"))
        )
      )
    )
  )
}

#' The many-datasets view. The chooser, the table and the CSV are all
#' app/R/mod_batch.R's; this version supplies the chrome and nothing else.
mod_v2_many_ui <- function(id) {
  ns <- NS(id)
  htmltools::tags$section(
    class = "v2-sec", id = "v2-many",
    htmltools::tags$h2(class = "v2-sec__title", "The same question, many times"),
    htmltools::tags$p(
      class = "v2-sec__lede",
      "Ask it of several datasets at once, or of one dataset split by treatment arm.",
      "Arms are always assessed separately — pooling them would answer a different question."
    ),
    mod_batch_ui(ns("batch"))
  )
}


# =============================================================================
# SERVER
# =============================================================================

mod_v2_evidence_server <- function(id, state) {
  moduleServer(id, function(input, output, session) {

    ns <- session$ns

    # ---- 1. THE AUTOMATIC ASSESSMENT (§B.3) ------------------------------
    # assessed_key is the idempotence guard: reactiveValues does not invalidate
    # when the new value is identical() to the old, so re-preparing a
    # byte-identical frame would otherwise leave the nulled assessment
    # unrepaired.
    assessed_key <- NULL

    assess_now <- function() {
      if (is.null(state$prepared)) {
        assessed_key <<- NULL
        state$assess <- NULL
        if (!identical(state$status, "error")) state$status <- "empty"
        return(invisible(NULL))
      }

      key <- list(prepared = state$prepared, lognormal = isTRUE(state$include_lognormal))
      if (identical(key, assessed_key) &&
          (!is.null(state$assess) || !is.null(state$last_error))) return(invisible(NULL))

      prepared <- state$prepared
      use_lognormal <- isTRUE(state$include_lognormal)

      # S7 — a failure here is a normal outcome, not a crash. The call itself is
      # ca_assess_once() in app/R/helpers.R: S2 run_tests = "yes", S5
      # time_scale = "none", S3 dist = NULL. It is the ONE call site in the
      # repository and this version does not write its own (§B.4, §H.8).
      res <- tryCatch(
        withProgress(message = "Assessing", value = 0, {
          incProgress(0.2, detail = "Fitting candidate models")
          a <- ca_assess_once(prepared, include_lognormal = use_lognormal)
          incProgress(0.8)
          a
        }),
        error = function(e) structure(list(msg = conditionMessage(e)), class = "ca_failed")
      )

      assessed_key <<- key

      if (inherits(res, "ca_failed")) {
        state$assess <- NULL
        state$alpha_tests <- NULL
        state$last_error <- res$msg
        state$status <- "prepared"
        return(invisible(NULL))
      }

      state$include_lognormal <- use_lognormal
      state$assess <- res
      state$alpha_tests <- if (is.finite(state$alpha) &&
                               abs(state$alpha - .V2_ALPHA_DEFAULT) > 1e-9) {
        ca_tests_at_alpha(prepared, state$alpha)
      } else NULL
      state$last_error <- NULL
      state$status <- "assessed"
      invisible(NULL)
    }

    observeEvent(list(state$prepared, state$include_lognormal), {
      assess_now()
    }, ignoreNULL = FALSE)

    # The catch-up trigger: a re-prepare that lands on an identical frame moves
    # the status but not the object. assess_now() is idempotent.
    observeEvent(state$status, { assess_now() }, ignoreInit = FALSE)

    observeEvent(input$include_lognormal, {
      state$include_lognormal <- isTRUE(input$include_lognormal)
    }, ignoreInit = TRUE)

    # ---- 2. THE DISPLAY-ONLY EXPLORATIONS (§B.1 reactives 4 and 5) -------
    alpha_r <- debounce(reactive(input$alpha), 400)

    observeEvent(alpha_r(), {
      a <- alpha_r()
      if (is.null(a) || !is.finite(a)) return(invisible(NULL))
      state$alpha <- a
      # NULL at the package default is load-bearing: it is how the rest of the
      # app knows the readings on screen are the assessment's own.
      state$alpha_tests <- if (abs(a - .V2_ALPHA_DEFAULT) < 1e-9) NULL else {
        ca_tests_at_alpha(state$prepared, a)
      }
      invisible(NULL)
    }, ignoreInit = TRUE)

    tau_grid_r <- reactive({
      if (is.null(state$prepared)) return(numeric(0))
      .v2_tau_grid(state$prepared$Y)
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

    # Only the cheap triggers are debounced: debouncing the expensive reactive
    # itself would make it eager and recompute inside a closed disclosure.
    tau_idx_d <- debounce(reactive(input$tau_idx), 250)
    dist_d    <- debounce(reactive(if (is.null(input$receus_dist)) "" else input$receus_dist), 250)

    receus_dist_r <- reactive({
      choice <- dist_d()
      if (!is.null(choice) && length(choice) == 1L && !is.na(choice) && nzchar(choice)) {
        return(as.character(choice))
      }
      d <- state$assess$selected_receus_dist      # S3 — read, never re-derived
      if (is.null(d) || length(d) != 1L || is.na(d) || !nzchar(d)) return(NULL)
      as.character(d)
    })

    tau_r <- reactive({
      tau_idx_d()
      if (is.null(state$prepared) || !ca_has_tests(state)) return(NULL)
      d <- receus_dist_r()
      if (is.null(d)) return(NULL)
      ca_receus_at_tau(state$prepared, d, isolate(tau_value_r()))
    })

    tau_curve_r <- reactive({
      if (is.null(state$prepared) || !ca_has_tests(state)) return(NULL)
      d <- receus_dist_r()
      if (is.null(d)) return(NULL)
      g <- tau_grid_r()
      if (!length(g)) return(NULL)
      k <- length(g)
      rows <- withProgress(message = "Recomputing across evaluation times", value = 0, {
        pieces <- lapply(seq_len(k), function(i) {
          incProgress(1 / k, detail = paste0("Evaluation time ", i, " of ", k))
          r <- ca_receus_at_tau(state$prepared, d, g[[i]])
          if (is.null(r)) return(NULL)
          data.frame(tau = r$tau, pi_hat = r$pi_hat, r_hat = r$r_hat)
        })
        pieces <- pieces[!vapply(pieces, is.null, logical(1))]
        if (!length(pieces)) NULL else do.call(rbind, pieces)
      })
      list(data = rows, k = k)
    })

    # The readings every track and card reads: the assessment's own, with the
    # two alpha-recomputed ones merged over them when the slider has moved.
    tests_r <- reactive({
      if (!ca_has_tests(state)) return(NULL)
      base <- state$assess$tests
      at <- state$alpha_tests
      if (!is.null(at)) {
        if (!is.null(at$mz)) base$mz <- at$mz
        if (!is.null(at$shen)) base$shen <- at$shen
      }
      base
    })

    # ---- 3. DOES THE CURVE FLATTEN? --------------------------------------

    km_level_r <- reactive({
      if (!ca_has_tests(state)) return(NA_real_)
      ca_tail_level(state$assess$tests$immune)
    })

    output$km <- renderPlot({
      req(state$prepared)
      sp <- state$fit$kmplot
      req(!is.null(sp))
      ann <- try(.v2_annotate_km(sp, state$prepared, km_level_r(), isTRUE(state$dark)),
                 silent = TRUE)
      suppressMessages(print(if (inherits(ann, "try-error")) sp else ann))
    }, res = 108, bg = "transparent",
       alt = "Kaplan-Meier survival curve for the prepared dataset, with the follow-up tail after the last event shaded.")

    output$curve_read <- renderUI({
      req(state$prepared)
      f <- ca_tail_facts(state$prepared)
      censored <- ca_last_obs_censored(state)

      chip <- if (isTRUE(censored)) {
        ca_chip("neutral", "The last observed time is censored, so a plateau is possible")
      } else if (identical(censored, FALSE)) {
        ca_chip("neutral", "The last observed time is an event, so there is no clear plateau")
      } else NULL

      level <- km_level_r()
      line <- if (is.null(f) || isTRUE(f$zero_width)) {
        "The longest follow-up time is an event, so there is no flat stretch to read."
      } else if (length(level) == 1L && is.finite(level)) {
        paste0("The curve settles near ", ca_num(level, 2), " after ",
               ca_num(f$last_event, 2), " and stays there to ", ca_num(f$max_time, 2), ".")
      } else NULL

      htmltools::div(
        class = "v2-figcap",
        chip,
        if (!is.null(line)) htmltools::tags$p(line)
      )
    })

    # ---- 4. WHICH MODEL FITS BEST? ---------------------------------------

    output$aic_msg <- renderUI({
      if (is.null(state$prepared)) {
        return(htmltools::tags$p(class = "v2-empty", "No data yet."))
      }
      if (!is.null(state$assess) || is.null(state$last_error)) return(NULL)
      # §B.7 — the one failure surface. No sentence names the package; the raw
      # text sits in the technical disclosure.
      ca_note("warning", "The models could not be fitted for this dataset.",
              ca_tech(htmltools::tags$pre(class = "ca-mono", state$last_error)))
    })

    output$aic_plot_wrap <- renderUI({
      req(state$assess)
      tbl <- state$assess$screening$aic_table
      req(is.data.frame(tbl), nrow(tbl) > 0L)
      htmltools::div(
        class = "v2-figure",
        plotOutput(ns("aic_dots"), height = paste0(64 + 34 * nrow(tbl), "px"))
      )
    })

    output$aic_dots <- renderPlot({
      req(state$assess)
      p <- ca_viz_aic_dots(state$assess$screening$aic_table,
                           best = state$assess$screening$best_model,
                           dark = isTRUE(state$dark))
      req(!is.null(p))
      print(p)
    }, res = 108, bg = "transparent",
       alt = "Model comparison scores, one dot per candidate model, smaller to the left; a filled dot allows a cured group and a hollow ring does not.")

    output$best_line <- renderUI({
      req(state$assess)
      lab <- .v2_model_label(state$assess$screening$best_model)
      if (is.null(lab)) {
        return(htmltools::tags$p(class = "v2-read", "No model could be fitted to these data."))
      }
      cure <- identical(as.character(state$assess$screening$best_model_type), "cure")
      # Built as one HTML string so the emphasis and the full stop sit together;
      # separate tag arguments would put a space in front of the full stop.
      htmltools::tags$p(
        class = "v2-read",
        htmltools::HTML(paste0(
          "The best description is the <strong>", htmltools::htmlEscape(lab), "</strong>. ",
          if (cure) "It allows a permanently event-free group."
          else "It has no permanently event-free group, and nothing further can rescue that."
        ))
      )
    })

    output$aic_table <- DT::renderDT({
      req(state$assess)
      tbl <- state$assess$screening$aic_table

      disp <- data.frame(
        # USE.NAMES = FALSE: a character input would otherwise name the result
        # and data.frame() would take those names as row names.
        model = vapply(tbl$model, function(x) {
          lab <- .v2_model_label(x); if (is.null(lab)) as.character(x) else lab
        }, character(1), USE.NAMES = FALSE),
        type = vapply(tbl$model_type, function(x) as.character(ca_chip("neutral", x)), character(1), USE.NAMES = FALSE),
        AIC = vapply(tbl$AIC, function(x) ca_num(x, 2), character(1)),
        parameter_estimates = vapply(tbl$parameter_estimates, function(x) {
          # The fitting step labels a one-parameter estimate with an empty name,
          # so the cell can arrive as "=0.1416". The dangling "=" is stripped;
          # no number is altered and no name is invented.
          if (is.na(x)) ca_dash() else sub("^=", "", as.character(x))
        }, character(1)),
        error = vapply(tbl$error, function(x) if (!nzchar(x)) ca_dash() else as.character(x),
                       character(1)),
        stringsAsFactors = FALSE
      )
      # The package's own row order — smallest score first, failures last —
      # kept as a hidden key so em-dash cells never sort lexically (S4).
      disp$.aic_order <- seq_len(nrow(disp))

      DT::datatable(
        disp, rownames = FALSE, selection = "none", escape = -2,
        colnames = c("Model", "Type", "Score", "Parameters", "Problem", "order"),
        class = "compact stripe hover",
        options = list(
          dom = "t", paging = FALSE, ordering = TRUE, scrollX = TRUE,
          order = list(list(2L, "asc")),
          columnDefs = list(
            list(targets = 5L, visible = FALSE, searchable = FALSE),
            list(targets = 2L, orderData = 5L, className = "dt-right"),
            list(targets = 3L, className = "ca-mono", width = "30%"),
            list(targets = 4L, width = "24%")
          )
        )
      )
    })

    output$aic_tech <- renderUI({
      req(state$assess)
      ca_tech(htmltools::tags$p(class = "ca-tech__body",
                                state$assess$screening$initial_decision))
    })

    # ---- 5. DO THE READINGS AGREE? ---------------------------------------

    output$diag_msg <- renderUI({
      if (is.null(state$prepared) || is.null(state$assess)) return(NULL)
      if (!isTRUE(state$assess$tests_run)) {
        return(htmltools::tagList(
          ca_note("info", "The follow-up and cured-group readings were not run.",
                  ca_tech(htmltools::tags$p(class = "ca-tech__body",
                                            state$assess$tests_reason)))
        ))
      }
      if (is.null(state$alpha_tests)) return(NULL)
      ca_banner("This is an exploration. The verdict above is unchanged.", variant = "override")
    })

    output$tracks <- renderUI({
      tt <- tests_r()
      if (is.null(tt) || is.null(state$prepared)) return(NULL)

      qn   <- tt$qn
      mz   <- tt$mz
      shen <- tt$shen
      n    <- nrow(state$prepared)
      # S1 — the single closed form this app is permitted to evaluate.
      thr <- ca_qn_threshold(n, state$alpha)

      # S9. The two follow-up statistics are algebraically the same reading, so
      # ONE track is drawn for them and the companion value rides underneath as
      # a sentence. Never two tracks, never two votes.
      companion <- if (is.finite(mz$statistic) && is.finite(mz$alpha)) {
        paste0("The companion statistic reads ", ca_num(mz$statistic, 4),
               " against ", ca_num(mz$alpha, 3),
               " on its own scale — the same test, expressed the other way round.")
      } else NULL

      # S6: the three follow-up readings go missing TOGETHER. Two tracks would
      # then print the same not-computable sentence twice, so the void case is
      # one panel carrying the question and the reason once.
      if (!is.finite(qn$statistic) && !is.finite(shen$statistic)) {
        return(htmltools::div(
          class = "v2-tracks",
          ca_viz_threshold_track(
            stat = NA_real_, threshold = NA_real_, larger_is_better = TRUE,
            label = "Is follow-up long enough?"
          )
        ))
      }

      htmltools::div(
        class = "v2-tracks",
        ca_viz_threshold_track(
          stat = qn$statistic, threshold = thr, larger_is_better = TRUE,
          label = "Is follow-up long enough?", companion_line = companion
        ),
        ca_viz_threshold_track(
          stat = shen$statistic, threshold = shen$alpha, larger_is_better = FALSE,
          label = "A second look at the same question, on its own scale"
        )
      )
    })

    output$plane <- renderPlot({
      tt <- tests_r()
      req(!is.null(tt))
      p <- ca_viz_receus_plane(tt$receus$pi_hat, tt$receus$r_hat,
                               dark = isTRUE(state$dark))
      req(!is.null(p))
      print(p)
    }, res = 108, bg = "transparent",
       alt = "The estimated cure fraction plotted against the uncured censored ratio, with the region that supports a cure model shaded.")

    output$plane_side <- renderUI({
      tt <- tests_r()
      if (is.null(tt)) return(NULL)
      rc <- tt$receus
      void <- !is.finite(rc$pi_hat) || !is.finite(rc$r_hat)

      htmltools::div(
        class = "v2-plane__side",
        htmltools::tags$h3("Is the event-free group real?"),
        if (void) {
          htmltools::tagList(
            ca_chip("void", "Cannot be computed"),
            htmltools::tags$p(.V2_VOID_RECEUS)
          )
        } else {
          htmltools::tagList(
            ca_chip(.v2_receus_variant(rc$decision), rc$decision),
            htmltools::div(
              class = "v2-stats",
              htmltools::div(class = "ca-stat",
                             htmltools::tags$span(class = "ca-stat__label", "Share never having the event"),
                             htmltools::tags$span(class = "ca-stat__value", ca_num(rc$pi_hat))),
              htmltools::div(class = "ca-stat",
                             htmltools::tags$span(class = "ca-stat__label", "Uncured people still censored"),
                             htmltools::tags$span(class = "ca-stat__value", ca_num(rc$r_hat)))
            ),
            htmltools::tags$p(class = "ca-provenance",
                              "Supported when the first is above 0.025 and the second below 0.05.")
          )
        },
        ca_tech(htmltools::tags$p(class = "ca-tech__body", rc$interpretation))
      )
    })

    # ---- the exploration disclosure --------------------------------------

    output$explore_msg <- renderUI({
      if (is.null(state$prepared)) return(ca_empty("No data yet."))
      if (is.null(state$assess)) return(NULL)
      if (!ca_has_tests(state)) return(ca_empty("The readings were not run for these data."))
      NULL
    })

    output$alpha_msg <- renderUI({
      a <- input$alpha
      if (is.null(a) || (is.finite(a) && a >= 0.01 && a <= 0.20)) return(NULL)
      ca_empty("α must be between 0.01 and 0.20.")
    })

    output$tau_label <- renderUI({
      if (!ca_has_tests(state)) return(NULL)
      tau <- tau_value_r()
      if (!length(tau_grid_r())) return(NULL)
      htmltools::tags$p(class = "ca-provenance", "τ = ",
                        htmltools::tags$span(class = "ca-mono", ca_num(tau)))
    })

    output$tau_msg <- renderUI({
      out <- list()
      res <- tau_r()
      if (!is.null(res)) {
        out <- c(out, list(htmltools::div(
          class = "v2-sens__row",
          htmltools::div(class = "ca-stat",
                         htmltools::tags$span(class = "ca-stat__label", "π̂"),
                         htmltools::tags$span(class = "ca-stat__value", ca_num(res$pi_hat))),
          htmltools::div(class = "ca-stat",
                         htmltools::tags$span(class = "ca-stat__label", "r̂"),
                         htmltools::tags$span(class = "ca-stat__value", ca_num(res$r_hat))),
          htmltools::tags$p(res$decision)
        )))
      }
      cur <- tau_curve_r()
      if (!is.null(cur)) {
        drawn <- if (is.null(cur$data)) 0L else sum(stats::complete.cases(cur$data))
        if (cur$k - drawn > 0L) {
          out <- c(out, list(ca_empty(paste0(
            cur$k - drawn, " of ", cur$k,
            " times could not be computed and are not plotted."))))
        }
      }
      if (!length(out)) return(NULL)
      htmltools::tagList(out)
    })

    output$tau_plot_wrap <- renderUI({
      cur <- tau_curve_r()
      if (is.null(cur) || is.null(cur$data)) return(NULL)
      plotOutput(ns("tau_plot"), height = "260px")
    })

    output$tau_plot <- renderPlot({
      cur <- tau_curve_r()
      req(!is.null(cur), !is.null(cur$data))
      d <- cur$data[stats::complete.cases(cur$data), , drop = FALSE]
      req(nrow(d) > 0)
      k <- ca_tokens(isTRUE(state$dark))
      here <- tau_value_r()

      long <- rbind(
        data.frame(tau = d$tau, value = d$pi_hat, series = "π̂"),
        data.frame(tau = d$tau, value = d$r_hat,  series = "r̂")
      )
      cuts <- data.frame(series = c("π̂", "r̂"),
                         yint = c(.V2_PI_CUT, .V2_R_CUT))

      p <- ggplot(long, aes(x = .data$tau, y = .data$value)) +
        geom_hline(data = cuts, aes(yintercept = .data$yint),
                   colour = k$rule2, linetype = "dashed", linewidth = 0.5)
      if (is.finite(here)) {
        p <- p + geom_vline(xintercept = here, colour = k$rule2, linewidth = 0.5)
      }
      p +
        geom_line(colour = unname(k$series[["petrol"]]), linewidth = 0.9) +
        facet_wrap(~ series, ncol = 2) +
        coord_cartesian(ylim = c(0, 1)) +
        labs(x = "Evaluation time τ", y = NULL,
             subtitle = "Dashed lines: 0.025 and 0.05") +
        theme_cure_assess(dark = isTRUE(state$dark))
    }, res = 108, bg = "transparent",
       alt = "How the estimated cure fraction and the uncured censored ratio change as the follow-up cut-off moves.")

    # -- the fitted-curve overlay ------------------------------------------
    observeEvent(list(state$assess, state$fit), {
      if (is.null(state$assess)) {
        updateSelectInput(session, "overlay_model", choices = character(0))
        return(invisible(NULL))
      }
      tbl <- state$assess$screening$aic_table
      ok <- tbl$model[tbl$error == ""]
      have <- names(state$fit$fits)
      if (!is.null(have)) ok <- ok[ok %in% have]
      bm <- state$assess$screening$best_model
      sel <- if (length(bm) && !is.na(bm) && bm %in% ok) bm else if (length(ok)) ok[[1L]] else NULL
      choices <- if (length(ok)) {
        stats::setNames(ok, vapply(ok, function(m) {
          lab <- .v2_model_label(m); if (is.null(lab)) m else lab
        }, character(1)))
      } else character(0)
      updateSelectInput(session, "overlay_model", choices = choices, selected = sel)
      invisible(NULL)
    }, ignoreNULL = FALSE)

    overlay_failed_r <- reactive({
      if (is.null(state$assess)) return(FALSE)
      m <- input$overlay_model
      if (is.null(m) || !nzchar(m)) return(FALSE)
      tbl <- state$assess$screening$aic_table
      row <- tbl[tbl$model == m, , drop = FALSE]
      if (!nrow(row)) return(TRUE)
      nzchar(row$error[[1L]])
    })

    output$overlay_msg <- renderUI({
      if (!isTRUE(overlay_failed_r())) return(NULL)
      ca_empty("That model did not fit, so there is no curve to draw.")
    })

    output$overlay_plot <- renderPlot({
      req(state$fit)
      km <- .v2_km_frame(state$fit$kmfit)
      req(!is.null(km))
      f <- ca_tail_facts(state$prepared)

      censor <- if ("n_censor" %in% names(km)) {
        km[km$n_censor > 0, c("time", "surv"), drop = FALSE]
      } else km[0L, c("time", "surv"), drop = FALSE]

      band <- if (all(c("lower", "upper") %in% names(km))) {
        km[stats::complete.cases(km[, c("time", "lower", "upper")]), , drop = FALSE]
      } else km

      m <- input$overlay_model
      ov <- NULL; lab <- "Fitted model"
      if (!is.null(m) && nzchar(m) && !isTRUE(overlay_failed_r())) {
        fit_obj <- state$fit$fits[[m]]$fit
        if (!is.null(fit_obj)) {
          grid <- seq(0, max(km$time, na.rm = TRUE), length.out = 200)
          ov <- .v2_overlay_frame(fit_obj, grid)
          lab <- paste0("Fitted: ", .v2_model_label(m))
        }
      }

      print(ca_km_overlay_plot(
        km = band, censor = censor, overlay = ov,
        last_event_time = if (is.null(f)) NA_real_ else f$last_event,
        max_time = if (is.null(f)) NA_real_ else f$max_time,
        km_label = "Observed", overlay_label = lab,
        dark = isTRUE(state$dark), x_lab = "Time", y_lab = "Survival"
      ))
    }, res = 108, bg = "transparent",
       alt = "Kaplan-Meier curve with the selected fitted model drawn over it as a dashed line.")

    # -- the cutoff what-if. Writes nothing, overrides nothing, and never
    #    leaves this panel. The package decision stays canonical.
    sens_receus_r <- reactive({
      tt <- tests_r()
      if (is.null(tt)) return(NULL)
      rc <- tt$receus
      if (!is.finite(rc$pi_hat) || !is.finite(rc$r_hat)) return(NULL)
      rc
    })

    output$sens_head <- renderUI({
      rc <- sens_receus_r()
      if (is.null(rc)) {
        if (!ca_has_tests(state)) return(NULL)
        return(ca_empty(.V2_VOID_RECEUS))
      }
      htmltools::tagList(
        htmltools::tags$p("The two cutoffs are fixed by the published method and cannot be changed."),
        htmltools::tags$p(paste0("The decision above stands: “", rc$decision, "”.")),
        htmltools::tags$p(paste0(
          "Moving the sliders only shows how close this dataset sits to the ",
          "published lines. Nothing else here uses them."))
      )
    })

    output$sens_panel <- renderUI({
      rc <- sens_receus_r()
      if (is.null(rc)) return(NULL)
      pi_cut <- if (is.null(input$sens_pi_cut)) .V2_PI_CUT else input$sens_pi_cut
      r_cut  <- if (is.null(input$sens_r_cut))  .V2_R_CUT  else input$sens_r_cut
      would <- function(ok) if (isTRUE(ok)) "would pass" else "would not pass"
      htmltools::div(
        class = "v2-sens__row",
        htmltools::tags$p(paste0("π̂ = ", ca_num(rc$pi_hat), " greater than ",
                                 ca_num(pi_cut, 3), " → ", would(rc$pi_hat > pi_cut))),
        htmltools::tags$p(paste0("r̂ = ", ca_num(rc$r_hat), " less than ",
                                 ca_num(r_cut, 3), " → ", would(rc$r_hat < r_cut)))
      )
    })

    invisible(NULL)
  })
}
