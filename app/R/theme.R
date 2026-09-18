# =============================================================================
# cureAssessApp — app/R/theme.R                        owner: builder-css
#
# The R half of the visual system, and the only place a colour is written down
# in R. Five things live here and nothing else (BUILD_CONTRACT §A, §M):
#
#   1. ca_bs_theme()        the bs_theme() object app.R mounts
#   2. ca_tokens() / ca_plot_cols()   the R mirror of app.css's colour tokens
#   3. theme_cure_assess()  the ggplot2 theme every plot in the app wears
#   4. plot helpers         ca_followup_tail(), ca_level_line(), ca_step_ribbon(),
#                           ca_km_overlay_plot(), ca_style_survplot()
#   5. ca_icon()            inline SVG glyphs (bsicons/fontawesome are forbidden)
#
# NO component builder lives here — chips, cards, callouts, the rail and the
# banners are all helpers.R (§F). NO statistic is computed here: every function
# below takes numbers that already came out of a cureAssess object and draws
# them.
#
# The token values are duplicated in app/www/app.css on purpose: R draws the
# plots and the browser draws the page, and neither can read the other's
# variables. Edit both files or neither.
#
# Verified against R 4.6.1 / bslib 0.12.0 / ggplot2 4.0.3 / survminer 0.5.2.
# =============================================================================


# -----------------------------------------------------------------------------
# 0. FONTS — system stacks, deliberately.
#
# font_google() downloads font files when the theme is BUILT, i.e. at app start,
# on the demo machine, on whatever network the venue has. A cold cache plus no
# Wi-Fi is either a failed launch or a silent fallback to something unstyled, in
# front of the room. A system stack has no network step and no FOUT.
# -----------------------------------------------------------------------------
CA_SANS <- c("system-ui", "-apple-system", "BlinkMacSystemFont", "Segoe UI",
             "Roboto", "Helvetica Neue", "Arial", "sans-serif")
CA_SERIF <- c("Charter", "Bitstream Charter", "Sitka Text", "Cambria",
              "Iowan Old Style", "Palatino Linotype", "Georgia", "serif")
CA_MONO <- c("ui-monospace", "SFMono-Regular", "SF Mono", "Menlo",
             "Consolas", "Liberation Mono", "monospace")


# -----------------------------------------------------------------------------
# 1. THE bs_theme() CALL
# -----------------------------------------------------------------------------

#' The application's Bootstrap 5 theme.
#'
#' Mounted once, by `app.R`, as `page_fluid(theme = ca_bs_theme())`. The
#' light-mode values are set here so Bootstrap's own components start in the
#' palette; `app.css` re-states them as custom properties and adds the dark
#' ramp, because `bs_theme()` has no dark half.
#'
#' @return A `bs_theme` object (Bootstrap 5).
ca_bs_theme <- function() {
  bslib::bs_theme(
    version      = 5,
    base_font    = bslib::font_collection(CA_SANS),
    heading_font = bslib::font_collection(CA_SERIF),
    code_font    = bslib::font_collection(CA_MONO),

    bg = "#FBFCFC",   # card / chart surface
    fg = "#11191C",   # primary ink, 17.32:1 on bg

    primary   = "#0A5670",  # petrol 600 — white on it 8.15:1
    secondary = "#4E6068",  # slate    — white on it 6.57:1
    success   = "#1F7A3D",  # white on it 5.37:1
    info      = "#00739B",  # petrol 500 — white on it 5.35:1
    warning   = "#C2860E",  # ink on it 5.69:1
    danger    = "#B03A29",  # white on it 6.03:1

    "border-radius"        = "6px",
    "border-radius-sm"     = "3px",
    "border-radius-lg"     = "10px",
    "spacer"               = "1rem",
    "font-size-base"       = "1rem",
    "line-height-base"     = "1.55",
    "headings-font-weight" = "600",
    "body-bg"              = "#EEF2F3",     # page plane, one step off the card
    "body-color"           = "#11191C",
    "border-color"         = "#DBE2E4",
    "link-color"           = "#0A5670",
    "card-bg"              = "#FBFCFC",
    "card-border-color"    = "#DBE2E4",
    "card-cap-bg"          = "#F4F7F8",
    "focus-ring-width"     = "3px",
    "focus-ring-color"     = "rgba(0, 115, 155, 0.45)",
    "focus-ring-opacity"   = "1",
    "enable-shadows"       = FALSE,
    "enable-gradients"     = FALSE
  )
}

#' Alias for [ca_bs_theme()].
#'
#' Some drafts of the build brief call the theme `app_theme()`; the contract
#' name is `ca_bs_theme()`. Both are the same object, so neither spelling can
#' fail at mount time.
app_theme <- function() ca_bs_theme()


# -----------------------------------------------------------------------------
# 2. TOKENS — the R mirror of app.css
# -----------------------------------------------------------------------------

#' The colour tokens, for one mode.
#'
#' The R side of `app.css`'s `:root` block. `dark` comes from `state$dark`,
#' which mirrors `input$ca_mode == "dark"`; no function here reads the toggle
#' itself.
#'
#' @param dark logical(1). `TRUE` for the dark ramp.
#' @return A named list: surfaces, ink, rules, the three chart series, the
#'   confidence-band alpha, the censor ink and the follow-up tail trio.
ca_tokens <- function(dark = FALSE) {
  if (!isTRUE(dark)) {
    list(
      surface = "#FBFCFC", canvas = "#EEF2F3", sunk = "#F4F7F8", sunk2 = "#E7ECEE",
      ink = "#11191C", ink2 = "#414D52", ink3 = "#667378",
      rule = "#DBE2E4", rule2 = "#C3CDD0",
      series = c(petrol = "#00739B", ember = "#C2571F", claret = "#8D2157"),
      band_alpha = 0.12, censor = "#0A5670",
      tail_fill = "#E7ECEE", tail_rule = "#8A979B", tail_ink = "#414D52",
      level = "#4E6068",
      # V2_CONTRACT §F.4: the supported region of the cured-group plane is
      # tinted with the app's own pass pair, so the rectangle in the chart is
      # the same green as a pass chip on the page. Mirrors --ca-pass-bg and
      # --ca-pass-line in app.css §1 / §1b.
      pass_bg = "#E6F3E9", pass_line = "#B4D7BE"
    )
  } else {
    list(
      surface = "#161D20", canvas = "#0E1315", sunk = "#1D2528", sunk2 = "#26302F",
      ink = "#EAF0F1", ink2 = "#AEBCC0", ink3 = "#8A979B",
      rule = "#2A3438", rule2 = "#3D4A4F",
      series = c(petrol = "#2E9BC6", ember = "#D4732F", claret = "#D8428A"),
      band_alpha = 0.16, censor = "#8CCBE2",
      tail_fill = "#20292C", tail_rule = "#8A979B", tail_ink = "#AEBCC0",
      level = "#9DAEB4",
      pass_bg = "#14291B", pass_line = "#2C4A33"
    )
  }
}

