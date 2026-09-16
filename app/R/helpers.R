# =============================================================================
# app/R/helpers.R — shared non-statistical utilities and HTML component builders
# Owner: builder-shell.  APPEND-ONLY: no other builder edits this file.
#
# This file implements exactly the twenty functions of BUILD_CONTRACT section F,
# with the contract signatures and return types, and nothing else. A helper you
# need that is not here belongs in your own module file with your module's
# prefix (.quant_*, .data_*, .qual_*), never here.
#
# Nothing in this file computes an inferential statistic. The only arithmetic
# performed anywhere below is: the six descriptive counts (F.1), the tail-window
# descriptives (F.2), the subtraction 1 - p_hat (F.3) and the closed-form qn
# threshold 1 - alpha^(1/n) (F.4). Those four are the complete list of app-side
# computations permitted by the contract (section L, item 5).
#
# Component builders (chips, cards, callouts, banners) live here, not in
# theme.R. theme.R owns ca_bs_theme(), the design tokens, theme_cure_assess(),
# the plot helpers and ca_icon(). Calls across the two files are fine: both are
# auto-loaded by Shiny before the app runs, and every call happens at run time.
# =============================================================================


# ---- F.1 --------------------------------------------------------------------
#' The six permitted descriptive numbers for a prepared dataset
#'
#' Counts on the prepared frame's own `Y` and `D` columns — not cure-model
#' statistics, which is why they may be computed here. Reads no package field.
#'
#' @param prepared `prepare.surv.data()` output, or NULL.
#' @return Named list of six numerics: `n`, `events`, `censored_pct`,
#'   `median_followup`, `max_followup`, `last_event_time`. `last_event_time` is
#'   `NA_real_` when the dataset contains no events.
ca_data_summary <- function(prepared) {
  empty <- list(n = 0L, events = 0L, censored_pct = NA_real_,
                median_followup = NA_real_, max_followup = NA_real_,
                last_event_time = NA_real_)
  if (is.null(prepared) || !is.data.frame(prepared) || nrow(prepared) == 0L) return(empty)
  if (!all(c("Y", "D") %in% names(prepared))) return(empty)

  y <- as.numeric(prepared$Y)
  d <- as.integer(prepared$D)
  ok <- !is.na(y) & !is.na(d)
  y <- y[ok]; d <- d[ok]
  if (length(y) == 0L) return(empty)

  events <- sum(d == 1L)
  list(
    n               = length(y),
    events          = events,
    censored_pct    = 100 * (1 - mean(d)),
    median_followup = stats::median(y),
    max_followup    = max(y),
    last_event_time = if (events > 0L) max(y[d == 1L]) else NA_real_
  )
}


# ---- F.2 --------------------------------------------------------------------
#' Descriptives of the follow-up tail — the window after the last event
#'
#' The gap between the last event and the end of follow-up is what the three
#' follow-up tests key on; `zero_width` is the same gate those tests apply
#' (`max_time > last_event` must hold, or Maller-Zhou, qn and Shen all return
#' NA). Computed from the prepared frame only; reads no package field.
#'
#' @param prepared `prepare.surv.data()` output, or NULL.
#' @return `list(last_event, max_time, gap, gap_pct, zero_width, n_cens_after)`,
#'   or NULL when `prepared` is NULL/empty or contains no events.
ca_tail_facts <- function(prepared) {
  if (is.null(prepared) || !is.data.frame(prepared) || nrow(prepared) == 0L) return(NULL)
  if (!all(c("Y", "D") %in% names(prepared))) return(NULL)

  y <- as.numeric(prepared$Y)
  d <- as.integer(prepared$D)
  ok <- !is.na(y) & !is.na(d)
  y <- y[ok]; d <- d[ok]
  if (length(y) == 0L || sum(d == 1L) == 0L) return(NULL)

  last_event <- max(y[d == 1L])
  max_time   <- max(y)
  gap        <- max_time - last_event

  list(
    last_event   = last_event,
    max_time     = max_time,
    gap          = gap,
    gap_pct      = if (max_time > 0) 100 * gap / max_time else NA_real_,
    zero_width   = !(max_time > last_event),
    n_cens_after = sum(d == 0L & y > last_event)
  )
}


# ---- F.3 --------------------------------------------------------------------
#' The Kaplan-Meier tail level, read off `immune.test()`
#'
#' Reads `immune$p_hat` — the field returned by `cureAssess::immune.test()`, also
#' available at `state$assess$tests$immune$p_hat` — and subtracts it from one.
#' This is a subtraction on one package field, not a computation. Label the
#' result the KM tail level; it is NOT the RECeUS cure fraction pi_hat (on gbsg
#' the two are 0.3428 and 0.3238).
#'
#' @param immune The `immune` element of `$tests`, or `immune.test()` output.
#' @return numeric(1): `1 - p_hat`, or `NA_real_` when `p_hat` is NULL or NA.
#
# =============================================================================
# FIXPASS (finding 1.2) — [SIGN-OFF: G] — UNRESOLVED RULE CONFLICT, READ THIS
# =============================================================================
# This function performs ARITHMETIC ON AN INFERENTIAL FIELD. `p_hat` is output
# of `cureAssess::immune.test()`; `1 - p_hat` is a number the package does not
# return. Rule R2 in docs/shiny-app-spec.md permits the app exactly ONE
# computation — the qn threshold closed form `1 - alpha^(1/n)` — and this is
# not it. As R2 is written today, `ca_tail_level()` is outside it.
#
# It is well mitigated on screen: the value is labelled "tail level S", never
# pi-hat, and the Qualitative tab now prints its provenance under the plot. The
# behaviour is NOT being changed in this pass, and nobody should delete it
# without the team deciding first.
#
# THE TEAM MUST PICK ONE, and this comment is the flag, not the decision:
#   (a) amend R2 in docs/shiny-app-spec.md to permit a one-step monotone
#       re-expression of a single package field for display, naming this
#       function as the only instance; or
#   (b) render `p_hat` itself on screen and let the reader invert it, which
#       removes the arithmetic at the cost of a harder-to-read plateau label.
# Until one of those lands, the app has a documented exception to R2.
# =============================================================================
ca_tail_level <- function(immune) {
  if (is.null(immune)) return(NA_real_)
  p <- immune$p_hat
  if (is.null(p) || length(p) != 1L || is.na(p) || !is.finite(p)) return(NA_real_)
  1 - as.numeric(p)
}


# ---- F.4 --------------------------------------------------------------------
#' The qn threshold — the one closed form this app is permitted to evaluate
#'
#' `cureAssess::qn.test()` returns `method`, `statistic` and `interpretation`
#' only: the threshold sits inside the interpretation sentence, never in a
#' field, and the package's own sentence always quotes its fixed alpha = 0.05
#' version. The threshold moves with sample size, so an app showing qn at a
#' user-chosen alpha must render `1 - alpha^(1/n)` itself. Always label the
#' result "computed by this app". For qn, LARGER is better.
#'
#' @param n Analysed sample size, `nrow(state$prepared)`.
#' @param alpha Significance level in (0, 1); the package default is 0.05.
#' @return numeric(1), or `NA_real_` for an unusable `n` or `alpha`.
ca_qn_threshold <- function(n, alpha = 0.05) {
  if (is.null(n) || length(n) != 1L || is.na(n) || !is.finite(n) || n < 1) return(NA_real_)
  if (is.null(alpha) || length(alpha) != 1L || is.na(alpha) ||
      !is.finite(alpha) || alpha <= 0 || alpha >= 1) return(NA_real_)
  1 - alpha^(1 / n)
}


# ---- F.5 --------------------------------------------------------------------
#' Format a number for display
#'
#' The single number formatter for the whole app. It has to put 1.04e-140,
#' 5.25e-13, 0.0495, 1719.70 and a missing value in the same table and leave all
#' five readable, so very small magnitudes go to three significant figures in
#' scientific notation and everything else to fixed decimals. A missing,
#' infinite or absent value renders as the em dash, never as the text "NA" and
#' never as a blank cell. Pass `digits = 2` for AIC.
#'
#' @param x Numeric value (a length-1 vector in normal use).
#' @param digits Decimal places for the fixed-notation branch.
#' @return character of the same length as `x`; the em dash where `x` is unusable.
ca_num <- function(x, digits = 4) {
  if (is.null(x) || length(x) == 0L) return(ca_dash())
  x <- suppressWarnings(as.numeric(x))
  vapply(x, function(v) {
    if (is.na(v) || !is.finite(v)) return(ca_dash())
    if (v != 0 && abs(v) < 1e-4) return(format(v, digits = 3, scientific = TRUE))
    formatC(v, format = "f", digits = digits)
  }, character(1), USE.NAMES = FALSE)
}


