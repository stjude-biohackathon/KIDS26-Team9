# ---------------------------------------------------------------------------
# mod_expert.R — the Expert judgment tab (NEW FILE, owner: rewriter-intro)
#
# REVISION v2.0, REVISION_CONTRACT §G.2. This is the second tab and the first
# real step of the published check. It asks the team lead's two poster
# questions, verbatim, and it does nothing else.
#
# THE RULE THIS FILE EXISTS TO ENFORCE (§C.2): the user answers; the software
# never answers for them and never infers an answer from any statistic.
# Both radio groups therefore start with `selected = character(0)` — a default
# of "Yes" would be the app answering for the user.
#
# STATE, and this module is the only writer of all three fields (§C.2):
#   state$expert_q1       chr(1) "" | "yes" | "no"   — "Is a cure biologically plausible?"
#   state$expert_q2       chr(1) "" | "yes" | "no"   — "Is long-term survival without recurrence expected?"
#   state$expert_confirmed lgl(1) — derived, never toggled directly:
#                          identical(q1, "yes") && identical(q2, "yes")
# `mod_data.R` resets all three to ""/""/FALSE on a dataset change; this module
# then mirrors that reset back into the two radio groups. Read by `mod_rec` and
# by the report; the three-way outcome comes from `ca_expert_state(state)`
# (helpers.R N.1) and is never re-derived from the raw fields here.
#
# No package function is called and no package field is read on this tab, so
# there is no field provenance to record.
#
# Static, always renders: no empty state and no error state (§G.9).
#
# V2_CONTRACT (this pass, owner builder-rec):
#   * §B.1 reactive 7 — answering a question triggers NO computation. It writes
#     the three state fields above and nothing else; the Recommendation tab
#     re-renders its verdict from the assessment that already exists. There is
#     no Run button and no Prepare button to couple to, in this file or
#     anywhere in app/ (R2), and this module must never acquire one.
#   * The three-way outcome "yes" / "no" / "unanswered" is the SAME value that
#     reaches `ca_recommendation()`, the batch CSV's expert column and the
#     report's `expert` parameter. One source, `ca_expert_state()`; three
#     consumers; they cannot disagree.
# ---------------------------------------------------------------------------


#' One question row: the poster's wording, two choices, nothing pre-selected
#'
#' The question is the radio group's own label, so the label is associated with
#' the group for screen readers, and carries `ca-choice__q` for styling.
#'
#' @param input_id namespaced input id
#' @param question the poster's verbatim question text — never reworded
#' @return an `htmltools` `<div class="ca-choice">`
#' @noRd
.expert_question <- function(input_id, question) {
  htmltools::tags$div(
    class = "ca-choice",
    htmltools::tags$div(
      class = "ca-choice__row",
      radioButtons(
        input_id,
        label = htmltools::tags$span(class = "ca-choice__q", question),
        choices = c("Yes", "No"),
        selected = character(0),   # §C.2: no default. The app never answers.
        inline = TRUE
      )
    )
  )
}


#' Map a radio value to the stored answer
#'
#' @param v `input$q1` / `input$q2`: `"Yes"`, `"No"`, or `NULL` when unanswered.
#' @return chr(1), one of `""`, `"yes"`, `"no"` — the `state$expert_q*` domain.
#' @noRd
.expert_answer <- function(v) {
  if (is.null(v) || length(v) != 1L || is.na(v) || !nzchar(v)) return("")
  if (identical(v, "Yes")) return("yes")
  if (identical(v, "No")) return("no")
  ""
}


#' Map a stored answer back to the radio value
#'
#' @param a chr(1), one of `""`, `"yes"`, `"no"`.
#' @return `"Yes"`, `"No"`, or `character(0)` for "leave nothing selected".
#' @noRd
.expert_choice <- function(a) {
  if (identical(a, "yes")) return("Yes")
  if (identical(a, "no")) return("No")
  character(0)
}


