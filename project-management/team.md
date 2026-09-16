# Team and Roles — KIDS26 Team 9

- **Team name:** KIDS26 Team 9
- **Team lead:** Durbadal Ghosh (`@Durbadal0`)
- **Comms channel:** [to confirm at T-06]
- **Project question:** Can we let a clinician or analyst decide whether a cure model is appropriate for their survival dataset without writing R code or reading the cure-model literature?
- **Expected output (by Fri 18 Sep, 3:00 pm):** a locally-run Shiny app (`cureAssessApp`) wrapping the `cureAssess` R package, plus example data, a downloadable HTML report, a user guide, and a rehearsed demo.
- **Tools and stack:** R (>= 4.1; the VM has 4.6.1), `shiny`, `bslib`, `DT`, `rmarkdown`; package dependencies `survival`, `flexsurv`, `flexsurvcure`, `survminer`, `ggplot2`, `dplyr`. Repo `stjude-biohackathon/KIDS26-Team9`, branch `main`. Local only — `shiny::runApp()` on the hackathon VM / RStudio, no public hosting. Public and simulated data only.

**The app does not exist yet.** Everything below is a plan for the 16.5 h of hack time (~15 h of build time after the Wednesday onboarding block).

## Roster

| Person | GitHub | Pod | Primary role | Backup |
| --- | --- | --- | --- | --- |
| Durbadal Ghosh | `@Durbadal0` | — | **Team lead.** Oversight, integration decisions, scope calls, unblocking, feature-freeze call, lightning pitch. **No assigned build tasks.** | — |
| Geethanjalee Mudunkotuwa | `@GeethanjaleeM` | Floating (based in Pod B) | **Science Lead + first point of contact for BOTH pods.** Owns the reference-answer oracle, statistical correctness, and every word of interpretation/help text the app prints. Package author, so she is the authority on `cureAssess` behaviour. | Durbadal |
| Sharon Freshour | `@sharonfreshour` | **Pod A — App** | **App Lead.** Shiny architecture, data input + column mapping, Models/AIC tab, owns merges into `main`. | Rashid |
| Rashid Mehmood | [handle to confirm - collect Day 1] | **Pod A — App** | **App Dev.** Diagnostics tab, Verdict tab, report download, in-app help wiring. | Sharon |
| Rachael Oluwakamiye Abolade, PhD | `@Oluwakamiyeabolade` | **Pod B — Data & QA** | **Data/QA Lead.** Example dataset curation, simulation scenario matrix, independent verification against the oracle, user guide, booth demo script. | Geethanjalee |

Rashid's handle is collected as part of **T-06** on Wednesday morning; the row above is not done until it is filled in.

## How the pods work

Pods are 2 + 2, with the science lead floating.

**Pod A — App (Sharon, Rashid).** Pod A builds the Shiny app: the five tabs (Data, Models, Diagnostics, Verdict, About), the CSV upload and column mapper, the plots, the report download, and the in-app help wiring. Pod A calls the `cureAssess` exported functions and re-implements nothing. To keep merge conflicts out of a single `app.R`, the app is built as Shiny modules in separate files under `app/R/mod_*.R`, with **one owner per module file**. Sharon owns merges into `main`.

**Pod B — Data & QA (Rachael, with Geethanjalee based here).** Pod B builds what the app is tested against and then tests it: the data contract, the three curated real examples, the four-scenario simulation matrix, the parameterised HTML report, the user guide, and the verification passes. Geethanjalee separately builds the **reference oracle** (**G-01**) — `cure.appropriateness(..., run_tests = "yes")` run in plain R on all three real examples, committed to `tests/reference/`. Those committed numbers, not anyone's memory, are what the app must reproduce.

**Why Pod B verifies, not Pod A.** The person who wrote a screen is the worst person to check it, because they will read the number they expected to see rather than the number on screen. Verification here is a mechanical comparison — open the app, read the value, compare it against the committed oracle file, file a GitHub issue if it differs — and it is done by someone who did not write the code being checked (**B-04**, **B-06**, **B-08**). A number that disagrees with the package is a **blocking** bug, not a cosmetic one: the whole claim of the project is that the app is a faithful front end to a peer-review-backed workflow.

