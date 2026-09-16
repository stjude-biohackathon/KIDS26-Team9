# Team Lead Checklist

Use this page to get the team moving. It is intentionally short: a three-day project needs enough structure to coordinate work, not a second project to maintain.

**This project:** **cureAssessApp** — an interactive Shiny front end for the `cureAssess` R package, built at the St. Jude BioHackathon 2026 (Wed 16 – Fri 18 September 2026) by KIDS26 Team 9. Team lead: Durbadal Ghosh (`@Durbadal0`). The app does not exist yet; everything in `project-management/` and `docs/` is a plan for building it.

## Where everything is

| Document | What it is for |
| --- | --- |
| [README.md](../README.md) | Project profile: problem, solution, inputs, expected output, stack, and how a new user gets from clone to running app. Finalised Friday in F2 (task D-01). |
| [project-management/schedule.md](schedule.md) | The block-by-block plan (W1–W3, T1–T4, F1–F4) with times, breaks as hard stops, standups, feature freeze and code lock. The authority on *when*. |
| [project-management/task-backlog.md](task-backlog.md) | Every task with its canonical ID (`T-`, `A-`, `B-`, `G-`, `D-`, `S-`), owner, backup and acceptance criteria. The authority on *what* and *who*. |
| [project-management/team.md](team.md) | Roster, pods (Pod A app / Pod B data & QA), roles, backups, and the absence-tolerance rules. |
| [project-management/project-plan.md](project-plan.md) | Goal, milestones, Definition of Done and the risk register in one place. |
| [project-management/CHECKLIST.md](CHECKLIST.md) | This file: the lead's running checklist, conventions, comms, and handoff. |
| [project-management/decisions.md](decisions.md) | Decision log. Anything that changes the approach, plus the feature-freeze call and any approved Friday feature, gets a dated entry with the reason. |
| [docs/data-contract.md](../docs/data-contract.md) | What a valid input dataset looks like: required columns, event coding, time units, missing-value policy, minimum n, and every error `.check_surv_data()` can raise. Written Wednesday in W2 (task B-01). |
| [docs/user-guide.md](../docs/user-guide.md) | Guided walkthrough for a non-statistician, using the `gbsg` teaching example. Written Friday in F2 (task D-02). |
| [docs/handoff.md](../docs/handoff.md) | Known limitations and next steps for whoever picks this up after the event. Written Friday in F4 (task D-08). |
| [docs/git-github-basics.md](../docs/git-github-basics.md) | Git and GitHub reference, including a GitHub Desktop workflow. |
| [docs/ai-guidance.md](../docs/ai-guidance.md) | Guidance on using the AI coding agents available at the event. |
| [docs/troubleshooting.md](../docs/troubleshooting.md) | Common setup and recovery steps. First stop when something will not run. |
| `cureAssess/` | The vendored `cureAssess` R package (v0.1.0, MIT, upstream `https://github.com/GeethanjaleeM/cureAssess`). Read it, do not fork the statistics into the app. |
| `tests/reference/` | The reference oracle: the numbers the app must reproduce exactly. Committed Wednesday in W2 (task G-01). |

## Start Here

