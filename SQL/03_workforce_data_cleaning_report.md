# Workforce Analytics — Phase 3 Data Cleaning & Transformation

**Project:** Employee & Workforce Analytics | **Platform:** PostgreSQL 18  
**Source schemas:** `raw` (immutable), `staging` (curated)  
**Scope:** 8,430 employee master records; 290,014 employee-month records spanning 60 months (2021–2025).  
**Evidence:** Phase 2 profiling, Phase 3 working SQL and previously recorded validation outputs. The accompanying consolidated script has been reviewed and reorganized but **has not been executed against the live PostgreSQL database**.

## 1. Executive summary

The project transformed synthetic HRIS source data into a standardized staging layer suitable for workforce metrics and subsequent analytics modeling. The major quality risks were inconsistent organization labels, missing termination classifications, tenure-counter freezes, and temporally invalid manager references. Reference-based mappings and controlled updates resolved confirmed errors. Missing measurements and ambiguous employment events were retained or flagged rather than invented or overwritten.

The reported final checks found **zero invalid master departments, locations, job-role combinations, or manager references**, and **zero invalid monthly departments, locations, or job roles**. Temporal checks confirmed correction of the **46 frozen tenure observations affecting 35 employees**. Important exceptions remain documented, not silently corrected.

## 2. Scope and controls

| Dataset | Records | Purpose |
|---|---:|---|
| Employee master (`employees_hris`) | 8,430 | Employee attributes, current organization, manager, employment status |
| Monthly HRIS (`employee_monthly_hris`) | 290,014 | Historical employee-month observations, pay, tenure, workload, performance |
| Supporting histories | Performance 26,922; promotions 1,985; salary 29,313; separations 3,580 | Event and reference validation |
| Organization and location references | 187 organization rows; 6 locations | Canonical dimensions and mapping validation |

All data corrections target `staging`, not `raw`. Mappings are contextualized by job family and level where required. No arbitrary value imputation was used for missing performance, work hours, or absences. The script preserves source data and uses explicit exception registers.

## 3. Cleaning actions and verified outcomes

| Area | Initial issue | Resolution | Recorded outcome |
|---|---|---|---|
| Master departments | 376 noncanonical values | Canonical department mapping | 0 invalid, 8 canonical departments |
| Master locations | 369 noncanonical, 99 missing | Mapping and latest-month recovery | 0 invalid/missing, 6 canonical locations |
| Master job roles | 401 invalid records, 266 distinct malformed strings | Family/level-aware normalization and explicit mapping | 0 invalid combinations, 184 valid distinct roles |
| Missing termination type | 255 terminated employees | Unique same-date match to separation history | 0 incomplete termination records |
| Missing master manager | 135 missing | Latest observed monthly manager for 134 | 1 legitimate null for CEO |
| Monthly departments | 13,091 invalid | Extended department mapping | 0 invalid |
| Monthly locations | 12,991 invalid | Extended location mapping | 0 invalid |
| Monthly job roles | 13,003 invalid | Exact, abbreviation, contextual and uniquely verified fuzzy mapping | 0 invalid |
| Organizational tenure | 46 frozen transitions among 35 employees | Reconstruct increments within employee sequence | 0 remaining transition anomalies |
| Role tenure and promotion counters | Same 46 anomalous transitions | Reconstruct within role/promotion periods | 0 remaining transition anomalies |
| Manager timeline | 257 employee-month rows refer to managers absent that month after termination | Preserve source manager; create exception register | 257 flagged rows; 103 employees, 85 managers |

The recorded validation for organizational tenure reported **281,584 consecutive month-pairs** with expected +1 progression after correction. The corresponding role/promotion checks reported zero remaining anomalies and 1,985 promotion-related job-level changes consistent with the 1,985 promotion-history events.

## 4. Missingness decisions

| Field | Missing | Treatment and rationale |
|---|---:|---|
| Master latest performance rating | 1,605 | Leave NULL: no supporting performance-history rating available |
| Monthly latest performance rating | 39,926 (13.77%) | Leave NULL: same-year reviews may not yet have occurred; filling them would risk look-ahead bias |
| Monthly average weekly hours | 2,934 (1.01%) | Leave NULL: unknown is not zero |
| Monthly unscheduled absence days | 4,361 (1.50%) | Leave NULL: unknown is not zero |
| Monthly manager ID | 60 | Legitimate CEO null, one per month |

Analysts must use explicit denominators for nonmissing performance, hours, and absence measures, and disclose data coverage when comparing segments.

## 5. Unresolved exceptions and analytic implications

**Employment-status contradictions:** 41 employees are marked `Active` in the master while appearing in separation history. The SQL registers them in `staging.employment_status_conflicts`, separating employees whose latest monthly observation is later than the separation month from other conflicts. These may reflect stale event records, synchronization errors, or unmodeled rehire scenarios. **Do not automatically reclassify these employees as terminated**. Their employment status should be reviewed before definitive headcount or attrition reporting.

**Stale manager references:** 257 employee-month rows refer to a former manager after that manager's termination date and without a manager record in the same month. The `staging.stale_manager_references` register preserves affected employee, month, manager, and termination date. Reporting on manager span or hierarchy should exclude or separately label these records; the original `manager_id` is preserved for traceability.

**Same-month terminated managers:** 2,413 rows reference a manager shown as terminated during the same monthly period. Month-granularity alone cannot prove those relationships were invalid at the employee's observation time, so these were **not** automatically classified as errors.

**Same-level reporting:** 22 manager relationships across 10 employees were identified in profiling. Same-level reporting can be legitimate; no unsupported hierarchy edits were made.

**Salary-history events:** 1,951 repeated employee/date pairs reflect concurrent change reasons (e.g., merit and promotion). They are **not duplicates to delete**. Preserve event reason as part of the event grain.

## 6. Quality assurance and acceptance criteria

Recorded master audit: 8,430 total/unique employee IDs; 0 invalid departments; 0 invalid locations; 0 invalid job-family/level/role combinations; 0 invalid manager references; 0 incomplete terminations; 1,605 legitimately unrated employees.

Recorded monthly organizational audit: 290,014 rows; 0 invalid departments; 0 invalid locations; 0 invalid job-role combinations. Temporal validation: 0 remaining tenure freezes or promotion-counter anomalies. Promotion history: 1,985 events matched to 1,985 monthly job-level transitions.

The final query in the curated script returns master/monthly totals, missingness, and exception counts. **These are historical recorded results, not a claim that the newly consolidated file has been rerun successfully.** To accept the consolidated script for production-like use, run it in a fresh test staging schema/database, compare totals and exception registers, and verify no changes to `raw`.

## 7. Reproducibility notes

The curated SQL retains the transformation steps from the original 77-step working script and removes one-off profiling, failed schema probes, and redundant investigations. It also separates the abbreviation-mapping `INSERT` from its subsequent `UPDATE` to avoid PostgreSQL's same-statement data-modifying CTE visibility issue. It assumes raw imports and staging schema exist. It uses `CREATE TABLE IF NOT EXISTS` and conflict handling rather than dropping existing staging data; a truly fresh rebuild should begin with an empty staging schema in a controlled test environment.

## 8. Recommendations for Phase 4 analytics

Use employee-month as the grain for historical trends and employee ID as the grain for master snapshots. Define monthly headcount and attrition carefully around the 41 unresolved status conflicts. Exclude stale-manager references from validated hierarchy metrics. Publish coverage rates alongside rating, workload, and absence measures. Treat salary changes as distinct events by employee, effective date, and change reason. Build dimensional views and KPIs only after running the consolidated staging script and confirming the audit.
