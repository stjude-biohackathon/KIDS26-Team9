# =============================================================================
# mod_docs.R — the Documentation tab (nav id "docs"), builder-docs
#
# Static. Package call sites: NONE. This file reads no `state` field, no
# package field and no package version, so it has no provenance to record.
#
# V2_CONTRACT §E (R3, R4, R5). This pass replaced the three-line-per-method
# summaries with the full technical treatment: every reading is documented to
# the depth of the package help text — what it measures, its definition, its
# symbols, its direction, its decision rule, what is and is not implemented,
# when it cannot be computed, and its source — set as typeset mathematics in
# HTML + unicode + CSS (classes .ca-m / .ca-eq / .ca-hat / .ca-frac / .ca-syms,
# defined in app/www/app.css §N, builder-shell). NO MathJax, NO KaTeX, NO CDN,
# no webfont: the app is demonstrated offline. Math is never set inside <code>.
#
# Copy provenance: §E.2 (the five method blocks), §E.3 (how the simulated
# examples are generated) and §E.4 (the glossary) are pasted verbatim from the
# contract as raw strings and emitted with htmltools::HTML(). They are contract
# copy: do not rewrite them here, and do not re-expand what §E deliberately cut.
#
# Deleted this pass, per §E.5:
#   1. `.DOCS_SHORT_FOLLOWUP` and its "If follow-up is too short" accordion
#      panel, in full (R4) — title, value and all four lines. The three
#      references that supported those lines stay in the reference list.
#   2. Nothing is rendered below the reference list; the reference list is the
#      last element of ca_docs_sections() and remains so.
#   3. The closing sentence of the three-checks panel is gone. It restated the
#      R1 line deleted from the Intro tab — three checks, and a negative answer
#      ending the assessment — and §E.5.3 requires zero occurrences repo-wide
#      of that sentence or of any paraphrase of it. The three checks themselves
#      stay; what goes is the ordering-and-stopping claim on top of them.
# Earlier deletions (the provenance table, the FAQ, the worked readings, the
# per-panel navigation buttons, the immune-summary panel, the three reference
# cards, and everything that used to sit below References) stay deleted.
#
# G2/C1 holds: the reference list and the one package-link block beside the QR
# code are the only places a package name appears, and no function name, field
# name, R object or line of R code appears anywhere on screen.
#
# Shared with the alternatives (§F.1, §F.3): `ca_docs_sections()` is the frozen
# entry point. app-v2's Method overlay and app-v3's Method mode render exactly
# this function, so the words exist once. `mod_docs_ui()` adds only the tab's
# own chrome (the page title and its one-line lede) around it.
# =============================================================================


# ---- panel 1: the three checks ----------------------------------------------

# The poster's verbatim wording for the three steps. This is the only place in
# the app the three steps are restated (C3 allows it on Documentation).
.DOCS_CHECKS <- list(
  c("Expert judgment",
    "Is a cure biologically plausible? Is long-term survival without recurrence expected?"),
  c("Visual assessment",
    "Does the survival curve plateau, with late events absent?"),
  c("Quantitative assessment",
    "Is there strong quantitative evidence of sufficient follow-up and a cure fraction?")
)


# ---- §E.2 the five method blocks --------------------------------------------

