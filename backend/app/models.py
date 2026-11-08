"""
NexusCore SQLAlchemy Models (All 27 Normalized Entities)
3NF / BCNF Compliant Object Relational Mapping
Group AC - CS304.3 Advanced Database Management Systems
"""

from datetime import datetime, timezone
from sqlalchemy import (
    Column, Integer, BigInteger, String, Text, Numeric, Boolean,
    Date, DateTime, ForeignKey, Index, JSON
)
from sqlalchemy.orm import relationship
from backend.app.database import Base

def utcnow():
    return datetime.now(timezone.utc)

# ============================================================================
# GROUP 1: CORE BUSINESS ENTITIES (11 Models)
# ============================================================================

class Client(Base):
    __tablename__ = "client"

    client_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    company_name = Column(String(150), unique=True, nullable=False, index=True)
    industry = Column(String(100), nullable=False)
    contact_email = Column(String(255), unique=True, nullable=False)
    contact_phone = Column(String(30), nullable=True)
    billing_tier = Column(String(20), default="standard", nullable=False) # standard, premium, enterprise
    sla_response_hours = Column(Integer, default=24, nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)

    projects = relationship("Project", back_populates="client", cascade="all, delete-orphan")
    interactions = relationship("ClientInteraction", back_populates="client", cascade="all, delete-orphan")


class ClientInteraction(Base):
    __tablename__ = "client_interaction"

    interaction_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    client_id = Column(Integer, ForeignKey("client.client_id", ondelete="CASCADE"), nullable=False)
    interaction_type = Column(String(50), nullable=False) # meeting, call, email, review, support
    summary = Column(String(255), nullable=False)
    details = Column(Text, nullable=True)
    sentiment_score = Column(Numeric(3, 2), nullable=True)
    logged_by = Column(String(100), nullable=False)
    interaction_date = Column(DateTime, default=utcnow, nullable=False)

    client = relationship("Client", back_populates="interactions")


