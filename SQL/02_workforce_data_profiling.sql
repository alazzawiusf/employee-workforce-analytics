-- ============================================================================
-- WORKFORCE ANALYTICS | PHASE 02: RAW DATA QUALITY PROFILING
-- Database: workforce_analytics | PostgreSQL 18
-- Schemas: raw (read-only in this script)
-- Purpose: reproducible evidence for data quality assessment.
-- All statements are SELECT-only; no raw data is changed.
-- Run individual statements in pgAdmin Query Tool; outputs are documented
-- separately in the Data Quality Profiling Report.
-- NOTE: An invalid exact reference value may be a spelling/formatting issue.
-- NOTE: Historical event coverage is not proof of event-value reconciliation.
-- ============================================================================


-- ============================================================================
-- 01 | ENTITY KEYS AND REFERENTIAL INTEGRITY
-- ============================================================================


-- Q01 | Source query 01
SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT employee_id) AS unique_employee_ids,
    COUNT(*) FILTER (
        WHERE employee_id IS NULL
    ) AS null_employee_ids,
    COUNT(*) FILTER (
        WHERE employee_id IS NOT NULL
    ) - COUNT(DISTINCT employee_id) AS duplicate_employee_ids
FROM raw.employees_hris;


-- Q02 | Source query 02
SELECT
    COUNT(*) AS orphan_records,
    COUNT(DISTINCT m.employee_id) AS affected_employees
FROM raw.employee_monthly_hris AS m
LEFT JOIN raw.employees_hris AS e
    ON m.employee_id = e.employee_id
WHERE e.employee_id IS NULL;


-- Q03 | Source query 03
SELECT
    'performance_history' AS table_name,
    COUNT(*) AS orphan_records
FROM raw.performance_history AS h
LEFT JOIN raw.employees_hris AS e
    ON h.employee_id = e.employee_id
WHERE e.employee_id IS NULL

UNION ALL

SELECT
    'promotion_history',
    COUNT(*)
FROM raw.promotion_history AS h
LEFT JOIN raw.employees_hris AS e
    ON h.employee_id = e.employee_id
WHERE e.employee_id IS NULL

UNION ALL

SELECT
    'salary_history',
    COUNT(*)
FROM raw.salary_history AS h
LEFT JOIN raw.employees_hris AS e
    ON h.employee_id = e.employee_id
WHERE e.employee_id IS NULL

UNION ALL

SELECT
    'separation_history',
    COUNT(*)
FROM raw.separation_history AS h
LEFT JOIN raw.employees_hris AS e
    ON h.employee_id = e.employee_id
WHERE e.employee_id IS NULL;


-- Q04 | Source query 04
SELECT
    'employee_monthly_hris' AS table_name,
    COUNT(*) AS duplicate_groups
FROM (
    SELECT employee_id, year_month
    FROM raw.employee_monthly_hris
    GROUP BY employee_id, year_month
    HAVING COUNT(*) > 1
) AS duplicates

UNION ALL

SELECT
    'performance_history',
    COUNT(*)
FROM (
    SELECT employee_id, performance_year
    FROM raw.performance_history
    GROUP BY employee_id, performance_year
    HAVING COUNT(*) > 1
) AS duplicates

UNION ALL

SELECT
    'promotion_history',
    COUNT(*)
FROM (
    SELECT employee_id, promotion_date
    FROM raw.promotion_history
    GROUP BY employee_id, promotion_date
    HAVING COUNT(*) > 1
) AS duplicates

UNION ALL

SELECT
    'salary_history',
    COUNT(*)
FROM (
    SELECT employee_id, effective_date
    FROM raw.salary_history
    GROUP BY employee_id, effective_date
    HAVING COUNT(*) > 1
) AS duplicates;


-- Q05 | Source query 05
WITH repeated_dates AS (
    SELECT
        employee_id,
        effective_date
    FROM raw.salary_history
    GROUP BY employee_id, effective_date
    HAVING COUNT(*) > 1
)
SELECT
    s.change_reason,
    COUNT(*) AS records
FROM raw.salary_history AS s
JOIN repeated_dates AS r
    ON s.employee_id = r.employee_id
   AND s.effective_date = r.effective_date
GROUP BY s.change_reason
ORDER BY records DESC;


-- Q06 | Source query 06
SELECT
    COUNT(*) AS duplicate_groups
FROM (
    SELECT
        employee_id,
        effective_date,
        change_reason
    FROM raw.salary_history
    GROUP BY
        employee_id,
        effective_date,
        change_reason
    HAVING COUNT(*) > 1
) AS duplicates;


-- ============================================================================
-- 02 | EMPLOYEE MASTER: REFERENCE QUALITY
-- ============================================================================


-- Q07 | Source query 07
SELECT
    COUNT(*) FILTER (
        WHERE e.current_department IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM raw.organization_structure AS s
              WHERE s.department = e.current_department
          )
    ) AS invalid_departments,

    COUNT(*) FILTER (
        WHERE e.location IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM raw.location_reference AS l
              WHERE l.location = e.location
          )
    ) AS invalid_locations,

    COUNT(*) FILTER (
        WHERE e.location IS NULL
    ) AS missing_locations

