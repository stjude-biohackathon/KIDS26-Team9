# =============================================================================
# cureAssessApp — app/R/theme.R
#
# The R half of the visual system. Three things live here and nothing else:
#   1. ca_bs_theme()        the bs_theme() call (Bootstrap 5 via bslib 0.12.0)
#   2. ca_tokens() etc.     the R mirror of app.css's colour tokens
#   3. theme_cure_assess()  the ggplot2 4.0.3 theme + the KM plot styling
#   4. ca_icon()            inline SVG glyphs (bsicons/fontawesome are forbidden)
#
# This file computes NO statistic. Every plotting function here takes numbers
# that already came out of a cureAssess object and draws them.
#
# Verified on R 4.6.1 / ggplot2 4.0.3 / bslib 0.12.0 / survminer 0.5.2.
# =============================================================================

`%+replace%` <- ggplot2::`%+replace%`

# -----------------------------------------------------------------------------
# 0. FONTS — system stacks, deliberately. See the note at the bottom of §1.
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
    warning   = "#C2860E",  # ink on it 5.69:1 (Bootstrap picks dark text here)
    danger    = "#B03A29",  # white on it 6.03:1

    "border-radius"        = "6px",
    "border-radius-sm"     = "3px",
    "border-radius-lg"     = "10px",
    "spacer"               = "1rem",
    "font-size-base"       = "1.0625rem",   # 17px — readable at three metres
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

# Use it, with the dark-mode toggle and the one stylesheet:
#
#   ui <- bslib::page_fluid(
#     theme = ca_bs_theme(),
#     htmltools::tags$head(
#       htmltools::tags$link(rel = "stylesheet", href = "app.css")
#     ),
#     bslib::input_dark_mode(id = "ca_mode", mode = "light"),
#     ...
#   )
#
# mode = "light" opens light for the demo rather than inheriting the OS setting,
# so the projector shows the same thing every time. The toggle still works.
#
# WHY SYSTEM FONTS, NOT font_google(): font_google() downloads the font files
# when the theme is BUILT — i.e. at app start, on the demo machine, on whatever
# network the venue has. A cold cache plus no Wi-Fi is a failed launch or a
# silent fallback to something unstyled, in front of the room. A system stack
# has no network step and no FOUT. If you ever do want a web face, the drop-in
# is base_font = bslib::font_collection(bslib::font_google("Source Sans 3",
# local = TRUE), CA_SANS) — and you must then vendor the cache into the repo
# and test with Wi-Fi off before Friday.

# -----------------------------------------------------------------------------
# 2. TOKENS — the R mirror of app.css. Edit both, or neither.
# -----------------------------------------------------------------------------
ca_tokens <- function(dark = FALSE) {
  if (!dark) list(
    surface = "#FBFCFC", canvas = "#EEF2F3", sunk = "#F4F7F8",
    ink = "#11191C", ink2 = "#414D52", ink3 = "#667378",
    rule = "#DBE2E4", rule2 = "#C3CDD0",
    series = c(petrol = "#00739B", ember = "#C2571F", claret = "#8D2157"),
    band_alpha = 0.12, censor = "#0A5670",
    tail_fill = "#E7ECEE", tail_rule = "#8A979B", tail_ink = "#414D52"
  ) else list(
    surface = "#161D20", canvas = "#0E1315", sunk = "#1D2528",
    ink = "#EAF0F1", ink2 = "#AEBCC0", ink3 = "#8A979B",
    rule = "#2A3438", rule2 = "#3D4A4F",
    series = c(petrol = "#2E9BC6", ember = "#D4732F", claret = "#D8428A"),
    band_alpha = 0.16, censor = "#8CCBE2",
    tail_fill = "#20292C", tail_rule = "#8A979B", tail_ink = "#AEBCC0"
  )
}
ca_series <- function(dark = FALSE) unname(ca_tokens(dark)$series)

ca_scale_colour_cure <- function(dark = FALSE, ...)
  ggplot2::scale_colour_manual(values = ca_series(dark), ...)
ca_scale_fill_cure <- function(dark = FALSE, ...)
  ggplot2::scale_fill_manual(values = ca_series(dark), ...)

