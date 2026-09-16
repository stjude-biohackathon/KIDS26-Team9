# ─────────────────────────────────────────────────────────────────────────────
# THROWAWAY SCAFFOLD — NOT THE PROJECT.
#
# This is a 60-line Shiny app whose only job is to prove, during the Wednesday
# onboarding block (task T-03), that Shiny + cureAssess + plotting all work on
# your machine. If this opens and draws a curve, your environment is good.
#
#   shiny::runApp("app-scaffold")
#
# The real application is built from scratch in app/ against the specification
# in docs/shiny-app-spec.md. Do NOT grow this file into the real app — it has
# none of the module structure the spec requires, and four people editing one
# file is how a three-day project loses a morning to merge conflicts.
#
# Delete this directory once everyone has passed T-03.
# ─────────────────────────────────────────────────────────────────────────────

library(shiny)
suppressPackageStartupMessages({
  library(survival)
  library(ggplot2)
})

# Load cureAssess: prefer the installed package, fall back to the vendored source.
if (requireNamespace("cureAssess", quietly = TRUE)) {
  library(cureAssess)
} else if (requireNamespace("devtools", quietly = TRUE) && dir.exists("../cureAssess")) {
  devtools::load_all("../cureAssess", quiet = TRUE)
} else {
  stop("cureAssess is not available. Run scripts/smoke_test.R first.")
}

ui <- fluidPage(
  titlePanel("Scaffold — environment check only"),
  p(tags$strong("This is not the project."),
    " It exists to confirm Shiny, cureAssess and ggplot2 work on your machine.",
    " The real app is built in ", tags$code("app/"), " per ",
    tags$code("docs/shiny-app-spec.md"), "."),
  hr(),
  sidebarLayout(
    sidebarPanel(
      selectInput("ds", "Dataset",
                  c("nwtco - High risk (stage 3-4)" = "nwtco_high",
                    "gbsg - breast cancer" = "gbsg")),
      actionButton("go", "Run assessment", class = "btn-primary"),
      width = 4
    ),
    mainPanel(
      plotOutput("km", height = "320px"),
      h4("Verdict"),
      verbatimTextOutput("verdict"),
      width = 8
    )
  )
)

server <- function(input, output, session) {

  prepared <- reactive({
    if (input$ds == "nwtco_high") {
      list(data = subset(survival::nwtco, stage %in% c(3, 4)),
           time = "edrel", status = "rel")
    } else {
      list(data = survival::gbsg, time = "rfstime", status = "status")
    }
  })

  output$km <- renderPlot({
    d <- prepared()
    dat <- prepare.surv.data(d$data, time = d$time, status = d$status,
                             time_scale = "days_to_years")
    fit <- survival::survfit(survival::Surv(Y, D) ~ 1, data = dat)
    plot(fit, xlab = "Years", ylab = "Survival probability",
         main = "Kaplan-Meier estimate", conf.int = TRUE, las = 1)
  })

  result <- eventReactive(input$go, {
    d <- prepared()
    withProgress(message = "Fitting cure and non-cure models...", {
      cure.appropriateness(d$data, time = d$time, status = d$status,
                           time_scale = "days_to_years",
                           plot_km = FALSE, run_tests = "yes")
    })
  })

  output$verdict <- renderPrint({
    if (input$go == 0) {
      cat("Press 'Run assessment'.\n")
    } else {
      r <- result()
      cat("Best model by AIC:", r$screening$best_model,
          paste0("(", r$screening$best_model_type, ")"), "\n")
      cat("RECeUS pi_hat    :", round(r$tests$receus$pi_hat, 4), "\n")
      cat("RECeUS r_hat     :", round(r$tests$receus$r_hat, 4), "\n")
      cat("RECeUS decision  :", r$tests$receus$decision, "\n")
    }
  })
}

shinyApp(ui, server)
