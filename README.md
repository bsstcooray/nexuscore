# NexusCore — Dashboard UI & Interactive Platform

**A Unified, Database-Centric Project, Client and Bug Management System for HelaNexus Software Solutions**  
*Built according to the Group AC Project Proposal (CS304.3)*

---

## 🌟 Overview & Key Capabilities

NexusCore eliminates data fragmentation across HelaNexus by unifying clients, projects, employees, tasks, GitHub bugs, telemetry sessions, and cryptographic audit records into one high-performance platform.

### 🎨 Dynamic Background Sceneries with Swipe Up-Down Animation
The dashboard couples rich photographic/cybernetic backgrounds with matching **particles.js** configurations, smoothly transitioned via a 3-button switcher in the top header toolbar:

1. **⚡ Tech / Mesh** (`tech.jpg` + `particlesjs-config.json`): High-tech digital circuit board with animated cyan/white connected constellation mesh and cursor repulsion.
2. **🌌 NASA Nebula** (`nasa.png` + `particlesjs-config-nasa.json`): Deep space galaxy nebula with twinkling stars and gentle drift.
3. **🎄 Christmas Snow** (`christmas.jpg` + `particlesjs-config-snow.json`): Festive winter wonderland with falling snowflakes and cursor bubbling deflection.

#### 🔄 Smooth Swipe Up-Down Transition
- Switching upward in the order (Tech $\rightarrow$ NASA $\rightarrow$ Snow) triggers an upward swipe animation (`swipe-out-to-top` and `swipe-in-from-bottom`).
- Switching downward triggers a downward swipe animation (`swipe-out-to-bottom` and `swipe-in-from-top`).
- The particle canvas layer synchronizes with hardware-accelerated vertical translate easing.

#### 🪟 Glassmorphism & Background Transparency
- All panels, stat cards, kanban boards, sidebars, and headers feature calibrated translucency (`background: rgba(12, 19, 34, 0.42)` with `backdrop-filter: blur(12px)` and translucent borders).
- The artwork, stars, and snowflakes remain clearly visible through the glass panels while text and metrics maintain crisp contrast.

---

## 🖥️ Included Interfaces

1. **Executive Overview Dashboard**:
   - Live KPI cards: Active Projects, Sprints In-Flight, Decoupled Staging Bugs, and Billable Dev Hours.
   - Sprint 4 Velocity & Burndown SVG chart (Materialized view simulation).
   - Project Risk & Allocation Matrix (CarePlus, FinFlow, LogiTrack).
   - Partitioned Database Operations & Hash Chain Log stream.

2. **Projects & Kanban Sprints**:
   - Concurrency control with `SELECT FOR UPDATE` row locks.
   - Kanban board columns: *Backlog*, *To Do*, *In Progress*, and *QA Verified & Done*.
   - Task cards with story points, skill tags, assigned developer avatars, and dependencies.

3. **Smart Assignee Recommendation Engine**:
   - Interactive SQL scoring function (`suggest_assignee()`) calculating weighted matches:
     $$\text{Score} = (\text{Skill Match} \times 0.45) + (\text{Free Capacity} \times 0.35) + (\text{Efficiency} \times 0.20)$$
   - Candidate ranking with score progress bars and one-click ACID locking assignment.

4. **GitHub Staging & Bug Sync Layer**:
   - Decoupled staging architecture: Webhooks enter `GITHUB_STAGING`, undergo procedure validation, and upsert cleanly into `BUG`.
   - Payload JSON inspector with duplicate rejection safeguards.
   - "Trigger Sync Service" simulator and one-click "AI Triage" classification.

5. **Work Session Telemetry & Desktop Agent**:
   - Live session timer logging to `WORK_SESSION`.
   - Real-time window and process name telemetry feed.
   - Compliant with **Sri Lanka Personal Data Protection Act (PDPA) No. 9 of 2022** (no keylogging or screen captures).
   - Non-work application alert trigger simulation (`APP_RULE` $\rightarrow$ `ALERT`).

6. **Security & Cryptographic Hash-Chained Audit Ledger**:
   - `AUDIT_LOG` visualization showing SHA-256 hash chaining:
     $$\text{current\_hash} = \text{SHA256}(\text{prev\_hash} \parallel \text{row\_id} \parallel \text{row\_data\_jsonb})$$
   - "Verify Hash Integrity" button validating 100% of tables against unauthorized tampering.
   - Role-Based Access Control (RBAC) and Row-Level Security (RLS) policies.

7. **Database Architecture & 27 Entities Inspector**:
   - Complete 27-entity breakdown across 6 architectural groups:
     1. Core Business (11)
     2. GitHub Integration (2)
     3. Work Monitoring (4)
     4. Intelligence & Analytics (7)
     5. Security & Sessions (2)
     6. AI (1)
   - Catalogue of the 6 core stored procedures and 6 key database triggers.

8. **Google Gemini AI Assistant (Drawer)**:
   - Slide-out panel for natural language queries (Text-to-SQL).
   - Sprint summary generation in under 5 seconds.
   - Automated bug triage and logging to `AI_INTERACTION_LOG`.

9. **Audio Feedback Engine & Guided Tour**:
   - Web Audio API synthesizer for tactile UI sound cues.
   - WCAG 2.1 compliant with instant visual toast notifications and mute toggle.
   - Role Switcher simulator (CEO / Admin, Project Manager, Developer, Client).
   - Interactive step-by-step onboarding tour.

---

## 🚀 How to Run

Simply open [index.html](file:///c:/Users/PC/Desktop/NexusCoreNew/index.html) in your browser:
- Double click `index.html` in File Explorer, or
- Run via Node: `npx serve .` or any static HTTP server.
