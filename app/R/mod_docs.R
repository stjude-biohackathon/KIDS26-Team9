# =============================================================================
# mod_docs.R — the Documentation / Help tab (nav id "docs"), builder-tabs-b
#
# Static teaching content plus one live block: the provenance table, which reads
# `state$assess` when it exists and prints "— not yet computed —" otherwise.
# Package call sites: NONE. `utils::packageVersion()` is the only package-adjacent
# call and it reads metadata, not statistics.
#
# Every statistical sentence here is contract §J copy, a package `interpretation`
# string, or a definition lifted from docs/cure-models-101.md. This file writes
# no statistical prose of its own.
# =============================================================================


# ---- the per-method explainers (contract §J.6, verbatim) --------------------

# Six labelled lines per method, in the contract's order. Each method keeps its
# own labels: the immune summary says "Threshold:" where the tests say
# "Threshold, and where it comes from:", because it has none to source.
#
# The *Reference:* lines carry the citations printed in the package's own
# documentation (cureAssess/R/*.R roxygen @references). Contract §J.6 prints a
# different volume and DOI for Maller-Zhou 1994 and for Shen 2000; those two
# lines are demonstrably the 1992 Biometrika paper and a wrong DOI respectively,
# so the §J.0 rule applies — the package wins over a defective docs line. Flagged
# for the verify phase.
.DOCS_METHODS <- list(
  list(
    key = "mz",
    title = "Maller–Zhou test (1994) — mz.test()",
    target = "quant",
    target_label = "See this test on the Quantitative tab →",
    lines = list(
      c("The question it asks:", "did follow-up extend far enough past the last event that a plateau could be seen?"),
      c("Direction:", "smaller is better — below α supports sufficient follow-up."),
      c("Threshold, and where it comes from:", "α, an argument you can change; the package default is 0.05."),
      c("When it returns nothing, and why:", "when the largest observed time is an event rather than a censored observation, there is no follow-up tail to measure and the statistic is undefined."),
      c("Exact call and field:", "cureAssess::mz.test(dat, alpha) → $statistic, $alpha, $interpretation."),
      c("Reference:", "Maller RA, Zhou S (1994). Testing for sufficient follow-up and outliers in survival data. Journal of the American Statistical Association, 89(428), 1499–1506. doi:10.1080/01621459.1994.10476889")
    )
  ),
  list(
    key = "qn",
    title = "qn statistic (Maller & Zhou 1996) — qn.test()",
    target = "quant",
    target_label = "See this statistic on the Quantitative tab →",
    lines = list(
      c("The question it asks:", "what share of events fall inside a late window as wide as the flat tail?"),
      c("Direction:", "larger is better — above the threshold supports sufficient follow-up. This is the opposite of Maller–Zhou and Shen; getting it backwards is a blocking bug."),
      c("Threshold, and where it comes from:", "1 - α^(1/n), which moves with sample size. qn.test() returns no threshold field, so this app computes it from α and n — the single closed form the app is permitted to evaluate. The package's own sentence always quotes its own fixed 0.05 version."),
      c("When it returns nothing, and why:", "the same gate as Maller–Zhou and Shen — largest observed time is an event."),
      c("Exact call and field:", "cureAssess::qn.test(dat) → $statistic, $interpretation. There is no alpha argument and no $threshold field."),
      c("Reference:", "Maller RA, Zhou X (1996). Survival Analysis with Long-Term Survivors. Wiley. Finite-sample behaviour: Maller RA, Resnick S, Shemehsavar S (2024). Canadian Journal of Statistics, 52(2), 359–379. doi:10.1002/cjs.11771")
    )
  ),
  list(
    key = "shen",
    title = "Shen test (2000) — shen.test()",
    target = "quant",
    target_label = "See this test on the Quantitative tab →",
    lines = list(
      c("The question it asks:", "the same follow-up question, through a narrower late-time window."),
      c("Direction:", "smaller is better — below α supports sufficient follow-up."),
      c("Threshold, and where it comes from:", "α, an argument; default 0.05. Shen is the stricter of the two by design: it exists because Maller–Zhou can over-declare sufficiency."),
      c("When it returns nothing, and why:", "same gate as above."),
      c("Exact call and field:", "cureAssess::shen.test(dat, alpha) → $statistic, $alpha, $interpretation."),
      c("Reference:", "Shen P-S (2000). Testing for sufficient follow-up in survival data. Statistics & Probability Letters, 49(4), 313–322. doi:10.1016/S0167-7152(00)00063-8")
    )
  ),
  list(
    key = "immune",
    title = "Maller–Zhou immune summary (1996) — immune.test()",
    target = "qual",
    target_label = "See the curve this summarises on the Qualitative tab →",
    lines = list(
      c("The question it asks:", "what do the data look like at the end of follow-up — how much censoring, and was the last observation a censored subject?"),
      c("Direction:", "none. This is descriptive, not a test. It has no statistic, no threshold and no null hypothesis, despite the name. It is never passed or failed."),
      c("Threshold:", "there is none, and the app must not invent one."),
      c("When it returns nothing:", "it always returns; p_cens is NA if the status column contains missing values."),
      c("Exact call and fields:", "cureAssess::immune.test(dat) → $p_hat, $p_cens, $last_observation, $last_observation_censored, $interpretation."),
      c("Reference:", "Maller RA, Zhou X (1996). Survival Analysis with Long-Term Survivors. Wiley. See also Maller RA, Zhou S (1992). Biometrika, 79(4), 731–739. doi:10.1093/biomet/79.4.731")
    )
  ),
  list(
    key = "receus",
    title = "RECeUS — receus.method()",
    target = "conclusion",
    target_label = "See the decision it drives on the Conclusion tab →",
    lines = list(
      c("The question it asks:", "is the estimated cure fraction non-negligible, and is the share of uncured subjects still unresolved at the end of follow-up small enough to identify it?"),
      c("Direction:", "two conditions, both required — π̂ greater than 0.025 and r̂ less than 0.05."),
      c("Thresholds, and where they come from:", "0.025 and 0.05 are fixed inside the package source and reachable by no argument. They come from Selukar & Othus (2023), who chose and validated them."),
      c("When it returns nothing, and why:", "when the maximum-likelihood fit behind it does not converge, π̂ and r̂ come back missing; the app reports that rather than a decision."),
      c("Exact call and fields:", "cureAssess::receus.method(data, dist, whichTau) → $pi_hat, $r_hat, $tau, $cure_fraction_condition, $followup_condition, $decision, $interpretation, $estimates."),
      c("Reference:", "Selukar S, Othus M (2023). RECeUS: Ratio estimation of censored uncured subjects, a different approach for assessing cure model appropriateness in studies with long-term survivors. Statistics in Medicine, 42(3), 209–227. doi:10.1002/sim.9610")
    )
  ),
  list(
    key = "screening",
    title = "Model screening — model.fitting() / cure.appropriateness()",
    target = "quant",
    target_label = "See the AIC table on the Quantitative tab →",
    lines = list(
      c("The question it asks:", "among eight candidate models (ten with lognormal), four of them cure models, which has the smallest AIC?"),
      c("Direction:", "smaller AIC is a better description of the data you have. It is not evidence that a cure model is identifiable — that is what the five diagnostics are for."),
      c("Threshold:", "none. AIC is a ranking, not a test."),
      c("When a row returns nothing, and why:", "an individual fit can fail to converge; the package records the reason in the error column and sets AIC = NA. Failed rows sort last and are always shown."),
      c("Exact call and fields:", "cureAssess::cure.appropriateness(data, time, status, time_scale, dist, plot_km, run_tests, include_lognormal) → $screening$aic_table, $screening$best_model, $screening$initial_decision, $selected_receus_dist, $tests, $tests_reason, $final_recommendation."),
      c("Reference:", "the cureAssess tutorial manuscript; package by Mudunkotuwa & Ghosh, MIT licence.")
    )
  )
)