# ---- F.6 --------------------------------------------------------------------
#' Format a proportion as a percentage
#'
#' @param x Proportion on the 0-1 scale.
#' @param digits Decimal places.
#' @return character; the em dash (with no percent sign) where `x` is unusable.
ca_pct <- function(x, digits = 1) {
  s <- if (is.null(x) || length(x) == 0L) ca_dash() else ca_num(100 * suppressWarnings(as.numeric(x)), digits = digits)
  ifelse(s == ca_dash(), s, paste0(s, "%"))
}


# ---- F.7 --------------------------------------------------------------------
#' The em dash — the only rendering of an unavailable number
#'
#' @return character(1).
ca_dash <- function() "—"


# ---- F.8 --------------------------------------------------------------------
#' A status chip
#'
#' Colour is never the only channel: every chip carries a word and a glyph.
#' An unknown variant stops loudly rather than falling through to a neutral
#' chip, because a silently-neutral verdict is worse than a crash in review.
#' Note that `immune.test()` is descriptive and must always take the "neutral"
#' variant — never pass/fail — and that "cannot be computed" is "void", never
#' a red "fail".
#'
#' @param variant One of "pass", "fail", "neutral", "caution", "void".
#' @param label The word shown in the chip; always rendered as text.
#' @param glyph `ca_icon()` name; defaults to the variant's own glyph.
#' @return `htmltools` `<span class="ca-chip ca-chip--VARIANT">`.
ca_chip <- function(variant, label, glyph = NULL) {
  variants <- c(pass = "check", fail = "cross", neutral = "ring",
                caution = "bang", void = "dash")
  if (!is.character(variant) || length(variant) != 1L || !(variant %in% names(variants))) {
    stop("ca_chip(): variant must be one of pass, fail, neutral, caution, void; got '",
         paste(variant, collapse = ", "), "'", call. = FALSE)
  }
  if (is.null(glyph)) glyph <- unname(variants[[variant]])
  htmltools::tags$span(
    class = paste0("ca-chip ca-chip--", variant),
    ca_icon(glyph),
    htmltools::tags$span(as.character(label))
  )
}


# ---- F.9 --------------------------------------------------------------------
#' The card shell every diagnostic and summary block sits in
#'
#' @param title Card heading text (or a tag).
#' @param body Card contents; may be a `tagList`.
#' @param chip Optional `ca_chip()` rendered in the header.
#' @param lede Optional plain-language sentence above the body.
#' @param foot Optional footer, typically `ca_provenance()`.
#' @return `htmltools` `<section class="ca-card">`.
ca_card <- function(title, body, chip = NULL, lede = NULL, foot = NULL) {
  htmltools::tags$section(
    class = "ca-card",
    htmltools::tags$header(
      class = "ca-card__head",
      htmltools::tags$h3(class = "ca-card__title", title),
      chip
    ),
    if (!is.null(lede)) htmltools::tags$p(class = "ca-card__lede", lede),
    htmltools::tags$div(class = "ca-card__body", body),
    if (!is.null(foot)) htmltools::tags$footer(class = "ca-card__foot", foot)
  )
}


# ---- F.10 -------------------------------------------------------------------
#' A callout block
#'
#' @param variant One of "info", "warning", "interpret".
#' @param title Callout heading.
#' @param body Callout contents; may be a `tagList` or `htmltools::HTML()`.
#' @return `htmltools` `<aside class="ca-note ca-note--VARIANT">`.
ca_note <- function(variant, title, body) {
  if (!is.character(variant) || length(variant) != 1L ||
      !(variant %in% c("info", "warning", "interpret"))) {
    stop("ca_note(): variant must be one of info, warning, interpret; got '",
         paste(variant, collapse = ", "), "'", call. = FALSE)
  }
  htmltools::tags$aside(
    class = paste0("ca-note ca-note--", variant),
    htmltools::tags$h4(class = "ca-note__title", title),
    htmltools::tags$div(class = "ca-note__body", body)
  )
}


# ---- F.11 -------------------------------------------------------------------
#' The collapsible technical-detail block
#'
#' Every verbatim package `interpretation` string and every raw error message
#' goes in one of these, underneath the plain-language sentence and never
#' instead of it. Collapsed by default.
#'
#' @param body Contents, typically a package `interpretation` string.
#' @param title Summary line.
#' @return `htmltools` `<details class="ca-tech">`.
ca_tech <- function(body, title = "Technical details") {
  htmltools::tags$details(
    class = "ca-tech",
    htmltools::tags$summary(title),
    htmltools::tags$div(class = "ca-tech__body", body)
  )
}


# ---- F.12 -------------------------------------------------------------------
#' A tooltip on an inline label
#'
#' bslib only: no JS, no bsicons, no new dependency.
#'
#' @param label Visible text.
#' @param text Tooltip contents.
#' @param placement bslib placement, default "top".
#' @return `htmltools` tag.
ca_tip <- function(label, text, placement = "top") {
  bslib::tooltip(
    htmltools::tags$span(class = "ca-tip", label, ca_icon("info")),
    text,
    placement = placement
  )
}


# ---- F.13 -------------------------------------------------------------------
#' Clear the assessment — the single implementation of the stale-verdict rule
#'
#' `state$assess` may be non-NULL only if it was produced from the CURRENT
#' `state$prepared`. Every event that can change `state$prepared` calls this as
#' its first statement, before any other assignment. Never hand-roll the
#' nulling: one implementation means one place to audit.
#'
#' @param state The single shared `reactiveValues`.
#' @return `invisible(NULL)`, called for its side effect.
ca_reset_assessment <- function(state) {
  state$assess      <- NULL
  state$alpha_tests <- NULL
  state$last_error  <- NULL
  state$status      <- "data_loaded"
  invisible(NULL)
}


# ---- F.14 -------------------------------------------------------------------
#' The standard empty state
#'
#' No dead ends: one sentence naming the next action, plus the control that
#' goes there.
#'
#' @param text The sentence.
#' @param action_id Input id for the button, ALREADY namespaced by the caller.
#' @param action_label Button label.
#' @return `htmltools` `<div class="ca-empty">`.
ca_empty <- function(text, action_id = NULL, action_label = NULL) {
  htmltools::tags$div(
    class = "ca-empty",
    htmltools::tags$p(class = "ca-empty__text", text),
    if (!is.null(action_id)) {
      htmltools::tags$div(
        class = "ca-empty__action",
        shiny::actionButton(
          action_id,
          if (is.null(action_label)) "Continue" else action_label,
          class = "btn btn-primary"
        )
      )
    }
  )
}


# ---- F.15 -------------------------------------------------------------------
#' The left navigation rail
#'
#' One `actionLink("nav_<id>")` per entry, numbered by position so the order
#' comes from `NAV_ORDER` and is never typed. Locked items stay clickable and
#' stay in the tab order (`aria-disabled="true"`, never the `disabled`
#' attribute, never `tabindex="-1"`): clicking a locked item navigates, and the
#' destination tab's own empty state explains what is missing. A dead click is
#' worse than a helpful empty page.
#'
#' Called only by `app.R`, through `renderUI`, so the states below are plain
#' server-side attributes rather than a custom JS message.
#'
#' @param order Character vector of tab ids, in display order.
#' @param labels Named character vector of rail labels, indexed by tab id.
#' @param states Named character vector of "locked"/"ready"/"done", or NULL for
#'   all "ready".
#' @param active The currently displayed tab id, or NULL.
#' @return `htmltools` `<nav class="ca-rail">`.
ca_rail <- function(order, labels, states = NULL, active = NULL) {
  stopifnot(is.character(order), length(order) > 0L)
  if (is.null(states)) states <- stats::setNames(rep("ready", length(order)), order)
  words  <- c(locked = "Locked", ready = "Ready", done = "Done")
  glyphs <- c(locked = "dash",   ready = "ring",  done = "check")

  items <- lapply(seq_along(order), function(i) {
    id <- order[[i]]
    st <- if (id %in% names(states)) as.character(states[[id]]) else "ready"
    if (!(st %in% names(words))) {
      stop("ca_rail(): state must be one of locked, ready, done; got '", st, "'", call. = FALSE)
    }
    is_active <- !is.null(active) && identical(id, active)
    lab <- if (id %in% names(labels)) as.character(labels[[id]]) else id

    htmltools::tags$li(
      class = "ca-rail__item",
      `data-ca-state` = st,
      shiny::actionLink(
        inputId = paste0("nav_", id),
        label = htmltools::tagList(
          htmltools::tags$span(class = "ca-rail__num", i),
          htmltools::tags$span(class = "ca-rail__glyph", ca_icon(unname(glyphs[[st]]))),
          htmltools::tags$span(class = "ca-rail__label", lab),
          htmltools::tags$span(class = "ca-rail__state", unname(words[[st]]))
        ),
        class = "ca-rail__link",
        `data-ca-state` = st,
        `aria-current` = if (is_active) "page" else NULL,
        `aria-disabled` = if (identical(st, "locked")) "true" else NULL
      )
    )
  })

  htmltools::tags$nav(
    class = "ca-rail",
    `aria-label` = "Assessment steps",
    htmltools::tags$ol(items)
  )
}


