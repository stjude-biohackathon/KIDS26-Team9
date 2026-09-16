# `tests/reference/` — the reference oracle

**Empty by design.** Filled by task **G-01** (Geethanjalee, Wednesday block W2).

These files are the ground truth the Shiny app is checked against. They are produced by running
`cure.appropriateness(..., run_tests = "yes")` in plain R — no app involved — on every dataset in
the test corpus, and committing the results.

The rule: **every number the app prints must equal the number in these files.** A mismatch is a
blocking bug, not a cosmetic one. Verification is done by Pod B, who did not write the app
(tasks **B-04**, **B-06**, **B-08**).

Columns to record per dataset: `dataset`, `n`, `events`, `censored_prop`, `max_followup`,
`best_model`, `best_model_type`, `best_aic`, `pi_hat`, `r_hat`, `mz_stat`, `qn_stat`, `shen_stat`,
`immune_p_hat`, `immune_p_cens`, `receus_decision`, `final_recommendation`.

Expected values, the generating snippet, and the environment they must be produced under are in
[`project-management/qa-plan.md`](../../project-management/qa-plan.md).
