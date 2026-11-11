/* ==========================================================================
   NexusCore - Unified Database-Centric Management Platform
   HelaNexus Software Solutions | Interactive Application Logic
   ========================================================================== */

// --- EXACT CONFIG OBJECTS FROM WORKSPACE JSON FILES (Guarantees 100% operation even via file:/// protocol) ---
const PARTICLE_CONFIGS = {
  mesh: {
    "particles": {
      "number": { "value": 80, "density": { "enable": true, "value_area": 800 } },
      "color": { "value": "#ffffff" },
      "shape": { "type": "circle", "stroke": { "width": 0, "color": "#000000" }, "polygon": { "nb_sides": 5 } },
      "opacity": { "value": 0.5, "random": false, "anim": { "enable": false, "speed": 1, "opacity_min": 0.1, "sync": false } },
      "size": { "value": 3, "random": true, "anim": { "enable": false, "speed": 40, "size_min": 0.1, "sync": false } },
      "line_linked": { "enable": true, "distance": 150, "color": "#ffffff", "opacity": 0.4, "width": 1 },
      "move": { "enable": true, "speed": 6, "direction": "none", "random": false, "straight": false, "out_mode": "out", "bounce": false, "attract": { "enable": false, "rotateX": 600, "rotateY": 1200 } }
    },
    "interactivity": {
      "detect_on": "canvas",
      "events": { "onhover": { "enable": true, "mode": "repulse" }, "onclick": { "enable": true, "mode": "push" }, "resize": true },
      "modes": { "grab": { "distance": 400, "line_linked": { "opacity": 1 } }, "bubble": { "distance": 400, "size": 40, "duration": 2, "opacity": 8, "speed": 3 }, "repulse": { "distance": 200, "duration": 0.4 }, "push": { "particles_nb": 4 }, "remove": { "particles_nb": 2 } }
    },
    "retina_detect": true
  },
  nasa: {
    "particles": {
      "number": { "value": 160, "density": { "enable": true, "value_area": 800 } },
      "color": { "value": "#ffffff" },
      "shape": { "type": "circle", "stroke": { "width": 0, "color": "#000000" }, "polygon": { "nb_sides": 5 } },
      "opacity": { "value": 1, "random": true, "anim": { "enable": true, "speed": 1, "opacity_min": 0, "sync": false } },
      "size": { "value": 3, "random": true, "anim": { "enable": false, "speed": 4, "size_min": 0.3, "sync": false } },
      "line_linked": { "enable": false, "distance": 150, "color": "#ffffff", "opacity": 0.4, "width": 1 },
      "move": { "enable": true, "speed": 1, "direction": "none", "random": true, "straight": false, "out_mode": "out", "bounce": false, "attract": { "enable": false, "rotateX": 600, "rotateY": 600 } }
    },
    "interactivity": {
      "detect_on": "canvas",
      "events": { "onhover": { "enable": true, "mode": "bubble" }, "onclick": { "enable": true, "mode": "repulse" }, "resize": true },
      "modes": { "grab": { "distance": 400, "line_linked": { "opacity": 1 } }, "bubble": { "distance": 250, "size": 0, "duration": 2, "opacity": 0, "speed": 3 }, "repulse": { "distance": 400, "duration": 0.4 }, "push": { "particles_nb": 4 }, "remove": { "particles_nb": 2 } }
    },
    "retina_detect": true
  },
  snow: {
    "particles": {
      "number": { "value": 400, "density": { "enable": true, "value_area": 800 } },
      "color": { "value": "#fff" },
      "shape": { "type": "circle", "stroke": { "width": 0, "color": "#000000" }, "polygon": { "nb_sides": 5 } },
      "opacity": { "value": 0.5, "random": true, "anim": { "enable": false, "speed": 1, "opacity_min": 0.1, "sync": false } },
      "size": { "value": 10, "random": true, "anim": { "enable": false, "speed": 40, "size_min": 0.1, "sync": false } },
      "line_linked": { "enable": false, "distance": 500, "color": "#ffffff", "opacity": 0.4, "width": 2 },
      "move": { "enable": true, "speed": 6, "direction": "bottom", "random": false, "straight": false, "out_mode": "out", "bounce": false, "attract": { "enable": false, "rotateX": 600, "rotateY": 1200 } }
    },
    "interactivity": {
      "detect_on": "canvas",
      "events": { "onhover": { "enable": true, "mode": "bubble" }, "onclick": { "enable": true, "mode": "repulse" }, "resize": true },
      "modes": { "grab": { "distance": 400, "line_linked": { "opacity": 0.5 } }, "bubble": { "distance": 400, "size": 4, "duration": 0.3, "opacity": 1, "speed": 3 }, "repulse": { "distance": 200, "duration": 0.4 }, "push": { "particles_nb": 4 }, "remove": { "particles_nb": 2 } }
    },
    "retina_detect": true
  }
};

// --- WEB AUDIO API SOUND ENGINE (No external MP3 files needed, 100% standalone) ---
class SoundEngine {
  constructor() {
    this.isMuted = false;
    this.ctx = null;
  }

  init() {
    if (!this.ctx && (window.AudioContext || window.webkitAudioContext)) {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      this.ctx = new AudioCtx();
    }
  }

  playTone(freq, type, duration, gainVal = 0.08) {
    if (this.isMuted) return;
    try {
      this.init();
      if (!this.ctx) return;
      if (this.ctx.state === 'suspended') {
        this.ctx.resume();
      }
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = type;
      osc.frequency.setValueAtTime(freq, this.ctx.currentTime);
      gain.gain.setValueAtTime(gainVal, this.ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.0001, this.ctx.currentTime + duration);
      osc.connect(gain);
      gain.connect(this.ctx.destination);
      osc.start();
      osc.stop(this.ctx.currentTime + duration);
    } catch (e) {
      console.warn('Audio playback error', e);
    }
  }

  playClick() {
    this.playTone(850, 'sine', 0.06, 0.06);
  }

  playSwitch() {
    if (this.isMuted) return;
    try {
      this.init();
      if (!this.ctx) return;
      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(320, this.ctx.currentTime);
      osc.frequency.exponentialRampToValueAtTime(880, this.ctx.currentTime + 0.16);
      gain.gain.setValueAtTime(0.08, this.ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.0001, this.ctx.currentTime + 0.16);
      osc.connect(gain);
      gain.connect(this.ctx.destination);
      osc.start();
      osc.stop(this.ctx.currentTime + 0.16);
    } catch (e) {}
  }

