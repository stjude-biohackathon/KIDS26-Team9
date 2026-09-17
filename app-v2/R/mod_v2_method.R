# =============================================================================
# app-v2/R/mod_v2_method.R — the method overlay.           owner: builder-v2
#
# §G.1: Method sits OFF the evidence column, because it is not part of the
# argument the column makes. It is a full-screen reading view with a floating
# table of contents, opened from the sticky bar and from section 6, and closed
# with one control or the Escape-sized close button.
#
# THE WORDS EXIST ONCE. Every definition, threshold, direction, decision rule,
# limit and reference in here is ca_docs_sections() (app/R/mod_docs.R), the
# same function the baseline's Documentation tab renders. This file adds the
# reading chrome and not one sentence of copy.
#
# Like the data drawer, the overlay is a label pointing at a bare checkbox: no
# JavaScript, no server round trip, and the content is in the document at all
# times, so opening it is instant.
# =============================================================================

mod_v2_method_ui <- function(id) {
  htmltools::tagList(
    htmltools::tags$label(class = "v2-scrim v2-scrim--method",
                          `for` = "v2-method-open", `aria-hidden` = "true"),
    htmltools::div(
      class = "v2-method", role = "region", `aria-label` = "Method",

      htmltools::div(
        class = "v2-method__head",
        htmltools::tags$h2("Method"),
        htmltools::tags$p(
          class = "ca-lede",
          "What each reading measures, which way is better, and where it stops working."
        ),
        htmltools::tags$label(class = "v2-close", `for` = "v2-method-open",
                              title = "Close", htmltools::HTML("&times;"))
      ),

      htmltools::div(
        class = "v2-method__cols",
        htmltools::tags$nav(
          class = "v2-method__toc", `aria-label` = "Contents",
          htmltools::tags$p(class = "ca-provenance", "Scroll for every section.")
        ),
        htmltools::div(class = "v2-method__body", ca_docs_sections())
      )
    )
  )
}

#' Nothing to do: the overlay is static, reads no state and writes none. The
#' signature matches the other modules so app.R mounts them the same way.
mod_v2_method_server <- function(id, state) {
  moduleServer(id, function(input, output, session) invisible(NULL))
}