#' The named colours the plot code uses, one call.
#'
#' Every plot in the app — the Data thumbnail, the Quantitative overlay, the
#' Qualitative annotated KM, the tau curve — takes its marks from this list, so
#' the same hue never means two things in two tabs. Use the names, never a hex
#' literal, in `mod_quantitative.R` and `mod_qualitative.R`.
#'
#' @param dark logical(1), from `state$dark`.
#' @return A named list:
#'   * `km`         Kaplan-Meier step curve (solid)
#'   * `band`       confidence-band fill, and `band_alpha` its alpha
#'   * `censor`     censoring ticks (shape 124), a darker step of the curve's hue
#'   * `overlay`    fitted-model curve; ALWAYS drawn long-dashed ("42")
#'   * `tail_fill` / `tail_rule` / `tail_ink`  the follow-up tail band
#'   * `level`      the dotted tail-level reference line
#'   * `series`     the three-hue chart ramp, for a facet or a third curve
ca_plot_cols <- function(dark = FALSE) {
  k <- ca_tokens(dark)
  list(
    km         = unname(k$series[["petrol"]]),
    band       = unname(k$series[["petrol"]]),
    band_alpha = k$band_alpha,
    censor     = k$censor,
    overlay    = unname(k$series[["ember"]]),
    overlay_linetype = "42",
    tail_fill  = k$tail_fill,
    tail_rule  = k$tail_rule,
    tail_ink   = k$tail_ink,
    level      = k$level,
    series     = unname(k$series),
    ink        = k$ink,
    ink2       = k$ink2,
    ink3       = k$ink3,
    surface    = k$surface,
    rule       = k$rule
  )
}

# The same two lists as plain constants, for a call site that has no `dark` to
# hand. CA_COL is the light ramp; CA_COL_DARK is the dark one. Prefer
# ca_plot_cols(dark) — these exist so a colour is never re-typed as a hex.
CA_COL      <- ca_plot_cols(FALSE)
CA_COL_DARK <- ca_plot_cols(TRUE)

#' The three chart series, in order: petrol, ember, claret.
#'
#' Cap: three. A fourth curve means a facet, not a fourth hue.
ca_series <- function(dark = FALSE) unname(ca_tokens(dark)$series)

#' `scale_colour_manual()` / `scale_fill_manual()` over the app's three series.
ca_scale_colour_cure <- function(dark = FALSE, ...) {
  ggplot2::scale_colour_manual(values = ca_series(dark), ...)
}
ca_scale_fill_cure <- function(dark = FALSE, ...) {
  ggplot2::scale_fill_manual(values = ca_series(dark), ...)
}


# -----------------------------------------------------------------------------
# 3. THE ggplot2 THEME
# -----------------------------------------------------------------------------

#' ggplot2 defaults for un-coloured geoms, on ggplot2 >= 3.6.
#'
#' `element_geom()` lets a theme set the ink, paper and accent that a geom
#' falls back to, so a layer drawn without an explicit colour still lands
#' inside the palette instead of reverting to black. Returns `NULL` on an older
#' ggplot2, where `theme(geom = )` is not a valid element.
.ca_geom_element <- function(k) {
  if (!("element_geom" %in% getNamespaceExports("ggplot2"))) return(NULL)
  ggplot2::element_geom(ink = k$ink, paper = k$surface,
                        accent = unname(k$series[["petrol"]]))
}

#' The app's ggplot2 theme.
#'
#' Horizontal hairlines only: survival probability is read off the y-axis, so y
#' gets gridlines and x gets ticks and a baseline. Solid, never dashed — a
#' dashed gridline competes with the dashed fitted overlay, which is the one
#' dash in the figure that carries meaning.
#'
#' @param dark logical(1), from `state$dark`.
#' @param base_size base type size in points.
#' @param base_family device font family. Leave it at `"sans"`: the graphics
#'   device renders the plot, not the browser, and it cannot see `system-ui` or
#'   Charter. Neither showtext nor thematic is installed. Do not try to make
#'   plot text match the UI face.
#' @return A complete `ggplot2` theme.
theme_cure_assess <- function(dark = FALSE, base_size = 14, base_family = "sans") {
  `%+replace%` <- ggplot2::`%+replace%`
  k <- ca_tokens(dark)
  half <- base_size / 2

  th <- ggplot2::theme_minimal(base_size = base_size, base_family = base_family) %+replace%
    ggplot2::theme(
      plot.background    = ggplot2::element_rect(fill = k$surface, colour = NA),
      panel.background   = ggplot2::element_rect(fill = k$surface, colour = NA),
      panel.border       = ggplot2::element_blank(),

      panel.grid.major.y = ggplot2::element_line(colour = k$rule, linewidth = 0.3),
      panel.grid.major.x = ggplot2::element_blank(),
      panel.grid.minor   = ggplot2::element_blank(),
      axis.line.x        = ggplot2::element_line(colour = k$rule2, linewidth = 0.3),
      axis.ticks.x       = ggplot2::element_line(colour = k$rule2, linewidth = 0.3),
      axis.ticks.y       = ggplot2::element_blank(),
      axis.ticks.length  = grid::unit(3, "pt"),

      axis.text  = ggplot2::element_text(colour = k$ink3, size = base_size * 0.86),
      axis.title = ggplot2::element_text(colour = k$ink2, size = base_size * 0.93),
      axis.title.x = ggplot2::element_text(margin = ggplot2::margin(t = half)),
      axis.title.y = ggplot2::element_text(angle = 90, margin = ggplot2::margin(r = half)),

      plot.title = ggplot2::element_text(colour = k$ink, size = base_size * 1.22,
                                         face = "bold", hjust = 0,
                                         margin = ggplot2::margin(b = half * 0.6)),
      plot.subtitle = ggplot2::element_text(colour = k$ink2, size = base_size * 0.95,
                                            hjust = 0, margin = ggplot2::margin(b = half)),
      plot.caption = ggplot2::element_text(colour = k$ink3, size = base_size * 0.80,
                                           hjust = 0, margin = ggplot2::margin(t = half)),
      plot.title.position   = "plot",
      plot.caption.position = "plot",

      legend.position      = "top",
      legend.justification = "left",
      legend.title         = ggplot2::element_blank(),
      legend.text          = ggplot2::element_text(colour = k$ink2, size = base_size * 0.9),
      legend.key           = ggplot2::element_rect(fill = k$surface, colour = NA),
      legend.background    = ggplot2::element_rect(fill = k$surface, colour = NA),
      legend.margin        = ggplot2::margin(b = half * 0.4),

      strip.text = ggplot2::element_text(colour = k$ink2, face = "bold",
                                         hjust = 0, size = base_size * 0.9),
      plot.margin = ggplot2::margin(half, half, half, half)
    )

  geom_el <- .ca_geom_element(k)
  if (!is.null(geom_el)) th <- th %+replace% ggplot2::theme(geom = geom_el)
  th
}

#' Alias for [theme_cure_assess()], for the `theme_cureassess()` spelling.
theme_cureassess <- function(dark = FALSE, base_size = 14, base_family = "sans") {
  theme_cure_assess(dark = dark, base_size = base_size, base_family = base_family)
}


