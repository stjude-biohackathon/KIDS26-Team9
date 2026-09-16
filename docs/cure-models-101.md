# Cure Models 101

**Audience:** anyone on KIDS26 Team 9 who is a competent programmer but has not thought about survival statistics in years. No prior cure-model knowledge assumed; every symbol is defined where it first appears.

**Why you need this:** we are building `cureAssessApp`, a Shiny front end for the `cureAssess` R package. The app does not exist yet; this document explains the science it will have to present correctly. You do not need to derive any of it — you need to look at a number the app printed and know whether the app is lying. Every number quoted here comes from the verified reference tables in [`project-management/qa-plan.md`](../project-management/qa-plan.md); nothing is recomputed, and facts still to be settled are marked `[to confirm]`.

---

## 1. The one-paragraph version

Standard survival analysis assumes that if you waited long enough, every patient would eventually have the event you are measuring — relapse, progression, death. For many modern cancer therapies that is false: a fraction of patients are effectively cured and never have the event. A **cure model** explicitly splits the population into a cured group and an uncured group. It is a better description of reality when a cure fraction genuinely exists *and* the study followed patients long enough to tell the cured apart from the not-yet-relapsed. When either condition fails, a cure model produces numbers that look fine and mean nothing. `cureAssess` runs a fixed set of checks that tell you whether those conditions hold; our app wraps them so that someone who cannot write R can still get the right answer.

---

## 2. Why ordinary survival analysis is not enough

Survival analysis models the time until an event. Its central object is the **survival function** `S(t)`: the probability that a patient has *not* had the event by time `t`. At `t = 0` nobody has had the event, so `S(0) = 1`, and `S(t)` decreases from there.

Ordinary survival models — exponential, Weibull, Cox, all of them — assume that decrease continues forever: `S(t) -> 0` as `t -> infinity`. In words, **wait long enough and everyone has the event.** That assumption is baked into the maths, not chosen by the analyst, and it described most diseases for most of the history of the method.

Modern therapy broke it. In many paediatric cancers and several adult regimens a substantial share of patients are effectively cured: their risk of relapse falls to essentially zero and stays there. Those patients are not "people who will relapse later" — they are people who will not relapse.

Fit an ordinary model to such data and the model is forced to push `S(t)` to zero eventually, because it has no vocabulary for "this group is done". It compensates by distorting the shape of the curve, typically by stretching the tail — which makes fitted late-time survival wrong in exactly the quantities clinicians care about: long-term survival probability, mean survival time.

---

## 3. What a cure model is

Split the population in two. Some patients are **cured** and will never have the event. The rest are **uncured** (the literature also says "susceptible") and will have the event if followed long enough.

| Symbol | Meaning |
| --- | --- |
| `p` | the proportion of the population that is **uncured** |
| `1 - p` | the proportion that is **cured** — the **cure fraction** |
| `Su(t)` | the survival function **of the uncured group only**: among uncured patients, the probability of not yet having had the event by time `t` |
| `S(t)` | the survival function of the whole population — what your data actually show you |

Because only the uncured can have the event, `Su(t)` behaves like an ordinary survival function: it starts at 1 and decays to 0.

Now take a randomly chosen patient at time `t`. There are exactly two ways they can be event-free: they are cured, with probability `1 - p`, in which case they are event-free forever; or they are uncured, with probability `p`, and happen not to have had the event yet, which has probability `Su(t)`. Add the two routes:

```
S(t) = (1 - p) + p * Su(t)
```

That is the **mixture cure model**, and it is the whole idea. Read it left to right: *total survival equals the cured fraction, which never goes away, plus the uncured fraction times however much of the uncured group is still event-free.*

The behaviour at large `t` is the point. As `t` grows, `Su(t)` heads to 0, the second term vanishes, and `S(t) -> (1 - p)`. The curve does **not** go to zero. It levels off at the cure fraction.

**What this looks like on a plot.** The **Kaplan-Meier (KM) curve** is the standard non-parametric estimate of `S(t)` — the descending staircase in every oncology paper. In a population with a cure fraction it descends while the uncured are having events, then **flattens into a plateau above zero** once the uncured are used up. The height of the plateau is the cure fraction, `1 - p`. That plateau is the visual signature of cure, and it is why the Data tab will show the KM curve (task **A-04**).

---

## 4. The catch: two extra assumptions

A cure model buys you the plateau and charges two assumptions for it.

