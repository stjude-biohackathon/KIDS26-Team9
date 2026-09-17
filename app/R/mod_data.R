# ---------------------------------------------------------------------------
# mod_data.R — the Data tab (rewriter-data)
#
# Owns the only two package calls that turn a file into an analysable frame:
# BUILD_CONTRACT I.1 (prepare.surv.data) and I.2 (model.fitting, plot_km =
# TRUE). The 0/1 recode (rule R3) happens app-side, in ca_clean_surv(), BEFORE
# either of those runs, and time is scaled exactly once, inside I.1.
#
# REVISION_CONTRACT v2.0 §E.2 stripped this screen to the data summary and the
# preview table. Deleted here this pass: the annotated Kaplan-Meier card and
# every figure (#6), .data_annotate_km() (#7), the plot legend (#8), the "How to
# read this curve" accordion (#9), the plateau callout (#10), the zero-width
# tail warning (#11), the "Work through the curve" button (#12), all four
# main-panel Prepare buttons and the message-builder action arguments that
# emitted them (#13), the page lede (#14) and the two card ledes (#15, #16).
# Visual assessment now lives entirely on the Qualitative tab.
#
# V2_CONTRACT §B deletes the last button on this screen. The sidebar is now
# source radio, built-in select, file input, the four mapping controls and the
# two small-print hints — and nothing else. Preparation is automatic: the
# 5-tuple (source/upload, time, status, event level, time scale) is debounced by
# 600 ms and prepares itself, so no keystroke through the mapping controls costs
# a fit and nothing on any tab is ever stale (§B.1 reactives 1 and 3, §B.6).
#
# FIELD PROVENANCE (REVISION_CONTRACT G2 — kept in code, never on screen):
#   * state$prepared  <- cureAssess::prepare.surv.data() return    (I.1)
#   * state$fit       <- cureAssess::model.fitting() return, incl. $kmplot,
#                        which the Qualitative tab draws              (I.2)
#   * state$dropped   <- ca_clean_surv()$dropped, app-side counts only
#   The six numbers in the summary card are ca_data_summary(prepared)
#   (helpers.R F.1) — descriptive counts, the only app-side computation this
#   file performs. No inferential statistic is computed or read here. The
#   tail-level read that used to sit in this file (the old tail_level() reactive
#   and the KM annotation) is gone: per REVISION_CONTRACT §F, mod_qualitative.R
#   is now the only file permitted to read that package object at all.
#
# Every visible sentence is pasted from REVISION_CONTRACT §G.3 or §G.9. Nothing
# statistical is written here.
#
# Private helpers carry the `.data_` prefix.
# ---------------------------------------------------------------------------


# ===========================================================================
# 1. PRIVATE HELPERS — parsing, column inspection, message wording
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
#' Produces the `selectInput` choices required by BUILD_CONTRACT H.1 — the
#' label is the value and its count, e.g. `"1 (299 rows)"`, and the value
#' passed on is the bare level as a character string. `NA` is never offered:
#' rows with a missing status are dropped by `ca_clean_surv()`.
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


#' The one short sentence for a refusal — REVISION_CONTRACT §G.9, Data
#'
#' `ca_clean_surv()` (helpers.R F.17) is the single authority on which mappings
#' are refusable. Its own messages are longer than §G.9 allows, so they are
#' mapped here to the contract's one-line wording. The raw text is never
#' discarded: the caller puts it verbatim in `ca_tech()` underneath.
#'
#' Anything unrecognised falls to the contract's catch-all row. That is
#' deliberate — it also keeps a package message that names a file path or a
#' regeneration command off the screen (G2) while leaving it readable in the
#' technical-detail block.
#'
#' @param txt the raw refusal text, from `ca_clean_surv()$error` or a condition
#' @return character(1), one of the §G.9 sentences
#' @noRd
.data_sentence <- function(txt) {
  if (is.null(txt) || !length(txt)) return("Preparing the data failed.")
  txt <- as.character(txt)[[1L]]

  if (grepl("not numeric", txt, fixed = TRUE) ||
      grepl("`Y` must be numeric", txt, fixed = TRUE)) {
    return("The time column is not numeric. Pick a numeric column.")
  }
  if (grepl("No rows have that value", txt, fixed = TRUE)) {
    return("No rows have that value, so there would be no events. Pick another.")
  }
  if (grepl("negative or not finite", txt, fixed = TRUE)) {
    k <- sub(".*\\(([0-9]+) rows\\).*", "\\1", txt)
    if (identical(k, txt)) k <- NULL
    return(sprintf(
      "%s rows have a negative or non-finite time. Fix the file and upload again.",
      if (is.null(k)) "Some" else k
    ))
  }
  if (grepl("nothing to analyse", txt, fixed = TRUE)) {
    return("Every row has a missing time or status, so there is nothing to analyse.")
  }
  if (grepl("no events (or too few rows)", txt, fixed = TRUE)) {
    return("These data have no events, so there is nothing to assess.")
  }
  "Preparing the data failed."
}


