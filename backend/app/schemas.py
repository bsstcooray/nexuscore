"""
NexusCore Pydantic Validation Schemas
Request and response serializations for all endpoints.
"""

from datetime import datetime, date
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field

# Authentication
class LoginRequest(BaseModel):
    username: str
    password: str
    totp_code: Optional[str] = None

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    username: str
    role: str
    mfa_required: bool = False
    full_name: Optional[str] = None
    designation: Optional[str] = None

class MFASetupResponse(BaseModel):
    secret: str
    otpauth_url: str

class MFAVerifyRequest(BaseModel):
    code: str

# Projects & Tasks
class TaskCreate(BaseModel):
    project_id: int
    title: str
    description: Optional[str] = None
    priority: str = "medium"
    status: str = "todo"
    estimated_hours: float = 4.0
    sprint_number: int = 1
    deadline: datetime
    assigned_to: Optional[int] = None

class TaskUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    priority: Optional[str] = None
    status: Optional[str] = None
    assigned_to: Optional[int] = None
    actual_hours: Optional[float] = None

class TaskStatusUpdate(BaseModel):
    status: str
    notes: Optional[str] = None

# Smart Assignee
class SmartAssignRequest(BaseModel):
    task_id: int
    assigned_by: str = "smart_engine"

class SmartAssignResponse(BaseModel):
    task_id: int
    assigned_employee_id: int
    match_score: float
    message: str

# GitHub Staging
class GitHubWebhookPayload(BaseModel):
    action: str
    issue: Dict[str, Any]
    repository: Optional[Dict[str, Any]] = None

class GitHubSyncRunRequest(BaseModel):
    repo: Optional[str] = None
    dry_run: bool = False

# Telemetry
class WorkSessionStartRequest(BaseModel):
    employee_id: int
    task_id: Optional[int] = None

class WorkSessionStopRequest(BaseModel):
    session_id: int

class ActivityEventBatch(BaseModel):
    session_id: int
    employee_id: int
    events: List[Dict[str, Any]]

# Audit
class TamperSimulateRequest(BaseModel):
    audit_id: int
    tampered_action: str = "UNAUTHORIZED_TAMPER"

# AI
class GeminiQueryRequest(BaseModel):
    prompt: str
    project_id: Optional[int] = None
    context: Optional[str] = "general"
    api_key: Optional[str] = None

class GeminiQueryResponse(BaseModel):
    prompt: str
    generated_sql: Optional[str]
    response_summary: str
    latency_ms: int
    tokens_used: int
    model_version: str