**(a) A genuinely non-zero cured group exists.** If the true cure fraction is zero, the model is estimating a parameter that does not exist. It will still return a number, because optimisers always return a number.

**(b) Follow-up is long enough to identify the cured group.** This is the one that gets violated in practice, and it is what most of the `cureAssess` diagnostics are about.

**In words first.** Imagine the uncured patients. There is some point in time by which every uncured patient would have had their event — the moment the uncured group is exhausted. Sufficient follow-up means **the study kept observing patients past that moment.** Only then can you say "the people still event-free at the end are the cured ones", because everyone who was going to have an event already had it.

**Formally:** `tau_F0 <= tau_G`.

| Symbol | Meaning |
| --- | --- |
| `F0` | the event-time distribution **among the uncured** |
| `tau_F0` | the last time at which the uncured can still have events — the time by which all susceptible patients would have had the event |
| `G` | the censoring distribution: how long patients are observed before the study stops watching them |
| `tau_G` | the end of follow-up — the last time the study is still observing anybody |

So `tau_F0 <= tau_G` reads: *the uncured run out of events before the study runs out of observation.*

**The intuition to actually hold on to.** Take one patient who is event-free at the end of the study. Two completely different stories produce that observation: she is cured and will never relapse, or she is uncured and would have relapsed next year, but the study stopped watching first. **If follow-up is too short the data cannot distinguish those two stories** — they produce identical observations. No clever estimator fixes this, because the information is not in the data. That is what "not identifiable" means in practice.

---

## 5. Why getting it wrong is expensive

Othus et al. re-analysed six SWOG trials, fitting cure models at an early follow-up time and again at a later one on the same trials. Two findings matter for us: the cure-model estimates of **mean survival shifted materially** between the early and later analysis, and **the direction of the shift was not predictable** — it was not a consistent bias you could anticipate.

The second point is the sharp one. If immature follow-up always inflated mean survival you could correct for it, or at least caveat in a known direction. It does not. So there is **no post-hoc correction**; the only defence is to check identifiability before you fit, which is what this entire workflow exists to do. Othus M, Bansal A, Koepl L, Wagner S, Ramsey S (2020). *Bias in mean survival from fitting cure models with limited follow-up.* Value in Health, 23(8), 1034-1039.

---

## 6. A plateau is not proof

This is the trap that makes a tool necessary rather than optional. The KM curve flattens for two very different reasons.

- **Real cure.** The uncured are exhausted and the remaining patients are cured. The plateau is meaningful.
- **Censoring artifact.** Patients leave the study — dropout, loss to follow-up, administrative end of study. A step down in the KM estimator requires an observed event among people still being watched, so **a curve with nobody left to watch is flat by construction.**

The two look the same on the plot. You cannot eyeball your way out of this.

**The concrete demonstration: simulated scenario D.** The simulation matrix in [`project-management/qa-plan.md`](../project-management/qa-plan.md) includes a scenario built to produce exactly this trap. All four scenarios use `n = 300, shape = 1.2, scale = 1, seed = 11` and `time_scale = "none"`. Scenario D is generated with a **true cure fraction of 0.00** — no cured group at all — administrative follow-up of 10, and a **dropout rate of 0.45**, which is heavy.

Because the true cure fraction is zero, the correct answer is known in advance: a cure model is wrong here. But the heavy dropout empties the risk set, so the KM curve **shows a plateau anyway**, and a naive reading of the plot says "cure fraction". The diagnostics refuse it:

| Quantity | Scenario D value |
| --- | --- |
| AIC best model | `weibull` (**non-cure**) |
| pi_hat (estimated cure fraction) | 0.000 |
| r_hat | 0.9973 |
| Verdict | **Cure model not supported** |

The model comparison prefers a non-cure model, the estimated cure fraction is effectively zero, and `r_hat` — defined in section 8 — is 0.9973, about as far from acceptable as the scale goes.

There is a second wrinkle we have to build for. In simulated scenarios C and D the Maller-Zhou, `qn` and Shen statistics come back as `NA`, because the package can only compute them when the largest observed time is a **censored** observation; when the longest observed time is an *event* there is no plateau region to test and the statistics are undefined. This is not a bug and not a crash. Task **A-07** specifies that the Diagnostics tab must render a clear "cannot be computed — the longest observed time is an event, so there is no plateau to test" message rather than a blank cell, an `NA`, or a red error screen. Risk **R7** tracks this as high-likelihood, because it happens on any dataset whose longest observation is an event.

---

## 7. The three-step check

