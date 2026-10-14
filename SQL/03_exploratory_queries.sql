-- EXPLORATION: development investigations (not production setup)
-- PostgreSQL 18 | workforce_analytics | Phase 4
-- Generated from the executed SQL development log.
-- Review before executing against a new database.

-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 06: EXAMINE MONTHLY EMPLOYMENT STATUS DISTRIBUTION
-- Purpose: Validate employment status before KPI calculations
-- Source: analytics.vw_employee_monthly
-- ============================================================

SELECT
    employment_status,
    COUNT(*) AS total_records,
    COUNT(DISTINCT employee_id) AS unique_employees,
    COUNT(DISTINCT month_date) AS months_present,
    MIN(month_date) AS first_month,
    MAX(month_date) AS last_month
FROM analytics.vw_employee_monthly
GROUP BY employment_status
ORDER BY total_records DESC;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 07: INVESTIGATE TERMINATION MONTH REPRESENTATION
-- Purpose: Determine how termination events appear in monthly data
-- Sources: analytics.vw_employee_monthly, staging.employees_hris
-- ============================================================

SELECT
    COUNT(*) AS terminated_monthly_records,

    COUNT(*) FILTER (
        WHERE e.termination_date IS NULL
    ) AS missing_termination_dates,

    COUNT(*) FILTER (
        WHERE DATE_TRUNC('month', e.termination_date)::date
              = m.month_date
    ) AS termination_in_same_month,

    COUNT(*) FILTER (
        WHERE DATE_TRUNC('month', e.termination_date)::date
              < m.month_date
    ) AS termination_before_record_month,

    COUNT(*) FILTER (
        WHERE DATE_TRUNC('month', e.termination_date)::date
              > m.month_date
    ) AS termination_after_record_month

FROM analytics.vw_employee_monthly AS m

LEFT JOIN staging.employees_hris AS e
    ON m.employee_id = e.employee_id

WHERE m.employment_status = 'Terminated';


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 11: INVESTIGATE DECEMBER 2025 HEADCOUNT DISCREPANCY
-- Purpose: Reconcile current active employees with December 2025
-- Sources: staging.employees_hris, analytics.vw_employee_monthly
-- ============================================================

SELECT
    CASE
        WHEN m.employee_id IS NULL
            THEN 'No December 2025 Record'
        WHEN m.employment_status = 'Terminated'
            THEN 'Terminated in December 2025'
        ELSE 'Other Status'
    END AS discrepancy_reason,

    COUNT(*) AS employee_count

FROM staging.employees_hris AS e

LEFT JOIN analytics.vw_employee_monthly AS m
    ON e.employee_id = m.employee_id
   AND m.month_date = DATE '2025-12-01'

WHERE e.employment_status = 'Active'
  AND (
      m.employee_id IS NULL
      OR m.employment_status IS DISTINCT FROM 'Active'
  )

GROUP BY 1
ORDER BY employee_count DESC;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 12: INVESTIGATE MISSING DECEMBER EMPLOYEE RECORDS
-- Purpose: Examine 24 active employees missing from December
-- Sources: staging.employees_hris, analytics.vw_employee_monthly
-- ============================================================

WITH missing_employees AS (
    SELECT
        e.employee_id,
        e.hire_date,
        e.termination_date,
        e.employment_status
    FROM staging.employees_hris AS e
    LEFT JOIN analytics.vw_employee_monthly AS dec
        ON e.employee_id = dec.employee_id
       AND dec.month_date = DATE '2025-12-01'
    WHERE e.employment_status = 'Active'
      AND dec.employee_id IS NULL
)

SELECT
    m.employee_id,
    m.hire_date,
    m.termination_date,
    m.employment_status,
    MAX(h.month_date) AS last_monthly_record,
    COUNT(h.month_date) AS total_monthly_records
FROM missing_employees AS m
LEFT JOIN analytics.vw_employee_monthly AS h
    ON m.employee_id = h.employee_id
GROUP BY
    m.employee_id,
    m.hire_date,
    m.termination_date,
    m.employment_status
ORDER BY last_monthly_record DESC NULLS LAST;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 26: INSPECT PROMOTION HISTORY STRUCTURE
-- Purpose: Identify promotion event fields and data types
-- Source: staging.promotion_history / raw.promotion_history
-- ============================================================

