# Risk Register — cureAssessApp (KIDS26 Team 9)

St. Jude BioHackathon 2026, Wed 16 – Fri 18 September 2026.
This is a plan written before the event. The Shiny app has not been built yet; every "the app must…"
statement below is a requirement on work still to be done.

Scope of this document: the ten registered risks, how each one will be detected and handled in the
moment, the objective tripwires that force a decision at a fixed time, and the shortcuts that stay
forbidden no matter how far behind we are.

---

## 1. Register

| # | Risk | Likelihood | Mitigation | Owner |
| --- | --- | --- | --- | --- |
| R1 | VM / RStudio / package install fails in W1 and eats Day 1 | Medium | Dependency list published in advance; `scripts/smoke_test.R` and the scaffold app give a go/no-go in 2 min; local-laptop RStudio is an accepted fallback; escalate to organisers by 11:15 Wed. | Durbadal |
| R2 | A teammate is absent for part of the event (flagged as expected) | **High** | Every task has a named backup; nothing single-owner on the critical path; **everything pushed at every block end**; the Thu 1:00–2:00 flex hour absorbs slippage. | Durbadal |
| R3 | Scope creep — the stretch list eats the core | Medium | Hard **feature freeze Thu 17:00**; stretch goals are written down and explicitly out of scope until the Definition of Done is signed off. | Durbadal |
| R4 | Merge conflicts from everyone editing one `app.R` | **High** | Shiny modules in separate files, `app/R/mod_*.R`, **one owner per module file**; short branches; Sharon owns merges to `main`. | Sharon |
| R5 | The app prints a number that differs from the package | Medium | Pod B verifies against Geethanjalee's oracle every block; a mismatch is a **blocking** bug, not a cosmetic one. | Rachael |
| R6 | A model fit fails on a user's uploaded data | Medium | `model.fitting()` already captures the error; surface the `error` column and a friendly message. Never crash. | Rashid |
| R7 | Diagnostics come back `NA` and the UI looks broken | **High** (happens on any dataset whose longest observation is an event) | Explicit "cannot be computed" state with the reason, specified up front. | Rashid |
| R8 | Demo machine or projector fails | Low | Screenshots + screen-capture GIF committed Friday morning; backup laptop with the app already running (Rashid). | Rashid |
| R9 | Non-experts blocked waiting on Geethanjalee | Medium | She is the declared first point of contact with ~50 % of her time reserved for it; tasks are written to be doable without cure-model knowledge; Durbadal is the overflow. | Geethanjalee |
| R10 | Judges read the `gbsg` contradiction as a bug | Low | Reframe it as the headline finding — it is the clearest demonstration of why the tool is needed. Scripted into the booth walkthrough. | Rachael |

---

## 2. Response detail

### R1 — Environment fails in W1
**Trigger.** During T-01/T-03, any teammate cannot open RStudio on the VM, `scripts/smoke_test.R` errors,
or `shiny::runApp("app-scaffold")` does not launch.
**Response.** The unblocked pair with the blocked immediately; Durbadal escalates to the organisers by
11:15 Wed and records the blocker in `decisions.md`; W1 stays onboarding-only so no feature work is lost.
**Fallback.** Local-laptop RStudio is an accepted environment for anyone the VM will not serve; W2 starts
on whatever environment works for that person, with the dependency list as the shared contract.

### R2 — A teammate is absent for part of the event
**Trigger.** Someone is not present at a block start or misses one of the standups (Wed 4:45 pm,
Thu 9:30 am, Thu 4:45 pm, Fri 9:30 am) without notice.
**Response.** The named backup picks the task up from the last pushed branch — this only works because
of the block-end push rule, so enforce it; Durbadal reassigns and logs the change in `decisions.md`.
**Fallback.** The Thu 1:00–2:00 flex hour and all of Friday F1 absorb the slip; nothing on the critical
path is ever scheduled into the flex hour.

