# =============================================================================
# mod_qualitative.R — the Qualitative tab (nav id "qual"), owner: builder-tabs-b
#
# Two of the three published steps live here, because neither is a computation:
#   step 2  VISUAL ASSESSMENT  — the annotated KM curve and the reading guide
#   step 1  EXPERT JUDGMENT    — the user's own checkbox, which software never ticks
#
# Package call sites: NONE. Every number on this tab is read out of state$fit
# (the survfit / ggsurvplot objects) or state$assess (the cure.appropriateness
# result), or is one of the app-side descriptives permitted by contract §F.
# =============================================================================


# ---- private helpers (contract §F: module-prefixed, defined in my own file) --

#' Plot colours, from theme.R's own palette accessor.
#'
#' theme.R's plot-helper header instructs this module to take every mark from
#' `ca_plot_cols(dark)` and never to type a hex literal, so that the same hue
#' never means two things in two tabs. The literal fallback mirrors the same
#' token table and exists only so the tab still draws if theme.R is not loaded.
.qual_cols <- function(dark = FALSE) {
  if (exists("ca_plot_cols", mode = "function")) {
    cols <- try(ca_plot_cols(dark), silent = TRUE)
    if (!inherits(cols, "try-error") && is.list(cols)) return(cols)
  }
  if (!isTRUE(dark)) {
    list(km = "#00739B", overlay = "#C2571F", censor = "#0A5670",
         tail_fill = "#E7ECEE", tail_rule = "#8A979B", tail_ink = "#414D52",
         level = "#4E6068", ink2 = "#414D52")
  } else {
    list(km = "#2E9BC6", overlay = "#D4732F", censor = "#8CCBE2",
         tail_fill = "#20292C", tail_rule = "#8A979B", tail_ink = "#AEBCC0",
         level = "#9DAEB4", ink2 = "#AEBCC0")
  }
}

#' The shared ggplot2 theme, guarded.
#'
#' `theme_cure_assess()` is theme.R's (contract §F preamble). If it is not
#' loaded the tab still draws, on ggplot2's own minimal theme.
.qual_theme <- function(dark = FALSE) {
  if (exists("theme_cure_assess", mode = "function")) {
    th <- try(theme_cure_assess(dark), silent = TRUE)
    if (!inherits(th, "try-error")) return(th)
  }
  ggplot2::theme_minimal(base_size = 14)
}

#' Render `ca_tail_facts()$gap_pct`, which helpers.R returns already scaled to
#' percent (`100 * gap / max_time`). Presentational only.
.qual_fmt_pct <- function(x, digits = 1) {
  if (is.null(x) || length(x) != 1L || !is.finite(x)) return(ca_dash())
  paste0(ca_num(x, digits), "%")
}

#' Which built-in dataset is loaded, for the worked reading.
#'
#' Matches on the registry label rather than on a key, because only `label` and
#' `source` reach this module (contract §C). Returns NA when the dataset is an
#' upload or one of the four simulated scenarios, which have no worked reading.
.qual_dataset_key <- function(state) {
  if (!identical(state$source, "builtin")) return(NA_character_)
  lab <- state$label
  if (is.null(lab) || !nzchar(lab)) return(NA_character_)
  if (grepl("^gbsg", lab, ignore.case = TRUE))   return("gbsg")
  if (grepl("^nwtco", lab, ignore.case = TRUE))  return("nwtco")
  if (grepl("^colon", lab, ignore.case = TRUE))  return("colon")
  NA_character_
}

#' The KM level at the end of follow-up, for the plateau guide line.
#'
#' Reads `1 - immune$p_hat` through `ca_tail_level()` (contract §F.3) when the
#' assessment exists; otherwise reads the last value of the package's own
#' Kaplan-Meier estimate out of `state$fit$kmfit`. Both are package output —
#' neither is a survival calculation done in app code.
#'
#' This is the KM level, not RECeUS `pi_hat`; the two are close but not equal
#' (gbsg: 0.3428 vs 0.3238) and the on-plot label says "tail level S =".
#'
#' FIXPASS (finding 1.3): the function silently switched between two DIFFERENT
#' definitions of the same displayed number — `1 - immune$p_hat` when the
#' assessment exists, `kmfit$surv[last]` when it does not — and nothing on
#' screen said which one the reader was looking at. The two are numerically
#' identical only because `immune.test()` itself defines
#' `pHat <- 1 - summary(kmfit, times = lastObs, extend = TRUE)$surv`; the app
#' was asserting that identity without stating it. Value and provenance string
#' are now produced by ONE function, `.qual_tail_level_info()`, so the label
#' under the plot can never drift from the branch that produced the number.
.qual_tail_level_info <- function(state) {
  if (ca_has_tests(state) && !is.null(state$assess$tests$immune)) {
    lv <- ca_tail_level(state$assess$tests$immune)
    if (is.finite(lv)) {
      return(list(
        value = lv,
        source = "cure.appropriateness() -> 1 - $tests$immune$p_hat"
      ))
    }
  }
  sf <- state$fit$kmfit
  if (is.null(sf) || is.null(sf$surv) || !length(sf$surv)) {
    return(list(value = NA_real_, source = NA_character_))
  }
  lv <- sf$surv[[length(sf$surv)]]
  if (!is.finite(lv)) return(list(value = NA_real_, source = NA_character_))
  list(value = lv, source = "survival::survfit() -> $surv[last]")
}

.qual_tail_level <- function(state) {
  .qual_tail_level_info(state)$value
}