FROM raw.employees_hris AS e;


-- Q08 | Source query 08
SELECT
    e.current_department AS invalid_department,
    COUNT(*) AS affected_records
FROM raw.employees_hris AS e
WHERE e.current_department IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM raw.organization_structure AS s
      WHERE s.department = e.current_department
  )
GROUP BY e.current_department
ORDER BY affected_records DESC;


-- Q09 | Source query 09
SELECT
    e.location AS invalid_location,
    COUNT(*) AS affected_records
FROM raw.employees_hris AS e
WHERE e.location IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM raw.location_reference AS l
      WHERE l.location = e.location
  )
GROUP BY e.location
ORDER BY affected_records DESC;


-- Q10 | Source query 10
SELECT
    COUNT(*) AS invalid_job_role_records,
    COUNT(DISTINCT e.current_job_role)
        FILTER (
            WHERE e.current_job_role IS NOT NULL
              AND NOT EXISTS (
                  SELECT 1
                  FROM raw.organization_structure AS s
                  WHERE s.job_role = e.current_job_role
              )
        ) AS distinct_invalid_roles
FROM raw.employees_hris AS e
WHERE e.current_job_role IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM raw.organization_structure AS s
      WHERE s.job_role = e.current_job_role
  );


-- Q11 | Source query 12
SELECT
    COUNT(*) AS total_invalid_roles,

    COUNT(*) FILTER (
        WHERE EXISTS (
            SELECT 1
            FROM raw.organization_structure AS s
            WHERE LOWER(TRIM(s.job_role)) =
                  LOWER(TRIM(e.current_job_role))
        )
    ) AS resolved_by_basic_normalization,

    COUNT(*) FILTER (
        WHERE NOT EXISTS (
            SELECT 1
            FROM raw.organization_structure AS s
            WHERE LOWER(TRIM(s.job_role)) =
                  LOWER(TRIM(e.current_job_role))
        )
    ) AS requiring_further_investigation

FROM raw.employees_hris AS e
WHERE e.current_job_role IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM raw.organization_structure AS s
      WHERE s.job_role = e.current_job_role
  );


-- Q12 | Source query 14
WITH invalid_roles AS (
    SELECT
        e.current_job_role,
        e.current_job_family,
        e.current_job_level
    FROM raw.employees_hris e
    WHERE e.current_job_role IS NOT NULL
      AND NOT EXISTS (
          SELECT 1
          FROM raw.organization_structure s
          WHERE s.job_role = e.current_job_role
      )
),
normalized AS (
    SELECT
        *,
        LOWER(TRIM(current_job_role)) AS basic_role,
        LOWER(
            REGEXP_REPLACE(
                REGEXP_REPLACE(
                    TRIM(current_job_role),
                    '^Sr\.\s*', 'Senior ', 'i'
                ),
                '^Assoc\.\s*', 'Associate ', 'i'
            )
        ) AS expanded_role
    FROM invalid_roles
)
SELECT
    COUNT(*) AS total_invalid,

    COUNT(*) FILTER (
        WHERE EXISTS (
            SELECT 1
            FROM raw.organization_structure s
            WHERE LOWER(TRIM(s.job_role)) = n.basic_role
        )
    ) AS basic_normalization,

    COUNT(*) FILTER (
        WHERE NOT EXISTS (
            SELECT 1
            FROM raw.organization_structure s
            WHERE LOWER(TRIM(s.job_role)) = n.basic_role
        )
        AND EXISTS (
            SELECT 1
            FROM raw.organization_structure s
            WHERE LOWER(TRIM(s.job_role)) = n.expanded_role
              AND s.job_family = n.current_job_family
              AND s.job_level = n.current_job_level
        )
    ) AS abbreviation_expansion,

    COUNT(*) FILTER (
        WHERE NOT EXISTS (
            SELECT 1
            FROM raw.organization_structure s
            WHERE LOWER(TRIM(s.job_role)) = n.basic_role
        )
        AND NOT EXISTS (
            SELECT 1
            FROM raw.organization_structure s
            WHERE LOWER(TRIM(s.job_role)) = n.expanded_role
              AND s.job_family = n.current_job_family
              AND s.job_level = n.current_job_level
        )
    ) AS still_unresolved

FROM normalized n;


