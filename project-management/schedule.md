# Run Sheet — KIDS26 Team 9 · cureAssessApp

St. Jude BioHackathon 2026 · Wed 16 – Fri 18 September 2026

**Total hack time: 16.5 hours.** Subtract the 1.5 h Wednesday onboarding block (W1) and roughly
**15 hours of actual build time** remain. Blocks are named **W1–W3**, **T1–T4**, **F1–F4**.

**Breaks and meals are hard stops.** Hands off keyboards, leave the room, come back. They are also
the natural push points — see the block-end push rule below.

**The Definition of Done targets Thursday 5:00 pm**, a full day before judging. That is deliberate.
Friday is for troubleshooting, documentation and rehearsal — **Friday is not a build day.**

Push at the end of every block. Unpushed work does not exist.

## Hard markers — read these before anything else

| Marker | When | What it means |
| --- | --- | --- |
| **W1 is onboarding only** | Wed 10:30–12:00 | Access, install, smoke test, package walkthrough, conventions. **No feature work of any kind**, even if you finish early. If you finish early, help someone who has not. |
| **Flex / absence hour** | Thu 1:00–2:00 | Campus tours are optional. This hour is the designated flex and absence-absorbing hour. **Nothing on the critical path may be scheduled in it.** Anyone who skips the tour starts T3 early. |
| **FEATURE FREEZE** | **Thu 17:00** | Durbadal's call (T-08). Scope closes. Bug fixes only after this point. |
| **CODE LOCK** | **Fri 2:45 pm** | T-09. Laptops closed, final push done, walk to MTC Room 2 (IA 1405). |

## At a glance

| Day | Hack hours | Blocks | Theme |
| --- | --- | --- | --- |
| **Wed 16 Sep** | 5.5 h | W1, W2, W3 | Onboarding, then app skeleton and data foundations — Stage 1 wired end to end by 5:00 pm. |
| **Thu 17 Sep** | 6.5 h | T1, T2, T3, T4 | Build out Models, Diagnostics, Verdict and the report; full regression. **Definition of Done by 5:00 pm; feature freeze at 17:00.** |
| **Fri 18 Sep** | 4.5 h | F1, F2, F3, F4 | Bug bash, docs, rehearsal, tag and lock — then demos. **No building.** |

---

## Wednesday 16 September — 5.5 h hack

| Time | Block | Location | Pod A (Sharon, Rashid) | Pod B (Rachael, Geethanjalee) | Lead (Durbadal) |
| --- | --- | --- | --- | --- | --- |
| 8:30–9:30 | Breakfast & check-in | MTC Atrium | Eat, find each other | Eat, find each other | Confirm everyone has arrived |
| 9:30–10:30 | Welcome | MTC Board Room IA 1500 | Attend | Attend | Attend |
| **10:30–12:00** | **W1 — onboarding only, NO feature work** | Huddle Rooms | **T-01** VM/RStudio opens · **T-02** GitHub access + one trivial commit each (add yourself to `team.md`) · **T-03** install deps, run `scripts/smoke_test.R` then `shiny::runApp("app-scaffold")` · **T-04** AI coding agent access · attend **T-05** | **T-01**–**T-04** same as Pod A · **T-05** Geethanjalee delivers the 20-min walkthrough: what a cure model is, what `cureAssess` does, what the app must reproduce | **T-06** confirm pods, roles, comms channel, branch + PR convention, block-end push rule, Definition of Done; **collect Rashid's GitHub handle**. Escalate any install failure to organisers **by 11:15** |
| 12:00–1:00 | Lunch | [to confirm] | Hard stop | Hard stop | Hard stop |
| **1:00–3:00** | **W2 — app skeleton + data foundations** | Huddle Rooms | **A-01** app skeleton, `bslib` navbar, five tabs Data/Models/Diagnostics/Verdict/About *(Sharon)* · **A-02** Data tab v1: dataset picker → `prepare.surv.data()` → summary card + `head()` table *(Rashid)* | **B-01** `docs/data-contract.md` *(Rachael)* · **B-02** curate the three examples to `data/examples/` as CSV + provenance/licence README *(Rachael)* · **G-01** build the reference oracle, commit `tests/reference/` *(Geethanjalee)* | Unblock; keep Geethanjalee reachable by both pods; record decisions in `decisions.md` |
| 3:00–3:20 | **PM break — hard stop** | ARC Lobby | Push work in progress | Push work in progress | Push work in progress |
| **3:20–5:00** | **W3 — wire Stage 1 end to end** | Huddle Rooms | **A-03** CSV upload + column mapper (time, status, which level means event, `none`/`days_to_years`), friendly `.check_surv_data()` errors *(Sharon)* · **A-04** KM plot with risk table on the Data tab *(Rashid)* | **B-03** implement `simulate_cure_data()` and the four-scenario matrix *(Rachael)* · **B-04** verification pass #1: Stage-1 numbers, app vs oracle, three datasets; a GitHub issue per mismatch *(Rachael)* · Geethanjalee backs B-03 and answers Pod A | Watch for Pod A starvation; re-balance pods if needed |
| **4:45–5:00** | **T-07 standup + push everything** | Huddle Rooms | Report, then push | Report, then push | Run the standup; write up decisions |
| 5:30–7:00 | Reception | ARC Lobby | Optional, **no work** | Optional, **no work** | Optional, **no work** |