#' Name of the cure model whose curve is drawn beside the Kaplan-Meier estimate.
#'
#' FIXPASS (finding 1.1, R1 violation): this used to run its own
#' `which.min(AIC)` over `state$fit$fits` and present the winner on screen as
#' "the cure model with the lowest AIC in the candidate set". That is a
#' model-selection DECISION, and the package already makes it and publishes it:
#' `cure.appropriateness()` performs the identical selection at
#' `cureAssess/R/cure.appropriateness.R:176`
#' (`best_cure_model <- cure_rows$model[which.min(cure_rows$AIC)]`) and returns
#' it as **`$selected_receus_model`** — the very name RECeUS is then run under.
#' Worse, the app's re-derivation ran over `state$fit`, which is a DIFFERENT
#' `model.fitting()` call from the one behind the assessment, so the two could
#' in principle name different models while the screen claimed one decision.
#'
#' Now: when `ca_has_tests(state)` the package field is read and used directly.
#' The `which.min` path survives ONLY as the pre-assessment fallback — there is
#' no package field to read before the assessment has been run — and the caller
#' labels it on screen as such.
#'
#' @return `list(model = character(1) or NA_character_, from = "package" or "app")`.
#'   `from == "package"` means `state$assess$selected_receus_model`;
#'   `from == "app"` means the app-side fallback described above.
.qual_best_cure_model <- function(state) {
  fit <- state$fit
  fits <- if (is.null(fit)) NULL else fit$fits
  if (is.null(fits) || !length(fits)) {
    return(list(model = NA_character_, from = "app"))
  }

  # --- the package's own decision, read as a field (contract §I.11) ----------
  # `selected_receus_model` may be NULL, NA_character_ or a model name; all
  # three are handled. It is only trusted when it names a model that actually
  # exists and converged in the `state$fit` we are about to draw from, since
  # that object may have come from a different model.fitting() call.
  if (ca_has_tests(state)) {
    sel <- state$assess$selected_receus_model
    if (!is.null(sel) && length(sel) == 1L && !is.na(sel) && nzchar(sel) &&
        sel %in% names(fits)) {
      f <- fits[[sel]]
      if (is.null(f$error) && !is.null(f$fit)) {
        return(list(model = as.character(sel), from = "package"))
      }
    }
  }

  # --- fallback, pre-assessment only ----------------------------------------
  # Cure models are the names ending in `_cure`, the same rule model.fitting()
  # uses to fill the `model_type` column.
  nms <- grep("_cure$", names(fits), value = TRUE)
  if (!length(nms)) return(list(model = NA_character_, from = "app"))
  ok <- vapply(nms, function(m) {
    f <- fits[[m]]
    is.null(f$error) && !is.null(f$fit) && length(f$AIC) == 1L && is.finite(f$AIC)
  }, logical(1))
  nms <- nms[ok]
  if (!length(nms)) return(list(model = NA_character_, from = "app"))
  aics <- vapply(nms, function(m) as.numeric(fits[[m]]$AIC), numeric(1))
  list(model = nms[[which.min(aics)]], from = "app")
}

#' Kaplan-Meier step data read straight off the package's survfit object.
#'
#' The column set theme.R's `ca_km_overlay_plot()` documents: time, surv, the
#' confidence limits and the per-time censoring counts, each prefixed with the
#' t = 0 row the survfit object leaves implicit.
.qual_km_frame <- function(sf) {
  if (is.null(sf) || is.null(sf$time) || !length(sf$time)) return(NULL)
  out <- data.frame(
    time = c(0, sf$time),
    surv = c(1, sf$surv),
    stringsAsFactors = FALSE
  )
  if (!is.null(sf$lower) && length(sf$lower) == length(sf$time)) {
    out$lower <- c(1, sf$lower)
    out$upper <- c(1, sf$upper)
  }
  if (!is.null(sf$n.censor) && length(sf$n.censor) == length(sf$time)) {
    out$n.censor <- c(0, sf$n.censor)
  }
  out
}

#' Fitted survival curve for one candidate model, via the fitting package's own
#' summary method. Never a hand-coded S(t): `summary(fit, type = "survival")`
#' is the flexsurv/flexsurvcure accessor the contract names in §H.2.
.qual_model_curve <- function(fit_obj, grid) {
  if (is.null(fit_obj) || !length(grid)) return(NULL)
  s <- try(summary(fit_obj, type = "survival", t = grid, ci = FALSE), silent = TRUE)
  if (inherits(s, "try-error")) return(NULL)
  if (is.list(s) && !is.data.frame(s)) {
    if (!length(s)) return(NULL)
    s <- s[[1]]
  }
  s <- as.data.frame(s, stringsAsFactors = FALSE)
  tcol <- intersect(c("time", ".time"), names(s))
  ecol <- intersect(c("est", ".est", "estimate"), names(s))
  if (!length(tcol) || !length(ecol)) return(NULL)
  out <- data.frame(time = s[[tcol[[1]]]], surv = s[[ecol[[1]]]],
                    stringsAsFactors = FALSE)
  out[is.finite(out$time) & is.finite(out$surv), , drop = FALSE]
}


# ---- the annotated KM plot ---------------------------------------------------