-- Q13 | Source query 17
WITH roles AS (
    SELECT
        e.current_job_role,
        e.current_job_family,
        e.current_job_level,
        LOWER(TRIM(e.current_job_role)) AS basic_role,
        LOWER(
            REGEXP_REPLACE(
                REGEXP_REPLACE(
                    TRIM(e.current_job_role),
                    '^Sr\.\s*', 'Senior ', 'i'
                ),
                '^Assoc\.\s*', 'Associate ', 'i'
            )
        ) AS first_expansion,
        LOWER(TRIM(
            REGEXP_REPLACE(
                REGEXP_REPLACE(
                    REGEXP_REPLACE(
                        REGEXP_REPLACE(
                            REGEXP_REPLACE(
                                e.current_job_role,
                                '\mAnlst\M', 'Analyst', 'gi'
                            ),
                            '\mEng\M', 'Engineer', 'gi'
                        ),
                        '\mMgr\M', 'Manager', 'gi'
                    ),
                    '\mSpec\.', 'Specialist', 'gi'
                ),
                '\mDir\.', 'Director', 'gi'
            )
        )) AS second_expansion
    FROM raw.employees_hris e
    WHERE e.current_job_role IS NOT NULL
),
unresolved AS (
    SELECT *
    FROM roles r
    WHERE NOT EXISTS (
        SELECT 1
        FROM raw.organization_structure s
        WHERE LOWER(TRIM(s.job_role)) = r.basic_role
    )
    AND NOT EXISTS (
        SELECT 1
        FROM raw.organization_structure s
        WHERE LOWER(TRIM(s.job_role)) = r.first_expansion
          AND s.job_family = r.current_job_family
          AND s.job_level = r.current_job_level
    )
)
SELECT
    COUNT(*) AS previously_unresolved,

    COUNT(*) FILTER (
        WHERE EXISTS (
            SELECT 1
            FROM raw.organization_structure s
            WHERE LOWER(TRIM(s.job_role)) = u.second_expansion
              AND s.job_family = u.current_job_family
              AND s.job_level = u.current_job_level
        )
    ) AS resolved_by_new_abbreviations,

    COUNT(*) FILTER (
        WHERE NOT EXISTS (
            SELECT 1
            FROM raw.organization_structure s
            WHERE LOWER(TRIM(s.job_role)) = u.second_expansion
              AND s.job_family = u.current_job_family
              AND s.job_level = u.current_job_level
        )
    ) AS remaining_unresolved

FROM unresolved u;


-- Q14 | Source query 18
WITH roles AS (
    SELECT
        e.employee_id,
        e.current_job_role,
        e.current_job_family,
        e.current_job_level,
        LOWER(TRIM(e.current_job_role)) AS basic_role,
        LOWER(
            REGEXP_REPLACE(
                REGEXP_REPLACE(
                    TRIM(e.current_job_role),
                    '^Sr\.\s*', 'Senior ', 'i'
                ),
                '^Assoc\.\s*', 'Associate ', 'i'
            )
        ) AS first_expansion,
        LOWER(TRIM(
            REGEXP_REPLACE(
                REGEXP_REPLACE(
                    REGEXP_REPLACE(
                        REGEXP_REPLACE(
                            REGEXP_REPLACE(
                                e.current_job_role,
                                '\mAnlst\M', 'Analyst', 'gi'
                            ),
                            '\mEng\M', 'Engineer', 'gi'
                        ),
                        '\mMgr\M', 'Manager', 'gi'
                    ),
                    '\mSpec\.', 'Specialist', 'gi'
                ),
                '\mDir\.', 'Director', 'gi'
            )
        )) AS second_expansion
    FROM raw.employees_hris e
    WHERE e.current_job_role IS NOT NULL
),
unresolved AS (
    SELECT *
    FROM roles r
    WHERE NOT EXISTS (
        SELECT 1
        FROM raw.organization_structure s
        WHERE LOWER(TRIM(s.job_role)) = r.basic_role
    )
    AND NOT EXISTS (
        SELECT 1
        FROM raw.organization_structure s
        WHERE LOWER(TRIM(s.job_role)) = r.first_expansion
          AND s.job_family = r.current_job_family
          AND s.job_level = r.current_job_level
    )
    AND NOT EXISTS (
        SELECT 1
        FROM raw.organization_structure s
        WHERE LOWER(TRIM(s.job_role)) = r.second_expansion
          AND s.job_family = r.current_job_family
          AND s.job_level = r.current_job_level
    )
)
SELECT
    u.current_job_role AS invalid_role,
    u.current_job_family,
    u.current_job_level,
    COUNT(DISTINCT s.job_role) AS candidate_count,
    STRING_AGG(DISTINCT s.job_role, ' | ' ORDER BY s.job_role)
        AS possible_reference_roles
FROM unresolved u
LEFT JOIN raw.organization_structure s
    ON s.job_family = u.current_job_family
   AND s.job_level = u.current_job_level
GROUP BY
    u.current_job_role,
    u.current_job_family,
    u.current_job_level
ORDER BY candidate_count ASC, invalid_role;


-- ============================================================================
-- 03 | EMPLOYEE MASTER: COMPLETENESS AND SEPARATION RECONCILIATION
-- ============================================================================


-- Q15 | Source query 20
SELECT
    COUNT(*) AS total_employees,

    COUNT(*) FILTER (
        WHERE termination_date IS NULL
    ) AS missing_termination_date,

    COUNT(*) FILTER (
        WHERE termination_type IS NULL
    ) AS missing_termination_type,

    COUNT(*) FILTER (
        WHERE current_manager_id IS NULL
    ) AS missing_manager_id,

    COUNT(*) FILTER (
        WHERE location IS NULL
    ) AS missing_location,

    COUNT(*) FILTER (
        WHERE latest_performance_rating IS NULL
    ) AS missing_performance_rating

