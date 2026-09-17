# =============================================================================
# app-v3/R/aa_shared.R — V2_CONTRACT §G.0, verbatim.
#
# Named to sort first under any locale so Shiny's alphabetical auto-load of
# R/ runs it before this version's own modules.
#
# Sources the shared engine from ../app/R. Nothing here is copied into this
# directory, and nothing here is edited — see the coupling statement in README.md.
# =============================================================================

.ca_shared_dir <- local({
  cands <- c(file.path("..", "app", "R"),      # runApp("app-v3") from the repo root
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

# Every shared file is sourced, in sorted order — datasets.R, helpers.R,
# mod_batch.R, mod_docs.R, mod_quantitative.R, theme.R and the rest. Sourcing
# the baseline's other modules is harmless: they define mod_*_ui / mod_*_server
# functions that this version simply does not call, and no file in app/R/ runs
# anything at source time. Name collisions cannot happen because every v3
# module is named mod_v3_*.
#
# The one thing this version must NOT do is call mod_data_server(),
# mod_quantitative_server() or mod_recommendation_server(): those own the
# baseline's own input ids. v3 re-implements the *wiring* (§B.2 auto-prepare,
# §B.3 auto-assess) against its own controls, and calls the same shared engine
# functions the baseline calls — ca_assess_once(), ca_recommendation(),
# ca_batch_assess(), ca_tests_at_alpha(), ca_receus_at_tau(), ca_docs_sections()
# and the four ca_viz_* chart builders.

# The directory holding the shared stylesheet and images. app.R mounts it at a
# resource path, and app/www/img at "img" so that the shared documentation
# markup's own relative <img src="img/..."> resolves here without a single byte
# being copied.
.ca_shared_www <- normalizePath(file.path(dirname(.ca_shared_dir), "www"))


# The batch-table row-names defect this file used to work around has been fixed
# upstream in app/R/mod_batch.R (USE.NAMES = FALSE on the vapply() calls that
# build the display frame), so the local data.frame() shim is gone. Nothing in
# this file rebinds a shared function any more.