This is the workflow from Figure 1 of the tutorial manuscript, and the structure the Verdict tab must mirror (task **A-08**).

1. **Expert judgment.** *Is cure biologically plausible for this disease and this endpoint?* Is there a known mechanism, a known therapy, a literature reporting long-term survivors? This is a conversation with a clinician. **No software can answer it**, ours included — the Verdict tab presents it as a step the *user* confirms, not something the app decides.
2. **Visual assessment.** *Does the KM curve plateau above zero, with late events absent?* A plateau with events still occurring at the end of follow-up is not a plateau.
3. **Quantitative assessment.** *Do the statistics support both a non-zero cure fraction and sufficient follow-up?* This is where the five diagnostics live.

**Failing any one step means a cure model is inappropriate.** It is a conjunction, not a scoring system: a dataset that sails through steps 2 and 3 with no biological basis for cure still fails. `cureAssess` automates steps 2 and 3. Step 1 is the human's.

---

## 8. What each diagnostic actually asks

Five diagnostics; `run.cure.tests(data, dist)` runs all five at once. Each gets its own card on the Diagnostics tab with the statistic, the threshold, a pass/fail chip, and the package's own `interpretation` string (task **A-07**).

Two conventions before the list. Most of these statistics are about **sufficient follow-up** (assumption b), not about whether a cure fraction exists (assumption a); only RECeUS speaks to both. And the direction of "good" is **not** the same across the five — get this wrong in the UI and the app will confidently tell users the opposite of the truth. That is the highest-risk copy in the project, which is why task **G-03** assigns all five plain-language descriptions to Geethanjalee.

**Maller-Zhou 1994 — `mz.test(dat, alpha)`.** *Is the gap between the last observed event and the end of follow-up big enough, relative to how many events were still happening just before it, that the study plausibly outlasted the uncured?* **Smaller is better: a statistic below 0.05 supports sufficient follow-up.** Threshold is `alpha`, default `0.05`. Returns `NA` when the largest observed time is an event.

**The `qn` statistic — `qn.test(dat)`.** *What share of the sample had events inside the late-time window just before the last event?* A long plateau makes that window wide, so it captures more events. **Larger is better** — the opposite of `mz.test`; larger `qn` means stronger evidence of sufficient follow-up. The threshold is **not** a fixed number but sample-size-dependent, `1 - 0.05^(1/n)`, where `n` is the number of rows. Because it moves with `n`, the app must display the computed threshold beside the statistic — a bare `qn` value is uninterpretable alone. Per-dataset threshold values come from the reference oracle (task **G-01**); do not hand-compute them in UI copy. Returns `NA` on the same condition.

**Shen 2000 — `shen.test(dat, alpha)`.** The same question as Maller-Zhou, asked with a different late-time window. Shen's version **corrects Maller-Zhou's type-I error inflation**: Maller-Zhou declares "follow-up is sufficient" more often than it should, and Shen tightens it. **Smaller is better: a statistic below 0.05 supports sufficient follow-up.** Threshold is `alpha`, default `0.05`. Returns `NA` on the same condition.

**The immune summary — `immune.test(dat)`.** *What does the tail of the KM curve actually look like?* It reports the estimated event probability by the end of follow-up, the proportion of censored observations, and whether the largest observed time was censored. **No direction — and this is the important part.** Despite the name ending in `.test`, **this is a descriptive summary, not a hypothesis test.** There is no null hypothesis, no p-value, no threshold and no pass/fail; it exists to give context to the other four. A pass/fail chip on this card would be a factual error. Present it as "Immune summary (descriptive)" with its three numbers and no verdict.

**RECeUS — `receus.method(data, dist, whichTau)`.** "Ratio Estimation of Censored Uncured Subjects" (Selukar & Othus 2023). The only diagnostic that addresses both assumptions at once, and the one that drives the headline verdict. It returns two quantities:

| Symbol | Meaning |
| --- | --- |
| `pi_hat` | the **estimated cure fraction** — how much of the population looks cured |
| `r_hat` | the **estimated proportion of uncured subjects still censored at the end of follow-up** — how much of the uncured group we never got to see resolve |

*Is there enough of a cured group to be worth modelling* (`pi_hat`) *and did we watch the uncured group long enough to have actually seen them* (`r_hat`)? A cure model is appropriate **if and only if both** hold: **`pi_hat > 0.025` AND `r_hat < 0.05`.** So `pi_hat` **large** is good, `r_hat` **small** is good, and both must pass. Failing `pi_hat` returns "Cure model not supported"; passing `pi_hat` but failing `r_hat` returns "Follow-up insufficient for cure modeling" — different verdicts with different advice attached, and the Verdict tab must distinguish them. One argument to know about: `whichTau` is the evaluation time and defaults to the maximum observed time.

