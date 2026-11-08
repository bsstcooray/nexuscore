"""
NexusCore Work Monitoring & Telemetry Router
PDPA 2022 compliant activity monitoring, process rule evaluation and manager alerting.
"""

from datetime import datetime, timezone
from typing import Dict, Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.models import WorkSession, ActivityEvent, AppRule, Alert, Employee
from backend.app.schemas import WorkSessionStartRequest, WorkSessionStopRequest

router = APIRouter(prefix="/api/telemetry", tags=["Work Monitoring & Telemetry"])

@router.post("/session/start")
def start_work_session(payload: WorkSessionStartRequest, db: Session = Depends(get_db)):
    # Check if active session already open
    active = db.query(WorkSession).filter(
        WorkSession.employee_id == payload.employee_id,
        WorkSession.status == "active"
    ).first()
    if active:
        return {"status": "resumed", "session_id": active.session_id, "start_time": active.start_time.isoformat()}

    session = WorkSession(
        employee_id=payload.employee_id,
        task_id=payload.task_id,
        start_time=datetime.now(timezone.utc),
        status="active"
    )
    db.add(session)
    db.commit()
    db.refresh(session)
    return {"status": "started", "session_id": session.session_id, "start_time": session.start_time.isoformat()}

@router.post("/session/stop")
def stop_work_session(payload: WorkSessionStopRequest, db: Session = Depends(get_db)):
    session = db.query(WorkSession).filter(WorkSession.session_id == payload.session_id).first()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found.")
    
    session.status = "completed"
    session.end_time = datetime.now(timezone.utc)
    db.commit()
    return {"status": "completed", "session_id": session.session_id}

@router.post("/heartbeat")
def record_telemetry_heartbeat(payload: Dict[str, Any], db: Session = Depends(get_db)):
    """Receives desktop agent process telemetry (PDPA 2022 compliant)."""
    session_id = payload.get("session_id", 1)
    employee_id = payload.get("employee_id", 1)
    process_name = payload.get("process_name", "Code.exe")
    window_title = payload.get("window_title", "NexusCore Workspace")
    duration = payload.get("duration_seconds", 30)

    # Classify against APP_RULE
    rule = db.query(AppRule).filter(
        (AppRule.pattern.ilike(f"%{process_name}%")) | (AppRule.pattern.ilike(f"%{window_title}%"))
    ).first()

    is_productive = rule.is_productive if rule else True

    # Record event
    event = ActivityEvent(
        session_id=session_id,
        employee_id=employee_id,
        event_timestamp=datetime.now(timezone.utc),
        window_title=window_title[:250],
        process_name=process_name[:100],
        is_productive=is_productive,
        duration_seconds=duration
    )
    db.add(event)

    # Update session minutes
    session = db.query(WorkSession).filter(WorkSession.session_id == session_id).first()
    alert_raised = False
    if session:
        mins = round(duration / 60.0)
        session.total_duration_minutes += mins
        if is_productive:
            session.productive_duration_minutes += mins
        else:
            session.idle_duration_minutes += mins
            if session.idle_duration_minutes >= 10:
                # Trigger Manager Alert
                alert = Alert(
                    session_id=session_id,
                    employee_id=employee_id,
                    alert_type="non_work_application_threshold",
                    severity="high",
                    description=f"Logged {session.idle_duration_minutes} minutes non-work activity in '{process_name}'."
                )
                db.add(alert)
                alert_raised = True

    db.commit()
    return {
        "status": "recorded",
        "is_productive": is_productive,
        "alert_raised": alert_raised
    }

@router.get("/alerts")
def list_manager_alerts(limit: int = 10, db: Session = Depends(get_db)):
    alerts = db.query(Alert).order_by(Alert.alert_id.desc()).limit(limit).all()
    return [
        {
            "alert_id": a.alert_id,
            "employee_id": a.employee_id,
            "employee_name": a.employee.full_name if a.employee else f"Employee #{a.employee_id}",
            "alert_type": a.alert_type,
            "severity": a.severity,
            "description": a.description,
            "status": a.status,
            "created_at": a.created_at.isoformat() if a.created_at else None
        }
        for a in alerts
    ]
