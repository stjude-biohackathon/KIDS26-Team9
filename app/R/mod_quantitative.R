# ---------------------------------------------------------------------------
# mod_quantitative.R — the Quantitative tab (owner: builder-auto)
#
# REVISION v3.0 (V2_CONTRACT §B — the auto-compute contract).
#
# THE RUN BUTTON IS GONE, and so are the three other action buttons this file
# used to carry (the RECeUS distribution "apply", the tau "apply" and the tau
# ladder "draw"). The assessment now runs BY ITSELF whenever the prepared
# dataset or the candidate set changes — §B.1 reactive 2, coded in §B.3 — and
# every exploration inside the disclosure recomputes by itself too, debounced
# so a dragged slider does not refit on every tick:
#
#   reactive 2  assess_r        state$prepared / state$include_lognormal
#                               -> ca_assess_once()  (helpers.R §B.4)
#   reactive 4  alpha_tests_r   input$alpha, debounced 400 ms
#                               -> ca_tests_at_alpha() -> mz.test(), shen.test()
#   reactive 5  tau_r           tau slider or distribution override, 250 ms
#                               -> ca_receus_at_tau() -> receus.method()
#
# Reactives 4 and 5 are DISPLAY ONLY. They never write state$assess, never
# reach the recommendation rule and never reach the report (§B.1, R8).
#
# S7 the assessment is wrapped in tryCatch; S2 run_tests = "yes"; S5
# time_scale = "none" — all three live inside ca_assess_once() in helpers.R,
# which is the ONE cure.appropriateness() call site in the repository (§B.4,
# §H.8). This file calls it and never writes its own.
#
# S1 / C1: no statistic is computed here. Every number on screen is read out of
# a package return field and the field is named in a comment beside it — the
# provenance stays in the comments and off the screen. The only app-side
# arithmetic is ca_qn_threshold() (the single permitted closed form) and the
# plain comparisons of the cutoff what-if.
#
# Package call sites owned by this file: mz.test(), shen.test() (through
# ca_tests_at_alpha()) and receus.method() (through ca_receus_at_tau()).
# model.fitting() moved to mod_data.R (§B.1 reactive 3); this file reads
# state$fit for the overlay and never fits anything itself.
#
# REVISION v4.0 (FINAL_CONTRACT §P, §G.4-G.6, §E.3, §E.5).
#
#   N1  The Maller-Zhou and qn cards each show a test statistic AND a p-value.
#       Both numbers are package fields and the two cards read each other's:
#       the statistic is $tests$qn$statistic (the proportion N_n/n) and the
#       p-value is $tests$mz$statistic (alpha_n, already on the p-value scale
#       and compared to alpha by the package itself). They are one test (S9),
#       so one line above the grid says so. NOTHING IS COMPUTED: each number is
#       read from its own field, and neither is ever re-derived from the other,
#       even though the algebra relating them is exact.
#       Shen returns only method/statistic/alpha/interpretation, so its card
#       carries a p-value and says in one line that there is no statistic to
#       show. Back-solving Shen's underlying proportion from its p-value is
#       forbidden (§P.2.4).
#   N2  Every technical-details disclosure in the diagnostics region is gone —
#       the four cards, the "not run" branch and the screening block. The
#       package interpretation strings are no longer rendered anywhere here.
#   N3  The cutoff what-if is now the RECeUS threshold test: a heading and one
#       line. The controls are unchanged and still write nothing.
#   N4  The two verdict lines are larger (.ca-sens__verdict) and direct.
#   E   Both plots size to their container; the AIC table scrolls inside
#       .ca-tablewrap with scrollX; the page heading is the lead's full name.
#
# Batch has never lived in this file — it is mounted from mod_recommendation.R
# and moves to its own tab this pass. Nothing here refers to it.
# ---------------------------------------------------------------------------


# ---- private constants ----------------------------------------------------

# Package default alpha for mz.test()/shen.test(); also the alpha the package's
# own qn interpretation string is hard-wired to.
.QUANT_ALPHA_DEFAULT <- 0.05

# RECeUS cutoffs. Literals inside receus.method() (R/receus.method.R:116-117);
# no exported argument reaches them. Shown, never applied by this app.
.QUANT_PI_CUT <- 0.025
.QUANT_R_CUT <- 0.05

