# NexusCore — Unified Database-Centric Management Platform

**A Unified, Database-Centric Project, Client and Bug Management System for HelaNexus Software Solutions**  
*Comprehensive Full Implementation according to the Group AC Project Proposal (CS304.3 Advanced Database Management Systems)*

---

## 🌟 Executive Summary

NexusCore solves data fragmentation inside **HelaNexus Software Solutions** by consolidating clients, projects, employees, sprint tasks, GitHub bugs, work telemetry, and cryptographic audit ledgers into a single **PostgreSQL 16+** authoritative database. 

Business rules, auditability, Row-Level Security, and scoring functions are strictly enforced inside the database engine rather than left to frontend application logic.

---

## 📐 Database Architecture (PostgreSQL 16+)

### 1. 27 Normalized Relational Entities (3NF / BCNF)
The schema is organized into 6 architectural domains:

1. **Core Business (11 Entities)**:
   - `CLIENT`: Company profiles, industry, billing tiers (`standard`, `premium`, `enterprise`), SLA response hours.
   - `CLIENT_INTERACTION`: Communication logs, channels, meeting minutes, and sentiment scores.
   - `PROJECT`: Contract codes, budget allocations, budget expenditures, health scores, risk classifications.
   - `EMPLOYEE`: Staff directory, departmental domain, billable hourly rates, and weekly hour limits.
   - `APP_USER`: System credentials, Argon2 password hashes, RBAC roles (`ceo_admin`, `project_manager`, `developer_qa`, `client_restricted`), and TOTP MFA secrets.
   - `PROJECT_ASSIGNMENT`: Many-to-many junction resolving staff allocation percentages with capacity limits.
   - `TASK`: Sprint deliverables, priorities, statuses (`backlog`, `todo`, `in_progress`, `review`, `completed`), estimated vs. actual hours, and deadlines.
   - `BUG`: Defect tracking, severity rankings, reproduction steps, GitHub issue cross-references, and resolution timestamps.
   - `TIME_LOG`: Timesheet tracking, billable vs non-billable flags, and developer work summaries.
   - `GITHUB_REFERENCE`: External GitHub commit, issue, and pull request URLs.
   - `AUDIT_LOG`: Cryptographically hash-chained immutable audit ledger recording every `INSERT`, `UPDATE`, and `DELETE`.

2. **GitHub Integration & Decoupled Staging (2 Entities)**:
   - `SYNC_RUN`: Execution run logs, fetched count, synced count, failed count, and execution errors.
   - `GITHUB_STAGING`: Decoupled isolation buffer capturing external webhook payloads before validation.

3. **Work Monitoring & Telemetry (4 Entities - Range Partitioned)**:
   - `WORK_SESSION`: Developer work intervals, total elapsed duration, productive time, and idle duration.
   - `ACTIVITY_EVENT`: High-throughput telemetry heartbeats (**Range Partitioned by Month** for Sri Lanka PDPA No. 9 of 2022 compliance and fast retention purge).
   - `APP_RULE`: Pattern matching engine classifying foreground processes into productive vs entertainment.
   - `ALERT`: Manager notifications triggered when non-work application time exceeds configured thresholds.

4. **Intelligence & Analytics (7 Entities)**:
   - `SKILL`: Catalog of technical competencies across frontend, backend, database, DevOps, and QA.
   - `EMPLOYEE_SKILL`: Developer proficiencies (1-5) and verified years of experience.
   - `TASK_SKILL`: Prerequisite technical skills and minimum levels required for task execution.
   - `TASK_DEPENDENCY`: Directed Acyclic Graph (DAG) dependency constraints preventing premature completion.
   - `TASK_STATUS_HISTORY`: Automated state transition timeline with actor identification.
   - `PROJECT_METRIC_SNAPSHOT`: Weekly roll-ups of burndown percentage, cycle times, open defects, and calculated risk.
   - `ASSIGNMENT_SUGGESTION`: In-database cache of Smart Assignee scores and recommendation rationales.

5. **Security & Sessions (2 Entities)**:
   - `USER_SESSION`: Revocable cryptographic session tokens with client IP address and user-agent fingerprints.
   - `LOGIN_ATTEMPT`: Brute-force detection logs tracking successful vs failed authentication attempts.

