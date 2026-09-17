# =============================================================================
# cureAssessApp — application entry point
# Owner: builder-shell.  Nobody else edits this file.
#
# This file, and only this file, knows the tab order. It attaches the
# libraries, creates the one shared reactive state object, defines the one
# navigation callback, builds the left rail and the hidden navset, and calls
# the eight module servers. It contains no statistics and no package call
# sites.
#
# Run it with:  shiny::runApp("app")   from the repository root
#          or:  shiny::runApp()        from inside app/
# =============================================================================

# ---- libraries: these five, in this order, and no others -------------------
# suppressPackageStartupMessages: bslib masks utils::page and DT masks two
# shiny exports, and each prints an "Attaching package" block to the console on
# every launch. The masking is expected and harmless (nothing here calls
# utils::page, and DT's dataTableOutput/renderDataTable are the ones we want),
# but the notices are the only noise a clean start-up produces, so they are
# silenced rather than left for a reader to triage.
suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(DT)
  library(ggplot2)
})

# cureAssess is attached here, ONCE, for the whole app. The installed package is
# preferred; the vendored source at cureAssess/ is the fallback so a teammate
# with a fresh clone and no install is not blocked (same idiom as
# app-scaffold/app.R). Either way the package is attached before the UI is built.
if (requireNamespace("cureAssess", quietly = TRUE)) {
  library(cureAssess)                                  # nolint: the fifth library
} else {
  .ca_vendored <- Filter(dir.exists, c("cureAssess", file.path("..", "cureAssess")))
  if (length(.ca_vendored) > 0L && requireNamespace("devtools", quietly = TRUE)) {
    devtools::load_all(.ca_vendored[[1]], quiet = TRUE)
  } else {
    stop("cureAssess is not available. Install it, or run scripts/smoke_test.R first.",
         call. = FALSE)
  }
  rm(.ca_vendored)
}

# No builder calls library() anywhere else. Modules use plain names for the
# five above (e.g. cure.appropriateness(), nav_select(), datatable(), ggplot()).
# Everything else is namespaced at the call site:
#   survival::, survminer::, dplyr::, htmltools::, stats::, utils::, grid::
# flexsurv and flexsurvcure are NEVER called by app code.
# FIXPASS (reverifier): this line used to say the same of rmarkdown, which
# stopped being true when the report download was reinstated.
# mod_recommendation.R now calls rmarkdown::pandoc_available(),
# rmarkdown::find_pandoc() and rmarkdown::render() from its downloadHandler,
# always namespaced and never via library(). The comment was the only thing
# that was wrong.

# ---- auto-load fallback: the only source() in the repository ---------------
# Shiny sources every app/R/*.R file automatically, alphabetically, relative to
# the app directory. This block fires only when that did not happen (someone
# sourced app.R directly rather than launching the app directory), so it can
# never double-source. Both candidate directories are listed so the fallback
# works from the repository root as well as from app/.
if (!exists("ca_bs_theme", mode = "function")) {
  .ca_rdir <- Filter(dir.exists, c(file.path("R"), file.path("app", "R")))
  if (length(.ca_rdir) > 0L) {
    for (.f in sort(list.files(.ca_rdir[[1]], pattern = "\\.R$", full.names = TRUE))) source(.f)
    rm(.f)
  }
  rm(.ca_rdir)
}

# ---- THE ONE PLACE THE TAB ORDER CHANGES ----------------------------------
# Swapping two ids here reorders the rail and the panels together. The rail
# numbers come from seq_along(NAV_ORDER); nothing else in the repo depends on
# position, because every other reference is by id.
#
# FINAL_CONTRACT §B.1 — EIGHT tabs. `qmulti` is the batch assessment, lifted
# out of the Recommendation accordion into a tab of its own and seated
# immediately below `quant`. The old "conclusion" id is dead and is NOT in this
# vector, so go_to() rejects it: any stale navigation to it stops() loudly on
# the first click, by design.
NAV_ORDER <- c("intro", "expert", "data", "qual", "quant", "qmulti", "rec", "docs")

