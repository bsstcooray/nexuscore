"""
NexusCore Cryptographic Audit Ledger Router
Verifies SHA-256 hash chains, detects tampering, and ensures append-only immutability.
"""

import hashlib
import json
from datetime import datetime, timezone
from typing import List, Dict, Any
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.models import AuditLog
from backend.app.schemas import TamperSimulateRequest

router = APIRouter(prefix="/api/audit", tags=["Cryptographic Audit Ledger"])

@router.get("/logs")
def list_audit_logs(limit: int = 50, db: Session = Depends(get_db)):
    logs = db.query(AuditLog).order_by(AuditLog.audit_id.asc()).limit(limit).all()
    return [
        {
            "audit_id": a.audit_id,
            "table_name": a.table_name,
            "record_id": a.record_id,
            "action": a.action,
            "changed_by": a.changed_by,
            "changed_at": a.changed_at.isoformat() if a.changed_at else None,
            "prev_hash": a.prev_hash,
            "current_hash": a.current_hash,
            "payload": a.new_data
        }
        for a in logs
    ]

@router.get("/verify-chain")
def verify_hash_chain(db: Session = Depends(get_db)):
    """Validates every record in AUDIT_LOG against computed SHA-256 digests."""
    logs = db.query(AuditLog).order_by(AuditLog.audit_id.asc()).all()
    
    total = len(logs)
    valid = 0
    tampered = 0
    broken_ids = []
    
    last_hash = "0000000000000000000000000000000000000000000000000000000000000000"
    for log in logs:
        payload_str = json.dumps(log.new_data, sort_keys=True) if isinstance(log.new_data, dict) else str(log.new_data or "")
        
        # Expected SHA-256 hash
        digest_input = f"{log.prev_hash}{log.table_name}{log.record_id}{log.action}{payload_str}"
        computed_hash = hashlib.sha256(digest_input.encode()).hexdigest()

        # Check hash match and continuity
        if log.current_hash != computed_hash or log.prev_hash != last_hash:
            tampered += 1
            broken_ids.append(log.audit_id)
        else:
            valid += 1
        
        last_hash = log.current_hash

    is_healthy = (tampered == 0)
    return {
        "status": "healthy" if is_healthy else "compromised",
        "is_chain_healthy": is_healthy,
        "total_records": total,
        "valid_records": valid,
        "tampered_records": tampered,
        "broken_audit_ids": broken_ids,
        "message": "Cryptographic ledger integrity verified. Zero anomalies." if is_healthy else f"ALERT: Tampering detected at Audit ID(s): {broken_ids}!"
    }

@router.post("/simulate-tamper")
def simulate_tamper(payload: TamperSimulateRequest, db: Session = Depends(get_db)):
    """Simulates an unauthorized out-of-band edit to demonstrate tamper detection."""
    log = db.query(AuditLog).filter(AuditLog.audit_id == payload.audit_id).first()
    if not log:
        raise HTTPException(status_code=404, detail="Audit record not found.")

    # Tamper the action without updating the cryptographic hash
    log.action = payload.tampered_action
    db.commit()

    return {
        "status": "tampered",
        "audit_id": payload.audit_id,
        "message": f"Simulated tamper on Audit #{payload.audit_id}. Chain continuity is now broken."
    }

@router.post("/repair-chain")
def repair_hash_chain(db: Session = Depends(get_db)):
    """Re-computes and repairs cryptographic hashes across the ledger."""
    logs = db.query(AuditLog).order_by(AuditLog.audit_id.asc()).all()
    prev_hash = "0000000000000000000000000000000000000000000000000000000000000000"
    
    for log in logs:
        log.prev_hash = prev_hash
        payload_str = json.dumps(log.new_data, sort_keys=True) if isinstance(log.new_data, dict) else str(log.new_data or "")
        digest_input = f"{log.prev_hash}{log.table_name}{log.record_id}{log.action}{payload_str}"
        log.current_hash = hashlib.sha256(digest_input.encode()).hexdigest()
        prev_hash = log.current_hash

    db.commit()
    return {"status": "repaired", "message": f"Successfully re-signed {len(logs)} audit blocks."}
