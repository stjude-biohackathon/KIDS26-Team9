# ---------------------------------------------------------------------------
# mod_quantitative.R — the Quantitative tab (owner: builder-quant)
#
# Carries the spec "Models" tab (§4.2) and the spec "Diagnostics" tab (§4.3) in
# one vertical flow, plus the threshold controls of BUILD CONTRACT §H.2.
#
# R1: no statistic is computed here. Every number on screen is read out of a
# cureAssess return field, and the field is named in a comment beside it. The
# only app-side arithmetic in this file is ca_qn_threshold() (contract §F.4,
# the single permitted closed form) and the plain comparisons the contract
# spells out for the category-C what-if rows.
#
# Package call sites owned by this file: §I.5 model.fitting(), §I.6
# cure.appropriateness() (the ONE call site in the whole app), §I.7 mz.test(),
# §I.8 shen.test(), §I.9 run.cure.tests(), §I.10 receus.method().
# ---------------------------------------------------------------------------


# ---- private constants ----------------------------------------------------

# Package default alpha for mz.test()/shen.test(); also the alpha the package's
# own qn interpretation string is hard-wired to.
.QUANT_ALPHA_DEFAULT <- 0.05

# RECeUS cutoffs. Literals inside receus.method() (R/receus.method.R:116-117);
# no exported argument reaches them. Shown, never applied by this app.
.QUANT_PI_CUT <- 0.025
.QUANT_R_CUT <- 0.05

# The RECeUS short codes receus.method()/run.cure.tests() accept, in the order
# the contract §H.2 lists them. "" means "use the distribution the assessment
# selected".
.QUANT_RECEUS_DISTS <- c(
  "Automatic — the distribution the assessment selected" = "",
  "exp — exponential cure" = "exp",
  "wei — Weibull cure" = "wei",
  "gam — gamma cure" = "gam",
  "llogis — log-logistic cure" = "llogis",
  "lnorm — lognormal cure" = "lnorm",
  "expUnc — exponential non-cure" = "expUnc",
  "weiUnc — Weibull non-cure" = "weiUnc",
  "gamUnc — gamma non-cure" = "gamUnc",
  "llogisUnc — log-logistic non-cure" = "llogisUnc",
  "lnormUnc — lognormal non-cure" = "lnormUnc"
)

# Contract §J.10 / §J.11 — the not-computable body, verbatim, both lines.
.QUANT_VOID_1 <- paste0(
  "Cannot be computed — the longest observed time is an event, ",
  "so there is no plateau to test."
)
.QUANT_VOID_2 <- paste0(
  "This is a property of the data, not an error. All three follow-up tests ",
  "need follow-up to extend past the last event."
)

# Contract §J.10 — RECeUS has its own not-computable sentence.
.QUANT_VOID_RECEUS <- paste0(
  "Cannot be computed — the model fit behind RECeUS did not converge ",
  "for this dataset."
)

# Contract §J.6 "The question it asks" lines, verbatim, one per card.
.QUANT_LEDE_MZ <- paste0(
  "Did follow-up extend far enough past the last event that a plateau ",
  "could be seen?"
)
.QUANT_LEDE_QN <- "What share of events fall inside a late window as wide as the flat tail?"
.QUANT_LEDE_SHEN <- "The same follow-up question, through a narrower late-time window."
.QUANT_LEDE_IMMUNE <- paste0(
  "What do the data look like at the end of follow-up — how much ",
  "censoring, and was the last observation a censored subject?"
)
.QUANT_LEDE_RECEUS <- paste0(
  "Is the estimated cure fraction non-negligible, and is the share of uncured ",
  "subjects still unresolved at the end of follow-up small enough to identify it?"
)

# Contract §J.4 — the "AIC is initial support only" copy, verbatim.
.QUANT_AIC_CAVEAT <- paste0(
  "A better AIC fit is not evidence that a cure model is identifiable. AIC ",
  "asks how well a model describes the data you have; identifiability asks ",
  "whether the data contain enough follow-up to pin the cure fraction down. ",
  "Different questions, and only the second one is being decided here."
)

# Contract §J.8 route 4 — the Othus et al. warning, verbatim, used as the
# caption of the tau-sensitivity curve.
.QUANT_TAU_WARNING <- paste0(
  "Othus et al. refitted cure models on six SWOG trials at an early and a ",
  "later follow-up time, found the mean-survival estimates shifted ",
  "materially, and found the direction of the shift was not predictable. ",
  "There is no post-hoc correction to apply — which is why this check ",
  "happens before you fit, not after."
)


# ---- private helpers ------------------------------------------------------

#' Colours for this module's two plot series.
#'
#' Local to this file (contract §F: a helper that is not in helpers.R is
#' defined privately, with the module prefix). Draws nothing statistical.
.quant_palette <- function(dark = FALSE) {
  if (isTRUE(dark)) {
    list(km = "#8fa6bf", fit = "#7fd1c1", rule = "#5c6b7a", band = "#8fa6bf")
  } else {
    list(km = "#41566e", fit = "#1f7a6a", rule = "#9aa7b4", band = "#41566e")
  }
}

#' Safe length-1 character read for package fields that may be NULL or NA.
#'
#' `selected_receus_model` in particular "may be NULL, NA_character_, or a
#' name" (contract §I.11) — all three arrive here.
.quant_chr <- function(x, fallback = ca_dash()) {
  if (is.null(x) || length(x) < 1L || is.na(x[[1L]]) || !nzchar(as.character(x[[1L]]))) {
    return(fallback)
  }
  as.character(x[[1L]])
}

#' Evaluation times for the tau-sensitivity control.
#'
#' An axis, not an estimate: an evenly spaced ladder of at most 25 candidate
#' evaluation times running from the median observed time up to the largest
#' observed time, which is the value receus.method() uses by default. The
#' median is one of the descriptives contract §F.1 permits.
.quant_tau_grid <- function(y, k = 25L) {
  y <- y[is.finite(y) & y > 0]
  if (length(y) < 2L) return(numeric(0))
  hi <- max(y)
  lo <- stats::median(y)
  if (!(hi > lo)) lo <- hi / 2
  if (!(hi > lo)) return(hi)
  g <- seq(from = lo, to = hi, length.out = min(as.integer(k), 25L))
  g <- unique(g[is.finite(g)])
  if (!length(g)) return(numeric(0))
  g
}

#' Kaplan-Meier step data read straight off the survfit object.
#'
#' Reads state$fit$kmfit ($time, $surv, $lower, $upper, $n.censor). Recomputes
#' nothing — survival::survfit() already produced every number here.
.quant_km_frame <- function(kmfit) {
  # FIXPASS (3.5a): this bound c(1, kmfit$lower) and c(0, kmfit$n.censor)
  # unconditionally. A survfit object carrying no confidence limits (or a
  # limit vector of a different length) made data.frame() throw "arguments
  # imply differing number of rows" inside renderPlot, which surfaced as a red
  # stack trace where the overlay should be. The sibling .qual_km_frame() in
  # mod_qualitative.R already guarded exactly this; these are its guards.
  # Optional columns are now absent rather than wrong, and the render site
  # below checks names(km) before drawing the band or the censoring ticks.
  if (is.null(kmfit) || is.null(kmfit$time) || !length(kmfit$time)) return(NULL)
  if (is.null(kmfit$surv) || length(kmfit$surv) != length(kmfit$time)) return(NULL)
  out <- data.frame(
    time = c(0, kmfit$time),
    surv = c(1, kmfit$surv),
    stringsAsFactors = FALSE
  )
  if (!is.null(kmfit$lower) && length(kmfit$lower) == length(kmfit$time) &&
      !is.null(kmfit$upper) && length(kmfit$upper) == length(kmfit$time)) {
    out$lower <- c(1, kmfit$lower)
    out$upper <- c(1, kmfit$upper)
  }
  if (!is.null(kmfit$n.censor) && length(kmfit$n.censor) == length(kmfit$time)) {
    out$n_censor <- c(0, kmfit$n.censor)
  }
  out
}