# ---- F.16 -------------------------------------------------------------------
#' One provenance line
#'
#' Every displayed number must be traceable to a call and a field, e.g.
#' `cure.appropriateness() -> $tests$receus$r_hat`. A value whose origin cannot
#' be named is rejected in review.
#'
#' @param call_text The call-and-field string.
#' @return `htmltools` `<p class="ca-provenance">`.
ca_provenance <- function(call_text) {
  htmltools::tags$p(
    class = "ca-provenance",
    htmltools::tags$code(class = "ca-mono", as.character(call_text))
  )
}


# ---- F.17 -------------------------------------------------------------------
#' App-side preparation of a raw frame, before any package function sees it
#'
#' Purely mechanical and entirely non-statistical: coerce the time column to
#' numeric, recode the status column to a 0/1 indicator against the level the
#' user named as the event, drop rows missing either, and count what was
#' dropped. It never calls a `cureAssess` function and never guesses the event
#' level.
#'
#' The two columns it adds are the ones the package call site names:
#' `..Y_raw` (numeric time, still on its original scale) and `..D01`
#' (0/1 event indicator). `prepare.surv.data()` is then handed
#' `time = "..Y_raw", status = "..D01"` and does the time scaling.
#'
#' @param raw The dataset exactly as loaded.
#' @param time_col Name of the time column.
#' @param status_col Name of the status column.
#' @param event_level The status value meaning "event", as character.
#' @return `list(data, dropped, error)`. `data` is the cleaned frame (NULL when
#'   `error` is set), `dropped` is
#'   `list(n_total, n_time_na, n_status_na, n_kept)` of integers, and `error` is
#'   a ready-to-show sentence or NULL.
ca_clean_surv <- function(raw, time_col, status_col, event_level) {
  fail <- function(msg, dropped = NULL) list(data = NULL, dropped = dropped, error = msg)

  if (is.null(raw) || !is.data.frame(raw) || nrow(raw) == 0L) {
    return(fail("Every row has a missing time or status, so there is nothing to analyse."))
  }
  if (is.null(time_col) || !(time_col %in% names(raw)) ||
      is.null(status_col) || !(status_col %in% names(raw))) {
    return(fail("Preparing the data failed."))
  }

  n_total <- nrow(raw)

  # --- time: coerce to numeric, and say so plainly when it will not coerce ---
  tv <- raw[[time_col]]
  if (is.factor(tv)) tv <- as.character(tv)
  if (is.numeric(tv)) {
    y <- as.numeric(tv)
  } else if (is.character(tv)) {
    y <- suppressWarnings(as.numeric(trimws(tv)))
    had_value <- !is.na(tv) & nzchar(trimws(tv))
    if (any(had_value) && all(is.na(y[had_value]))) {
      return(fail("The time column you chose is not numeric. Pick a numeric column."))
    }
  } else {
    return(fail("The time column you chose is not numeric. Pick a numeric column."))
  }

  # --- status: recode to 0/1 against the level the user named as the event ---
  sv <- as.character(raw[[status_col]])
  d  <- as.integer(sv == as.character(event_level))   # NA status stays NA here
  if (sum(d == 1L, na.rm = TRUE) == 0L) {
    return(fail("No rows have that value, so there would be no events. Pick a different level."))
  }

  # --- drop rows missing either, counting the two reasons separately --------
  n_time_na   <- sum(is.na(y))
  n_status_na <- sum(is.na(d))
  keep        <- !is.na(y) & !is.na(d)
  n_kept      <- sum(keep)
  dropped <- list(n_total = as.integer(n_total), n_time_na = as.integer(n_time_na),
                  n_status_na = as.integer(n_status_na), n_kept = as.integer(n_kept))

  if (n_kept == 0L) {
    return(fail("Every row has a missing time or status, so there is nothing to analyse.", dropped))
  }

  y <- y[keep]; d <- d[keep]
  bad <- !is.finite(y) | y < 0
  if (any(bad)) {
    return(fail(paste0("Some times are negative or not finite (", sum(bad),
                       " rows). Survival times must be finite and non-negative. ",
                       "Fix the file and upload again."), dropped))
  }
  if (sum(d) == 0L || n_kept < 2L) {
    return(fail(paste0("This dataset has no events (or too few rows) to assess. ",
                       "Cure-model diagnostics need both events and censored observations."),
                dropped))
  }

  out <- raw[keep, , drop = FALSE]
  out[["..Y_raw"]] <- y
  out[["..D01"]]   <- d
  rownames(out) <- NULL

  list(data = out, dropped = dropped, error = NULL)
}


# ---- F.18 -------------------------------------------------------------------
#' One cell of the six-number summary row
#'
#' @param label Micro label above the value.
#' @param value The formatted value; pass it through `ca_num()` first.
#' @param note Optional definition footnote, e.g. "median of observed follow-up
#'   times, all subjects".
#' @return `htmltools` `<div class="ca-statrow__cell">`.
ca_kv <- function(label, value, note = NULL) {
  htmltools::tags$div(
    class = "ca-statrow__cell",
    htmltools::tags$div(class = "ca-statrow__label", label),
    htmltools::tags$div(class = "ca-statrow__value", value),
    if (!is.null(note)) htmltools::tags$div(class = "ca-statrow__note", note)
  )
}


# ---- F.19 -------------------------------------------------------------------
#' The always-visible banner over an overridden or explored result
#'
#' @param text Banner text.
#' @param variant "override" or "warning".
#' @return `htmltools` `<div class="ca-banner ca-banner--VARIANT">`.
ca_banner <- function(text, variant = "override") {
  if (!is.character(variant) || length(variant) != 1L ||
      !(variant %in% c("override", "warning"))) {
    stop("ca_banner(): variant must be one of override, warning; got '",
         paste(variant, collapse = ", "), "'", call. = FALSE)
  }
  htmltools::tags$div(class = paste0("ca-banner ca-banner--", variant), text)
}


# ---- F.20 -------------------------------------------------------------------
#' Is there a usable `$tests` list on the current assessment?
#'
#' `state$assess$tests` is NULL — not an empty list — when `tests_run` is FALSE,
#' so every `state$assess$tests$...` read must be guarded with this.
#'
#' @param state The shared `reactiveValues`.
#' @return logical(1).
ca_has_tests <- function(state) {
  !is.null(state$assess) && isTRUE(state$assess$tests_run) && !is.null(state$assess$tests)
}


# ---- F.21 (added by INTEGRATOR) ---------------------------------------------
#' Fire `handler` on a real click of an `actionButton` / `actionLink`, never on
#' the counter reset that a re-render causes.
#'
#' THE BUG THIS FIXES. A bare `observeEvent(input$x, go_to("qual"))` fires on
#' the value change NULL -> 0 that every button sends when the client first
#' binds it, so at session start every navigation button in every module fired
#' at once and the app landed on whichever tab won the race. The same thing
#' happens again, mid-session, every time a button inside a `renderUI()` is
#' rebuilt: its counter restarts at 0, which is a change, which fired the
#' handler. `ignoreInit = TRUE` alone is not enough - it suppresses only the
#' first of those, not the re-render resets.
#'
#' The fix is to fire on a strict increment only. Each call keeps its own
#' counter in its own closure, so the guard is per input id and per session.
#'
#' FIXPASS (reverifier, finding 3.1 reopened) — `ignoreNULL` MUST be FALSE, and
#' this is not cosmetic. `shiny:::isNullEvent()` treats an `actionButton` value
#' of 0 as a null event, so with `ignoreNULL = TRUE` the observer never ran on
#' the counter reset a `renderUI()` rebuild sends. `seen` therefore kept the
#' value from the button's PREVIOUS DOM life while the client counter restarted
#' at 0, and the first real click on the rebuilt button arrived as a value the
#' guard had already seen — so it was silently refused, and only the second
#' click fired. Driving the live app confirmed it on all three of finding 3.1's
#' Prepare buttons: each worked on its first press of the session and was dead
#' on the first press of every cleared state after that. With `ignoreNULL`
#' FALSE the reset reaches this observer, `n` is 0, `fire` is FALSE (0 is never
#' greater than a non-negative `seen`) and the baseline drops back to 0, so the
#' very next click is a strict increment again. The strict-increment guard is
#' what keeps that 0 — and the NULL a removed button sends — from firing the
#' handler, which is exactly the race the rest of this comment describes.
#' This affects every `renderUI()`-embedded button in the app, not just Data's.
#'
#' @param input The module's `input` object.
#' @param id character(1), the unnamespaced input id.
#' @param handler A function of no arguments, called on a real click.
#' @return The observer, invisibly.
ca_on_click <- function(input, id, handler) {
  seen <- 0L
  shiny::observeEvent(input[[id]], {
    v <- input[[id]]
    n <- if (is.null(v) || !is.finite(v)) 0L else as.integer(v)
    # 0 is never a click: it is the session-start bind, the NULL a removed
    # button sends, or a renderUI() rebuild restarting the client counter.
    # Any other CHANGE is a click — including a value lower than the last one
    # seen, which can only mean the element was rebuilt in between (a rebuilt
    # actionButton always restarts at 0, so it can never report a stale high
    # count). Testing `n != seen` rather than `n > seen` also survives the case
    # where the rebuild's 0 and the click that follows it are coalesced into a
    # single flush, so the reset never reaches this observer at all.
    fire <- n > 0L && n != seen
    seen <<- n
    if (isTRUE(fire)) handler()
    invisible(NULL)
  }, ignoreInit = TRUE, ignoreNULL = FALSE)
}