Geethanjalee is counted in Pod B because statistical judgement is needed most at verification, but **roughly half her time is reserved for answering Pod A**. That is the honest reading of "the expert oversees both groups" with only four pairs of hands. If Pod A is starved, re-balance at the Day-1 standup.

## Expertise map

- **Only Durbadal and Geethanjalee have prior cure-model experience.** Sharon, Rashid and Rachael are assumed to have general coding / Shiny familiarity and **no cure-model background**. That is a design constraint on the task list, not a problem to be fixed during the hackathon.
- **Every task assigned to Sharon, Rashid or Rachael is written so it can be completed without reading the cure-model literature.** They wire up functions, render values the package returns, compare printed numbers against a committed reference file, and print interpretation text that Geethanjalee wrote. None of that requires knowing what a mixture cure model is.
- **Anything requiring a statistical judgement call routes to Geethanjalee first and Durbadal second.** Examples of judgement calls: what a threshold means, whether an `NA` is correct behaviour or a bug, how to word a verdict, whether two diagnostics disagreeing is expected, and what to tell a user whose follow-up looks insufficient. Do not guess and do not ask an AI coding agent to arbitrate — those answers become **G-02**, **G-03** and **G-04**.
- Practical rule: if you are about to write a sentence about what a statistic *means*, stop and hand it to Geethanjalee. If you are about to write code that *displays* a statistic, that is yours.

## Pod placement caveat — read this before the Day-1 standup

**The Pod A / Pod B placement of Sharon, Rashid and Rachael is a starting guess made without knowledge of their individual skills.** It was assigned to have a plan on paper at hour zero, not because anyone judged who is better at what. Swap freely at the Day-1 standup (**T-06**) — if Rachael would rather build Shiny modules and Rashid would rather own data and verification, trade the task IDs and update this table. The only placements that should not move without discussion are Geethanjalee (she is the package author, so the oracle and all interpretation text stay with her) and Durbadal (no build tasks by design).

---

## Durbadal Ghosh — Team lead

**Mandate:** keep the team unblocked and the scope closed, make the calls nobody else can make, and pitch the work in three minutes.

**Holds no build tasks.** This is deliberate. Durbadal writes no app code, curates no data and owns no module file. His job is oversight, integration decisions, scope calls, unblocking, and the lightning pitch. If he ends up coding, something has gone wrong with the plan and that should be said out loud at the next standup.

Owns:
- **T-06** — confirm pods, roles, comms channel, branch + PR convention, block-end push rule, and the Definition of Done at the W1 onboarding block. Collect Rashid's GitHub handle. *Done:* every person can restate the convention, and the handle is in this file.
- **T-07** (W3, 4:45–5:00) — run the standup, confirm everyone has pushed, and record the day's decisions in `project-management/decisions.md` with date, decision, why.
- **T-08** — **Thursday 17:00 FEATURE FREEZE.** His call, said out loud, logged in `decisions.md`. Scope closes; only bug fixes after this.
- **T-09** — **Friday 2:45 CODE LOCK.** Laptops closed, walk to MTC Room 2 (IA 1405).
- **D-05** — the lightning deck: **5 slides, 3 minutes**, content supplied by the team. *Done:* deck committed, and rehearsed twice on the real machine as part of **D-07**.
- **Lightning pitch** (Fri 3:00–4:00, MTC Room 2 IA 1405) — he presents, Sharon drives the app.
- Booth (Fri 4:00–6:00) — floats and closes.
- Risk ownership: **R1** (VM/install failure — escalate to organisers by 11:15 Wed), **R2** (absences), **R3** (scope creep).
- Written approval in `decisions.md` for any new feature during Friday's **F1** bug bash. Without it, the answer is no.

Does **not** own: any app module, the oracle, the datasets, the report template, the user guide, verification, or merges to `main`.

