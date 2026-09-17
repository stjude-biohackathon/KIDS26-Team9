# =============================================================================
# mod_v3_controls.R — the whole left pane.            V2_CONTRACT §G.2, builder-v3
#
# Five hairline-separated sections, no card edges:
#   1 Dataset      example picker (19 registry entries grouped by family) or upload
#   2 Mapping      four controls, collapsed to a one-line summary once valid
#   3 Your judgment the two expert questions
#   4 Explore      alpha, the distribution override, the extra candidate shape
#   5 Take away    the ten-row preview
#
# It is also the only module in this version that WRITES to `state`, and it
# carries the two automatic computations of the auto-compute contract:
#
#   §B.2  auto-prepare   the 5-tuple, debounced 600 ms -> prepare.surv.data()
#                        + model.fitting(plot_km = TRUE)
#   §B.3  auto-assess    state$prepared / state$include_lognormal
#                        -> ca_assess_once()  (helpers.R F.22, the ONE call site)
#   §B.1 reactive 4      input$alpha, debounced 400 ms -> ca_tests_at_alpha()
#
# THERE IS NO RUN BUTTON AND NO PREPARE BUTTON (R2). The user chooses data,
# chooses columns, answers two questions, and downloads. Everything else happens
# on its own.
#
# FIELD PROVENANCE (code comments only, never on screen — C1):
#   state$prepared  <- cureAssess::prepare.surv.data()
#   state$fit       <- cureAssess::model.fitting(plot_km = TRUE)   — overlay only
#   state$assess    <- ca_assess_once()  ->  cure.appropriateness()
#   state$alpha_tests <- ca_tests_at_alpha() -> mz.test(), shen.test()
# =============================================================================


# ---- private helpers --------------------------------------------------------

#' The example picker: 19 radio rows, grouped by family, each carrying its note.
#'
#' Hand-written markup rather than `radioButtons()` because the contract asks
#' for family headings inside one radio group, which `radioButtons()` cannot
#' emit. Shiny's own radio input binding attaches to any element carrying
#' `class="shiny-input-radiogroup"` and an id, and reads
#' `input:radio[name="<that id>"]:checked` inside it — so `name` is set to the
#' namespaced id, exactly as `radioButtons()` does.
#'
#' The note is hidden until its row is chosen (CSS), so the list stays scannable
#' at nineteen entries and the chosen scenario explains itself.
#' @noRd
.v3_picker <- function(id, selected = "gbsg") {
  fams <- if (exists("CA_DATASET_FAMILIES")) CA_DATASET_FAMILIES else character(0)
  blocks <- lapply(fams, function(fam) {
    keys <- Filter(function(k) identical(CA_DATASETS[[k]]$family, fam), names(CA_DATASETS))
    if (!length(keys)) return(NULL)
    htmltools::tagList(
      htmltools::div(class = "v3-picker__fam", fam),
      lapply(keys, function(k) {
        e   <- CA_DATASETS[[k]]
        rid <- paste0(id, "__", k)
        htmltools::div(
          class = "v3-pick",
          htmltools::tags$input(
            type = "radio", name = id, id = rid, value = k,
            class = "v3-pick__input",
            checked = if (identical(k, selected)) "checked" else NULL
          ),
          htmltools::tags$label(
            class = "v3-pick__label", `for` = rid,
            htmltools::span(class = "v3-pick__name", as.character(e$label)),
            htmltools::span(class = "v3-pick__note", as.character(e$note))
          )
        )
      })
    )
  })
  htmltools::div(id = id, class = "shiny-input-radiogroup v3-picker", blocks)
}


#' One pane section: a numbered eyebrow, a title, and its contents.
#' @noRd
.v3_sec <- function(n, title, ..., id = NULL) {
  htmltools::tags$section(
    class = "v3-sec", id = id,
    htmltools::div(
      class = "v3-sec__head",
      htmltools::span(class = "v3-sec__n", n),
      htmltools::h2(class = "v3-sec__title", title)
    ),
    htmltools::div(class = "v3-sec__body", ...)
  )
}


#' A closed disclosure that matches the pane's density.
#' @noRd
.v3_fold <- function(summary, ..., open = FALSE) {
  htmltools::tags$details(
    class = "v3-fold", open = if (isTRUE(open)) "open" else NULL,
    htmltools::tags$summary(summary),
    htmltools::div(class = "v3-fold__body", ...)
  )
}


