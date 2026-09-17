# =============================================================================
# app-v2/R/mod_v2_data.R — section 2 of the column, and the data drawer.
#                                                        owner: builder-v2
#
# §G.1 section 2: the mapping is stated as a sentence in the column, with an
# Edit control that opens a right-hand slide-over holding the source, the
# upload, the four mapping controls and the ten-row preview. The follow-up
# timeline sits under the sentence.
#
# This module also owns the preparation half of the auto-compute contract
# (V2_CONTRACT §B.1 reactives 1 and 3, coded as §B.2):
#
#   the 5-tuple (source/dataset/upload, time, status, event level, time scale)
#     -> debounced 600 ms
#     -> ca_reset_assessment(state)        FIRST, before any package call (§B.6)
#     -> ca_clean_surv()                   the 0/1 recode, app-side
#     -> prepare.surv.data()               time is scaled ONCE, here (S5)
#     -> model.fitting(plot_km = TRUE)     overlay objects only, never a decision
#
# There is no Prepare button and no Run button. `ignoreInit = FALSE` on the
# launch preparation is what replaces them: gbsg is prepared and assessed
# before first paint, so no section is ever empty.
#
# FIELD PROVENANCE (code comments only, never on screen — C1):
#   state$prepared   prepare.surv.data() output, columns Y and D
#   state$fit        model.fitting() output: $kmfit, $kmplot, $fits
# =============================================================================


# ---- private helpers --------------------------------------------------------

#' Read one uploaded CSV with the baseline's own strict reader.
#'
#' The shared reader sniffs the delimiter, rejects ragged rows by line number,
#' strips a byte-order mark and cleans the column names, so an upload here
#' fails with exactly the wording the baseline uses. The fallback exists only
#' so this version cannot be taken down by a rename upstream.
#' @noRd
.v2_read_csv <- function(path) {
  if (exists(".data_read_csv", mode = "function")) return(.data_read_csv(path))
  df <- tryCatch(
    utils::read.csv(path, header = TRUE, stringsAsFactors = FALSE, check.names = TRUE),
    error = function(e) e, warning = function(w) w
  )
  if (inherits(df, "condition")) return(list(data = NULL, error = "parse", detail = conditionMessage(df)))
  if (!is.data.frame(df) || !nrow(df) || ncol(df) < 2L) return(list(data = NULL, error = "unreadable", detail = NULL))
  list(data = df, error = NULL, detail = NULL)
}

#' One short sentence for a refusal, using the baseline's own wording.
#' @noRd
.v2_sentence <- function(txt) {
  if (exists(".data_sentence", mode = "function")) return(.data_sentence(txt))
  "Preparing the data failed."
}

#' Names of the numeric columns.
#' @noRd
.v2_numeric_cols <- function(df) {
  if (!is.data.frame(df) || !ncol(df)) return(character(0))
  names(df)[vapply(df, is.numeric, logical(1))]
}

#' A first guess at the mapping for a file the registry has never seen.
#'
#' A SUGGESTION, never a decision: every one of the three controls stays under
#' the user's hand, and nothing here looks at a value to decide anything — it
#' reads column NAMES and counts distinct values, which is the same class of
#' work the registry defaults do for the built-in examples.
#'
#' Without this an uploaded file gets "the first numeric column is the time and
#' the FIRST column is the status", which on a two-column file means the time
#' column is also proposed as the status column and the assessment that follows
#' is nonsense until the reader notices. Naming the columns is exactly what the
#' drawer is for; this just opens it on a sensible guess.
#'
#' @return `list(time, status, event_level)`, any element possibly NULL.
#' @noRd
.v2_guess_map <- function(raw) {
  cols <- names(raw)
  num  <- .v2_numeric_cols(raw)
  norm <- function(x) tolower(gsub("[^a-z0-9]", "", tolower(x)))
  n_lv <- function(nm) length(unique(raw[[nm]][!is.na(raw[[nm]])]))

  time_like   <- c("time", "y", "t", "futime", "survtime", "os", "pfs", "rfstime", "edrel")
  status_like <- c("status", "d", "event", "cens", "censor", "died", "death", "rel", "delta")

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

  lv <- if (is.null(scol)) character(0) else .v2_level_choices(raw[[scol]])
  ev <- if ("1" %in% lv) "1" else if (length(lv)) lv[[length(lv)]] else NULL

  list(time = tcol, status = scol, event_level = ev)
}