# =============================================================================
# --- interpretation copy: owner Geethanjalee -------------------------------
#
# Everything below this fence is finished, signed-off statistical prose from
# BUILD_CONTRACT section J. Pod A wires it in; Pod A never rewrites it. No
# builder writes statistical prose: a screen that needs a sentence which is not
# here ships without the sentence, and the gap is reported.
#
# Each constant is a plain character(1) of HTML and is rendered with
# `htmltools::HTML(CA_COPY_X)`. Names carrying _TITLE are headings for
# `ca_note()` / `ca_card()`; names carrying _HTML are bodies. Braces in the
# sensitivity constants mark run-time substitutions and are documented at each
# constant.
#
# `[SIGN-OFF: G]` markers from the contract are retained as comments on the
# blocks they govern.
# =============================================================================
#
# #############################################################################
# ##                                                                         ##
# ##   FIXPASS — STOP. MOST OF THE CONSTANTS BELOW ARE NOT ON SCREEN.        ##
# ##                                                                         ##
# #############################################################################
#
# 52 CA_COPY_* constants are defined in this block. Only 9 of them are ever
# read. The other 43 have ZERO references outside this file: during the build,
# six modules were written in parallel and most of them RE-TYPED this prose
# locally instead of reading the constant. Two copies of the same statistical
# sentence now exist, and the one the reader sees is usually NOT the one here.
#
#   >>> EDITING AN UNREFERENCED CONSTANT BELOW CHANGES NOTHING ON SCREEN. <<<
#
# This is not hypothetical. CA_COPY_METHOD_MZ_HTML and CA_COPY_METHOD_SHEN_HTML
# both carried wrong journal citations (wrong volume, wrong pages, DOIs that do
# not resolve) while mod_docs.R shipped the correct ones from its own copy, and
# nobody could see the defect because the defective text never rendered. They
# have been corrected in this pass, but the underlying trap is unchanged.
#
# Consolidating to one source is a refactor with regression risk and was
# deliberately OUT OF SCOPE for this pass. Until it happens, use this map.
#
# --- LIVE: rendered on screen. Edit here and the change reaches the user. ----
#
#   CA_COPY_INTRO_TITLE        mod_intro.R  -> mod_intro_ui()
#   CA_COPY_INTRO_HTML         mod_intro.R  -> mod_intro_ui()
#   CA_COPY_NOT_DO_TITLE       mod_intro.R  -> mod_intro_ui()
#   CA_COPY_NOT_DO_HTML        mod_intro.R  -> mod_intro_ui()
#   CA_COPY_INTRO_CTA          mod_intro.R  -> mod_intro_ui()
#   CA_COPY_KM_GUIDE_TITLE     mod_data.R   -> .data_km_guide()
#   CA_COPY_KM_GUIDE_HTML      mod_data.R   -> .data_km_guide()
#   CA_COPY_PLATEAU_TITLE      mod_data.R   -> .data_plateau_note()
#   CA_COPY_PLATEAU_HTML       mod_data.R   -> .data_plateau_note()
#
#   NOTE: the Qualitative tab renders the J.1 reading guide and the J.2 plateau
#   callout too, but from its OWN retyped copies — .QUAL_READ_CHECKS and
#   .qual_plateau_callout() in mod_qualitative.R. So CA_COPY_KM_GUIDE_* and
#   CA_COPY_PLATEAU_* are live on the Data tab and dead on the Qualitative tab.
#   A one-sided edit here makes the two tabs disagree with each other.
#
# --- UNREFERENCED: dead here. The prose actually ships from the file named. --
#
#   Worked readings (6) -> mod_qualitative.R, .qual_worked_title() and
#   .qual_worked_reading(); those two functions are what mod_docs.R (Worked
#   readings accordion) and mod_conclusion.R (disagreement illustrations) call.
#     CA_COPY_READING_NWTCO_TITLE   CA_COPY_READING_NWTCO_HTML
#     CA_COPY_READING_GBSG_TITLE    CA_COPY_READING_GBSG_HTML
#     CA_COPY_READING_COLON_TITLE   CA_COPY_READING_COLON_HTML
#
#   Per-method explainers (12) -> mod_docs.R, the .DOCS_METHODS list rendered
#   by .docs_method_panel(). THIS IS WHERE THE CITATIONS LIVE ON SCREEN.
#     CA_COPY_METHOD_MZ_TITLE        CA_COPY_METHOD_MZ_HTML
#     CA_COPY_METHOD_QN_TITLE        CA_COPY_METHOD_QN_HTML
#     CA_COPY_METHOD_SHEN_TITLE      CA_COPY_METHOD_SHEN_HTML
#     CA_COPY_METHOD_IMMUNE_TITLE    CA_COPY_METHOD_IMMUNE_HTML
#     CA_COPY_METHOD_RECEUS_TITLE    CA_COPY_METHOD_RECEUS_HTML
#     CA_COPY_METHOD_SCREENING_TITLE CA_COPY_METHOD_SCREENING_HTML
#
#   Category-C sensitivity panel (8) -> mod_quantitative.R, retyped inline in
#   the sensitivity panel renderer.
#     CA_COPY_SENS_TITLE             CA_COPY_SENS_LEDE_HTML
#     CA_COPY_SENS_PACKAGE_HEAD_HTML CA_COPY_SENS_YOURS_HEAD_HTML
#     CA_COPY_SENS_MEANING_HTML      CA_COPY_SENS_FOOT_HTML
#     CA_COPY_SENS_AT_DEFAULTS       CA_COPY_SENS_CHANGED
#
#   Conclusion tab (13) -> mod_conclusion.R, retyped inline.
#     CA_COPY_CONCLUSION_HEADING     CA_COPY_CONCLUSION_SUBLINE
#     CA_COPY_STEP1_TITLE            CA_COPY_STEP1_BODY
#     CA_COPY_STEP2_TITLE            CA_COPY_STEP2_LABEL
#     CA_COPY_STEP3_TITLE            CA_COPY_STEP1_OPEN_BANNER
#     CA_COPY_TESTS_REASON_PREFACE   CA_COPY_DISAGREE_HTML
#     CA_COPY_INSUFFICIENT_TITLE     CA_COPY_INSUFFICIENT_HTML
#     CA_COPY_REPRODUCE_LEDE
#
#   Not-computable wording and the immune chip (4) -> mod_quantitative.R (the
#   mz / qn / shen void cards and the immune card); mod_docs.R's FAQ echoes
#   CA_COPY_NOT_COMPUTABLE_1 in its own answer text.
#     CA_COPY_NOT_COMPUTABLE_1       CA_COPY_NOT_COMPUTABLE_2
#     CA_COPY_NOT_COMPUTABLE_CHIP    CA_COPY_IMMUNE_CHIP
#
# To re-derive this map after any edit:
#   grep -o 'CA_COPY_[A-Z0-9_]*' app/R/*.R app/app.R | grep -v '^app/R/helpers.R'
# =============================================================================

# --- J.1 Kaplan-Meier reading guide (Qualitative tab) ------------------------
# [SIGN-OFF: G] the on-plot phrase "tail level S =" as a stand-in for the cure
# fraction; it is the KM level (gbsg 0.3428), not pi-hat (0.3238). Confirm the
# wording keeps them distinct.
CA_COPY_KM_GUIDE_TITLE <- "How to read this curve"