# The rail carries the lead's tab names verbatim (T1/T3): the rail IS the tab
# list, so an abbreviation here would mean the app does not have the tabs that
# were asked for. The two long names wrap to two lines in the widened label
# column (see app.css §17 — the rail gains 44px at >=1200px and 28px in the
# 992-1200px band); the rail's own `max-height` + `overflow-y: auto` already
# absorb the extra height at short viewports, and below 992px the labels are
# visually hidden in favour of the icon rail, so neither long name reaches the
# <768px horizontal scroller.
CA_NAV_LABELS <- c(
  intro  = "Intro",
  expert = "Expert judgment",
  data   = "Data",
  qual   = "Qualitative",
  quant  = "Quantitative — Assess Single Datasets",
  qmulti = "Quantitative — Assess Multiple Datasets",
  rec    = "Recommendation",
  docs   = "Documentation"
)

# FINAL_CONTRACT §B.3 — the full page heading rides on each rail link as a
# plain `title` attribute, so the 76px icon rail (768–992px) and the <768px
# horizontal bar stay hoverable once the label is visually hidden. A plain HTML
# attribute, no JS. These strings must match the <h1> on each tab.
CA_NAV_TITLES <- c(
  intro  = "Is a cure model right for your data?",
  expert = "Expert judgment",
  data   = "Data",
  qual   = "Visual assessment",
  quant  = "Quantitative — Assess Single Datasets",
  qmulti = "Quantitative — Assess Multiple Datasets",
  rec    = "Recommendation",
  docs   = "Documentation"
)


# =============================================================================
# UI
# =============================================================================

ui <- bslib::page_fluid(
  theme = ca_bs_theme(),
  htmltools::tags$head(
    # C1: the browser tab is visible UI too, and app-v2 already dropped the
    # package name from it. All three versions now show the same tab text.
    htmltools::tags$title("Is a cure model appropriate?"),
    htmltools::tags$link(rel = "stylesheet", href = "app.css")
  ),
  bslib::input_dark_mode(id = "ca_mode", mode = "light"),
  htmltools::div(
    class = "ca-shell",

    # The rail is re-emitted server-side so that data-ca-state and aria-current
    # are plain attributes computed from state; there is no custom JS and no
    # sendCustomMessage anywhere in the app. The mount is display:contents so
    # the <nav class="ca-rail"> that ca_rail() returns is itself the flex child
    # of .ca-shell and the wrapper adds no layout of its own.
    shiny::uiOutput("ca_rail", style = "display: contents;"),

    htmltools::tags$main(
      class = "ca-main",

      # V2_CONTRACT §B.5 — the other half of the progress indication.
      # With the Run and Prepare buttons gone (R2) the app computes on its own,
      # and withProgress() plus the .recalculating dim carry that to anyone
      # watching the screen. This carries it to anyone who is not: one polite
      # live region holding ca_status_line(), which states no number, names no
      # method and is visually hidden, so it adds ZERO visible words (C2).
      htmltools::tags$div(
        class = "ca-sr",
        role = "status",
        `aria-live` = "polite",
        `aria-atomic` = "true",
        shiny::textOutput("ca_status", inline = TRUE)
      ),

      # Written out literally in NAV_ORDER order: splicing into navset_hidden()
      # is the one place bslib 0.12.0 is fussy, and eight literal lines cannot
      # break. If NAV_ORDER changes, reorder these eight lines to match.
      #
      # FINAL_CONTRACT §C.3: `qmulti` mounts mod_batch_page_ui(), which is a
      # thin page wrapper owned by builder-batch. It passes the SAME module id
      # straight through to mod_batch_ui(), so no extra namespace level is
      # introduced and every existing batch input id is unchanged.
      bslib::navset_hidden(
        id = "ca_nav",
        bslib::nav_panel_hidden(value = "intro",  mod_intro_ui("intro")),
        bslib::nav_panel_hidden(value = "expert", mod_expert_ui("expert")),
        bslib::nav_panel_hidden(value = "data",   mod_data_ui("data")),
        bslib::nav_panel_hidden(value = "qual",   mod_qualitative_ui("qual")),
        bslib::nav_panel_hidden(value = "quant",  mod_quantitative_ui("quant")),
        bslib::nav_panel_hidden(value = "qmulti", mod_batch_page_ui("qmulti")),
        bslib::nav_panel_hidden(value = "rec",    mod_recommendation_ui("rec")),
        bslib::nav_panel_hidden(value = "docs",   mod_docs_ui("docs"))
      )
    )
  )
)


