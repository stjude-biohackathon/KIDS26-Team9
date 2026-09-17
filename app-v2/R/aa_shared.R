# =============================================================================
# app-v2/R/aa_shared.R — V2_CONTRACT §G.0, verbatim.
#
# Sources the shared engine from ../app/R. Nothing here is copied into this
# directory, and nothing here is edited — see the coupling statement in
# README.md.
#
# The file is named to sort first under any locale so Shiny's alphabetical
# auto-load of R/ runs it before this version's own modules. Every shared file
# is sourced, in sorted order: datasets.R, helpers.R, mod_batch.R, mod_data.R,
# mod_docs.R, mod_expert.R, mod_intro.R, mod_qualitative.R, mod_quantitative.R,
# mod_recommendation.R, theme.R. Sourcing the baseline's other modules is
# harmless: they define mod_*_ui / mod_*_server functions this version simply
# does not call, and no file in app/R/ runs anything at source time. Name
# collisions cannot happen because every module here is named mod_v2_*.
# =============================================================================

.ca_shared_dir <- local({
  cands <- c(file.path("..", "app", "R"),      # runApp("app-v2") from the repo root
             file.path("app", "R"),            # sourced from the repo root directly
             file.path("..", "..", "app", "R"))
  hit <- Filter(function(p) file.exists(file.path(p, "helpers.R")), cands)
  if (length(hit) == 0L) stop("Shared engine not found: expected ../app/R/helpers.R", call. = FALSE)
  normalizePath(hit[[1]])
})

for (.f in sort(list.files(.ca_shared_dir, pattern = "\\.R$", full.names = TRUE))) {
  source(.f, local = FALSE)
}
rm(.f)