# The RECeUS short codes receus.method() accepts. The VALUES are the package's
# short codes; the LABELS are plain display names, because C1 keeps package
# argument spellings off the screen. "" means "use the distribution the
# assessment selected" (S3 — read $selected_receus_dist, never re-map a name).
.QUANT_RECEUS_DISTS <- c(
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

# The not-computable line, one line, verbatim. Maller-Zhou, qn and Shen return
# NA together when the largest observed time is an event (S6). §C.7 F19 reuses
# this exact string in the batch CSV so the screen and the file agree.
.QUANT_VOID_LINE <- "Cannot be computed: the longest observed time is an event."

# RECeUS has its own not-computable line.
.QUANT_VOID_RECEUS <- "Cannot be computed: the model behind this number did not converge."

# The one banner line shown when an exploration result is on screen.
.QUANT_EXPLORE_BANNER <- "This is an exploration. The result above is unchanged."

# §B.1 — the permanent line under the tau control, in all three versions.
.QUANT_TAU_CAVEAT <- "This is an exploration. The decision above, and the report, always use the default."


# ---- the two shared exploration entry points (§F.3, frozen signatures) -----

#' Maller-Zhou and Shen recomputed at a user-chosen alpha — DISPLAY ONLY.
#'
#' Alpha is a genuine argument of both package functions, so moving it is a
#' real re-call rather than a re-rendering. The result never reaches
#' `ca_recommendation()` or the report (§B.1).
#'
#' Called by this module and by the alternative versions (§F.1).
#'
#' @param prepared `prepare.surv.data()` output, or NULL.
#' @param alpha Significance level in (0, 1).
#' @return `list(mz = <mz.test() return>, shen = <shen.test() return>)`, or
#'   NULL when it could not be computed. Downstream reads `$statistic`,
#'   `$alpha` and `$interpretation` off each element.
ca_tests_at_alpha <- function(prepared, alpha) {
  if (is.null(prepared) || !is.data.frame(prepared) || !nrow(prepared)) return(NULL)
  if (is.null(alpha) || length(alpha) != 1L || !is.finite(alpha)) return(NULL)
  tryCatch(
    list(
      mz   = cureAssess::mz.test(dat = prepared, alpha = alpha),
      shen = cureAssess::shen.test(dat = prepared, alpha = alpha)
    ),
    error = function(e) NULL
  )
}

#' The cured-group reading recomputed at one evaluation time — DISPLAY ONLY.
#'
#' `dist` is a package short code, normally `$selected_receus_dist` off the
#' assessment (S3), or the user's override from the exploration disclosure.
#' The result never reaches `ca_recommendation()` or the report (§B.1).
#'
#' Called by this module and by the alternative versions (§F.1).
#'
#' @param prepared `prepare.surv.data()` output, or NULL.
#' @param dist Package distribution short code, length 1 and non-empty.
#' @param tau Evaluation time.
#' @return `receus.method()` return (`$tau`, `$pi_hat`, `$r_hat`, `$decision`,
#'   `$interpretation`), or NULL when it could not be computed.
ca_receus_at_tau <- function(prepared, dist, tau) {
  if (is.null(prepared) || !is.data.frame(prepared) || !nrow(prepared)) return(NULL)
  if (is.null(dist) || length(dist) != 1L || is.na(dist) || !nzchar(dist)) return(NULL)
  if (is.null(tau) || length(tau) != 1L || !is.finite(tau)) return(NULL)
  tryCatch(
    cureAssess::receus.method(data = prepared, dist = as.character(dist), whichTau = tau),
    error = function(e) NULL
  )
}


# ---- private helpers ------------------------------------------------------

#' Colours for this module's two plot series.
#'
#' Local to this file (a helper that is not in helpers.R is defined privately,
#' with the module prefix). Draws nothing statistical.
.quant_palette <- function(dark = FALSE) {
  if (isTRUE(dark)) {
    list(km = "#8fa6bf", fit = "#7fd1c1", rule = "#5c6b7a", band = "#8fa6bf")
  } else {
    list(km = "#41566e", fit = "#1f7a6a", rule = "#9aa7b4", band = "#41566e")
  }
}

#' Display name for a model key (helpers.R N.3).
#'
#' CA_MODEL_LABELS is owned by helpers.R. An unknown key falls back to the key
#' itself, never to NA and never to an error, which is why this is an `[`
#' lookup with an NA guard rather than `[[`. Returns NULL for a missing or NA
#' key, which is how the caller detects "no model was fitted".
.quant_model_label <- function(key) {
  if (is.null(key) || length(key) < 1L || is.na(key[[1L]])) return(NULL)
  key <- as.character(key[[1L]])
  lab <- unname(CA_MODEL_LABELS[key])
  if (is.na(lab)) key else lab
}

#' Evaluation times for the tau-sensitivity control.
#'
#' An axis, not an estimate: an evenly spaced ladder of at most 25 candidate
#' evaluation times running from the median observed time up to the largest
#' observed time, which is the value receus.method() uses by default. The
#' median is one of the descriptives S1 permits.
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
#' nothing — survival::survfit() already produced every number here. Optional
#' columns are absent rather than wrong when the survfit object does not carry
#' them, and the render site checks names(km) before drawing the band or the
#' censoring ticks.
.quant_km_frame <- function(kmfit) {
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
#'
#' `modifier` is an extra class for the slot. The diagnostics section passes
#' "ca-stat--pv" on the p-value rows (§A handshake 3; builder-shell owns the
#' rule). An undefined class is inert, so the row degrades to a plain slot.
.quant_stat <- function(label, value_text, void = FALSE, modifier = NULL) {
  htmltools::div(
    class = paste(
      c(
        if (isTRUE(void)) "ca-stat ca-stat--void" else "ca-stat",
        modifier
      ),
      collapse = " "
    ),
    htmltools::span(class = "ca-stat__label", label),
    htmltools::span(class = "ca-stat__value", value_text)
  )
}

#' The threshold line under a statistic — one short line.
.quant_threshold <- function(text) {
  htmltools::div(
    class = "ca-threshold",
    htmltools::span(class = "ca-threshold__value", text)
  )
}

#' The empty state the exploration disclosure shows while there is nothing to
#' explore.
#'
#' The two "press Run assessment" branches are deleted with the button (§B.0).
#' While an assessment is in flight this returns NULL rather than a message:
#' at 0.1-0.2 s a message would be a flicker, and §B.5 says an output is either
#' the previous value at 45% opacity or the new one.
.quant_explore_empty <- function(state) {
  if (is.null(state$prepared)) {
    return(ca_empty("Load a dataset on the Data step first."))
  }
  if (is.null(state$assess)) return(NULL)
  if (!ca_has_tests(state)) return(ca_empty("Diagnostics were not run."))
  NULL
}

#' Chip variant for a RECeUS decision string.
#'
#' Fixed lookup; an unrecognised string stops loudly rather than falling
#' through to a neutral chip, because a silently-neutral verdict is worse than
#' a crash in review.
.quant_receus_variant <- function(decision) {
  switch(
    as.character(decision),
    "Cure model appropriate" = "pass",
    "Cure model not supported" = "fail",
    "Follow-up insufficient for cure modeling" = "fail",
    stop("Unrecognised RECeUS decision string: ", decision, call. = FALSE)
  )
}

#' Startup assertion: at alpha = 0.05 the app's qn chip direction must agree
#' with the package's own sentence.
#'
#' Reads qn$statistic and qn$interpretation; compares the app's chip rule
#' (larger qn is better, S8) against the presence of the package's own
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
#' `base` is state$assess$tests. `alpha_tests` is state$alpha_tests: NULL when
#' alpha is the package default 0.05, else ca_tests_at_alpha()'s two package
#' objects. Everything merged in is a package return object; the interpretation
#' strings shown are the package's own, recomputed at the user's alpha.
.quant_merge_alpha <- function(base, alpha_tests) {
  if (is.null(base)) return(NULL)
  if (is.null(alpha_tests)) return(base)
  if (!is.null(alpha_tests$mz)) base$mz <- alpha_tests$mz
  if (!is.null(alpha_tests$shen)) base$shen <- alpha_tests$shen
  base
}

#' The alpha re-calls, or NULL at the package default.
#'
#' NULL is load-bearing: `state$alpha_tests == NULL` is how the rest of the app
#' (mod_recommendation.R, the report) knows alpha is still 0.05, so the default
#' must never be stored as a recomputed pair.
.quant_alpha_tests <- function(prepared, alpha) {
  if (is.null(prepared)) return(NULL)
  if (is.null(alpha) || !is.finite(alpha)) return(NULL)
  if (abs(alpha - .QUANT_ALPHA_DEFAULT) < 1e-9) return(NULL)
  ca_tests_at_alpha(prepared, alpha)
}

#' The distribution the exploration should use.
#'
#' The user's override when they picked one, otherwise the distribution the
#' assessment itself selected. S3 — read $selected_receus_dist, never call the
#' unexported mapping helper.
.quant_receus_dist <- function(state, choice) {
  if (!is.null(choice) && length(choice) == 1L && !is.na(choice) && nzchar(choice)) {
    return(as.character(choice))
  }
  d <- state$assess$selected_receus_dist     # $selected_receus_dist
  if (is.null(d) || length(d) != 1L || is.na(d) || !nzchar(d)) return(NULL)
  as.character(d)
}


# ---- UI -------------------------------------------------------------------

#' Quantitative tab UI.
#'
#' Default view: the best-fit line, the AIC table and the four diagnostic
#' cards, all of which appear by themselves. There is no run control and no
#' checkbox above them — the candidate-set switch moved into the exploration
#' disclosure with the other optional controls (§B.0, §G.2 "Explore").
mod_quantitative_ui <- function(id) {
  ns <- NS(id)

  htmltools::tagList(

    # ---- 1. heading and the two states this tab can be in ------------------
    htmltools::tags$section(
      class = "ca-section",
      # FINAL_CONTRACT §B.2 / §G.7 — the rail carries the short label
      # ("Quantitative — single"); the page heading carries the lead's full
      # name, verbatim, em dash (U+2014) with spaces.
      htmltools::tags$h1(class = "ca-section__title",
                         "Quantitative — Assess Single Datasets"),
      # The poster's own flowchart wording for this step, verbatim.
      htmltools::p(
        class = "ca-lede",
        "Is there strong quantitative evidence of sufficient follow-up and a cure fraction?"
      ),
      uiOutput(ns("gate_msg")),
      uiOutput(ns("assess_msg"))
    ),

    # ---- 2. model screening -----------------------------------------------
    htmltools::tags$section(
      class = "ca-section",
      uiOutput(ns("screening_head")),
      uiOutput(ns("best_line")),
      uiOutput(ns("aic_wrap"))
    ),

    # ---- 3. the four diagnostic cards -------------------------------------
    htmltools::tags$section(
      class = "ca-section",
      uiOutput(ns("diag_head_title")),
      uiOutput(ns("diag_msg")),
      uiOutput(ns("diag_banner")),
      # §P.2.5 — the shared-p-value line, rendered ONCE, here and nowhere else.
      uiOutput(ns("diag_pair_note")),
      htmltools::div(
        class = "ca-grid-2",
        uiOutput(ns("card_mz")),
        uiOutput(ns("card_qn")),
        uiOutput(ns("card_shen")),
        uiOutput(ns("card_receus"))
      )
    ),

    # ---- 4. ONE closed disclosure holds every optional control -------------
    # Closed by default, so nothing in it is computed until it is opened:
    # Shiny suspends the outputs inside a collapsed panel, and every
    # exploration below hangs off one of those outputs.
    bslib::accordion(
      open = FALSE,
      bslib::accordion_panel(
        title = "Optional: explore the assumptions",
        value = "explore",

        uiOutput(ns("explore_msg")),

        # -- the candidate set ---------------------------------------------
        # A genuine re-assessment, not a display change: the assessment
        # re-runs by itself when this moves (§B.1 reactive 2).
        checkboxInput(
          ns("include_lognormal"),
          label = "Also fit lognormal models",
          value = FALSE
        ),

        # -- the alpha slider, a genuine argument of mz.test()/shen.test() --
        sliderInput(
          ns("alpha"),
          label = htmltools::span(
            htmltools::span(class = "ca-nocaps", "α"),
            " for Maller–Zhou and Shen"
          ),
          min = 0.01, max = 0.20, value = .QUANT_ALPHA_DEFAULT, step = 0.005,
          width = "24rem"
        ),
        htmltools::div(actionLink(ns("alpha_reset"), "Reset α to 0.05")),
        uiOutput(ns("alpha_msg")),

        # -- the distribution override and the evaluation time tau ----------
        # Both feed the same recomputation (§B.1 reactive 5), debounced, with
        # no apply button: the result below follows the controls.
        selectInput(
          ns("receus_dist"),
          label = "RECeUS distribution",
          choices = .QUANT_RECEUS_DISTS,
          selected = "",
          width = "28rem"
        ),
        sliderInput(
          ns("tau_idx"),
          label = "Evaluation time τ (earliest to latest)",
          min = 1, max = 25, value = 25, step = 1, ticks = FALSE,
          width = "24rem"
        ),
        uiOutput(ns("tau_label")),
        htmltools::div(actionLink(ns("tau_reset"), "Reset τ to the largest observed time")),
        # §B.1 — the permanent exploration line, one line, always visible.
        htmltools::p(class = "ca-provenance", .QUANT_TAU_CAVEAT),
        uiOutput(ns("tau_msg")),
        # Emitted only once a ladder exists: a bare plotOutput reserves its
        # full height from first paint, which opens the panel with a hole.
        uiOutput(ns("tau_plot_wrap")),

        # -- the fitted curve over the Kaplan-Meier estimate ----------------
        selectInput(
          ns("overlay_model"),
          label = "Fitted curve to draw over the Kaplan-Meier estimate",
          choices = character(0),
          selected = NULL,
          width = "22rem"
        ),
        uiOutput(ns("overlay_msg")),
        # §E.3 — no fixed pixel height. height = "100%" inside a container that
        # carries a CSS aspect-ratio, so Shiny re-renders the PNG at the
        # container's real size on every resize.
        htmltools::div(
          class = "ca-plot ca-plot--fluid",
          plotOutput(ns("overlay_plot"), height = "100%")
        ),

        # -- the cutoff what-if --------------------------------------------
        # The two sliders are static, not re-emitted by renderUI, so dragging
        # one cannot rebuild the panel underneath the user's cursor. Only the
        # prose around them is rendered.
        htmltools::div(
          class = "ca-sens",
          uiOutput(ns("sens_head")),
          htmltools::div(
            class = "ca-sens__row",
            # §G.4 — the labels name the quantities in words; the π̂ / r̂ glyphs
            # stay in the result lines below, where the RECeUS card has already
            # defined them.
            sliderInput(
              ns("sens_pi_cut"),
              "Cure fraction threshold",
              min = 0, max = 0.5, value = .QUANT_PI_CUT, step = 0.005, width = "22rem"
            ),
            sliderInput(
              ns("sens_r_cut"),
              "Uncured ratio threshold",
              min = 0, max = 0.5, value = .QUANT_R_CUT, step = 0.005, width = "22rem"
            ),
            actionLink(ns("sens_reset"), "Reset to 0.025 and 0.05")
          ),
          uiOutput(ns("sens_panel"))
        )
      )
    )
  )
}


# ---- server ---------------------------------------------------------------

#' Quantitative tab server.
#'
#' Owns the single-dataset assessment (§B.3, through helpers.R's
#' ca_assess_once()), the alpha re-calls of mz.test()/shen.test() and the two
#' render-time-only RECeUS explorations.
mod_quantitative_server <- function(id, state, go_to) {
  moduleServer(id, function(input, output, session) {

    ns <- session$ns

    # ---- navigation ------------------------------------------------------
    ca_on_click(input, "to_data", function() go_to("data"))

    # ---- 1. THE AUTOMATIC ASSESSMENT (§B.3) ------------------------------
    # No button. The assessment follows the prepared dataset and the candidate
    # set. Everything below reads state$assess, which is NULL between a data
    # change and the result that replaces it (§B.6): ca_reset_assessment()
    # nulls it synchronously in the prepare observer, before any package call,
    # so no stale number can survive a data change.
    #
    # assessed_key is the idempotence guard. Two things make it necessary:
    # reactiveValues does not invalidate when the new value is identical() to
    # the old, so re-preparing a byte-identical frame would leave the nulled
    # assessment unrepaired; and the catch-up observer below can coincide with
    # the primary one in a single flush. Whichever fires first does the work,
    # the other finds the key unchanged and returns.
    assessed_key <- NULL

    assess_now <- function() {
      if (is.null(state$prepared)) {
        assessed_key <<- NULL
        state$assess <- NULL
        # "error" belongs to the Data step: it means the data itself could not
        # be read or prepared, and that tab renders its message off exactly
        # this status plus state$last_error. Overwriting it here would blank a
        # message this module did not write and cannot replace.
        if (!identical(state$status, "error")) state$status <- "empty"
        return(invisible(NULL))
      }

      key <- list(prepared = state$prepared,
                  lognormal = isTRUE(state$include_lognormal))
      done <- identical(key, assessed_key) &&
        (!is.null(state$assess) || !is.null(state$last_error))
      if (isTRUE(done)) return(invisible(NULL))

      prepared <- state$prepared
      use_lognormal <- isTRUE(state$include_lognormal)

      # S7 — a package failure is a normal outcome, not a crash. The call
      # itself is ca_assess_once() in helpers.R: S2 run_tests = "yes", S5
      # time_scale = "none", S3 dist = NULL. It is the one call site in the
      # repository and this file does not write its own (§B.4, §H.8).
      res <- tryCatch(
        withProgress(message = "Assessing", value = 0, {
          incProgress(0.2, detail = "Fitting candidate models")
          a <- ca_assess_once(prepared, include_lognormal = use_lognormal)
          incProgress(0.8)
          a
        }),
        error = function(e) structure(list(msg = conditionMessage(e)),
                                      class = "ca_failed")
      )

      assessed_key <<- key

      if (inherits(res, "ca_failed")) {
        # §B.7 — assess stays NULL, the status falls back, and the raw package
        # text goes in the technical disclosure, never in the sentence (C1).
        state$assess <- NULL
        state$alpha_tests <- NULL
        state$last_error <- res$msg
        state$status <- "prepared"
        return(invisible(NULL))
      }

      state$include_lognormal <- use_lognormal
      state$assess <- res
      state$alpha_tests <- .quant_alpha_tests(prepared, state$alpha)
      state$last_error <- NULL
      state$status <- "assessed"

      # Console-only assertion: the qn chip direction must match the package's
      # own sentence at alpha = 0.05 (S8, larger qn is better).
      if (ca_has_tests(state)) {
        thr <- ca_qn_threshold(nrow(prepared), .QUANT_ALPHA_DEFAULT)
        # $tests$qn$statistic and $tests$qn$interpretation
        ok <- .quant_qn_direction_ok(state$assess$tests$qn, thr)
        if (identical(ok, FALSE)) {
          warning(
            "cureAssessApp: qn direction check failed. The app's chip and ",
            "cureAssess's own qn interpretation string disagree at alpha = 0.05.",
            call. = FALSE
          )
        }
      }

      invisible(NULL)
    }

    # The primary trigger (§B.3): the prepared frame or the candidate set.
    observeEvent(list(state$prepared, state$include_lognormal), {
      assess_now()
    }, ignoreNULL = FALSE)

    # The catch-up trigger. mod_data.R moves the status to "prepared" as the
    # last statement of a successful prepare, which covers the one case the
    # primary trigger cannot see: a re-prepare that lands on an identical
    # frame. assess_now() is idempotent, so this can only ever do work the
    # primary trigger did not.
    observeEvent(state$status, {
      assess_now()
    }, ignoreInit = FALSE)

    # The candidate-set checkbox writes state, and state drives the assessment
    # — never the other way round, so the two cannot chase each other.
    observeEvent(input$include_lognormal, {
      state$include_lognormal <- isTRUE(input$include_lognormal)
    }, ignoreInit = TRUE)

    # ---- 2. THE ALPHA RE-CALLS (§B.1 reactive 4, 400 ms) -----------------
    alpha_r <- debounce(reactive(input$alpha), 400)

    observeEvent(alpha_r(), {
      a <- alpha_r()
      if (is.null(a) || !is.finite(a)) return(invisible(NULL))
      state$alpha <- a
      # NULL at the package default; two package objects otherwise.
      state$alpha_tests <- .quant_alpha_tests(state$prepared, a)
      invisible(NULL)
    }, ignoreInit = TRUE)

    ca_on_click(input, "alpha_reset", function() {
      updateSliderInput(session, "alpha", value = .QUANT_ALPHA_DEFAULT)
    })

    # ---- 3. THE TAU LADDER AND THE TAU RESULT (§B.1 reactive 5, 250 ms) --
    tau_grid_r <- reactive({
      if (is.null(state$prepared)) return(numeric(0))
      .quant_tau_grid(state$prepared$Y)     # prepare.surv.data() output column Y
    })

    observeEvent(tau_grid_r(), {
      g <- tau_grid_r()
      k <- max(length(g), 1L)
      updateSliderInput(session, "tau_idx", max = k, value = k)
    }, ignoreInit = FALSE)

    tau_value_r <- reactive({
      g <- tau_grid_r()
      i <- input$tau_idx
      if (!length(g) || is.null(i) || !is.finite(i)) return(NA_real_)
      i <- max(1L, min(length(g), as.integer(i)))
      g[[i]]
    })

    # Only the cheap trigger is debounced. debounce() drives its input with an
    # internal observer, so debouncing the expensive reactive itself would
    # make it eager and recompute inside a closed disclosure; debouncing the
    # slider index and the distribution keeps both results lazy.
    tau_idx_d <- debounce(reactive(input$tau_idx), 250)
    dist_d <- debounce(reactive(input$receus_dist %||% ""), 250)

    ca_on_click(input, "tau_reset", function() {
      if (!isTRUE(explore_ready_r())) return(invisible(NULL))
      k <- max(length(tau_grid_r()), 1L)
      updateSliderInput(session, "tau_idx", value = k)
    })

    # One evaluation time. Lazy: computed only when the disclosure is open.
    tau_r <- reactive({
      tau_idx_d()                                   # the debounced trigger
      if (is.null(state$prepared) || !ca_has_tests(state)) return(NULL)
      d <- .quant_receus_dist(state, dist_d())
      if (is.null(d)) return(NULL)
      tau <- isolate(tau_value_r())
      ca_receus_at_tau(state$prepared, d, tau)
    })

    # The ladder across every evaluation time. It depends on the dataset and
    # the distribution, never on tau — tau only moves the marker drawn on it,
    # which is why dragging the slider redraws the figure without refitting.
    tau_curve_r <- reactive({
      if (is.null(state$prepared) || !ca_has_tests(state)) return(NULL)
      d <- .quant_receus_dist(state, dist_d())
      if (is.null(d)) return(NULL)
      g <- tau_grid_r()
      if (!length(g)) return(NULL)
      k <- length(g)
      rows <- withProgress(message = "Recomputing across evaluation times", value = 0, {
        pieces <- lapply(seq_len(k), function(i) {
          incProgress(1 / k, detail = paste0("Evaluation time ", i, " of ", k))
          r <- ca_receus_at_tau(state$prepared, d, g[[i]])
          if (is.null(r)) return(NULL)
          # Every column is a package return field: $tau, $pi_hat, $r_hat.
          data.frame(tau = r$tau, pi_hat = r$pi_hat, r_hat = r$r_hat)
        })
        pieces <- pieces[!vapply(pieces, is.null, logical(1))]
        if (!length(pieces)) NULL else do.call(rbind, pieces)
      })
      list(data = rows, k = k)
    })

    # ---- the test list every card reads ----------------------------------
    # Canonical = state$assess$tests. The alpha-recomputed Maller-Zhou and
    # Shen are merged over it, because alpha is a genuine argument of those two
    # package functions. Nothing else overrides the cards.
    tests_r <- reactive({
      if (!ca_has_tests(state)) return(NULL)
      .quant_merge_alpha(state$assess$tests, state$alpha_tests)
    })

    explore_ready_r <- reactive(ca_has_tests(state))

    observe({
      ready <- isTRUE(explore_ready_r())
      # An <a disabled> still fires in a browser, so the two reset links check
      # the same flag in their handlers; this only stops them looking live.
      updateActionButton(session, "tau_reset", disabled = !ready)
      updateActionButton(session, "sens_reset", disabled = !ready)
      invisible(NULL)
    })

    ca_on_click(input, "sens_reset", function() {
      if (!isTRUE(explore_ready_r())) return(invisible(NULL))
      updateSliderInput(session, "sens_pi_cut", value = .QUANT_PI_CUT)
      updateSliderInput(session, "sens_r_cut", value = .QUANT_R_CUT)
    })

    # ---- EMPTY AND ERROR STATES ------------------------------------------
    output$gate_msg <- renderUI({
      if (!is.null(state$prepared)) return(NULL)
      ca_empty(
        "Load a dataset on the Data step first.",
        action_id = ns("to_data"),
        action_label = "Data →"
      )
    })

    # §B.7 — the one failure surface on this tab. No sentence names the
    # package; the raw text sits in the technical disclosure. ca_note()'s
    # caution styling is its "warning" variant (the only three variants
    # helpers.R accepts are info, warning and interpret).
    output$assess_msg <- renderUI({
      if (is.null(state$prepared)) return(NULL)
      if (!is.null(state$assess) || is.null(state$last_error)) return(NULL)
      ca_note(
        "warning",
        "The models could not be fitted for this dataset.",
        ca_tech(htmltools::tags$pre(class = "ca-mono", state$last_error))
      )
    })

    # ---- 4. MODEL SCREENING ----------------------------------------------
    # The two section headings are rendered, not static: before a result there
    # is nothing under either of them, and two bare headings over empty space
    # read as a half-built page.
    output$screening_head <- renderUI({
      req(state$assess)
      htmltools::h3(class = "ca-section__title", "Candidate models")
    })

    output$diag_head_title <- renderUI({
      req(state$assess)
      htmltools::h3(class = "ca-section__title", "Diagnostics")
    })

    output$best_line <- renderUI({
      if (is.null(state$assess)) return(NULL)
      bm <- state$assess$screening$best_model          # $screening$best_model
      lab <- .quant_model_label(bm)                    # display name via N.3
      if (is.null(lab)) {
        return(htmltools::p("No model could be fitted to these data."))
      }
      htmltools::p(htmltools::strong("Best fit: "), paste0(lab, "."))
    })

    output$aic_wrap <- renderUI({
      if (is.null(state$assess)) return(NULL)
      # §E.5 — the wide table scrolls inside its own container, never by
      # pushing the page. Belt and braces with DT's own scrollX below.
      htmltools::div(class = "ca-tablewrap", DTOutput(ns("aic_table")))
    })

    output$aic_table <- renderDT({
      req(state$assess)
      tbl <- state$assess$screening$aic_table   # the one AIC source

      disp <- data.frame(
        # Display name, not the package's internal key, so the column matches
        # the "Best fit: ..." line above it (C1 keeps package spellings off the
        # screen). The VALUE shown is a relabelling only — no row is added,
        # removed or reordered, and the hidden .aic_order key below still
        # drives the sort.
        # USE.NAMES = FALSE: vapply() over a character vector names its result
        # with that vector's values, and data.frame() adopts the first named
        # column as row names — which fails outright on an NA model name.
        model = vapply(
          tbl$model,
          function(x) {                                        # $aic_table$model
            lab <- .quant_model_label(x)
            if (is.null(lab)) as.character(x) else lab
          },
          character(1), USE.NAMES = FALSE
        ),
        # Badge read from the model_type column, never inferred from the name.
        type = vapply(
          tbl$model_type,
          function(x) as.character(ca_chip("neutral", x)),      # $aic_table$model_type
          character(1), USE.NAMES = FALSE
        ),
        AIC = vapply(tbl$AIC, function(x) ca_num(x, 2), character(1)),  # $aic_table$AIC
        parameter_estimates = vapply(
          tbl$parameter_estimates,
          # UPSTREAM BUG (cureAssess 0.1.0, R/model.fitting.R extract_estimates):
          # it labels estimates with names(x$fit$res[, 1]). For a ONE-parameter
          # fit res is a 1-row matrix, so res[, 1] drops to a length-1 vector
          # and R discards the rowname — the exponential row arrives as the
          # orphan string "=0.1416" with no parameter name. The fix upstream is
          # to use rownames(x$fit$res). Here we only strip the dangling "="
          # rather than invent the name, so the cell reads "0.1416" instead of
          # looking broken. No number is altered.
          function(x) {                                                 # $aic_table$parameter_estimates
            if (is.na(x)) return(ca_dash())
            s <- sub("^=", "", as.character(x))
            # C1: "theta" is the PACKAGE's internal name for the cure fraction
            # in this string — for the best-fit row its value is byte-identical
            # to the pi-hat the RECeUS card shows — so it is a field name on
            # screen, and the one package spelling that survived the C1 sweep
            # of this tab. Relabel the KEY to the word the rest of the app uses
            # for that quantity; "shape", "scale" and "rate" are ordinary
            # distribution vocabulary, not package names, and are left alone.
            # Key only, anchored at the start or after a separator, so no
            # NUMBER and no other parameter is touched.
            gsub("(^|; )theta=", "\\1cure fraction=", s)
          },
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
      # sort lexically and failed fits stay at the bottom (S4).
      disp$.aic_order <- seq_len(nrow(disp))

      datatable(
        disp,
        rownames = FALSE,
        selection = "none",
        escape = -2,                       # only the badge column carries HTML
        # Plain column headers. Cell VALUES stay exactly as the package emits
        # them: a data table is data, not prose. The error column stays visible
        # and failed rows are never filtered (S4).
        colnames = c("Model", "Type", "AIC", "Parameters", "Problem", "order"),
        class = "compact stripe hover",
        options = list(
          dom = "t",
          paging = FALSE,
          ordering = TRUE,
          # §E.5 — the Parameters and Problem columns carry long strings and
          # are the one thing that pushed the page wide at 768px. The error
          # column stays visible and failed rows stay unfiltered (S4):
          # narrowing is never implemented by hiding a column.
          scrollX = TRUE,
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

    # ---- 5. THE FOUR DIAGNOSTIC CARDS ------------------------------------
    # Four cards, not five: the descriptive summary card is deleted (S10), and
    # no field of that test object is read anywhere in this file.
    output$diag_msg <- renderUI({
      if (is.null(state$prepared) || is.null(state$assess)) return(NULL)
      if (!isTRUE(state$assess$tests_run)) {                 # $tests_run
        # The heading, plus the reason, as a plain paragraph. No fabricated
        # cards. The technical-details disclosure is gone (N2).
        return(htmltools::tagList(
          htmltools::h4(class = "ca-section__title", "Diagnostics were not run"),
          htmltools::p(state$assess$tests_reason)               # $tests_reason
        ))
      }
      NULL
    })

    # §P.2.5 — Maller-Zhou and qn are algebraically the same test (S9), so the
    # two cards visibly share a p-value. One line says so, once, above the card
    # grid; it is not repeated on either card.
    output$diag_pair_note <- renderUI({
      if (is.null(tests_r())) return(NULL)
      htmltools::p(paste0(
        "Maller-Zhou and qn are two readings of one test, so they share a ",
        "p-value and cannot disagree."
      ))
    })

    # The one exploration banner. It sits above the cards because the cards are
    # what a moved alpha changes.
    output$diag_banner <- renderUI({
      if (is.null(state$assess)) return(NULL)
      if (is.null(state$alpha_tests)) return(NULL)
      ca_banner(.QUANT_EXPLORE_BANNER, variant = "override")
    })

    output$alpha_msg <- renderUI({
      a <- input$alpha
      if (is.null(a)) return(NULL)
      if (is.finite(a) && a >= 0.01 && a <= 0.20) return(NULL)
      ca_empty("α must be between 0.01 and 0.20.")
    })

    # -- Maller-Zhou -------------------------------------------------------
    output$card_mz <- renderUI({
      tt <- tests_r()
      if (is.null(tt)) return(NULL)
      mz <- tt$mz
      # §P.2.1 / §P.2.3. TWO FIELDS, BOTH READ, NEITHER COMPUTED.
      #   p-value        <- $tests$mz$statistic  — already on the p-value scale
      #                     (Maller & Zhou 1994 eq. 5, alpha_n, compared to alpha
      #                     by the package itself)
      #   test statistic <- $tests$qn$statistic  — the proportion N_n/n over the
      #                     same late-time window; mz and qn are one test (S9)
      # The cross-read is deliberate and legal: both are fields of exported
      # package returns. Neither number may ever be re-derived from the other,
      # exact though that algebra is (§P.2.3).
      pval <- mz$statistic                        # $tests$mz$statistic
      stat <- tt$qn$statistic                     # $tests$qn$statistic
      alpha <- mz$alpha                           # $tests$mz$alpha
      void <- !is.finite(pval)

      # Direction: SMALLER is better (S8) — below alpha supports sufficient
      # follow-up.
      chip <- if (void) {
        ca_chip("void", "Cannot be computed", glyph = "dash")
      } else if (pval < alpha) {
        ca_chip("pass", "Follow-up sufficient")
      } else {
        ca_chip("fail", "Not sufficient")
      }

      ca_card(
        title = "Maller-Zhou test",
        chip = chip,
        body = htmltools::tagList(
          # §P.2.6 — in the void branch no labelled row is rendered at all,
          # rather than a labelled em dash.
          if (!void) .quant_stat("p-value", ca_num(pval), modifier = "ca-stat--pv"),
          if (!void) .quant_stat("Test statistic", ca_num(stat)),
          .quant_threshold(paste0("Sufficient if the p-value is below ",
                                  ca_num(alpha, 3))),
          if (void) htmltools::p(.QUANT_VOID_LINE)
        )
      )
    })

    # -- qn ----------------------------------------------------------------
    output$card_qn <- renderUI({
      tt <- tests_r()
      if (is.null(tt) || is.null(state$prepared)) return(NULL)
      qn <- tt$qn
      # §P.2.2 / §P.2.3 — the mirror of the Maller-Zhou card. The statistic is
      # this test's own field; the p-value is $tests$mz$statistic, read, never
      # derived. See the comment on card_mz.
      stat <- qn$statistic                        # $tests$qn$statistic
      pval <- tt$mz$statistic                     # $tests$mz$statistic
      n <- nrow(state$prepared)
      # S1 — the single closed form the app is permitted to evaluate.
      # qn.test() returns no threshold field, so this value is app-computed.
      thr <- ca_qn_threshold(n, state$alpha)
      void <- !is.finite(stat)

      # Direction: LARGER qn is better (S8) — above the threshold supports
      # sufficient follow-up. Getting this backwards is a blocking bug; the
      # console assertion in the assessment guards it.
      chip <- if (void || !is.finite(thr)) {
        ca_chip("void", "Cannot be computed", glyph = "dash")
      } else if (stat > thr) {
        ca_chip("pass", "Follow-up sufficient")
      } else {
        ca_chip("fail", "Not sufficient")
      }

      ca_card(
        title = "qn statistic",
        chip = chip,
        body = htmltools::tagList(
          # S8 — larger is better here, so the statistic leads (§P.2.2).
          if (!void) .quant_stat("Test statistic", ca_num(stat)),
          if (!void) .quant_stat("p-value", ca_num(pval), modifier = "ca-stat--pv"),
          .quant_threshold(paste0("Sufficient if the statistic is above ",
                                  ca_num(thr, 7))),
          if (void) htmltools::p(.QUANT_VOID_LINE)
        )
      )
    })

    # -- Shen --------------------------------------------------------------
    output$card_shen <- renderUI({
      tt <- tests_r()
      if (is.null(tt)) return(NULL)
      sh <- tt$shen
      # §P.2.4 — shen.test() returns method, statistic, alpha, interpretation
      # and NOTHING ELSE. Its $statistic is the same complement-raised-to-n
      # form as Maller-Zhou's but over Shen's own window, and the package
      # compares it directly to alpha, so it is already on the p-value scale.
      # The underlying count and proportion are NOT returned. Recovering them
      # by inverting that form is a closed form and is FORBIDDEN (S1 permits
      # exactly one app-side closed form, the qn threshold). A number the
      # package chose not to report is a number the app does not have, so this
      # card shows no test statistic.
      pval <- sh$statistic                        # $tests$shen$statistic
      alpha <- sh$alpha                           # $tests$shen$alpha
      void <- !is.finite(pval)

      # Direction: SMALLER is better (S8).
      chip <- if (void) {
        ca_chip("void", "Cannot be computed", glyph = "dash")
      } else if (pval < alpha) {
        ca_chip("pass", "Follow-up sufficient")
      } else {
        ca_chip("fail", "Not sufficient")
      }

      ca_card(
        title = "Shen test",
        chip = chip,
        body = htmltools::tagList(
          if (!void) .quant_stat("p-value", ca_num(pval), modifier = "ca-stat--pv"),
          .quant_threshold(paste0("Sufficient if the p-value is below ",
                                  ca_num(alpha, 3))),
          if (void) htmltools::p(.QUANT_VOID_LINE),
          # Where the statistic slot would be. One short line, verbatim.
          if (!void) htmltools::p("")
        )
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

      chip <- if (void) {
        ca_chip("void", "Cannot be computed", glyph = "dash")
      } else {
        # $tests$receus$decision, verbatim as the chip label. An unrecognised
        # string stop()s loudly — a neutral chip standing in for a verdict is
        # the one thing that must never happen.
        ca_chip(.quant_receus_variant(rc$decision), rc$decision)
      }

      ca_card(
        title = "RECeUS",
        chip = chip,
        body = htmltools::tagList(
          .quant_stat("π̂", if (void) ca_dash() else ca_num(pi_hat), void = void),
          .quant_stat("r̂", if (void) ca_dash() else ca_num(r_hat), void = void),
          .quant_threshold("Supported if π̂ above 0.025 and r̂ below 0.05"),
          if (void) htmltools::p(.QUANT_VOID_RECEUS)
        )
      )
    })

    # ---- 6. THE EXPLORATION DISCLOSURE -----------------------------------
    output$explore_msg <- renderUI(.quant_explore_empty(state))

    # Choices are the models whose error is empty AND which the fitted objects
    # actually carry: the overlay draws from state$fit (mod_data.R's
    # model.fitting(), §B.1 reactive 3), and a model present in the AIC table
    # but absent from that fit has no curve to draw.
    observeEvent(list(state$assess, state$fit), {
      if (is.null(state$assess)) {
        updateSelectInput(session, "overlay_model", choices = character(0))
        return(invisible(NULL))
      }
      tbl <- state$assess$screening$aic_table
      ok <- tbl$model[tbl$error == ""]                 # $aic_table$error
      have <- names(state$fit$fits)                    # $fit$fits
      if (!is.null(have)) ok <- ok[ok %in% have]
      bm <- state$assess$screening$best_model          # $screening$best_model
      sel <- if (length(bm) && !is.na(bm) && bm %in% ok) bm else if (length(ok)) ok[[1L]] else NULL
      # Display names in the picker; the VALUES stay the package's model keys.
      choices <- if (length(ok)) {
        stats::setNames(ok, vapply(ok, .quant_model_label, character(1)))
      } else {
        character(0)
      }
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
      nzchar(row$error[[1L]])                          # $aic_table$error
    })

    output$overlay_msg <- renderUI({
      if (!isTRUE(overlay_failed_r())) return(NULL)
      ca_empty("That model did not fit, so there is no curve to draw.")
    })

    output$overlay_plot <- renderPlot({
      req(state$fit)
      km <- .quant_km_frame(state$fit$kmfit)           # $fit$kmfit
      req(!is.null(km))
      pal <- .quant_palette(isTRUE(state$dark))
      # .quant_km_frame() omits the confidence limits and the censoring counts
      # when the survfit object does not carry them, so neither column may be
      # assumed to exist here.
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
          lab <- paste0("Fitted: ", .quant_model_label(m))
        }
      }

      series <- c("Kaplan-Meier")
      cols <- c(pal$km)
      if (!is.null(ov)) { series <- c(series, lab); cols <- c(cols, pal$fit) }

      p <- ggplot()
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
    }, res = 108, bg = "transparent",
       alt = "Kaplan-Meier curve with the selected fitted model drawn over it as a dashed line.")

    # ---- tau feedback ----------------------------------------------------
    output$tau_label <- renderUI({
      # A tau is only meaningful next to a result, so the readout waits for
      # one. It is a value, not prose.
      if (!ca_has_tests(state)) return(NULL)
      tau <- tau_value_r()
      if (!length(tau_grid_r())) return(NULL)
      htmltools::p(
        class = "ca-provenance",
        "τ = ", htmltools::span(class = "ca-mono", ca_num(tau))
      )
    })

    output$tau_msg <- renderUI({
      out <- list()

      res <- tau_r()
      if (!is.null(res)) {
        out <- c(out, list(
          htmltools::div(
            class = "ca-sens__row",
            .quant_stat("π̂", ca_num(res$pi_hat),          # receus.method() $pi_hat
                        void = !is.finite(res$pi_hat)),
            .quant_stat("r̂", ca_num(res$r_hat),           # receus.method() $r_hat
                        void = !is.finite(res$r_hat)),
            htmltools::p(res$decision)                           # $decision, verbatim
          )
        ))
      }

      cur <- tau_curve_r()
      if (!is.null(cur)) {
        drawn <- if (is.null(cur$data)) 0L else sum(stats::complete.cases(cur$data))
        failed <- cur$k - drawn
        if (failed > 0L) {
          out <- c(out, list(ca_empty(paste0(
            failed, " of ", cur$k,
            " times could not be computed and are not plotted."
          ))))
        }
      }

      if (!length(out)) return(NULL)
      htmltools::tagList(out)
    })

    output$tau_plot <- renderPlot({
      cur <- tau_curve_r()
      req(!is.null(cur), !is.null(cur$data))
      d <- cur$data[stats::complete.cases(cur$data), , drop = FALSE]
      req(nrow(d) > 0)
      pal <- .quant_palette(isTRUE(state$dark))
      here <- tau_value_r()

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

      p <- ggplot(long, aes(x = .data$tau, y = .data$value)) +
        geom_hline(
          data = cuts, aes(yintercept = .data$yint),
          colour = pal$rule, linetype = "dashed", linewidth = 0.5
        )
      # The marker for the evaluation time the slider is on. This is what
      # redraws as tau moves; the ladder itself does not depend on tau.
      if (is.finite(here)) {
        p <- p + geom_vline(xintercept = here, colour = pal$rule, linewidth = 0.5)
      }
      p +
        geom_line(colour = pal$fit, linewidth = 0.9) +
        facet_wrap(~ series, ncol = 2) +
        coord_cartesian(ylim = c(0, 1)) +
        labs(
          x = "Evaluation time τ",
          y = NULL,
          subtitle = "Dashed lines: 0.025 and 0.05"
        ) +
        theme_cure_assess(dark = isTRUE(state$dark))
    }, res = 108, bg = "transparent",
       alt = "How the estimated cure fraction and the uncured censored ratio change as the follow-up cut-off moves.")

    output$tau_plot_wrap <- renderUI({
      cur <- tau_curve_r()
      if (is.null(cur) || is.null(cur$data)) return(NULL)
      # §E.3 — container-sized, not a fixed pixel height. The two facets want a
      # wide box, hence the second class.
      htmltools::div(
        class = "ca-plot ca-plot--fluid ca-plot--wide",
        plotOutput(session$ns("tau_plot"), height = "100%")
      )
    })

    # ---- THE CUTOFF WHAT-IF ----------------------------------------------
    # Writes nothing, overrides nothing, never leaves this panel. The package
    # decision stays canonical and is quoted here verbatim. No pass/fail chip,
    # no ca-rec classes, and no composed "would be appropriate" sentence.
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
      if (is.null(rc)) {
        # explore_msg at the top of the disclosure covers the empty states; the
        # only case left here is a result with no usable pi/r.
        if (!ca_has_tests(state)) return(NULL)
        return(ca_empty(.QUANT_VOID_RECEUS))
      }
      # §G.4 — a heading and one line. Nothing else.
      htmltools::div(
        class = if (isTRUE(sens_changed_r())) "ca-sens__head ca-sens--changed" else "ca-sens__head",
        htmltools::h4(
          class = "ca-section__title",
          "Test a different RECeUS threshold"
        ),
        htmltools::p(paste0(
          "The published thresholds are 0.025 for the cure fraction and 0.05 ",
          "for the uncured ratio. Moving them changes nothing else in the app."
        ))
      )
    })

    output$sens_panel <- renderUI({
      rc <- sens_receus_r()
      if (is.null(rc)) return(NULL)
      pi_hat <- rc$pi_hat                              # $tests$receus$pi_hat
      r_hat <- rc$r_hat                                # $tests$receus$r_hat
      pi_cut <- input$sens_pi_cut %||% .QUANT_PI_CUT
      r_cut <- input$sens_r_cut %||% .QUANT_R_CUT

      # §G.5 — a direct statement, not a hedge. "at this threshold" is
      # load-bearing: it keeps a what-if a what-if.
      verdict <- function(ok) {
        if (isTRUE(ok)) {
          "cure model is appropriate at this threshold"
        } else {
          "cure model is not appropriate at this threshold"
        }
      }

      htmltools::div(
        class = "ca-sens__row",
        # Exactly two rows and no third line. These are plain comparisons of
        # two package fields against two numbers the user typed; they are
        # never stored, never chipped, and never leave this panel.
        htmltools::p(
          class = "ca-sens__verdict",
          paste0(
            "π̂ = ", ca_num(pi_hat),
            if (pi_hat > pi_cut) " above " else " not above ", ca_num(pi_cut, 3),
            " → ", verdict(pi_hat > pi_cut)
          )
        ),
        htmltools::p(
          class = "ca-sens__verdict",
          paste0(
            "r̂ = ", ca_num(r_hat),
            if (r_hat < r_cut) " below " else " not below ", ca_num(r_cut, 3),
            " → ", verdict(r_hat < r_cut)
          )
        )
      )
    })

    invisible(NULL)
  })
}
