# Demo Plan — cureAssessApp (KIDS26 Team 9)

St. Jude BioHackathon 2026, Friday 18 September 2026.

**Status note.** The app does not exist yet. This document is the plan we build toward and rehearse
in block **F3 (Fri 1:00–2:00)**. Every number quoted here comes from the verified reference oracle
(task **G-01**) and is what the app must reproduce; if the app ever prints something different, that
is a blocking bug (risk **R5**), not a slide edit.

---

## 1. The two demos

Two separate deliverables, two different shapes. Do not try to use one script for both.

| | Lightning talk | Booth walkthrough |
| --- | --- | --- |
| Session | Demo Lightning Session | Demos / Judging Reception |
| Time | **3:00–4:00 pm** | **4:00–6:00 pm** |
| Room | **MTC Room 2 (IA 1405)** | **MTC Atrium** |
| Length | **3 minutes** | **5 minutes**, repeated many times |
| Format | ~5 slides, one live moment | Live app, one narrator, one driver |
| Task ID | **D-05** (deck) | **D-06** (script) |
| Rehearsal | **D-07** — two timed dry runs | **D-07** — two timed dry runs |

### Roles

**Lightning pitch (3 min, MTC Room 2 IA 1405)**

- **Durbadal** presents.
- **Sharon** drives the app.
- **D-05** (the deck) is owned by Durbadal, with content supplied by the team.
- Any other role in this session is not assigned in the plan — **[to confirm]** at the Friday 9:30 am standup.

**Booth (MTC Atrium, 4:00–6:00 pm, rotating every 30 minutes so nobody is stuck for the whole two hours)**

| Person | Booth role |
| --- | --- |
| Rachael | Narrates the 5-minute walkthrough; owns **D-06**, the booth script |
| Sharon | Drives the app |
| Geethanjalee | Fields statistical questions |
| Rashid | Owns the backup laptop and the screenshot/GIF fallback |
| Durbadal | Floats and closes |

**6:00 pm** — winners announced and closing remarks, MTC Atrium. Nobody leaves before this.

### Division of labour between the two

The lightning talk sells the **problem**. The booth proves the **tool**. The lightning talk has one
live moment (the `gbsg` contradiction) and no time for anything else. The booth has room for the
happy path first, then the contradiction, then the disagreement among diagnostics, then the report.

---

## 2. The story we tell

The same four beats drive the deck and the booth. If a question pulls you off script, return to the
beat you were on.

**Beat 1 — Cure models are the right tool when some patients never relapse, and modern therapy makes
that common.**
Ordinary survival analysis assumes everyone eventually has the event. That is no longer true. A
mixture cure model splits the population: `S(t) = (1 − p) + p · Su(t)`, where `(1 − p)` is the cure
fraction and `Su(t)` is survival among the uncured. On a Kaplan–Meier curve a cure fraction looks
like a plateau that flattens out above zero. In mortality endpoints, read "cure" as long-term
survivorship — the hazard becoming negligible — not literal immunity.

**Beat 2 — But cure models need two extra assumptions, and getting it wrong biases your results in a
direction you cannot predict.**
The two assumptions: (1) a genuinely non-zero cured fraction exists, and (2) follow-up is long enough
to *identify* it (formally `τ_F0 ≤ τ_G`). If (2) fails, a late censored patient could be cured or
uncured-and-not-yet-relapsed, and the two are observationally indistinguishable. Othus et al.
re-analysed six SWOG trials at two follow-up times and found cure-model estimates of mean survival
shifted materially — **and the direction of the shift was not predictable.** So you cannot correct
for it afterwards. And a plateau on its own is not proof: heavy censoring alone manufactures one.

**Beat 3 — Checking those assumptions today means writing R and reading the methods literature.**
The checks exist and are published — Maller & Zhou (1992, 1994), Shen (2000), Selukar & Othus (2023).
They are implemented in the `cureAssess` R package by the author standing at this booth. But using
them means knowing which tests exist, which distribution to pass to them, how to read a statistic
against its threshold, and what to do when two of them disagree. That gate keeps the method away from
the clinicians and analysts who actually need the answer.