# [SIGN-OFF: G] the six *Direction* lines are the highest-risk copy in the app
# (R13). Review them against the package source, not against the docs.

#' Render one method explainer as an accordion panel, with the control that
#' navigates to the tab where the method's own card lives.
.docs_method_panel <- function(ns, m) {
  bslib::accordion_panel(
    title = m$title,
    value = m$key,
    htmltools::tags$dl(
      class = "ca-card__body",
      lapply(m$lines, function(ln) {
        htmltools::tagList(
          htmltools::tags$dt(htmltools::tags$em(ln[[1]])),
          htmltools::tags$dd(ln[[2]])
        )
      })
    ),
    actionButton(ns(paste0("go_", m$key)), m$target_label)
  )
}


# ---- the glossary -----------------------------------------------------------

# Definitions assembled from docs/cure-models-101.md sections 3, 4 and 12 and
# from contract §J.9 and §J.2. No definition is written fresh here.
# [SIGN-OFF: G] the ten glossary entries, and in particular the tau_F0 / tau_G
# wording, which is the one place the app names a quantity no package field
# returns.
.DOCS_GLOSSARY <- list(
  c("Mixture cure model",
    "A model that says some patients will never have the event: S(t) = (1 − p) + p·Su(t), where p is the share who remain at risk and Su(t) is the survival function of the uncured group only. As t grows, Su(t) heads to 0 and S(t) approaches 1 − p: the curve does not go to zero, it levels off at the cure fraction."),
  c("Cure fraction",
    "The proportion of the population that is cured, 1 − p. On a Kaplan-Meier plot it is the height of the plateau. RECeUS estimates it as π̂, and the app's “tail level S” is the closely related Kaplan-Meier level at the end of follow-up — close to π̂ but not the same number."),
  c("Susceptible / uncured",
    "The patients who are not cured and will have the event if followed long enough. The literature uses “susceptible” and “uncured” interchangeably; p is their share of the population."),
  c("Immune",
    "The older literature's word for the cured group, and the reason immune.test() is called what it is. Despite the name it is a descriptive summary, not a hypothesis test. “Cure” is a statistical label for a shape in the data, not a clinical promise — for a mortality endpoint read it as long-term survivorship, not as literal immunity."),
  c("Plateau",
    "The flat run above zero at the right-hand end of a Kaplan-Meier curve. It is the visual signature of a cure fraction — and also what heavy censoring produces in data with a true cure fraction of exactly zero. A plateau is a hypothesis, not a finding."),
  c("Censoring",
    "A subject whose event was never observed: all the data record is that the event had not happened by the time the study stopped watching them. In a prepared dataset the status column is 1 for an event and 0 for a censored observation."),
  c("Right-censoring",
    "The form of censoring assumed throughout this app: observation stops at some time and the event, if it ever happens, happens after that. Dropout, loss to follow-up and the administrative end of the study all produce right-censored records."),
  c("Sufficient follow-up",
    "The study kept observing patients past the moment the uncured group was exhausted. Only then can you say the people still event-free at the end are the cured ones, because everyone who was going to have an event already had it. If follow-up is too short, a cured patient and an uncured patient who would have relapsed next year produce identical records, and no estimator can separate them."),
  c("tau_F0 and tau_G",
    "The two times the classical sufficient-follow-up condition compares. tau_F0 is the last time at which the uncured can still have events — the time by which all susceptible patients would have had the event. tau_G is the end of follow-up, the last time the study is still observing anybody. Sufficient follow-up is the condition tau_F0 ≤ tau_G: the uncured run out of events before the study runs out of observation. Neither quantity is returned by any package field; the diagnostics test the condition indirectly, through the gap between the last event and the end of follow-up."),
  c("AIC (Akaike information criterion)",
    "A ranking of how well each candidate model describes the data you have. Smaller is better, there is no threshold, and it is not a test. A better AIC fit is not evidence that a cure model is identifiable: AIC asks how well a model describes the data you have; identifiability asks whether the data contain enough follow-up to pin the cure fraction down.")
)