### R3 — Scope creep
**Trigger.** A branch or PR appears whose title carries no task ID from the backlog, or any `S-` stretch
work starts before the Definition of Done is signed off.
**Response.** Sharon does not merge it; the idea is written onto the stretch list instead. Only Durbadal
can authorise an exception, and only as a written entry in `decisions.md`.
**Fallback.** The Thu 17:00 feature freeze is absolute — after it, bug fixes only, and F1 on Friday is a
bug bash with no new features.

### R4 — Merge conflicts on one file
**Trigger.** A PR touches an `app/R/mod_*.R` file owned by someone else, or git reports a conflict when
Sharon merges to `main`.
**Response.** Sharon resolves it with the file owner present, never alone; the owner rewrites their own
side. Branches stay short (`<initials>/<task-id>-<short-slug>`, one PR per task) so conflicts stay small.
**Fallback.** If two people genuinely must touch the same module inside one block, they pair on a single
branch instead of opening two.

### R5 — The app prints a number the package did not produce
**Trigger.** A verification pass (B-04 Stage-1, B-06 AIC tables, B-08 full regression) finds any app value
that differs from `tests/reference/`.
**Response.** Rachael files a GitHub issue per mismatch and says it out loud at the next standup; it is
treated as blocking, so Pod A stops feature work on that tab until it is closed. Geethanjalee is the
authority on which value is correct.
**Fallback.** If a mismatch cannot be resolved before the freeze, the number is removed from the UI with
an explanatory message — we ship less rather than ship wrong.

### R6 — A model fit fails on uploaded data
**Trigger.** `model.fitting()` returns `AIC = NA` for one or more rows and puts a message in the `error`
column — expect this on small, heavily censored or badly coded uploads.
**Response.** The Models tab shows the `error` column rather than hiding it, keeps the remaining rows
ranked, and prints a plain-language note that some fits did not converge. `model.fitting()` never throws,
so there is no crash to handle — only a display job.
**Fallback.** The user can re-run with the `include_lognormal` toggle off, or work from the fits that did
succeed; the Verdict tab must still be reachable.

### R7 — Diagnostics return `NA` and the UI looks broken
**Trigger.** Maller–Zhou, `qn` or Shen come back `NA`. This happens whenever the largest observed time is
an event, which is exactly what simulation scenarios C and D produce.
**Response.** The Diagnostics card renders the specified state — "cannot be computed — the longest
observed time is an event, so there is no plateau to test" — never a blank cell, never a bare `NA`,
never a crash. Immune summary and RECeUS still render.
**Fallback.** Scenarios C and D are the standing regression cases for this state; if the message is not in
place, the tripwire on the Diagnostics tab (below) fires.

### R8 — Demo machine or projector fails
**Trigger.** The app will not launch, the laptop will not wake, or the projector will not sync — either at
the 3:00–4:00 lightning session or during the 4:00–6:00 booth rotation.
**Response.** Rashid switches to the backup laptop, which has the app already running and untouched since
the 2:45 code lock; Sharon keeps driving so the narration does not change.
**Fallback.** Present from the D-04 screenshots and screen-capture GIF committed in F2 — the lightning
deck and the booth script must both work with no live app.

### R9 — Non-experts blocked waiting on Geethanjalee
**Trigger.** A Pod A task stalls on a statistical question for more than a few minutes, or more than one
person is queued for her at a block start.
**Response.** Ask Durbadal, who is the declared overflow; park the question in a GitHub issue and keep
working the non-statistical part of the task in the meantime.
**Fallback.** Re-balance the pods at the next standup — the 2 + 2 split with Geethanjalee counted in Pod B
is a starting guess and is meant to be changed if Pod A is starved.

