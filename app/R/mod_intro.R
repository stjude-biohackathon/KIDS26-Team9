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
# ---------------------------------------------------------------------------


#' A poster figure with its caption
#'
#' @param src web path under `app/www` — always `"img/..."`, no leading slash,
#'   because Shiny serves `app/www` as the web root (§H).
#' @param alt long-form alternative text; the §H alt strings are pasted whole.
#' @param cap caption text.
#' @return an `htmltools` `<figure class="ca-figure">`
#' @noRd
.intro_figure <- function(src, alt, cap) {
  htmltools::tags$figure(
    class = "ca-figure",
    htmltools::tags$img(src = src, class = "ca-figure__img", alt = alt),
    htmltools::tags$figcaption(class = "ca-figure__cap", cap)
  )
}


#' Intro tab UI
#'
#' Title, one lede line, the flowchart, the equation, one control. Nothing
#' else on this tab (§G.1).
#'
#' @param id module id, equal to the nav id `"intro"`
#' @noRd
mod_intro_ui <- function(id) {
  ns <- NS(id)

  htmltools::tags$div(
    class = "ca-section",

    htmltools::tags$h1(class = "ca-section__title",
                       "Is a cure model right for your data?"),

    htmltools::tags$p(
      class = "ca-lede",
      paste("A cure model assumes some patients never have the event. It fits only when that group",
            "really exists and follow-up is long enough to see it.")
    ),

    # The flowchart leads the tab: it replaces the deleted three-step strip and
    # carries the three checks in the lead's own wording (§H.1).
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

    # The equation, with the poster's own line. The notation in the alt text is
    # the poster's: S_a(t) = pi_a + (1 - pi_a) S_u,a(t), pi_a the cure fraction
    # — never the README's (1 - p) form (§H.2).
    .intro_figure(
      src = "img/mixture-cure-model.png",
      alt = paste("Mixture cure model: overall survival in group a equals the cure fraction pi_a plus",
                  "one minus pi_a times the survival of the uncured in group a."),
      cap = "Cure models estimate the cure fraction and the survival of the uncured separately."
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