6. **Artificial Intelligence (1 Entity)**:
   - `AI_INTERACTION_LOG`: Full audit history of prompts, generated SQL queries, token consumption, and response latency.

---

### 2. The 6 Core Stored Procedures & Functions

1. **`sp_assign_task_smart(p_task_id INT, p_assigned_by VARCHAR)`**:
   In-database multi-factor scoring function:
   $$\text{Score} = (\text{Skill Fit} \times 0.50) + (\text{Free Capacity} \times 0.30) + (\text{Dept Fit} \times 0.20)$$
   Executes with **`SELECT FOR UPDATE`** row locking on employee records to guarantee zero double-allocations during concurrent sprint planning.
2. **`sp_sync_github_staging(p_run_id INT)`**:
   Validates unverified payloads in `GITHUB_STAGING`, checks for existing issue IDs, and upserts clean records into `BUG` within an atomic transaction.
3. **`sp_refresh_project_metrics(p_project_id INT)`**:
   Automates weekly client progress reporting: aggregates cycle time, burndown completion, open bugs, and project health in < 2 seconds (saving 3-4 hours of manual reporting).
4. **`sp_merge_duplicate_clients(p_primary_id INT, p_duplicate_id INT)`**:
   Locates duplicate client profiles via `pg_trgm` trigram fuzzy matching, cascades all foreign keys, and consolidates projects and interactions.
5. **`sp_process_activity_event(p_session_id INT, p_process_name VARCHAR, ...)`**:
   Evaluates foreground processes against `APP_RULE` and raises instant manager alerts if non-work time passes thresholds.
6. **`sp_verify_audit_hash_chain()`**:
   Recomputes SHA-256 digests across the entire `AUDIT_LOG` chain:
   $$\text{current\_hash} = \text{SHA256}(\text{prev\_hash} \parallel \text{table\_name} \parallel \text{record\_id} \parallel \text{action} \parallel \text{payload})$$
   Validates continuous ledger integrity and flags broken audit block IDs.

---

### 3. The 6 Core Database Triggers

1. **`trg_audit_chain_insert_update_delete`**: AFTER INSERT/UPDATE/DELETE trigger writing SHA-256 hash chains with JSONB old/new values.
2. **`trg_prevent_audit_tamper`**: BEFORE UPDATE/DELETE trigger rejecting modifications to `AUDIT_LOG`.
3. **`trg_task_status_history`**: Automatically captures task status changes in `TASK_STATUS_HISTORY`.
4. **`trg_telemetry_app_rule_alert`**: Flags continuous non-work activity and dispatches alerts to project managers.
5. **`trg_enforce_task_dependency`**: Rejects task completion if prerequisite DAG dependencies remain unfinished.
6. **`trg_update_project_health`**: Automatically triggers `sp_refresh_project_metrics` when tasks or bugs change state.

---

## ⚡ Backend Application (FastAPI & Python 3.12)

The backend provides high-performance asynchronous REST endpoints and real-time WebSockets:

- **Auth & MFA**: `/api/auth/login`, `/api/auth/mfa/setup`, `/api/auth/mfa/verify`, `/api/auth/me`
- **Executive Analytics**: `/api/overview/metrics`, `/api/overview/burndown`, `/api/overview/recent-audits`
- **Projects & Kanban**: `/api/projects`, `/api/projects/{id}/kanban`, `/api/projects/tasks/{id}/status`
- **Smart Assignee Engine**: `/api/smart-assign/candidates`, `/api/smart-assign/allocate`
- **Decoupled GitHub Staging**: `/api/github/staging-queue`, `/api/github/webhook`, `/api/github/process-staging`
- **Work Telemetry**: `/api/telemetry/session/start`, `/api/telemetry/session/stop`, `/api/telemetry/heartbeat`, `/api/telemetry/alerts`
- **Cryptographic Audit**: `/api/audit/logs`, `/api/audit/verify-chain`, `/api/audit/simulate-tamper`, `/api/audit/repair-chain`
- **Database Admin & Console**: `/api/db/schema/entities`, `/api/db/procedures/run/{name}`, `/api/db/sql/execute`
- **Gemini AI Assistant**: `/api/gemini/query`, `/api/gemini/logs`
- **WebSocket Streaming**: `/ws/alerts` for live push alerts

