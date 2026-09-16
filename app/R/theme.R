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
      level = "#4E6068"
    )
  } else {
    list(
      surface = "#161D20", canvas = "#0E1315", sunk = "#1D2528", sunk2 = "#26302F",
      ink = "#EAF0F1", ink2 = "#AEBCC0", ink3 = "#8A979B",
      rule = "#2A3438", rule2 = "#3D4A4F",
      series = c(petrol = "#2E9BC6", ember = "#D4732F", claret = "#D8428A"),
      band_alpha = 0.16, censor = "#8CCBE2",
      tail_fill = "#20292C", tail_rule = "#8A979B", tail_ink = "#AEBCC0",
      level = "#9DAEB4"
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
  restyle <- function(g, tbl = FALSE) {
    if (!inherits(g, "ggplot")) return(g)
    suppressMessages(
      g +
        ggplot2::scale_colour_manual(values = rep(s, length.out = 12)) +
        ggplot2::scale_fill_manual(values = rep(s, length.out = 12)) +
        theme_cure_assess(dark, base_size = if (tbl) base_size * 0.9 else base_size) +
        ggplot2::theme(legend.position = if (tbl) "none" else "top")
    )
  }
  if (inherits(sp, "ggsurvplot") || is.list(sp)) {
    if (!is.null(sp$plot))         sp$plot         <- restyle(sp$plot)
    if (!is.null(sp$table))        sp$table        <- restyle(sp$table, tbl = TRUE)
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
  conclusion = '<path stroke-width="1.2" d="M3.7 13.6V2.7"/><path stroke-width="1.2" d="M3.7 3.4h7.3l-1.4 2.5 1.4 2.5H3.7z"/>',
  docs  = '<circle cx="8" cy="8" r="5.6" stroke-width="1.2"/><path stroke-width="1.2" d="M6.5 6.4a1.56 1.56 0 1 1 2.1 1.5c-.4.16-.56.48-.56.88v.28"/><circle cx="8" cy="11" r=".68" fill="currentColor" stroke="none"/>'
)
# Older spellings of two rail ids, so a caller that says "concl" or "help"
# still gets the right picture instead of the fallback.
CA_ICON_PATHS$concl <- CA_ICON_PATHS$conclusion
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
#' intro, data, quant, qual, conclusion, docs.
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
