# Employee & Workforce Analytics
## Executive Business Report | 2021–2025

**Purpose:** Workforce stability, retention exposure, compensation positioning, and management decisions  
**Audience:** Business leaders, HR leadership, People Operations, Finance, and workforce planning stakeholders  
**Data:** Fictional U.S. organization; **synthetic workforce simulation**, not records from an actual employer  
**Reporting period:** January 2021–December 2025

> **Executive interpretation.** This report describes what occurred inside a simulated workforce and how a management team *could* use these signals to prioritize investigation. It is not evidence that the reported patterns generalize to real employees or prove that any management intervention will reduce turnover.

---

## Executive decision brief

The organization finishes 2025 with **meaningfully lower employee turnover than at the beginning of the observation period**, but that improvement does not eliminate uneven workforce exposure. Across five years, **3,539 employees separated**, with the annual turnover rate declining from **16.27% in 2021 to 12.42% in 2025**—a **3.85-percentage-point improvement**. Voluntary departures account for most of the separation volume. At the same time, employees early in organizational tenure, employees in entry-level roles, and employees in relatively low compensation positions exhibit higher departure rates.

The management opportunity is not to launch a single, company-wide retention initiative. It is to **target a small number of measurable workforce conditions**, verify the quality of the supporting data, and test whether actions improve outcomes over time.

### Leadership scorecard

| Business indicator | Observed result | Management interpretation |
|---|---:|---|
| Five-year recorded separations | **3,539** | Material replacement and continuity exposure |
| Annual turnover, 2021 → 2025 | **16.27% → 12.42%** | Improvement, with room to sustain and explain it |
| Voluntary / involuntary separations | **2,777 / 762** | Most departures were voluntary in the validated cohort |
| December 2025 observed active workforce | **4,867** | Operational monthly headcount measure |
| End-of-period active status, employee records | **4,891** | Differs from December snapshot by **24**; reconciliation required |
| December 2025 mean / median annual base salary | **$99,861 / $88,600** | Workforce compensation baseline; not take-home earnings |
| December 2025 annualized base-salary total | **$486.0 million** | Base pay only; excludes benefits, incentives, and employer taxes |
| Strongest organizational-tenure turnover segment | **1–3 years: 20.66% annualized** | Prioritize early-career / early-tenure experience |

## 1. Workforce trajectory: recovery with an unresolved headcount difference

The monthly active workforce declined from **4,923 in January 2021** to a low of **4,669 in April 2022**, before recovering to **4,867 in December 2025**. The final observed count remained **56 people (1.14%) below** the first monthly observation. This is not evidence of continuous shrinkage: the most recent year shows a higher average workforce and a clear recovery during its second half.

![Monthly active workforce headcount, 2021–2025](images/15_monthly_workforce_headcount.png)

*Figure 1. Active-employee counts recorded in monthly workforce snapshots. These are observed monthly counts, not a count of everyone ever employed.*

A separate end-of-period employee-status source records **4,891 active employees**, compared with **4,867 in the December monthly snapshot**. The **24-person difference** must remain visible in management reporting until resolved; otherwise reports using different source tables may display apparently contradictory headcounts. It is not appropriate to silently replace one number with the other.

**Business implication:** Use one explicitly named operational headcount definition for dashboard trends, while maintaining a reconciliation log to the employee master. Headcount alone cannot establish whether replacement hiring, retention, or organizational expansion caused a particular change.

## 2. Employee turnover: improvement is led by fewer voluntary exits

Annual separations fell from **780 in 2021** to **600 in 2025**. The associated annual turnover rate moved from **16.27% to 12.42%**, despite some fluctuation between years. The decline between 2024 and 2025 is especially notable (**15.31% → 12.42%**).

![Annual employee turnover trend](images/01_annual_turnover_trend.png)

*Figure 2. Annual separations divided by average observed monthly active headcount.*

The composition of the change matters. Voluntary turnover decreased from **12.66% in 2021** to **9.59% in 2025**; involuntary turnover decreased from **3.61%** to **2.84%**. Among validated separations, voluntary departures represent **2,777 of 3,539**, approximately **78.5%**.

![Voluntary and involuntary turnover rates](images/02_voluntary_involuntary_turnover.png)

*Figure 3. Annual voluntary and involuntary exit rates, using the same headcount denominator.*

**Business implication:** It would be useful to understand what changed in 2025—staffing mix, compensation positioning, manager practices, or another simulated workforce condition—before attributing the improvement to any one factor. The model shows an association with the calendar year even after adjustment, but does **not** establish a causal explanation.

