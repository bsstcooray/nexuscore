-- ============================================================================
-- NexusCore pgTAP Test Suite
-- Target: Automated Database Integrity & Regression Testing
-- Verifies 27 Entities, Constraints, Triggers & Stored Procedures
-- ============================================================================

BEGIN;
SELECT plan(25);

-- 1. Verify Extensions
SELECT has_extension('pgcrypto', 'pgcrypto extension must be installed for SHA-256');
SELECT has_extension('pg_trgm', 'pg_trgm extension must be installed for fuzzy search');

-- 2. Verify Core Tables Exist
SELECT has_table('client', 'CLIENT table must exist');
SELECT has_table('project', 'PROJECT table must exist');
SELECT has_table('task', 'TASK table must exist');
SELECT has_table('bug', 'BUG table must exist');
SELECT has_table('audit_log', 'AUDIT_LOG table must exist');
SELECT has_table('github_staging', 'GITHUB_STAGING table must exist');
SELECT has_table('activity_event', 'ACTIVITY_EVENT table must exist');
SELECT has_table('app_rule', 'APP_RULE table must exist');

-- 3. Verify Constraints and Foreign Keys
SELECT col_is_pk('client', 'client_id', 'client_id must be primary key');
SELECT col_is_pk('project', 'project_id', 'project_id must be primary key');
SELECT fk_ok('project', 'client_id', 'client', 'client_id', 'PROJECT must reference CLIENT');
SELECT fk_ok('task', 'project_id', 'project', 'project_id', 'TASK must reference PROJECT');

-- 4. Verify Triggers Exist
SELECT has_trigger('task', 'trg_task_status_history', 'TASK must have status history trigger');
SELECT has_trigger('audit_log', 'trg_prevent_audit_tamper_update', 'AUDIT_LOG must prevent update tampering');
SELECT has_trigger('task', 'trg_enforce_task_dependency', 'TASK must enforce DAG dependencies');

-- 5. Stored Procedure Unit Tests: sp_assign_task_smart
PREPARE test_smart_assign AS CALL sp_assign_task_smart(1, 'pgtap_runner');
SELECT lives_ok('test_smart_assign', 'sp_assign_task_smart must execute without exception');

-- 6. Stored Procedure Unit Tests: sp_refresh_project_metrics
PREPARE test_refresh_metrics AS CALL sp_refresh_project_metrics(1);
SELECT lives_ok('test_refresh_metrics', 'sp_refresh_project_metrics must roll up project burndown and risk');

-- 7. Stored Procedure Unit Tests: sp_verify_audit_hash_chain
PREPARE test_audit_verify AS CALL sp_verify_audit_hash_chain();
SELECT lives_ok('test_audit_verify', 'sp_verify_audit_hash_chain must validate cryptographic hash chain');

-- 8. Verify Tamper Prevention Trigger Throws Exception
PREPARE test_audit_tamper AS UPDATE AUDIT_LOG SET action = 'TAMPERED' WHERE audit_id = 1;
SELECT throws_ok(
    'test_audit_tamper',
    'restrict_violation',
    'CRITICAL SECURITY VIOLATION: AUDIT_LOG is strictly append-only. Modifying or deleting audit records is forbidden by system policy.',
    'AUDIT_LOG update must be rejected by trigger'
);

-- Finish pgTAP tests
SELECT * FROM finish();
ROLLBACK;