#' Distinct values of a status column, labelled with their row counts.
#' @noRd
.v2_level_choices <- function(x) {
  if (is.null(x)) return(character(0))
  v <- x[!is.na(x)]
  if (is.factor(v)) v <- as.character(v)
  v <- as.character(v)
  if (!length(v)) return(character(0))
  tb  <- table(v)
  lv  <- names(tb)
  cnt <- as.integer(tb)
  num <- suppressWarnings(as.numeric(lv))
  ord <- if (!anyNA(num)) order(num) else order(lv)
  stats::setNames(lv[ord], sprintf("%s (%s rows)", lv[ord],
                                   format(cnt[ord], big.mark = ",", trim = TRUE)))
}

#' The built-in examples as one optgroup per scenario family.
#'
#' The registry carries the family, the label and the one-line note for all
#' nineteen entries, so the picker is generated, never typed.
#' @noRd
.v2_builtin_choices <- function() {
  fams <- if (exists("CA_DATASET_FAMILIES")) CA_DATASET_FAMILIES else character(0)
  out <- list()
  for (fam in fams) {
    keys <- Filter(function(k) identical(CA_DATASETS[[k]]$family, fam), names(CA_DATASETS))
    if (!length(keys)) next
    out[[fam]] <- stats::setNames(
      unlist(keys, use.names = FALSE),
      vapply(keys, function(k) as.character(CA_DATASETS[[k]]$label), character(1))
    )
  }
  if (!length(out)) stats::setNames(names(CA_DATASETS), names(CA_DATASETS)) else out
}


# =============================================================================
# UI
# =============================================================================

#' Section 2 in the evidence column — the mapping as a sentence, the Edit
#' control, and the follow-up timeline.
mod_v2_data_ui <- function(id) {
  ns <- NS(id)
  htmltools::tags$section(
    class = "v2-sec", id = "v2-data",
    htmltools::div(
      class = "v2-sec__head",
      htmltools::tags$h2(class = "v2-sec__title", "The data"),
      htmltools::tags$label(class = "v2-linkbtn", `for` = "v2-drawer-open",
                            "Change data or columns")
    ),
    uiOutput(ns("mapping_sentence")),
    uiOutput(ns("timeline"))
  )
}

#' The drawer: a right-hand slide-over holding everything about the dataset.
#'
#' It is opened and closed by a label pointing at a bare checkbox, so there is
#' no JavaScript and no server round trip. Its controls stay in the document at
#' all times, which is why the preview inside it is live the moment it opens.
mod_v2_drawer_ui <- function(id) {
  ns <- NS(id)

  htmltools::tagList(
    htmltools::tags$label(class = "v2-scrim", `for` = "v2-drawer-open",
                          `aria-hidden` = "true"),
    htmltools::tags$aside(
      class = "v2-drawer", `aria-label` = "Dataset and columns",

      htmltools::div(
        class = "v2-drawer__head",
        htmltools::tags$h2("Dataset"),
        htmltools::tags$label(class = "v2-close", `for` = "v2-drawer-open",
                              title = "Close", htmltools::HTML("&times;"))
      ),

      htmltools::div(
        class = "v2-drawer__body",

        radioButtons(ns("source"), "Source", inline = TRUE,
                     choices = c("Built-in example" = "builtin", "Upload a CSV" = "upload"),
                     selected = "builtin"),

        conditionalPanel(
          condition = "input.source == 'builtin'", ns = ns,
          selectInput(ns("builtin"), "Example", choices = .v2_builtin_choices(),
                      selected = "gbsg"),
          uiOutput(ns("builtin_note"))
        ),

        conditionalPanel(
          condition = "input.source == 'upload'", ns = ns,
          fileInput(ns("file"), "CSV file", accept = ".csv", multiple = FALSE),
          htmltools::tags$p(
            class = "ca-provenance",
            "Comma-separated, one header row, decimal point. The file is read into this session only."
          )
        ),

        htmltools::tags$hr(),

        selectInput(ns("col_time"), "Time column", choices = character(0)),
        selectInput(ns("col_status"), "Status column", choices = character(0)),
        selectInput(ns("event_level"), "Which value means the event?", choices = character(0)),
        radioButtons(ns("time_scale"), "Time scale",
                     choices = c("Leave as supplied" = "none", "Days → years" = "days_to_years"),
                     selected = "none"),

        uiOutput(ns("drawer_msg")),

        htmltools::tags$h3(class = "v2-drawer__sub", "First rows"),
        DT::DTOutput(ns("preview")),
        htmltools::tags$p(
          class = "ca-provenance",
          "Check that the time column and the event indicator are the ones you meant."
        )
      )
    )
  )
}