**Beat 4 — So we built the check into a tool anyone can use. Here it is.**
A guided Shiny front end that walks a non-statistician from "here is my dataset" to a plain-language
verdict and a downloadable HTML report, operationalising Figure 1 of the tutorial manuscript
(*A Tutorial for Evaluating Cure Model Appropriateness*; Mudunkotuwa, Ghosh, Triplett, Selukar,
in preparation): **① Expert judgment → ② Visual assessment → ③ Quantitative assessment.** Step ① stays
with the user, because it is a conversation with a clinician, not something software can decide.

---

## 3. Lightning talk — slide by slide

Five slides, 3:00 total. **Owner: D-05, Durbadal.** Sharon drives the app for slide 4.

Speaker discipline: read the clock at the end of slides 2 and 4. If you are over at slide 4, cut the
detail on slide 3, never the live moment.

| Slide | Budget | Running |
| --- | --- | --- |
| 1. Some patients never relapse | 0:25 | 0:25 |
| 2. Cure models need two assumptions you cannot see | 0:35 | 1:00 |
| 3. Checking them means writing R | 0:30 | 1:30 |
| 4. **Live: the gbsg moment** | 1:00 | 2:30 |
| 5. What we are asking for | 0:30 | 3:00 |

### Slide 1 — "Some patients never relapse. Standard survival analysis assumes they will."

**On the slide:** one Kaplan–Meier curve with a plateau above zero, annotated "cure fraction"; the
mixture formula `S(t) = (1 − p) + p · Su(t)` in small type.

**Say:** "Standard survival analysis assumes every patient eventually has the event. Modern therapy
broke that assumption — some patients are effectively cured. A cure model handles that by splitting
the population into a cured fraction and an uncured fraction. On a KM curve, that is a plateau that
flattens out above zero."

### Slide 2 — "Cure models carry two extra assumptions. Getting them wrong biases you unpredictably."

**On the slide:** the two assumptions as two lines — (1) a real cured fraction exists, (2) follow-up
is long enough to identify it. Underneath, one line: *Othus et al., six SWOG trials, two follow-up
times: estimates shifted materially and the direction was not predictable.*

**Say:** "Two extra assumptions come with the model. There has to be a real cured fraction, and
follow-up has to be long enough to see it. If follow-up is too short, a patient censored late could
be cured, or uncured and not yet relapsed — you cannot tell those apart. When Othus and colleagues
re-analysed six SWOG trials at two different follow-up times, the cure-model estimates moved, and the
direction of the move was not predictable. You cannot fix this after the fact."

### Slide 3 — "The checks are published. Using them means writing R."

**On the slide:** the three-step Figure 1 workflow (Expert judgment → Visual assessment →
Quantitative assessment); the four citations (Maller & Zhou 1992, 1994; Shen 2000; Selukar & Othus
2023); a small code block representing the current workflow.

**Say:** "The checks exist. They are published and they are implemented in the `cureAssess` package,
written by Geethanjalee, who is on this team. But to use them you have to know which tests exist,
which distribution to hand them, and how to read the output. That is a real barrier for the people
who need the answer."

### Slide 4 — Live: "AIC says fit a cure model. The diagnostics say you cannot."

This is the live moment. Sharon drives; the app is already open on the `gbsg` dataset with the run
complete, so there is no waiting.

**On the slide / screen:** the app on `gbsg` — the AIC table with `loglogistic_cure` at the top
(AIC 1719.70), next to the verdict panel showing **π̂ = 0.3238, r̂ = 0.3080**, verdict
**"Follow-up insufficient for cure modeling"**.

**Say:** "This is a public breast-cancer dataset, 686 patients. AIC ranks a *cure* model best. A
naive analyst stops here and fits one. But the RECeUS diagnostic says r̂ is 0.31 — about 31 percent
of uncured patients are still censored at the end of follow-up. The cure fraction cannot be estimated
reliably from this data. **A better AIC fit is not evidence that a cure model is identifiable.** Our
app says that, in those words, without anyone writing a line of R."

### Slide 5 — "What we are asking for."

**On the slide:** three next-step bullets and the repo name.