SELECT
    table_schema,
    table_name,
    ordinal_position,
    column_name,
    data_type

FROM information_schema.columns

WHERE table_schema IN ('staging', 'raw')
  AND table_name = 'promotion_history'

ORDER BY
    table_schema,
    ordinal_position;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 28: INVESTIGATE PROMOTION EVENT DISTRIBUTION
-- Purpose: Examine promotion timing and historical coverage
-- Source: raw.promotion_history
-- ============================================================

WITH calendar_months AS (
    SELECT
        GENERATE_SERIES(
            DATE '2021-01-01',
            DATE '2025-12-01',
            INTERVAL '1 month'
        )::date AS month_date
),

monthly_promotions AS (
    SELECT
        DATE_TRUNC('month', promotion_date)::date AS month_date,
        COUNT(*) AS promotion_events,
        COUNT(DISTINCT employee_id) AS promoted_employees

    FROM raw.promotion_history

    GROUP BY 1
)

SELECT
    c.month_date,

    COALESCE(p.promotion_events, 0)
        AS promotion_events,

    COALESCE(p.promoted_employees, 0)
        AS promoted_employees

FROM calendar_months AS c

LEFT JOIN monthly_promotions AS p
    ON c.month_date = p.month_date

ORDER BY c.month_date;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 32: ANALYZE PROMOTION TRANSITIONS BY JOB LEVEL
-- Purpose: Identify career progression patterns and
--          salary increases across job-level transitions
-- Source: raw.promotion_history
-- ============================================================

SELECT
    previous_level,
    new_level,

    COUNT(*) AS promotion_events,

    COUNT(DISTINCT employee_id)
        AS unique_promoted_employees,

    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS share_of_all_promotions_pct,

    ROUND(
        AVG(
            100.0 * (salary_after - salary_before)
            / NULLIF(salary_before, 0)
        ),
        2
    ) AS avg_salary_increase_pct,

    ROUND(
        AVG(salary_after - salary_before),
        2
    ) AS avg_salary_increase_amount

FROM raw.promotion_history

GROUP BY
    previous_level,
    new_level

ORDER BY
    promotion_events DESC;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 33: INSPECT APRIL WORKFORCE BY JOB LEVEL
-- Purpose: Examine workforce distribution during annual
--          promotion cycles before calculating level rates
-- Source: analytics.vw_employee_monthly
-- ============================================================

SELECT
    EXTRACT(YEAR FROM month_date)::integer AS year,

    job_level,

    COUNT(DISTINCT employee_id)
        AS employees_in_level,

    COUNT(DISTINCT employee_id) FILTER (
        WHERE employment_status = 'Active'
    ) AS active_employees_in_level,

    COUNT(DISTINCT employee_id) FILTER (
        WHERE employment_status = 'Terminated'
    ) AS terminated_employees_in_level

FROM analytics.vw_employee_monthly

WHERE EXTRACT(MONTH FROM month_date) = 4

GROUP BY
    EXTRACT(YEAR FROM month_date),
    job_level

ORDER BY
    year,
    job_level;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 37: ANALYZE PROMOTION RATES BY JOB LEVEL
-- Purpose: Compare promotion opportunities across
--          job levels and calendar years
-- Source: analytics.vw_promotion_rate_by_level
-- ============================================================

SELECT
    job_level,

    SUM(employees_before_promotion)
        AS total_annual_workforce_exposures,

    SUM(promoted_employees)
        AS total_promotion_events,

    ROUND(
        100.0 * SUM(promoted_employees)
        / NULLIF(SUM(employees_before_promotion), 0),
        2
    ) AS five_year_weighted_promotion_rate_pct,

    MAX(promotion_rate_pct)
        AS highest_annual_promotion_rate_pct,

    MIN(promotion_rate_pct)
        AS lowest_annual_promotion_rate_pct,

    ROUND(AVG(promotion_rate_pct), 2)
        AS average_annual_promotion_rate_pct

FROM analytics.vw_promotion_rate_by_level

GROUP BY job_level

ORDER BY job_level;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 41: ANALYZE ANNUAL COMPENSATION TRENDS
-- Purpose: Compare year-end salary and compa-ratio trends
--          while monitoring employee data coverage
-- Sources: analytics.vw_monthly_compensation,
--          analytics.vw_monthly_headcount_reconciled
-- ============================================================

