# Workforce Analytics — Data Quality Profiling Report

**Project:** Employee & Workforce Analytics  
**Phase:** 02 — Raw Data Profiling  
**Database:** `workforce_analytics` (PostgreSQL)  
**Observation period:** January 2021–December 2025  
**Status:** Profiling findings documented; cleaning and remediation not yet performed.

## 1. Executive summary

The raw workforce dataset provides a substantial basis for headcount, retention, mobility, performance, compensation and management-structure analytics. Core employee identifiers and historical event coverage are sound. However, inconsistent department/location/job-role labels, tenure anomalies, some manager-month mismatches, and conflicting separation records require explicit controls before production-quality KPI reporting.

**Most important business risks:** misleading department/location/role breakdowns; inconsistent termination classification; inaccurate tenure-based segmentation; incomplete manager hierarchies. **No raw data was changed** during profiling.

## 2. Dataset inventory and scope

| Raw table | Records |
|---|---:|
| `employees_hris` | 8,430 |
| `employee_monthly_hris` | 290,014 |
| `performance_history` | 26,922 |
| `promotion_history` | 1,985 |
| `salary_history` | 29,313 |
| `separation_history` | 3,580 |
| `organization_structure` | 187 |
| `location_reference` | 6 |
| `organization_events` | 1 |

The last three tables provide structural reference data and event context. Figures reflect the profiling results discussed during the project; they are not fresh executions of the SQL script.

## 3. Identity, uniqueness, and historical coverage

- Employee master contains **8,430 unique employee IDs**, with no null/duplicate IDs identified.
- No orphan employee references were found in monthly records or the four employee history tables.
- No duplicate employee/month, employee/performance-year, or employee/promotion-date groups were found.
- **1,951 salary-history employee/date combinations repeat**, but events carry distinct change reasons (such as Merit and Promotion). No duplicates were found at `(employee_id, effective_date, change_reason)` grain. **Do not deduplicate by employee/date alone.**
- All **1,985 promotions**, **29,313 salary events**, and **3,580 separation events** occur within their employees' first-to-last monthly-record coverage. This establishes *date-range coverage*, not proof that events are accurately reflected in monthly values.

## 4. Employee master quality findings

| Test | Finding | Interpretation / next action |
|---|---:|---|
| Department not exactly in organizational reference | 376 (4.46%) | Normalize and map canonical department labels |
| Location not exactly in location reference | 369 (4.38%) | Normalize and map locations |
| Location NULL | 99 (1.17%) | Resolve if supported; preserve unresolved missingness |
| Job role not exactly in organizational reference | 401 (4.76%) | Use staged, context-validated role mapping |
| Terminated employees missing termination type | 255 | All 255 have non-null type in separation history; reconcile with provenance |
| Master `latest_performance_rating` NULL | 1,605 | Evaluate eligibility and coverage before any imputation |
| Master `current_manager_id` NULL | 135 | Evaluate organizational context; do not automatically classify all as defects |

Job-role investigation found **190** of 401 invalid records matching after basic case/space normalization; **101** additional records matching through `Sr.` / `Assoc.` expansion; **55** additional records matching through other abbreviation expansion; **55** remaining records had one job-family/job-level candidate in the reference. A single candidate is a *review aid*, not automatic proof of the correct spelling. Check the full normalization sequence and job family/level before mapping.

### Separation-history reconciliation

- Master employee statuses: **4,891 Active**, **3,539 Terminated**.
- All 3,539 master-terminated employees are represented in separation history.
- **41 master-Active employees also appear in separation history**. Among them, **35** have monthly records after the separation month (46 such records); **6** have none after the separation month. Their last monthly status remains Active.
- These records require a documented business rule or source-of-truth decision. Do not infer rehire, erroneous payment, or incorrect separation from this evidence alone.

## 5. Monthly HRIS completeness

| Field | Missing records | Share of 290,014 | Interpretation |
|---|---:|---:|---|
| `latest_performance_rating` | 39,926 | 13.77% | Strongly tenure-related; coverage bias risk |
| `unscheduled_absence_days` | 4,361 | 1.50% | Do not convert NULL to zero |
| `average_weekly_hours` | 2,934 | 1.01% | Do not convert NULL to zero |
| `manager_id` | 60 | 0.02% | All belong to one CEO (`EMP000001`), a structural NULL |
| Department, job family, job role, job level, location, base salary, employment status | 0 each | 0% | No missing values in these fields |

