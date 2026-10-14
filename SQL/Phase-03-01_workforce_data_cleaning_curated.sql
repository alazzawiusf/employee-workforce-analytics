-- ============================================================================
-- WORKFORCE ANALYTICS | PHASE 3: DATA CLEANING & TRANSFORMATION
-- PostgreSQL 18 | database: workforce_analytics
-- ============================================================================
-- PURPOSE: Reproducible, ordered staging transformations extracted from the
--          original working SQL notebook (77 investigative/operational steps).
-- INPUTS : raw.* tables loaded and validated; staging schema must exist.
-- OUTPUTS: staging.employees_hris, staging.employee_monthly_hris,
--          three mapping tables and two data-quality exception tables.
-- SAFETY : No INSERT/UPDATE/DELETE against raw.*.
-- RUN    : Execute top-to-bottom on a fresh staging schema; do not selectively
--          rerun after modifying mapping logic without reviewing dependencies.
-- NOTE   : Historical data-quality results are documented separately. This
--          consolidated script has NOT been executed against the user's DB.
--          Existing staging tables are NOT reset automatically.
-- ============================================================================



-- ============================================================================
-- A. MASTER TABLE INITIALIZATION
-- ============================================================================

-- ============================================================
-- PHASE 3: DATA CLEANING & TRANSFORMATION
-- STEP 1: CREATE EMPLOYEE STAGING TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS staging.employees_hris
(
    LIKE raw.employees_hris
    INCLUDING ALL
);

INSERT INTO staging.employees_hris
SELECT *
FROM raw.employees_hris
ON CONFLICT DO NOTHING;

-- Verify staging population
SELECT
    (SELECT COUNT(*) FROM raw.employees_hris)
        AS raw_records,

    (SELECT COUNT(*) FROM staging.employees_hris)
        AS staging_records;


-- ============================================================
-- PHASE 3: DEPARTMENT STANDARDIZATION
-- STEP 3: CREATE MAPPING AND APPLY CORRECTIONS
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS staging.department_mapping (
    original_department TEXT PRIMARY KEY,
    standardized_department TEXT NOT NULL
);

-- Automatic normalization: case and surrounding spaces
INSERT INTO staging.department_mapping
    (original_department, standardized_department)
SELECT DISTINCT
    e.current_department,
    r.department
FROM staging.employees_hris e
JOIN (
    SELECT DISTINCT department
    FROM raw.organization_structure
) r
    ON LOWER(TRIM(e.current_department)) = LOWER(TRIM(r.department))
WHERE e.current_department IS DISTINCT FROM r.department
ON CONFLICT (original_department)
DO UPDATE SET
    standardized_department = EXCLUDED.standardized_department;

-- Explicit mapping: abbreviations and spelling errors
WITH manual_mapping(original_department, standardized_department) AS (
    VALUES
    ('Ops', 'Operations'),
    ('Opreations', 'Operations'),
    ('Oeprations', 'Operations'),
    ('Operaitons', 'Operations'),
    ('Opeartions', 'Operations'),

    ('Client Service', 'Client Services'),
    ('Client Svcs', 'Client Services'),
    ('Client Serivces', 'Client Services'),
    ('Cilent Services', 'Client Services'),
    ('ClientS ervices', 'Client Services'),
    ('Client eSrvices', 'Client Services'),
    ('Cleint Services', 'Client Services'),
    ('Clien tServices', 'Client Services'),

    ('Tech', 'Technology'),
    ('IT', 'Technology'),
    ('Tehcnology', 'Technology'),
    ('Technloogy', 'Technology'),
    ('Tecnhology', 'Technology'),
    ('Technoolgy', 'Technology'),
    ('Tcehnology', 'Technology'),

    ('Fin', 'Finance'),
    ('Finacne', 'Finance'),
    ('Finnace', 'Finance'),
    ('Fiannce', 'Finance'),
    ('Fniance', 'Finance'),

    ('Risk/Compliance', 'Risk & Compliance'),
    ('Risk and Compliance', 'Risk & Compliance'),
    ('Risk & Comlpiance', 'Risk & Compliance'),
    ('Risk & Compliacne', 'Risk & Compliance'),
    ('Risk & Complaince', 'Risk & Compliance'),
    ('Riks & Compliance', 'Risk & Compliance'),

    ('Human Resource', 'Human Resources'),
    ('Human Resoruces', 'Human Resources'),
    ('Human Reosurces', 'Human Resources'),
    ('Human Resoucres', 'Human Resources'),

    ('Mktg', 'Marketing'),
    ('Makreting', 'Marketing'),
    ('Mraketing', 'Marketing'),

    ('Corp Services', 'Corporate Services'),
    ('Corporate Svcs', 'Corporate Services'),
    ('Corportae Services', 'Corporate Services'),
    ('Corporaet Services', 'Corporate Services'),
    ('Corporate Serviecs', 'Corporate Services'),
    ('Croporate Services', 'Corporate Services')
)
INSERT INTO staging.department_mapping
    (original_department, standardized_department)
SELECT original_department, standardized_department
FROM manual_mapping
ON CONFLICT (original_department)
DO UPDATE SET
    standardized_department = EXCLUDED.standardized_department;

-- Apply mapping to staging only
UPDATE staging.employees_hris e
SET current_department = m.standardized_department
FROM staging.department_mapping m
WHERE e.current_department = m.original_department
  AND e.current_department IS DISTINCT FROM m.standardized_department;

-- Final validation
SELECT
    COUNT(*) AS total_employees,
    COUNT(*) FILTER (
        WHERE NOT EXISTS (
            SELECT 1
            FROM raw.organization_structure r
            WHERE r.department = e.current_department
        )
    ) AS remaining_invalid_departments,
    COUNT(*) FILTER (
        WHERE e.current_department IS NULL
    ) AS missing_departments
FROM staging.employees_hris e;

COMMIT;




-- ============================================================
-- DEPARTMENT STANDARDIZATION: FINAL VALIDATION
-- ============================================================

SELECT
    COUNT(*) AS total_employees,

    COUNT(*) FILTER (
        WHERE NOT EXISTS (
            SELECT 1
            FROM raw.organization_structure r
            WHERE r.department = e.current_department
        )
    ) AS remaining_invalid_departments,

    COUNT(*) FILTER (
        WHERE e.current_department IS NULL
    ) AS missing_departments,

    COUNT(DISTINCT current_department)
        AS distinct_departments