# Contract copy, pasted verbatim; one <article class="ca-method"> per reading,
# each a short lead paragraph with the full mathematics behind a closed
# <details class="ca-more"> disclosure.
#
# [SIGN-OFF] the five *Direction* statements are the highest-risk copy in the
# app. Reviewed against the package source, not against any document:
#   mz.test()   stat < alpha  -> sufficient follow-up  (smaller is better)
#   shen.test() stat < alpha  -> sufficient follow-up  (smaller is better)
#   qn.test()   stat > 1 - alpha^(1/n) -> sufficient follow-up (LARGER is
#               better, and the threshold moves with n)
#   receus.method() pi_hat > 0.025 && r_hat < 0.05 -> "Cure model appropriate"
#   model.fitting() ranks by AIC; smaller AIC, failed rows kept with a reason.
# All three follow-up statistics return NA together when max(Y) equals the
# largest event time (S6); RECeUS returns NA when the fit behind it fails.
# S9 — mz = (1 - qn)^n exactly — is stated in both the Maller-Zhou block and
# the qn block, and the two are never presented as independent votes.
# §E.5 also requires that the non-implementation of the Maller, Resnick and
# Shemehsavar (2024) exact finite-sample critical values survives into the app;
# it is the "What is implemented here — and what is not" entry of the qn block.
.DOCS_METHODS_HTML <- r"---(
<div class="ca-section">
  <h2 class="ca-section__title">The methods</h2>
  <p class="ca-lede">
    Five readings, in the order the assessment applies them. Each one is stated in a
    sentence first; the definitions, thresholds and limits sit behind the disclosure
    underneath it.
  </p>


  <!-- ===================================================================== -->
  <!-- 1. MODEL COMPARISON (AIC)                                             -->
  <!-- ===================================================================== -->
  <article class="ca-method">
    <h3>Model comparison</h3>
    <p class="ca-method__lead">
      Does a model that allows a permanently event-free group describe these data better
      than one that does not? Eight models are fitted — four survival shapes, each with
      and without a cured group — and ranked. If the best-ranked model is one without a
      cured group, a cure model is not appropriate and nothing downstream can rescue it.
    </p>

    <details class="ca-more">
      <summary>Definition, direction and decision rule</summary>
      <div class="ca-more__body">
        <dl class="ca-def">

          <dt>What it measures</dt>
          <dd>
            Relative fit, penalised for the number of free parameters. For each candidate
            model <span class="ca-m"><i>m</i></span>,
            <span class="ca-eq ca-math">
              AIC<sub>m</sub><span class="op">=</span>2<i>k</i><sub>m</sub><span class="op">&minus;</span>2&#8201;log&#8201;<span class="ca-hat it">L</span><sub>m</sub>
            </span>
            where <span class="ca-m"><span class="ca-hat it">L</span><sub>m</sub></span> is the
            maximised likelihood and <span class="ca-m"><i>k</i><sub>m</sub></span> the number of
            free parameters. For right-censored data the log-likelihood is
            <span class="ca-eq ca-math">
              log&#8201;<i>L</i><span class="op">=</span>&#8721;<sub class="up">i&#8201;=&#8201;1</sub><sup>n</sup>
              <span class="br">&#123;</span><i>d</i><sub>i</sub>&#8201;log&#8201;<i>f</i><span class="br">(</span><i>y</i><sub>i</sub><span class="br">)</span>
              <span class="op">+</span>
              <span class="br">(</span>1<span class="op">&minus;</span><i>d</i><sub>i</sub><span class="br">)</span>&#8201;log&#8201;<i>S</i><span class="br">(</span><i>y</i><sub>i</sub><span class="br">)</span><span class="br">&#125;</span>
            </span>
          </dd>

          <dt>The candidate set</dt>
          <dd>
            Four shapes for the event times — exponential, Weibull, gamma and log-logistic.
            Each is fitted twice. Without a cured group the survival function is
            <span class="ca-m"><i>S</i><span class="br">(</span><i>t</i><span class="br">)</span><span class="op">=</span><i>S</i><sub>u</sub><span class="br">(</span><i>t</i><span class="opt">;</span>&#8201;<i>&theta;</i><span class="br">)</span></span>.
            With a cured group it is the mixture
            <span class="ca-eq ca-math">
              <i>S</i><span class="br">(</span><i>t</i><span class="br">)</span><span class="op">=</span><i>&pi;</i><span class="op">+</span><span class="br">(</span>1<span class="op">&minus;</span><i>&pi;</i><span class="br">)</span>&#8201;<i>S</i><sub>u</sub><span class="br">(</span><i>t</i><span class="opt">;</span>&#8201;<i>&theta;</i><span class="br">)</span><span class="opt">,</span>&emsp;<i>&pi;</i><span class="op">&#8712;</span><span class="br">[</span>0<span class="opt">,</span>&#8201;1<span class="br">]</span>
            </span>
            which carries one extra free parameter. A fifth shape, the lognormal, can be
            added; it is off by default because its heavy tail can move both the ranking
            and the remaining-uncured ratio.
          </dd>

          <dt>Symbols</dt>
          <dd>
            <div class="ca-syms">
              <div><span class="ca-m"><i>&pi;</i></span><span>the cure fraction — the share of the population that will never experience the event</span></div>
              <div><span class="ca-m"><i>S</i><sub>u</sub><span class="br">(</span><i>t</i><span class="br">)</span></span><span>the latency survival function: survival of the uncured, falling from 1 to 0</span></div>
              <div><span class="ca-m"><i>&theta;</i></span><span>the shape and scale parameters of the latency distribution</span></div>
              <div><span class="ca-m"><i>y</i><sub>i</sub><span class="opt">,</span>&#8201;<i>d</i><sub>i</sub></span><span>the observed time for subject <span class="ca-m"><i>i</i></span> and its indicator, 1 for an event and 0 for censoring</span></div>
              <div><span class="ca-m"><i>n</i></span><span>the number of subjects</span></div>
            </div>
          </dd>

          <dt>Direction</dt>
          <dd>
            Smaller AIC is the better description. Evidence <em>for</em> a cure fraction is
            the smallest-AIC model being one of the four with a cured group. Note what this
            is not: a smaller AIC says a cure model describes the observed data better, not
            that the cure fraction is identifiable from them. That second question is what
            the follow-up readings and the ratio of censored uncured subjects answer.
          </dd>

          <dt>Decision rule</dt>
          <dd>
            Rank every candidate by AIC and take the smallest. There is no threshold, no
            significance level and no sample-size dependence — it is a ranking, not a test.
            If the winner is a model without a cured group, the conclusion is that a cure
            model is not appropriate. If the winner has a cured group, the smallest-AIC
            <em>cure</em> model supplies the distribution used for the ratio of censored
            uncured subjects.
          </dd>

          <dt>What is implemented here</dt>
          <dd>
            The ranking only. No minimum AIC gap is required — the common
            “<span class="ca-m">&Delta;</span>AIC<span class="ca-m"><span class="op">&gt;</span>2</span>”
            convention is not applied, so a cure model that wins by 0.3 wins outright, and
            a near-tie is visible in the table rather than resolved by a rule. There is no
            bootstrap, no likelihood-ratio test between the nested pair, and no correction
            for the cure fraction lying on the boundary of its parameter space. Ties are
            broken by table order.
          </dd>

          <dt>When it cannot be computed</dt>
          <dd>
            An individual fit can fail to converge — too few events, a flat likelihood in
            the cure fraction, or an estimate driven to the boundary. That model keeps its
            row, carries the reason it failed, and sorts last; it is never hidden, because
            which models failed is itself informative. If every fit fails there is no
            ranking and the assessment stops.
          </dd>

          <dt>Source</dt>
          <dd>
            Akaike H (1974). A new look at the statistical model identification.
            Model screening as the first stage of cure model assessment follows
            Selukar &amp; Othus (2023), §2.4.
          </dd>

        </dl>
      </div>
    </details>
  </article>


  <!-- ===================================================================== -->
  <!-- 2. MALLER-ZHOU                                                        -->
  <!-- ===================================================================== -->
  <article class="ca-method">
    <h3>Maller&ndash;Zhou statistic</h3>
    <p class="ca-method__lead">
      Did follow-up run far enough past the last event for a flat tail to mean something?
      The reading looks at a window at the end of the data, as wide as the quiet gap
      between the last event and the end of follow-up, and asks how many events fall in it.
      A long quiet gap preceded by events is what sufficient follow-up looks like.
    </p>

    <details class="ca-more">
      <summary>Definition, direction and decision rule</summary>
      <div class="ca-more__body">
        <dl class="ca-def">

          <dt>What it measures</dt>
          <dd>
            The separation between the largest event time and the end of follow-up,
            expressed as the number of events falling within one gap-width of the last
            event. It targets the condition
            <span class="ca-m"><i>&tau;</i><sub class="up">F<sub>0</sub></sub><span class="op">&lt;</span><i>&tau;</i><sub class="up">G</sub></span>
            — that the event-time distribution of the uncured is exhausted before censoring
            runs out — against the null
            <span class="ca-m"><i>&tau;</i><sub class="up">F<sub>0</sub></sub><span class="op">&#8805;</span><i>&tau;</i><sub class="up">G</sub></span>.
          </dd>

          <dt>Definition</dt>
          <dd>
            Let <span class="ca-m"><i>Y</i><sup class="up">*</sup></span> be the largest event
            time and <span class="ca-m"><i>Y</i><sub class="up">max</sub></span> the largest
            observed time, event or censored. The plateau length is the gap
            <span class="ca-m"><i>Y</i><sub class="up">max</sub><span class="op">&minus;</span><i>Y</i><sup class="up">*</sup></span>,
            and the window is that same width laid back from the last event:
            <span class="ca-eq ca-math">
              <span class="br">(</span>&#8201;2<i>Y</i><sup class="up">*</sup><span class="op">&minus;</span><i>Y</i><sub class="up">max</sub><span class="opt">,</span>&emsp;<i>Y</i><sup class="up">*</sup>&#8201;<span class="br">]</span>
            </span>
            With <span class="ca-m"><i>N</i><sub>n</sub></span> the number of events in that
            window, the statistic is
            <span class="ca-eq ca-math">
              <i>&alpha;</i><sub>n</sub><span class="op">=</span>
              <span class="br">(</span>1<span class="op">&minus;</span><i>N</i><sub>n</sub><span class="opt">&#8201;/&#8201;</span><i>n</i><span class="br">)</span><sup>n</sup>
            </span>
          </dd>

          <dt>Symbols</dt>
          <dd>
            <div class="ca-syms">
              <div><span class="ca-m"><i>Y</i><sup class="up">*</sup></span><span>largest observed <em>event</em> time</span></div>
              <div><span class="ca-m"><i>Y</i><sub class="up">max</sub></span><span>largest observed time of any kind — the end of follow-up in the data</span></div>
              <div><span class="ca-m"><i>N</i><sub>n</sub></span><span>number of events falling in the window above</span></div>
              <div><span class="ca-m"><i>n</i></span><span>the number of subjects</span></div>
              <div><span class="ca-m"><i>&tau;</i><sub class="up">F<sub>0</sub></sub></span><span>the earliest time by which every uncured subject has had the event</span></div>
              <div><span class="ca-m"><i>&tau;</i><sub class="up">G</sub></span><span>the latest time the censoring distribution can reach</span></div>
            </div>
          </dd>

          <dt>Direction</dt>
          <dd>
            <strong>Smaller is better.</strong> A small value means many events sit inside a
            window that is narrow relative to the observed span, which is to say the events
            finished well before follow-up did. Large values mean events were still arriving
            when observation stopped, and a flat tail cannot be distinguished from a study
            that ended too early.
          </dd>

          <dt>Decision rule</dt>
          <dd>
            Follow-up is declared sufficient when
            <span class="ca-m"><i>&alpha;</i><sub>n</sub><span class="op">&lt;</span>0.05</span>.
            The threshold is the fixed level 0.05 and does not move with sample size — but
            the statistic itself is an <span class="ca-m"><i>n</i></span>-th power, so the
            <em>number of events</em> the rule demands is close to constant: for any
            <span class="ca-m"><i>n</i><span class="op">&#8805;</span>4</span>, the rule is
            satisfied exactly when three or more events fall in the window.
          </dd>

          <dt>What is implemented here</dt>
          <dd>
            The closed form above and the fixed 0.05 level, and nothing else. There is no
            simulated critical-value table, no exact finite-sample calibration and no
            bootstrap. The reading applies to one homogeneous group: it takes no covariates,
            no strata and no treatment arms, so a dataset spanning several arms must be
            split before it is read, never pooled.
          </dd>

          <dt>It is the same decision as the <span class="ca-m"><i>q</i><sub>n</sub></span> reading</dt>
          <dd>
            The two are one decision shown twice, because
            <span class="ca-m"><i>&alpha;</i><sub>n</sub><span class="op">=</span><span class="br">(</span>1<span class="op">&minus;</span><i>q</i><sub>n</sub><span class="br">)</span><sup>n</sup></span>
            exactly, on the same window and the same event count. The map is strictly
            decreasing, so they cannot disagree and must never be read as two independent
            votes. See the next block.
          </dd>

          <dt>When it cannot be computed</dt>
          <dd>
            When the largest observed time is an event — that is,
            <span class="ca-m"><i>Y</i><sub class="up">max</sub><span class="op">=</span><i>Y</i><sup class="up">*</sup></span>.
            The gap is then zero, the window collapses to a point, and there is no observed
            stretch beyond the last event to measure. This is not a failure to converge; it
            is the absence of the thing being measured. All three follow-up readings become
            unavailable together, for the same reason and on exactly the same data.
          </dd>

          <dt>Source</dt>
          <dd>
            Maller RA, Zhou S (1994). Testing for sufficient follow-up and outliers in
            survival data. <em>Journal of the American Statistical Association</em>,
            89(428), 1499&ndash;1506 — their equation (5). See also Maller RA, Zhou X (1996),
            <em>Survival Analysis with Long-Term Survivors</em>, Wiley.
          </dd>

        </dl>
      </div>
    </details>
  </article>


  <!-- ===================================================================== -->
  <!-- 3. qn                                                                 -->
  <!-- ===================================================================== -->
  <article class="ca-method">
    <h3><span class="ca-m"><i>q</i><sub>n</sub></span> statistic</h3>
    <p class="ca-method__lead">
      The same question as above, read on a scale that stays legible. It reports the share
      of the sample whose events fall in that end-of-data window, rather than raising it to
      the power <span class="ca-m"><i>n</i></span>. Larger is better here — the opposite of
      the other two readings — and its threshold moves with sample size.
    </p>

    <details class="ca-more">
      <summary>Definition, direction and decision rule</summary>
      <div class="ca-more__body">
        <dl class="ca-def">

          <dt>What it measures</dt>
          <dd>
            The proportion of the sample whose events fall in the late window — a direct
            reading of how many events the quiet tail is standing on. It uses the identical
            window and the identical event count as the Maller&ndash;Zhou reading, on the
            untransformed scale.
          </dd>

          <dt>Definition</dt>
          <dd>
            With <span class="ca-m"><i>Y</i><sup class="up">*</sup></span> the largest event
            time and <span class="ca-m"><i>Y</i><sub class="up">max</sub></span> the largest
            observed time, the window is again
            <span class="ca-m"><span class="br">(</span>&#8201;2<i>Y</i><sup class="up">*</sup><span class="op">&minus;</span><i>Y</i><sub class="up">max</sub><span class="opt">,</span>&#8201;<i>Y</i><sup class="up">*</sup>&#8201;<span class="br">]</span></span>,
            of width <span class="ca-m"><i>Y</i><sub class="up">max</sub><span class="op">&minus;</span><i>Y</i><sup class="up">*</sup></span>,
            and with <span class="ca-m"><i>N</i><sub>n</sub></span> the events it contains,
            <span class="ca-eq ca-math">
              <i>q</i><sub>n</sub><span class="op">=</span>
              <span class="ca-frac"><span><i>N</i><sub>n</sub></span><span><i>n</i></span></span>
            </span>
          </dd>

          <dt>Symbols</dt>
          <dd>
            <div class="ca-syms">
              <div><span class="ca-m"><i>Y</i><sup class="up">*</sup></span><span>largest observed event time</span></div>
              <div><span class="ca-m"><i>Y</i><sub class="up">max</sub></span><span>largest observed time of any kind</span></div>
              <div><span class="ca-m"><i>N</i><sub>n</sub></span><span>events in the window — the same count the Maller&ndash;Zhou reading uses</span></div>
              <div><span class="ca-m"><i>n</i></span><span>the number of subjects</span></div>
            </div>
          </dd>

          <dt>Direction</dt>
          <dd>
            <strong>Larger is better</strong>, and this is the one reading that runs that
            way. A long plateau produces a wide window, a wide window captures many events,
            and a high share of events inside it is evidence of sufficient follow-up and of
            a genuine plateau. Small values mean events were still occurring at the end of
            observation, which is weak evidence for a plateau whatever the curve looks like.
          </dd>

          <dt>Decision rule, and how the threshold moves with <span class="ca-m"><i>n</i></span></dt>
          <dd>
            Follow-up is declared sufficient when
            <span class="ca-eq ca-math">
              <i>q</i><sub>n</sub><span class="op">&gt;</span>1<span class="op">&minus;</span>0.05<sup class="up">1&#8201;/&#8201;<i>n</i></sup>
            </span>
            The threshold falls as the sample grows, because the same <em>share</em> of a
            larger sample is a larger number of events:
            <div class="ca-syms">
              <div><span class="ca-m"><i>n</i><span class="op">=</span>100</span><span><span class="ca-m">0.0295</span></span></div>
              <div><span class="ca-m"><i>n</i><span class="op">=</span>250</span><span><span class="ca-m">0.0119</span></span></div>
              <div><span class="ca-m"><i>n</i><span class="op">=</span>500</span><span><span class="ca-m">0.0060</span></span></div>
              <div><span class="ca-m"><i>n</i><span class="op">=</span>1000</span><span><span class="ca-m">0.0030</span></span></div>
              <div><span class="ca-m"><i>n</i><span class="op">=</span>1404</span><span><span class="ca-m">0.0021</span></span></div>
            </div>
            Because
            <span class="ca-m"><i>n</i><span class="br">(</span>1<span class="op">&minus;</span>0.05<sup class="up">1/<i>n</i></sup><span class="br">)</span><span class="op">&#8594;</span><span class="op">&minus;</span>log&#8201;0.05<span class="op">&#8776;</span>2.996</span>
            from below, the rule reduces to the same plain statement as the reading above:
            for any <span class="ca-m"><i>n</i><span class="op">&#8805;</span>4</span>, three or
            more events in the window.
          </dd>

          <dt>The two readings are one decision</dt>
          <dd>
            The Maller&ndash;Zhou statistic and this one are algebraically the same
            quantity. Exactly, on every dataset,
            <span class="ca-eq ca-math">
              <i>&alpha;</i><sub>n</sub><span class="op">=</span>
              <span class="br">(</span>1<span class="op">&minus;</span><i>q</i><sub>n</sub><span class="br">)</span><sup>n</sup>
              <span class="op">&#8660;</span>
              <i>q</i><sub>n</sub><span class="op">=</span>1<span class="op">&minus;</span><i>&alpha;</i><sub>n</sub><sup class="up">1&#8201;/&#8201;<i>n</i></sup>
            </span>
            and since the map is strictly decreasing,
            <span class="ca-m"><i>&alpha;</i><sub>n</sub><span class="op">&lt;</span>0.05</span>
            holds precisely when
            <span class="ca-m"><i>q</i><sub>n</sub><span class="op">&gt;</span>1<span class="op">&minus;</span>0.05<sup class="up">1/<i>n</i></sup></span>.
            They cannot disagree. They are presented as two readings of one decision, on
            two scales, and never as two independent pieces of evidence.
          </dd>

          <dt>What is implemented here — and what is not</dt>
          <dd>
            The rule applied is the <span class="ca-m"><i>&alpha;</i><sub>n</sub></span>-equivalent
            one given above. The exact finite-sample critical values for
            <span class="ca-m"><i>q</i><sub>n</sub></span> derived by Maller, Resnick and
            Shemehsavar (2024) are <strong>not</strong> used, and neither are the simulated
            critical-value tables of Maller &amp; Zhou (1996), which are indexed by sample
            size, censoring proportion and a tail parameter and would require rounding all
            three to the nearest tabulated level. The consequence is worth stating plainly:
            with the published tables this reading would clear a substantially higher bar
            than the threshold above, and would declare sufficient follow-up less often. The
            <span class="ca-m"><i>q</i><sub>n</sub></span> value itself is reported and is
            directionally informative whichever cutoff is used.
          </dd>

          <dt>When it cannot be computed</dt>
          <dd>
            When the largest observed time is an event,
            <span class="ca-m"><i>Y</i><sub class="up">max</sub><span class="op">=</span><i>Y</i><sup class="up">*</sup></span>.
            The window has zero width and there is nothing beyond the last event to
            measure. Unavailable together with the other two follow-up readings.
          </dd>

          <dt>Source</dt>
          <dd>
            Maller RA, Zhou X (1996). <em>Survival Analysis with Long-Term Survivors</em>,
            Wiley. Finite-sample and asymptotic distributions: Maller RA, Resnick S,
            Shemehsavar S (2024). <em>Canadian Journal of Statistics</em>, 52(2),
            359&ndash;379. The decision rule applied here is Maller RA, Zhou S (1994),
            equation (5).
          </dd>

        </dl>
      </div>
    </details>
  </article>


  <!-- ===================================================================== -->
  <!-- 4. SHEN                                                               -->
  <!-- ===================================================================== -->
  <article class="ca-method">
    <h3>Shen statistic</h3>
    <p class="ca-method__lead">
      The same follow-up question, read through a deliberately narrower window. The
      Maller&ndash;Zhou window can declare follow-up sufficient too readily; this one
      shrinks it, so it demands that the events cluster closer to the last event. It is the
      stricter of the two by construction, and it can never be the more optimistic.
    </p>

    <details class="ca-more">
      <summary>Definition, direction and decision rule</summary>
      <div class="ca-more__body">
        <dl class="ca-def">

          <dt>What it measures</dt>
          <dd>
            The same quantity — events in a late window, raised to the power
            <span class="ca-m"><i>n</i></span> — but with the window rescaled by how far the
            last event sits from the end of follow-up, which tightens it when that gap is a
            small fraction of the observed span.
          </dd>

          <dt>Definition</dt>
          <dd>
            Set the weight and the estimated censoring endpoint
            <span class="ca-eq ca-math">
              <i>w</i><span class="op">=</span>
              <span class="ca-frac"><span><i>Y</i><sub class="up">max</sub><span class="op">&minus;</span><i>Y</i><sup class="up">*</sup></span><span><i>Y</i><sub class="up">max</sub></span></span>
              <span class="opt">,</span>&emsp;
              <span class="ca-hat it">&tau;</span><sub class="up">G</sub><span class="op">=</span><i>w</i>&#8201;<i>Y</i><sup class="up">*</sup><span class="op">+</span><span class="br">(</span>1<span class="op">&minus;</span><i>w</i><span class="br">)</span>&#8201;<i>Y</i><sub class="up">max</sub>
            </span>
            The window runs from
            <span class="ca-m"><span class="ca-hat it">&tau;</span><sub class="up">G</sub>&#8201;<i>Y</i><sup class="up">*</sup><span class="opt">&#8201;/&#8201;</span><i>Y</i><sub class="up">max</sub></span>
            up to <span class="ca-m"><i>Y</i><sup class="up">*</sup></span>, inclusive at both
            ends. With <span class="ca-m"><i>N</i><sub>n</sub><sup class="up">S</sup></span>
            the events it contains,
            <span class="ca-eq ca-math">
              <span class="ca-hat it">&alpha;</span><sub>n</sub><span class="op">=</span>
              <span class="br">(</span>1<span class="op">&minus;</span><i>N</i><sub>n</sub><sup class="up">S</sup><span class="opt">&#8201;/&#8201;</span><i>n</i><span class="br">)</span><sup>n</sup>
            </span>
          </dd>

          <dt>How narrow the window is</dt>
          <dd>
            Write
            <span class="ca-m"><i>&rho;</i><span class="op">=</span><i>Y</i><sup class="up">*</sup><span class="opt">&#8201;/&#8201;</span><i>Y</i><sub class="up">max</sub><span class="op">&#8712;</span><span class="br">(</span>0<span class="opt">,</span>&#8201;1<span class="br">]</span></span>.
            Then the window is
            <span class="ca-m"><span class="br">[</span>&#8201;<i>Y</i><sup class="up">*</sup><i>&rho;</i><span class="br">(</span>2<span class="op">&minus;</span><i>&rho;</i><span class="br">)</span><span class="opt">,</span>&#8201;<i>Y</i><sup class="up">*</sup>&#8201;<span class="br">]</span></span>,
            of width
            <span class="ca-m"><i>Y</i><sup class="up">*</sup><span class="br">(</span>1<span class="op">&minus;</span><i>&rho;</i><span class="br">)</span><sup class="up">2</sup></span>.
            Against the Maller&ndash;Zhou window, whose width is
            <span class="ca-m"><i>Y</i><sub class="up">max</sub><span class="op">&minus;</span><i>Y</i><sup class="up">*</sup></span>,
            the ratio of widths is
            <span class="ca-m"><i>&rho;</i><span class="br">(</span>1<span class="op">&minus;</span><i>&rho;</i><span class="br">)</span><span class="op">&#8804;</span>&#188;</span>.
            This window is always contained in the wider one, so
            <span class="ca-m"><i>N</i><sub>n</sub><sup class="up">S</sup><span class="op">&#8804;</span><i>N</i><sub>n</sub></span>
            and therefore
            <span class="ca-m"><span class="ca-hat it">&alpha;</span><sub>n</sub><span class="op">&#8805;</span><i>&alpha;</i><sub>n</sub></span>
            on every dataset. This reading can never declare follow-up sufficient where the
            Maller&ndash;Zhou reading does not; it can and does withhold that conclusion
            where the other grants it.
          </dd>

          <dt>Symbols</dt>
          <dd>
            <div class="ca-syms">
              <div><span class="ca-m"><i>Y</i><sup class="up">*</sup></span><span>largest observed event time</span></div>
              <div><span class="ca-m"><i>Y</i><sub class="up">max</sub></span><span>largest observed time of any kind</span></div>
              <div><span class="ca-m"><i>w</i></span><span>the gap as a fraction of the observed span</span></div>
              <div><span class="ca-m"><span class="ca-hat it">&tau;</span><sub class="up">G</sub></span><span>the estimated endpoint of the censoring distribution</span></div>
              <div><span class="ca-m"><i>&rho;</i></span><span>the last event time as a fraction of the last observed time</span></div>
              <div><span class="ca-m"><i>N</i><sub>n</sub><sup class="up">S</sup></span><span>events in this narrower window</span></div>
            </div>
          </dd>

          <dt>Direction</dt>
          <dd>
            <strong>Smaller is better</strong>, as for the Maller&ndash;Zhou reading. Small
            values support sufficient follow-up.
          </dd>

          <dt>Decision rule</dt>
          <dd>
            Follow-up is declared sufficient when
            <span class="ca-m"><span class="ca-hat it">&alpha;</span><sub>n</sub><span class="op">&lt;</span>0.05</span>.
            The threshold is the fixed level 0.05 and does not move with sample size.
          </dd>

          <dt>What is implemented here</dt>
          <dd>
            The closed form above at the fixed 0.05 level. No simulated or tabulated
            critical values, no asymptotic calibration, no bootstrap. Like the other two, it
            reads one homogeneous group and takes no covariates or strata.
          </dd>

          <dt>When it cannot be computed</dt>
          <dd>
            When the largest observed time is an event,
            <span class="ca-m"><i>Y</i><sub class="up">max</sub><span class="op">=</span><i>Y</i><sup class="up">*</sup></span>.
            The gap is zero, so <span class="ca-m"><i>w</i><span class="op">=</span>0</span>,
            the window collapses, and there is no stretch of follow-up beyond the last event
            to read. Unavailable together with the other two follow-up readings, on the same
            data and for the same reason.
          </dd>

          <dt>Source</dt>
          <dd>
            Shen P-S (2000). Testing for sufficient follow-up in survival data.
            <em>Statistics &amp; Probability Letters</em>, 49(4), 313&ndash;322. In the
            original literature this statistic is written
            <span class="ca-m"><span class="ca-hat it">&alpha;</span><sub>n</sub></span>.
          </dd>

        </dl>
      </div>
    </details>
  </article>


  <!-- ===================================================================== -->
  <!-- 5. RECeUS                                                             -->
  <!-- ===================================================================== -->
  <article class="ca-method">
    <h3>Ratio of censored uncured subjects</h3>
    <p class="ca-method__lead">
      Two questions at once. Is the estimated cure fraction large enough to be worth
      modelling, and by the end of follow-up is the group still event-free made up almost
      entirely of cured patients rather than of patients whose event has simply not happened
      yet? Both must hold. This is the reading the overall recommendation rests on.
    </p>

    <details class="ca-more">
      <summary>Definition, direction and decision rule</summary>
      <div class="ca-more__body">
        <dl class="ca-def">

          <dt>What it measures</dt>
          <dd>
            Not the tail of the observed curve, but two fitted quantities: the cure fraction,
            and the share of the still-event-free mass at the end of follow-up that belongs
            to the uncured. The second is the quantity that makes a cure fraction
            identifiable — if almost none of the uncured are left unresolved, the plateau is
            the cured group and not an artefact of when the study stopped.
          </dd>

          <dt>Definition</dt>
          <dd>
            Under the mixture
            <span class="ca-m"><i>S</i><span class="br">(</span><i>t</i><span class="br">)</span><span class="op">=</span><i>&pi;</i><span class="op">+</span><span class="br">(</span>1<span class="op">&minus;</span><i>&pi;</i><span class="br">)</span>&#8201;<i>S</i><sub>u</sub><span class="br">(</span><i>t</i><span class="br">)</span></span>,
            evaluated at the analysis time <span class="ca-m"><i>&tau;</i></span>, the target is
            <span class="ca-eq ca-math">
              <i>r</i><span class="op">=</span>
              <span class="ca-frac">
                <span><i>S</i><sub>u</sub><span class="br">(</span><i>&tau;</i><span class="br">)</span></span>
                <span><i>S</i><span class="br">(</span><i>&tau;</i><span class="br">)</span></span>
              </span>
              <span class="op">=</span>
              <span class="ca-frac">
                <span><i>S</i><sub>u</sub><span class="br">(</span><i>&tau;</i><span class="br">)</span></span>
                <span><i>&pi;</i><span class="op">+</span><span class="br">(</span>1<span class="op">&minus;</span><i>&pi;</i><span class="br">)</span>&#8201;<i>S</i><sub>u</sub><span class="br">(</span><i>&tau;</i><span class="br">)</span></span>
              </span>
            </span>
            The cure fraction and the shape parameters are estimated by maximum likelihood
            on the right-censored sample, using the smallest-AIC cure model from screening,
            and the estimate is the same expression at the fitted values:
            <span class="ca-eq ca-math">
              <span class="ca-hat it">r</span><span class="op">=</span>
              <span class="ca-frac">
                <span><i>S</i><sub>u</sub><span class="br">(</span><i>&tau;</i><span class="opt">;</span>&#8201;<span class="ca-hat it">&theta;</span><span class="br">)</span></span>
                <span><span class="ca-hat it">&pi;</span><span class="op">+</span><span class="br">(</span>1<span class="op">&minus;</span><span class="ca-hat it">&pi;</span><span class="br">)</span>&#8201;<i>S</i><sub>u</sub><span class="br">(</span><i>&tau;</i><span class="opt">;</span>&#8201;<span class="ca-hat it">&theta;</span><span class="br">)</span></span>
              </span>
            </span>
          </dd>

          <dt>Symbols</dt>
          <dd>
            <div class="ca-syms">
              <div><span class="ca-m"><i>&tau;</i></span><span>the analysis time at which the ratio is read — here the largest observed follow-up time in the data</span></div>
              <div><span class="ca-m"><span class="ca-hat it">&pi;</span></span><span>the estimated cure fraction</span></div>
              <div><span class="ca-m"><span class="ca-hat it">&theta;</span></span><span>the estimated shape and scale of the latency distribution</span></div>
              <div><span class="ca-m"><i>S</i><sub>u</sub><span class="br">(</span><i>&tau;</i><span class="br">)</span></span><span>the fraction of uncured subjects still event-free at <span class="ca-m"><i>&tau;</i></span> — written <span class="ca-m"><i>u</i></span> in the source paper</span></div>
              <div><span class="ca-m"><i>S</i><span class="br">(</span><i>&tau;</i><span class="br">)</span></span><span>the fraction of the whole cohort still event-free at <span class="ca-m"><i>&tau;</i></span></span></div>
              <div><span class="ca-m"><span class="ca-hat it">r</span></span><span>the remaining-uncured ratio: the uncured share of what is left, standardised by the cure fraction and the censoring pattern</span></div>
            </div>
            Two consequences follow from the definition and are worth holding on to. If the
            cure fraction is zero then
            <span class="ca-m"><i>r</i><span class="op">=</span>1</span> whatever the
            follow-up, so the ratio is at its worst possible value exactly when there is
            nothing to model. And <span class="ca-m"><i>r</i></span> is not the raw fraction
            of uncured remaining; it is that fraction divided by the total remaining, which
            is what lets a single threshold apply across different cure fractions and
            censoring patterns.
          </dd>

          <dt>Direction</dt>
          <dd>
            For the cure fraction, <strong>larger is better</strong> — a cure fraction away
            from zero is evidence that there is a cured group to model. For the ratio,
            <strong>smaller is better</strong> — a small ratio means little of the uncured
            group is still unresolved, which is evidence of sufficient follow-up. Evidence
            <em>for</em> a cure model requires both at once.
          </dd>

          <dt>Decision rule</dt>
          <dd>
            A cure model is appropriate when
            <span class="ca-eq ca-math">
              <span class="ca-hat it">&pi;</span><span class="op">&gt;</span>0.025
              <span class="op">&nbsp;and&nbsp;</span>
              <span class="ca-hat it">r</span><span class="op">&lt;</span>0.05
            </span>
            Both thresholds are fixed constants from the source paper and do not move with
            sample size. If the first fails, the estimated cure fraction is negligible and
            a cure model is not supported. If the second fails, too large a share of the
            uncured is still censored and follow-up is insufficient to estimate a cure
            fraction reliably. Raising the ratio threshold or lowering the cure-fraction
            threshold would declare cure models appropriate more often, both when that is
            correct and when it is not.
          </dd>

          <dt>What is implemented here</dt>
          <dd>
            Point estimates only. The asymptotic normal distribution of the ratio and the
            associated confidence interval are established in the source paper but are not
            used in the decision — the rule compares two point estimates against two fixed
            constants. The analysis time is fixed at the largest observed follow-up time
            rather than a protocol-specified administrative censoring time. No sensitivity
            analysis across thresholds is run, and no alternative model families are tried
            once screening has chosen one. The family is always the smallest-AIC <em>cure</em>
            family: a model without a cured group would force the cure fraction to zero and
            the ratio to one by construction, which is a restatement of the screening result
            rather than a second reading of it.
          </dd>

          <dt>When it cannot be computed</dt>
          <dd>
            When the maximum-likelihood fit for the chosen family does not converge — too
            few events, a likelihood flat in the cure fraction, or an estimate pinned to the
            boundary. There is then no cure fraction and no ratio, and the decision is
            withheld rather than guessed. Unlike the three follow-up readings, this one does
            <em>not</em> require the largest observed time to be censored, so it remains
            available on data where those three are not.
          </dd>

          <dt>Source</dt>
          <dd>
            Selukar S, Othus M (2023). RECeUS: Ratio estimation of censored uncured
            subjects, a different approach for assessing cure model appropriateness in
            studies with long-term survivors. <em>Statistics in Medicine</em>, 42(3),
            209&ndash;227. The thresholds are those of §2.1; the pairing with AIC model
            screening is §2.4.
          </dd>

        </dl>
      </div>
    </details>
  </article>

</div>
)---"


# ---- §E.3 how the simulated examples are generated (R5) ---------------------

# Contract copy, pasted verbatim. The numbers here and the verified generator
# run in §D are one fact: if either changes, both change. Sample sizes, cure
# fractions, the five analysis times and the two seeds are the values
# builder-sims verified against the regenerated files.
.DOCS_SIMULATION_HTML <- r"---(
<div class="ca-section">
  <h2 class="ca-section__title">How the simulated examples are generated</h2>

  <p class="ca-method__lead">
    Every simulated example comes from the same model the method was published with, so
    its behaviour under each reading is known in advance. Each one is produced by
    committed code from a fixed seed and is reproducible exactly.
  </p>

  <details class="ca-more">
    <summary>The generating model</summary>
    <div class="ca-more__body">
      <dl class="ca-def">

        <dt>Event times</dt>
        <dd>
          Each patient is either cured — with probability <span class="ca-m"><i>&pi;</i></span>,
          and then never has the event — or uncured, in which case the event time is drawn
          from a Weibull distribution with shape 2 and scale 1. The cohort survival
          function is therefore
          <span class="ca-eq ca-math">
            <i>S</i><span class="br">(</span><i>t</i><span class="br">)</span><span class="op">=</span><i>&pi;</i><span class="op">+</span><span class="br">(</span>1<span class="op">&minus;</span><i>&pi;</i><span class="br">)</span>&#8201;<i>S</i><sub>u</sub><span class="br">(</span><i>t</i><span class="br">)</span>
          </span>
        </dd>

        <dt>Cure fractions</dt>
        <dd>
          <span class="ca-m"><i>&pi;</i></span> takes the values 0, 0.10, 0.30, 0.50, 0.60
          and 0.90. The value 0 is included deliberately: with no cured group at all, a
          correct assessment must decline a cure model at every length of follow-up.
        </dd>

        <dt>Length of follow-up</dt>
        <dd>
          Follow-up is set not in time units but by how much of the uncured group is left
          unresolved when the study stops. Write
          <span class="ca-m"><i>u</i><span class="op">=</span><i>S</i><sub>u</sub><span class="br">(</span><i>&tau;</i><span class="br">)</span></span>
          for the fraction of uncured patients still event-free at the analysis time. The
          analysis time <span class="ca-m"><i>&tau;</i></span> is chosen to hit each target
          <span class="ca-m"><i>u</i></span> in 0.25, 0.10, 0.05, 0.01 and 0.001 — the
          75th, 90th, 95th, 99th and 99.9th percentiles of the uncured distribution — then
          rounded to the nearest quarter so the analysis lands at a plausible calendar
          point. That gives analysis dates of 1.25, 1.50, 1.75, 2.25 and 2.75. This
          parameterisation makes follow-up comparable across settings.
        </dd>

        <dt>Accrual and censoring</dt>
        <dd>
          Patients enter uniformly over an accrual period,
          <span class="ca-m"><i>A</i><span class="op">~</span>Unif<span class="br">(</span>0<span class="opt">,</span>&#8201;0.5887<span class="br">)</span></span>,
          the accrual end being half the 75th percentile of the uncured distribution.
          Everyone is followed to the common analysis time
          <span class="ca-m"><i>&tau;</i></span>, so the recorded pair is
          <span class="ca-eq ca-math">
            <i>Y</i><span class="op">=</span>min<span class="br">(</span><i>T</i><span class="opt">,</span>&#8201;<i>&tau;</i><span class="op">&minus;</span><i>A</i><span class="br">)</span>
            <span class="opt">,</span>&emsp;
            <i>D</i><span class="op">=</span><span class="br">1</span><span class="br">&#123;</span><i>T</i><span class="op">&#8804;</span><i>&tau;</i><span class="op">&minus;</span><i>A</i><span class="br">&#125;</span>
          </span>
          and late entrants are censored earlier — the administrative censoring pattern of
          a real trial. One example adds random loss to follow-up on top of that.
        </dd>

        <dt>Sample sizes and seed</dt>
        <dd>
          <span class="ca-m"><i>n</i></span> takes the values 50, 250, 400, 500 and 1000,
          and 300 for the four original examples. Everything is drawn once from seed 2026,
          and seed 11 for those four, so the numbers on this screen are the same for
          everyone, every time. Re-running the data-generation script in the project's
          data-raw folder regenerates every file and re-checks that each one still
          produces the verdict it is listed with.
        </dd>

        <dt>Coverage</dt>
        <dd>
          The set spans the corners deliberately: no cure fraction with short follow-up, no
          cure fraction with long follow-up, a substantial cure fraction with short
          follow-up, and a substantial cure fraction with long follow-up. Three examples
          are generated so that the largest observed time is an <em>event</em> rather than a
          censored observation, which is the case in which all three follow-up readings are
          unavailable — they are included so the behaviour can be seen rather than
          described. The four original examples predate this design and use a flat
          follow-up limit with no staggered entry.
        </dd>

        <dt>Source of the design</dt>
        <dd>
          Selukar S, Othus M (2023), §3.1. The built-in real datasets are public and
          de-identified; where a dataset spans several treatment arms it is restricted to
          one arm, because every reading here applies to a single homogeneous group.
        </dd>

      </dl>
    </div>
  </details>
</div>
)---"


# ---- §E.4 the glossary ------------------------------------------------------

# Contract copy, pasted verbatim; replaces the nine-entry list with thirteen
# entries ordered so each term is defined after the terms it depends on. The
# "Immunes" entry is cut under S10 (no immune branding anywhere on screen); the
# two ideas it carried — that cure is a latent status, and that the label
# describes a shape in the data rather than a clinical promise — are folded
# into the "Cure fraction" entry.
.DOCS_GLOSSARY_HTML <- r"---(
<dl class="ca-def">

  <dt>Mixture cure model</dt>
  <dd>
    A model treating the cohort as a mixture of subjects not susceptible to the event and
    subjects susceptible to it, so that
    <span class="ca-m"><i>S</i><span class="br">(</span><i>t</i><span class="br">)</span><span class="op">=</span><i>&pi;</i><span class="op">+</span><span class="br">(</span>1<span class="op">&minus;</span><i>&pi;</i><span class="br">)</span>&#8201;<i>S</i><sub>u</sub><span class="br">(</span><i>t</i><span class="br">)</span></span>.
    As <span class="ca-m"><i>t</i></span> grows the curve levels off at
    <span class="ca-m"><i>&pi;</i></span> rather than at zero.
  </dd>

  <dt>Cure fraction, <span class="ca-m"><i>&pi;</i></span></dt>
  <dd>
    The proportion of the population not susceptible to the event of interest. On a
    Kaplan&ndash;Meier plot it is the height at which the curve would settle. Cure is a
    latent status — no subject is observed to be cured — so the term describes a shape in
    the data, not a clinical promise.
  </dd>

  <dt>Susceptibles, or uncured</dt>
  <dd>
    The subjects who will experience the event if followed long enough. Their share of the
    population is <span class="ca-m">1<span class="op">&minus;</span><i>&pi;</i></span>.
  </dd>

  <dt>Latency distribution, <span class="ca-m"><i>S</i><sub>u</sub><span class="br">(</span><i>t</i><span class="br">)</span></span></dt>
  <dd>
    The survival function of the event times among the uncured alone. It falls from 1 to 0;
    all the levelling-off in the cohort curve comes from the cure fraction, never from this.
  </dd>

  <dt>Right-censoring</dt>
  <dd>
    A subject whose event was never observed: the record says only that the event had not
    occurred when observation stopped. Loss to follow-up, withdrawal and the administrative
    end of the study all produce right-censored records.
  </dd>

  <dt>Administrative censoring</dt>
  <dd>
    Censoring caused by the analysis happening at a fixed calendar time
    <span class="ca-m"><i>&tau;</i></span>, so that a subject accrued at time
    <span class="ca-m"><i>A</i></span> is observed for at most
    <span class="ca-m"><i>&tau;</i><span class="op">&minus;</span><i>A</i></span>. Late
    entrants are censored earliest.
  </dd>

  <dt>Plateau</dt>
  <dd>
    The flat run above zero at the right-hand end of a Kaplan&ndash;Meier estimate. It is
    the visual signature of a cure fraction, and it is also what heavy censoring produces
    when the cure fraction is in fact zero. Distinguishing the two is the whole problem.
  </dd>

  <dt><span class="ca-m"><i>&tau;</i><sub class="up">F<sub>0</sub></sub></span> and <span class="ca-m"><i>&tau;</i><sub class="up">G</sub></span></dt>
  <dd>
    The earliest time by which the event-time distribution of the uncured reaches 1 — every
    susceptible subject has had the event — and the corresponding endpoint of the censoring
    distribution. The classical condition for assessing a cure fraction is
    <span class="ca-m"><i>&tau;</i><sub class="up">F<sub>0</sub></sub><span class="op">&lt;</span><i>&tau;</i><sub class="up">G</sub></span>:
    the longest event times of the uncured must not be hidden by censoring.
  </dd>

  <dt>Sufficient follow-up</dt>
  <dd>
    Observation continued past the point at which the uncured were exhausted, so the
    subjects still event-free at the end are the cured ones. With shorter follow-up a cured
    subject and a subject who would relapse next year leave identical records, and no
    estimator can separate them.
  </dd>

  <dt>Proportion of uncured remaining, <span class="ca-m"><i>u</i></span></dt>
  <dd>
    <span class="ca-m"><i>u</i><span class="op">=</span><i>S</i><sub>u</sub><span class="br">(</span><i>&tau;</i><span class="br">)</span></span>,
    the fraction of susceptible subjects who have not yet had the event at the analysis
    time. It is latent and cannot be observed; it is how the length of follow-up is
    parameterised in simulation, and 0.1&ndash;0.2% is the conventional standard for
    follow-up long enough to fit a cure model in practice.
  </dd>

  <dt>Remaining-uncured ratio, <span class="ca-m"><i>r</i></span></dt>
  <dd>
    <span class="ca-m"><i>u</i></span> standardised by the total still event-free at the
    analysis time,
    <span class="ca-m"><i>r</i><span class="op">=</span><i>S</i><sub>u</sub><span class="br">(</span><i>&tau;</i><span class="br">)</span><span class="opt">&#8201;/&#8201;</span><i>S</i><span class="br">(</span><i>&tau;</i><span class="br">)</span></span>.
    The standardisation absorbs the cure fraction and the censoring pattern, so one
    threshold serves across settings. It equals 1 when the cure fraction is zero.
  </dd>

  <dt>Largest event time and largest observed time</dt>
  <dd>
    <span class="ca-m"><i>Y</i><sup class="up">*</sup></span> and
    <span class="ca-m"><i>Y</i><sub class="up">max</sub></span>. The gap between them is the
    observed stretch of follow-up beyond the last event, and it is the raw material of all
    three follow-up readings. When the gap is zero, none of them exists.
  </dd>

  <dt>AIC</dt>
  <dd>
    Akaike's information criterion,
    <span class="ca-m">2<i>k</i><span class="op">&minus;</span>2&#8201;log&#8201;<span class="ca-hat it">L</span></span>:
    a ranking of how well each candidate describes the data at hand, penalised for the
    number of free parameters. Smaller is better; there is no threshold and it is not a test.
  </dd>

</dl>
)---"


# ---- panel: data and ethics -------------------------------------------------

# The count is the registry's: nineteen built-in examples, three of them real
# trial data and sixteen simulated (§D.1).
.DOCS_DATA_ETHICS <- c(
  "The built-in examples are public, de-identified datasets, plus sixteen simulated scenarios generated in this repository. No patient-identifiable data ships with this app.",
  "A file you upload is read into this session on this machine only. Nothing is transmitted and nothing is written to disk."
)


# ---- references -------------------------------------------------------------

# A plain list, and the last thing on the page. Eleven entries, in this order.
# This list and the package-link block beside the QR code are the only C1
# exemptions in the app. Entries 6, 7 and 10 supported the deleted "If
# follow-up is too short" panel and stay: the list is now the tab's only
# bibliographic record, and a reference costs no visible words (§E.5.1).
.DOCS_REFERENCES <- c(
  "Maller RA, Zhou S (1992). Estimating the proportion of immunes in a censored sample. Biometrika, 79(4), 731\u2013739. doi:10.1093/biomet/79.4.731",
  "Maller RA, Zhou S (1994). Testing for sufficient follow-up and outliers in survival data. Journal of the American Statistical Association, 89(428), 1499\u20131506. doi:10.1080/01621459.1994.10476889",
  "Maller RA, Zhou S (1995). Testing for the presence of immune or cured individuals. Biometrics, 51, 1197\u20131205. doi:10.2307/2533253",
  "Maller RA, Zhou X (1996). Survival Analysis with Long-Term Survivors. Wiley.",
  "Shen P-S (2000). Testing for sufficient follow-up in survival data. Statistics & Probability Letters, 49(4), 313\u2013322. doi:10.1016/S0167-7152(00)00063-8",
  "Escobar-Bach M, Van Keilegom I (2019). Non-parametric cure rate estimation under insufficient follow-up by using extremes. Journal of the Royal Statistical Society Series B, 81(5), 861\u2013880.",
  "Othus M, Bansal A, Koepl L, Wagner S, Ramsey S (2020). Bias in mean survival from fitting cure models with limited follow-up. Value in Health, 23(8), 1034\u20131039.",
  "Selukar S, Othus M (2023). RECeUS: Ratio estimation of censored uncured subjects, a different approach for assessing cure model appropriateness in studies with long-term survivors. Statistics in Medicine, 42(3), 209\u2013227. doi:10.1002/sim.9610",
  "Maller RA, Resnick S, Shemehsavar S (2024). Finite sample and asymptotic distributions of a statistic for sufficient follow-up in cure models. Canadian Journal of Statistics, 52(2), 359\u2013379. doi:10.1002/cjs.11771",
  "Yuen TP, Musta E (2024). Testing for sufficient follow-up in survival data with a cure fraction. arXiv:2403.16832.",
  "Mudunkotuwa G, Ghosh D, Triplett B, Selukar S. A Tutorial for Evaluating Cure Model Appropriateness (in preparation)."
)


# =============================================================================
# SECTIONS — the one shared entry point (§F.3)
# =============================================================================

#' Every Documentation section, in reading order, with no page chrome.
#'
#' FINAL_CONTRACT D1 — the Glossary and the Data-and-ethics accordion is now
#' FIRST, above "The three checks". Everything below it keeps the order §E.5.2
#' fixed: the method blocks, then the simulated-data section, then the QR block,
#' then the reference list LAST, with nothing rendered after it. This is a
#' re-ordering of existing tagList elements and nothing else — the accordions'
#' own contents, titles and `open = FALSE` state are unchanged, and the
#' mathematics still sets in HTML and unicode with no network (C5).
#'
#' The depth sits behind closed disclosures: the three checks, the glossary and
#' the data-and-ethics note are closed accordion panels, and every method's
#' definitions, symbols, thresholds and limits are behind a closed
#' <details class="ca-more">. Only the lead paragraphs are visible by default.
#'
#' @return an htmltools::tagList, safe to drop into any container.
ca_docs_sections <- function() {

  htmltools::tagList(

    htmltools::div(
      class = "ca-section",
      bslib::accordion(
        open = FALSE, multiple = TRUE,

        bslib::accordion_panel(
          title = "Glossary", value = "glossary",
          # §E.4 — thirteen entries, in dependency order.
          htmltools::HTML(.DOCS_GLOSSARY_HTML)
        ),

        bslib::accordion_panel(
          title = "Data and ethics", value = "data_ethics",
          htmltools::tags$div(
            class = "ca-card__body",
            lapply(.DOCS_DATA_ETHICS, htmltools::tags$p)
          )
        )
      )
    ),

    htmltools::div(
      class = "ca-section",
      bslib::accordion(
        open = FALSE, multiple = TRUE,
        bslib::accordion_panel(
          title = "The three checks", value = "checks",
          htmltools::tags$div(
            class = "ca-card__body",
            lapply(.DOCS_CHECKS, function(s) {
              htmltools::tags$p(htmltools::tags$strong(s[[1]]), " \u2014 ", s[[2]])
            })
          )
        )
      )
    ),

    # §E.2 — the five readings, in the order the assessment applies them.
    htmltools::HTML(.DOCS_METHODS_HTML),

    # §E.3 — R5.
    htmltools::HTML(.DOCS_SIMULATION_HTML),

    # The QR block, immediately above References. The target is CA_PACKAGE_URL
    # (helpers.R) and is hard-coded nowhere else; the label says "the package"
    # because the CRAN submission is still pending.
    htmltools::div(
      class = "ca-section",
      htmltools::div(
        class = "ca-qr",
        htmltools::tags$a(
          href = CA_PACKAGE_URL, target = "_blank", rel = "noopener",
          htmltools::tags$img(
            src = "img/cureassess-qr.svg", class = "ca-qr__img",
            alt = "QR code linking to the package."
          )
        ),
        htmltools::tags$div(
          # The package name is spelled out only in the reference list; here the
          # QR link beside this line already identifies what is attributed.
          htmltools::tags$p("MIT licensed. Authors Geethanjalee Mudunkotuwa and Durbadal Ghosh."),
          htmltools::tags$p("Scan for the package.")
        )
      )
    ),

    # LAST. Nothing is rendered below this (§E.5.2).
    htmltools::div(
      class = "ca-section",
      htmltools::tags$h2(class = "ca-section__title", "References"),
      htmltools::tags$ul(lapply(.DOCS_REFERENCES, htmltools::tags$li))
    )
  )
}


# =============================================================================
# UI
# =============================================================================

#' Documentation tab UI. Static; renders at every status, including "empty".
#'
#' The tab's chrome is the page title and one lede line; everything else is
#' ca_docs_sections(). Nothing is clickable except the QR link, the accordion
#' titles and the disclosure summaries.
mod_docs_ui <- function(id) {
  ns <- NS(id)

  htmltools::tagList(

    htmltools::div(
      class = "ca-section",
      htmltools::tags$h1(class = "ca-section__title", "Documentation"),
      htmltools::tags$p(
        class = "ca-lede",
        "This app decides whether a cure model is appropriate for right-censored survival data. It does not fit your final model and it does not estimate treatment effects."
      )
    ),

    ca_docs_sections()
  )
}


# =============================================================================
# SERVER
# =============================================================================

#' Documentation tab server.
#'
#' Nothing to do: the tab is static, it writes nothing to `state`, it reads
#' nothing from `state`, and it has no controls. `state` and `go_to` stay in the
#' signature because the module contract fixes it.
mod_docs_server <- function(id, state, go_to) {
  moduleServer(id, function(input, output, session) {
    invisible(NULL)
  })
}
