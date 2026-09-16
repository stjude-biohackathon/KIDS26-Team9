# User guide — cureAssessApp

**Stub. Written during the hackathon by task [D-02](../project-management/task-backlog.md)**
(Rachael, Friday block F2, 10:50–12:00). Do not write it earlier — it documents the app as built,
not the app as planned.

## What this document must contain

A guided walkthrough for someone who has never seen the app and does not know what a cure model is:

1. **Install and launch** — pointer to the README, then `shiny::runApp("app")`.
2. **Walk one dataset end to end** — load `nwtco — High risk`, read the summary card, look at the
   Kaplan-Meier curve, run the models, read the diagnostics, read the verdict, download the report.
3. **The teaching example** — then do the same with `gbsg`, where AIC prefers a *cure* model but
   RECeUS reports r̂ = 0.3080 and the verdict is "Follow-up insufficient for cure modeling". Explain
   why a better AIC fit is not on its own evidence that a cure model is identifiable. This is the
   example that teaches a user what the tool is for.
4. **Bringing your own data** — the column mapper, the 0/1 event-coding requirement, time units.
   Point at [`data-contract.md`](data-contract.md) for the full specification.
5. **Reading each diagnostic** — with the direction of each threshold spelled out, because two of the
   five point the opposite way from the others. See [`cure-models-101.md`](cure-models-101.md).
6. **When the diagnostics disagree** — what to do, and why it is expected rather than a bug.
7. **What the app does not do** — it assesses whether a cure model is *appropriate*; it does not fit
   your final analysis model, handle covariates, or compare treatment arms.

Keep it short enough that someone reads the whole thing. Screenshots from task **D-04** go here.