#' One expert question: the poster's verbatim wording, nothing pre-selected.
#'
#' The app never answers for the user, so `selected = character(0)`.
#' @noRd
.v3_question <- function(input_id, question) {
  htmltools::div(
    class = "v3-q",
    radioButtons(
      input_id,
      label = htmltools::span(class = "v3-q__text", question),
      choices = c("Yes", "No"), selected = character(0), inline = TRUE
    )
  )
}

.v3_answer <- function(v) {
  if (is.null(v) || length(v) != 1L || is.na(v) || !nzchar(v)) return("")
  if (identical(v, "Yes")) return("yes")
  if (identical(v, "No")) return("no")
  ""
}
.v3_choice <- function(a) {
  if (identical(a, "yes")) return("Yes")
  if (identical(a, "no")) return("No")
  character(0)
}

# The permanent exploration line. Same sentence in all three versions (§B.1).
.V3_TAU_CAVEAT <- "This is an exploration. The decision above, and the report, always use the default."

# The package default alpha, and the RECeUS short codes the override offers.
# The VALUES are the package's own codes; the LABELS are plain display names,
# because C1 keeps package spellings off the screen. "" means "use the one the
# assessment selected" (S3 — read $selected_receus_dist, never re-map a name).
.V3_ALPHA_DEFAULT <- 0.05
.V3_RECEUS_DISTS <- c(
  "Chosen automatically" = "",
  "exponential cure model" = "exp",
  "Weibull cure model" = "wei",
  "gamma cure model" = "gam",
  "log-logistic cure model" = "llogis",
  "lognormal cure model" = "lnorm",
  "exponential" = "expUnc",
  "Weibull" = "weiUnc",
  "gamma" = "gamUnc",
  "log-logistic" = "llogisUnc",
  "lognormal" = "lnormUnc"
)


# =============================================================================
# UI
# =============================================================================

mod_v3_controls_ui <- function(id) {
  ns <- NS(id)

  htmltools::tagList(

    # ---- 1 Dataset --------------------------------------------------------
    .v3_sec(
      1, "Dataset",
      htmltools::div(
        class = "v3-switch",
        radioButtons(
          ns("source"), label = NULL,
          choices = c("Example" = "builtin", "Upload" = "upload"),
          selected = "builtin", inline = TRUE
        )
      ),
      conditionalPanel(
        condition = "input.source == 'builtin'", ns = ns,
        .v3_picker(ns("example"), selected = "gbsg")
      ),
      conditionalPanel(
        condition = "input.source == 'upload'", ns = ns,
        fileInput(ns("file"), NULL, accept = ".csv", multiple = FALSE,
                  buttonLabel = "Choose CSV", placeholder = "no file"),
        htmltools::p(class = "ca-provenance",
                     "Comma-separated, one header row. The file is read into this session only.")
      ),
      uiOutput(ns("load_msg"))
    ),

    # ---- 2 Mapping --------------------------------------------------------
    # Collapsed to its own one-line summary once it is valid; opening the
    # summary is the Edit.
    .v3_sec(
      2, "Columns",
      htmltools::tags$details(
        class = "v3-fold v3-fold--map",
        htmltools::tags$summary(uiOutput(ns("map_summary"), inline = TRUE)),
        htmltools::div(
          class = "v3-fold__body",
          selectInput(ns("col_time"), "Time", choices = character(0), selectize = FALSE),
          selectInput(ns("col_status"), "Status", choices = character(0), selectize = FALSE),
          selectInput(ns("event_level"), "Value meaning the event",
                      choices = character(0), selectize = FALSE),
          radioButtons(ns("time_scale"), "Time scale",
                       choices = c("As supplied" = "none", "Days → years" = "days_to_years"),
                       selected = "none")
        )
      ),
      uiOutput(ns("map_msg"))
    ),

    # ---- 3 Your judgment --------------------------------------------------
    .v3_sec(
      3, "Your judgment",
      htmltools::p(class = "v3-sec__lede",
                   "Only a person who knows the disease can answer these."),
      .v3_question(ns("q1"), "Is a cure biologically plausible?"),
      .v3_question(ns("q2"), "Is long-term survival without recurrence expected?")
    ),

    # ---- 4 Explore --------------------------------------------------------
    .v3_sec(
      4, "Explore",
      .v3_fold(
        "Optional dials",
        checkboxInput(ns("include_lognormal"), "Also fit lognormal shapes", value = FALSE),
        sliderInput(
          ns("alpha"),
          label = htmltools::span(htmltools::span(class = "ca-nocaps", "α"),
                                  " for the follow-up readings"),
          min = 0.01, max = 0.20, value = .V3_ALPHA_DEFAULT, step = 0.005
        ),
        selectInput(ns("receus_dist"), "Shape behind the cured-group reading",
                    choices = .V3_RECEUS_DISTS, selected = "", selectize = FALSE),
        htmltools::p(class = "ca-provenance", .V3_TAU_CAVEAT)
      )
    ),

    # ---- 5 Take away ------------------------------------------------------
    .v3_sec(
      5, "Take away",
      .v3_fold("First ten rows, as prepared", DT::DTOutput(ns("preview"))),
      uiOutput(ns("download_msg"))
    )
  )
}