FROM staging.employees_hris e;


-- ============================================================
-- PHASE 3: LOCATION STANDARDIZATION
-- STEP 5: CREATE MAPPING AND APPLY CORRECTIONS
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS staging.location_mapping (
    original_location TEXT PRIMARY KEY,
    standardized_location TEXT NOT NULL
);

-- 1. Automatic normalization
INSERT INTO staging.location_mapping
    (original_location, standardized_location)
SELECT DISTINCT
    e.location,
    r.location
FROM staging.employees_hris e
JOIN raw.location_reference r
    ON LOWER(TRIM(e.location)) = LOWER(TRIM(r.location))
WHERE e.location IS DISTINCT FROM r.location
ON CONFLICT (original_location)
DO UPDATE SET
    standardized_location = EXCLUDED.standardized_location;


-- 2. Explicit mapping
WITH manual_mapping(original_location, standardized_location) AS (
    VALUES
    ('Dallas', 'Dallas, TX'),
    ('Dallas TX', 'Dallas, TX'),
    ('Dallas,T X', 'Dallas, TX'),
    ('Dallas ,TX', 'Dallas, TX'),
    ('Dlalas, TX', 'Dallas, TX'),
    ('Dallsa, TX', 'Dallas, TX'),

    ('Chicago', 'Chicago, IL'),
    ('Chicag,o IL', 'Chicago, IL'),
    ('Chicago,I L', 'Chicago, IL'),

    ('CHARLOTTE', 'Charlotte, NC'),
    ('Charlotte', 'Charlotte, NC'),
    ('Charltote, NC', 'Charlotte, NC'),
    ('Charoltte, NC', 'Charlotte, NC'),
    ('Chalrotte, NC', 'Charlotte, NC'),
    ('Charlotte,N C', 'Charlotte, NC'),
    ('Cahrlotte, NC', 'Charlotte, NC'),

    ('New York NY', 'New York, NY'),
    ('NYC', 'New York, NY'),
    ('New York', 'New York, NY'),
    ('New Yokr, NY', 'New York, NY'),
    ('New Yor,k NY', 'New York, NY'),
    ('NewY ork, NY', 'New York, NY'),

    ('San Francisco', 'San Francisco, CA'),
    ('San Fransisco, CA', 'San Francisco, CA'),
    ('SF', 'San Francisco, CA'),
    ('San Francicso, CA', 'San Francisco, CA'),
    ('San Frnacisco, CA', 'San Francisco, CA'),
    ('Sna Francisco, CA', 'San Francisco, CA'),
    ('San Farncisco, CA', 'San Francisco, CA'),

    ('Remtoe', 'Remote'),
    ('Rmeote', 'Remote'),
    ('Reomte', 'Remote')
)

INSERT INTO staging.location_mapping
    (original_location, standardized_location)
SELECT original_location, standardized_location
FROM manual_mapping
ON CONFLICT (original_location)
DO UPDATE SET
    standardized_location = EXCLUDED.standardized_location;


-- 3. Validate mapping targets
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM staging.location_mapping m
        WHERE NOT EXISTS (
            SELECT 1
            FROM raw.location_reference r
            WHERE r.location = m.standardized_location
        )
    ) THEN
        RAISE EXCEPTION
            'Location mapping contains invalid reference values';
    END IF;
END $$;


-- 4. Apply corrections to staging only
UPDATE staging.employees_hris e
SET location = m.standardized_location
FROM staging.location_mapping m
WHERE e.location = m.original_location
  AND e.location IS DISTINCT FROM m.standardized_location;

COMMIT;


-- ============================================================
-- PHASE 3: LOCATION STANDARDIZATION
-- STEP 8: RECOVER MISSING LOCATIONS
-- ============================================================

BEGIN;

WITH latest_monthly_location AS (
    SELECT DISTINCT ON (m.employee_id)
        m.employee_id,
        COALESCE(
            lm.standardized_location,
            m.location
        ) AS recovered_location

    FROM raw.employee_monthly_hris m

    JOIN staging.employees_hris e
        ON e.employee_id = m.employee_id
       AND e.location IS NULL

    LEFT JOIN staging.location_mapping lm
        ON m.location = lm.original_location

    ORDER BY
        m.employee_id,
        m.year_month DESC
)

UPDATE staging.employees_hris e

SET location = l.recovered_location

FROM latest_monthly_location l

WHERE e.employee_id = l.employee_id
  AND e.location IS NULL
  AND EXISTS (
      SELECT 1
      FROM raw.location_reference r
      WHERE r.location = l.recovered_location
  );

COMMIT;


-- ============================================================
-- PHASE 3: JOB ROLE STANDARDIZATION
-- STEP 11: BASIC NORMALIZATION
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS staging.job_role_mapping (
    original_job_role TEXT NOT NULL,
    job_family TEXT NOT NULL,
    job_level TEXT NOT NULL,
    standardized_job_role TEXT NOT NULL,

    PRIMARY KEY (
        original_job_role,
        job_family,
        job_level
    )
);

-- Insert only unambiguous matches
WITH candidates AS (
    SELECT
        e.current_job_role,
        e.current_job_family,
        e.current_job_level,
        MIN(s.job_role) AS standardized_job_role,
        COUNT(DISTINCT s.job_role) AS candidate_count

    FROM staging.employees_hris e

    JOIN raw.organization_structure s
        ON LOWER(TRIM(e.current_job_role))
         = LOWER(TRIM(s.job_role))
       AND e.current_job_family = s.job_family
       AND e.current_job_level = s.job_level

    WHERE e.current_job_role IS DISTINCT FROM s.job_role

    GROUP BY
        e.current_job_role,
        e.current_job_family,
        e.current_job_level
)

INSERT INTO staging.job_role_mapping (
    original_job_role,
    job_family,
    job_level,
    standardized_job_role
)
SELECT
    current_job_role,
    current_job_family,
    current_job_level,
    standardized_job_role
FROM candidates
WHERE candidate_count = 1

ON CONFLICT (
    original_job_role,
    job_family,
    job_level
)
DO NOTHING;

-- Apply verified mappings
UPDATE staging.employees_hris e

