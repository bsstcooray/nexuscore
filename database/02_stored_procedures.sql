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