---

## 🖥️ Dynamic Frontend & Background Animation Engine

1. **3-Variant Background Switcher**:
   - **⚡ Tech / Mesh** (`tech.jpg` + `particlesjs-config.json`): Cyber workstation with cyan/white constellation lines and repulse interactivity.
   - **🌌 NASA Nebula** (`nasa.png` + `particlesjs-config-nasa.json`): Deep space galaxy nebula with twinkling stars.
   - **🎄 Christmas Snow** (`christmas.jpg` + `particlesjs-config-snow.json`): Festive winter cottage with falling snow particles.
2. **Smooth Swipe Up-Down Transitions**:
   - Upward switching triggers directional slide up animation.
   - Downward switching triggers directional slide down animation.
   - Synced with hardware-accelerated particle canvas vertical translate.
3. **Calibrated Glassmorphism**:
   - `background: rgba(10, 16, 30, 0.30)` with `backdrop-filter: blur(10px)`.
   - The monitors, RGB fans, and background scenery are clearly visible through UI panels.
4. **Web Audio SFX Engine**:
   - Procedural Web Audio API sound feedback for clicks, switches, alerts, and success events (WCAG 2.1 compliant with instant visual toasts and mute toggle).
5. **Interactive Guided Tour**:
   - Step-by-step Driver-style onboarding walkthrough across key features.

---

## 🛠️ How to Run the Complete Project

### 1. Run the FastAPI Backend
```bash
# Start backend server with automatic reload
python -m uvicorn backend.app.main:app --reload --port 8000
```
- API Docs (Swagger UI): [http://localhost:8000/docs](http://localhost:8000/docs)
- Interactive Dashboard: [http://localhost:8000/](http://localhost:8000/)

### 2. Run Automated Pytest Suite
```bash
python -m pytest backend/tests/ -v
```
*Executes all 7 automated integration tests verifying health, analytics, Kanban, Smart Assignee, GitHub staging, cryptographic audit, and Gemini AI endpoints.*

### 3. Generate 10,000+ Synthetic Records
```bash
python database/generate_data.py
```
*Generates `database/05_seed_synthetic_data.sql` with 11,000+ SQL statements across all 27 entities.*

### 4. Run the Background Services
```bash
# Run GitHub sync service (pulls, stages, and validates issues)
python services/github_sync_service.py

# Run PDPA 2022 Desktop Activity Agent (streams active window telemetry)
python services/desktop_activity_agent.py
```

### 5. Multi-Container Docker Deployment
```bash
docker-compose -f devops/docker-compose.yml up --build
```
*Spins up PostgreSQL 16 (with WAL archiving, `pg_trgm`, and `pgcrypto`), the FastAPI backend, and the decoupled GitHub sync worker.*

---

## 👥 Group AC — Team Roles & Contributions

| Student Name | Student ID | Subsystem Role |
| :--- | :--- | :--- |
| **W.G.B.D. Gamage** | 35273 | Backend, FastAPI, GitHub Integration |
| **G.J.B.I. Perera** | 36626 | Schema, Migrations, 10,000+ Synthetic Data |
| **R.G.M.N. Jayawardhana** | 36909 | Stored Procedures, ACID Transactions, Smart Assignment |
| **N.H.M. Sivmini** | 37097 | Triggers, Hash Chain Audit Ledger, Activity Alerts |
| **K.P.C.J. Bimsari** | 37054 | Database Security (RBAC, RLS, TOTP MFA, Sessions) |
| **H.K. Dinura** | 37210 | Indexing (B-tree, GIN, Trigram, BRIN), Performance |
| **H.I. Nirmal** | 35172 | Analytics, Materialized Views, Metric Forecasting |
| **M.F.S. Zainab** | 36484 | Database Architecture, Schema Documentation, Backend |
| **B.S.S.T. Cooray** | 37226 | Frontend UI/UX, Particle Switcher, Sound FX, Gemini AI, Tour |
| **H.C.S. Dilruk** | 35408 | DevOps, Docker Compose, WAL Archiving & PITR Recovery |
