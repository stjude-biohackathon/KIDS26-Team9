---
title: "Submitting `cureAssess` 0.1.0 to CRAN"
subtitle: "A step-by-step guide for the package maintainer"
author: "Prepared for Geethanjalee Mudunkotuwa"
date: "2 September 2026"
---

\vspace{-1em}

# Before anything else: read this page

You are listed in the package as the **maintainer** (`cre`). CRAN requires
that the person who submits a package *is* its maintainer, because:

* the email address you type into the submission form must match the
  maintainer address in the `DESCRIPTION` file, character for character; and
* CRAN emails a confirmation link to that address, and **the submission does
  not exist until that link is clicked**.

Your maintainer address is:

> **`geethanjaleem@gmail.com`**

Everything in this guide assumes you are working from that mailbox.

## Who does what

| Step | Who |
|:--|:--|
| 1. Review the two items in Section 2 | **You** |
| 2. Send you the package source or tarball | Durbadal |
| 3. Set up R, pandoc and LaTeX (Section 4) | **You** |
| 4. Build and check locally (Section 6) | **You** |
| 5. Run the win-builder checks (Section 7) | **You** |
| 6. Submit the web form (Section 8) | **You** |
| 7. Click the confirmation email (Section 9) | **You only** |

## Current state of the package

The package has been prepared for submission and currently passes CRAN's own
check cleanly:

| Check | Result |
|:--|:--|
| `R CMD check --as-cran` | **0 errors, 0 warnings, 2 notes** |
| Note 1 | "New submission" -- expected and unavoidable |
| Note 2 | Local HTML Tidy version -- will not occur on CRAN |
| Test suite | 40 of 40 pass |
| PDF manual | Builds cleanly |
| Vignette | Builds cleanly |

\newpage

# Two things to review before you submit

These are decisions made on your behalf during preparation. Please confirm
both before submitting, because your name goes on the result.

## A corrected reference in `qn.test()` -- please verify

The documentation for `qn.test()` originally cited:

```
Maller RA, et al. (2024).
The qn test for the cure proportion.
Stat Med, 2024;43(8):1557-75.
```

**This paper could not be found.** It does not resolve in Crossref or PubMed:
there is no article with that title, and *Statistics in Medicine* volume 43,
issue 8, pages 1557--75 is a different paper entirely.

It has been replaced with what appears to be the intended source -- the paper
that derives finite-sample critical values for the $q_n$ statistic:

```
Maller RA, Resnick S, Shemehsavar S (2024).
Finite sample and asymptotic distributions of a statistic for
sufficient follow-up in cure models.
Canadian Journal of Statistics, 52(2), 359-379.
doi:10.1002/cjs.11771
```

**Please confirm this is the reference you meant.** If you had a different
paper in mind, tell Durbadal and it will be corrected before submission. CRAN
resolves DOIs automatically during its incoming checks, so an unverifiable
citation is likely to be queried.

## Authorship and maintainership

The `DESCRIPTION` file now reads:

| Person | Roles |
|:--|:--|
| Geethanjalee Mudunkotuwa | `aut`, `cre`, `cph` -- author, maintainer, copyright holder |
| Durbadal Ghosh | `aut` -- author |

The `LICENSE` file continues to name you as copyright holder. If you would
prefer a different arrangement, change it *before* submitting -- altering the
maintainer after acceptance requires a separate email to CRAN.

**What being maintainer commits you to:** CRAN will email you whenever your
package breaks against a new R release or a changed dependency. You are
expected to respond, usually within two weeks. Packages whose maintainers do
not respond are archived and removed from CRAN.

\newpage

# What has already been done

You do not need to redo any of this. It is listed so you know what changed
since you last worked on the package.

| Area | What was done |
|:--|:--|
| `DESCRIPTION` | Added method references with DOIs (CRAN requires these); added `URL`, `BugReports`, `Language: en-US` |
| `qn.test()` | Corrected the unverifiable citation -- see Section 2.1 |
| References | Attached verified DOIs to all six citations |
| Examples | Added runnable examples to five exported functions that had none |
| `?cureAssess` | Added package-level help page |
| Encoding | Replaced seven non-ASCII en-dashes with ASCII equivalents |
| `README` | Replaced the unedited devtools template with real content |
| Vignette | Fixed 20 malformed headings, two typos, a mislabelled code block, and a variable that shadowed `survival::gbsg` |
| `cran-comments.md` | Written, ready to paste into the submission form |

**The statistical behaviour of the package was not changed.** Only three lines
of executable code differ from your original, all of them text labels that get
printed rather than computed with. This was verified by installing your
original version alongside the current one and confirming every numeric result
is identical to the last digit.

# Setting up your machine

Skip any step you have already done.

## R version 4.1.0 or newer

The package declares `Depends: R (>= 4.1.0)`. Check your version:

```r
R.version.string
```

If it is older, install a current R from <https://cran.r-project.org>.

## Package dependencies

In R, run:

```r
install.packages(c(
  "survival", "flexsurv", "flexsurvcure", "survminer",
  "ggplot2", "dplyr",
  "knitr", "rmarkdown", "testthat",
  "devtools", "roxygen2", "rcmdcheck"
))
```

## pandoc -- required to build the vignette

Without pandoc, `R CMD build` fails with
*"Pandoc is required to build R Markdown vignettes"*.

If you have **RStudio** installed, it ships a copy and RStudio finds it
automatically -- **run every command in this guide from inside RStudio's
console** and you can skip this step.

If you work from a terminal instead, install pandoc from
<https://pandoc.org/installing.html>, then confirm:

```r
rmarkdown::pandoc_available()   # must return TRUE
```

## LaTeX -- required to build the PDF manual

CRAN builds a PDF reference manual, so your local check needs LaTeX too. If
you do not already have a TeX installation:

```r
install.packages("tinytex")
tinytex::install_tinytex()
```

That downloads roughly 250 MB and takes a few minutes. Confirm afterwards:

```r
tinytex::is_tinytex()   # must return TRUE
```

\newpage

# Getting the package source

Durbadal has the prepared version. The changes are on a git branch called
`cran-submission-prep`. Ask him for **either**:

**Option A -- the built tarball (simplest).** A single file named
`cureAssess_0.1.0.tar.gz`. Put it in a folder of your choice. You can submit
this file directly, though you should still run the checks in Sections 6 and 7.

**Option B -- the source repository (preferred).** He pushes the branch to
GitHub, and you clone or pull it. This lets you inspect every change, rebuild
from source, and keeps the history. In a terminal:

```bash
git clone https://github.com/GeethanjaleeM/cureAssess.git
cd cureAssess
git checkout cran-submission-prep
```

Option B is better if you want to review the changes described in Section 3
before putting your name to them.

# Building and checking locally

Work in the folder that contains the `DESCRIPTION` file.

## Build the tarball

From a terminal:

```bash
R CMD build .
```

This produces `cureAssess_0.1.0.tar.gz`. If you were given the tarball
directly (Option A above), skip this.

## Run the CRAN check

```bash
R CMD check --as-cran cureAssess_0.1.0.tar.gz
```

This takes a few minutes. Or, equivalently, from within R:

```r
devtools::check()
```

## Reading the result

The last line reports the status. **You are looking for:**

```
Status: 1 NOTE
```

or

```
Status: 2 NOTEs
```

Either is fine, provided the notes are the two expected ones:

**Expected note 1 -- always present, cannot be removed:**

```
* checking CRAN incoming feasibility ... NOTE
Maintainer: 'Geethanjalee Mudunkotuwa <geethanjaleem@gmail.com>'

New submission
```

This simply tells the reviewer the package is new. It is not a problem.

**Expected note 2 -- may or may not appear, depending on your system:**

```
* checking HTML version of manual ... NOTE
Skipping checking HTML validation: 'tidy' doesn't look like recent
enough HTML Tidy.
```

This is about the `tidy` program on your own computer, not about the package.
CRAN's machines have a current version, so it will not appear there.

**If you see any ERROR or WARNING, stop and tell Durbadal.** Do not submit.

**If you see a note that is not one of the two above**, read it carefully --
it usually names the exact file and line at fault.

\newpage

# Running the win-builder checks

CRAN expects a package to have been tested against the development version of
R before submission. This is done through a free service called win-builder.
**Do not skip this** -- it is the single most common way a first submission
gets bounced for something avoidable.

## Submit to win-builder

From R, in the package folder:

```r
devtools::check_win_devel()      # R-devel  (the important one)
devtools::check_win_release()    # current R release
```

Each uploads your tarball to a Windows machine in Germany, which builds and
checks it.

> **Note:** this step could not be completed on Durbadal's machine -- his
> network blocks win-builder entirely. If the commands above hang or time out
> for you as well, try a different network (home instead of university Wi-Fi,
> or a phone hotspot).

## Wait for the results

Results arrive by email at `geethanjaleem@gmail.com`, usually within 15 to 30
minutes but occasionally longer. **Check your spam folder.**

The email contains a link to a check log. Open it and look at the final
`Status:` line. You want the same outcome as Section 6.3 -- notes only, no
errors or warnings.

A note you may see only on Windows:

```
* checking CRAN incoming feasibility ... NOTE
Possibly misspelled words in DESCRIPTION:
  Kaplan, Maller, Othus, RECeUS, Selukar, Shen, Zhou
```

These are author surnames and a method acronym. They are spelled correctly.
The `cran-comments.md` file already explains this to the reviewer.

**Wait for both emails and confirm both are clean before continuing.**

\newpage

# Submitting to CRAN

Go to:

> **<https://cran.r-project.org/submit.html>**

The form has four fields. Fill them in exactly as follows.

## Your name

```
Geethanjalee Mudunkotuwa
```

## Your email address

```
geethanjaleem@gmail.com
```

This **must** match the maintainer address in `DESCRIPTION` exactly. A
mismatch causes automatic rejection.

