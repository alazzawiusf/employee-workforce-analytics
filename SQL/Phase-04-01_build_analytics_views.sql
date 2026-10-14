-- BUILD: 13 analytics views, dependency order
-- PostgreSQL 18 | workforce_analytics | Phase 4
-- Generated from the executed SQL development log.
-- Review before executing against a new database.

-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 04: CREATE EMPLOYEE MONTHLY ANALYTICS VIEW
-- Purpose: Establish the employee-month analytical foundation
-- Grain: One row per employee per month
-- Source: staging.employee_monthly_hris
-- ============================================================

CREATE OR REPLACE VIEW analytics.vw_employee_monthly AS

SELECT
    employee_id,
    TO_DATE(year_month || '-01', 'YYYY-MM-DD') AS month_date,
    year_month,

    department,
    job_family,
    job_role,
    job_level,
    location,
    manager_id,

    employment_status,

    base_salary,
    compa_ratio,

    organizational_tenure_months,
    role_tenure_months,
    months_since_last_promotion,

    latest_performance_rating,
    team_vacancy_rate,
    average_weekly_hours,
    unscheduled_absence_days,
    recent_absence_metric,
    recent_workload_metric

FROM staging.employee_monthly_hris;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 09: CREATE MONTHLY HEADCOUNT ANALYTICS VIEW
-- Purpose: Calculate monthly workforce headcount metrics
-- Grain: One row per calendar month
-- Source: analytics.vw_employee_monthly
-- ============================================================

CREATE OR REPLACE VIEW analytics.vw_monthly_headcount AS

SELECT
    month_date,

    COUNT(*) FILTER (
        WHERE employment_status = 'Active'
    ) AS month_end_headcount,

    COUNT(*) FILTER (
        WHERE employment_status = 'Terminated'
    ) AS terminations,

    COUNT(*) AS employees_present_during_month

FROM analytics.vw_employee_monthly

GROUP BY month_date;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 15: CREATE RECONCILED MONTHLY HEADCOUNT VIEW
-- Purpose: Establish official headcount and data coverage KPIs
-- Grain: One row per calendar month
-- Sources: staging.employees_hris, analytics.vw_monthly_headcount
-- ============================================================

CREATE OR REPLACE VIEW analytics.vw_monthly_headcount_reconciled AS

WITH employment_headcount AS (
    SELECT
        h.month_date,

        COUNT(e.employee_id) AS official_headcount

    FROM analytics.vw_monthly_headcount AS h

    LEFT JOIN staging.employees_hris AS e
        ON e.hire_date < (h.month_date + INTERVAL '1 month')
       AND (
           e.termination_date IS NULL
           OR e.termination_date >=
              (h.month_date + INTERVAL '1 month')
       )

    GROUP BY h.month_date
)

SELECT
    h.month_date,

    e.official_headcount,

    h.month_end_headcount AS observed_headcount,

    e.official_headcount - h.month_end_headcount
        AS headcount_coverage_gap,

    ROUND(
        100.0 * h.month_end_headcount
        / NULLIF(e.official_headcount, 0),
        4
    ) AS headcount_coverage_pct,

    h.terminations,

    h.employees_present_during_month

FROM analytics.vw_monthly_headcount AS h

JOIN employment_headcount AS e
    ON h.month_date = e.month_date;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 18: CREATE MONTHLY HIRING & SEPARATION ANALYTICS VIEW
-- Purpose: Calculate monthly hiring and separation KPIs
-- Grain: One row per calendar month
-- Period: January 2021 - December 2025
-- Source: staging.employees_hris
-- ============================================================

CREATE OR REPLACE VIEW analytics.vw_monthly_workforce_movements AS

WITH calendar_months AS (
    SELECT
        GENERATE_SERIES(
            DATE '2021-01-01',
            DATE '2025-12-01',
            INTERVAL '1 month'
        )::date AS month_date
),

monthly_hires AS (
    SELECT
        DATE_TRUNC('month', hire_date)::date AS month_date,
        COUNT(*) AS hires
    FROM staging.employees_hris
    WHERE hire_date >= DATE '2021-01-01'
      AND hire_date < DATE '2026-01-01'
    GROUP BY 1
),

monthly_separations AS (
    SELECT
        DATE_TRUNC('month', termination_date)::date AS month_date,

        COUNT(*) AS separations,

        COUNT(*) FILTER (
            WHERE termination_type = 'Voluntary'
        ) AS voluntary_separations,

        COUNT(*) FILTER (
            WHERE termination_type = 'Involuntary'
        ) AS involuntary_separations

    FROM staging.employees_hris
    WHERE termination_date >= DATE '2021-01-01'
      AND termination_date < DATE '2026-01-01'
    GROUP BY 1
)

