"""
NexusCore FastAPI Automated Pytest Suite
Tests authentication, stored procedure runners, and security audit ledger.
"""

import pytest
from fastapi.testclient import TestClient
from backend.app.main import app

client = TestClient(app)

def test_health_endpoint():
    res = client.get("/api/health")
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "healthy"
    assert data["system"] == "NexusCore"

def test_overview_metrics():
    res = client.get("/api/overview/metrics")
    assert res.status_code == 200
    data = res.json()
    assert "active_projects" in data
    assert "cycle_time_days" in data
    assert "database_health" in data

def test_kanban_tasks():
    res = client.get("/api/projects/1/kanban")
    assert res.status_code == 200
    data = res.json()
    assert "todo" in data
    assert "in_progress" in data
    assert "completed" in data

def test_smart_assignee_scoring():
    res = client.get("/api/smart-assign/candidates?task_id=1")
    assert res.status_code == 200
    candidates = res.json()
    assert len(candidates) > 0
    assert candidates[0]["total_score"] > 0
    assert "allocated_hours" in candidates[0]

def test_github_staging_queue():
    res = client.get("/api/github/staging-queue")
    assert res.status_code == 200
    items = res.json()
    assert isinstance(items, list)

def test_audit_hash_chain_verification():
    res = client.get("/api/audit/verify-chain")
    assert res.status_code == 200
    data = res.json()
    assert "is_chain_healthy" in data
    assert data["is_chain_healthy"] is True

def test_gemini_ai_query():
    res = client.post("/api/gemini/query", json={"prompt": "Summarize sprint 4 delivery velocity"})
    assert res.status_code == 200
    data = res.json()
    assert "generated_sql" in data
    assert "response_summary" in data
    assert data["latency_ms"] > 0