Backed up by: nobody is named in the roster. **[to confirm]** at the Day-1 standup — pick a stand-in for the scope call, the freeze call and the pitch, because the roster currently has a single point of failure here.

Escalates to: the hackathon organisers (VM, GitHub and agent access — **T-01** through **T-04**).

## Geethanjalee Mudunkotuwa — Science Lead

**Mandate:** be the authority on what is statistically correct, produce the numbers the app must match, and write every word the app says about meaning.

Owns:
- **T-05** — the 20-minute walkthrough in W1: what a cure model is, what `cureAssess` does, what the app must reproduce. *Done:* the three non-experts can each say what the app has to produce and why a KM plateau is not proof of cure.
- **G-01** — the **reference oracle**: `cure.appropriateness(..., run_tests = "yes")` on all three real examples in plain R, committed to `tests/reference/` (AIC table + all five diagnostics + verdict). *Done:* the committed files match the verified reference numbers, and Pod B can diff against them without asking her anything. A full run takes 0.1–0.2 s, so this is a short task with a long shadow — everything downstream compares to it.
- **G-02** — Stage-1 help copy: what AIC is, and why "a cure model won on AIC" is *initial support only*, not proof.
- **G-03** — help copy for all five diagnostics, two plain-language sentences each (Maller–Zhou 1994, `qn`, Shen 2000, Immune summary, RECeUS).
- **G-04** — verdict copy plus the "follow-up looks insufficient — what now?" guidance: use a non-cure model; or the extreme-value estimators of Escobar-Bach & Van Keilegom; or Yuen & Musta's relaxed condition; or collect more follow-up.
- **B-08** — full regression, jointly with Rachael: every tab, all seven datasets (3 real + 4 simulated), app vs oracle, sign-off table committed.
- **B-09** — clean-clone test: fresh `git clone` on a machine that has never run the app.
- **B-11** — clean-clone re-test on Friday after all F2 changes.
- **First point of contact for both pods** on anything statistical, with ~50 % of her time reserved for that.
- Booth (Fri 4:00–6:00) — fields statistical questions.
- Risk ownership: **R9** (non-experts blocked waiting on her).
- Backup for: **B-01**, **B-02**, **B-03**, **D-02**, and anything else of Rachael's with no task-level backup named.

Does **not** own: any app module, the UI, merges to `main`, the deck, or the booth script. If she is writing Shiny code, Pod A is under-staffed and the pods should be re-balanced.

Backed up by: Durbadal.

Escalates to: Durbadal (for scope, for "we cannot do this in the time left", and when too many people are queued on her at once).

## Sharon Freshour — App Lead (Pod A)

**Mandate:** own the app's architecture and the path from a dataset to a verdict on screen, and be the only person who merges to `main`.

Owns:
- **A-01** (W2) — app skeleton: `app/` directory, `bslib` navbar page, five tabs (Data, Models, Diagnostics, Verdict, About). *Done:* `shiny::runApp("app")` opens, all tabs navigate, zero console errors.
- **A-03** (W3) — CSV upload + column mapper: time column, status column, which level means "event", time scale (`none` / `days_to_years`). `.check_surv_data()` failures surface as friendly messages, never a red Shiny crash. *Done:* uploading `gbsg.csv` reproduces the built-in gbsg path exactly.
- **A-05** (T1) — Models tab: `model.fitting()` → sortable `DT` AIC table with a cure / non-cure badge, best-model callout, `include_lognormal` toggle, explicit **Run** button, and the `error` column shown when a fit fails. *Done:* the AIC table matches the oracle for all three real examples, and a deliberately broken fit shows its message instead of vanishing.
- **A-08** (T3) — Verdict tab: `cure.appropriateness(run_tests = "yes")` → three-step status strip mirroring manuscript Figure 1 (Expert judgment → Visual assessment → Quantitative assessment), the plain-language recommendation, and an explicit "the diagnostics can disagree — here is what to do" panel. Default `run_tests = "yes"`, **not** `"auto"`, with the reason shown on screen. *Done:* `gbsg` shows a cure model winning on AIC *and* a follow-up-insufficient verdict, without looking like a bug.
- **A-10** (T4) — in-app help: a tooltip/popover on every statistic (text from **G-02**/**G-03**/**G-04**, not written by Pod A); About tab with the four key references and how to cite the package.
- **D-03** (F2) — in-app help / label polish pass, jointly with Rashid.
- **D-08** (F4) — tag `v1.0`, write `docs/handoff.md` with known limitations and next steps, final push. *Done:* the tag exists on `main` and the handoff doc names the stretch list as next steps.
- **Merges to `main`**, one PR per task, PR title starting with the task ID.
- Risk ownership: **R4** (merge conflicts — modules in separate files, one owner per file, short branches).
- Lightning pitch (Fri 3:00–4:00) — drives the app while Durbadal presents.
- Booth (Fri 4:00–6:00) — drives the app.
- Backup for: **A-02**, **A-04**, **A-07**, and Rashid's Pod A work generally.

