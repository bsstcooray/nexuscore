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