# -----------------------------------------------------------------------------
# 4. PLOT HELPERS
#
# Colour assignments for the KM figure, fixed for the whole app:
#
#   KM step curve ...... ca_plot_cols()$km, linewidth 0.7, SOLID
#   Confidence band .... the same hue at 12% (light) / 16% (dark), no outline
#   Censoring marks .... $censor, shape 124 — the clinical vertical tick, a
#                        darker step of the curve's own hue so it reads as a
#                        mark ON the curve, not as a second series
#   Fitted overlay ..... $overlay, linewidth 0.7, LONG DASH ("42"). The dash is
#                        deliberate secondary encoding: solid = data, dashed =
#                        model. It survives greyscale, projectors and CVD.
#   Follow-up tail ..... $tail_fill wash plus a hairline at the last event time.
#                        NEUTRAL, never amber or red: the tail means
#                        "unresolved", not "bad", and colouring it as a warning
#                        would editorialise a descriptive fact.
# -----------------------------------------------------------------------------

#' The shaded follow-up tail: last event time to end of follow-up.
#'
#' Returns a list of annotation layers, addable to a ggplot with `+`. An empty
#' list when the band has no width — the same zero-gap case in which
#' Maller-Zhou, `qn` and Shen all return "cannot be computed".
#'
#' @param last_event_time `max(Y[D == 1])` on `state$prepared` (§F.1's
#'   `last_event_time`; a descriptive count, not a statistic).
#' @param max_time end of follow-up, `max(Y)`.
#' @param dark logical(1). @param min_time left edge of the axis.
#' @param label band label, or `NULL`/`""` for none.
ca_followup_tail <- function(last_event_time, max_time, dark = FALSE,
                             min_time = 0, label = "follow-up tail") {
  k <- ca_tokens(dark)
  if (!is.finite(last_event_time) || !is.finite(max_time) ||
      max_time <= last_event_time) return(list())

  out <- list(
    ggplot2::annotate("rect", xmin = last_event_time, xmax = max_time,
                      ymin = -Inf, ymax = Inf, fill = k$tail_fill, colour = NA),
    ggplot2::annotate("segment", x = last_event_time, xend = last_event_time,
                      y = -Inf, yend = Inf, colour = k$tail_rule, linewidth = 0.3)
  )
  # Measure before labelling: a band narrower than 12% of the axis cannot hold
  # the words, and a clipped label is worse than none.
  span <- (max_time - last_event_time) / (max_time - min_time)
  if (!is.null(label) && nzchar(label) && is.finite(span) && span >= 0.12) {
    out <- c(out, list(
      ggplot2::annotate("text", x = (last_event_time + max_time) / 2, y = 1,
                        label = label, hjust = 0.5, vjust = 1.7, size = 3.0,
                        colour = k$tail_ink, family = "sans")))
  }
  out
}

#' The dotted horizontal reference line at the KM tail level.
#'
#' The level is `1 - immune$p_hat` (§F.3, `ca_tail_level()`): the height of the
#' plateau as the Kaplan-Meier estimator draws it. It is NOT pi-hat, and the
#' label must never call it one.
#'
#' @param level numeric(1) in [0, 1], from `ca_tail_level()`.
#' @param dark logical(1). @param label text drawn at the right-hand end, or NULL.
#' @param x_label x position for the label; defaults to the panel's left edge.
ca_level_line <- function(level, dark = FALSE, label = NULL, x_label = -Inf) {
  k <- ca_tokens(dark)
  if (!is.finite(level)) return(list())
  out <- list(
    ggplot2::annotate("segment", x = -Inf, xend = Inf, y = level, yend = level,
                      colour = k$level, linewidth = 0.4, linetype = "22")
  )
  if (!is.null(label) && nzchar(label)) {
    out <- c(out, list(
      ggplot2::annotate("text", x = x_label, y = level, label = label,
                        hjust = -0.05, vjust = -0.6, size = 3.0,
                        colour = k$level, family = "sans")))
  }
  out
}

#' Rectangles for a step-function confidence band.
#'
#' Not `geom_ribbon()`: a Kaplan-Meier confidence band is a step function, and
#' a smoothed ribbon would draw diagonals the estimator never claims.
#'
#' @param km data.frame with `time`, `lower`, `upper`, any row order.
#' @return data.frame with `x1`, `x2`, `lower`, `upper`, ready for `geom_rect()`.
ca_step_ribbon <- function(km) {
  km <- km[order(km$time), , drop = FALSE]
  n <- nrow(km)
  if (n < 2) return(data.frame(x1 = numeric(0), x2 = numeric(0),
                               lower = numeric(0), upper = numeric(0)))
  data.frame(x1 = km$time[-n], x2 = km$time[-1],
             lower = km$lower[-n], upper = km$upper[-n])
}

#' The Kaplan-Meier figure, with an optional fitted overlay.
#'
#' Draws only. Every number arrives through an argument; nothing here estimates
#' anything.
#'
#' @param km data.frame with `time`, `surv`, optionally `lower`/`upper`. Read
#'   straight off `state$fit$kmfit`, a `survfit` object:
#'   `sf <- state$fit$kmfit;`
#'   `km <- data.frame(time = c(0, sf$time), surv = c(1, sf$surv),`
#'   `                 lower = c(1, sf$lower), upper = c(1, sf$upper),`
#'   `                 n.censor = c(0, sf$n.censor))`
#' @param censor rows of `km` where `n.censor > 0` (columns `time`, `surv`).
#' @param overlay data.frame(`time`, `surv`) from the fitting package's own
#'   summary method — `summary(state$fit$fits[[m]]$fit, type = "survival",`
#'   `t = grid)`. Never hand-code an S(t).
#' @param last_event_time,max_time the follow-up tail band's two edges.
#' @param dark logical(1), from `state$dark`.
#' @return A ggplot.
ca_km_overlay_plot <- function(km, censor = NULL, overlay = NULL,
                               last_event_time = NA_real_, max_time = NA_real_,
                               km_label = "Kaplan-Meier estimate",
                               overlay_label = "Fitted model",
                               dark = FALSE, conf_int = TRUE,
                               title = NULL, subtitle = NULL,
                               x_lab = "Time", y_lab = "Survival probability S(t)",
                               caption = NULL) {
  cols <- ca_plot_cols(dark)
  if (!is.finite(max_time)) max_time <- max(km$time, na.rm = TRUE)

  p <- ggplot2::ggplot() +
    ca_followup_tail(last_event_time, max_time, dark,
                     min_time = min(km$time, na.rm = TRUE))

  if (isTRUE(conf_int) && all(c("lower", "upper") %in% names(km))) {
    p <- p + ggplot2::geom_rect(
      data = ca_step_ribbon(km), colour = NA, fill = cols$band,
      alpha = cols$band_alpha,
      ggplot2::aes(xmin = .data$x1, xmax = .data$x2,
                   ymin = .data$lower, ymax = .data$upper))
  }

  p <- p + ggplot2::geom_step(
    data = km, direction = "hv", linewidth = 0.7, lineend = "round",
    ggplot2::aes(x = .data$time, y = .data$surv,
                 colour = km_label, linetype = km_label))

  if (!is.null(censor) && nrow(censor) > 0) {
    p <- p + ggplot2::geom_point(
      data = censor, shape = 124, size = 2.4, stroke = 0.9, colour = cols$censor,
      ggplot2::aes(x = .data$time, y = .data$surv))
  }

  if (!is.null(overlay) && nrow(overlay) > 0) {
    p <- p + ggplot2::geom_line(
      data = overlay, linewidth = 0.7, lineend = "round",
      ggplot2::aes(x = .data$time, y = .data$surv,
                   colour = overlay_label, linetype = overlay_label))
  }

  lv <- c(km_label, overlay_label)
  p +
    ggplot2::scale_colour_manual(
      NULL, breaks = lv,
      values = stats::setNames(c(cols$km, cols$overlay), lv)) +
    ggplot2::scale_linetype_manual(
      NULL, breaks = lv,
      values = stats::setNames(c("solid", cols$overlay_linetype), lv)) +
    ggplot2::scale_y_continuous(
      limits = c(0, 1), breaks = seq(0, 1, 0.25),
      expand = ggplot2::expansion(mult = c(0.01, 0.04))) +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0.01, 0.02))) +
    ggplot2::labs(title = title, subtitle = subtitle, x = x_lab, y = y_lab,
                  caption = caption) +
    ggplot2::guides(colour = ggplot2::guide_legend(
      override.aes = list(linewidth = 1.1))) +
    theme_cure_assess(dark)
}