SELECT
    c.month_date,

    COALESCE(h.hires, 0) AS hires,

    COALESCE(s.separations, 0) AS separations,

    COALESCE(s.voluntary_separations, 0)
        AS voluntary_separations,

    COALESCE(s.involuntary_separations, 0)
        AS involuntary_separations,

    COALESCE(h.hires, 0)
        - COALESCE(s.separations, 0)
        AS net_workforce_change

FROM calendar_months AS c

LEFT JOIN monthly_hires AS h
    ON c.month_date = h.month_date

LEFT JOIN monthly_separations AS s
    ON c.month_date = s.month_date;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 20: CREATE MONTHLY EMPLOYEE TURNOVER ANALYTICS VIEW
-- Purpose: Calculate monthly turnover using average headcount
-- Grain: One row per calendar month
-- Sources: Reconciled headcount and workforce movements
-- ============================================================

CREATE OR REPLACE VIEW analytics.vw_monthly_turnover AS

WITH monthly_base AS (
    SELECT
        h.month_date,
        h.official_headcount AS ending_headcount,

        LAG(h.official_headcount) OVER (
            ORDER BY h.month_date
        ) AS previous_month_headcount,

        m.hires,
        m.separations,
        m.voluntary_separations,
        m.involuntary_separations

    FROM analytics.vw_monthly_headcount_reconciled AS h

    JOIN analytics.vw_monthly_workforce_movements AS m
        ON h.month_date = m.month_date
),

headcount_base AS (
    SELECT
        *,

        COALESCE(
            previous_month_headcount,
            ending_headcount - hires + separations
        ) AS beginning_headcount

    FROM monthly_base
),

turnover_base AS (
    SELECT
        *,
        (beginning_headcount + ending_headcount) / 2.0
            AS average_headcount

    FROM headcount_base
)

SELECT
    month_date,
    beginning_headcount,
    ending_headcount,
    average_headcount,

    hires,
    separations,
    voluntary_separations,
    involuntary_separations,

    ROUND(
        100.0 * separations
        / NULLIF(average_headcount, 0),
        4
    ) AS monthly_turnover_rate_pct,

    ROUND(
        100.0 * voluntary_separations
        / NULLIF(average_headcount, 0),
        4
    ) AS voluntary_turnover_rate_pct,

    ROUND(
        100.0 * involuntary_separations
        / NULLIF(average_headcount, 0),
        4
    ) AS involuntary_turnover_rate_pct

FROM turnover_base;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 22: CREATE ANNUAL EMPLOYEE TURNOVER ANALYTICS VIEW
-- Purpose: Calculate annual workforce turnover KPIs
-- Grain: One row per calendar year
-- Source: analytics.vw_monthly_turnover
-- ============================================================

CREATE OR REPLACE VIEW analytics.vw_annual_turnover AS

SELECT
    EXTRACT(YEAR FROM month_date)::integer AS year,

    COUNT(*) AS months_in_year,

    SUM(hires) AS annual_hires,
    SUM(separations) AS annual_separations,

    SUM(voluntary_separations)
        AS annual_voluntary_separations,

    SUM(involuntary_separations)
        AS annual_involuntary_separations,

    ROUND(
        AVG(average_headcount), 2
    ) AS annual_average_headcount,

    ROUND(
        100.0 * SUM(separations)
        / NULLIF(AVG(average_headcount), 0),
        4
    ) AS annual_turnover_rate_pct,

    ROUND(
        100.0 * SUM(voluntary_separations)
        / NULLIF(AVG(average_headcount), 0),
        4
    ) AS annual_voluntary_turnover_pct,

    ROUND(
        100.0 * SUM(involuntary_separations)
        / NULLIF(AVG(average_headcount), 0),
        4
    ) AS annual_involuntary_turnover_pct

FROM analytics.vw_monthly_turnover

GROUP BY EXTRACT(YEAR FROM month_date);


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 24: CREATE ANNUAL WORKFORCE SUMMARY VIEW
-- Purpose: Combine annual headcount and workforce movement KPIs
-- Grain: One row per calendar year
-- Sources: Monthly headcount reconciliation and annual turnover
-- ============================================================

CREATE OR REPLACE VIEW analytics.vw_annual_workforce_summary AS

WITH annual_headcount AS (
    SELECT
        EXTRACT(YEAR FROM month_date)::integer AS year,

        MAX(official_headcount) FILTER (
            WHERE EXTRACT(MONTH FROM month_date) = 12
        ) AS year_end_headcount,

        ROUND(AVG(official_headcount), 2)
            AS average_month_end_headcount,

        SUM(headcount_coverage_gap)
            AS missing_employee_months

    FROM analytics.vw_monthly_headcount_reconciled

    GROUP BY EXTRACT(YEAR FROM month_date)
)

