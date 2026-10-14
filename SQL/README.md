# Phase 4 — Workforce Analytics SQL

PostgreSQL 18 | Database: `workforce_analytics` | Schemas: `staging`, `raw`, `analytics`

## Files

- `01_build_analytics_views.sql`: 13 `CREATE OR REPLACE VIEW` statements in dependency order. **Run this to recreate the analytics model** after staging tables and raw promotion history are available.
- `02_validation_checks.sql`: quality and reconciliation checks from development. Run selectively after building.
- `03_exploratory_queries.sql`: investigative and exploratory SQL retained as an audit trail, not required to build the model.
- `04_original_development_log.sql`: unmodified original SQL (all steps).

## Important modeling notes

- `analytics.vw_monthly_headcount_reconciled.official_headcount` is derived from employee hire and termination dates; observed headcount uses monthly HRIS records.
- 45 missing employee-month records across four months in late 2025; 24 are missing in December 2025. Do not impute compensation for absent records.
- Compensation KPIs filter monthly records to `employment_status = 'Active'`.
- Annual promotion rate uses average annual workforce headcount; level-specific promotion rate uses March active headcount (before April promotions).
- `average_team_vacancy_rate` is an **employee-weighted average of recorded team vacancy rates**, not an enterprise vacancy rate.
- Performance ratings have missing values; operational KPI view exposes counts and coverage.
- Views use `raw.promotion_history` directly, because a staging version was not available in the development environment.

## Usage

Run the build file in pgAdmin Query Tool on the `workforce_analytics` database, **only after** staging/raw dependencies exist. Views already exist in the current database, so rebuilding is not necessary unless you intentionally deploy to a new database or revise definitions. Run validation checks selectively; do not blindly run all investigative queries.

## Preservation

The SQL statements were **reorganized, not rewritten or revalidated on a live database**. The original development log is retained unchanged. The build script contains only view definitions.