FROM raw.employees_hris;


-- Q16 | Source query 21
SELECT
    employment_status,
    COUNT(*) AS total_employees,

    COUNT(*) FILTER (
        WHERE termination_date IS NULL
    ) AS missing_termination_date,

    COUNT(*) FILTER (
        WHERE termination_date IS NOT NULL
    ) AS has_termination_date,

    COUNT(*) FILTER (
        WHERE termination_type IS NULL
    ) AS missing_termination_type,

    COUNT(*) FILTER (
        WHERE termination_type IS NOT NULL
    ) AS has_termination_type

FROM raw.employees_hris
GROUP BY employment_status
ORDER BY employment_status;


-- Q17 | Source query 23
SELECT
    COUNT(*) AS terminated_missing_type,

    COUNT(*) FILTER (
        WHERE s.employee_id IS NOT NULL
    ) AS found_in_separation_history,

    COUNT(*) FILTER (
        WHERE s.termination_type IS NOT NULL
    ) AS recoverable_termination_types,

    COUNT(*) FILTER (
        WHERE s.employee_id IS NULL
    ) AS not_found_in_separation_history

FROM raw.employees_hris e

LEFT JOIN raw.separation_history s
    ON e.employee_id = s.employee_id

WHERE e.employment_status = 'Terminated'
  AND e.termination_type IS NULL;


-- Q18 | Source query 24
SELECT
    e.employment_status,
    COUNT(*) AS employee_count,

    COUNT(*) FILTER (
        WHERE s.employee_id IS NOT NULL
    ) AS found_in_separation_history,

    COUNT(*) FILTER (
        WHERE s.employee_id IS NULL
    ) AS not_found_in_separation_history

FROM raw.employees_hris e

LEFT JOIN raw.separation_history s
    ON e.employee_id = s.employee_id

GROUP BY e.employment_status
ORDER BY e.employment_status;


-- Q19 | Source query 25
SELECT
    e.employee_id,
    e.employment_status,
    e.hire_date,
    e.termination_date AS master_termination_date,
    s.termination_date AS history_termination_date,
    s.termination_type AS history_termination_type,
    CASE
        WHEN s.termination_date < e.hire_date
            THEN 'Possible Rehire'
        WHEN s.termination_date >= e.hire_date
            THEN 'Separation After Hire'
        ELSE 'Missing Date'
    END AS investigation_category
FROM raw.employees_hris e
JOIN raw.separation_history s
    ON e.employee_id = s.employee_id
WHERE e.employment_status = 'Active'
ORDER BY s.termination_date;


-- Q20 | Source query 27
WITH conflicting_employees AS (
    SELECT
        e.employee_id,
        s.termination_date
    FROM raw.employees_hris e
    JOIN raw.separation_history s
        ON e.employee_id = s.employee_id
    WHERE e.employment_status = 'Active'
),
monthly_activity AS (
    SELECT
        c.employee_id,
        c.termination_date,
        MAX(TO_DATE(m.year_month, 'YYYY-MM'))
            AS last_monthly_record,
        COUNT(*) FILTER (
            WHERE TO_DATE(m.year_month, 'YYYY-MM')
                > DATE_TRUNC('month', c.termination_date)
        ) AS months_after_separation
    FROM conflicting_employees c
    LEFT JOIN raw.employee_monthly_hris m
        ON c.employee_id = m.employee_id
    GROUP BY
        c.employee_id,
        c.termination_date
)
SELECT
    COUNT(*) AS conflicting_employees,

    COUNT(*) FILTER (
        WHERE months_after_separation > 0
    ) AS employees_with_records_after_separation,

    COUNT(*) FILTER (
        WHERE months_after_separation = 0
    ) AS employees_without_records_after_separation,

    MAX(months_after_separation)
        AS max_months_after_separation

FROM monthly_activity;


-- Q21 | Source query 28
WITH conflicting_employees AS (
    SELECT
        e.employee_id,
        s.termination_date
    FROM raw.employees_hris e
    JOIN raw.separation_history s
        ON e.employee_id = s.employee_id
    WHERE e.employment_status = 'Active'
),
monthly_records AS (
    SELECT
        c.employee_id,
        c.termination_date,
        TO_DATE(m.year_month, 'YYYY-MM') AS record_month,
        m.employment_status AS monthly_status
    FROM conflicting_employees c
    JOIN raw.employee_monthly_hris m
        ON c.employee_id = m.employee_id
)
SELECT
    CASE
        WHEN record_month =
             DATE_TRUNC('month', termination_date)::date
            THEN 'Separation Month'

        WHEN record_month >
             DATE_TRUNC('month', termination_date)::date
            THEN 'After Separation'

        ELSE 'Before Separation'
    END AS record_period,

    monthly_status,

    COUNT(*) AS monthly_records,
    COUNT(DISTINCT employee_id) AS unique_employees