SELECT
    t.year,

    h.year_end_headcount,
    h.average_month_end_headcount,
    h.missing_employee_months,

    t.annual_hires,
    t.annual_separations,

    t.annual_hires - t.annual_separations
        AS net_workforce_change,

    t.annual_voluntary_separations,
    t.annual_involuntary_separations,

    t.annual_average_headcount,

    t.annual_turnover_rate_pct,
    t.annual_voluntary_turnover_pct,
    t.annual_involuntary_turnover_pct

FROM analytics.vw_annual_turnover AS t

JOIN annual_headcount AS h
    ON t.year = h.year;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 30: CREATE ANNUAL PROMOTION ANALYTICS VIEW
-- Purpose: Calculate annual promotion and salary growth KPIs
-- Grain: One row per calendar year
-- Sources: raw.promotion_history,
--          analytics.vw_annual_turnover
-- ============================================================

CREATE OR REPLACE VIEW analytics.vw_annual_promotions AS

WITH annual_promotion_events AS (
    SELECT
        EXTRACT(YEAR FROM promotion_date)::integer AS year,

        COUNT(*) AS promotion_events,

        COUNT(DISTINCT employee_id) AS promoted_employees,

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

    GROUP BY EXTRACT(YEAR FROM promotion_date)
)

SELECT
    t.year,

    COALESCE(p.promotion_events, 0)
        AS promotion_events,

    COALESCE(p.promoted_employees, 0)
        AS promoted_employees,

    t.annual_average_headcount,

    ROUND(
        100.0 * COALESCE(p.promoted_employees, 0)
        / NULLIF(t.annual_average_headcount, 0),
        2
    ) AS promotion_rate_pct,

    p.avg_salary_increase_pct,

    p.avg_salary_increase_amount

FROM analytics.vw_annual_turnover AS t

LEFT JOIN annual_promotion_events AS p
    ON t.year = p.year;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 35: CREATE PROMOTION RATE BY JOB LEVEL VIEW
-- Purpose: Measure annual promotion rates using
--          pre-promotion workforce levels
-- Grain: Year and previous job level
-- Sources: analytics.vw_employee_monthly,
--          raw.promotion_history
-- ============================================================

CREATE OR REPLACE VIEW analytics.vw_promotion_rate_by_level AS

WITH march_workforce AS (
    SELECT
        EXTRACT(YEAR FROM month_date)::integer AS year,
        job_level,

        COUNT(DISTINCT employee_id)
            AS employees_before_promotion

    FROM analytics.vw_employee_monthly

    WHERE EXTRACT(MONTH FROM month_date) = 3
      AND employment_status = 'Active'

    GROUP BY
        EXTRACT(YEAR FROM month_date),
        job_level
),

annual_promotions AS (
    SELECT
        EXTRACT(YEAR FROM promotion_date)::integer AS year,
        previous_level AS job_level,

        COUNT(*) AS promotion_events,

        COUNT(DISTINCT employee_id)
            AS promoted_employees

    FROM raw.promotion_history

    GROUP BY
        EXTRACT(YEAR FROM promotion_date),
        previous_level
)

SELECT
    w.year,
    w.job_level,

    w.employees_before_promotion,

    COALESCE(p.promotion_events, 0)
        AS promotion_events,

    COALESCE(p.promoted_employees, 0)
        AS promoted_employees,

    ROUND(
        100.0 * COALESCE(p.promoted_employees, 0)
        / NULLIF(w.employees_before_promotion, 0),
        2
    ) AS promotion_rate_pct

FROM march_workforce AS w

LEFT JOIN annual_promotions AS p
    ON w.year = p.year
   AND w.job_level = p.job_level;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 39: CREATE MONTHLY COMPENSATION KPI VIEW
-- Purpose: Calculate monthly salary distribution and
--          compensation positioning for active employees
-- Grain: One row per calendar month
-- Source: analytics.vw_employee_monthly
-- ============================================================

CREATE OR REPLACE VIEW analytics.vw_monthly_compensation AS

SELECT
    month_date,

    COUNT(DISTINCT employee_id)
        AS employees_with_compensation_data,

    ROUND(AVG(base_salary), 2)
        AS average_base_salary,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY base_salary
        )::numeric,
        2
    ) AS median_base_salary,

    ROUND(MIN(base_salary), 2)
        AS minimum_base_salary,

    ROUND(MAX(base_salary), 2)
        AS maximum_base_salary,

    ROUND(
        PERCENTILE_CONT(0.25) WITHIN GROUP (
            ORDER BY base_salary
        )::numeric,
        2
    ) AS salary_25th_percentile,

    ROUND(
        PERCENTILE_CONT(0.75) WITHIN GROUP (
            ORDER BY base_salary
        )::numeric,
        2
    ) AS salary_75th_percentile,

    ROUND(AVG(compa_ratio), 4)
        AS average_compa_ratio,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY compa_ratio
        )::numeric,
        4
    ) AS median_compa_ratio