  playSuccess() {
    if (this.isMuted) return;
    this.playTone(523.25, 'sine', 0.12, 0.08); // C5
    setTimeout(() => this.playTone(659.25, 'sine', 0.12, 0.08), 90); // E5
    setTimeout(() => this.playTone(783.99, 'sine', 0.22, 0.08), 180); // G5
  }

  playAlert() {
    this.playTone(330, 'sawtooth', 0.25, 0.12);
  }

  toggleMute() {
    this.isMuted = !this.isMuted;
    showToast(this.isMuted ? '🔇 Audio Feedback Muted (WCAG 2.1)' : '🔊 Audio Feedback Enabled', 'info');
    return this.isMuted;
  }
}

const audio = new SoundEngine();

// --- WCAG 2.1 ACCESSIBLE VISUAL TOAST NOTIFICATIONS ---
function showToast(message, type = 'info') {
  const container = document.getElementById('toastContainer');
  if (!container) return;

  const toast = document.createElement('div');
  toast.className = 'toast';
  
  let icon = '🔔';
  if (type === 'success') icon = '✅';
  if (type === 'alert') icon = '⚠️';
  if (type === 'security') icon = '🛡️';

  toast.innerHTML = `<span>${icon}</span> <span>${message}</span>`;
  container.appendChild(toast);

  setTimeout(() => {
    toast.style.transition = 'all 0.3s ease';
    toast.style.opacity = '0';
    toast.style.transform = 'translateY(15px)';
    setTimeout(() => {
      if (toast.remove) {
        toast.remove();
      } else if (toast.parentNode) {
        toast.parentNode.removeChild(toast);
      }
    }, 300);
  }, 3400);
}

// --- ASYNC CONFIG LOADER (Tries fetch from JSON file on HTTP, falls back seamlessly to embedded config) ---
async function fetchOrFallbackConfig(mode) {
  const configFiles = {
    mesh: 'particlesjs-config.json',
    nasa: 'particlesjs-config-nasa.json',
    snow: 'particlesjs-config-snow.json'
  };

  try {
    const res = await fetch(configFiles[mode]);
    if (res.ok) {
      const json = await res.json();
      return json;
    }
  } catch (err) {
    // Expected on local file:/// protocol or offline
  }
  return PARTICLE_CONFIGS[mode];
}

// --- PARTICLE BACKGROUND SWITCHER CONTROLLER (3 VARIANTS + SMOOTH SWIPE UP-DOWN) ---
const THEME_ORDER = {
  mesh: 0,
  nasa: 1,
  snow: 2
};

const THEME_CLASSES = {
  mesh: 'bg-tech bg-mesh',
  nasa: 'bg-nasa',
  snow: 'bg-snow bg-christmas'
};

let currentParticleMode = null;
let isSwitchingTheme = false;

async function initParticles(mode = 'mesh') {
  currentParticleMode = mode;

  // 1. Safely cancel any existing animation frame requests to prevent memory leaks and stacking
  if (window.pJSDom && Array.isArray(window.pJSDom)) {
    window.pJSDom.forEach(item => {
      try {
        if (item && item.pJS && item.pJS.fn && item.pJS.fn.drawAnimFrame) {
          cancelAnimationFrame(item.pJS.fn.drawAnimFrame);
        }
      } catch (e) {}
    });
  }

  // 2. Clear canvas container DOM
  const pContainer = document.getElementById('particles-js');
  if (pContainer) {
    pContainer.innerHTML = '';
  }

  // 3. CRITICAL: Ensure window.pJSDom is always an initialized array, NEVER null!
  window.pJSDom = [];

  // 4. Retrieve configuration object
  const cfg = await fetchOrFallbackConfig(mode);

  // 5. Initialize particlesJS with the selected configuration
  try {
    particlesJS('particles-js', cfg);
    if (window.pJSDom && window.pJSDom.length > 0 && window.pJSDom[0].pJS) {
      const pJS = window.pJSDom[0].pJS;
      if (pJS.fn && pJS.fn.canvasSize) {
        pJS.fn.canvasSize();
      }
    }
  } catch (err) {
    console.error('particlesJS init error:', err);
  }
}

// Full theme and background scenery switcher with smooth swipe up-down transition
async function switchThemeAndParticles(newMode) {
  if (isSwitchingTheme) return;
  if (newMode === currentParticleMode && window.pJSDom && window.pJSDom.length > 0) return;
  isSwitchingTheme = true;

  const oldMode = currentParticleMode || 'mesh';
  const direction = THEME_ORDER[newMode] > THEME_ORDER[oldMode] ? 'up' : 'down';

  const bgLayers = {
    mesh: document.getElementById('bgLayerTech'),
    nasa: document.getElementById('bgLayerNasa'),
    snow: document.getElementById('bgLayerSnow')
  };

  const oldLayer = bgLayers[oldMode];
  const newLayer = bgLayers[newMode];
  const particlesWrapper = document.getElementById('particles-wrapper');

  audio.playSwitch();

  if (oldLayer && newLayer) {
    const oldCls = THEME_CLASSES[oldMode] || 'bg-tech bg-mesh';
    const newCls = THEME_CLASSES[newMode] || 'bg-tech bg-mesh';

    if (direction === 'up') {
      // Swipe UP: outgoing slides to top, incoming slides from bottom
      oldLayer.className = `bg-scenery ${oldCls} active swipe-out-to-top`;
      newLayer.className = `bg-scenery ${newCls} swipe-in-from-bottom`;

      if (particlesWrapper) {
        particlesWrapper.classList.remove('particle-swipe-up', 'particle-swipe-down');
        void particlesWrapper.offsetWidth; // trigger reflow
        particlesWrapper.classList.add('particle-swipe-up');
      }

      requestAnimationFrame(() => {
        newLayer.className = `bg-scenery ${newCls} active`;
      });
    } else {
      // Swipe DOWN: outgoing slides to bottom, incoming slides from top
      oldLayer.className = `bg-scenery ${oldCls} active swipe-out-to-bottom`;
      newLayer.className = `bg-scenery ${newCls} swipe-in-from-top`;

      if (particlesWrapper) {
        particlesWrapper.classList.remove('particle-swipe-up', 'particle-swipe-down');
        void particlesWrapper.offsetWidth; // trigger reflow
        particlesWrapper.classList.add('particle-swipe-down');
      }

      requestAnimationFrame(() => {
        newLayer.className = `bg-scenery ${newCls} active`;
      });
    }
  }

  // Load particles configuration
  await initParticles(newMode);

  // Update button active state
  document.querySelectorAll('.particle-btn').forEach(btn => {
    btn.classList.remove('active', 'nasa', 'snow');
    if (btn.dataset.variant === newMode) {
      btn.classList.add('active');
      if (newMode === 'nasa') btn.classList.add('nasa');
      if (newMode === 'snow') btn.classList.add('snow');
    }
  });

  const names = {
    mesh: 'Tech Circuit Backdrop + Network Mesh (tech.jpg)',
    nasa: 'NASA Deep Space Nebula (nasa.png)',
    snow: 'Christmas Snow Wonderland (christmas.jpg)'
  };
  showToast(`Swiped ${direction.toUpperCase()}: ${names[newMode]}`, 'info');

  setTimeout(() => {
    const oldCls = THEME_CLASSES[oldMode] || 'bg-tech bg-mesh';
    const newCls = THEME_CLASSES[newMode] || 'bg-tech bg-mesh';
    if (oldLayer) {
      oldLayer.className = `bg-scenery ${oldCls}`;
    }
    if (newLayer) {
      newLayer.className = `bg-scenery ${newCls} active`;
    }
    if (particlesWrapper) {
      particlesWrapper.classList.remove('particle-swipe-up', 'particle-swipe-down');
    }
    isSwitchingTheme = false;
  }, 860);
}

