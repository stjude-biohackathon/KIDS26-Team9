# =============================================================================
# cureAssessApp — application entry point
# Owner: builder-shell.  Nobody else edits this file.
#
# This file, and only this file, knows the tab order. It attaches the
# libraries, creates the one shared reactive state object, defines the one
# navigation callback, builds the left rail and the hidden navset, and calls
# the six module servers. It contains no statistics and no package call sites.
#
# Run it with:  shiny::runApp("app")   from the repository root
#          or:  shiny::runApp()        from inside app/
# =============================================================================

# ---- libraries: these five, in this order, and no others -------------------
library(shiny)
library(bslib)
library(DT)
library(ggplot2)

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
# stopped being true when the report download was reinstated. mod_conclusion.R
# now calls rmarkdown::pandoc_available(), rmarkdown::find_pandoc() and
# rmarkdown::render() from its downloadHandler, always namespaced and never
# via library(). The comment was the only thing that was wrong.

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
NAV_ORDER <- c("intro", "data", "quant", "qual", "conclusion", "docs")

CA_NAV_LABELS <- c(intro = "Intro", data = "Data", quant = "Quantitative",
                   qual = "Qualitative", conclusion = "Conclusion", docs = "Documentation")


# =============================================================================
# UI
# =============================================================================

ui <- bslib::page_fluid(
  theme = ca_bs_theme(),
  htmltools::tags$head(
    htmltools::tags$title("cureAssess — is a cure model appropriate?"),
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
      # Written out literally in NAV_ORDER order: splicing into navset_hidden()
      # is the one place bslib 0.12.0 is fussy, and six literal lines cannot
      # break. If NAV_ORDER changes, reorder these six lines to match.
      bslib::navset_hidden(
        id = "ca_nav",
        bslib::nav_panel_hidden(value = "intro",      mod_intro_ui("intro")),
        bslib::nav_panel_hidden(value = "data",       mod_data_ui("data")),
        bslib::nav_panel_hidden(value = "quant",      mod_quantitative_ui("quant")),
        bslib::nav_panel_hidden(value = "qual",       mod_qualitative_ui("qual")),
        bslib::nav_panel_hidden(value = "conclusion", mod_conclusion_ui("conclusion")),
        bslib::nav_panel_hidden(value = "docs",       mod_docs_ui("docs"))
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
  state <- reactiveValues(
    nav = "intro", dark = FALSE,
    raw = NULL, label = NULL, source = NULL, map = NULL, dropped = NULL,
    prepared = NULL, fit = NULL, assess = NULL,
    include_lognormal = FALSE, alpha = 0.05, alpha_tests = NULL,
    expert_confirmed = FALSE, expert_note = "", visual_ack = FALSE,
    status = "empty", last_error = NULL
  )

  # ---- the navigation callback --------------------------------------------
  # Defined once, closing over the root session, and passed unchanged to all
  # six modules. It switches the visible panel and updates state$nav, and does
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
  output$ca_rail <- renderUI({
    st         <- state$status
    has_prep   <- !is.null(state$prepared)
    has_assess <- !is.null(state$assess)

    states <- c(
      intro      = "done",
      data       = if (st %in% c("prepared", "assessed")) "done" else "ready",
      quant      = if (!has_prep) "locked" else if (identical(st, "assessed")) "done" else "ready",
      qual       = if (!has_prep) "locked" else if (isTRUE(state$expert_confirmed)) "done" else "ready",
      conclusion = if (!has_assess) "locked" else "ready",
      docs       = "ready"
    )

    ca_rail(NAV_ORDER, CA_NAV_LABELS, states = states, active = state$nav)
  })

  # ---- the six module servers ---------------------------------------------
  # Module id equals nav id throughout, so input ids on the Data tab are
  # namespaced "data-..." and so on. The automatic first-load Prepare of the
  # default dataset belongs to mod_data (contract C.1, owner tabs-a); the shell
  # does not reach into another module's inputs to trigger it.
  mod_intro_server("intro", state, go_to)
  mod_data_server("data", state, go_to)
  mod_quantitative_server("quant", state, go_to)
  mod_qualitative_server("qual", state, go_to)
  mod_conclusion_server("conclusion", state, go_to)
  mod_docs_server("docs", state, go_to)

  invisible(NULL)
}

shinyApp(ui, server)