#' Add the four annotation layers to the package's own ggsurvplot.
#'
#' Contract §M relocated `annotate_km()` here: the layers are private to this
#' module, and only `ca_tail_facts()` and `ca_tail_level()` are shared. The four
#' layers, in the order the reading guide walks them:
#'   1. shaded follow-up tail band  — last event to end of follow-up (check 6)
#'   2. last-event marker           — the vertical rule closing the band (check 3)
#'   3. censored-in-tail count      — the label inside the band (check 5)
#'   4. plateau guide               — the dotted KM tail level (check 1)
#'
#' The band is prepended to `$layers` so it sits behind the curve rather than
#' over it. The risk table (`$table`) is left as the package built it; printing
#' the ggsurvplot draws curve and table together.
.qual_annotate_km <- function(sp, prepared, tail_level = NA_real_, dark = FALSE) {
  if (is.null(sp) || is.null(sp$plot)) return(sp)
  cols <- .qual_cols(dark)
  facts <- ca_tail_facts(prepared)

  # theme.R restyles both the curve and the risk table in one call, and already
  # suppresses survminer's cosmetic "Ignoring unknown labels" message.
  if (exists("ca_style_survplot", mode = "function")) {
    sp <- ca_style_survplot(sp, dark)
  } else {
    sp$plot <- sp$plot + .qual_theme(dark)
    if (!is.null(sp$table)) sp$table <- sp$table + .qual_theme(dark)
  }
  p <- sp$plot

  if (!is.null(facts) && isTRUE(is.finite(facts$last_event)) &&
      isTRUE(is.finite(facts$max_time)) && !isTRUE(facts$zero_width)) {

    # Layers 1 and 2: the shaded band and the hairline closing it at the last
    # event. Both are prepended so the band sits behind the curve rather than
    # washing over it; any label the helper adds stays on top.
    tail_layers <- ca_followup_tail(
      facts$last_event, facts$max_time, dark,
      min_time = 0, label = "follow-up tail"
    )
    if (length(tail_layers)) {
      behind <- tail_layers[seq_len(min(2L, length(tail_layers)))]
      infront <- if (length(tail_layers) > 2L) tail_layers[-seq_len(2L)] else list()
      p$layers <- c(behind, p$layers)
      for (lyr in infront) p <- p + lyr
    }

    # Layer 3: what the band actually contains, which is check 5 of the guide.
    p <- p +
      ggplot2::annotate(
        "text",
        x = facts$last_event, y = 0.97,
        label = "last event", hjust = 1.05, vjust = 1,
        size = 3.0, colour = cols$tail_ink, family = "sans"
      ) +
      ggplot2::annotate(
        "text",
        x = (facts$last_event + facts$max_time) / 2, y = 0.06,
        label = paste0(
          facts$n_cens_after, " censored in this band\n",
          .qual_fmt_pct(facts$gap_pct), " of follow-up, no events"
        ),
        hjust = 0.5, vjust = 0, size = 3.0, lineheight = 1.15,
        colour = cols$tail_ink, family = "sans"
      )
  }

  # Layer 4: the plateau guide. [SIGN-OFF: G] the on-plot phrase "tail level
  # S =" stands in for the cure fraction. It is the KM level (gbsg 0.3428), not
  # RECeUS pi_hat (0.3238); confirm the wording keeps them distinct.
  if (isTRUE(is.finite(tail_level))) {
    for (lyr in ca_level_line(
      tail_level, dark,
      label = paste0("tail level S = ", ca_num(tail_level, 3))
    )) p <- p + lyr
  }

  sp$plot <- p
  sp
}

#' KM curve beside the best-fitting cure model, on one set of axes.
#'
#' Both series are package output: the step function from `state$fit$kmfit`, the
#' smooth curve from the fitting package's `summary()` method. Returns NULL when
#' no cure model converged, and the caller then shows an empty state.
.qual_overlay_plot <- function(state, model, dark = FALSE) {
  km <- .qual_km_frame(state$fit$kmfit)
  if (is.null(km) || is.null(model) || is.na(model)) return(NULL)
  grid <- seq(0, max(km$time, na.rm = TRUE), length.out = 200)
  mc <- .qual_model_curve(state$fit$fits[[model]]$fit, grid)
  if (is.null(mc) || !nrow(mc)) return(NULL)

  censor <- if (!is.null(km$n.censor)) {
    km[km$n.censor > 0, c("time", "surv"), drop = FALSE]
  } else {
    NULL
  }
  facts <- ca_tail_facts(state$prepared)

  # theme.R owns this figure so that the Quantitative overlay and this one are
  # the same picture: solid = data, long-dashed = model, same tail band.
  if (exists("ca_km_overlay_plot", mode = "function")) {
    return(ca_km_overlay_plot(
      km = km, censor = censor, overlay = mc,
      last_event_time = if (is.null(facts)) NA_real_ else facts$last_event,
      max_time = if (is.null(facts)) NA_real_ else facts$max_time,
      km_label = "Kaplan-Meier estimate",
      overlay_label = paste0("Fitted ", model),
      dark = dark
    ))
  }

  cols <- .qual_cols(dark)
  ggplot2::ggplot() +
    ggplot2::geom_step(data = km, ggplot2::aes(x = time, y = surv),
                       colour = cols$km, linewidth = 0.7) +
    ggplot2::geom_line(data = mc, ggplot2::aes(x = time, y = surv),
                       colour = cols$overlay, linewidth = 0.7, linetype = "42") +
    ggplot2::coord_cartesian(ylim = c(0, 1)) +
    ggplot2::labs(x = "Time", y = "Survival probability S(t)") +
    .qual_theme(dark)
}


# ---- the reading guide (contract §J.1, verbatim) ----------------------------

