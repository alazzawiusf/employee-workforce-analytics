-- VALIDATION: development checks, run after building views
-- PostgreSQL 18 | workforce_analytics | Phase 4
-- Generated from the executed SQL development log.
-- Review before executing against a new database.

-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 02: VALIDATE EMPLOYEE-MONTH GRAIN
-- Purpose: Check uniqueness and completeness of monthly keys
-- ============================================================

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (employee_id, year_month)) AS unique_employee_months,
    COUNT(*) - COUNT(DISTINCT (employee_id, year_month)) AS duplicate_rows,
    COUNT(*) FILTER (
        WHERE employee_id IS NULL
           OR year_month IS NULL
    ) AS missing_key_rows
FROM staging.employee_monthly_hris;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 03: VALIDATE MONTHLY DATE FORMAT AND COVERAGE
-- Purpose: Verify YYYY-MM format and monthly coverage
-- ============================================================

SELECT
    COUNT(*) FILTER (
        WHERE year_month IS NULL
           OR year_month !~ '^[0-9]{4}-(0[1-9]|1[0-2])$'
    ) AS invalid_month_formats,
    MIN(year_month) AS first_month,
    MAX(year_month) AS last_month,
    COUNT(DISTINCT year_month) AS distinct_months
FROM staging.employee_monthly_hris;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 05: VALIDATE EMPLOYEE MONTHLY ANALYTICS VIEW
-- Purpose: Verify row counts, unique keys, and date conversion
-- ============================================================

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (employee_id, month_date)) AS unique_employee_months,
    COUNT(*) - COUNT(DISTINCT (employee_id, month_date)) AS duplicate_rows,
    COUNT(*) FILTER (
        WHERE month_date IS NULL
    ) AS null_month_dates,
    MIN(month_date) AS first_month,
    MAX(month_date) AS last_month,
    COUNT(DISTINCT month_date) AS distinct_months
FROM analytics.vw_employee_monthly;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 08: VALIDATE EMPLOYEE RECORDS AFTER TERMINATION
-- Purpose: Detect monthly records occurring after termination
-- Sources: analytics.vw_employee_monthly, staging.employees_hris
-- ============================================================

SELECT
    COUNT(*) AS records_after_termination,
    COUNT(DISTINCT m.employee_id) AS affected_employees,

    COUNT(*) FILTER (
        WHERE m.employment_status = 'Active'
    ) AS active_records_after_termination,

    COUNT(*) FILTER (
        WHERE m.employment_status = 'Terminated'
    ) AS terminated_records_after_termination

FROM analytics.vw_employee_monthly AS m

JOIN staging.employees_hris AS e
    ON m.employee_id = e.employee_id

WHERE e.termination_date IS NOT NULL
  AND m.month_date >
      DATE_TRUNC('month', e.termination_date)::date;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 10: VALIDATE MONTHLY HEADCOUNT KPIs
-- Purpose: Verify monthly headcount and termination metrics
-- Source: analytics.vw_monthly_headcount
-- ============================================================

SELECT
    COUNT(*) AS total_months,

    MIN(month_date) AS first_month,
    MAX(month_date) AS last_month,

    MIN(month_end_headcount) AS minimum_headcount,
    MAX(month_end_headcount) AS maximum_headcount,

    SUM(terminations) AS total_terminations,

    SUM(employees_present_during_month) AS total_employee_month_records,

    COUNT(*) FILTER (
        WHERE month_end_headcount + terminations
              <> employees_present_during_month
    ) AS inconsistent_months,

    MAX(month_end_headcount) FILTER (
        WHERE month_date = DATE '2025-12-01'
    ) AS december_2025_headcount

FROM analytics.vw_monthly_headcount;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 13: ASSESS MISSING EMPLOYEE-MONTH RECORDS
-- Purpose: Identify gaps in monthly employee coverage
-- Sources: staging.employees_hris, analytics.vw_employee_monthly
-- ============================================================

WITH expected_months AS (
    SELECT
        e.employee_id,
        gs.month_date::date AS month_date
    FROM staging.employees_hris AS e
    CROSS JOIN LATERAL generate_series(
        GREATEST(
            DATE_TRUNC('month', e.hire_date)::date,
            DATE '2021-01-01'
        ),
        LEAST(
            DATE_TRUNC(
                'month',
                COALESCE(e.termination_date, DATE '2025-12-31')
            )::date,
            DATE '2025-12-01'
        ),
        INTERVAL '1 month'
    ) AS gs(month_date)
)

