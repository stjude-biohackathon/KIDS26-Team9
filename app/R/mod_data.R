# ---------------------------------------------------------------------------
# mod_data.R — the Data tab (builder-tabs-a)
#
# Owns the only two package calls that turn a file into an analysable frame:
# contract I.1 (prepare.surv.data) and I.2 (model.fitting, plot_km = TRUE).
# The 0/1 recode (rule R3) happens app-side, in ca_clean_surv(), BEFORE either
# of those runs.
#
# Every statistical sentence on this screen is pasted verbatim from contract
# section J (J.1 the reading guide, J.2 the plateau callout, J.10 the error
# wording). Nothing statistical is written by the builder.
#
# Private helpers carry the `.data_` prefix per contract section F.
# ---------------------------------------------------------------------------


# ===========================================================================
# 1. PRIVATE HELPERS — parsing, column inspection, plot annotation
# ===========================================================================

#' Read one uploaded CSV, strictly
#'
#' Applies the `docs/data-contract.md` §9 rules before trusting the parse:
#' sniff the header line for a wrong delimiter, reject ragged rows by line
#' number, reject a one-column parse, strip a UTF-8 BOM, and clean
#' non-printing characters out of the column names.
#'
#' @param path a file path (Shiny's `datapath`)
#' @return `list(data, error, detail)` where `error` is one of `NULL`,
#'   `"unreadable"`, `"delimiter"`, `"onecol"`, `"ragged"`, `"parse"`, and
#'   `detail` carries the first line, the offending row number, or the raw
#'   parser message for the technical-detail block.
#' @noRd
.data_read_csv <- function(path) {
  bad <- function(err, detail = NULL) list(data = NULL, error = err, detail = detail)

  first <- tryCatch(
    readLines(path, n = 1L, warn = FALSE, encoding = "UTF-8"),
    error = function(e) character(0)
  )
  if (!length(first) || !nzchar(trimws(first[[1L]]))) return(bad("unreadable"))

  # a literal BOM in source is fragile, so build it rather than type it
  line1 <- sub(intToUtf8(65279L), "", first[[1L]], fixed = TRUE)

  # Wrong delimiter: no comma, but a semicolon or a tab. Do not silently retry
  # with another separator - a mangled one-column parse is the symptom users
  # find hardest to diagnose.
  if (!grepl(",", line1, fixed = TRUE) &&
      (grepl(";", line1, fixed = TRUE) || grepl("\t", line1, fixed = TRUE))) {
    return(bad("delimiter", line1))
  }

  nf <- tryCatch(
    utils::count.fields(path, sep = ",", quote = "\"", blank.lines.skip = TRUE),
    error = function(e) NULL
  )
  if (!is.null(nf) && length(nf) > 1L && !anyNA(nf) && any(nf != nf[[1L]])) {
    return(bad("ragged", which(nf != nf[[1L]])[[1L]]))
  }

  df <- tryCatch(
    utils::read.csv(
      path, header = TRUE, stringsAsFactors = FALSE,
      check.names = TRUE, fileEncoding = "UTF-8-BOM"
    ),
    error = function(e) e,
    warning = function(w) w
  )
  if (inherits(df, "condition")) return(bad("parse", conditionMessage(df)))
  if (!is.data.frame(df) || nrow(df) < 1L || ncol(df) < 1L) return(bad("unreadable"))
  if (ncol(df) == 1L) return(bad("onecol", line1))

  raw_names <- names(df)
  clean <- trimws(gsub("[^[:print:]]", "", raw_names))
  clean[!nzchar(clean)] <- raw_names[!nzchar(clean)]
  names(df) <- make.unique(clean)

  list(data = df, error = NULL, detail = if (!identical(raw_names, names(df))) "cleaned_names" else NULL)
}


#' Names of the numeric columns of a data frame
#' @noRd
.data_numeric_cols <- function(df) {
  if (!is.data.frame(df) || !ncol(df)) return(character(0))
  names(df)[vapply(df, is.numeric, logical(1))]
}


#' Distinct values of a status column, labelled with their row counts
#'
#' Produces the `selectInput` choices required by contract H.1 — the label is
#' the value and its count, e.g. `"1 (299 rows)"`, and the value passed on is
#' the bare level as a character string. `NA` is never offered: rows with a
#' missing status are dropped by `ca_clean_surv()`.
#'
#' @return a named character vector, possibly of length zero
#' @noRd
.data_level_choices <- function(x) {
  if (is.null(x)) return(character(0))
  v <- x[!is.na(x)]
  if (is.factor(v)) v <- as.character(v)
  v <- as.character(v)
  if (!length(v)) return(character(0))

  tb <- table(v)
  lv <- names(tb)
  cnt <- as.integer(tb)

  num <- suppressWarnings(as.numeric(lv))
  ord <- if (!anyNA(num)) order(num) else order(lv)
  lv <- lv[ord]
  cnt <- cnt[ord]

  stats::setNames(
    lv,
    sprintf("%s (%s rows)", lv, format(cnt, big.mark = ",", trim = TRUE))
  )
}


#' The registry entry for a built-in key, or NULL
#' @noRd
.data_registry_entry <- function(key) {
  if (is.null(key) || !nzchar(key)) return(NULL)
  if (!exists("CA_DATASETS")) return(NULL)
  CA_DATASETS[[key]]
}


#' Pull one column out of a frame without erroring when it is absent
#' @noRd
.data_col <- function(df, nm) {
  if (is.data.frame(df) && nm %in% names(df)) df[[nm]] else NULL
}