CA_COPY_KM_GUIDE_HTML <- paste0(
"<p>You are looking for one thing: <strong>does this dataset support a cure model?</strong> A cure model says ",
"some patients never have the event, so the curve should stop falling and stay up. These seven checks tell you ",
"whether what you are seeing is that, or something that only looks like it. Work down the list.</p>",

"<div class='ca-read'>",

"<div class='ca-read__item'><p><strong>1. Does the curve flatten, and how high does it flatten?</strong></p>",
"<p>Follow the curve left to right and find the point where it stops stepping down and runs horizontally. The ",
"height of that flat run is your rough cure fraction &mdash; read it off the dotted <strong>tail level</strong> ",
"line. A curve that is still descending at the right-hand edge has no plateau to interpret.</p>",
"<p><em>Formal diagnostic: RECeUS <code>pi_hat</code>, which must exceed 0.025.</em></p></div>",

"<div class='ca-read__item'><p><strong>2. How much of the study is flat?</strong></p>",
"<p>Compare the shaded tail band with the whole x-axis. A flat stretch covering half the follow-up is a plateau; ",
"one year of flatness at the end of a twenty-year study is the curve running out of data, not the disease ",
"running out of events.</p>",
"<p><em>Formal diagnostic: the <code>qn</code> statistic &mdash; it measures exactly this, as the share of events ",
"falling inside a window whose width is the length of the flat tail. <strong>Larger <code>qn</code> is better</strong>, ",
"and it is compared against a threshold that moves with sample size, not against 0.05.</em></p></div>",

"<div class='ca-read__item'><p><strong>3. What is the very last observation &mdash; an event or a censoring mark?</strong></p>",
"<p>Look at the extreme right-hand end. If the final mark is a censored subject (a tick), follow-up outlived the ",
"last event and there is something to test. If the final mark is an event (a step down), the study stopped while ",
"patients were still relapsing, and the question &ldquo;is follow-up long enough&rdquo; cannot be asked of this ",
"data at all.</p>",
"<p><em>Formal diagnostic: the immune summary reports <code>last_observation_censored</code> directly. It also ",
"gates Maller-Zhou, <code>qn</code> and Shen &mdash; all three return &ldquo;cannot be computed&rdquo; when the ",
"last observation is an event.</em></p></div>",

"<div class='ca-read__item'><p><strong>4. How many subjects are still being watched out there?</strong></p>",
"<p>Read the risk table under the plot. A plateau held up by four hundred subjects still under observation is ",
"evidence. A plateau held up by six is a line drawn through almost nobody, and it will move if one of those six ",
"relapses.</p>",
"<p><em>Formal diagnostic: none of the five tests reads the risk table &mdash; this is a judgement you make by ",
"eye, and it is the check that most often overturns a confident-looking plot.</em></p></div>",

"<div class='ca-read__item'><p><strong>5. How dense are the censoring marks along the flat part?</strong></p>",
"<p>Count the ticks in the shaded band; the label on the plot gives the number. Ticks packed along a flat stretch ",
"mean subjects were leaving the study, not surviving it. A flat curve produced by a handful of censored subjects ",
"is a censoring artifact, and no amount of flatness redeems it.</p>",
"<p><em>Formal diagnostic: the immune summary's censoring proportion <code>p_cens</code> gives the study-wide ",
"figure; the plot label gives the tail-specific count.</em></p></div>",

"<div class='ca-read__item'><p><strong>6. How wide is the gap between the last event and the end of follow-up?</strong></p>",
"<p>This is the shaded band, and it is the single feature that matters most. It is the stretch of time in which ",
"the study kept watching and nothing happened &mdash; the evidence that the uncured had run out. Wide gap, strong ",
"evidence. Narrow gap, weak evidence. <strong>Zero gap and there is no evidence at all</strong>: if the largest ",
"observed time is an event the band has no width, and Maller-Zhou, <code>qn</code> and Shen all return ",
"&ldquo;cannot be computed&rdquo; together.</p>",
"<p><em>Formal diagnostic: all three follow-up tests key on this gap. Maller-Zhou and Shen are <strong>smaller is ",
"better</strong> (below &alpha; supports sufficient follow-up); <code>qn</code> is <strong>larger is better</strong>. ",
"Shen uses a narrower window than Maller-Zhou and is the stricter of the two by design.</em></p></div>",

"<div class='ca-read__item'><p><strong>7. How wide is the shaded confidence band out in the tail?</strong></p>",
"<p>A plateau drawn with a confidence band half the height of the plot is a plateau you cannot locate. If the band ",
"spans 0.26 to 0.45, the data are consistent with a cure fraction of a quarter or of a half, and reporting a point ",
"estimate hides that.</p>",
"<p><em>Formal diagnostic: no test scores the band width. The closest quantitative statement is RECeUS ",
"<code>r_hat</code> &mdash; the share of uncured subjects still censored at the end of follow-up &mdash; which ",
"must be below 0.05.</em></p></div>",

"</div>",

"<p class='ca-key'><strong>The rule is a conjunction, not a score.</strong> Checks 1 and 7 are about whether a cure ",
"fraction exists; 2, 3, 5 and 6 are about whether follow-up was long enough to see it. A cure model needs both, ",
"plus a clinical reason to expect cure in the first place. Any one of them failing is enough to stop.</p>"
)

# --- J.2 Plateau-is-not-proof callout (Qualitative tab, above the plot) ------
# [SIGN-OFF: G] "true cure fraction of exactly zero" alludes to simulated
# scenario D (true cure fraction 0.00, dropout 0.45, r-hat 0.9973). Confirm
# whether to name it.
CA_COPY_PLATEAU_TITLE <- "⚠ A plateau is not proof"

CA_COPY_PLATEAU_HTML <- paste0(
"<p><strong>A Kaplan-Meier curve goes flat for two completely different reasons, and they look identical on the ",
"plot.</strong></p>",
"<p>The honest one: the uncured patients have all had their events, the people left are cured, and the curve has ",
"nowhere further to fall.</p>",
"<p>The other one: there is nobody left to watch. The Kaplan-Meier estimator only steps down when someone who is ",
"still under observation has an event. Once subjects have dropped out, been lost to follow-up, or hit the ",
"administrative end of the study, the curve <strong>cannot</strong> step down &mdash; it is flat by construction, ",
"whatever is happening to those patients in reality. Heavy censoring alone manufactures a convincing plateau in ",
"data with a true cure fraction of exactly zero.</p>",
"<p><strong>You cannot tell the two apart by looking.</strong> That is not a failure of your eye; the two ",
"situations produce the same picture, and the information that would separate them is not in the plot. It is why ",
"this app exists, and why the visual check is step 2 of three rather than the whole assessment.</p>",
"<p>What the diagnostics add is the question you cannot ask a picture: <em>after the last event, did the study ",
"keep watching anybody, for how long, and how many?</em> Read the shaded tail band and the risk table alongside ",
"the shape, and treat the shape alone as a hypothesis rather than a finding.</p>"
)

# --- J.3 Worked reading 1: nwtco, high risk (Documentation tab) --------------
CA_COPY_READING_NWTCO_TITLE <- "Worked reading 1 — nwtco, high risk"

CA_COPY_READING_NWTCO_HTML <- paste0(
"<p><strong>What you should see.</strong> The curve drops steeply through the first two years, then levels off ",
"around 0.78 and stays there for the rest of the plot. The shaded follow-up tail is enormous: the last event ",
"lands at year 7.4 and the study kept watching until year 17, so <strong>56% of the total follow-up contains no ",
"events at all</strong>, with 479 censored subjects in it. The risk table still reads 436 at year 8 and 197 at ",
"year 12 &mdash; this plateau is held up by hundreds of people, not a handful. The confidence band is a thin ",
"ribbon out there, roughly 0.76 to 0.81.</p>",
"<p><strong>How that squares with the numbers.</strong> Everything agrees. Maller-Zhou is 1.04e-140, far below ",
"0.05, and <code>qn</code> is 0.2051 against its sample-size threshold of 0.0021 &mdash; the same verdict from the ",
"same arithmetic, stated two ways. Shen is 0.0496, which passes, but only just: Shen uses a narrower late-time ",
"window than Maller-Zhou and is the stricter of the two, and even on the best dataset we have it sits within ",
"0.0004 of its cutoff. Worth noticing rather than worrying about. RECeUS passes both conditions comfortably ",
"&mdash; <code>pi_hat</code> 0.7823 against a floor of 0.025, <code>r_hat</code> 0.0041 against a ceiling of 0.05, ",
"meaning about 0.4% of uncured subjects were still censored when follow-up ended. ",
# FIXPASS: was "the tail level ... 0.784, is within 0.002 of pi_hat", which is
# false by a hair. The package returns 1 - p_hat = 0.784324 and pi_hat =
# 0.782266, a gap of 0.002058. The same sentence also ships (live) from
# mod_qualitative.R's .qual_worked_reading("nwtco") and was corrected there.
"The tail level you read off the ",
"plot, 0.7843, is within 0.0021 of <code>pi_hat</code>. <strong>Verdict: cure model appropriate</strong> &mdash; ",
"subject to step 1, which is still yours.</p>"
)

