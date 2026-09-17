# =============================================================================
# mod_qualitative.R — the Qualitative tab (nav id "qual"), owner: builder-auto
#
# The visual assessment step, and nothing else: the package's own Kaplan-Meier
# curve with its risk table, the shaded follow-up band behind it, one neutral
# plateau chip, and two short bullet lists.
#
# REVISION v3.0 (V2_CONTRACT §B): the curve and the visual check appear BY
# THEMSELVES off state$prepared. There is no button anywhere on this tab that
# starts anything — the two nav buttons at the foot are navigation — and no
# sentence on it names a Run or a Prepare control, because neither exists any
# more. Nothing here calls a package function, so nothing here needs a
# debounce: mod_data.R debounces the mapping tuple upstream (§B.1 reactive 1)
# and this tab simply follows state$prepared and state$fit.
#
# The lead asked for plain bullets and got numbered plates, so the two lists
# below are now a plain <ul>. .ca-read (the counter-plate list) is no longer
# used by any file.
#
# Expert judgment moved to mod_expert.R this pass (REVISION_CONTRACT §E.3 #19).
# The overlay plot, the seven-check reading guide, the hard-coded worked
# readings, the plateau-is-not-proof callout and the six-cell stat row are all
# deleted (§E.3 #17-#27).
#
# Package call sites: NONE. Every number on this tab is either an app-side
# descriptive permitted by BUILD_CONTRACT §F or a single package field read
# through a named helper.
#
# FIELD PROVENANCE (kept here as code comments, never on screen — §G2):
#   state$fit$kmplot                            survminer::ggsurvplot(), built in mod_data.R
#   state$prepared                              prepare.surv.data() output
#   $tests$immune$last_observation_censored      read via ca_last_obs_censored() (helpers N.2)
#   $tests$immune$p_hat                          read via ca_tail_level() as 1 - p_hat (helpers F.3)
#
# [SIGN-OFF: G] (REVISION_CONTRACT §F) — the two silent reads of the immune
# object, and the bullet wording "the curve settles near {level}" as a
# description of 1 - p_hat. That is the Kaplan-Meier level, NOT the RECeUS cure
# fraction pi_hat; on gbsg the two are 0.3428 and 0.3238. Nothing on this tab
# names the object, the method, an author, a threshold or a test.
# =============================================================================


# ---- private helpers --------------------------------------------------------

#' The shared ggplot2 theme, guarded.
#'
#' `theme_cure_assess()` is theme.R's. If it is not loaded the tab still draws,
#' on ggplot2's own minimal theme.
.qual_theme <- function(dark = FALSE) {
  if (exists("theme_cure_assess", mode = "function")) {
    th <- try(theme_cure_assess(dark), silent = TRUE)
    if (!inherits(th, "try-error")) return(th)
  }
  ggplot2::theme_minimal(base_size = 14)
}

#' Put the shaded follow-up band behind the package's own curve.
#'
#' One annotation layer set and no others (§E.3 #24): the last-event text
#' marker, the censored-in-band count and the dotted tail-level rule with its
#' "tail level S =" label are all deleted. `ca_style_survplot()` restyles both
#' the curve and the risk table and suppresses survminer's cosmetic "Ignoring
#' unknown labels" message; the risk table itself (`$table`) is left exactly as
#' the package built it, and printing the ggsurvplot draws both together.
#'
#' The band layers are prepended to `$layers` so the shading sits behind the
#' curve rather than washing over it.
.qual_annotate_km <- function(sp, prepared, dark = FALSE) {
  if (is.null(sp) || is.null(sp$plot)) return(sp)

  if (exists("ca_style_survplot", mode = "function")) {
    sp <- ca_style_survplot(sp, dark)
  } else {
    sp$plot <- sp$plot + .qual_theme(dark)
    if (!is.null(sp$table)) sp$table <- sp$table + .qual_theme(dark)
  }
  p <- sp$plot

  # ca_tail_facts() is an app-side descriptive on the prepared frame's own Y and
  # D columns (helpers F.2) — no package field, no statistic.
  facts <- ca_tail_facts(prepared)
  if (!is.null(facts) && isTRUE(is.finite(facts$last_event)) &&
      isTRUE(is.finite(facts$max_time)) && !isTRUE(facts$zero_width)) {
    # label = NULL: ca_followup_tail() documents NULL as "no label" and returns
    # the two band layers only, so the band is drawn and never named on the
    # curve. No edit to theme.R is needed for this.
    tail_layers <- ca_followup_tail(
      facts$last_event, facts$max_time, dark,
      min_time = 0, label = NULL
    )
    if (length(tail_layers)) {
      behind  <- tail_layers[seq_len(min(2L, length(tail_layers)))]
      infront <- if (length(tail_layers) > 2L) tail_layers[-seq_len(2L)] else list()
      p$layers <- c(behind, p$layers)
      for (lyr in infront) p <- p + lyr
    }
  }

  sp$plot <- p
  sp
}