---

## 9. Worked example: when it works

`nwtco`, High risk subgroup (stage 3-4), `edrel` as time and `rel` as status, with `time_scale = "days_to_years"`.

| Quantity | Value |
| --- | --- |
| n | 1404 |
| AIC best model | `loglogistic_cure` (AIC 1928.38) |
| pi_hat | 0.7823 |
| r_hat | 0.0041 |
| Maller-Zhou (1994) | 1.04e-140 |
| `qn` | 0.2051 |
| Shen (2000) | 0.0496 |
| RECeUS verdict | **Cure model appropriate** |

Walk it. The AIC comparison picks a **cure** model, which is initial support. Maller-Zhou at `1.04e-140` is far below 0.05, so follow-up looks sufficient. Shen at `0.0496` is below 0.05 — sufficient, but only just, which is worth noticing: Shen is the stricter of the two and sits very close to its threshold here even while Maller-Zhou is emphatic. `qn` at `0.2051` is compared against `1 - 0.05^(1/1404)`, not against 0.05. And RECeUS passes both conditions: `pi_hat = 0.7823` clears 0.025 comfortably, and `r_hat = 0.0041` is well under 0.05 — only about 0.4% of uncured subjects are still censored at the end of follow-up.

Both RECeUS conditions pass, the follow-up statistics agree, the AIC comparison agrees. This is the happy path, and what the app should look like when everything lines up.

---

## 10. Worked example: when it does not

`gbsg`, `rfstime` as time and `status` as status, with `time_scale = "days_to_years"`.

| Quantity | Value |
| --- | --- |
| n | 686 |
| AIC best model | `loglogistic_cure` (AIC 1719.70) |
| pi_hat | 0.3238 |
| r_hat | **0.3080** |
| Maller-Zhou (1994) | 0.0495 |
| `qn` | 0.0044 |
| Shen (2000) | 0.3676 |
| RECeUS verdict | **Follow-up insufficient for cure modeling** |

This example justifies the whole project. Read it in order.

1. **AIC picks a cure model.** `loglogistic_cure` wins. An analyst who knows a cure model can be fitted, and who stops at the model-comparison step, fits one here and reports a cure fraction of about 0.32. That is the natural thing to do and it is wrong.
2. **`r_hat = 0.3080`.** About 31% of uncured subjects are still censored at the end of follow-up. Roughly a third of the group whose event times carry all the information were never observed long enough to resolve. The cure fraction cannot be estimated reliably from this data.
3. **Therefore: a better AIC fit is not evidence that a cure model is identifiable.** AIC compares how well candidate models describe the data you have. It says nothing about whether the data contain enough follow-up to pin down the cure fraction. Different questions, and only the second is about identifiability.

Item 3 is the teaching point. It is why Stage 1 alone is not enough, why the app has a Diagnostics tab and a Verdict tab rather than just an AIC table, and the line that goes in the demo.

For completeness, the borderline case: **`colon`** recurrence, `Lev+5FU` arm, n = 304, AIC best `loglogistic_cure` (AIC 741.52), `pi_hat = 0.5736`, `r_hat = 0.0640`, Maller-Zhou `5.25e-13`, `qn = 0.0888`, Shen `0.0065`, verdict **Follow-up insufficient** — and it lands there because `r_hat = 0.064` sits *just above* the 0.05 cutoff. Same verdict as `gbsg`, reached from a completely different distance. Good material for the point that 0.05 is a convention, not a law of nature.

---

## 11. When the diagnostics disagree

Look at the `gbsg` row again, at just the follow-up statistics.

| Diagnostic | Value | Its threshold | Says |
| --- | --- | --- | --- |
| Maller-Zhou (1994) | 0.0495 | below 0.05 is sufficient | follow-up **is** sufficient |
| `qn` | 0.0044 | above `1 - 0.05^(1/686)` is sufficient | follow-up is **not** sufficient |
| Shen (2000) | 0.3676 | below 0.05 is sufficient | follow-up is **not** sufficient |
| RECeUS `r_hat` | 0.3080 | below 0.05 is sufficient | follow-up is **not** sufficient |

**Maller-Zhou says yes; the other three say no.** And the one that says yes barely says it — 0.0495 against a 0.05 cutoff is a margin of 0.0005.