SELECT
    COUNT(*) AS expected_employee_months,

    COUNT(m.employee_id) AS observed_employee_months,

    COUNT(*) FILTER (
        WHERE m.employee_id IS NULL
    ) AS missing_employee_months,

    COUNT(DISTINCT e.employee_id) FILTER (
        WHERE m.employee_id IS NULL
    ) AS employees_with_missing_months

FROM expected_months AS e

LEFT JOIN analytics.vw_employee_monthly AS m
    ON e.employee_id = m.employee_id
   AND e.month_date = m.month_date;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 14: RECONCILE MONTHLY HEADCOUNT WITH EMPLOYMENT DATES
-- Purpose: Compare observed and employment-date-based headcount
-- Grain: One row per month
-- Sources: staging.employees_hris, analytics.vw_monthly_headcount
-- ============================================================

WITH calendar_months AS (
    SELECT
        GENERATE_SERIES(
            DATE '2021-01-01',
            DATE '2025-12-01',
            INTERVAL '1 month'
        )::date AS month_date
),

employment_headcount AS (
    SELECT
        c.month_date,

        COUNT(e.employee_id) AS date_based_headcount

    FROM calendar_months AS c

    LEFT JOIN staging.employees_hris AS e
        ON e.hire_date < (c.month_date + INTERVAL '1 month')
       AND (
           e.termination_date IS NULL
           OR e.termination_date >=
              (c.month_date + INTERVAL '1 month')
       )

    GROUP BY c.month_date
)

SELECT
    h.month_date,
    h.month_end_headcount AS observed_headcount,
    e.date_based_headcount,
    e.date_based_headcount - h.month_end_headcount
        AS headcount_difference

FROM analytics.vw_monthly_headcount AS h

JOIN employment_headcount AS e
    ON h.month_date = e.month_date

ORDER BY h.month_date;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 16: VALIDATE RECONCILED MONTHLY HEADCOUNT KPIs
-- Purpose: Verify headcount reconciliation and coverage gaps
-- Source: analytics.vw_monthly_headcount_reconciled
-- ============================================================

SELECT
    COUNT(*) AS total_months,

    COUNT(*) FILTER (
        WHERE headcount_coverage_gap <> 0
    ) AS months_with_coverage_gaps,

    SUM(headcount_coverage_gap) AS total_missing_employee_months,

    MIN(headcount_coverage_gap) AS minimum_coverage_gap,
    MAX(headcount_coverage_gap) AS maximum_coverage_gap,

    MAX(official_headcount) FILTER (
        WHERE month_date = DATE '2025-12-01'
    ) AS december_official_headcount,

    MAX(observed_headcount) FILTER (
        WHERE month_date = DATE '2025-12-01'
    ) AS december_observed_headcount,

    MIN(headcount_coverage_pct) AS minimum_coverage_pct,

    COUNT(*) FILTER (
        WHERE official_headcount
              <> observed_headcount + headcount_coverage_gap
    ) AS inconsistent_months

FROM analytics.vw_monthly_headcount_reconciled;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 17: VALIDATE MONTHLY HIRING AND SEPARATION EVENTS
-- Purpose: Establish hiring and separation event totals
-- Period: January 2021 - December 2025
-- Source: staging.employees_hris
-- ============================================================

SELECT
    COUNT(*) FILTER (
        WHERE hire_date >= DATE '2021-01-01'
          AND hire_date < DATE '2026-01-01'
    ) AS total_hires,

    COUNT(*) FILTER (
        WHERE termination_date >= DATE '2021-01-01'
          AND termination_date < DATE '2026-01-01'
    ) AS total_separations,

    COUNT(*) FILTER (
        WHERE termination_date >= DATE '2021-01-01'
          AND termination_date < DATE '2026-01-01'
          AND termination_type = 'Voluntary'
    ) AS voluntary_separations,

    COUNT(*) FILTER (
        WHERE termination_date >= DATE '2021-01-01'
          AND termination_date < DATE '2026-01-01'
          AND termination_type = 'Involuntary'
    ) AS involuntary_separations,

    COUNT(*) FILTER (
        WHERE termination_date >= DATE '2021-01-01'
          AND termination_date < DATE '2026-01-01'
          AND (
              termination_type IS NULL
              OR termination_type NOT IN ('Voluntary', 'Involuntary')
          )
    ) AS other_or_unknown_separations