#' Restyle the package's own ggsurvplot (`state$fit$kmplot`).
#'
#' Recomputes nothing: it repaints the object `cureAssess` handed us, so the
#' curve and the risk table stay exactly what the package drew. Use it wherever
#' `$kmplot` is displayed.
#'
#'   output$km <- renderPlot({
#'     print(ca_style_survplot(state$fit$kmplot, dark = isTRUE(state$dark)))
#'   }, res = 108, bg = "transparent")
#'
#' Pass `bg = "transparent"` to `renderPlot()` and let the theme paint the
#' surface, so the plot's ground always matches the card it sits in.
#'
#' survminer emits "Ignoring unknown labels: fill Strata" at print time; it is
#' cosmetic and already suppressed inside the restyle.
#'
#' @param sp a `ggsurvplot` (a list of ggplots) or a bare ggplot.
#' @param dark logical(1), from `state$dark`.
ca_style_survplot <- function(sp, dark = FALSE, base_size = 14) {
  s <- ca_series(dark)
  k <- ca_tokens(dark)

  # INTEGRATION FIX 1 (C3, no repetition): the fitting step titles the figure
  # "Kaplan-Meier Survival Curve", and every card that mounts it is ALREADY
  # headed "Kaplan-Meier curve" - the same words twice, 40px apart, on all
  # three versions. The card keeps the title; the figure drops it.
  # INTEGRATION FIX 2: a single-group curve was drawing a legend reading
  # "Strata / All", which names a grouping the app never makes. Dropped
  # whenever there is one stratum; a real split still gets its legend.
  # INTEGRATION FIX 3 (dark mode): the risk-table numbers inherit the strata
  # COLOUR scale, which on the dark ramp is a mid petrol on near-black and was
  # reported as barely legible. They are re-inked to the body colour, which is
  # what they are - labels, not a second data series.
  n_strata <- tryCatch({
    st <- sp$plot$data$strata
    if (is.null(st)) 1L else length(unique(stats::na.omit(as.character(st))))
  }, error = function(e) 1L)

  restyle <- function(g, tbl = FALSE) {
    if (!inherits(g, "ggplot")) return(g)
    suppressMessages(
      g +
        ggplot2::scale_colour_manual(values = rep(s, length.out = 12)) +
        ggplot2::scale_fill_manual(values = rep(s, length.out = 12)) +
        theme_cure_assess(dark, base_size = if (tbl) base_size * 0.9 else base_size) +
        ggplot2::theme(
          legend.position = if (tbl || n_strata < 2L) "none" else "top",
          # Only the MAIN plot loses its title. The risk table keeps "Number at
          # risk", which the body copy on every version points the reader at.
          plot.title    = if (tbl) ggplot2::element_text(
                              colour = k$ink, size = base_size * 0.95,
                              face = "bold", hjust = 0)
                          else ggplot2::element_blank(),
          plot.subtitle = if (tbl) ggplot2::element_text(colour = k$ink2)
                          else ggplot2::element_blank(),
          # the risk table's "Strata" axis title names nothing the user chose
          axis.title.y  = if (tbl) ggplot2::element_blank() else ggplot2::element_text(
            colour = k$ink2, size = base_size * 0.93)
        )
    )
  }

  #' Re-ink the risk-table numbers, which are drawn as a text layer.
  reink <- function(g) {
    if (!inherits(g, "ggplot")) return(g)
    for (i in seq_along(g$layers)) {
      L <- g$layers[[i]]
      if (inherits(L$geom, "GeomText") || inherits(L$geom, "GeomLabel")) {
        g$layers[[i]]$aes_params$colour <- k$ink
        g$layers[[i]]$mapping$colour <- NULL
      }
    }
    g
  }

  if (inherits(sp, "ggsurvplot") || is.list(sp)) {
    if (!is.null(sp$plot))         sp$plot         <- restyle(sp$plot)
    if (!is.null(sp$table))        sp$table        <- reink(restyle(sp$table, tbl = TRUE))
    if (!is.null(sp$ncensor.plot)) sp$ncensor.plot <- restyle(sp$ncensor.plot, tbl = TRUE)
    return(sp)
  }
  restyle(sp)
}