Does **not** own: any interpretation or help *wording* (that is Geethanjalee's), the datasets, the report template, verification of her own tabs, or the scope call.

Backed up by: Rashid.

Escalates to: Geethanjalee for anything statistical (what a number means, whether behaviour is correct); Durbadal for scope, for "this tab will not be ready", and for merge disputes.

## Rashid Mehmood — App Dev (Pod A)

**Mandate:** own the two tabs where the science becomes visible, plus the report download, and make every failure state readable.

Owns:
- **A-02** (W2) — Data tab v1: built-in dataset picker → `prepare.surv.data()` → summary card (n, events, censored %, median follow-up, max follow-up) + `head()` table. *Done:* "nwtco — High risk" shows n = 1404.
- **A-04** (W3) — KM plot on the Data tab with risk table. *Done:* the plot renders for all three built-in examples with no console errors.
- **A-06** (T1) — overlay the fitted survival curve for the selected model on the KM curve. *Done:* changing the selected model changes the overlay.
- **A-07** (T2) — Diagnostics tab: five cards (Maller–Zhou 1994, `qn`, Shen 2000, Immune summary, RECeUS), each with statistic, threshold, pass/fail chip, and the package's own `interpretation` string. **Must render an explanatory "cannot be computed" state when the statistic is `NA`** — the message being "the longest observed time is an event, so there is no plateau to test", not a blank cell, not `NA`, not a crash. *Done:* simulated scenarios C and D render that message; the three real examples match the oracle.
- **A-09** (T4) — wire `downloadHandler` to render and download the HTML report produced by **B-07**. *Done:* clicking download yields an HTML file that opens.
- **D-03** (F2) — in-app help / label polish pass, jointly with Sharon.
- **D-04** (F2) — screenshots plus a short screen-capture GIF for the slides and as the offline demo fallback. *Done:* committed to the repo, not sitting on a laptop.
- Booth (Fri 4:00–6:00) — owns the backup laptop with the app already running, and the screenshot fallback.
- Risk ownership: **R6** (a model fit fails on uploaded data — surface the `error` column, never crash), **R7** (diagnostics return `NA` and the UI looks broken), **R8** (demo machine or projector fails).
- Backup for: **A-01**, **A-03**, **A-05**, **A-08**, **B-07**.

Does **not** own: merges to `main`, the interpretation wording, the oracle, the datasets, or verification of his own tabs.

Backed up by: Sharon.

Escalates to: Geethanjalee for anything statistical — in particular, whether an `NA` or a failed fit is correct package behaviour or a real bug; Durbadal for scope and for "this will not be ready".

## Rachael Oluwakamiye Abolade, PhD — Data/QA Lead (Pod B)

**Mandate:** define and build the data the app runs on, independently prove the app's numbers match the package, and write what a new user reads.

Owns:
- **B-01** (W2) — the data contract, `docs/data-contract.md`: required columns, event coding (0/1 required by the package; must remap 1/2 and TRUE/FALSE), time units, missing-value policy, minimum n, and every error `.check_surv_data()` can raise. *Done:* Pod A can build the column mapper from this document alone.
- **B-02** (W2) — curate the three built-in examples to `data/examples/` as CSV plus a `README.md` with provenance and licence: (1) `nwtco_high_risk` (stage 3–4), (2) `gbsg`, (3) `colon_lev5fu` (recurrence, `etype == 1`, `rx == "Lev+5FU"`). *Done:* files committed with licence and provenance; nothing restricted or identifiable.
- **B-03** (W3) — implement `simulate_cure_data()` and the four-scenario matrix. *Done:* the function reproduces the reference implementation's outputs.
- **B-04** (W3) — verification pass #1: Stage-1 numbers, app vs oracle, three datasets. *Done:* a GitHub issue filed per mismatch, or an explicit "no mismatches" note.
- **B-05** (T1) — commit the four simulated scenario datasets and their expected verdicts.
- **B-06** (T2) — verification pass #2: AIC tables, app vs oracle, three real plus four simulated datasets. One issue per mismatch.
- **B-07** (T3) — `report/report.Rmd`, a parameterised HTML report: dataset label, data summary, KM plot, AIC table, five diagnostics, verdict, session info, citations. *Done:* renders from plain R with parameters before Pod A wires **A-09** to it.
- **B-08** (T4) — full regression jointly with Geethanjalee: every tab, all seven datasets, app vs oracle, sign-off table committed.
- **D-01** (F2) — final `README.md`: what it is, install, run in under 10 minutes, screenshot.
- **D-02** (F2) — `docs/user-guide.md`: the guided walkthrough using the gbsg teaching example.
- **D-06** (F3) — booth script: **5 minutes**, plus answers to the six questions judges will ask. *Done:* committed and rehearsed twice under **D-07**.
- Booth (Fri 4:00–6:00) — narrates the 5-minute walkthrough.
- Risk ownership: **R5** (the app prints a number that differs from the package — a mismatch is blocking), **R10** (judges read the `gbsg` contradiction as a bug — reframe it as the headline finding).

Does **not** own: any app code or module file, the interpretation/help wording (Geethanjalee's), merges to `main`, or the scope call.

Backed up by: Geethanjalee (**B-01**, **B-02**, **B-03**, **D-02** and anything with no task-level backup named); Rashid for **B-07**.

Escalates to: Geethanjalee first for anything statistical — especially "is this difference a real mismatch or a rounding artifact?"; Durbadal second, and immediately if a mismatch threatens the Definition of Done.

---

## If someone is away

Absences are expected, not hypothetical — the lead has flagged this (**R2**, likelihood **High**). The plan is built so that one person missing a block costs a block, not a deliverable.

The rule set:

1. **Every task has a named backup.** Where the backlog names a task-level backup, that person picks it up. Where it does not, the roster backup in the table above applies.
2. **Nothing single-owner sits on the critical path.** The critical path to the Definition of Done is A-01 → A-02 → A-03 → A-05 → A-07 → A-08 → B-07 → A-09, and every one of those has a second person who can carry it.
3. **Push at the end of every block.** Unpushed work does not exist. This is what actually makes a handover possible: if a teammate does not come back tomorrow, their branch is on the remote and somebody else opens the PR.
4. **Branch per task, one PR per task**, so a half-finished task is a readable diff and not a mystery in somebody's working directory.
5. **The Thursday 1:00–2:00 flex hour absorbs slippage.** Campus tours are optional; anyone who skips the tour starts T3 early. Nothing on the critical path may be *scheduled* there — it exists to catch what slipped.
6. **Friday F1 is bug bash only** and the Definition of Done targets **Thursday 5:00 pm**, a full day before judging. That day of slack is the absence buffer.
7. **Say it at the standup.** If you know you will miss a block, say so at the previous standup (Wed 4:45 pm, Thu 9:30 am, Thu 4:45 pm, Fri 9:30 am) and hand your branch over out loud. Durbadal logs the reassignment in `decisions.md`.

| If away | Picks up | Task IDs |
| --- | --- | --- |
| Sharon | Rashid | **A-01**, **A-03**, **A-05**, **A-08**, **A-10**, **D-08**, and Sharon's half of **D-03**. Merge rights to `main` pass to Rashid; Durbadal approves merges while she is out. App driving at the lightning pitch and booth also falls to Rashid. |
| Rashid | Sharon | **A-02**, **A-04**, **A-06**, **A-07**, **A-09**, **D-04**, and Rashid's half of **D-03**. Booth backup laptop and screenshot fallback go to Sharon. |
| Rachael | Geethanjalee | **B-01**, **B-02**, **B-03**, **B-04**, **B-05**, **B-06**, **D-01**, **D-02**, **D-06**, and Rachael's half of **B-08**. **B-07** goes to Rashid (task-level backup). Booth narration goes to Geethanjalee. |
| Geethanjalee | Durbadal | **T-05**, **G-01**, **G-02**, **G-03**, **G-04**, **B-09**, **B-11**, and her half of **B-08**. He is the only other person with cure-model expertise, so this is the one handover with no third option — which is why **G-01** is committed to `tests/reference/` early rather than living in her head. |
| Durbadal | **[to confirm]** | The roster names no backup. Confirm a stand-in at the Day-1 standup for **T-06**–**T-09**, **D-05** and the lightning pitch. |

If two people are away in the same block, the lead cuts scope rather than moving the deadline: stretch goals **S-1** through **S-5** are already out of scope until the Definition of Done is signed off, and the next thing to go is polish, never verification.

## Demo-day assignments (Fri 3:00–6:00)

| Slot | Who does what |
| --- | --- |
| **Lightning pitch** — 3 min, MTC Room 2 (IA 1405), 3:00–4:00 | Durbadal presents; Sharon drives the app. Deck is **D-05** (5 slides, 3 minutes). |
| **Booth** — MTC Atrium, 4:00–6:00, **rotate every 30 min so nobody is stuck the whole 2 h** | Rachael narrates the 5-minute walkthrough (**D-06**) · Sharon drives · Geethanjalee fields statistical questions · Rashid owns the backup laptop and the screenshot fallback (**D-04**) · Durbadal floats and closes. |
| Rehearsal | **D-07** — **two timed dry runs** on the actual demo machine with the actual app, in **F3** (Fri 1:00–2:00). Whole team. Both the 3-minute pitch and the 5-minute booth script are rehearsed twice; this is item 8 of the Definition of Done. |
| 6:00 | Winners announced and closing remarks (MTC Atrium). |

## Ways of working

- **Branch per task:** `<initials>/<task-id>-<short-slug>`, e.g. `sf/A-01-app-skeleton`.
- **One PR per task.** The PR title starts with the task ID. A teammate skims it before merge. **Sharon merges to `main`.**
- **Push at the end of every block.** Unpushed work does not exist.
- **Decisions** that change the approach go in `project-management/decisions.md` with date, decision, and why. Durbadal records them.
- **Blockers** go in a GitHub issue immediately, and get said out loud at the next standup.
- **Never commit** data that is not public, credentials, or anything identifiable. Public and simulated data only.
- **One owner per module file** (`app/R/mod_*.R`). Do not edit someone else's module; ask them or open an issue.
- **Standups:** Wed 4:45 pm, Thu 9:30 am, Thu 4:45 pm, Fri 9:30 am. Ten minutes, standing up.
- **Hard stops** are hard: Wed 3:00–3:20 break, Thu 10:30–10:50 and 3:00–3:20 breaks, Fri 10:30–10:50 break. **Thu 17:00 = feature freeze. Fri 2:45 = code lock.**

Roles can overlap, and the pod split in particular is a first guess. Revisit this file at the Day-1 standup (**T-06**) and whenever the plan changes; log the change in `decisions.md`.