FROM staging.employees_hris;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 19: VALIDATE MONTHLY WORKFORCE MOVEMENT KPIs
-- Purpose: Verify hiring, separation, and net change totals
-- Source: analytics.vw_monthly_workforce_movements
-- ============================================================

SELECT
    COUNT(*) AS total_months,

    SUM(hires) AS total_hires,
    SUM(separations) AS total_separations,

    SUM(voluntary_separations) AS voluntary_separations,
    SUM(involuntary_separations) AS involuntary_separations,

    SUM(net_workforce_change) AS total_net_change,

    COUNT(*) FILTER (
        WHERE separations <>
              voluntary_separations + involuntary_separations
    ) AS inconsistent_separation_months,

    COUNT(*) FILTER (
        WHERE net_workforce_change <> hires - separations
    ) AS inconsistent_net_change_months,

    MIN(month_date) AS first_month,
    MAX(month_date) AS last_month

FROM analytics.vw_monthly_workforce_movements;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 21: VALIDATE MONTHLY EMPLOYEE TURNOVER KPIs
-- Purpose: Verify headcount continuity and turnover calculations
-- Source: analytics.vw_monthly_turnover
-- ============================================================

SELECT
    COUNT(*) AS total_months,

    MIN(beginning_headcount) AS minimum_beginning_headcount,
    MAX(ending_headcount) AS maximum_ending_headcount,

    COUNT(*) FILTER (
        WHERE beginning_headcount + hires - separations
              <> ending_headcount
    ) AS headcount_balance_errors,

    COUNT(*) FILTER (
        WHERE average_headcount <= 0
           OR average_headcount IS NULL
    ) AS invalid_average_headcount_months,

    MIN(monthly_turnover_rate_pct) AS minimum_monthly_turnover_pct,
    MAX(monthly_turnover_rate_pct) AS maximum_monthly_turnover_pct,

    ROUND(
        AVG(monthly_turnover_rate_pct), 4
    ) AS average_monthly_turnover_pct,

    COUNT(*) FILTER (
        WHERE ABS(
            monthly_turnover_rate_pct
            - voluntary_turnover_rate_pct
            - involuntary_turnover_rate_pct
        ) > 0.0001
    ) AS turnover_rate_consistency_errors

FROM analytics.vw_monthly_turnover;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 23: VALIDATE ANNUAL EMPLOYEE TURNOVER KPIs
-- Purpose: Review annual turnover rates and validate totals
-- Source: analytics.vw_annual_turnover
-- ============================================================

SELECT
    year,
    months_in_year,

    annual_hires,
    annual_separations,
    annual_voluntary_separations,
    annual_involuntary_separations,

    annual_average_headcount,

    annual_turnover_rate_pct,
    annual_voluntary_turnover_pct,
    annual_involuntary_turnover_pct,

    annual_separations
        - annual_voluntary_separations
        - annual_involuntary_separations
        AS separation_count_difference,

    ROUND(
        annual_turnover_rate_pct
        - annual_voluntary_turnover_pct
        - annual_involuntary_turnover_pct,
        4
    ) AS turnover_rate_difference

FROM analytics.vw_annual_turnover

ORDER BY year;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 25: VALIDATE ANNUAL WORKFORCE SUMMARY
-- Purpose: Verify annual headcount, workforce movements,
--          turnover rates, and data coverage
-- Source: analytics.vw_annual_workforce_summary
-- ============================================================

SELECT
    year,
    year_end_headcount,
    average_month_end_headcount,
    missing_employee_months,

    annual_hires,
    annual_separations,
    net_workforce_change,

    annual_turnover_rate_pct,

    year_end_headcount
        - LAG(year_end_headcount) OVER (
            ORDER BY year
        ) AS actual_headcount_change,

    CASE
        WHEN LAG(year_end_headcount) OVER (
            ORDER BY year
        ) IS NULL THEN NULL
        ELSE
            year_end_headcount
            - LAG(year_end_headcount) OVER (
                ORDER BY year
            )
            - net_workforce_change
    END AS headcount_reconciliation_error

FROM analytics.vw_annual_workforce_summary

ORDER BY year;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 27: PROFILE PROMOTION EVENTS & DATA QUALITY
-- Purpose: Validate promotion events before KPI development
-- Source: raw.promotion_history
-- ============================================================

