# cran-comments

## Submission summary

This is a new submission of **cureAssess** version 0.1.0.

cureAssess provides diagnostics for deciding whether a cure model is
appropriate for right-censored survival data. Methods implemented are those of
Maller and Zhou (1992, 1994), Shen (2000), and Selukar and Othus (2023); all
are cited with DOIs in the `Description` field.

## Test environments

* local macOS (aarch64-apple-darwin23), R 4.6.1
* win-builder (devel and release)
* R-hub: Windows Server, Ubuntu Linux, macOS

## R CMD check results

0 errors | 0 warnings | 1 note

```
* checking CRAN incoming feasibility ... NOTE
Maintainer: 'Geethanjalee Mudunkotuwa <geethanjaleem@gmail.com>'

New submission
```

This note is expected for a first submission.

If the incoming checks flag possibly misspelled words in the `Description`
field, these are author surnames (Kaplan, Maller, Othus, Selukar, Shen, Zhou)
and the method acronym RECeUS. All are spelled correctly.

## Notes for the reviewer

* The package title, description, and all exported functions are documented,
  and every exported function has a runnable example. No example is wrapped in
  `\dontrun{}`.
* Examples use the `gbsg` and `nwtco` data sets from the **survival** package,
  which is already a hard dependency. All examples run in well under 5 seconds.
* No function writes to the user's home filespace, the working directory, or
  the package installation directory. Nothing is written outside `tempdir()`.
* No functions change the user's options, par settings, or working directory.
* The package contains no compiled code.
* The unit tests use `skip_on_cran()` for the model-fitting tests, which depend
  on numerical optimization in **flexsurv** and **flexsurvcure** and are
  therefore not reproducible enough for CRAN's check farm. They run locally and
  in CI.

## Downstream dependencies

There are currently no downstream dependencies for this package.