# -----------------------------------------------------------------------------
# 5. INLINE SVG GLYPHS
#
# 16px viewBox, stroke-based, stroke="currentColor": every glyph inherits the
# colour of the chip, rail item or banner it sits in, in both modes, with no
# second palette to keep in step. bsicons and fontawesome are forbidden (§L.1).
#
# The five chip glyphs required by §F.8 are check / cross / ring / bang / dash.
# The six rail glyphs are named for the nav ids in NAV_ORDER, and are drawn from
# the subject: an open manuscript, a data table, a bar of statistics, a
# descending KM staircase, a finish flag, a question mark.
# -----------------------------------------------------------------------------
CA_ICON_PATHS <- list(
  # -- status ----------------------------------------------------------------
  check = '<path d="M3 8.5l3.2 3.2L13 4.8"/>',
  cross = '<path d="M4 4l8 8M12 4l-8 8"/>',
  dash  = '<path d="M3 8h10"/>',
  dot   = '<circle cx="8" cy="8" r="5" stroke-width="1.6"/><circle cx="8" cy="8" r="1.8" fill="currentColor" stroke="none"/>',
  ring  = '<circle cx="8" cy="8" r="4.6" stroke-width="1.6"/>',
  bang  = '<path d="M8 3.5v5.2"/><circle cx="8" cy="12.2" r="1" fill="currentColor" stroke="none"/>',
  warn  = '<path stroke-width="1.5" d="M8 2.2l6 11H2z"/><path stroke-width="1.5" d="M8 6.4v3.2"/><circle cx="8" cy="11.6" r=".8" fill="currentColor" stroke="none"/>',
  info  = '<circle cx="8" cy="8" r="6" stroke-width="1.4"/><path stroke-width="1.5" d="M8 7.2v4"/><circle cx="8" cy="4.9" r=".85" fill="currentColor" stroke="none"/>',
  lock  = '<rect x="3.5" y="7" width="9" height="6.5" rx="1.2" stroke-width="1.5"/><path stroke-width="1.5" d="M5.7 7V5.2a2.3 2.3 0 0 1 4.6 0V7"/>',
  arrow = '<path d="M3 8h10M9.2 4.2L13 8l-3.8 3.8"/>',
  eye   = '<path stroke-width="1.4" d="M1.6 8S3.9 3.8 8 3.8 14.4 8 14.4 8 12.1 12.2 8 12.2 1.6 8 1.6 8z"/><circle cx="8" cy="8" r="1.9" stroke-width="1.4"/>',

  # -- the six rail glyphs, one per nav id ------------------------------------
  intro = '<path stroke-width="1.2" d="M2.4 3.6h4.2A1.6 1.6 0 0 1 8 5v7.4a1.3 1.3 0 0 0-1.1-.7H2.4z"/><path stroke-width="1.2" d="M13.6 3.6H9.4A1.6 1.6 0 0 0 8 5v7.4a1.3 1.3 0 0 1 1.1-.7h4.5z"/>',
  data  = '<rect x="2.4" y="3.2" width="11.2" height="9.6" rx="1.2" stroke-width="1.2"/><path stroke-width="1.2" d="M2.4 6.4h11.2M6.4 6.4v6.4M10 6.4v6.4"/>',
  quant = '<path stroke-width="1.2" d="M2.4 13h11.2M4.2 13V8.8M7.2 13V5.2M10.2 13v-2.4M13.2 13V7"/>',
  qual  = '<path stroke-width="1.2" d="M2.4 4.3v3.4h2.9v2.7h3.4v2.1h4.9"/>',
  rec   = '<path stroke-width="1.2" d="M3.7 13.6V2.7"/><path stroke-width="1.2" d="M3.7 3.4h7.3l-1.4 2.5 1.4 2.5H3.7z"/>',
  expert = '<circle cx="8" cy="5.4" r="2.4" stroke-width="1.2"/><path stroke-width="1.2" d="M3.2 13.2a4.8 4.8 0 0 1 9.6 0"/>',
  docs  = '<circle cx="8" cy="8" r="5.6" stroke-width="1.2"/><path stroke-width="1.2" d="M6.5 6.4a1.56 1.56 0 1 1 2.1 1.5c-.4.16-.56.48-.56.88v.28"/><circle cx="8" cy="11" r=".68" fill="currentColor" stroke="none"/>'
)
# Older spellings of two rail ids, so a caller that says "concl" or "help"
# still gets the right picture instead of the fallback.
CA_ICON_PATHS$concl      <- CA_ICON_PATHS$rec
CA_ICON_PATHS$conclusion <- CA_ICON_PATHS$rec
CA_ICON_PATHS$help  <- CA_ICON_PATHS$docs

#' One inline SVG glyph.
#'
#' `ca_icon("check")` returns an `htmltools` HTML string suitable for dropping
#' inside a chip, a rail item, a banner or a summary. The glyph is
#' `aria-hidden`: it is always paired with a word, never used as the only
#' channel (§F.8, §L.12).
#'
#' An unknown name returns the neutral `dot` glyph rather than stopping — a
#' missing picture must never take the app down mid-demo. Legal names:
#' check, cross, dash, dot, ring, bang, warn, info, lock, arrow, eye,
#' intro, expert, data, quant, qual, rec, docs.
#'
#' @param name character(1), one of the names above.
#' @param size pixel size of the square glyph.
#' @param class optional class attribute for the `<svg>`.
ca_icon <- function(name, size = 16, class = NULL) {
  if (!is.character(name) || length(name) != 1L || !(name %in% names(CA_ICON_PATHS))) {
    name <- "dot"
  }
  htmltools::HTML(sprintf(
    paste0('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" ',
           'width="%1$s" height="%1$s" fill="none" stroke="currentColor" ',
           'stroke-width="2" stroke-linecap="round" stroke-linejoin="round" ',
           'aria-hidden="true" focusable="false"%2$s>%3$s</svg>'),
    size,
    if (is.null(class)) "" else sprintf(' class="%s"', class),
    CA_ICON_PATHS[[name]]
  ))
}


# -----------------------------------------------------------------------------
# 6. THE FOUR SHARED CHART BUILDERS — V2_CONTRACT §F.4
#
# DRAW-ONLY. Every number arrives through an argument; none of these calls a
# cureAssess function, holds a reactive, reads `state` or computes a statistic.
# The only arithmetic below is turning a value into a percentage position along
# a bar, which is layout, not inference.
#
# All three versions (app/, app-v2/, app-v3/) call these. app-v2 and app-v3 may
# READ this file and may never edit it (§F.2) — a chart that needs a new option
# gets it here, from builder-shell, or not at all this pass.
#
# Two are HTML/CSS (the timeline and the threshold track) because they are one
# bar with three labels: a graphics device would cost a PNG round trip, would
# not reflow, would not inherit the dark ramp and could not be read by a screen
# reader. Their styling lives in app/www/app.css §O.
# Two are ggplot (the plane and the AIC dots) because they carry real axes.
#
# plotly is forbidden, so there is no hover layer anywhere. The compensation is
# mandatory and is honoured below: every chart has at most ten marks, every mark
# that matters is direct-labelled, and every chart has a table view beside it.
#
# THE NOT-COMPUTABLE LINE. Maller-Zhou, qn and Shen return NA together when the
# largest observed time is an event (S6). The wording below is the same sentence
# the Quantitative tab uses (`.QUANT_VOID_LINE`, mod_quantitative.R), repeated
# here as a literal rather than read across files so this file has no run-time
# dependency on another builder's module. If one moves, move both.
# -----------------------------------------------------------------------------

CA_VOID_LINE <- "Cannot be computed: the longest observed time is an event."

#' Clamp a value to a percentage position along a bar. Layout, not statistics.
#' @noRd
.ca_pct_pos <- function(x, lo, hi) {
  if (!is.finite(x) || !is.finite(lo) || !is.finite(hi) || hi <= lo) return(0)
  max(0, min(100, 100 * (x - lo) / (hi - lo)))
}

#' A short numeric label for a chart tick. Not `ca_num()`: axis labels want
#' three significant figures, not four decimals.
#' @noRd
.ca_tick <- function(x, digits = 3) {
  if (is.null(x) || length(x) != 1L || is.na(x) || !is.finite(x)) return(ca_dash())
  # trimws: formatC() pads short results to a common width, which would put
  # leading spaces inside a tick label.
  trimws(formatC(as.numeric(x), digits = digits, format = "g"))
}


