# ---------------------------------------------------------------------------
# mod_batch.R — the batch engine and its UI module (owner: builder-batch)
#
# V2_CONTRACT §C. Two input shapes, both required:
#   (a) several datasets assessed together;
#   (b) ONE dataset split by a grouping column, each arm assessed SEPARATELY,
#       because every published reading here applies to one homogeneous group.
#
# File order, fixed by §C.0: constants, .ca_batch_frame_one(), the three frame
# (spec) builders, ca_batch_assess(), ca_batch_csv(), ca_batch_group_choices(),
# then mod_batch_ui() / mod_batch_server(). NOTHING in this file runs at source
# time — the CA_BATCH_* constants it references live in helpers.R (§C.1) and are
# only ever touched when a function is called.
#
# The engine half (everything above mod_batch_ui) imports no Shiny, holds no
# reactive, never touches `state` and never throws. app-v2 and app-v3 mount the
# module rather than re-implementing any of it (§C.0, §F.2).
#
# FIELD PROVENANCE (C1 — kept in code, never on screen). Every value in a row
# is read from the object cure.appropriateness() returns, through the one call
# site ca_assess_once() (§B.4):
#   best_model            <- $screening$best_model      (rendered via CA_MODEL_LABELS)
#   is_cure_model         <- $screening$best_model_type == "cure"
#   aic                   <- $screening$aic_table$AIC at the best_model row
#   maller_zhou           <- $tests$mz$statistic      threshold $tests$mz$alpha
#   qn                    <- $tests$qn$statistic      threshold ca_qn_threshold(n, .05)
#   shen                  <- $tests$shen$statistic    threshold $tests$shen$alpha
#   cure_fraction         <- $tests$receus$pi_hat
#   uncured_censored_ratio<- $tests$receus$r_hat
#   receus_decision       <- $tests$receus$decision (verbatim)
#   the F20 branch keys on $tests_run
# The only app-side numbers are ca_data_summary() descriptives and the qn
# threshold closed form — the two things rule S1 permits.
#
# Private helpers carry the `.ca_batch_` prefix.
# ---------------------------------------------------------------------------


# ===========================================================================
# 1. CONSTANTS
# ===========================================================================

# The two markers that stand in for a missing cell in the downloaded file
# (§C.4). Never a blank, never the literal NA. Which one is used is read off
# the `assessed` column, never guessed. On screen the same cells are ca_dash().
.CA_BATCH_NOT_COMPUTABLE <- "not computable"
.CA_BATCH_NOT_ASSESSED   <- "not assessed"

# The 23 columns of §C.4, in the frozen order. Lower snake_case with no spaces
# so the file re-imports cleanly; no function, field or package name among them.
.CA_BATCH_COLS <- c(
  "dataset", "n", "events", "censored_pct", "median_followup", "max_followup",
  "time_unit", "best_model", "is_cure_model", "aic",
  "maller_zhou", "maller_zhou_threshold", "qn", "qn_threshold",
  "shen", "shen_threshold", "cure_fraction", "uncured_censored_ratio",
  "receus_decision", "expert_judgment", "recommendation", "assessed", "reason"
)

# The columns that are always populated, so the marker substitution above skips
# them. `reason` is legitimately empty on a clean row and must stay empty.
.CA_BATCH_ALWAYS <- c("dataset", "time_unit", "expert_judgment", "assessed", "reason")

# ---- the exact user-facing sentences of §C.7 -------------------------------
# Every failure row carries one of these. There is no code path that leaves a
# reason blank while anything else on the row is missing.

.CA_BATCH_F4  <- "Not assessed: no events, so there is nothing to model."
.CA_BATCH_F6  <- "Not assessed: the time column is not numeric in this file."
.CA_BATCH_F8  <- "Not assessed: no row in this group has the value that means the event."
.CA_BATCH_F9  <- "Not assessed: every row has a missing time or status."
.CA_BATCH_F10 <- "Not assessed: some times are negative or not finite."
.CA_BATCH_F16 <- "Not assessed: that file could not be read as comma-separated values."
.CA_BATCH_F13 <- "Every row has the same value in that column, so there is nothing to split."
.CA_BATCH_F14 <- "Choose the datasets to assess, or a column to split by."
.CA_BATCH_F15 <- "Load a dataset on the Data step first."
.CA_BATCH_F17 <- "Not assessed: the models could not be fitted for this group."
.CA_BATCH_F20 <- paste("No cure model could be fitted, so the follow-up and",
                       "cured-group diagnostics were not run.")
.CA_BATCH_F21 <- "No model could be fitted to this group."
.CA_BATCH_F23 <- paste("Nobody has answered the expert-judgment question, so every",
                       "recommendation below is provisional.")
.CA_BATCH_F24 <- "Available once an assessment has run."

.CA_BATCH_F1 <- function(n, min_n) sprintf(
  "Not assessed: only %s rows after dropping missing times and statuses, and %s are needed.",
  format(n, big.mark = ",", trim = TRUE), format(min_n, trim = TRUE))

.CA_BATCH_F2 <- function(e, min_events) sprintf(
  "Not assessed: %s events. At least %s are needed to fit a cure model.",
  format(e, big.mark = ",", trim = TRUE), format(min_events, trim = TRUE))

.CA_BATCH_F3 <- function(cens, min_censored) sprintf(
  paste("Not assessed: %s censored observations. At least %s are needed to estimate",
        "a cured group. Open it on its own to look at it anyway."),
  format(cens, big.mark = ",", trim = TRUE), format(min_censored, trim = TRUE))

.CA_BATCH_F5 <- function(k) sprintf(
  "%s rows have no value in that column and are in no group.",
  format(k, big.mark = ",", trim = TRUE))

.CA_BATCH_F7 <- function(col) sprintf("Not assessed: this file has no column called %s.", col)

.CA_BATCH_F12 <- function(k, max_groups) sprintf(
  "That column has %s distinct values. This handles up to %s groups at once — pick a column with fewer.",
  format(k, big.mark = ",", trim = TRUE), format(max_groups, trim = TRUE))

.CA_BATCH_F22 <- function(n) sprintf(
  paste("Assessed. n = %s is below the size this tool has been checked against,",
        "so treat this row as indicative."),
  format(n, big.mark = ",", trim = TRUE))

#' F19 — the S6 void sentence
#'
#' §C.7 asks for the Quantitative tab's own void line, reused verbatim so the
#' screen and the downloaded file say the same thing. That constant lives in a
#' file this builder does not own and is resolved at CALL time (this file sorts
#' before mod_quantitative.R, so it cannot be read at source time). The literal
#' below is the §C.7 table's wording and is the fallback only.
#' @noRd
.ca_batch_f19 <- function() {
  if (exists(".QUANT_VOID_LINE", inherits = TRUE)) {
    v <- get(".QUANT_VOID_LINE", inherits = TRUE)
    if (is.character(v) && length(v) == 1L && nzchar(v)) return(v)
  }
  "Follow-up diagnostics cannot be computed: the longest observed time is an event."
}


