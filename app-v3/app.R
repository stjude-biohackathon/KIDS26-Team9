# =============================================================================
# app-v3 — "The Bench"                       V2_CONTRACT §G.2. Owner: builder-v3.
#
# A fixed two-pane instrument that never scrolls as a page. The left pane holds
# every control the app has; the right pane is a live canvas that redraws the
# instant any of them changes, with the verdict pinned across its top. Nothing
# is ever run, because the canvas always shows the answer for whatever the left
# pane currently says.
#
# THIS FILE OWNS THE UI ASSEMBLY AND NOTHING ELSE. Every number on screen comes
# from the shared engine in ../app/R — see README.md.
#
#   shiny::runApp("app-v3")        from the repository root
# =============================================================================

# ---- libraries: the same five as the baseline, in the same order ------------
library(shiny)
library(bslib)
library(DT)
library(ggplot2)

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

# ---- auto-load fallback -----------------------------------------------------
# Shiny sources app-v3/R/*.R automatically, alphabetically, before this file.
# aa_shared.R sorts first and pulls in ../app/R. This block fires only when
# that did not happen (someone sourced app.R directly), so it cannot
# double-source.
if (!exists("ca_bs_theme", mode = "function")) {
  .ca_rdir <- Filter(dir.exists, c(file.path("R"), file.path("app-v3", "R")))
  if (length(.ca_rdir) > 0L) {
    for (.f in sort(list.files(.ca_rdir[[1]], pattern = "\\.R$", full.names = TRUE))) source(.f)
    rm(.f)
  }
  rm(.ca_rdir)
}

# ---- the shared stylesheet and images, served, never copied (§G.0) ----------
# "cashared" carries app/www/app.css. "img" carries app/www/img, because the
# shared documentation markup writes <img src="img/..."> and that path has to
# resolve from here too.
#
# §G.0 writes this prefix as "shared". Shiny reserves that exact word
# (addResourcePath() refuses it: "called with the reserved prefix 'shared'"),
# so the prefix is "cashared" here and in the <link> below. Nothing else about
# §G.0 changes, and not one byte is copied into this directory.
shiny::addResourcePath("cashared", .ca_shared_www)
shiny::addResourcePath("img", file.path(.ca_shared_www, "img"))

# The three modes. This vector is the whole of the navigation.
V3_MODES <- c(Assess = "assess", Compare = "compare", Method = "method")


# =============================================================================
# UI
# =============================================================================

ui <- bslib::page(
  theme = ca_bs_theme(),

  htmltools::tags$head(
    htmltools::tags$title("Is a cure model appropriate?"),
    # The shared sheet FIRST, this version's overrides second.
    htmltools::tags$link(rel = "stylesheet", href = "cashared/app.css"),
    htmltools::tags$link(rel = "stylesheet", href = "v3.css")
  ),

  htmltools::div(
    class = "v3-app",

    # ---- the 56px top bar: identity, dataset, navigation, light/dark -------
    htmltools::tags$header(
      class = "v3-top",
      htmltools::div(
        class = "v3-top__brand",
        htmltools::span(class = "v3-top__mark", ca_icon("qual", size = 18)),
        # C1: this said "cureAssess". The package NAME was then the first
        # visible text on every screen of this version - the one place C1
        # allows it is the reference list. The mark now describes the tool.
        htmltools::span(class = "v3-top__name", "Cure model check")
      ),
      htmltools::div(class = "v3-top__ds", textOutput("ds_name", inline = TRUE)),

      htmltools::div(
        class = "v3-seg",
        radioButtons(
          "mode",
          label = htmltools::span(class = "ca-sr", "View"),
          choices = V3_MODES, selected = "assess", inline = TRUE
        )
      ),

      htmltools::div(
        class = "v3-top__mode",
        bslib::input_dark_mode(id = "ca_mode", mode = "light")
      )
    ),

    # ---- the body: one control pane, one canvas, each scrolling alone ------
    htmltools::div(
      class = "v3-body",

      htmltools::tags$aside(
        class = "v3-pane", `aria-label` = "Controls",
        conditionalPanel(
          condition = "input.mode == 'assess'",
          mod_v3_controls_ui("ctl")
        ),
        conditionalPanel(
          condition = "input.mode == 'compare'",
          htmltools::div(
            class = "v3-sec",
            htmltools::h2(class = "v3-sec__title", "What to compare"),
            mod_batch_ui("batch", section = "chooser")
          )
        ),
        conditionalPanel(
          condition = "input.mode == 'method'",
          mod_v3_method_ui("method", section = "toc")
        )
      ),

      htmltools::tags$main(
        class = "v3-canvas",

        # One polite live region, visually hidden, so the automatic
        # recomputation is announced to anyone not watching the numbers
        # (§B.5). It adds zero visible words.
        htmltools::div(
          class = "ca-sr", role = "status",
          `aria-live` = "polite", `aria-atomic` = "true",
          textOutput("ca_status", inline = TRUE)
        ),

        conditionalPanel(
          condition = "input.mode == 'assess'",
          mod_v3_strip_ui("strip"),
          mod_v3_canvas_ui("canvas")
        ),
        conditionalPanel(
          condition = "input.mode == 'compare'",
          htmltools::div(class = "v3-canvas__inner", mod_batch_ui("batch", section = "results"))
        ),
        conditionalPanel(
          condition = "input.mode == 'method'",
          mod_v3_method_ui("method", section = "body")
        )
      )
    )
  )
)


