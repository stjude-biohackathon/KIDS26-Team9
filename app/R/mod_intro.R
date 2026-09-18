# ---------------------------------------------------------------------------
# mod_intro.R — the Intro tab (owner: rewriter-intro)
#
# REVISION v2.0: gutted to a few lines of copy plus the two poster figures.
# Deleted this pass (REVISION_CONTRACT §E.1): .intro_steps() and the
# "The three-step check" card (#1), the "What this app does not do" note (#2),
# the "Data and ethics" note (#3, moved to Documentation), the long
# old page lede with its (1 - p) notation (#4), and the
# "Start with an example dataset →" control, whose replacement now goes to the
# Expert judgment tab, not to Data (#5).
#
# Every sentence below is REVISION_CONTRACT §G.1, pasted verbatim. The two
# captions are the team lead's own poster wording. No prose here spells out the
# three checks: the flowchart image carries them (§H.1).
#
# Static, always renders: no empty state and no error state (§G.9).
# This tab reads no `state` field and no package field, so there is no field
# provenance to record.
#
# V2_CONTRACT (this pass, owner builder-rec):
#   * §E.5 #3 / R1 — the one-line caption that used to sit under the flowchart,
#     asserting that the checks run in a fixed order and that a "no" ends the
#     assessment, is DELETED, and the flowchart's alt text is rewritten so it
#     does not restate it. Nothing replaces it: C2 says when in doubt, delete.
#     Neither the sentence nor a paraphrase of it may return, here or in
#     app-v2/ or app-v3/.
#   * R2 — there is no Run button and no Prepare button anywhere in app/. The
#     first built-in dataset is prepared and assessed before first paint
#     (§B.2, ignoreInit = FALSE), so every later tab already has an answer on
#     it by the time the reader arrives. The only control on this tab is
#     navigation, which R2 explicitly leaves alone.
#
# FINAL_CONTRACT (this pass, owner builder-intro):
#   * I1 / §G.1 — the three definitions (cure model, cure fraction, sufficient
#     follow-up) arrive as ONE paragraph of two sentences, pasted verbatim.
#   * I2 / §G.8 — the equation figure carries `ca-figure--eq` and is capped
#     much smaller by the shared stylesheet. This file writes no CSS.
#   * I3 / §D — a drawn, inline-SVG cure-model schematic, themed entirely from
#     `var(--ca-…)` tokens so it works in light and dark and at any width.
#     It is a picture drawn from literals: no dataset, no package call, no
#     number on screen, so S1 is not engaged (§D.2).
#   * I4 / §D.7 — the flowchart now sits AFTER that diagram.
# ---------------------------------------------------------------------------


#' A poster figure with its caption
#'
#' @param src web path under `app/www` — always `"img/..."`, no leading slash,
#'   because Shiny serves `app/www` as the web root (§H).
#' @param alt long-form alternative text; the §H alt strings are pasted whole.
#' @param cap caption text.
#' @param extra_class optional extra class on the `<figure>`. Used once, for
#'   the equation figure, which carries `ca-figure--eq` so the shared stylesheet
#'   can cap its height much lower than the flowchart's (FINAL_CONTRACT I2 /
#'   §G.8). This module writes no CSS.
#' @return an `htmltools` `<figure class="ca-figure">`
#' @noRd
.intro_figure <- function(src, alt, cap, extra_class = NULL) {
  htmltools::tags$figure(
    class = paste(c("ca-figure", extra_class), collapse = " "),
    htmltools::tags$img(src = src, class = "ca-figure__img", alt = alt),
    htmltools::tags$figcaption(class = "ca-figure__cap", cap)
  )
}