> ### Wednesday exit criteria — all true before anyone leaves
> 1. **Every person** has VM access, RStudio open, a clone of `stjude-biohackathon/KIDS26-Team9`, a
>    pushed trivial commit proving write access, dependencies installed, a passing smoke test, and
>    AI-agent access (T-01 to T-04).
> 2. Rashid's GitHub handle is recorded in `team.md`; pods, roles, comms channel, branch/PR
>    convention and the Definition of Done are confirmed (T-06).
> 3. `shiny::runApp("app")` opens, all five tabs navigate, **zero console errors** (A-01).
> 4. Data tab v1 shows the summary card and `head()` table; **"nwtco — High risk" shows n = 1404** (A-02).
> 5. Uploading `gbsg.csv` through the column mapper reproduces the built-in gbsg path exactly (A-03).
> 6. KM plot with risk table renders on the Data tab (A-04).
> 7. `docs/data-contract.md` is committed (B-01); the three example CSVs plus provenance/licence
>    README are in `data/examples/` (B-02).
> 8. `tests/reference/` holds the oracle — AIC table, all five diagnostics, verdict — for all three
>    real examples (G-01).
> 9. `simulate_cure_data()` and the four-scenario matrix are committed (B-03).
> 10. Verification pass #1 is done and **every mismatch has a GitHub issue** (B-04).
> 11. The standup happened, decisions are in `decisions.md`, and **everything is pushed**.

---

## Thursday 17 September — 6.5 h hack