# ===========================================================================
# 2. .ca_batch_frame_one() — raw frame + mapping -> one analysable frame
# ===========================================================================

#' Turn one raw frame and one mapping into a prepared frame, or a refusal
#'
#' ca_clean_surv() (the 0/1 recode, rule S5) -> the size gate -> the ONE
#' preparation call for the batch path. Shared by all three input shapes so
#' every version gates identically (§C.6).
#'
#' Time is scaled exactly once, here; the engine then passes
#' `time_scale = "none"` to the assessment (S5).
#'
#' @param raw the dataset as loaded.
#' @param map `list(time, status, event_level, time_scale)`.
#' @param label the row label; carried through for the caller's convenience.
#' @return `list(frame, blocked, error)`. `frame` is a prepared frame or NULL;
#'   `blocked` is `""` or one of the §C.7 pre-flight sentences; `error` is raw
#'   package text for the technical disclosure only, or `""`.
#' @noRd
.ca_batch_frame_one <- function(raw, map, label = NULL,
                                min_n        = CA_BATCH_MIN$n,
                                min_events   = CA_BATCH_MIN$events,
                                min_censored = CA_BATCH_MIN$censored) {

  out <- function(frame = NULL, blocked = "", error = "") {
    list(frame = frame, blocked = blocked, error = error, label = label)
  }

  if (!is.data.frame(raw) || nrow(raw) == 0L) return(out(blocked = .CA_BATCH_F9))
  if (!is.list(map) || is.null(map$time) || is.null(map$status)) {
    return(out(blocked = .CA_BATCH_F14))
  }

  want <- c(map$time, map$status)
  absent <- want[!want %in% names(raw)]
  if (length(absent)) return(out(blocked = .CA_BATCH_F7(absent[[1L]])))

  cleaned <- tryCatch(
    ca_clean_surv(raw, map$time, map$status, as.character(map$event_level)),
    error = function(e) list(data = NULL, dropped = NULL, error = conditionMessage(e))
  )

  if (!is.data.frame(cleaned$data)) {
    # ca_clean_surv() is the single authority on which mappings are refusable,
    # and every one of its five refusals maps to a §C.7 sentence. The catch-all
    # is unreachable today and exists so a future refusal cannot arrive blank.
    txt <- if (is.null(cleaned$error)) "" else as.character(cleaned$error)[[1L]]
    sentence <-
      if (grepl("not numeric", txt, fixed = TRUE))            .CA_BATCH_F6
      else if (grepl("No rows have that value", txt, fixed = TRUE)) .CA_BATCH_F8
      else if (grepl("negative or not finite", txt, fixed = TRUE))  .CA_BATCH_F10
      else if (grepl("nothing to analyse", txt, fixed = TRUE))      .CA_BATCH_F9
      else if (grepl("no events", txt, fixed = TRUE))               .CA_BATCH_F4
      else .CA_BATCH_F17
    return(out(blocked = sentence, error = txt))
  }

  d01    <- as.integer(cleaned$data[["..D01"]])
  n_kept <- nrow(cleaned$data)
  events <- sum(d01 == 1L, na.rm = TRUE)
  cens   <- n_kept - events

  # THE SIZE GATE (§C.1). Applied here and again inside the engine, so the
  # engine is safe when a frame reaches it by another route.
  if (events == 0L)           return(out(blocked = .CA_BATCH_F4))
  if (n_kept < min_n)         return(out(blocked = .CA_BATCH_F1(n_kept, min_n)))
  if (events < min_events)    return(out(blocked = .CA_BATCH_F2(events, min_events)))
  if (cens   < min_censored)  return(out(blocked = .CA_BATCH_F3(cens, min_censored)))

  ts <- if (is.null(map$time_scale)) "none" else as.character(map$time_scale)
  prepared <- tryCatch(
    cureAssess::prepare.surv.data(
      data = cleaned$data, time = "..Y_raw", status = "..D01", time_scale = ts
    ),
    error = function(e) e
  )
  if (inherits(prepared, "condition")) {
    return(out(blocked = .CA_BATCH_F17, error = conditionMessage(prepared)))
  }
  out(frame = prepared)
}


#' The time-unit word for a mapping (§C.4 column 7)
#' @noRd
.ca_batch_time_unit <- function(time_scale) {
  if (identical(as.character(time_scale), "days_to_years")) "years" else "original units"
}


# ===========================================================================
# 3. THE THREE FRAME BUILDERS
# ===========================================================================
#
# Each returns `list(specs = list(...), notes = character(0))`. A spec is
#   list(label, provenance, time_unit, build = function() .ca_batch_frame_one(...))
# and is built ONLY on a cache miss (§C.6), so ticking a fourth checkbox costs
# one assessment and unticking costs nothing. Provenance is the memo key: it
# names where a row came from and the whole mapping that produced it, never the
# data, so a mapping change invalidates every row that used it (§B.6).

#' Specs for built-in example datasets — shape (a)
#'
#' The registry already carries `time`, `status`, `event_level` and
#' `time_scale` per entry, which is why this shape offers no mapping controls
#' at all (§C.6).
#' @noRd
ca_batch_specs_builtin <- function(keys, include_lognormal = FALSE) {
  keys <- as.character(keys)
  keys <- keys[nzchar(keys)]
  specs <- list()
  for (k in keys) {
    entry <- if (exists("CA_DATASETS")) CA_DATASETS[[k]] else NULL
    if (is.null(entry)) next
    local({
      key <- k
      e   <- entry
      map <- list(time = e$time, status = e$status,
                  event_level = as.character(e$event_level), time_scale = e$time_scale)
      specs[[length(specs) + 1L]] <<- list(
        label      = as.character(e$label),
        provenance = paste("builtin", key, isTRUE(include_lognormal), sep = "|"),
        time_unit  = .ca_batch_time_unit(e$time_scale),
        build      = function() {
          raw <- tryCatch(ca_dataset_load(key), error = function(err) err)
          if (inherits(raw, "condition")) {
            return(list(frame = NULL, blocked = .CA_BATCH_F16,
                        error = conditionMessage(raw), label = as.character(e$label)))
          }
          .ca_batch_frame_one(raw, map, as.character(e$label))
        }
      )
    })
  }
  list(specs = specs, notes = character(0))
}