**This is expected behaviour, not a bug.** They are different statistics answering closely related but non-identical questions, using different late-time windows and different sample-size corrections. Shen exists specifically because Maller-Zhou over-declares sufficiency, so when the two disagree in exactly this direction — Maller-Zhou passing, Shen failing — that is the known behaviour Shen was designed to catch, not a contradiction. And a statistic sitting 0.0005 from its threshold is not making a confident claim in either direction.

**How the app must present this.** This is deliberate: these are **descriptive aids to be read together with subject-matter knowledge, not a single decision rule.** Concretely:

- Never collapse the five diagnostics into one green/red light with no detail.
- Show all five, with their values, their thresholds, and their individual readings.
- The Verdict tab carries an explicit **"the diagnostics can disagree — here is what to do"** panel (task **A-08**), whose wording is Geethanjalee's (task **G-04**).
- Default `run_tests = "yes"`, **not** `"auto"`. With `"auto"` the package silently skips Stage 2 when the smallest-AIC model is a non-cure model, and the user never sees the diagnostics at all. The app always shows them, and explains on screen why they appear even when a non-cure model won the AIC comparison.

Risk **R10** anticipates that a judge might read the `gbsg` contradiction as a defect. The counter is to lead with it: it is the clearest available demonstration of why a tool like this is needed.

**What to do when follow-up looks insufficient.** The app must say something more useful than "no". Per task **G-04**: use a **non-cure** model instead; or the extreme-value estimators of Escobar-Bach & Van Keilegom (2019); or Yuen & Musta's relaxed condition (2024); or collect more follow-up.

---

## 12. A note on the word "cure"

"Cure" is a statistical label for a shape in the data, not a clinical promise. For a **mortality** endpoint in particular, read it as **long-term survivorship** — the hazard of the event becoming negligible — and **not** as literal immunity to death. Everybody dies of something; a patient in the "cured" group of a relapse-free-survival model is a patient whose risk of *that specific event* has fallen to effectively zero.

This matters for the app's copy, not just for accuracy of thought. A user who reads "cure fraction = 0.78" as "78% of these children are immune" has misunderstood the output. The in-app help (tasks **A-10**, **G-02**, **G-03**, **G-04**) should use "long-term survivorship" where it fits, and never imply more than the statistic supports.

---

## 13. The package, function by function

Nine exported functions. **The app should lean on the wrapper and not re-implement anything.**

| Function | Plain-language purpose | App use |
| --- | --- | --- |
| `prepare.surv.data(data, time, status, time_scale)` | Renames your two columns to `Y` (time) and `D` (event 1/0) and optionally divides days by 365.25. | Data tab, after column mapping. |
| `model.fitting(data, plot_km, include_lognormal)` | Fits a cure **and** a non-cure model for exponential / Weibull / gamma / log-logistic (+ optional lognormal) and ranks all of them by AIC. | Models tab. |
| `cure.appropriateness(...)` | **The wrapper.** Runs both stages and returns one object with the verdict. | Verdict tab. |
| `run.cure.tests(data, dist)` | Runs all five diagnostics at once. Requires `dist`. | Diagnostics tab. |
| `mz.test(dat, alpha)` | Maller-Zhou 1994 sufficient-follow-up test. Statistic `< 0.05` implies follow-up looks sufficient. | Diagnostics card. |
| `qn.test(dat)` | Maller-Zhou `qn` statistic. **Larger** is better; compared against a sample-size-dependent threshold `1 - 0.05^(1/n)`. | Diagnostics card. |
| `shen.test(dat, alpha)` | Shen 2000 test; corrects Maller-Zhou's type-I inflation. `< 0.05` implies sufficient. | Diagnostics card. |
| `immune.test(dat)` | Descriptive KM-tail summary: event probability at end of follow-up, censoring proportion, whether the last observation was censored. **Not a hypothesis test.** | Diagnostics card. |
| `receus.method(data, dist, whichTau)` | RECeUS (Selukar & Othus 2023). Returns `pi_hat` and `r_hat`. Cure model appropriate iff **`pi_hat > 0.025` AND `r_hat < 0.05`**. | Diagnostics card + Verdict. |

**Eight traps, all verified in the package source.**