SET current_job_role = m.standardized_job_role

FROM staging.job_role_mapping m

WHERE e.current_job_role = m.original_job_role
  AND e.current_job_family = m.job_family
  AND e.current_job_level = m.job_level
  AND e.current_job_role IS DISTINCT FROM m.standardized_job_role;

COMMIT;


-- ============================================================
-- PHASE 3: JOB ROLE STANDARDIZATION
-- STEP 13: SENIOR & ASSOCIATE ABBREVIATION CORRECTION
-- ============================================================

BEGIN;

WITH candidates AS (
    SELECT
        e.current_job_role AS original_job_role,
        e.current_job_family AS job_family,
        e.current_job_level AS job_level,
        MIN(s.job_role) AS standardized_job_role,
        COUNT(DISTINCT s.job_role) AS candidate_count

    FROM staging.employees_hris e

    JOIN raw.organization_structure s
        ON LOWER(
            TRIM(
                REGEXP_REPLACE(
                    REGEXP_REPLACE(
                        e.current_job_role,
                        '\mSr\.',
                        'Senior',
                        'gi'
                    ),
                    '\mAssoc\.',
                    'Associate',
                    'gi'
                )
            )
        ) = LOWER(TRIM(s.job_role))

       AND e.current_job_family = s.job_family
       AND e.current_job_level = s.job_level

    WHERE NOT EXISTS (
        SELECT 1
        FROM raw.organization_structure valid_role
        WHERE valid_role.job_role = e.current_job_role
          AND valid_role.job_family = e.current_job_family
          AND valid_role.job_level = e.current_job_level
    )

    GROUP BY
        e.current_job_role,
        e.current_job_family,
        e.current_job_level
),

new_mappings AS (
    INSERT INTO staging.job_role_mapping (
        original_job_role,
        job_family,
        job_level,
        standardized_job_role
    )

    SELECT
        original_job_role,
        job_family,
        job_level,
        standardized_job_role

    FROM candidates
    WHERE candidate_count = 1

    ON CONFLICT (
        original_job_role,
        job_family,
        job_level
    )
    DO NOTHING

    RETURNING *
)

UPDATE staging.employees_hris e

SET current_job_role = m.standardized_job_role

FROM new_mappings m

WHERE e.current_job_role = m.original_job_role
  AND e.current_job_family = m.job_family
  AND e.current_job_level = m.job_level;

COMMIT;


-- ============================================================
-- PHASE 3: JOB ROLE STANDARDIZATION
-- STEP 15: ADDITIONAL ABBREVIATION CORRECTION
-- ============================================================

BEGIN;

WITH candidates AS (
    SELECT
        e.current_job_role AS original_job_role,
        e.current_job_family AS job_family,
        e.current_job_level AS job_level,
        MIN(s.job_role) AS standardized_job_role,
        COUNT(DISTINCT s.job_role) AS candidate_count

    FROM staging.employees_hris e

    JOIN raw.organization_structure s
        ON LOWER(TRIM(
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
        )) = LOWER(TRIM(s.job_role))

       AND e.current_job_family = s.job_family
       AND e.current_job_level = s.job_level

    WHERE NOT EXISTS (
        SELECT 1
        FROM raw.organization_structure v
        WHERE v.job_role = e.current_job_role
          AND v.job_family = e.current_job_family
          AND v.job_level = e.current_job_level
    )

    GROUP BY
        e.current_job_role,
        e.current_job_family,
        e.current_job_level
),

new_mappings AS (
    INSERT INTO staging.job_role_mapping (
        original_job_role,
        job_family,
        job_level,
        standardized_job_role
    )
    SELECT
        original_job_role,
        job_family,
        job_level,
        standardized_job_role
    FROM candidates
    WHERE candidate_count = 1

    ON CONFLICT (
        original_job_role,
        job_family,
        job_level
    )
    DO NOTHING

    RETURNING *
)

UPDATE staging.employees_hris e
SET current_job_role = m.standardized_job_role
FROM new_mappings m
WHERE e.current_job_role = m.original_job_role
  AND e.current_job_family = m.job_family
  AND e.current_job_level = m.job_level;

COMMIT;


-- ============================================================
-- PHASE 3: JOB ROLE STANDARDIZATION
-- STEP 18: FINAL REFERENCE-BASED CORRECTION
-- ============================================================

BEGIN;

WITH invalid_roles AS (
    SELECT DISTINCT
        e.current_job_role,
        e.current_job_family,
        e.current_job_level

    FROM staging.employees_hris e

    WHERE NOT EXISTS (
        SELECT 1
        FROM raw.organization_structure s
        WHERE s.job_role = e.current_job_role
          AND s.job_family = e.current_job_family
          AND s.job_level = e.current_job_level
    )
),

candidates AS (
    SELECT
        i.current_job_role AS original_job_role,
        i.current_job_family AS job_family,
        i.current_job_level AS job_level,
        MIN(s.job_role) AS standardized_job_role

    FROM invalid_roles i

    JOIN raw.organization_structure s
        ON s.job_family = i.current_job_family
       AND s.job_level = i.current_job_level

    GROUP BY
        i.current_job_role,
        i.current_job_family,
        i.current_job_level

    HAVING COUNT(DISTINCT s.job_role) = 1
),

new_mappings AS (
    INSERT INTO staging.job_role_mapping (
        original_job_role,
        job_family,
        job_level,
        standardized_job_role
    )

    SELECT
        original_job_role,
        job_family,
        job_level,
        standardized_job_role

    FROM candidates

    ON CONFLICT (
        original_job_role,
        job_family,
        job_level
    )
    DO NOTHING

    RETURNING *
)

UPDATE staging.employees_hris e

SET current_job_role = m.standardized_job_role

FROM new_mappings m

WHERE e.current_job_role = m.original_job_role
  AND e.current_job_family = m.job_family
  AND e.current_job_level = m.job_level;

COMMIT;


-- ============================================================
-- PHASE 3: TERMINATION DATA CLEANING
-- STEP 21: RECOVER MISSING TERMINATION TYPES
-- ============================================================

BEGIN;