#' Specs for uploaded files, and for the dataset already on the Data step
#'
#' Uploaded files share ONE mapping: a batch is a set of comparable datasets,
#' and files with different schemas are separate analyses (§C.6). A file that
#' lacks the chosen column becomes a row carrying F7, never a silent drop.
#'
#' @param files `list(list(name, data))` — already parsed, so a parse failure is
#'   passed in as `data = NULL` and surfaces as F16.
#' @noRd
ca_batch_specs_upload <- function(files, map, include_lognormal = FALSE) {
  specs <- list()
  if (!length(files)) return(list(specs = specs, notes = character(0)))
  unit <- .ca_batch_time_unit(map$time_scale)
  for (i in seq_along(files)) {
    local({
      f <- files[[i]]
      lab <- as.character(f$name)
      specs[[length(specs) + 1L]] <<- list(
        label      = lab,
        provenance = paste("upload", lab, map$time, map$status,
                           as.character(map$event_level), map$time_scale,
                           isTRUE(include_lognormal), sep = "|"),
        time_unit  = unit,
        build      = function() {
          if (!is.data.frame(f$data)) {
            return(list(frame = NULL, blocked = .CA_BATCH_F16,
                        error = if (is.null(f$error)) "" else as.character(f$error),
                        label = lab))
          }
          .ca_batch_frame_one(f$data, map, lab)
        }
      )
    })
  }
  list(specs = specs, notes = character(0))
}


#' Specs for one dataset split by a grouping column — shape (b)
#'
#' Source is the dataset on the Data step and the mapping is reused verbatim:
#' no second upload and no second mapping (§C.6). Rows with no value in the
#' grouping column form no group and are reported once, above the table (F5).
#' @noRd
ca_batch_specs_group <- function(raw, map, group_col, source_id = "current",
                                 include_lognormal = FALSE,
                                 max_groups = CA_BATCH_MAX_GROUPS) {
  none <- function(notes = character(0)) list(specs = list(), notes = notes)

  if (!is.data.frame(raw) || nrow(raw) == 0L) return(none(.CA_BATCH_F15))
  if (is.null(group_col) || !nzchar(group_col) || !group_col %in% names(raw)) {
    return(none(.CA_BATCH_F14))
  }

  g  <- raw[[group_col]]
  if (is.factor(g)) g <- as.character(g)
  gc <- as.character(g)
  na_rows <- sum(is.na(gc) | !nzchar(trimws(gc)))
  keep    <- !is.na(gc) & nzchar(trimws(gc))
  levels_present <- unique(gc[keep])

  notes <- character(0)
  if (na_rows > 0L) notes <- c(notes, .CA_BATCH_F5(na_rows))

  if (length(levels_present) < 2L) return(none(c(notes, .CA_BATCH_F13)))
  if (length(levels_present) > max_groups) {
    return(none(c(notes, .CA_BATCH_F12(length(levels_present), max_groups))))
  }

  # numeric levels in numeric order, everything else in the order the file uses
  num <- suppressWarnings(as.numeric(levels_present))
  levels_present <- if (!anyNA(num)) levels_present[order(num)] else levels_present

  unit  <- .ca_batch_time_unit(map$time_scale)
  specs <- list()
  for (lv in levels_present) {
    local({
      level <- lv
      # INTEGRATION FIX: the label was the BARE level, so splitting gbsg by
      # `meno` produced rows called "0" and "1" - in the table and, worse, in
      # the downloaded CSV, where there is no surrounding context at all. §C.4
      # column 1 is "the dataset or arm NAME". Naming the column with it makes
      # every row self-describing: "meno = 0", "rx = Lev+5FU".
      lab   <- sprintf("%s = %s", group_col, as.character(level))
      specs[[length(specs) + 1L]] <<- list(
        label      = lab,
        provenance = paste("group", source_id, map$time, map$status,
                           as.character(map$event_level), map$time_scale,
                           group_col, level, isTRUE(include_lognormal), sep = "|"),
        time_unit  = unit,
        build      = function() {
          sub <- raw[keep & gc == level, , drop = FALSE]
          .ca_batch_frame_one(sub, map, lab)
        }
      )
    })
  }
  list(specs = specs, notes = notes)
}


# ===========================================================================
# 4. ca_batch_assess() — THE ENGINE
# ===========================================================================

#' An empty results frame with the 23 columns of §C.4, in order
#' @noRd
.ca_batch_empty_df <- function(k = 0L) {
  chr <- function() rep(NA_character_, k)
  num <- function() rep(NA_real_, k)
  int <- function() rep(NA_integer_, k)
  out <- data.frame(
    dataset = chr(), n = int(), events = int(), censored_pct = num(),
    median_followup = num(), max_followup = num(), time_unit = chr(),
    best_model = chr(), is_cure_model = chr(), aic = num(),
    maller_zhou = num(), maller_zhou_threshold = num(),
    qn = num(), qn_threshold = num(), shen = num(), shen_threshold = num(),
    cure_fraction = num(), uncured_censored_ratio = num(),
    receus_decision = chr(), expert_judgment = chr(), recommendation = chr(),
    assessed = chr(), reason = chr(),
    stringsAsFactors = FALSE
  )
  out[, .CA_BATCH_COLS, drop = FALSE]
}


#' The word form of the expert answer, for column 20
#' @noRd
.ca_batch_expert_word <- function(expert) {
  switch(as.character(expert)[[1L]], yes = "yes", no = "no", "not answered")
}


#' The display label for a model key, never the key itself when a label exists
#' @noRd
.ca_batch_model_label <- function(key) {
  if (is.null(key) || length(key) != 1L || is.na(key)) return(NA_character_)
  key <- as.character(key)
  if (exists("CA_MODEL_LABELS") && key %in% names(CA_MODEL_LABELS)) CA_MODEL_LABELS[[key]] else key
}