| Time | Block | Location | Pod A (Sharon, Rashid) | Pod B (Rachael, Geethanjalee) | Lead (Durbadal) |
| --- | --- | --- | --- | --- | --- |
| 8:30–9:30 | Breakfast & check-in | ARC Lobby | Eat | Eat | Eat |
| **9:30–9:40** | **Standup (10 min, standing)** | ARC Lobby | What landed / blocked / next | What landed / blocked / next | Run it; triage blockers into issues |
| **9:30–10:30** | **T1 — Models / AIC tab** | ARC Lobby | **A-05** Models tab: `model.fitting()` → sortable `DT` AIC table, cure/non-cure badge, best-model callout, `include_lognormal` toggle, explicit **Run** button, **`error` column shown** *(Sharon)* · **A-06** overlay the fitted survival curve for the selected model on the KM curve *(Rashid)* | **B-05** commit the four simulated scenario datasets + their expected verdicts *(Rachael)* · **G-02** Stage-1 help copy: what AIC is, and why "a cure model won on AIC" is **initial support only, not proof** *(Geethanjalee)* | Unblock; keep the freeze on the calendar in everyone's head |
| 10:30–10:50 | **AM break — hard stop** | [to confirm] | Push | Push | Push |
| **10:50–12:00** | **T2 — Diagnostics tab** | ARC Lobby | **A-07** five diagnostics cards — Maller–Zhou (1994), `qn`, Shen (2000), Immune summary, RECeUS — each with statistic, threshold, pass/fail chip and the package's own `interpretation` string; **must render an explanatory "cannot be computed" state when the statistic is `NA`** *(Rashid; Sharon backs)* | **B-06** verification pass #2: AIC tables, app vs oracle, three real + four simulated datasets *(Rachael)* · **G-03** help copy for all five diagnostics, two plain-language sentences each *(Geethanjalee)* | Review the `NA` state personally — it is the highest-likelihood UI risk |
| 12:00–1:00 | Lunch | ARC Lobby | Hard stop | Hard stop | Hard stop |
| **1:00–2:00** | **FLEX — campus tours / designated flex + absence hour. Nothing on the critical path here.** | Campus tours available / ARC Lobby | Optional tour, or start T3 early | Optional tour, or start T3 early | Use this hour to absorb slippage and cover absences |
| **1:00–3:00** | **T3 — Verdict tab + report engine** (up to 2 h) | ARC Lobby | **A-08** Verdict tab: `cure.appropriateness(run_tests = "yes")` → three-step status strip (Expert judgment → Visual assessment → Quantitative assessment), plain-language recommendation, explicit "the diagnostics can disagree — here is what to do" panel; default `"yes"` **not** `"auto"`, and say why on screen *(Sharon)* · Rashid is A-08 backup and backup owner for B-07 | **B-07** `report/report.Rmd` parameterised HTML report: dataset label, data summary, KM plot, AIC table, five diagnostics, verdict, session info, citations *(Rachael; Rashid backs)* · **G-04** verdict copy plus "follow-up looks insufficient — what now?" guidance *(Geethanjalee)* | Scope calls; decide what gets cut if T3 runs long |
| 3:00–3:20 | **PM break — hard stop** | [to confirm] | Push | Push | Push |
| **3:20–5:00** | **T4 — integration, report download, full regression** | ARC Lobby | **A-09** wire `downloadHandler` to render and download the HTML report *(Rashid)* · **A-10** in-app help: tooltip/popover on every statistic; About tab with the four key references and how to cite the package *(Sharon)* | **B-08** full regression: every tab, all seven datasets, app vs oracle; **commit the sign-off table** *(Rachael + Geethanjalee)* · **B-09** clean-clone test on a machine that has never run the app *(Geethanjalee)* | **T-08 — 17:00 FEATURE FREEZE is your call.** Sign off the Definition of Done or name what is missing |
| **4:45–5:00** | **Standup + push everything** | ARC Lobby | Report, then push | Report, then push | Run the standup; declare the freeze; log it in `decisions.md` |

> ### Thursday exit criteria — all true before anyone leaves
> 1. Models tab is live: sortable AIC table, cure/non-cure badge, best-model callout,
>    `include_lognormal` toggle, Run button, and the `error` column visible (A-05); the selected
>    model's fitted curve overlays the KM curve (A-06).
> 2. All five diagnostics cards render statistic, threshold, pass/fail chip and the package's own
>    interpretation string — **and the `NA` case shows the "cannot be computed" explanation, not a
>    blank cell or a crash** (A-07).
> 3. Verdict tab shows the three-step strip, the plain-language recommendation, and the
>    "diagnostics can disagree" panel, with `run_tests = "yes"` as the default and the reason on
>    screen (A-08).
> 4. The HTML report renders and **downloads** with KM plot, AIC table, five diagnostics, verdict
>    and session info (B-07 + A-09).
> 5. In-app help exists for **every statistic shown**; the About tab carries the references and the
>    package citation (A-10).
> 6. Help copy for Stage 1, all five diagnostics and the verdict is written and wired (G-02, G-03, G-04).
> 7. The four simulated scenario datasets and their expected verdicts are committed (B-05).
> 8. Verification pass #2 is clean or every gap has an issue (B-06); the **full-regression sign-off
>    table is committed** — every number the app prints matches the oracle for all seven datasets (B-08).
> 9. The clean-clone test passed on a machine that had never run the app (B-09).
> 10. **The feature freeze has been declared out loud at 17:00** and recorded in `decisions.md` (T-08).
> 11. Everything is pushed.

---

## Friday 18 September — 4.5 h hack, then demos

