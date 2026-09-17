# app/R/datasets.R -----------------------------------------------------------
#
# The built-in dataset registry and its one accessor.
#
# The nineteen CSVs described here live in data/examples/ and are regenerated
# by data-raw/make_examples.R with fixed seeds. Each entry records everything the
# Data step needs to offer sensible defaults for a dataset it did not write:
# which column holds the time, which holds the status, which value of the
# status column means EVENT, and whether the time needs converting from days to
# years. Those defaults are suggestions the user can override in the mapper;
# the Data step prepares and assesses automatically whenever that mapping
# changes, so nothing here is a decision -- only a starting point.
#
# `verdict` is the headline the assessment is expected to produce for the
# dataset as mapped here -- the string that comes back in
# state$assess$tests$receus$decision, verified against the running package for
# all nineteen by the verification block of data-raw/make_examples.R. Note that this is the RECeUS decision, NOT
# state$assess$final_recommendation, which is the Stage-1 AIC narrative and
# never says "Follow-up insufficient for cure modeling".
#
# `verdict` is UI text only: a label that lets the Data step say what this
# example is meant to demonstrate before anything has been run. It is never
# read by a computation, never compared against a result to decide anything,
# and never substituted for one. Once an assessment exists, everything the app
# shows comes from the assessment.


#' Built-in example datasets
#'
#' A named list of nineteen entries, in the order they are offered in the
#' dataset picker. Each entry is a list with the fields:
#'
#'   key         the list name, repeated inside the entry for convenience
#'   family      scenario family, one of CA_DATASET_FAMILIES; the picker groups
#'               by this and shows the families in that order
#'   label       display name for the picker
#'   file        file name inside data/examples/
#'   time        default time column, as named in the CSV
#'   status      default status column, as named in the CSV
#'   event_level the value of `status` that means EVENT, as character(1),
#'               matching the character comparison ca_clean_surv() performs
#'   time_scale  "none" or "days_to_years", passed to prepare.surv.data()
#'   note        one line shown under the picker: what this example teaches
#'   verdict     the headline recommendation this dataset is expected to
#'               produce, i.e. its `tests$receus$decision`; UI text only,
#'               never used in a computation
CA_DATASETS <- list(

  gbsg = list(
    key         = "gbsg",
    family      = "Real trial data",
    label       = "gbsg (breast cancer)",
    file        = "gbsg.csv",
    time        = "rfstime",
    status      = "status",
    event_level = "1",
    time_scale  = "days_to_years",
    note        = "686 breast cancer patients. AIC picks a cure model, but the follow-up tail is thin and the diagnostics disagree -- the example that justifies the whole tool.",
    verdict     = "Follow-up insufficient for cure modeling"
  ),

  nwtco_high_risk = list(
    key         = "nwtco_high_risk",
    family      = "Real trial data",
    label       = "nwtco \u2014 High risk (stage 3-4)",
    file        = "nwtco_high_risk.csv",
    time        = "edrel",
    status      = "rel",
    event_level = "1",
    time_scale  = "days_to_years",
    note        = "1404 Wilms tumour patients at stage 3 or 4. A high plateau with nine years of event-free follow-up behind it; every diagnostic agrees.",
    verdict     = "Cure model appropriate"
  ),

  colon_lev5fu = list(
    key         = "colon_lev5fu",
    family      = "Real trial data",
    label       = "colon \u2014 Lev+5FU, recurrence",
    file        = "colon_lev5fu.csv",
    time        = "time",
    status      = "status",
    event_level = "1",
    time_scale  = "days_to_years",
    note        = "304 patients on the Lev+5FU arm, recurrence endpoint. The borderline case: a convincing plateau, and one statistic just over its threshold.",
    verdict     = "Follow-up insufficient for cure modeling"
  ),

  sim_a = list(
    key         = "sim_a",
    family      = "Four corners",
    label       = "Simulated A \u2014 cure + mature follow-up",
    file        = "sim_a.csv",
    time        = "Y",
    status      = "D",
    event_level = "1",
    time_scale  = "none",
    note        = "Simulated, 300 subjects with a true cure fraction of 0.40 and follow-up long enough to see it. The happy path.",
    verdict     = "Cure model appropriate"
  ),

  sim_b = list(
    key         = "sim_b",
    family      = "Four corners",
    label       = "Simulated B \u2014 cure hidden by short follow-up",
    file        = "sim_b.csv",
    time        = "Y",
    status      = "D",
    event_level = "1",
    time_scale  = "none",
    note        = "Simulated, the same true cure fraction of 0.40 as A, but follow-up stops at 1.5 time units. A real cure fraction is invisible when the study ends too early.",
    verdict     = "Cure model not supported"
  ),

  sim_c = list(
    key         = "sim_c",
    family      = "Four corners",
    label       = "Simulated C \u2014 no cure fraction",
    file        = "sim_c.csv",
    time        = "Y",
    status      = "D",
    event_level = "1",
    time_scale  = "none",
    note        = "Simulated, true cure fraction 0.00 and only 4% censored. The longest observed time is an event, so the three follow-up tests cannot be computed at all.",
    verdict     = "Cure model not supported"
  ),

  sim_d = list(
    key         = "sim_d",
    family      = "Four corners",
    label       = "Simulated D \u2014 censoring artifact",
    file        = "sim_d.csv",
    time        = "Y",
    status      = "D",
    event_level = "1",
    time_scale  = "none",
    note        = "Simulated, true cure fraction 0.00 with heavy dropout. Censoring alone manufactures a convincing plateau, and the longest observed time is again an event.",
    verdict     = "Cure model not supported"
  ),


  # -- Cure fraction ladder ---------------------------------------------------
  # Same trial design, same length of follow-up, cure fraction climbing from
  # none to nine in ten. 500 subjects each.

  sim_pi00 = list(
    key         = "sim_pi00",
    family      = "Cure fraction ladder",
    label       = "Cure fraction 0%",
    file        = "sim_pi00.csv",
    time        = "time",
    status      = "status",
    event_level = "1",
    time_scale  = "none",
    note        = "The bottom rung: nobody is cured, and follow-up runs to the end of the event tail. Almost everyone has the event.",
    verdict     = "Cure model not supported"
  ),

  sim_pi10 = list(
    key         = "sim_pi10",
    family      = "Cure fraction ladder",
    label       = "Cure fraction 10%",
    file        = "sim_pi10.csv",
    time        = "time",
    status      = "status",
    event_level = "1",
    time_scale  = "none",
    note        = "A small cure fraction. It takes long follow-up for a plateau this low to be convincing.",
    verdict     = "Cure model appropriate"
  ),

  sim_pi30 = list(
    key         = "sim_pi30",
    family      = "Cure fraction ladder",
    label       = "Cure fraction 30%",
    file        = "sim_pi30.csv",
    time        = "time",
    status      = "status",
    event_level = "1",
    time_scale  = "none",
    note        = "A moderate cure fraction with mature follow-up. The easiest case to get right.",
    verdict     = "Cure model appropriate"
  ),

  sim_pi60 = list(
    key         = "sim_pi60",
    family      = "Cure fraction ladder",
    label       = "Cure fraction 60%",
    file        = "sim_pi60.csv",
    time        = "time",
    status      = "status",
    event_level = "1",
    time_scale  = "none",
    note        = "A large cure fraction with mature follow-up. This is the last rung of the follow-up ladder as well.",
    verdict     = "Cure model appropriate"
  ),

  sim_pi90 = list(
    key         = "sim_pi90",
    family      = "Cure fraction ladder",
    label       = "Cure fraction 90%",
    file        = "sim_pi90.csv",
    time        = "time",
    status      = "status",
    event_level = "1",
    time_scale  = "none",
    note        = "Nearly everyone is cured, so 92% of the data is censored and only 41 events carry the whole estimate.",
    verdict     = "Cure model appropriate"
  ),


  # -- Follow-up ladder -------------------------------------------------------
  # One population with a 60% cure fraction, analysed at four calendar dates.
  # 1000 subjects each. Only the length of follow-up changes.

  sim_fu25 = list(
    key         = "sim_fu25",
    family      = "Follow-up ladder",
    label       = "Follow-up: earliest",
    file        = "sim_fu25.csv",
    time        = "time",
    status      = "status",
    event_level = "1",
    time_scale  = "none",
    note        = "The earliest analysis. A quarter of those who will have the event have not had it yet, and the plateau is an illusion.",
    verdict     = "Follow-up insufficient for cure modeling"
  ),

  sim_fu10 = list(
    key         = "sim_fu10",
    family      = "Follow-up ladder",
    label       = "Follow-up: early",
    file        = "sim_fu10.csv",
    time        = "time",
    status      = "status",
    event_level = "1",
    time_scale  = "none",
    note        = "The same trial, later. A tenth of those still at risk of the event remain, and it is still too early.",
    verdict     = "Follow-up insufficient for cure modeling"
  ),

  sim_fu05 = list(
    key         = "sim_fu05",
    family      = "Follow-up ladder",
    label       = "Follow-up: intermediate",
    file        = "sim_fu05.csv",
    time        = "time",
    status      = "status",
    event_level = "1",
    time_scale  = "none",
    note        = "Closer. The curve looks flat and the cure fraction is estimated well, but the tail is still moving.",
    verdict     = "Follow-up insufficient for cure modeling"
  ),

  sim_fu01 = list(
    key         = "sim_fu01",
    family      = "Follow-up ladder",
    label       = "Follow-up: mature",
    file        = "sim_fu01.csv",
    time        = "time",
    status      = "status",
    event_level = "1",
    time_scale  = "none",
    note        = "The same trial again, waited out. This is where the verdict flips: one in a hundred still at risk is few enough.",
    verdict     = "Cure model appropriate"
  ),


  # -- Censoring and sample size ----------------------------------------------

  sim_dropout = list(
    key         = "sim_dropout",
    family      = "Censoring and sample size",
    label       = "Heavy loss to follow-up",
    file        = "sim_dropout.csv",
    time        = "time",
    status      = "status",
    event_level = "1",
    time_scale  = "none",
    note        = "A real 50% cure fraction and a long study, ruined by patients dropping out. Length of follow-up is not the same as amount of follow-up.",
    verdict     = "Follow-up insufficient for cure modeling"
  ),

  sim_small = list(
    key         = "sim_small",
    family      = "Censoring and sample size",
    label       = "Small study, 50 patients",
    file        = "sim_small.csv",
    time        = "time",
    status      = "status",
    event_level = "1",
    time_scale  = "none",
    note        = "50 patients, a real 50% cure fraction, mature follow-up. The verdict is right; the estimated cure fraction is a third off.",
    verdict     = "Cure model appropriate"
  ),

  sim_lastevent = list(
    key         = "sim_lastevent",
    family      = "Censoring and sample size",
    label       = "Study ends on an event",
    file        = "sim_lastevent.csv",
    time        = "time",
    status      = "status",
    event_level = "1",
    time_scale  = "none",
    note        = "No cure fraction, light censoring. The very last patient observed had the event, so the three follow-up checks have nothing to measure.",
    verdict     = "Cure model not supported"
  )
)


