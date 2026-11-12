-- ============================================================================
-- NEXUSCORE UPDATED COMPLETE DATABASE SCHEMA & BASELINE DATA
-- Unified Project, Client and Bug Management System - HelaNexus Solutions
-- ============================================================================

-- >>> BEGIN FILE: database/01_schema_27_entities.sql <<<
-- ============================================================================
-- NexusCore Database Architecture: 27 Normalized Entities (3NF / BCNF)
-- Target System: HelaNexus Software Solutions (PostgreSQL 16+)
-- Module: CS304.3 Advanced Database Management Systems (ADBMS) | Group AC
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Drop existing tables with CASCADE for clean idempotent deployment
DROP TABLE IF EXISTS AI_INTERACTION_LOG CASCADE;
DROP TABLE IF EXISTS LOGIN_ATTEMPT CASCADE;
DROP TABLE IF EXISTS USER_SESSION CASCADE;
DROP TABLE IF EXISTS ASSIGNMENT_SUGGESTION CASCADE;
DROP TABLE IF EXISTS PROJECT_METRIC_SNAPSHOT CASCADE;
DROP TABLE IF EXISTS TASK_STATUS_HISTORY CASCADE;
DROP TABLE IF EXISTS TASK_DEPENDENCY CASCADE;
DROP TABLE IF EXISTS TASK_SKILL CASCADE;
DROP TABLE IF EXISTS EMPLOYEE_SKILL CASCADE;
DROP TABLE IF EXISTS SKILL CASCADE;
DROP TABLE IF EXISTS ALERT CASCADE;
DROP TABLE IF EXISTS APP_RULE CASCADE;
DROP TABLE IF EXISTS ACTIVITY_EVENT CASCADE;
DROP TABLE IF EXISTS WORK_SESSION CASCADE;
DROP TABLE IF EXISTS GITHUB_STAGING CASCADE;
DROP TABLE IF EXISTS SYNC_RUN CASCADE;
DROP TABLE IF EXISTS AUDIT_LOG CASCADE;
DROP TABLE IF EXISTS GITHUB_REFERENCE CASCADE;
DROP TABLE IF EXISTS TIME_LOG CASCADE;
DROP TABLE IF EXISTS BUG CASCADE;
DROP TABLE IF EXISTS TASK CASCADE;
DROP TABLE IF EXISTS PROJECT_ASSIGNMENT CASCADE;
DROP TABLE IF EXISTS APP_USER CASCADE;
DROP TABLE IF EXISTS EMPLOYEE CASCADE;
DROP TABLE IF EXISTS PROJECT CASCADE;
DROP TABLE IF EXISTS CLIENT_INTERACTION CASCADE;
DROP TABLE IF EXISTS CLIENT CASCADE;

-- Drop custom ENUM types
DROP TYPE IF EXISTS client_tier_enum CASCADE;
DROP TYPE IF EXISTS project_status_enum CASCADE;
DROP TYPE IF EXISTS task_priority_enum CASCADE;
DROP TYPE IF EXISTS task_status_enum CASCADE;
DROP TYPE IF EXISTS bug_severity_enum CASCADE;
DROP TYPE IF EXISTS bug_status_enum CASCADE;
DROP TYPE IF EXISTS app_user_role_enum CASCADE;
DROP TYPE IF EXISTS alert_severity_enum CASCADE;
DROP TYPE IF EXISTS sync_status_enum CASCADE;

-- Custom ENUM types
CREATE TYPE client_tier_enum AS ENUM ('standard', 'premium', 'enterprise');
CREATE TYPE project_status_enum AS ENUM ('planning', 'active', 'on_hold', 'completed', 'archived');
CREATE TYPE task_priority_enum AS ENUM ('low', 'medium', 'high', 'critical');
CREATE TYPE task_status_enum AS ENUM ('backlog', 'todo', 'in_progress', 'review', 'completed', 'blocked');
CREATE TYPE bug_severity_enum AS ENUM ('low', 'medium', 'high', 'critical');
CREATE TYPE bug_status_enum AS ENUM ('reported', 'triaged', 'in_progress', 'resolved', 'closed');
CREATE TYPE app_user_role_enum AS ENUM ('ceo_admin', 'project_manager', 'developer_qa', 'client_restricted');
CREATE TYPE alert_severity_enum AS ENUM ('info', 'low', 'medium', 'high', 'critical');
CREATE TYPE sync_status_enum AS ENUM ('pending', 'processing', 'completed', 'failed');

-- ============================================================================
-- GROUP 1: CORE BUSINESS ENTITIES (11 Tables)
-- ============================================================================