#' Fitted survival curve, taken from the fitting package's own summary method.
#'
#' summary(fit, type = "survival", t = grid) on a flexsurv / flexsurvcure
#' object. Never a hand-coded parametric survival function. `ci = FALSE`
#' because the confidence band would be bootstrapped and the overlay only
#' needs the point curve.
.quant_overlay_frame <- function(fit, grid) {
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

#' One labelled statistic slot inside a diagnostic card.
.quant_stat <- function(label, value_text, void = FALSE) {
  htmltools::div(
    class = if (isTRUE(void)) "ca-stat ca-stat--void" else "ca-stat",
    htmltools::span(class = "ca-stat__label", label),
    htmltools::span(class = "ca-stat__value", value_text)
  )
}

#' The threshold line under a statistic: the value, then its direction.
.quant_threshold <- function(value_text, dir_text) {
  htmltools::div(
    class = "ca-threshold",
    htmltools::span(class = "ca-threshold__value", value_text),
    htmltools::span(class = "ca-threshold__dir", dir_text)
  )
}

#' The two body lines of a not-computable follow-up card (contract §J.11).
.quant_void_body <- function() {
  htmltools::tagList(
    htmltools::p(.QUANT_VOID_1),
    htmltools::p(.QUANT_VOID_2)
  )
}

#' One RECeUS condition tick, rendered as its own row (R10: two ticks, never
#' one combined sentence).
#'
#' `met` is the package's own logical — $cure_fraction_condition or
#' $followup_condition — never a comparison made here.
.quant_cond <- function(text, met) {
  htmltools::div(
    class = "ca-rec__cond",
    # The glyph is drawn by CSS from data-ca-met (app.css .ca-rec__cond::before),
    # so emitting a unicode tick here too printed it twice.
    `data-ca-met` = if (isTRUE(met)) "true" else "false",
    htmltools::span(text)
  )
}

#' The empty state every card in the "Explore RECeUS" section shows while there
#' is nothing to explore.
#'
#' FIXPASS (3.2): the τ card and the what-if card rendered nothing at all
#' before an assessment — two live-looking buttons, a τ readout and two bare
#' sliders under a heading with no text — while their handlers aborted
#' silently on req(). The distribution card above already had this empty state;
#' this is the same one, so all three cards explain themselves the same way.
#' Returns NULL once there is a result, i.e. once the controls really work.
.quant_explore_empty <- function(state, action_id = NULL) {
  if (is.null(state$prepared)) {
    return(ca_empty(
      paste0(
        "Prepare a dataset on the Data step first — these controls explore a ",
        "result that does not exist yet."
      ),
      action_id = action_id,
      action_label = if (is.null(action_id)) NULL else "Go to Data →"
    ))
  }
  if (is.null(state$assess)) {
    # FIXPASS (3.2, wording): status "data_loaded" with a prepared frame in
    # hand means the Data step's mapping moved on and state$prepared is the
    # old frame, so the next press is Prepare data, not Run assessment. This
    # is the same correction made in run_msg, said the same way.
    if (identical(state$status, "data_loaded")) {
      return(ca_empty(paste0(
        "The Data step changed, so there is no current result to explore. ",
        "Press Prepare data on the Data step, then Run assessment at the top ",
        "of this tab, and these controls come alive."
      )))
    }
    return(ca_empty(paste0(
      "Run the assessment first — these controls explore a result that does ",
      "not exist yet. Press Run assessment at the top of this tab and they ",
      "come alive."
    )))
  }
  if (!ca_has_tests(state)) {
    return(ca_empty(paste0(
      "The five diagnostics were not run for this dataset, so there is no ",
      "RECeUS result to explore. The reason the package gives is under ",
      "“The five diagnostics” above."
    )))
  }
  NULL
}

#' Chip variant for a RECeUS decision string. Fixed lookup; an unrecognised
#' string stops loudly rather than falling through to a neutral chip.
.quant_receus_variant <- function(decision) {
  switch(
    as.character(decision),
    "Cure model appropriate" = "pass",
    "Cure model not supported" = "fail",
    "Follow-up insufficient for cure modeling" = "caution",
    stop("Unrecognised RECeUS decision string: ", decision, call. = FALSE)
  )
}

#' Startup assertion, contract §K: at alpha = 0.05 the app's qn chip direction
#' must agree with the package's own sentence.
#'
#' Reads qn$statistic and qn$interpretation; compares the app's chip rule
#' (larger qn is better) against the presence of the package's own
#' "Because qn exceeds this threshold" clause. Returns NA when qn could not be
#' computed, TRUE when they agree, FALSE when they do not.
.quant_qn_direction_ok <- function(qn, threshold) {
  if (is.null(qn) || !is.finite(qn$statistic) || !is.finite(threshold)) return(NA)
  app_sufficient <- qn$statistic > threshold
  pkg_sufficient <- grepl(
    "Because qn exceeds this threshold", qn$interpretation, fixed = TRUE
  )
  identical(app_sufficient, pkg_sufficient)
}

#' Merge the alpha-recomputed Maller-Zhou and Shen results over the canonical
#' test list.
#'
#' `base` is state$assess$tests (or a run.cure.tests() override). `alpha_tests`
#' is state$alpha_tests: NULL when alpha is the package default 0.05, else
#' list(mz = <cure.test.result>, shen = <cure.test.result>) from the direct
#' §I.7/§I.8 calls. Everything merged in is a package return object; the
#' interpretation strings shown are the package's own, recomputed at the user's
#' alpha.
.quant_merge_alpha <- function(base, alpha_tests) {
  if (is.null(base)) return(NULL)
  if (is.null(alpha_tests)) return(base)
  if (!is.null(alpha_tests$mz)) base$mz <- alpha_tests$mz
  if (!is.null(alpha_tests$shen)) base$shen <- alpha_tests$shen
  base
}

#' Direct mz.test()/shen.test() calls at a non-default alpha (§I.7, §I.8).
#'
#' Returns NULL at the package default, which is what state$alpha_tests = NULL
#' means. Both calls are wrapped: a failure degrades to the canonical 0.05
#' results rather than blanking the tab.
.quant_alpha_tests <- function(prepared, alpha) {
  if (is.null(prepared)) return(NULL)
  if (!is.finite(alpha) || abs(alpha - .QUANT_ALPHA_DEFAULT) < 1e-9) return(NULL)
  tryCatch(
    list(
      mz = cureAssess::mz.test(dat = prepared, alpha = alpha),
      shen = cureAssess::shen.test(dat = prepared, alpha = alpha)
    ),
    error = function(e) NULL
  )
}


# ---- UI -------------------------------------------------------------------

#' Quantitative tab UI.
#'
#' One vertical flow: run control, AIC table, best-model callout, fitted-curve
#' overlay, the five diagnostic cards, then the threshold and sensitivity
#' controls.
mod_quantitative_ui <- function(id) {
  ns <- NS(id)

  htmltools::tagList(

    # ---- 1. the run control -----------------------------------------------
    htmltools::tags$section(
      class = "ca-section",
      htmltools::h2(class = "ca-section__title", "Quantitative assessment"),
      htmltools::p(
        class = "ca-lede",
        paste0(
          "Fit the candidate models, rank them by AIC, and run the five ",
          "diagnostics. Nothing is fitted until you press Run assessment."
        )
      ),
      uiOutput(ns("gate_msg")),
      htmltools::div(
        class = "ca-card",
        htmltools::div(
          class = "ca-card__body",
          checkboxInput(
            ns("include_lognormal"),
            label = "Also fit lognormal models",
            value = FALSE
          ),
          htmltools::p(
            class = "ca-lede",
            paste0(
              "Off by default. The lognormal distribution has a heavy tail ",
              "that can change both the selected model and the RECeUS ",
              "conclusion."
            )
          ),
          actionButton(ns("run"), "Run assessment", class = "btn-primary"),
          uiOutput(ns("run_msg"))
        )
      )
    ),

    # ---- 2 + 3. the AIC table and the best-model callout -------------------
    htmltools::tags$section(
      class = "ca-section",
      htmltools::h3(class = "ca-section__title", "Candidate models, ranked by AIC"),
      uiOutput(ns("models_msg")),
      uiOutput(ns("aic_wrap")),
      uiOutput(ns("best_callout"))
    ),

    # ---- 4. the fitted-curve overlay --------------------------------------
    htmltools::tags$section(
      class = "ca-section",
      htmltools::h3(class = "ca-section__title", "Fitted curve over the Kaplan-Meier estimate"),
      selectInput(
        ns("overlay_model"),
        label = "Model to overlay",
        choices = character(0),
        selected = NULL,
        width = "22rem"
      ),
      uiOutput(ns("overlay_msg")),
      plotOutput(ns("overlay_plot"), height = "380px")
    ),

    # ---- 5. the five diagnostics ------------------------------------------
    htmltools::tags$section(
      class = "ca-section",
      htmltools::h3(class = "ca-section__title", "The five diagnostics"),
      uiOutput(ns("diag_head")),
      uiOutput(ns("diag_msg")),

      # ---- 7a. thresholds that are genuine package arguments --------------
      htmltools::div(
        class = "ca-card",
        htmltools::div(
          class = "ca-card__head",
          htmltools::span(class = "ca-card__title", "Thresholds")
        ),
        htmltools::div(
          class = "ca-card__body",
          sliderInput(
            ns("alpha"),
            label = htmltools::span(
              htmltools::span(class = "ca-nocaps", "α"),
              " for Maller–Zhou and Shen"
            ),
            min = 0.01, max = 0.20, value = .QUANT_ALPHA_DEFAULT, step = 0.005,
            width = "24rem"
          ),
          htmltools::div(
            actionLink(ns("alpha_reset"), "Reset α to the package default (0.05)"),
            htmltools::span(" · "),
            actionLink(ns("reset_all"), "Reset every threshold to the package default")
          ),
          uiOutput(ns("alpha_msg"))
        )
      ),

      htmltools::div(
        class = "ca-grid-2",
        uiOutput(ns("card_mz")),
        uiOutput(ns("card_qn")),
        uiOutput(ns("card_shen")),
        uiOutput(ns("card_immune")),
        uiOutput(ns("card_receus"))
      )
    ),

    # ---- 7b. RECeUS exploration -------------------------------------------
    htmltools::tags$section(
      class = "ca-section",
      htmltools::h3(class = "ca-section__title", "Explore RECeUS"),
      htmltools::p(
        class = "ca-lede",
        paste0(
          "Everything in this section is exploration. None of it changes the ",
          "result above, and none of it reaches the Conclusion tab."
        )
      ),

      htmltools::div(
        class = "ca-card",
        htmltools::div(
          class = "ca-card__head",
          htmltools::span(class = "ca-card__title", "Distribution behind RECeUS")
        ),
        htmltools::div(
          class = "ca-card__body",
          selectInput(
            ns("receus_dist"),
            label = "RECeUS distribution",
            choices = .QUANT_RECEUS_DISTS,
            selected = "",
            width = "28rem"
          ),
          actionButton(ns("receus_apply"), "Re-run diagnostics with this distribution"),
          uiOutput(ns("receus_msg"))
        )
      ),

      htmltools::div(
        class = "ca-card",
        htmltools::div(
          class = "ca-card__head",
          htmltools::span(class = "ca-card__title", "Evaluation time τ")
        ),
        htmltools::div(
          class = "ca-card__body",
          sliderInput(
            ns("tau_idx"),
            label = "Evaluation time (earliest to latest)",
            min = 1, max = 25, value = 25, step = 1, ticks = FALSE,
            width = "24rem"
          ),
          uiOutput(ns("tau_label")),
          actionButton(ns("tau_apply"), "Re-run RECeUS at this τ"),
          htmltools::span(" "),
          actionButton(ns("tau_curve_run"), "Draw π̂ and r̂ across τ"),
          htmltools::div(actionLink(ns("tau_reset"), "Reset τ to the largest observed time")),
          uiOutput(ns("tau_msg")),
          # INTEGRATOR: emitted only once a curve exists. A bare
          # plotOutput(height = "280px") reserved its full height from first
          # paint, so the card opened with a 280px hole under the controls.
          uiOutput(ns("tau_plot_wrap")),
          uiOutput(ns("tau_caption"))
        )
      ),

      # ---- 7c. the category-C what-if panel (§H.4, §J.7) ------------------
      # The two sliders are static, not re-emitted by renderUI, so dragging
      # one cannot rebuild the panel underneath the user's cursor. Only the
      # prose around them is rendered.
      htmltools::div(
        class = "ca-sens",
        uiOutput(ns("sens_head")),
        htmltools::div(
          class = "ca-sens__row",
          sliderInput(
            ns("sens_pi_cut"),
            htmltools::span(htmltools::span(class = "ca-nocaps", "π̂"), " cutoff (yours)"),
            min = 0, max = 0.5, value = .QUANT_PI_CUT, step = 0.005, width = "22rem"
          ),
          sliderInput(
            ns("sens_r_cut"),
            htmltools::span(htmltools::span(class = "ca-nocaps", "r̂"), " cutoff (yours)"),
            min = 0, max = 0.5, value = .QUANT_R_CUT, step = 0.005, width = "22rem"
          ),
          actionLink(ns("sens_reset"), "Reset both cutoffs to the package values")
        ),
        uiOutput(ns("sens_panel"))
      )
    )
  )
}


# ---- server ---------------------------------------------------------------

#' Quantitative tab server.
#'
#' Owns the single cure.appropriateness() call site in the app (§I.6), the
#' alpha re-calls of mz.test()/shen.test() (§I.7, §I.8), and the two
#' render-time-only RECeUS explorations (§I.9, §I.10).
mod_quantitative_server <- function(id, state, go_to) {
  moduleServer(id, function(input, output, session) {

    ns <- session$ns

    # Render-time locals. Contract §C.3 and forbidden-list item 8: an
    # exploration result never touches `state`.
    override_tests <- reactiveVal(NULL)   # run.cure.tests() result (§I.9)
    override_dist <- reactiveVal("")      # the short code behind it
    tau_result <- reactiveVal(NULL)       # receus.method() at a chosen tau (§I.10)
    tau_curve <- reactiveVal(NULL)        # the tau ladder, list(data =, k =)
    qn_flag <- reactiveVal(NA)            # §K startup assertion outcome

    # ---- navigation ------------------------------------------------------
    ca_on_click(input, "to_data", function() go_to("data"))

    # ---- the tau ladder --------------------------------------------------
    tau_grid_r <- reactive({
      if (is.null(state$prepared)) return(numeric(0))
      .quant_tau_grid(state$prepared$Y)     # prepare.surv.data() output column Y
    })

    observeEvent(tau_grid_r(), {
      g <- tau_grid_r()
      k <- max(length(g), 1L)
      updateSliderInput(session, "tau_idx", max = k, value = k)
      tau_result(NULL)
      tau_curve(NULL)
    }, ignoreInit = FALSE)

    tau_value_r <- reactive({
      g <- tau_grid_r()
      i <- input$tau_idx
      if (!length(g) || is.null(i) || !is.finite(i)) return(NA_real_)
      i <- max(1L, min(length(g), as.integer(i)))
      g[[i]]
    })

    # ---- 1. THE RUN CONTROL ---------------------------------------------
    # The only place cure.appropriateness() is called (§I.6). Wrapped in
    # withProgress with the two named steps and in tryCatch (R11).
    ca_on_click(input, "run", function() {
      if (is.null(state$prepared)) return(invisible(NULL))

      use_lognormal <- isTRUE(input$include_lognormal)
      prepared <- state$prepared

      # §I.6 — the single cure.appropriateness() call site in the app.
      # suppressMessages(): survminer's ggsurvplot emits the cosmetic ggplot2
      # 4.x note 'Ignoring unknown labels: fill "Strata"' while it builds the
      # risk table. Warnings and errors are untouched.
      ca_assess_once <- function() {
        suppressMessages(cureAssess::cure.appropriateness(
          data              = prepared,
          time              = "Y",
          status            = "D",
          time_scale        = "none",   # R12 — prepared is already scaled
          dist              = NULL,
          plot_km           = TRUE,
          run_tests         = "yes",    # R4 — never "auto"
          include_lognormal = use_lognormal
        ))
      }

      res <- tryCatch(
        withProgress(message = "Running assessment", value = 0, {
          incProgress(0.05, detail = "Fitting candidate models")
          # §I.5 — cure.appropriateness() discards the fitted objects, so the
          # overlay needs its own model.fitting() call for $fits[[m]]$fit.
          fit <- suppressMessages(cureAssess::model.fitting(
            data = prepared, plot_km = TRUE, include_lognormal = use_lognormal
          ))
          incProgress(0.45, detail = "Running diagnostics")
          assess <- ca_assess_once()
          incProgress(0.50)
          list(fit = fit, assess = assess, error = NULL)
        }),
        error = function(e) list(fit = NULL, assess = NULL, error = conditionMessage(e))
      )

      if (!is.null(res$error)) {
        # §C.1 "Run fails": last_error set, assess and alpha_tests nulled.
        state$assess <- NULL
        state$alpha_tests <- NULL
        state$last_error <- res$error
        state$status <- "error"
        qn_flag(NA)
        override_tests(NULL); override_dist(""); tau_result(NULL); tau_curve(NULL)
        return(invisible(NULL))
      }

      # §C.1 "Run succeeds".
      state$include_lognormal <- use_lognormal
      state$fit <- res$fit
      state$assess <- res$assess
      state$alpha_tests <- .quant_alpha_tests(prepared, state$alpha)
      state$last_error <- NULL
      state$status <- "assessed"

      # A fresh run invalidates every exploration built on the old one.
      override_tests(NULL); override_dist(""); tau_result(NULL); tau_curve(NULL)

      # §K startup assertion: the qn chip direction must match the package's
      # own sentence at alpha = 0.05.
      if (ca_has_tests(state)) {
        thr <- ca_qn_threshold(nrow(prepared), .QUANT_ALPHA_DEFAULT)
        ok <- .quant_qn_direction_ok(state$assess$tests$qn, thr)
        qn_flag(ok)
        if (identical(ok, FALSE)) {
          warning(
            "cureAssessApp: qn direction check failed. The app's chip and ",
            "cureAssess's own qn interpretation string disagree at alpha = 0.05. ",
            "This is a blocking build error (BUILD CONTRACT sections J.0 and K).",
            call. = FALSE
          )
        }
      } else {
        qn_flag(NA)
      }

      invisible(NULL)
    })

    # ---- 7. THRESHOLD CONTROLS -------------------------------------------
    # Category A: alpha is a genuine argument of mz.test() and shen.test().
    alpha_r <- debounce(reactive(input$alpha), 400)

    observeEvent(alpha_r(), {
      a <- alpha_r()
      if (is.null(a) || !is.finite(a)) return(invisible(NULL))
      state$alpha <- a
      # §I.7 + §I.8 — direct calls at the user's alpha; NULL at the default.
      state$alpha_tests <- .quant_alpha_tests(state$prepared, a)
      invisible(NULL)
    }, ignoreInit = TRUE)

    ca_on_click(input, "alpha_reset", function() {
      updateSliderInput(session, "alpha", value = .QUANT_ALPHA_DEFAULT)
    })

    ca_on_click(input, "sens_reset", function() {
      # FIXPASS (3.2): the two reset links are actionLinks, and a browser does
      # not block a click on an <a disabled> the way it blocks one on a
      # <button disabled>, so the disabled attribute set below has to be
      # honoured here too rather than left as a claim the element does not
      # keep. The card's empty state says why it is off.
      if (!isTRUE(explore_ready_r())) return(invisible(NULL))
      updateSliderInput(session, "sens_pi_cut", value = .QUANT_PI_CUT)
      updateSliderInput(session, "sens_r_cut", value = .QUANT_R_CUT)
    })

    ca_on_click(input, "tau_reset", function() {
      # FIXPASS (3.2): same as sens_reset — an <a disabled> still fires.
      if (!isTRUE(explore_ready_r())) return(invisible(NULL))
      k <- max(length(tau_grid_r()), 1L)
      updateSliderInput(session, "tau_idx", value = k)
      tau_result(NULL)
    })

    # One control returns every threshold in this tab to the package default.
    ca_on_click(input, "reset_all", function() {
      updateSliderInput(session, "alpha", value = .QUANT_ALPHA_DEFAULT)
      updateSliderInput(session, "sens_pi_cut", value = .QUANT_PI_CUT)
      updateSliderInput(session, "sens_r_cut", value = .QUANT_R_CUT)
      updateSelectInput(session, "receus_dist", selected = "")
      updateSliderInput(session, "tau_idx", value = max(length(tau_grid_r()), 1L))
      override_tests(NULL); override_dist(""); tau_result(NULL); tau_curve(NULL)
    })

    # ---- §I.9 the RECeUS distribution override ---------------------------
    # FIXPASS (3.2): every control in the "Explore RECeUS" section explores a
    # result. Before Run there is no result, so the four exploration buttons
    # were live but inert — their handlers opened with req(ca_has_tests(state)),
    # which raises a silent condition and aborts, so a click did nothing at all
    # and said nothing at all. They are now disabled until an assessment with a
    # usable $tests list exists, the same way receus_apply was already handled,
    # and each card carries the empty state that says why (see tau_msg,
    # receus_msg and sens_head below).
    explore_ready_r <- reactive(ca_has_tests(state))

    observe({
      ready <- isTRUE(explore_ready_r())
      updateActionButton(session, "tau_apply", disabled = !ready)
      updateActionButton(session, "tau_curve_run", disabled = !ready)
      updateActionButton(session, "tau_reset", disabled = !ready)
      updateActionButton(session, "sens_reset", disabled = !ready)
      # The apply button additionally needs a short code to be picked.
      updateActionButton(
        session, "receus_apply",
        disabled = !ready || !nzchar(input$receus_dist %||% "")
      )
      invisible(NULL)
    })

    observeEvent(input$receus_dist, {
      if (!nzchar(input$receus_dist %||% "")) {
        override_tests(NULL)
        override_dist("")
      }
    }, ignoreInit = FALSE)

    ca_on_click(input, "receus_apply", function() {
      req(state$prepared)
      d <- input$receus_dist
      if (is.null(d) || !nzchar(d)) return(invisible(NULL))
      res <- tryCatch(
        cureAssess::run.cure.tests(data = state$prepared, dist = d),
        error = function(e) structure(list(msg = conditionMessage(e)), class = "quant_failed")
      )
      if (inherits(res, "quant_failed")) {
        override_tests(NULL)
        override_dist("")
        showNotification(
          paste0("run.cure.tests() failed for distribution \"", d, "\": ", res$msg),
          type = "error", duration = 10
        )
        return(invisible(NULL))
      }
      override_tests(res)   # render-time local; never written to state
      override_dist(d)
      invisible(NULL)
    })

    # ---- §I.10 the tau sensitivity control -------------------------------
    ca_on_click(input, "tau_apply", function() {
      req(state$prepared)
      req(ca_has_tests(state))
      tau <- tau_value_r()
      req(is.finite(tau))
      if (!is.finite(tau)) return(NULL)   # a cleared input yields NA; guard hard
      d <- state$assess$selected_receus_dist   # §I.11 — never re-map the name
      if (is.null(d) || is.na(d)) return(invisible(NULL))
      res <- tryCatch(
        cureAssess::receus.method(data = state$prepared, dist = d, whichTau = tau),
        error = function(e) NULL
      )
      tau_result(res)       # render-time local; never written to state
      invisible(NULL)
    })

    ca_on_click(input, "tau_curve_run", function() {
      req(state$prepared)
      req(ca_has_tests(state))
      g <- tau_grid_r()
      req(length(g) > 0)
      d <- state$assess$selected_receus_dist
      if (is.null(d) || is.na(d)) return(invisible(NULL))
      k <- length(g)
      rows <- withProgress(message = "Recomputing RECeUS across evaluation times", value = 0, {
        pieces <- lapply(seq_len(k), function(i) {
          incProgress(1 / k, detail = paste0("Evaluation time ", i, " of ", k))
          tau <- g[[i]]
          if (!is.finite(tau)) return(NULL)
          r <- tryCatch(
            cureAssess::receus.method(data = state$prepared, dist = d, whichTau = tau),
            error = function(e) NULL
          )
          if (is.null(r)) return(NULL)
          # Every column is a package return field: $tau, $pi_hat, $r_hat.
          data.frame(tau = r$tau, pi_hat = r$pi_hat, r_hat = r$r_hat)
        })
        pieces <- pieces[!vapply(pieces, is.null, logical(1))]
        if (!length(pieces)) NULL else do.call(rbind, pieces)
      })
      tau_curve(list(data = rows, k = k))
      invisible(NULL)
    })

    # ---- the test list every card reads ----------------------------------
    # Canonical = state$assess$tests. A distribution override replaces the base
    # list for display only. The alpha-recomputed Maller-Zhou and Shen are
    # merged over whichever base is in force, because alpha is a genuine
    # argument of those two functions regardless of the RECeUS distribution.
    tests_r <- reactive({
      base <- if (!is.null(override_tests())) override_tests() else {
        if (!ca_has_tests(state)) return(NULL)
        state$assess$tests
      }
      .quant_merge_alpha(base, state$alpha_tests)
    })

    # ---- 8. EMPTY AND ERROR STATES ---------------------------------------
    # Every cross-tab block offers the control that unblocks it. Same-tab
    # blocks name the control that is already on screen rather than cloning
    # its input id.
    output$gate_msg <- renderUI({
      if (!is.null(state$prepared)) return(NULL)
      ca_empty(
        "Prepare a dataset on the Data step first — there is nothing to fit yet.",
        action_id = ns("to_data"),
        action_label = "Go to Data →"
      )
    })

    output$run_msg <- renderUI({
      if (is.null(state$prepared)) return(NULL)

      if (identical(state$status, "error") && !is.null(state$last_error)) {
        return(htmltools::tagList(
          ca_empty(paste0(
            "The assessment could not be completed. This usually means the ",
            "maximum-likelihood fit behind RECeUS did not converge on this dataset."
          )),
          ca_tech(htmltools::tags$pre(class = "ca-mono", state$last_error))
        ))
      }

      if (is.null(state$assess)) {
        if (identical(state$status, "data_loaded")) {
          # FIXPASS (3.2, wording): this said "Press Run assessment again",
          # which sends the user to the wrong button. Status "data_loaded"
          # with a prepared frame in hand means the Data step's mapping
          # changed after the frame was prepared, so state$prepared is the OLD
          # frame: running here would assess the previous mapping. The Data
          # step has to be re-prepared first.
          return(ca_empty(
            paste0(
              "The dataset or the column mapping changed on the Data step, so ",
              "the previous assessment no longer applies and the prepared data ",
              "behind this tab is out of date. Press Prepare data on the Data ",
              "step first, then come back and press Run assessment."
            ),
            action_id = ns("to_data"),
            action_label = "Go to Data →"
          ))
        }
        return(ca_empty(
          "Press Run assessment to fit the candidate models and run the five diagnostics."
        ))
      }

      # The candidate set was toggled after the run that produced the table.
      if (!identical(isTRUE(input$include_lognormal), isTRUE(state$include_lognormal))) {
        return(ca_empty(paste0(
          "The candidate set changed. The table below is from the previous run ",
          "— press Run assessment to update it."
        )))
      }
      NULL
    })

    stale_r <- reactive({
      !is.null(state$assess) &&
        !identical(isTRUE(input$include_lognormal), isTRUE(state$include_lognormal))
    })

    output$models_msg <- renderUI({
      if (is.null(state$assess)) return(NULL)
      bm <- state$assess$screening$best_model      # chr or NA (§I.11)
      if (length(bm) && is.na(bm)) {
        return(ca_empty(paste0(
          "No candidate model could be fitted to this dataset. The reason for ",
          "each failure is in the table below."
        )))
      }
      NULL
    })

    # ---- 2. THE AIC TABLE -------------------------------------------------
    output$aic_wrap <- renderUI({
      if (is.null(state$assess)) return(NULL)
      htmltools::div(
        class = if (isTRUE(stale_r())) "is-stale" else NULL,
        DTOutput(ns("aic_table"))
      )
    })

    output$aic_table <- renderDT({
      req(state$assess)
      tbl <- state$assess$screening$aic_table   # §I.11 — the one AIC source

      disp <- data.frame(
        model = tbl$model,                                     # $aic_table$model
        # Badge read from the model_type column, never inferred from the name.
        type = vapply(
          tbl$model_type,
          function(x) as.character(ca_chip("neutral", x)),      # $aic_table$model_type
          character(1)
        ),
        AIC = vapply(tbl$AIC, function(x) ca_num(x, 2), character(1)),  # $aic_table$AIC
        parameter_estimates = vapply(
          tbl$parameter_estimates,
          function(x) if (is.na(x)) ca_dash() else as.character(x),      # $aic_table$parameter_estimates
          character(1)
        ),
        error = vapply(
          tbl$error,
          function(x) if (!nzchar(x)) ca_dash() else as.character(x),     # $aic_table$error
          character(1)
        ),
        stringsAsFactors = FALSE
      )
      # Hidden sort key: the row order model.fitting() returned, which is AIC
      # ascending with the NA rows last. Not a computation — it is the
      # package's own ordering, kept so the displayed em-dash AIC cells do not
      # sort lexically and failed fits stay at the bottom.
      disp$.aic_order <- seq_len(nrow(disp))

      datatable(
        disp,
        rownames = FALSE,
        selection = "none",
        escape = -2,                       # only the badge column carries HTML
        colnames = c("Model", "Type", "AIC", "Parameter estimates", "Error", "order"),
        class = "compact stripe hover",
        options = list(
          dom = "t",
          paging = FALSE,
          ordering = TRUE,
          scrollX = FALSE,
          autoWidth = FALSE,
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

    # ---- 3. THE BEST-MODEL CALLOUT ---------------------------------------
    output$best_callout <- renderUI({
      if (is.null(state$assess)) return(NULL)
      scr <- state$assess$screening
      bm <- scr$best_model                       # $screening$best_model
      bt <- scr$best_model_type                  # $screening$best_model_type

      head_line <- if (length(bm) && !is.na(bm)) {
        htmltools::p(
          htmltools::strong("Best model by AIC: "),
          htmltools::span(class = "ca-mono", bm),
          htmltools::span(" "),
          ca_chip("neutral", .quant_chr(bt))
        )
      } else {
        htmltools::p(htmltools::strong("Best model by AIC: "), ca_dash())
      }

      ca_note(
        "interpret",
        "What the AIC ranking does and does not say",
        htmltools::tagList(
          head_line,
          # $screening$initial_decision, verbatim.
          htmltools::p(scr$initial_decision),
          htmltools::p(.QUANT_AIC_CAVEAT),
          ca_provenance("cure.appropriateness() -> $screening$initial_decision")
        )
      )
    })

    # ---- 4. THE FITTED-CURVE OVERLAY -------------------------------------
    # Choices are the models whose error is empty; the default is the best
    # model. Both read off the AIC table, which is AIC order.
    observeEvent(state$assess, {
      if (is.null(state$assess)) {
        updateSelectInput(session, "overlay_model", choices = character(0))
        return(invisible(NULL))
      }
      tbl <- state$assess$screening$aic_table
      ok <- tbl$model[tbl$error == ""]                 # $aic_table$error
      bm <- state$assess$screening$best_model
      sel <- if (length(bm) && !is.na(bm) && bm %in% ok) bm else if (length(ok)) ok[[1L]] else NULL
      updateSelectInput(session, "overlay_model", choices = ok, selected = sel)
      invisible(NULL)
    }, ignoreNULL = FALSE)

    overlay_failed_r <- reactive({
      if (is.null(state$assess)) return(FALSE)
      m <- input$overlay_model
      if (is.null(m) || !nzchar(m)) return(FALSE)
      tbl <- state$assess$screening$aic_table
      row <- tbl[tbl$model == m, , drop = FALSE]
      if (!nrow(row)) return(TRUE)
      nzchar(row$error[[1L]])                          # $aic_table$error
    })

    output$overlay_msg <- renderUI({
      if (is.null(state$prepared)) return(NULL)
      if (is.null(state$assess)) {
        return(ca_empty(
          "Press Run assessment to fit the candidate models and run the five diagnostics."
        ))
      }
      if (isTRUE(overlay_failed_r())) {
        return(ca_empty("This model did not fit, so there is no curve to draw."))
      }
      NULL
    })

    output$overlay_plot <- renderPlot({
      req(state$fit)
      km <- .quant_km_frame(state$fit$kmfit)           # $fit$kmfit
      req(!is.null(km))
      pal <- .quant_palette(isTRUE(state$dark))
      # FIXPASS (3.5a): .quant_km_frame() now omits the confidence limits and
      # the censoring counts when the survfit object does not carry them, so
      # neither column may be assumed to exist here.
      censor <- if ("n_censor" %in% names(km)) {
        km[km$n_censor > 0, c("time", "surv"), drop = FALSE]
      } else {
        km[0L, c("time", "surv"), drop = FALSE]
      }
      # survfit() leaves $lower/$upper NA where the band is undefined; drop
      # those rows so the ribbon does not warn. Nothing is imputed.
      band <- if (all(c("lower", "upper") %in% names(km))) {
        km[stats::complete.cases(km[, c("time", "lower", "upper")]), , drop = FALSE]
      } else {
        NULL
      }

      m <- input$overlay_model
      ov <- NULL
      lab <- NULL
      if (!is.null(m) && nzchar(m) && !isTRUE(overlay_failed_r())) {
        fit_obj <- state$fit$fits[[m]]$fit             # $fit$fits[[m]]$fit
        if (!is.null(fit_obj)) {
          grid <- seq(0, max(km$time, na.rm = TRUE), length.out = 200)
          ov <- .quant_overlay_frame(fit_obj, grid)
          lab <- paste0("Fitted: ", m)
        }
      }

      series <- c("Kaplan-Meier")
      cols <- c(pal$km)
      if (!is.null(ov)) { series <- c(series, lab); cols <- c(cols, pal$fit) }

      p <- ggplot()
      # FIXPASS (3.5a): the ribbon is added only when the survfit object
      # actually carried confidence limits.
      if (!is.null(band) && nrow(band)) {
        p <- p + geom_ribbon(
          data = band,
          aes(x = .data$time, ymin = .data$lower, ymax = .data$upper),
          fill = pal$band, alpha = 0.14
        )
      }
      p <- p +
        geom_step(
          data = km,
          aes(x = .data$time, y = .data$surv, colour = "Kaplan-Meier"),
          linewidth = 0.7
        )

      if (nrow(censor)) {
        p <- p + geom_point(
          data = censor,
          aes(x = .data$time, y = .data$surv),
          colour = pal$km, shape = 3, size = 1.5, alpha = 0.7
        )
      }
      if (!is.null(ov)) {
        p <- p + geom_line(
          data = ov,
          aes(x = .data$time, y = .data$surv, colour = lab),
          linewidth = 0.9
        )
      }

      p +
        scale_colour_manual(values = stats::setNames(cols, series), name = NULL) +
        coord_cartesian(ylim = c(0, 1)) +
        labs(x = "Time", y = "Survival probability") +
        theme_cure_assess(dark = isTRUE(state$dark))
    }, res = 108, bg = "transparent")

    # ---- 5. THE FIVE DIAGNOSTIC CARDS ------------------------------------
    output$diag_head <- renderUI({
      if (is.null(state$assess)) return(NULL)
      dist_used <- if (nzchar(override_dist())) override_dist() else
        .quant_chr(state$assess$selected_receus_dist)   # $selected_receus_dist
      model_used <- .quant_chr(state$assess$selected_receus_model)  # $selected_receus_model

      htmltools::tagList(
        htmltools::p(
          class = "ca-lede",
          "RECeUS distribution in use: ",
          htmltools::span(class = "ca-mono", dist_used),
          if (!identical(model_used, ca_dash())) {
            htmltools::span(" (mapped from the smallest-AIC cure model ",
                            htmltools::span(class = "ca-mono", model_used), ")")
          }
        ),
        htmltools::p(
          class = "ca-lede",
          paste0(
            "The diagnostics are shown even when a non-cure model won on AIC: ",
            "“a non-cure model fits better” and “there is no ",
            "cure fraction to find” are different claims."
          )
        ),
        if (nzchar(override_dist())) {
          ca_banner(
            paste0(
              "Showing diagnostics for distribution “", override_dist(),
              "”, chosen by hand. The Conclusion tab still uses the ",
              "automatically selected distribution “",
              .quant_chr(state$assess$selected_receus_dist), "”."
            ),
            variant = "override"
          )
        },
        if (!is.null(state$alpha_tests)) {
          ca_banner(
            paste0(
              "Maller–Zhou and Shen are shown at α = ",
              ca_num(state$alpha, 3), ", not the package default 0.05. The ",
              "app-computed qn threshold below uses the same α."
            ),
            variant = "override"
          )
        }
      )
    })

    output$diag_msg <- renderUI({
      if (is.null(state$prepared)) return(NULL)
      if (is.null(state$assess)) {
        return(ca_empty(
          "Press Run assessment to fit the candidate models and run the five diagnostics."
        ))
      }
      if (!isTRUE(state$assess$tests_run)) {                 # $tests_run
        return(htmltools::tagList(
          htmltools::h4(class = "ca-section__title", "The diagnostics were not run"),
          htmltools::p(state$assess$tests_reason),           # $tests_reason, verbatim
          ca_provenance("cure.appropriateness() -> $tests_reason")
        ))
      }
      NULL
    })

    output$alpha_msg <- renderUI({
      a <- input$alpha
      if (is.null(a)) return(NULL)
      if (is.finite(a) && a >= 0.01 && a <= 0.20) return(NULL)
      ca_empty("α must be between 0.01 and 0.20. Reset to the package default 0.05?")
    })

    # -- Maller-Zhou 1994 --------------------------------------------------
    output$card_mz <- renderUI({
      tt <- tests_r()
      if (is.null(tt)) return(NULL)
      mz <- tt$mz
      stat <- mz$statistic                        # $tests$mz$statistic
      alpha <- mz$alpha                           # $tests$mz$alpha
      void <- !is.finite(stat)

      chip <- if (void) {
        ca_chip("void", "Cannot be computed", glyph = "dash")
      } else if (stat < alpha) {
        ca_chip("pass", "Follow-up looks sufficient")
      } else {
        ca_chip("fail", "Not sufficient")
      }

      ca_card(
        title = "Maller–Zhou test (1994)",
        chip = chip,
        lede = .QUANT_LEDE_MZ,
        body = htmltools::tagList(
          .quant_stat("Statistic", ca_num(stat), void = void),
          .quant_threshold(
            paste0("α = ", ca_num(alpha, 3)),
            "smaller is better — below α supports sufficient follow-up"
          ),
          if (void) .quant_void_body(),
          ca_tech(htmltools::tagList(
            htmltools::p(class = "ca-tech__body", mz$interpretation),  # verbatim
            htmltools::p(class = "ca-mono", mz$method)                 # $tests$mz$method
          ))
        ),
        foot = ca_provenance("cure.appropriateness() -> $tests$mz$statistic")
      )
    })

    # -- qn ----------------------------------------------------------------
    output$card_qn <- renderUI({
      tt <- tests_r()
      if (is.null(tt) || is.null(state$prepared)) return(NULL)
      qn <- tt$qn
      stat <- qn$statistic                        # $tests$qn$statistic
      n <- nrow(state$prepared)
      # §F.4 / R2 — the single closed form the app is permitted to evaluate.
      # qn.test() returns no threshold field, so this value is app-computed.
      thr <- ca_qn_threshold(n, state$alpha)
      void <- !is.finite(stat)

      chip <- if (void || !is.finite(thr)) {
        ca_chip("void", "Cannot be computed", glyph = "dash")
      } else if (stat > thr) {
        ca_chip("pass", "Follow-up looks sufficient")
      } else {
        ca_chip("fail", "Not sufficient")
      }

      mismatch <- identical(qn_flag(), FALSE) &&
        is.null(state$alpha_tests) && is.null(override_tests())

      ca_card(
        title = "qn statistic (Maller & Zhou 1996)",
        chip = chip,
        lede = .QUANT_LEDE_QN,
        body = htmltools::tagList(
          .quant_stat("Statistic", ca_num(stat), void = void),
          .quant_threshold(
            htmltools::tagList(
              htmltools::span("1 − α^(1/n) = "),
              htmltools::span(ca_num(thr, 7)),
              htmltools::span(" "),
              ca_tip(
                "computed by this app",
                paste0(
                  "qn.test() returns no threshold field, so the app renders ",
                  "the closed form 1 - alpha^(1/n) from alpha and n = ", n,
                  ". The package's own sentence, below, always quotes its own ",
                  "fixed 0.05 version."
                )
              )
            ),
            "larger is better — above the threshold supports sufficient follow-up"
          ),
          if (void) .quant_void_body(),
          if (!is.null(state$alpha_tests)) {
            htmltools::p(
              class = "ca-lede",
              paste0(
                "The threshold above is computed at α = ",
                ca_num(state$alpha, 3),
                ". The package sentence below is fixed at α = 0.05 and is ",
                "shown unchanged."
              )
            )
          },
          ca_tech(htmltools::tagList(
            htmltools::p(class = "ca-tech__body", qn$interpretation),  # verbatim, alpha = 0.05
            htmltools::p(class = "ca-mono", qn$method),                # $tests$qn$method
            if (mismatch) {
              htmltools::p(
                class = "ca-mono",
                paste0(
                  "Direction check FAILED: at α = 0.05 the app's chip and ",
                  "the package's own qn sentence disagree. This is a build ",
                  "error — please report it."
                )
              )
            }
          ))
        ),
        foot = ca_provenance("cure.appropriateness() -> $tests$qn$statistic")
      )
    })

    # -- Shen 2000 ---------------------------------------------------------
    output$card_shen <- renderUI({
      tt <- tests_r()
      if (is.null(tt)) return(NULL)
      sh <- tt$shen
      stat <- sh$statistic                        # $tests$shen$statistic
      alpha <- sh$alpha                           # $tests$shen$alpha
      void <- !is.finite(stat)

      chip <- if (void) {
        ca_chip("void", "Cannot be computed", glyph = "dash")
      } else if (stat < alpha) {
        ca_chip("pass", "Follow-up looks sufficient")
      } else {
        ca_chip("fail", "Not sufficient")
      }

      ca_card(
        title = "Shen test (2000)",
        chip = chip,
        lede = .QUANT_LEDE_SHEN,
        body = htmltools::tagList(
          .quant_stat("Statistic", ca_num(stat), void = void),
          .quant_threshold(
            paste0("α = ", ca_num(alpha, 3)),
            "smaller is better — below α supports sufficient follow-up"
          ),
          if (void) .quant_void_body(),
          ca_tech(htmltools::tagList(
            htmltools::p(class = "ca-tech__body", sh$interpretation),  # verbatim
            htmltools::p(class = "ca-mono", sh$method)                 # $tests$shen$method
          ))
        ),
        foot = ca_provenance("cure.appropriateness() -> $tests$shen$statistic")
      )
    })

    # -- Immune summary ----------------------------------------------------
    output$card_immune <- renderUI({
      tt <- tests_r()
      if (is.null(tt)) return(NULL)
      im <- tt$immune

      ca_card(
        title = "Maller–Zhou immune summary (1996)",
        # R8 — descriptive, never pass/fail.
        chip = ca_chip("neutral", "Descriptive, not a test"),
        lede = .QUANT_LEDE_IMMUNE,
        body = htmltools::tagList(
          .quant_stat(
            "Event probability by the end of follow-up",
            ca_num(im$p_hat),                      # $tests$immune$p_hat
            void = !is.finite(im$p_hat)
          ),
          .quant_stat(
            "Censoring proportion",
            ca_num(im$p_cens),                     # $tests$immune$p_cens
            void = !is.finite(im$p_cens)
          ),
          .quant_stat(
            "Last observation",
            ca_num(im$last_observation),           # $tests$immune$last_observation
            void = !is.finite(im$last_observation)
          ),
          .quant_stat(
            "Last observation censored",
            # $tests$immune$last_observation_censored
            if (isTRUE(im$last_observation_censored)) "Yes"
            else if (isFALSE(im$last_observation_censored)) "No"
            else ca_dash()
          ),
          .quant_threshold("None", "there is no threshold, and the app does not invent one"),
          ca_tech(htmltools::tagList(
            htmltools::p(class = "ca-tech__body", im$interpretation),  # verbatim
            htmltools::p(class = "ca-mono", im$method)                 # $tests$immune$method
          ))
        ),
        foot = ca_provenance("cure.appropriateness() -> $tests$immune$p_hat")
      )
    })

    # -- RECeUS ------------------------------------------------------------
    output$card_receus <- renderUI({
      tt <- tests_r()
      if (is.null(tt)) return(NULL)
      rc <- tt$receus
      pi_hat <- rc$pi_hat                          # $tests$receus$pi_hat
      r_hat <- rc$r_hat                            # $tests$receus$r_hat
      void <- !is.finite(pi_hat) || !is.finite(r_hat)

      # FIXPASS (3.5b): .quant_receus_variant() stop()s on a decision string it
      # does not recognise, and ca_chip() stop()s on a variant it does not
      # recognise. Both fired inside this renderUI and surfaced as a red Shiny
      # error. The stop() stays — a loud failure is right, because the one
      # thing that must never happen is an unknown verdict rendering as a
      # neutral chip — but it is caught here and reported as a warning note
      # carrying the raw string. When it fires the card gets NO chip at all.
      chip <- NULL
      chip_error <- NULL
      if (void) {
        chip <- ca_chip("void", "Cannot be computed", glyph = "dash")
      } else {
        chip <- tryCatch(
          # $tests$receus$decision, verbatim as the chip label.
          ca_chip(.quant_receus_variant(rc$decision), rc$decision),
          error = function(e) {
            chip_error <<- conditionMessage(e)
            NULL
          }
        )
      }

      body <- if (void) {
        htmltools::tagList(
          .quant_stat("π̂", ca_dash(), void = TRUE),
          .quant_stat("r̂", ca_dash(), void = TRUE),
          ca_empty(.QUANT_VOID_RECEUS),
          htmltools::p(
            class = "ca-lede",
            "Try a different RECeUS distribution under Explore RECeUS below."
          )
        )
      } else {
        htmltools::tagList(
          .quant_stat("π̂ (estimated cure fraction)", ca_num(pi_hat)),
          .quant_stat("r̂ (uncured still censored at the end)", ca_num(r_hat)),
          htmltools::div(
            class = "ca-rec__conditions",
            # R10 — two separate ticks, each from the package's own logical.
            .quant_cond(
              paste0("π̂ = ", ca_num(pi_hat), " > ", .QUANT_PI_CUT),
              rc$cure_fraction_condition           # $tests$receus$cure_fraction_condition
            ),
            .quant_cond(
              paste0("r̂ = ", ca_num(r_hat), " < ", .QUANT_R_CUT),
              rc$followup_condition                # $tests$receus$followup_condition
            )
          ),
          htmltools::p(
            class = "ca-lede",
            paste0(
              "Evaluated at τ = ", ca_num(rc$tau),   # $tests$receus$tau
              ", the largest observed time."
            )
          ),
          htmltools::p(
            class = "ca-lede",
            "Distribution: ",
            htmltools::span(class = "ca-mono", .quant_chr(rc$dist))  # $tests$receus$dist
          )
        )
      }

      ca_card(
        title = "RECeUS",
        chip = chip,
        lede = .QUANT_LEDE_RECEUS,
        body = htmltools::tagList(
          # FIXPASS (3.5b): the caught chip failure, surfaced in the card
          # instead of as a red stack trace. The raw decision string is shown
          # so it can be reported verbatim.
          if (!is.null(chip_error)) {
            ca_note(
              "warning",
              "This RECeUS verdict could not be labelled",
              htmltools::tagList(
                htmltools::p(paste0(
                  "cureAssess returned a decision string this app does not ",
                  "recognise, so no verdict chip is shown for it — the app ",
                  "will not guess, and it will not show a neutral chip in ",
                  "place of a verdict. The package's own decision string is ",
                  "reproduced below and is unchanged."
                )),
                htmltools::p(
                  class = "ca-mono",
                  paste0("$tests$receus$decision = \"", .quant_chr(rc$decision), "\"")
                ),
                htmltools::p(class = "ca-mono", chip_error),
                htmltools::p(paste0(
                  "Please report this, with the dataset and the string above, ",
                  "to the cureAssessApp maintainers."
                ))
              )
            )
          },
          body,
          ca_tech(htmltools::tagList(
            htmltools::p(class = "ca-tech__body", rc$interpretation),  # verbatim
            htmltools::p(class = "ca-mono", rc$method)                 # $tests$receus$method
          ))
        ),
        foot = ca_provenance("cure.appropriateness() -> $tests$receus$r_hat")
      )
    })

    # ---- §I.9 override feedback ------------------------------------------
    output$receus_msg <- renderUI({
      if (is.null(state$prepared)) return(NULL)
      if (is.null(state$assess)) {
        return(ca_empty(
          "Press Run assessment to fit the candidate models and run the five diagnostics."
        ))
      }
      if (!nzchar(override_dist())) {
        return(htmltools::p(
          class = "ca-lede",
          paste0(
            "Leave this on Automatic to use the distribution the assessment ",
            "selected. Picking a short code by hand re-runs the five ",
            "diagnostics for display only."
          )
        ))
      }
      ca_banner(
        paste0(
          "The five cards above are showing distribution “", override_dist(),
          "”. Set the selector back to Automatic to return to the ",
          "assessment's own choice."
        ),
        variant = "override"
      )
    })

    # ---- §I.10 tau feedback ----------------------------------------------
    output$tau_label <- renderUI({
      # FIXPASS (3.2): this rendered "τ = 7.28 — the largest observed time…"
      # from the moment a dataset was prepared, which made the whole card look
      # live while its buttons did nothing. A τ is only meaningful next to a
      # RECeUS result, so the readout now waits for one.
      if (!ca_has_tests(state)) return(NULL)
      tau <- tau_value_r()
      g <- tau_grid_r()
      if (!length(g)) return(NULL)
      htmltools::p(
        class = "ca-lede",
        "τ = ", htmltools::span(class = "ca-mono", ca_num(tau)),
        if (isTRUE(all.equal(tau, max(g)))) {
          htmltools::span(" — the largest observed time, which is what receus.method() uses by default.")
        } else {
          htmltools::span(" — earlier than the largest observed time.")
        }
      )
    })

    output$tau_msg <- renderUI({
      # FIXPASS (3.2): returned NULL with no assessment, leaving the card's two
      # buttons and its reset link with nothing to explain them.
      empty <- .quant_explore_empty(state)
      if (!is.null(empty)) return(empty)
      out <- list()

      res <- tau_result()
      if (!is.null(res)) {
        out <- c(out, list(
          ca_banner(
            paste0(
              "Showing RECeUS at τ = ", ca_num(res$tau),   # $tau
              ", an evaluation time you chose. The card above, and everything ",
              "on the Conclusion tab, uses the largest observed time."
            ),
            variant = "override"
          ),
          htmltools::div(
            class = "ca-sens__row",
            .quant_stat("π̂ at this τ", ca_num(res$pi_hat),  # $pi_hat
                        void = !is.finite(res$pi_hat)),
            .quant_stat("r̂ at this τ", ca_num(res$r_hat),        # $r_hat
                        void = !is.finite(res$r_hat)),
            htmltools::p(class = "ca-lede", res$decision)                   # $decision, verbatim
          ),
          ca_provenance("receus.method(whichTau = ...) -> $pi_hat, $r_hat")
        ))
      }

      cur <- tau_curve()
      if (!is.null(cur)) {
        drawn <- if (is.null(cur$data)) 0L else sum(stats::complete.cases(cur$data))
        failed <- cur$k - drawn
        if (failed > 0L) {
          out <- c(out, list(ca_empty(paste0(
            failed, " of ", cur$k,
            " evaluation times could not be computed and are not plotted."
          ))))
        }
      }

      if (!length(out)) return(NULL)
      htmltools::tagList(out)
    })

    output$tau_plot <- renderPlot({
      cur <- tau_curve()
      req(!is.null(cur), !is.null(cur$data))
      d <- cur$data[stats::complete.cases(cur$data), , drop = FALSE]
      req(nrow(d) > 0)
      pal <- .quant_palette(isTRUE(state$dark))

      # Long form of two package fields against the evaluation time. No
      # smoothing, no fitting: every point is one receus.method() return.
      long <- rbind(
        data.frame(tau = d$tau, value = d$pi_hat, series = "π̂"),
        data.frame(tau = d$tau, value = d$r_hat, series = "r̂")
      )
      cuts <- data.frame(
        series = c("π̂", "r̂"),
        yint = c(.QUANT_PI_CUT, .QUANT_R_CUT)
      )

      ggplot(long, aes(x = .data$tau, y = .data$value)) +
        geom_hline(
          data = cuts, aes(yintercept = .data$yint),
          colour = pal$rule, linetype = "dashed", linewidth = 0.5
        ) +
        geom_line(colour = pal$fit, linewidth = 0.9) +
        facet_wrap(~ series, ncol = 2) +
        coord_cartesian(ylim = c(0, 1)) +
        labs(
          x = "Evaluation time τ",
          y = NULL,
          subtitle = "Dashed lines are the package cutoffs 0.025 and 0.05"
        ) +
        theme_cure_assess(dark = isTRUE(state$dark))
    }, res = 108, bg = "transparent")

    output$tau_plot_wrap <- renderUI({
      if (is.null(tau_curve())) return(NULL)
      plotOutput(session$ns("tau_plot"), height = "280px")
    })

    output$tau_caption <- renderUI({
      if (is.null(tau_curve())) return(NULL)
      ca_note(
        "warning",
        "Changing the evaluation time changes the estimate",
        htmltools::p(.QUANT_TAU_WARNING)
      )
    })

    # ---- 7c. THE CATEGORY-C SENSITIVITY PANEL (contract §H.4 and §J.7) ----
    # Writes nothing, overrides nothing, never leaves this panel. The package
    # decision stays canonical and stays on screen in the RECeUS card above
    # and is repeated here verbatim.
    sens_changed_r <- reactive({
      pi_cut <- input$sens_pi_cut %||% .QUANT_PI_CUT
      r_cut <- input$sens_r_cut %||% .QUANT_R_CUT
      !isTRUE(all.equal(pi_cut, .QUANT_PI_CUT)) ||
        !isTRUE(all.equal(r_cut, .QUANT_R_CUT))
    })

    # The panel's RECeUS result, or NULL when there is nothing to compare.
    sens_receus_r <- reactive({
      tt <- tests_r()
      if (is.null(tt)) return(NULL)
      rc <- tt$receus
      if (!is.finite(rc$pi_hat) || !is.finite(rc$r_hat)) return(NULL)
      rc
    })

    output$sens_head <- renderUI({
      rc <- sens_receus_r()
      # FIXPASS (3.2): both sens_head and sens_panel returned NULL before an
      # assessment, leaving two bare sliders and a reset link under a heading
      # with no text at all. The heading slot now carries the same empty state
      # the other two Explore RECeUS cards show.
      if (is.null(rc)) {
        empty <- .quant_explore_empty(state)
        if (!is.null(empty)) return(empty)
        # There IS an assessment, but RECeUS returned no usable π̂/r̂ for it.
        return(ca_empty(paste0(
          "RECeUS could not be computed for this dataset, so there are no π̂ ",
          "and r̂ to compare against your own cutoffs. The RECeUS card above ",
          "says why."
        )))
      }
      changed <- isTRUE(sens_changed_r())
      tick <- function(ok) if (isTRUE(ok)) "✓ passes" else "✗ fails"

      htmltools::div(
        # §H.4 item 4: off the package values, the panel gains the modifier and
        # the heading says so in words as well as in styling.
        class = if (changed) "ca-sens__head ca-sens--changed" else "ca-sens__head",
        htmltools::h4(
          class = "ca-section__title",
          paste0(
            "⚠ What-if: your own cutoffs — for discussion only ",
            if (changed) "(cutoffs changed from the package values)"
            else "(at the package values)"
          )
        ),
        htmltools::p(
          htmltools::strong("This panel does not change the result."),
          " The numbers 0.025 and 0.05 are written inside the ",
          htmltools::span(class = "ca-mono", "cureAssess"),
          " package and cannot be changed through it. The decision above — ",
          # $tests$receus$decision, verbatim
          htmltools::strong(paste0("“", rc$decision, "”")),
          " — is the package's decision, and it is the one that counts."
        ),
        htmltools::p(htmltools::strong(
          "The package's answer (fixed, and the only one used anywhere else in this app):"
        )),
        htmltools::div(
          class = "ca-sens__row",
          htmltools::p(paste0(
            "π̂ = ", ca_num(rc$pi_hat),        # $pi_hat
            " must be greater than 0.025 → ",
            tick(rc$cure_fraction_condition)             # the package's own logical
          )),
          htmltools::p(paste0(
            "r̂ = ", ca_num(rc$r_hat),              # $r_hat
            " must be less than 0.05 → ",
            tick(rc$followup_condition)                  # the package's own logical
          )),
          htmltools::p(
            "→ Package decision: ",
            htmltools::strong(paste0("“", rc$decision, "”"))
          )
        )
      )
    })

    output$sens_panel <- renderUI({
      rc <- sens_receus_r()
      if (is.null(rc)) return(NULL)
      pi_hat <- rc$pi_hat
      r_hat <- rc$r_hat
      pi_cut <- input$sens_pi_cut %||% .QUANT_PI_CUT
      r_cut <- input$sens_r_cut %||% .QUANT_R_CUT
      would <- function(ok) if (isTRUE(ok)) "would pass" else "would not pass"

      htmltools::tagList(
        htmltools::p(
          htmltools::strong("If the cutoffs were the ones you picked"),
          paste0(
            " (π̂ cutoff ", ca_num(pi_cut, 3),
            ", r̂ cutoff ", ca_num(r_cut, 3),
            "), the same two π̂ and r̂ would read:"
          )
        ),
        htmltools::div(
          class = "ca-sens__row",
          # Exactly two rows and no third line. These are plain comparisons of
          # two package fields against two numbers the user typed; they are
          # never stored, never chipped, and never leave this panel.
          htmltools::p(paste0(
            "π̂ = ", ca_num(pi_hat), " greater than ", ca_num(pi_cut, 3),
            " → ", would(pi_hat > pi_cut)
          )),
          htmltools::p(paste0(
            "r̂ = ", ca_num(r_hat), " less than ", ca_num(r_cut, 3),
            " → ", would(r_hat < r_cut)
          ))
        ),
        htmltools::p(
          htmltools::strong("What that does and does not mean."),
          " It tells you how close this dataset sits to the published cutoffs. It does ",
          htmltools::strong("not"),
          " mean a cure model would be appropriate under your cutoffs — the ",
          "cutoffs in Selukar & Othus (2023) were chosen and validated by the ",
          "authors of the method; a number you typed has no such backing. Use ",
          "this to see how far from the line you are, and to have a ",
          "conversation about it. Do not use it to reach a different answer."
        ),
        htmltools::p(htmltools::strong(paste0(
          "Nothing on the Conclusion tab uses the numbers you typed here. ",
          "Only the package's decision travels."
        )))
      )
    })

    invisible(NULL)
  })
}