#' One row: the size gate, the ONE assessment call, and every §C.7 outcome
#'
#' Everything that can throw is inside one tryCatch, PER FRAME rather than
#' around the loop. The most likely cause of a throw is a hard failure inside
#' the package: when the internal MLE fails, both RECeUS conditions are NA and
#' `if (NA)` stops, which would otherwise kill the whole run.
#' @noRd
.ca_batch_row <- function(frame, label, blocked = "", time_unit = "original units",
                          include_lognormal = FALSE, expert = "unanswered",
                          min_n = CA_BATCH_MIN$n, min_events = CA_BATCH_MIN$events,
                          min_censored = CA_BATCH_MIN$censored) {

  row <- .ca_batch_empty_df(1L)
  row$dataset         <- as.character(label)
  row$time_unit       <- as.character(time_unit)
  row$expert_judgment <- .ca_batch_expert_word(expert)
  row$assessed        <- "no"
  row$reason          <- ""

  done <- function(r, err = "") list(row = r, error = err)

  # ---- pre-flight refusal, carried straight in (§C.2) --------------------
  if (is.character(blocked) && length(blocked) == 1L && !is.na(blocked) && nzchar(blocked)) {
    row$reason <- blocked
    return(done(row))
  }

  if (!is.data.frame(frame) || !all(c("Y", "D") %in% names(frame))) {
    row$reason <- .CA_BATCH_F17
    return(done(row))
  }

  # ---- descriptives: the counts rule S1 permits the app to make ----------
  s <- tryCatch(ca_data_summary(frame), error = function(e) NULL)
  if (is.null(s) || !isTRUE(s$n > 0L)) {
    row$reason <- .CA_BATCH_F9
    return(done(row))
  }
  cens <- s$n - s$events
  row$n               <- as.integer(s$n)
  row$events          <- as.integer(s$events)
  row$censored_pct    <- round(s$censored_pct, 1)     # presentation only (§C.4)
  row$median_followup <- s$median_followup
  row$max_followup    <- s$max_followup

  # ---- the size gate again, so the engine is safe on its own -------------
  if (s$events == 0L)        { row$reason <- .CA_BATCH_F4; return(done(row)) }
  if (s$n < min_n)           { row$reason <- .CA_BATCH_F1(s$n, min_n); return(done(row)) }
  if (s$events < min_events) { row$reason <- .CA_BATCH_F2(s$events, min_events); return(done(row)) }
  if (cens < min_censored)   { row$reason <- .CA_BATCH_F3(cens, min_censored); return(done(row)) }

  # ---- THE assessment (§B.4). plot_km = FALSE: no curve reaches a file,
  # and it halves the cost (measured 0.094/0.162/0.195 s at n = 304/686/1404).
  res <- tryCatch(
    ca_assess_once(frame, include_lognormal = isTRUE(include_lognormal), plot_km = FALSE),
    error = function(e) e
  )
  if (inherits(res, "condition")) {                             # F17
    row$reason <- .CA_BATCH_F17
    return(done(row, conditionMessage(res)))
  }

  row$assessed <- "yes"
  notes <- character(0)

  sc    <- res$screening
  btype <- if (is.null(sc$best_model_type)) NA_character_ else as.character(sc$best_model_type)[[1L]]
  best  <- if (is.null(sc$best_model)) NA_character_ else as.character(sc$best_model)[[1L]]
  tab   <- sc$aic_table

  if (is.na(best) || !is.data.frame(tab) || all(is.na(tab$AIC))) {
    # F21 — every fit failed: columns 8-19 stay missing, 21 is no recommendation
    notes <- c(notes, .CA_BATCH_F21)
  } else {
    row$best_model    <- .ca_batch_model_label(best)
    row$is_cure_model <- if (is.na(btype)) NA_character_ else if (identical(btype, "cure")) "yes" else "no"
    hit <- match(best, tab$model)
    if (!is.na(hit)) row$aic <- round(as.numeric(tab$AIC[[hit]]), 2)   # presentation only

    if (!isTRUE(res$tests_run) || is.null(res$tests)) {
      notes <- c(notes, .CA_BATCH_F20)                                # F20
    } else {
      tt <- res$tests
      pick <- function(x) {
        if (is.null(x) || length(x) != 1L) return(NA_real_)
        v <- suppressWarnings(as.numeric(x))
        if (length(v) != 1L) NA_real_ else v
      }
      mz  <- pick(tt$mz$statistic)
      qn  <- pick(tt$qn$statistic)
      shn <- pick(tt$shen$statistic)

      if (is.na(mz) && is.na(qn) && is.na(shn)) {
        # F19 — S6: the three follow-up readings go missing TOGETHER, and their
        # thresholds go with them: all six cells read the same marker.
        notes <- c(notes, .ca_batch_f19())
      } else {
        row$maller_zhou           <- mz
        row$maller_zhou_threshold <- pick(tt$mz$alpha)
        row$qn                    <- qn
        # the one app-computed value in the file: the closed form S1 permits
        row$qn_threshold          <- ca_qn_threshold(s$n, 0.05)
        row$shen                  <- shn
        row$shen_threshold        <- pick(tt$shen$alpha)
      }

      row$cure_fraction          <- pick(tt$receus$pi_hat)
      row$uncured_censored_ratio <- pick(tt$receus$r_hat)
      dec <- tt$receus$decision
      if (!is.null(dec) && length(dec) == 1L && !is.na(dec)) {
        row$receus_decision <- as.character(dec)
      }
    }
  }

  aic_type <- if (is.na(row$is_cure_model)) NA_character_
              else if (identical(row$is_cure_model, "yes")) "cure" else "non-cure"
  rec <- tryCatch(
    ca_recommendation(aic_type, row$receus_decision, expert = expert),
    error = function(e) NULL
  )
  if (!is.null(rec$headline)) row$recommendation <- as.character(rec$headline)[[1L]]

  if (s$n < CA_BATCH_WARN_N) notes <- c(notes, .CA_BATCH_F22(s$n))     # F22

  row$reason <- paste(notes, collapse = " ")
  done(row)
}


#' Assess many frames, one row each, in input order
#'
#' THE SHARED SIGNATURE (§C.2) — frozen. Imports no Shiny, holds no reactive,
#' never touches `state`, never throws.
#'
#' @param frames list of prepared frames (columns `Y`, `D`, already scaled) or
#'   NULL entries.
#' @param labels character of the same length; blanks become "Group 1"..., and
#'   duplicates go through `make.unique()`. Never NA.
#' @param blocked character or NULL; a non-empty entry is a pre-flight refusal
#'   carried straight into the row, and that frame is never touched.
#' @param time_unit "years" or "original units" for column 7.
#' @param include_lognormal passed to the assessment.
#' @param expert "yes" / "no" / "unanswered", from `ca_expert_state(state)`.
#' @param on_progress `function(i, k, label)` or NULL, called BEFORE each
#'   assessment. Shiny passes a closure over `incProgress()`; a plain script
#'   passes NULL.
#' @return `data.frame`, `nrow = length(frames)`, the 23 columns of §C.4 in that
#'   order, plus `attr(out, "errors")`: a named character vector of raw package
#'   error text for the on-screen technical disclosure only, never the file.
ca_batch_assess <- function(frames,
                            labels            = names(frames),
                            blocked           = NULL,
                            time_unit         = "original units",
                            include_lognormal = FALSE,
                            expert            = "unanswered",
                            min_n             = CA_BATCH_MIN$n,
                            min_events        = CA_BATCH_MIN$events,
                            min_censored      = CA_BATCH_MIN$censored,
                            on_progress       = NULL) {

  if (is.null(frames)) frames <- list()
  if (is.data.frame(frames)) frames <- list(frames)
  if (!is.list(frames)) frames <- as.list(frames)
  k <- length(frames)

  # labels: never NA, never blank, never duplicated
  labels <- if (is.null(labels)) rep(NA_character_, k) else as.character(labels)
  length(labels) <- k
  blank <- is.na(labels) | !nzchar(trimws(labels))
  labels[blank] <- sprintf("Group %d", seq_len(k)[blank])
  labels <- make.unique(labels, sep = " ")

  blocked <- if (is.null(blocked)) rep("", k) else as.character(blocked)
  length(blocked) <- k
  blocked[is.na(blocked)] <- ""

  time_unit <- as.character(time_unit)
  if (length(time_unit) == 1L) time_unit <- rep(time_unit, k) else length(time_unit) <- k
  time_unit[is.na(time_unit)] <- "original units"

  if (k == 0L) {
    out <- .ca_batch_empty_df(0L)
    attr(out, "errors") <- character(0)
    return(out)
  }

  rows   <- vector("list", k)
  errors <- character(0)
  for (i in seq_len(k)) {
    if (is.function(on_progress)) {
      try(on_progress(i, k, labels[[i]]), silent = TRUE)
    }
    r <- .ca_batch_row(
      frame = frames[[i]], label = labels[[i]], blocked = blocked[[i]],
      time_unit = time_unit[[i]], include_lognormal = include_lognormal,
      expert = expert, min_n = min_n, min_events = min_events,
      min_censored = min_censored
    )
    rows[[i]] <- r$row
    if (is.character(r$error) && length(r$error) == 1L && nzchar(r$error)) {
      errors[[labels[[i]]]] <- r$error
    }
  }

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out <- out[, .CA_BATCH_COLS, drop = FALSE]
  attr(out, "errors") <- errors
  out
}


