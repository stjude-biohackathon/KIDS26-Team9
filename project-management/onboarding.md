# Day-1 Onboarding Runbook — W1, Wednesday 10:30–12:00

KIDS26 Team 9 · St. Jude BioHackathon 2026 · project **cureAssessApp**

W1 is **onboarding only. No feature work.** The goal of this block is that all five people end it with
a working environment, write access to the repo, and enough shared vocabulary to start building at
1:00 pm. If you finish the checklist early, help whoever has not.

---

## 1. What you are building, in 60 seconds

`cureAssess` is a published, peer-review-backed R package that answers one question: *is a cure model
appropriate for this survival dataset?* Today, using it means writing R and knowing the cure-model
literature, which keeps the method away from the clinicians and analysts who need it. We are building
**cureAssessApp** — a guided, point-and-click Shiny front end that walks a non-statistician from
"here is my dataset" to a plain-language verdict plus a downloadable HTML report. It runs **locally**
via `shiny::runApp()` on the hackathon VM or in RStudio; there is no public hosting, and only public or
simulated data ever enters this repo. **The app does not exist yet** — everything below is setup, and
the first line of app code is written in W2.

The app is five tabs:

| Tab | What it does |
| --- | --- |
| **Data** | Pick a built-in example or upload a CSV, map the time and status columns, see a summary card and a Kaplan–Meier plot. |
| **Models** | Fit cure and non-cure parametric models, rank them by AIC, show which one won. |
| **Diagnostics** | Five diagnostic cards — Maller–Zhou (1994), `qn`, Shen (2000), Immune summary, RECeUS — each with its statistic, threshold and interpretation. |
| **Verdict** | The three-step check from the tutorial manuscript's Figure 1, plus the plain-language recommendation and a download button for the report. |
| **About** | References, how to cite the package, limitations. |

---

## 2. The 90-minute checklist

Work top to bottom. Minute budgets are guidance, not a contract — but if you are more than 10 minutes
behind on any row, say so out loud rather than silently grinding.

| Clock | Min | Task | Done looks like |
| --- | --- | --- | --- |
| 10:30–10:35 | 5 | — | Everyone has this runbook open and knows which pod they are in. |
| 10:35–10:45 | 10 | **T-01** | VM reached, RStudio opens, `R.version.string` prints 4.6.1. |
| 10:45–10:55 | 10 | **T-02** | Repo cloned; you can see `cureAssess/` and `project-management/` locally. |
| 10:55–11:00 | 5 | **T-04** | The event's AI coding agents open and respond in your editor. |
| 11:00–11:20 | 20 | **T-03** | All 11 packages load, `cureAssess` 0.1.0 installs, smoke test passes, scaffold app opens. |
| 11:20–11:40 | 20 | **T-05** | **Package walkthrough led by Geethanjalee** — what a cure model is, what `cureAssess` does, what the app must reproduce. Listen; do not install things during this. |
| 11:40–11:55 | 15 | **T-06** | **Roles and conventions confirmation led by Durbadal** — pods, comms channel, branch + PR convention, block-end push rule, Definition of Done. Rashid's GitHub handle collected. |
| 11:55–12:00 | 5 | **T-02** (finish) | Your `team.md` commit is pushed and the PR is open. Buffer for whoever is still stuck. |

Total: 90 minutes. T-01, T-02 and T-04 are all access checks and are deliberately front-loaded so that
failures surface before the **11:15 escalation deadline** (see below).

---

## 3. Step 1: accounts and access

Three things must work. Check them in this order, because each one can fail independently.

**VM and RStudio (T-01).** Sign in to the hackathon VM and open RStudio. In the console:

```r
R.version.string   # expect "R version 4.6.1 ..."
getwd()
```

**GitHub repo access (T-02).** You need **write** access to `stjude-biohackathon/KIDS26-Team9`
(branch `main`). Reading is not enough — we prove write access in Step 5 by each person pushing one
trivial commit. If you are not yet a collaborator, tell Durbadal; he adds you or escalates.

**The event's AI coding agents (T-04).** Confirm the AI coding agents provided at the event
(for example Copilot) actually open and respond in your editor, before you need them under time pressure.
Read `docs/ai-guidance.md` first — it is short and it is the team's policy, not a suggestion. The two
rules that matter here: **every suggestion gets human review before it runs**, and **never paste
credentials, private data, or anything identifiable into an agent**. Agent output is a draft, never a
validated result, and never a citable source for a statistical claim — that is Geethanjalee's call.