class Project(Base):
    __tablename__ = "project"

    project_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    client_id = Column(Integer, ForeignKey("client.client_id", ondelete="RESTRICT"), nullable=False)
    code = Column(String(20), unique=True, nullable=False, index=True)
    name = Column(String(150), nullable=False)
    description = Column(Text, nullable=True)
    status = Column(String(20), default="planning", nullable=False) # planning, active, on_hold, completed, archived
    budget_allocated = Column(Numeric(12, 2), default=0.00, nullable=False)
    budget_spent = Column(Numeric(12, 2), default=0.00, nullable=False)
    health_score = Column(Integer, default=100, nullable=False)
    risk_level = Column(String(20), default="low", nullable=False) # low, moderate, high, critical
    start_date = Column(Date, nullable=False)
    target_end_date = Column(Date, nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    client = relationship("Client", back_populates="projects")
    tasks = relationship("Task", back_populates="project", cascade="all, delete-orphan")
    bugs = relationship("Bug", back_populates="project", cascade="all, delete-orphan")
    assignments = relationship("ProjectAssignment", back_populates="project", cascade="all, delete-orphan")
    metric_snapshots = relationship("ProjectMetricSnapshot", back_populates="project", cascade="all, delete-orphan")


class Employee(Base):
    __tablename__ = "employee"

    employee_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    full_name = Column(String(150), nullable=False)
    work_email = Column(String(255), unique=True, nullable=False, index=True)
    designation = Column(String(100), nullable=False)
    department = Column(String(80), nullable=False) # engineering, design, qa, devops, admin, leadership
    hourly_rate = Column(Numeric(8, 2), nullable=False)
    weekly_capacity_hours = Column(Numeric(4, 1), default=40.0, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    hire_date = Column(Date, default=datetime.now().date, nullable=False)

    user = relationship("AppUser", back_populates="employee", uselist=False, cascade="all, delete-orphan")
    assignments = relationship("ProjectAssignment", back_populates="employee")
    tasks = relationship("Task", back_populates="assignee")
    bugs = relationship("Bug", back_populates="assignee")
    time_logs = relationship("TimeLog", back_populates="employee")
    skills = relationship("EmployeeSkill", back_populates="employee", cascade="all, delete-orphan")
    work_sessions = relationship("WorkSession", back_populates="employee", cascade="all, delete-orphan")
    alerts = relationship("Alert", back_populates="employee", cascade="all, delete-orphan")


class AppUser(Base):
    __tablename__ = "app_user"

    user_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    employee_id = Column(Integer, ForeignKey("employee.employee_id", ondelete="CASCADE"), unique=True, nullable=True)
    username = Column(String(80), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    role = Column(String(30), default="developer_qa", nullable=False) # ceo_admin, project_manager, developer_qa, client_restricted
    mfa_secret = Column(String(64), nullable=True)
    mfa_enabled = Column(Boolean, default=False, nullable=False)
    is_locked = Column(Boolean, default=False, nullable=False)
    failed_login_count = Column(Integer, default=0, nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    employee = relationship("Employee", back_populates="user")
    sessions = relationship("UserSession", back_populates="user", cascade="all, delete-orphan")
    ai_logs = relationship("AIInteractionLog", back_populates="user")


class ProjectAssignment(Base):
    __tablename__ = "project_assignment"

    assignment_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    project_id = Column(Integer, ForeignKey("project.project_id", ondelete="CASCADE"), nullable=False)
    employee_id = Column(Integer, ForeignKey("employee.employee_id", ondelete="RESTRICT"), nullable=False)
    assigned_role = Column(String(80), nullable=False)
    allocation_percentage = Column(Integer, default=100, nullable=False)
    joined_date = Column(Date, default=datetime.now().date, nullable=False)

    project = relationship("Project", back_populates="assignments")
    employee = relationship("Employee", back_populates="assignments")


class Task(Base):
    __tablename__ = "task"

    task_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    project_id = Column(Integer, ForeignKey("project.project_id", ondelete="CASCADE"), nullable=False)
    assigned_to = Column(Integer, ForeignKey("employee.employee_id", ondelete="SET NULL"), nullable=True)
    title = Column(String(200), nullable=False, index=True)
    description = Column(Text, nullable=True)
    priority = Column(String(20), default="medium", nullable=False) # low, medium, high, critical
    status = Column(String(20), default="todo", nullable=False) # backlog, todo, in_progress, review, completed, blocked
    estimated_hours = Column(Numeric(5, 2), default=4.0, nullable=False)
    actual_hours = Column(Numeric(5, 2), default=0.0, nullable=False)
    sprint_number = Column(Integer, default=1, nullable=False)
    deadline = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    project = relationship("Project", back_populates="tasks")
    assignee = relationship("Employee", back_populates="tasks")
    bugs = relationship("Bug", back_populates="task")
    time_logs = relationship("TimeLog", back_populates="task", cascade="all, delete-orphan")
    skills = relationship("TaskSkill", back_populates="task", cascade="all, delete-orphan")
    dependencies = relationship("TaskDependency", foreign_keys="TaskDependency.task_id", back_populates="task", cascade="all, delete-orphan")
    status_history = relationship("TaskStatusHistory", back_populates="task", cascade="all, delete-orphan")


class Bug(Base):
    __tablename__ = "bug"

    bug_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    project_id = Column(Integer, ForeignKey("project.project_id", ondelete="CASCADE"), nullable=False)
    task_id = Column(Integer, ForeignKey("task.task_id", ondelete="SET NULL"), nullable=True)
    title = Column(String(255), nullable=False)
    severity = Column(String(20), default="medium", nullable=False) # low, medium, high, critical
    status = Column(String(20), default="reported", nullable=False) # reported, triaged, in_progress, resolved, closed
    steps_to_reproduce = Column(Text, nullable=True)
    github_issue_id = Column(Integer, unique=True, nullable=True, index=True)
    reported_by = Column(String(100), nullable=False)
    assigned_to = Column(Integer, ForeignKey("employee.employee_id", ondelete="SET NULL"), nullable=True)
    resolved_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    project = relationship("Project", back_populates="bugs")
    task = relationship("Task", back_populates="bugs")
    assignee = relationship("Employee", back_populates="bugs")


class TimeLog(Base):
    __tablename__ = "time_log"

    log_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    employee_id = Column(Integer, ForeignKey("employee.employee_id", ondelete="RESTRICT"), nullable=False)
    task_id = Column(Integer, ForeignKey("task.task_id", ondelete="CASCADE"), nullable=False)
    hours_spent = Column(Numeric(4, 2), nullable=False)
    work_summary = Column(Text, nullable=False)
    is_billable = Column(Boolean, default=True, nullable=False)
    logged_date = Column(Date, default=datetime.now().date, nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    employee = relationship("Employee", back_populates="time_logs")
    task = relationship("Task", back_populates="time_logs")


class GithubReference(Base):
    __tablename__ = "github_reference"

    reference_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    reference_type = Column(String(20), nullable=False) # task, bug
    item_id = Column(Integer, nullable=False)
    github_repo = Column(String(150), nullable=False)
    github_pull_or_issue_num = Column(Integer, nullable=False)
    html_url = Column(String(500), nullable=False)
    last_synced_at = Column(DateTime, default=utcnow, nullable=False)


class AuditLog(Base):
    __tablename__ = "audit_log"

    audit_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    table_name = Column(String(80), nullable=False, index=True)
    record_id = Column(Integer, nullable=False)
    action = Column(String(10), nullable=False) # INSERT, UPDATE, DELETE
    old_data = Column(JSON, nullable=True)
    new_data = Column(JSON, nullable=True)
    changed_by = Column(String(100), nullable=False)
    changed_at = Column(DateTime, default=utcnow, nullable=False, index=True)
    prev_hash = Column(String(64), nullable=False)
    current_hash = Column(String(64), nullable=False, index=True)


# ============================================================================
# GROUP 2: GITHUB INTEGRATION & DECOUPLED STAGING (2 Models)
# ============================================================================

class SyncRun(Base):
    __tablename__ = "sync_run"

    run_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    source = Column(String(80), default="github-api", nullable=False)
    status = Column(String(20), default="pending", nullable=False) # pending, processing, completed, failed
    items_fetched = Column(Integer, default=0, nullable=False)
    items_synced = Column(Integer, default=0, nullable=False)
    items_failed = Column(Integer, default=0, nullable=False)
    error_log = Column(Text, nullable=True)
    started_at = Column(DateTime, default=utcnow, nullable=False)
    completed_at = Column(DateTime, nullable=True)

    staging_items = relationship("GithubStaging", back_populates="sync_run", cascade="all, delete-orphan")


class GithubStaging(Base):
    __tablename__ = "github_staging"

    staging_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    run_id = Column(Integer, ForeignKey("sync_run.run_id", ondelete="CASCADE"), nullable=False)
    issue_number = Column(Integer, nullable=False)
    title = Column(String(255), nullable=False)
    state = Column(String(30), nullable=False)
    raw_payload = Column(JSON, nullable=False)
    staging_status = Column(String(20), default="pending", nullable=False) # pending, validated, upserted, rejected
    validation_error = Column(Text, nullable=True)
    ingested_at = Column(DateTime, default=utcnow, nullable=False)

    sync_run = relationship("SyncRun", back_populates="staging_items")


# ============================================================================
# GROUP 3: WORK MONITORING & TELEMETRY (4 Models)
# ============================================================================

class WorkSession(Base):
    __tablename__ = "work_session"

    session_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    employee_id = Column(Integer, ForeignKey("employee.employee_id", ondelete="CASCADE"), nullable=False)
    task_id = Column(Integer, ForeignKey("task.task_id", ondelete="SET NULL"), nullable=True)
    start_time = Column(DateTime, default=utcnow, nullable=False)
    end_time = Column(DateTime, nullable=True)
    total_duration_minutes = Column(Integer, default=0, nullable=False)
    productive_duration_minutes = Column(Integer, default=0, nullable=False)
    idle_duration_minutes = Column(Integer, default=0, nullable=False)
    status = Column(String(20), default="active", nullable=False) # active, paused, completed

    employee = relationship("Employee", back_populates="work_sessions")
    events = relationship("ActivityEvent", back_populates="session", cascade="all, delete-orphan")
    alerts = relationship("Alert", back_populates="session")


class ActivityEvent(Base):
    __tablename__ = "activity_event"

    event_id = Column(BigInteger, primary_key=True, index=True, autoincrement=True)
    session_id = Column(Integer, ForeignKey("work_session.session_id", ondelete="CASCADE"), nullable=False)
    employee_id = Column(Integer, nullable=False)
    event_timestamp = Column(DateTime, default=utcnow, nullable=False, index=True)
    window_title = Column(String(255), nullable=False)
    process_name = Column(String(120), nullable=False)
    is_productive = Column(Boolean, default=True, nullable=False)
    duration_seconds = Column(Integer, default=10, nullable=False)

    session = relationship("WorkSession", back_populates="events")


class AppRule(Base):
    __tablename__ = "app_rule"

    rule_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    pattern = Column(String(120), unique=True, nullable=False)
    match_type = Column(String(20), nullable=False) # process, window_title_regex, exact
    rule_category = Column(String(50), nullable=False) # ide, terminal, documentation, communication, non_work, entertainment
    is_productive = Column(Boolean, default=True, nullable=False)
    alert_threshold_seconds = Column(Integer, default=300, nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)


class Alert(Base):
    __tablename__ = "alert"

    alert_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    session_id = Column(Integer, ForeignKey("work_session.session_id", ondelete="CASCADE"), nullable=True)
    employee_id = Column(Integer, ForeignKey("employee.employee_id", ondelete="CASCADE"), nullable=False)
    rule_id = Column(Integer, ForeignKey("app_rule.rule_id", ondelete="SET NULL"), nullable=True)
    alert_type = Column(String(50), nullable=False)
    severity = Column(String(20), default="medium", nullable=False) # info, low, medium, high, critical
    description = Column(Text, nullable=False)
    status = Column(String(20), default="active", nullable=False) # active, acknowledged, dismissed, resolved
    acknowledged_by = Column(String(100), nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    employee = relationship("Employee", back_populates="alerts")
    session = relationship("WorkSession", back_populates="alerts")


# ============================================================================
# GROUP 4: INTELLIGENCE & ANALYTICS (7 Models)
# ============================================================================

class Skill(Base):
    __tablename__ = "skill"

    skill_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    name = Column(String(80), unique=True, nullable=False)
    category = Column(String(50), nullable=False) # frontend, backend, database, devops, testing, ai_ml, design
    description = Column(Text, nullable=True)

    employee_skills = relationship("EmployeeSkill", back_populates="skill", cascade="all, delete-orphan")
    task_skills = relationship("TaskSkill", back_populates="skill", cascade="all, delete-orphan")


class EmployeeSkill(Base):
    __tablename__ = "employee_skill"

    emp_skill_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    employee_id = Column(Integer, ForeignKey("employee.employee_id", ondelete="CASCADE"), nullable=False)
    skill_id = Column(Integer, ForeignKey("skill.skill_id", ondelete="CASCADE"), nullable=False)
    proficiency_level = Column(Integer, nullable=False) # 1 - 5
    years_experience = Column(Numeric(3, 1), default=1.0, nullable=False)

    employee = relationship("Employee", back_populates="skills")
    skill = relationship("Skill", back_populates="employee_skills")


class TaskSkill(Base):
    __tablename__ = "task_skill"

    task_skill_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    task_id = Column(Integer, ForeignKey("task.task_id", ondelete="CASCADE"), nullable=False)
    skill_id = Column(Integer, ForeignKey("skill.skill_id", ondelete="CASCADE"), nullable=False)
    required_level = Column(Integer, default=3, nullable=False) # 1 - 5

    task = relationship("Task", back_populates="skills")
    skill = relationship("Skill", back_populates="task_skills")


class TaskDependency(Base):
    __tablename__ = "task_dependency"

    dependency_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    task_id = Column(Integer, ForeignKey("task.task_id", ondelete="CASCADE"), nullable=False)
    depends_on_task_id = Column(Integer, ForeignKey("task.task_id", ondelete="CASCADE"), nullable=False)
    dependency_type = Column(String(30), default="finish_to_start", nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    task = relationship("Task", foreign_keys=[task_id], back_populates="dependencies")


class TaskStatusHistory(Base):
    __tablename__ = "task_status_history"

    history_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    task_id = Column(Integer, ForeignKey("task.task_id", ondelete="CASCADE"), nullable=False)
    old_status = Column(String(20), nullable=True)
    new_status = Column(String(20), nullable=False)
    changed_by = Column(String(100), nullable=False)
    notes = Column(Text, nullable=True)
    changed_at = Column(DateTime, default=utcnow, nullable=False)

    task = relationship("Task", back_populates="status_history")


class ProjectMetricSnapshot(Base):
    __tablename__ = "project_metric_snapshot"

    snapshot_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    project_id = Column(Integer, ForeignKey("project.project_id", ondelete="CASCADE"), nullable=False)
    snapshot_date = Column(Date, default=datetime.now().date, nullable=False)
    burndown_percentage = Column(Numeric(5, 2), nullable=False)
    cycle_time_days = Column(Numeric(4, 2), nullable=False)
    open_bugs_count = Column(Integer, default=0, nullable=False)
    velocity_points = Column(Integer, default=0, nullable=False)
    risk_score = Column(Integer, default=0, nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    project = relationship("Project", back_populates="metric_snapshots")


class AssignmentSuggestion(Base):
    __tablename__ = "assignment_suggestion"

    suggestion_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    task_id = Column(Integer, ForeignKey("task.task_id", ondelete="CASCADE"), nullable=False)
    employee_id = Column(Integer, ForeignKey("employee.employee_id", ondelete="CASCADE"), nullable=False)
    match_score = Column(Numeric(5, 2), nullable=False)
    skill_fit_score = Column(Numeric(5, 2), nullable=False)
    workload_score = Column(Numeric(5, 2), nullable=False)
    ranking = Column(Integer, nullable=False)
    recommendation_reason = Column(Text, nullable=True)
    generated_at = Column(DateTime, default=utcnow, nullable=False)


# ============================================================================
# GROUP 5: SECURITY & SESSIONS (2 Models)
# ============================================================================

class UserSession(Base):
    __tablename__ = "user_session"

    session_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("app_user.user_id", ondelete="CASCADE"), nullable=False)
    token_hash = Column(String(64), unique=True, nullable=False, index=True)
    ip_address = Column(String(50), nullable=True)
    user_agent = Column(Text, nullable=True)
    expires_at = Column(DateTime, nullable=False)
    is_revoked = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    user = relationship("AppUser", back_populates="sessions")


class LoginAttempt(Base):
    __tablename__ = "login_attempt"

    attempt_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    username = Column(String(80), nullable=False, index=True)
    ip_address = Column(String(50), nullable=True)
    is_success = Column(Boolean, default=False, nullable=False)
    failure_reason = Column(String(100), nullable=True)
    attempted_at = Column(DateTime, default=utcnow, nullable=False)


# ============================================================================
# GROUP 6: ARTIFICIAL INTELLIGENCE (1 Model)
# ============================================================================

class AIInteractionLog(Base):
    __tablename__ = "ai_interaction_log"

    interaction_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("app_user.user_id", ondelete="SET NULL"), nullable=True)
    prompt_text = Column(Text, nullable=False)
    generated_sql = Column(Text, nullable=True)
    response_summary = Column(Text, nullable=False)
    latency_ms = Column(Integer, nullable=False)
    tokens_used = Column(Integer, nullable=False)
    model_version = Column(String(50), default="gemini-1.5-flash", nullable=False)
    status = Column(String(20), default="success", nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)

    user = relationship("AppUser", back_populates="ai_logs")