WITH year_end_compensation AS (
    SELECT
        EXTRACT(YEAR FROM c.month_date)::integer AS year,

        c.employees_with_compensation_data,
        h.official_headcount,

        h.headcount_coverage_pct,

        c.average_base_salary,
        c.median_base_salary,

        c.salary_25th_percentile,
        c.salary_75th_percentile,

        c.average_compa_ratio,
        c.median_compa_ratio

    FROM analytics.vw_monthly_compensation AS c

    JOIN analytics.vw_monthly_headcount_reconciled AS h
        ON c.month_date = h.month_date

    WHERE EXTRACT(MONTH FROM c.month_date) = 12
)

SELECT
    year,

    employees_with_compensation_data,
    official_headcount,
    headcount_coverage_pct,

    average_base_salary,
    median_base_salary,

    ROUND(
        100.0 * (
            average_base_salary
            - LAG(average_base_salary) OVER (ORDER BY year)
        ) / NULLIF(
            LAG(average_base_salary) OVER (ORDER BY year),
            0
        ),
        2
    ) AS avg_salary_yoy_change_pct,

    salary_25th_percentile,
    salary_75th_percentile,

    average_compa_ratio,
    median_compa_ratio

FROM year_end_compensation

ORDER BY year;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 44: ANALYZE COMPENSATION BY JOB LEVEL
-- Purpose: Compare salary distributions and compensation
--          positioning across job levels at year-end 2025
-- Source: analytics.vw_compensation_by_level
-- ============================================================

SELECT
    job_level,

    employee_count,

    average_base_salary,
    median_base_salary,

    minimum_base_salary,
    maximum_base_salary,

    salary_25th_percentile,
    salary_75th_percentile,

    average_compa_ratio,

    ROUND(
        average_base_salary - median_base_salary,
        2
    ) AS mean_median_salary_gap,

    ROUND(
        salary_75th_percentile - salary_25th_percentile,
        2
    ) AS salary_interquartile_range

FROM analytics.vw_compensation_by_level

WHERE month_date = DATE '2025-12-01'

ORDER BY job_level;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 47: ANALYZE COMPENSATION BY DEPARTMENT
-- Purpose: Compare salary distributions, department sizes,
--          and compensation positioning at year-end 2025
-- Source: analytics.vw_compensation_by_department
-- ============================================================

SELECT
    department,

    employee_count,

    ROUND(
        100.0 * employee_count
        / NULLIF(SUM(employee_count) OVER (), 0),
        2
    ) AS workforce_share_pct,

    average_base_salary,
    median_base_salary,

    minimum_base_salary,
    maximum_base_salary,

    salary_25th_percentile,
    salary_75th_percentile,

    average_compa_ratio,

    ROUND(
        average_base_salary - median_base_salary,
        2
    ) AS mean_median_salary_gap,

    ROUND(
        salary_75th_percentile - salary_25th_percentile,
        2
    ) AS salary_interquartile_range

FROM analytics.vw_compensation_by_department

WHERE month_date = DATE '2025-12-01'

ORDER BY average_base_salary DESC;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 48: ANALYZE JOB-LEVEL MIX BY DEPARTMENT
-- Purpose: Identify whether departmental salary differences
--          may be influenced by workforce seniority mix
-- Grain: Department and job level, December 2025
-- Source: analytics.vw_employee_monthly
-- ============================================================

WITH level_distribution AS (
    SELECT
        department,
        job_level,

        COUNT(DISTINCT employee_id) AS employee_count,

        ROUND(AVG(base_salary), 2)
            AS average_base_salary

    FROM analytics.vw_employee_monthly

    WHERE month_date = DATE '2025-12-01'
      AND employment_status = 'Active'

    GROUP BY
        department,
        job_level
)

SELECT
    department,
    job_level,
    employee_count,

    ROUND(
        100.0 * employee_count
        / NULLIF(
            SUM(employee_count) OVER (
                PARTITION BY department
            ),
            0
        ),
        2
    ) AS department_level_share_pct,

    average_base_salary

FROM level_distribution

ORDER BY
    department,
    job_level;