**Say:** "It runs locally today. Next: hosting it so anyone on campus can point a browser at it,
extending it to compare treatment arms, and using it as a teaching tool for the appropriateness
question. Come to the booth in the Atrium and bring a dataset — we want to know what breaks."

---

## 4. The demo script — 5 minutes

**Owner: D-06, Rachael.** Rachael narrates, Sharon drives. Run it in this exact order — the happy
path has to land before the contradiction means anything.

Before each run, reset the app to the Data tab with no dataset loaded. A full
`cure.appropriateness()` run takes 0.1–0.2 s, so nothing here should involve waiting.

### 0:00–1:00 — The happy path

1. **(0:00)** Load the built-in example **"nwtco — High risk"** (stage 3–4 Wilms tumour, n = 1404,
   public data). Say what the dataset is in one sentence.
2. **(0:15)** Point at the Kaplan–Meier curve on the Data tab. "Look at the tail. It flattens out
   above zero and stays there. That is what a cure fraction looks like."
3. **(0:35)** Move to the Verdict tab. Read out the verdict: **"Cure model appropriate"**, with
   **π̂ = 0.7823** and **r̂ = 0.0041**. "π̂ is the estimated cure fraction — it has to clear 0.025.
   r̂ is the fraction of uncured patients still censored at the end of follow-up — it has to be under
   0.05. Here it is 0.004. Both conditions pass. The app says go ahead."
4. **(0:50)** One sentence of closure: "That is the case where a cure model is the right tool. Now
   the interesting one."

### 1:00–3:00 — The money example

5. **(1:00)** Load the built-in example **"gbsg"** (German Breast Cancer Study Group recurrence-free
   survival, n = 686, public data).
6. **(1:15)** Go to the Models tab. "AIC again prefers a **cure** model — `loglogistic_cure`, AIC
   1719.70. If all you had was model selection, you would stop here and fit a cure model. That is
   exactly what a careful, well-intentioned analyst does."
7. **(1:45)** Go to the Verdict tab. Let the verdict sit on screen for a beat before speaking:
   **"Follow-up insufficient for cure modeling"**.
8. **(2:00)** Read the numbers. "**r̂ = 0.3080.** About 31 percent of uncured patients are still
   censored at the end of follow-up. Those patients might be cured, or they might relapse next year,
   and the data cannot distinguish the two. π̂ comes back as 0.3238, but it is not a number you can
   trust, because there is no way to identify it from this follow-up."
9. **(2:30)** Land the point, slowly: "**A better AIC fit is not evidence that a cure model is
   identifiable.** Those are two different questions and the literature keeps them separate. The
   whole reason this project exists is that nothing in a standard workflow stops you between those
   two screens."

### 3:00–4:00 — The diagnostics disagree, on purpose

10. **(3:00)** Stay on `gbsg`. Open the Diagnostics tab and put all five cards on screen at once.
11. **(3:15)** "Look at what these say about the same dataset. **Maller–Zhou is 0.0495** — just under
    the 0.05 threshold, so it says follow-up *is* sufficient. **`qn` is 0.0044**, **Shen is 0.3676**,
    and **RECeUS** says follow-up is insufficient. Three say no, one says yes."
12. **(3:35)** "That is not a bug and we did not hide it. These are descriptive aids, each with
    different assumptions and different failure modes — Shen exists specifically because Maller–Zhou
    inflates type-I error. They are meant to be read *together*, alongside what you know clinically
    about the disease. They are not a single decision rule. So the app shows you all five, tells you
    in plain language what each one means, and has a panel that says what to do when they disagree."
13. **(3:50)** "And it always shows you the diagnostics, even when a non-cure model wins on AIC. The
    package can skip that step automatically. We deliberately turned that off, because the skipped
    step is the one people need to see."

#### Optional variant — only if stretch goal S-1 landed

If the **follow-up truncation slider (S-1)** is built, it replaces step (c) — steps 10–13 above —
with a 45-second version. This is the single most persuasive thing the app can do in front of a judge,
so use it when it exists. If S-1 is not built, do not mention it.

- **(3:00)** Go back to **"nwtco — High risk"**, the dataset that just passed. Verdict on screen:
  **"Cure model appropriate"**.