### R10 — Judges read the `gbsg` contradiction as a bug
**Trigger.** A judge or visitor asks why the diagnostics disagree with each other, or why an app that
picked a cure model then says follow-up is insufficient.
**Response.** Lead with it rather than defend it: AIC picks `loglogistic_cure` (AIC 1719.70), but
r̂ = 0.3080 means the cure fraction cannot be identified; Maller–Zhou (0.0495) says follow-up is
sufficient while `qn` (0.0044), Shen (0.3676) and RECeUS say it is not. That disagreement is the finding.
**Fallback.** `colon` is the borderline companion case — r̂ = 0.064 against the 0.05 threshold — for
showing that thresholds are conventions, not laws. Geethanjalee fields the statistical follow-ups.

---

## 3. Tripwires

Objective, checkable conditions with a deadline. If the condition is not true by its deadline, the action
is taken — it is not re-debated. Durbadal calls each tripwire; the check happens at the standup or break
nearest the deadline and the outcome is recorded in `decisions.md`.

| Tripwire | Condition that must be true | Deadline | How we check | Action if not met |
| --- | --- | --- | --- | --- |
| TW-1 | Every teammate has RStudio open, `scripts/smoke_test.R` passing, and the scaffold app launching | **11:15 Wed** (in W1) | Each person says "pass" out loud on their own machine | Durbadal escalates to the organisers; anyone still blocked moves to local-laptop RStudio, which is an accepted fallback; T-03 pairing continues |
| TW-2 | Rashid's GitHub handle is collected and he has pushed a trivial commit (T-02) | **12:00 Wed** (end of W1) | `git log` on `main` shows one commit per person | Durbadal logs it as a blocker and escalates repo access; until write access works, Sharon pushes Rashid's branches so no work sits unpushed |
| TW-3 | `tests/reference/` is committed for all three real examples (G-01) | **5:00 pm Wed** (W3 standup) | The directory exists on `main` with AIC table, five diagnostics and verdict per dataset | Geethanjalee finishes G-01 before starting anything in T1; B-04 verification slips to T1 and Durbadal records the new order |
| TW-4 | The app shows a real Kaplan–Meier plot from a real dataset | **5:00 pm Wed** (W3 standup) | Anyone other than the author launches the app and sees the plot | Geethanjalee joins Pod A for Thursday morning and Pod B verification slips a block |
| TW-5 | The Diagnostics tab renders all five cards, including the "cannot be computed" state | **12:00 Thu** (end of T2) | Run one real dataset and simulation scenario C; both render without a blank cell or crash | Drop the report download (A-09) to a stretch goal and protect the Verdict tab instead |
| TW-6 | All eight Definition of Done items are met | **5:00 pm Thu** (T4 standup, at the feature freeze) | Read the Definition of Done aloud item by item; each is yes or no, no partial credit | Friday F2 and F3 shrink, the `S-` stretch goals are abandoned outright, and the lead decides what to cut — **never cut the two demo dry runs** |

---

## 4. What we will not do under time pressure

These stay forbidden even if we are behind, and there is no deadline that makes them acceptable.

- **No hardcoded results.** Nothing is typed into the UI, the report or the slides to make a demo look
  finished. If a value is not computed live from the package, it does not appear.
- **No number the package did not produce.** Every figure on screen or in the HTML report comes from a
  `cureAssess` call in that session. If it cannot be reproduced against the oracle, it comes out of the UI
  rather than going in front of a judge.
- **No non-public data in the repo, ever.** Public and simulated data only — nothing restricted, nothing
  identifiable, nothing from St. Jude clinical datasets, not even briefly, not even in a branch, and
  nothing identifiable on screen during the demo.
- **The two timed dry runs (D-07) are not skipped.** They happen on the actual demo machine with the
  actual app. If Friday is tight, F2 and F4 shrink first; the rehearsals are the last thing to give.
- **No features after the Thursday 17:00 feature freeze** without Durbadal's written approval recorded in
  `project-management/decisions.md`. A verbal "go ahead" is not approval, and Sharon does not merge
  anything that lacks the written entry.