FROM monthly_records

WHERE record_month >=
      DATE_TRUNC('month', termination_date)::date

GROUP BY record_period, monthly_status

ORDER BY record_period, monthly_status;


-- ============================================================================
-- 04 | MONTHLY HRIS: COMPLETENESS AND MISSINGNESS PATTERNS
-- ============================================================================


-- Q22 | Source query 30
SELECT
    COUNT(*) AS total_records,

    COUNT(*) FILTER (
        WHERE department IS NULL
    ) AS missing_department,

    COUNT(*) FILTER (
        WHERE job_family IS NULL
    ) AS missing_job_family,

    COUNT(*) FILTER (
        WHERE job_role IS NULL
    ) AS missing_job_role,

    COUNT(*) FILTER (
        WHERE job_level IS NULL
    ) AS missing_job_level,

    COUNT(*) FILTER (
        WHERE location IS NULL
    ) AS missing_location,

    COUNT(*) FILTER (
        WHERE manager_id IS NULL
    ) AS missing_manager_id,

    COUNT(*) FILTER (
        WHERE latest_performance_rating IS NULL
    ) AS missing_performance_rating,

    COUNT(*) FILTER (
        WHERE average_weekly_hours IS NULL
    ) AS missing_weekly_hours,

    COUNT(*) FILTER (
        WHERE unscheduled_absence_days IS NULL
    ) AS missing_absence_days,

    COUNT(*) FILTER (
        WHERE base_salary IS NULL
    ) AS missing_base_salary,

    COUNT(*) FILTER (
        WHERE employment_status IS NULL
    ) AS missing_employment_status

FROM raw.employee_monthly_hris;


-- Q23 | Source query 31
SELECT
    CASE
        WHEN organizational_tenure_months < 6
            THEN 'Less than 6 months'
        WHEN organizational_tenure_months < 12
            THEN '6-11 months'
        WHEN organizational_tenure_months < 24
            THEN '12-23 months'
        WHEN organizational_tenure_months < 60
            THEN '24-59 months'
        ELSE '60+ months'
    END AS tenure_group,

    COUNT(*) AS total_records,

    COUNT(*) FILTER (
        WHERE latest_performance_rating IS NULL
    ) AS missing_ratings,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE latest_performance_rating IS NULL
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS missing_percentage

FROM raw.employee_monthly_hris

GROUP BY tenure_group

ORDER BY
    MIN(organizational_tenure_months);


-- Q24 | Source query 32
SELECT
    job_level,
    job_role,
    COUNT(*) AS missing_manager_records,
    COUNT(DISTINCT employee_id) AS affected_employees,
    MIN(year_month) AS first_month,
    MAX(year_month) AS last_month

FROM raw.employee_monthly_hris

WHERE manager_id IS NULL

GROUP BY
    job_level,
    job_role

ORDER BY
    missing_manager_records DESC,
    job_level;


-- Q25 | Source query 33
SELECT
    employee_id,
    COUNT(*) AS monthly_records,
    COUNT(DISTINCT job_role) AS distinct_job_roles,
    STRING_AGG(DISTINCT job_role, ' | ') AS job_role_variations,
    MIN(year_month) AS first_month,
    MAX(year_month) AS last_month

FROM raw.employee_monthly_hris

WHERE manager_id IS NULL

GROUP BY employee_id

ORDER BY employee_id;


-- Q26 | Source query 34
SELECT
    LEFT(year_month, 4) AS calendar_year,

    COUNT(*) AS total_records,

    COUNT(*) FILTER (
        WHERE average_weekly_hours IS NULL
    ) AS missing_weekly_hours,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE average_weekly_hours IS NULL
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS missing_weekly_hours_pct,

    COUNT(*) FILTER (
        WHERE unscheduled_absence_days IS NULL
    ) AS missing_absence_days,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE unscheduled_absence_days IS NULL
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS missing_absence_days_pct

FROM raw.employee_monthly_hris

GROUP BY LEFT(year_month, 4)

ORDER BY calendar_year;


-- ============================================================================
-- 05 | MONTHLY HRIS: REFERENCE AND STRUCTURAL VALIDATION
-- ============================================================================


-- Q27 | Source query 35
SELECT
    department,

    COUNT(*) AS total_records,

    COUNT(*) FILTER (
        WHERE average_weekly_hours IS NULL
    ) AS missing_weekly_hours,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE average_weekly_hours IS NULL
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS missing_weekly_hours_pct,

    COUNT(*) FILTER (
        WHERE unscheduled_absence_days IS NULL
    ) AS missing_absence_days,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE unscheduled_absence_days IS NULL
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS missing_absence_days_pct

FROM raw.employee_monthly_hris

GROUP BY department

ORDER BY total_records DESC;