#' The cure-model schematic (FINAL_CONTRACT I3, drawn exactly to §D)
#'
#' Inline SVG, not a PNG and not a ggplot: it inherits the page's CSS custom
#' properties, so dark mode is automatic with no second asset; it scales to any
#' width with no fixed pixel height; and it is offline by construction (C5).
#'
#' S1 IS NOT ENGAGED (§D.2). This is a schematic: every coordinate below is a
#' constant chosen to look right. It is drawn from no dataset, reads no `state`
#' field, calls no package function and reports no number. The only tick labels
#' are the structural 0 and 1 on the survival axis, and the plateau is labelled
#' with the symbol pi — never with a value.
#'
#' Every stroke and fill is a `var(--ca-…)` token with a neutral fallback, so
#' there is no hard-coded colour and the drawing re-themes with the page (§D.3).
#' The long labels live in the HTML key below the drawing, not inside the
#' viewBox, where at ~343px wide they would be illegible (§D.4).
#'
#' The ids `ca-cd-t` / `ca-cd-d` are literal: the diagram appears once, on this
#' tab only (§D.6).
#'
#' @return an `htmltools` `<figure class="ca-figure ca-cure-diagram">`
#' @noRd
.intro_cure_diagram <- function() {
  el <- function(name, ...) htmltools::tag(name, list(...))

  swatch <- function(kind, text) {
    htmltools::tags$li(
      htmltools::tags$span(
        class = paste0("ca-cure-diagram__swatch ca-cure-diagram__swatch--", kind)
      ),
      text
    )
  }

  htmltools::tags$figure(
    class = "ca-figure ca-cure-diagram",

    htmltools::tags$svg(
      viewBox = "0 0 640 340",
      preserveAspectRatio = "xMidYMid meet",
      # No `height` attribute: "auto" is not a valid SVG length, and Chrome
      # logs `<svg> attribute height: Expected length, "auto"` on every load.
      # `.ca-cure-diagram svg { height: auto }` in app.css does the real work,
      # and the viewBox + preserveAspectRatio keep the aspect ratio.
      width = "100%",
      xmlns = "http://www.w3.org/2000/svg",
      role = "img",
      `aria-labelledby` = "ca-cd-t ca-cd-d",

      el("title", id = "ca-cd-t", "A mixture cure model"),
      el("desc", id = "ca-cd-d",
         paste("Survival starts at one and falls, then flattens onto a plateau.",
               "The plateau height is the cure fraction. A dashed curve shows the",
               "uncured group, whose survival keeps falling to zero.")),

      # 1. Axes.
      el("line", x1 = "64", y1 = "280", x2 = "600", y2 = "280",
         stroke = "var(--ca-rule-2, #999)", `stroke-width` = "1"),
      el("line", x1 = "64", y1 = "24", x2 = "64", y2 = "280",
         stroke = "var(--ca-rule-2, #999)", `stroke-width` = "1"),

      # 2. Tick labels and axis titles. 1 and 0 are structural, not data.
      el("text", x = "54", y = "29", `text-anchor` = "end", `font-size` = "15",
         fill = "var(--ca-ink-3, #667378)", "1"),
      el("text", x = "54", y = "284", `text-anchor` = "end", `font-size` = "15",
         fill = "var(--ca-ink-3, #667378)", "0"),
      el("text", x = "22", y = "152", `text-anchor` = "middle", `font-size` = "16",
         fill = "var(--ca-ink-2, #414D52)", transform = "rotate(-90 22 152)",
         "Survival"),
      el("text", x = "332", y = "318", `text-anchor` = "middle", `font-size` = "16",
         fill = "var(--ca-ink-2, #414D52)", "Time"),

      # 3. The uncured component: keeps falling, all the way to zero.
      #    §D.3 writes this tail as `S 480 280, 600 280`. The S shorthand
      #    reflects the previous control point, which puts the implied control
      #    below the axis and makes the drawn curve dip under zero and come
      #    back up — a survival curve that rises. The tail is written out as an
      #    explicit C with the SAME on-curve anchors, so only the control point
      #    the contract never named moves, and the curve stays monotone.
      el("path", d = "M 64 24 C 150 120, 220 240, 320 272 C 420 279, 480 280, 600 280",
         stroke = "var(--ca-ink-3, #667378)", `stroke-width` = "2",
         `stroke-dasharray` = "7 5", fill = "none"),

      # 4. The cure-fraction rule, and 5. the cured share as an area.
      el("line", x1 = "64", y1 = "190", x2 = "600", y2 = "190",
         stroke = "var(--ca-primary, #0A5670)", `stroke-width` = "1.5",
         `stroke-dasharray` = "2 4"),
      el("rect", x = "64", y = "190", width = "536", height = "90",
         fill = "var(--ca-primary, #0A5670)", opacity = "0.10"),

      # 6. Overall survival: the same shape, flattening onto the plateau.
      #    Same correction as (3), same reason: the S shorthand made the curve
      #    sag below the plateau it is supposed to settle onto. Anchors
      #    unchanged.
      el("path", d = "M 64 24 C 150 96, 220 172, 320 188 C 420 190, 480 190, 600 190",
         stroke = "var(--ca-primary, #0A5670)", `stroke-width` = "3.5",
         fill = "none", `stroke-linecap` = "round"),

      # 7. The one symbol inside the drawing.
      el("text", x = "74", y = "182", `font-size` = "18", `font-style` = "italic",
         fill = "var(--ca-primary, #0A5670)", `dominant-baseline` = "auto",
         "π"),

      # 8. Two right-hand brackets: pi down to 0, and pi up to 1. No text
      #    inside the SVG for these — the key below carries the words (§D.4).
      el("path", d = "M 606 194 h 6 v 82 h -6",
         stroke = "var(--ca-ink-3, #667378)", `stroke-width` = "1.5", fill = "none"),
      el("path", d = "M 606 186 h 6 v -156 h -6",
         stroke = "var(--ca-ink-3, #667378)", `stroke-width` = "1.5", fill = "none")
    ),

    htmltools::tags$ul(
      class = "ca-cure-diagram__key",
      swatch("solid",   "Overall survival: the whole group."),
      swatch("dashed",  "The uncured (susceptible) group, whose survival keeps falling."),
      swatch("plateau", "The plateau height is the cure fraction π.")
    ),

    htmltools::tags$figcaption(
      class = "ca-figure__cap",
      "A mixture cure model: a cured fraction plus a declining uncured group."
    )
  )
}