# =============================================================================
# SERVER
# =============================================================================

#' @return a list of reactives the canvas needs: `receus_dist`.
mod_v3_controls_server <- function(id, state) {
  moduleServer(id, function(input, output, session) {

    # ---------------------------------------------------------------------
    # 1. LOADING A DATASET INTO state$raw
    # ---------------------------------------------------------------------

    upload_parsed <- reactive({
      f <- input$file
      if (is.null(f) || !nzchar(f$datapath)) return(NULL)
      .data_read_csv(f$datapath)          # the shared strict reader (mod_data.R)
    })

    set_raw <- function(raw, label, src) {
      ca_reset_assessment(state)          # helpers.R F.13 — always first (§B.6)
      state$raw <- raw
      state$label <- label
      state$source <- src
      state$map <- NULL
      state$dropped <- NULL
      state$prepared <- NULL
      state$fit <- NULL
      # A clinician confirmed plausibility for THAT population, not for every
      # population, so the two answers are re-asked on a dataset change.
      state$expert_q1 <- ""
      state$expert_q2 <- ""
      state$expert_confirmed <- FALSE
      invisible(NULL)
    }

    #' A first guess at the mapping for a file the registry has never seen.
    #'
    #' INTEGRATION FIX, matching app/ and app-v2/: the old fallback proposed the
    #' FIRST column as the status column, so an ordinary two-column
    #' `time,status` upload had its TIME column offered as the status column and
    #' the smallest time value as the event level. All three versions now guess
    #' the same way. It reads column NAMES and counts distinct values only, and
    #' it is a suggestion - every control stays under the user's hand.
    #' @noRd
    .guess_map <- function(raw) {
      cols <- names(raw)
      num  <- names(raw)[vapply(raw, is.numeric, logical(1))]
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

    refresh_mapping <- function(raw, entry = NULL) {
      num <- names(raw)[vapply(raw, is.numeric, logical(1))]
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

      lv <- .v3_levels(if (!is.null(s_def)) raw[[s_def]] else NULL)
      e_def <- if (!is.null(entry) && as.character(entry$event_level) %in% lv) {
        as.character(entry$event_level)
      } else if (is.null(entry) && "1" %in% lv) {
        "1"
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

    observeEvent(input$example, {
      req(identical(input$source, "builtin"))
      load_builtin(input$example)
    }, ignoreInit = TRUE)

    observeEvent(input$source, {
      if (identical(input$source, "builtin")) {
        load_builtin(input$example)
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

    # Keep the event-level choices in step with the chosen status column.
    observeEvent(list(state$raw, input$col_status), {
      raw <- state$raw
      req(is.data.frame(raw))
      sc <- input$col_status
      if (is.null(sc) || !sc %in% names(raw)) return(invisible(NULL))
      lv <- .v3_levels(raw[[sc]])
      entry <- if (identical(input$source, "builtin")) CA_DATASETS[[input$example]] else NULL
      want <- if (!is.null(entry) && identical(entry$status, sc)) as.character(entry$event_level) else NULL
      sel <- if (!is.null(want) && want %in% lv) want
             else if (!is.null(input$event_level) && input$event_level %in% lv) input$event_level
             else if (length(lv)) lv[[1L]] else NULL
      updateSelectInput(session, "event_level", choices = lv, selected = sel)
    }, ignoreInit = TRUE)

    # A mapping change clears the verdict immediately (§B.6). "Changed" means
    # changed away from the mapping that produced state$prepared, so the echo of
    # our own updateSelectInput() calls is correctly a no-op.
    observeEvent(
      list(input$col_time, input$col_status, input$event_level, input$time_scale), {
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
      }, ignoreInit = TRUE)

    # ---------------------------------------------------------------------
    # 2. PRE-FLIGHT — everything knowable without calling the package
    # ---------------------------------------------------------------------

    preflight <- reactive({
      raw <- state$raw
      tc <- input$col_time; sc <- input$col_status; el <- input$event_level
      if (!is.data.frame(raw) || is.null(tc) || is.null(sc) || is.null(el) ||
          !tc %in% names(raw) || !sc %in% names(raw)) {
        return(list(block = TRUE, error = NULL, cleaned = NULL))
      }
      cleaned <- tryCatch(
        ca_clean_surv(raw, tc, sc, as.character(el)),         # helpers.R F.17
        error = function(e) list(data = NULL, dropped = NULL, error = conditionMessage(e))
      )
      if (!is.data.frame(cleaned$data)) {
        return(list(block = TRUE,
                    error = if (!is.null(cleaned$error)) cleaned$error else "Preparing the data failed.",
                    cleaned = cleaned))
      }
      list(block = FALSE, error = NULL, cleaned = cleaned)
    })

    # ---------------------------------------------------------------------
    # 3. §B.2 — AUTO-PREPARE. No button.
    # ---------------------------------------------------------------------

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
      ca_reset_assessment(state)                      # §B.6, first statement

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
        return(fail("These data have no events, so there is nothing to assess."))
      }

      res <- tryCatch(
        withProgress(message = "Preparing data", value = 0, {
          incProgress(0.2, detail = "Standardising the time and event columns")
          # The ONE prepare call in this version, and the only place time is
          # scaled (S5): everything downstream reads state$prepared.
          prepared <- cureAssess::prepare.surv.data(
            data = cleaned$data, time = "..Y_raw", status = "..D01",
            time_scale = time_scale
          )
          incProgress(0.3, detail = "Fitting candidate models")
          # plot_km = TRUE so state$fit$kmplot and $kmfit exist for the curve
          # panel. suppressMessages(): survminer emits a cosmetic ggplot2 note
          # while it builds the risk table. Nothing statistical is suppressed.
          fit <- suppressMessages(cureAssess::model.fitting(
            data = prepared, plot_km = TRUE, include_lognormal = FALSE
          ))
          incProgress(0.5, detail = "Done")
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

    # The 5-tuple, debounced by 600 ms (§B.1 reactive 1). Every intermediate
    # change restarts the timer, so switching dataset — which also rewrites the
    # four mapping controls from the registry — costs exactly one preparation.
    map_tuple <- debounce(reactive({
      list(source = input$source, key = input$example,
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
          state$status %in% c("prepared", "assessed")) {
        return(invisible(NULL))
      }
      if (isTRUE(preflight()$block)) return(invisible(NULL))
      do_prepare(tup$time, tup$status, tup$event_level, tup$time_scale)
    }, ignoreInit = FALSE)

    # Launch preparation, so no panel is ever empty on first paint and the
    # verdict strip carries a real answer before the reader has done anything.
    observeEvent(TRUE, {
      entry <- load_builtin("gbsg")
      if (is.null(entry)) return(invisible(NULL))
      do_prepare(entry$time, entry$status, as.character(entry$event_level), entry$time_scale)
    }, once = TRUE, ignoreInit = FALSE)

    # ---------------------------------------------------------------------
    # 4. §B.3 — AUTO-ASSESS. Still no button.
    # ---------------------------------------------------------------------

    assessed_key <- NULL

    assess_now <- function() {
      if (is.null(state$prepared)) {
        assessed_key <<- NULL
        state$assess <- NULL
        if (!identical(state$status, "error")) state$status <- "empty"
        return(invisible(NULL))
      }
      key <- list(prepared = state$prepared, lognormal = isTRUE(state$include_lognormal))
      if (identical(key, assessed_key) &&
          (!is.null(state$assess) || !is.null(state$last_error))) {
        return(invisible(NULL))
      }

      prepared <- state$prepared
      use_lognormal <- isTRUE(state$include_lognormal)

      # S7 — a package failure is a normal outcome, not a crash. The call is
      # ca_assess_once() (helpers.R F.22): S2 run_tests = "yes",
      # S5 time_scale = "none", S3 dist = NULL. It is the ONE call site in the
      # repository and this file does not write its own.
      res <- tryCatch(
        withProgress(message = "Assessing", value = 0, {
          incProgress(0.2, detail = "Fitting candidate models")
          a <- ca_assess_once(prepared, include_lognormal = use_lognormal)
          incProgress(0.8)
          a
        }),
        error = function(e) structure(list(msg = conditionMessage(e)), class = "ca_failed")
      )

      assessed_key <<- key

      if (inherits(res, "ca_failed")) {
        state$assess <- NULL
        state$alpha_tests <- NULL
        state$last_error <- res$msg
        state$status <- "prepared"
        return(invisible(NULL))
      }

      state$include_lognormal <- use_lognormal
      state$assess <- res
      state$alpha_tests <- .v3_alpha_tests(prepared, state$alpha)
      state$last_error <- NULL
      state$status <- "assessed"
      invisible(NULL)
    }

    observeEvent(list(state$prepared, state$include_lognormal), {
      assess_now()
    }, ignoreNULL = FALSE)

    # The catch-up trigger: a re-prepare that lands on an identical frame does
    # not invalidate state$prepared, but does move the status.
    observeEvent(state$status, assess_now(), ignoreInit = FALSE)

    observeEvent(input$include_lognormal, {
      state$include_lognormal <- isTRUE(input$include_lognormal)
    }, ignoreInit = TRUE)

    # ---------------------------------------------------------------------
    # 5. §B.1 reactive 4 — alpha, debounced 400 ms. DISPLAY ONLY.
    # ---------------------------------------------------------------------

    alpha_r <- debounce(reactive(input$alpha), 400)

    observeEvent(alpha_r(), {
      a <- alpha_r()
      if (is.null(a) || !is.finite(a)) return(invisible(NULL))
      state$alpha <- a
      state$alpha_tests <- .v3_alpha_tests(state$prepared, a)
      invisible(NULL)
    }, ignoreInit = TRUE)

    # ---------------------------------------------------------------------
    # 6. THE TWO EXPERT ANSWERS — this module is their only writer
    # ---------------------------------------------------------------------

    observe({
      q1 <- .v3_answer(input$q1)
      q2 <- .v3_answer(input$q2)
      state$expert_q1 <- q1
      state$expert_q2 <- q2
      state$expert_confirmed <- identical(q1, "yes") && identical(q2, "yes")
    })

    observeEvent(state$expert_q1, {
      if (!identical(.v3_answer(input$q1), state$expert_q1)) {
        updateRadioButtons(session, "q1", choices = c("Yes", "No"),
                           selected = .v3_choice(state$expert_q1), inline = TRUE)
      }
    }, ignoreInit = TRUE)

    observeEvent(state$expert_q2, {
      if (!identical(.v3_answer(input$q2), state$expert_q2)) {
        updateRadioButtons(session, "q2", choices = c("Yes", "No"),
                           selected = .v3_choice(state$expert_q2), inline = TRUE)
      }
    }, ignoreInit = TRUE)

    # ---------------------------------------------------------------------
    # 7. THE PANE'S OWN RENDERS
    # ---------------------------------------------------------------------

    output$load_msg <- renderUI({
      up <- upload_parsed()
      if (identical(input$source, "upload") && !is.null(up) && !is.null(up$error)) {
        txt <- switch(
          up$error,
          delimiter = "That file does not look comma-separated. Save it as a comma-separated CSV and try again.",
          onecol    = "That file does not look comma-separated. Save it as a comma-separated CSV and try again.",
          ragged    = sprintf("Row %s has a different number of fields from the header.",
                              format(up$detail, trim = TRUE)),
          "That file could not be read. Check it is comma-separated with a header row."
        )
        return(ca_note("warning", "That file could not be read", htmltools::p(txt)))
      }
      if (is.null(state$raw)) return(ca_empty("Pick an example or upload a CSV."))
      NULL
    })

    # The mapping, stated as one line. Column names are the user's own data,
    # not package spellings, so C1 is untouched.
    output$map_summary <- renderUI({
      m <- state$map
      if (is.null(m)) {
        return(htmltools::span(class = "v3-map__sum is-empty", "Choose the columns"))
      }
      scale_txt <- if (identical(m$time_scale, "days_to_years")) " · days → years" else ""
      htmltools::span(
        class = "v3-map__sum",
        htmltools::span(
          class = "v3-map__line",
          htmltools::span(class = "v3-map__k", "time"),
          htmltools::span(class = "v3-map__v", as.character(m$time)),
          htmltools::span(class = "v3-map__x", scale_txt)
        ),
        htmltools::span(
          class = "v3-map__line",
          htmltools::span(class = "v3-map__k", "event"),
          htmltools::span(class = "v3-map__v",
                          paste0(as.character(m$status), " = ", as.character(m$event_level)))
        )
      )
    })

    output$map_msg <- renderUI({
      pf <- preflight()
      out <- list()
      if (!is.null(pf$error)) {
        out[[length(out) + 1L]] <- ca_note(
          "warning", "These columns cannot be used",
          htmltools::tagList(
            htmltools::p(.data_sentence(pf$error)),      # the shared one-liner
            ca_tech(htmltools::tags$pre(pf$error))
          )
        )
      }
      if (identical(state$status, "error") && !is.null(state$last_error)) {
        out[[length(out) + 1L]] <- ca_note(
          "warning", "Preparing the data failed",
          htmltools::tagList(
            htmltools::p(.data_sentence(state$last_error)),
            ca_tech(htmltools::tags$pre(state$last_error))
          )
        )
      }
      d <- state$dropped
      if (!length(out) && !is.null(d) && isTRUE(d$n_total > d$n_kept)) {
        out[[length(out) + 1L]] <- htmltools::p(
          class = "ca-provenance",
          sprintf("Dropped %s of %s rows with a missing time or status. Every count is after dropping.",
                  format(d$n_total - d$n_kept, big.mark = ",", trim = TRUE),
                  format(d$n_total, big.mark = ",", trim = TRUE))
        )
      }
      if (!length(out)) return(NULL)
      htmltools::tagList(out)
    })

    output$preview <- DT::renderDT({
      prepared <- state$prepared
      validate(need(is.data.frame(prepared), "The first rows appear once a dataset is loaded."))
      d <- utils::head(prepared, 10L)
      d <- d[, setdiff(names(d), c("..Y_raw", "..D01")), drop = FALSE]
      ord <- c(intersect(c("Y", "D"), names(d)), setdiff(names(d), c("Y", "D")))
      d <- d[, ord, drop = FALSE]
      num  <- names(d)[vapply(d, is.numeric, logical(1))]
      frac <- num[vapply(d[num], function(x) {
        x <- x[is.finite(x)]; length(x) > 0L && any(x != round(x))
      }, logical(1))]
      tbl <- DT::datatable(
        d, rownames = FALSE, class = "compact stripe",
        options = list(dom = "t", ordering = FALSE, scrollX = TRUE, pageLength = 10L)
      )
      if (length(frac)) tbl <- DT::formatRound(tbl, columns = frac, digits = 4L)
      tbl
    })

    # The report's failure surface lives here, beside the take-away section;
    # the button itself is pinned in the verdict strip. mod_v3_strip.R writes
    # this value.
    output$download_msg <- renderUI({
      msg <- state$report_error
      if (is.null(msg)) return(NULL)
      ca_note(
        "warning", "The report could not be generated",
        htmltools::tagList(
          htmltools::p("The verdict above is unchanged."),
          ca_tech(htmltools::tags$p(msg))
        )
      )
    })

    # What the canvas needs and cannot reach across a module boundary.
    list(receus_dist = reactive(input$receus_dist))
  })
}


# ---- two small private utilities -------------------------------------------

#' Distinct values of a status column, labelled with their row counts.
#' @noRd
.v3_levels <- function(x) {
  if (is.null(x)) return(character(0))
  v <- x[!is.na(x)]
  if (is.factor(v)) v <- as.character(v)
  v <- as.character(v)
  if (!length(v)) return(character(0))
  tb <- table(v); lv <- names(tb); cnt <- as.integer(tb)
  num <- suppressWarnings(as.numeric(lv))
  ord <- if (!anyNA(num)) order(num) else order(lv)
  stats::setNames(lv[ord], sprintf("%s (%s rows)", lv[ord],
                                   format(cnt[ord], big.mark = ",", trim = TRUE)))
}

#' The alpha re-calls, or NULL at the package default.
#'
#' NULL is load-bearing: `state$alpha_tests == NULL` is how the rest of the app
#' knows alpha is still 0.05, so the default must never be stored as a
#' recomputed pair.
#' @noRd
.v3_alpha_tests <- function(prepared, alpha) {
  if (is.null(prepared)) return(NULL)
  if (is.null(alpha) || !is.finite(alpha)) return(NULL)
  if (abs(alpha - .V3_ALPHA_DEFAULT) < 1e-9) return(NULL)
  ca_tests_at_alpha(prepared, alpha)     # mod_quantitative.R, §F.3
}