- **(3:10)** "Watch the verdict, not the slider." Drag the follow-up slider down, restricting
  follow-up to shorter and shorter windows. Each re-run takes about 0.2 s, so it moves live.
- **(3:30)** Let the audience watch the verdict flip from **"Cure model appropriate"** to
  insufficient follow-up. Say nothing while it flips.
- **(3:40)** "Same patients. Same disease. Same biology. All we changed is how long we watched. This
  recreates Figure 2 of the tutorial manuscript. That is the entire argument for checking before you
  fit."
- Then pick up at step 14. If you use this variant, keep the `gbsg` diagnostics disagreement in your
  back pocket as the answer to "do the tests ever disagree?"

### 4:00–4:30 — Take it with you

14. **(4:00)** Click **Download report**. Open the HTML file that lands.
15. **(4:10)** Scroll it fast: dataset label, data summary, KM plot, AIC table, all five diagnostics,
    the verdict, session info, and the citations. "One file, self-contained, opens in any browser.
    This is what you put in front of a collaborator, or attach to a statistical analysis plan."

### 4:30–5:00 — Who it is for, and what is next

16. **(4:30)** "This is for the analyst or clinician who has a KM curve with a plateau and needs to
    know whether a cure model is defensible — without first reading four methods papers. The
    statistical work is Geethanjalee's package; what we built this week is the on-ramp."
17. **(4:45)** "Next: host it so anyone can use it from a browser, extend it to compare treatment
    arms, and add a simulation panel so it teaches the concept as well as answering the question.
    Everything is in the repo — what would you want it to do?"
18. **(5:00)** Stop. Hand over to Geethanjalee or Durbadal for questions and reset the app.

---

## 5. Questions judges will ask, and the answers

Short and honest. Do not oversell, and do not apologise for scope. Q1–Q6 are the six required by
**D-06** and everyone on the booth must be able to answer them cold; Q7–Q12 are the follow-ups we
expect and are Geethanjalee's and Durbadal's to field.

**Q1. What is new here? Isn't this just a wrapper around an existing R package?**
It is a front end, and we say so. The statistics are the published `cureAssess` package. What is new
is that the decision workflow — three stages, five diagnostics, the conflict-resolution guidance, and
a shareable report — is now something you can do without writing R or reading the methods papers. The
gate was never the mathematics; it was the access. We also found and specified behaviour the package
exposes but does not explain: the diagnostics return `NA` on some datasets, and the automatic mode
silently skips the step that matters most. The app makes both visible.

**Q2. Who is the user?**
An analyst or clinical researcher who has right-censored survival data, sees a plateau in the KM
curve, and has to decide whether a cure model is defensible. They know survival analysis. They do not
know the cure-model appropriateness literature. Secondary user: a statistician who knows all of this
and wants the five diagnostics and a report in one click instead of a script.

**Q3. Why not just look at the KM curve?**
Because a plateau is not proof. Heavy censoring alone manufactures a plateau — we have a simulated
scenario with a true cure fraction of zero and 45 percent dropout where the curve looks exactly like
cure, and the diagnostics correctly refuse it. Eyeballing the curve is step ② of three. It cannot
tell you whether follow-up is long enough to *identify* the cure fraction, which is step ③, and that
is the step that actually biases your estimates.

**Q4. What happens if I bring my own data?**
Upload a CSV, then map your columns: which one is time, which one is status, which level of status
means "event", and whether the time column needs converting from days to years. The app validates
the mapping before running anything and reports problems in plain language rather than a crash — event
status has to be exactly 0/1 for the underlying package, and the very common 1/2 coding is remapped in
the mapper. From there it is identical to the built-in examples. We tested that uploading the `gbsg`
CSV reproduces the built-in `gbsg` path exactly.

**Q5. Does it handle covariates, or compare treatment arms?**
No, and that is a real limitation, not an oversight. The published methods we implement assess **one
group at a time** — the manuscript is explicit about that caveat. So the app assesses one group at a
time too, and it does not pretend otherwise. If you want to assess two arms, you run it twice and
read the results side by side yourself. Side-by-side group comparison is on our stretch list (S-3),
but doing it properly is a methods question before it is a software question, and we were not going
to invent a method at a hackathon.