-- Q28 | Source query 36
SELECT
    COUNT(*) AS total_monthly_records,

    COUNT(*) FILTER (
        WHERE NOT EXISTS (
            SELECT 1
            FROM raw.organization_structure s
            WHERE s.department = m.department
        )
    ) AS invalid_department_records,

    COUNT(DISTINCT department) AS distinct_department_values,

    COUNT(DISTINCT department) FILTER (
        WHERE NOT EXISTS (
            SELECT 1
            FROM raw.organization_structure s
            WHERE s.department = m.department
        )
    ) AS distinct_invalid_departments,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE NOT EXISTS (
                SELECT 1
                FROM raw.organization_structure s
                WHERE s.department = m.department
            )
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS invalid_department_pct

FROM raw.employee_monthly_hris m;


-- Q29 | Source query 37
SELECT
    COUNT(*) AS total_monthly_records,

    COUNT(*) FILTER (
        WHERE m.location IS NULL
    ) AS missing_location_records,

    COUNT(*) FILTER (
        WHERE m.location IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM raw.location_reference l
              WHERE l.location = m.location
          )
    ) AS invalid_location_records,

    COUNT(DISTINCT m.location) AS distinct_location_values,

    COUNT(DISTINCT m.location) FILTER (
        WHERE NOT EXISTS (
            SELECT 1
            FROM raw.location_reference l
            WHERE l.location = m.location
        )
    ) AS distinct_invalid_locations,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE m.location IS NOT NULL
              AND NOT EXISTS (
                  SELECT 1
                  FROM raw.location_reference l
                  WHERE l.location = m.location
              )
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS invalid_location_pct

FROM raw.employee_monthly_hris m;


-- Q30 | Source query 38
SELECT
    COUNT(*) AS total_monthly_records,

    COUNT(*) FILTER (
        WHERE NOT EXISTS (
            SELECT 1
            FROM raw.organization_structure s
            WHERE s.job_role = m.job_role
        )
    ) AS invalid_job_role_records,

    COUNT(*) FILTER (
        WHERE NOT EXISTS (
            SELECT 1
            FROM raw.organization_structure s
            WHERE s.job_family = m.job_family
        )
    ) AS invalid_job_family_records,

    COUNT(DISTINCT m.job_role) AS distinct_job_roles,

    COUNT(DISTINCT m.job_role) FILTER (
        WHERE NOT EXISTS (
            SELECT 1
            FROM raw.organization_structure s
            WHERE s.job_role = m.job_role
        )
    ) AS distinct_invalid_job_roles,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE NOT EXISTS (
                SELECT 1
                FROM raw.organization_structure s
                WHERE s.job_role = m.job_role
            )
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS invalid_job_role_pct

FROM raw.employee_monthly_hris m;


-- ============================================================================
-- 06 | MONTHLY HRIS: NUMERIC AND TEMPORAL VALIDATION
-- ============================================================================


-- Q31 | Source query 39
SELECT
    COUNT(*) AS total_monthly_records,

    COUNT(*) FILTER (
        WHERE EXISTS (
            SELECT 1
            FROM raw.organization_structure s
            WHERE s.job_role = m.job_role
              AND s.job_family = m.job_family
              AND s.job_level = m.job_level
        )
    ) AS valid_job_combinations,

    COUNT(*) FILTER (
        WHERE NOT EXISTS (
            SELECT 1
            FROM raw.organization_structure s
            WHERE s.job_role = m.job_role
              AND s.job_family = m.job_family
              AND s.job_level = m.job_level
        )
    ) AS invalid_job_combinations,

    COUNT(*) FILTER (
        WHERE EXISTS (
            SELECT 1
            FROM raw.organization_structure s
            WHERE s.job_role = m.job_role
        )
        AND NOT EXISTS (
            SELECT 1
            FROM raw.organization_structure s
            WHERE s.job_role = m.job_role
              AND s.job_family = m.job_family
              AND s.job_level = m.job_level
        )
    ) AS valid_role_but_invalid_combination

FROM raw.employee_monthly_hris m;


-- Q32 | Source query 40
SELECT
    COUNT(*) AS total_records,

    COUNT(*) FILTER (
        WHERE base_salary <= 0
    ) AS invalid_base_salary,

    COUNT(*) FILTER (
        WHERE compa_ratio <= 0
    ) AS invalid_compa_ratio,

    COUNT(*) FILTER (
        WHERE organizational_tenure_months < 0
           OR role_tenure_months < 0
           OR months_since_last_promotion < 0
    ) AS negative_tenure_or_promotion_months,

    COUNT(*) FILTER (
        WHERE role_tenure_months > organizational_tenure_months
    ) AS role_tenure_exceeds_org_tenure,

    COUNT(*) FILTER (
        WHERE team_vacancy_rate < 0
           OR team_vacancy_rate > 1
    ) AS invalid_vacancy_rate,

    COUNT(*) FILTER (
        WHERE average_weekly_hours < 0
           OR average_weekly_hours > 168
    ) AS invalid_weekly_hours,

    COUNT(*) FILTER (
        WHERE unscheduled_absence_days < 0
           OR unscheduled_absence_days > 31
    ) AS invalid_absence_days,

    COUNT(*) FILTER (
        WHERE latest_performance_rating < 1
           OR latest_performance_rating > 5
    ) AS invalid_performance_rating