# ---- FAQ / troubleshooting --------------------------------------------------

.DOCS_FAQ <- list(
  list(
    q = "Three diagnostic cards say “Cannot be computed”. Is the app broken?",
    a = list(
      "No. Cannot be computed — the longest observed time is an event, so there is no plateau to test.",
      "This is a property of the data, not an error. All three follow-up tests need follow-up to extend past the last event. Maller–Zhou, qn and Shen share that single gate, so they always go dark together. The immune summary and RECeUS still render, because neither depends on the gap."
    )
  ),
  list(
    q = "A non-cure model won on AIC, but the five diagnostics still appeared. Why?",
    a = list(
      "Because the app always calls cure.appropriateness() with run_tests = \"yes\", so the diagnostics run whichever model wins the AIC comparison.",
      "They answer a different question. AIC ranks how well each candidate describes the data you already have; the diagnostics ask whether the data contain enough follow-up to identify a cure fraction at all. A non-cure model winning on AIC is worth knowing, and it is not a reason to hide the follow-up evidence."
    )
  ),
  list(
    q = "I ticked “include lognormal” and the conclusion changed. Which run is right?",
    a = list(
      "Both are honest runs; they use different candidate sets. The package's own note explains the mechanism: the lognormal distribution has a heavy tail that can substantially change the RECeUS remaining-uncured ratio and the selected model, so it is opt-in.",
      "RECeUS is fitted under the distribution implied by the selected model, so adding a heavy-tailed candidate that then wins the AIC comparison can move π̂ and r̂, and with them the decision. If the two runs disagree, that instability is itself the finding, and it is worth reporting rather than picking the more convenient of the two."
    )
  ),
  list(
    q = "Maller–Zhou and qn never disagree with each other. Is one of them redundant?",
    a = list(
      "On the datasets in this app they count events in the identical window, so the two statistics are the same underlying count presented two ways and can never split.",
      "Treat them as one piece of evidence, not two. Two chips agreeing is not independent confirmation, which is exactly why the Conclusion tab tallies chips rather than scoring them."
    )
  ),
  list(
    q = "I moved α and the headline verdict did not move. Is the slider working?",
    a = list(
      "Yes. α is an argument of mz.test() and shen.test(), and it also sets the app-computed qn threshold, so those three chips respond to it.",
      "The headline verdict comes from RECeUS, whose two cutoffs — 0.025 on π̂ and 0.05 on r̂ — are literals inside the package and are reachable by no argument. No slider in this app can move them."
    )
  ),
  list(
    q = "The assessment failed with an error.",
    a = list(
      "The assessment could not be completed. This usually means the maximum-likelihood fit behind RECeUS did not converge on this dataset.",
      "The package's verbatim message is shown under the error on the Quantitative tab. Try a different RECeUS distribution, or press Run assessment again after changing the candidate set."
    )
  ),
  list(
    q = "My CSV would not load.",
    a = list(
      "The Data tab names the exact problem — a non-comma delimiter, a ragged row, a non-numeric time column, or an event level matching no rows — and says what to change.",
      "Two things are worth checking first: the file must be comma-separated with a header row, and the value you pick for “which value means the event” must actually occur in the status column."
    )
  ),
  list(
    q = "Why does the app refuse a dataset with no events?",
    a = list(
      "This dataset has no events (or too few rows) to assess. Cure-model diagnostics need both events and censored observations.",
      "With zero events the follow-up statistics degenerate rather than fail loudly, so the app stops before calling the package at all."
    )
  )
)