# Seven checks, each a tickable reading aid. Ticking records nothing: these
# inputs are namespaced `qread_*`, live only in this module, never touch
# `state`, and never feed a chip, a tally or a verdict.
.QUAL_READ_CHECKS <- list(
  list(
    q = "Does the curve flatten, and how high does it flatten?",
    body = list(
      "Follow the curve left to right and find the point where it stops stepping down and runs horizontally. The height of that flat run is your rough cure fraction — read it off the dotted ",
      "tail level",
      " line. A curve that is still descending at the right-hand edge has no plateau to interpret."
    ),
    dx = "Formal diagnostic: RECeUS pi_hat, which must exceed 0.025."
  ),
  list(
    q = "How much of the study is flat?",
    body = list(
      "Compare the shaded tail band with the whole x-axis. A flat stretch covering half the follow-up is a plateau; one year of flatness at the end of a twenty-year study is the curve running out of data, not the disease running out of events."
    ),
    dx = "Formal diagnostic: the qn statistic — it measures exactly this, as the share of events falling inside a window whose width is the length of the flat tail. Larger qn is better, and it is compared against a threshold that moves with sample size, not against 0.05."
  ),
  list(
    q = "What is the very last observation — an event or a censoring mark?",
    body = list(
      "Look at the extreme right-hand end. If the final mark is a censored subject (a tick), follow-up outlived the last event and there is something to test. If the final mark is an event (a step down), the study stopped while patients were still relapsing, and the question “is follow-up long enough” cannot be asked of this data at all."
    ),
    dx = "Formal diagnostic: the immune summary reports last_observation_censored directly. It also gates Maller-Zhou, qn and Shen — all three return “cannot be computed” when the last observation is an event."
  ),
  list(
    q = "How many subjects are still being watched out there?",
    body = list(
      "Read the risk table under the plot. A plateau held up by four hundred subjects still under observation is evidence. A plateau held up by six is a line drawn through almost nobody, and it will move if one of those six relapses."
    ),
    dx = "Formal diagnostic: none of the five tests reads the risk table — this is a judgement you make by eye, and it is the check that most often overturns a confident-looking plot."
  ),
  list(
    q = "How dense are the censoring marks along the flat part?",
    body = list(
      "Count the ticks in the shaded band; the label on the plot gives the number. Ticks packed along a flat stretch mean subjects were leaving the study, not surviving it. A flat curve produced by a handful of censored subjects is a censoring artifact, and no amount of flatness redeems it."
    ),
    dx = "Formal diagnostic: the immune summary's censoring proportion p_cens gives the study-wide figure; the plot label gives the tail-specific count."
  ),
  list(
    q = "How wide is the gap between the last event and the end of follow-up?",
    body = list(
      "This is the shaded band, and it is the single feature that matters most. It is the stretch of time in which the study kept watching and nothing happened — the evidence that the uncured had run out. Wide gap, strong evidence. Narrow gap, weak evidence. ",
      "Zero gap and there is no evidence at all",
      ": if the largest observed time is an event the band has no width, and Maller-Zhou, qn and Shen all return “cannot be computed” together."
    ),
    dx = "Formal diagnostic: all three follow-up tests key on this gap. Maller-Zhou and Shen are smaller is better (below alpha supports sufficient follow-up); qn is larger is better. Shen uses a narrower window than Maller-Zhou and is the stricter of the two by design."
  ),
  list(
    q = "How wide is the shaded confidence band out in the tail?",
    body = list(
      "A plateau drawn with a confidence band half the height of the plot is a plateau you cannot locate. If the band spans 0.26 to 0.45, the data are consistent with a cure fraction of a quarter or of a half, and reporting a point estimate hides that."
    ),
    dx = "Formal diagnostic: no test scores the band width. The closest quantitative statement is RECeUS r_hat — the share of uncured subjects still censored at the end of follow-up — which must be below 0.05."
  )
)

#' Render one reading-guide item: a checkbox the user controls, the plain
#' language question, and the name of the formal diagnostic covering the same
#' feature. Bodies with three elements have their middle element emphasised,
#' which is where the contract copy carries bold.
.qual_read_item <- function(ns, i, item) {
  body <- if (length(item$body) == 3L) {
    htmltools::tagList(item$body[[1]], htmltools::tags$strong(item$body[[2]]),
                       item$body[[3]])
  } else {
    htmltools::tagList(item$body[[1]])
  }
  htmltools::div(
    class = "ca-read__item",
    checkboxInput(
      inputId = ns(paste0("qread_", i)),
      label = htmltools::tags$strong(paste0(i, ". ", item$q)),
      value = FALSE,
      width = "100%"
    ),
    htmltools::tags$p(body),
    htmltools::tags$p(class = "ca-lede", htmltools::tags$em(item$dx))
  )
}


# ---- worked readings (contract §J.3, §J.4, §J.5, verbatim) ------------------