SELECT
    COUNT(*) AS total_promotions,

    COUNT(DISTINCT employee_id) AS promoted_employees,

    MIN(promotion_date) AS first_promotion,
    MAX(promotion_date) AS last_promotion,

    COUNT(*) FILTER (
        WHERE employee_id IS NULL
           OR promotion_date IS NULL
           OR previous_level IS NULL
           OR new_level IS NULL
    ) AS incomplete_promotion_records,

    COUNT(*) FILTER (
        WHERE previous_level = new_level
    ) AS same_level_promotions,

    COUNT(*) FILTER (
        WHERE previous_level ~ '^L[1-8]$'
          AND new_level ~ '^L[1-8]$'
          AND SUBSTRING(new_level FROM 2)::integer
              < SUBSTRING(previous_level FROM 2)::integer
    ) AS downward_level_changes,

    COUNT(*) - COUNT(DISTINCT (
        employee_id,
        promotion_date,
        previous_level,
        new_level
    )) AS duplicate_promotion_events,

    COUNT(*) FILTER (
        WHERE salary_before IS NULL
           OR salary_after IS NULL
    ) AS missing_salary_values

FROM raw.promotion_history;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 29: VALIDATE PROMOTIONS AGAINST EMPLOYEE RECORDS
-- Purpose: Verify employee references and employment dates
-- Sources: raw.promotion_history, staging.employees_hris
-- ============================================================

SELECT
    COUNT(*) AS total_promotion_events,

    COUNT(*) FILTER (
        WHERE e.employee_id IS NULL
    ) AS unmatched_employee_records,

    COUNT(*) FILTER (
        WHERE p.promotion_date < e.hire_date
    ) AS promotions_before_hire,

    COUNT(*) FILTER (
        WHERE p.promotion_date > e.termination_date
    ) AS promotions_after_termination,

    COUNT(*) FILTER (
        WHERE p.salary_after < p.salary_before
    ) AS salary_decreases_after_promotion,

    COUNT(*) FILTER (
        WHERE p.salary_after = p.salary_before
    ) AS promotions_without_salary_increase,

    COUNT(*) FILTER (
        WHERE p.salary_before <= 0
           OR p.salary_after <= 0
    ) AS invalid_salary_values

FROM raw.promotion_history AS p

LEFT JOIN staging.employees_hris AS e
    ON p.employee_id = e.employee_id;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 31: VALIDATE ANNUAL PROMOTION KPIs
-- Purpose: Review promotion rates, salary increases,
--          and verify annual promotion totals
-- Source: analytics.vw_annual_promotions
-- ============================================================

SELECT
    year,
    promotion_events,
    promoted_employees,
    annual_average_headcount,
    promotion_rate_pct,
    avg_salary_increase_pct,
    avg_salary_increase_amount,

    promotion_events - promoted_employees
        AS repeat_promotion_events,

    SUM(promotion_events) OVER ()
        AS total_promotion_events,

    SUM(promoted_employees) OVER ()
        AS total_annual_promoted_employee_counts

FROM analytics.vw_annual_promotions

ORDER BY year;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 34: VALIDATE PROMOTION TIMING AGAINST MONTHLY HRIS
-- Purpose: Determine whether April job levels represent
--          pre-promotion or post-promotion employee levels
-- Sources: raw.promotion_history,
--          analytics.vw_employee_monthly
-- ============================================================

WITH promotion_comparison AS (
    SELECT
        p.employee_id,
        p.promotion_date,
        p.previous_level,
        p.new_level,

        march.job_level AS march_level,
        april.job_level AS april_level

    FROM raw.promotion_history AS p

    LEFT JOIN analytics.vw_employee_monthly AS march
        ON p.employee_id = march.employee_id
       AND march.month_date =
           (p.promotion_date - INTERVAL '1 month')::date

    LEFT JOIN analytics.vw_employee_monthly AS april
        ON p.employee_id = april.employee_id
       AND april.month_date = p.promotion_date
)

SELECT
    COUNT(*) AS total_promotions,

    COUNT(*) FILTER (
        WHERE march_level = previous_level
    ) AS march_matches_previous_level,

    COUNT(*) FILTER (
        WHERE april_level = new_level
    ) AS april_matches_new_level,

    COUNT(*) FILTER (
        WHERE april_level = previous_level
    ) AS april_matches_previous_level,

    COUNT(*) FILTER (
        WHERE march_level IS NULL
    ) AS missing_march_records,

    COUNT(*) FILTER (
        WHERE april_level IS NULL
    ) AS missing_april_records,

    COUNT(*) FILTER (
        WHERE march_level = previous_level
          AND april_level = new_level
    ) AS fully_verified_transitions