**Q6. Is it validated?**
Against the package, yes, deliberately and continuously. Geethanjalee produced a reference oracle by
running the package directly in R, and every number the app prints is checked against it on seven
datasets — three public real datasets and four simulated scenarios with known ground truth. A
mismatch is treated as a blocking bug. What we have *not* done, and will not claim, is clinical
validation on restricted data, or any validation of the underlying statistical methods themselves —
those are peer-reviewed upstream and cited in the app.

**Q7. What about restricted data, or PHI?**
None went anywhere near this. Public and simulated data only, by design: nothing restricted, nothing
identifiable, and no St. Jude clinical dataset is in the repo or appears on screen. The app also runs
entirely locally — `shiny::runApp()` on your own machine, no hosting, no upload to any server — so
your data never leaves the computer it is on. That was a deliberate choice for the hackathon, not a
limitation we ran into.

**Q8. Can I use it right now? Where is it hosted?**
It is local only this week: clone the repo and run it in R or RStudio. The README is written to get a
new user from clone to running app in under ten minutes. Public hosting on Posit Connect or
shinyapps.io is a documented next step (S-5), not something we shipped, and it needs a decision about
what data people would then be uploading to a server.

**Q9. Why do the diagnostics disagree, and which one should I believe?**
They disagree because they test different things under different assumptions. Maller–Zhou tests
sufficient follow-up and is known to inflate type-I error; Shen corrects exactly that; `qn` is a
different statistic with a sample-size-dependent threshold; the immune summary is descriptive, not a
test, despite its name; RECeUS estimates the cure fraction and the remaining-uncured ratio directly.
We do not tell you which to believe, because the literature does not, and a tool that fakes one
answer would be worse than the problem. We show all five, explain each in two sentences, and tell you
to read them with your clinical knowledge of the disease.

**Q10. What if the diagnostics can't be computed at all?**
That happens, and it is specified up front rather than discovered in the demo. Three of the five
statistics can only be computed when the largest observed time is censored. On a dataset where the
longest observation is an event, they come back `NA`. The app renders an explicit "cannot be
computed — the longest observed time is an event, so there is no plateau to test" state with the
reason, instead of a blank cell or an error. Two of our four simulated scenarios exist specifically
to exercise that path.

**Q11. What if the app tells me follow-up is insufficient? Am I stuck?**
No, and the app says so on screen rather than leaving you at a dead end. Your options are: fit a
non-cure model and report it as such; use the extreme-value estimators of Escobar-Bach and Van
Keilegom; use Yuen and Musta's relaxed condition; or collect more follow-up. What you should not do
is fit the cure model anyway and hope, because the bias does not have a predictable direction.

**Q12. What would you do next?**
In order: the follow-up truncation slider, which lets you watch a verdict flip in real time as you
shorten follow-up and is the clearest teaching device we have; a simulation panel with sliders for
cure fraction, follow-up length and censoring rate, which turns the app into a teaching tool; group
comparison, with the one-group-at-a-time caveat stated honestly; PDF output alongside HTML; and
hosting. The handoff document in the repo lists the known limitations next to each of these.

---

## 6. Logistics and failure plan

### Where and when

| Time | Event | Room | Who |
| --- | --- | --- | --- |
| 2:00–2:45 pm | **F4** — tag `v1.0`, handoff doc, final push (**D-08**, Sharon) | Huddle Rooms | Whole team |
| 2:30 pm | Pre-demo checklist (§7) | Huddle Rooms | Rashid + Sharon |
| **2:45 pm** | **CODE LOCK (T-09).** Laptops closed. | — | Whole team |
| 2:45–3:00 pm | Walk to MTC Room 2 | — | Whole team |
| 3:00–4:00 pm | **Demo Lightning Session** | **MTC Room 2 (IA 1405)** | Durbadal presents, Sharon drives |
| 4:00–6:00 pm | **Demos / Judging Reception** | **MTC Atrium** | Booth rotation, below |
| 6:00 pm | Winners announced, closing remarks | MTC Atrium | Whole team |