#' The worked reading for one curated dataset.
#'
#' Defined here because it is a reading aid attached to the curve; also called
#' by mod_conclusion.R (the disagreement illustrations) and mod_docs.R (the
#' "Worked readings" accordion). All three files have the same owner.
#' `key` is one of "nwtco", "gbsg", "colon"; `parts` selects which labelled
#' paragraphs to render.
.qual_worked_reading <- function(key, parts = c("see", "numbers", "extra")) {
  p <- function(...) htmltools::tags$p(...)
  b <- function(x) htmltools::tags$strong(x)

  see <- switch(
    key,
    nwtco = p(b("What you should see."), " The curve drops steeply through the first two years, then levels off around 0.78 and stays there for the rest of the plot. The shaded follow-up tail is enormous: the last event lands at year 7.4 and the study kept watching until year 17, so ", b("56% of the total follow-up contains no events at all"), ", with 479 censored subjects in it. The risk table still reads 436 at year 8 and 197 at year 12 — this plateau is held up by hundreds of people, not a handful. The confidence band is a thin ribbon out there, roughly 0.76 to 0.81."),
    gbsg = p(b("What you should see."), " The curve descends steadily for six years and never really settles; the flat run at the right is short and arrives only at the very end. The shaded tail is thin — the last event is at year 6.7, follow-up ends at year 7.3, so the gap is ", b("7.6% of the study"), ", and it contains just ", b("8 censored subjects"), ". The risk table has already fallen to 36 by year 6 and reaches 0 by year 8. The confidence band out in the tail spans roughly 0.26 to 0.45, wide enough that the data are consistent with a cure fraction of a quarter or of a half."),
    colon = p(b("What you should see."), " A genuine-looking plateau around 0.60 from about year 5.7 onward, with a substantial shaded tail — the last event is at year 5.7, follow-up runs to year 9.1, so ", b("37% of the study contains no events"), ", holding 142 censored subjects. That is a real flat stretch supported by real numbers at risk, and it looks much more like the nwtco picture than the gbsg one. The confidence band is moderate, roughly 0.55 to 0.66."),
    NULL
  )

  numbers <- switch(
    key,
    nwtco = p(b("How that squares with the numbers."), " Everything agrees. Maller-Zhou is 1.04e-140, far below 0.05, and qn is 0.2051 against its sample-size threshold of 0.0021 — the same verdict from the same arithmetic, stated two ways. Shen is 0.0496, which passes, but only just: Shen uses a narrower late-time window than Maller-Zhou and is the stricter of the two, and even on the best dataset we have it sits within 0.0004 of its cutoff. Worth noticing rather than worrying about. RECeUS passes both conditions comfortably — pi_hat 0.7823 against a floor of 0.025, r_hat 0.0041 against a ceiling of 0.05, meaning about 0.4% of uncured subjects were still censored when follow-up ended. The tail level you read off the plot, 0.7843, is within 0.0021 of pi_hat. ", b("Verdict: cure model appropriate"), " — subject to step 1, which is still yours."),
    gbsg = p(b("How that squares with the numbers."), " This is the dataset that justifies the whole tool. AIC picks a cure model, and an analyst who stops there reports a cure fraction near 0.32 and is wrong. Maller-Zhou is 0.0495 and qn is 0.0044 against a threshold of 0.0044 — both nominally say follow-up is sufficient, both by a margin of essentially nothing: ", b("three events out of 686 fall in the window, and one fewer would flip both"), ". Shen, which uses a narrower window precisely because Maller-Zhou over-declares sufficiency, returns 0.3676 — nowhere near its 0.05 cutoff. RECeUS agrees with Shen: pi_hat 0.3238 clears its floor, so a cured group plausibly exists, but r_hat is 0.3080, meaning ", b("about 31% of uncured subjects were still censored when the study ended"), ". ", b("Verdict: follow-up insufficient for cure modeling."), ""),
    colon = p(b("How that squares with the numbers."), " The follow-up statistics are emphatic: Maller-Zhou 5.25e-13, qn 0.0888 against a threshold of 0.0098, Shen 0.0065 — and unlike gbsg, Shen agrees rather than dissenting. pi_hat is 0.5736, a clear cured group, and the tail level you read off the plot, 0.599, is close to it. ", b("Then r_hat comes in at 0.0640, just above the 0.05 ceiling — and the verdict is “follow-up insufficient”, the same headline as gbsg, reached from a completely different distance."), ""),
    NULL
  )

  extra <- switch(
    key,
    gbsg = p(b("What to do when they disagree, as they do here."), " Do not count chips and take the majority — they are not votes, and Maller-Zhou and qn are the same statistic presented two ways, so they always agree with each other and are never independent confirmation. Instead: (i) check how close each statistic is to its threshold, because one sitting 0.0005 from its cutoff is not making a claim in either direction; (ii) prefer the stricter test when the pattern is the known one — Shen exists to catch Maller-Zhou's over-declaration, so Maller-Zhou passing while Shen fails is Shen working as designed, not a contradiction; (iii) weigh r_hat, which asks the identifiability question most directly; and (iv) look back at the picture, where a 7.6% tail containing 8 subjects was never going to carry the claim. A better AIC fit is not evidence that a cure model is identifiable. AIC asks how well a model describes the data you have; identifiability asks whether the data contain enough follow-up to pin the cure fraction down. Different questions, and only the second one is being decided here."),
    colon = p(b("What to make of that."), " gbsg fails with r_hat of 0.31; this fails with 0.064. Those are not the same finding and should not prompt the same response. 0.05 is a convention, in the same family as the 0.05 in Maller-Zhou and Shen and the 0.025 floor on pi_hat — a line drawn by people, not a property of nature, and a dataset landing 0.014 on the wrong side of it is telling you the answer is genuinely uncertain, not that it is no. The honest reading is “close, and worth discussing with a statistician”, and the sensible next steps are a sensitivity analysis and the alternatives listed below rather than either fitting the cure model anyway or abandoning it."),
    NULL
  )

  # FIXPASS: the nwtco paragraph said the tail level is "within 0.002 of
  # pi_hat", which is false by a hair — the package returns 1 - p_hat =
  # 0.784324 and pi_hat = 0.782266, a gap of 0.002058. The prose now quotes
  # 0.7843 and "within 0.0021", both exact. The same sentence exists a second
  # time in helpers.R (CA_COPY_READING_NWTCO_HTML) and was corrected there too.
  #
  # [SIGN-OFF: G] (a) gbsg: qn passes, contradicting the published section 11
  # table; (b) "prefer the stricter test" as guidance on weighing disagreement;
  # (c) "close, and worth discussing with a statistician" for a near-miss r_hat.

  out <- list()
  if ("see" %in% parts)     out <- c(out, list(see))
  if ("numbers" %in% parts) out <- c(out, list(numbers))
  if ("extra" %in% parts)   out <- c(out, list(extra))
  out <- Filter(Negate(is.null), out)
  if (!length(out)) return(NULL)
  do.call(htmltools::tagList, out)
}

#' Display title for a worked reading.
.qual_worked_title <- function(key) {
  switch(
    key,
    nwtco = "Worked reading — nwtco, high risk: everything agrees",
    gbsg  = "Worked reading — gbsg: the disagreement case",
    colon = "Worked reading — colon, Lev+5FU: the borderline case",
    "Worked reading"
  )
}


# ---- the plateau-is-not-proof callout (contract §J.2, verbatim) -------------

