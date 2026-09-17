# =============================================================================
# app/R/helpers.R — shared non-statistical utilities and HTML component builders
# Owner: builder-shell.  APPEND-ONLY: no other builder edits this file.
#
# This file implements the BUILD_CONTRACT section F helpers, with the contract
# signatures and return types, plus the four additions of REVISION_CONTRACT
# §D.3, and nothing else. A helper you need that is not here belongs in your own
# module file with your module's prefix (.quant_*, .data_*, .qual_*), never here.
#
# REVISION_CONTRACT §E.8: this file holds NO user-facing statistical prose. The
# 52 shared copy constants that used to fill the bottom half are deleted; the
# copy now lives in the module that renders it, where the rewriter who owns
# that screen can see it. F.16 is withdrawn too — nothing about the package
# appears in the visible UI, only in code comments like this one.
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
# It is well mitigated on screen: the value is described as the height the
# curve settles at, never as pi-hat, and it carries no method name, no author
# name and no threshold (REVISION_CONTRACT §F). The behaviour is NOT being
# changed in this pass, and nobody should delete it without the team deciding
# first.
#
# REVISION_CONTRACT §F reduces the exposure further: the whole immune summary is
# gone from the screen and from the report, and this field and
# last_observation_censored are the only two reads that survive, both silent,
# both from mod_qualitative.R only.
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
#' user-chosen alpha must render `1 - alpha^(1/n)` itself. For qn, LARGER is
#' better: the statistic must exceed this threshold. (The on-screen threshold
#' line is "Above {threshold}" and says nothing about where it came from —
#' REVISION_CONTRACT §G.5.2.)
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
#' A statement about the data that is not a test result always takes the
#' "neutral" variant — never pass/fail — and "cannot be computed" is "void",
#' never a red "fail".
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
#' @param foot Optional footer, typically a one-line `.ca-provenance` footnote.
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
#
# V2_CONTRACT §B.6 — THE STALENESS RULE, widened for auto-compute.
# With the Run and Prepare buttons gone (§B.0), the only thing standing between
# a mapping change and a stale number on screen is this function running as the
# FIRST statement of the auto-prepare observer, before any package call. It
# therefore has to clear everything derived from the old mapping, not just the
# assessment: the fitted objects behind the Kaplan-Meier overlay, the tau
# exploration, and the batch table whose rows were keyed on that mapping.
#
# Two changes this pass, both required by §B.6:
#   * `state$fit`, `state$tau_result` and `state$batch` are nulled too. The last
#     two are new fields, declared in app.R.
#   * `state$status` returns to "empty", not "data_loaded". "data_loaded" named
#     the mapped-but-not-yet-prepared limbo that only existed because a human
#     had to press Prepare. Nothing waits there any more: the observer that
#     calls this function prepares on the next line, so the state is transient
#     and is never painted. The live vocabulary is empty | error | prepared |
#     assessed.
ca_reset_assessment <- function(state) {
  state$assess      <- NULL
  state$fit         <- NULL
  state$alpha_tests <- NULL
  state$tau_result  <- NULL
  state$batch       <- NULL
  state$last_error  <- NULL
  state$status      <- "empty"
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
#' @param titles Named character vector of full page headings, indexed by tab
#'   id, or NULL. FINAL_CONTRACT §B.3: between 768px and 992px the rail is a
#'   76px icon column and `.ca-rail__label` is visually hidden, and below 768px
#'   it is a horizontal bar carrying only number, glyph and state. A plain
#'   `title` attribute on the link is then the only way to recover the tab's
#'   full name on hover. It is an HTML attribute, not a tooltip component: no
#'   JS, no Bootstrap popover, nothing to initialise. NULL keeps the markup
#'   byte-for-byte as it was, so this argument is additive.
#' @return `htmltools` `<nav class="ca-rail">`.
ca_rail <- function(order, labels, states = NULL, active = NULL, titles = NULL) {
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
    ttl <- if (!is.null(titles) && id %in% names(titles)) {
      as.character(titles[[id]])
    } else {
      NULL
    }

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
        title = ttl,
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


# ---- F.16 — WITHDRAWN -------------------------------------------------------
# The one-line provenance builder is DELETED (REVISION_CONTRACT §D.3). Nothing about
# the package — no function name, no field path, no `$` path — appears in the
# visible UI any more. The provenance itself is NOT lost: every site that reads
# a package field now carries the field path as an R comment beside the read,
# so the team can still see where each number came from.
#
# The CSS class `.ca-provenance` stays: it is the small-print style used for the
# Data sidebar hints and for one-line footnotes.


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
# REVISION_CONTRACT §D.3 — the four additions. Consumed by five modules; do not
# define a local same-named copy anywhere else.
# =============================================================================

# ---- N.1 --------------------------------------------------------------------
#' The three-way expert-judgment outcome — the single implementation
#'
#' `mod_expert.R`, `mod_recommendation.R` and the rail in `app.R` all call this;
#' nobody re-derives the outcome from the raw `expert_q1` / `expert_q2` fields.
#'
#' The software never answers the two questions and never infers the outcome
#' from a statistic: `"unanswered"` is a real, visible state.
#'
#' @param state The single shared `reactiveValues`.
#' @return chr(1): `"yes"`, `"no"` or `"unanswered"`.
ca_expert_state <- function(state) {
  q1 <- state$expert_q1
  q2 <- state$expert_q2
  norm <- function(x) if (is.null(x) || length(x) != 1L || is.na(x)) "" else as.character(x)
  q1 <- norm(q1); q2 <- norm(q2)
  if (!nzchar(q1) || !nzchar(q2)) return("unanswered")
  if (identical(q1, "yes") && identical(q2, "yes")) return("yes")
  "no"
}


# ---- N.2 --------------------------------------------------------------------
#' Is the longest observed time a censored observation?
#'
#' THE ONE SANCTIONED SILENT READ (REVISION_CONTRACT §F). This reads
#' `state$assess$tests$immune$last_observation_censored` — a field of
#' `cureAssess::immune.test()`, reached through `cure.appropriateness()`.
#'
#' §F's rule, carried here so it travels with the code:
#'  * The immune summary is GONE as a visible object. Its card, its four
#'    numbers, its interpretation string, its chip, its documentation panel and
#'    its report card are all deleted. The words "immune", `p_hat`, `p_cens`,
#'    `last_observation` and `last_observation_censored` never appear on screen
#'    or in the report again.
#'  * This field may still be read, silently, by `mod_qualitative.R` ONLY, and
#'    rendered as ONE neutral chip — a statement about the data, never a pass,
#'    never a fail, never a test result.
#'  * The chip variant is `ca_chip("neutral", ...)`. Never "pass", "fail",
#'    "caution" or "void".
#'  * No method name, author name, threshold, alpha, p-value or
#'    "descriptive, not a test" disclaimer goes anywhere near it.
#'  * No replacement statistic may be invented to fill the gap. The gap is
#'    intentional.
#'  * Guarded by `ca_has_tests()`: before an assessment has landed this returns
#'    NA and the chip renders NOTHING AT ALL - it appears with the result rather
#'    than standing in for it. (The old "Run the assessment to check this" label
#'    retired with the Run button.) It never renders the literal text NA.
#'
#' @param state The single shared `reactiveValues`.
#' @return `TRUE`, `FALSE`, or `NA` when there is no usable assessment.
ca_last_obs_censored <- function(state) {
  if (!ca_has_tests(state)) return(NA)
  # reads $tests$immune$last_observation_censored; see REVISION_CONTRACT §F
  im <- state$assess$tests$immune
  if (is.null(im)) return(NA)
  v <- im$last_observation_censored
  if (is.null(v) || length(v) != 1L || is.na(v)) return(NA)
  isTRUE(v)
}


# ---- N.3 --------------------------------------------------------------------
#' Display names for the ten model keys
#'
#' So that no `loglogistic_cure`-style key is ever rendered as prose. Index it
#' with `CA_MODEL_LABELS[[key]]` guarded by a `key %in% names(...)` test, or use
#' the fallback idiom below: an unknown key resolves to the key itself, never to
#' NA and never to an error.
#'
#'   lab <- if (!is.na(key) && key %in% names(CA_MODEL_LABELS))
#'            CA_MODEL_LABELS[[key]] else key
#'
#' Keys are the values of `$screening$best_model` and the `model` column of
#' `$screening$aic_table`.
CA_MODEL_LABELS <- c(
  exponential       = "exponential",
  exponential_cure  = "exponential cure model",
  weibull           = "Weibull",
  weibull_cure      = "Weibull cure model",
  gamma             = "gamma",
  gamma_cure        = "gamma cure model",
  loglogistic       = "log-logistic",
  loglogistic_cure  = "log-logistic cure model",
  lognormal         = "lognormal",
  lognormal_cure    = "lognormal cure model"
)


# ---- N.4 --------------------------------------------------------------------
# The QR image encodes this URL. cureAssess 0.1.0 is a PENDING CRAN submission
# (cureAssess/cran-comments.md), so for now this is the upstream repository and
# every on-screen label says "the package", never "CRAN". On acceptance, change
# this one line to the CRAN address and regenerate app/www/img/cureassess-qr.svg.
CA_PACKAGE_URL <- "https://github.com/GeethanjaleeM/cureAssess"


# =============================================================================
# V2_CONTRACT §B.4, §C.1, §C.3 — the shared engine surface.
#
# Four things, and nothing else: the one package call site, the four batch
# constants, the one recommendation rule, and the status line. All three
# versions (app/, app-v2/, app-v3/) call these; none of them writes its own.
#
# Nothing below computes an inferential statistic. ca_assess_once() passes
# arguments to the package and returns what it gets; ca_recommendation() is a
# lookup on two package fields plus the human's answer; ca_status_line()
# renders no number at all.
# =============================================================================


# ---- F.22 -------------------------------------------------------------------
#' F.22 — THE single cure.appropriateness() call site in the repository.
#' S2 run_tests = "yes"; S5 time_scale = "none" (prepared is already scaled);
#' S3 dist = NULL, the package picks and reports $selected_receus_dist.
#' plot_km: TRUE for the single-dataset path (the overlay needs the curve),
#' FALSE for batch (measured: it halves the cost and no curve reaches a CSV).
#' The caller wraps this in tryCatch (S7). It does not wrap itself, because the
#' two callers need different failure behaviour.
ca_assess_once <- function(prepared, include_lognormal = FALSE, plot_km = TRUE) {
  stopifnot(is.data.frame(prepared), all(c("Y", "D") %in% names(prepared)))
  suppressMessages(cureAssess::cure.appropriateness(
    data              = prepared,
    time              = "Y",
    status            = "D",
    time_scale        = "none",
    dist              = NULL,
    plot_km           = isTRUE(plot_km),
    run_tests         = "yes",
    include_lognormal = isTRUE(include_lognormal)
  ))
}


# ---- F.22b ------------------------------------------------------------------
# V2_CONTRACT §C.1 — the batch size gate and its ceilings, as named constants so
# each one changes in exactly one line. Read by app/R/mod_batch.R and by the
# selection previews in app-v2/ and app-v3/.
#
# WHY 20 / 5 / 5, and why a gate exists at all:
# the richest candidates carry three free parameters (the cure fraction plus two
# shape/scale), the uncured distribution is identified by the events and the
# cure fraction by the censored tail, so 3 + 3 is the mathematical floor. The
# package will happily return "Cure model appropriate" with a cure fraction of
# 0.498 on n = 6 (verified), so the gate exists to prevent a table of confident
# nonsense, not to prevent a crash. 20 is operational, not a theorem.
CA_BATCH_MIN        <- list(n = 20L, events = 5L, censored = 5L)

# Hard ceiling on a split. Above this the panel refuses outright (§C.7 F12):
# async is banned and Shiny is single-threaded, so the tab is frozen for the
# whole run and 200 frames is already ~40 s.
CA_BATCH_MAX_GROUPS <- 200L

# Below this n a row is assessed but flagged as indicative (§C.7 F22).
CA_BATCH_WARN_N     <- 300L

# Above this many NEW rows, a split needs one confirming click (§C.6). This is
# the only button left anywhere in app/, and it is a guard against a deliberate
# multi-second freeze, not a Run button.
CA_BATCH_AUTO_MAX   <- 12L


# ---- F.23 -------------------------------------------------------------------
#' F.23 — the ONE recommendation rule in the repository.
#' R8: the only inputs are $screening$best_model_type and $tests$receus$decision,
#' i.e. the AIC screening and the RECeUS decision from cure.appropriateness(),
#' plus the human's expert answer. Nothing else feeds it in any version.
#' alpha, tau and the distribution override are display-only and are forbidden
#' from reaching this function or report.Rmd.
#'
#' This is `.rec_verdict()` lifted out of mod_recommendation.R with its two
#' `state` reads turned into arguments, so the single view, the batch table, the
#' batch CSV and both alternative versions all state the same verdict from the
#' same code. `.rec_verdict()` is now a three-line wrapper over it.
#'
#' Rules, in this order, and the order matters:
#'   1. an expert "no" overrides everything;
#'   2. a missing AIC screening result gives "No recommendation.";
#'   3. the AIC result crossed with the RECeUS decision;
#'   4. provisional is TRUE when the expert question is unanswered, and rides
#'      with rules 2 and 3 only — never with rule 1.
#'
#' @param aic_type chr(1)/NA — `$screening$best_model_type`, "cure" or "non-cure".
#' @param receus_decision chr(1)/NA — `$tests$receus$decision`.
#' @param expert chr(1) — "yes", "no" or "unanswered", from `ca_expert_state()`.
#' @return `list(headline = chr(1), variant = chr(1)|NULL, reasons = chr(n),
#'   provisional = lgl(1))`. `variant` is NULL for "No recommendation." — that
#'   outcome carries no banner colour.
ca_recommendation <- function(aic_type, receus_decision, expert = "unanswered") {

  # ---- Rule 1 — expert judgment overrides everything ------------------------
  if (identical(as.character(expert), "no")) {
    return(list(
      headline = "Do not use a cure model.",
      variant  = "ca-rec--unsupported",
      # FINAL_CONTRACT E2 / §G.2: ", whatever the numbers say" is struck. The
      # same sentence is mirrored, character for character, by mod_expert.R's
      # "no" outcome line and by rp_recommendation() in report/report.Rmd —
      # three owners, one string. If one of them drifts the screen and the
      # report disagree.
      reasons  = paste(
        "You answered no at the expert judgment step. A cure model is not",
        "appropriate here."
      ),
      provisional = FALSE
    ))
  }

  # Rule 4 rides along with Rules 2 and 3, never with Rule 1. When the expert
  # step is answered "yes", nothing at all is added — a silent pass is a pass.
  provisional <- identical(as.character(expert), "unanswered")

  no_recommendation <- function(why) list(
    headline = "No recommendation.", variant = NULL,
    reasons = why, provisional = provisional
  )

  # ---- Rule 2 — nothing was fitted ------------------------------------------
  # reads $screening$best_model_type
  if (is.null(aic_type) || length(aic_type) != 1L || is.na(aic_type)) {
    return(no_recommendation("No model could be fitted to these data."))
  }

  # V2_CONTRACT §C.3, the one behavioural addition this pass. An ABSENT or NA
  # decision now returns "No recommendation." instead of stopping: batch has to
  # put a row on screen for a group whose diagnostics never ran ($tests_run
  # FALSE, §C.7 F20), and a stop() there would take the whole table down. The
  # loud stop() on an UNRECOGNISED decision string stays, one line below — a
  # string the app cannot parse must still halt, because a verdict the app
  # cannot derive is a verdict it must not state.
  if (is.null(receus_decision) || length(receus_decision) != 1L ||
      is.na(receus_decision)) {
    return(no_recommendation("The diagnostics did not run for these data."))
  }

  # The three decision strings receus.method() can emit
  # (cureAssess/R/receus.method.R:121, :132, :143). Nothing else is legal.
  decisions <- c("Cure model appropriate",
                 "Cure model not supported",
                 "Follow-up insufficient for cure modeling")
  dec <- as.character(receus_decision)
  if (!(dec %in% decisions)) {
    stop("Unrecognised RECeUS decision string: ", paste(dec, collapse = " "))
  }

  # ---- Rule 3 — the numbers, crossed ----------------------------------------
  # model.fitting() only ever puts "cure" or "non-cure" in best_model_type
  # (cureAssess/R/model.fitting.R:194, off aic_table$model_type), so the two
  # columns of the contract's table are this one test.
  is_cure <- identical(as.character(aic_type), "cure")

  headline <- "Do not use a cure model."
  variant  <- "ca-rec--unsupported"
  also_non_cure <- "A model without a cured group also describes these data better."

  if (identical(dec, "Cure model appropriate")) {
    if (is_cure) {
      headline <- "Use a cure model."
      variant  <- "ca-rec--appropriate"
      reasons  <- "There is a cured group, and follow-up is long enough to measure it."
    } else {
      reasons <- paste(
        "Follow-up and the cured group look adequate, but a model without a",
        "cured group describes these data better."
      )
    }
  } else if (identical(dec, "Follow-up insufficient for cure modeling")) {
    reasons <- paste(
      "Follow-up is too short to tell a cured patient from one who has not",
      "had the event yet."
    )
    if (!is_cure) reasons <- c(reasons, also_non_cure)
  } else {
    # "Cure model not supported"
    reasons <- "The cured group is too small to be worth modelling."
    if (!is_cure) reasons <- c(reasons, also_non_cure)
  }

  list(headline = headline, variant = variant, reasons = reasons,
       provisional = provisional)
}


# ---- F.24 -------------------------------------------------------------------
#' The one-line statement of where the assessment currently stands
#'
#' V2_CONTRACT R2 removed every Run and Prepare button, so the app computes on
#' its own as the user moves around. A full assessment measures 0.1-0.2 s, which
#' reads as a blink — but a blink with no announcement is invisible to anyone
#' not watching the number, and a rare slow one would look frozen. `withProgress`
#' covers the visible channel (§B.5); this covers the other one.
#'
#' It is mounted inside a visually-hidden `aria-live="polite"` region, so it
#' announces the change to assistive technology and adds **zero visible words**
#' (C2, §H.6). It states no number, names no method and names no package.
#'
#' Status vocabulary, after §B.6: empty | error | prepared | assessed.
#'
#' @param state The single shared `reactiveValues`.
#' @return chr(1). Never NA, never empty.
ca_status_line <- function(state) {
  st  <- state$status
  st  <- if (is.null(st) || length(st) != 1L || is.na(st)) "empty" else as.character(st)
  raw <- state$raw

  if (identical(st, "error"))    return("That data could not be used.")
  if (is.null(raw))              return("No data loaded.")
  if (identical(st, "assessed")) return("Assessment ready.")
  if (identical(st, "prepared")) {
    # prepared but no assessment on the object means the fits threw (§B.7). The
    # sentence that explains it lives on the Quantitative tab; this is only the
    # announcement that the wait is over.
    if (!is.null(state$last_error)) return("The models could not be fitted.")
    if (is.null(state$assess))      return("Assessing.")
    return("Assessment ready.")
  }
  "Preparing the data."
}