FROM raw.employee_monthly_hris;


-- Q33 | Source query 41
WITH monthly_sequence AS (
    SELECT
        employee_id,
        year_month,
        organizational_tenure_months,

        LAG(year_month) OVER (
            PARTITION BY employee_id
            ORDER BY year_month
        ) AS previous_month,

        LAG(organizational_tenure_months) OVER (
            PARTITION BY employee_id
            ORDER BY year_month
        ) AS previous_tenure

    FROM raw.employee_monthly_hris
)

SELECT
    COUNT(*) AS records_with_previous_month,

    COUNT(*) FILTER (
        WHERE (
            EXTRACT(YEAR FROM AGE(
                TO_DATE(year_month || '-01', 'YYYY-MM-DD'),
                TO_DATE(previous_month || '-01', 'YYYY-MM-DD')
            )) * 12
            +
            EXTRACT(MONTH FROM AGE(
                TO_DATE(year_month || '-01', 'YYYY-MM-DD'),
                TO_DATE(previous_month || '-01', 'YYYY-MM-DD')
            ))
        ) = 1
        AND organizational_tenure_months
            <> previous_tenure + 1
    ) AS tenure_increment_violations

FROM monthly_sequence
WHERE previous_month IS NOT NULL;


-- Q34 | Source query 42
WITH monthly_sequence AS (
    SELECT
        employee_id,
        year_month,
        organizational_tenure_months,

        LAG(year_month) OVER (
            PARTITION BY employee_id
            ORDER BY year_month
        ) AS previous_month,

        LAG(organizational_tenure_months) OVER (
            PARTITION BY employee_id
            ORDER BY year_month
        ) AS previous_tenure

    FROM raw.employee_monthly_hris
),

consecutive_months AS (
    SELECT
        *,
        organizational_tenure_months - previous_tenure
            AS tenure_change

    FROM monthly_sequence

    WHERE previous_month IS NOT NULL
      AND (
          (
              LEFT(year_month, 4)::INT * 12
              + RIGHT(year_month, 2)::INT
          )
          -
          (
              LEFT(previous_month, 4)::INT * 12
              + RIGHT(previous_month, 2)::INT
          )
      ) = 1
)

SELECT
    tenure_change,
    COUNT(*) AS affected_records,
    COUNT(DISTINCT employee_id) AS affected_employees

FROM consecutive_months

WHERE tenure_change <> 1

GROUP BY tenure_change
ORDER BY affected_records DESC;


-- Q35 | Source query 43
WITH status_sequence AS (
    SELECT
        employee_id,
        year_month,
        employment_status,

        LAG(employment_status) OVER (
            PARTITION BY employee_id
            ORDER BY year_month
        ) AS previous_status

    FROM raw.employee_monthly_hris
)

SELECT
    previous_status,
    employment_status AS current_status,

    COUNT(*) AS transition_records,
    COUNT(DISTINCT employee_id) AS affected_employees

FROM status_sequence

WHERE previous_status IS NOT NULL
  AND previous_status <> employment_status

GROUP BY
    previous_status,
    employment_status

ORDER BY transition_records DESC;


-- Q36 | Source query 44
WITH latest_monthly_status AS (
    SELECT DISTINCT ON (employee_id)
        employee_id,
        year_month AS latest_month,
        employment_status AS monthly_status
    FROM raw.employee_monthly_hris
    ORDER BY employee_id, year_month DESC
)

SELECT
    e.employment_status AS master_status,
    m.monthly_status,
    COUNT(*) AS employee_count

FROM raw.employees_hris e

JOIN latest_monthly_status m
    ON e.employee_id = m.employee_id

GROUP BY
    e.employment_status,
    m.monthly_status

ORDER BY
    master_status,
    monthly_status;


-- ============================================================================
-- 07 | MONTHLY HRIS: MANAGEMENT HIERARCHY
-- ============================================================================


-- Q37 | Source query 45
SELECT
    COUNT(*) AS total_monthly_records,

    COUNT(*) FILTER (
        WHERE m.manager_id IS NULL
    ) AS missing_manager_records,

    COUNT(*) FILTER (
        WHERE m.manager_id IS NOT NULL
          AND mgr.employee_id IS NULL
    ) AS manager_not_found_same_month,

    COUNT(*) FILTER (
        WHERE m.manager_id = m.employee_id
    ) AS self_reporting_records,

    COUNT(DISTINCT m.employee_id) FILTER (
        WHERE m.manager_id IS NOT NULL
          AND mgr.employee_id IS NULL
    ) AS employees_with_missing_manager_reference

FROM raw.employee_monthly_hris m

LEFT JOIN raw.employee_monthly_hris mgr
    ON m.manager_id = mgr.employee_id
   AND m.year_month = mgr.year_month;