.qual_plateau_callout <- function() {
  ca_note(
    "warning",
    "⚠ A plateau is not proof",
    htmltools::tagList(
      htmltools::tags$p(htmltools::tags$strong(
        "A Kaplan-Meier curve goes flat for two completely different reasons, and they look identical on the plot."
      )),
      htmltools::tags$p(
        "The honest one: the uncured patients have all had their events, the people left are cured, and the curve has nowhere further to fall."
      ),
      htmltools::tags$p(
        "The other one: there is nobody left to watch. The Kaplan-Meier estimator only steps down when someone who is still under observation has an event. Once subjects have dropped out, been lost to follow-up, or hit the administrative end of the study, the curve ",
        htmltools::tags$strong("cannot"),
        " step down — it is flat by construction, whatever is happening to those patients in reality. Heavy censoring alone manufactures a convincing plateau in data with a true cure fraction of exactly zero."
      ),
      htmltools::tags$p(
        htmltools::tags$strong("You cannot tell the two apart by looking."),
        " That is not a failure of your eye; the two situations produce the same picture, and the information that would separate them is not in the plot. It is why this app exists, and why the visual check is step 2 of three rather than the whole assessment."
      ),
      htmltools::tags$p(
        "What the diagnostics add is the question you cannot ask a picture: ",
        htmltools::tags$em("after the last event, did the study keep watching anybody, for how long, and how many?"),
        " Read the shaded tail band and the risk table alongside the shape, and treat the shape alone as a hypothesis rather than a finding."
      )
    )
  )
  # [SIGN-OFF: G] "true cure fraction of exactly zero" alludes to simulated
  # scenario D (true cure fraction 0.00, dropout 0.45, r_hat 0.9973). Confirm
  # whether to name it.
}


# =============================================================================
# UI
# =============================================================================

#' Qualitative tab UI: visual assessment (step 2) and expert judgment (step 1).
mod_qualitative_ui <- function(id) {
  ns <- NS(id)

  htmltools::tagList(

    htmltools::div(
      class = "ca-section",
      htmltools::h2(class = "ca-section__title", "Step 2 — Visual assessment"),
      htmltools::p(
        class = "ca-lede",
        "Look at the curve before you read any number. This step is a visual aid, not a test: nothing on this tab is a pass or a fail, and nothing you tick here changes a verdict."
      ),
      uiOutput(ns("status_msg"))
    ),

    htmltools::div(class = "ca-section", .qual_plateau_callout()),

    htmltools::div(
      class = "ca-section",
      ca_card(
        title = "Kaplan-Meier curve with the follow-up tail marked",
        lede = "The shaded band runs from the last event to the end of follow-up. The dotted line is the level the curve settles at. The table underneath is the number of subjects still under observation.",
        body = htmltools::tagList(
          htmltools::div(class = "ca-plot",
                         plotOutput(ns("km_main"), height = "560px")),
          uiOutput(ns("km_facts")),
          uiOutput(ns("visual_chip")),
          checkboxInput(
            ns("visual_ack"),
            "I have looked at the curve, the shaded tail band and the risk table.",
            value = FALSE
          ),
          htmltools::p(
            class = "ca-lede",
            "Ticking this records that you looked. It is presentational and changes no chip and no verdict."
          )
        ),
        foot = ca_provenance("cure.appropriateness() -> $tests$immune$last_observation_censored")
      )
    ),

    htmltools::div(
      class = "ca-section",
      ca_note(
        "interpret",
        "How to read this curve",
        htmltools::tagList(
          htmltools::tags$p(
            "You are looking for one thing: ",
            htmltools::tags$strong("does this dataset support a cure model?"),
            " A cure model says some patients never have the event, so the curve should stop falling and stay up. These seven checks tell you whether what you are seeing is that, or something that only looks like it. Work down the list."
          ),
          htmltools::div(
            class = "ca-read",
            lapply(seq_along(.QUAL_READ_CHECKS), function(i) {
              .qual_read_item(ns, i, .QUAL_READ_CHECKS[[i]])
            })
          ),
          uiOutput(ns("read_progress")),
          htmltools::tags$p(
            class = "ca-key",
            htmltools::tags$strong("The rule is a conjunction, not a score."),
            " Checks 1 and 7 are about whether a cure fraction exists; 2, 3, 5 and 6 are about whether follow-up was long enough to see it. A cure model needs both, plus a clinical reason to expect cure in the first place. Any one of them failing is enough to stop."
          )
        )
      )
    ),

    htmltools::div(class = "ca-section", uiOutput(ns("worked"))),

    htmltools::div(
      class = "ca-section",
      ca_card(
        title = "The curve beside the best-fitting cure model",
        lede = "The step function is the Kaplan-Meier estimate; the smooth curve is the cure model with the lowest AIC, drawn by the fitting package's own summary method. A close fit is not evidence that a cure model is identifiable — that is what step 3 decides.",
        body = htmltools::tagList(
          htmltools::div(class = "ca-plot ca-plot--sm",
                         plotOutput(ns("km_overlay"), height = "360px")),
          uiOutput(ns("overlay_msg"))
        ),
        foot = ca_provenance("model.fitting() -> $fits[[model]]$fit")
      )
    ),

    htmltools::div(
      class = "ca-section",
      htmltools::h2(class = "ca-section__title", "Step 1 — Expert judgment"),
      ca_card(
        title = "① Expert judgment",
        chip = NULL,
        lede = "Software cannot judge clinical plausibility. This step is a conversation with a clinician.",
        body = htmltools::tagList(
          htmltools::tags$p(
            "Is there a clinical reason to expect that some patients in this population are cured? This app will never answer that for you, and it will never tick the box below on your behalf."
          ),
          checkboxInput(
            ns("expert_ok"),
            "I have confirmed with subject-matter knowledge that cure is biologically plausible for this population and endpoint.",
            value = FALSE
          ),
          uiOutput(ns("expert_chip")),
          textAreaInput(
            ns("expert_note"),
            "Optional note — who you asked, and what they said",
            value = "", rows = 3, width = "100%"
          ),
          htmltools::tags$p(
            class = "ca-lede",
            "The note travels to the Conclusion tab. Changing the dataset clears both the tick and the note, because a clinician confirmed plausibility for one population, not for every population."
          )
        )
      )
    ),

    htmltools::div(
      class = "ca-section",
      actionButton(ns("to_data"), "Go to Data →"),
      actionButton(ns("to_quant"), "Go to Quantitative →")
    )
  )
}