#' Annotate the package's own Kaplan-Meier plot
#'
#' Repaints `state$fit$kmplot` — it recomputes nothing. Four layers are added
#' on top of the curve the package drew, each one the visual counterpart of a
#' numbered check in the reading guide (contract J.1):
#'
#'   * the shaded follow-up-tail band, from the last event to the end of
#'     follow-up (check 6), drawn *under* the curve so it never hides a step;
#'   * the last-event-time marker, a dashed vertical rule (check 3);
#'   * the censored-in-tail count label (check 5);
#'   * the plateau guide, a dotted horizontal rule at the tail level (check 1).
#'
#' All tail numbers come from `ca_tail_facts()` (contract F.2) and the level
#' from `ca_tail_level()` (F.3, `1 - immune$p_hat`). Nothing is computed here.
#' When `zero_width` is TRUE — the largest observed time is an event — the band
#' and its label are omitted and the caller shows the J.1 check-6 explanation.
#'
#' The risk table (`sp$table`) is returned untouched, so printing the returned
#' object still renders the curve and the table together.
#'
#' @param sp a `ggsurvplot` object, or NULL
#' @param prepared `state$prepared`
#' @param tail_level numeric(1), the KM tail level, possibly `NA_real_`
#' @return the same object with `sp$plot` replaced, or `sp` unchanged on any
#'   failure
#' @noRd
.data_annotate_km <- function(sp, prepared, tail_level = NA_real_) {
  if (is.null(sp) || is.null(sp$plot) || !inherits(sp$plot, "ggplot")) return(sp)

  out <- tryCatch({
    p <- sp$plot
    facts <- ca_tail_facts(prepared)

    band_fill <- "#7a8390"
    mark_col <- "#b4532a"
    level_col <- "#2f6f6b"
    lab_fill <- "grey97"
    lab_col <- "grey15"

    if (!is.null(facts) && is.finite(facts$last_event)) {

      if (!isTRUE(facts$zero_width) && is.finite(facts$max_time)) {
        # Prepended, not appended: a full-height rect added on top of a
        # ggsurvplot would sit over the curve and the censoring ticks.
        band <- ggplot2::annotate(
          "rect",
          xmin = facts$last_event, xmax = facts$max_time,
          ymin = -Inf, ymax = Inf,
          fill = band_fill, alpha = 0.16
        )
        p$layers <- c(list(band), p$layers)

        # Anchored just inside the panel's right edge rather than on
        # max_time: the band always reaches the right of the plot, and a long
        # label placed on the data value itself clips when follow-up ends
        # close to the axis limit (nwtco).
        p <- p + ggplot2::annotate(
          "label",
          x = Inf, y = 0.97,
          label = sprintf(
            "follow-up tail: %s wide · %s censored, no events",
            ca_num(facts$gap, 2), format(facts$n_cens_after, big.mark = ",", trim = TRUE)
          ),
          hjust = 1.03, vjust = 1, size = 3.1,
          fill = lab_fill, colour = lab_col, linewidth = 0, alpha = 0.9
        )
      }

      p <- p +
        ggplot2::geom_vline(
          xintercept = facts$last_event,
          linetype = "22", linewidth = 0.6, colour = mark_col
        ) +
        ggplot2::annotate(
          "label",
          x = facts$last_event, y = 0.03,
          label = sprintf("last event  %s", ca_num(facts$last_event, 2)),
          hjust = 1.02, vjust = 0, size = 3.1,
          fill = lab_fill, colour = mark_col, linewidth = 0, alpha = 0.9
        )
    }

    if (is.finite(tail_level)) {
      p <- p +
        ggplot2::geom_hline(
          yintercept = tail_level,
          linetype = "dotted", linewidth = 0.6, colour = level_col
        ) +
        ggplot2::annotate(
          "label",
          x = 0, y = tail_level,
          label = sprintf("tail level S = %s", ca_num(tail_level, 4)),
          hjust = 0, vjust = -0.2, size = 3.1,
          fill = lab_fill, colour = level_col, linewidth = 0, alpha = 0.9
        )
    }

    sp$plot <- p
    sp
  }, error = function(e) sp)

  out
}