FROM promotion_comparison;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 36: VALIDATE PROMOTION RATES BY JOB LEVEL
-- Purpose: Review level-specific promotion rates and
--          verify annual totals and denominator validity
-- Sources: analytics.vw_promotion_rate_by_level,
--          analytics.vw_annual_promotions
-- ============================================================

WITH annual_validation AS (
    SELECT
        year,

        SUM(employees_before_promotion)
            AS march_active_workforce,

        SUM(promotion_events)
            AS level_promotion_events,

        SUM(promoted_employees)
            AS level_promoted_employees,

        MIN(promotion_rate_pct)
            AS lowest_level_promotion_rate_pct,

        MAX(promotion_rate_pct)
            AS highest_level_promotion_rate_pct,

        COUNT(*) FILTER (
            WHERE promoted_employees > employees_before_promotion
               OR promotion_rate_pct > 100
               OR promotion_rate_pct < 0
        ) AS invalid_level_rates

    FROM analytics.vw_promotion_rate_by_level

    GROUP BY year
)

SELECT
    v.*,

    a.promotion_events AS expected_promotion_events,

    v.level_promotion_events - a.promotion_events
        AS promotion_count_difference

FROM annual_validation AS v

JOIN analytics.vw_annual_promotions AS a
    ON v.year = a.year

ORDER BY v.year;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 38: PROFILE MONTHLY COMPENSATION DATA
-- Purpose: Validate salary and compa-ratio fields before
--          developing workforce compensation KPIs
-- Source: analytics.vw_employee_monthly
-- ============================================================

SELECT
    COUNT(*) AS total_employee_month_records,

    COUNT(*) FILTER (
        WHERE employment_status = 'Active'
    ) AS active_employee_month_records,

    COUNT(*) FILTER (
        WHERE base_salary IS NULL
    ) AS missing_salary_records,

    COUNT(*) FILTER (
        WHERE base_salary <= 0
    ) AS invalid_salary_records,

    COUNT(*) FILTER (
        WHERE compa_ratio IS NULL
    ) AS missing_compa_ratio_records,

    COUNT(*) FILTER (
        WHERE compa_ratio <= 0
    ) AS invalid_compa_ratio_records,

    ROUND(MIN(base_salary), 2)
        AS minimum_salary,

    ROUND(MAX(base_salary), 2)
        AS maximum_salary,

    ROUND(AVG(base_salary), 2)
        AS average_salary,

    ROUND(MIN(compa_ratio), 4)
        AS minimum_compa_ratio,

    ROUND(MAX(compa_ratio), 4)
        AS maximum_compa_ratio,

    ROUND(AVG(compa_ratio), 4)
        AS average_compa_ratio

FROM analytics.vw_employee_monthly;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 40: VALIDATE MONTHLY COMPENSATION KPIs
-- Purpose: Verify salary distributions, compa-ratio values,
--          and employee coverage across all 60 months
-- Sources: analytics.vw_monthly_compensation,
--          analytics.vw_monthly_headcount_reconciled
-- ============================================================

SELECT
    COUNT(*) AS total_months,

    MIN(c.month_date) AS first_month,
    MAX(c.month_date) AS last_month,

    MIN(c.average_base_salary) AS lowest_monthly_avg_salary,
    MAX(c.average_base_salary) AS highest_monthly_avg_salary,

    MIN(c.median_base_salary) AS lowest_monthly_median_salary,
    MAX(c.median_base_salary) AS highest_monthly_median_salary,

    MIN(c.average_compa_ratio) AS lowest_monthly_avg_compa_ratio,
    MAX(c.average_compa_ratio) AS highest_monthly_avg_compa_ratio,

    COUNT(*) FILTER (
        WHERE c.minimum_base_salary > c.salary_25th_percentile
           OR c.salary_25th_percentile > c.median_base_salary
           OR c.median_base_salary > c.salary_75th_percentile
           OR c.salary_75th_percentile > c.maximum_base_salary
    ) AS invalid_salary_distributions,

    COUNT(*) FILTER (
        WHERE c.employees_with_compensation_data
              <> h.observed_headcount
    ) AS observed_headcount_mismatches,

    COUNT(*) FILTER (
        WHERE c.employees_with_compensation_data
              < h.official_headcount
    ) AS months_with_incomplete_compensation_coverage,

    SUM(
        h.official_headcount
        - c.employees_with_compensation_data
    ) AS total_missing_employee_months