# =============================================================================
# SERVER
# =============================================================================

#' Owns state$raw, state$label, state$source, state$map, state$dropped,
#' state$prepared and state$fit.
mod_v2_data_server <- function(id, state) {
  moduleServer(id, function(input, output, session) {

    # ---- loading ----------------------------------------------------------

    upload_parsed <- reactive({
      f <- input$file
      if (is.null(f) || !nzchar(f$datapath)) return(NULL)
      .v2_read_csv(f$datapath)
    })

    set_raw <- function(raw, label, src) {
      ca_reset_assessment(state)
      state$raw <- raw; state$label <- label; state$source <- src
      state$map <- NULL; state$dropped <- NULL
      state$prepared <- NULL; state$fit <- NULL
      # A clinician confirmed plausibility for THAT population, not for every
      # population, so both answers and the derived flag are cleared.
      state$expert_q1 <- ""; state$expert_q2 <- ""; state$expert_confirmed <- FALSE
      state$status <- "empty"
      invisible(NULL)
    }

    refresh_mapping <- function(raw, entry = NULL) {
      num <- .v2_numeric_cols(raw)
      all_cols <- names(raw)

      # The registry knows the built-in examples; an uploaded file gets the
      # name-and-level guess instead. Either way these are suggestions the
      # drawer lets the reader change, and changing one re-assesses by itself.
      guess <- .v2_guess_map(raw)

      t_def <- if (!is.null(entry) && entry$time %in% num) entry$time else guess$time
      s_def <- if (!is.null(entry) && entry$status %in% all_cols) entry$status else guess$status

      updateSelectInput(session, "col_time", choices = num, selected = t_def)
      updateSelectInput(session, "col_status", choices = all_cols, selected = s_def)

      lv <- .v2_level_choices(if (is.null(s_def)) NULL else raw[[s_def]])
      e_def <- if (!is.null(entry) && as.character(entry$event_level) %in% lv) {
        as.character(entry$event_level)
      } else if (!is.null(guess$event_level) && guess$event_level %in% lv) {
        guess$event_level
      } else if (length(lv)) lv[[length(lv)]] else NULL
      updateSelectInput(session, "event_level", choices = lv, selected = e_def)

      ts_def <- if (!is.null(entry) && entry$time_scale %in% c("none", "days_to_years")) {
        entry$time_scale
      } else "none"
      updateRadioButtons(session, "time_scale", selected = ts_def)
      invisible(NULL)
    }

    load_builtin <- function(key) {
      entry <- if (is.null(key) || !nzchar(key)) NULL else CA_DATASETS[[key]]
      if (is.null(entry)) return(invisible(NULL))
      raw <- tryCatch(ca_dataset_load(key), error = function(e) e)
      if (inherits(raw, "condition")) {
        ca_reset_assessment(state)
        state$last_error <- conditionMessage(raw)
        state$status <- "error"
        return(invisible(NULL))
      }
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
        # A bad file must not silently leave the previous dataset in place.
        ca_reset_assessment(state)
        state$raw <- NULL; state$label <- NULL; state$source <- "upload"
        state$map <- NULL; state$dropped <- NULL
        state$prepared <- NULL; state$fit <- NULL
        state$status <- "empty"
        return(invisible(NULL))
      }
      set_raw(up$data, as.character(input$file$name), "upload")
      refresh_mapping(up$data, NULL)
    }, ignoreInit = TRUE)

    # Event levels follow the chosen status column; the registry default wins
    # while the status column is still the registry's own.
    observeEvent(list(state$raw, input$col_status), {
      raw <- state$raw
      req(is.data.frame(raw))
      sc <- input$col_status
      if (is.null(sc) || !sc %in% names(raw)) return(invisible(NULL))
      lv <- .v2_level_choices(raw[[sc]])
      entry <- if (identical(input$source, "builtin")) CA_DATASETS[[input$builtin]] else NULL
      want <- if (!is.null(entry) && identical(entry$status, sc)) as.character(entry$event_level) else NULL
      sel <- if (!is.null(want) && want %in% lv) want
             else if (!is.null(input$event_level) && input$event_level %in% lv) input$event_level
             else if (length(lv)) lv[[1L]] else NULL
      updateSelectInput(session, "event_level", choices = lv, selected = sel)
    }, ignoreInit = TRUE)

    # A mapping change clears the verdict immediately (§B.6), before the
    # debounce has even landed.
    observeEvent(list(input$col_time, input$col_status, input$event_level, input$time_scale), {
      req(state$raw)
      m <- state$map
      if (!is.null(m) && identical(m$time, input$col_time) &&
          identical(m$status, input$col_status) &&
          identical(m$event_level, as.character(input$event_level)) &&
          identical(m$time_scale, input$time_scale)) return(invisible(NULL))
      ca_reset_assessment(state)
    }, ignoreInit = TRUE)

    # ---- preparation (§B.1 reactives 1 and 3) -----------------------------

    prepared_key <- NULL

    .map_key <- function(time_col, status_col, event_level, time_scale) {
      raw <- state$raw
      paste(as.character(state$source), as.character(state$label),
            if (is.data.frame(raw)) nrow(raw) else 0L,
            if (is.data.frame(raw)) ncol(raw) else 0L,
            as.character(time_col), as.character(status_col),
            as.character(event_level), as.character(time_scale), sep = "|")
    }

    do_prepare <- function(time_col, status_col, event_level, time_scale) {
      ca_reset_assessment(state)                 # §B.6 — FIRST, always

      raw <- state$raw
      if (!is.data.frame(raw)) return(invisible(NULL))
      event_level <- as.character(event_level)

      fail <- function(m) {
        prepared_key <<- NULL
        state$prepared <- NULL; state$fit <- NULL
        state$last_error <- m; state$status <- "error"
        invisible(NULL)
      }

      cleaned <- tryCatch(
        ca_clean_surv(raw, time_col, status_col, event_level),
        error = function(e) list(data = NULL, dropped = NULL, error = conditionMessage(e))
      )
      if (!is.data.frame(cleaned$data)) {
        return(fail(if (!is.null(cleaned$error)) cleaned$error else "Preparing the data failed."))
      }

      d01 <- cleaned$data[["..D01"]]
      if (nrow(cleaned$data) < 2L || is.null(d01) || sum(d01 == 1L, na.rm = TRUE) == 0L) {
        return(fail(paste("This dataset has no events (or too few rows) to assess.",
                          "Cure-model diagnostics need both events and censored observations.")))
      }

      res <- tryCatch(
        withProgress(message = "Reading the data", value = 0, {
          incProgress(0.2, detail = "Standardising the time and event columns")
          # Time is scaled exactly ONCE, here (S5). The assessment that follows
          # is then handed time_scale = "none".
          prepared <- cureAssess::prepare.surv.data(
            data = cleaned$data, time = "..Y_raw", status = "..D01",
            time_scale = time_scale
          )
          incProgress(0.4, detail = "Drawing the curve")
          # Overlay objects only, never a decision (§B.1 reactive 3).
          # suppressMessages(): the curve builder emits a cosmetic ggplot2 note
          # while it assembles the risk table. Nothing statistical is silenced.
          fit <- suppressMessages(cureAssess::model.fitting(
            data = prepared, plot_km = TRUE, include_lognormal = FALSE
          ))
          incProgress(0.4, detail = "Done")
          list(prepared = prepared, fit = fit)
        }),
        error = function(e) e
      )
      if (inherits(res, "condition")) return(fail(conditionMessage(res)))

      state$map <- list(time = time_col, status = status_col,
                        event_level = event_level, time_scale = time_scale)
      prepared_key <<- .map_key(time_col, status_col, event_level, time_scale)
      state$dropped  <- cleaned$dropped
      state$prepared <- res$prepared
      state$fit      <- res$fit
      state$last_error <- NULL
      state$status <- "prepared"
      invisible(NULL)
    }

    # The 5-tuple, debounced by 600 ms: switching dataset rewrites four mapping
    # controls at once and still costs exactly one preparation.
    map_tuple <- debounce(reactive({
      list(source = input$source, key = input$builtin,
           upload = if (is.null(input$file)) NULL else input$file$datapath,
           time = input$col_time, status = input$col_status,
           event_level = input$event_level, time_scale = input$time_scale)
    }), 600)

    observeEvent(map_tuple(), {
      tup <- map_tuple()
      if (!is.data.frame(state$raw)) return(invisible(NULL))
      if (is.null(tup$time) || is.null(tup$status) || is.null(tup$event_level)) {
        return(invisible(NULL))
      }
      key <- .map_key(tup$time, tup$status, tup$event_level, tup$time_scale)
      if (identical(key, prepared_key) && is.data.frame(state$prepared) &&
          state$status %in% c("prepared", "assessed")) return(invisible(NULL))
      do_prepare(tup$time, tup$status, tup$event_level, tup$time_scale)
    }, ignoreInit = FALSE)

    # The launch preparation. This is what replaces the Prepare button: the
    # first paint already carries a real verdict.
    observeEvent(TRUE, {
      entry <- load_builtin("gbsg")
      if (is.null(entry)) return(invisible(NULL))
      do_prepare(entry$time, entry$status, as.character(entry$event_level), entry$time_scale)
    }, once = TRUE, ignoreInit = FALSE)

    # ---- section 2 --------------------------------------------------------

    output$mapping_sentence <- renderUI({
      if (is.null(state$raw)) {
        return(htmltools::tags$p(class = "v2-empty", "No data yet."))
      }
      if (identical(state$status, "error")) {
        return(ca_note("warning", .v2_sentence(state$last_error),
                       ca_tech(htmltools::tags$pre(class = "ca-mono", state$last_error))))
      }
      req(state$prepared)
      m <- state$map
      d <- state$dropped
      years <- identical(m$time_scale, "days_to_years")

      htmltools::tagList(
        htmltools::tags$p(
          class = "v2-sec__lede",
          if (years) "Follow-up times were recorded in days and are read here in years."
          else "Follow-up times are read exactly as they were supplied.",
          " ",
          if (!is.null(d) && d$n_kept < d$n_total) {
            sprintf("%s of the %s rows in the file are analysed; the rest have a missing time or status.",
                    format(d$n_kept, big.mark = ",", trim = TRUE),
                    format(d$n_total, big.mark = ",", trim = TRUE))
          } else {
            "Every row in the file has a usable time and a usable outcome."
          }
        )
      )
    })

    output$timeline <- renderUI({
      req(state$prepared)
      f <- ca_tail_facts(state$prepared)
      unit <- if (identical(state$map$time_scale, "days_to_years")) "years" else NULL
      if (is.null(f)) {
        return(ca_viz_timeline(NA_real_, NA_real_))
      }
      htmltools::tagList(
        htmltools::tags$p(class = "v2-figlabel",
                          "When the last event happened, and how long people were watched after it"),
        ca_viz_timeline(f$last_event, f$max_time, f$gap_pct, f$n_cens_after,
                        f$zero_width, unit = unit)
      )
    })

    # ---- the drawer -------------------------------------------------------

    output$builtin_note <- renderUI({
      k <- input$builtin
      if (is.null(k) || !nzchar(k) || is.null(CA_DATASETS[[k]])) return(NULL)
      htmltools::tags$p(class = "ca-provenance", CA_DATASETS[[k]]$note)
    })

    output$drawer_msg <- renderUI({
      up <- upload_parsed()
      if (identical(input$source, "upload") && !is.null(up) && !is.null(up$error)) {
        return(ca_note(
          "warning", "That file could not be read",
          htmltools::tags$p(switch(
            up$error,
            delimiter = "That file does not look comma-separated. Save it as a comma-separated CSV and upload again.",
            onecol    = "That file parsed as a single column. Check the separator and upload again.",
            ragged    = "Some rows have a different number of values from the header row.",
            "That file could not be read as comma-separated values."
          ))
        ))
      }
      if (identical(state$status, "error")) {
        return(ca_note("warning", .v2_sentence(state$last_error),
                       ca_tech(htmltools::tags$pre(class = "ca-mono", state$last_error))))
      }
      NULL
    })

    output$preview <- DT::renderDT({
      prepared <- state$prepared
      validate(need(is.data.frame(prepared), "The first rows appear once a dataset is loaded."))
      d <- utils::head(prepared, 10L)
      d <- d[, setdiff(names(d), c("..Y_raw", "..D01")), drop = FALSE]
      ord <- c(intersect(c("Y", "D"), names(d)), setdiff(names(d), c("Y", "D")))
      d <- d[, ord, drop = FALSE]

      num <- names(d)[vapply(d, is.numeric, logical(1))]
      frac <- num[vapply(d[num], function(x) {
        x <- x[is.finite(x)]
        length(x) > 0L && any(x != round(x))
      }, logical(1))]

      tbl <- DT::datatable(d, rownames = FALSE, class = "compact stripe",
                           options = list(dom = "t", ordering = FALSE,
                                          scrollX = TRUE, pageLength = 10L))
      if (length(frac)) tbl <- DT::formatRound(tbl, columns = frac, digits = 4L)
      tbl
    })

    invisible(NULL)
  })
}