### Booth rotation

Rotate every **30 minutes** across 4:00–6:00 so nobody stands at the booth for the full two hours.
Four slots: 4:00–4:30, 4:30–5:00, 5:00–5:30, 5:30–6:00.

Invariants that must hold in every slot:

- At least one narrator and one driver at the stand at all times.
- Rashid's backup laptop is powered, unlocked and running the app for the entire two hours, whether
  or not he is at the stand.
- Geethanjalee is reachable within the Atrium in every slot — she does not have to be at the stand,
  but statistical questions get handed to her, not answered by guesswork.
- Whoever is off-rotation takes a break away from the stand. That is the point of rotating.
- Durbadal floats across all four slots and closes conversations with judges.

The person-by-slot assignment is **[to confirm]** at the Friday 9:30 am standup, once absences for
the day are known (risk **R2** — a teammate being absent for part of the event is expected).

### If the demo machine or the projector fails (risk R8)

Three layers, in order:

1. **Screenshots and a screen-capture GIF** of the full walkthrough, committed to the repo on **Friday
   morning** in block **F2 (10:50–12:00)** as task **D-04** (owner: Rashid). Stored so they open with
   no network — see the checklist in §7.
2. **A second laptop with the app already running** (owner: Rashid). Not sleeping, not at a login
   screen, not needing a fresh `runApp()` — already on the Data tab with the app live.
3. **Narrate from the numbers.** Everyone on the booth should be able to tell the `gbsg` story —
   AIC picks a cure model, r̂ = 0.3080, verdict "Follow-up insufficient for cure modeling" — from
   memory, with no screen at all. The story is the deliverable; the screen is the evidence.

### Rehearsal

**D-07: two timed dry runs, in block F3 (Fri 1:00–2:00), on the actual demo machine with the actual
app — not on a developer laptop.** This is a hard requirement and item 8 of the Definition of Done.
A run that works on the laptop it was built on has proved nothing about the machine that will be in
the room. Both the 3-minute deck and the 5-minute booth script get rehearsed twice, timed with a
visible clock, with the screenshot fallback already committed.

Both dry runs are the whole team's task. Anything that surfaces in a dry run and is not a one-line
fix does not get fixed — it gets cut from the script. F4 starts at 2:00 regardless.

---

## 7. Pre-demo checklist

Run this at **2:30 pm Friday**, on the actual demo machine, before code lock at 2:45. Owners:
Rashid and Sharon. If any box cannot be ticked, say so out loud immediately — Durbadal makes the call
on whether to fall back to screenshots.

- [ ] Fresh `git clone` of `main` at tag `v1.0`, and `shiny::runApp("app")` launches from it with no
      errors and no console warnings on screen.
- [ ] All three built-in examples load and run end to end: **"nwtco — High risk"**, **gbsg**,
      **colon (Lev+5FU, recurrence)**.
- [ ] Spot-check against the oracle on screen: nwtco high-risk shows **π̂ = 0.7823** and
      **r̂ = 0.0041**; gbsg shows **π̂ = 0.3238** and **r̂ = 0.3080**.
- [ ] Report download works: click it, the HTML file lands, and it opens in the browser with the KM
      plot, AIC table, all five diagnostics and the verdict present.
- [ ] Laptop plugged in **and** charged above 80 percent; power mode set so the screen never sleeps
      and the machine never suspends mid-demo.
- [ ] Display scaling and font size set so the verdict text and the AIC table are readable from
      **three metres** — check this by standing three metres away, not by assuming.
- [ ] Browser zoom set to the level used in the dry runs, and the app window sized so no tab needs
      horizontal scrolling.
- [ ] All notifications silenced: system Do Not Disturb on, chat and mail clients quit, calendar
      alerts off, screen-share and meeting apps quit.
- [ ] Screenshots and the screen-capture GIF (**D-04**) open from local disk with the network
      switched off. Test with the network actually off.
- [ ] Lightning deck open, full-screen-ready, on slide 1.
- [ ] Backup laptop on, unlocked, app running on the Data tab, in Rashid's hands.
- [ ] App reset to the Data tab with no dataset loaded, ready for the first walkthrough.