FROM analytics.vw_monthly_compensation AS c

JOIN analytics.vw_monthly_headcount_reconciled AS h
    ON c.month_date = h.month_date;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 43: VALIDATE COMPENSATION BY JOB LEVEL
-- Purpose: Verify salary distributions, employee counts,
--          and compensation coverage across job levels
-- Sources: analytics.vw_compensation_by_level,
--          analytics.vw_monthly_compensation
-- ============================================================

WITH monthly_validation AS (
    SELECT
        month_date,

        SUM(employee_count)
            AS total_level_employees,

        COUNT(*) AS job_levels_present,

        COUNT(*) FILTER (
            WHERE minimum_base_salary > salary_25th_percentile
               OR salary_25th_percentile > median_base_salary
               OR median_base_salary > salary_75th_percentile
               OR salary_75th_percentile > maximum_base_salary
        ) AS invalid_salary_distributions,

        COUNT(*) FILTER (
            WHERE average_base_salary <= 0
               OR average_compa_ratio <= 0
        ) AS invalid_compensation_values

    FROM analytics.vw_compensation_by_level

    GROUP BY month_date
)

SELECT
    COUNT(*) AS total_months,

    MIN(v.job_levels_present)
        AS minimum_job_levels,

    MAX(v.job_levels_present)
        AS maximum_job_levels,

    SUM(v.invalid_salary_distributions)
        AS invalid_salary_distributions,

    SUM(v.invalid_compensation_values)
        AS invalid_compensation_values,

    COUNT(*) FILTER (
        WHERE v.total_level_employees
              <> c.employees_with_compensation_data
    ) AS employee_count_mismatch_months,

    SUM(
        v.total_level_employees
        - c.employees_with_compensation_data
    ) AS total_employee_count_difference

FROM monthly_validation AS v

JOIN analytics.vw_monthly_compensation AS c
    ON v.month_date = c.month_date;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 46: VALIDATE COMPENSATION BY DEPARTMENT
-- Purpose: Verify employee counts, salary distributions,
--          and compensation values across departments
-- Sources: analytics.vw_compensation_by_department,
--          analytics.vw_monthly_compensation
-- ============================================================

WITH monthly_validation AS (
    SELECT
        month_date,

        COUNT(*) AS departments_present,

        SUM(employee_count) AS total_department_employees,

        COUNT(*) FILTER (
            WHERE department IS NULL
        ) AS null_department_groups,

        COUNT(*) FILTER (
            WHERE minimum_base_salary > salary_25th_percentile
               OR salary_25th_percentile > median_base_salary
               OR median_base_salary > salary_75th_percentile
               OR salary_75th_percentile > maximum_base_salary
        ) AS invalid_salary_distributions,

        COUNT(*) FILTER (
            WHERE employee_count <= 0
               OR average_base_salary <= 0
               OR average_compa_ratio <= 0
        ) AS invalid_compensation_values

    FROM analytics.vw_compensation_by_department

    GROUP BY month_date
)

SELECT
    COUNT(*) AS total_months,

    MIN(v.departments_present) AS minimum_departments,
    MAX(v.departments_present) AS maximum_departments,

    SUM(v.null_department_groups) AS null_department_groups,

    SUM(v.invalid_salary_distributions)
        AS invalid_salary_distributions,

    SUM(v.invalid_compensation_values)
        AS invalid_compensation_values,

    COUNT(*) FILTER (
        WHERE v.total_department_employees
              <> c.employees_with_compensation_data
    ) AS employee_count_mismatch_months,

    SUM(
        v.total_department_employees
        - c.employees_with_compensation_data
    ) AS total_employee_count_difference

FROM monthly_validation AS v

JOIN analytics.vw_monthly_compensation AS c
    ON v.month_date = c.month_date;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 49: VALIDATE OPERATIONAL ANALYTICS INPUTS
-- Purpose: Assess completeness and validity of performance,
--          absence, workload, and vacancy variables
-- Source: analytics.vw_employee_monthly
-- ============================================================

