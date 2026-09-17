# =============================================================================
# app-v2/app.R — "The Verdict Page"          owner: builder-v2
#
# V2_CONTRACT §G.1. One page; the answer is the first thing on it, present from
# the moment a dataset is loaded. Everything below it exists to explain it and
# to let the reader attack it, in the order a sceptic asks:
#
#     who says so -> what data -> does the curve flatten -> which model won
#     -> do the diagnostics agree
#
# No tabs. No rail. No Run button, no Prepare button, no Re-run button. The
# only things the user does are load or choose data and map its columns, answer
# the two expert-judgment questions, and download.
#
# THIS VERSION OWNS ONLY ITS UI. Every number on screen comes from the shared
# engine in app/R/, sourced by R/aa_shared.R (§G.0) and never edited or copied.
# See README.md for the coupling statement.
#
# Run it with:  shiny::runApp("app-v2")   from the repository root.
# =============================================================================

suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
  library(DT)
  library(ggplot2)
})

# cureAssess is attached here, ONCE, exactly as the baseline does it: the
# installed package first, the vendored source as the fallback.
if (requireNamespace("cureAssess", quietly = TRUE)) {
  suppressPackageStartupMessages(library(cureAssess))
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

# ---- auto-load fallback ------------------------------------------------------
# Shiny sources app-v2/R/*.R alphabetically before this file, so aa_shared.R has
# already pulled in the shared engine. This block fires only when that did not
# happen (someone sourced app.R directly) and so can never double-source.
if (!exists("ca_bs_theme", mode = "function")) {
  .v2_rdir <- Filter(dir.exists, c(file.path("R"), file.path("app-v2", "R")))
  if (length(.v2_rdir) > 0L) {
    for (.f in sort(list.files(.v2_rdir[[1]], pattern = "\\.R$", full.names = TRUE))) source(.f)
    rm(.f)
  }
  rm(.v2_rdir)
}

# ---- the shared stylesheet and images, served, never copied (§G.0) ----------
shiny::addResourcePath("cashared", normalizePath(file.path(dirname(.ca_shared_dir), "www")))
# ca_docs_sections() references img/cureassess-qr.svg by that relative path, so
# the baseline's image directory is mounted under the name it expects. Nothing
# is copied into app-v2/www.
shiny::addResourcePath("img", normalizePath(file.path(dirname(.ca_shared_dir), "www", "img")))


# =============================================================================
# UI
# =============================================================================

.V2_ID <- "v"

# conditionalPanel conditions are JavaScript, and the mode switch lives inside
# a module, so its input id carries the module prefix. The single-dataset view
# tests for "not many" rather than "is one", so it is the view on screen during
# the moment before the client has echoed the radio back.
.V2_ONE  <- sprintf("input['%s-mode'] != 'many'", .V2_ID)
.V2_MANY <- sprintf("input['%s-mode'] == 'many'", .V2_ID)

ui <- bslib::page_fluid(
  theme = ca_bs_theme(),

  htmltools::tags$head(
    htmltools::tags$title("Is a cure model appropriate?"),
    # The shared stylesheet FIRST; v2.css only overrides layout.
    htmltools::tags$link(rel = "stylesheet", href = "cashared/app.css"),
    htmltools::tags$link(rel = "stylesheet", href = "v2.css")
  ),

  htmltools::div(
    class = "v2-root",

    # Two CSS-only overlays. A bare checkbox carries no Shiny binding, so these
    # are pure presentation: the drawer and the method view open and close with
    # no round trip to the server and no JavaScript.
    htmltools::tags$input(type = "checkbox", id = "v2-drawer-open",
                          class = "v2-toggle", hidden = NA),
    htmltools::tags$input(type = "checkbox", id = "v2-method-open",
                          class = "v2-toggle", hidden = NA),

    htmltools::div(
      class = "v2-flow",

      mod_v2_band_ui(.V2_ID),
      htmltools::div(class = "v2-sentinel"),
      mod_v2_bar_ui(.V2_ID),

      htmltools::tags$main(
        class = "v2-col",

        # 1. Your judgment — directly under the band, because answering it
        #    changes the band and the user should see that happen.
        mod_v2_expert_ui(.V2_ID),

        # 2-6, or the many-datasets view. One switch, one column.
        conditionalPanel(
          condition = .V2_ONE,
          mod_v2_data_ui(.V2_ID),
          mod_v2_evidence_ui(.V2_ID),
          mod_v2_takeaway_ui(.V2_ID)
        ),
        conditionalPanel(
          condition = .V2_MANY,
          mod_v2_many_ui(.V2_ID)
        )
      )
    ),

    mod_v2_drawer_ui(.V2_ID),
    mod_v2_method_ui(.V2_ID),

    # Progressive enhancement, and nothing depends on it. It reveals the
    # verdict in the sticky bar once the band has scrolled away (so the
    # headline is never printed twice on one screen) and builds the method
    # view's contents list. If it never runs, the bar simply keeps its dataset
    # name and the method view keeps its static contents line.
    htmltools::tags$script(htmltools::HTML("
(function () {
  function stickWatch() {
    var band = document.querySelector('.v2-sentinel');
    var bar  = document.querySelector('.v2-bar');
    if (!band || !bar || !('IntersectionObserver' in window)) return;
    new IntersectionObserver(function (e) {
      bar.classList.toggle('is-stuck', !e[0].isIntersecting);
    }, { threshold: 0 }).observe(band);
  }
  function toc() {
    var body = document.querySelector('.v2-method__body');
    var nav  = document.querySelector('.v2-method__toc');
    if (!body || !nav) return;
    var hs = body.querySelectorAll('h2, h3');
    if (!hs.length) return;
    var frag = document.createDocumentFragment();
    hs.forEach(function (h, i) {
      if (!h.id) h.id = 'v2-doc-' + i;
      var a = document.createElement('a');
      a.href = '#' + h.id;
      a.textContent = h.textContent;
      a.className = 'v2-method__toc-item v2-method__toc-item--' + h.tagName.toLowerCase();
      frag.appendChild(a);
    });
    nav.textContent = '';
    nav.appendChild(frag);
  }
  function go() { stickWatch(); toc(); }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', go);
  } else { go(); }
})();
"))
  )
)


# =============================================================================
# Server
# =============================================================================

server <- function(input, output, session) {

  # ---- the ONE shared state object ----------------------------------------
  # The same closed field list the baseline declares in app/app.R, minus `nav`,
  # which this version has no use for: there are no tabs to navigate between.
  # mod_batch_server() reads raw, label, source, map, include_lognormal and the
  # two expert answers off this object, so the shape is not optional.
  state <- reactiveValues(
    dark = FALSE,
    raw = NULL, label = NULL, source = NULL, map = NULL, dropped = NULL,
    prepared = NULL, fit = NULL, assess = NULL,
    include_lognormal = FALSE, alpha = 0.05, alpha_tests = NULL,
    tau_result = NULL, batch = NULL,
    expert_q1 = "", expert_q2 = "", expert_confirmed = FALSE,
    status = "empty", last_error = NULL
  )

  # ---- light / dark --------------------------------------------------------
  # Mirrors the bslib toggle; read by every plot builder. One writer.
  observeEvent(input$ca_mode, {
    state$dark <- identical(input$ca_mode, "dark")
  }, ignoreInit = FALSE)

  # ---- the module servers --------------------------------------------------
  # One id for all of them: this version is one page, so the namespace is one
  # namespace and every module reads and writes the same `state`.
  mod_v2_verdict_server(.V2_ID, state)
  mod_v2_data_server(.V2_ID, state)
  mod_v2_expert_server(.V2_ID, state)
  mod_v2_evidence_server(.V2_ID, state)
  mod_v2_method_server(.V2_ID, state)

  # Batch is NOT a v2 module (§G.1). The engine, the chooser, the table and the
  # CSV writer are all app/R/mod_batch.R's; this version mounts them in its own
  # chrome and re-implements none of it.
  mod_batch_server(paste0(.V2_ID, "-batch"), state, go_to = NULL)

  invisible(NULL)
}

shinyApp(ui, server)
