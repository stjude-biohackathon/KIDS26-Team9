# =============================================================================
# app-v2/R/mod_v2_expert.R — section 1, "Your judgment".   owner: builder-v2
#
# §G.1: the two questions sit immediately under the verdict band, because
# answering them changes the band directly above and the user should see that
# happen.
#
# The app never answers them and never infers them from a statistic:
# "unanswered" is a real, visible state, and it is what makes the verdict
# provisional. ca_expert_state() (app/R/helpers.R N.1) is the single
# implementation of the three-way outcome; nothing here re-derives it.
#
# The two questions are the poster's verbatim wording and may not be reworded.
# =============================================================================

#' One question row. The question is the radio group's own label, so it is
#' associated with the group for screen readers.
#' @noRd
.v2_question <- function(input_id, question) {
  # .ca-choice__row and .ca-choice__q are the shared stylesheet's own question
  # row: the question left, the two options right, and reading-size type on the
  # question. The .ca-choice CARD around them is deliberately not used — this
  # version drops card edges in the column (§G.1).
  htmltools::div(
    class = "v2-q ca-choice__row",
    radioButtons(
      input_id,
      label = htmltools::tags$span(class = "ca-choice__q", question),
      choices = c("Yes", "No"),
      selected = character(0),      # no default: the app never answers
      inline = TRUE
    )
  )
}

#' @noRd
.v2_answer <- function(v) {
  if (is.null(v) || length(v) != 1L || is.na(v) || !nzchar(v)) return("")
  if (identical(v, "Yes")) "yes" else if (identical(v, "No")) "no" else ""
}

#' @noRd
.v2_choice <- function(a) {
  if (identical(a, "yes")) "Yes" else if (identical(a, "no")) "No" else character(0)
}


# =============================================================================
# UI
# =============================================================================

mod_v2_expert_ui <- function(id) {
  ns <- NS(id)
  htmltools::tags$section(
    class = "v2-sec v2-sec--judgment", id = "v2-judgment",
    htmltools::tags$h2(class = "v2-sec__title", "Your judgment"),
    htmltools::tags$p(
      class = "v2-sec__lede",
      "Only a person who knows the disease can answer these. The app never answers them for you."
    ),
    htmltools::div(
      class = "v2-q__grid",
      .v2_question(ns("q1"), "Is a cure biologically plausible?"),
      .v2_question(ns("q2"), "Is long-term survival without recurrence expected?")
    ),
    uiOutput(ns("outcome"))
  )
}


# =============================================================================
# SERVER
# =============================================================================

mod_v2_expert_server <- function(id, state) {
  moduleServer(id, function(input, output, session) {

    # The only writer of the three expert fields. Written from locals only:
    # reading them back here would make the observer depend on its own write.
    observe({
      q1 <- .v2_answer(input$q1)
      q2 <- .v2_answer(input$q2)
      state$expert_q1 <- q1
      state$expert_q2 <- q2
      state$expert_confirmed <- identical(q1, "yes") && identical(q2, "yes")
    })

    # A dataset change clears the answers (a clinician confirmed plausibility
    # for that population, not for every population); mirror that back into the
    # controls. The guard keeps this from ping-ponging with the observer above.
    observeEvent(state$expert_q1, {
      if (!identical(.v2_answer(input$q1), state$expert_q1)) {
        updateRadioButtons(session, "q1", choices = c("Yes", "No"),
                           selected = .v2_choice(state$expert_q1), inline = TRUE)
      }
    }, ignoreInit = TRUE)

    observeEvent(state$expert_q2, {
      if (!identical(.v2_answer(input$q2), state$expert_q2)) {
        updateRadioButtons(session, "q2", choices = c("Yes", "No"),
                           selected = .v2_choice(state$expert_q2), inline = TRUE)
      }
    }, ignoreInit = TRUE)

    output$outcome <- renderUI({
      st <- ca_expert_state(state)
      if (identical(st, "yes")) {
        htmltools::div(class = "v2-q__out", ca_chip("pass", "Answered yes"),
                       htmltools::tags$span("Cure is plausible here."))
      } else if (identical(st, "no")) {
        htmltools::div(class = "v2-q__out", ca_chip("fail", "Answered no"),
                       htmltools::tags$span(
                         "A cure model is not appropriate for this population, whatever the numbers say."))
      } else {
        htmltools::div(class = "v2-q__out", ca_chip("neutral", "Not answered"),
                       htmltools::tags$span("Until both are answered the verdict above is provisional."))
      }
    })

    invisible(NULL)
  })
}