# ---- the two bullet lists (REVISION_CONTRACT §G.4.1, §G.4.2) ----------------

# The generic list: five lines, pasted from FINAL_CONTRACT §G.3 (Q5) and not
# rewritten here. The wording is the standard vocabulary of the cure-model
# literature — plateau, cure fraction, at risk, censoring.
.QUAL_PLATEAU_BULLETS <- c(
  "The curve stops declining and plateaus.",
  "No events fall inside plateaus.",
  "Enough people are still at risk is an evidence for cure: check the table under the plot.",
  "Heavy censoring alone can flatten a curve, so a plateau does not necessarily indicate presence of a cure fraction."
)

#' The per-dataset bullets, generated from the loaded data.
#'
#' §G.4.2: between one and three of the four templates, filled from descriptive
#' quantities only. Never hard-coded per dataset and never a `switch()` on a
#' dataset key — the three hard-coded worked readings are deleted (§E.3 #22).
#' Rendered in the contract's own bullet order.
#'
#' @param state The shared `reactiveValues`.
#' @return character vector of one to three finished sentences, or `character(0)`
#'   when no dataset is prepared.
.qual_dataset_bullets <- function(state) {
  prepared <- state$prepared
  if (is.null(prepared)) return(character(0))

  facts <- ca_tail_facts(prepared)   # app-side descriptives, helpers F.2
  sm    <- ca_data_summary(prepared) # app-side descriptives, helpers F.1
  out   <- character(0)

  no_tail <- is.null(facts) || isTRUE(facts$zero_width)

  if (!no_tail) {
    # Bullet 1. {level} reads $tests$immune$p_hat via ca_tail_level() as
    # 1 - p_hat (helpers F.3); see REVISION_CONTRACT §F. Guarded by
    # ca_has_tests() so it is simply not emitted before an assessment has run —
    # it never renders the text NA.
    level <- if (ca_has_tests(state)) {
      ca_tail_level(state$assess$tests$immune)
    } else {
      NA_real_
    }
    if (length(level) == 1L && is.finite(level)) {
      out <- c(out, paste0(
        "The curve plateaus near ", ca_num(level, 2),
        " after ", ca_num(facts$last_event, 2),
        " and remains there to ", ca_num(facts$max_time, 2), "."
      ))
    }

    # Bullet 2. ca_tail_facts()$gap_pct and $n_cens_after.
    # ca_tail_facts() returns gap_pct ALREADY on the 0-100 scale
    # (100 * gap / max_time) while ca_pct() multiplies its argument by 100, so
    # the /100 below is what makes the rendered figure correct. See the report:
    # §G.4.2 writes this blank as `ca_pct(·, 0)` but writes bullet 3's as
    # `ca_pct($censored_pct/100, 0)`; both fields carry the same unit, so both
    # need the same division.
    out <- c(out, paste0(
      ca_pct(facts$gap_pct / 100, 0),
      " of the follow-up comes after the last event, with ",
      format(facts$n_cens_after),
      " people still at risk in it."
    ))
  }

  # Bullet 3. ca_data_summary()$events, $n, $censored_pct (also 0-100 scale).
  out <- c(out, paste0(
    format(sm$events), " of ", format(sm$n), " people had the event, and ",
    ca_pct(sm$censored_pct / 100, 0), " were censored."
  ))

  # Bullet 4. Emitted only when there is no follow-up tail at all, and then
  # bullets 1 and 2 are not emitted.
  if (no_tail) {
    out <- c(out, "The longest observed time is an event, so there is no plateau to read.")
  }

  out
}

#' Render a character vector as a plain bullet list.
#'
#' A plain `<ul>` with no class, so it takes the stylesheet's own `ul, ol` rule
#' (disc markers, 1.3em indent, one step of space between items). The numbered
#' `.ca-read` plates are gone: these are bullets, not a sequence of steps.
.qual_bullet_list <- function(items) {
  if (!length(items)) return(NULL)
  htmltools::tags$ul(
    lapply(items, function(x) htmltools::tags$li(x))
  )
}


# =============================================================================
# UI
# =============================================================================