# --- J.4 Worked reading 2: gbsg, the disagreement case -----------------------
# [SIGN-OFF: G] (a) gbsg: qn passes, contradicting the published section 11
# table; (b) "prefer the stricter test" as guidance on weighing disagreement.
CA_COPY_READING_GBSG_TITLE <- "Worked reading 2 — gbsg, the disagreement case"

CA_COPY_READING_GBSG_HTML <- paste0(
"<p><strong>What you should see.</strong> The curve descends steadily for six years and never really settles; the ",
"flat run at the right is short and arrives only at the very end. The shaded tail is thin &mdash; the last event ",
"is at year 6.7, follow-up ends at year 7.3, so the gap is <strong>7.6% of the study</strong>, and it contains ",
"just <strong>8 censored subjects</strong>. The risk table has already fallen to 36 by year 6 and reaches 0 by ",
"year 8. The confidence band out in the tail spans roughly 0.26 to 0.45, wide enough that the data are consistent ",
"with a cure fraction of a quarter or of a half.</p>",
"<p><strong>How that squares with the numbers.</strong> This is the dataset that justifies the whole tool. AIC ",
"picks a cure model, and an analyst who stops there reports a cure fraction near 0.32 and is wrong. Maller-Zhou ",
"is 0.0495 and <code>qn</code> is 0.0044 against a threshold of 0.0044 &mdash; both nominally say follow-up is ",
"sufficient, both by a margin of essentially nothing: <strong>three events out of 686 fall in the window, and one ",
"fewer would flip both</strong>. Shen, which uses a narrower window precisely because Maller-Zhou over-declares ",
"sufficiency, returns 0.3676 &mdash; nowhere near its 0.05 cutoff. RECeUS agrees with Shen: <code>pi_hat</code> ",
"0.3238 clears its floor, so a cured group plausibly exists, but <code>r_hat</code> is 0.3080, meaning ",
"<strong>about 31% of uncured subjects were still censored when the study ended</strong>. <strong>Verdict: ",
"follow-up insufficient for cure modeling.</strong></p>",
"<p><strong>What to do when they disagree, as they do here.</strong> Do not count chips and take the majority ",
"&mdash; they are not votes, and Maller-Zhou and <code>qn</code> are the same statistic presented two ways, so ",
"they always agree with each other and are never independent confirmation. Instead: (i) check how close each ",
"statistic is to its threshold, because one sitting 0.0005 from its cutoff is not making a claim in either ",
"direction; (ii) prefer the stricter test when the pattern is the known one &mdash; Shen exists to catch ",
"Maller-Zhou's over-declaration, so Maller-Zhou passing while Shen fails is Shen working as designed, not a ",
"contradiction; (iii) weigh <code>r_hat</code>, which asks the identifiability question most directly; and (iv) ",
"look back at the picture, where a 7.6% tail containing 8 subjects was never going to carry the claim. A better ",
"AIC fit is not evidence that a cure model is identifiable. AIC asks how well a model describes the data you ",
"have; identifiability asks whether the data contain enough follow-up to pin the cure fraction down. Different ",
"questions, and only the second one is being decided here.</p>"
)

# --- J.5 Worked reading 3: colon, Lev+5FU arm, the borderline case -----------
# [SIGN-OFF: G] confirm "close, and worth discussing with a statistician" as
# the advice attached to a near-miss r-hat.
CA_COPY_READING_COLON_TITLE <- "Worked reading 3 — colon, Lev+5FU, the borderline case"

CA_COPY_READING_COLON_HTML <- paste0(
"<p><strong>What you should see.</strong> A genuine-looking plateau around 0.60 from about year 5.7 onward, with ",
"a substantial shaded tail &mdash; the last event is at year 5.7, follow-up runs to year 9.1, so <strong>37% of ",
"the study contains no events</strong>, holding 142 censored subjects. That is a real flat stretch supported by ",
"real numbers at risk, and it looks much more like the nwtco picture than the gbsg one. The confidence band is ",
"moderate, roughly 0.55 to 0.66.</p>",
"<p><strong>How that squares with the numbers.</strong> The follow-up statistics are emphatic: Maller-Zhou ",
"5.25e-13, <code>qn</code> 0.0888 against a threshold of 0.0098, Shen 0.0065 &mdash; and unlike gbsg, Shen agrees ",
"rather than dissenting. <code>pi_hat</code> is 0.5736, a clear cured group, and the tail level you read off the ",
"plot, 0.599, is close to it. <strong>Then <code>r_hat</code> comes in at 0.0640, just above the 0.05 ceiling ",
"&mdash; and the verdict is &ldquo;follow-up insufficient&rdquo;, the same headline as gbsg, reached from a ",
"completely different distance.</strong></p>",
"<p><strong>What to make of that.</strong> gbsg fails with <code>r_hat</code> of 0.31; this fails with 0.064. ",
"Those are not the same finding and should not prompt the same response. 0.05 is a convention, in the same family ",
"as the 0.05 in Maller-Zhou and Shen and the 0.025 floor on <code>pi_hat</code> &mdash; a line drawn by people, ",
"not a property of nature, and a dataset landing 0.014 on the wrong side of it is telling you the answer is ",
"genuinely uncertain, not that it is no. The honest reading is &ldquo;close, and worth discussing with a ",
"statistician&rdquo;, and the sensible next steps are a sensitivity analysis and the alternatives listed below ",
"rather than either fitting the cure model anyway or abandoning it.</p>"
)

# --- J.6 Per-method explainers (Documentation tab, one accordion panel each) -
# [SIGN-OFF: G] the six Direction lines are the highest-risk copy in the app
# (R13). Review them against the package source, not against the docs.
CA_COPY_METHOD_MZ_TITLE <- "Maller–Zhou test (1994) — mz.test()"

CA_COPY_METHOD_MZ_HTML <- paste0(
"<ul class='ca-read'>",
"<li class='ca-read__item'><em>The question it asks:</em> did follow-up extend far enough past the last event ",
"that a plateau could be seen?</li>",
"<li class='ca-read__item'><em>Direction:</em> <strong>smaller is better</strong> &mdash; below &alpha; supports ",
"sufficient follow-up.</li>",
"<li class='ca-read__item'><em>Threshold, and where it comes from:</em> &alpha;, an argument you can change; the ",
"package default is 0.05.</li>",
"<li class='ca-read__item'><em>When it returns nothing, and why:</em> when the largest observed time is an event ",
"rather than a censored observation, there is no follow-up tail to measure and the statistic is undefined.</li>",
"<li class='ca-read__item'><em>Exact call and field:</em> <code>cureAssess::mz.test(dat, alpha)</code> &rarr; ",
"<code>$statistic</code>, <code>$alpha</code>, <code>$interpretation</code>.</li>",
# FIXPASS [SIGN-OFF: G] — WRONG CITATION, CORRECTED. This line used to read
# "Maller & Zhou (1994), Biometrika 81(4), 731-744. doi:10.1093/biomet/81.4.731",
# which conflates the two papers: it took the journal, volume and DOI stem of
# the 1992 Biometrika paper, put the 1994 year on them, and then mangled the
# volume (81 for 79) and the page range (731-744 for 731-739). The DOI it
# printed does not resolve to either paper. Both papers are cited below,
# verbatim from cureAssess/README.md and the roxygen @references in
# cureAssess/R/mz.test.R. mz.test() implements the 1994 JASA statistic; the
# 1992 Biometrika paper is the companion the package also cites.
"<li class='ca-read__item'><em>Reference:</em> Maller RA &amp; Zhou S (1992), <em>Estimating the ",
"proportion of immunes in a censored sample.</em> Biometrika 79(4), 731&ndash;739. ",
"doi:10.1093/biomet/79.4.731</li>",
"<li class='ca-read__item'><em>Reference:</em> Maller RA &amp; Zhou S (1994), <em>Testing for ",
"sufficient follow-up and outliers in survival data.</em> Journal of the American Statistical ",
"Association 89(428), 1499&ndash;1506. doi:10.1080/01621459.1994.10476889</li>",
"</ul>"
)

CA_COPY_METHOD_QN_TITLE <- "qn statistic (Maller & Zhou 1996) — qn.test()"

