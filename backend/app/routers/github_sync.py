"""
NexusCore GitHub Sync & Staging Queue Router
Decoupled staging architecture: external webhooks write ONLY to staging buffer.
"""

from datetime import datetime, timezone
from typing import Dict, Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.models import SyncRun, GithubStaging, Bug, GithubReference, Project

router = APIRouter(prefix="/api/github", tags=["GitHub Staging & Bug Sync"])

@router.get("/staging-queue")
def list_staging_queue(db: Session = Depends(get_db)):
    items = db.query(GithubStaging).order_by(GithubStaging.staging_id.desc()).limit(20).all()
    return [
        {
            "staging_id": item.staging_id,
            "issue_number": item.issue_number,
            "title": item.title,
            "state": item.state,
            "staging_status": item.staging_status,
            "ingested_at": item.ingested_at.isoformat() if item.ingested_at else None,
            "validation_error": item.validation_error
        }
        for item in items
    ]

@router.post("/webhook")
def receive_github_webhook(payload: Dict[str, Any], db: Session = Depends(get_db)):
    """Receives GitHub Webhook events and buffers them strictly into GITHUB_STAGING."""
    issue = payload.get("issue")
    if not issue:
        return {"status": "ignored", "reason": "No issue payload in webhook."}

    # Find or create active sync run
    sync_run = db.query(SyncRun).filter(SyncRun.status == "processing").first()
    if not sync_run:
        sync_run = SyncRun(source="github-webhook", status="processing", items_fetched=1)
        db.add(sync_run)
        db.commit()
        db.refresh(sync_run)
    else:
        sync_run.items_fetched += 1

    # Buffer into GITHUB_STAGING
    staging_entry = GithubStaging(
        run_id=sync_run.run_id,
        issue_number=issue.get("number", 0),
        title=issue.get("title", "Untitled Issue"),
        state=issue.get("state", "open"),
        raw_payload=payload,
        staging_status="pending"
    )
    db.add(staging_entry)
    db.commit()

    return {
        "status": "buffered",
        "staging_id": staging_entry.staging_id,
        "message": "Payload securely staged. Main database isolated."
    }

@router.post("/process-staging")
def process_staging_queue(db: Session = Depends(get_db)):
    """Executes single-transaction validation and upsert from staging queue into BUG."""
    pending_items = db.query(GithubStaging).filter(GithubStaging.staging_status == "pending").all()
    default_proj = db.query(Project).filter(Project.status == "active").first()
    proj_id = default_proj.project_id if default_proj else 1

    synced = 0
    rejected = 0

    for item in pending_items:
        if not item.title or len(item.title.strip()) == 0:
            item.staging_status = "rejected"
            item.validation_error = "Validation Failed: Empty title."
            rejected += 1
            continue

        # Upsert Bug
        bug = db.query(Bug).filter(Bug.github_issue_id == item.issue_number).first()
        if not bug:
            bug = Bug(
                project_id=proj_id,
                title=item.title,
                severity="high" if "critical" in item.title.lower() or "deadlock" in item.title.lower() else "medium",
                status="closed" if item.state == "closed" else "reported",
                steps_to_reproduce=f"Ingested from GitHub Issue #{item.issue_number}",
                github_issue_id=item.issue_number,
                reported_by="github_sync_worker"
            )
            db.add(bug)
        else:
            bug.title = item.title
            bug.status = "closed" if item.state == "closed" else bug.status

        item.staging_status = "upserted"
        synced += 1

    db.commit()
    return {
        "status": "completed",
        "items_synced": synced,
        "items_rejected": rejected
    }
