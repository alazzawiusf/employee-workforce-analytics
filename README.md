# Employee & Workforce Analytics

**An end-to-end SQL and Python analytics project exploring workforce stability, employee turnover, compensation, and data quality across a five-year simulated organization (2021–2025).**

This project transforms longitudinal HRIS-style records into validated workforce metrics, statistical evidence, visualizations, and management-ready recommendations. It combines relational data preparation in **PostgreSQL** with **Python** for exploratory analysis, hypothesis testing, regression modeling, and reporting.

> **Data disclosure:** All employees, organizational records, and outcomes are **synthetic**. The dataset represents a fictional U.S. organization; it does not contain real employee information or describe any actual employer. Findings are valid for this simulation and should not be generalized to real-world workforces without independent evidence.

## Explore the project

| Deliverable | What it contains |
|---|---|
| [Executive Business Report](python_analysis/notebooks/reports/Employee_Workforce_Executive_Report.md) | Business implications, priorities, workforce risks, and a proposed 90-day management agenda |
| [Statistical & Analytical Report](python_analysis/notebooks/reports/Employee_Workforce_Statistical_Report.md) | Definitions, distributions, statistical tests, adjusted models, uncertainty, and data-quality findings |
| [Python Analysis Notebook](python_analysis/notebooks/01_workforce_eda_cleaned_v2.ipynb) | Data validation, exploration, workforce metrics, statistical modeling, and chart generation |

## Project at a glance

| Measure | Result |
|---|---:|
| Observation period | **January 2021 – December 2025 (60 months)** |
| Unique employees in the simulated population | **8,430** |
| Monthly employee records analyzed | **290,014** |
| Validated separations during the period | **3,539** |
| Voluntary / involuntary separations | **2,777 / 762** |
| Annual turnover rate, 2021 → 2025 | **16.27% → 12.42%** |
| Observed active employees, December 2025 | **4,867** |
| Final active employee-master records | **4,891** |

The difference between the last two headcounts is a documented **24-person source-reconciliation discrepancy**, not a rounding adjustment.

## Business questions

- How did headcount and employee turnover change over five years?
- Which employee segments experienced higher observed separation rates?
- How were compensation positioning, performance information, and time in role associated with subsequent exits?
- How do workforce data-quality issues affect management reporting and interpretation?
- Which findings warrant targeted business investigation rather than unsupported causal claims?

## Selected findings

### 1. Workforce turnover improved by 2025

Annual turnover decreased from **16.27% in 2021 to 12.42% in 2025**, a reduction of **3.85 percentage points**. The trend was not strictly downward every year, and voluntary exits accounted for most recorded departures.

![Annual employee turnover trend](python_analysis/notebooks/reports/images/01_annual_turnover_trend.png)

### 2. Early organizational tenure carried higher observed turnover

Employees with **1–3 years of organizational tenure** had an annualized turnover rate of **20.66%**, compared with **10.44%** for employees with **10+ years**. These descriptive differences suggest where to investigate onboarding, role expectations, and development experiences; they do not establish the causes of departure.

![Turnover by organizational tenure](python_analysis/notebooks/reports/images/04_turnover_by_tenure.png)

### 3. Compensation positioning was associated with next-month exits

Employee-months with a **compa-ratio below 0.80** had a next-month exit rate of **1.53%**, versus **0.96%** at a compa-ratio of **1.10 or above**. Compa-ratio measures base salary relative to the midpoint of the applicable pay band. This pattern is an analytical signal, **not proof that a pay increase would prevent a departure**.

![Turnover by compensation positioning](python_analysis/notebooks/reports/images/05_turnover_by_compa_ratio.png)

### 4. Validation uncovered issues that matter for reporting

The investigation identified three important measurement findings:

- **24** people were active in the final employee master but absent from the December active monthly snapshot.
- The separation-history source included **41** IDs outside the validated termination cohort used in the analysis.
- `role_tenure_months` and `months_since_last_promotion` were **identical across all 290,014 monthly records**. The redundant promotion-timing field was retained for traceability but omitted from final explanatory analysis in favor of role tenure.

These discrepancies were documented rather than silently overwritten. Full checks, methodological constraints, and interpretations are detailed in the [Statistical & Analytical Report](python_analysis/notebooks/reports/Employee_Workforce_Statistical_Report.md).

## Analytical approach