#' Qualitative tab UI: the visual assessment, and nothing else.
mod_qualitative_ui <- function(id) {
  ns <- NS(id)

  htmltools::tagList(

    htmltools::div(
      class = "ca-section",
      htmltools::tags$h1(class = "ca-section__title", "Visual assessment"),
      # The poster's own flowchart wording for this step, verbatim.
      htmltools::p(class = "ca-lede",
                   "Does the survival curve plateau, with late events absent?"),
      uiOutput(ns("status_msg"))
    ),

    htmltools::div(
      class = "ca-section",
      ca_card(
        title = "Kaplan-Meier curve",
        lede = "The shaded band runs from the last event to the end of follow-up.",
        # FINAL_CONTRACT §G.3 (Q2-Q4): "This dataset" comes first and the
        # generic reading guide sits below it, collapsed inside ca_tech() — the
        # existing <details> component, so no new disclosure idiom and no new
        # CSS. The <summary> is the heading now and carries the question mark;
        # the old <h4> is gone.
        # FINAL_CONTRACT §E.3: height = "100%" inside .ca-plot--fluid, whose
        # aspect-ratio gives the container its height, so the plot is
        # re-rendered at the container's real size instead of 560 fixed pixels.
        body = htmltools::tagList(
          htmltools::div(class = "ca-plot ca-plot--fluid",
                         plotOutput(ns("km_main"), height = "100%")),
          uiOutput(ns("plateau_chip")),
          htmltools::tags$h4("This dataset"),
          uiOutput(ns("dataset_bullets")),
          ca_tech(body  = .qual_bullet_list(.QUAL_PLATEAU_BULLETS),
                  title = "How to spot a plateau?")
        )
      )
    ),

    htmltools::div(
      class = "ca-navrow",
      actionButton(ns("to_data"), "Data →"),
      actionButton(ns("to_quant"), "Quantitative →")
    )
  )
}


# =============================================================================
# SERVER
# =============================================================================

#' Qualitative tab server. Writes NO state field: `expert_confirmed` moved to
#' mod_expert.R and the old visual-acknowledgement flag is retired (§C.2).
mod_qualitative_server <- function(id, state, go_to) {
  moduleServer(id, function(input, output, session) {

    # ---- navigation ---------------------------------------------------------

    ca_on_click(input, "to_data", function() go_to("data"))
    ca_on_click(input, "to_quant", function() go_to("quant"))

    # ---- empty and status states (§G.9, Qualitative) ------------------------

    output$status_msg <- renderUI({
      if (is.null(state$prepared)) {
        # No action button: the nav row at the foot of this tab already
        # offers "Data →", and two identical buttons on one screen is the
        # clutter this pass is removing (C4).
        return(ca_empty("Load a dataset on the Data step first."))
      }
      if (is.null(state$fit) || is.null(state$fit$kmplot)) {
        return(ca_empty("The curve is not available for this dataset."))
      }
      # There is no third state. The assessment starts by itself and lands in
      # about a fifth of a second, so a "waiting for the assessment" line would
      # be a flicker; the chip and the first bullet simply appear when it does.
      NULL
    })

    # ---- the curve, the band and the risk table -----------------------------

    output$km_main <- renderPlot({
      req(state$prepared)
      sp <- state$fit$kmplot   # survminer::ggsurvplot(), built once in mod_data.R
      req(!is.null(sp))
      ann <- try(.qual_annotate_km(sp, state$prepared, isTRUE(state$dark)),
                 silent = TRUE)
      # A failed annotation must never cost the user the curve itself.
      suppressMessages(print(if (inherits(ann, "try-error")) sp else ann))
    }, res = 108, bg = "transparent",
       alt = "Kaplan-Meier survival curve for the prepared dataset, with the period after the last event shaded.")

    # ---- the plateau chip (§G.4) -------------------------------------------
    # reads $tests$immune$last_observation_censored via ca_last_obs_censored();
    # see REVISION_CONTRACT §F. A statement about the data: always the neutral
    # chip variant, never pass, fail, caution or void, and nothing is printed
    # beside it.
    output$plateau_chip <- renderUI({
      req(state$prepared)
      censored <- ca_last_obs_censored(state)
      # NA means the assessment has not landed yet (or ran without producing
      # diagnostics). Nothing is rendered in that case: the chip appears with
      # the result rather than standing in for it, and the old third label
      # pointed at a Run control that no longer exists. NOTE for builder-shell:
      # the doc comment on ca_last_obs_censored() in helpers.R still quotes
      # that retired label.
      label <- if (isTRUE(censored)) {
        "The longest observed time is censored, so a plateau is possible"
      } else if (identical(censored, FALSE)) {
        "The longest observed time is an event, so there is no plateau"
      } else {
        return(NULL)
      }
      ca_chip("neutral", label)
    })

    # ---- the per-dataset bullets -------------------------------------------

    output$dataset_bullets <- renderUI({
      req(state$prepared)
      .qual_bullet_list(.qual_dataset_bullets(state))
    })

    invisible(NULL)
  })
}
