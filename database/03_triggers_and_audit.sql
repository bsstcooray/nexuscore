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