WITH verified_recovery AS (
    SELECT
        s.employee_id,
        s.termination_date,
        MIN(s.termination_type) AS recovered_type

    FROM raw.separation_history s

    JOIN staging.employees_hris e
        ON e.employee_id = s.employee_id
       AND e.termination_date = s.termination_date

    WHERE e.employment_status = 'Terminated'
      AND e.termination_type IS NULL
      AND s.termination_type IS NOT NULL

    GROUP BY
        s.employee_id,
        s.termination_date

    HAVING COUNT(DISTINCT s.termination_type) = 1
),

updated AS (
    UPDATE staging.employees_hris e

    SET termination_type = r.recovered_type

    FROM verified_recovery r

    WHERE e.employee_id = r.employee_id
      AND e.termination_date = r.termination_date
      AND e.employment_status = 'Terminated'
      AND e.termination_type IS NULL

    RETURNING e.employee_id
)

SELECT COUNT(*) AS recovered_termination_types
FROM updated;

COMMIT;


-- ============================================================
-- PHASE 3: EMPLOYEE MASTER CLEANING
-- STEP 24: RECOVER MISSING MANAGER IDs
-- ============================================================

BEGIN;

WITH latest_monthly_manager AS (
    SELECT DISTINCT ON (m.employee_id)
        m.employee_id,
        m.manager_id AS recovered_manager_id

    FROM raw.employee_monthly_hris m

    JOIN staging.employees_hris e
        ON e.employee_id = m.employee_id
       AND e.current_manager_id IS NULL

    ORDER BY
        m.employee_id,
        m.year_month DESC
),

verified_managers AS (
    SELECT
        l.employee_id,
        l.recovered_manager_id

    FROM latest_monthly_manager l

    JOIN staging.employees_hris manager
        ON manager.employee_id = l.recovered_manager_id

    WHERE l.recovered_manager_id <> l.employee_id
),

updated AS (
    UPDATE staging.employees_hris e

    SET current_manager_id = v.recovered_manager_id

    FROM verified_managers v

    WHERE e.employee_id = v.employee_id
      AND e.current_manager_id IS NULL

    RETURNING e.employee_id
)

SELECT
    COUNT(*) AS recovered_manager_ids
FROM updated;

COMMIT;



-- ============================================================================
-- B. MONTHLY SNAPSHOT INITIALIZATION
-- ============================================================================

-- ============================================================
-- PHASE 3: MONTHLY HRIS DATA CLEANING
-- STEP 28: CREATE MONTHLY STAGING TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS staging.employee_monthly_hris
(
    LIKE raw.employee_monthly_hris INCLUDING ALL
);

INSERT INTO staging.employee_monthly_hris
SELECT *
FROM raw.employee_monthly_hris
ON CONFLICT DO NOTHING;

-- Validate record counts
SELECT
    (SELECT COUNT(*)
     FROM raw.employee_monthly_hris) AS raw_records,

    (SELECT COUNT(*)
     FROM staging.employee_monthly_hris) AS staging_records,

    (SELECT COUNT(DISTINCT employee_id)
     FROM staging.employee_monthly_hris) AS unique_employees,

    (SELECT COUNT(DISTINCT year_month)
     FROM staging.employee_monthly_hris) AS distinct_months;


-- ============================================================
-- PHASE 3: MONTHLY HRIS DATA CLEANING
-- STEP 31: EXTEND DEPARTMENT MAPPING & STANDARDIZE
-- ============================================================

BEGIN;

-- 1. Add reviewed mappings
INSERT INTO staging.department_mapping
    (original_department, standardized_department)
VALUES
    ('HR', 'Human Resources'),

    ('Operatinos', 'Operations'),
    ('Operatoins', 'Operations'),
    ('Opertaions', 'Operations'),

    ('Techonlogy', 'Technology'),
    ('Technolgoy', 'Technology'),

    ('Client Sevrices', 'Client Services'),
    ('Client Srevices', 'Client Services'),
    ('Client Servcies', 'Client Services'),
    ('Clietn Services', 'Client Services'),
    ('Client Serviecs', 'Client Services'),
    ('Clinet Services', 'Client Services'),

    ('Markeitng', 'Marketing'),
    ('Marketnig', 'Marketing'),
    ('Markteing', 'Marketing'),
    ('Marekting', 'Marketing'),

    ('Corporat eServices', 'Corporate Services'),
    ('Corporate eSrvices', 'Corporate Services'),
    ('Corporate Serivces', 'Corporate Services'),
    ('CorporateS ervices', 'Corporate Services'),
    ('Corporate Sevrices', 'Corporate Services'),
    ('Corporate Servcies', 'Corporate Services'),
    ('Coroprate Services', 'Corporate Services'),
    ('Coprorate Services', 'Corporate Services'),
    ('Corpoarte Services', 'Corporate Services'),
    ('Corporate Srevices', 'Corporate Services'),
    ('Corproate Services', 'Corporate Services'),

    ('Risk & Cmopliance', 'Risk & Compliance'),
    ('Risk & Complinace', 'Risk & Compliance'),
    ('Risk  &Compliance', 'Risk & Compliance'),
    ('Risk &C ompliance', 'Risk & Compliance'),
    ('Ris k& Compliance', 'Risk & Compliance'),
    ('Risk & Copmliance', 'Risk & Compliance'),
    ('Risk&  Compliance', 'Risk & Compliance'),
    ('Rsik & Compliance', 'Risk & Compliance'),
    ('Risk & Compilance', 'Risk & Compliance'),
    ('Risk & oCmpliance', 'Risk & Compliance'),

    ('Huma nResources', 'Human Resources'),
    ('Huamn Resources', 'Human Resources'),
    ('Human Resuorces', 'Human Resources'),
    ('Humna Resources', 'Human Resources'),
    ('Human Resourecs', 'Human Resources'),
    ('Hmuan Resources', 'Human Resources'),
    ('Human eRsources', 'Human Resources'),
    ('HumanR esources', 'Human Resources'),
    ('Human Rseources', 'Human Resources')

ON CONFLICT (original_department) DO NOTHING;

-- 2. Apply mappings to monthly staging
UPDATE staging.employee_monthly_hris m
SET department = dm.standardized_department
FROM staging.department_mapping dm
WHERE m.department = dm.original_department
  AND m.department IS DISTINCT FROM dm.standardized_department;