#' Scenario families, in picker order
#'
#' Every entry of CA_DATASETS carries a `family` drawn from this vector. The
#' picker groups the list by family and shows the groups in this order; no
#' group has more than five entries, so the list never becomes a flat wall of
#' names.
CA_DATASET_FAMILIES <- c(
  "Real trial data",
  "Four corners",
  "Cure fraction ladder",
  "Follow-up ladder",
  "Censoring and sample size"
)


#' Locate the data/examples directory
#'
#' The app is started with `shiny::runApp("app")` or from inside `app/`, so the
#' working directory is the app directory and the CSVs are one level up. The
#' repository root is checked too, so a session that sourced the file by hand
#' still finds them. Returns NA_character_ when no candidate exists, leaving
#' the caller to raise the user-facing message.
.data_examples_dir <- function() {
  candidates <- c(
    file.path("..", "data", "examples"),
    file.path("data", "examples"),
    file.path("..", "..", "data", "examples")
  )
  hit <- candidates[dir.exists(candidates)]
  if (length(hit) == 0L) NA_character_ else hit[[1L]]
}


#' Full path to one built-in dataset's CSV
#'
#' Returns NA_character_ if the examples directory cannot be found or the file
#' is not in it.
.data_dataset_path <- function(key) {
  entry <- CA_DATASETS[[key]]
  if (is.null(entry)) return(NA_character_)
  dir <- .data_examples_dir()
  if (is.na(dir)) return(NA_character_)
  path <- file.path(dir, entry$file)
  if (!file.exists(path)) NA_character_ else path
}


#' Load one built-in dataset
#'
#' Reads the CSV named by `key` in CA_DATASETS and returns it exactly as
#' stored: original column names, original values, nothing renamed, recoded or
#' dropped. The column mapping in the registry is a default for the Data step
#' to offer, not something applied here.
#'
#' @param key character(1), one of `names(CA_DATASETS)`.
#' @return a data.frame.
ca_dataset_load <- function(key) {
  if (!is.character(key) || length(key) != 1L || is.na(key)) {
    stop("A built-in dataset key must be a single string.", call. = FALSE)
  }
  if (is.null(CA_DATASETS[[key]])) {
    stop("There is no built-in dataset called '", key, "'.", call. = FALSE)
  }

  path <- .data_dataset_path(key)
  if (is.na(path)) {
    stop("The example file '", CA_DATASETS[[key]]$file,
         "' is missing. Regenerate it with: Rscript data-raw/make_examples.R",
         call. = FALSE)
  }

  utils::read.csv(path, header = TRUE, stringsAsFactors = FALSE)
}