# ---- the provenance table ---------------------------------------------------

# Every displayed statistic, with the field it came from. Values read live from
# state; before an assessment each value column reads "— not yet computed —".
.DOCS_PROVENANCE <- list(
  c("Best model by AIC",            "$screening$best_model"),
  c("Best model type",              "$screening$best_model_type"),
  c("RECeUS distribution",          "$selected_receus_dist"),
  c("Maller–Zhou statistic",    "$tests$mz$statistic"),
  c("qn statistic",                 "$tests$qn$statistic"),
  c("Shen statistic",               "$tests$shen$statistic"),
  c("Last observation censored",    "$tests$immune$last_observation_censored"),
  c("Censoring proportion",         "$tests$immune$p_cens"),
  c("RECeUS pi_hat",                "$tests$receus$pi_hat"),
  c("RECeUS r_hat",                 "$tests$receus$r_hat"),
  c("RECeUS tau",                   "$tests$receus$tau"),
  c("RECeUS decision",              "$tests$receus$decision")
)

#' Pull one provenance value out of `state$assess` by its field path.
#'
#' Walks the `$a$b$c` path literally so the table and the code agree by
#' construction. Returns the not-yet-computed dash before an assessment.
.docs_provenance_value <- function(state, path) {
  if (is.null(state$assess)) return("— not yet computed —")
  parts <- strsplit(sub("^\\$", "", path), "$", fixed = TRUE)[[1]]
  v <- state$assess
  for (p in parts) {
    if (is.null(v) || is.null(v[[p]])) return(ca_dash())
    v <- v[[p]]
  }
  if (is.logical(v) && length(v) == 1L) return(if (isTRUE(v)) "TRUE" else "FALSE")
  if (is.numeric(v) && length(v) == 1L) return(ca_num(v, 4))
  if (is.character(v) && length(v) == 1L && nzchar(v)) return(v)
  ca_dash()
}