-- 3. Final validation
SELECT
    COUNT(*) AS total_records,

    COUNT(*) FILTER (
        WHERE m.department IS NULL
           OR NOT EXISTS (
               SELECT 1
               FROM raw.organization_structure s
               WHERE s.department = m.department
           )
    ) AS invalid_departments,

    COUNT(DISTINCT m.department) AS distinct_departments

FROM staging.employee_monthly_hris m;

COMMIT;


-- ============================================================
-- PHASE 3: MONTHLY HRIS DATA CLEANING
-- STEP 35: EXTEND LOCATION MAPPING & STANDARDIZE
-- ============================================================

BEGIN;

-- 1. Add reviewed location mappings
INSERT INTO staging.location_mapping
    (original_location, standardized_location)
VALUES
    -- Chicago
    ('Chicgao, IL', 'Chicago, IL'),
    ('Cihcago, IL', 'Chicago, IL'),
    ('Chciago, IL', 'Chicago, IL'),
    ('Chicago ,IL', 'Chicago, IL'),
    ('Chicaog, IL', 'Chicago, IL'),
    ('Chiacgo, IL', 'Chicago, IL'),

    -- Dallas
    ('Dalals, TX', 'Dallas, TX'),
    ('Dalla,s TX', 'Dallas, TX'),

    -- New York
    ('Nwe York, NY', 'New York, NY'),
    ('New oYrk, NY', 'New York, NY'),
    ('New York,N Y', 'New York, NY'),
    ('Ne wYork, NY', 'New York, NY'),
    ('New Yrok, NY', 'New York, NY'),
    ('New York ,NY', 'New York, NY'),

    -- Charlotte
    ('Charlotte ,NC', 'Charlotte, NC'),
    ('Charlott,e NC', 'Charlotte, NC'),
    ('Charlotet, NC', 'Charlotte, NC'),
    ('Chralotte, NC', 'Charlotte, NC'),

    -- San Francisco
    ('Sa nFrancisco, CA', 'San Francisco, CA'),
    ('San Francisco,C A', 'San Francisco, CA'),
    ('San Francisc,o CA', 'San Francisco, CA'),
    ('San Fracnisco, CA', 'San Francisco, CA'),
    ('SanF rancisco, CA', 'San Francisco, CA'),
    ('San Francisco ,CA', 'San Francisco, CA'),
    ('San Francisoc, CA', 'San Francisco, CA'),
    ('San Franicsco, CA', 'San Francisco, CA'),
    ('San rFancisco, CA', 'San Francisco, CA'),
    ('San Francsico, CA', 'San Francisco, CA')

ON CONFLICT (original_location) DO NOTHING;

-- 2. Apply mapping to monthly staging
UPDATE staging.employee_monthly_hris m
SET location = lm.standardized_location
FROM staging.location_mapping lm
WHERE m.location = lm.original_location
  AND m.location IS DISTINCT FROM lm.standardized_location;

-- 3. Final quality validation
SELECT
    COUNT(*) AS total_records,

    COUNT(DISTINCT m.location) AS distinct_locations,

    COUNT(*) FILTER (
        WHERE m.location IS NULL
    ) AS missing_locations,

    COUNT(*) FILTER (
        WHERE m.location IS NOT NULL
          AND NOT EXISTS (
              SELECT 1
              FROM raw.location_reference ref
              WHERE ref.location = m.location
          )
    ) AS invalid_locations

FROM staging.employee_monthly_hris m;

COMMIT;


-- ============================================================
-- PHASE 3: MONTHLY HRIS DATA CLEANING
-- STEP 39: APPLY VERIFIED JOB ROLE MAPPINGS
-- ============================================================

BEGIN;

WITH candidate_matches AS (
    SELECT DISTINCT
        m.job_role AS original_job_role,
        m.job_family,
        m.job_level,
        s.job_role AS standardized_job_role

    FROM staging.employee_monthly_hris m

    JOIN raw.organization_structure s
        ON s.job_family = m.job_family
       AND s.job_level = m.job_level
       AND LOWER(TRIM(s.job_role)) =
           LOWER(TRIM(m.job_role))

    WHERE NOT EXISTS (
        SELECT 1
        FROM raw.organization_structure valid
        WHERE valid.job_role = m.job_role
          AND valid.job_family = m.job_family
          AND valid.job_level = m.job_level
    )
),

unique_matches AS (
    SELECT
        original_job_role,
        job_family,
        job_level,
        MIN(standardized_job_role) AS standardized_job_role

    FROM candidate_matches

    GROUP BY
        original_job_role,
        job_family,
        job_level

    HAVING COUNT(DISTINCT standardized_job_role) = 1
)

INSERT INTO staging.job_role_mapping (
    original_job_role,
    job_family,
    job_level,
    standardized_job_role
)

SELECT
    original_job_role,
    job_family,
    job_level,
    standardized_job_role

FROM unique_matches

ON CONFLICT (
    original_job_role,
    job_family,
    job_level
) DO NOTHING;


-- Apply all existing and newly added mappings
UPDATE staging.employee_monthly_hris m

SET job_role = jm.standardized_job_role

FROM staging.job_role_mapping jm

WHERE m.job_role = jm.original_job_role
  AND m.job_family = jm.job_family
  AND m.job_level = jm.job_level
  AND m.job_role IS DISTINCT FROM jm.standardized_job_role;


-- Validate remaining invalid roles
SELECT
    COUNT(*) AS total_records,

    COUNT(*) FILTER (
        WHERE NOT EXISTS (
            SELECT 1
            FROM raw.organization_structure s
            WHERE s.job_role = m.job_role
              AND s.job_family = m.job_family
              AND s.job_level = m.job_level
        )
    ) AS remaining_invalid_roles

FROM staging.employee_monthly_hris m;

COMMIT;


-- ============================================================
-- PHASE 3: MONTHLY HRIS DATA CLEANING
-- STEP 42: APPLY JOB ROLE ABBREVIATION MAPPINGS
-- ============================================================

BEGIN;

-- Insert mappings first. The following UPDATE must be a separate statement
-- to see rows inserted in this transaction (PostgreSQL CTE snapshot semantics).
WITH invalid_roles AS (
    SELECT DISTINCT
        m.job_role,
        m.job_family,
        m.job_level
    FROM staging.employee_monthly_hris m
    WHERE NOT EXISTS (
        SELECT 1
        FROM raw.organization_structure s
        WHERE s.job_role = m.job_role
          AND s.job_family = m.job_family
          AND s.job_level = m.job_level
    )
),