#' The legend for the annotated plot
#'
#' Names each added mark and points at the numbered check in the reading guide
#' it belongs to, so the plot and the guide share one vocabulary.
#'
#' @param facts `ca_tail_facts(state$prepared)`, possibly NULL
#' @param tail_level numeric(1), possibly `NA_real_`
#' @noRd
.data_km_legend <- function(facts, tail_level) {
  key <- function(swatch_style, name, text) {
    htmltools::tags$li(
      class = "ca-read__item",
      htmltools::tags$span(class = "ca-key", style = swatch_style),
      htmltools::tags$strong(name), " — ", text
    )
  }

  zero <- !is.null(facts) && isTRUE(facts$zero_width)

  band_text <- if (zero) {
    "not drawn for this dataset: the largest observed time is an event, so the tail has no width. See check 6."
  } else if (!is.null(facts)) {
    htmltools::tagList(
      "the follow-up tail: the stretch of time after the last event in which the study kept watching and nothing happened. It is ",
      htmltools::tags$strong(ca_num(facts$gap, 2)),
      " wide and holds ",
      htmltools::tags$strong(format(facts$n_cens_after, big.mark = ",", trim = TRUE)),
      " censored observations. This is check 6, and check 5 counts the ticks inside it."
    )
  } else {
    "the follow-up tail: the stretch of time after the last event in which the study kept watching and nothing happened. See check 6."
  }

  htmltools::tagList(
    htmltools::tags$ul(
      class = "ca-read",
      key("background:#7a8390;opacity:.30", "Shaded band", band_text),
      key(
        "background:#b4532a",
        "Dashed vertical rule",
        htmltools::tagList(
          "the last event time",
          if (!is.null(facts) && is.finite(facts$last_event)) {
            htmltools::tagList(", ", htmltools::tags$strong(ca_num(facts$last_event, 2)))
          },
          ". Everything to its right is censoring only. This is check 3."
        )
      ),
      key(
        "background:#2f6f6b",
        "Dotted horizontal rule",
        htmltools::tagList(
          "the tail level S",
          if (is.finite(tail_level)) {
            htmltools::tagList(" = ", htmltools::tags$strong(ca_num(tail_level, 4)))
          },
          ", the height the curve settles at. Read your rough cure fraction off it. This is check 1. It is the Kaplan-Meier level, not RECeUS π̂ — the two are close but they are different numbers."
        )
      ),
      key(
        "background:transparent;border:1px solid currentColor",
        "Ticks on the curve",
        "censored subjects. The risk table beneath the plot gives how many are still being watched at each time. This is check 4."
      )
    ),
    if (zero) {
      # Contract J.1, check 6 — the exact sentence for the degraded case.
      ca_note(
        "warning",
        "The follow-up tail has no width",
        htmltools::p(
          htmltools::tags$strong("Zero gap and there is no evidence at all"),
          ": if the largest observed time is an event the band has no width, and Maller-Zhou, ",
          htmltools::tags$code("qn"), " and Shen all return “cannot be computed” together."
        )
      )
    }
  )
}


#' The "How to read this curve" panel — contract J.1
#'
#' The seven numbered checks and the closing conjunction rule. The text is the
#' canonical constant from helpers.R, not a retyped copy, so this panel and the
#' Qualitative tab's cannot drift apart.
#' @noRd
.data_km_guide <- function() {
  # FIXPASS: was rendered beside the plot in a 5/12 column nested inside
  # layout_sidebar, which left the prose ~340px wide (about 20 characters a
  # line) and stretched the Data page past 10,000px. The full guide belongs to
  # the Qualitative step; here it is collapsed by default and constrained to a
  # readable measure.
  htmltools::div(
    class = "ca-km-guide",
    bslib::accordion(
      open = FALSE,
      bslib::accordion_panel(
        title = CA_COPY_KM_GUIDE_TITLE,
        htmltools::HTML(CA_COPY_KM_GUIDE_HTML)
      )
    )
  )
}


#' The plateau-is-not-proof callout — contract J.2
#'
#' Sits above the plot. Title and body are the canonical constants from
#' helpers.R; the title already carries its warning glyph.
#' @noRd
.data_plateau_note <- function() {
  ca_note("warning", CA_COPY_PLATEAU_TITLE, htmltools::HTML(CA_COPY_PLATEAU_HTML))
}


# ===========================================================================
# 2. UI
# ===========================================================================

#' Data tab UI
#'
#' Sidebar: source, dataset or upload, the four mapping controls, Prepare.
#' Main: messages, the six-number summary, the annotated Kaplan-Meier plot
#' beside its reading guide, and the `head()` preview.
#'
#' @param id module id, equal to the nav id `"data"`
#' @noRd
mod_data_ui <- function(id) {
  ns <- NS(id)

  builtin_choices <- stats::setNames(
    names(CA_DATASETS),
    vapply(CA_DATASETS, function(d) as.character(d$label), character(1))
  )

  controls <- bslib::sidebar(
    width = 330, open = "open", title = "Dataset",

    radioButtons(
      ns("source"), "Source",
      choices = c("Built-in example" = "builtin", "Upload a CSV" = "upload"),
      selected = "builtin"
    ),

    conditionalPanel(
      condition = "input.source == 'builtin'", ns = ns,
      selectInput(ns("builtin"), "Built-in dataset", choices = builtin_choices, selected = "gbsg")
    ),

    conditionalPanel(
      condition = "input.source == 'upload'", ns = ns,
      fileInput(ns("file"), "CSV file", accept = ".csv", multiple = FALSE),
      htmltools::p(
        class = "ca-provenance",
        "Comma-separated, one header row, decimal point. The file is read into this R session only."
      )
    ),

    htmltools::tags$hr(),

    selectInput(ns("col_time"), "Time column", choices = character(0)),
    selectInput(ns("col_status"), "Status column", choices = character(0)),
    selectInput(ns("event_level"), "Which value means the event?", choices = character(0)),

    radioButtons(
      ns("time_scale"), "Time scale",
      choices = c("Leave as supplied" = "none", "Days → years" = "days_to_years"),
      selected = "none"
    ),
    htmltools::p(
      class = "ca-provenance",
      "Choose days-to-years if your time column is recorded in days."
    ),

    actionButton(ns("prepare"), "Prepare data", class = "btn btn-primary")
  )

  htmltools::div(
    class = "ca-section",
    htmltools::tags$h1(class = "ca-section__title", "Load and prepare your data"),
    htmltools::p(
      class = "ca-lede",
      "Pick a built-in example or upload a CSV, tell the app which column is the time, which is the status and which value means the event, then press Prepare data. Everything downstream reads the prepared frame and nothing else."
    ),

    bslib::layout_sidebar(
      sidebar = controls,

      uiOutput(ns("data_msg")),
      uiOutput(ns("summary_card")),

      ca_card(
        title = "Kaplan-Meier curve, annotated",
        lede = "The package's own curve and risk table, with the follow-up tail, the last event and the tail level marked on it.",
        body = htmltools::tagList(
          .data_plateau_note(),
          # FIXPASS: the plot now takes the full content width and the reading
          # guide sits below it, collapsed. See .data_km_guide().
          htmltools::div(
            class = "ca-plot",
            plotOutput(ns("km_plot"), height = "560px"),
            uiOutput(ns("km_legend"))
          ),
          .data_km_guide(),
          htmltools::div(
            class = "ca-hero",
            actionButton(ns("to_qual_km"), "Work through the curve on the Qualitative step →", class = "btn btn-outline-primary")
          )
        )
      ),

      ca_card(
        title = "First rows of the prepared frame",
        lede = "Y and D are what every package function reads. Check that D is 1 where you meant the event.",
        body = DT::DTOutput(ns("head_table"))
      )
    )
  )
}