CA_COPY_METHOD_QN_HTML <- paste0(
"<ul class='ca-read'>",
"<li class='ca-read__item'><em>The question it asks:</em> what share of events fall inside a late window as wide ",
"as the flat tail?</li>",
"<li class='ca-read__item'><em>Direction:</em> <strong>larger is better</strong> &mdash; above the threshold ",
"supports sufficient follow-up. This is the opposite of Maller&ndash;Zhou and Shen; getting it backwards is a ",
"blocking bug.</li>",
"<li class='ca-read__item'><em>Threshold, and where it comes from:</em> <code>1 - &alpha;^(1/n)</code>, which ",
"moves with sample size. <code>qn.test()</code> returns no threshold field, so <strong>this app computes it</strong> ",
"from &alpha; and n &mdash; the single closed form the app is permitted to evaluate. The package's own sentence ",
"always quotes its own fixed 0.05 version.</li>",
"<li class='ca-read__item'><em>When it returns nothing, and why:</em> the same gate as Maller&ndash;Zhou and Shen ",
"&mdash; largest observed time is an event.</li>",
"<li class='ca-read__item'><em>Exact call and field:</em> <code>cureAssess::qn.test(dat)</code> &rarr; ",
"<code>$statistic</code>, <code>$interpretation</code>. There is no <code>alpha</code> argument and no ",
"<code>$threshold</code> field.</li>",
"<li class='ca-read__item'><em>Reference:</em> Maller &amp; Zhou (1996), <em>Survival Analysis with Long-Term ",
"Survivors</em>, Wiley.</li>",
"</ul>"
)

CA_COPY_METHOD_SHEN_TITLE <- "Shen test (2000) — shen.test()"

CA_COPY_METHOD_SHEN_HTML <- paste0(
"<ul class='ca-read'>",
"<li class='ca-read__item'><em>The question it asks:</em> the same follow-up question, through a narrower ",
"late-time window.</li>",
"<li class='ca-read__item'><em>Direction:</em> <strong>smaller is better</strong> &mdash; below &alpha; supports ",
"sufficient follow-up.</li>",
"<li class='ca-read__item'><em>Threshold, and where it comes from:</em> &alpha;, an argument; default 0.05. Shen ",
"is the stricter of the two by design: it exists because Maller&ndash;Zhou can over-declare sufficiency.</li>",
"<li class='ca-read__item'><em>When it returns nothing, and why:</em> same gate as above.</li>",
"<li class='ca-read__item'><em>Exact call and field:</em> <code>cureAssess::shen.test(dat, alpha)</code> &rarr; ",
"<code>$statistic</code>, <code>$alpha</code>, <code>$interpretation</code>.</li>",
# FIXPASS [SIGN-OFF: G] — WRONG CITATION, CORRECTED. This line used to read
# "Shen (2000), Statistics & Probability Letters 48(3), 313-318.
# doi:10.1016/S0167-7152(00)00012-2". Volume, issue, end page and DOI were all
# wrong; the DOI does not resolve to this paper. Corrected against
# cureAssess/README.md, cureAssess/DESCRIPTION and the roxygen @references in
# cureAssess/R/shen.test.R, which agree on 49(4), 313-322,
# doi:10.1016/S0167-7152(00)00063-8.
"<li class='ca-read__item'><em>Reference:</em> Shen P-S (2000), <em>Testing for sufficient ",
"follow-up in survival data.</em> Statistics &amp; Probability Letters 49(4), 313&ndash;322. ",
"doi:10.1016/S0167-7152(00)00063-8</li>",
"</ul>"
)

CA_COPY_METHOD_IMMUNE_TITLE <- "Maller–Zhou immune summary (1996) — immune.test()"

CA_COPY_METHOD_IMMUNE_HTML <- paste0(
"<ul class='ca-read'>",
"<li class='ca-read__item'><em>The question it asks:</em> what do the data look like at the end of follow-up ",
"&mdash; how much censoring, and was the last observation a censored subject?</li>",
"<li class='ca-read__item'><em>Direction:</em> <strong>none. This is descriptive, not a test.</strong> It has no ",
"statistic, no threshold and no null hypothesis, despite the name. It is never passed or failed.</li>",
"<li class='ca-read__item'><em>Threshold:</em> there is none, and the app must not invent one.</li>",
"<li class='ca-read__item'><em>When it returns nothing:</em> it always returns; <code>p_cens</code> is ",
"<code>NA</code> if the status column contains missing values.</li>",
"<li class='ca-read__item'><em>Exact call and fields:</em> <code>cureAssess::immune.test(dat)</code> &rarr; ",
"<code>$p_hat</code>, <code>$p_cens</code>, <code>$last_observation</code>, ",
"<code>$last_observation_censored</code>, <code>$interpretation</code>.</li>",
"<li class='ca-read__item'><em>Reference:</em> Maller &amp; Zhou (1996), Wiley.</li>",
"</ul>"
)

CA_COPY_METHOD_RECEUS_TITLE <- "RECeUS — receus.method()"

CA_COPY_METHOD_RECEUS_HTML <- paste0(
"<ul class='ca-read'>",
"<li class='ca-read__item'><em>The question it asks:</em> is the estimated cure fraction non-negligible, and is ",
"the share of uncured subjects still unresolved at the end of follow-up small enough to identify it?</li>",
"<li class='ca-read__item'><em>Direction:</em> two conditions, both required &mdash; &pi;&#770; ",
"<strong>greater than</strong> 0.025 <strong>and</strong> r&#770; <strong>less than</strong> 0.05.</li>",
"<li class='ca-read__item'><em>Thresholds, and where they come from:</em> 0.025 and 0.05 are fixed inside the ",
"package source and reachable by no argument. They come from Selukar &amp; Othus (2023), who chose and validated ",
"them.</li>",
"<li class='ca-read__item'><em>When it returns nothing, and why:</em> when the maximum-likelihood fit behind it ",
"does not converge, &pi;&#770; and r&#770; come back missing; the app reports that rather than a decision.</li>",
"<li class='ca-read__item'><em>Exact call and fields:</em> <code>cureAssess::receus.method(data, dist, ",
"whichTau)</code> &rarr; <code>$pi_hat</code>, <code>$r_hat</code>, <code>$tau</code>, ",
"<code>$cure_fraction_condition</code>, <code>$followup_condition</code>, <code>$decision</code>, ",
"<code>$interpretation</code>, <code>$estimates</code>.</li>",
"<li class='ca-read__item'><em>Reference:</em> Selukar &amp; Othus (2023).</li>",
"</ul>"
)

CA_COPY_METHOD_SCREENING_TITLE <- "Model screening — model.fitting() / cure.appropriateness()"

CA_COPY_METHOD_SCREENING_HTML <- paste0(
"<ul class='ca-read'>",
"<li class='ca-read__item'><em>The question it asks:</em> among eight candidate models (ten with lognormal), ",
"four of them cure models, which has the smallest AIC?</li>",
"<li class='ca-read__item'><em>Direction:</em> smaller AIC is a better description of the data you have. ",
"<strong>It is not evidence that a cure model is identifiable</strong> &mdash; that is what the five diagnostics ",
"are for.</li>",
"<li class='ca-read__item'><em>Threshold:</em> none. AIC is a ranking, not a test.</li>",
"<li class='ca-read__item'><em>When a row returns nothing, and why:</em> an individual fit can fail to converge; ",
"the package records the reason in the <code>error</code> column and sets <code>AIC = NA</code>. Failed rows sort ",
"last and are always shown.</li>",
"<li class='ca-read__item'><em>Exact call and fields:</em> <code>cureAssess::cure.appropriateness(data, time, ",
"status, time_scale, dist, plot_km, run_tests, include_lognormal)</code> &rarr; ",
"<code>$screening$aic_table</code>, <code>$screening$best_model</code>, ",
"<code>$screening$initial_decision</code>, <code>$selected_receus_dist</code>, <code>$tests</code>, ",
"<code>$tests_reason</code>, <code>$final_recommendation</code>.</li>",
"<li class='ca-read__item'><em>Reference:</em> the cureAssess tutorial manuscript; package by Mudunkotuwa &amp; ",
"Ghosh, MIT licence.</li>",
"</ul>"
)

# --- J.7 The category-C sensitivity panel (Quantitative tab) -----------------
# Substitutions, all made by mod_quantitative.R at render time:
#   {decision}     state$assess$tests$receus$decision, verbatim
#   {pi_hat}       state$assess$tests$receus$pi_hat, through ca_num()
#   {r_hat}        state$assess$tests$receus$r_hat, through ca_num()
#   {sens_pi_cut}  input$sens_pi_cut      {sens_r_cut}  input$sens_r_cut
# The panel renders exactly two condition rows and no third line: it never
# composes a "would be appropriate" sentence, never re-uses a package decision
# string as its own conclusion, and never emits a pass/fail chip.
CA_COPY_SENS_TITLE <- "⚠ What-if: your own cutoffs — for discussion only"

CA_COPY_SENS_LEDE_HTML <- paste0(
"<p><strong>This panel does not change the result.</strong> The numbers 0.025 and 0.05 are written inside the ",
"<code>cureAssess</code> package and cannot be changed through it. The decision above &mdash; ",
"<strong>&ldquo;{decision}&rdquo;</strong> &mdash; is the package's decision, and it is the one that counts.</p>"
)