normalized_roles AS (
    SELECT
        *,
        LOWER(TRIM(
            REGEXP_REPLACE(
                REGEXP_REPLACE(
                    REGEXP_REPLACE(
                        REGEXP_REPLACE(
                            REGEXP_REPLACE(
                                REGEXP_REPLACE(
                                    REGEXP_REPLACE(
                                        job_role,
                                        '\mSr\.', 'Senior', 'gi'
                                    ),
                                    '\mAssoc\.', 'Associate', 'gi'
                                ),
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
        )) AS normalized_role
    FROM invalid_roles
),

verified_matches AS (
    SELECT
        n.job_role AS original_job_role,
        n.job_family,
        n.job_level,
        MIN(s.job_role) AS standardized_job_role
    FROM normalized_roles n
    JOIN raw.organization_structure s
        ON s.job_family = n.job_family
       AND s.job_level = n.job_level
       AND LOWER(TRIM(s.job_role)) = n.normalized_role
    GROUP BY
        n.job_role,
        n.job_family,
        n.job_level
    HAVING COUNT(DISTINCT s.job_role) = 1
)
INSERT INTO staging.job_role_mapping (
    original_job_role, job_family, job_level, standardized_job_role
)
SELECT original_job_role, job_family, job_level, standardized_job_role
FROM verified_matches
ON CONFLICT (original_job_role, job_family, job_level) DO NOTHING;

UPDATE staging.employee_monthly_hris m
SET job_role = jm.standardized_job_role
FROM staging.job_role_mapping jm
WHERE m.job_role = jm.original_job_role
  AND m.job_family = jm.job_family
  AND m.job_level = jm.job_level
  AND m.job_role IS DISTINCT FROM jm.standardized_job_role;

COMMIT;


-- ============================================================
-- PHASE 3: MONTHLY HRIS DATA CLEANING
-- STEP 45: APPLY EXISTING JOB ROLE MAPPINGS
-- ============================================================

WITH updated AS (
    UPDATE staging.employee_monthly_hris m

    SET job_role = jm.standardized_job_role

    FROM staging.job_role_mapping jm

    WHERE m.job_role = jm.original_job_role
      AND m.job_family = jm.job_family
      AND m.job_level = jm.job_level
      AND m.job_role IS DISTINCT FROM jm.standardized_job_role

      AND EXISTS (
          SELECT 1
          FROM raw.organization_structure s
          WHERE s.job_role = jm.standardized_job_role
            AND s.job_family = jm.job_family
            AND s.job_level = jm.job_level
      )

    RETURNING m.employee_id
)

SELECT COUNT(*) AS corrected_records
FROM updated;


-- ============================================================
-- PHASE 3: MONTHLY HRIS DATA CLEANING
-- STEP 50: APPLY VERIFIED LEVENSHTEIN CORRECTIONS
-- ============================================================

BEGIN;

WITH invalid_roles AS (
    SELECT DISTINCT
        m.job_role,
        m.job_family,
        m.job_level
    FROM staging.employee_monthly_hris m
    WHERE NOT EXISTS (
        SELECT 1
        FROM raw.organization_structure s
        WHERE s.job_role = m.job_role
          AND s.job_family = m.job_family
          AND s.job_level = m.job_level
    )
),

candidate_distances AS (
    SELECT
        i.job_role AS original_job_role,
        i.job_family,
        i.job_level,
        s.job_role AS standardized_job_role,
        LEVENSHTEIN(
            LOWER(TRIM(i.job_role)),
            LOWER(TRIM(s.job_role))
        ) AS edit_distance
    FROM invalid_roles i
    JOIN raw.organization_structure s
        ON s.job_family = i.job_family
       AND s.job_level = i.job_level
),

ranked_matches AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY
                original_job_role,
                job_family,
                job_level
            ORDER BY edit_distance, standardized_job_role
        ) AS match_rank,

        LEAD(edit_distance) OVER (
            PARTITION BY
                original_job_role,
                job_family,
                job_level
            ORDER BY edit_distance, standardized_job_role
        ) AS second_best_distance

    FROM candidate_distances
)

INSERT INTO staging.job_role_mapping (
    original_job_role,
    job_family,
    job_level,
    standardized_job_role
)

SELECT
    original_job_role,
    job_family,
    job_level,
    standardized_job_role

FROM ranked_matches

WHERE match_rank = 1
  AND edit_distance <= 2
  AND (
      second_best_distance IS NULL
      OR second_best_distance > edit_distance
  )

ON CONFLICT (
    original_job_role,
    job_family,
    job_level
) DO NOTHING;


-- Apply mappings after insertion is complete.

WITH updated AS (
    UPDATE staging.employee_monthly_hris m

    SET job_role = jm.standardized_job_role

    FROM staging.job_role_mapping jm

    WHERE m.job_role = jm.original_job_role
      AND m.job_family = jm.job_family
      AND m.job_level = jm.job_level
      AND m.job_role IS DISTINCT FROM jm.standardized_job_role

      AND EXISTS (
          SELECT 1
          FROM raw.organization_structure s
          WHERE s.job_role = jm.standardized_job_role
            AND s.job_family = jm.job_family
            AND s.job_level = jm.job_level
      )

    RETURNING m.employee_id
)

SELECT COUNT(*) AS corrected_records
FROM updated;

COMMIT;


-- ============================================================
-- PHASE 3: MONTHLY HRIS DATA CLEANING
-- STEP 53: FINAL MANUAL JOB ROLE CORRECTIONS
-- ============================================================

BEGIN;

-- Save the 16 verified mappings

INSERT INTO staging.job_role_mapping (
    original_job_role,
    job_family,
    job_level,
    standardized_job_role
)
SELECT
    'Dir. ' || SUBSTRING(s.job_role FROM 13),
    s.job_family,
    s.job_level,
    s.job_role
FROM raw.organization_structure s
WHERE s.job_role LIKE 'Director of %'
  AND s.job_level = 'L6'
  AND ('Dir. ' || SUBSTRING(s.job_role FROM 13)) IN (
      'Dir. Account Management',
      'Dir. Sales',
      'Dir. Engineering',
      'Dir. Infrastructure',
      'Dir. Product Management',
      'Dir. Digital Marketing',
      'Dir. FP&A',
      'Dir. PMO',
      'Dir. Data Engineering',
      'Dir. Legal',
      'Dir. Procurement',
      'Dir. Compliance',
      'Dir. Enterprise Risk',
      'Dir. Information Security',
      'Dir. Talent Acquisition',
      'Dir. Total Rewards'
  )
ON CONFLICT (
    original_job_role,
    job_family,
    job_level
) DO NOTHING;

-- Apply corrections

UPDATE staging.employee_monthly_hris m
SET job_role = jm.standardized_job_role
FROM staging.job_role_mapping jm
WHERE m.job_role = jm.original_job_role
  AND m.job_family = jm.job_family
  AND m.job_level = jm.job_level
  AND m.job_role LIKE 'Dir. %'
  AND EXISTS (
      SELECT 1
      FROM raw.organization_structure s
      WHERE s.job_role = jm.standardized_job_role
        AND s.job_family = jm.job_family
        AND s.job_level = jm.job_level
  );

COMMIT;



-- ============================================================================
-- C. TEMPORAL METRIC CORRECTIONS
-- ============================================================================

-- ============================================================
-- PHASE 3: MONTHLY HRIS DATA CLEANING
-- STEP 63: CORRECT ORGANIZATIONAL TENURE FREEZES
-- ============================================================

BEGIN;

WITH tenure_sequence AS (
    SELECT
        employee_id,
        year_month,
        organizational_tenure_months,

        FIRST_VALUE(organizational_tenure_months) OVER (
            PARTITION BY employee_id
            ORDER BY year_month
        ) AS initial_tenure,

        FIRST_VALUE(
            TO_DATE(year_month || '-01', 'YYYY-MM-DD')
        ) OVER (
            PARTITION BY employee_id
            ORDER BY year_month
        ) AS initial_month,

        LAG(organizational_tenure_months) OVER (
            PARTITION BY employee_id
            ORDER BY year_month
        ) AS previous_tenure,

        LAG(year_month) OVER (
            PARTITION BY employee_id
            ORDER BY year_month
        ) AS previous_month

    FROM staging.employee_monthly_hris
),

affected_employees AS (
    SELECT DISTINCT employee_id
    FROM tenure_sequence
    WHERE organizational_tenure_months = previous_tenure
      AND TO_DATE(year_month || '-01', 'YYYY-MM-DD')
          = (
              TO_DATE(previous_month || '-01', 'YYYY-MM-DD')
              + INTERVAL '1 month'
          )::DATE
),

corrected_values AS (
    SELECT
        t.employee_id,
        t.year_month,

        t.initial_tenure
        + (
            EXTRACT(YEAR FROM AGE(
                TO_DATE(t.year_month || '-01', 'YYYY-MM-DD'),
                t.initial_month
            ))::INTEGER * 12
            +
            EXTRACT(MONTH FROM AGE(
                TO_DATE(t.year_month || '-01', 'YYYY-MM-DD'),
                t.initial_month
            ))::INTEGER
        ) AS corrected_tenure

    FROM tenure_sequence t
    JOIN affected_employees a
        ON t.employee_id = a.employee_id
),

updated AS (
    UPDATE staging.employee_monthly_hris m

    SET organizational_tenure_months = c.corrected_tenure

    FROM corrected_values c

    WHERE m.employee_id = c.employee_id
      AND m.year_month = c.year_month
      AND m.organizational_tenure_months
          IS DISTINCT FROM c.corrected_tenure

    RETURNING m.employee_id
)

SELECT
    COUNT(*) AS corrected_records,
    COUNT(DISTINCT employee_id) AS affected_employees
FROM updated;

COMMIT;


-- ============================================================
-- PHASE 3: MONTHLY HRIS DATA CLEANING
-- STEP 67: CORRECT ROLE TENURE & PROMOTION COUNTERS
-- ============================================================

BEGIN;

WITH monthly_sequence AS (
    SELECT
        employee_id,
        year_month,
        job_role,
        job_level,
        role_tenure_months,
        months_since_last_promotion,

        LAG(job_role) OVER w AS previous_role,
        LAG(job_level) OVER w AS previous_level,
        LAG(year_month) OVER w AS previous_month,

        ROW_NUMBER() OVER w AS month_number

    FROM staging.employee_monthly_hris

    WINDOW w AS (
        PARTITION BY employee_id
        ORDER BY year_month
    )
),

period_flags AS (
    SELECT
        *,

        CASE
            WHEN previous_role IS NULL
              OR job_role IS DISTINCT FROM previous_role
            THEN 1
            ELSE 0
        END AS new_role_period,

        CASE
            WHEN previous_level IS NULL
              OR job_level IS DISTINCT FROM previous_level
            THEN 1
            ELSE 0
        END AS new_promotion_period

    FROM monthly_sequence
),

period_groups AS (
    SELECT
        *,

        SUM(new_role_period) OVER (
            PARTITION BY employee_id
            ORDER BY year_month
        ) AS role_period,

        SUM(new_promotion_period) OVER (
            PARTITION BY employee_id
            ORDER BY year_month
        ) AS promotion_period

    FROM period_flags
),

corrected_values AS (
    SELECT
        employee_id,
        year_month,

        FIRST_VALUE(role_tenure_months) OVER (
            PARTITION BY employee_id, role_period
            ORDER BY year_month
        )
        + ROW_NUMBER() OVER (
            PARTITION BY employee_id, role_period
            ORDER BY year_month
        ) - 1 AS corrected_role_tenure,

        FIRST_VALUE(months_since_last_promotion) OVER (
            PARTITION BY employee_id, promotion_period
            ORDER BY year_month
        )
        + ROW_NUMBER() OVER (
            PARTITION BY employee_id, promotion_period
            ORDER BY year_month
        ) - 1 AS corrected_promotion_months

    FROM period_groups
),

updated AS (
    UPDATE staging.employee_monthly_hris m

    SET
        role_tenure_months = c.corrected_role_tenure,
        months_since_last_promotion = c.corrected_promotion_months

    FROM corrected_values c

    WHERE m.employee_id = c.employee_id
      AND m.year_month = c.year_month

      AND (
          m.role_tenure_months
              IS DISTINCT FROM c.corrected_role_tenure

          OR m.months_since_last_promotion
              IS DISTINCT FROM c.corrected_promotion_months
      )

    RETURNING m.employee_id
)

SELECT
    COUNT(*) AS corrected_records,
    COUNT(DISTINCT employee_id) AS affected_employees
FROM updated;

COMMIT;



-- ============================================================================
-- D. DATA QUALITY EXCEPTION REGISTER
-- ============================================================================

-- ============================================================
-- PHASE 3: MONTHLY HRIS DATA CLEANING
-- STEP 74: DOCUMENT STALE MANAGER REFERENCES
-- ============================================================

CREATE TABLE IF NOT EXISTS staging.stale_manager_references (
    employee_id TEXT NOT NULL,
    year_month TEXT NOT NULL,
    manager_id TEXT NOT NULL,
    manager_termination_date DATE NOT NULL,

    PRIMARY KEY (employee_id, year_month)
);

INSERT INTO staging.stale_manager_references (
    employee_id,
    year_month,
    manager_id,
    manager_termination_date
)
SELECT
    e.employee_id,
    e.year_month,
    e.manager_id,
    mgr.termination_date

FROM staging.employee_monthly_hris e

JOIN staging.employees_hris mgr
    ON e.manager_id = mgr.employee_id

LEFT JOIN staging.employee_monthly_hris m
    ON e.manager_id = m.employee_id
   AND e.year_month = m.year_month

WHERE e.manager_id IS NOT NULL
  AND m.employee_id IS NULL
  AND mgr.termination_date
      < TO_DATE(e.year_month || '-01', 'YYYY-MM-DD')

ON CONFLICT (employee_id, year_month)
DO UPDATE SET
    manager_id = EXCLUDED.manager_id,
    manager_termination_date =
        EXCLUDED.manager_termination_date;

-- Verification
SELECT
    COUNT(*) AS flagged_records,
    COUNT(DISTINCT employee_id) AS affected_employees,
    COUNT(DISTINCT manager_id) AS former_managers
FROM staging.stale_manager_references;


-- ============================================================
-- PHASE 3: MONTHLY HRIS DATA CLEANING
-- STEP 76: DOCUMENT EMPLOYMENT STATUS CONFLICTS
-- ============================================================

CREATE TABLE IF NOT EXISTS staging.employment_status_conflicts (
    employee_id TEXT NOT NULL,
    employment_status TEXT NOT NULL,
    termination_date DATE NOT NULL,
    termination_type TEXT,
    last_recorded_month TEXT,
    conflict_type TEXT NOT NULL,

    PRIMARY KEY (employee_id, termination_date)
);

WITH latest_monthly AS (
    SELECT
        employee_id,
        MAX(year_month) AS last_recorded_month
    FROM staging.employee_monthly_hris
    GROUP BY employee_id
)

INSERT INTO staging.employment_status_conflicts (
    employee_id,
    employment_status,
    termination_date,
    termination_type,
    last_recorded_month,
    conflict_type
)

SELECT
    e.employee_id,
    e.employment_status,
    s.termination_date,
    s.termination_type,
    lm.last_recorded_month,

    CASE
        WHEN lm.last_recorded_month >
             TO_CHAR(s.termination_date, 'YYYY-MM')
        THEN 'ACTIVE_AFTER_RECORDED_SEPARATION'

        ELSE 'ACTIVE_WITH_SEPARATION_HISTORY'
    END

FROM staging.employees_hris e

JOIN raw.separation_history s
    ON e.employee_id = s.employee_id

JOIN latest_monthly lm
    ON e.employee_id = lm.employee_id

WHERE e.employment_status = 'Active'

ON CONFLICT (employee_id, termination_date)
DO UPDATE SET
    employment_status = EXCLUDED.employment_status,
    termination_type = EXCLUDED.termination_type,
    last_recorded_month = EXCLUDED.last_recorded_month,
    conflict_type = EXCLUDED.conflict_type;

-- Verification
SELECT
    conflict_type,
    COUNT(*) AS conflict_records,
    COUNT(DISTINCT employee_id) AS affected_employees
FROM staging.employment_status_conflicts
GROUP BY conflict_type
ORDER BY conflict_type;



-- ============================================================================
-- E. FINAL DATA QUALITY AUDIT
-- ============================================================================

-- ============================================================
-- PHASE 3: FINAL DATA QUALITY AUDIT
-- STEP 77: MASTER & MONTHLY HRIS VALIDATION
-- ============================================================

WITH master_audit AS (
    SELECT
        COUNT(*) AS total_employees,
        COUNT(DISTINCT employee_id) AS unique_employees,
        COUNT(*) FILTER (
            WHERE employment_status = 'Active'
        ) AS active_employees,
        COUNT(*) FILTER (
            WHERE employment_status = 'Terminated'
        ) AS terminated_employees
    FROM staging.employees_hris
),

monthly_audit AS (
    SELECT
        COUNT(*) AS total_monthly_records,
        COUNT(DISTINCT employee_id) AS monthly_employees,
        COUNT(DISTINCT year_month) AS reporting_months,

        COUNT(*) FILTER (
            WHERE department IS NULL
               OR location IS NULL
               OR job_role IS NULL
        ) AS missing_organizational_fields,

        COUNT(*) FILTER (
            WHERE organizational_tenure_months < 0
               OR role_tenure_months < 0
               OR months_since_last_promotion < 0
        ) AS negative_tenure_values,

        COUNT(*) FILTER (
            WHERE latest_performance_rating IS NULL
        ) AS missing_performance_ratings,

        COUNT(*) FILTER (
            WHERE average_weekly_hours IS NULL
        ) AS missing_weekly_hours,

        COUNT(*) FILTER (
            WHERE unscheduled_absence_days IS NULL
        ) AS missing_absence_days

    FROM staging.employee_monthly_hris
),

exception_audit AS (
    SELECT
        (SELECT COUNT(*)
         FROM staging.stale_manager_references)
            AS stale_manager_references,

        (SELECT COUNT(*)
         FROM staging.employment_status_conflicts)
            AS employment_status_conflicts
)

SELECT
    ma.*,
    mo.*,
    ex.*
FROM master_audit ma
CROSS JOIN monthly_audit mo
CROSS JOIN exception_audit ex;

