"""
NexusCore Projects, Sprints & Kanban Tasks Router
Full CRUD, DAG dependency enforcement, and status history tracking.
"""

from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.models import (
    Project, Task, Bug, TaskDependency, TaskStatusHistory, Employee
)
from backend.app.schemas import TaskCreate, TaskUpdate, TaskStatusUpdate

router = APIRouter(prefix="/api/projects", tags=["Projects, Sprints & Kanban"])

@router.get("")
def list_projects(db: Session = Depends(get_db)):
    projects = db.query(Project).all()
    return [
        {
            "project_id": p.project_id,
            "code": p.code,
            "name": p.name,
            "status": p.status,
            "health_score": p.health_score,
            "risk_level": p.risk_level,
            "budget_allocated": float(p.budget_allocated),
            "budget_spent": float(p.budget_spent),
            "client_id": p.client_id
        }
        for p in projects
    ]

@router.get("/{project_id}/kanban")
def get_project_kanban(project_id: int, sprint: Optional[int] = None, db: Session = Depends(get_db)):
    query = db.query(Task).filter(Task.project_id == project_id)
    if sprint:
        query = query.filter(Task.sprint_number == sprint)
    tasks = query.all()

    kanban = {"todo": [], "in_progress": [], "review": [], "completed": []}
    for t in tasks:
        item = {
            "task_id": t.task_id,
            "title": t.title,
            "priority": t.priority,
            "status": t.status,
            "estimated_hours": float(t.estimated_hours),
            "actual_hours": float(t.actual_hours),
            "deadline": t.deadline.isoformat() if t.deadline else None,
            "assigned_to": t.assigned_to,
            "assignee_name": t.assignee.full_name if t.assignee else "Unassigned"
        }
        if t.status in kanban:
            kanban[t.status].append(item)
        else:
            kanban["todo"].append(item)

    return kanban

@router.post("/tasks", status_code=status.HTTP_201_CREATED)
def create_task(payload: TaskCreate, db: Session = Depends(get_db)):
    new_task = Task(
        project_id=payload.project_id,
        title=payload.title,
        description=payload.description,
        priority=payload.priority,
        status=payload.status,
        estimated_hours=payload.estimated_hours,
        sprint_number=payload.sprint_number,
        deadline=payload.deadline,
        assigned_to=payload.assigned_to
    )
    db.add(new_task)
    db.commit()
    db.refresh(new_task)
    return {"status": "created", "task_id": new_task.task_id}

@router.put("/tasks/{task_id}/status")
def update_task_status(task_id: int, payload: TaskStatusUpdate, db: Session = Depends(get_db)):
    task = db.query(Task).filter(Task.task_id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="Task not found.")

    old_status = task.status
    new_status = payload.status

    # DAG Dependency Check (Trigger logic simulation)
    if new_status in ("review", "completed") and old_status != new_status:
        deps = db.query(TaskDependency).filter(TaskDependency.task_id == task_id).all()
        for d in deps:
            prereq = db.query(Task).filter(Task.task_id == d.depends_on_task_id).first()
            if prereq and prereq.status != "completed":
                raise HTTPException(
                    status_code=400,
                    detail=f"Dependency Violation: Task #{task_id} cannot transition to '{new_status}' because prerequisite Task #{prereq.task_id} ('{prereq.title}') is '{prereq.status}'."
                )

    task.status = new_status
    if new_status == "completed" and task.actual_hours == 0:
        task.actual_hours = task.estimated_hours

    # Record history
    history = TaskStatusHistory(
        task_id=task.task_id,
        old_status=old_status,
        new_status=new_status,
        changed_by="kanban_user",
        notes=payload.notes or f"Updated status to {new_status}"
    )
    db.add(history)
    db.commit()

    return {"status": "success", "task_id": task_id, "new_status": new_status}