# ---- F.4.1 ------------------------------------------------------------------
#' The follow-up timeline — where the last event sits inside follow-up
#'
#' One 44px bar. The first segment runs from time zero to the last event; the
#' second runs from the last event to the end of follow-up, which is the window
#' the three follow-up readings key on. Ticks at 0, the last event and the end.
#'
#' When `zero_width` is TRUE the second segment has no width at all — the S6
#' case — and the bar carries a void chip inline instead of three grey cards.
#'
#' Every number comes from `ca_tail_facts()`, which counts on the prepared
#' frame's own `Y` and `D` and reads no package field.
#'
#' @param last_event numeric(1), `ca_tail_facts()$last_event`.
#' @param max_time numeric(1), `ca_tail_facts()$max_time`.
#' @param gap_pct numeric(1), `ca_tail_facts()$gap_pct`, the tail as a
#'   percentage of follow-up. Used in the caption only.
#' @param n_cens_after integer(1), `ca_tail_facts()$n_cens_after`.
#' @param zero_width logical(1), `ca_tail_facts()$zero_width`.
#' @param unit character(1), the time unit in words, for the tick labels.
#' @param caption `TRUE` for the standard caption, `FALSE` for none, or a
#'   character(1) to supply your own.
#' @return `htmltools` `<figure class="ca-timeline">`.
ca_viz_timeline <- function(last_event, max_time, gap_pct = NA_real_,
                            n_cens_after = NA_integer_, zero_width = FALSE,
                            unit = NULL, caption = TRUE) {

  ok <- is.numeric(last_event) && is.numeric(max_time) &&
    length(last_event) == 1L && length(max_time) == 1L &&
    is.finite(last_event) && is.finite(max_time) && max_time > 0

  if (!ok) {
    return(htmltools::tags$figure(
      class = "ca-timeline", `data-ca-state` = "void",
      htmltools::tags$div(class = "ca-timeline__void", ca_chip("void", "Not available"))
    ))
  }

  void  <- isTRUE(zero_width) || !(max_time > last_event)
  share <- .ca_pct_pos(last_event, 0, max_time)
  if (void) share <- 100

  unit_txt <- if (is.null(unit) || !nzchar(unit)) "" else paste0(" ", unit)

  # The figure is one picture: the label reads it aloud, and the segments and
  # ticks are decorative to assistive technology.
  alt <- if (void) {
    paste0("Follow-up ends at ", .ca_tick(max_time), unit_txt,
           ", on the last event. There is no window after it.")
  } else {
    paste0("The last event is at ", .ca_tick(last_event), unit_txt,
           ". Follow-up continues to ", .ca_tick(max_time), unit_txt, ".")
  }

  cap <- if (isTRUE(caption)) {
    if (void) {
      CA_VOID_LINE
    } else {
      bits <- character(0)
      if (is.numeric(gap_pct) && length(gap_pct) == 1L && is.finite(gap_pct)) {
        bits <- c(bits, paste0(formatC(gap_pct, digits = 1, format = "f"),
                               "% of follow-up falls after the last event"))
      }
      if (is.numeric(n_cens_after) && length(n_cens_after) == 1L &&
          is.finite(n_cens_after)) {
        bits <- c(bits, paste0(as.integer(n_cens_after),
                               " still under observation there"))
      }
      if (length(bits) == 0L) NULL else paste0(paste(bits, collapse = ", "), ".")
    }
  } else if (is.character(caption) && length(caption) == 1L && nzchar(caption)) {
    caption
  } else {
    NULL
  }

  tick <- function(value, pos, cls = NULL) htmltools::tags$span(
    class = paste(c("ca-timeline__tick", cls), collapse = " "),
    style = sprintf("left: %.4f%%;", pos),
    htmltools::tags$span(class = "ca-timeline__tick-rule"),
    htmltools::tags$span(class = "ca-timeline__tick-label ca-num", .ca_tick(value))
  )

  htmltools::tags$figure(
    class = "ca-timeline",
    `data-ca-state` = if (void) "void" else "ready",
    htmltools::tags$div(
      class = "ca-timeline__track", role = "img", `aria-label` = alt,
      htmltools::tags$div(
        class = "ca-timeline__seg ca-timeline__seg--observed",
        style = sprintf("width: %.4f%%;", share)
      ),
      if (!void) htmltools::tags$div(
        class = "ca-timeline__seg ca-timeline__seg--tail",
        style = sprintf("width: %.4f%%;", 100 - share)
      ),
      if (void) htmltools::tags$div(
        class = "ca-timeline__inline-chip", ca_chip("void", "No window")
      )
    ),
    htmltools::tags$div(
      class = "ca-timeline__axis",
      tick(0, 0, "ca-timeline__tick--start"),
      if (!void) tick(last_event, share),
      tick(max_time, 100, "ca-timeline__tick--end")
    ),
    if (!is.null(cap)) htmltools::tags$figcaption(class = "ca-timeline__caption", cap)
  )
}


# ---- F.4.2 ------------------------------------------------------------------
#' One threshold track — a reading, its threshold, and which side is good
#'
#' One linear scale from zero to a little past the larger of the two values.
#' The threshold is a tick; the reading is an 8px dot; the good side of the
#' threshold is tinted. Direction is explicit, because it is not the same for
#' the two readings that use this (S8).
#'
#' TWO TRACKS ARE DRAWN, NEVER THREE (S9). Maller-Zhou and qn are algebraically
#' the same test, so a third track would draw one decision twice and read as two
#' independent votes. The caller draws the qn track and passes the Maller-Zhou
#' reading as `companion_line`, one sentence beneath it.
#'
#' A missing reading renders one void panel carrying the not-computable line —
#' never the literal text NA, never a blank, never a red fail.
#'
#' @param stat numeric(1), the reading. `NA` renders the void panel.
#' @param threshold numeric(1), the value it is compared against.
#' @param larger_is_better logical(1). TRUE for qn, FALSE for Shen (S8).
#' @param label character(1), the question the track answers, in words.
#' @param companion_line character(1) or NULL — the S9 sentence.
#' @param void_line character(1), the sentence used when `stat` is missing.
#' @return `htmltools` `<figure class="ca-track">`.
ca_viz_threshold_track <- function(stat, threshold, larger_is_better, label,
                                   companion_line = NULL,
                                   void_line = CA_VOID_LINE) {

  num1 <- function(x) is.numeric(x) && length(x) == 1L && !is.na(x) && is.finite(x)

  head <- htmltools::tags$figcaption(class = "ca-track__title", label)

  if (!num1(stat) || !num1(threshold)) {
    return(htmltools::tags$figure(
      class = "ca-track", `data-ca-state` = "void",
      head,
      htmltools::tags$div(
        class = "ca-track__void",
        ca_chip("void", "Cannot be computed"),
        htmltools::tags$p(class = "ca-track__void-text", void_line)
      )
    ))
  }

  bigger <- isTRUE(larger_is_better)
  met    <- if (bigger) stat > threshold else stat < threshold

  # The scale starts at zero and ends a little past whichever value is larger,
  # so both marks are always inside the bar and the gap between them is drawn
  # to scale. This is layout arithmetic, not a transformation of a statistic.
  hi <- max(stat, threshold)
  hi <- if (hi <= 0) 1 else hi * 1.12
  p_stat <- .ca_pct_pos(stat, 0, hi)
  p_thr  <- .ca_pct_pos(threshold, 0, hi)

  good_style <- if (bigger) {
    sprintf("left: %.4f%%; right: 0;", p_thr)
  } else {
    sprintf("left: 0; width: %.4f%%;", p_thr)
  }

  htmltools::tags$figure(
    class = "ca-track",
    `data-ca-met` = if (isTRUE(met)) "true" else "false",
    head,
    htmltools::tags$div(
      class = "ca-track__bar",
      role = "img",
      `aria-label` = paste0(
        label, " The reading is ", .ca_tick(stat, 4), ", against ",
        .ca_tick(threshold, 4), ". ",
        if (bigger) "Larger is better." else "Smaller is better."
      ),
      htmltools::tags$div(class = "ca-track__good", style = good_style),
      htmltools::tags$div(class = "ca-track__thr",
                          style = sprintf("left: %.4f%%;", p_thr)),
      htmltools::tags$div(class = "ca-track__dot",
                          style = sprintf("left: %.4f%%;", p_stat))
    ),
    htmltools::tags$div(
      class = "ca-track__labels",
      htmltools::tags$span(
        class = "ca-track__stat ca-num", .ca_tick(stat, 4)),
      htmltools::tags$span(
        # INTEGRATION FIX: this read just "below 0.05", sitting at the right-hand
        # end of the bar with the reading "0.3676" at the left - which parses as
        # the false sentence "0.3676, below 0.05". It is the CRITERION, not a
        # claim about the value, and it now says so. Same wording the
        # Quantitative cards already use, so the two agree.
        class = "ca-track__thr-label",
        if (bigger) "needs to be above " else "needs to be below ",
        htmltools::tags$span(class = "ca-num", .ca_tick(threshold, 4))
      )
    ),
    if (!is.null(companion_line) && nzchar(companion_line)) {
      htmltools::tags$p(class = "ca-track__companion", companion_line)
    }
  )
}


