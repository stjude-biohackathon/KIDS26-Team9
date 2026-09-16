# Decision log — cureAssessApp, KIDS26 Team 9

One entry per decision that changes the approach: newest goes last, IDs are never reused, and the entry says what was decided, why, and what it commits us to.
Never delete or rewrite an entry — if a decision turns out to be wrong, add a new entry that supersedes it and note the supersession in both.

**Scope of this log:** approach-level decisions only, per the conventions in [team.md](team.md). Day-to-day task status lives in the task backlog and in GitHub issues, not here. During the event, Durbadal records decisions at each standup (Wed 4:45 pm, Thu 9:30 am, Thu 4:45 pm, Fri 9:30 am) and immediately when a call is made mid-block. Any new feature admitted after the Thursday 17:00 feature freeze requires the lead's written approval **in this file** (task A-11 / B-10).

---

## Index

| ID | Title | Area | Date | Status |
| --- | --- | --- | --- | --- |
| [D-001](#d-001---local-only-deployment) | Local-only deployment | Infrastructure | 2026-09-15 | Active |
| [D-002](#d-002---public-and-simulated-data-only) | Public and simulated data only | Data governance | 2026-09-15 | Active |
| [D-003](#d-003---scope-is-the-full-guided-workflow-plus-a-report) | Scope is the full guided workflow plus a report | Scope | 2026-09-15 | Active |
| [D-004](#d-004---two-pods-of-two-with-a-floating-science-lead) | Two pods of two with a floating science lead | Team structure | 2026-09-15 | Active — revisit at Day-1 standup |
| [D-005](#d-005---wednesday-w1-is-onboarding-only) | Wednesday W1 is onboarding only | Schedule | 2026-09-15 | Active |
| [D-006](#d-006---feature-freeze-thursday-code-lock-friday) | Feature freeze Thursday, code lock Friday | Schedule | 2026-09-15 | Active |
| [D-007](#d-007---diagnostics-always-run-never-auto) | Diagnostics always run, never auto | App behaviour | 2026-09-15 | Active |
| [D-008](#d-008---no-calls-into-package-internals) | No calls into package internals | App behaviour | 2026-09-15 | Active |
| [D-009](#d-009---cureassess-is-vendored-not-installed) | cureAssess is vendored, not installed | Repo layout | 2026-09-15 | Active |

---

### D-001 - Local-only deployment

- **Date:** 2026-09-15 (pre-event)
- **Decision:** The app runs locally only, via `shiny::runApp("app")` on the hackathon VM / RStudio. There is no public or internal hosting of any kind during the event.
- **Why:** Hosting is a dependency we do not control and cannot debug on a 16.5-hour clock: accounts, quotas, package installs on a remote image, and a deploy step that can fail on Friday morning for reasons unrelated to our code. Running locally means the demo path is the same path the team develops against all week, so a green run at Thursday 5:00 pm is direct evidence the Friday demo will work. It also keeps D-002 easy to enforce — nothing is exposed to a URL anyone outside the room can reach.
- **Alternatives considered:** **shinyapps.io** — quickest public link, but an external account and a separate dependency-resolution environment, and it puts the app on the public internet, which fights D-002. **An internal Posit Connect server** — the right long-term answer, but it needs access, credentials and possibly an IT ticket that will not close inside three days. Both lose on the same ground: they add a failure mode on the critical path for a benefit (a shareable URL) that judging does not require.
- **Consequences:** The Definition of Done is written against a clean clone plus `shiny::runApp("app")`, and that is what B-09 and B-11 test. `README.md` (D-01) must get a new user from clone to running app in under 10 minutes with no deploy step. The demo runs from a laptop in the room, which makes R8 (machine/projector failure) a real risk, so the screenshot and GIF fallback (D-04) is mandatory, not optional, and Rashid owns a backup laptop with the app already running. Deployment to Posit Connect / shinyapps.io is recorded as stretch goal S-5 and as a next step in `docs/handoff.md` (D-08) — not a goal.
- **Decided by:** Durbadal Ghosh (team lead)

---

### D-002 - Public and simulated data only

- **Date:** 2026-09-15 (pre-event)
- **Decision:** Only public data and data we simulate ourselves goes into this repository or onto the screen. Nothing restricted, nothing identifiable, and nothing from St. Jude clinical datasets enters the repo or appears in the app, the report, the slides or the booth demo.
- **Why:** A hackathon repo is the wrong place for controlled data: it is cloned onto multiple machines in a day, screen-shared in a public room, and projected to judges. The methodological point the app makes does not need restricted data — the three public examples recorded in [qa-plan.md](qa-plan.md) already give us the happy path (`nwtco` high risk), the headline contradiction (`gbsg`) and the borderline case (`colon`), which is everything the demo needs.
- **Alternatives considered:** Using the **SWOG S1203 data** or the **St. Jude BMTCT datasets** that sit behind the tutorial manuscript. They would be more clinically compelling, but they carry access and disclosure obligations that cannot be honoured in a shared public repo on a three-day clock, and a single careless screenshot is unrecoverable. This project places all three of those assets explicitly outside this repo.
- **Consequences:** B-02 curates the three built-in examples to `data/examples/` as CSV with provenance and licence recorded in a `README.md`; B-03 and B-05 supply the four simulated scenarios so we can demonstrate failure modes without borrowing anyone's patients. The repo convention "never commit data that is not public, credentials, or anything identifiable" is binding on every commit. Reviewers check uploaded-file paths as well as committed files: the CSV upload route (A-03) means a booth visitor could load their own data, so the demo laptop is driven only with our own example files, and nothing a visitor uploads is committed. If anyone wants a St. Jude dataset in the picture, the answer is a post-event conversation, not a commit.
- **Decided by:** Durbadal Ghosh (team lead)

---

### D-003 - Scope is the full guided workflow plus a report

- **Date:** 2026-09-15 (pre-event)
- **Decision:** Build the full guided workflow — Data, Models, Diagnostics, Verdict, About, with a downloadable HTML report — and nothing more. The simulation lab and multi-arm comparison are written down as stretch goals (S-2 and S-3) and are explicitly out of scope until the Definition of Done is signed off.
- **Why:** The problem we are solving is the gate between a dataset and a defensible answer, and that gate is the whole three-step check, not any single tab. A wrapper that only prints an AIC table would reproduce the exact mistake the tutorial manuscript is written to prevent — `gbsg` picks a cure model on AIC and still fails the follow-up diagnostics. The report is what makes the verdict portable off our laptop and into an analyst's write-up, so it is core rather than polish. At the other end, a simulation lab and side-by-side multi-arm comparison are each a tab's worth of new UI and new statistical judgement; attempting them alongside the core guarantees that something in the middle of the workflow is half-finished at judging.
- **Alternatives considered:** A **minimal wrapper** (upload plus AIC table) — safe to finish, but it demonstrates nothing that a short R script does not, and it would ship the naive reading of the method. An **ambitious multi-arm and simulation-lab build** — a better teaching tool if it landed, but four pairs of hands over roughly 15 hours of build time cannot land it plus the core, and R3 (scope creep eating the core) is the single most likely way this project fails.
- **Consequences:** The eight Definition-of-Done items are the scope boundary; anything not needed by one of them waits. Stretch work starts only after sign-off, and in order — **S-1, the follow-up truncation slider, first**, because it recreates manuscript Figure 2 and flips the `gbsg`-style verdict live in front of a judge for roughly 0.2 s of compute. S-2 and S-3 stay on the list and move to `docs/handoff.md` as next steps if untouched. Note the manuscript caveat that travels with S-3: the published methods assess one group at a time, so a multi-arm view needs a statistical decision from Geethanjalee before any UI is drawn.
- **Decided by:** Durbadal Ghosh (team lead)

---

### D-004 - Two pods of two with a floating science lead

- **Date:** 2026-09-15 (pre-event)
- **Decision:** Two pods of two — **Pod A (App)** Sharon Freshour and Rashid Mehmood, **Pod B (Data & QA)** Rachael Oluwakamiye Abolade and Geethanjalee Mudunkotuwa — with Geethanjalee as floating science lead and declared first point of contact for **both** pods. Durbadal leads, holds oversight, integration and scope calls, and takes no assigned build tasks.
- **Why:** Only Durbadal and Geethanjalee have prior cure-model expertise; Sharon, Rashid and Rachael are assumed to have general coding and Shiny familiarity and no cure-model background. Splitting build from verification means every number the app prints is checked by someone who did not write the code that printed it (R5), and it lets every Pod A and Pod B task be written so it can be done without reading the cure-model literature — anything needing a statistical judgement call routes to Geethanjalee. She is counted in Pod B because verification against the oracle is where that judgement is needed most.
- **Alternatives considered:** Embedding Geethanjalee in **one pod full time** — either Pod A builds statistically unsupervised, or Pod B loses the author-level authority that makes the oracle (G-01) trustworthy. **One undifferentiated team of four** — no clear owner per module file, which walks straight into R4, the merge-conflict risk that [risks.md](risks.md) rates High (**R4**). Both were rejected, but note the honest tension in what we chose: **this is 2 + 2 out of four people, so Geethanjalee's cross-pod availability is roughly half her time, not full cover for two pods.** That is the best available reading of "the expert oversees both groups" with four pairs of hands, and it is a real constraint, not a solved problem. Equally honest: **the placement of Sharon, Rashid and Rachael is a starting guess made without knowledge of their individual skills.**
- **Consequences:** Swap people between pods freely at the Day-1 standup — the guess above is expected to be wrong in at least one place, and re-balancing is cheaper on Wednesday morning than on Thursday afternoon. Re-balance immediately if Pod A is starved waiting on Geethanjalee; Durbadal is the declared overflow contact (R9). Because absence tolerance is a hard requirement (R2), every task carries a named backup — Sharon backs Rashid and vice versa, Geethanjalee backs Rachael, Durbadal backs Geethanjalee — no task sits single-owner on the critical path, and everything is pushed at the end of every block so any teammate can pick it up. Sharon owns merges into `main`, with Shiny modules in separate `app/R/mod_*.R` files, one owner per file. If a pod boundary is redrawn, record it as a new decision entry superseding this one.
- **Decided by:** Durbadal Ghosh (team lead)

---

### D-005 - Wednesday W1 is onboarding only

- **Date:** 2026-09-15 (pre-event)
- **Decision:** The Wednesday **10:30–12:00** block (**W1**, 1.5 h) is reserved for access and environment setup. No feature work happens in it. Build starts in W2 at 1:00 pm.
- **Why:** An environment failure discovered at 3:00 pm on Wednesday costs a whole day; the same failure discovered at 11:00 am can still be escalated to the organisers with time to recover (R1). Fifteen hours of build time is enough only if it is genuinely available, and half-configured machines silently steal it. The block also buys the three non-experts the 20-minute grounding in what a cure model is and what the app must reproduce (T-05), without which their first tasks would be guesswork.
- **Alternatives considered:** **Starting feature work at 10:30 and fixing environments in parallel** — attractive on paper, but it hides install failures behind visible progress, and the person whose VM is broken ends up blocked while the branch they need moves on without them. **Deferring setup to after lunch** — loses the escalation window entirely and pushes the first real build block into Wednesday afternoon.
- **Consequences:** W1 is the whole of T-01 through T-06: VM and RStudio open, GitHub write access proved by each person pushing one trivial commit to `team.md`, dependencies installed and `scripts/smoke_test.R` plus `shiny::runApp("app-scaffold")` green, AI-agent access confirmed, Geethanjalee's 20-minute package walkthrough, and Durbadal confirming pods, comms channel, branch and PR convention, the block-end push rule and the Definition of Done — including collecting Rashid's GitHub handle, which is currently unrecorded. Go/no-go on the environment is a two-minute check, and **anything unresolved is escalated to the organisers by 11:15 Wednesday**; local-laptop RStudio is an accepted fallback. W2 plans assume a working environment for all four builders — if that is not true at noon, the first W2 decision is a re-plan, recorded here.
- **Decided by:** Durbadal Ghosh (team lead)

---

### D-006 - Feature freeze Thursday, code lock Friday

- **Date:** 2026-09-15 (pre-event)
- **Decision:** **Feature freeze at Thursday 17:00** (end of T4) — scope closes and only bug fixes land after it. **Code lock at Friday 2:45 pm** (end of F4) — laptops closed, walk to MTC Room 2 (IA 1405). The Definition of Done is targeted at **Thursday 5:00 pm**, a full day before judging, so Friday is troubleshooting, documentation and rehearsal rather than building.
- **Why:** Demos fail on the things nobody rehearsed, not on the features nobody built. Aiming the Definition of Done at Thursday 5:00 pm converts Friday's 4.5 hours from a build extension into deliberate slack: F1 is bug bash only, F2 is docs and the clean-clone test, F3 is the deck plus two timed dry runs on the real machine, F4 is the tag and handoff. Without a stated freeze, R3 (scope creep) consumes exactly those hours and we arrive at 3:00 pm with a newer app and an unrehearsed demo.
- **Alternatives considered:** **Freezing Friday morning instead** — an extra evening of features bought at the cost of the bug bash and both dry runs, which is the wrong trade when judging is scored on a 3-minute pitch and a 5-minute booth walkthrough. **Treating the Friday 2:45 pm code lock as the only deadline** — no distinction between "new feature" and "fix", so the last commit before the demo could be an untested feature. Two gates, one for scope and one for code, keep Friday's changes small and reviewable.
- **Consequences:** T-08 records the freeze as the lead's call; T-09 records the lock. After Thursday 17:00, **no new feature lands without Durbadal's written approval in this file** — a new decision entry, which is the cost that keeps the bar high. The Thursday 1:00–2:00 flex hour (campus tours, and the designated absence hour) carries nothing on the critical path, so slippage has somewhere to go. Anything unfinished at freeze goes to `docs/handoff.md` (D-08) as a known limitation rather than into Friday's build queue. Friday's remaining work is fixed in advance: A-11 / B-10 by severity in F1, D-01 through D-04 and B-11 in F2, D-05 through D-07 in F3, D-08 in F4.
- **Decided by:** Durbadal Ghosh (team lead)

---

### D-007 - Diagnostics always run, never auto

- **Date:** 2026-09-15 (pre-event)
- **Decision:** The app calls `cure.appropriateness()` with `run_tests = "yes"`, never the package default `"auto"`. Users always see all five diagnostics, including when a non-cure model wins on AIC, and the screen explains why they are being shown anyway.
- **Why:** With `run_tests = "auto"` the wrapper silently skips Stage 2 whenever the smallest-AIC model is a non-cure model. That is a sensible default for a scripting user who knows what was skipped, and a trap for the point-and-click user this app exists for: they would see an AIC verdict with no diagnostics and no indication that half the assessment did not run. The reverse case is just as important — `gbsg` picks `loglogistic_cure` on AIC, and it is the diagnostics (r̂ = 0.3080, `qn` = 0.0044, RECeUS) that reveal follow-up is insufficient. Stage 1 alone is not enough in either direction, and an empty panel teaches nothing.
- **Alternatives considered:** Keeping **`"auto"`** — matches the package default and saves a fraction of a second, but hides exactly the information the app is built to surface. **`"no"`** — never in contention; it disables Stage 2 outright. A **user-facing toggle between `"auto"` and `"yes"`** — rejected because it hands a non-expert a switch whose consequence ("silently skip half the assessment") is the thing they are least equipped to judge.
- **Consequences:** A-08 hard-codes `run_tests = "yes"` on the Verdict tab and carries on-screen copy explaining why diagnostics appear even though a non-cure model won; G-04 owns the wording. G-01's oracle is generated the same way — `cure.appropriateness(..., run_tests = "yes")` — so app and oracle are comparable line for line, which is what B-04, B-06 and B-08 check. Two consequences fall out of the wrapper's behaviour and must be handled in the UI, not discovered at the booth: when no `dist` is supplied the wrapper runs RECeUS on the **best-AIC cure model**, which on a non-cure-winning dataset is not the overall best model, so the app states which distribution the diagnostics used; and when **no cure model fits at all**, the wrapper cannot run the tests and reports that reason instead of results, so the Diagnostics and Verdict tabs must render that explanation rather than an empty panel. This is also the setting under which the `NA` diagnostics of simulated scenarios C and D appear, so the "cannot be computed — the longest observed time is an event, so there is no plateau to test" state (A-07, R7) is on the normal path, not an edge case.
- **Decided by:** Durbadal Ghosh (team lead)

---

### D-008 - No calls into package internals

- **Date:** 2026-09-15 (pre-event)
- **Decision:** The app never calls the package's internal `.map_model_to_receus_dist()`. Model-to-RECeUS translation happens either inside `cure.appropriateness()`, which does the mapping itself, or through an explicit dropdown of RECeUS distribution codes that the user or the app passes as `dist`.
- **Why:** `model.fitting()` names models one way (`weibull_cure`, `loglogistic_cure`) and `receus.method()` wants short codes (`"exp"`, `"wei"`, `"gam"`, `"llogis"`, `"lnorm"`, plus the `...Unc` non-cure variants). The translation between them is an unexported internal helper marked as such in the package source; reaching it needs `:::`, which is not part of the package's contract, can be renamed or dropped in any upstream release without notice, and would flag in a package check. The supported routes give the same answer: the wrapper maps for us, and the `dist` argument is the public way to override it. Re-typing the mapping table in app code is the same bet with an extra copy to keep in sync.
- **Alternatives considered:** **`cureAssess:::.map_model_to_receus_dist()`** — shortest path, but it couples the app to a private implementation detail and makes our app the thing that breaks when the package improves. **Re-implementing the mapping in app code** — no `:::`, but it duplicates logic that already exists and will drift silently the moment the package adds a distribution; a drifted copy produces a wrong-distribution RECeUS result that still looks plausible on screen, which is the worst failure mode we have.
- **Consequences:** A-08 relies on the wrapper's own mapping for the Verdict tab. Where the Diagnostics tab needs an explicit distribution (A-07, via `run.cure.tests()`), it comes from a dropdown of the documented short codes, not from a locally-derived translation. Whichever route is used, the app **displays which distribution the diagnostics ran on**, so a verification mismatch is traceable rather than mysterious. Two related rules follow from the same principle of leaning on the package rather than re-implementing it: the `error` column from `model.fitting()` is displayed, not hidden, because failed fits are recorded there with `AIC = NA` rather than thrown (A-05, R6); and `include_lognormal` stays an opt-in toggle with the warning that lognormal's heavy tail can change both the selected model and the RECeUS conclusion. If a real need to touch an internal ever appears, the fix goes upstream first — see D-009.
- **Decided by:** Durbadal Ghosh (team lead)

---

### D-009 - cureAssess is vendored, not installed

- **Date:** 2026-09-15 (pre-event)
- **Decision:** The `cureAssess` package source (version 0.1.0, MIT) is vendored into this repository at `cureAssess/` rather than installed from GitHub. Upstream remains `https://github.com/GeethanjaleeM/cureAssess`, the vendored copy is **not modified**, and any fix goes upstream.
- **Why:** Two failure modes disappear at once. First, network and install dependence: the team does not need a working GitHub reach or a successful source build on every machine at every setup step, which matters most in W1 when R1 is live. Second, a moving target: the package author is on this team and may well improve the package during the event, and an app being verified against a fixed oracle cannot also be chasing an upstream change mid-block. A pinned, in-repo copy means every clone of this repository — and every clean-clone test — reproduces the same numbers. Not modifying the copy is what keeps that guarantee meaningful: if fixes landed locally, our vendored tree would quietly become a fork and the published package would no longer be the thing we validated against.
- **Alternatives considered:** **Installing from GitHub at setup time** (`remotes`/`pak`) — the normal workflow, but it makes every machine's environment a fresh network and compile gamble and lets upstream change under a verification pass. **A git submodule pointing at upstream** — pins a commit honestly, but adds a clone step people forget, and a missed `--recursive` presents as a broken app rather than a missing dependency.
- **Consequences:** W1's smoke test (T-03) and the clean-clone tests (B-09, B-11) exercise the vendored copy, so a green clean clone is real evidence the demo machine will behave. Any bug or gap Pod A or Pod B finds in the package is filed upstream against `GeethanjaleeM/cureAssess` — Geethanjalee is the package author and the authority on its behaviour — and the app works around it locally until a release exists; nobody edits `cureAssess/` in this repo. Attribution and licensing travel with the code: MIT, authors Geethanjalee Mudunkotuwa (aut, cre, cph) and Durbadal Ghosh (aut), and the About tab (A-10) carries how to cite the package alongside Maller & Zhou (1992, 1994), Shen (2000) and Selukar & Othus (2023). `docs/handoff.md` (D-08) records the vendored version and where upstream lives, so whoever picks this up knows which copy is canonical.
- **Decided by:** Durbadal Ghosh (team lead)

---

## Template — copy this for the next decision

### D-0NN - <next decision>

- **Date:** <YYYY-MM-DD> (<block, e.g. W3 / T4 / F1>)
- **Decision:** <what was decided, one or two sentences — state it as a rule someone can follow>
- **Why:** <the reasoning: what problem this solves, what breaks without it>
- **Alternatives considered:** <what else was on the table and why it lost>
- **Consequences:** <what this commits the team to: which task IDs change, what has to be retested, what the Definition of Done now means>
- **Decided by:** <name (role)>
- **Supersedes / superseded by:** <D-0NN, or omit this line>