# The app has no dark-mode R session variable of its own: read the toggle.
#   dark <- isTRUE(input$ca_mode == "dark")
#   renderPlot({ ca_km_overlay_plot(..., dark = isTRUE(input$ca_mode == "dark")) })
# Pass bg = "transparent" to renderPlot and let the theme paint the surface, so
# the plot's ground always matches the card it sits in:
#   renderPlot({...}, res = 108, bg = "transparent")

# -----------------------------------------------------------------------------
# 3. THE ggplot2 THEME
# -----------------------------------------------------------------------------
theme_cure_assess <- function(dark = FALSE, base_size = 14, base_family = "sans") {
  k <- ca_tokens(dark)
  half <- base_size / 2

  ggplot2::theme_minimal(base_size = base_size, base_family = base_family) %+replace%
    ggplot2::theme(
      # ggplot2 4.0's geom defaults: anything drawn without an explicit colour
      # still lands inside the palette instead of falling back to black.
      geom = ggplot2::element_geom(ink = k$ink, paper = k$surface,
                                   accent = k$series[["petrol"]]),

      plot.background    = ggplot2::element_rect(fill = k$surface, colour = NA),
      panel.background   = ggplot2::element_rect(fill = k$surface, colour = NA),
      panel.border       = ggplot2::element_blank(),

      # Horizontal hairlines only. Survival probability is read off the y-axis;
      # x gets ticks and a baseline. Solid, never dashed.
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
}

# Note on base_family: R's graphics device, not the browser, renders the plot.
# It cannot see system-ui or Charter, and neither showtext nor thematic is
# installed, so "sans" (Helvetica/Arial on the device) is the correct and only
# safe choice. Do NOT try to make plot text match the UI face.

# -----------------------------------------------------------------------------
# 4. COLOUR ASSIGNMENTS FOR THE KM FIGURE
#
#   KM step curve ......... series 1 (petrol), linewidth 0.7 (~2px), solid
#   Confidence band ....... series 1 at 12% (light) / 16% (dark), no outline
#   Censoring marks ....... --ca-censor, shape 124 (the clinical vertical tick),
#                           a darker step of the curve's own hue so it reads as
#                           a mark ON the curve, not as a second series
#   Fitted overlay ........ series 2 (ember), linewidth 0.7, LONG DASH ("42").
#                           Dash is deliberate secondary encoding: solid = data,
#                           dashed = model. It survives grayscale, projectors
#                           and colour-blind readers.
#   Follow-up tail band ... --ca-tail-fill wash + a solid hairline at the last
#                           event time. NEUTRAL, never amber or red: the tail
#                           means "unresolved", not "bad", and colouring it as a
#                           warning would editorialise a descriptive fact.
#
#   last_event_time = max(Y[D == 1]) — a descriptive count, permitted by §5.10.
# -----------------------------------------------------------------------------

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
  # the words, and a clipped label is worse than none. The caption carries it.
  span <- (max_time - last_event_time) / (max_time - min_time)
  if (!is.null(label) && nzchar(label) && span >= 0.12)
    out <- c(out, list(
      ggplot2::annotate("text", x = (last_event_time + max_time) / 2, y = 1,
                        label = label, hjust = 0.5, vjust = 1.7, size = 3.0,
                        colour = k$tail_ink, family = "sans")))
  out
}

# Rectangles, not geom_ribbon: a KM confidence band is a step function and a
# smoothed ribbon would draw diagonals the estimator never claims.
ca_step_ribbon <- function(km) {
  km <- km[order(km$time), ]
  n <- nrow(km)
  if (n < 2) return(km[0, c("time", "lower", "upper")])
  data.frame(x1 = km$time[-n], x2 = km$time[-1],
             lower = km$lower[-n], upper = km$upper[-n])
}