#' Re-derive the two human-answer columns without re-assessing anything
#'
#' Columns 20 and 21 are the only cells that move when the expert-judgment
#' answer changes, and neither needs a package call — which is why the memo key
#' of §C.6 does not mention the answer. Rows that were never assessed keep an
#' empty recommendation: an answer cannot recommend anything about a group
#' nobody looked at.
#' @noRd
.ca_batch_apply_expert <- function(res, expert) {
  if (!is.data.frame(res) || !nrow(res)) return(res)
  res$expert_judgment <- .ca_batch_expert_word(expert)
  ok <- !is.na(res$assessed) & res$assessed == "yes"
  if (!any(ok)) return(res)
  for (i in which(ok)) {
    aic_type <- if (is.na(res$is_cure_model[[i]])) NA_character_
                else if (identical(res$is_cure_model[[i]], "yes")) "cure" else "non-cure"
    rec <- tryCatch(
      ca_recommendation(aic_type, res$receus_decision[[i]], expert = expert),
      error = function(e) NULL
    )
    res$recommendation[[i]] <- if (is.null(rec$headline)) NA_character_ else as.character(rec$headline)[[1L]]
  }
  res
}


# ===========================================================================
# 5. ca_batch_csv() — the downloaded record
# ===========================================================================

#' Render a results frame as comma-separated text
#'
#' `formatC(digits = 6, format = "g")` keeps 0.0494606 readable and 1.04e-140
#' intact; quoting stays ON because reason strings contain commas. Missing
#' cells take one of the two markers of §C.4, chosen by reading the `assessed`
#' column — never guessed, never blank, never the literal NA.
#'
#' @param results the `ca_batch_assess()` return.
#' @return character(1), ready for `writeLines()`.
ca_batch_csv <- function(results) {
  if (!is.data.frame(results)) results <- .ca_batch_empty_df(0L)
  missing_cols <- setdiff(.CA_BATCH_COLS, names(results))
  if (length(missing_cols)) {
    for (cc in missing_cols) results[[cc]] <- NA
  }
  out <- results[, .CA_BATCH_COLS, drop = FALSE]

  assessed <- as.character(out$assessed)
  assessed[is.na(assessed)] <- "no"
  marker <- ifelse(assessed == "yes", .CA_BATCH_NOT_COMPUTABLE, .CA_BATCH_NOT_ASSESSED)

  for (cc in .CA_BATCH_COLS) {
    v <- out[[cc]]
    gone <- is.na(v)
    txt <- if (is.numeric(v)) formatC(as.numeric(v), digits = 6, format = "g") else as.character(v)
    txt <- trimws(txt)
    if (!cc %in% .CA_BATCH_ALWAYS) {
      gone <- gone | !nzchar(txt)
      txt[gone] <- marker[gone]
    } else {
      txt[gone] <- ""
    }
    out[[cc]] <- txt
  }

  lines <- character(0)
  tc <- textConnection("lines", open = "w", local = TRUE)
  on.exit(try(close(tc), silent = TRUE), add = TRUE)
  utils::write.csv(out, file = tc, row.names = FALSE)
  close(tc)
  on.exit()
  paste0(paste(lines, collapse = "\n"), "\n")
}


# ===========================================================================
# 6. ca_batch_group_choices() — which columns may be split on
# ===========================================================================

#' The grouping columns a dataset offers, labelled with their level counts
#'
#' A column qualifies when it is not the time column, not the status column,
#' has 2 to `CA_BATCH_MAX_GROUPS` distinct non-missing values, and is not
#' numeric with more than 20 distinct values — the numeric guard is what stops
#' someone picking a measurement and generating 300 groups of one row (§C.6).
#'
#' @param raw the dataset as loaded.
#' @param map `list(time, status, ...)`.
#' @return named character; names are labels like `"rx (3 levels)"`, values are
#'   column names. `character(0)` when nothing qualifies.
ca_batch_group_choices <- function(raw, map = NULL) {
  if (!is.data.frame(raw) || !ncol(raw) || !nrow(raw)) return(character(0))
  max_groups <- CA_BATCH_MAX_GROUPS

  skip <- c(map$time, map$status, "..Y_raw", "..D01")
  skip <- skip[!is.null(skip)]

  vals <- character(0)
  labs <- character(0)
  for (cc in setdiff(names(raw), skip)) {
    v <- raw[[cc]]
    if (is.factor(v)) v <- as.character(v)
    if (is.list(v)) next
    keep <- !is.na(v)
    if (is.character(v)) keep <- keep & nzchar(trimws(v))
    u <- unique(v[keep])
    k <- length(u)
    if (k < 2L || k > max_groups) next
    if (is.numeric(v) && k > 20L) next
    vals <- c(vals, cc)
    labs <- c(labs, sprintf("%s (%d levels)", cc, k))
  }
  if (!length(vals)) return(character(0))
  stats::setNames(vals, labs)
}


# ===========================================================================
# 7. UI
# ===========================================================================