## 3. Where retention exposure is concentrated

### Early organizational tenure is the clearest planning priority

The annualized turnover rate was **19.44%** in the first year, **20.66%** among employees with one to three years of tenure, and **10.44%** for employees with ten or more years. The one-to-three-year segment therefore showed nearly double the rate of the longest-tenured group.

![Employee turnover by organizational tenure](images/04_turnover_by_tenure.png)

*Figure 4. Annualized observed separation rates by organizational-tenure segment.*

This pattern suggests a management question: **what happens after initial onboarding, as employees move into their second and third years?** Possible areas for review include manager check-ins, role clarity, development discussions, work design, and compensation expectations. These are hypotheses for follow-up, not proven explanations.

### Role level and department reveal different types of exposure

Entry-level employees had the highest clearly supported job-level turnover rate: **L1 at 19.86%**, versus **L3 at 12.51%** and **L4 at 10.48%**. Very senior levels contain too few observations for stable comparisons.

![Employee turnover by job level](images/03_turnover_by_job_level.png)

*Figure 5. Annualized turnover varies substantially by level; interpret small executive-level groups cautiously.*

Department comparisons distinguish **rate** from **volume**. Human Resources had the highest departmental turnover rate (**15.97%**), but Operations generated the largest number of exits (**859**). A department with a relatively modest rate may still impose the greater recruitment and service-continuity burden because it is much larger.

![Annualized employee turnover by department](images/09_turnover_by_department.png)

*Figure 6. Percentage-based comparisons should be paired with absolute exit counts when allocating resources.*

**Business implication:** Establish two prioritization tracks. Target high **rates** for localized diagnosis and high **volumes** for capacity planning. Avoid ranking teams on percentages alone.

## 4. Compensation positioning: the relationship is consistent, not sufficient on its own

A **compa-ratio** compares base salary with the midpoint of the employee's modeled pay band; **1.00** indicates the midpoint. In the monthly pre-exit analysis, workers positioned below **0.80** had a next-month separation rate of **1.53%**, compared with **0.96%** among workers at **1.10 or above**.

![Turnover by compensation positioning](images/05_turnover_by_compa_ratio.png)

*Figure 7. Monthly next-month separation rates by compensation-to-midpoint group.*

These differences persist in the adjusted statistical analysis, although they become smaller after accounting for other observed characteristics. **Lower compensation positioning is therefore a useful review signal, not proof that raising pay would prevent an exit.** The salary midpoint itself varies by job family, level, and location, so compa-ratio is more comparable than raw salary across dissimilar roles.

Meanwhile, December 2025 mean base salary was **$99,861**, up from **$91,998** in January 2021—an **8.55% increase in the workforce average**. This is a comparison of two different monthly workforce populations; it must **not** be described as an 8.55% raise for a typical employee.

![Mean and median monthly salary trend](images/11_monthly_salary_trend.png)

*Figure 8. Changes in workforce-average salary reflect both changes for continuing employees and changes in workforce composition.*

A reconciliation of average-salary movements confirms that entry and exit composition matters. The simulation also implements annual salary adjustments in April; the concentration of pay changes in that month is **part of the simulation design**, not an independent discovery about company policy.

**Business implication:** Review pay positioning within comparable job families and locations, focus on employees with sustained low relative positioning, and assess whether adjustments are targeted and affordable. Decisions should consider performance, level, internal equity, and budget—not compa-ratio alone.

## 5. Performance information: useful, but sensitive to coverage

Employees in the **low-performance category (rating 1–2)** had a **1.83%** observed next-month separation rate, compared with **0.68%** among employees rated above 4. The rate for employee-months with **missing performance information** was also elevated (**1.76%**).

![Turnover by performance rating and missing-rating category](images/06_turnover_by_performance.png)

*Figure 9. The “Missing” category is retained intentionally; it is not interpreted as poor performance.*

The coverage issue is important: roughly **13.77%** of monthly observations have no latest performance rating, and missingness is heavily concentrated among newer employees. An unrated new hire should not be characterized as low-performing or high-risk simply because the annual review cycle has not occurred.

**Business implication:** Build a clear “not yet eligible for rating” status in management reporting and evaluate retention separately from performance-review completion. Performance indicators can help describe patterns but should not be used as automated personnel decisions.

## 6. Time in current role: a development discussion, not a promotion-delay finding