-- Q38 | Source query 46
WITH missing_manager_references AS (
    SELECT
        m.employee_id,
        m.year_month,
        m.manager_id

    FROM raw.employee_monthly_hris m

    WHERE m.manager_id IS NOT NULL

      AND NOT EXISTS (
          SELECT 1
          FROM raw.employee_monthly_hris mgr
          WHERE mgr.employee_id = m.manager_id
            AND mgr.year_month = m.year_month
      )
)

SELECT
    CASE
        WHEN e.employee_id IS NULL
            THEN 'Manager not found in employee master'
        ELSE 'Manager exists in master but missing that month'
    END AS issue_type,

    COUNT(*) AS affected_records,

    COUNT(DISTINCT m.employee_id) AS affected_employees,

    COUNT(DISTINCT m.manager_id) AS distinct_managers

FROM missing_manager_references m

LEFT JOIN raw.employees_hris e
    ON m.manager_id = e.employee_id

GROUP BY issue_type
ORDER BY affected_records DESC;


-- Q39 | Source query 47
SELECT
    COUNT(*) AS valid_manager_month_pairs,

    COUNT(*) FILTER (
        WHERE mgr.job_level <= m.job_level
    ) AS hierarchy_violations,

    COUNT(*) FILTER (
        WHERE mgr.job_level = m.job_level
    ) AS same_level_reporting,

    COUNT(*) FILTER (
        WHERE mgr.job_level < m.job_level
    ) AS lower_level_manager,

    COUNT(DISTINCT m.employee_id) FILTER (
        WHERE mgr.job_level <= m.job_level
    ) AS affected_employees

FROM raw.employee_monthly_hris m

JOIN raw.employee_monthly_hris mgr
    ON m.manager_id = mgr.employee_id
   AND m.year_month = mgr.year_month;


-- ============================================================================
-- 08 | HISTORICAL EVENT COVERAGE
-- ============================================================================


-- Q40 | Source query 48
WITH employee_monthly_coverage AS (
    SELECT
        employee_id,
        MIN(year_month) AS first_month,
        MAX(year_month) AS last_month
    FROM raw.employee_monthly_hris
    GROUP BY employee_id
)

SELECT
    COUNT(*) AS total_promotions,

    COUNT(*) FILTER (
        WHERE c.employee_id IS NULL
    ) AS promotions_without_monthly_records,

    COUNT(*) FILTER (
        WHERE TO_CHAR(p.promotion_date, 'YYYY-MM') < c.first_month
           OR TO_CHAR(p.promotion_date, 'YYYY-MM') > c.last_month
    ) AS promotions_outside_monthly_coverage,

    COUNT(*) FILTER (
        WHERE TO_CHAR(p.promotion_date, 'YYYY-MM')
              BETWEEN c.first_month AND c.last_month
    ) AS promotions_within_monthly_coverage

FROM raw.promotion_history p

LEFT JOIN employee_monthly_coverage c
    ON p.employee_id = c.employee_id;


-- Q41 | Source query 49
WITH employee_monthly_coverage AS (
    SELECT
        employee_id,
        MIN(year_month) AS first_month,
        MAX(year_month) AS last_month
    FROM raw.employee_monthly_hris
    GROUP BY employee_id
)

SELECT
    COUNT(*) AS total_salary_events,

    COUNT(*) FILTER (
        WHERE c.employee_id IS NULL
    ) AS events_without_monthly_records,

    COUNT(*) FILTER (
        WHERE TO_CHAR(s.effective_date, 'YYYY-MM') < c.first_month
           OR TO_CHAR(s.effective_date, 'YYYY-MM') > c.last_month
    ) AS events_outside_monthly_coverage,

    COUNT(*) FILTER (
        WHERE TO_CHAR(s.effective_date, 'YYYY-MM')
              BETWEEN c.first_month AND c.last_month
    ) AS events_within_monthly_coverage

FROM raw.salary_history s

LEFT JOIN employee_monthly_coverage c
    ON s.employee_id = c.employee_id;


-- Q42 | Source query 50
WITH employee_monthly_coverage AS (
    SELECT
        employee_id,
        MIN(year_month) AS first_month,
        MAX(year_month) AS last_month
    FROM raw.employee_monthly_hris
    GROUP BY employee_id
)

SELECT
    COUNT(*) AS total_separations,

    COUNT(*) FILTER (
        WHERE c.employee_id IS NULL
    ) AS separations_without_monthly_records,

    COUNT(*) FILTER (
        WHERE TO_CHAR(s.termination_date, 'YYYY-MM') < c.first_month
           OR TO_CHAR(s.termination_date, 'YYYY-MM') > c.last_month
    ) AS separations_outside_monthly_coverage,

    COUNT(*) FILTER (
        WHERE TO_CHAR(s.termination_date, 'YYYY-MM')
              BETWEEN c.first_month AND c.last_month
    ) AS separations_within_monthly_coverage

FROM raw.separation_history s

LEFT JOIN employee_monthly_coverage c
    ON s.employee_id = c.employee_id;
