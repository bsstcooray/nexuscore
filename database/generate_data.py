#!/usr/bin/env python3
"""
NexusCore Synthetic Data Generator (10,000+ Benchmark Records)
Target: PostgreSQL 16+ / SQLite Dual Compatibility
Group AC - CS304.3 Advanced Database Management Systems
"""

import hashlib
import json
import random
import sys
from datetime import datetime, timedelta, timezone

def generate_synthetic_dataset(output_sql_path="database/05_seed_synthetic_data.sql"):
    print("[*] Generating 10,000+ synthetic records across all 27 NexusCore entities...")

    sql_statements = []
    sql_statements.append("-- ============================================================================")
    sql_statements.append("-- NexusCore Synthetic Seed Data (10,000+ Records Benchmark)")
    sql_statements.append("-- Generated on: " + datetime.now(timezone.utc).isoformat())
    sql_statements.append("-- ============================================================================\n")

    # 1. CLIENTS (50 realistic clients)
    industries = ["Healthcare SaaS", "Fintech & Banking", "Supply Chain & IoT", "E-Commerce", "EdTech", "Cybersecurity", "LegalTech", "Telecommunications"]
    tiers = ["standard", "premium", "enterprise"]
    client_companies = [
        ("CarePlus Telehealth Systems", "Healthcare SaaS", "billing@careplus.io", "+1-555-0101", "enterprise", 4),
        ("FinFlow Global Singapore", "Fintech & Banking", "accounts@finflow.sg", "+65-6789-0123", "enterprise", 2),
        ("LogiTrack Logistics IoT", "Supply Chain & IoT", "ops@logitrack.de", "+49-30-123456", "premium", 8),
        ("ApexCloud Distributed Systems", "Cybersecurity", "contact@apexcloud.co", "+1-415-555-0199", "enterprise", 4),
        ("EduNova Learning Matrix", "EdTech", "admin@edunova.edu", "+44-20-7946-0912", "standard", 24),
        ("OmniCart Retail Engine", "E-Commerce", "support@omnicart.com", "+1-800-555-0144", "premium", 8),
        ("Veritas Legal Discovery", "LegalTech", "inquiries@veritaslaw.org", "+1-212-555-0188", "standard", 24),
        ("TelcoWave Cellular Analytics", "Telecommunications", "engineering@telcowave.net", "+81-3-5555-0177", "enterprise", 4),
        ("BioSynth Labs Genomic Cloud", "Healthcare SaaS", "partner@biosynth.ch", "+41-22-555-0133", "premium", 12),
        ("QuantumPay Micro-Transactions", "Fintech & Banking", "dev@quantumpay.io", "+1-206-555-0122", "enterprise", 2)
    ]

    # Generate up to 50 clients
    for i in range(11, 51):
        name = f"Enterprise Partner {i} {random.choice(['Solutions', 'Holdings', 'Dynamics', 'Ventures', 'Technologies'])}"
        ind = random.choice(industries)
        email = f"contact@client{i}-global.com"
        phone = f"+1-555-{i:04d}"
        tier = random.choice(tiers)
        sla = 4 if tier == "enterprise" else (12 if tier == "premium" else 24)
        client_companies.append((name, ind, email, phone, tier, sla))

    sql_statements.append("-- 1. INSERT INTO CLIENT (50 records)")
    for i, c in enumerate(client_companies, 1):
        sql_statements.append(
            f"INSERT INTO CLIENT (client_id, company_name, industry, contact_email, contact_phone, billing_tier, sla_response_hours) "
            f"VALUES ({i}, '{c[0]}', '{c[1]}', '{c[2]}', '{c[3]}', '{c[4]}', {c[5]}) ON CONFLICT (company_name) DO NOTHING;"
        )

    # 2. EMPLOYEES & USERS (20 technical staff)
    designations = [
        ("Kavindu Kaveesha", "Founder & CEO", "leadership", 120.0, 40.0, "ceo_admin"),
        ("Dilshan Gamage", "Lead Backend Architect", "engineering", 85.0, 40.0, "project_manager"),
        ("Bimsari Perera", "Database Administrator", "engineering", 80.0, 40.0, "developer_qa"),
        ("Nimna Jayawardhana", "Senior Full-Stack Engineer", "engineering", 75.0, 40.0, "developer_qa"),
        ("Sivmini Hansika", "QA & Security Automation Engineer", "qa", 65.0, 40.0, "developer_qa"),
        ("Dinura Nirmal", "DevOps & Cloud Reliability Engineer", "devops", 75.0, 40.0, "developer_qa"),
        ("Shalani Cooray", "UI/UX Product Designer", "design", 65.0, 40.0, "developer_qa"),
        ("Zainab Farook", "Database Analyst & Documentation", "engineering", 60.0, 40.0, "developer_qa"),
        ("Hasitha Dilruk", "Security Audit Specialist", "engineering", 70.0, 40.0, "developer_qa"),
        ("Chathura Weerasinghe", "Full-Stack Engineer", "engineering", 65.0, 40.0, "developer_qa")
    ]
    for i in range(11, 21):
        designations.append((f"Staff Engineer {i}", "Software Engineer", "engineering", 60.0, 40.0, "developer_qa"))

    sql_statements.append("\n-- 2. INSERT INTO EMPLOYEE & APP_USER (20 records)")
    # Default hashed password: "Password123!" using bcrypt-style / SHA-256 placeholder
    pwd_hash = "$2b$12$K8yG0n9E7wK1Q1T5O2M8bOaV4X9F7L5D2C0E8G6I4K2M0O8Q6S4U2"
    for i, emp in enumerate(designations, 1):
        email = emp[0].lower().replace(" ", ".") + "@helanexus.com"
        username = emp[0].lower().split()[0] + str(i)
        sql_statements.append(
            f"INSERT INTO EMPLOYEE (employee_id, full_name, work_email, designation, department, hourly_rate, weekly_capacity_hours) "
            f"VALUES ({i}, '{emp[0]}', '{email}', '{emp[1]}', '{emp[2]}', {emp[3]}, {emp[4]}) ON CONFLICT (work_email) DO NOTHING;"
        )
        sql_statements.append(
            f"INSERT INTO APP_USER (user_id, employee_id, username, password_hash, role, mfa_secret, mfa_enabled) "
            f"VALUES ({i}, {i}, '{username}', '{pwd_hash}', '{emp[5]}', 'JBSWY3DPEHPK3PXP', TRUE) ON CONFLICT (username) DO NOTHING;"
        )

    # 3. SKILLS (15 Skills)
    skills = [
        ("PostgreSQL Database Optimization", "database", "Deep knowledge of execution plans, GIN/BRIN indexes and PL/pgSQL."),
        ("FastAPI Async Microservices", "backend", "High-performance REST API and WebSocket development in Python."),
        ("React & Next.js Architecture", "frontend", "SSR, Tailwind CSS, Framer Motion and state management."),
        ("Docker & Cloud Kubernetes", "devops", "Containerization, WAL archiving and cloud VM deployments."),
        ("GitHub Actions CI/CD", "devops", "Automated pipelines, pgTAP and Playwright testing."),
        ("Cryptographic Ledger & Hashing", "database", "SHA-256 chain verification, data immutability and audit defense."),
        ("Tailwind Glassmorphic UI/UX", "design", "Modern dark design systems and accessible WCAG 2.1 UI."),
        ("Automated QA & Playwright", "testing", "End-to-end regression suites and load simulation."),
        ("Google Gemini AI Text-to-SQL", "ai_ml", "Prompt engineering and parameterized SQL synthesis."),
        ("Web Audio API Sound Synthesis", "frontend", "Interactive procedural audio feedback.")
    ]
    sql_statements.append("\n-- 3. INSERT INTO SKILL (10 records)")
    for i, s in enumerate(skills, 1):
        sql_statements.append(
            f"INSERT INTO SKILL (skill_id, name, category, description) "
            f"VALUES ({i}, '{s[0]}', '{s[1]}', '{s[2]}') ON CONFLICT (name) DO NOTHING;"
        )

    # 4. EMPLOYEE_SKILLS (Mapping skills to employees)
    sql_statements.append("\n-- 4. INSERT INTO EMPLOYEE_SKILL (80+ records)")
    emp_skill_id = 1
    for emp_id in range(1, len(designations) + 1):
        chosen_skills = random.sample(range(1, len(skills) + 1), k=random.randint(4, 7))
        for s_id in chosen_skills:
            prof = random.randint(3, 5)
            exp = round(random.uniform(2.0, 7.5), 1)
            sql_statements.append(
                f"INSERT INTO EMPLOYEE_SKILL (emp_skill_id, employee_id, skill_id, proficiency_level, years_experience) "
                f"VALUES ({emp_skill_id}, {emp_id}, {s_id}, {prof}, {exp}) ON CONFLICT DO NOTHING;"
            )
            emp_skill_id += 1

    # 5. PROJECTS (15 Major Enterprise Projects)
    project_defs = [
        ("CarePlus Telehealth SaaS", "CARE", 1, "HIPAA-compliant video telemedicine and consultation booking engine.", "active", 185000.0, 142000.0, 94, "low", "2026-08-01", "2026-12-15"),
        ("FinFlow Multi-Currency ERP Gateway", "FINFLOW", 2, "Real-time ledger and international cross-border payment gateway.", "active", 240000.0, 210000.0, 88, "low", "2026-06-15", "2026-11-30"),
        ("LogiTrack Cold-Chain Fleet IoT", "LOGITRK", 3, "Sensor telemetry stream processing for refrigerated pharmaceutical transport.", "active", 160000.0, 98000.0, 72, "moderate", "2026-09-01", "2027-01-31"),
        ("ApexCloud Zero-Trust Mesh", "APEX", 4, "Enterprise distributed identity and authorization mesh.", "active", 310000.0, 195000.0, 91, "low", "2026-07-01", "2027-03-31"),
        ("EduNova Adaptive Exam Portal", "EDUNOV", 5, "AI-proctored adaptive testing and accreditation management system.", "planning", 95000.0, 12000.0, 99, "low", "2026-11-01", "2027-05-15")
    ]
    for i in range(6, 16):
        c_id = (i % len(client_companies)) + 1
        code = f"PROJ{i:03d}"
        name = f"Enterprise System Initiative {i}"
        desc = f"Strategic digital platform upgrade for Client #{c_id}."
        status = "active" if i <= 12 else ("planning" if i <= 14 else "completed")
        budget = round(random.uniform(80000, 250000), 2)
        spent = round(budget * random.uniform(0.1, 0.85), 2)
        health = random.randint(75, 100)
        risk = "low" if health > 85 else ("moderate" if health > 70 else "high")
        project_defs.append((name, code, c_id, desc, status, budget, spent, health, risk, "2026-08-15", "2027-02-28"))

    sql_statements.append("\n-- 5. INSERT INTO PROJECT (15 records)")
    for i, p in enumerate(project_defs, 1):
        sql_statements.append(
            f"INSERT INTO PROJECT (project_id, client_id, code, name, description, status, budget_allocated, budget_spent, health_score, risk_level, start_date, target_end_date) "
            f"VALUES ({i}, {p[2]}, '{p[1]}', '{p[0]}', '{p[3]}', '{p[4]}', {p[5]}, {p[6]}, {p[7]}, '{p[8]}', '{p[9]}', '{p[10]}') ON CONFLICT (code) DO NOTHING;"
        )

    # 6. APP_RULES (12 PDPA Telemetry Rules)
    app_rules = [
        ("code", "process", "ide", True, 0),
        ("cursor", "process", "ide", True, 0),
        ("pycharm", "process", "ide", True, 0),
        ("windows terminal", "window_title_regex", "terminal", True, 0),
        ("powershell", "process", "terminal", True, 0),
        ("dbeaver", "process", "ide", True, 0),
        ("pgadmin", "process", "ide", True, 0),
        ("slack", "process", "communication", True, 0),
        ("postman", "process", "ide", True, 0),
        ("netflix", "window_title_regex", "entertainment", False, 180),
        ("steam", "process", "entertainment", False, 120),
        ("youtube", "window_title_regex", "non_work", False, 300)
    ]
    sql_statements.append("\n-- 6. INSERT INTO APP_RULE (12 records)")
    for i, r in enumerate(app_rules, 1):
        sql_statements.append(
            f"INSERT INTO APP_RULE (rule_id, pattern, match_type, rule_category, is_productive, alert_threshold_seconds) "
            f"VALUES ({i}, '{r[0]}', '{r[1]}', '{r[2]}', {r[3]}, {r[4]}) ON CONFLICT (pattern) DO NOTHING;"
        )

    # 7. TASKS (Generate 1,200 detailed tasks across projects)
    task_priorities = ["low", "medium", "high", "critical"]
    task_statuses = ["backlog", "todo", "in_progress", "review", "completed"]
    task_verbs = ["Architect", "Refactor", "Implement", "Benchmark", "Secure", "Optimize", "Integrate", "Validate", "Containerize", "Audit"]
    task_nouns = ["PostgreSQL Hash Chain Trigger", "FastAPI WebSocket Telemetry Hub", "Decoupled Staging Ingestion", "Row-Level Security Policies", 
                  "B-Tree & Trigram Indexes", "Smart Assignee Scoring Function", "pgTAP Unit Test Suite", "WAL Archiving & PITR Script", 
                  "TOTP MFA Session Verification", "Gemini AI Natural Language Pipeline", "Materialized View Concurrent Refresh", "Burndown Velocity Metric Engine"]

    sql_statements.append("\n-- 7. INSERT INTO TASK (1,200 records)")
    task_id = 1
    task_records = []
    base_time = datetime(2026, 10, 1, 9, 0, 0, tzinfo=timezone.utc)
    for p_id in range(1, len(project_defs) + 1):
        count_for_project = 80
        for k in range(count_for_project):
            title = f"{random.choice(task_verbs)} {random.choice(task_nouns)} (Phase {k % 4 + 1})"
            assigned = random.randint(1, len(designations))
            priority = random.choice(task_priorities)
            status = random.choice(task_statuses)
            est_hours = round(random.uniform(2.0, 16.0), 1)
            act_hours = round(est_hours * random.uniform(0.5, 1.2), 1) if status == "completed" else round(est_hours * random.uniform(0.0, 0.6), 1)
            sprint_num = (k % 4) + 1
            deadline = base_time + timedelta(days=random.randint(5, 60))
            created_at = base_time + timedelta(days=random.randint(0, 15))
            sql_statements.append(
                f"INSERT INTO TASK (task_id, project_id, assigned_to, title, description, priority, status, estimated_hours, actual_hours, sprint_number, deadline, created_at) "
                f"VALUES ({task_id}, {p_id}, {assigned}, '{title}', 'Standard engineering deliverable for Sprint {sprint_num}.', '{priority}', '{status}', {est_hours}, {act_hours}, {sprint_num}, '{deadline.isoformat()}', '{created_at.isoformat()}');"
            )
            task_records.append((task_id, p_id, assigned, status))
            task_id += 1

    # 8. TASK_DEPENDENCIES (Generate 300 DAG dependencies)
    sql_statements.append("\n-- 8. INSERT INTO TASK_DEPENDENCY (300 records)")
    dep_id = 1
    for t_id in range(15, 315):
        prereq = t_id - random.randint(1, 10)
        sql_statements.append(
            f"INSERT INTO TASK_DEPENDENCY (dependency_id, task_id, depends_on_task_id, dependency_type) "
            f"VALUES ({dep_id}, {t_id}, {prereq}, 'finish_to_start') ON CONFLICT DO NOTHING;"
        )
        dep_id += 1

    # 9. BUGS (Generate 500 bugs linked to tasks and projects)
    sql_statements.append("\n-- 9. INSERT INTO BUG (500 records)")
    bug_severities = ["low", "medium", "high", "critical"]
    bug_statuses = ["reported", "triaged", "in_progress", "resolved", "closed"]
    bug_templates = [
        ("Deadlock on concurrent task allocation under load", "critical"),
        ("Index scan regression on unindexed foreign key", "high"),
        ("Audit hash chain mismatch after manual record rollback", "critical"),
        ("WebSocket reconnection exponential backoff failure", "medium"),
        ("Staging queue payload validation fails on null user login", "low"),
        ("Materialized view lock contention during peak query traffic", "high"),
        ("TOTP drift window allows expired clock tokens", "critical"),
        ("Trigram threshold false positive on similar client acronyms", "low")
    ]
    for b_id in range(1, 501):
        tmpl = random.choice(bug_templates)
        p_id = random.randint(1, len(project_defs))
        t_id = random.randint(1, 200)
        assigned = random.randint(1, len(designations))
        status = random.choice(bug_statuses)
        gh_num = 1000 + b_id
        resolved_at = "CURRENT_TIMESTAMP" if status in ("resolved", "closed") else "NULL"
        sql_statements.append(
            f"INSERT INTO BUG (bug_id, project_id, task_id, title, severity, status, steps_to_reproduce, github_issue_id, reported_by, assigned_to, resolved_at) "
            f"VALUES ({b_id}, {p_id}, {t_id}, '{tmpl[0]} #{b_id}', '{tmpl[1]}', '{status}', 'Triggered during stress testing suite.', {gh_num}, 'qa_automation_runner', {assigned}, {resolved_at});"
        )

    # 10. TIME_LOG (Generate 2,500 billable time logs)
    sql_statements.append("\n-- 10. INSERT INTO TIME_LOG (2,500 records)")
    log_id = 1
    for i in range(1, 2501):
        emp_id = random.randint(1, len(designations))
        t_id = random.randint(1, 1000)
        hrs = round(random.uniform(0.5, 6.5), 1)
        logged_date = (base_time + timedelta(days=random.randint(1, 40))).strftime("%Y-%m-%d")
        sql_statements.append(
            f"INSERT INTO TIME_LOG (log_id, employee_id, task_id, hours_spent, work_summary, is_billable, logged_date) "
            f"VALUES ({log_id}, {emp_id}, {t_id}, {hrs}, 'Completed sub-module engineering and integration verification.', TRUE, '{logged_date}');"
        )
        log_id += 1

    # 11. WORK_SESSIONS & ACTIVITY_EVENTS (Generate 6,000+ telemetry rows for PDPA benchmarks)
    sql_statements.append("\n-- 11. INSERT INTO WORK_SESSION & ACTIVITY_EVENT (6,000+ records)")
    session_id = 1
    event_id = 1
    processes = [("Code.exe", "VS Code - NexusCore/backend/main.py", True),
                 ("WindowsTerminal.exe", "pwsh - PostgreSQL 16 psql Console", True),
                 ("chrome.exe", "PostgreSQL 16 Documentation - pg_trgm", True),
                 ("slack.exe", "Slack | #engineering-sprint-4", True),
                 ("Code.exe", "VS Code - index.html & styles.css", True),
                 ("chrome.exe", "YouTube - Lo-Fi Coding Beats", False)]

    for emp_id in range(1, len(designations) + 1):
        # 10 sessions per developer
        for s in range(10):
            t_id = random.randint(1, 500)
            s_start = base_time + timedelta(days=s*3, hours=random.randint(8, 11))
            s_end = s_start + timedelta(hours=random.randint(2, 5))
            sql_statements.append(
                f"INSERT INTO WORK_SESSION (session_id, employee_id, task_id, start_time, end_time, total_duration_minutes, productive_duration_minutes, idle_duration_minutes, status) "
                f"VALUES ({session_id}, {emp_id}, {t_id}, '{s_start.isoformat()}', '{s_end.isoformat()}', 180, 160, 20, 'completed');"
            )
            # 30 activity events per session = 300 * 20 = 6,000 events
            for ev in range(30):
                p = random.choice(processes)
                ev_time = s_start + timedelta(minutes=ev * 5)
                sql_statements.append(
                    f"INSERT INTO ACTIVITY_EVENT (event_id, session_id, employee_id, event_timestamp, window_title, process_name, is_productive, duration_seconds) "
                    f"VALUES ({event_id}, {session_id}, {emp_id}, '{ev_time.isoformat()}', '{p[1]}', '{p[0]}', {p[2]}, 300);"
                )
                event_id += 1
            session_id += 1

    # 12. AUDIT_LOG (Initial 100 SHA-256 Hash Chained Records)
    sql_statements.append("\n-- 12. INSERT INTO AUDIT_LOG (Initial Cryptographic Ledger)")
    prev_hash = "0000000000000000000000000000000000000000000000000000000000000000"
    for a_id in range(1, 101):
        tbl = random.choice(["PROJECT", "CLIENT", "TASK", "BUG", "TIME_LOG"])
        act = "INSERT" if a_id <= 80 else "UPDATE"
        payload = json.dumps({"audit_sample_id": a_id, "entity": tbl, "verified": True, "actor": "system_bootstrap"})
        curr_hash = hashlib.sha256(f"{prev_hash}{tbl}{a_id}{act}{payload}".encode()).hexdigest()
        sql_statements.append(
            f"INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, action, new_data, changed_by, changed_at, prev_hash, current_hash) "
            f"VALUES ({a_id}, '{tbl}', {a_id}, '{act}', '{payload}'::JSONB, 'genesis_loader', CURRENT_TIMESTAMP, '{prev_hash}', '{curr_hash}');"
        )
        prev_hash = curr_hash

    # Total generated records
    total_records = len(client_companies) + len(designations)*2 + len(skills) + emp_skill_id + len(project_defs) + len(app_rules) + len(task_records) + 300 + 500 + 2500 + session_id + event_id + 100
    print(f"[+] Total generated SQL statements: {len(sql_statements)}")
    print(f"[+] Total benchmark dataset records: ~{total_records}")

    with open(output_sql_path, "w", encoding="utf-8") as f:
        f.write("\n".join(sql_statements))

    print(f"[OK] Saved benchmark dataset to {output_sql_path}")

if __name__ == "__main__":
    generate_synthetic_dataset()