// Expose globally
window.initParticles = initParticles;
window.switchThemeAndParticles = switchThemeAndParticles;

// --- NAVIGATION & VIEW SWITCHING ---
function initNavigation() {
  const navItems = document.querySelectorAll('.nav-item');
  const viewPanels = document.querySelectorAll('.view-panel');
  const viewTitle = document.getElementById('viewTitle');
  const viewSubtitle = document.getElementById('viewSubtitle');

  const titles = {
    'view-overview': { title: 'Executive Overview', sub: 'Real-time database analytics & system performance metrics' },
    'view-projects': { title: 'Projects & Kanban Sprints', sub: 'Row-level locking (SELECT FOR UPDATE) & sprint pipelines' },
    'view-smart-assign': { title: 'Smart Assignee Engine', sub: 'Database scoring algorithm factoring skills, capacity & deadlines' },
    'view-github-sync': { title: 'GitHub Staging & Bug Sync', sub: 'Decoupled webhook staging table & upsert procedure' },
    'view-telemetry': { title: 'Work Session & Desktop Telemetry', sub: 'PDPA No. 9 2022 compliant activity monitoring & alerts' },
    'view-security-audit': { title: 'Security & Hash-Chained Audit', sub: 'Argon2, RLS policies, revocable sessions & tamper-proof ledger' },
    'view-database': { title: 'Database Architecture & 27 Entities', sub: 'PostgreSQL 16+ 3NF/BCNF schema, 6 stored procedures, 6 triggers' }
  };

  navItems.forEach(item => {
    item.addEventListener('click', (e) => {
      e.preventDefault();
      const targetId = item.dataset.target;
      if (!targetId) return;

      navItems.forEach(n => n.classList.remove('active'));
      item.classList.add('active');

      viewPanels.forEach(panel => {
        panel.classList.remove('active');
        if (panel.id === targetId) {
          panel.classList.add('active');
        }
      });

      if (titles[targetId]) {
        viewTitle.innerHTML = titles[targetId].title;
        viewSubtitle.innerText = titles[targetId].sub;
      }

      audio.playClick();
    });
  });
}

// --- ROLE SWITCHER SIMULATOR ---
function initRoleSwitcher() {
  const roleSelect = document.getElementById('roleSelect');
  if (!roleSelect) return;

  roleSelect.addEventListener('change', (e) => {
    const role = e.target.value;
    audio.playSwitch();

    // Adjust UI based on Role
    const financeElements = document.querySelectorAll('.role-finance');
    const devElements = document.querySelectorAll('.role-dev-only');
    const adminPills = document.querySelectorAll('.role-admin-badge');

    if (role === 'client') {
      financeElements.forEach(el => el.style.display = 'none');
      showToast('Client Mode (Restricted): Read-only milestones, burndown & summaries active.', 'security');
    } else if (role === 'developer') {
      financeElements.forEach(el => el.style.display = 'none');
      showToast('Developer Mode: Assigned tasks, bug tracking, and telemetry active.', 'info');
    } else if (role === 'manager') {
      financeElements.forEach(el => el.style.display = 'inline-block');
      showToast('Project Manager Mode: Sprint planning, smart assignment & team alerts active.', 'info');
    } else {
      financeElements.forEach(el => el.style.display = 'inline-block');
      showToast('CEO / Administrator Mode: Full database & financial access granted.', 'security');
    }
  });
}

// --- WORK SESSION TIMER & TELEMETRY SIMULATOR ---
let sessionTimer = null;
let sessionSeconds = 3840; // 1h 4m
let isSessionRunning = true;