FROM analytics.vw_employee_monthly

WHERE employment_status = 'Active'

GROUP BY month_date;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 42: CREATE COMPENSATION BY JOB LEVEL VIEW
-- Purpose: Measure salary distribution and compensation
--          positioning across organizational job levels
-- Grain: Month and job level
-- Source: analytics.vw_employee_monthly
-- ============================================================

CREATE OR REPLACE VIEW analytics.vw_compensation_by_level AS

SELECT
    month_date,
    job_level,

    COUNT(DISTINCT employee_id)
        AS employee_count,

    ROUND(AVG(base_salary), 2)
        AS average_base_salary,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY base_salary
        )::numeric,
        2
    ) AS median_base_salary,

    ROUND(MIN(base_salary), 2)
        AS minimum_base_salary,

    ROUND(MAX(base_salary), 2)
        AS maximum_base_salary,

    ROUND(
        PERCENTILE_CONT(0.25) WITHIN GROUP (
            ORDER BY base_salary
        )::numeric,
        2
    ) AS salary_25th_percentile,

    ROUND(
        PERCENTILE_CONT(0.75) WITHIN GROUP (
            ORDER BY base_salary
        )::numeric,
        2
    ) AS salary_75th_percentile,

    ROUND(AVG(compa_ratio), 4)
        AS average_compa_ratio

FROM analytics.vw_employee_monthly

WHERE employment_status = 'Active'

GROUP BY
    month_date,
    job_level;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 45: CREATE COMPENSATION BY DEPARTMENT VIEW
-- Purpose: Measure salary distributions and compensation
--          positioning across organizational departments
-- Grain: Month and department
-- Source: analytics.vw_employee_monthly
-- ============================================================

CREATE OR REPLACE VIEW analytics.vw_compensation_by_department AS

SELECT
    month_date,
    department,

    COUNT(DISTINCT employee_id)
        AS employee_count,

    ROUND(AVG(base_salary), 2)
        AS average_base_salary,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY base_salary
        )::numeric,
        2
    ) AS median_base_salary,

    ROUND(MIN(base_salary), 2)
        AS minimum_base_salary,

    ROUND(MAX(base_salary), 2)
        AS maximum_base_salary,

    ROUND(
        PERCENTILE_CONT(0.25) WITHIN GROUP (
            ORDER BY base_salary
        )::numeric,
        2
    ) AS salary_25th_percentile,

    ROUND(
        PERCENTILE_CONT(0.75) WITHIN GROUP (
            ORDER BY base_salary
        )::numeric,
        2
    ) AS salary_75th_percentile,

    ROUND(AVG(compa_ratio), 4)
        AS average_compa_ratio

FROM analytics.vw_employee_monthly

WHERE employment_status = 'Active'

GROUP BY
    month_date,
    department;


-- ============================================================
-- PHASE 4: ANALYTICS DATA MODEL & KPI DEVELOPMENT
-- STEP 50: CREATE MONTHLY OPERATIONAL KPI VIEW
-- Purpose: Consolidate performance, absence, workload,
--          and vacancy metrics for downstream analytics
-- Grain: One row per calendar month
-- Source: analytics.vw_employee_monthly
-- ============================================================

CREATE OR REPLACE VIEW analytics.vw_monthly_operational_kpis AS

SELECT
    month_date,

    COUNT(DISTINCT employee_id)
        AS active_employees_observed,

    COUNT(latest_performance_rating)
        AS employees_with_performance_data,

    ROUND(
        100.0 * COUNT(latest_performance_rating)
        / NULLIF(COUNT(*), 0),
        2
    ) AS performance_coverage_pct,

    ROUND(AVG(latest_performance_rating), 2)
        AS average_performance_rating,

    COUNT(unscheduled_absence_days)
        AS employees_with_absence_data,

    ROUND(AVG(unscheduled_absence_days), 2)
        AS average_unscheduled_absence_days,

    COUNT(average_weekly_hours)
        AS employees_with_weekly_hours_data,

    ROUND(AVG(average_weekly_hours), 2)
        AS average_weekly_hours,

    COUNT(recent_workload_metric)
        AS employees_with_workload_data,

    ROUND(AVG(recent_workload_metric), 4)
        AS average_recent_workload_metric,

    COUNT(team_vacancy_rate)
        AS employees_with_vacancy_data,

    ROUND(AVG(team_vacancy_rate), 4)
        AS average_team_vacancy_rate

FROM analytics.vw_employee_monthly

WHERE employment_status = 'Active'

GROUP BY month_date;