| Time | Block | Location | Pod A (Sharon, Rashid) | Pod B (Rachael, Geethanjalee) | Lead (Durbadal) |
| --- | --- | --- | --- | --- | --- |
| 8:30–9:00 | Breakfast & check-in | ARC Lobby | Eat | Eat | Eat |
| 9:00–9:30 | Announcements | ARC Lobby | Attend | Attend | Attend |
| **9:30–9:40** | **Standup (10 min, standing)** | Huddle Rooms | What landed / blocked / next | What landed / blocked / next | Run it; rank the issue list by severity |
| **9:30–10:30** | **F1 — bug bash only** | Huddle Rooms | **A-11** work the issue list by severity. **No new features without the lead's written approval in `decisions.md`** | **B-10** work the issue list by severity, same rule | Own the severity ranking; refuse new features unless you write the approval down |
| 10:30–10:50 | **AM break — hard stop** | [to confirm] | Push | Push | Push |
| **10:50–12:00** | **F2 — docs, help polish, clean-clone, screenshots** | Huddle Rooms | **D-03** in-app help / label polish pass *(Sharon + Rashid)* · **D-04** screenshots plus a short screen-capture GIF for the slides and as the offline demo fallback *(Rashid)* | **D-01** final `README.md`: what it is, install, run in under 10 minutes, screenshot *(Rachael)* · **D-02** `docs/user-guide.md` guided walkthrough with the gbsg teaching example *(Rachael; Geethanjalee backs)* · **B-11** clean-clone **re-test** after all Friday changes *(Geethanjalee)* | Read the README as a stranger would; time the clone-to-running path |
| 12:00–1:00 | Lunch | [to confirm] | Hard stop | Hard stop | Hard stop |
| **1:00–2:00** | **F3 — demo build** | Huddle Rooms | **D-07** two timed dry runs on the actual demo machine with the actual app — Sharon drives *(whole team)* · feed slide content to D-05 | **D-06** booth script: 5 minutes plus answers to the six questions judges will ask *(Rachael)* · **D-07** dry runs — Geethanjalee rehearses the statistical answers | **D-05** lightning deck: **5 slides, 3 minutes**, content from the team; present in both dry runs |
| **2:00–2:45** | **F4 — freeze** | Huddle Rooms | **D-08** tag `v1.0`; `docs/handoff.md` with known limitations and next steps; final push *(Sharon)* · Rashid confirms the backup laptop has the app running and the screenshot fallback loaded | Final read of README, user guide and handoff doc | Sign off the tag; confirm nothing is unpushed |
| **2:45** | **T-09 — CODE LOCK** | Huddle Rooms → MTC Room 2 (IA 1405) | Laptops closed | Laptops closed | Laptops closed |
| 2:45–3:00 | Walk to MTC Room 2 (IA 1405) | MTC Room 2, IA 1405 | Walk together; carry the backup laptop | Walk together | Walk together |
| 3:00–4:00 | **Demo Lightning Session** | MTC Room 2, IA 1405 | **Sharon drives the app** · Rashid holds the fallback | Rachael and Geethanjalee in the room | **Durbadal presents the 3-minute pitch** |
| 4:00–6:00 | **Demos / Judging Reception** — booth, rotate every 30 min | MTC Atrium | See booth rotation below | See booth rotation below | Floats and closes |
| 6:00 | Winners announced & closing remarks | MTC Atrium | Attend | Attend | Attend |

> ### Friday exit criteria
> **Before F4 ends (2:45 pm code lock):**
> 1. The issue list has been worked by severity; anything still open is known and written down (A-11 / B-10).
> 2. `README.md` gets a new user from clone to running app in under 10 minutes (D-01);
>    `docs/user-guide.md` walks the gbsg teaching example end to end (D-02).
> 3. Help and label polish pass is done (D-03); screenshots and the screen-capture GIF are
>    **committed** and usable if the projector or the app fails (D-04).
> 4. The clean-clone re-test passed **after** all Friday changes (B-11).
> 5. The 3-minute deck and the 5-minute booth script have each been rehearsed **twice** on the real
>    machine, within time (D-05, D-06, D-07).
> 6. `v1.0` is tagged, `docs/handoff.md` lists known limitations and next steps, and the final push
>    is done (D-08).
> 7. Backup laptop is charged, has the app already running, and has the screenshot fallback open.
>
> **Before leaving at the end of the day:** nothing is left in MTC Atrium or MTC Room 2 — laptops,
> chargers, the backup machine and any printed booth material come home with their owner.