#' Batch panel UI
#'
#' Returns plain content; the caller supplies the chrome. In the baseline the
#' Recommendation tab wraps it in one accordion panel, closed by default (§C.6);
#' the alternatives mount the two sections in their own frames, which is what
#' `section` is for — `mod_batch_ui(id)` on its own is unchanged.
#'
#' @param id module id.
#' @param section "both" (default), "chooser" or "results".
#' @noRd
mod_batch_ui <- function(id, section = c("both", "chooser", "results")) {
  section <- match.arg(section)
  ns <- NS(id)

  chooser <- htmltools::div(
    class = "ca-batch__chooser",
    radioButtons(
      ns("shape"), NULL,
      choices  = c("These datasets" = "sets",
                   "Split this dataset by a column" = "split"),
      selected = "sets"
    ),
    conditionalPanel(
      condition = "input.shape == 'sets'", ns = ns,
      uiOutput(ns("pick_sets")),
      fileInput(ns("files"), "Add CSV files", accept = ".csv", multiple = TRUE),
      uiOutput(ns("upload_map"))
    ),
    conditionalPanel(
      condition = "input.shape == 'split'", ns = ns,
      uiOutput(ns("pick_split"))
    )
  )

  results <- htmltools::div(
    class = "ca-batch__results",
    uiOutput(ns("status")),
    DT::DTOutput(ns("table")),
    uiOutput(ns("foot"))
  )

  switch(section,
         chooser = chooser,
         results = results,
         htmltools::div(class = "ca-batch", chooser, results))
}


# ===========================================================================
# 8. SERVER
# ===========================================================================