# =============================================================================
# SERVER
# =============================================================================

#' Qualitative tab server. Writes exactly three state fields:
#' `expert_confirmed`, `expert_note` and `visual_ack`. Never sets
#' `expert_confirmed` to TRUE on its own — only `input$expert_ok` can.
mod_qualitative_server <- function(id, state, go_to) {
  moduleServer(id, function(input, output, session) {

    # ---- the three state writes (contract §C.1) -----------------------------

    observeEvent(input$expert_ok, {
      state$expert_confirmed <- isTRUE(input$expert_ok)
    }, ignoreInit = TRUE)

    observeEvent(input$expert_note, {
      state$expert_note <- if (is.null(input$expert_note)) "" else input$expert_note
    }, ignoreInit = TRUE)

    observeEvent(input$visual_ack, {
      state$visual_ack <- isTRUE(input$visual_ack)
    }, ignoreInit = TRUE)

    # A dataset change resets `expert_confirmed` and `expert_note` in mod_data.R.
    # Mirror that back into the widgets, guarding against a write loop by only
    # updating when the widget disagrees with the state.
    observeEvent(state$expert_confirmed, {
      if (!identical(isTRUE(input$expert_ok), isTRUE(state$expert_confirmed))) {
        updateCheckboxInput(session, "expert_ok",
                            value = isTRUE(state$expert_confirmed))
      }
    }, ignoreInit = TRUE)

    observeEvent(state$expert_note, {
      cur <- if (is.null(input$expert_note)) "" else input$expert_note
      if (!identical(cur, state$expert_note)) {
        updateTextAreaInput(session, "expert_note", value = state$expert_note)
      }
    }, ignoreInit = TRUE)

    # ---- navigation ---------------------------------------------------------

    # Empty states carry their own buttons; they get their own ids so that no
    # two controls in the tab ever share a DOM id.
    ca_on_click(input, "to_data", function() go_to("data"))
    ca_on_click(input, "to_quant", function() go_to("quant"))
    ca_on_click(input, "to_data_empty", function() go_to("data"))
    ca_on_click(input, "to_quant_empty", function() go_to("quant"))
    ca_on_click(input, "to_data_km", function() go_to("data"))
    ca_on_click(input, "to_data_overlay", function() go_to("data"))

    # ---- empty and status states (contract §J.10, Qualitative) --------------

    output$status_msg <- renderUI({
      if (is.null(state$prepared)) {
        return(ca_empty(
          "Prepare a dataset on the Data step first — there is no curve to look at yet.",
          action_id = session$ns("to_data_empty"), action_label = "Go to Data →"
        ))
      }
      if (is.null(state$fit) || is.null(state$fit$kmplot)) {
        return(ca_empty(
          "The Kaplan-Meier plot is missing. Press Prepare data again on the Data step.",
          action_id = session$ns("to_data_km"), action_label = "Go to Data →"
        ))
      }
      if (is.null(state$assess)) {
        return(ca_empty(
          "The curve is below and the reading guide works now. The plateau check needs the assessment — run it on the Quantitative step.",
          action_id = session$ns("to_quant_empty"), action_label = "Go to Quantitative →"
        ))
      }
      NULL
    })

    # ---- the annotated KM plot ---------------------------------------------

    output$km_main <- renderPlot({
      req(state$prepared)
      sp <- state$fit$kmplot
      req(!is.null(sp))
      dark <- isTRUE(state$dark)
      ann <- try(
        .qual_annotate_km(sp, state$prepared, .qual_tail_level(state), dark),
        silent = TRUE
      )
      # A failed annotation must never cost the user the curve itself.
      suppressMessages(print(if (inherits(ann, "try-error")) sp else ann))
    }, res = 108, bg = "transparent")

    # The six tail-window descriptives under the plot. All of these are
    # ca_tail_facts() output (contract §F.2) — app-side counts, not statistics.
    output$km_facts <- renderUI({
      req(state$prepared)
      f <- ca_tail_facts(state$prepared)

      # FIXPASS (finding 1.3): the "tail level S" number has two possible
      # sources and the app used to show neither. This provenance line names
      # the one that actually produced the value on screen, and it is built
      # from the same call that produced it, so the two cannot disagree.
      lvl <- .qual_tail_level_info(state)
      prov <- if (is.na(lvl$source)) NULL else ca_provenance(lvl$source)

      if (is.null(f)) {
        return(htmltools::tagList(
          htmltools::tags$p(
            class = "ca-lede",
            "This dataset has no events, so there is no follow-up tail to measure."
          ),
          prov
        ))
      }
      if (isTRUE(f$zero_width)) {
        return(htmltools::tagList(
          ca_note(
            "warning",
            "There is no follow-up tail",
            htmltools::tagList(
              htmltools::tags$p(
                "The largest observed time is an event, so the band has no width. Maller-Zhou, qn and Shen all return “cannot be computed” on this dataset."
              ),
              htmltools::tags$p(
                "This is a property of the data, not an error. All three follow-up tests need follow-up to extend past the last event."
              )
            )
          ),
          prov
        ))
      }
      htmltools::tagList(
        htmltools::div(
          class = "ca-statrow",
          ca_kv("Last event at", ca_num(f$last_event, 3)),
          ca_kv("Follow-up ends", ca_num(f$max_time, 3)),
          ca_kv("Gap", ca_num(f$gap, 3), "last event to end of follow-up"),
          ca_kv("Gap as a share", .qual_fmt_pct(f$gap_pct), "of the whole x-axis"),
          ca_kv("Censored in the band", format(f$n_cens_after)),
          ca_kv("Tail level S", ca_num(lvl$value, 4),
                "the KM level, not RECeUS pi_hat")
        ),
        prov
      )
    })

    # ---- the visual-assessment chip ----------------------------------------
    # Driven only by the package field. Labelled a visual aid, never a test,
    # and never a pass/fail variant (contract §L.12).
    output$visual_chip <- renderUI({
      req(state$prepared)
      if (!ca_has_tests(state) || is.null(state$assess$tests$immune)) {
        return(htmltools::div(
          ca_chip("neutral", "Waiting on the assessment"),
          htmltools::tags$p(class = "ca-lede",
                            "This is a visual aid, not a test.")
        ))
      }
      im <- state$assess$tests$immune
      censored <- isTRUE(im$last_observation_censored)
      label <- if (censored) {
        "Plateau possible: the last observation is censored"
      } else {
        "No clear plateau: the last observation is an event"
      }
      htmltools::div(
        ca_chip("neutral", label),
        htmltools::tags$p(class = "ca-lede",
                          "This is a visual aid, not a test."),
        htmltools::tags$blockquote(htmltools::tags$p(im$interpretation))
      )
    })

    # ---- reading-guide progress (a reading aid; writes nothing) -------------

    output$read_progress <- renderUI({
      n <- sum(vapply(
        seq_along(.QUAL_READ_CHECKS),
        function(i) isTRUE(input[[paste0("qread_", i)]]),
        logical(1)
      ))
      htmltools::tags$p(
        class = "ca-lede",
        paste0(n, " of ", length(.QUAL_READ_CHECKS), " checks ticked."),
        " Ticking is a place-keeper for your own reading. It feeds no chip, no tally and no verdict."
      )
    })

    # ---- the worked reading for the loaded dataset -------------------------

    output$worked <- renderUI({
      key <- .qual_dataset_key(state)
      if (is.na(key)) {
        if (is.null(state$prepared)) return(NULL)
        return(ca_card(
          title = "Worked readings",
          lede = "There is no worked reading for this dataset.",
          body = htmltools::tags$p(
            "The three curated examples — nwtco (high risk), gbsg and colon (Lev+5FU) — each have a worked reading that walks the curve and the numbers together. They are on the Documentation tab under “Worked readings”."
          )
        ))
      }
      ca_card(
        title = .qual_worked_title(key),
        lede = "What an experienced reader sees on this exact curve, and how it squares with the diagnostics.",
        body = .qual_worked_reading(key)
      )
    })

    # ---- KM beside the best-fitting cure model ------------------------------

    # FIXPASS (finding 1.1): both call sites now take `state`, not `state$fit`,
    # so that the package's published selection can be read when it exists.
    output$km_overlay <- renderPlot({
      req(state$fit)
      sel <- .qual_best_cure_model(state)
      req(!is.na(sel$model))
      p <- .qual_overlay_plot(state, sel$model, isTRUE(state$dark))
      req(!is.null(p))
      suppressMessages(print(p))
    }, res = 108, bg = "transparent")

    output$overlay_msg <- renderUI({
      if (is.null(state$fit)) {
        return(ca_empty(
          "Prepare a dataset on the Data step first — there is nothing to fit yet.",
          action_id = session$ns("to_data_overlay"), action_label = "Go to Data →"
        ))
      }
      sel <- .qual_best_cure_model(state)
      if (is.na(sel$model)) {
        return(ca_empty("No cure model could be fitted to this dataset, so there is no curve to draw beside the Kaplan-Meier estimate."))
      }
      # FIXPASS (finding 1.1): the claim on screen now matches where the name
      # came from. "the cure model with the lowest AIC in the candidate set" is
      # a package decision and is only said when the package field supplied it.
      if (identical(sel$from, "package")) {
        htmltools::tagList(
          htmltools::tags$p(
            class = "ca-lede",
            paste0("Fitted model: ", sel$model,
                   ", the cure model the assessment selected — the lowest-AIC cure model in the candidate set, and the distribution RECeUS was run under.")
          ),
          ca_provenance("cure.appropriateness() -> $selected_receus_model")
        )
      } else {
        htmltools::tagList(
          htmltools::tags$p(
            class = "ca-lede",
            paste0("Fitted model: ", sel$model,
                   ", lowest AIC in the current candidate set (assessment not yet run).")
          ),
          ca_provenance("model.fitting() -> $fits[[m]]$AIC, compared by this app")
        )
      }
    })

    # ---- the expert-judgment chip (never empty, usable at any status) ------

    output$expert_chip <- renderUI({
      if (isTRUE(state$expert_confirmed)) {
        htmltools::div(
          ca_chip("pass", "Confirmed by user"),
          htmltools::tags$p(
            class = "ca-lede",
            "Software cannot judge clinical plausibility. This step is a conversation with a clinician."
          )
        )
      } else {
        htmltools::div(
          ca_chip("neutral", "Waiting on you"),
          htmltools::tags$p(
            class = "ca-lede",
            "Software cannot judge clinical plausibility. This step is a conversation with a clinician."
          )
        )
      }
    })

    invisible(NULL)
  })
}
