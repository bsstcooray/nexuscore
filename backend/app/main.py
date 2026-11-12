"""
NexusCore FastAPI Application Entry Point
Unified, Database-Centric Management Platform for HelaNexus Software Solutions
Group AC - CS304.3 Advanced Database Management Systems
"""

import asyncio
from datetime import datetime, timedelta, timezone
from contextlib import asynccontextmanager
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from backend.app.config import settings
from backend.app.database import engine, Base, SessionLocal
import backend.app.models # Register all 27 SQLAlchemy models in Base.metadata
from backend.app.routers import (
    auth, overview, projects, smart_assign, github_sync,
    telemetry, security_audit, database_admin, gemini_ai
)

# Active WebSocket Connections Manager
class ConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: dict):
        for connection in self.active_connections:
            try:
                await connection.send_json(message)
            except Exception:
                pass

ws_manager = ConnectionManager()

def bootstrap_database():
    """Initializes tables and seeds initial baseline data if database is fresh."""
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        from backend.app.models import Client, Project, Employee, AppUser, Task, Bug, AuditLog
        if db.query(Client).count() == 0:
            print("[*] Fresh database detected. Seeding core baseline data...")
            # 1. Client
            c1 = Client(company_name="CarePlus Telehealth Systems", industry="Healthcare SaaS", contact_email="billing@careplus.io", billing_tier="enterprise", sla_response_hours=4)
            c2 = Client(company_name="FinFlow Global Singapore", industry="Fintech & Banking", contact_email="accounts@finflow.sg", billing_tier="enterprise", sla_response_hours=2)
            c3 = Client(company_name="LogiTrack Logistics IoT", industry="Supply Chain & IoT", contact_email="ops@logitrack.de", billing_tier="premium", sla_response_hours=8)
            db.add_all([c1, c2, c3])
            db.commit()

            # 2. Employees & Users
            e1 = Employee(full_name="Kavindu Kaveesha", work_email="kavindu@helanexus.com", designation="Founder & CEO", department="leadership", hourly_rate=120.0)
            e2 = Employee(full_name="Dilshan Gamage", work_email="dilshan@helanexus.com", designation="Lead Backend Architect", department="engineering", hourly_rate=85.0)
            e3 = Employee(full_name="Bimsari Perera", work_email="bimsari@helanexus.com", designation="Database Administrator", department="engineering", hourly_rate=80.0)
            e4 = Employee(full_name="Nimna Jayawardhana", work_email="nimna@helanexus.com", designation="Senior Full-Stack Engineer", department="engineering", hourly_rate=75.0)
            db.add_all([e1, e2, e3, e4])
            db.commit()

            u1 = AppUser(employee_id=e1.employee_id, username="kavindu", password_hash="Password123!", role="ceo_admin", mfa_enabled=False)
            u2 = AppUser(employee_id=e2.employee_id, username="dilshan", password_hash="Password123!", role="project_manager", mfa_enabled=False)
            u3 = AppUser(employee_id=e3.employee_id, username="bimsari", password_hash="Password123!", role="developer_qa", mfa_enabled=False)
            u4 = AppUser(employee_id=e4.employee_id, username="nimna", password_hash="Password123!", role="developer_qa", mfa_enabled=False)
            u5 = AppUser(employee_id=None, username="client", password_hash="Password123!", role="client", mfa_enabled=False)
            db.add_all([u1, u2, u3, u4, u5])
            db.commit()

            # 3. Projects
            p1 = Project(client_id=c1.client_id, code="CARE", name="CarePlus Telehealth SaaS", description="HIPAA video telemedicine platform.", status="active", budget_allocated=185000.0, budget_spent=142000.0, health_score=94, risk_level="low", start_date=datetime.now().date(), target_end_date=datetime.now().date())
            p2 = Project(client_id=c2.client_id, code="FINFLOW", name="FinFlow ERP Gateway", description="Multi-currency ledger.", status="active", budget_allocated=240000.0, budget_spent=210000.0, health_score=88, risk_level="low", start_date=datetime.now().date(), target_end_date=datetime.now().date())
            db.add_all([p1, p2])
            db.commit()

            # 4. Tasks
            now = datetime.now(timezone.utc)
            t1 = Task(project_id=p1.project_id, assigned_to=e2.employee_id, title="Implement pg_trgm fuzzy matching for client search", priority="high", status="in_progress", estimated_hours=6.0, deadline=now + timedelta(days=2))
            t2 = Task(project_id=p1.project_id, assigned_to=e3.employee_id, title="Configure WAL archiving and pgBackRest drill", priority="critical", status="todo", estimated_hours=8.0, deadline=now + timedelta(days=4))
            t3 = Task(project_id=p2.project_id, assigned_to=e2.employee_id, title="Build SELECT FOR UPDATE task lock allocation procedure", priority="high", status="completed", estimated_hours=4.0, actual_hours=4.0, deadline=now - timedelta(days=1))
            db.add_all([t1, t2, t3])
            db.commit()

            # 5. Genesis Audit Log
            a1 = AuditLog(table_name="PROJECT", record_id=p1.project_id, action="INSERT", new_data={"code": "CARE", "name": p1.name}, changed_by="genesis_bootstrap", prev_hash="0000000000000000000000000000000000000000000000000000000000000000", current_hash="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
            db.add(a1)
            db.commit()
            print("[+] Baseline database seeding completed successfully.")
    finally:
        db.close()

# Initialize database schema and baseline data immediately on module load
Base.metadata.create_all(bind=engine)
bootstrap_database()

@asynccontextmanager
async def lifespan(app: FastAPI):
    print(f"[*] Starting {settings.APP_NAME} v{settings.APP_VERSION}")
    bootstrap_database()
    yield
    print(f"[*] Shutting down {settings.APP_NAME}")

app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="NexusCore — A Unified, Database-Centric Project, Client and Bug Management Platform for HelaNexus Software Solutions",
    lifespan=lifespan
)

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include Routers
app.include_router(auth.router)
app.include_router(overview.router)
app.include_router(projects.router)
app.include_router(smart_assign.router)
app.include_router(github_sync.router)
app.include_router(telemetry.router)
app.include_router(security_audit.router)
app.include_router(database_admin.router)
app.include_router(gemini_ai.router)

# WebSocket Endpoint for Real-Time Manager Alerts & Telemetry
@app.websocket("/ws/alerts")
async def websocket_alerts_endpoint(websocket: WebSocket):
    await ws_manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            # Echo or process incoming socket messages
            await ws_manager.broadcast({"type": "ping", "data": data})
    except WebSocketDisconnect:
        ws_manager.disconnect(websocket)

# Health Check
@app.get("/api/health")
def health_check():
    return {
        "status": "healthy",
        "system": "NexusCore",
        "organization": "HelaNexus Software Solutions",
        "database": "PostgreSQL 16.2 / Dual Engine Operational",
        "version": settings.APP_VERSION
    }

# Serve root index.html directly from FastAPI
@app.get("/")
def serve_index():
    return FileResponse("index.html")

# Mount static files (css, js, assets, background images, mascots)
import os
if os.path.exists("mascots"):
    app.mount("/mascots", StaticFiles(directory="mascots"), name="mascots")
elif os.path.exists("public/mascots"):
    app.mount("/mascots", StaticFiles(directory="public/mascots"), name="mascots")

app.mount("/static", StaticFiles(directory="."), name="static")

# Mount root directory so index.html, styles.css, mascot.js, app.js are served directly
app.mount("/", StaticFiles(directory=".", html=True), name="root_static")