# ---- F.4.3 ------------------------------------------------------------------
#' The cured-group plane — the two RECeUS quantities, plotted against each other
#'
#' 420x420. x is the ratio of censored uncured subjects, y is the cure fraction.
#' The region in which both conditions hold is drawn as a tinted rectangle with
#' a solid boundary and one corner label; the dataset is one dot, direct
#' labelled with both values. One scale per axis, no dual axis, no legend.
#'
#' THE CUT-OFFS 0.025 AND 0.05 ARE DRAWN, NOT DECIDED. They are the package's
#' own comparison (cureAssess/R/receus.method.R:116-117:
#' `pi_hat > 0.025 && r_hat < 0.05`) and V2_CONTRACT §F.4 specifies the region
#' explicitly. Drawing the region is decoration on a decision the package has
#' already made and already reported in its decision string, which is the value
#' every verdict in this app actually reads. Nothing here recomputes it, and the
#' same literals are deliberately NOT written to the batch CSV (§C.4).
#'
#' @param pi_hat numeric(1), `$tests$receus$pi_hat`.
#' @param r_hat numeric(1), `$tests$receus$r_hat`.
#' @param extra `data.frame(label, pi, r)` of further points — the batch table's
#'   other rows — or NULL. Drawn small and unlabelled, behind the main dot.
#' @param dark logical(1), from `state$dark`. Trailing so the contract's
#'   positional signature is unchanged; without it the chart could not follow
#'   the dark ramp.
#' @return A ggplot, or NULL when neither value is usable.
ca_viz_receus_plane <- function(pi_hat, r_hat, extra = NULL, dark = FALSE) {
  num1 <- function(x) is.numeric(x) && length(x) == 1L && !is.na(x) && is.finite(x)
  if (!num1(pi_hat) || !num1(r_hat)) return(NULL)

  k      <- ca_tokens(dark)
  cols   <- ca_plot_cols(dark)
  pi_cut <- 0.025
  r_cut  <- 0.05

  pts <- data.frame(pi = as.numeric(pi_hat), r = as.numeric(r_hat))
  if (is.data.frame(extra) && nrow(extra) > 0L &&
      all(c("pi", "r") %in% names(extra))) {
    ex <- extra[is.finite(extra$pi) & is.finite(extra$r), c("pi", "r"), drop = FALSE]
  } else {
    ex <- NULL
  }

  x_hi <- max(c(pts$r, ex$r, r_cut * 2), na.rm = TRUE) * 1.08
  x_hi <- if (!is.finite(x_hi) || x_hi <= 0) 0.2 else x_hi

  lab <- paste0("cure fraction ", formatC(pts$pi, format = "f", digits = 3),
                "\nratio ", formatC(pts$r, format = "f", digits = 4))

  # INTEGRATION FIX: the direct label was always drawn to the RIGHT of and ABOVE
  # the dot (hjust -0.12, vjust -0.18). With gbsg the ratio sits at 0.308 of a
  # 0.36 axis and with sim_c the cure fraction sits at the ceiling, so ggplot2
  # clipped the label at the panel edge and the two numbers vanished. The label
  # now flips to the other side of the dot once the point passes 60% of either
  # axis, which keeps it inside the panel at every value the app can produce.
  lab_h <- if (pts$r  > x_hi * 0.60) 1.12 else -0.12
  lab_v <- if (pts$pi > 0.78)        1.20 else -0.18

  p <- ggplot2::ggplot() +
    ggplot2::annotate("rect", xmin = -Inf, xmax = r_cut, ymin = pi_cut, ymax = Inf,
                      fill = k$pass_bg, colour = NA) +
    ggplot2::annotate("segment", x = r_cut, xend = r_cut, y = pi_cut, yend = Inf,
                      colour = k$pass_line, linewidth = 0.6) +
    ggplot2::annotate("segment", x = -Inf, xend = r_cut, y = pi_cut, yend = pi_cut,
                      colour = k$pass_line, linewidth = 0.6) +
    # Pinned just inside the shaded corner rather than hung off r_cut, which
    # ran outside the panel whenever the axis maximum was small.
    ggplot2::annotate("text", x = min(r_cut, x_hi) * 0.96, y = 1, label = "supported",
                      hjust = 1, vjust = 1.6, size = 3.1,
                      colour = k$ink2, family = "sans") +
    ggplot2::annotate("segment", x = r_cut, xend = r_cut, y = -Inf, yend = pi_cut,
                      colour = k$rule2, linewidth = 0.3, linetype = "22") +
    ggplot2::annotate("segment", x = r_cut, xend = Inf, y = pi_cut, yend = pi_cut,
                      colour = k$rule2, linewidth = 0.3, linetype = "22")

  if (!is.null(ex) && nrow(ex) > 0L) {
    p <- p + ggplot2::geom_point(
      data = ex, shape = 21, size = 2.4, stroke = 0.7,
      colour = cols$ink3, fill = NA,
      ggplot2::aes(x = .data$r, y = .data$pi))
  }

  p +
    ggplot2::geom_point(data = pts, size = 3.2, colour = k$ink,
                        ggplot2::aes(x = .data$r, y = .data$pi)) +
    ggplot2::annotate("text", x = pts$r, y = pts$pi, label = lab,
                      hjust = lab_h, vjust = lab_v, size = 3.1, lineheight = 1.15,
                      colour = k$ink2, family = "sans") +
    ggplot2::scale_x_continuous(
      limits = c(0, x_hi), expand = ggplot2::expansion(mult = c(0.02, 0.08))) +
    ggplot2::scale_y_continuous(
      limits = c(0, 1), breaks = seq(0, 1, 0.25),
      expand = ggplot2::expansion(mult = c(0.02, 0.06))) +
    ggplot2::labs(x = "Censored uncured subjects, as a ratio",
                  y = "Estimated cure fraction") +
    theme_cure_assess(dark) +
    ggplot2::theme(legend.position = "none",
                   panel.grid.major.y = ggplot2::element_line(
                     colour = k$rule, linewidth = 0.3))
}