#' Batch panel server
#'
#' Selection of at most `CA_BATCH_AUTO_MAX` new rows assesses itself, so R2
#' stays literally true for every realistic interaction. Above that, one
#' confirming control appears — a guard, not a Run button: the session is
#' single-threaded, so a 40-second frozen tab must be a deliberate act.
#'
#' @param id module id.
#' @param state the one shared reactiveValues.
#' @param go_to the navigation callback; accepted for a uniform module
#'   signature and deliberately unused — this panel adds no navigation button.
#' @noRd
mod_batch_server <- function(id, state, go_to = NULL) {
  moduleServer(id, function(input, output, session) {

    # ---- the memo (§C.6): provenance -> one finished row ------------------
    cache <- new.env(parent = emptyenv())
    cache_err <- new.env(parent = emptyenv())
    results  <- reactiveVal(NULL)
    pending  <- reactiveVal(NULL)
    run_note <- reactiveVal(character(0))

    # ---- the dataset currently on the Data step --------------------------
    current_map <- reactive({
      m <- state$map
      if (is.null(m)) return(NULL)
      list(time = m$time, status = m$status,
           event_level = as.character(m$event_level), time_scale = m$time_scale)
    })

    current_id <- reactive({
      raw <- state$raw
      if (!is.data.frame(raw)) return(NULL)
      paste("cur", as.character(state$source), as.character(state$label),
            nrow(raw), ncol(raw), sep = "|")
    })

    # ---- uploads: parsed once, with the Data step's own strict reader -----
    uploads <- reactive({
      f <- input$files
      if (is.null(f) || !nrow(f)) return(list())
      lapply(seq_len(nrow(f)), function(i) {
        p <- .data_read_csv(f$datapath[[i]])
        list(name = f$name[[i]], data = p$data, error = p$error)
      })
    })

    # columns common to every uploaded file — one mapping for the whole set
    upload_cols <- reactive({
      u <- Filter(function(x) is.data.frame(x$data), uploads())
      if (!length(u)) return(character(0))
      Reduce(intersect, lapply(u, function(x) names(x$data)))
    })

    output$upload_map <- renderUI({
      cols <- upload_cols()
      if (!length(cols)) return(NULL)
      m <- current_map()
      pick <- function(nm, fallback) if (!is.null(nm) && nm %in% cols) nm else fallback
      num <- {
        u <- Filter(function(x) is.data.frame(x$data), uploads())
        Reduce(intersect, lapply(u, function(x) names(x$data)[vapply(x$data, is.numeric, logical(1))]))
      }
      if (!length(num)) num <- cols
      htmltools::tagList(
        selectInput(session$ns("u_time"), "Time column", choices = num,
                    selected = pick(m$time, num[[1L]])),
        selectInput(session$ns("u_status"), "Status column", choices = cols,
                    selected = pick(m$status, cols[[1L]])),
        selectInput(session$ns("u_event"), "Which value means the event?",
                    choices = .ca_batch_upload_levels(uploads(), input$u_status),
                    selected = if (is.null(m$event_level)) NULL else as.character(m$event_level)),
        radioButtons(session$ns("u_scale"), "Time scale",
                     choices = c("Leave as supplied" = "none", "Days → years" = "days_to_years"),
                     selected = if (is.null(m$time_scale)) "none" else m$time_scale),
        htmltools::p(class = "ca-provenance",
                     "Uploaded files share one mapping. A file without that column is listed with the reason.")
      )
    })

    observeEvent(list(input$u_status, uploads()), {
      lv <- .ca_batch_upload_levels(uploads(), input$u_status)
      sel <- if (!is.null(input$u_event) && input$u_event %in% lv) input$u_event
             else if (length(lv)) lv[[1L]] else NULL
      updateSelectInput(session, "u_event", choices = lv, selected = sel)
    }, ignoreInit = TRUE)

    upload_map <- reactive({
      list(time = input$u_time, status = input$u_status,
           event_level = as.character(input$u_event),
           time_scale = if (is.null(input$u_scale)) "none" else input$u_scale)
    })

    # ---- shape (a): the registry, grouped by family ----------------------
    output$pick_sets <- renderUI({
      fams <- if (exists("CA_DATASET_FAMILIES")) CA_DATASET_FAMILIES else character(0)
      blocks <- lapply(seq_along(fams), function(i) {
        fam <- fams[[i]]
        keys <- Filter(function(k) identical(CA_DATASETS[[k]]$family, fam), names(CA_DATASETS))
        if (!length(keys)) return(NULL)
        choices <- stats::setNames(
          unlist(keys, use.names = FALSE),
          vapply(keys, function(k) as.character(CA_DATASETS[[k]]$label), character(1))
        )
        checkboxGroupInput(session$ns(paste0("pick_", i)), fam, choices = choices,
                           selected = isolate(input[[paste0("pick_", i)]]))
      })
      cur <- if (is.data.frame(state$raw) && !is.null(state$map)) {
        checkboxInput(session$ns("use_current"),
                      sprintf("%s (on the Data step)", as.character(state$label)),
                      value = isolate(isTRUE(input$use_current)))
      }
      htmltools::tagList(blocks, cur)
    })

    picked_keys <- reactive({
      fams <- if (exists("CA_DATASET_FAMILIES")) CA_DATASET_FAMILIES else character(0)
      unlist(lapply(seq_along(fams), function(i) input[[paste0("pick_", i)]]), use.names = FALSE)
    })

    # ---- shape (b): the grouping column ---------------------------------
    output$pick_split <- renderUI({
      raw <- state$raw
      if (!is.data.frame(raw)) {
        return(htmltools::p(class = "ca-provenance", .CA_BATCH_F15))
      }
      ch <- ca_batch_group_choices(raw, current_map())
      if (!length(ch)) {
        return(htmltools::p(class = "ca-provenance", .CA_BATCH_F14))
      }
      selectInput(session$ns("group_col"), "Column", choices = ch,
                  selected = if (!is.null(input$group_col) && input$group_col %in% ch) input$group_col else ch[[1L]])
    })

    # ---- the plan: what the current selection asks for --------------------
    plan <- reactive({
      lgn <- isTRUE(state$include_lognormal)

      if (identical(input$shape, "split")) {
        raw <- state$raw
        if (!is.data.frame(raw)) return(list(specs = list(), notes = .CA_BATCH_F15))
        gcol <- input$group_col
        if (is.null(gcol) || !nzchar(gcol)) return(list(specs = list(), notes = .CA_BATCH_F14))
        if (!gcol %in% names(raw)) return(list(specs = list(), notes = .CA_BATCH_F14))
        return(ca_batch_specs_group(raw, current_map(), gcol,
                                    source_id = current_id(), include_lognormal = lgn))
      }

      specs <- list()
      notes <- character(0)

      b <- ca_batch_specs_builtin(picked_keys(), include_lognormal = lgn)
      specs <- c(specs, b$specs)

      if (isTRUE(input$use_current) && is.data.frame(state$raw) && !is.null(current_map())) {
        raw <- state$raw
        m   <- current_map()
        lab <- as.character(state$label)
        specs <- c(specs, list(list(
          label      = lab,
          provenance = paste(current_id(), m$time, m$status, m$event_level,
                             m$time_scale, lgn, sep = "|"),
          time_unit  = .ca_batch_time_unit(m$time_scale),
          build      = function() .ca_batch_frame_one(raw, m, lab)
        )))
      }

      u <- uploads()
      if (length(u)) {
        um <- upload_map()
        if (!is.null(um$time) && !is.null(um$status)) {
          specs <- c(specs, ca_batch_specs_upload(u, um, include_lognormal = lgn)$specs)
        }
      }

      if (!length(specs)) notes <- c(notes, .CA_BATCH_F14)
      list(specs = specs, notes = notes)
    })

    # ---- running, with the incremental cache ------------------------------
    run_plan <- function(p) {
      specs <- p$specs
      if (!length(specs)) { results(NULL); return(invisible(NULL)) }

      prov <- vapply(specs, function(s) s$provenance, character(1))
      miss <- which(!vapply(prov, function(k) exists(k, envir = cache, inherits = FALSE), logical(1)))

      if (length(miss)) {
        # a session-long memo, cleared wholesale rather than grown without end
        if (length(ls(cache)) > 800L) {
          rm(list = ls(cache), envir = cache); rm(list = ls(cache_err), envir = cache_err)
          miss <- seq_along(specs)
        }
        total <- length(miss)
        # isolated: the selection observer must not re-fire on an expert answer
        # (that moves two columns and no package call — see below).
        expert <- isolate(ca_expert_state(state))
        lgn    <- isolate(isTRUE(state$include_lognormal))

        withProgress(message = "Assessing", value = 0, {
          built <- lapply(miss, function(i) specs[[i]]$build())
          units <- vapply(specs[miss], function(s) s$time_unit, character(1))

          # one call per time unit, so a mixed selection still reports the right
          # unit per row; progress advances across the whole run either way.
          for (u in unique(units)) {
            idx <- which(units == u)
            rows <- ca_batch_assess(
              frames            = lapply(built[idx], function(b) b$frame),
              labels            = vapply(specs[miss][idx], function(s) s$label, character(1)),
              blocked           = vapply(built[idx], function(b) b$blocked, character(1)),
              time_unit         = u,
              include_lognormal = lgn,
              expert            = expert,
              on_progress       = function(i, k, label) {
                incProgress(1 / max(total, 1L), detail = label)
              }
            )
            errs <- attr(rows, "errors")
            for (j in seq_along(idx)) {
              key <- prov[[miss[[idx[[j]]]]]]
              assign(key, rows[j, , drop = FALSE], envir = cache)
              lab <- rows$dataset[[j]]
              be <- built[[idx[[j]]]]$error
              raw_err <- c(
                if (!is.null(errs) && lab %in% names(errs)) errs[[lab]],
                if (is.character(be) && length(be) == 1L && nzchar(be)) be
              )
              if (length(raw_err)) assign(key, paste(raw_err, collapse = " "), envir = cache_err)
            }
          }
        })
      }

      out <- do.call(rbind, lapply(prov, function(k) get(k, envir = cache)))
      rownames(out) <- NULL
      out <- .ca_batch_apply_expert(out, isolate(ca_expert_state(state)))
      errs <- character(0)
      for (i in seq_along(prov)) {
        if (exists(prov[[i]], envir = cache_err, inherits = FALSE)) {
          errs[[out$dataset[[i]]]] <- get(prov[[i]], envir = cache_err)
        }
      }
      attr(out, "errors") <- errs
      results(out)
      invisible(NULL)
    }

    # Selection changes assess themselves, up to the guard.
    observe({
      p <- plan()
      run_note(p$notes)
      if (!length(p$specs)) { pending(NULL); results(NULL); return() }

      prov <- vapply(p$specs, function(s) s$provenance, character(1))
      new  <- sum(!vapply(prov, function(k) exists(k, envir = cache, inherits = FALSE), logical(1)))

      if (new > CA_BATCH_AUTO_MAX) {
        pending(p)
        results(NULL)
        return()
      }
      pending(NULL)
      run_plan(p)
    })

    ca_on_click(input, "run_big", function() {
      p <- pending()
      if (is.null(p)) return(invisible(NULL))
      pending(NULL)
      run_plan(p)
    })

    # The expert answer moves two columns and no package call (§C.5).
    observeEvent(list(state$expert_q1, state$expert_q2), {
      r <- results()
      if (is.data.frame(r)) {
        errs <- attr(r, "errors")
        r2 <- .ca_batch_apply_expert(r, ca_expert_state(state))
        attr(r2, "errors") <- errs
        results(r2)
      }
    }, ignoreInit = TRUE)

    # ---- the panel's own lines -------------------------------------------
    output$status <- renderUI({
      out <- list()
      for (n in run_note()) out[[length(out) + 1L]] <- htmltools::p(class = "ca-provenance", n)

      p <- pending()
      if (!is.null(p)) {
        k <- length(p$specs)
        out[[length(out) + 1L]] <- htmltools::div(
          class = "ca-batch__confirm",
          htmltools::p(sprintf("%d groups. About %d seconds.", k, max(1L, round(k * 0.18)))),
          actionButton(session$ns("run_big"), sprintf("Assess these %d groups", k))
        )
      }

      r <- results()
      if (is.data.frame(r) && nrow(r) && identical(ca_expert_state(state), "unanswered")) {
        out[[length(out) + 1L]] <- htmltools::p(class = "ca-provenance", .CA_BATCH_F23)
      }
      if (!length(out)) return(NULL)
      htmltools::tagList(out)
    })

    # ---- the table: nine columns, hidden numeric sort keys ----------------
    output$table <- DT::renderDT({
      r <- results()
      validate(need(is.data.frame(r) && nrow(r) > 0L, .CA_BATCH_F24))

      esc  <- function(x) htmltools::htmlEscape(as.character(x))
      # NA sorts last: the hidden key carries a sentinel above every real value.
      key  <- function(x) { v <- as.numeric(x); v[is.na(v)] <- 1e15; v }
      # USE.NAMES = FALSE is load-bearing, not tidiness: vapply() over a
      # CHARACTER vector names its result with the input values, data.frame()
      # adopts those names as row names, and a not-assessed row (best_model NA)
      # then kills the render with "row names contain missing values".
      dash <- function(x, digits) vapply(x, function(v) ca_num(v, digits), character(1), USE.NAMES = FALSE)

      name_cell <- vapply(seq_len(nrow(r)), function(i) {
        reason <- r$reason[[i]]
        as.character(htmltools::tagList(
          htmltools::tags$span(r$dataset[[i]]),
          if (!is.na(reason) && nzchar(reason)) {
            htmltools::tags$div(class = "ca-provenance", reason)
          }
        ))
      }, character(1), USE.NAMES = FALSE)

      cure_cell <- vapply(r$is_cure_model, function(v) {
        if (is.na(v)) ca_dash() else as.character(ca_chip("neutral", if (identical(v, "yes")) "cure model" else "no cured group"))
      }, character(1), USE.NAMES = FALSE)

      disp <- data.frame(
        dataset = name_cell,
        n       = dash(r$n, 0),
        events  = dash(r$events, 0),
        cens    = vapply(r$censored_pct, function(v) if (is.na(v)) ca_dash() else paste0(ca_num(v, 1), "%"), character(1), USE.NAMES = FALSE),
        model   = vapply(r$best_model, function(v) if (is.na(v)) ca_dash() else esc(v), character(1), USE.NAMES = FALSE),
        cure    = cure_cell,
        pi      = dash(r$cure_fraction, 4),
        rr      = dash(r$uncured_censored_ratio, 4),
        rec     = vapply(r$recommendation, function(v) if (is.na(v)) ca_dash() else esc(v), character(1), USE.NAMES = FALSE),
        stringsAsFactors = FALSE
      )
      disp$.k_row    <- seq_len(nrow(r))
      disp$.k_n      <- key(r$n)
      disp$.k_events <- key(r$events)
      disp$.k_cens   <- key(r$censored_pct)
      disp$.k_pi     <- key(r$cure_fraction)
      disp$.k_r      <- key(r$uncured_censored_ratio)

      DT::datatable(
        disp,
        rownames  = FALSE,
        selection = "none",
        escape    = FALSE,
        colnames  = c("Dataset", "n", "Events", "Censored %", "Best model",
                      "Cure model", "Cure fraction", "Uncured ratio", "Recommendation",
                      "order", "kn", "ke", "kc", "kp", "kr"),
        class     = "compact stripe hover",
        options = list(
          dom        = "ftip",
          pageLength = 25L,
          scrollX    = TRUE,
          order      = list(list(9L, "asc")),
          columnDefs = list(
            list(targets = 9:14, visible = FALSE, searchable = FALSE),
            list(targets = 0L, orderData = 9L),
            list(targets = 1L, orderData = 10L, className = "dt-right"),
            list(targets = 2L, orderData = 11L, className = "dt-right"),
            list(targets = 3L, orderData = 12L, className = "dt-right"),
            list(targets = 6L, orderData = 13L, className = "dt-right"),
            list(targets = 7L, orderData = 14L, className = "dt-right")
          )
        )
      )
    })

    # ---- the footer: the caveat, the download, the raw text ---------------
    output$foot <- renderUI({
      r <- results()
      if (!is.data.frame(r) || !nrow(r)) return(NULL)
      errs <- attr(r, "errors")
      htmltools::tagList(
        htmltools::p(class = "ca-provenance",
                     "This table is for scanning; the file you download is the record."),
        # S9: the file reports the two follow-up statistics on two scales, and
        # they are algebraically the same reading.
        htmltools::p(class = "ca-provenance",
                     "The file reports the follow-up statistic on two scales. It is one reading, not two."),
        downloadButton(session$ns("download"), "Download results"),
        if (length(errs)) {
          ca_tech(htmltools::tags$pre(paste(sprintf("%s: %s", names(errs), unname(errs)),
                                            collapse = "\n")))
        }
      )
    })

    output$download <- downloadHandler(
      filename = function() {
        d <- format(Sys.Date())
        if (identical(input$shape, "split") && !is.null(input$group_col) &&
            !is.null(state$label)) {
          slug <- function(x) {
            x <- tolower(gsub("[^A-Za-z0-9]+", "-", as.character(x)[[1L]]))
            x <- gsub("(^-|-$)", "", x)
            if (nzchar(x)) x else "dataset"
          }
          sprintf("cure-assessment-%s-by-%s-%s.csv",
                  slug(state$label), slug(input$group_col), d)
        } else {
          sprintf("cure-assessment-batch-%s.csv", d)
        }
      },
      content = function(file) {
        r <- results()
        writeLines(ca_batch_csv(if (is.data.frame(r)) r else .ca_batch_empty_df(0L)), con = file)
      },
      contentType = "text/csv"
    )

    invisible(NULL)
  })
}


#' Event-level choices shared by every readable uploaded file
#' @noRd
.ca_batch_upload_levels <- function(files, status_col) {
  if (is.null(status_col) || !nzchar(status_col)) return(character(0))
  u <- Filter(function(x) is.data.frame(x$data) && status_col %in% names(x$data), files)
  if (!length(u)) return(character(0))
  lv <- unique(unlist(lapply(u, function(x) {
    v <- x$data[[status_col]]
    if (is.factor(v)) v <- as.character(v)
    as.character(unique(v[!is.na(v)]))
  }), use.names = FALSE))
  if (!length(lv)) return(character(0))
  num <- suppressWarnings(as.numeric(lv))
  if (!anyNA(num)) lv <- lv[order(num)] else lv <- sort(lv)
  lv
}