SELECT
    COUNT(*) AS active_employee_months,

    COUNT(*) FILTER (
        WHERE latest_performance_rating IS NULL
    ) AS missing_performance_ratings,

    COUNT(*) FILTER (
        WHERE unscheduled_absence_days IS NULL
    ) AS missing_absence_days,

    COUNT(*) FILTER (
        WHERE average_weekly_hours IS NULL
    ) AS missing_weekly_hours,

    COUNT(*) FILTER (
        WHERE team_vacancy_rate IS NULL
    ) AS missing_vacancy_rates,

    COUNT(*) FILTER (
        WHERE recent_workload_metric IS NULL
    ) AS missing_workload_metrics,

    MIN(latest_performance_rating)
        AS minimum_performance_rating,

    MAX(latest_performance_rating)
        AS maximum_performance_rating,

    MIN(unscheduled_absence_days)
        AS minimum_absence_days,

    MAX(unscheduled_absence_days)
        AS maximum_absence_days,

    MIN(average_weekly_hours)
        AS minimum_weekly_hours,

    MAX(average_weekly_hours)
        AS maximum_weekly_hours,

    MIN(team_vacancy_rate)
        AS minimum_vacancy_rate,

    MAX(team_vacancy_rate)
        AS maximum_vacancy_rate

FROM analytics.vw_employee_monthly

WHERE employment_status = 'Active';


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 51: FINAL OPERATIONAL KPI VALIDATION
-- Purpose: Validate monthly operational KPI completeness,
--          workforce reconciliation, and metric boundaries
-- Sources: analytics.vw_monthly_operational_kpis,
--          analytics.vw_monthly_headcount_reconciled
-- ============================================================

SELECT
    COUNT(*) AS total_months,

    MIN(o.month_date) AS first_month,
    MAX(o.month_date) AS last_month,

    COUNT(*) FILTER (
        WHERE o.active_employees_observed
              <> h.observed_headcount
    ) AS headcount_mismatch_months,

    COUNT(*) FILTER (
        WHERE o.employees_with_performance_data
                  > o.active_employees_observed
           OR o.employees_with_absence_data
                  > o.active_employees_observed
           OR o.employees_with_weekly_hours_data
                  > o.active_employees_observed
           OR o.employees_with_workload_data
                  > o.active_employees_observed
           OR o.employees_with_vacancy_data
                  > o.active_employees_observed
    ) AS invalid_coverage_months,

    COUNT(*) FILTER (
        WHERE o.average_performance_rating NOT BETWEEN 1 AND 5
           OR o.performance_coverage_pct NOT BETWEEN 0 AND 100
           OR o.average_unscheduled_absence_days < 0
           OR o.average_weekly_hours < 0
           OR o.average_team_vacancy_rate NOT BETWEEN 0 AND 1
    ) AS invalid_metric_months,

    MIN(o.performance_coverage_pct)
        AS minimum_performance_coverage_pct,

    MAX(o.performance_coverage_pct)
        AS maximum_performance_coverage_pct,

    MIN(o.average_performance_rating)
        AS minimum_average_performance,

    MAX(o.average_performance_rating)
        AS maximum_average_performance,

    COUNT(*) FILTER (
        WHERE o.active_employees_observed
              < h.official_headcount
    ) AS incomplete_workforce_coverage_months

FROM analytics.vw_monthly_operational_kpis AS o

JOIN analytics.vw_monthly_headcount_reconciled AS h
    ON o.month_date = h.month_date;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 52: FINAL ANALYTICS MODEL INVENTORY
-- Purpose: Verify required analytics views exist
--          before closing Phase 4
-- Source: PostgreSQL information_schema
-- ============================================================

WITH required_views(view_name) AS (
    VALUES
        ('vw_employee_monthly'),
        ('vw_monthly_headcount'),
        ('vw_monthly_headcount_reconciled'),
        ('vw_monthly_workforce_movements'),
        ('vw_monthly_turnover'),
        ('vw_annual_turnover'),
        ('vw_annual_workforce_summary'),
        ('vw_annual_promotions'),
        ('vw_promotion_rate_by_level'),
        ('vw_monthly_compensation'),
        ('vw_compensation_by_level'),
        ('vw_compensation_by_department'),
        ('vw_monthly_operational_kpis')
)

SELECT
    r.view_name,

    CASE
        WHEN v.table_name IS NOT NULL THEN 'READY'
        ELSE 'MISSING'
    END AS validation_status

FROM required_views AS r

LEFT JOIN information_schema.views AS v
    ON v.table_schema = 'analytics'
   AND v.table_name = r.view_name

ORDER BY r.view_name;