# ---- F.4.4 ------------------------------------------------------------------
#' The model-comparison dot plot
#'
#' One row per candidate, in the package's own row order, on one linear axis.
#'
#' SHAPE, NOT HUE, carries the one distinction that matters: a model with a
#' cured group is a filled dot, one without is a hollow ring. That survives
#' colour-vision deficiency, greyscale and a projector lamp.
#'
#' S4 IS HONOURED HERE AND IS NOT NEGOTIABLE. A fit that failed keeps its row,
#' is drawn as a cross pinned outside the axis with its reason beside it, and
#' sorts last. It is never filtered out, because which models failed is itself
#' informative. The sortable table stays beside this chart as the table view.
#'
#' NO DELTA ANYWHERE. The app differences nothing (S1); the eye reads the gap.
#'
#' @param aic_table `$screening$aic_table` — columns `model`, `model_type`,
#'   `AIC`, `error`. Already ordered by the package, missing values last.
#' @param best character(1) or NULL, `$screening$best_model`. Its dot is drawn
#'   1.4x and carries a direct label.
#' @param dark logical(1), from `state$dark`. Trailing, as above.
#' @return A ggplot, or NULL when there is no usable table.
ca_viz_aic_dots <- function(aic_table, best = NULL, dark = FALSE) {
  if (!is.data.frame(aic_table) || nrow(aic_table) == 0L) return(NULL)
  if (!all(c("model", "AIC") %in% names(aic_table))) return(NULL)

  k <- ca_tokens(dark)

  tbl <- aic_table
  tbl$..aic  <- suppressWarnings(as.numeric(tbl$AIC))
  tbl$..fail <- !is.finite(tbl$..aic)
  tbl$..cure <- if ("model_type" %in% names(tbl)) {
    identical_cure <- as.character(tbl$model_type) == "cure"
    ifelse(is.na(identical_cure), grepl("_cure$", tbl$model), identical_cure)
  } else {
    grepl("_cure$", tbl$model)
  }
  tbl$..err <- if ("error" %in% names(tbl)) {
    e <- as.character(tbl$error); e[is.na(e)] <- ""; e
  } else {
    rep("", nrow(tbl))
  }

  # Failed rows sort last, whatever order they arrived in (S4).
  tbl <- tbl[order(tbl$..fail, tbl$..aic), , drop = FALSE]
  lab <- vapply(as.character(tbl$model), function(m) {
    if (!is.na(m) && m %in% names(CA_MODEL_LABELS)) CA_MODEL_LABELS[[m]] else m
  }, character(1), USE.NAMES = FALSE)
  tbl$..label <- factor(lab, levels = rev(lab))
  tbl$..best  <- if (is.null(best) || length(best) != 1L || is.na(best)) {
    rep(FALSE, nrow(tbl))
  } else {
    !is.na(tbl$model) & as.character(tbl$model) == as.character(best)
  }

  ok  <- tbl[!tbl$..fail, , drop = FALSE]
  bad <- tbl[tbl$..fail, , drop = FALSE]
  if (nrow(ok) == 0L) return(NULL)

  # The crosses sit just outside the data range, on the axis's own scale, so a
  # failed fit is visibly off the scale rather than pretending to a value.
  span <- diff(range(ok$..aic))
  if (!is.finite(span) || span <= 0) span <- max(abs(ok$..aic[1]), 1)
  x_lo <- min(ok$..aic) - span * 0.06
  x_fail <- min(ok$..aic) - span * 0.16

  p <- ggplot2::ggplot() +
    ggplot2::geom_segment(
      data = ok, linewidth = 0.3, colour = k$rule,
      ggplot2::aes(x = x_lo, xend = .data$..aic,
                   y = .data$..label, yend = .data$..label)) +
    # INTEGRATION FIX: `fill` was set OUTSIDE aes() to the same petrol as the
    # stroke, so shape 21 painted a SOLID dot and the documented "hollow ring =
    # no cured group" distinction did not survive to the screen — both classes
    # rendered identically. Fill is now mapped, and the non-cure fill is the
    # panel's own surface, which reads as a true ring on light and dark alike.
    ggplot2::geom_point(
      data = ok, stroke = 1.1,
      ggplot2::aes(x = .data$..aic, y = .data$..label,
                   shape = .data$..cure, size = .data$..best,
                   fill = .data$..cure),
      colour = unname(k$series[["petrol"]]))

  bst <- ok[ok$..best, , drop = FALSE]
  if (nrow(bst) > 0L) {
    p <- p + ggplot2::geom_text(
      data = bst, hjust = -0.35, vjust = 0.4, size = 3.1,
      colour = k$ink, family = "sans",
      ggplot2::aes(x = .data$..aic, y = .data$..label,
                   label = formatC(.data$..aic, format = "f", digits = 2)))
  }

  if (nrow(bad) > 0L) {
    bad$..x <- x_fail
    p <- p +
      ggplot2::geom_point(
        data = bad, shape = 4, size = 2.6, stroke = 1.1, colour = k$ink3,
        ggplot2::aes(x = .data$..x, y = .data$..label)) +
      ggplot2::geom_text(
        data = bad, hjust = 0, vjust = 0.4, size = 2.9,
        colour = k$ink3, family = "sans",
        ggplot2::aes(x = .data$..x, y = .data$..label,
                     label = paste0("   did not fit")))
  }

  p +
    ggplot2::scale_shape_manual(values = c(`TRUE` = 21, `FALSE` = 21),
                                breaks = c("TRUE", "FALSE"), guide = "none") +
    ggplot2::scale_fill_manual(
      values = c(`TRUE` = unname(k$series[["petrol"]]), `FALSE` = k$surface),
      breaks = c("TRUE", "FALSE"), guide = "none") +
    ggplot2::scale_size_manual(values = c(`TRUE` = 4.2, `FALSE` = 3.0),
                               guide = "none") +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0.04, 0.12))) +
    ggplot2::labs(x = "Model comparison score: smaller is a better description",
                  y = NULL) +
    theme_cure_assess(dark) +
    ggplot2::theme(
      legend.position = "none",
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_line(colour = k$rule, linewidth = 0.3),
      axis.text.y = ggplot2::element_text(colour = k$ink2, hjust = 1)
    )
}