**1. Simulate and organize data.** A Python generation engine creates a fictional organization with employee histories, compensation, reviews, promotions, hiring, and separations. A separate process introduces selected HRIS-style quality defects into copies of the clean tables.

**2. Prepare relational data in PostgreSQL.** The analytical notebook reads employee-month records from the `workforce_analytics` database through the `analytics.vw_employee_monthly` view. Historical separation records provide a second source for reconciliation. The SQL work and database setup are separate from the statistical notebook.

**3. Validate data and definitions.** Check missingness, employee-month integrity, rating coverage, conflicting status counts, unmatched records, and overlapping career measures before interpreting rates.

**4. Explore workforce patterns.** Analyze headcount, annual and exposure-based turnover, job levels, organizational tenure, departments, compensation distributions, and performance-rating coverage.

**5. Evaluate statistical relationships.** Apply group comparisons, employee-cluster bootstrap confidence intervals, an adjusted logistic exit model, and an OLS salary-change model with employee-clustered standard errors.

**6. Communicate findings.** Produce report-ready figures and two complementary deliverables: a decision-focused executive report and a technical statistical report.

### Model interpretation and limitations

The adjusted **next-month all-cause exit model** used **281,608 employee-month observations** and achieved an **in-sample ROC-AUC of 0.632**. That indicates modest discrimination; it is **not a validated employee-level prediction or decision tool**. The multivariable **salary-change regression** had **R² = 0.364** for its analyzed population. Neither model establishes causal effects.

All estimates depend on the simulation assumptions, measurement definitions, model specification, and observed populations. Particular care is needed when comparing annual turnover denominators with employee-month exposure rates or interpreting missing performance ratings among newly hired employees.

## Technology

**PostgreSQL · SQL · Python · pandas · NumPy · SciPy · statsmodels · scikit-learn · Matplotlib · Seaborn · Jupyter Notebook**

Core methods: relational querying, data validation and reconciliation, descriptive statistics, segmentation, Pearson correlation, confidence intervals, cluster-aware inference, logistic regression, OLS regression, and business reporting.

## Repository layout

The links above assume this `README.md` is placed at the root of the `1. workforce_data` project folder.

```text
1. workforce_data/
├── README.md
├── python_analysis/
│   └── notebooks/
│       ├── 01_workforce_eda_cleaned_v2.ipynb
│       └── reports/
│           ├── Employee_Workforce_Executive_Report.md
│           ├── Employee_Workforce_Statistical_Report.md
│           └── images/
│               ├── 01_annual_turnover_trend.png
│               ├── 02_voluntary_involuntary_turnover.png
│               ├── ...
│               └── 16_workforce_correlation_heatmap.png
└── [other project data, generator, and SQL files as published]
```

The reports reference charts using **relative Markdown paths**, so images render on GitHub when the folder structure above is preserved. The final publication set contains **15 numbered figures** (there is no Figure 14).

## Running the analysis

The notebook requires a locally accessible PostgreSQL database named `workforce_analytics`, with a populated `analytics.vw_employee_monthly` view, plus the relevant separation-history CSV. **Uploading the notebook alone does not recreate the SQL database or its data.**

1. Prepare the synthetic workforce data and PostgreSQL objects using the project's data-generation and SQL workflow.
2. Install the Python packages used in the notebook:

   ```bash
   pip install pandas numpy scipy statsmodels scikit-learn matplotlib seaborn psycopg[binary] jupyter
   ```

3. Open `python_analysis/notebooks/01_workforce_eda_cleaned_v2.ipynb` and run it in order. The connection cell prompts for the local PostgreSQL password; check local input-file paths before execution.
4. Generate the PNG figures and keep them alongside the Markdown reports in `python_analysis/notebooks/reports/images/`.

**Publication note:** Do not commit database passwords, local credentials, or private configuration files. The `README.md` describes the analytical workflow; reproducibility also requires publishing the applicable database setup scripts and source data or generation instructions.

## Reports

For a business-focused reading path, start with the **[Executive Business Report](python_analysis/notebooks/reports/Employee_Workforce_Executive_Report.md)**. For analytical definitions, numeric results, statistical evidence, and limitations, see the **[Statistical & Analytical Report](python_analysis/notebooks/reports/Employee_Workforce_Statistical_Report.md)**.

---

*Independent portfolio project · Synthetic workforce data · 2021–2025*