Employees in the **13–24 month** current-role group had a next-month exit rate of **1.58%**, compared with **1.08%** for **25–48 months**. In the adjusted analysis, role tenure of **49+ months** also had higher estimated exit odds than the 25–48-month reference group.

This is **not** evidence that a specific length of time without a promotion causes turnover. In the underlying simulated data, the stored “months since last promotion” field is an exact duplicate of time in current role, so it cannot isolate the effect of promotion timing. It was excluded from the final analytical models in favor of the current-role variable.

**Business implication:** Review expectations and development conversations at key role milestones while reserving conclusions about actual promotion impact for an event-based analysis of promotion history.

## 7. Recommended management agenda

Recommendations below are **illustrative decisions for the fictional organization**, designed to follow naturally from the patterns observed.

| Priority | Management action | Suggested owner | Evidence to monitor |
|---|---|---|---|
| **1 — Early-tenure experience** | Review the 6-, 12-, and 24-month employee experience; compare managers and role families rather than assuming a single cause | HR Business Partners / Operations leads | 12–36-month turnover rate, early exit counts, tenure-segment mix |
| **2 — Pay-positioning review** | Evaluate persistent low compa-ratio groups within comparable jobs, markets, and performance levels | Compensation / Finance | Exit rates by band position; cost of adjustments; internal equity checks |
| **3 — Workload and role clarity** | Investigate high-volume operational teams and role transition points through manager and employee feedback | Operations / People leaders | Exit volume, vacancy pressure, workload and staffing trends |
| **4 — Consistent performance-data coverage** | Separate “not yet rated” from true missing/defective records and monitor review eligibility | HR Operations / HRIS | Rating coverage by tenure and level; unresolved missingness |
| **5 — Headcount reconciliation** | Reconcile monthly snapshot counts to end-of-period employee status before publishing an official dashboard | HRIS / Analytics | Unmatched active IDs; source-of-truth agreement; monthly QA pass rate |

### Proposed execution sequence

**First 30 days — establish a trustworthy baseline.** Validate the 24-person active-count discrepancy and the unmatched separation-history records. Publish consistent definitions for headcount, turnover, compa-ratio, and review eligibility. Identify where early-tenure exits are concentrated by manager and role family.

**Days 31–60 — investigate with business partners.** Review the largest exit-volume teams alongside the highest-rate segments. Use interviews, exit-reason evidence (if available), manager feedback, and pay-band context to test whether the patterns have a plausible operational explanation.

**Days 61–90 — test and measure.** Pilot a small intervention where evidence supports it—for example, a structured 12–24-month career conversation process. Define the comparison population and success measures before launch, and track outcomes without claiming causation from an uncontrolled before/after comparison.

## 8. Governance and limits on decisions

Three findings are material to the reliability of any executive dashboard:

1. **24 employees** labeled active in the final employee status do not appear as active in the December 2025 monthly snapshot.
2. The separation-history source contains **41 employee IDs outside the validated monthly-panel termination cohort**; the validated cohort itself is fully matched.
3. The generator produces identical values for **role tenure** and **months since last promotion** in all **290,014** monthly observations; the second field must not be treated as an independent retention indicator.

The departure model is **not reliable enough to predict which specific employee will leave**. Its results can guide questions about workforce segments, but they should **not** be used for automated targeting or high-stakes decisions about individuals. Full model diagnostics are provided in the companion statistical report.

## 9. Executive conclusion

The simulated organization demonstrates **improving retention by 2025**, alongside persistent differences across tenure, job level, relative pay, and performance-data availability. The most defensible management response is a **targeted measurement and investigation program**—not a blanket claim that one policy will solve turnover. The project also demonstrates why reliable workforce reporting depends on reconciled headcounts, carefully defined analytical measures, and clear separation between observed patterns and causal claims.

---

### Report basis and reproduction

This newly authored business report draws on the executed outputs in `01_workforce_eda_cleaned_v2.ipynb` (Steps 13–65) and the 15 supplied PNG figure names. **PostgreSQL** supports the relational data source; the business-facing report intentionally omits SQL syntax and statistical implementation detail, which are documented in the companion [Statistical Analysis Report](Employee_Workforce_Statistical_Report.md).

All figure paths use the GitHub-compatible relative form `images/<filename>.png`. Place **both `.md` reports next to the `images` directory**; for example, `python_analysis/notebooks/reports/`. Do not replace the original high-resolution PNGs with notebook thumbnails if you already have higher-resolution files.