# ===========================================================================
# 3. SERVER
# ===========================================================================

#' Data tab server
#'
#' Writes `raw`, `label`, `source`, `map`, `dropped`, `prepared` and `fit`, and
#' drives the `"empty"` / `"data_loaded"` / `"prepared"` / `"error"` statuses.
#' Every transition begins with `ca_reset_assessment(state)` so no verdict can
#' outlive the frame that produced it (contract C.2).
#'
#' @param id module id, `"data"`
#' @param state the one shared `reactiveValues`
#' @param go_to the navigation callback from `app.R`
#' @noRd
mod_data_server <- function(id, state, go_to) {
  moduleServer(id, function(input, output, session) {

    # -- parsing the upload is a pure reactive, so the message panel can read
    # the failure without a second reactiveValues (contract C forbids one).
    upload_parsed <- reactive({
      f <- input$file
      if (is.null(f) || !nzchar(f$datapath)) return(NULL)
      .data_read_csv(f$datapath)
    })

    # ---------------------------------------------------------------------
    # 3.1 loading a dataset into state$raw
    # ---------------------------------------------------------------------

    #' Install a freshly loaded frame, per the contract C.1 "dataset changed"
    #' row: expert judgment is re-asked for the new population, and every
    #' derived object is cleared.
    set_raw <- function(raw, label, src) {
      ca_reset_assessment(state)
      state$raw <- raw
      state$label <- label
      state$source <- src
      state$map <- NULL
      state$dropped <- NULL
      state$prepared <- NULL
      state$fit <- NULL
      state$expert_confirmed <- FALSE
      state$expert_note <- ""
      state$visual_ack <- FALSE
      state$status <- "data_loaded"
      invisible(NULL)
    }

    #' Point the four mapping controls at a frame, using the registry defaults
    #' when there are any and sane fallbacks otherwise.
    refresh_mapping <- function(raw, entry = NULL) {
      num <- .data_numeric_cols(raw)
      all_cols <- names(raw)

      t_def <- if (!is.null(entry) && entry$time %in% num) entry$time
               else if (length(num)) num[[1L]] else NULL
      s_def <- if (!is.null(entry) && entry$status %in% all_cols) entry$status
               else if (length(all_cols)) all_cols[[1L]] else NULL

      updateSelectInput(session, "col_time", choices = num, selected = t_def)
      updateSelectInput(session, "col_status", choices = all_cols, selected = s_def)

      lv <- .data_level_choices(.data_col(raw, s_def))
      e_def <- if (!is.null(entry) && as.character(entry$event_level) %in% lv) {
        as.character(entry$event_level)
      } else if (length(lv)) lv[[1L]] else NULL
      updateSelectInput(session, "event_level", choices = lv, selected = e_def)

      ts_def <- if (!is.null(entry) && entry$time_scale %in% c("none", "days_to_years")) {
        entry$time_scale
      } else {
        "none"
      }
      updateRadioButtons(session, "time_scale", selected = ts_def)
      invisible(NULL)
    }

    load_builtin <- function(key) {
      entry <- .data_registry_entry(key)
      if (is.null(entry)) return(invisible(NULL))

      raw <- tryCatch(ca_dataset_load(key), error = function(e) e)
      if (inherits(raw, "condition")) {
        ca_reset_assessment(state)
        state$last_error <- conditionMessage(raw)
        state$status <- "error"
        return(invisible(NULL))
      }
      # tolerate a registry loader that wraps its frame in a list
      if (is.list(raw) && !is.data.frame(raw) && is.data.frame(raw$data)) raw <- raw$data
      if (!is.data.frame(raw)) return(invisible(NULL))

      set_raw(raw, as.character(entry$label), "builtin")
      refresh_mapping(raw, entry)
      invisible(entry)
    }

    observeEvent(input$builtin, {
      req(identical(input$source, "builtin"))
      load_builtin(input$builtin)
    }, ignoreInit = TRUE)

    observeEvent(input$source, {
      if (identical(input$source, "builtin")) {
        load_builtin(input$builtin)
      } else {
        up <- upload_parsed()
        if (!is.null(up) && is.null(up$error)) {
          set_raw(up$data, as.character(input$file$name), "upload")
          refresh_mapping(up$data, NULL)
        }
      }
    }, ignoreInit = TRUE)

    observeEvent(upload_parsed(), {
      up <- upload_parsed()
      req(!is.null(up))
      if (!is.null(up$error)) {
        # a bad file must not silently leave the previous dataset in place
        ca_reset_assessment(state)
        state$raw <- NULL
        state$label <- NULL
        state$source <- "upload"
        state$map <- NULL
        state$dropped <- NULL
        state$prepared <- NULL
        state$fit <- NULL
        state$status <- "empty"
        return(invisible(NULL))
      }
      set_raw(up$data, as.character(input$file$name), "upload")
      refresh_mapping(up$data, NULL)
    }, ignoreInit = TRUE)

    # Keep the event-level choices in step with the chosen status column. The
    # registry default wins while the status column is still the registry's
    # own; after that the user's pick is preserved when it remains valid.
    observeEvent(list(state$raw, input$col_status), {
      raw <- state$raw
      req(is.data.frame(raw))
      sc <- input$col_status
      if (is.null(sc) || !sc %in% names(raw)) return(invisible(NULL))

      lv <- .data_level_choices(raw[[sc]])
      entry <- if (identical(input$source, "builtin")) .data_registry_entry(input$builtin) else NULL
      want <- if (!is.null(entry) && identical(entry$status, sc)) as.character(entry$event_level) else NULL

      sel <- if (!is.null(want) && want %in% lv) want
             else if (!is.null(input$event_level) && input$event_level %in% lv) input$event_level
             else if (length(lv)) lv[[1L]] else NULL

      updateSelectInput(session, "event_level", choices = lv, selected = sel)
    }, ignoreInit = TRUE)

    # Contract C.1: a mapping change clears the verdict. "Changed" means
    # changed away from the mapping that produced state$prepared, so the echo
    # of our own updateSelectInput() calls is correctly a no-op.
    observeEvent(
      list(input$col_time, input$col_status, input$event_level, input$time_scale),
      {
        req(state$raw)
        m <- state$map
        if (!is.null(m) &&
            identical(m$time, input$col_time) &&
            identical(m$status, input$col_status) &&
            identical(m$event_level, as.character(input$event_level)) &&
            identical(m$time_scale, input$time_scale)) {
          return(invisible(NULL))
        }
        ca_reset_assessment(state)
      },
      ignoreInit = TRUE
    )

    # ---------------------------------------------------------------------
    # 3.2 pre-flight validation
    # ---------------------------------------------------------------------

    #' Everything that can be known about the current mapping without calling
    #' a package function. Returns the J.10 messages in priority order and
    #' whether Prepare must be refused.
    #' Everything knowable about the current mapping without calling a package
    #' function, and whether Prepare must be refused.
    #'
    #' `ca_clean_surv()` (helper F.17) is the single authority on which
    #' mappings are refusable and on the exact J.10 sentence for each: a
    #' non-numeric time column, a level matching no rows, negative or
    #' non-finite times, every row dropped, and zero events after dropping all
    #' come back in its `error`. Those sentences are surfaced here rather than
    #' retyped, so this panel cannot drift from the helper. Only the two things
    #' it does not cover are added: the reserved-name collision and the
    #' informational dropped-row count.
    preflight <- reactive({
      raw <- state$raw
      msg <- list()
      add <- function(kind, text, action_id = NULL, action_label = NULL) {
        msg[[length(msg) + 1L]] <<- list(
          kind = kind, text = text,
          action_id = action_id, action_label = action_label
        )
      }

      tc <- input$col_time
      sc <- input$col_status
      el <- input$event_level

      if (!is.data.frame(raw) || is.null(tc) || is.null(sc) || is.null(el) ||
          !tc %in% names(raw) || !sc %in% names(raw)) {
        return(list(block = TRUE, msg = msg, cleaned = NULL))
      }

      cleaned <- tryCatch(
        ca_clean_surv(raw, tc, sc, as.character(el)),
        error = function(e) list(data = NULL, dropped = NULL, error = conditionMessage(e))
      )

      if (!is.data.frame(cleaned$data)) {
        txt <- if (!is.null(cleaned$error)) cleaned$error else "Preparing the data failed."
        # the two refusals the user can escape with a control rather than by
        # editing the file
        if (grepl("nothing to analyse", txt, fixed = TRUE)) {
          add("error", txt, "go_upload", "Upload a different file")
        } else if (grepl("no events (or too few rows)", txt, fixed = TRUE)) {
          add("error", txt, "go_builtin", "Pick a built-in example")
        } else {
          add("error", txt)
        }
        return(list(block = TRUE, msg = msg, cleaned = cleaned))
      }

      # ---- non-blocking information, in the order the user meets it -------

      # docs/data-contract.md: prepare.surv.data() overwrites Y and D
      for (cc in intersect(c("Y", "D"), names(raw))) {
        add("warning", sprintf(
          "This file already has a column called `%s`. Preparing the data will overwrite it.", cc
        ))
      }

      drp <- cleaned$dropped
      if (!is.null(drp) && isTRUE(drp$n_total > drp$n_kept)) {
        add("info", sprintf(
          "Dropped %s of %s rows with a missing time or status (missing time: %s; missing status: %s). Every n shown in this app is the analysed n, after dropping.",
          format(drp$n_total - drp$n_kept, big.mark = ",", trim = TRUE),
          format(drp$n_total, big.mark = ",", trim = TRUE),
          format(drp$n_time_na, big.mark = ",", trim = TRUE),
          format(drp$n_status_na, big.mark = ",", trim = TRUE)
        ))
      }

      list(block = FALSE, msg = msg, cleaned = cleaned)
    })

    observe({
      updateActionButton(session, "prepare", disabled = isTRUE(preflight()$block))
    })

    # ---------------------------------------------------------------------
    # 3.3 preparation — contract I.1 then I.2
    # ---------------------------------------------------------------------

    #' Run the R3 recode, then the two package calls, then write state.
    #'
    #' Takes its mapping explicitly rather than reading `input$` so the launch
    #' auto-prepare can run before the client has echoed the control values
    #' back. Everything is inside one `tryCatch`: a red Shiny stack trace on
    #' this tab is a bug.
    do_prepare <- function(time_col, status_col, event_level, time_scale) {
      ca_reset_assessment(state)                       # contract C.2, first statement

      raw <- state$raw
      if (!is.data.frame(raw)) return(invisible(NULL))
      event_level <- as.character(event_level)

      fail <- function(m) {
        state$prepared <- NULL
        state$fit <- NULL
        state$last_error <- m
        state$status <- "error"
        invisible(NULL)
      }

      cleaned <- tryCatch(
        ca_clean_surv(raw, time_col, status_col, event_level),
        error = function(e) list(data = NULL, dropped = NULL, error = conditionMessage(e))
      )
      if (!is.data.frame(cleaned$data)) {
        return(fail(if (!is.null(cleaned$error)) cleaned$error else "ca_clean_surv() returned no data."))
      }

      d01 <- .data_col(cleaned$data, "..D01")
      # Contract I: refuse before the package is called at all. Zero events
      # makes MZ/Shen return 1, qn return 0 with warnings, and RECeUS throw.
      if (nrow(cleaned$data) < 2L || is.null(d01) || sum(d01 == 1L, na.rm = TRUE) == 0L) {
        return(fail("This dataset has no events (or too few rows) to assess. Cure-model diagnostics need both events and censored observations."))
      }

      res <- tryCatch(
        withProgress(message = "Preparing data", value = 0, {
          incProgress(0.2, detail = "Standardising Y and D")
          prepared <- cureAssess::prepare.surv.data(       # contract I.1
            data = cleaned$data,
            time = "..Y_raw",
            status = "..D01",
            time_scale = time_scale
          )
          incProgress(0.3, detail = "Fitting candidate models for the Kaplan-Meier plot")
          # suppressMessages(): survminer's ggsurvplot emits the cosmetic
          # ggplot2 4.x note 'Ignoring unknown labels: fill "Strata"' while it
          # builds the risk table. Nothing statistical is suppressed - warnings
          # and errors still propagate.
          fit <- suppressMessages(cureAssess::model.fitting(  # contract I.2
            data = prepared,
            plot_km = TRUE,
            include_lognormal = FALSE
          ))
          incProgress(0.5, detail = "Done")
          list(prepared = prepared, fit = fit)
        }),
        error = function(e) e
      )

      if (inherits(res, "condition")) return(fail(conditionMessage(res)))

      state$map <- list(
        time = time_col, status = status_col,
        event_level = event_level, time_scale = time_scale
      )
      state$dropped <- cleaned$dropped
      state$prepared <- res$prepared
      state$fit <- res$fit
      state$last_error <- NULL
      state$status <- "prepared"
      invisible(NULL)
    }

    #' The Prepare action, shared by the sidebar button and by the Prepare
    #' button the empty states offer. Two controls, two distinct input ids,
    #' one code path.
    prepare_now <- function() {
      if (isTRUE(preflight()$block)) return(invisible(NULL))
      do_prepare(input$col_time, input$col_status, input$event_level, input$time_scale)
    }

    ca_on_click(input, "prepare", function() prepare_now())
    # FIXPASS (finding 3.1): every empty state used to emit its Prepare button
    # under the single id "prepare_go", so up to three DOM elements shared one
    # input id. Each actionButton binding keeps its own counter starting at 0,
    # so a click on the second or third of them sent the same value the first
    # had already sent — not an increment — and ca_on_click()'s strict-increment
    # guard correctly refused to fire. Two of the three visible buttons were
    # dead. Each empty state now carries its own id; all four are registered
    # here against the one handler.
    ca_on_click(input, "prepare_go_empty", function() prepare_now())
    ca_on_click(input, "prepare_go_loaded", function() prepare_now())
    ca_on_click(input, "prepare_go_summary", function() prepare_now())
    ca_on_click(input, "prepare_go_km", function() prepare_now())

    # the two shortcuts the error states offer
    ca_on_click(input, "go_builtin", function() updateRadioButtons(session, "source", selected = "builtin"))
    ca_on_click(input, "go_upload", function() updateRadioButtons(session, "source", selected = "upload"))

    # Launch auto-prepare of gbsg (contract C.1) so the first screen a user
    # sees carries a real summary card and a real curve.
    observeEvent(TRUE, {
      entry <- load_builtin("gbsg")
      if (is.null(entry)) return(invisible(NULL))
      do_prepare(entry$time, entry$status, as.character(entry$event_level), entry$time_scale)
    }, once = TRUE, ignoreInit = FALSE)

    ca_on_click(input, "to_qual_km", function() go_to("qual"))

    # ---------------------------------------------------------------------
    # 3.4 messages
    # ---------------------------------------------------------------------

    output$data_msg <- renderUI({
      pf <- preflight()
      items <- pf$msg
      out <- list()

      # upload-time parse failures first: without a frame nothing else applies
      up <- upload_parsed()
      if (identical(input$source, "upload") && !is.null(up) && !is.null(up$error)) {
        out[[length(out) + 1L]] <- switch(
          up$error,
          unreadable = ca_note(
            "warning", "That file could not be read",
            htmltools::p("That file could not be read as CSV. Check that it is comma-separated with a header row.")
          ),
          parse = ca_note(
            "warning", "That file could not be read",
            htmltools::tagList(
              htmltools::p("That file could not be read as CSV. Check that it is comma-separated with a header row."),
              ca_tech(htmltools::tags$pre(up$detail))
            )
          ),
          delimiter = ca_note(
            "warning", "Wrong delimiter",
            htmltools::tagList(
              htmltools::p("This file looks semicolon-delimited, not comma-delimited. Please save it as a comma-separated CSV and upload again."),
              ca_tech(htmltools::tags$pre(up$detail), title = "The first line of the file")
            )
          ),
          onecol = ca_note(
            "warning", "Wrong delimiter",
            htmltools::tagList(
              htmltools::p("This file looks semicolon-delimited, not comma-delimited. Please save it as a comma-separated CSV and upload again."),
              htmltools::p("Only one column was found, which usually means the delimiter is wrong."),
              ca_tech(htmltools::tags$pre(up$detail), title = "The first line of the file")
            )
          ),
          ragged = ca_note(
            "warning", "Ragged rows",
            htmltools::p(sprintf(
              "Row %s has a different number of fields from the header. Fix the file and upload again.",
              format(up$detail, trim = TRUE)
            ))
          ),
          ca_note("warning", "That file could not be read",
                  htmltools::p("That file could not be read as CSV. Check that it is comma-separated with a header row."))
        )
      } else if (identical(input$source, "upload") && !is.null(up) &&
                 identical(up$detail, "cleaned_names")) {
        out[[length(out) + 1L]] <- ca_note(
          "info", "Column names were cleaned",
          htmltools::p("Some column names contained non-printing characters, which were removed so the dropdowns match the file.")
        )
      }

      # FIXPASS (finding 3.4): this generic empty state used to render
      # alongside the error note whenever loading a built-in dataset failed —
      # status is "error" and state$raw is NULL at the same time — so the user
      # met two blocks at once and the actionable one was the second. When an
      # error is already on screen the generic sentence is suppressed.
      # FIXPASS (finding 3.1): own input id, was the shared "prepare_go".
      if ((identical(state$status, "empty") || is.null(state$raw)) &&
          !identical(state$status, "error")) {
        out[[length(out) + 1L]] <- ca_empty(
          "Pick a built-in example or upload a CSV, then press Prepare data.",
          action_id = session$ns("prepare_go_empty"), action_label = "Prepare data"
        )
      }

      for (m in items) {
        title <- switch(m$kind, error = "This mapping cannot be prepared",
                        warning = "Check this before you prepare", "For your information")
        variant <- switch(m$kind, error = "warning", warning = "warning", "info")
        body <- htmltools::tagList(
          htmltools::p(m$text),
          if (!is.null(m$action_id)) {
            htmltools::div(
              class = "ca-empty__action",
              actionButton(session$ns(m$action_id), m$action_label, class = "btn btn-outline-secondary btn-sm")
            )
          },
        )
        out[[length(out) + 1L]] <- ca_note(variant, title, body)
      }

      if (identical(state$status, "error") && !is.null(state$last_error)) {
        le <- state$last_error
        sentence <- if (grepl("`Y` must be numeric", le, fixed = TRUE)) {
          "The time column you chose is not numeric. Pick a numeric column."
        } else if (grepl("`D` must be coded as 0/1", le, fixed = TRUE)) {
          "The event indicator could not be reduced to 0/1. Check which level you marked as the event."
        } else if (grepl("is missing", le, fixed = TRUE)) {
          # FIXPASS (finding 3.4): a missing data/examples/*.csv failed
          # ca_dataset_load() and fell through to the generic sentence, burying
          # the only actionable instruction — datasets.R's regeneration command
          # — inside the collapsed technical-detail block. The package's own
          # message is the visible sentence here; it names the file and the
          # command that rebuilds it.
          le
        } else {
          "Preparing the data failed."
        }
        out[[length(out) + 1L]] <- ca_note(
          "warning", "Preparing the data failed",
          htmltools::tagList(htmltools::p(sentence), ca_tech(htmltools::tags$pre(le)))
        )
      }

      if (identical(state$status, "data_loaded") && !is.null(state$raw) && !isTRUE(pf$block)) {
        out[[length(out) + 1L]] <- ca_empty(
          "Columns loaded. Choose your time column, your status column, and which value means the event — then press Prepare data.",
          # FIXPASS (finding 3.1): own input id, was the shared "prepare_go".
          action_id = session$ns("prepare_go_loaded"), action_label = "Prepare data"
        )
      }

      if (!length(out)) return(NULL)
      htmltools::tagList(out)
    })

    # ---------------------------------------------------------------------
    # 3.5 the six-number summary
    # ---------------------------------------------------------------------

    output$summary_card <- renderUI({
      prepared <- state$prepared
      if (!is.data.frame(prepared)) {
        return(ca_card(
          title = "Summary of the prepared data",
          body = ca_empty(
            "Nothing is prepared yet. Press Prepare data to see the six descriptive numbers.",
            # FIXPASS (finding 3.1): own input id, was the shared "prepare_go".
            action_id = session$ns("prepare_go_summary"), action_label = "Prepare data"
          )
        ))
      }

      s <- tryCatch(ca_data_summary(prepared), error = function(e) NULL)
      if (is.null(s)) {
        return(ca_card(
          title = "Summary of the prepared data",
          body = ca_empty("The summary could not be computed for this frame.")
        ))
      }

      unit <- if (identical(state$map$time_scale, "days_to_years")) "years" else "time units as supplied"
      stale <- !identical(state$status, "prepared") && !identical(state$status, "assessed")

      # FIXPASS (finding 3.3): changing the time column, the status column, the
      # event level or the time scale deliberately keeps the previously
      # prepared frame rather than silently discarding it — but the only signal
      # that the numbers below no longer match the sidebar was the `is-stale`
      # opacity change, which is colour and colour alone. A reader who cannot
      # see that change, or is not looking for it, reads these counts as the
      # current mapping's. The sentence says so in words. It is gated on
      # status == "data_loaded", the mapping-changed state, so a failed Run on
      # the Quantitative step (status "error", prepared still valid) does not
      # claim the mapping moved.
      mapping_changed <- identical(state$status, "data_loaded")

      ca_card(
        title = "Summary of the prepared data",
        # One HTML string, not a tagList: htmltools puts each child of a
        # tagList on its own line, and the browser collapses that newline into
        # a space, which printed "in years ." with a gap before the stop.
        lede = htmltools::HTML(paste0(
          "Descriptive counts on the prepared frame &mdash; not cure-model ",
          "statistics. Time is in <strong>", htmltools::htmlEscape(unit), "</strong>.",
          if (mapping_changed) {
            paste0(
              " <strong>Showing the previously prepared mapping.</strong> ",
              "Press Prepare data to apply your change."
            )
          } else {
            ""
          }
        )),
        chip = ca_chip("neutral", if (is.null(state$label)) "dataset" else state$label),
        body = htmltools::div(
          class = paste("ca-statrow", if (stale) "is-stale" else ""),
          ca_kv("n analysed", format(s$n, big.mark = ",", trim = TRUE),
                "rows kept after dropping a missing time or status"),
          ca_kv("events", format(s$events, big.mark = ",", trim = TRUE),
                "rows with D = 1"),
          ca_kv("censored", paste0(ca_num(s$censored_pct, 1), "%"),
                "share of rows with D = 0"),
          ca_kv("median follow-up", ca_num(s$median_followup, 3),
                "median of observed follow-up times, all subjects"),
          ca_kv("max follow-up", ca_num(s$max_followup, 3),
                "largest observed time, event or censored"),
          ca_kv("last event time", ca_num(s$last_event_time, 3),
                "largest time at which an event occurred")
        ),
        foot = if (!is.null(state$dropped)) {
          htmltools::p(class = "ca-provenance", sprintf(
            "%s rows in the file, %s analysed.",
            format(state$dropped$n_total, big.mark = ",", trim = TRUE),
            format(state$dropped$n_kept, big.mark = ",", trim = TRUE)
          ))
        }
      )
    })

    # ---------------------------------------------------------------------
    # 3.6 the annotated Kaplan-Meier plot and its legend
    # ---------------------------------------------------------------------

    #' The KM tail level, from the package's immune summary.
    #'
    #' Contract I.3: read `state$assess$tests$immune` when the assessment has
    #' run, otherwise call `immune.test()` here. `ca_tail_level()` is the
    #' permitted subtraction `1 - p_hat`, and the result is the Kaplan-Meier
    #' level, never RECeUS pi-hat.
    tail_level <- reactive({
      prepared <- state$prepared
      if (!is.data.frame(prepared)) return(NA_real_)
      imm <- if (ca_has_tests(state)) {
        state$assess$tests$immune
      } else {
        tryCatch(cureAssess::immune.test(dat = prepared), error = function(e) NULL)
      }
      if (is.null(imm)) return(NA_real_)
      tryCatch(ca_tail_level(imm), error = function(e) NA_real_)
    })

    output$km_plot <- renderPlot({
      sp <- state$fit$kmplot
      validate(need(
        !is.null(sp),
        "The Kaplan-Meier plot is missing. Press Prepare data again."
      ))

      # theme.R owns the repaint; call it only if builder-css shipped it.
      if (exists("ca_style_survplot", mode = "function")) {
        sp <- tryCatch(ca_style_survplot(sp), error = function(e) sp)
      }
      sp <- .data_annotate_km(sp, state$prepared, tail_level())

      # survminer emits a cosmetic "Ignoring unknown labels" message at print.
      suppressWarnings(suppressMessages(print(sp)))
    }, res = 104)

    output$km_legend <- renderUI({
      prepared <- state$prepared
      if (!is.data.frame(prepared) || is.null(state$fit$kmplot)) {
        return(ca_empty(
          "The Kaplan-Meier plot is missing. Press Prepare data again.",
          # FIXPASS (finding 3.1): own input id, was the shared "prepare_go".
          action_id = session$ns("prepare_go_km"), action_label = "Prepare data"
        ))
      }
      facts <- tryCatch(ca_tail_facts(prepared), error = function(e) NULL)
      .data_km_legend(facts, tail_level())
    })

    # ---------------------------------------------------------------------
    # 3.7 head() preview, Y and D first
    # ---------------------------------------------------------------------

    output$head_table <- DT::renderDT({
      prepared <- state$prepared
      validate(need(is.data.frame(prepared), "Press Prepare data to see the first rows."))

      d <- utils::head(prepared, 10L)
      # the two scratch columns ca_clean_surv() adds are exact duplicates of
      # Y and D, so they are dropped from the preview only
      d <- d[, setdiff(names(d), c("..Y_raw", "..D01")), drop = FALSE]
      ord <- c(intersect(c("Y", "D"), names(d)), setdiff(names(d), c("Y", "D")))
      d <- d[, ord, drop = FALSE]

      DT::datatable(
        d,
        rownames = FALSE,
        class = "compact stripe",
        options = list(dom = "t", ordering = FALSE, scrollX = TRUE, pageLength = 10L)
      )
    })

    invisible(NULL)
  })
}
