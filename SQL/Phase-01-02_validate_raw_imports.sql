-- Employee & Workforce Analytics
-- Raw import verification (read-only)
-- Run after importing all nine CSV files into raw tables.

SELECT 'employees_hris' AS table_name, COUNT(*) AS row_count
FROM raw.employees_hris
UNION ALL
SELECT 'employee_monthly_hris', COUNT(*) FROM raw.employee_monthly_hris
UNION ALL
SELECT 'performance_history', COUNT(*) FROM raw.performance_history
UNION ALL
SELECT 'promotion_history', COUNT(*) FROM raw.promotion_history
UNION ALL
SELECT 'salary_history', COUNT(*) FROM raw.salary_history
UNION ALL
SELECT 'separation_history', COUNT(*) FROM raw.separation_history
UNION ALL
SELECT 'organization_structure', COUNT(*) FROM raw.organization_structure
UNION ALL
SELECT 'location_reference', COUNT(*) FROM raw.location_reference
UNION ALL
SELECT 'organization_events', COUNT(*) FROM raw.organization_events
ORDER BY table_name;