#' Intro tab UI
#'
#' In order (FINAL_CONTRACT §D.7): the title and its one-line lede, the two
#' definition sentences, the small equation, the cure-model diagram, the
#' flowchart, one control. Nothing else on this tab.
#'
#' @param id module id, equal to the nav id `"intro"`
#' @noRd
mod_intro_ui <- function(id) {
  ns <- NS(id)

  htmltools::tags$div(
    class = "ca-section",

    htmltools::tags$h1(class = "ca-section__title",
                       "Is a cure model right for your data?"),

    # FINAL_CONTRACT I1 / §G.1, pasted verbatim: one paragraph, two sentences,
    # carrying all three definitions — a cure model, the cure fraction and
    # sufficient follow-up. Nothing more is added, here or below (C2).
    #
    # The earlier one-line lede ("A cure model assumes some patients never have
    # the event...") is deleted rather than kept above this one: it defined the
    # same two ideas in weaker words, so keeping both made the page open on two
    # paragraphs of overlapping definition. That is the repetition C3 forbids,
    # and the lead asked for the definitions to be ONE OR TWO SENTENCES (I1) —
    # which is exactly what this paragraph is.
    htmltools::tags$p(
      class = "ca-lede",
      paste("A cure model splits population into a cured subpopulation, who never have the event, and an",
            "uncured or susceptible subpopulation, who experience the event; the cure fraction is the",
            "proportion who are cured. Cure models require sufficent follow to identify the cured fraction and uncured survival.")
    ),

    # FINAL_CONTRACT §D.7 fixes the order of what follows: the small equation,
    # then the drawn cure-model diagram, then the flowchart, then the control.
    #
    # The equation, now TYPESET HTML rather than the poster PNG
    # (img/mixture-cure-model.png, which stays on disk but is unused here): an
    # image can neither drop the poster's subscript a nor take a smaller font.
    # The markup and the classes are the Documentation tab's own — `ca-eq
    # ca-math`, italic <i> variables, a real <sub>, `&pi;` — so it matches the
    # rest of the app, needs no new CSS, and renders with no network (C5). At
    # `.ca-eq`'s 1.12em it is far smaller than the 520x76 plate the image
    # occupied. The caption now names the three variables.
    htmltools::tags$figure(
      class = "ca-figure",
      htmltools::HTML(paste0(
        '<span class="ca-eq ca-math">',
        '<i>S</i><span class="br">(</span><i>t</i><span class="br">)</span>',
        '<span class="op">=</span><i>&pi;</i><span class="op">+</span>',
        '<span class="br">(</span>1<span class="op">&minus;</span><i>&pi;</i><span class="br">)</span>',
        '&#8201;<i>S</i><sub>u</sub><span class="br">(</span><i>t</i><span class="br">)</span>',
        '</span>'
      )),
      htmltools::tags$figcaption(
        class = "ca-figure__cap",
        htmltools::HTML(paste0(
          '<span class="ca-m"><i>S</i><span class="br">(</span><i>t</i><span class="br">)</span></span>',
          ' is survival in the whole group, ',
          '<span class="ca-m"><i>&pi;</i></span> the cure fraction, and ',
          '<span class="ca-m"><i>S</i><sub>u</sub><span class="br">(</span><i>t</i><span class="br">)</span></span>',
          ' survival of the uncured.'
        ))
      )
    ),

    # I3: the drawn schematic of the mixture, immediately after the equation it
    # illustrates. §D.1 records why the poster's image11.png is the visual
    # reference but is not reused: it is a raster with a baked white ground, it
    # does not show the two components, and it repeats the sufficient-follow-up
    # idea that the flowchart below already carries (C3).
    .intro_cure_diagram(),

    # I4: the flowchart now comes AFTER the diagram. It carries the three
    # checks in the lead's own wording (§H.1).
    #
    # V2_CONTRACT §E.5 #3 (R1): the caption that sat under this figure is
    # DELETED, and this alt text is rewritten so that it no longer reads as
    # that sentence. It now names the three checks and nothing else: no
    # ordering claim, no stopping claim. Do not reintroduce either.
    .intro_figure(
      src = "img/workflow-flowchart.png",
      alt = paste("A flowchart of three checks. Expert judgment: is a cure biologically plausible,",
                  "and is long-term survival without recurrence expected? Visual assessment: does the",
                  "survival curve plateau, with late events absent? Quantitative assessment: is there",
                  "strong quantitative evidence of sufficient follow-up and a cure fraction?"),
      cap = "Cure-model appropriateness"
    ),

    # The only interactive element on the tab, and it goes to Expert judgment:
    # that is the first real step, not Data (§G.1).
    htmltools::tags$div(
      class = "ca-hero",
      actionButton(ns("to_expert"), "First check →", class = "btn btn-primary btn-lg")
    )
  )
}


#' Intro tab server
#'
#' The tab holds no state and reads none: its single behaviour is the start
#' control, which hands navigation back to `app.R` through `go_to()`.
#'
#' @param id module id, `"intro"`
#' @param state the one shared `reactiveValues`; unused here, kept because the
#'   module signature in REVISION_CONTRACT §D.1 is fixed
#' @param go_to the navigation callback from `app.R`
#' @noRd
mod_intro_server <- function(id, state, go_to) {
  moduleServer(id, function(input, output, session) {

    ca_on_click(input, "to_expert", function() go_to("expert"))

    invisible(NULL)
  })
}
