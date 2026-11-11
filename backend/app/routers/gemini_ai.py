"""
NexusCore Google Gemini AI Agent Router
Natural language Text-to-SQL synthesis, sprint summaries, and AI_INTERACTION_LOG auditing.
"""

import time
from typing import Dict, Any, Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.models import AIInteractionLog
from backend.app.schemas import GeminiQueryRequest, GeminiQueryResponse
from services.gemini_service import execute_gemini_interaction

router = APIRouter(prefix="/api/gemini", tags=["Google Gemini AI Assistant"])

@router.post("/query", response_model=GeminiQueryResponse)
def query_gemini_assistant(payload: GeminiQueryRequest, db: Session = Depends(get_db)):
    # Call the GenAI interaction service with automatic updated SQL database context
    result = execute_gemini_interaction(
        prompt=payload.prompt,
        user_api_key=payload.api_key
    )
    
    sql = result.get("generated_sql")
    summary = result.get("response_summary", "")
    latency_ms = result.get("latency_ms", 120)
    tokens = result.get("tokens_used", 250)
    model_version = result.get("model_version", "gemini-3.8-flash")

    # Audit the AI Interaction in AI_INTERACTION_LOG (Proposal Requirement)
    try:
        ai_log = AIInteractionLog(
            user_id=1,
            prompt_text=payload.prompt,
            generated_sql=sql,
            response_summary=summary[:1000] if summary else "",
            latency_ms=latency_ms,
            tokens_used=tokens,
            model_version=model_version,
            status="success"
        )
        db.add(ai_log)
        db.commit()
    except Exception as e:
        print(f"[!] Warning logging AI interaction to database: {e}")
        db.rollback()

    return GeminiQueryResponse(
        prompt=payload.prompt,
        generated_sql=sql,
        response_summary=summary,
        latency_ms=latency_ms,
        tokens_used=tokens,
        model_version=model_version
    )

@router.get("/logs")
def list_ai_logs(limit: int = 15, db: Session = Depends(get_db)):
    logs = db.query(AIInteractionLog).order_by(AIInteractionLog.interaction_id.desc()).limit(limit).all()
    return [
        {
            "id": l.interaction_id,
            "prompt": l.prompt_text,
            "generated_sql": l.generated_sql,
            "response": l.response_summary,
            "latency_ms": l.latency_ms,
            "tokens": l.tokens_used,
            "created_at": l.created_at.isoformat() if l.created_at else None
        }
        for l in logs
    ]