## The package file

Click *Browse* and select:

```
cureAssess_0.1.0.tar.gz
```

Make sure you upload the `.tar.gz` file itself -- not a folder, and not a
`.zip`.

## Optional comments

Open the file `cran-comments.md` in the package folder and paste its contents
into this box. It tells the reviewer:

* which platforms you tested on;
* that the "New submission" note is expected;
* that the flagged words are surnames, not misspellings;
* that the package writes nothing outside `tempdir()` and has no compiled code.

Then click **Upload package**.

# Confirming by email -- do not miss this

Within a few minutes, CRAN sends an email to `geethanjaleem@gmail.com` with a
subject line like *"CRAN submission cureAssess 0.1.0"*. It contains a
confirmation link.

**You must click that link.** Until you do, your package has not been
submitted -- it sits in limbo and is eventually discarded. This is the single
most common way a first submission silently fails.

Check your spam folder if it has not arrived within about ten minutes.

\newpage

# What happens next

After you confirm, the package enters CRAN's queue. Automated checks run
first, then a human volunteer reviews it. A first submission typically takes
between one day and two weeks.

There are three possible outcomes.

## Accepted

You receive an email saying the package has been published. It appears at
`https://cran.r-project.org/package=cureAssess` within a day, and becomes
installable by anyone:

```r
install.packages("cureAssess")
```

## Changes requested -- this is normal

Most first submissions get at least one round of comments. **This is not a
rejection.** A reviewer will ask for something specific, for example:

* wording in the `Description` field;
* an example that should not be wrapped in `\dontrun{}`;
* a missing `\value{}` section in a help file.

To respond:

1. Make the change.
2. Bump the version in `DESCRIPTION` to `0.1.1`.
3. Add a line to `cran-comments.md` saying what you changed.
4. Re-run Sections 6 and 7.
5. Resubmit through the same web form.

**Reply in the same email thread.** Do not start an unrelated new submission.

## Rejected outright

Unlikely at this stage, since the check is already clean. If it happens, the
email will explain why.

# After acceptance

Ask Durbadal to tag the release in git so the exact submitted source is
recorded:

```bash
git tag -a v0.1.0 -m "CRAN release 0.1.0"
```

From then on, remember the maintainer obligation described in Section 2.2:
watch for emails from CRAN about your package, and respond promptly.

\newpage

\appendix

# Quick reference

**Submission URL** -- <https://cran.r-project.org/submit.html>

| Form field | Value |
|:--|:--|
| Name | `Geethanjalee Mudunkotuwa` |
| Email | `geethanjaleem@gmail.com` |
| File | `cureAssess_0.1.0.tar.gz` |
| Comments | contents of `cran-comments.md` |

**The whole sequence in commands:**

```r
# 1. build and check locally
devtools::check()

# 2. check on R-devel and release (wait for both emails)
devtools::check_win_devel()
devtools::check_win_release()

# 3. then submit at https://cran.r-project.org/submit.html
# 4. then CLICK THE CONFIRMATION EMAIL
```

# Troubleshooting

**"Pandoc is required to build R Markdown vignettes"**
: Pandoc is missing or not on your PATH. Run the commands from inside
  RStudio, which bundles its own copy. See Section 4.3.

**"pdflatex is not available"**
: LaTeX is missing. Install TinyTeX -- see Section 4.4. Until you do, the
  check reports a spurious error and warning about the PDF manual that has
  nothing to do with the package.

**`check_win_devel()` hangs or times out**
: Your network is blocking win-builder. Try a different network or a phone
  hotspot. This happened on Durbadal's machine.

**"there is no package called 'cureAssess'"**
: Something tried to load the package before it was installed. Run
  `devtools::install()` first, or use `devtools::check()` which handles this.

**The confirmation email never arrives**
: Check spam. Confirm the email you typed into the form matches
  `geethanjaleem@gmail.com` exactly. If it still does not arrive after an
  hour, resubmit.

**A check flags a "possibly invalid DOI"**
: All six DOIs in the package were verified against Crossref and resolve
  correctly. Some publishers (Oxford, Taylor and Francis, Wiley) return an
  error to automated checkers while working fine in a browser. Say so in your
  reply to the reviewer.

# Optional improvements, not required for CRAN

Two rough edges were deliberately left alone, because fixing them would change
how the package behaves and that was your decision to make. Neither blocks
submission.

**`final_recommendation` ignores the Stage 2 diagnostics.** For the `gbsg`
data, RECeUS returns *"Follow-up insufficient for cure modeling"*, yet
`final_recommendation` still reads *"provides initial support for cure model
appropriateness"* and merely notes that diagnostics were run. The field
summarises the AIC screening step only. A statistically-minded reviewer may
raise this, since it works against the package's own two-stage argument.

**`run.cure.tests()` has no print method.** It returns an object of class
`"cure.tests"`, but printing it dumps the raw nested list. The vignette avoids
this by printing each component separately.