Performance rating missingness by organizational tenure: **100%** for less than six months, **85.66%** for 6–11 months, **21.29%** for 12–23 months, and **0%** for both 24–59 and 60+ months. This is consistent with a tenure-dependent recording/eligibility process but does not prove the policy. Report rating availability denominators alongside performance KPIs.

Missing workload/absence values remain broadly stable across 2021–2025 and across major departments. High percentages among rare misspelled department variants have very small denominators and should not be interpreted as separate department-level effects.

## 6. Monthly reference and structural integrity

| Test | Affected records | Percentage |
|---|---:|---:|
| Department exact-reference mismatch | 13,091 | 4.51% |
| Location exact-reference mismatch | 12,991 | 4.48% |
| Job role exact-reference mismatch | 13,003 | 4.48% |
| Job family exact-reference mismatch | 0 | 0% |
| Role/family/level combination mismatch | 13,003 | 4.48% |
| Valid role but invalid family/level combination | 0 | 0% |

There are **122 distinct department strings** (114 nonmatching), **84 location strings** (78 nonmatching), and **1,820 job-role strings** (1,636 nonmatching). The reference matches **8 departments** and **6 locations** exactly. The 13,003 role-combination mismatches coincide with nonmatching role names; no extra mismatch was detected where the role itself matched. Do not add counts across dimensions because a monthly record may have multiple issues.

## 7. Numeric and temporal consistency

All 290,014 monthly records passed the tested range rules for positive base salary/compa-ratio, nonnegative tenure/promotion months, role tenure not exceeding organizational tenure, vacancy rate in [0,1], weekly hours in [0,168], absence days in [0,31], and performance rating in [1,5] when present. These are *specified test bounds*, not independent confirmation of metric definitions or value accuracy.

Across **281,584** records with a prior month, **46** consecutive-month tenure-increment anomalies affected **35** employees. In every case, tenure change was **0** rather than the expected **+1**. Investigate whether tenure should be derived from `hire_date` and whether any exceptions (such as employment breaks) are modeled.

Observed monthly employment-status transitions were **3,415 Active → Terminated** and **0 Terminated → Active**. Latest monthly status matches master status for all **8,430** employees: 4,891 Active and 3,539 Terminated. This does **not** resolve the separate 41-record-set conflict with separation history.

## 8. Management hierarchy

| Test | Result |
|---|---:|
| Null manager-month records | 60 (one CEO; expected) |
| Manager ID not found in same month's roster | 257 |
| Employees affected by missing manager-month reference | 103 |
| Distinct referenced managers affected | 85 |
| Referenced manager absent from master | 0 |
| Self-reporting records | 0 |
| Valid manager-month joins | 289,697 |
| Same-level employee/manager pairs | 22 (10 employees) |
| Manager below employee's level | 0 |

All 257 manager-month mismatches reference managers who exist in the master, but are absent from the same-month roster. The 22 same-level relationships are **potential** hierarchy exceptions, not necessarily policy violations. Document whether peer-level reporting is permitted before remediation.

## 9. Remediation backlog for Phase 03 (staging)

| Priority | Workstream | Required treatment / acceptance criteria |
|---|---|---|
| High | Canonical department/location/job-role mapping | Create auditable mapping tables; validate family/level for roles; report mapped/unmapped counts; preserve original raw values |
| High | Separation reconciliation | Recover 255 missing termination types from historical source with provenance; flag and adjudicate 41 Active/separation conflicts |
| High | KPI semantic definitions | Define headcount and turnover event timing, status source of truth, denominator logic and coverage limitations |
| Medium | Manager hierarchy | Flag 257 absent manager-month references; retain CEO structural NULL; validate 22 same-level cases against policy |
| Medium | Tenure consistency | Reconcile 46 stagnant monthly tenure increments; prefer validated date-derived calculation if semantics support it |
| Medium | Missing analytical measures | Preserve workload/absence NULL; expose performance-rating coverage by tenure; avoid blanket imputation |
| Medium | Quality gates | Add staging validation queries for mapping coverage, key uniqueness, status consistency and post-cleaning exception counts |

**Recommended architecture:** `raw` (immutable source) → `staging` (standardized, validated, exception-flagged) → `analytics` (documented KPI-ready model). Retain an exception log and mapping provenance.

## 10. Scope limits and handoff

This report summarizes **previously observed SQL outputs**, not newly rerun queries. It does not claim all source tables have undergone exhaustive column-by-column profiling. Historical coverage tests check event dates against the min/max monthly period; they do not validate every event's corresponding monthly value or the absence of internal gaps. SQL queries and this report together form the Phase 02 handoff. Before KPI publication, execute Phase 03 controls and reconcile flagged exceptions.