---

## Standups

Four standups. **Ten minutes, standing up, no laptops.** Durbadal runs them; blockers raised here
must already have a GitHub issue, or they get one on the spot.

| # | When | Where | Purpose |
| --- | --- | --- | --- |
| 1 | **Wed 4:45 pm** | Huddle Rooms | T-07. First standup: confirm pod placement is working, then everyone pushes. |
| 2 | **Thu 9:30 am** | ARC Lobby | Set the day; T1 starts immediately after. |
| 3 | **Thu 4:45 pm** | ARC Lobby | The freeze standup: Definition of Done check, then everyone pushes. |
| 4 | **Fri 9:30 am** | Huddle Rooms | Rank the issue list by severity; F1 starts immediately after. |

Each person answers three questions, in this order:

1. **What landed?** — merged and pushed, not "nearly done".
2. **What is blocked?** — name the person or thing you are waiting on.
3. **What is next?** — the specific task ID you will work in the next block.

Pod placement for Sharon, Rashid and Rachael is a starting guess. **Swap freely at the Wednesday
standup** if the split is wrong, and re-balance if Pod A is starved of Geethanjalee's time.

---

## Friday demo logistics

| Time | What | Where |
| --- | --- | --- |
| **2:45** | **CODE LOCK** (T-09), laptops closed, walk out together | Huddle Rooms |
| 2:45–3:00 | Walk to MTC Room 2 (IA 1405) | MTC Room 2, IA 1405 |
| 3:00–4:00 | **Demo Lightning Session** — our slot is a 3-minute pitch, 5 slides | MTC Room 2, IA 1405 |
| 4:00–6:00 | **Demos / Judging Reception** — booth, 30-minute rotation | MTC Atrium |
| 6:00 | Winners announced & closing remarks | MTC Atrium |

### Lightning session (3 min, MTC Room 2, IA 1405)

| Role | Who |
| --- | --- |
| Presents the 3-minute pitch | **Durbadal** |
| Drives the app live | **Sharon** |
| Fallback if the live app or projector fails | **Rashid** — screenshots and screen-capture GIF from D-04, on the backup laptop |

The deck is D-05: **5 slides, 3 minutes**, rehearsed twice in F3 on the actual demo machine.

### Booth (MTC Atrium, 4:00–6:00)

Standing roles for the two hours:

| Role | Who |
| --- | --- |
| Narrates the 5-minute walkthrough (script D-06) | **Rachael** |
| Drives the app | **Sharon** |
| Fields statistical questions | **Geethanjalee** |
| Owns the backup laptop and the screenshot fallback | **Rashid** |
| Floats and closes | **Durbadal** |

**Rotate every 30 minutes so nobody is stuck at the booth for two hours.** Four slots:

| Slot | Time | On the booth | Off the floor |
| --- | --- | --- | --- |
| 1 | 4:00–4:30 | [to confirm] | [to confirm] |
| 2 | 4:30–5:00 | [to confirm] | [to confirm] |
| 3 | 5:00–5:30 | [to confirm] | [to confirm] |
| 4 | 5:30–6:00 | [to confirm] | [to confirm] |

Fill the rotation in at the **Friday 9:30 am standup**, once absences for the day are known. Two
constraints when you fill it: Rachael or Sharon is on the booth in every slot so the walkthrough can
always be given, and the backup laptop is never unattended.

### What the booth demo must land

The verified `gbsg` result is the headline, not a footnote: AIC picks a **cure** model, so a naive
analyst would stop there — but r̂ = 0.3080 means the cure fraction cannot be estimated reliably, and
the diagnostics disagree with each other (Maller–Zhou 0.0495 says follow-up is sufficient; `qn`,
Shen and RECeUS say it is not). A better AIC fit is **not** evidence that a cure model is
identifiable. If a judge reads that disagreement as a bug, Rachael reframes it as the clearest
demonstration of why the tool exists — that reframe is scripted into D-06.