#' Expert judgment tab UI
#'
#' @param id module id, equal to the nav id `"expert"`
#' @noRd
mod_expert_ui <- function(id) {
  ns <- NS(id)

  htmltools::tags$div(
    class = "ca-section",

    htmltools::tags$h1(class = "ca-section__title", "Expert judgment"),

    # FINAL_CONTRACT E1 / §G.2: the two-sentence opening lede that stood here,
    # about who can answer these questions and about the app never answering
    # them, is DELETED and nothing replaces it. The page opens on the <h1> and
    # goes straight to the first question. Do not reintroduce it or a
    # paraphrase of it.

    # The poster's verbatim wording. It may not be reworded (§G.2).
    .expert_question(ns("q1"), "Is a cure biologically plausible?"),
    .expert_question(ns("q2"), "Is long-term survival without recurrence expected?"),

    uiOutput(ns("outcome"))
  )
}


#' Expert judgment tab server
#'
#' @param id module id, `"expert"`
#' @param state the one shared `reactiveValues`
#' @param go_to the navigation callback from `app.R`
#' @noRd
mod_expert_server <- function(id, state, go_to) {
  moduleServer(id, function(input, output, session) {

    # ---- the only writer of the three expert fields (§C.2) -----------------
    # Both answers and the derived flag are written in one observer, from
    # locals only: reading state$expert_q1 back here would make this observer
    # depend on its own write.
    observe({
      q1 <- .expert_answer(input$q1)
      q2 <- .expert_answer(input$q2)
      state$expert_q1 <- q1
      state$expert_q2 <- q2
      # Derived, never directly toggled, and never TRUE unless the user said so
      # twice. The software never infers this from a statistic (§C.2).
      state$expert_confirmed <- identical(q1, "yes") && identical(q2, "yes")
    })

    # ---- mirror an external reset back into the controls -------------------
    # A dataset change clears the answers in mod_data.R (a clinician confirmed
    # plausibility for that population, not for every population). The guard
    # keeps this from ping-ponging with the observer above.
    observeEvent(state$expert_q1, {
      if (!identical(.expert_answer(input$q1), state$expert_q1)) {
        updateRadioButtons(session, "q1", choices = c("Yes", "No"),
                           selected = .expert_choice(state$expert_q1),
                           inline = TRUE)
      }
    }, ignoreInit = TRUE)

    observeEvent(state$expert_q2, {
      if (!identical(.expert_answer(input$q2), state$expert_q2)) {
        updateRadioButtons(session, "q2", choices = c("Yes", "No"),
                           selected = .expert_choice(state$expert_q2),
                           inline = TRUE)
      }
    }, ignoreInit = TRUE)

    # ---- the outcome line: one of exactly three (§G.2) ---------------------
    output$outcome <- renderUI({
      # ca_expert_state() (helpers.R N.1) is the single implementation of the
      # three-way outcome: "unanswered", "yes", "no".
      st <- ca_expert_state(state)

      if (identical(st, "yes")) {
        chip <- ca_chip("pass", "Answered yes")
        # R2: the old wording here was "Next, load your data." A dataset is
        # already loaded and already assessed by the time this tab is reached,
        # so that instruction was false as well as spare.
        line <- "Cure is plausible here."
      } else if (identical(st, "no")) {
        chip <- ca_chip("fail", "Answered no")
        # FINAL_CONTRACT E2 / §G.2: the trailing clause this line used to end
        # on is struck, and the sentence now stops at "population." The same
        # sentence lives in helpers.R ca_recommendation() rule 1 and in
        # report/report.Rmd's rp_recommendation() mirror — all three must read
        # the same or the screen and the report disagree.
        line <- "A cure model is not appropriate for this population."
      } else {
        chip <- ca_chip("neutral", "Not answered")
        line <- "Answer both to continue."
      }

      htmltools::tags$div(
        class = "ca-choice",
        chip,
        htmltools::tags$p(line),
        # The "no" case keeps the forward button on purpose: a user may want to
        # look at the curve anyway, and a dead end with no exit is worse than an
        # honest warning with one (§G.2).
        if (!identical(st, "unanswered")) {
          actionButton(session$ns("to_data"), "Data →")
        }
      )
    })

    ca_on_click(input, "to_data", function() go_to("data"))

    invisible(NULL)
  })
}