### If access fails

| Failure | Do this |
| --- | --- |
| VM will not load, or RStudio will not open | Tell Durbadal immediately. Working in **local RStudio on your own laptop is an accepted fallback** — you need R >= 4.1 and the packages in Step 2. Do not spend 40 minutes fighting the VM. |
| You cannot clone, or `git push` is rejected | Check you are signed in to the GitHub account that was given access. See `docs/troubleshooting.md` — note that GitHub no longer accepts account passwords for Git over HTTPS. |
| A package will not install | Post the **exact command and the full error text** in the team channel. Sharon is the backup on T-03. |
| The AI agents will not authenticate | Not a blocker. Note it, move on, continue with the checklist; every task in the plan is doable without them. |

**Escalation deadline: 11:15 Wednesday.** If VM, RStudio, GitHub write access or the package install is
still broken at 11:15, stop troubleshooting alone and hand it to Durbadal, who escalates to the
organisers. Losing Day 1 to an install problem is the single biggest scheduled risk on the register
(R1) and the mitigation only works if you escalate on time instead of being polite about it.

---

## 4. Step 2: R environment

R **>= 4.1** is required by the package. The hackathon VM has **4.6.1**, which is fine.

Copy-paste this whole block into the R console:

```r
# --- cureAssessApp environment setup -----------------------------------------
R.version.string   # must be 4.1.0 or newer; the hackathon VM has 4.6.1

pkgs <- c(
  # cureAssess package dependencies
  "survival", "flexsurv", "flexsurvcure", "survminer", "ggplot2", "dplyr",
  # app dependencies
  "shiny", "bslib", "DT", "rmarkdown", "knitr"
)

missing <- setdiff(pkgs, rownames(installed.packages()))
if (length(missing)) install.packages(missing)

# Load everything once, so a broken install fails here and not mid-demo
invisible(lapply(pkgs, library, character.only = TRUE))

sessionInfo()
# -----------------------------------------------------------------------------
```

Notes:

- **`flexsurv` and `flexsurvcure` are the slow ones.** They compile. Start this block and then read
  Section 8 of this document while it runs, rather than watching the log.
- The reference numbers we must reproduce were produced with `flexsurv` 2.3.2 and `flexsurvcure` 1.3.3.
  If your versions differ, it is not automatically a problem — but say so, because a number that
  disagrees with the oracle is a **blocking** bug and we need to know whether versions explain it.
- **`shinycssloaders` is optional** — loading spinners only. Skip it in W1; install it later if the app
  actually needs one: `install.packages("shinycssloaders")`.
- Nothing else gets installed without a word in the team channel. Surprise dependencies break the
  clean-clone test (B-09 / B-11) on Thursday and Friday.

---

## 5. Step 3: install the vendored `cureAssess` package

The package is **vendored into this repo** at `cureAssess/` — you do not need to clone it separately, and
you do not need GitHub access to the upstream repository. It is MIT licensed, version 0.1.0, authored by
Geethanjalee Mudunkotuwa and Durbadal Ghosh.

Run these from the repo root. Pick **one** of the two options.

**Option A — prebuilt tarball (recommended for W1).** Installs it like any other package. Do this if you
just want the app to work.

```r
install.packages("cureAssess/cureAssess_0.1.0.tar.gz", repos = NULL, type = "source")

library(cureAssess)
packageVersion("cureAssess")   # expect '0.1.0'
```

**Option B — load from source (for development).** Use this if you are reading or stepping through
package code rather than only calling it.

```r
# devtools is not in the dependency list above; install it if you want this route
# install.packages("devtools")
devtools::load_all("cureAssess")
```

`load_all()` does **not** install anything — it loads the source into your current session only, so you
must re-run it in every new session. Do not mix Option A and Option B in the same session; if you have
both, you will not be able to tell which code is running, which is exactly the situation you do not want
when a number disagrees with the oracle.

---

## 6. Step 4: prove it works

Two commands. Both from the repo root.

```r
source("scripts/smoke_test.R")
```

Then:

```r
shiny::runApp("app-scaffold")
```

**What correct output looks like.** The smoke test prints the `nwtco` **High risk** (stage 3–4) result
and finishes with the verdict **`Cure model appropriate`**. The numbers it prints are the verified
reference values:

| Quantity | Expected |
| --- | --- |
| n | 1404 |
| AIC best model | `loglogistic_cure` (AIC 1928.38) |
| π̂ (cure fraction) | 0.7823 |
| r̂ | 0.0041 |
| Verdict | **Cure model appropriate** |

**It should be fast.** A full `cure.appropriateness()` run takes **0.1–0.2 s** — well under a second. If
the smoke test appears to hang for minutes, that is a signal, not patience: stop it and report it.

`shiny::runApp("app-scaffold")` should open a page in your browser with **no errors in the R console**.
The scaffold is a go/no-go check that Shiny itself renders on your machine — it is **not** the product.
The real app will live in `app/` and is built starting in W2 (A-01).

If `scripts/smoke_test.R` or `app-scaffold/` is not in your clone, run `git pull` on `main` first, then
flag it to Durbadal rather than writing your own version.

**If the smoke test passes and the scaffold opens, your environment is good.** You are done with setup —
close the terminal tabs, and go and start your first task. Do not keep tuning your setup.

---

## 7. Step 5: your first commit

This is the second half of **T-02**. The point is not the content of the change; it is to prove you have
write access *before* you have work you care about losing.

**Branch convention:** `<initials>/<task-id>-<short-slug>` — for example `sf/A-01-app-skeleton`.
**One PR per task.** PR title starts with the task ID. A teammate skims it before merge. **Sharon merges
to `main`.** Never push to `main` directly.

```bash
git clone https://github.com/stjude-biohackathon/KIDS26-Team9.git
cd KIDS26-Team9

git switch -c <initials>/T-02-add-<firstname>-to-team

# Now edit project-management/team.md and add your row:
#   name, GitHub handle, pod, primary role, backup

git add project-management/team.md
git commit -m "T-02 add <Your Name> to team.md"
git push -u origin <initials>/T-02-add-<firstname>-to-team
```

Then open the PR — either in the GitHub web UI, or:

```bash
gh pr create \
  --title "T-02 add <Your Name> to team.md" \
  --body "Proves write access. Adds my row to team.md."
```

**Done looks like:** your branch is on GitHub, the PR is open, and your name is in the diff.

Two conventions to internalise now, because they carry the whole plan:

- **Push at the end of every block.** Unpushed work does not exist. We have a hard requirement that any
  teammate can pick up any task if someone is absent, and that only holds if the work is on GitHub.
- **Blockers go in a GitHub issue immediately** — not at the next standup. Standups are Wed 4:45 pm,
  Thu 9:30 am, Thu 4:45 pm, Fri 9:30 am.

---

## 8. The five minutes of cure-model background you actually need

You do not need to read the literature to do your tasks. You do need this much.

**Ordinary survival analysis assumes everyone eventually has the event.** Fit a standard survival model
and it will quietly insist that if you waited long enough, every patient relapses. Modern therapy broke
that assumption: some patients are effectively **cured** and never relapse.

**A cure model splits the population in two** — a cured group and an uncured group — and models them
separately: `S(t) = (1 − p) + p · Su(t)`, where `(1 − p)` is the **cure fraction** (the long-term
survivors) and `Su(t)` is survival among the uncured. In mortality endpoints, read "cure" as
*long-term survivorship* — the hazard becoming negligible — not literal immunity to death.

**On a Kaplan–Meier curve, a cure fraction looks like a plateau that flattens out above zero.** The curve
drops as the uncured have events, then goes flat because nobody left is going to have one.

**But a plateau can be manufactured.** If enough patients drop out or the study simply stops early, the
KM curve also goes flat — not because anyone was cured, but because you ran out of data. Those two
pictures look the same on screen. **That is the entire reason this tool exists.** Worse, you cannot fix
it after the fact: re-analyses at different follow-up times have shown cure-model estimates shift
materially, and the direction of the shift is not predictable.

**So the diagnostics check two separate things:**

1. **Is there really a cured group?** — is the cure fraction meaningfully above zero?
2. **Did we follow people long enough to tell?** — is follow-up long enough that a flat tail means
   "cured" rather than "not observed yet"?

Both must pass. A dataset can fail on either one, and failing either means a cure model is inappropriate
for it. There is also a step the software cannot do: **is cure biologically plausible here at all?** That
is a conversation with a clinician, which is why the Verdict tab must present it as a step the *user*
confirms, not something the app decides.