CA_COPY_SENS_PACKAGE_HEAD_HTML <-
"<p><strong>The package's answer (fixed, and the only one used anywhere else in this app):</strong></p>"

CA_COPY_SENS_YOURS_HEAD_HTML <- paste0(
"<p><strong>If the cutoffs were the ones you picked</strong> (&pi;&#770; cutoff {sens_pi_cut}, r&#770; cutoff ",
"{sens_r_cut}), the same two &pi;&#770; and r&#770; would read:</p>"
)

CA_COPY_SENS_MEANING_HTML <- paste0(
"<p><strong>What that does and does not mean.</strong> It tells you how close this dataset sits to the published ",
"cutoffs. It does <strong>not</strong> mean a cure model would be appropriate under your cutoffs &mdash; the ",
"cutoffs in Selukar &amp; Othus (2023) were chosen and validated by the authors of the method; a number you typed ",
"has no such backing. Use this to see how far from the line you are, and to have a conversation about it. Do not ",
"use it to reach a different answer.</p>"
)

CA_COPY_SENS_FOOT_HTML <- paste0(
"<p><strong>Nothing on the Conclusion tab uses the numbers you typed here. Only the package's decision ",
"travels.</strong></p>"
)

CA_COPY_SENS_AT_DEFAULTS   <- "(at the package values)"
CA_COPY_SENS_CHANGED       <- "(cutoffs changed from the package values)"

# --- J.8 Conclusion tab ------------------------------------------------------
CA_COPY_CONCLUSION_HEADING <- "The three-step check, in the published order"

CA_COPY_CONCLUSION_SUBLINE <- paste0(
"The tabs run Quantitative before Qualitative for workflow convenience. The order of checking is not the order ",
"of reasoning — below is the published order."
)

CA_COPY_STEP1_TITLE <- "① Expert judgment"

CA_COPY_STEP1_BODY <- paste0(
"Software cannot judge clinical plausibility. Is there a clinical reason to expect that some patients in this ",
"population are cured? This step is a conversation with a clinician, and this app will never answer it for you."
)

CA_COPY_STEP2_TITLE <- "② Visual assessment"

CA_COPY_STEP2_LABEL <- "This is a visual aid, not a test."

CA_COPY_STEP3_TITLE <- "③ Quantitative assessment"

CA_COPY_STEP1_OPEN_BANNER <- paste0(
"Steps 2 and 3 are shown below, but a cure model is only appropriate if all three steps pass. Step 1 is still open."
)

CA_COPY_TESTS_REASON_PREFACE <- paste0(
"This sentence summarises the model comparison only — it does not mention RECeUS, π̂ or r̂. ",
"The RECeUS recommendation is step ③ above."
)

# Lead line is built at run time from the package strings and the chip rules
# (never from a docs table); this is the fixed block that follows it.
CA_COPY_DISAGREE_HTML <- paste0(
"<p><strong>Disagreement is information, not a malfunction.</strong> These five diagnostics ask overlapping but ",
"different questions, and they were published by different authors to catch different failures. Do not count them ",
"and take the majority &mdash; they are not votes. Maller&ndash;Zhou and <code>qn</code> are the same underlying ",
"count presented two ways, so they always agree with each other and are never independent confirmation of one ",
"another. Shen uses a narrower window precisely because Maller&ndash;Zhou can over-declare sufficiency, so ",
"Maller&ndash;Zhou passing while Shen fails is Shen working as designed. RECeUS asks the identifiability question ",
"most directly, through r&#770;. When they split: check how close each statistic sits to its threshold, prefer ",
"the stricter test when the pattern is the known one, weigh r&#770;, and look back at the curve.</p>"
)

# [SIGN-OFF: G] the ordering of the four routes and the "not implemented in
# cureAssess" wording.
CA_COPY_INSUFFICIENT_TITLE <- "Follow-up looks insufficient — what now?"

CA_COPY_INSUFFICIENT_HTML <- paste0(
"<h4>The diagnostics say follow-up is insufficient. What are my options?</h4>",
"<p>This is not a dead end, and it is not a verdict on your data quality. It means the follow-up you have cannot ",
"separate &ldquo;cured&rdquo; from &ldquo;not yet relapsed&rdquo;, so a cure model would return a number that ",
"looks precise and is not identified. Four routes:</p>",
"<div class='ca-read'>",
"<div class='ca-read__item'><p><strong>1. Fit a non-cure model instead.</strong> The most common and usually the ",
"right answer. Standard survival models &mdash; Cox, Weibull, whatever fits &mdash; remain valid and ",
"interpretable; you simply do not report a cure fraction. You lose a quantity the data could not support ",
"anyway.</p></div>",
"<div class='ca-read__item'><p><strong>2. Use the extreme-value estimators of Escobar-Bach and Van Keilegom ",
"(2019).</strong> Non-parametric cure-rate estimation designed specifically for insufficient follow-up, using ",
"extreme-value theory to extrapolate the tail rather than assuming the plateau is complete. Not implemented in ",
"<code>cureAssess</code> &mdash; you would fit this outside the app.</p></div>",
"<div class='ca-read__item'><p><strong>3. Use Yuen and Musta's relaxed condition (2024).</strong> A weaker ",
"sufficient-follow-up requirement than the classical condition used by the tests here, so some datasets that fail ",
"the classical condition are still workable under theirs. Also outside this app.</p></div>",
"<div class='ca-read__item'><p><strong>4. Collect more follow-up.</strong> If the study is ongoing, or a later ",
"data cut exists, this is the only route that fixes the problem at source rather than working around it. It is ",
"worth taking seriously: Othus et al. refitted cure models on six SWOG trials at an early and a later follow-up ",
"time, found the mean-survival estimates shifted materially, and found the <strong>direction of the shift was not ",
"predictable</strong>. There is no post-hoc correction to apply &mdash; which is why this check happens before ",
"you fit, not after.</p></div>",
"</div>",
"<p>References for 2, 3 and 4 are on the Documentation tab.</p>"
)

# --- J.9 Intro tab and the reproduce-in-R block ------------------------------
CA_COPY_INTRO_TITLE <- "Is a cure model appropriate for your data?"

CA_COPY_INTRO_HTML <- paste0(
"<p>A <strong>mixture cure model</strong> says that some patients will never have the event: ",
"S(t) = (1 &minus; p) + p&middot;Su(t), where p is the share who remain at risk. On a Kaplan-Meier curve that ",
"looks like a plateau above zero. Two extra assumptions ride along, and both can fail quietly: there must ",
"genuinely be a cured group, and follow-up must be long enough to tell a cured group apart from one that has ",
"simply not relapsed yet. <strong>A plateau produced by heavy censoring is an artifact, not cure.</strong></p>",
"<p>The published check has three steps: <strong>&#9312; expert judgment &rarr; &#9313; visual assessment &rarr; ",
"&#9314; quantitative assessment.</strong> This app automates &#9313; and &#9314;. Step &#9312; is a human ",
"conversation it must never decide.</p>",
"<p><strong>Failing any one step means a cure model is inappropriate. This is a conjunction, not a ",
"score.</strong></p>",
"<p>These tabs run the quantitative step before the visual one, because that is the order it is most convenient ",
"to work in. The order of <em>checking</em> is not the order of <em>reasoning</em>; the Conclusion presents all ",
"three steps in the published order.</p>"
)

CA_COPY_NOT_DO_TITLE <- "What this app does not do"

CA_COPY_NOT_DO_HTML <- paste0(
"<p>This app assesses whether a cure model is <em>appropriate</em>. It does not fit your final analysis model, ",
"and it does not produce treatment-effect estimates.</p>"
)

CA_COPY_INTRO_CTA <- "Start with an example dataset →"

CA_COPY_REPRODUCE_LEDE <- "Everything on this screen comes from these calls. Paste them into R to reproduce it."

# --- J.10 / J.11 The not-computable wording, shared by three cards -----------
# Rendered whenever mz, qn or shen returns NA, alongside ca_chip("void",
# "Cannot be computed") and the package's own interpretation string in
# ca_tech(). Immune and RECeUS still render.
CA_COPY_NOT_COMPUTABLE_1 <- paste0(
"Cannot be computed — the longest observed time is an event, so there is no plateau to test."
)

CA_COPY_NOT_COMPUTABLE_2 <- paste0(
"This is a property of the data, not an error. All three follow-up tests need follow-up to extend past the last ",
"event."
)

CA_COPY_NOT_COMPUTABLE_CHIP <- "Cannot be computed"

CA_COPY_IMMUNE_CHIP <- "Descriptive, not a test"

# --- end interpretation copy: owner Geethanjalee -----------------------------