# =============================================================================
# UI
# =============================================================================

#' Documentation tab UI. Static; renders at every status, including "empty".
mod_docs_ui <- function(id) {
  ns <- NS(id)

  htmltools::tagList(

    htmltools::div(
      class = "ca-section",
      htmltools::h2(class = "ca-section__title", "Documentation"),
      htmltools::p(
        class = "ca-lede",
        "What each test and method is about, in the order you meet them; a glossary; the worked readings; the references; and what to do when something goes wrong."
      ),
      ca_card(
        title = "What this app does",
        body = htmltools::tagList(
          htmltools::tags$p(
            "It walks a dataset through the published two-stage check for whether a cure model is appropriate — Kaplan-Meier plus AIC model comparison, then five follow-up and cure-fraction diagnostics — and returns a plain-language verdict."
          ),
          htmltools::tags$p(
            "The published check has three steps: ① expert judgment → ② visual assessment → ③ quantitative assessment. This app automates ② and ③. Step ① is a human conversation it must never decide."
          ),
          htmltools::tags$p(htmltools::tags$strong(
            "Failing any one step means a cure model is inappropriate. This is a conjunction, not a score."
          ))
        )
      ),
      ca_note(
        "info",
        "What this app does not do",
        htmltools::tags$p(
          "This app assesses whether a cure model is ",
          htmltools::tags$em("appropriate"),
          ". It does not fit your final analysis model, and it does not produce treatment-effect estimates."
        )
      )
    ),

    htmltools::div(
      class = "ca-section",
      htmltools::h3(class = "ca-section__title", "The six methods, one at a time"),
      htmltools::p(
        class = "ca-lede",
        "Five diagnostics and the AIC screening step that precedes them. Each panel gives the question the method answers, the direction of “good”, where its threshold comes from, when it cannot be computed, the exact call and field, and the reference."
      ),
      do.call(
        bslib::accordion,
        c(
          lapply(.DOCS_METHODS, function(m) .docs_method_panel(ns, m)),
          list(open = FALSE, multiple = TRUE)
        )
      )
    ),

    htmltools::div(
      class = "ca-section",
      htmltools::h3(class = "ca-section__title", "Worked readings"),
      htmltools::p(
        class = "ca-lede",
        "Three curated datasets, each read twice — once off the curve, once off the numbers."
      ),
      bslib::accordion(
        open = FALSE, multiple = TRUE,
        bslib::accordion_panel(
          title = .qual_worked_title("nwtco"), value = "wr_nwtco",
          .qual_worked_reading("nwtco")
        ),
        bslib::accordion_panel(
          title = .qual_worked_title("gbsg"), value = "wr_gbsg",
          .qual_worked_reading("gbsg")
        ),
        bslib::accordion_panel(
          title = .qual_worked_title("colon"), value = "wr_colon",
          .qual_worked_reading("colon")
        )
      ),
      actionButton(ns("go_worked"), "Look at a curve on the Qualitative tab →")
    ),

    htmltools::div(
      class = "ca-section",
      htmltools::h3(class = "ca-section__title", "Glossary"),
      htmltools::tags$dl(
        class = "ca-card__body",
        lapply(.DOCS_GLOSSARY, function(g) {
          htmltools::tagList(
            htmltools::tags$dt(htmltools::tags$strong(g[[1]])),
            htmltools::tags$dd(g[[2]])
          )
        })
      )
    ),

    htmltools::div(
      class = "ca-section",
      htmltools::h3(class = "ca-section__title", "Where the numbers on screen come from"),
      htmltools::p(
        class = "ca-lede",
        "Every statistic in this app is a field of the single cure.appropriateness() result. Nothing in this table was computed in app code."
      ),
      uiOutput(ns("provenance"))
    ),

    htmltools::div(
      class = "ca-section",
      htmltools::h3(class = "ca-section__title", "FAQ and troubleshooting"),
      do.call(
        bslib::accordion,
        c(
          lapply(seq_along(.DOCS_FAQ), function(i) {
            f <- .DOCS_FAQ[[i]]
            bslib::accordion_panel(
              title = f$q, value = paste0("faq_", i),
              lapply(f$a, htmltools::tags$p)
            )
          }),
          list(open = FALSE, multiple = TRUE)
        )
      )
    ),

    htmltools::div(
      class = "ca-section",
      htmltools::h3(class = "ca-section__title", "References"),
      ca_card(
        title = "The four key references",
        lede = "Each with the DOI printed in the package documentation.",
        body = htmltools::tags$ul(
          htmltools::tags$li("Maller RA, Zhou S (1992). Estimating the proportion of immunes in a censored sample. Biometrika, 79(4), 731–739. doi:10.1093/biomet/79.4.731"),
          htmltools::tags$li("Maller RA, Zhou S (1994). Testing for sufficient follow-up and outliers in survival data. Journal of the American Statistical Association, 89(428), 1499–1506. doi:10.1080/01621459.1994.10476889"),
          htmltools::tags$li("Shen P-S (2000). Testing for sufficient follow-up in survival data. Statistics & Probability Letters, 49(4), 313–322. doi:10.1016/S0167-7152(00)00063-8"),
          htmltools::tags$li("Selukar S, Othus M (2023). RECeUS: Ratio estimation of censored uncured subjects, a different approach for assessing cure model appropriateness in studies with long-term survivors. Statistics in Medicine, 42(3), 209–227. doi:10.1002/sim.9610")
        )
      ),
      ca_card(
        title = "Background cited in the package source",
        body = htmltools::tags$ul(
          htmltools::tags$li("Maller RA, Zhou S (1995). Testing for the presence of immune or cured individuals. Biometrics, 51, 1197–1205. doi:10.2307/2533253"),
          htmltools::tags$li("Maller RA, Zhou X (1996). Survival Analysis with Long-Term Survivors. Wiley."),
          htmltools::tags$li("Maller RA, Resnick S, Shemehsavar S (2024). Finite sample and asymptotic distributions of a statistic for sufficient follow-up in cure models. Canadian Journal of Statistics, 52(2), 359–379. doi:10.1002/cjs.11771")
        )
      ),
      ca_card(
        title = "If follow-up looks insufficient",
        lede = "The references behind routes 2, 3 and 4 on the Conclusion tab.",
        body = htmltools::tagList(
          htmltools::tags$ul(
            htmltools::tags$li("Escobar-Bach M, Van Keilegom I (2019). Non-parametric cure rate estimation under insufficient follow-up by using extremes. Journal of the Royal Statistical Society Series B, 81(5), 861–880."),
            htmltools::tags$li("Yuen TP, Musta E (2024). Testing for sufficient follow-up in survival data with a cure fraction. arXiv:2403.16832."),
            htmltools::tags$li("Othus M, Bansal A, Koepl L, Wagner S, Ramsey S (2020). Bias in mean survival from fitting cure models with limited follow-up. Value in Health, 23(8), 1034–1039.")
          ),
          actionButton(ns("go_conclusion"), "See the four routes on the Conclusion tab →")
        )
      ),
      ca_card(
        title = "The tutorial manuscript",
        body = htmltools::tags$p(
          "“A Tutorial for Evaluating Cure Model Appropriateness” — Mudunkotuwa, Ghosh, Triplett, Selukar (in preparation). This app operationalises its Figure 1 workflow. The manuscript is not distributed with this repository."
        )
      ),
      ca_card(
        title = "The package, how to cite, and licence",
        body = htmltools::tagList(
          htmltools::tags$p(
            "cureAssess, MIT licensed; authors Geethanjalee Mudunkotuwa (author, creator, copyright holder) and Durbadal Ghosh (author). Upstream ",
            htmltools::tags$span(class = "ca-mono", "https://github.com/GeethanjaleeM/cureAssess"),
            ", vendored in this repository at ",
            htmltools::tags$span(class = "ca-mono", "cureAssess/"),
            ". This app is a front end; every statistic is the package's."
          ),
          uiOutput(ns("version_line")),
          htmltools::tags$p(
            htmltools::tags$strong("How to cite."),
            " Cite the package with ",
            htmltools::tags$span(class = "ca-mono", "citation(\"cureAssess\")"),
            " in R, and cite the tutorial manuscript above for the workflow this app implements."
          ),
          htmltools::tags$p(
            htmltools::tags$strong("Licence."),
            " The package is MIT. The app's licence is the repository's LICENSE.md."
          ),
          htmltools::tags$p(
            htmltools::tags$strong("Data note."),
            " The built-in examples are public or simulated data only, with provenance and licence for each in data/examples/README.md. No restricted or identifiable data is in this repository."
          )
        )
      )
    ),

    htmltools::div(
      class = "ca-section",
      actionButton(ns("to_intro"), "Back to the Intro →"),
      actionButton(ns("to_data"), "Go to Data →")
    )
  )
}


