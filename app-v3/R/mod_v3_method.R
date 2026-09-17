# =============================================================================
# mod_v3_method.R — Method mode.                      V2_CONTRACT §G.2, builder-v3
#
# Method is a MODE, not an overlay, because the frame never changes in this
# version: the control pane collapses to a table of contents and the canvas
# takes the technical documentation.
#
# The words are not written here. `ca_docs_sections()` in ../app/R/mod_docs.R is
# the one copy of the technical documentation in the repository, and all three
# versions render it. This file supplies the chrome, the two orientation figures
# and the contents list, and nothing else.
#
# The orientation block at the top is what carries a reader who knows no
# survival analysis: one sentence saying what a cure model assumes, the team's
# own flowchart of the three checks, and the mixture equation. It is the only
# prose this file owns.
# =============================================================================


#' A figure with its caption.
#'
#' `src` is served from ../app/www/img at the "img" resource path, mounted in
#' app.R. Nothing is copied into this directory.
#' @noRd
.v3_figure <- function(src, alt, cap) {
  htmltools::tags$figure(
    class = "ca-figure",
    htmltools::tags$img(src = src, class = "ca-figure__img", alt = alt),
    htmltools::tags$figcaption(class = "ca-figure__cap", cap)
  )
}


#' The orientation block: what this is, for someone meeting it cold.
#' @noRd
.v3_orientation <- function() {
  htmltools::div(
    class = "ca-section",
    htmltools::h2(class = "ca-section__title", "Is a cure model right for your data?"),
    htmltools::p(
      class = "ca-lede",
      paste("A cure model assumes some patients never have the event. It fits only when that",
            "group really exists and follow-up is long enough to see it.")
    ),
    .v3_figure(
      src = "img/workflow-flowchart.png",
      alt = paste("A flowchart of three checks. Expert judgment: is a cure biologically plausible,",
                  "and is long-term survival without recurrence expected? Visual assessment: does the",
                  "survival curve plateau, with late events absent? Quantitative assessment: is there",
                  "strong quantitative evidence of sufficient follow-up and a cure fraction?"),
      cap = "Cure-model appropriateness"
    ),
    .v3_figure(
      src = "img/mixture-cure-model.png",
      alt = paste("Mixture cure model: overall survival in group a equals the cure fraction pi_a plus",
                  "one minus pi_a times the survival of the uncured in group a."),
      cap = "Cure models estimate the cure fraction and the survival of the uncured separately."
    )
  )
}


#' The first heading inside a rendered block, for the contents list.
#'
#' The shared documentation arrives partly as tags and partly as raw HTML, so
#' its section names are read off the rendered markup rather than guessed. A
#' block with no heading — the link block — is simply left out of the contents
#' list and still rendered.
#' @noRd
.v3_heading_of <- function(s) {
  pats <- c("<h2[^>]*>\\s*([^<]{2,90})", "accordion-title[^>]*>\\s*([^<]{2,90})")
  for (p in pats) {
    m <- regexpr(p, s, perl = TRUE)
    if (m > 0L) {
      lab <- trimws(sub(p, "\\1", regmatches(s, m), perl = TRUE))
      if (nzchar(lab)) return(lab)
    }
  }
  NULL
}


#' Every documentation block, wrapped and named, in order.
#'
#' Computed once at load, because `ca_docs_sections()` is static.
#' @noRd
.v3_doc_blocks <- local({
  cached <- NULL
  function() {
    if (!is.null(cached)) return(cached)
    secs <- ca_docs_sections()
    out <- lapply(seq_along(secs), function(i) {
      tag <- secs[[i]]
      lab <- .v3_heading_of(paste(as.character(tag), collapse = ""))
      list(id = paste0("v3-doc-", i), label = lab, tag = tag)
    })
    cached <<- c(
      list(list(id = "v3-doc-0", label = "What this is", tag = .v3_orientation())),
      out
    )
    cached
  }
})


# =============================================================================
# UI
# =============================================================================

#' @param section "toc" for the control pane, "body" for the canvas.
mod_v3_method_ui <- function(id, section = c("body", "toc")) {
  section <- match.arg(section)
  blocks <- .v3_doc_blocks()

  if (identical(section, "toc")) {
    return(htmltools::tags$section(
      class = "v3-sec",
      htmltools::div(
        class = "v3-sec__head",
        htmltools::h2(class = "v3-sec__title", "Contents")
      ),
      htmltools::tags$nav(
        class = "v3-toc", `aria-label` = "Documentation contents",
        htmltools::tags$ol(lapply(
          Filter(function(b) !is.null(b$label), blocks),
          function(b) htmltools::tags$li(
            htmltools::tags$a(href = paste0("#", b$id), b$label)
          )
        ))
      ),
      htmltools::p(
        class = "ca-provenance",
        "Each method states what it measures, which way is better, its decision rule and when it cannot be computed."
      )
    ))
  }

  htmltools::div(
    class = "v3-canvas__inner v3-method",
    lapply(blocks, function(b) {
      htmltools::div(id = b$id, class = "v3-method__block", b$tag)
    })
  )
}


# =============================================================================
# SERVER
# =============================================================================

#' Method mode has no controls, writes nothing and reads nothing from `state`.
#' The signature is kept uniform with the other v3 modules.
mod_v3_method_server <- function(id, state) {
  moduleServer(id, function(input, output, session) invisible(NULL))
}