1. **Access your assigned team repository.** Organizers will provide the repository and add team members. Confirm that you can open it on GitHub and clone it to your computer. Follow [Git and GitHub basics](../docs/git-github-basics.md) for the full path.
2. **Complete the project profile.** Agree on the question, inputs, expected output, tools, and team roles before pursuing a large implementation.
3. **Make a small first change.** Create a branch, update this README or document a data source, commit the change, and open a pull request. Use the terminal steps in [Git and GitHub basics](../docs/git-github-basics.md) or [GitHub Desktop](https://desktop.github.com/) if you prefer a graphical interface.
4. **Ask for help early.** Record blockers in an issue, raise them at a check-in, or ask a mentor. See [troubleshooting](../docs/troubleshooting.md) for common recovery steps.

## The Team

- **Members and roles:** Record these in [team.md](team.md). Five people: Durbadal (lead, no assigned build tasks), Geethanjalee (science lead, first point of contact for both pods), Sharon (App Lead, owns merges to `main`), Rashid (App Dev), Rachael (Data/QA Lead).
- **Ways of working:** Branch, review, push and standup rules are in [Conventions for this project](#conventions-for-this-project) below; the timing is in [schedule.md](schedule.md).
- **Current plan:** Goal, milestones, Definition of Done and risks are in [project-plan.md](project-plan.md); the task-by-task detail is in [task-backlog.md](task-backlog.md).

## Project Structure

Use the folders that fit your project. You do not need to fill every folder. This is the layout this project actually uses.

```text
app/                The Shiny app. app/R/mod_*.R, one Shiny module per file, one owner per file
cureAssess/         Vendored cureAssess R package (v0.1.0, MIT); read it, do not re-implement it
data/examples/      The three public example datasets as CSV, with README.md giving provenance and licence
docs/               Data contract, user guide, handoff notes, plus the event's Git and troubleshooting guides
project-management/ Schedule, task backlog, team and roles, project plan, decisions log, this checklist
report/             report.Rmd, the parameterised HTML report the app renders and downloads
scripts/            smoke_test.R and other standalone helper scripts
tests/reference/    Reference oracle: AIC tables, diagnostics and verdicts the app must match exactly
```

## Data, meta data and secrets
**Do not commit passwords, API keys, private information, or identifiable human or clinical data. Check the source and license before sharing external data or media.**

For this project that rule has a specific consequence: **public and simulated data only.** Nothing restricted, nothing identifiable, and nothing from St. Jude clinical datasets enters this repository or appears on screen during the demo. The manuscript, the SWOG S1203 data and the St. Jude BMTCT datasets are all out of scope for this repo.

## Resources

- New to Git or GitHub or need to know how to work with git in a shared repo: read [Git and GitHub basics](../docs/git-github-basics.md).
- Using Copilot agents: read [AI assistance](../docs/ai-guidance.md).
- Stuck during setup: open [troubleshooting](../docs/troubleshooting.md).
- Collaborating on changes: see [Contributing to your team](#contributing-to-your-team) below.

## Contributing to your team
### A Simple Workflow

1. Pick a small task or write down a blocker.
2. Create a branch with a clear name, such as `add-project-profile` or `fix-data-path`.
3. Make one focused change and commit it with a short message.
4. Push the branch and open a pull request.
5. Ask another teammate to look at the change before merging.
6. Update the README or project notes when the change affects how someone uses the project.

The [Git and GitHub basics](../docs/git-github-basics.md) guide explains each step, including a GitHub Desktop workflow.

### Conventions for this project

- **Branch per task:** `<initials>/<task-id>-<short-slug>`, for example `sf/A-01-app-skeleton`.
- **One pull request per task.** The PR title starts with the task ID. A teammate skims it before merge. Sharon merges to `main`.
- **Push at the end of every block.** Unpushed work does not exist. This is what makes an absence survivable.
- **One owner per module file.** Shiny modules live in separate files under `app/R/mod_*.R` so four people are not editing one `app.R`.
- **Decisions that change the approach** go in [decisions.md](decisions.md) with the date, the decision, and why.
- **Blockers** go in a GitHub issue immediately and get said out loud at the next standup.
- **A number that disagrees with `tests/reference/` is a blocking bug**, not a cosmetic one.

### A Pull Request Is Ready When

- The change has a clear purpose.
- A teammate can understand what changed.
- You have recorded how you checked it, or explained why checking was not possible.
- Relevant assumptions, data sources, and limitations are documented.
- The change does not include credentials or sensitive data.

Small, incomplete pull requests are welcome when they make the current state visible and clearly describe what remains.


## Reproducibility and Attribution

Make work easier to inspect and reuse by keeping inputs, decisions, methods, and limitations visible. Prefer small readable steps over unexplained one-off commands. Cite data, code, models, and external resources that your project depends on. These practices help the next person understand what happened.

This repository is a reusable template. See [LICENSE.md](../LICENSE.md) for the licensing terms and update the project profile and attribution when you create a team project.

For this project, the things that must stay cited are: the `cureAssess` package and its authors (Geethanjalee Mudunkotuwa, Durbadal Ghosh), the tutorial manuscript the workflow comes from, the provenance and licence of each example dataset in `data/examples/README.md`, and the four key references shown on the About tab — Maller & Zhou (1992, 1994), Shen (2000) and Selukar & Othus (2023). The downloadable report includes session info so a reader can see exactly which package versions produced the numbers.

## Code of Conduct

In this repository, we use St. Jude's Code of Conduct document, outlining our expectations for all participants. Ask for help early, give feedback about the work rather than the person, and make room for different levels of experience.

For details, please visit: https://issuu.com/sjcrh/docs/st._jude_code_of_conduct.

Three of the five team members have no cure-model background, and that is planned for rather than apologised for: tasks are written so they can be done without reading the cure-model literature, and Geethanjalee owns anything that needs a statistical judgement call. Asking her early is the intended path, not an interruption.


## Team Leads: Before the Event

- [x] Complete the [project profile](../README.md#project-profile). — Done in [README.md](../README.md): project name, problem, solution, data decision, expected output by Fri 3:00 pm, stack, and the local-only deployment decision.
- [x] Agree on one communication channel and a short check-in rhythm. — Channel is Slack; the check-in rhythm (Wed 4:45 pm, Thu 9:30 am, Thu 4:45 pm, Fri 9:30 am, ten minutes, standing up) is fixed in [schedule.md](schedule.md) and repeated under [Communications](#communications) below. **Still open:** the specific Slack team channel is `[team channel to confirm]` — confirm it in W1 (task T-06).
- [x] Create three to six small first tasks in the project board or [project-plan.md](project-plan.md). — The full backlog is in [task-backlog.md](task-backlog.md). The W1 onboarding set is T-01 to T-06; the first build tasks are A-01, A-02, B-01, B-02 and G-01 in W2.
- [x] Use the plan and the expected output to suggest practical roles in [team.md](team.md). — Roles, pods, backups and the absence-tolerance rules are in [team.md](team.md). Pod placement for Sharon, Rashid and Rachael is a starting guess made without knowing their individual skills and can be swapped freely at the Day-1 standup.
- [ ] Collect Rashid Mehmood's GitHub handle (`[to confirm]`) and confirm write access for all five members — part of T-02 / T-06 in W1.
- [ ] Identify the mentor or support contact for the team (`[to confirm]`).


## During the Three Days

Times, breaks and block boundaries are in [schedule.md](schedule.md); task IDs, owners and acceptance criteria are in [task-backlog.md](task-backlog.md). Breaks are hard stops. Everyone pushes at the end of every block.

### Day 1 — Wednesday 16 September: onboard, then Stage 1 end to end

- **W1, 10:30–12:00 — onboarding only, no feature work.** VM and RStudio open (T-01); everyone clones and pushes one trivial commit to `team.md` to prove write access (T-02); dependencies installed and `scripts/smoke_test.R` plus the scaffold app run clean (T-03); AI agent access confirmed (T-04); Geethanjalee's 20-minute walkthrough of what a cure model is and what the app must reproduce (T-05); pods, roles, conventions, block-end push rule and the Definition of Done confirmed, and Rashid's GitHub handle collected (T-06).
- **W2, 1:00–3:00 — skeleton and foundations.** App skeleton with the five tabs Data / Models / Diagnostics / Verdict / About (A-01); Data tab v1 with the built-in dataset picker and summary card (A-02); the data contract written (B-01); the three example datasets curated to `data/examples/` with provenance and licence (B-02); the reference oracle generated and committed to `tests/reference/` (G-01).
- **W3, 3:20–5:00 — wire Stage 1 end to end.** CSV upload and column mapper with friendly error messages instead of a red Shiny crash (A-03); KM plot with risk table (A-04); `simulate_cure_data()` and the four-scenario matrix (B-03); verification pass #1 against the oracle, one GitHub issue per mismatch (B-04).
- **4:45–5:00 standup (T-07).** Everyone pushes. Durbadal records the day's decisions in [decisions.md](decisions.md).
- **Day 1 is done when:** `shiny::runApp("app")` opens with all five tabs and no console errors; a built-in dataset and an uploaded CSV both produce a data summary and a KM plot; the oracle is committed; every branch is pushed. If the VM or the install is still broken at 11:15 Wednesday, Durbadal escalates to the organisers and the team falls back to local RStudio.

### Day 2 — Thursday 17 September: build the three analysis tabs, then freeze

- **9:30 standup**, then **T1, 9:30–10:30 — Models tab.** Sortable AIC table with cure / non-cure badges, best-model callout, explicit Run button, the `error` column shown when a fit fails, and the `include_lognormal` opt-in toggle (A-05); fitted curve overlaid on the KM plot (A-06); the four simulated scenario datasets and their expected verdicts committed (B-05); Stage-1 help copy (G-02).
- **T2, 10:50–12:00 — Diagnostics tab.** Five cards — Maller–Zhou (1994), `qn`, Shen (2000), Immune summary, RECeUS — each with statistic, threshold, pass/fail chip and the package's own interpretation string, and an explanatory "cannot be computed" state when a statistic is `NA` (A-07); verification pass #2 across all seven datasets (B-06); two plain-language sentences of help per diagnostic (G-03).
- **1:00–2:00 flex hour.** Campus tours and absence cover. Nothing on the critical path is scheduled here; anyone who skips the tour starts T3 early.
- **T3, 1:00–3:00 — Verdict tab and report engine.** Three-step status strip (Expert judgment → Visual assessment → Quantitative assessment), the plain-language recommendation, and the panel that explains what to do when the diagnostics disagree (A-08); the parameterised `report/report.Rmd` (B-07); verdict copy and the "follow-up looks insufficient — what now?" guidance (G-04).
- **T4, 3:20–5:00 — integrate and regress.** Report download wired to `downloadHandler` (A-09); in-app help on every statistic and the About tab with the four key references (A-10); full regression across every tab and all seven datasets with the sign-off table committed (B-08); clean-clone test on a machine that has never run the app (B-09).
- **17:00 = FEATURE FREEZE (T-08), Durbadal's call.** Scope closes. Only bug fixes after this, and the call is logged in [decisions.md](decisions.md). **4:45–5:00 standup**, everyone pushes.
- **Day 2 is done when:** all eight Definition of Done items in [project-plan.md](project-plan.md) are met — this is the target, one full day before judging — and the feature freeze has been called and recorded. Anything still open becomes a triaged issue for Friday's bug bash, not an evening of building.

### Day 3 — Friday 18 September: fix, document, rehearse, demo

- **9:30 standup**, then **F1, 9:30–10:30 — bug bash only.** Work Thursday's issue list by severity (A-11 / B-10). No new features without Durbadal's written approval in [decisions.md](decisions.md).
- **F2, 10:50–12:00 — docs and polish.** Final README that gets a new user from clone to running app in under 10 minutes (D-01); the user guide built around the `gbsg` teaching example (D-02); in-app help and label polish (D-03); screenshots and a short screen-capture GIF, which double as the offline demo fallback (D-04); clean-clone re-test after all Friday changes (B-11).
- **F3, 1:00–2:00 — demo build.** Five-slide, three-minute lightning deck (D-05); five-minute booth script plus answers to the six questions judges will ask (D-06); **two timed dry runs on the actual demo machine with the actual app** (D-07).
- **F4, 2:00–2:45 — freeze.** Tag `v1.0`, write [docs/handoff.md](../docs/handoff.md) with known limitations and next steps, final push (D-08). **2:45 = CODE LOCK (T-09)** — laptops closed, walk to MTC Room 2 (IA 1405).
- **3:00–4:00 Demo Lightning Session** (MTC Room 2, IA 1405): Durbadal presents, Sharon drives the app. **4:00–6:00 Demos / Judging Reception** (MTC Atrium): Rachael narrates the five-minute walkthrough, Sharon drives, Geethanjalee fields statistical questions, Rashid owns the backup laptop and the screenshot fallback, Durbadal floats and closes. Rotate every 30 minutes so nobody is stuck for two hours. **6:00** winners and closing remarks.
- **Day 3 is done when:** `v1.0` is tagged and pushed, the handoff doc is written, both rehearsals have happened on the real machine, and the screenshot fallback is committed.

# Final Output and Handoff

Use this space for the material that helps someone understand the project after the event.

**These entries are filled in on Friday, in F4 (task D-08), not now.** The substance goes in [docs/handoff.md](../docs/handoff.md) and this section links to it.

- **Final demo or report:** the locally-run Shiny app (`shiny::runApp("app")` in `app/`) plus the downloadable HTML report rendered from `report/report.Rmd`. Together these are the deliverable shown at the lightning session and the booth. Link the tagged `v1.0` release here on Friday.
- **Main result:** to be written in [docs/handoff.md](../docs/handoff.md) on Friday. The intended headline is that the app takes a non-statistician from a survival dataset to a plain-language verdict on whether a cure model is appropriate, reproducing the `cureAssess` workflow exactly.
- **How to reproduce or run it:** [README.md](../README.md) — clone to running app in under 10 minutes (task D-01). Local only; no public hosting.
- **Data and source notes:** `data/examples/README.md` for the provenance and licence of each example dataset; [docs/data-contract.md](../docs/data-contract.md) for what a valid input looks like; `cureAssess/` (v0.1.0, MIT) for the package itself. Public and simulated data only.
- **Known limitations:** to be written in [docs/handoff.md](../docs/handoff.md) on Friday, from the issues that are still open at code lock plus the constraints already known — local-only deployment, one group assessed at a time, and diagnostics that cannot be computed when the longest observed time is an event.
- **Next steps:** to be written in [docs/handoff.md](../docs/handoff.md) on Friday, drawing on the stretch list in [task-backlog.md](task-backlog.md), starting with S-1, the follow-up truncation slider.

Keep generated figures and reports clearly named. Do not commit sensitive data or files that cannot be redistributed.

## Communications

Keep communication easy to find and easy to use during the three-day event.

- **Primary channel:** Slack — `[team channel to confirm]`. Confirm the channel in W1 (task T-06) and record it here and in [team.md](team.md).
- **Slack team channel:** `[team channel to confirm]`
- **Team lead:** Durbadal Ghosh, `@Durbadal0`. Scope calls, integration decisions, unblocking, the feature-freeze call.
- **First point of contact for both pods:** Geethanjalee Mudunkotuwa, `@GeethanjaleeM` — anything statistical, anything about `cureAssess` behaviour, and every word of interpretation text the app prints. Durbadal is the overflow when she is saturated.
- **Mentor or support contact:** `[to confirm]`
- **Check-in times:** Wed 4:45 pm (end of W3), Thu 9:30 am (start of T1), Thu 4:45 pm (end of T4), Fri 9:30 am (start of F1). Ten minutes, standing up. Everyone pushes at each one.
- **Slack general channel:** [Use this general channel for communication to all teams](https://stjudebiohackathon.slack.com/archives/C04JD4M3TCM)

Use `project-management/check-in.md` for short updates when useful (create the file if needed). Do not store private contact details or sensitive project information in this public repository.

## Optional Templates

Planning documents in this repository:

- [Team and roles](team.md)
- [Project plan](project-plan.md) — goal, milestones, Definition of Done, risk register
- [Schedule](schedule.md) — blocks W1–W3, T1–T4, F1–F4 with times and standups
- [Task backlog](task-backlog.md) — every task ID, owner, backup and acceptance criterion
- [Decisions log](decisions.md) — dated decisions, the feature-freeze call, any approved Friday feature
- [Team lead checklist](CHECKLIST.md) — this file
- [Data contract](../docs/data-contract.md) — written Wednesday, task B-01
- [User guide](../docs/user-guide.md) — written Friday, task D-02
- [Handoff notes](../docs/handoff.md) — written Friday, task D-08
- [Git and GitHub basics](../docs/git-github-basics.md)
- [AI assistance](../docs/ai-guidance.md)
- [Troubleshooting](../docs/troubleshooting.md)

Use only the templates that help. The repository should make progress easier, not require paperwork for its own sake.