1. **Two naming schemes.** `model.fitting()` returns names like `weibull_cure`; `receus.method()` wants short codes (`"exp"`, `"wei"`, `"gam"`, `"llogis"`, `"lnorm"`, plus `...Unc` non-cure variants). The translation lives in an **internal** function — **do not call it.** Call `cure.appropriateness()` and let it map, or expose a dropdown of the short codes.
2. **`run_tests = "auto"` silently skips Stage 2** when the smallest-AIC model is non-cure. Default to `"yes"` and explain on screen why the diagnostics are shown anyway.
3. **The data check requires `D` to be exactly 0/1** and `Y` numeric. A dataset coded 1/2 — very common — will error, so the column mapper (task **A-03**) must let the user pick which level means "event".
4. **`model.fitting()` never throws** on a failed fit; it records the message in the `error` column and sets `AIC = NA`. **Display that column, do not hide it** (task **A-05**).
5. **Diagnostics return `NA` when the largest observed time is an event** (section 6). Handle it with an explanatory state, never a blank or a crash.
6. **`include_lognormal` defaults to `FALSE`** deliberately: lognormal's heavy tail can change both the selected model and the RECeUS conclusion. Expose it as an opt-in toggle carrying that warning.
7. **`immune.test()` is descriptive, not a test**, despite the name. Label it so, and give it no pass/fail chip.
8. **`receus.method()` defaults `whichTau`** to the maximum observed time.

**Performance.** A full `cure.appropriateness()` run takes **0.1-0.2 s** — fast enough for the app to re-run the entire assessment interactively, which is what makes stretch goal **S-1**, the follow-up truncation slider, viable.

---

## 14. Further reading

**The diagnostics themselves** — these four are what the About tab must cite (Definition of Done item 5):

- Maller RA, Zhou S (1992). *Estimating the proportion of immunes in a censored sample.* Biometrika, 79(4), 731-739. doi:10.1093/biomet/79.4.731
- Maller RA, Zhou S (1994). *Testing for sufficient follow-up and outliers in survival data.* JASA, 89(428), 1499-1506. doi:10.1080/01621459.1994.10476889
- Shen P-S (2000). *Testing for sufficient follow-up in survival data.* Statistics & Probability Letters, 49(4), 313-322. doi:10.1016/S0167-7152(00)00063-8
- Selukar S, Othus M (2023). *RECeUS: Ratio estimation of censored uncured subjects, a different approach for assessing cure model appropriateness in studies with long-term survivors.* Statistics in Medicine, 42(3), 209-227. doi:10.1002/sim.9610

**Background cited in the package source:**

- Maller RA, Zhou S (1995). *Testing for the presence of immune or cured individuals.* Biometrics, 51, 1197-1205. doi:10.2307/2533253
- Maller RA, Zhou X (1996). *Survival Analysis with Long-Term Survivors.* Wiley.
- Maller RA, Resnick S, Shemehsavar S (2024). *Finite sample and asymptotic distributions of a statistic for sufficient follow-up in cure models.* Canadian Journal of Statistics, 52(2), 359-379. doi:10.1002/cjs.11771

**Further reading referenced above:**

- Othus M, Bansal A, Koepl L, Wagner S, Ramsey S (2020). *Bias in mean survival from fitting cure models with limited follow-up.* Value in Health, 23(8), 1034-1039.
- Escobar-Bach M, Van Keilegom I (2019). *Non-parametric cure rate estimation under insufficient follow-up by using extremes.* Journal of the Royal Statistical Society Series B, 81(5), 861-880.
- Yuen TP, Musta E (2024). *Testing for sufficient follow-up in survival data with a cure fraction.* arXiv:2403.16832.

**The workflow this app operationalises:** Mudunkotuwa, Ghosh, Triplett, Selukar. *A Tutorial for Evaluating Cure Model Appropriateness* (in preparation). The app implements this manuscript's Figure 1 workflow. The manuscript itself is **not** in this repository.

**The package:** `cureAssess` version 0.1.0, MIT licensed. Authors: Geethanjalee Mudunkotuwa (aut, cre, cph), Durbadal Ghosh (aut). Upstream `https://github.com/GeethanjaleeM/cureAssess`; vendored into this repo at `cureAssess/`. How to cite it goes on the About tab (task **A-10**).

---

**Who to ask.** Geethanjalee Mudunkotuwa is the package author, the Science Lead, and the declared first point of contact for both pods on anything requiring a statistical judgement call — including every word of interpretation text the app prints. If a number looks wrong, that is a **blocking** bug (risk **R5**), not a cosmetic one: file a GitHub issue immediately and say it out loud at the next standup. Durbadal Ghosh is the overflow and makes scope calls.
