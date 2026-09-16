
<!-- README.md is generated from README.Rmd. Please edit that file -->

# cureAssess

<!-- badges: start -->

<!-- badges: end -->

cureAssess helps you decide whether a **cure model** is appropriate for
right-censored survival data — that is, whether the data plausibly
contain a fraction of subjects who will never experience the event of
interest.

Fitting a cure model when follow-up is too short, or when there is no
real cured fraction, produces biased estimates. cureAssess packages the
standard screening and diagnostic procedures for that decision into one
workflow.

## Installation

Install the released version from CRAN:

``` r
install.packages("cureAssess")
```

Or the development version from GitHub:

``` r
# install.packages("pak")
pak::pak("GeethanjaleeM/cureAssess")
```

## The two-stage workflow

**Stage 1 — screening.** Standardize the data, fit matched cure and
non-cure parametric models, and rank them by AIC. If the smallest-AIC
model is a cure model, that is initial support for cure modeling.

**Stage 2 — diagnostics.** Run the formal checks for sufficient
follow-up and for a cured fraction: the Maller-Zhou statistics, Shen’s
test, an immune summary of the Kaplan-Meier tail, and the RECeUS method.

`cure.appropriateness()` runs both stages in one call.

## Example

``` r
library(cureAssess)
library(survival)

res <- cure.appropriateness(
  data = gbsg,
  time = "rfstime",
  status = "status",
  time_scale = "days_to_years",
  plot_km = FALSE,
  run_tests = "yes"
)

res
#> 
#> Cure model appropriateness analysis
#> -----------------------------------
#> Best model by AIC: loglogistic_cure 
#> Best model type: cure 
#> 
#> Initial decision:
#> The model with the smallest AIC is a cure model (loglogistic_cure). This provides initial support for cure model appropriateness. 
#> 
#> RECeUS distribution used: llogis 
#> Based on cure model: loglogistic_cure 
#> 
#> Testing status:
#> Tests were run because `run_tests = "yes"`. RECeUS used distribution: llogis. 
#> 
#> Final recommendation:
#> The model with the smallest AIC is a cure model (loglogistic_cure). This provides initial support for cure model appropriateness. Additional cure-appropriateness diagnostics were run for further evaluation.
```

The AIC comparison behind the decision is available directly:

``` r
head(res$screening$aic_table[, c("model", "model_type", "AIC")], 4)
#>              model model_type      AIC
#> 1 loglogistic_cure       cure 1719.696
#> 2       gamma_cure       cure 1723.476
#> 3      loglogistic   non-cure 1731.346
#> 4     weibull_cure       cure 1733.922
```

Individual diagnostics can also be run on their own, on data prepared by
`prepare.surv.data()`:

``` r
dat <- prepare.surv.data(
  data = gbsg,
  time = "rfstime",
  status = "status",
  time_scale = "days_to_years"
)

mz.test(dat)
#> 
#> Maller-Zhou test statistic (1994)
#> ---------------------------------
#> Statistic: 0.0494606 
#> Alpha: 0.05 
#> Interpretation: Since the Maller-Zhou statistic (0.0495) is less than alpha = 0.05, there is evidence of sufficient follow-up, supporting cure model appropriateness.
receus.method(dat, dist = "lnorm")
#> 
#> RECeUS Cure Model Assessment
#> ----------------------------
#> Distribution: lnorm 
#> Tau: 7.2799 
#> 
#> Estimated cure fraction (pi_hat): 0.2775 
#> Remaining uncured ratio (r_hat): 0.4083 
#> 
#> Decision: Follow-up insufficient for cure modeling 
#> 
#> Interpretation:
#> The remaining uncured ratio (r_hat = 0.4083 ) is greater than or equal to 0.05. This suggests that a large proportion of uncured subjects remain censored at the end of follow-up, indicating insufficient follow-up to reliably estimate a cure fraction.
```

Note what the two stages say here. AIC preferred a *cure* model for
these data, but RECeUS reports that too large a share of uncured
subjects is still censored at the end of follow-up. A better AIC fit is
not on its own evidence that a cure fraction can be estimated reliably —
which is why the screening stage alone is not enough.

For a worked comparison of a data set where a cure model *is* supported
(`nwtco`) against one where it is *not* (`gbsg`), see the introductory
vignette:

``` r
vignette("introduction", package = "cureAssess")
```

## Interpreting the output

These diagnostics are descriptive aids, not a single decision rule.
Sufficient follow-up tests ask whether the study ran long enough to tell
a genuine cure fraction apart from a plateau caused by censoring. Read
them together, and alongside subject-matter knowledge about whether cure
is clinically plausible.

## References

- Maller RA, Zhou S (1992). Estimating the proportion of immunes in a
  censored sample. *Biometrika*, 79(4), 731–739.
  <doi:10.1093/biomet/79.4.731>
- Maller RA, Zhou S (1994). Testing for sufficient follow-up and
  outliers in survival data. *Journal of the American Statistical
  Association*, 89(428), 1499–1506. <doi:10.1080/01621459.1994.10476889>
- Shen P-S (2000). Testing for sufficient follow-up in survival data.
  *Statistics & Probability Letters*, 49(4), 313–322.
  <doi:10.1016/S0167-7152(00)00063-8>
- Selukar S, Othus M (2023). RECeUS: Ratio estimation of censored
  uncured subjects. *Statistics in Medicine*, 42(3), 209–227.
  <doi:10.1002/sim.9610>

## License

MIT © Geethanjalee Mudunkotuwa