# =============================================================================
# Server
# =============================================================================

server <- function(input, output, session) {

  # ---- the ONE shared state object ----------------------------------------
  # Closed list: no module adds, renames or repurposes a field. Modules talk to
  # each other only through this object and through go_to().
  #
  # REVISION_CONTRACT §C.1. expert_q1 / expert_q2 / expert_confirmed are
  # written only by mod_expert.R (and cleared by mod_data.R on a dataset
  # change); expert_confirmed is derived from the two answers and is never
  # inferred from a statistic. Two fields are retired by §C.2 — the visual
  # acknowledgement flag and the free-text expert note — and neither the
  # declaration below nor any read site mentions them any more.
  #
  # V2_CONTRACT §B.6 and §C — two fields are added this pass, and only two:
  #   tau_result  the tau-ladder exploration result (mod_quantitative.R). It is
  #               DISPLAY-ONLY: it never reaches ca_recommendation() and never
  #               reaches report.Rmd (§B.1, §C.3). It lives on state rather than
  #               in a module-local reactive so that ca_reset_assessment() can
  #               clear it, which is what keeps an exploration from outliving
  #               the mapping it was computed on.
  #   batch       the batch result frame (mod_batch.R), cleared for the same
  #               reason: its rows are cached on a provenance key that includes
  #               the mapping tuple (§C.6).
  # Both are nulled by ca_reset_assessment() (helpers.R F.13), which the
  # auto-prepare observer calls as its first statement. Nothing else adds,
  # renames or repurposes a field.
  state <- reactiveValues(
    nav = "intro", dark = FALSE,
    raw = NULL, label = NULL, source = NULL, map = NULL, dropped = NULL,
    prepared = NULL, fit = NULL, assess = NULL,
    include_lognormal = FALSE, alpha = 0.05, alpha_tests = NULL,
    tau_result = NULL, batch = NULL,
    expert_q1 = "", expert_q2 = "", expert_confirmed = FALSE,
    status = "empty", last_error = NULL
  )

  # ---- the navigation callback --------------------------------------------
  # Defined once, closing over the root session, and passed unchanged to all
  # eight modules. It switches the visible panel and updates state$nav, and does
  # nothing else: navigating is not an analysis event, so it never touches
  # prepared, assess or status. Safe and idempotent from any state, including
  # the empty one. An illegal tab id stops loudly so a typo is caught the first
  # time it is clicked.
  go_to <- function(tab) {
    stopifnot(is.character(tab), length(tab) == 1L, tab %in% NAV_ORDER)
    bslib::nav_select(id = "ca_nav", selected = tab, session = session)
    state$nav <- tab
    invisible(tab)
  }

  # ---- rail clicks ---------------------------------------------------------
  # The rail lives inside a renderUI, so its actionLinks are rebuilt whenever
  # the completion state changes and their click counters restart at zero. A
  # per-session record of the last count seen makes the observer fire on a real
  # increment only, never on the reset that follows a re-render.
  # ca_on_click() (helpers.R F.21) is that guard, and is the single
  # click-observer idiom for the whole app: every module uses it too, so a
  # button rebuilt inside a renderUI can never fire its handler by itself.
  lapply(NAV_ORDER, function(tab) {
    ca_on_click(input, paste0("nav_", tab), function() go_to(tab))
  })

  # ---- light / dark --------------------------------------------------------
  # state$dark mirrors the bslib toggle and is read by the plot builders in the
  # Quantitative and Qualitative modules. Shell is the only writer.
  observeEvent(input$ca_mode, {
    state$dark <- identical(input$ca_mode, "dark")
  }, ignoreInit = FALSE)

  # ---- rail completion state ----------------------------------------------
  # Rendered, not messaged. Locked items stay clickable and stay in the tab
  # order: clicking one still navigates, and the destination tab's own empty
  # state explains what is missing and offers the control that goes there.
  # REVISION_CONTRACT §B.3, one row per tab. `qual` no longer reports "done"
  # off an expert tick — that signal moved to `expert`, and it is read through
  # ca_expert_state() so the three-way outcome has exactly one implementation.
  #
  # V2_CONTRACT §B — WHAT AUTO-COMPUTE CHANGES HERE.
  # The rail used to key its locks on `state$prepared` and `state$assess`, which
  # was right when a human had to press Prepare and Run: a NULL there meant "you
  # have not done this yet". With both buttons gone (R2) a NULL there means
  # something completely different — the recompute triggered by the last mapping
  # change has not landed yet, ~150 ms. Keying locks on those two fields would
  # make three rail items flicker Locked -> Ready on every debounced change, and
  # would contradict §B.2's promise that `rec` is never locked.
  #
  # So "Locked" now means exactly one thing: THERE IS NO USABLE DATA IN THE APP.
  # That is `state$raw` empty, or a preparation that failed outright. Anything
  # else is either computed ("Done") or computing ("Ready"), and a step that is
  # computing shows the same state as one waiting to be read, because from the
  # user's side there is nothing to do in either case. `expert` is untouched and
  # is now the only rail item that tracks something the user must actually do.
  output$ca_rail <- renderUI({
    st <- state$status

    # Anything downstream of preparation exists, or is on its way.
    usable <- !is.null(state$raw) && !identical(st, "error")

    states <- c(
      intro  = "done",
      expert = if (identical(ca_expert_state(state), "unanswered")) "ready" else "done",
      data   = if (usable && st %in% c("prepared", "assessed")) "done" else "ready",
      qual   = if (!usable) "locked" else "ready",
      quant  = if (!usable) "locked"
               else if (identical(st, "assessed") && !is.null(state$assess)) "done"
               else "ready",
      # FINAL_CONTRACT §B.4: the new batch tab takes the SAME rule as `rec` —
      # locked only when there is no usable data, "ready" otherwise, and never
      # "done". Batch has no single completion the rail could assert: it runs
      # over a set of datasets the user chooses, and finishing one says nothing
      # about the rest. Eight steps, one coherent vocabulary.
      qmulti = if (!usable) "locked" else "ready",
      rec    = if (!usable) "locked" else "ready",
      docs   = "ready"
    )

    ca_rail(NAV_ORDER, CA_NAV_LABELS, states = states, active = state$nav,
            titles = CA_NAV_TITLES)
  })

  # ---- the progress announcement -------------------------------------------
  # Paired with the visually-hidden live region in the UI. helpers.R F.24 owns
  # the wording; the shell only mounts it.
  output$ca_status <- shiny::renderText(ca_status_line(state))

  # ---- the eight module servers -------------------------------------------
  # Module id equals nav id throughout, so input ids on the Data tab are
  # namespaced "data-..." and so on. The first-load preparation of the default
  # dataset belongs to mod_data's auto-prepare observer (V2_CONTRACT §B.2,
  # `ignoreInit = FALSE`); the shell does not reach into another module's inputs
  # to trigger it.
  #
  # FINAL_CONTRACT §C: batch is tab 6, mounted here under the id "qmulti".
  # It was an accordion panel inside the Recommendation tab; that mount and the
  # accordion around it are gone. mod_batch_server() already accepts and
  # ignores go_to, and it adds no navigation button of its own.
  mod_intro_server("intro", state, go_to)
  mod_expert_server("expert", state, go_to)
  mod_data_server("data", state, go_to)
  mod_qualitative_server("qual", state, go_to)
  mod_quantitative_server("quant", state, go_to)
  mod_batch_server("qmulti", state, go_to)
  mod_recommendation_server("rec", state, go_to)
  mod_docs_server("docs", state, go_to)

  invisible(NULL)
}

shinyApp(ui, server)