One consequence you will meet in the code: the diagnostics **can disagree with each other**, and the
model that wins on AIC **can be a cure model even when follow-up is insufficient**. Neither is a bug.
They are descriptive aids to be read together, not a single decision rule, and the app has to say so
on screen.

For the longer version, see `docs/cure-models-101.md`. For anything beyond it, ask Geethanjalee — she
wrote the package.

---

## 9. Where things live

| Path | What it is | When you need it |
| --- | --- | --- |
| `project-management/onboarding.md` | This runbook | W1, and again whenever you rebuild your environment |
| `project-management/team.md` | Roster, pods, roles, backups | W1 (you edit it in Step 5); whenever you need to know who backs up a task |
| `project-management/project-plan.md` | Schedule, blocks W1–W3 / T1–T4 / F1–F4, task backlog | Start of every block |
| `project-management/decisions.md` | Decisions that change the approach — date, decision, why | When you change an approach, and when you wonder why something is the way it is *(created during the event)* |
| `docs/ai-guidance.md` | Policy for the event's AI coding agents | Before your first agent prompt (T-04) |
| `docs/git-github-basics.md` | Clone, branch, PR mechanics | Step 5, and any time Git confuses you |
| `docs/troubleshooting.md` | Access, clone, auth and missing-tool failures | Step 1, when something will not connect |
| `docs/cure-models-101.md` | The long version of Section 8 | After W1, when you want the background you skipped *[to confirm — no numbered task produces this; ask Durbadal if it is missing from your clone]* |
| `docs/data-contract.md` | Required columns, event coding, time units, every error the package can raise on input | Before you touch data input or the column mapper *(written in W2, B-01)* |
| `docs/user-guide.md` | Guided walkthrough for an end user | F2 onward *(written in F2, D-02)* |
| `cureAssess/` | The vendored package, version 0.1.0 | Step 3; and whenever you need to know exactly what a function does |
| `cureAssess/R/` | Package source | When the docs are not specific enough — this is the authority on behaviour |
| `scripts/smoke_test.R` | Environment go/no-go | Step 4, and after any environment change |
| `app-scaffold/` | Throwaway Shiny app that proves Shiny renders | Step 4 only |
| `app/` | The actual app | From W2 onward *(does not exist yet — A-01 creates it)* |
| `data/examples/` | The three built-in example datasets, with provenance and licence | From W2 onward *(B-02)* |
| `tests/reference/` | The reference oracle — the numbers the app must reproduce exactly | Whenever the app prints a number and you need to know if it is right *(W2, G-01)* |

Two standing rules about this repo: **never commit** data that is not public, credentials, or anything
identifiable — public and simulated data only. And nothing from a restricted or clinical dataset goes
into the repo or appears on screen during the demo.

---

## 10. Who to ask

Route the question to the right person and you get an answer in two minutes instead of twenty.

| Ask | About |
| --- | --- |
| **Geethanjalee Mudunkotuwa** (`@GeethanjaleeM`) | **First point of contact for both pods, and first stop for anything statistical or package-related.** What a statistic means, whether a number is right, what a diagnostic implies, why the package behaved that way, any wording that interprets a result. She wrote `cureAssess`, so she is the authority on its behaviour. About half her time is deliberately reserved for answering questions — use it. |
| **Sharon Freshour** (`@sharonfreshour`) | App architecture, module boundaries, Shiny structure, and **all merges into `main`**. Ask before you restructure something another module depends on. |
| **Rachael Oluwakamiye Abolade** (`@Oluwakamiyeabolade`) | Data — the example datasets, the data contract, the simulation scenarios — and verification. If the app's number disagrees with the oracle, she is the one who found it and the one who confirms the fix. |
| **Durbadal Ghosh** (`@Durbadal0`) | **Team lead.** Scope, priorities, and anything blocking. Access escalations. Whether something counts as a new feature after the Thursday 5:00 pm freeze. Also the overflow when Geethanjalee is busy. |
| **Rashid Mehmood** *(handle TBD — collected in T-06)* | Diagnostics and Verdict tab internals, report download, in-app help wiring. |

**Ask early.** The two failure modes that actually cost us time are someone quietly stuck for an hour,
and someone guessing at a statistical judgement call instead of asking the expert. Neither is
resourcefulness.

**Put the blocker in a GitHub issue the moment you are stuck — not at the next standup.** Standups are
for confirming what is already written down, not for discovering it. If you are blocked, the issue goes
up first, and then you say it out loud at the standup too.