# ===========================================================================
# 2. UI
# ===========================================================================

#' Data tab UI
#'
#' Sidebar: source, dataset or upload, the four mapping controls. No button:
#' the mapping prepares itself (§B.2). Main: messages, the data summary, the
#' preview table. No figures — visual assessment is the Qualitative tab's job
#' (REVISION_CONTRACT §E.2).
#'
#' @param id module id, equal to the nav id `"data"`
#' @noRd
mod_data_ui <- function(id) {
  ns <- NS(id)

  # INTEGRATION FIX: the picker was a flat list of all nineteen names, even
  # though datasets.R carries a `family` on every entry and its own header says
  # "the picker groups ... so the list never becomes a flat wall of names".
  # Both alternative versions group; the baseline now does too, from the same
  # registry field, in CA_DATASET_FAMILIES order. A named list of named vectors
  # is what selectInput() turns into <optgroup>s.
  builtin_choices <- local({
    fams <- if (exists("CA_DATASET_FAMILIES")) CA_DATASET_FAMILIES else character(0)
    lab  <- function(k) as.character(CA_DATASETS[[k]]$label)
    grouped <- list()
    for (f in fams) {
      keys <- Filter(function(k) identical(CA_DATASETS[[k]]$family, f), names(CA_DATASETS))
      if (length(keys)) grouped[[f]] <- stats::setNames(keys, vapply(keys, lab, character(1)))
    }
    # Any entry whose family is missing from the list still has to be reachable.
    placed <- unlist(grouped, use.names = FALSE)
    rest   <- setdiff(names(CA_DATASETS), placed)
    if (length(rest)) grouped[["Other"]] <- stats::setNames(rest, vapply(rest, lab, character(1)))
    if (!length(grouped)) {
      stats::setNames(names(CA_DATASETS),
                      vapply(names(CA_DATASETS), lab, character(1)))
    } else grouped
  })

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
        "Comma-separated, one header row, decimal point. The file is read into this session only."
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
    )
  )

  htmltools::div(
    class = "ca-section",
    # §G.3: page title is one word, and there is no lede.
    htmltools::tags$h1(class = "ca-section__title", "Data"),

    bslib::layout_sidebar(
      sidebar = controls,

      uiOutput(ns("data_msg")),
      uiOutput(ns("summary_card")),

      ca_card(
        title = "Data preview",
        body = htmltools::tagList(
          DT::DTOutput(ns("head_table")),
          # §G.3, verbatim, and the only sentence under the table.
          htmltools::p(
            class = "ca-provenance",
            "Check that the time column and the event indicator are the ones you meant."
          )
        )
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
#' outlive the frame that produced it (BUILD_CONTRACT C.2).
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

    #' Install a freshly loaded frame, per the REVISION_CONTRACT §C.3
    #' "dataset changed" row: expert judgment is re-asked for the new
    #' population, and every derived object is cleared.
    set_raw <- function(raw, label, src) {
      ca_reset_assessment(state)
      state$raw <- raw
      state$label <- label
      state$source <- src
      state$map <- NULL
      state$dropped <- NULL
      state$prepared <- NULL
      state$fit <- NULL
      # §C.3: a clinician confirmed plausibility for THAT population, not for
      # every population, so both answers and the derived flag are cleared.
      # mod_expert.R is the only writer of these three fields thereafter.
      state$expert_q1 <- ""
      state$expert_q2 <- ""
      state$expert_confirmed <- FALSE
      state$status <- "data_loaded"
      invisible(NULL)
    }

    #' A first guess at the mapping for a file the registry has never seen.
    #'
    #' INTEGRATION FIX. The fallback used to be "the first numeric column is the
    #' time and the FIRST column is the status", which on an ordinary two-column
    #' `time,status` upload proposes the TIME column as the status column and
    #' then picks the smallest time value as the event level. The app went on to
    #' print a confident verdict on a dataset it had read as one event and 99.8%
    #' censored. app-v2 had already worked around this locally; the heuristic is
    #' lifted here so the baseline and both alternatives map an upload the same
    #' way.
    #'
    #' It is a SUGGESTION, never a decision: all four controls stay under the
    #' user's hand, and nothing here inspects a value to decide anything - it
    #' reads column NAMES and counts distinct values, exactly the class of work
    #' the registry defaults already do for the built-in examples.
    #' @noRd
    .guess_map <- function(raw) {
      cols <- names(raw)
      num  <- .data_numeric_cols(raw)
      norm <- function(x) tolower(gsub("[^a-z0-9]", "", tolower(x)))
      n_lv <- function(nm) length(unique(raw[[nm]][!is.na(raw[[nm]])]))

      time_like   <- c("time", "y", "t", "futime", "survtime", "os", "pfs",
                       "rfstime", "edrel")
      status_like <- c("status", "d", "event", "cens", "censor", "died",
                       "death", "rel", "delta")

      pick <- function(candidates, wanted) {
        hit <- candidates[norm(candidates) %in% wanted]
        if (length(hit)) hit[[1L]] else NULL
      }

      tcol <- pick(num, time_like)
      if (is.null(tcol)) tcol <- if (length(num)) num[[1L]] else NULL

      rest <- setdiff(cols, tcol)
      scol <- pick(rest, status_like)
      if (is.null(scol)) {
        two <- rest[vapply(rest, function(nm) n_lv(nm) == 2L, logical(1))]
        scol <- if (length(two)) two[[1L]] else if (length(rest)) rest[[1L]] else NULL
      }
      list(time = tcol, status = scol)
    }

    #' Point the four mapping controls at a frame, using the registry defaults
    #' when there are any and the name/level heuristic above otherwise.
    refresh_mapping <- function(raw, entry = NULL) {
      num <- .data_numeric_cols(raw)
      all_cols <- names(raw)
      guess <- if (is.null(entry)) .guess_map(raw) else list(time = NULL, status = NULL)

      t_def <- if (!is.null(entry) && entry$time %in% num) entry$time
               else if (!is.null(guess$time)) guess$time
               else if (length(num)) num[[1L]] else NULL
      s_def <- if (!is.null(entry) && entry$status %in% all_cols) entry$status
               else if (!is.null(guess$status)) guess$status
               else if (length(all_cols)) all_cols[[1L]] else NULL

      updateSelectInput(session, "col_time", choices = num, selected = t_def)
      updateSelectInput(session, "col_status", choices = all_cols, selected = s_def)

      lv <- .data_level_choices(.data_col(raw, s_def))
      e_def <- if (!is.null(entry) && as.character(entry$event_level) %in% lv) {
        as.character(entry$event_level)
      } else if (is.null(entry) && "1" %in% lv) {
        # An uploaded 0/1 column means 1 = event far more often than it means
        # 1 = censored, and the control is one click away either way.
        "1"
      } else if (length(lv)) lv[[length(lv)]] else NULL
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

    # BUILD_CONTRACT C.1: a mapping change clears the verdict. "Changed" means
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

    #' Everything knowable about the current mapping without calling a package
    #' function, and whether preparing must be refused.
    #'
    #' `ca_clean_surv()` (helpers.R F.17) is the single authority on which
    #' mappings are refusable: a non-numeric time column, a level matching no
    #' rows, negative or non-finite times, every row dropped, and zero events
    #' after dropping all come back in its `error`. Its text is mapped to the
    #' §G.9 one-liner by `.data_sentence()` and carried verbatim underneath, so
    #' this panel cannot drift from the helper. Only the two things the helper
    #' does not cover are added: the reserved-name collision and the
    #' informational dropped-row count.
    #'
    #' V2_CONTRACT §B.0: no message carries a button, and neither does the
    #' sidebar. A blocked mapping simply never prepares, and the sentence says
    #' what to change.
    preflight <- reactive({
      raw <- state$raw
      msg <- list()
      add <- function(kind, text) {
        msg[[length(msg) + 1L]] <<- list(kind = kind, text = text, detail = NULL)
      }
      add_err <- function(text, detail) {
        msg[[length(msg) + 1L]] <<- list(kind = "error", text = text, detail = detail)
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
        raw_txt <- if (!is.null(cleaned$error)) cleaned$error else "Preparing the data failed."
        add_err(.data_sentence(raw_txt), raw_txt)
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
        # §G.3: the rows-dropped note stays — it is a data fact the user must
        # see — shortened to one sentence plus the after-dropping caveat.
        add("info", sprintf(
          "Dropped %s of %s rows with a missing time or status. Every count here is after dropping.",
          format(drp$n_total - drp$n_kept, big.mark = ",", trim = TRUE),
          format(drp$n_total, big.mark = ",", trim = TRUE)
        ))
      }

      list(block = FALSE, msg = msg, cleaned = cleaned)
    })

    # ---------------------------------------------------------------------
    # 3.3 preparation — BUILD_CONTRACT I.1 then I.2, run automatically
    # ---------------------------------------------------------------------

    # What `state$prepared` was last built from. A plain closure variable, not a
    # state field: it exists only so a debounce that fires on an unchanged
    # mapping does not refit, and nothing downstream can see it.
    prepared_key <- NULL

    #' The provenance of one preparation: the dataset identity plus the whole
    #' mapping. Two preparations with the same key produce the same frame.
    #' @noRd
    .map_key <- function(time_col, status_col, event_level, time_scale) {
      raw <- state$raw
      paste(as.character(state$source), as.character(state$label),
            if (is.data.frame(raw)) nrow(raw) else 0L,
            if (is.data.frame(raw)) ncol(raw) else 0L,
            as.character(time_col), as.character(status_col),
            as.character(event_level), as.character(time_scale), sep = "|")
    }

    #' Run the R3 recode, then the two package calls, then write state.
    #'
    #' Takes its mapping explicitly rather than reading `input$` so the launch
    #' preparation can run before the client has echoed the control values
    #' back. Everything is inside one `tryCatch`: a red Shiny stack trace on
    #' this tab is a bug.
    do_prepare <- function(time_col, status_col, event_level, time_scale) {
      ca_reset_assessment(state)                       # C.2, first statement

      raw <- state$raw
      if (!is.data.frame(raw)) return(invisible(NULL))
      event_level <- as.character(event_level)

      fail <- function(m) {
        prepared_key <<- NULL
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
        return(fail(if (!is.null(cleaned$error)) cleaned$error else "Preparing the data failed."))
      }

      d01 <- .data_col(cleaned$data, "..D01")
      # Refuse before the package is called at all. Zero events makes MZ/Shen
      # return 1, qn return 0 with warnings, and RECeUS throw.
      if (nrow(cleaned$data) < 2L || is.null(d01) || sum(d01 == 1L, na.rm = TRUE) == 0L) {
        return(fail("This dataset has no events (or too few rows) to assess. Cure-model diagnostics need both events and censored observations."))
      }

      res <- tryCatch(
        withProgress(message = "Preparing data", value = 0, {
          incProgress(0.2, detail = "Standardising the time and event columns")
          # I.1 — the ONLY prepare.surv.data() call in the app, and the only
          # place time is scaled. Everything downstream reads state$prepared.
          prepared <- cureAssess::prepare.surv.data(
            data = cleaned$data,
            time = "..Y_raw",
            status = "..D01",
            time_scale = time_scale
          )
          incProgress(0.3, detail = "Fitting candidate models")
          # I.2 — plot_km = TRUE so state$fit$kmplot exists for the Qualitative
          # tab, which is now the only screen that draws it.
          # suppressMessages(): survminer's ggsurvplot emits the cosmetic
          # ggplot2 4.x note 'Ignoring unknown labels: fill "Strata"' while it
          # builds the risk table. Nothing statistical is suppressed - warnings
          # and errors still propagate.
          fit <- suppressMessages(cureAssess::model.fitting(
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
      prepared_key <<- .map_key(time_col, status_col, event_level, time_scale)
      state$dropped <- cleaned$dropped
      state$prepared <- res$prepared
      state$fit <- res$fit
      state$last_error <- NULL
      state$status <- "prepared"
      invisible(NULL)
    }

    # ---- THE AUTO-PREPARE (§B.1 reactive 1, §B.2) -------------------------
    # The 5-tuple, debounced by 600 ms. Every intermediate change restarts the
    # timer, so switching dataset — which also rewrites the four mapping
    # controls from the registry — costs exactly one preparation, fired once
    # everything has settled. There is no Prepare button anywhere.
    map_tuple <- debounce(
      reactive({
        list(
          source      = input$source,
          key         = input$builtin,
          upload      = if (is.null(input$file)) NULL else input$file$datapath,
          time        = input$col_time,
          status      = input$col_status,
          event_level = input$event_level,
          time_scale  = input$time_scale
        )
      }),
      600
    )

    # observeEvent runs its handler isolated, so nothing below adds a
    # dependency: the tuple above is the only trigger.
    observeEvent(map_tuple(), {
      tup <- map_tuple()
      if (!is.data.frame(state$raw)) return(invisible(NULL))
      if (is.null(tup$time) || is.null(tup$status) || is.null(tup$event_level)) {
        return(invisible(NULL))
      }

      # A debounce that lands on the mapping already prepared is a no-op — and
      # must not call ca_reset_assessment(), which would throw away a perfectly
      # current verdict.
      #
      # The status test is what makes that safe. Touching a mapping control
      # clears the assessment immediately (§B.6) and leaves status "empty"; if
      # the user then puts the control back, the key matches again but
      # `state$assess` is gone and `state$prepared` is the SAME object, so the
      # assessment — which triggers on that object changing — would never be
      # rebuilt. Preparing again writes a new frame and everything downstream
      # recomputes. One fit, and only on the path that needs it.
      key <- .map_key(tup$time, tup$status, tup$event_level, tup$time_scale)
      if (identical(key, prepared_key) && is.data.frame(state$prepared) &&
          state$status %in% c("prepared", "assessed")) {
        return(invisible(NULL))
      }

      # A refusable mapping never reaches the package; the message panel is
      # already saying which control to change.
      if (isTRUE(preflight()$block)) return(invisible(NULL))

      do_prepare(tup$time, tup$status, tup$event_level, tup$time_scale)
    }, ignoreInit = FALSE)

    # Launch preparation of gbsg (BUILD_CONTRACT C.1, V2_CONTRACT §B.2) so the
    # first screen a user sees carries a real summary card and a real preview,
    # and the Recommendation step is never locked. Running it here rather than
    # waiting for the debounce means no tab is empty on first paint; the
    # debounced observer then recognises its own key and does not refit.
    observeEvent(TRUE, {
      entry <- load_builtin("gbsg")
      if (is.null(entry)) return(invisible(NULL))
      do_prepare(entry$time, entry$status, as.character(entry$event_level), entry$time_scale)
    }, once = TRUE, ignoreInit = FALSE)

    # ---------------------------------------------------------------------
    # 3.4 messages — every sentence is REVISION_CONTRACT §G.9, Data
    # ---------------------------------------------------------------------

    output$data_msg <- renderUI({
      pf <- preflight()
      items <- pf$msg
      out <- list()

      # upload-time parse failures first: without a frame nothing else applies
      up <- upload_parsed()
      if (identical(input$source, "upload") && !is.null(up) && !is.null(up$error)) {
        unreadable <- "That file could not be read as CSV. Check it is comma-separated with a header row."
        not_csv <- "That file does not look comma-separated. Save it as a comma-separated CSV and upload again."

        out[[length(out) + 1L]] <- switch(
          up$error,
          unreadable = ca_note(
            "warning", "That file could not be read", htmltools::p(unreadable)
          ),
          parse = ca_note(
            "warning", "That file could not be read",
            htmltools::tagList(
              htmltools::p(unreadable),
              ca_tech(htmltools::tags$pre(up$detail))
            )
          ),
          delimiter = ca_note(
            "warning", "Wrong delimiter",
            htmltools::tagList(
              htmltools::p(not_csv),
              ca_tech(htmltools::tags$pre(up$detail), title = "The first line of the file")
            )
          ),
          onecol = ca_note(
            "warning", "Wrong delimiter",
            htmltools::tagList(
              htmltools::p(not_csv),
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
          ca_note("warning", "That file could not be read", htmltools::p(unreadable))
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
      if ((identical(state$status, "empty") || is.null(state$raw)) &&
          !identical(state$status, "error")) {
        out[[length(out) + 1L]] <- ca_empty(
          "Pick an example or upload a CSV."
        )
      }

      for (m in items) {
        title <- switch(m$kind, error = "This mapping cannot be prepared",
                        warning = "Check this before you prepare", "For your information")
        variant <- switch(m$kind, error = "warning", warning = "warning", "info")
        body <- htmltools::tagList(
          htmltools::p(m$text),
          # §G.9: the verbatim refusal goes underneath the short sentence,
          # never instead of it.
          if (!is.null(m$detail)) ca_tech(htmltools::tags$pre(m$detail))
        )
        out[[length(out) + 1L]] <- ca_note(variant, title, body)
      }

      if (identical(state$status, "error") && !is.null(state$last_error)) {
        le <- state$last_error
        out[[length(out) + 1L]] <- ca_note(
          "warning", "Preparing the data failed",
          htmltools::tagList(
            htmltools::p(.data_sentence(le)),
            ca_tech(htmltools::tags$pre(le))
          )
        )
      }

      if (identical(state$status, "data_loaded") && !is.null(state$raw) && !isTRUE(pf$block)) {
        out[[length(out) + 1L]] <- ca_empty(
          "Choose the time column, the status column and which value means the event."
        )
      }

      if (!length(out)) return(NULL)
      htmltools::tagList(out)
    })

    # ---------------------------------------------------------------------
    # 3.5 the data summary — six descriptive counts, ca_data_summary() (F.1)
    # ---------------------------------------------------------------------

    output$summary_card <- renderUI({
      prepared <- state$prepared
      if (!is.data.frame(prepared)) {
        return(ca_card(
          title = "Data summary",
          body = ca_empty("Nothing is prepared yet.")
        ))
      }

      # F.1 — descriptive counts on state$prepared. No package field is read
      # here and nothing inferential is computed.
      s <- tryCatch(ca_data_summary(prepared), error = function(e) NULL)
      if (is.null(s)) {
        return(ca_card(
          title = "Data summary",
          body = ca_empty("The summary could not be computed.")
        ))
      }

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
        title = "Data summary",
        chip = ca_chip("neutral", if (is.null(state$label)) "dataset" else state$label),
        body = htmltools::tagList(
          if (mapping_changed) {
            htmltools::p(
              class = "ca-provenance",
              htmltools::tags$strong("Showing the previous mapping.")
            )
          },
          htmltools::div(
            class = paste("ca-statrow", if (stale) "is-stale" else ""),
            ca_kv("n analysed", format(s$n, big.mark = ",", trim = TRUE),
                  "rows kept after dropping a missing time or status"),
            ca_kv("events", format(s$events, big.mark = ",", trim = TRUE),
                  "rows where the event happened"),
            ca_kv("censored", paste0(ca_num(s$censored_pct, 1), "%"),
                  "share of rows with no event"),
            ca_kv("median follow-up", ca_num(s$median_followup, 3),
                  "median of observed follow-up times, all subjects"),
            ca_kv("max follow-up", ca_num(s$max_followup, 3),
                  "largest observed time, event or censored"),
            ca_kv("last event time", ca_num(s$last_event_time, 3),
                  "largest time at which an event occurred")
          )
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
    # 3.6 head() preview, Y and D first
    # ---------------------------------------------------------------------

    output$head_table <- DT::renderDT({
      prepared <- state$prepared
      validate(need(is.data.frame(prepared), "The first rows appear once a dataset is loaded."))

      d <- utils::head(prepared, 10L)
      # the two scratch columns ca_clean_surv() adds are exact duplicates of
      # Y and D, so they are dropped from the preview only
      d <- d[, setdiff(names(d), c("..Y_raw", "..D01")), drop = FALSE]
      ord <- c(intersect(c("Y", "D"), names(d)), setdiff(names(d), c("Y", "D")))
      d <- d[, ord, drop = FALSE]

      # Columns that are not whole numbers are shown to 4 decimals. This is a
      # DISPLAY format only — `d` is untouched and nothing downstream reads this
      # table. Y is a derived column (the time scaling divides by 365.25), so
      # its full binary expansion is floating-point noise that makes the preview
      # unreadable without helping anyone check their column choice.
      num <- names(d)[vapply(d, is.numeric, logical(1))]
      frac <- num[vapply(d[num], function(x) {
        x <- x[is.finite(x)]
        length(x) > 0L && any(x != round(x))
      }, logical(1))]

      tbl <- DT::datatable(
        d,
        rownames = FALSE,
        class = "compact stripe",
        options = list(dom = "t", ordering = FALSE, scrollX = TRUE, pageLength = 10L)
      )
      if (length(frac)) tbl <- DT::formatRound(tbl, columns = frac, digits = 4L)
      tbl
    })

    invisible(NULL)
  })
}