# =============================================================================
# SERVER
# =============================================================================

server <- function(input, output, session) {

  # ---- the ONE shared state object ---------------------------------------
  # The same closed field list as the baseline's app.R, because the shared
  # engine reads it: ca_expert_state(), ca_reset_assessment(), ca_has_tests(),
  # ca_status_line(), ca_last_obs_censored() and mod_batch_server() all take
  # this object and address these names.
  state <- reactiveValues(
    nav = "assess", dark = FALSE,
    raw = NULL, label = NULL, source = NULL, map = NULL, dropped = NULL,
    prepared = NULL, fit = NULL, assess = NULL,
    include_lognormal = FALSE, alpha = 0.05, alpha_tests = NULL,
    tau_result = NULL, batch = NULL,
    expert_q1 = "", expert_q2 = "", expert_confirmed = FALSE,
    status = "empty", last_error = NULL,
    # v3-local, and the only field this version adds: the verbatim message from
    # a failed report render. The strip writes it; the control pane's Take away
    # section shows it. It is not an assessment field, so ca_reset_assessment()
    # correctly leaves it alone.
    report_error = NULL
  )

  # ---- the mode, mirrored into state$nav ---------------------------------
  observeEvent(input$mode, {
    state$nav <- if (is.null(input$mode)) "assess" else input$mode
  }, ignoreInit = FALSE)

  # ---- light / dark -------------------------------------------------------
  observeEvent(input$ca_mode, {
    state$dark <- identical(input$ca_mode, "dark")
  }, ignoreInit = FALSE)

  # ---- the dataset name in the top bar ------------------------------------
  output$ds_name <- renderText({
    if (is.null(state$label)) "" else as.character(state$label)
  })

  # ---- the progress announcement (helpers.R F.24 owns the wording) --------
  output$ca_status <- renderText(ca_status_line(state))

  # ---- the module servers -------------------------------------------------
  # mod_v3_controls_server owns everything that writes to state: the dataset,
  # the mapping, the two expert answers, the candidate set, the alpha re-calls,
  # and the two automatic computations of §B.2 and §B.3. It returns the
  # reactives the canvas needs but cannot reach across a module boundary.
  ctl <- mod_v3_controls_server("ctl", state)

  mod_v3_strip_server("strip", state)
  mod_v3_canvas_server("canvas", state, receus_dist = ctl$receus_dist)
  mod_v3_method_server("method", state)

  # Compare is not a v3 module (§G.2): it mounts the shared batch engine, whose
  # chooser and results sections are placed in the two panes above.
  mod_batch_server("batch", state, go_to = NULL)

  invisible(NULL)
}

shinyApp(ui, server)