#' The Models-tab overlay figure (A-06).
#'
#' Draws only. Every number comes in through the arguments.
#'  @param km        data.frame with time, surv, and optionally lower/upper —
#'                   read straight off state$fit$kmfit (a survfit object):
#'                     sf <- state$fit$kmfit
#'                     km <- data.frame(time = c(0, sf$time), surv = c(1, sf$surv),
#'                                      lower = c(1, sf$lower), upper = c(1, sf$upper),
#'                                      n.censor = c(0, sf$n.censor))
#'  @param censor    rows of km where n.censor > 0 (columns time, surv)
#'  @param overlay   data.frame(time, surv) from the fitting package's own
#'                   summary method — summary(state$fit$fits[[m]]$fit,
#'                   type = "survival", t = grid). Never hand-code an S(t).
#'  @param last_event_time  max(Y[D == 1]) on state$prepared
ca_km_overlay_plot <- function(km, censor = NULL, overlay = NULL,
                               last_event_time = NA_real_, max_time = NA_real_,
                               km_label = "Kaplan-Meier estimate",
                               overlay_label = "Fitted model",
                               dark = FALSE, conf_int = TRUE,
                               title = NULL, subtitle = NULL,
                               x_lab = "Time", y_lab = "Survival probability S(t)",
                               caption = NULL) {
  k <- ca_tokens(dark)
  s <- k$series
  if (is.na(max_time)) max_time <- max(km$time, na.rm = TRUE)

  p <- ggplot2::ggplot() +
    ca_followup_tail(last_event_time, max_time, dark,
                     min_time = min(km$time, na.rm = TRUE))

  if (isTRUE(conf_int) && all(c("lower", "upper") %in% names(km)))
    p <- p + ggplot2::geom_rect(
      data = ca_step_ribbon(km), colour = NA, fill = s[["petrol"]],
      alpha = k$band_alpha,
      ggplot2::aes(xmin = .data$x1, xmax = .data$x2,
                   ymin = .data$lower, ymax = .data$upper))

  p <- p + ggplot2::geom_step(
    data = km, direction = "hv", linewidth = 0.7, lineend = "round",
    ggplot2::aes(x = .data$time, y = .data$surv,
                 colour = km_label, linetype = km_label))

  if (!is.null(censor) && nrow(censor) > 0)
    p <- p + ggplot2::geom_point(
      data = censor, shape = 124, size = 2.4, stroke = 0.9, colour = k$censor,
      ggplot2::aes(x = .data$time, y = .data$surv))

  if (!is.null(overlay) && nrow(overlay) > 0)
    p <- p + ggplot2::geom_line(
      data = overlay, linewidth = 0.7, lineend = "round",
      ggplot2::aes(x = .data$time, y = .data$surv,
                   colour = overlay_label, linetype = overlay_label))

  lv <- c(km_label, overlay_label)
  p +
    ggplot2::scale_colour_manual(
      NULL, breaks = lv,
      values = stats::setNames(c(s[["petrol"]], s[["ember"]]), lv)) +
    ggplot2::scale_linetype_manual(
      NULL, breaks = lv,
      values = stats::setNames(c("solid", "42"), lv)) +
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

#' Restyle the package's OWN ggsurvplot (state$fit$kmplot) for the Data tab.
#' Recomputes nothing — it repaints the object cureAssess handed us, so the
#' risk table and the curve stay exactly what the package drew.
#'
#'   output$km_plot <- renderPlot({
#'     sp <- ca_style_survplot(state$fit$kmplot,
#'                             dark = isTRUE(input$ca_mode == "dark"))
#'     print(sp)
#'   }, res = 108, bg = "transparent")
#'
#' survminer emits "Ignoring unknown labels: fill Strata" at print time. It is
#' cosmetic; suppressMessages() around print() silences it if it bothers you.
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
# 5. INLINE SVG GLYPHS.  ca_icon("check") returns an htmltools tag.
# 16px viewBox, currentColor, stroke-based: they inherit the chip / rail colour.
# -----------------------------------------------------------------------------
CA_ICON_PATHS <- list(
  # status
  check = '<path d="M3 8.5l3.2 3.2L13 4.8"/>',
  cross = '<path d="M4 4l8 8M12 4l-8 8"/>',
  dash  = '<path d="M3 8h10"/>',
  dot   = '<circle cx="8" cy="8" r="5" stroke-width="1.6"/><circle cx="8" cy="8" r="1.8" fill="currentColor" stroke="none"/>',
  ring  = '<circle cx="8" cy="8" r="4.6" stroke-width="1.6"/>',
  bang  = '<path d="M8 3.5v5.2"/><circle cx="8" cy="12.2" r="1" fill="currentColor" stroke="none"/>',
  lock  = '<rect x="3.5" y="7" width="9" height="6.5" rx="1.2" stroke-width="1.5"/><path stroke-width="1.5" d="M5.7 7V5.2a2.3 2.3 0 0 1 4.6 0V7"/>',
  # the six rail glyphs, drawn from the subject: an open manuscript, a data
  # table, a bar of statistics, a descending KM staircase, a finish flag, a
  # question mark.
  intro = '<path stroke-width="1.2" d="M2.4 3.6h4.2A1.6 1.6 0 0 1 8 5v7.4a1.3 1.3 0 0 0-1.1-.7H2.4z"/><path stroke-width="1.2" d="M13.6 3.6H9.4A1.6 1.6 0 0 0 8 5v7.4a1.3 1.3 0 0 1 1.1-.7h4.5z"/>',
  data  = '<rect x="2.4" y="3.2" width="11.2" height="9.6" rx="1.2" stroke-width="1.2"/><path stroke-width="1.2" d="M2.4 6.4h11.2M6.4 6.4v6.4M10 6.4v6.4"/>',
  quant = '<path stroke-width="1.2" d="M2.4 13h11.2M4.2 13V8.8M7.2 13V5.2M10.2 13v-2.4M13.2 13V7"/>',
  qual  = '<path stroke-width="1.2" d="M2.4 4.3v3.4h2.9v2.7h3.4v2.1h4.9"/>',
  concl = '<path stroke-width="1.2" d="M3.7 13.6V2.7"/><path stroke-width="1.2" d="M3.7 3.4h7.3l-1.4 2.5 1.4 2.5H3.7z"/>',
  help  = '<circle cx="8" cy="8" r="5.6" stroke-width="1.2"/><path stroke-width="1.2" d="M6.5 6.4a1.56 1.56 0 1 1 2.1 1.5c-.4.16-.56.48-.56.88v.28"/><circle cx="8" cy="11" r=".68" fill="currentColor" stroke="none"/>'
)

ca_icon <- function(name, size = 16, class = NULL) {
  stopifnot(name %in% names(CA_ICON_PATHS))
  htmltools::HTML(sprintf(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" width="%1$s" height="%1$s" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false"%2$s>%3$s</svg>',
    size,
    if (is.null(class)) "" else sprintf(' class="%s"', class),
    CA_ICON_PATHS[[name]]
  ))
}

# -----------------------------------------------------------------------------
# 6. CHIP AND BANNER BUILDERS — so the word/glyph pairing can never drift apart.
# Every chip is (variant, glyph, word). There is no way to call these and get a
# colour without a word, which is the accessibility requirement in §8.2.
# -----------------------------------------------------------------------------
ca_chip <- function(variant = c("pass", "fail", "neutral", "void"), text, wrap = FALSE) {
  variant <- match.arg(variant)
  glyph <- c(pass = "check", fail = "cross", neutral = "dot", void = "dash")[[variant]]
  htmltools::tags$span(
    class = paste0("ca-chip ca-chip--", variant, if (wrap) " ca-chip--wrap" else ""),
    ca_icon(glyph, 15), text
  )
}

# The three RECeUS decision strings, matched verbatim. receus.method() can only
# ever return one of these three; anything else is a package change and should
# fail loudly rather than fall through to a neutral banner.
CA_RECEUS_VARIANT <- c(
  "Cure model appropriate"                   = "appropriate",
  "Cure model not supported"                 = "unsupported",
  "Follow-up insufficient for cure modeling" = "insufficient"
)
ca_receus_variant <- function(decision) {
  v <- CA_RECEUS_VARIANT[[decision]]        # errors on an unknown string — good
  v
}
ca_rec_banner <- function(decision, plain_language, verbatim = NULL,
                          conditions = NULL) {
  variant <- ca_receus_variant(decision)
  glyph <- c(appropriate = "check", unsupported = "cross", insufficient = "bang")[[variant]]
  htmltools::tags$div(
    class = paste0("ca-rec ca-rec--", variant),
    htmltools::tags$span(class = "ca-rec__glyph", ca_icon(glyph, 24)),
    htmltools::tags$div(
      class = "ca-rec__body",
      htmltools::tags$p(class = "ca-rec__decision", decision),
      htmltools::tags$p(class = "ca-rec__plain", plain_language),
      if (!is.null(conditions)) htmltools::tags$ul(
        class = "ca-rec__conditions",
        lapply(conditions, function(cond) htmltools::tags$li(
          class = "ca-rec__condition", `data-ca-met` = tolower(as.character(cond$met)),
          ca_icon(if (isTRUE(cond$met)) "check" else "cross", 15),
          htmltools::tags$span(cond$text)))),
      if (!is.null(verbatim))
        htmltools::tags$p(class = "ca-rec__verbatim", verbatim)
    )
  )
}
# ca_rec_banner(
#   decision = state$assess$tests$receus$decision,
#   plain_language = CA_COPY$receus_plain[[variant]],          # G-04 owns the words
#   verbatim = state$assess$final_recommendation,
#   conditions = list(
#     list(met = state$assess$tests$receus$cure_fraction_condition,
#          text = sprintf("Cure fraction present - pi_hat = %.4f > 0.025",
#                         state$assess$tests$receus$pi_hat)),
#     list(met = state$assess$tests$receus$followup_condition,
#          text = sprintf("Follow-up sufficient - r_hat = %.4f < 0.05",
#                         state$assess$tests$receus$r_hat))))

# -----------------------------------------------------------------------------
# 7. THE NAV ORDER — one vector, one place. Flip Quantitative/Qualitative by
# swapping two rows here and nothing else changes.
# -----------------------------------------------------------------------------
CA_NAV <- list(
  list(id = "intro",  label = "Intro",             icon = "intro"),
  list(id = "data",   label = "Data",              icon = "data"),
  list(id = "quant",  label = "Quantitative step", icon = "quant"),
  list(id = "qual",   label = "Qualitative step",  icon = "qual"),
  list(id = "concl",  label = "Conclusion",        icon = "concl"),
  list(id = "help",   label = "Documentation",     icon = "help")
)

#' Render the left rail. `states` is a named character vector over CA_NAV ids,
#' each "locked" | "ready" | "done"; `active` is the id of the current panel.
ca_rail <- function(states, active) {
  state_word  <- c(locked = "Locked", ready = "Ready", done = "Done")
  state_glyph <- c(locked = "lock",   ready = "dot",   done = "check")
  htmltools::tags$nav(
    class = "ca-rail", `aria-label` = "Assessment steps",
    htmltools::tags$p(class = "ca-eyebrow ca-rail__eyebrow", id = "ca-rail-h", "Workflow"),
    htmltools::tags$ul(
      class = "ca-rail__list", role = "tablist",
      `aria-orientation` = "vertical", `aria-labelledby` = "ca-rail-h",
      lapply(seq_along(CA_NAV), function(i) {
        item <- CA_NAV[[i]]
        st   <- states[[item$id]]
        on   <- identical(item$id, active)
        htmltools::tags$li(
          class = "ca-rail__item",
          htmltools::tags$a(
            class = "ca-rail__link", role = "tab",
            id = paste0("ca-tab-", item$id),
            href = paste0("#ca-panel-", item$id),
            `data-bs-toggle` = if (st != "locked") "tab",
            `data-ca-state`  = st,
            # A locked step keeps its place in the tab order and announces
            # itself as unavailable. Never `disabled`, never tabindex="-1".
            `aria-disabled`  = if (st == "locked") "true",
            `aria-controls`  = paste0("ca-panel-", item$id),
            `aria-selected`  = if (on) "true" else "false",
            `aria-current`   = if (on) "page",
            htmltools::tags$span(class = "ca-rail__num", `aria-hidden` = "true", i),
            htmltools::tags$span(class = "ca-rail__glyph", `aria-hidden` = "true",
                                 ca_icon(item$icon, 20)),
            htmltools::tags$span(class = "ca-rail__label", item$label),
            htmltools::tags$span(
              class = "ca-rail__state",
              htmltools::tags$span(class = "ca-rail__state-glyph", `aria-hidden` = "true",
                                   ca_icon(state_glyph[[st]], 13)),
              htmltools::tags$span(class = "ca-rail__state-text", state_word[[st]]))
          )
        )
      })
    )
  )
}