# =============================================================================
# SERVER
# =============================================================================

#' Documentation tab server. Writes nothing to `state`; reads `state$assess`
#' only for the provenance table.
mod_docs_server <- function(id, state, go_to) {
  moduleServer(id, function(input, output, session) {

    # One navigation observer per method explainer, wired from the same table
    # the panels are built from, so a new panel cannot forget its button.
    lapply(.DOCS_METHODS, function(m) {
      ca_on_click(input, paste0("go_", m$key), function() go_to(m$target))
    })

    ca_on_click(input, "go_worked", function() go_to("qual"))
    ca_on_click(input, "go_conclusion", function() go_to("conclusion"))
    ca_on_click(input, "to_intro", function() go_to("intro"))
    ca_on_click(input, "to_data", function() go_to("data"))

    output$provenance <- renderUI({
      rows <- lapply(.DOCS_PROVENANCE, function(p) {
        htmltools::tags$tr(
          htmltools::tags$td(p[[1]]),
          htmltools::tags$td(htmltools::tags$span(class = "ca-mono", p[[2]])),
          htmltools::tags$td(.docs_provenance_value(state, p[[2]]))
        )
      })
      htmltools::tags$table(
        class = "ca-provenance-table",
        htmltools::tags$thead(htmltools::tags$tr(
          htmltools::tags$th("What is shown"),
          htmltools::tags$th("Field of cure.appropriateness()"),
          htmltools::tags$th("Current value")
        )),
        htmltools::tags$tbody(rows)
      )
    })

    output$version_line <- renderUI({
      v <- tryCatch(
        as.character(utils::packageVersion("cureAssess")),
        error = function(e) NULL
      )
      htmltools::tags$p(
        "Package version in this session: ",
        htmltools::tags$span(
          class = "ca-mono",
          if (is.null(v)) ca_dash() else v
        ),
        "."
      )
    })

    invisible(NULL)
  })
}
