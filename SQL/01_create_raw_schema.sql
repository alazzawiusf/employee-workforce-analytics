-- Employee & Workforce Analytics
-- PostgreSQL raw-layer schema definition
-- Source: synthetic HRIS CSV exports
-- Purpose: preserve source records for profiling and reconciliation.
-- Run once against an empty workforce_analytics database, before CSV imports.
-- No primary/foreign keys or data-cleaning constraints are applied to raw tables.

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS analytics;

CREATE TABLE raw.employees_hris (
    employee_id TEXT,
    hire_date DATE,
    termination_date DATE,
    employment_status TEXT,
    termination_type TEXT,
    current_department TEXT,
    current_job_family TEXT,
    current_job_role TEXT,
    current_job_level TEXT,
    current_manager_id TEXT,
    location TEXT,
    current_base_salary NUMERIC,
    current_compa_ratio NUMERIC,
    organizational_tenure_months INTEGER,
    role_tenure_months INTEGER,
    promotions_count INTEGER,
    latest_performance_rating NUMERIC
);

CREATE TABLE raw.employee_monthly_hris (
    employee_id TEXT,
    year_month TEXT,
    department TEXT,
    job_family TEXT,
    job_role TEXT,
    job_level TEXT,
    location TEXT,
    manager_id TEXT,
    base_salary NUMERIC,
    compa_ratio NUMERIC,
    organizational_tenure_months INTEGER,
    role_tenure_months INTEGER,
    months_since_last_promotion INTEGER,
    latest_performance_rating NUMERIC,
    team_vacancy_rate NUMERIC,
    average_weekly_hours NUMERIC,
    unscheduled_absence_days NUMERIC,
    recent_absence_metric INTEGER,
    recent_workload_metric NUMERIC,
    employment_status TEXT
);

CREATE TABLE raw.performance_history (
    employee_id TEXT,
    performance_year INTEGER,
    performance_rating INTEGER,
    underlying_performance_score NUMERIC
);

CREATE TABLE raw.promotion_history (
    employee_id TEXT,
    promotion_date DATE,
    previous_level TEXT,
    new_level TEXT,
    previous_role TEXT,
    new_role TEXT,
    salary_before NUMERIC,
    salary_after NUMERIC
);

CREATE TABLE raw.salary_history (
    employee_id TEXT,
    effective_date DATE,
    previous_salary NUMERIC,
    new_salary NUMERIC,
    change_percent NUMERIC,
    change_reason TEXT
);

CREATE TABLE raw.separation_history (
    employee_id TEXT,
    termination_date DATE,
    termination_type TEXT,
    department TEXT,
    job_role TEXT,
    job_level TEXT,
    tenure_at_exit_months INTEGER,
    salary_at_exit NUMERIC,
    last_performance_rating NUMERIC
);

CREATE TABLE raw.organization_structure (
    department TEXT,
    job_family TEXT,
    job_level TEXT,
    job_role TEXT,
    is_manager_level BOOLEAN,
    national_band_min NUMERIC,
    national_band_midpoint NUMERIC,
    national_band_max NUMERIC
);

CREATE TABLE raw.location_reference (
    location TEXT,
    geo_differential NUMERIC
);

CREATE TABLE raw.organization_events (
    year_month TEXT,
    event_type TEXT,
    department TEXT
);