function updateSessionDisplay() {
  const hours = Math.floor(sessionSeconds / 3600);
  const minutes = Math.floor((sessionSeconds % 3600) / 60);
  const secs = sessionSeconds % 60;
  const timerEl = document.getElementById('liveSessionTimer');
  if (timerEl) {
    timerEl.innerText = `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
  }
}

function initWorkSession() {
  updateSessionDisplay();
  sessionTimer = setInterval(() => {
    if (isSessionRunning) {
      sessionSeconds++;
      updateSessionDisplay();
    }
  }, 1000);

  const toggleBtn = document.getElementById('btnToggleSession');
  if (toggleBtn) {
    toggleBtn.addEventListener('click', () => {
      isSessionRunning = !isSessionRunning;
      toggleBtn.innerText = isSessionRunning ? '⏸️ Pause Session' : '▶️ Resume Session';
      audio.playClick();
      showToast(isSessionRunning ? 'Work Session Resumed (Logging to WORK_SESSION table)' : 'Work Session Paused', 'info');
    });
  }

  // Simulate Non-Work Alert Trigger
  const simulateAlertBtn = document.getElementById('btnSimulateAlert');
  if (simulateAlertBtn) {
    simulateAlertBtn.addEventListener('click', () => {
      audio.playAlert();
      showToast('⚠️ PM Alert: Non-work application threshold exceeded (Steam / Netflix)! Trigger logged to ALERT table.', 'alert');
      const alertBadge = document.getElementById('activeAlertsCount');
      if (alertBadge) {
        alertBadge.innerText = parseInt(alertBadge.innerText || '0') + 1;
      }
    });
  }
}

// --- SMART ASSIGNEE RECOMMENDATION ENGINE LOGIC ---
const developersList = [
  { id: 1, name: 'Malith Cooray', designation: 'Senior Full Stack / AI Lead', skills: ['PostgreSQL', 'FastAPI', 'Next.js', 'PyTorch'], capacity: 65, cycleTime: 2.1, rating: 96 },
  { id: 2, name: 'Bimsari Jayawardhana', designation: 'Database Architect & Security', skills: ['PostgreSQL', 'RLS', 'Argon2', 'Audit Ledger'], capacity: 82, cycleTime: 1.8, rating: 94 },
  { id: 3, name: 'Dinura Gamage', designation: 'Backend & GitHub Integrations', skills: ['Python', 'FastAPI', 'Docker', 'WebSockets'], capacity: 40, cycleTime: 2.8, rating: 88 },
  { id: 4, name: 'Nirmal Perera', designation: 'Frontend & UI/UX Specialist', skills: ['Tailwind CSS', 'shadcn', 'Framer Motion', 'Web Audio'], capacity: 90, cycleTime: 1.4, rating: 92 },
  { id: 5, name: 'Sivmini Zainab', designation: 'Data Engineer & Performance', skills: ['pg_trgm', 'GIN Indexing', 'BRIN', 'pg_cron'], capacity: 70, cycleTime: 2.3, rating: 89 }
];

function calculateSmartAssignee(taskSkillRequired, urgency) {
  return developersList.map(dev => {
    let skillScore = dev.skills.includes(taskSkillRequired) ? 95 : 65;
    let capacityScore = dev.capacity;
    let efficiencyScore = Math.max(50, 100 - (dev.cycleTime * 15));
    let totalScore = Math.round((skillScore * 0.45) + (capacityScore * 0.35) + (efficiencyScore * 0.20));

    return {
      ...dev,
      calculatedScore: totalScore
    };
  }).sort((a, b) => b.calculatedScore - a.calculatedScore);
}

function renderSmartAssignees() {
  const container = document.getElementById('smartAssigneeResults');
  if (!container) return;

  const taskSkill = document.getElementById('selectAssignTaskSkill')?.value || 'PostgreSQL';
  const scored = calculateSmartAssignee(taskSkill, 'High');

  container.innerHTML = scored.map((dev, idx) => `
    <div class="scoring-card">
      <div class="candidate-info">
        <div class="candidate-avatar">${dev.name.split(' ').map(n=>n[0]).join('')}</div>
        <div>
          <div style="font-weight: 700; color: #fff; font-size: 0.92rem;">${dev.name} ${idx === 0 ? '<span class="badge badge-emerald">Top Match</span>' : ''}</div>
          <div style="font-size: 0.75rem; color: var(--text-muted);">${dev.designation}</div>
          <div style="display: flex; gap: 4px; margin-top: 5px;">
            ${dev.skills.map(s => `<span class="badge ${s === taskSkill ? 'badge-cyan' : 'badge-subtle'}" style="font-size: 0.65rem;">${s}</span>`).join('')}
          </div>
        </div>
      </div>
      <div style="display: flex; align-items: center; gap: 20px;">
        <div style="text-align: right;">
          <div style="font-size: 0.72rem; color: var(--text-dim);">Free Capacity: <strong style="color: #38bdf8;">${dev.capacity}%</strong></div>
          <div style="font-size: 0.72rem; color: var(--text-dim);">Avg Cycle Time: <strong style="color: #fff;">${dev.cycleTime} days</strong></div>
        </div>
        <div class="score-meter">
          <div class="score-bar-bg">
            <div class="score-bar-fill" style="width: ${dev.calculatedScore}%;"></div>
          </div>
          <div class="score-percentage">${dev.calculatedScore}%</div>
        </div>
        <button class="btn-primary-sm" onclick="assignTaskWithLock('${dev.name}', ${dev.calculatedScore})">
          🔒 Assign (SELECT FOR UPDATE)
        </button>
      </div>
    </div>
  `).join('');
}

window.assignTaskWithLock = function(devName, score) {
  audio.playSuccess();
  showToast(`ACID Transaction Committed: Task locked via SELECT FOR UPDATE and assigned to ${devName} (${score}% match score)!`, 'success');
};

// --- GITHUB DECOUPLED STAGING & BUG SYNC SIMULATOR ---
let stagingQueue = [
  { id: 'GH-8941', repo: 'helanexus/saas-core', title: 'Null pointer in Stripe subscription invoice webhook', severity: 'Critical', status: 'Pending Review', payload: '{"event": "issues.opened", "issue": {"number": 142, "state": "open", "labels": ["bug", "priority-high"]}}' },
  { id: 'GH-8942', repo: 'helanexus/iot-telemetry', title: 'Websocket disconnect timeout on mobile sleep', severity: 'Medium', status: 'Pending Review', payload: '{"event": "issues.opened", "issue": {"number": 88, "state": "open", "labels": ["mobile", "network"]}}' }
];

function renderStagingQueue() {
  const container = document.getElementById('stagingQueueContainer');
  if (!container) return;

  if (stagingQueue.length === 0) {
    container.innerHTML = `<div style="text-align: center; padding: 24px; color: var(--text-dim);">All staging records validated and promoted to production BUG table.</div>`;
    return;
  }

  container.innerHTML = stagingQueue.map((item, idx) => `
    <div class="staging-box" style="margin-bottom: 12px;">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
        <div style="display: flex; align-items: center; gap: 8px;">
          <span class="badge badge-rose">${item.severity}</span>
          <span style="font-family: var(--font-mono); font-size: 0.8rem; color: #38bdf8;">${item.id}</span>
          <span style="font-size: 0.78rem; color: var(--text-dim);">${item.repo}</span>
        </div>
        <div style="display: flex; gap: 8px;">
          <button class="btn-sm" onclick="aiTriageBug('${item.id}', '${item.title.replace(/'/g, "\\'")}')">🤖 AI Triage</button>
          <button class="btn-primary-sm" onclick="promoteStagingRecord(${idx})">✓ Validate & Upsert</button>
        </div>
      </div>
      <div style="font-weight: 600; font-size: 0.88rem; color: #fff; margin-bottom: 6px;">${item.title}</div>
      <div class="staging-json">${item.payload}</div>
    </div>
  `).join('');
}

window.promoteStagingRecord = function(index) {
  const item = stagingQueue[index];
  stagingQueue.splice(index, 1);
  renderStagingQueue();
  audio.playSuccess();
  showToast(`Stored Procedure Executed: ${item.id} validated, sanitized and inserted into production BUG table!`, 'success');
  
  const pendingCount = document.getElementById('githubPendingCount');
  if (pendingCount) pendingCount.innerText = stagingQueue.length;
};

window.aiTriageBug = function(bugId, title) {
  audio.playClick();
  if (window.PageMascotInstance) {
    const panel = document.getElementById('mascotChatPanel');
    if (panel && !panel.classList.contains('active')) {
      window.PageMascotInstance.toggleChatPanel();
    }
    window.PageMascotInstance.sendMascotPrompt(`Triage and classify staging bug [${bugId}]: "${title}"`);
  }
};

function initGitHubSync() {
  renderStagingQueue();
  const triggerBtn = document.getElementById('btnTriggerSync');
  if (triggerBtn) {
    triggerBtn.addEventListener('click', () => {
      triggerBtn.disabled = true;
      triggerBtn.innerHTML = '⏳ Syncing via REST API...';
      audio.playClick();
      setTimeout(() => {
        stagingQueue.push({
          id: `GH-${Math.floor(8945 + Math.random() * 50)}`,
          repo: 'helanexus/portal-web',
          title: 'Memory leak reported in dashboard canvas unmount',
          severity: 'High',
          status: 'Pending Review',
          payload: '{"event": "issues.labeled", "issue": {"number": 204, "labels": ["memory", "ui"]}}'
        });
        renderStagingQueue();
        triggerBtn.disabled = false;
        triggerBtn.innerHTML = '🔄 Trigger Sync Service';
        audio.playSuccess();
        showToast('GitHub Sync Completed: Staging table updated with new webhook records.', 'success');
      }, 1200);
    });
  }
}

// --- CRYPTOGRAPHIC AUDIT LOG & HASH-CHAIN VERIFICATION ---
const auditNodes = [
  { id: 'AUD-902', table: 'CLIENT', action: 'INSERT', actor: 'admin@helanexus.com', timestamp: '2026-11-07 14:12:05', prevHash: '7a8f...d301', rowHash: 'b49c0d24e1...f89a', status: 'VALID' },
  { id: 'AUD-903', table: 'PROJECT', action: 'UPDATE', actor: 'pm.kavindu@helanexus.com', timestamp: '2026-11-07 15:30:19', prevHash: 'b49c...f89a', rowHash: 'c71f92a3b0...910d', status: 'VALID' },
  { id: 'AUD-904', table: 'TASK_ASSIGNMENT', action: 'INSERT', actor: 'system_scoring_proc', timestamp: '2026-11-07 16:45:00', prevHash: 'c71f...910d', rowHash: 'e105da4812...77ab', status: 'VALID' },
  { id: 'AUD-905', table: 'USER_SESSION', action: 'REVOKE', actor: 'security_monitor', timestamp: '2026-11-07 18:02:11', prevHash: 'e105...77ab', rowHash: 'f4521bc890...112e', status: 'VALID' }
];

function initAuditLedger() {
  const container = document.getElementById('auditLedgerContainer');
  if (!container) return;

  container.innerHTML = auditNodes.map((node, i) => `
    <div class="audit-node">
      <div class="audit-node-header">
        <div style="display: flex; align-items: center; gap: 8px;">
          <span class="badge ${node.action === 'INSERT' ? 'badge-emerald' : node.action === 'UPDATE' ? 'badge-cyan' : 'badge-rose'}">${node.action}</span>
          <strong style="color: #fff; font-size: 0.85rem;">${node.table}</strong>
          <span style="font-size: 0.72rem; color: var(--text-dim);">By: ${node.actor}</span>
        </div>
        <div style="display: flex; align-items: center; gap: 8px;">
          <span class="badge badge-emerald">SHA-256 Verified</span>
          <span style="font-size: 0.72rem; color: var(--text-dim);">${node.timestamp}</span>
        </div>
      </div>
      <div style="display: flex; align-items: center; justify-content: space-between; font-size: 0.74rem;">
        <div>Prev Hash: <span class="hash-code">${node.prevHash}</span></div>
        <div class="hash-link-arrow">🔗 Hash Chain Linked</div>
        <div>Row Hash: <span class="hash-code">${node.rowHash}</span></div>
      </div>
    </div>
  `).join('');

  const verifyBtn = document.getElementById('btnVerifyHashChain');
  if (verifyBtn) {
    verifyBtn.addEventListener('click', () => {
      audio.playSuccess();
      showToast('🛡️ Hash Chain Cryptographic Verification: 100% of 27 tables validated. Zero tampering detected.', 'security');
    });
  }
}

// --- GUIDED ONBOARDING TOUR ---
function initGuidedTour() {
  const btnStartTour = document.getElementById('btnStartTour');
  if (!btnStartTour) return;

  btnStartTour.addEventListener('click', () => {
    audio.playSwitch();
    showToast('🚀 Welcome to NexusCore! Take a tour of the unified database platform.', 'info');

    const steps = [
      { element: '.particle-switcher-container', title: 'Particle Engine Switcher', text: 'Toggle between Network Mesh, NASA Stars, and Data Snow backgrounds.' },
      { element: '.role-switcher-box', title: 'Role Simulator', text: 'Switch between CEO, PM, Developer, and Client to inspect RLS permissions.' },
      { element: '.stat-card', title: 'Materialized Metrics', text: 'Live KPI cards powered by pre-computed materialized views.' },
      { element: '#mascot-root', title: 'NexusCore Mascot AI Bot', text: 'Natural language Text-to-SQL, sprint reports, and bug triage powered by Gemini 3.8 Flash!' }
    ];

    let currentStep = 0;
    function highlightNext() {
      if (currentStep >= steps.length) {
        showToast('🎉 Tour Complete! You are ready to explore NexusCore.', 'success');
        audio.playSuccess();
        return;
      }
      const s = steps[currentStep];
      showToast(`Step ${currentStep + 1}/${steps.length}: ${s.title} - ${s.text}`, 'info');
      currentStep++;
      setTimeout(highlightNext, 3500);
    }

    highlightNext();
  });
}

// --- MODAL UTILITIES ---
function openModal(modalId) {
  const modal = document.getElementById(modalId);
  if (modal) {
    modal.classList.add('open');
    audio.playClick();
  }
}

function closeModal(modalId) {
  const modal = document.getElementById(modalId);
  if (modal) {
    modal.classList.remove('open');
    audio.playClick();
  }
}
window.closeModal = closeModal;

// --- TASK MODAL HANDLERS ---
let activeEditingTaskId = 'TSK-1041';

function openNewTaskModal() {
  activeEditingTaskId = 'TSK-' + Math.floor(1050 + Math.random() * 50);
  document.getElementById('modalTaskHeading').innerText = 'New Task Allocation (' + activeEditingTaskId + ')';
  document.getElementById('inputTaskTitle').value = '';
  document.getElementById('inputTaskPoints').value = '3';
  document.getElementById('selectTaskStatus').value = 'To Do';
  document.getElementById('inputTaskDesc').value = '';
  openModal('modalTaskDetail');
}
window.openNewTaskModal = openNewTaskModal;

function openTaskDetailModal(id, title, status, pts, assignee, desc) {
  activeEditingTaskId = id;
  document.getElementById('modalTaskHeading').innerText = 'Task Details: ' + id;
  document.getElementById('inputTaskTitle').value = title;
  document.getElementById('inputTaskPoints').value = pts;
  document.getElementById('selectTaskStatus').value = status;
  if (document.getElementById('selectTaskAssignee')) {
    document.getElementById('selectTaskAssignee').value = assignee || 'Malith Cooray';
  }
  document.getElementById('inputTaskDesc').value = desc || '';
  openModal('modalTaskDetail');
}
window.openTaskDetailModal = openTaskDetailModal;

function saveTaskModalChanges() {
  const status = document.getElementById('selectTaskStatus').value;
  closeModal('modalTaskDetail');
  audio.playSuccess();
  showToast(`ACID Transaction Committed: Task [${activeEditingTaskId}] locked via SELECT FOR UPDATE, updated to "${status}" and committed to TASK table.`, 'success');
}
window.saveTaskModalChanges = saveTaskModalChanges;

// --- STORED PROCEDURE RUNNER CONSOLE ---
let currentActiveProc = 'suggest_assignee';

const PROCEDURE_DEFINITIONS = {
  suggest_assignee: {
    title: 'suggest_assignee(p_task_id INT)',
    desc: 'Calculates developer match score using (Skill×0.45) + (Capacity×0.35) + (Efficiency×0.20) with SELECT FOR UPDATE row-locking.',
    output: `CALL suggest_assignee(1045);
------------------------------------------------------
 employee_id |     full_name      | match_score 
-------------+--------------------+-------------
           1 | Malith Cooray      |       94.20
           2 | Bimsari Jayawardhana|      91.50
           4 | Nirmal Perera      |       89.00
(3 rows)
SELECT FOR UPDATE row lock acquired on TASK 1045.
Zero duplicate allocation risk verified.
Execution Time: 1.42 ms`
  },
  process_github_staging: {
    title: 'process_github_staging()',
    desc: 'Atomically processes raw webhook payloads from GITHUB_STAGING, validates JSON schema, detects duplicate issue numbers, and inserts into BUG table in a single transaction.',
    output: `CALL process_github_staging();
------------------------------------------------------
Validated 2 staging records from GITHUB_STAGING.
Upserted: 2 bugs into BUG table.
Duplicates rejected: 0.
Cryptographic hash logged to AUDIT_LOG.
Execution Time: 2.18 ms`
  },
  generate_weekly_progress: {
    title: 'generate_weekly_progress()',
    desc: 'Rolls up cycle times, completed story points, and bug resolution times into PROJECT_METRIC_SNAPSHOT in < 2 seconds instead of 4 hours of manual reporting.',
    output: `CALL generate_weekly_progress();
------------------------------------------------------
Aggregated 5 active projects across 27 entities.
Refreshed MATERIALIZED VIEW mv_project_analytics.
Old manual time: 3.5 hours -> New automated time: 1.64 seconds!
Execution Time: 1642.10 ms`
  },
  merge_duplicate_clients: {
    title: 'merge_duplicate_clients()',
    desc: 'Utilizes pg_trgm similarity to locate duplicate client entries, cascades foreign keys, and purges duplicate rows.',
    output: `SELECT merge_duplicate_clients(101, 108);
------------------------------------------------------
Cascaded 4 projects and 12 interaction logs.
Deleted redundant client ID 108.
UNIQUE constraint on company_name preserved.
Execution Time: 3.10 ms`
  },
  allocate_task_with_lock: {
    title: 'allocate_task_with_lock(p_task_id INT, p_dev_id INT)',
    desc: 'Prevents race conditions using SELECT FOR UPDATE row locking so two concurrent project managers cannot double-allocate the same task or developer.',
    output: `CALL allocate_task_with_lock(1045, 1);
------------------------------------------------------
Task row 1045 locked exclusively via SELECT FOR UPDATE.
Assigned to Employee ID 1 (Malith Cooray).
Zero double-allocations under parallel k6 load test!
Execution Time: 1.15 ms`
  },
  refresh_materialized_views: {
    title: 'refresh_analytics_materialized_views()',
    desc: 'Refreshes precomputed analytical views concurrently via pg_cron without blocking live transactional reads and writes.',
    output: `CALL refresh_analytics_materialized_views();
------------------------------------------------------
CONCURRENT REFRESH completed on 3 materialized views.
Live API latency unaffected (P99 remains at 1.4ms).
Next trigger scheduled by pg_cron in 30 minutes.
Execution Time: 4.80 ms`
  }
};

function openProcRunner(procKey) {
  currentActiveProc = procKey;
  const def = PROCEDURE_DEFINITIONS[procKey] || PROCEDURE_DEFINITIONS['suggest_assignee'];
  document.getElementById('modalProcTitle').innerText = 'Execute: ' + def.title;
  document.getElementById('modalProcDesc').innerText = def.desc;
  
  const consoleEl = document.getElementById('modalProcConsole');
  consoleEl.innerText = '-- Executing ' + def.title + ' on PostgreSQL 16.2...\n' + def.output;
  openModal('modalProcRunner');
  audio.playSuccess();
}
window.openProcRunner = openProcRunner;

function reRunActiveProcedure() {
  const def = PROCEDURE_DEFINITIONS[currentActiveProc];
  const consoleEl = document.getElementById('modalProcConsole');
  consoleEl.innerText = '-- Re-running procedure with ACID isolation...\n' + def.output;
  audio.playClick();
  showToast('Executed ' + def.title + ' successfully!', 'success');
}
window.reRunActiveProcedure = reRunActiveProcedure;

// --- ENTITY SCHEMA INSPECTOR ---
const ENTITY_SCHEMAS = {
  CLIENT: {
    group: 'Core Business (11 Entities)',
    columns: [
      { name: 'client_id', type: 'SERIAL', constraint: 'PRIMARY KEY', index: 'B-tree (client_id)' },
      { name: 'company_name', type: 'VARCHAR(150)', constraint: 'UNIQUE, NOT NULL', index: 'GIN (company_name gin_trgm_ops)' },
      { name: 'contact_email', type: 'VARCHAR(255)', constraint: 'NOT NULL', index: 'B-tree' },
      { name: 'contract_value', type: 'NUMERIC(12,2)', constraint: 'CHECK (contract_value >= 0)', index: 'None' },
      { name: 'created_at', type: 'TIMESTAMPTZ', constraint: 'DEFAULT NOW()', index: 'BRIN (created_at)' }
    ]
  },
  GITHUB_STAGING: {
    group: 'GitHub Integration (2 Entities)',
    columns: [
      { name: 'staging_id', type: 'SERIAL', constraint: 'PRIMARY KEY', index: 'B-tree' },
      { name: 'run_id', type: 'INT', constraint: 'FK -> SYNC_RUN(run_id)', index: 'B-tree' },
      { name: 'payload', type: 'JSONB', constraint: 'NOT NULL', index: 'GIN (payload jsonb_path_ops)' },
      { name: 'status', type: 'VARCHAR(50)', constraint: 'CHECK (PENDING, PROCESSED, REJECTED)', index: 'Partial (WHERE status=PENDING)' },
      { name: 'received_at', type: 'TIMESTAMPTZ', constraint: 'DEFAULT NOW()', index: 'BRIN' }
    ]
  },
  ACTIVITY_EVENT: {
    group: 'Work Monitoring (4 Entities - Monthly Partitioned)',
    columns: [
      { name: 'event_id', type: 'BIGSERIAL', constraint: 'PARTITION KEY', index: 'BRIN (timestamp)' },
      { name: 'session_id', type: 'INT', constraint: 'FK -> WORK_SESSION(session_id)', index: 'B-tree' },
      { name: 'app_name', type: 'VARCHAR(120)', constraint: 'NOT NULL (PDPA Compliant)', index: 'B-tree' },
      { name: 'window_title', type: 'VARCHAR(255)', constraint: 'NOT NULL', index: 'GIN (gin_trgm_ops)' },
      { name: 'event_time', type: 'TIMESTAMPTZ', constraint: 'RANGE PARTITIONED BY MONTH', index: 'BRIN' }
    ]
  },
  ASSIGNMENT_SUGGESTION: {
    group: 'Intelligence & Analytics (7 Entities)',
    columns: [
      { name: 'suggestion_id', type: 'SERIAL', constraint: 'PRIMARY KEY', index: 'B-tree' },
      { name: 'task_id', type: 'INT', constraint: 'FK -> TASK(task_id)', index: 'B-tree' },
      { name: 'employee_id', type: 'INT', constraint: 'FK -> EMPLOYEE(employee_id)', index: 'B-tree' },
      { name: 'score', type: 'NUMERIC(5,2)', constraint: 'CHECK (score BETWEEN 0 AND 100)', index: 'B-tree DESC' },
      { name: 'calculated_at', type: 'TIMESTAMPTZ', constraint: 'DEFAULT NOW()', index: 'None' }
    ]
  },
  USER_SESSION: {
    group: 'Security & Sessions (2 Entities)',
    columns: [
      { name: 'session_id', type: 'UUID', constraint: 'PRIMARY KEY', index: 'Hash' },
      { name: 'user_id', type: 'INT', constraint: 'FK -> APP_USER(user_id)', index: 'B-tree' },
      { name: 'token_hash', type: 'VARCHAR(255)', constraint: 'Argon2 Hashed', index: 'B-tree' },
      { name: 'is_revoked', type: 'BOOLEAN', constraint: 'DEFAULT FALSE', index: 'Partial (WHERE is_revoked=FALSE)' },
      { name: 'expires_at', type: 'TIMESTAMPTZ', constraint: 'NOT NULL', index: 'B-tree' }
    ]
  }
};

function openEntityModal(entityName) {
  const schema = ENTITY_SCHEMAS[entityName] || ENTITY_SCHEMAS['CLIENT'];
  document.getElementById('modalEntityName').innerText = 'Table Schema: ' + entityName;
  document.getElementById('modalEntityGroup').innerText = schema.group;
  
  const tbody = document.getElementById('modalEntityColumnsBody');
  if (tbody) {
    tbody.innerHTML = schema.columns.map(col => `
      <tr>
        <td><strong style="color: #fff; font-family: var(--font-mono);">${col.name}</strong></td>
        <td><span class="hash-code" style="color: #a78bfa;">${col.type}</span></td>
        <td><span class="badge ${col.constraint.includes('PRIMARY') ? 'badge-cyan' : col.constraint.includes('FK') ? 'badge-purple' : 'badge-emerald'}">${col.constraint}</span></td>
        <td><span style="font-family: var(--font-mono); font-size: 0.72rem; color: #38bdf8;">${col.index}</span></td>
      </tr>
    `).join('');
  }

  openModal('modalEntityDetail');
}
window.openEntityModal = openEntityModal;

function filterEntities(category) {
  const pills = document.querySelectorAll('#entityFilterPills .filter-pill');
  pills.forEach(p => p.classList.remove('active'));
  if (event && event.target) event.target.classList.add('active');

  const cards = document.querySelectorAll('.entity-card-wrap');
  cards.forEach(card => {
    if (category === 'all' || card.dataset.cat === category) {
      card.style.display = 'block';
    } else {
      card.style.display = 'none';
    }
  });
  audio.playClick();
}
window.filterEntities = filterEntities;

// --- TRIGRAM FUZZY SEARCH SIMULATOR ---
const CLIENT_RECORDS = [
  { id: 101, name: 'HelaNexus Software Solutions', contact: 'kavindu@helanexus.com', industry: 'Enterprise SaaS' },
  { id: 102, name: 'CarePlus Telehealth Pvt Ltd', contact: 'ops@careplus.lk', industry: 'HealthTech' },
  { id: 103, name: 'FinFlow Global SG', contact: 'finance@finflow.sg', industry: 'FinTech' },
  { id: 104, name: 'LogiTrack Fleet IoT', contact: 'iot@logitrack.com', industry: 'Logistics' },
  { id: 105, name: 'Helanex Cloud Consulting', contact: 'info@helanex-cloud.com', industry: 'Cloud & DevOps' }
];

function stringSimilarity(s1, s2) {
  let longer = s1.toLowerCase();
  let shorter = s2.toLowerCase();
  if (longer.length < shorter.length) {
    let tmp = longer; longer = shorter; shorter = tmp;
  }
  let longerLength = longer.length;
  if (longerLength === 0) return 1.0;
  
  let count = 0;
  for (let i = 0; i < shorter.length - 2; i++) {
    if (longer.includes(shorter.substr(i, 3))) count++;
  }
  return Math.min(1.0, (count * 3) / longerLength);
}

function runTrigramSearch(query) {
  const container = document.getElementById('trigramResultsContainer');
  if (!container) return;

  if (!query || query.trim().length === 0) {
    container.innerHTML = `<div style="font-size: 0.78rem; color: var(--text-dim);">Type a query above to test database trigram similarity matching (> 0.3 threshold).</div>`;
    return;
  }

  const results = CLIENT_RECORDS.map(c => {
    const sim = Math.max(
      stringSimilarity(query, c.name),
      c.name.toLowerCase().includes(query.toLowerCase()) ? 0.88 : 0.1
    );
    return { ...c, similarity: sim };
  }).filter(c => c.similarity >= 0.25).sort((a, b) => b.similarity - a.similarity);

  if (results.length === 0) {
    container.innerHTML = `<div style="font-size: 0.78rem; color: var(--accent-rose);">No clients matched pg_trgm similarity threshold (0.3).</div>`;
    return;
  }

  container.innerHTML = `
    <table class="custom-table" style="font-size: 0.78rem; margin-top: 8px;">
      <thead>
        <tr>
          <th>Client ID</th>
          <th>Matched Company Name</th>
          <th>Similarity Score (pg_trgm)</th>
          <th>Contact Email</th>
          <th>Industry</th>
        </tr>
      </thead>
      <tbody>
        ${results.map(r => `
          <tr>
            <td><span class="hash-code">#${r.id}</span></td>
            <td><strong style="color: #fff;">${r.name}</strong></td>
            <td><span class="badge ${r.similarity > 0.7 ? 'badge-emerald' : 'badge-amber'}">${(r.similarity * 100).toFixed(0)}% Match</span></td>
            <td>${r.contact}</td>
            <td><span class="badge badge-cyan">${r.industry}</span></td>
          </tr>
        `).join('')}
      </tbody>
    </table>
  `;
}
window.runTrigramSearch = runTrigramSearch;

// --- TAMPER-PROOF AUDIT ATTACK SIMULATOR ---
function simulateTamperAttack() {
  audio.playAlert();
  const nodes = document.querySelectorAll('.audit-node');
  if (nodes.length > 1) {
    const node = nodes[1];
    node.style.borderColor = '#f43f5e';
    node.style.background = 'rgba(244, 63, 94, 0.18)';
    const verifiedBadge = node.querySelector('.badge-emerald');
    if (verifiedBadge) {
      verifiedBadge.className = 'badge badge-rose';
      verifiedBadge.innerText = 'TAMPER DETECTED!';
    }
    const arrow = node.querySelector('.hash-link-arrow');
    if (arrow) {
      arrow.innerHTML = '❌ <strong style="color: #f43f5e;">CHAIN BROKEN (Hash Mismatch)</strong>';
    }
  }
  const btnRepair = document.getElementById('btnRepairChain');
  const btnTamper = document.getElementById('btnSimulateTamper');
  if (btnRepair) btnRepair.style.display = 'inline-flex';
  if (btnTamper) btnTamper.style.display = 'none';
  showToast('🚨 Trigger Alert: Unauthorized SQL modification detected on PROJECT table! Hash chain broken at AUD-903. Transaction aborted!', 'alert');
}
window.simulateTamperAttack = simulateTamperAttack;

function repairHashChain() {
  audio.playSuccess();
  initAuditLedger();
  const btnRepair = document.getElementById('btnRepairChain');
  const btnTamper = document.getElementById('btnSimulateTamper');
  if (btnRepair) btnRepair.style.display = 'none';
  if (btnTamper) btnTamper.style.display = 'inline-flex';
  showToast('🛡️ Hash Chain Repaired: Cryptographic ledger recomputed and verified across all 27 tables.', 'security');
}
window.repairHashChain = repairHashChain;

// --- INITIALIZATION ENTRY POINT ---
function bootNexusCore() {
  // 1. Initialize Particles immediately (Default variant: mesh)
  initParticles('mesh');

  // Particle buttons event listeners (The 3 buttons)
  const btnMesh = document.getElementById('btnParticleMesh');
  const btnNasa = document.getElementById('btnParticleNasa');
  const btnSnow = document.getElementById('btnParticleSnow');

  if (btnMesh) btnMesh.addEventListener('click', () => switchThemeAndParticles('mesh'));
  if (btnNasa) btnNasa.addEventListener('click', () => switchThemeAndParticles('nasa'));
  if (btnSnow) btnSnow.addEventListener('click', () => switchThemeAndParticles('snow'));

  // 2. Sound Toggle
  const soundBtn = document.getElementById('soundToggleBtn');
  if (soundBtn) {
    soundBtn.addEventListener('click', () => {
      const isMuted = audio.toggleMute();
      soundBtn.classList.toggle('muted', isMuted);
    });
  }

  // 3. Navigation
  initNavigation();

  // 4. Role Switcher
  initRoleSwitcher();

  // 5. Work Session
  initWorkSession();

  // 6. Smart Assignee Engine
  renderSmartAssignees();
  const selectSkill = document.getElementById('selectAssignTaskSkill');
  if (selectSkill) selectSkill.addEventListener('change', renderSmartAssignees);

  // 7. GitHub Staging Queue
  initGitHubSync();

  // 8. Cryptographic Audit Ledger
  initAuditLedger();

  // 9. Guided Onboarding Tour
  initGuidedTour();
}

// Execute immediately if DOM already interactive/loaded, otherwise listen to DOMContentLoaded
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', bootNexusCore);
} else {
  bootNexusCore();
}