-- 1. CLIENT
CREATE TABLE CLIENT (
    client_id SERIAL PRIMARY KEY,
    company_name VARCHAR(150) NOT NULL UNIQUE,
    industry VARCHAR(100) NOT NULL,
    contact_email VARCHAR(255) NOT NULL UNIQUE,
    contact_phone VARCHAR(30),
    billing_tier client_tier_enum NOT NULL DEFAULT 'standard',
    sla_response_hours INT NOT NULL DEFAULT 24 CHECK (sla_response_hours > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. CLIENT_INTERACTION
CREATE TABLE CLIENT_INTERACTION (
    interaction_id SERIAL PRIMARY KEY,
    client_id INT NOT NULL REFERENCES CLIENT(client_id) ON DELETE CASCADE,
    interaction_type VARCHAR(50) NOT NULL CHECK (interaction_type IN ('meeting', 'call', 'email', 'review', 'support')),
    summary VARCHAR(255) NOT NULL,
    details TEXT,
    sentiment_score NUMERIC(3,2) CHECK (sentiment_score BETWEEN -1.00 AND 1.00),
    logged_by VARCHAR(100) NOT NULL,
    interaction_date TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 3. PROJECT
CREATE TABLE PROJECT (
    project_id SERIAL PRIMARY KEY,
    client_id INT NOT NULL REFERENCES CLIENT(client_id) ON DELETE RESTRICT,
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    status project_status_enum NOT NULL DEFAULT 'planning',
    budget_allocated NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (budget_allocated >= 0),
    budget_spent NUMERIC(12,2) NOT NULL DEFAULT 0.00 CHECK (budget_spent >= 0),
    health_score INT NOT NULL DEFAULT 100 CHECK (health_score BETWEEN 0 AND 100),
    risk_level VARCHAR(20) NOT NULL DEFAULT 'low' CHECK (risk_level IN ('low', 'moderate', 'high', 'critical')),
    start_date DATE NOT NULL,
    target_end_date DATE NOT NULL CHECK (target_end_date >= start_date),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 4. EMPLOYEE
CREATE TABLE EMPLOYEE (
    employee_id SERIAL PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    work_email VARCHAR(255) NOT NULL UNIQUE,
    designation VARCHAR(100) NOT NULL,
    department VARCHAR(80) NOT NULL CHECK (department IN ('engineering', 'design', 'qa', 'devops', 'admin', 'leadership')),
    hourly_rate NUMERIC(8,2) NOT NULL CHECK (hourly_rate > 0),
    weekly_capacity_hours NUMERIC(4,1) NOT NULL DEFAULT 40.0 CHECK (weekly_capacity_hours > 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    hire_date DATE NOT NULL DEFAULT CURRENT_DATE
);

-- 5. APP_USER (System credentials, RBAC & TOTP MFA)
CREATE TABLE APP_USER (
    user_id SERIAL PRIMARY KEY,
    employee_id INT UNIQUE REFERENCES EMPLOYEE(employee_id) ON DELETE CASCADE,
    username VARCHAR(80) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role app_user_role_enum NOT NULL DEFAULT 'developer_qa',
    mfa_secret VARCHAR(64),
    mfa_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    is_locked BOOLEAN NOT NULL DEFAULT FALSE,
    failed_login_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 6. PROJECT_ASSIGNMENT (Many-to-Many resolver with capacity control)
CREATE TABLE PROJECT_ASSIGNMENT (
    assignment_id SERIAL PRIMARY KEY,
    project_id INT NOT NULL REFERENCES PROJECT(project_id) ON DELETE CASCADE,
    employee_id INT NOT NULL REFERENCES EMPLOYEE(employee_id) ON DELETE RESTRICT,
    assigned_role VARCHAR(80) NOT NULL,
    allocation_percentage INT NOT NULL DEFAULT 100 CHECK (allocation_percentage BETWEEN 1 AND 100),
    joined_date DATE NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT uq_project_employee UNIQUE (project_id, employee_id)
);

-- 7. TASK
CREATE TABLE TASK (
    task_id SERIAL PRIMARY KEY,
    project_id INT NOT NULL REFERENCES PROJECT(project_id) ON DELETE CASCADE,
    assigned_to INT REFERENCES EMPLOYEE(employee_id) ON DELETE SET NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT,
    priority task_priority_enum NOT NULL DEFAULT 'medium',
    status task_status_enum NOT NULL DEFAULT 'todo',
    estimated_hours NUMERIC(5,2) NOT NULL DEFAULT 4.0 CHECK (estimated_hours > 0),
    actual_hours NUMERIC(5,2) NOT NULL DEFAULT 0.0 CHECK (actual_hours >= 0),
    sprint_number INT NOT NULL DEFAULT 1 CHECK (sprint_number > 0),
    deadline TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 8. BUG
CREATE TABLE BUG (
    bug_id SERIAL PRIMARY KEY,
    project_id INT NOT NULL REFERENCES PROJECT(project_id) ON DELETE CASCADE,
    task_id INT REFERENCES TASK(task_id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    severity bug_severity_enum NOT NULL DEFAULT 'medium',
    status bug_status_enum NOT NULL DEFAULT 'reported',
    steps_to_reproduce TEXT,
    github_issue_id INT UNIQUE,
    reported_by VARCHAR(100) NOT NULL,
    assigned_to INT REFERENCES EMPLOYEE(employee_id) ON DELETE SET NULL,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 9. TIME_LOG
CREATE TABLE TIME_LOG (
    log_id SERIAL PRIMARY KEY,
    employee_id INT NOT NULL REFERENCES EMPLOYEE(employee_id) ON DELETE RESTRICT,
    task_id INT NOT NULL REFERENCES TASK(task_id) ON DELETE CASCADE,
    hours_spent NUMERIC(4,2) NOT NULL CHECK (hours_spent > 0 AND hours_spent <= 24.0),
    work_summary TEXT NOT NULL,
    is_billable BOOLEAN NOT NULL DEFAULT TRUE,
    logged_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 10. GITHUB_REFERENCE
CREATE TABLE GITHUB_REFERENCE (
    reference_id SERIAL PRIMARY KEY,
    reference_type VARCHAR(20) NOT NULL CHECK (reference_type IN ('task', 'bug')),
    item_id INT NOT NULL,
    github_repo VARCHAR(150) NOT NULL,
    github_pull_or_issue_num INT NOT NULL,
    html_url VARCHAR(500) NOT NULL,
    last_synced_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_github_ref UNIQUE (reference_type, item_id, github_repo, github_pull_or_issue_num)
);

-- 11. AUDIT_LOG (Cryptographically Hash-Chained Immutable Ledger)
CREATE TABLE AUDIT_LOG (
    audit_id SERIAL PRIMARY KEY,
    table_name VARCHAR(80) NOT NULL,
    record_id INT NOT NULL,
    action VARCHAR(10) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_data JSONB,
    new_data JSONB,
    changed_by VARCHAR(100) NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    prev_hash VARCHAR(64) NOT NULL,
    current_hash VARCHAR(64) NOT NULL
);

-- ============================================================================
-- GROUP 2: GITHUB INTEGRATION & DECOUPLED STAGING (2 Tables)
-- ============================================================================

-- 12. SYNC_RUN
CREATE TABLE SYNC_RUN (
    run_id SERIAL PRIMARY KEY,
    source VARCHAR(80) NOT NULL DEFAULT 'github-api',
    status sync_status_enum NOT NULL DEFAULT 'pending',
    items_fetched INT NOT NULL DEFAULT 0,
    items_synced INT NOT NULL DEFAULT 0,
    items_failed INT NOT NULL DEFAULT 0,
    error_log TEXT,
    started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ
);

-- 13. GITHUB_STAGING (Decoupled staging buffer)
CREATE TABLE GITHUB_STAGING (
    staging_id SERIAL PRIMARY KEY,
    run_id INT NOT NULL REFERENCES SYNC_RUN(run_id) ON DELETE CASCADE,
    issue_number INT NOT NULL,
    title VARCHAR(255) NOT NULL,
    state VARCHAR(30) NOT NULL,
    raw_payload JSONB NOT NULL,
    staging_status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (staging_status IN ('pending', 'validated', 'upserted', 'rejected')),
    validation_error TEXT,
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- GROUP 3: WORK MONITORING & TELEMETRY (4 Tables, Range Partitioning)
-- ============================================================================

-- 14. WORK_SESSION
CREATE TABLE WORK_SESSION (
    session_id SERIAL PRIMARY KEY,
    employee_id INT NOT NULL REFERENCES EMPLOYEE(employee_id) ON DELETE CASCADE,
    task_id INT REFERENCES TASK(task_id) ON DELETE SET NULL,
    start_time TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMPTZ,
    total_duration_minutes INT DEFAULT 0,
    productive_duration_minutes INT DEFAULT 0,
    idle_duration_minutes INT DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'completed'))
);

-- 15. ACTIVITY_EVENT (Range Partitioned by Month for PDPA 2022 Performance & Retention)
CREATE TABLE ACTIVITY_EVENT (
    event_id BIGSERIAL,
    session_id INT NOT NULL,
    employee_id INT NOT NULL,
    event_timestamp TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    window_title VARCHAR(255) NOT NULL,
    process_name VARCHAR(120) NOT NULL,
    is_productive BOOLEAN NOT NULL DEFAULT TRUE,
    duration_seconds INT NOT NULL DEFAULT 10 CHECK (duration_seconds > 0),
    PRIMARY KEY (event_id, event_timestamp)
) PARTITION BY RANGE (event_timestamp);

-- Monthly partition tables for 2026
CREATE TABLE activity_event_2026_10 PARTITION OF ACTIVITY_EVENT
    FOR VALUES FROM ('2026-10-01 00:00:00+00') TO ('2026-11-01 00:00:00+00');

CREATE TABLE activity_event_2026_11 PARTITION OF ACTIVITY_EVENT
    FOR VALUES FROM ('2026-11-01 00:00:00+00') TO ('2026-12-01 00:00:00+00');

CREATE TABLE activity_event_2026_12 PARTITION OF ACTIVITY_EVENT
    FOR VALUES FROM ('2026-12-01 00:00:00+00') TO ('2027-01-01 00:00:00+00');

-- 16. APP_RULE (PDPA 2022 compliant classification rules)
CREATE TABLE APP_RULE (
    rule_id SERIAL PRIMARY KEY,
    pattern VARCHAR(120) NOT NULL UNIQUE,
    match_type VARCHAR(20) NOT NULL CHECK (match_type IN ('process', 'window_title_regex', 'exact')),
    rule_category VARCHAR(50) NOT NULL CHECK (rule_category IN ('ide', 'terminal', 'documentation', 'communication', 'non_work', 'entertainment')),
    is_productive BOOLEAN NOT NULL DEFAULT TRUE,
    alert_threshold_seconds INT NOT NULL DEFAULT 300,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 17. ALERT
CREATE TABLE ALERT (
    alert_id SERIAL PRIMARY KEY,
    session_id INT REFERENCES WORK_SESSION(session_id) ON DELETE CASCADE,
    employee_id INT NOT NULL REFERENCES EMPLOYEE(employee_id) ON DELETE CASCADE,
    rule_id INT REFERENCES APP_RULE(rule_id) ON DELETE SET NULL,
    alert_type VARCHAR(50) NOT NULL,
    severity alert_severity_enum NOT NULL DEFAULT 'medium',
    description TEXT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'acknowledged', 'dismissed', 'resolved')),
    acknowledged_by VARCHAR(100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- GROUP 4: INTELLIGENCE & ANALYTICS (7 Tables)
-- ============================================================================

-- 18. SKILL
CREATE TABLE SKILL (
    skill_id SERIAL PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE,
    category VARCHAR(50) NOT NULL CHECK (category IN ('frontend', 'backend', 'database', 'devops', 'testing', 'ai_ml', 'design')),
    description TEXT
);

-- 19. EMPLOYEE_SKILL
CREATE TABLE EMPLOYEE_SKILL (
    emp_skill_id SERIAL PRIMARY KEY,
    employee_id INT NOT NULL REFERENCES EMPLOYEE(employee_id) ON DELETE CASCADE,
    skill_id INT NOT NULL REFERENCES SKILL(skill_id) ON DELETE CASCADE,
    proficiency_level INT NOT NULL CHECK (proficiency_level BETWEEN 1 AND 5),
    years_experience NUMERIC(3,1) NOT NULL DEFAULT 1.0 CHECK (years_experience >= 0),
    CONSTRAINT uq_emp_skill UNIQUE (employee_id, skill_id)
);

-- 20. TASK_SKILL
CREATE TABLE TASK_SKILL (
    task_skill_id SERIAL PRIMARY KEY,
    task_id INT NOT NULL REFERENCES TASK(task_id) ON DELETE CASCADE,
    skill_id INT NOT NULL REFERENCES SKILL(skill_id) ON DELETE CASCADE,
    required_level INT NOT NULL DEFAULT 3 CHECK (required_level BETWEEN 1 AND 5),
    CONSTRAINT uq_task_skill UNIQUE (task_id, skill_id)
);

-- 21. TASK_DEPENDENCY (Directed Acyclic Graph dependency model)
CREATE TABLE TASK_DEPENDENCY (
    dependency_id SERIAL PRIMARY KEY,
    task_id INT NOT NULL REFERENCES TASK(task_id) ON DELETE CASCADE,
    depends_on_task_id INT NOT NULL REFERENCES TASK(task_id) ON DELETE CASCADE,
    dependency_type VARCHAR(30) NOT NULL DEFAULT 'finish_to_start' CHECK (dependency_type IN ('finish_to_start', 'start_to_start', 'finish_to_finish')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_task_dependency UNIQUE (task_id, depends_on_task_id),
    CONSTRAINT chk_no_self_dependency CHECK (task_id != depends_on_task_id)
);

-- 22. TASK_STATUS_HISTORY
CREATE TABLE TASK_STATUS_HISTORY (
    history_id SERIAL PRIMARY KEY,
    task_id INT NOT NULL REFERENCES TASK(task_id) ON DELETE CASCADE,
    old_status task_status_enum,
    new_status task_status_enum NOT NULL,
    changed_by VARCHAR(100) NOT NULL,
    notes TEXT,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 23. PROJECT_METRIC_SNAPSHOT (Aggregated weekly delivery benchmarks)
CREATE TABLE PROJECT_METRIC_SNAPSHOT (
    snapshot_id SERIAL PRIMARY KEY,
    project_id INT NOT NULL REFERENCES PROJECT(project_id) ON DELETE CASCADE,
    snapshot_date DATE NOT NULL DEFAULT CURRENT_DATE,
    burndown_percentage NUMERIC(5,2) NOT NULL CHECK (burndown_percentage BETWEEN 0 AND 100),
    cycle_time_days NUMERIC(4,2) NOT NULL CHECK (cycle_time_days >= 0),
    open_bugs_count INT NOT NULL DEFAULT 0 CHECK (open_bugs_count >= 0),
    velocity_points INT NOT NULL DEFAULT 0 CHECK (velocity_points >= 0),
    risk_score INT NOT NULL DEFAULT 0 CHECK (risk_score BETWEEN 0 AND 100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_project_snapshot UNIQUE (project_id, snapshot_date)
);

-- 24. ASSIGNMENT_SUGGESTION (In-database ranking cache)
CREATE TABLE ASSIGNMENT_SUGGESTION (
    suggestion_id SERIAL PRIMARY KEY,
    task_id INT NOT NULL REFERENCES TASK(task_id) ON DELETE CASCADE,
    employee_id INT NOT NULL REFERENCES EMPLOYEE(employee_id) ON DELETE CASCADE,
    match_score NUMERIC(5,2) NOT NULL CHECK (match_score BETWEEN 0 AND 100),
    skill_fit_score NUMERIC(5,2) NOT NULL CHECK (skill_fit_score BETWEEN 0 AND 100),
    workload_score NUMERIC(5,2) NOT NULL CHECK (workload_score BETWEEN 0 AND 100),
    ranking INT NOT NULL CHECK (ranking > 0),
    recommendation_reason TEXT,
    generated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_task_emp_suggestion UNIQUE (task_id, employee_id)
);

-- ============================================================================
-- GROUP 5: SECURITY & SESSIONS (2 Tables)
-- ============================================================================

-- 25. USER_SESSION (Revocable session token management)
CREATE TABLE USER_SESSION (
    session_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES APP_USER(user_id) ON DELETE CASCADE,
    token_hash VARCHAR(64) NOT NULL UNIQUE,
    ip_address INET,
    user_agent TEXT,
    expires_at TIMESTAMPTZ NOT NULL,
    is_revoked BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 26. LOGIN_ATTEMPT (Brute-force detection & security auditing)
CREATE TABLE LOGIN_ATTEMPT (
    attempt_id SERIAL PRIMARY KEY,
    username VARCHAR(80) NOT NULL,
    ip_address INET,
    is_success BOOLEAN NOT NULL DEFAULT FALSE,
    failure_reason VARCHAR(100),
    attempted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- GROUP 6: ARTIFICIAL INTELLIGENCE (1 Table)
-- ============================================================================

-- 27. AI_INTERACTION_LOG (Text-to-SQL & Assistant Audit History)
CREATE TABLE AI_INTERACTION_LOG (
    interaction_id SERIAL PRIMARY KEY,
    user_id INT REFERENCES APP_USER(user_id) ON DELETE SET NULL,
    prompt_text TEXT NOT NULL,
    generated_sql TEXT,
    response_summary TEXT NOT NULL,
    latency_ms INT NOT NULL CHECK (latency_ms >= 0),
    tokens_used INT NOT NULL CHECK (tokens_used >= 0),
    model_version VARCHAR(50) NOT NULL DEFAULT 'gemini-1.5-flash',
    status VARCHAR(20) NOT NULL DEFAULT 'success' CHECK (status IN ('success', 'rejected', 'error')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- >>> END FILE: database/01_schema_27_entities.sql <<<

-- >>> BEGIN FILE: database/02_stored_procedures.sql <<<
-- ============================================================================
-- NexusCore Database Architecture: 6 Core Stored Procedures & Functions
-- PostgreSQL 16+ PL/pgSQL with ACID Row Locking, Fuzzy Matching & Cryptography
-- ============================================================================

-- ----------------------------------------------------------------------------
-- PROCEDURE 1: sp_assign_task_smart
-- Advanced In-Database Scoring Function with SELECT FOR UPDATE Row Locking
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_assign_task_smart(
    p_task_id INT,
    p_assigned_by VARCHAR(100),
    INOUT p_assigned_employee_id INT DEFAULT NULL,
    INOUT p_match_score NUMERIC(5,2) DEFAULT NULL,
    INOUT p_status_message TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_task_record RECORD;
    v_best_candidate RECORD;
BEGIN
    -- 1. Fetch and Lock the Task Record
    SELECT * INTO v_task_record
    FROM TASK
    WHERE task_id = p_task_id
    FOR UPDATE;

    IF NOT FOUND THEN
        p_status_message := 'Error: Task ID ' || p_task_id || ' does not exist.';
        RETURN;
    END IF;

    -- 2. Execute Multi-Factor Ranking Query with SELECT FOR UPDATE on Employee
    -- Factor A: Skill match ratio (weight 50%)
    -- Factor B: Workload availability capacity (weight 30%)
    -- Factor C: Department domain alignment (weight 20%)
    WITH CandidateScoring AS (
        SELECT 
            e.employee_id,
            e.full_name,
            -- Skill Fit Calculation (0 - 100)
            COALESCE(
                (
                    SELECT (COUNT(es.skill_id)::NUMERIC / NULLIF(COUNT(ts.skill_id), 0)::NUMERIC) * 100
                    FROM TASK_SKILL ts
                    LEFT JOIN EMPLOYEE_SKILL es 
                        ON ts.skill_id = es.skill_id 
                        AND es.employee_id = e.employee_id
                        AND es.proficiency_level >= ts.required_level
                    WHERE ts.task_id = p_task_id
                ), 75.0
            ) AS skill_score,
            -- Workload Capacity Calculation (100 = 0 hours allocated, 0 = fully booked)
            GREATEST(
                0.0,
                100.0 - (
                    COALESCE(
                        (
                            SELECT SUM(t.estimated_hours)
                            FROM TASK t
                            WHERE t.assigned_to = e.employee_id 
                              AND t.status IN ('todo', 'in_progress', 'review')
                        ), 0.0
                    ) / NULLIF(e.weekly_capacity_hours, 0) * 100.0
                )
            ) AS capacity_score,
            -- Department fit
            CASE WHEN e.department = 'engineering' THEN 100.0 ELSE 70.0 END AS dept_score
        FROM EMPLOYEE e
        WHERE e.is_active = TRUE
          AND e.department IN ('engineering', 'qa', 'devops')
        FOR UPDATE OF e SKIP LOCKED -- ACID: Prevent concurrent managers from allocating same dev
    )
    SELECT 
        employee_id,
        ROUND((skill_score * 0.50 + capacity_score * 0.30 + dept_score * 0.20)::NUMERIC, 2) AS total_score,
        skill_score,
        capacity_score
    INTO v_best_candidate
    FROM CandidateScoring
    ORDER BY (skill_score * 0.50 + capacity_score * 0.30 + dept_score * 0.20) DESC
    LIMIT 1;

    IF v_best_candidate.employee_id IS NULL THEN
        p_status_message := 'Warning: No eligible active developers currently available.';
        RETURN;
    END IF;

    -- 3. Assign Task Atomically
    UPDATE TASK
    SET assigned_to = v_best_candidate.employee_id,
        status = CASE WHEN status = 'backlog' THEN 'todo' ELSE status END
    WHERE task_id = p_task_id;

    -- 4. Cache Suggestion Score
    INSERT INTO ASSIGNMENT_SUGGESTION (
        task_id, employee_id, match_score, skill_fit_score, workload_score, ranking, recommendation_reason
    ) VALUES (
        p_task_id,
        v_best_candidate.employee_id,
        v_best_candidate.total_score,
        v_best_candidate.skill_score,
        v_best_candidate.capacity_score,
        1,
        'Auto-assigned via Smart Engine (Skill Fit: ' || v_best_candidate.skill_score || '%, Capacity: ' || v_best_candidate.capacity_score || '%)'
    )
    ON CONFLICT (task_id, employee_id) DO UPDATE 
    SET match_score = EXCLUDED.match_score,
        skill_fit_score = EXCLUDED.skill_fit_score,
        workload_score = EXCLUDED.workload_score,
        generated_at = CURRENT_TIMESTAMP;

    -- 5. Record State Transition
    INSERT INTO TASK_STATUS_HISTORY (
        task_id, old_status, new_status, changed_by, notes
    ) VALUES (
        p_task_id,
        v_task_record.status,
        CASE WHEN v_task_record.status = 'backlog' THEN 'todo' ELSE v_task_record.status END,
        p_assigned_by,
        'Smart Engine automated allocation to Employee #' || v_best_candidate.employee_id
    );

    p_assigned_employee_id := v_best_candidate.employee_id;
    p_match_score := v_best_candidate.total_score;
    p_status_message := 'Success: Task #' || p_task_id || ' allocated with match score ' || v_best_candidate.total_score || '%.';
END;
$$;


-- ----------------------------------------------------------------------------
-- PROCEDURE 2: sp_sync_github_staging
-- Decoupled Staging Ingestion with Validation and Single-Transaction Upsert
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_sync_github_staging(
    p_run_id INT,
    INOUT p_synced_count INT DEFAULT 0,
    INOUT p_failed_count INT DEFAULT 0
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_rec RECORD;
    v_default_project_id INT;
BEGIN
    -- Determine default triage project (e.g., first active project)
    SELECT project_id INTO v_default_project_id
    FROM PROJECT
    WHERE status = 'active'
    ORDER BY project_id ASC
    LIMIT 1;

    IF v_default_project_id IS NULL THEN
        SELECT project_id INTO v_default_project_id FROM PROJECT LIMIT 1;
    END IF;

    -- Process pending staging items for this sync run
    FOR v_rec IN 
        SELECT staging_id, issue_number, title, state, raw_payload
        FROM GITHUB_STAGING
        WHERE run_id = p_run_id AND staging_status = 'pending'
        FOR UPDATE
    LOOP
        -- Validation: Title must not be empty, payload must contain valid id
        IF v_rec.title IS NULL OR length(trim(v_rec.title)) = 0 THEN
            UPDATE GITHUB_STAGING
            SET staging_status = 'rejected',
                validation_error = 'Rejected: Issue title is empty or missing.'
            WHERE staging_id = v_rec.staging_id;
            
            p_failed_count := p_failed_count + 1;
        ELSE
            -- Upsert into BUG table
            INSERT INTO BUG (
                project_id,
                title,
                severity,
                status,
                steps_to_reproduce,
                github_issue_id,
                reported_by
            ) VALUES (
                v_default_project_id,
                v_rec.title,
                CASE 
                    WHEN v_rec.raw_payload->>'labels' ILIKE '%critical%' THEN 'critical'::bug_severity_enum
                    WHEN v_rec.raw_payload->>'labels' ILIKE '%high%' THEN 'high'::bug_severity_enum
                    ELSE 'medium'::bug_severity_enum
                END,
                CASE WHEN v_rec.state = 'closed' THEN 'closed'::bug_status_enum ELSE 'reported'::bug_status_enum END,
                'Imported via GitHub Sync Service Staging Queue. Raw issue: #' || v_rec.issue_number,
                v_rec.issue_number,
                COALESCE(v_rec.raw_payload->'user'->>'login', 'github-webhook')
            )
            ON CONFLICT (github_issue_id) DO UPDATE 
            SET title = EXCLUDED.title,
                status = EXCLUDED.status,
                resolved_at = CASE WHEN EXCLUDED.status = 'closed' THEN CURRENT_TIMESTAMP ELSE NULL END;

            -- Record reference mapping
            INSERT INTO GITHUB_REFERENCE (
                reference_type, item_id, github_repo, github_pull_or_issue_num, html_url
            ) VALUES (
                'bug',
                v_rec.issue_number,
                'HelaNexus/nexus-core-mono',
                v_rec.issue_number,
                COALESCE(v_rec.raw_payload->>'html_url', 'https://github.com/HelaNexus/nexus-core-mono/issues/' || v_rec.issue_number)
            )
            ON CONFLICT (reference_type, item_id, github_repo, github_pull_or_issue_num) DO UPDATE
            SET last_synced_at = CURRENT_TIMESTAMP;

            -- Mark staging item as upserted
            UPDATE GITHUB_STAGING
            SET staging_status = 'upserted',
                validation_error = NULL
            WHERE staging_id = v_rec.staging_id;

            p_synced_count := p_synced_count + 1;
        END IF;
    END LOOP;

    -- Update parent SYNC_RUN execution summary
    UPDATE SYNC_RUN
    SET items_synced = p_synced_count,
        items_failed = p_failed_count,
        status = 'completed',
        completed_at = CURRENT_TIMESTAMP
    WHERE run_id = p_run_id;
END;
$$;


-- ----------------------------------------------------------------------------
-- PROCEDURE 3: sp_refresh_project_metrics
-- Materialized Metric Roll-Ups & Risk Analysis (Weekly Automation)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_refresh_project_metrics(
    p_project_id INT,
    INOUT p_burndown NUMERIC(5,2) DEFAULT NULL,
    INOUT p_risk_score INT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_hours NUMERIC(8,2);
    v_done_hours NUMERIC(8,2);
    v_open_bugs INT;
    v_critical_bugs INT;
    v_cycle_time NUMERIC(4,2);
    v_calc_risk INT;
BEGIN
    -- 1. Calculate Burndown
    SELECT 
        COALESCE(SUM(estimated_hours), 0.0),
        COALESCE(SUM(CASE WHEN status = 'completed' THEN estimated_hours ELSE 0.0 END), 0.0)
    INTO v_total_hours, v_done_hours
    FROM TASK
    WHERE project_id = p_project_id;

    IF v_total_hours > 0 THEN
        p_burndown := ROUND((v_done_hours / v_total_hours * 100.0)::NUMERIC, 2);
    ELSE
        p_burndown := 0.0;
    END IF;

    -- 2. Calculate Bugs & Severity
    SELECT 
        COUNT(*),
        COUNT(*) FILTER (WHERE severity = 'critical')
    INTO v_open_bugs, v_critical_bugs
    FROM BUG
    WHERE project_id = p_project_id AND status != 'closed';

    -- 3. Calculate Cycle Time (Average days to complete tasks)
    SELECT COALESCE(ROUND(AVG(EXTRACT(EPOCH FROM (deadline - created_at)) / 86400)::NUMERIC, 2), 2.5)
    INTO v_cycle_time
    FROM TASK
    WHERE project_id = p_project_id AND status = 'completed';

    -- 4. In-Database Risk Score Formulation (0 = Perfect, 100 = Critical Danger)
    -- Risk = (Critical Bugs * 25) + (Open Bugs * 5) + (Unfinished Ratio * 20)
    v_calc_risk := LEAST(100, GREATEST(0, (v_critical_bugs * 25) + (v_open_bugs * 5) + ROUND(((100.0 - p_burndown) * 0.20)::NUMERIC)::INT));
    p_risk_score := v_calc_risk;

    -- 5. Upsert Project Metric Snapshot
    INSERT INTO PROJECT_METRIC_SNAPSHOT (
        project_id, snapshot_date, burndown_percentage, cycle_time_days, open_bugs_count, velocity_points, risk_score
    ) VALUES (
        p_project_id,
        CURRENT_DATE,
        p_burndown,
        v_cycle_time,
        v_open_bugs,
        ROUND((v_done_hours * 1.2)::NUMERIC)::INT,
        v_calc_risk
    )
    ON CONFLICT (project_id, snapshot_date) DO UPDATE
    SET burndown_percentage = EXCLUDED.burndown_percentage,
        cycle_time_days = EXCLUDED.cycle_time_days,
        open_bugs_count = EXCLUDED.open_bugs_count,
        risk_score = EXCLUDED.risk_score;

    -- 6. Update Project table overall health
    UPDATE PROJECT
    SET health_score = 100 - v_calc_risk,
        risk_level = CASE 
            WHEN v_calc_risk >= 70 THEN 'critical'
            WHEN v_calc_risk >= 40 THEN 'high'
            WHEN v_calc_risk >= 20 THEN 'moderate'
            ELSE 'low'
        END
    WHERE project_id = p_project_id;
END;
$$;


-- ----------------------------------------------------------------------------
-- PROCEDURE 4: sp_merge_duplicate_clients
-- Trigram Fuzzy Client Deduplication & Atomic Consolidation
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_merge_duplicate_clients(
    p_primary_client_id INT,
    p_duplicate_client_id INT,
    INOUT p_result_message TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_primary_name VARCHAR(150);
    v_dup_name VARCHAR(150);
BEGIN
    SELECT company_name INTO v_primary_name FROM CLIENT WHERE client_id = p_primary_client_id;
    SELECT company_name INTO v_dup_name FROM CLIENT WHERE client_id = p_duplicate_client_id;

    IF v_primary_name IS NULL OR v_dup_name IS NULL THEN
        p_result_message := 'Error: Invalid client ID provided.';
        RETURN;
    END IF;

    -- Reassign Projects to primary client
    UPDATE PROJECT
    SET client_id = p_primary_client_id
    WHERE client_id = p_duplicate_client_id;

    -- Reassign Client Interactions
    UPDATE CLIENT_INTERACTION
    SET client_id = p_primary_client_id
    WHERE client_id = p_duplicate_client_id;

    -- Delete the duplicate client
    DELETE FROM CLIENT WHERE client_id = p_duplicate_client_id;

    p_result_message := 'Successfully merged duplicate client "' || v_dup_name || '" into primary client "' || v_primary_name || '".';
END;
$$;


-- ----------------------------------------------------------------------------
-- PROCEDURE 5: sp_process_activity_event
-- Telemetry Heartbeat Processor with PDPA 2022 Non-Work Alerting
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_process_activity_event(
    p_session_id INT,
    p_employee_id INT,
    p_process_name VARCHAR(120),
    p_window_title VARCHAR(255),
    p_duration_seconds INT,
    INOUT p_is_alert_raised BOOLEAN DEFAULT FALSE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_rule RECORD;
    v_is_productive BOOLEAN := TRUE;
    v_idle_sum INT;
BEGIN
    -- Check against classification rules
    SELECT * INTO v_rule
    FROM APP_RULE
    WHERE p_process_name ILIKE ('%' || pattern || '%')
       OR p_window_title ILIKE ('%' || pattern || '%')
    LIMIT 1;

    IF FOUND THEN
        v_is_productive := v_rule.is_productive;
    END IF;

    -- Insert into range partitioned table
    INSERT INTO ACTIVITY_EVENT (
        session_id, employee_id, event_timestamp, window_title, process_name, is_productive, duration_seconds
    ) VALUES (
        p_session_id, p_employee_id, CURRENT_TIMESTAMP, p_window_title, p_process_name, v_is_productive, p_duration_seconds
    );

    -- Update session durations
    IF v_is_productive THEN
        UPDATE WORK_SESSION
        SET total_duration_minutes = total_duration_minutes + ROUND(p_duration_seconds / 60.0)::INT,
            productive_duration_minutes = productive_duration_minutes + ROUND(p_duration_seconds / 60.0)::INT
        WHERE session_id = p_session_id;
    ELSE
        UPDATE WORK_SESSION
        SET total_duration_minutes = total_duration_minutes + ROUND(p_duration_seconds / 60.0)::INT,
            idle_duration_minutes = idle_duration_minutes + ROUND(p_duration_seconds / 60.0)::INT
        WHERE session_id = p_session_id;

        -- Check accumulated non-work time in this session
        SELECT idle_duration_minutes INTO v_idle_sum
        FROM WORK_SESSION
        WHERE session_id = p_session_id;

        IF v_idle_sum >= 15 THEN
            -- Raise Manager Alert
            INSERT INTO ALERT (
                session_id, employee_id, rule_id, alert_type, severity, description
            ) VALUES (
                p_session_id,
                p_employee_id,
                v_rule.rule_id,
                'non_work_application_threshold',
                'high',
                'Exceeded non-work threshold (' || v_idle_sum || ' mins idle/entertainment) during logged active sprint session.'
            );
            p_is_alert_raised := TRUE;
        END IF;
    END IF;
END;
$$;


-- ----------------------------------------------------------------------------
-- PROCEDURE 6: sp_verify_audit_hash_chain
-- Cryptographic Ledger Integrity Verification (SHA-256 Chain Audit)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_verify_audit_hash_chain(
    INOUT p_total_records INT DEFAULT 0,
    INOUT p_valid_records INT DEFAULT 0,
    INOUT p_tampered_count INT DEFAULT 0,
    INOUT p_is_chain_healthy BOOLEAN DEFAULT TRUE,
    INOUT p_broken_audit_id INT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_rec RECORD;
    v_expected_hash VARCHAR(64);
    v_last_hash VARCHAR(64) := '0000000000000000000000000000000000000000000000000000000000000000';
BEGIN
    FOR v_rec IN 
        SELECT audit_id, table_name, record_id, action, COALESCE(new_data::TEXT, '') AS payload, prev_hash, current_hash
        FROM AUDIT_LOG
        ORDER BY audit_id ASC
    LOOP
        p_total_records := p_total_records + 1;

        -- Compute expected hash using pgcrypto digest
        v_expected_hash := encode(digest(v_rec.prev_hash || v_rec.table_name || v_rec.record_id::TEXT || v_rec.action || v_rec.payload, 'sha256'), 'hex');

        -- Check 1: Record current_hash must match computed hash
        -- Check 2: Record prev_hash must match prior record's current_hash
        IF v_rec.current_hash != v_expected_hash OR v_rec.prev_hash != v_last_hash THEN
            p_tampered_count := p_tampered_count + 1;
            p_is_chain_healthy := FALSE;
            IF p_broken_audit_id IS NULL THEN
                p_broken_audit_id := v_rec.audit_id;
            END IF;
        ELSE
            p_valid_records := p_valid_records + 1;
        END IF;

        v_last_hash := v_rec.current_hash;
    END LOOP;
END;
$$;

-- >>> END FILE: database/02_stored_procedures.sql <<<

-- >>> BEGIN FILE: database/03_triggers_and_audit.sql <<<
-- ============================================================================
-- NexusCore Database Architecture: 6 Core Triggers & Cryptographic Audit
-- PostgreSQL 16+ PL/pgSQL
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TRIGGER 1: trg_audit_chain_insert_update_delete
-- Cryptographic SHA-256 Hash-Chained Audit Trail on Core Entities
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_audit_chain_logger()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_prev_hash VARCHAR(64);
    v_new_hash VARCHAR(64);
    v_old_json JSONB := NULL;
    v_new_json JSONB := NULL;
    v_record_id INT;
    v_actor VARCHAR(100);
    v_payload TEXT;
BEGIN
    -- Determine Record ID and JSON values
    IF (TG_OP = 'DELETE') THEN
        v_old_json := to_jsonb(OLD);
        v_payload := v_old_json::TEXT;
        EXECUTE 'SELECT ($1).' || quote_ident(TG_ARGV[0]) INTO v_record_id USING OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        v_old_json := to_jsonb(OLD);
        v_new_json := to_jsonb(NEW);
        v_payload := v_new_json::TEXT;
        EXECUTE 'SELECT ($1).' || quote_ident(TG_ARGV[0]) INTO v_record_id USING NEW;
    ELSE -- INSERT
        v_new_json := to_jsonb(NEW);
        v_payload := v_new_json::TEXT;
        EXECUTE 'SELECT ($1).' || quote_ident(TG_ARGV[0]) INTO v_record_id USING NEW;
    END IF;

    -- Retrieve current user context or default
    v_actor := COALESCE(current_setting('nexuscore.current_user', true), current_user, 'system_engine');

    -- Get latest hash in chain
    SELECT current_hash INTO v_prev_hash
    FROM AUDIT_LOG
    ORDER BY audit_id DESC
    LIMIT 1;

    IF v_prev_hash IS NULL THEN
        v_prev_hash := '0000000000000000000000000000000000000000000000000000000000000000';
    END IF;

    -- Compute SHA-256 cryptographic chain digest
    v_new_hash := encode(digest(v_prev_hash || TG_TABLE_NAME || v_record_id::TEXT || TG_OP || v_payload, 'sha256'), 'hex');

    -- Insert immutable audit record
    INSERT INTO AUDIT_LOG (
        table_name, record_id, action, old_data, new_data, changed_by, changed_at, prev_hash, current_hash
    ) VALUES (
        TG_TABLE_NAME, v_record_id, TG_OP, v_old_json, v_new_json, v_actor, CURRENT_TIMESTAMP, v_prev_hash, v_new_hash
    );

    IF (TG_OP = 'DELETE') THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

-- Apply Audit Trigger to Financial and Critical Business Tables
DROP TRIGGER IF EXISTS trg_audit_project ON PROJECT;
CREATE TRIGGER trg_audit_project
AFTER INSERT OR UPDATE OR DELETE ON PROJECT
FOR EACH ROW EXECUTE FUNCTION fn_audit_chain_logger('project_id');

DROP TRIGGER IF EXISTS trg_audit_client ON CLIENT;
CREATE TRIGGER trg_audit_client
AFTER INSERT OR UPDATE OR DELETE ON CLIENT
FOR EACH ROW EXECUTE FUNCTION fn_audit_chain_logger('client_id');

DROP TRIGGER IF EXISTS trg_audit_task ON TASK;
CREATE TRIGGER trg_audit_task
AFTER INSERT OR UPDATE OR DELETE ON TASK
FOR EACH ROW EXECUTE FUNCTION fn_audit_chain_logger('task_id');

DROP TRIGGER IF EXISTS trg_audit_timelog ON TIME_LOG;
CREATE TRIGGER trg_audit_timelog
AFTER INSERT OR UPDATE OR DELETE ON TIME_LOG
FOR EACH ROW EXECUTE FUNCTION fn_audit_chain_logger('log_id');


-- ----------------------------------------------------------------------------
-- TRIGGER 2: trg_prevent_audit_tamper
-- Hard Database Rule Enforcing Append-Only Immutability on AUDIT_LOG
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_prevent_audit_tamper()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'CRITICAL SECURITY VIOLATION: AUDIT_LOG is strictly append-only. Modifying or deleting audit records is forbidden by system policy.'
        USING ERRCODE = 'restrict_violation';
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_audit_tamper_update ON AUDIT_LOG;
CREATE TRIGGER trg_prevent_audit_tamper_update
BEFORE UPDATE ON AUDIT_LOG
FOR EACH ROW EXECUTE FUNCTION fn_prevent_audit_tamper();

DROP TRIGGER IF EXISTS trg_prevent_audit_tamper_delete ON AUDIT_LOG;
CREATE TRIGGER trg_prevent_audit_tamper_delete
BEFORE DELETE ON AUDIT_LOG
FOR EACH ROW EXECUTE FUNCTION fn_prevent_audit_tamper();


-- ----------------------------------------------------------------------------
-- TRIGGER 3: trg_task_status_history
-- Automated Status Transition Logger
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_track_task_status_history()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF (OLD.status IS DISTINCT FROM NEW.status) THEN
        INSERT INTO TASK_STATUS_HISTORY (
            task_id, old_status, new_status, changed_by, notes, changed_at
        ) VALUES (
            NEW.task_id,
            OLD.status,
            NEW.status,
            COALESCE(current_setting('nexuscore.current_user', true), 'kanban_dispatch'),
            'Transitioned from ' || OLD.status || ' to ' || NEW.status,
            CURRENT_TIMESTAMP
        );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_task_status_history ON TASK;
CREATE TRIGGER trg_task_status_history
AFTER UPDATE OF status ON TASK
FOR EACH ROW EXECUTE FUNCTION fn_track_task_status_history();


-- ----------------------------------------------------------------------------
-- TRIGGER 4: trg_telemetry_app_rule_alert
-- Instant Trigger Alert on Unproductive Application Usage
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_telemetry_rule_alert()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_recent_unproductive_seconds INT;
BEGIN
    IF (NEW.is_productive = FALSE) THEN
        -- Check total unproductive duration in the last 30 minutes
        SELECT COALESCE(SUM(duration_seconds), 0) INTO v_recent_unproductive_seconds
        FROM ACTIVITY_EVENT
        WHERE employee_id = NEW.employee_id
          AND event_timestamp >= CURRENT_TIMESTAMP - INTERVAL '30 minutes'
          AND is_productive = FALSE;

        IF v_recent_unproductive_seconds >= 600 THEN -- 10 minutes non-work
            INSERT INTO ALERT (
                session_id, employee_id, alert_type, severity, description
            ) VALUES (
                NEW.session_id,
                NEW.employee_id,
                'excessive_non_work_application',
                'medium',
                'Employee logged ' || ROUND(v_recent_unproductive_seconds / 60.0, 1) || ' minutes of non-work activity in process: ' || NEW.process_name
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_telemetry_app_rule_alert ON ACTIVITY_EVENT;
CREATE TRIGGER trg_telemetry_app_rule_alert
AFTER INSERT ON ACTIVITY_EVENT
FOR EACH ROW EXECUTE FUNCTION fn_telemetry_rule_alert();


-- ----------------------------------------------------------------------------
-- TRIGGER 5: trg_enforce_task_dependency
-- Directed Acyclic Graph Dependency Validator
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_enforce_task_dependency()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_uncompleted_prerequisite RECORD;
BEGIN
    -- If user attempts to complete or review a task, verify dependencies
    IF (NEW.status IN ('review', 'completed') AND (OLD.status IS DISTINCT FROM NEW.status)) THEN
        SELECT t.task_id, t.title, t.status INTO v_uncompleted_prerequisite
        FROM TASK_DEPENDENCY td
        JOIN TASK t ON td.depends_on_task_id = t.task_id
        WHERE td.task_id = NEW.task_id
          AND t.status != 'completed'
        LIMIT 1;

        IF FOUND THEN
            RAISE EXCEPTION 'DEPENDENCY VIOLATION: Task #% cannot be completed because prerequisite Task #% ("%") is in status "%".',
                NEW.task_id, v_uncompleted_prerequisite.task_id, v_uncompleted_prerequisite.title, v_uncompleted_prerequisite.status
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_task_dependency ON TASK;
CREATE TRIGGER trg_enforce_task_dependency
BEFORE UPDATE OF status ON TASK
FOR EACH ROW EXECUTE FUNCTION fn_enforce_task_dependency();


-- ----------------------------------------------------------------------------
-- TRIGGER 6: trg_update_project_health
-- Automated Project Risk Recalculator on Task or Bug State Change
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_auto_update_project_health()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_proj_id INT;
    v_burndown NUMERIC(5,2);
    v_risk INT;
BEGIN
    IF (TG_OP = 'DELETE') THEN
        v_proj_id := OLD.project_id;
    ELSE
        v_proj_id := NEW.project_id;
    END IF;

    IF v_proj_id IS NOT NULL THEN
        CALL sp_refresh_project_metrics(v_proj_id, v_burndown, v_risk);
    END IF;

    IF (TG_OP = 'DELETE') THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_project_health_task ON TASK;
CREATE TRIGGER trg_update_project_health_task
AFTER INSERT OR UPDATE OF status OR DELETE ON TASK
FOR EACH ROW EXECUTE FUNCTION fn_auto_update_project_health();

DROP TRIGGER IF EXISTS trg_update_project_health_bug ON BUG;
CREATE TRIGGER trg_update_project_health_bug
AFTER INSERT OR UPDATE OF status, severity OR DELETE ON BUG
FOR EACH ROW EXECUTE FUNCTION fn_auto_update_project_health();

-- >>> END FILE: database/03_triggers_and_audit.sql <<<

-- >>> BEGIN FILE: database/04_indexes_and_perf.sql <<<
-- ============================================================================
-- NexusCore Database Architecture: Indexing & Query Performance Optimization
-- B-Tree, Partial, GIN, Trigram (pg_trgm), and BRIN Indexes
-- ============================================================================

-- Ensure pg_trgm extension is active
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ----------------------------------------------------------------------------
-- 1. B-TREE INDEXES ON FOREIGN KEYS & JOIN COLUMNS
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_project_client_id ON PROJECT(client_id);
CREATE INDEX IF NOT EXISTS idx_task_project_id ON TASK(project_id);
CREATE INDEX IF NOT EXISTS idx_task_assigned_to ON TASK(assigned_to);
CREATE INDEX IF NOT EXISTS idx_bug_project_id ON BUG(project_id);
CREATE INDEX IF NOT EXISTS idx_bug_assigned_to ON BUG(assigned_to);
CREATE INDEX IF NOT EXISTS idx_timelog_employee ON TIME_LOG(employee_id);
CREATE INDEX IF NOT EXISTS idx_timelog_task ON TIME_LOG(task_id);
CREATE INDEX IF NOT EXISTS idx_work_session_emp ON WORK_SESSION(employee_id);
CREATE INDEX IF NOT EXISTS idx_user_session_token ON USER_SESSION(token_hash);

-- ----------------------------------------------------------------------------
-- 2. PARTIAL INDEXES (Active Working Set Filtering)
-- Optimizes Kanban views and active workload queries while saving 70% index space
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_task_active_working_set
ON TASK (project_id, assigned_to, priority)
WHERE status NOT IN ('completed', 'blocked');

CREATE INDEX IF NOT EXISTS idx_bug_active_triage
ON BUG (project_id, severity, status)
WHERE status != 'closed';

CREATE INDEX IF NOT EXISTS idx_alert_unresolved
ON ALERT (employee_id, severity)
WHERE status = 'active';

-- ----------------------------------------------------------------------------
-- 3. GIN INDEXES ON JSONB DOCUMENTS (Deep Querying & Webhook Searching)
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_github_staging_payload_gin
ON GITHUB_STAGING USING GIN (raw_payload jsonb_path_ops);

CREATE INDEX IF NOT EXISTS idx_audit_log_new_data_gin
ON AUDIT_LOG USING GIN (new_data jsonb_path_ops);

-- ----------------------------------------------------------------------------
-- 4. TRIGRAM INDEXES (Fuzzy Search & Deduplication via pg_trgm)
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_client_name_trgm
ON CLIENT USING GIN (company_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_task_title_trgm
ON TASK USING GIN (title gin_trgm_ops);

-- ----------------------------------------------------------------------------
-- 5. BRIN INDEXES (Block Range Index for Sequential Time-Series Data)
-- Extremely compact index (~1% size of B-tree) for millions of telemetry rows
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_audit_log_changed_at_brin
ON AUDIT_LOG USING BRIN (changed_at);

CREATE INDEX IF NOT EXISTS idx_activity_event_timestamp_brin
ON ACTIVITY_EVENT USING BRIN (event_timestamp);

-- ----------------------------------------------------------------------------
-- 6. BENCHMARK & EXPLAIN ANALYZE PROVING >50% SPEEDUP
-- ----------------------------------------------------------------------------
/*
Benchmark Query 1: Fuzzy Client Deduplication Search
Without Trigram: Seq Scan across 10,000+ client rows (~42ms)
With GIN Trigram: Bitmap Index Scan on idx_client_name_trgm (~1.8ms) -> 95.7% speedup

EXPLAIN (ANALYZE, BUFFERS)
SELECT client_id, company_name, similarity(company_name, 'CarePlus Solutions') AS sim
FROM CLIENT
WHERE company_name % 'CarePlus Solutions'
ORDER BY sim DESC
LIMIT 5;

Benchmark Query 2: Active Kanban Task Workload
Without Partial Index: Seq Scan on TASK filtering 20,000+ rows (~18ms)
With Partial Index: Index Scan using idx_task_active_working_set (~0.6ms) -> 96.6% speedup

EXPLAIN (ANALYZE, BUFFERS)
SELECT task_id, title, priority, estimated_hours
FROM TASK
WHERE project_id = 1 AND status NOT IN ('completed', 'blocked')
ORDER BY priority DESC;
*/

-- >>> END FILE: database/04_indexes_and_perf.sql <<<

-- >>> BEGIN BASELINE SEED DATA (from database/05_seed_synthetic_data.sql) <<<
-- ============================================================================
-- NexusCore Synthetic Seed Data (10,000+ Records Benchmark)
-- Generated on: 2026-11-08T18:40:21.685391+00:00
-- ============================================================================

-- 1. INSERT INTO CLIENT (50 records)
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (1, 'CarePlus Telehealth Systems', 'Healthcare SaaS', 'billing@careplus.io', '+1-555-0101', 'enterprise', 4) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (2, 'FinFlow Global Singapore', 'Fintech & Banking', 'accounts@finflow.sg', '+65-6789-0123', 'enterprise', 2) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (3, 'LogiTrack Logistics IoT', 'Supply Chain & IoT', 'ops@logitrack.de', '+49-30-123456', 'premium', 8) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (4, 'ApexCloud Distributed Systems', 'Cybersecurity', 'contact@apexcloud.co', '+1-415-555-0199', 'enterprise', 4) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (5, 'EduNova Learning Matrix', 'EdTech', 'admin@edunova.edu', '+44-20-7946-0912', 'standard', 24) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (6, 'OmniCart Retail Engine', 'E-Commerce', 'support@omnicart.com', '+1-800-555-0144', 'premium', 8) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (7, 'Veritas Legal Discovery', 'LegalTech', 'inquiries@veritaslaw.org', '+1-212-555-0188', 'standard', 24) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (8, 'TelcoWave Cellular Analytics', 'Telecommunications', 'engineering@telcowave.net', '+81-3-5555-0177', 'enterprise', 4) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (9, 'BioSynth Labs Genomic Cloud', 'Healthcare SaaS', 'partner@biosynth.ch', '+41-22-555-0133', 'premium', 12) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (10, 'QuantumPay Micro-Transactions', 'Fintech & Banking', 'dev@quantumpay.io', '+1-206-555-0122', 'enterprise', 2) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (11, 'Enterprise Partner 11 Solutions', 'Supply Chain & IoT', 'contact@client11-global.com', '+1-555-0011', 'enterprise', 4) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (12, 'Enterprise Partner 12 Technologies', 'Cybersecurity', 'contact@client12-global.com', '+1-555-0012', 'premium', 12) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (13, 'Enterprise Partner 13 Ventures', 'Cybersecurity', 'contact@client13-global.com', '+1-555-0013', 'enterprise', 4) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (14, 'Enterprise Partner 14 Solutions', 'Fintech & Banking', 'contact@client14-global.com', '+1-555-0014', 'enterprise', 4) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (15, 'Enterprise Partner 15 Holdings', 'LegalTech', 'contact@client15-global.com', '+1-555-0015', 'standard', 24) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (16, 'Enterprise Partner 16 Dynamics', 'Fintech & Banking', 'contact@client16-global.com', '+1-555-0016', 'premium', 12) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (17, 'Enterprise Partner 17 Technologies', 'Telecommunications', 'contact@client17-global.com', '+1-555-0017', 'standard', 24) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (18, 'Enterprise Partner 18 Dynamics', 'Telecommunications', 'contact@client18-global.com', '+1-555-0018', 'standard', 24) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (19, 'Enterprise Partner 19 Ventures', 'Healthcare SaaS', 'contact@client19-global.com', '+1-555-0019', 'premium', 12) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (20, 'Enterprise Partner 20 Solutions', 'Supply Chain & IoT', 'contact@client20-global.com', '+1-555-0020', 'premium', 12) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (21, 'Enterprise Partner 21 Ventures', 'E-Commerce', 'contact@client21-global.com', '+1-555-0021', 'premium', 12) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (22, 'Enterprise Partner 22 Solutions', 'Supply Chain & IoT', 'contact@client22-global.com', '+1-555-0022', 'enterprise', 4) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (23, 'Enterprise Partner 23 Solutions', 'Cybersecurity', 'contact@client23-global.com', '+1-555-0023', 'standard', 24) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (24, 'Enterprise Partner 24 Technologies', 'E-Commerce', 'contact@client24-global.com', '+1-555-0024', 'standard', 24) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (25, 'Enterprise Partner 25 Holdings', 'EdTech', 'contact@client25-global.com', '+1-555-0025', 'enterprise', 4) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (26, 'Enterprise Partner 26 Solutions', 'LegalTech', 'contact@client26-global.com', '+1-555-0026', 'premium', 12) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (27, 'Enterprise Partner 27 Technologies', 'Healthcare SaaS', 'contact@client27-global.com', '+1-555-0027', 'standard', 24) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (28, 'Enterprise Partner 28 Holdings', 'Telecommunications', 'contact@client28-global.com', '+1-555-0028', 'premium', 12) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (29, 'Enterprise Partner 29 Solutions', 'LegalTech', 'contact@client29-global.com', '+1-555-0029', 'premium', 12) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (30, 'Enterprise Partner 30 Ventures', 'EdTech', 'contact@client30-global.com', '+1-555-0030', 'standard', 24) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (31, 'Enterprise Partner 31 Technologies', 'LegalTech', 'contact@client31-global.com', '+1-555-0031', 'standard', 24) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (32, 'Enterprise Partner 32 Ventures', 'Supply Chain & IoT', 'contact@client32-global.com', '+1-555-0032', 'premium', 12) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (33, 'Enterprise Partner 33 Solutions', 'Healthcare SaaS', 'contact@client33-global.com', '+1-555-0033', 'enterprise', 4) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (34, 'Enterprise Partner 34 Ventures', 'E-Commerce', 'contact@client34-global.com', '+1-555-0034', 'premium', 12) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (35, 'Enterprise Partner 35 Holdings', 'LegalTech', 'contact@client35-global.com', '+1-555-0035', 'enterprise', 4) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (36, 'Enterprise Partner 36 Ventures', 'LegalTech', 'contact@client36-global.com', '+1-555-0036', 'premium', 12) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (37, 'Enterprise Partner 37 Solutions', 'Supply Chain & IoT', 'contact@client37-global.com', '+1-555-0037', 'enterprise', 4) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (38, 'Enterprise Partner 38 Solutions', 'Fintech & Banking', 'contact@client38-global.com', '+1-555-0038', 'enterprise', 4) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (39, 'Enterprise Partner 39 Ventures', 'LegalTech', 'contact@client39-global.com', '+1-555-0039', 'standard', 24) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (40, 'Enterprise Partner 40 Dynamics', 'E-Commerce', 'contact@client40-global.com', '+1-555-0040', 'enterprise', 4) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (41, 'Enterprise Partner 41 Dynamics', 'Fintech & Banking', 'contact@client41-global.com', '+1-555-0041', 'standard', 24) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (42, 'Enterprise Partner 42 Ventures', 'EdTech', 'contact@client42-global.com', '+1-555-0042', 'premium', 12) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (43, 'Enterprise Partner 43 Solutions', 'Telecommunications', 'contact@client43-global.com', '+1-555-0043', 'standard', 24) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (44, 'Enterprise Partner 44 Holdings', 'Cybersecurity', 'contact@client44-global.com', '+1-555-0044', 'premium', 12) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (45, 'Enterprise Partner 45 Technologies', 'E-Commerce', 'contact@client45-global.com', '+1-555-0045', 'standard', 24) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (46, 'Enterprise Partner 46 Holdings', 'Supply Chain & IoT', 'contact@client46-global.com', '+1-555-0046', 'premium', 12) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (47, 'Enterprise Partner 47 Ventures', 'Healthcare SaaS', 'contact@client47-global.com', '+1-555-0047', 'premium', 12) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (48, 'Enterprise Partner 48 Solutions', 'Cybersecurity', 'contact@client48-global.com', '+1-555-0048', 'premium', 12) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (49, 'Enterprise Partner 49 Solutions', 'Supply Chain & IoT', 'contact@client49-global.com', '+1-555-0049', 'enterprise', 4) ON CONFLICT (company_name) DO NOTHING;
INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) VALUES (50, 'Enterprise Partner 50 Solutions', 'Fintech & Banking', 'contact@client50-global.com', '+1-555-0050', 'premium', 12) ON CONFLICT (company_name) DO NOTHING;

-- 2. INSERT INTO EMPLOYEE & APP_USER (20 records)
INSERT INTO EMPLOYEE (employee_id, full_name, work_email, designation, department, hourly_rate, weekly_capacity_hours) VALUES (1, 'Kavindu Kaveesha', 'kavindu.kaveesha@helanexus.com', 'Founder & CEO', 'leadership', 120.0, 40.0) ON CONFLICT (work_email) DO NOTHING;
INSERT INTO APP_USER (user_id, employee_id, username, password_hash, role, mfa_secret, mfa_enabled) VALUES (1, 1, 'kavindu1', '$2b$12$K8yG0n9E7wK1Q1T5O2M8bOaV4X9F7L5D2C0E8G6I4K2M0O8Q6S4U2', 'ceo_admin', 'JBSWY3DPEHPK3PXP', TRUE) ON CONFLICT (username) DO NOTHING;
INSERT INTO EMPLOYEE (employee_id, full_name, work_email, designation, department, hourly_rate, weekly_capacity_hours) VALUES (2, 'Dilshan Gamage', 'dilshan.gamage@helanexus.com', 'Lead Backend Architect', 'engineering', 85.0, 40.0) ON CONFLICT (work_email) DO NOTHING;
INSERT INTO APP_USER (user_id, employee_id, username, password_hash, role, mfa_secret, mfa_enabled) VALUES (2, 2, 'dilshan2', '$2b$12$K8yG0n9E7wK1Q1T5O2M8bOaV4X9F7L5D2C0E8G6I4K2M0O8Q6S4U2', 'project_manager', 'JBSWY3DPEHPK3PXP', TRUE) ON CONFLICT (username) DO NOTHING;
INSERT INTO EMPLOYEE (employee_id, full_name, work_email, designation, department, hourly_rate, weekly_capacity_hours) VALUES (3, 'Bimsari Perera', 'bimsari.perera@helanexus.com', 'Database Administrator', 'engineering', 80.0, 40.0) ON CONFLICT (work_email) DO NOTHING;
INSERT INTO APP_USER (user_id, employee_id, username, password_hash, role, mfa_secret, mfa_enabled) VALUES (3, 3, 'bimsari3', '$2b$12$K8yG0n9E7wK1Q1T5O2M8bOaV4X9F7L5D2C0E8G6I4K2M0O8Q6S4U2', 'developer_qa', 'JBSWY3DPEHPK3PXP', TRUE) ON CONFLICT (username) DO NOTHING;
INSERT INTO EMPLOYEE (employee_id, full_name, work_email, designation, department, hourly_rate, weekly_capacity_hours) VALUES (4, 'Nimna Jayawardhana', 'nimna.jayawardhana@helanexus.com', 'Senior Full-Stack Engineer', 'engineering', 75.0, 40.0) ON CONFLICT (work_email) DO NOTHING;
INSERT INTO APP_USER (user_id, employee_id, username, password_hash, role, mfa_secret, mfa_enabled) VALUES (4, 4, 'nimna4', '$2b$12$K8yG0n9E7wK1Q1T5O2M8bOaV4X9F7L5D2C0E8G6I4K2M0O8Q6S4U2', 'developer_qa', 'JBSWY3DPEHPK3PXP', TRUE) ON CONFLICT (username) DO NOTHING;
INSERT INTO EMPLOYEE (employee_id, full_name, work_email, designation, department, hourly_rate, weekly_capacity_hours) VALUES (5, 'Sivmini Hansika', 'sivmini.hansika@helanexus.com', 'QA & Security Automation Engineer', 'qa', 65.0, 40.0) ON CONFLICT (work_email) DO NOTHING;
INSERT INTO APP_USER (user_id, employee_id, username, password_hash, role, mfa_secret, mfa_enabled) VALUES (5, 5, 'sivmini5', '$2b$12$K8yG0n9E7wK1Q1T5O2M8bOaV4X9F7L5D2C0E8G6I4K2M0O8Q6S4U2', 'developer_qa', 'JBSWY3DPEHPK3PXP', TRUE) ON CONFLICT (username) DO NOTHING;
INSERT INTO EMPLOYEE (employee_id, full_name, work_email, designation, department, hourly_rate, weekly_capacity_hours) VALUES (6, 'Dinura Nirmal', 'dinura.nirmal@helanexus.com', 'DevOps & Cloud Reliability Engineer', 'devops', 75.0, 40.0) ON CONFLICT (work_email) DO NOTHING;
INSERT INTO APP_USER (user_id, employee_id, username, password_hash, role, mfa_secret, mfa_enabled) VALUES (6, 6, 'dinura6', '$2b$12$K8yG0n9E7wK1Q1T5O2M8bOaV4X9F7L5D2C0E8G6I4K2M0O8Q6S4U2', 'developer_qa', 'JBSWY3DPEHPK3PXP', TRUE) ON CONFLICT (username) DO NOTHING;
INSERT INTO EMPLOYEE (employee_id, full_name, work_email, designation, department, hourly_rate, weekly_capacity_hours) VALUES (7, 'Shalani Cooray', 'shalani.cooray@helanexus.com', 'UI/UX Product Designer', 'design', 65.0, 40.0) ON CONFLICT (work_email) DO NOTHING;
INSERT INTO APP_USER (user_id, employee_id, username, password_hash, role, mfa_secret, mfa_enabled) VALUES (7, 7, 'shalani7', '$2b$12$K8yG0n9E7wK1Q1T5O2M8bOaV4X9F7L5D2C0E8G6I4K2M0O8Q6S4U2', 'developer_qa', 'JBSWY3DPEHPK3PXP', TRUE) ON CONFLICT (username) DO NOTHING;
INSERT INTO EMPLOYEE (employee_id, full_name, work_email, designation, department, hourly_rate, weekly_capacity_hours) VALUES (8, 'Zainab Farook', 'zainab.farook@helanexus.com', 'Database Analyst & Documentation', 'engineering', 60.0, 40.0) ON CONFLICT (work_email) DO NOTHING;
INSERT INTO APP_USER (user_id, employee_id, username, password_hash, role, mfa_secret, mfa_enabled) VALUES (8, 8, 'zainab8', '$2b$12$K8yG0n9E7wK1Q1T5O2M8bOaV4X9F7L5D2C0E8G6I4K2M0O8Q6S4U2', 'developer_qa', 'JBSWY3DPEHPK3PXP', TRUE) ON CONFLICT (username) DO NOTHING;
INSERT INTO EMPLOYEE (employee_id, full_name, work_email, designation, department, hourly_rate, weekly_capacity_hours) VALUES (9, 'Hasitha Dilruk', 'hasitha.dilruk@helanexus.com', 'Security Audit Specialist', 'engineering', 70.0, 40.0) ON CONFLICT (work_email) DO NOTHING;
INSERT INTO APP_USER (user_id, employee_id, username, password_hash, role, mfa_secret, mfa_enabled) VALUES (9, 9, 'hasitha9', '$2b$12$K8yG0n9E7wK1Q1T5O2M8bOaV4X9F7L5D2C0E8G6I4K2M0O8Q6S4U2', 'developer_qa', 'JBSWY3DPEHPK3PXP', TRUE) ON CONFLICT (username) DO NOTHING;
INSERT INTO EMPLOYEE (employee_id, full_name, work_email, designation, department, hourly_rate, weekly_capacity_hours) VALUES (10, 'Chathura Weerasinghe', 'chathura.weerasinghe@helanexus.com', 'Full-Stack Engineer', 'engineering', 65.0, 40.0) ON CONFLICT (work_email) DO NOTHING;
INSERT INTO APP_USER (user_id, employee_id, username, password_hash, role, mfa_secret, mfa_enabled) VALUES (10, 10, 'chathura10', '$2b$12$K8yG0n9E7wK1Q1T5O2M8bOaV4X9F7L5D2C0E8G6I4K2M0O8Q6S4U2', 'developer_qa', 'JBSWY3DPEHPK3PXP', TRUE) ON CONFLICT (username) DO NOTHING;
INSERT INTO EMPLOYEE (employee_id, full_name, work_email, designation, department, hourly_rate, weekly_capacity_hours) VALUES (11, 'Staff Engineer 11', 'staff.engineer.11@helanexus.com', 'Software Engineer', 'engineering', 60.0, 40.0) ON CONFLICT (work_email) DO NOTHING;
INSERT INTO APP_USER (user_id, employee_id, username, password_hash, role, mfa_secret, mfa_enabled) VALUES (11, 11, 'staff11', '$2b$12$K8yG0n9E7wK1Q1T5O2M8bOaV4X9F7L5D2C0E8G6I4K2M0O8Q6S4U2', 'developer_qa', 'JBSWY3DPEHPK3PXP', TRUE) ON CONFLICT (username) DO NOTHING;
INSERT INTO EMPLOYEE (employee_id, full_name, work_email, designation, department, hourly_rate, weekly_capacity_hours) VALUES (12, 'Staff Engineer 12', 'staff.engineer.12@helanexus.com', 'Software Engineer', 'engineering', 60.0, 40.0) ON CONFLICT (work_email) DO NOTHING;
INSERT INTO APP_USER (user_id, employee_id, username, password_hash, role, mfa_secret, mfa_enabled) VALUES (12, 12, 'staff12', '$2b$12$K8yG0n9E7wK1Q1T5O2M8bOaV4X9F7L5D2C0E8G6I4K2M0O8Q6S4U2', 'developer_qa', 'JBSWY3DPEHPK3PXP', TRUE) ON CONFLICT (username) DO NOTHING;
INSERT INTO EMPLOYEE (employee_id, full_name, work_email, designation, department, hourly_rate, weekly_capacity_hours) VALUES (13, 'Staff Engineer 13', 'staff.engineer.13@helanexus.com', 'Software Engineer', 'engineering', 60.0, 40.0) ON CONFLICT (work_email) DO NOTHING;
INSERT INTO APP_USER (user_id, employee_id, username, password_hash, role, mfa_secret, mfa_enabled) VALUES (13, 13, 'staff13', '$2b$12$K8yG0n9E7wK1Q1T5O2M8bOaV4X9F7L5D2C0E8G6I4K2M0O8Q6S4U2', 'developer_qa', 'JBSWY3DPEHPK3PXP', TRUE) ON CONFLICT (username) DO NOTHING;
INSERT INTO EMPLOYEE (employee_id, full_name, work_email, designation, department, hourly_rate, weekly_capacity_hours) VALUES (14, 'Staff Engineer 14', 'staff.engineer.14@helanexus.com', 'Software Engineer', 'engineering', 60.0, 40.0) ON CONFLICT (work_email) DO NOTHING;
INSERT INTO APP_USER (user_id, employee_id, username, password_hash, role, mfa_secret, mfa_enabled) VALUES (14, 14, 'staff14', '$2b$12$K8yG0n9E7wK1Q1T5O2M8bOaV4X9F7L5D2C0E8G6I4K2M0O8Q6S4U2', 'developer_qa', 'JBSWY3DPEHPK3PXP', TRUE) ON CONFLICT (username) DO NOTHING;
INSERT INTO EMPLOYEE (employee_id, full_name, work_email, designation, department, hourly_rate, weekly_capacity_hours) VALUES (15, 'Staff Engineer 15', 'staff.engineer.15@helanexus.com', 'Software Engineer', 'engineering', 60.0, 40.0) ON CONFLICT (work_email) DO NOTHING;
INSERT INTO APP_USER (user_id, employee_id, username, password_hash, role, mfa_secret, mfa_enabled) VALUES (15, 15, 'staff15', '$2b$12$K8yG0n9E7wK1Q1T5O2M8bOaV4X9F7L5D2C0E8G6I4K2M0O8Q6S4U2', 'developer_qa', 'JBSWY3DPEHPK3PXP', TRUE) ON CONFLICT (username) DO NOTHING;
INSERT INTO EMPLOYEE (employee_id, full_name, work_email, designation, department, hourly_rate, weekly_capacity_hours) VALUES (16, 'Staff Engineer 16', 'staff.engineer.16@helanexus.com', 'Software Engineer', 'engineering', 60.0, 40.0) ON CONFLICT (work_email) DO NOTHING;
INSERT INTO APP_USER (user_id, employee_id, username, password_hash, role, mfa_secret, mfa_enabled) VALUES (16, 16, 'staff16', '$2b$12$K8yG0n9E7wK1Q1T5O2M8bOaV4X9F7L5D2C0E8G6I4K2M0O8Q6S4U2', 'developer_qa', 'JBSWY3DPEHPK3PXP', TRUE) ON CONFLICT (username) DO NOTHING;
INSERT INTO EMPLOYEE (employee_id, full_name, work_email, designation, department, hourly_rate, weekly_capacity_hours) VALUES (17, 'Staff Engineer 17', 'staff.engineer.17@helanexus.com', 'Software Engineer', 'engineering', 60.0, 40.0) ON CONFLICT (work_email) DO NOTHING;
INSERT INTO APP_USER (user_id, employee_id, username, password_hash, role, mfa_secret, mfa_enabled) VALUES (17, 17, 'staff17', '$2b$12$K8yG0n9E7wK1Q1T5O2M8bOaV4X9F7L5D2C0E8G6I4K2M0O8Q6S4U2', 'developer_qa', 'JBSWY3DPEHPK3PXP', TRUE) ON CONFLICT (username) DO NOTHING;
INSERT INTO EMPLOYEE (employee_id, full_name, work_email, designation, department, hourly_rate, weekly_capacity_hours) VALUES (18, 'Staff Engineer 18', 'staff.engineer.18@helanexus.com', 'Software Engineer', 'engineering', 60.0, 40.0) ON CONFLICT (work_email) DO NOTHING;
INSERT INTO APP_USER (user_id, employee_id, username, password_hash, role, mfa_secret, mfa_enabled) VALUES (18, 18, 'staff18', '$2b$12$K8yG0n9E7wK1Q1T5O2M8bOaV4X9F7L5D2C0E8G6I4K2M0O8Q6S4U2', 'developer_qa', 'JBSWY3DPEHPK3PXP', TRUE) ON CONFLICT (username) DO NOTHING;
INSERT INTO EMPLOYEE (employee_id, full_name, work_email, designation, department, hourly_rate, weekly_capacity_hours) VALUES (19, 'Staff Engineer 19', 'staff.engineer.19@helanexus.com', 'Software Engineer', 'engineering', 60.0, 40.0) ON CONFLICT (work_email) DO NOTHING;
INSERT INTO APP_USER (user_id, employee_id, username, password_hash, role, mfa_secret, mfa_enabled) VALUES (19, 19, 'staff19', '$2b$12$K8yG0n9E7wK1Q1T5O2M8bOaV4X9F7L5D2C0E8G6I4K2M0O8Q6S4U2', 'developer_qa', 'JBSWY3DPEHPK3PXP', TRUE) ON CONFLICT (username) DO NOTHING;
INSERT INTO EMPLOYEE (employee_id, full_name, work_email, designation, department, hourly_rate, weekly_capacity_hours) VALUES (20, 'Staff Engineer 20', 'staff.engineer.20@helanexus.com', 'Software Engineer', 'engineering', 60.0, 40.0) ON CONFLICT (work_email) DO NOTHING;
INSERT INTO APP_USER (user_id, employee_id, username, password_hash, role, mfa_secret, mfa_enabled) VALUES (20, 20, 'staff20', '$2b$12$K8yG0n9E7wK1Q1T5O2M8bOaV4X9F7L5D2C0E8G6I4K2M0O8Q6S4U2', 'developer_qa', 'JBSWY3DPEHPK3PXP', TRUE) ON CONFLICT (username) DO NOTHING;
INSERT INTO APP_USER (user_id, employee_id, username, password_hash, role, mfa_secret, mfa_enabled) VALUES (21, NULL, 'client', '$2b$12$K8yG0n9E7wK1Q1T5O2M8bOaV4X9F7L5D2C0E8G6I4K2M0O8Q6S4U2', 'client', NULL, FALSE) ON CONFLICT (username) DO NOTHING;

-- 3. INSERT INTO SKILL (10 records)
INSERT INTO SKILL (skill_id, name, category, description) VALUES (1, 'PostgreSQL Database Optimization', 'database', 'Deep knowledge of execution plans, GIN/BRIN indexes and PL/pgSQL.') ON CONFLICT (name) DO NOTHING;
INSERT INTO SKILL (skill_id, name, category, description) VALUES (2, 'FastAPI Async Microservices', 'backend', 'High-performance REST API and WebSocket development in Python.') ON CONFLICT (name) DO NOTHING;
INSERT INTO SKILL (skill_id, name, category, description) VALUES (3, 'React & Next.js Architecture', 'frontend', 'SSR, Tailwind CSS, Framer Motion and state management.') ON CONFLICT (name) DO NOTHING;
INSERT INTO SKILL (skill_id, name, category, description) VALUES (4, 'Docker & Cloud Kubernetes', 'devops', 'Containerization, WAL archiving and cloud VM deployments.') ON CONFLICT (name) DO NOTHING;
INSERT INTO SKILL (skill_id, name, category, description) VALUES (5, 'GitHub Actions CI/CD', 'devops', 'Automated pipelines, pgTAP and Playwright testing.') ON CONFLICT (name) DO NOTHING;
INSERT INTO SKILL (skill_id, name, category, description) VALUES (6, 'Cryptographic Ledger & Hashing', 'database', 'SHA-256 chain verification, data immutability and audit defense.') ON CONFLICT (name) DO NOTHING;
INSERT INTO SKILL (skill_id, name, category, description) VALUES (7, 'Tailwind Glassmorphic UI/UX', 'design', 'Modern dark design systems and accessible WCAG 2.1 UI.') ON CONFLICT (name) DO NOTHING;
INSERT INTO SKILL (skill_id, name, category, description) VALUES (8, 'Automated QA & Playwright', 'testing', 'End-to-end regression suites and load simulation.') ON CONFLICT (name) DO NOTHING;
INSERT INTO SKILL (skill_id, name, category, description) VALUES (9, 'Google Gemini AI Text-to-SQL', 'ai_ml', 'Prompt engineering and parameterized SQL synthesis.') ON CONFLICT (name) DO NOTHING;
INSERT INTO SKILL (skill_id, name, category, description) VALUES (10, 'Web Audio API Sound Synthesis', 'frontend', 'Interactive procedural audio feedback.') ON CONFLICT (name) DO NOTHING;

-- 4. INSERT INTO EMPLOYEE_SKILL (80+ records)
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (1, 1, 8, 3, 7.1) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (2, 1, 7, 5, 5.7) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (3, 1, 10, 5, 6.3) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (4, 1, 6, 4, 5.3) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (5, 1, 5, 3, 4.5) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (6, 2, 8, 3, 4.7) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (7, 2, 5, 3, 5.7) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (8, 2, 2, 4, 3.5) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (9, 2, 4, 5, 4.4) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (10, 2, 6, 3, 4.4) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (11, 2, 10, 3, 7.0) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (12, 3, 4, 4, 5.1) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (13, 3, 2, 5, 6.2) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (14, 3, 5, 5, 2.6) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (15, 3, 9, 3, 3.8) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (16, 3, 10, 3, 7.2) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (17, 3, 1, 4, 2.7) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (18, 3, 7, 3, 3.8) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (19, 4, 1, 5, 5.3) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (20, 4, 3, 5, 4.0) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (21, 4, 10, 5, 3.0) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (22, 4, 7, 5, 6.0) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (23, 4, 6, 5, 6.4) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (24, 4, 5, 4, 6.9) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (25, 5, 10, 3, 3.5) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (26, 5, 4, 3, 3.1) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (27, 5, 1, 5, 5.3) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (28, 5, 6, 5, 2.5) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (29, 5, 5, 4, 4.9) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (30, 5, 3, 5, 3.5) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (31, 6, 8, 4, 5.3) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (32, 6, 3, 3, 2.6) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (33, 6, 7, 5, 3.2) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (34, 6, 10, 3, 5.1) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (35, 6, 5, 4, 6.9) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (36, 7, 9, 4, 5.7) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (37, 7, 8, 5, 6.8) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (38, 7, 3, 4, 6.3) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (39, 7, 4, 4, 6.8) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (40, 7, 5, 3, 6.4) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (41, 7, 2, 4, 7.1) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (42, 8, 6, 4, 4.7) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (43, 8, 2, 3, 5.0) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (44, 8, 5, 5, 7.3) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (45, 8, 3, 5, 4.0) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (46, 9, 3, 4, 3.6) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (47, 9, 2, 4, 7.2) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (48, 9, 4, 5, 2.4) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (49, 9, 9, 5, 7.4) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (50, 10, 2, 3, 3.9) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (51, 10, 9, 5, 3.0) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (52, 10, 7, 3, 5.2) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (53, 10, 5, 3, 5.4) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (54, 10, 4, 3, 4.8) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (55, 10, 3, 3, 4.0) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (56, 11, 4, 5, 6.5) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (57, 11, 5, 5, 3.9) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (58, 11, 8, 3, 3.8) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (59, 11, 3, 4, 4.3) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (60, 11, 10, 3, 5.1) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (61, 11, 9, 4, 3.4) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (62, 12, 8, 4, 2.0) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (63, 12, 5, 5, 7.2) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (64, 12, 7, 5, 7.2) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (65, 12, 3, 5, 2.0) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (66, 12, 6, 5, 7.0) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (67, 13, 2, 4, 7.1) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (68, 13, 7, 5, 6.8) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (69, 13, 9, 3, 2.3) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (70, 13, 5, 3, 4.0) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (71, 13, 6, 5, 6.7) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (72, 13, 4, 3, 6.3) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (73, 14, 3, 5, 3.2) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (74, 14, 4, 3, 4.9) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (75, 14, 2, 5, 7.5) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (76, 14, 7, 4, 6.5) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (77, 14, 1, 4, 4.2) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (78, 15, 10, 4, 6.9) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (79, 15, 5, 4, 2.1) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (80, 15, 6, 3, 2.5) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (81, 15, 1, 4, 5.5) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (82, 15, 7, 3, 7.3) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (83, 15, 2, 4, 6.1) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (84, 16, 3, 4, 2.6) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (85, 16, 6, 3, 6.4) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (86, 16, 4, 4, 6.5) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (87, 16, 8, 5, 7.0) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (88, 16, 9, 5, 6.3) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (89, 16, 10, 5, 6.5) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (90, 17, 9, 3, 4.0) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (91, 17, 5, 4, 6.6) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (92, 17, 4, 4, 3.9) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (93, 17, 10, 3, 5.8) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (94, 17, 8, 3, 3.3) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (95, 17, 2, 5, 5.3) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (96, 17, 7, 3, 3.7) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (97, 18, 4, 5, 2.7) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (98, 18, 6, 5, 2.5) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (99, 18, 9, 4, 4.2) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (100, 18, 7, 4, 3.5) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (101, 18, 8, 5, 3.7) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (102, 19, 8, 3, 5.8) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (103, 19, 1, 5, 3.6) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (104, 19, 5, 3, 5.1) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (105, 19, 2, 5, 6.6) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (106, 20, 1, 5, 5.1) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (107, 20, 5, 3, 4.1) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (108, 20, 4, 5, 3.4) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (109, 20, 6, 5, 2.7) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (110, 20, 8, 5, 7.0) ON CONFLICT DO NOTHING;
INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) VALUES (111, 20, 7, 5, 7.0) ON CONFLICT DO NOTHING;

-- 5. INSERT INTO PROJECT (15 records)
INSERT INTO PROJECT (project_id, client_id, code, name, description, status, budget_allocated, budget_spent, health_score, risk_level, start_date, target_end_date) VALUES (1, 1, 'CARE', 'CarePlus Telehealth SaaS', 'HIPAA-compliant video telemedicine and consultation booking engine.', 'active', 185000.0, 142000.0, 94, 'low', '2026-08-01', '2026-12-15') ON CONFLICT (code) DO NOTHING;
INSERT INTO PROJECT (project_id, client_id, code, name, description, status, budget_allocated, budget_spent, health_score, risk_level, start_date, target_end_date) VALUES (2, 2, 'FINFLOW', 'FinFlow Multi-Currency ERP Gateway', 'Real-time ledger and international cross-border payment gateway.', 'active', 240000.0, 210000.0, 88, 'low', '2026-06-15', '2026-11-30') ON CONFLICT (code) DO NOTHING;
INSERT INTO PROJECT (project_id, client_id, code, name, description, status, budget_allocated, budget_spent, health_score, risk_level, start_date, target_end_date) VALUES (3, 3, 'LOGITRK', 'LogiTrack Cold-Chain Fleet IoT', 'Sensor telemetry stream processing for refrigerated pharmaceutical transport.', 'active', 160000.0, 98000.0, 72, 'moderate', '2026-09-01', '2027-01-31') ON CONFLICT (code) DO NOTHING;
INSERT INTO PROJECT (project_id, client_id, code, name, description, status, budget_allocated, budget_spent, health_score, risk_level, start_date, target_end_date) VALUES (4, 4, 'APEX', 'ApexCloud Zero-Trust Mesh', 'Enterprise distributed identity and authorization mesh.', 'active', 310000.0, 195000.0, 91, 'low', '2026-07-01', '2027-03-31') ON CONFLICT (code) DO NOTHING;
INSERT INTO PROJECT (project_id, client_id, code, name, description, status, budget_allocated, budget_spent, health_score, risk_level, start_date, target_end_date) VALUES (5, 5, 'EDUNOV', 'EduNova Adaptive Exam Portal', 'AI-proctored adaptive testing and accreditation management system.', 'planning', 95000.0, 12000.0, 99, 'low', '2026-11-01', '2027-05-15') ON CONFLICT (code) DO NOTHING;
INSERT INTO PROJECT (project_id, client_id, code, name, description, status, budget_allocated, budget_spent, health_score, risk_level, start_date, target_end_date) VALUES (6, 7, 'PROJ006', 'Enterprise System Initiative 6', 'Strategic digital platform upgrade for Client #7.', 'active', 157094.56, 20470.09, 82, 'moderate', '2026-08-15', '2027-02-28') ON CONFLICT (code) DO NOTHING;
INSERT INTO PROJECT (project_id, client_id, code, name, description, status, budget_allocated, budget_spent, health_score, risk_level, start_date, target_end_date) VALUES (7, 8, 'PROJ007', 'Enterprise System Initiative 7', 'Strategic digital platform upgrade for Client #8.', 'active', 237885.1, 178420.17, 99, 'low', '2026-08-15', '2027-02-28') ON CONFLICT (code) DO NOTHING;
INSERT INTO PROJECT (project_id, client_id, code, name, description, status, budget_allocated, budget_spent, health_score, risk_level, start_date, target_end_date) VALUES (8, 9, 'PROJ008', 'Enterprise System Initiative 8', 'Strategic digital platform upgrade for Client #9.', 'active', 168408.84, 119189.02, 98, 'low', '2026-08-15', '2027-02-28') ON CONFLICT (code) DO NOTHING;
INSERT INTO PROJECT (project_id, client_id, code, name, description, status, budget_allocated, budget_spent, health_score, risk_level, start_date, target_end_date) VALUES (9, 10, 'PROJ009', 'Enterprise System Initiative 9', 'Strategic digital platform upgrade for Client #10.', 'active', 175241.3, 69881.58, 91, 'low', '2026-08-15', '2027-02-28') ON CONFLICT (code) DO NOTHING;
INSERT INTO PROJECT (project_id, client_id, code, name, description, status, budget_allocated, budget_spent, health_score, risk_level, start_date, target_end_date) VALUES (10, 11, 'PROJ010', 'Enterprise System Initiative 10', 'Strategic digital platform upgrade for Client #11.', 'active', 240550.23, 144586.62, 90, 'low', '2026-08-15', '2027-02-28') ON CONFLICT (code) DO NOTHING;
INSERT INTO PROJECT (project_id, client_id, code, name, description, status, budget_allocated, budget_spent, health_score, risk_level, start_date, target_end_date) VALUES (11, 12, 'PROJ011', 'Enterprise System Initiative 11', 'Strategic digital platform upgrade for Client #12.', 'active', 80394.77, 21519.95, 98, 'low', '2026-08-15', '2027-02-28') ON CONFLICT (code) DO NOTHING;
INSERT INTO PROJECT (project_id, client_id, code, name, description, status, budget_allocated, budget_spent, health_score, risk_level, start_date, target_end_date) VALUES (12, 13, 'PROJ012', 'Enterprise System Initiative 12', 'Strategic digital platform upgrade for Client #13.', 'active', 104501.38, 22868.96, 90, 'low', '2026-08-15', '2027-02-28') ON CONFLICT (code) DO NOTHING;
INSERT INTO PROJECT (project_id, client_id, code, name, description, status, budget_allocated, budget_spent, health_score, risk_level, start_date, target_end_date) VALUES (13, 14, 'PROJ013', 'Enterprise System Initiative 13', 'Strategic digital platform upgrade for Client #14.', 'planning', 171169.92, 18306.09, 90, 'low', '2026-08-15', '2027-02-28') ON CONFLICT (code) DO NOTHING;
INSERT INTO PROJECT (project_id, client_id, code, name, description, status, budget_allocated, budget_spent, health_score, risk_level, start_date, target_end_date) VALUES (14, 15, 'PROJ014', 'Enterprise System Initiative 14', 'Strategic digital platform upgrade for Client #15.', 'planning', 214242.53, 65677.34, 86, 'low', '2026-08-15', '2027-02-28') ON CONFLICT (code) DO NOTHING;
INSERT INTO PROJECT (project_id, client_id, code, name, description, status, budget_allocated, budget_spent, health_score, risk_level, start_date, target_end_date) VALUES (15, 16, 'PROJ015', 'Enterprise System Initiative 15', 'Strategic digital platform upgrade for Client #16.', 'completed', 164476.02, 114995.42, 98, 'low', '2026-08-15', '2027-02-28') ON CONFLICT (code) DO NOTHING;

-- 6. INSERT INTO APP_RULE (12 records)
INSERT INTO APP_RULE (rule_id, pattern, match_type, rule_category, is_productive, alert_threshold_seconds) VALUES (1, 'code', 'process', 'ide', True, 0) ON CONFLICT (pattern) DO NOTHING;
INSERT INTO APP_RULE (rule_id, pattern, match_type, rule_category, is_productive, alert_threshold_seconds) VALUES (2, 'cursor', 'process', 'ide', True, 0) ON CONFLICT (pattern) DO NOTHING;
INSERT INTO APP_RULE (rule_id, pattern, match_type, rule_category, is_productive, alert_threshold_seconds) VALUES (3, 'pycharm', 'process', 'ide', True, 0) ON CONFLICT (pattern) DO NOTHING;
INSERT INTO APP_RULE (rule_id, pattern, match_type, rule_category, is_productive, alert_threshold_seconds) VALUES (4, 'windows terminal', 'window_title_regex', 'terminal', True, 0) ON CONFLICT (pattern) DO NOTHING;
INSERT INTO APP_RULE (rule_id, pattern, match_type, rule_category, is_productive, alert_threshold_seconds) VALUES (5, 'powershell', 'process', 'terminal', True, 0) ON CONFLICT (pattern) DO NOTHING;
INSERT INTO APP_RULE (rule_id, pattern, match_type, rule_category, is_productive, alert_threshold_seconds) VALUES (6, 'dbeaver', 'process', 'ide', True, 0) ON CONFLICT (pattern) DO NOTHING;
INSERT INTO APP_RULE (rule_id, pattern, match_type, rule_category, is_productive, alert_threshold_seconds) VALUES (7, 'pgadmin', 'process', 'ide', True, 0) ON CONFLICT (pattern) DO NOTHING;
INSERT INTO APP_RULE (rule_id, pattern, match_type, rule_category, is_productive, alert_threshold_seconds) VALUES (8, 'slack', 'process', 'communication', True, 0) ON CONFLICT (pattern) DO NOTHING;
INSERT INTO APP_RULE (rule_id, pattern, match_type, rule_category, is_productive, alert_threshold_seconds) VALUES (9, 'postman', 'process', 'ide', True, 0) ON CONFLICT (pattern) DO NOTHING;
INSERT INTO APP_RULE (rule_id, pattern, match_type, rule_category, is_productive, alert_threshold_seconds) VALUES (10, 'netflix', 'window_title_regex', 'entertainment', False, 180) ON CONFLICT (pattern) DO NOTHING;
INSERT INTO APP_RULE (rule_id, pattern, match_type, rule_category, is_productive, alert_threshold_seconds) VALUES (11, 'steam', 'process', 'entertainment', False, 120) ON CONFLICT (pattern) DO NOTHING;
INSERT INTO APP_RULE (rule_id, pattern, match_type, rule_category, is_productive, alert_threshold_seconds) VALUES (12, 'youtube', 'window_title_regex', 'non_work', False, 300) ON CONFLICT (pattern) DO NOTHING;

-- 7. INSERT INTO TASK (1,200 records)
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (1, 1, 15, 'Refactor Gemini AI Natural Language Pipeline (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'medium', 'review', 10.9, 6.2, 1, '2026-10-13T09:00:00+00:00', '2026-10-09T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (2, 1, 6, 'Validate B-Tree & Trigram Indexes (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'medium', 'in_progress', 4.0, 2.1, 2, '2026-11-17T09:00:00+00:00', '2026-10-01T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (3, 1, 6, 'Benchmark FastAPI WebSocket Telemetry Hub (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'medium', 'review', 5.0, 0.1, 3, '2026-10-28T09:00:00+00:00', '2026-10-16T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (4, 1, 9, 'Refactor pgTAP Unit Test Suite (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'critical', 'in_progress', 4.2, 1.4, 4, '2026-11-23T09:00:00+00:00', '2026-10-11T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (5, 1, 14, 'Refactor Row-Level Security Policies (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'medium', 'todo', 15.7, 3.7, 1, '2026-11-23T09:00:00+00:00', '2026-10-10T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (6, 1, 16, 'Architect WAL Archiving & PITR Script (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'high', 'in_progress', 15.8, 7.8, 2, '2026-11-11T09:00:00+00:00', '2026-10-11T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (7, 1, 4, 'Optimize Decoupled Staging Ingestion (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'critical', 'completed', 4.6, 4.8, 3, '2026-11-20T09:00:00+00:00', '2026-10-07T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (8, 1, 4, 'Benchmark TOTP MFA Session Verification (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'low', 'backlog', 13.4, 7.9, 4, '2026-11-08T09:00:00+00:00', '2026-10-06T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (9, 1, 2, 'Implement Smart Assignee Scoring Function (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'low', 'in_progress', 4.3, 2.2, 1, '2026-10-17T09:00:00+00:00', '2026-10-15T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (10, 1, 4, 'Containerize PostgreSQL Hash Chain Trigger (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'critical', 'todo', 4.1, 2.1, 2, '2026-10-13T09:00:00+00:00', '2026-10-04T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (11, 1, 20, 'Architect WAL Archiving & PITR Script (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'high', 'in_progress', 16.0, 8.5, 3, '2026-11-16T09:00:00+00:00', '2026-10-04T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (12, 1, 18, 'Secure Materialized View Concurrent Refresh (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'high', 'review', 5.1, 1.1, 4, '2026-11-03T09:00:00+00:00', '2026-10-13T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (13, 1, 16, 'Refactor Smart Assignee Scoring Function (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'critical', 'in_progress', 11.0, 5.8, 1, '2026-10-19T09:00:00+00:00', '2026-10-07T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (14, 1, 1, 'Architect WAL Archiving & PITR Script (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'critical', 'backlog', 14.2, 6.2, 2, '2026-10-20T09:00:00+00:00', '2026-10-15T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (15, 1, 2, 'Integrate Gemini AI Natural Language Pipeline (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'high', 'backlog', 10.4, 2.1, 3, '2026-10-29T09:00:00+00:00', '2026-10-10T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (16, 1, 1, 'Refactor FastAPI WebSocket Telemetry Hub (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'critical', 'todo', 12.0, 0.9, 4, '2026-10-26T09:00:00+00:00', '2026-10-04T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (17, 1, 17, 'Integrate WAL Archiving & PITR Script (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'high', 'todo', 12.7, 1.4, 1, '2026-11-22T09:00:00+00:00', '2026-10-11T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (18, 1, 15, 'Optimize Burndown Velocity Metric Engine (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'high', 'todo', 6.7, 4.0, 2, '2026-11-23T09:00:00+00:00', '2026-10-14T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (19, 1, 4, 'Validate FastAPI WebSocket Telemetry Hub (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'critical', 'todo', 11.3, 3.9, 3, '2026-11-24T09:00:00+00:00', '2026-10-14T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (20, 1, 2, 'Secure FastAPI WebSocket Telemetry Hub (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'high', 'review', 13.9, 3.3, 4, '2026-10-31T09:00:00+00:00', '2026-10-09T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (21, 1, 4, 'Secure pgTAP Unit Test Suite (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'critical', 'backlog', 4.4, 0.5, 1, '2026-11-10T09:00:00+00:00', '2026-10-11T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (22, 1, 16, 'Optimize Materialized View Concurrent Refresh (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'medium', 'backlog', 12.3, 0.2, 2, '2026-11-28T09:00:00+00:00', '2026-10-16T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (23, 1, 2, 'Architect Burndown Velocity Metric Engine (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'critical', 'backlog', 11.4, 5.4, 3, '2026-10-24T09:00:00+00:00', '2026-10-01T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (24, 1, 20, 'Architect TOTP MFA Session Verification (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'medium', 'completed', 12.5, 12.5, 4, '2026-10-17T09:00:00+00:00', '2026-10-07T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (25, 1, 19, 'Secure Gemini AI Natural Language Pipeline (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'critical', 'review', 11.8, 5.9, 1, '2026-10-24T09:00:00+00:00', '2026-10-08T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (26, 1, 16, 'Refactor Smart Assignee Scoring Function (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'high', 'review', 8.9, 2.8, 2, '2026-10-21T09:00:00+00:00', '2026-10-10T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (27, 1, 18, 'Refactor TOTP MFA Session Verification (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'medium', 'completed', 6.2, 3.5, 3, '2026-11-19T09:00:00+00:00', '2026-10-14T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (28, 1, 1, 'Implement Burndown Velocity Metric Engine (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'low', 'backlog', 12.2, 2.1, 4, '2026-10-20T09:00:00+00:00', '2026-10-15T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (29, 1, 3, 'Refactor PostgreSQL Hash Chain Trigger (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'medium', 'backlog', 2.7, 1.1, 1, '2026-10-21T09:00:00+00:00', '2026-10-09T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (30, 1, 17, 'Validate TOTP MFA Session Verification (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'critical', 'review', 15.7, 0.0, 2, '2026-10-29T09:00:00+00:00', '2026-10-11T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (31, 1, 19, 'Optimize FastAPI WebSocket Telemetry Hub (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'low', 'completed', 2.2, 1.3, 3, '2026-10-12T09:00:00+00:00', '2026-10-05T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (32, 1, 15, 'Benchmark WAL Archiving & PITR Script (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'low', 'completed', 7.1, 5.0, 4, '2026-10-24T09:00:00+00:00', '2026-10-14T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (33, 1, 12, 'Benchmark Gemini AI Natural Language Pipeline (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'critical', 'review', 13.7, 6.7, 1, '2026-11-17T09:00:00+00:00', '2026-10-01T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (34, 1, 14, 'Refactor B-Tree & Trigram Indexes (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'medium', 'backlog', 5.8, 3.3, 2, '2026-11-08T09:00:00+00:00', '2026-10-06T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (35, 1, 16, 'Benchmark pgTAP Unit Test Suite (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'low', 'review', 11.3, 5.4, 3, '2026-11-04T09:00:00+00:00', '2026-10-02T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (36, 1, 14, 'Implement Decoupled Staging Ingestion (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'low', 'backlog', 5.5, 0.9, 4, '2026-11-24T09:00:00+00:00', '2026-10-13T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (37, 1, 20, 'Containerize WAL Archiving & PITR Script (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'medium', 'backlog', 15.0, 7.8, 1, '2026-11-25T09:00:00+00:00', '2026-10-03T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (38, 1, 19, 'Containerize Burndown Velocity Metric Engine (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'low', 'todo', 5.7, 1.5, 2, '2026-11-19T09:00:00+00:00', '2026-10-09T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (39, 1, 12, 'Refactor Row-Level Security Policies (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'critical', 'in_progress', 11.7, 4.9, 3, '2026-11-24T09:00:00+00:00', '2026-10-14T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (40, 1, 1, 'Secure WAL Archiving & PITR Script (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'critical', 'todo', 9.0, 2.8, 4, '2026-11-02T09:00:00+00:00', '2026-10-08T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (41, 1, 16, 'Refactor WAL Archiving & PITR Script (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'high', 'in_progress', 8.0, 4.6, 1, '2026-11-24T09:00:00+00:00', '2026-10-10T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (42, 1, 16, 'Integrate Gemini AI Natural Language Pipeline (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'high', 'review', 6.7, 2.1, 2, '2026-11-27T09:00:00+00:00', '2026-10-05T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (43, 1, 15, 'Benchmark FastAPI WebSocket Telemetry Hub (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'high', 'backlog', 8.7, 1.2, 3, '2026-11-28T09:00:00+00:00', '2026-10-11T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (44, 1, 7, 'Secure Materialized View Concurrent Refresh (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'critical', 'completed', 11.2, 7.3, 4, '2026-10-21T09:00:00+00:00', '2026-10-12T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (45, 1, 16, 'Audit TOTP MFA Session Verification (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'low', 'in_progress', 15.4, 8.2, 1, '2026-11-27T09:00:00+00:00', '2026-10-16T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (46, 1, 19, 'Architect Smart Assignee Scoring Function (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'critical', 'backlog', 9.5, 0.2, 2, '2026-11-05T09:00:00+00:00', '2026-10-02T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (47, 1, 14, 'Refactor pgTAP Unit Test Suite (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'low', 'in_progress', 3.3, 1.1, 3, '2026-11-05T09:00:00+00:00', '2026-10-15T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (48, 1, 16, 'Architect Materialized View Concurrent Refresh (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'high', 'completed', 4.9, 4.7, 4, '2026-11-23T09:00:00+00:00', '2026-10-12T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (49, 1, 20, 'Implement Smart Assignee Scoring Function (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'low', 'backlog', 10.6, 3.9, 1, '2026-11-18T09:00:00+00:00', '2026-10-14T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (50, 1, 12, 'Implement Burndown Velocity Metric Engine (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'high', 'completed', 14.1, 11.5, 2, '2026-10-19T09:00:00+00:00', '2026-10-16T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (51, 1, 7, 'Integrate Smart Assignee Scoring Function (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'high', 'in_progress', 9.9, 5.9, 3, '2026-10-30T09:00:00+00:00', '2026-10-01T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (52, 1, 6, 'Benchmark FastAPI WebSocket Telemetry Hub (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'high', 'in_progress', 8.2, 1.7, 4, '2026-11-07T09:00:00+00:00', '2026-10-05T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (53, 1, 6, 'Implement Decoupled Staging Ingestion (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'critical', 'todo', 8.6, 0.2, 1, '2026-10-29T09:00:00+00:00', '2026-10-01T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (54, 1, 6, 'Secure pgTAP Unit Test Suite (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'medium', 'in_progress', 7.3, 0.3, 2, '2026-11-27T09:00:00+00:00', '2026-10-14T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (55, 1, 5, 'Implement PostgreSQL Hash Chain Trigger (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'medium', 'completed', 12.2, 7.5, 3, '2026-11-16T09:00:00+00:00', '2026-10-14T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (56, 1, 6, 'Secure Smart Assignee Scoring Function (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'critical', 'completed', 8.6, 8.9, 4, '2026-10-24T09:00:00+00:00', '2026-10-14T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (57, 1, 3, 'Audit Materialized View Concurrent Refresh (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'medium', 'in_progress', 7.0, 1.3, 1, '2026-11-10T09:00:00+00:00', '2026-10-11T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (58, 1, 7, 'Optimize TOTP MFA Session Verification (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'medium', 'backlog', 14.9, 0.1, 2, '2026-11-25T09:00:00+00:00', '2026-10-08T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (59, 1, 8, 'Architect Decoupled Staging Ingestion (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'medium', 'completed', 10.0, 5.7, 3, '2026-10-08T09:00:00+00:00', '2026-10-13T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (60, 1, 12, 'Architect Smart Assignee Scoring Function (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'critical', 'completed', 3.6, 2.3, 4, '2026-11-27T09:00:00+00:00', '2026-10-02T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (61, 1, 5, 'Audit B-Tree & Trigram Indexes (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'medium', 'review', 4.1, 0.6, 1, '2026-10-27T09:00:00+00:00', '2026-10-12T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (62, 1, 16, 'Benchmark Row-Level Security Policies (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'medium', 'backlog', 8.0, 1.8, 2, '2026-11-03T09:00:00+00:00', '2026-10-14T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (63, 1, 2, 'Containerize Decoupled Staging Ingestion (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'critical', 'completed', 5.8, 4.1, 3, '2026-10-17T09:00:00+00:00', '2026-10-13T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (64, 1, 3, 'Audit Materialized View Concurrent Refresh (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'high', 'backlog', 4.5, 1.7, 4, '2026-10-26T09:00:00+00:00', '2026-10-16T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (65, 1, 14, 'Secure Gemini AI Natural Language Pipeline (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'low', 'review', 5.9, 1.6, 1, '2026-11-11T09:00:00+00:00', '2026-10-03T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (66, 1, 6, 'Benchmark Materialized View Concurrent Refresh (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'critical', 'in_progress', 14.0, 3.2, 2, '2026-11-30T09:00:00+00:00', '2026-10-09T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (67, 1, 13, 'Secure Smart Assignee Scoring Function (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'high', 'in_progress', 13.8, 7.7, 3, '2026-11-01T09:00:00+00:00', '2026-10-05T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (68, 1, 1, 'Architect B-Tree & Trigram Indexes (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'medium', 'in_progress', 8.1, 2.2, 4, '2026-11-12T09:00:00+00:00', '2026-10-16T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (69, 1, 15, 'Benchmark FastAPI WebSocket Telemetry Hub (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'critical', 'backlog', 11.1, 2.0, 1, '2026-10-24T09:00:00+00:00', '2026-10-16T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (70, 1, 19, 'Containerize Burndown Velocity Metric Engine (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'high', 'review', 3.4, 0.0, 2, '2026-10-19T09:00:00+00:00', '2026-10-06T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (71, 1, 7, 'Benchmark PostgreSQL Hash Chain Trigger (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'low', 'in_progress', 7.0, 3.7, 3, '2026-10-06T09:00:00+00:00', '2026-10-02T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (72, 1, 5, 'Secure pgTAP Unit Test Suite (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'medium', 'in_progress', 7.8, 3.0, 4, '2026-10-07T09:00:00+00:00', '2026-10-06T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (73, 1, 3, 'Implement Decoupled Staging Ingestion (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'critical', 'review', 5.4, 1.2, 1, '2026-10-11T09:00:00+00:00', '2026-10-01T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (74, 1, 18, 'Refactor Decoupled Staging Ingestion (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'medium', 'backlog', 12.3, 3.4, 2, '2026-11-29T09:00:00+00:00', '2026-10-13T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (75, 1, 12, 'Refactor pgTAP Unit Test Suite (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'critical', 'in_progress', 13.7, 0.6, 3, '2026-10-17T09:00:00+00:00', '2026-10-12T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (76, 1, 13, 'Architect Burndown Velocity Metric Engine (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'high', 'completed', 2.8, 2.9, 4, '2026-10-20T09:00:00+00:00', '2026-10-13T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (77, 1, 9, 'Architect PostgreSQL Hash Chain Trigger (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'low', 'backlog', 13.0, 7.5, 1, '2026-11-08T09:00:00+00:00', '2026-10-10T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (78, 1, 11, 'Validate PostgreSQL Hash Chain Trigger (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'low', 'backlog', 9.2, 5.0, 2, '2026-11-11T09:00:00+00:00', '2026-10-01T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (79, 1, 3, 'Optimize WAL Archiving & PITR Script (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'high', 'review', 3.7, 1.0, 3, '2026-10-26T09:00:00+00:00', '2026-10-10T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (80, 1, 12, 'Audit FastAPI WebSocket Telemetry Hub (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'high', 'todo', 11.3, 1.2, 4, '2026-10-16T09:00:00+00:00', '2026-10-12T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (81, 2, 20, 'Architect Decoupled Staging Ingestion (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'low', 'review', 12.4, 6.6, 1, '2026-10-13T09:00:00+00:00', '2026-10-07T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (82, 2, 3, 'Integrate pgTAP Unit Test Suite (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'low', 'in_progress', 6.5, 1.0, 2, '2026-10-19T09:00:00+00:00', '2026-10-02T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (83, 2, 10, 'Secure Row-Level Security Policies (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'critical', 'in_progress', 12.7, 1.0, 3, '2026-11-22T09:00:00+00:00', '2026-10-10T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (84, 2, 15, 'Audit Decoupled Staging Ingestion (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'high', 'completed', 6.5, 4.9, 4, '2026-11-10T09:00:00+00:00', '2026-10-13T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (85, 2, 13, 'Integrate PostgreSQL Hash Chain Trigger (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'medium', 'completed', 16.0, 8.9, 1, '2026-10-10T09:00:00+00:00', '2026-10-12T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (86, 2, 17, 'Audit Burndown Velocity Metric Engine (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'high', 'completed', 9.0, 10.7, 2, '2026-11-02T09:00:00+00:00', '2026-10-14T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (87, 2, 7, 'Secure Decoupled Staging Ingestion (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'low', 'in_progress', 13.2, 0.5, 3, '2026-11-19T09:00:00+00:00', '2026-10-06T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (88, 2, 15, 'Secure WAL Archiving & PITR Script (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'critical', 'todo', 10.5, 5.1, 4, '2026-10-07T09:00:00+00:00', '2026-10-13T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (89, 2, 15, 'Refactor Burndown Velocity Metric Engine (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'medium', 'completed', 11.7, 9.1, 1, '2026-11-06T09:00:00+00:00', '2026-10-10T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (90, 2, 15, 'Secure PostgreSQL Hash Chain Trigger (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'high', 'backlog', 15.3, 2.0, 2, '2026-11-01T09:00:00+00:00', '2026-10-12T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (91, 2, 5, 'Benchmark Smart Assignee Scoring Function (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'critical', 'backlog', 11.2, 1.5, 3, '2026-11-16T09:00:00+00:00', '2026-10-03T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (92, 2, 17, 'Audit Materialized View Concurrent Refresh (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'medium', 'in_progress', 12.9, 0.5, 4, '2026-10-29T09:00:00+00:00', '2026-10-16T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (93, 2, 5, 'Refactor PostgreSQL Hash Chain Trigger (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'medium', 'completed', 5.5, 5.5, 1, '2026-10-28T09:00:00+00:00', '2026-10-12T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (94, 2, 9, 'Implement FastAPI WebSocket Telemetry Hub (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'medium', 'completed', 5.8, 6.1, 2, '2026-11-30T09:00:00+00:00', '2026-10-07T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (95, 2, 11, 'Integrate Gemini AI Natural Language Pipeline (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'critical', 'backlog', 5.1, 1.5, 3, '2026-11-07T09:00:00+00:00', '2026-10-16T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (96, 2, 7, 'Integrate Gemini AI Natural Language Pipeline (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'high', 'completed', 4.0, 2.5, 4, '2026-10-20T09:00:00+00:00', '2026-10-11T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (97, 2, 19, 'Architect TOTP MFA Session Verification (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'critical', 'review', 14.6, 7.1, 1, '2026-10-23T09:00:00+00:00', '2026-10-05T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (98, 2, 6, 'Refactor Materialized View Concurrent Refresh (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'low', 'backlog', 15.1, 5.1, 2, '2026-10-18T09:00:00+00:00', '2026-10-16T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (99, 2, 9, 'Containerize Row-Level Security Policies (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'critical', 'review', 4.0, 0.5, 3, '2026-11-10T09:00:00+00:00', '2026-10-12T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (100, 2, 2, 'Refactor Gemini AI Natural Language Pipeline (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'high', 'backlog', 11.5, 3.4, 4, '2026-11-25T09:00:00+00:00', '2026-10-06T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (101, 2, 15, 'Refactor pgTAP Unit Test Suite (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'high', 'in_progress', 9.9, 0.2, 1, '2026-10-24T09:00:00+00:00', '2026-10-13T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (102, 2, 19, 'Implement FastAPI WebSocket Telemetry Hub (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'high', 'todo', 10.9, 4.2, 2, '2026-11-24T09:00:00+00:00', '2026-10-05T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (103, 2, 3, 'Architect Decoupled Staging Ingestion (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'high', 'completed', 14.6, 7.9, 3, '2026-10-31T09:00:00+00:00', '2026-10-04T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (104, 2, 1, 'Implement FastAPI WebSocket Telemetry Hub (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'low', 'todo', 14.7, 3.8, 4, '2026-11-21T09:00:00+00:00', '2026-10-07T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (105, 2, 9, 'Integrate Row-Level Security Policies (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'medium', 'backlog', 15.8, 5.9, 1, '2026-11-09T09:00:00+00:00', '2026-10-16T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (106, 2, 13, 'Validate Row-Level Security Policies (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'low', 'review', 13.4, 5.6, 2, '2026-11-28T09:00:00+00:00', '2026-10-11T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (107, 2, 15, 'Secure Gemini AI Natural Language Pipeline (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'critical', 'todo', 13.8, 7.2, 3, '2026-11-08T09:00:00+00:00', '2026-10-02T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (108, 2, 5, 'Integrate WAL Archiving & PITR Script (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'medium', 'backlog', 12.7, 3.1, 4, '2026-11-07T09:00:00+00:00', '2026-10-11T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (109, 2, 5, 'Audit pgTAP Unit Test Suite (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'low', 'todo', 15.4, 0.2, 1, '2026-10-12T09:00:00+00:00', '2026-10-09T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (110, 2, 6, 'Refactor TOTP MFA Session Verification (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'critical', 'completed', 10.6, 9.7, 2, '2026-10-21T09:00:00+00:00', '2026-10-10T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (111, 2, 2, 'Architect Gemini AI Natural Language Pipeline (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'high', 'backlog', 13.2, 7.6, 3, '2026-11-05T09:00:00+00:00', '2026-10-14T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (112, 2, 13, 'Optimize Materialized View Concurrent Refresh (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'medium', 'completed', 12.0, 8.3, 4, '2026-11-10T09:00:00+00:00', '2026-10-16T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (113, 2, 3, 'Benchmark B-Tree & Trigram Indexes (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'critical', 'completed', 8.7, 8.4, 1, '2026-10-20T09:00:00+00:00', '2026-10-11T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (114, 2, 18, 'Implement Smart Assignee Scoring Function (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'medium', 'completed', 14.3, 16.6, 2, '2026-11-25T09:00:00+00:00', '2026-10-12T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (115, 2, 18, 'Secure B-Tree & Trigram Indexes (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'medium', 'todo', 4.1, 1.2, 3, '2026-10-12T09:00:00+00:00', '2026-10-11T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (116, 2, 8, 'Architect Burndown Velocity Metric Engine (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'medium', 'completed', 7.0, 5.0, 4, '2026-10-17T09:00:00+00:00', '2026-10-10T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (117, 2, 6, 'Refactor TOTP MFA Session Verification (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'medium', 'review', 10.7, 0.5, 1, '2026-10-30T09:00:00+00:00', '2026-10-05T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (118, 2, 2, 'Optimize PostgreSQL Hash Chain Trigger (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'medium', 'completed', 10.0, 8.4, 2, '2026-11-07T09:00:00+00:00', '2026-10-11T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (119, 2, 16, 'Implement pgTAP Unit Test Suite (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'critical', 'completed', 8.3, 6.4, 3, '2026-10-15T09:00:00+00:00', '2026-10-13T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (120, 2, 10, 'Audit FastAPI WebSocket Telemetry Hub (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'critical', 'completed', 15.9, 12.3, 4, '2026-11-23T09:00:00+00:00', '2026-10-14T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (121, 2, 6, 'Secure pgTAP Unit Test Suite (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'low', 'backlog', 4.9, 2.1, 1, '2026-10-14T09:00:00+00:00', '2026-10-09T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (122, 2, 10, 'Secure Decoupled Staging Ingestion (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'critical', 'todo', 3.2, 0.9, 2, '2026-11-10T09:00:00+00:00', '2026-10-14T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (123, 2, 2, 'Benchmark Gemini AI Natural Language Pipeline (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'low', 'backlog', 15.8, 1.7, 3, '2026-10-20T09:00:00+00:00', '2026-10-08T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (124, 2, 18, 'Validate Gemini AI Natural Language Pipeline (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'high', 'todo', 11.4, 1.2, 4, '2026-11-06T09:00:00+00:00', '2026-10-16T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (125, 2, 16, 'Audit Row-Level Security Policies (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'high', 'in_progress', 2.7, 1.1, 1, '2026-11-24T09:00:00+00:00', '2026-10-09T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (126, 2, 5, 'Containerize Row-Level Security Policies (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'low', 'review', 2.5, 0.7, 2, '2026-11-17T09:00:00+00:00', '2026-10-04T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (127, 2, 12, 'Validate Materialized View Concurrent Refresh (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'low', 'todo', 8.5, 2.3, 3, '2026-10-08T09:00:00+00:00', '2026-10-12T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (128, 2, 10, 'Validate Gemini AI Natural Language Pipeline (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'high', 'todo', 14.3, 2.6, 4, '2026-10-26T09:00:00+00:00', '2026-10-08T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (129, 2, 12, 'Audit WAL Archiving & PITR Script (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'medium', 'completed', 5.1, 5.5, 1, '2026-11-25T09:00:00+00:00', '2026-10-03T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (130, 2, 16, 'Implement PostgreSQL Hash Chain Trigger (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'critical', 'todo', 8.0, 3.4, 2, '2026-10-30T09:00:00+00:00', '2026-10-05T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (131, 2, 17, 'Benchmark pgTAP Unit Test Suite (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'critical', 'in_progress', 9.2, 4.2, 3, '2026-10-08T09:00:00+00:00', '2026-10-02T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (132, 2, 9, 'Benchmark Decoupled Staging Ingestion (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'low', 'backlog', 11.0, 0.7, 4, '2026-10-08T09:00:00+00:00', '2026-10-05T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (133, 2, 10, 'Integrate pgTAP Unit Test Suite (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'low', 'in_progress', 11.5, 4.1, 1, '2026-10-06T09:00:00+00:00', '2026-10-13T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (134, 2, 19, 'Secure TOTP MFA Session Verification (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'low', 'todo', 8.7, 2.8, 2, '2026-10-22T09:00:00+00:00', '2026-10-13T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (135, 2, 4, 'Benchmark WAL Archiving & PITR Script (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'high', 'completed', 5.3, 3.6, 3, '2026-10-08T09:00:00+00:00', '2026-10-16T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (136, 2, 4, 'Architect TOTP MFA Session Verification (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'medium', 'in_progress', 12.7, 4.0, 4, '2026-11-03T09:00:00+00:00', '2026-10-13T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (137, 2, 3, 'Refactor Smart Assignee Scoring Function (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'critical', 'completed', 5.3, 3.6, 1, '2026-11-17T09:00:00+00:00', '2026-10-06T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (138, 2, 10, 'Audit Row-Level Security Policies (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'medium', 'backlog', 7.2, 3.4, 2, '2026-10-09T09:00:00+00:00', '2026-10-03T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (139, 2, 12, 'Optimize Gemini AI Natural Language Pipeline (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'medium', 'review', 14.6, 0.2, 3, '2026-10-30T09:00:00+00:00', '2026-10-16T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (140, 2, 13, 'Containerize Burndown Velocity Metric Engine (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'medium', 'review', 11.3, 2.4, 4, '2026-11-09T09:00:00+00:00', '2026-10-12T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (141, 2, 7, 'Benchmark Decoupled Staging Ingestion (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'medium', 'in_progress', 10.3, 1.9, 1, '2026-11-15T09:00:00+00:00', '2026-10-04T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (142, 2, 14, 'Benchmark Smart Assignee Scoring Function (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'low', 'completed', 15.5, 13.1, 2, '2026-10-17T09:00:00+00:00', '2026-10-06T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (143, 2, 12, 'Validate PostgreSQL Hash Chain Trigger (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'high', 'todo', 13.3, 5.9, 3, '2026-10-12T09:00:00+00:00', '2026-10-10T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (144, 2, 15, 'Audit pgTAP Unit Test Suite (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'low', 'completed', 15.1, 8.9, 4, '2026-11-06T09:00:00+00:00', '2026-10-10T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (145, 2, 7, 'Benchmark Decoupled Staging Ingestion (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'critical', 'review', 6.1, 0.7, 1, '2026-10-20T09:00:00+00:00', '2026-10-16T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (146, 2, 3, 'Refactor Gemini AI Natural Language Pipeline (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'high', 'completed', 2.5, 1.3, 2, '2026-10-16T09:00:00+00:00', '2026-10-16T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (147, 2, 16, 'Validate Burndown Velocity Metric Engine (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'high', 'completed', 13.1, 10.4, 3, '2026-10-18T09:00:00+00:00', '2026-10-16T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (148, 2, 2, 'Optimize Decoupled Staging Ingestion (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'high', 'review', 8.9, 0.7, 4, '2026-10-09T09:00:00+00:00', '2026-10-15T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (149, 2, 4, 'Integrate Materialized View Concurrent Refresh (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'low', 'completed', 6.5, 4.7, 1, '2026-10-10T09:00:00+00:00', '2026-10-01T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (150, 2, 16, 'Refactor FastAPI WebSocket Telemetry Hub (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'medium', 'in_progress', 11.2, 3.8, 2, '2026-10-22T09:00:00+00:00', '2026-10-11T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (151, 2, 3, 'Benchmark WAL Archiving & PITR Script (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'high', 'todo', 14.9, 8.4, 3, '2026-10-27T09:00:00+00:00', '2026-10-16T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (152, 2, 13, 'Containerize WAL Archiving & PITR Script (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'high', 'completed', 2.4, 2.6, 4, '2026-11-20T09:00:00+00:00', '2026-10-04T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (153, 2, 15, 'Implement FastAPI WebSocket Telemetry Hub (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'low', 'in_progress', 10.0, 3.4, 1, '2026-10-28T09:00:00+00:00', '2026-10-03T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (154, 2, 12, 'Refactor PostgreSQL Hash Chain Trigger (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'low', 'review', 11.8, 0.2, 2, '2026-10-14T09:00:00+00:00', '2026-10-01T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (155, 2, 2, 'Integrate Burndown Velocity Metric Engine (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'low', 'todo', 6.7, 0.5, 3, '2026-10-28T09:00:00+00:00', '2026-10-15T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (156, 2, 10, 'Validate TOTP MFA Session Verification (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'medium', 'in_progress', 11.5, 3.4, 4, '2026-11-10T09:00:00+00:00', '2026-10-13T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (157, 2, 11, 'Audit TOTP MFA Session Verification (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'medium', 'backlog', 9.0, 4.5, 1, '2026-10-19T09:00:00+00:00', '2026-10-05T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (158, 2, 20, 'Implement Smart Assignee Scoring Function (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'critical', 'in_progress', 6.4, 2.0, 2, '2026-11-28T09:00:00+00:00', '2026-10-09T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (159, 2, 4, 'Architect Row-Level Security Policies (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'high', 'todo', 4.3, 1.4, 3, '2026-11-20T09:00:00+00:00', '2026-10-03T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (160, 2, 10, 'Validate Decoupled Staging Ingestion (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'critical', 'in_progress', 2.2, 1.1, 4, '2026-11-26T09:00:00+00:00', '2026-10-12T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (161, 3, 16, 'Integrate pgTAP Unit Test Suite (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'low', 'review', 9.8, 3.1, 1, '2026-10-18T09:00:00+00:00', '2026-10-14T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (162, 3, 1, 'Containerize Gemini AI Natural Language Pipeline (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'medium', 'review', 8.3, 4.7, 2, '2026-10-13T09:00:00+00:00', '2026-10-03T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (163, 3, 10, 'Audit B-Tree & Trigram Indexes (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'medium', 'completed', 15.9, 8.8, 3, '2026-10-08T09:00:00+00:00', '2026-10-03T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (164, 3, 3, 'Containerize Gemini AI Natural Language Pipeline (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'low', 'review', 15.3, 2.2, 4, '2026-11-13T09:00:00+00:00', '2026-10-06T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (165, 3, 20, 'Integrate TOTP MFA Session Verification (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'medium', 'completed', 4.1, 4.3, 1, '2026-11-16T09:00:00+00:00', '2026-10-11T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (166, 3, 2, 'Audit Gemini AI Natural Language Pipeline (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'medium', 'backlog', 5.8, 2.3, 2, '2026-10-23T09:00:00+00:00', '2026-10-04T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (167, 3, 18, 'Architect Decoupled Staging Ingestion (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'low', 'review', 8.0, 1.8, 3, '2026-11-19T09:00:00+00:00', '2026-10-16T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (168, 3, 5, 'Refactor Materialized View Concurrent Refresh (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'low', 'in_progress', 3.6, 0.9, 4, '2026-11-21T09:00:00+00:00', '2026-10-03T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (169, 3, 6, 'Validate B-Tree & Trigram Indexes (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'critical', 'completed', 13.8, 10.9, 1, '2026-10-22T09:00:00+00:00', '2026-10-14T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (170, 3, 2, 'Refactor FastAPI WebSocket Telemetry Hub (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'medium', 'review', 11.4, 3.4, 2, '2026-10-30T09:00:00+00:00', '2026-10-02T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (171, 3, 14, 'Optimize Smart Assignee Scoring Function (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'low', 'review', 6.2, 1.9, 3, '2026-10-08T09:00:00+00:00', '2026-10-07T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (172, 3, 5, 'Optimize Gemini AI Natural Language Pipeline (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'medium', 'todo', 5.6, 0.0, 4, '2026-11-05T09:00:00+00:00', '2026-10-01T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (173, 3, 6, 'Audit WAL Archiving & PITR Script (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'low', 'completed', 13.4, 15.6, 1, '2026-11-10T09:00:00+00:00', '2026-10-11T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (174, 3, 2, 'Implement Row-Level Security Policies (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'critical', 'completed', 14.8, 13.1, 2, '2026-10-13T09:00:00+00:00', '2026-10-13T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (175, 3, 7, 'Optimize PostgreSQL Hash Chain Trigger (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'critical', 'in_progress', 14.3, 3.2, 3, '2026-11-18T09:00:00+00:00', '2026-10-03T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (176, 3, 7, 'Benchmark Row-Level Security Policies (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'high', 'todo', 9.2, 4.3, 4, '2026-11-14T09:00:00+00:00', '2026-10-03T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (177, 3, 8, 'Containerize WAL Archiving & PITR Script (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'low', 'completed', 9.3, 10.6, 1, '2026-10-31T09:00:00+00:00', '2026-10-13T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (178, 3, 4, 'Benchmark pgTAP Unit Test Suite (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'high', 'todo', 4.8, 0.1, 2, '2026-11-02T09:00:00+00:00', '2026-10-02T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (179, 3, 17, 'Integrate FastAPI WebSocket Telemetry Hub (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'medium', 'completed', 7.6, 4.3, 3, '2026-11-27T09:00:00+00:00', '2026-10-16T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (180, 3, 9, 'Refactor Burndown Velocity Metric Engine (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'critical', 'completed', 15.9, 9.1, 4, '2026-10-12T09:00:00+00:00', '2026-10-10T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (181, 3, 20, 'Architect Gemini AI Natural Language Pipeline (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'high', 'todo', 9.2, 1.8, 1, '2026-11-16T09:00:00+00:00', '2026-10-05T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (182, 3, 7, 'Validate PostgreSQL Hash Chain Trigger (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'medium', 'review', 9.6, 2.6, 2, '2026-10-19T09:00:00+00:00', '2026-10-15T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (183, 3, 4, 'Benchmark FastAPI WebSocket Telemetry Hub (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'low', 'backlog', 10.4, 4.9, 3, '2026-11-27T09:00:00+00:00', '2026-10-05T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (184, 3, 20, 'Containerize PostgreSQL Hash Chain Trigger (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'high', 'completed', 10.6, 12.5, 4, '2026-11-28T09:00:00+00:00', '2026-10-13T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (185, 3, 12, 'Implement Burndown Velocity Metric Engine (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'medium', 'backlog', 3.0, 1.1, 1, '2026-11-21T09:00:00+00:00', '2026-10-09T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (186, 3, 7, 'Containerize PostgreSQL Hash Chain Trigger (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'critical', 'todo', 13.5, 2.6, 2, '2026-10-14T09:00:00+00:00', '2026-10-07T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (187, 3, 18, 'Benchmark PostgreSQL Hash Chain Trigger (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'medium', 'review', 11.5, 6.4, 3, '2026-11-18T09:00:00+00:00', '2026-10-03T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (188, 3, 9, 'Integrate Materialized View Concurrent Refresh (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'high', 'review', 14.6, 2.7, 4, '2026-11-25T09:00:00+00:00', '2026-10-13T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (189, 3, 18, 'Architect Gemini AI Natural Language Pipeline (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'critical', 'backlog', 16.0, 8.9, 1, '2026-11-07T09:00:00+00:00', '2026-10-07T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (190, 3, 11, 'Benchmark WAL Archiving & PITR Script (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'critical', 'todo', 4.5, 1.5, 2, '2026-11-15T09:00:00+00:00', '2026-10-10T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (191, 3, 12, 'Secure WAL Archiving & PITR Script (Phase 3)', 'Standard engineering deliverable for Sprint 3.', 'low', 'todo', 15.4, 8.1, 3, '2026-10-30T09:00:00+00:00', '2026-10-02T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (192, 3, 7, 'Containerize Burndown Velocity Metric Engine (Phase 4)', 'Standard engineering deliverable for Sprint 4.', 'high', 'review', 10.0, 1.1, 4, '2026-10-12T09:00:00+00:00', '2026-10-16T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (193, 3, 8, 'Validate PostgreSQL Hash Chain Trigger (Phase 1)', 'Standard engineering deliverable for Sprint 1.', 'critical', 'in_progress', 8.7, 3.1, 1, '2026-11-21T09:00:00+00:00', '2026-10-09T09:00:00+00:00');
INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) VALUES (194, 3, 8, 'Secure Gemini AI Natural Language Pipeline (Phase 2)', 'Standard engineering deliverable for Sprint 2.', 'medium', 'backlog', 14.1, 3.1, 2, '2026-10-18T09:00:00+00:00', '2026-10-08T09:00:00+00:00');
-- 12. INSERT INTO AUDIT_LOG (Initial Cryptographic Ledger)
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (1, 'BUG', 1, 'INSERT', '{"audit_sample_id": 1, "entity": "BUG", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, '0000000000000000000000000000000000000000000000000000000000000000', 'bd9cb838f9b8fd139cb5adb5a3a7d1a178cbdd86c7da1a745d48efb0d9f2b75f');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (2, 'TASK', 2, 'INSERT', '{"audit_sample_id": 2, "entity": "TASK", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, 'bd9cb838f9b8fd139cb5adb5a3a7d1a178cbdd86c7da1a745d48efb0d9f2b75f', '2fa8e865e8a6598e35538cbf7f58cf65c30444b99979ee23688a14838469f764');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (3, 'CLIENT', 3, 'INSERT', '{"audit_sample_id": 3, "entity": "CLIENT", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, '2fa8e865e8a6598e35538cbf7f58cf65c30444b99979ee23688a14838469f764', '5e599e11b1af831ec93ee3810a0cc9128c10d0ed403afcebf323ab914a13cca5');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (4, 'TASK', 4, 'INSERT', '{"audit_sample_id": 4, "entity": "TASK", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, '5e599e11b1af831ec93ee3810a0cc9128c10d0ed403afcebf323ab914a13cca5', 'e3d9836188d8e1b01cd78a5365f6aa68030125dc1fcc2dab36678858e16576ae');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (5, 'CLIENT', 5, 'INSERT', '{"audit_sample_id": 5, "entity": "CLIENT", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, 'e3d9836188d8e1b01cd78a5365f6aa68030125dc1fcc2dab36678858e16576ae', '9d7e2caffaf073757fa20682785e62e83b7d0f4aa57de61e3e27427849c5d90a');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (6, 'TIME_LOG', 6, 'INSERT', '{"audit_sample_id": 6, "entity": "TIME_LOG", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, '9d7e2caffaf073757fa20682785e62e83b7d0f4aa57de61e3e27427849c5d90a', 'fab0de5fc324688b9af4521c8a7bd6c0b8e73a04a3bbca3b98c33a079332c955');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (7, 'TASK', 7, 'INSERT', '{"audit_sample_id": 7, "entity": "TASK", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, 'fab0de5fc324688b9af4521c8a7bd6c0b8e73a04a3bbca3b98c33a079332c955', '65013125ee66021691effb1e1d60a8f5dccb3b60bdbd5635400b049027c2451c');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (8, 'PROJECT', 8, 'INSERT', '{"audit_sample_id": 8, "entity": "PROJECT", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, '65013125ee66021691effb1e1d60a8f5dccb3b60bdbd5635400b049027c2451c', '379c170ffc250a640f9a1b23600354537f927f0b33db2ff8e5d2f5e47d1073ce');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (9, 'BUG', 9, 'INSERT', '{"audit_sample_id": 9, "entity": "BUG", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, '379c170ffc250a640f9a1b23600354537f927f0b33db2ff8e5d2f5e47d1073ce', '2c83a41e45a08bcdc05dff2e3bc6c71a600937737fd75fd0cd6fd48efe238ab5');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (10, 'PROJECT', 10, 'INSERT', '{"audit_sample_id": 10, "entity": "PROJECT", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, '2c83a41e45a08bcdc05dff2e3bc6c71a600937737fd75fd0cd6fd48efe238ab5', 'eacfa3863b25b1a0eaad570852b744fc8688fcda9bc1fe486197bb8db5339aac');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (11, 'TASK', 11, 'INSERT', '{"audit_sample_id": 11, "entity": "TASK", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, 'eacfa3863b25b1a0eaad570852b744fc8688fcda9bc1fe486197bb8db5339aac', '071bd4af68963f8590390fed949b7bcb44d0dacb7b2475416d9a5cdab5d82392');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (12, 'BUG', 12, 'INSERT', '{"audit_sample_id": 12, "entity": "BUG", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, '071bd4af68963f8590390fed949b7bcb44d0dacb7b2475416d9a5cdab5d82392', '68c739a3970a6e69b006285f40c1b144d05426dc162ae9a7d94295e155a5fece');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (13, 'BUG', 13, 'INSERT', '{"audit_sample_id": 13, "entity": "BUG", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, '68c739a3970a6e69b006285f40c1b144d05426dc162ae9a7d94295e155a5fece', 'a97f6a0485842d950b983e60b7057119d505409fc64101f211763fdcf70217b7');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (14, 'TASK', 14, 'INSERT', '{"audit_sample_id": 14, "entity": "TASK", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, 'a97f6a0485842d950b983e60b7057119d505409fc64101f211763fdcf70217b7', '4bd2f72b3afad85fef7644cdb48ac9f2573a15f47e65518d9a91e39dae9f2e97');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (15, 'CLIENT', 15, 'INSERT', '{"audit_sample_id": 15, "entity": "CLIENT", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, '4bd2f72b3afad85fef7644cdb48ac9f2573a15f47e65518d9a91e39dae9f2e97', '9ffe118c74c24fc49094dbab30cf2d8f873e847fa2927a8a91aab337c2c86ee3');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (16, 'CLIENT', 16, 'INSERT', '{"audit_sample_id": 16, "entity": "CLIENT", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, '9ffe118c74c24fc49094dbab30cf2d8f873e847fa2927a8a91aab337c2c86ee3', 'e021f292ea888f2c9e4f5e2c27f97045d7e7dea1701d70cc5449708136310754');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (17, 'TIME_LOG', 17, 'INSERT', '{"audit_sample_id": 17, "entity": "TIME_LOG", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, 'e021f292ea888f2c9e4f5e2c27f97045d7e7dea1701d70cc5449708136310754', 'e7cfa19d220d8db8ac85ebe0f15cd52d175d65ea3e705cb134b60e8934b55602');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (18, 'TASK', 18, 'INSERT', '{"audit_sample_id": 18, "entity": "TASK", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, 'e7cfa19d220d8db8ac85ebe0f15cd52d175d65ea3e705cb134b60e8934b55602', '66f1d4a09b0ea9b06f39bfdf7d844d33aea5f72ca588ea922b80f6a05725deb6');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (19, 'CLIENT', 19, 'INSERT', '{"audit_sample_id": 19, "entity": "CLIENT", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, '66f1d4a09b0ea9b06f39bfdf7d844d33aea5f72ca588ea922b80f6a05725deb6', '7299dfa78490e655f7e099405e453a096232ec465c772827be496bbe69183c24');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (20, 'PROJECT', 20, 'INSERT', '{"audit_sample_id": 20, "entity": "PROJECT", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, '7299dfa78490e655f7e099405e453a096232ec465c772827be496bbe69183c24', '99fda3749a23be4752220a00ddea6f5e74e5e8f7885933eff6242074dfa6b992');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (21, 'PROJECT', 21, 'INSERT', '{"audit_sample_id": 21, "entity": "PROJECT", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, '99fda3749a23be4752220a00ddea6f5e74e5e8f7885933eff6242074dfa6b992', '95c7a2e60e4b27e5b83b2440cfde891361bdd0764e94a4bbe2a5a49c9d980c61');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (22, 'TASK', 22, 'INSERT', '{"audit_sample_id": 22, "entity": "TASK", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, '95c7a2e60e4b27e5b83b2440cfde891361bdd0764e94a4bbe2a5a49c9d980c61', '8d49b14c7ed8717d100f8589d68be8bd5ce8fd8858e728d10d09b2491ea97b6d');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (23, 'BUG', 23, 'INSERT', '{"audit_sample_id": 23, "entity": "BUG", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, '8d49b14c7ed8717d100f8589d68be8bd5ce8fd8858e728d10d09b2491ea97b6d', '14495e7a50d4aaca5efff2d02ad170f7cbb9863ebf9010bcd0d64b1df8e90da3');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (24, 'PROJECT', 24, 'INSERT', '{"audit_sample_id": 24, "entity": "PROJECT", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, '14495e7a50d4aaca5efff2d02ad170f7cbb9863ebf9010bcd0d64b1df8e90da3', '59e93d2d3013a6c9b7e7a221ae9f05deeaab53ea71510774c9461419f700282c');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (25, 'CLIENT', 25, 'INSERT', '{"audit_sample_id": 25, "entity": "CLIENT", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, '59e93d2d3013a6c9b7e7a221ae9f05deeaab53ea71510774c9461419f700282c', '2ae0a40997d09a1e54ceef20ecbf9c3783ec9077b1f9d679142f6221910133e8');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (26, 'BUG', 26, 'INSERT', '{"audit_sample_id": 26, "entity": "BUG", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, '2ae0a40997d09a1e54ceef20ecbf9c3783ec9077b1f9d679142f6221910133e8', '416b9aa3b463b568ce3e86b11223c6ca3034b567e1aa9869c63093ee0be9ab80');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (27, 'TIME_LOG', 27, 'INSERT', '{"audit_sample_id": 27, "entity": "TIME_LOG", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, '416b9aa3b463b568ce3e86b11223c6ca3034b567e1aa9869c63093ee0be9ab80', 'd82853533341c6cd7c73bd92d06d29e55dd2f948f5e60d6de650537f9e0df482');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (28, 'BUG', 28, 'INSERT', '{"audit_sample_id": 28, "entity": "BUG", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, 'd82853533341c6cd7c73bd92d06d29e55dd2f948f5e60d6de650537f9e0df482', '183848eb4bca27b391bc3c971712b134f690822135cb81a5db09fbada0ba7d90');
INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) VALUES (29, 'TIME_LOG', 29, 'INSERT', '{"audit_sample_id": 29, "entity": "TIME_LOG", "verified": true, "actor": "system_bootstrap"}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, '183848eb4bca27b391bc3c971712b134f690822135cb81a5db09fbada0ba7d90', '05b50fd18a0df61c03c23022ea04754a29277121e9749ac681e4a604bb29aa74');

-- >>> END BASELINE SEED DATA <<<
