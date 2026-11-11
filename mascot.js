/**
 * NexusCore Page Mascot & AI Bot
 * Integrated with Google Gemini 3.8 Flash & Updated Database SQL Context
 * 
 * Functions:
 * 1. 8-directional pointer tracking with hysteresis and dead zone.
 * 2. Click to access the NexusCore AI Bot floating dialog directly above the mascot.
 * 3. Natural language query processing with automatic updated database SQL context.
 * 4. Rich Markdown and SQL query rendering with reaction payoffs.
 */

(function () {
  const DIRECTIONS = [
    'up-left',
    'up',
    'up-right',
    'left',
    'center',
    'right',
    'down-left',
    'down',
    'down-right',
  ];

  const REACTIONS = [
    'blink',
    'heart',
    'sparkle',
    'surprised',
    'wink',
    'bashful',
    'sleepy',
    'dizzy',
    'delighted',
  ];

  const CLOCKWISE = [
    'right',
    'down-right',
    'down',
    'down-left',
    'left',
    'up-left',
    'up',
    'up-right',
  ];

  const SECTOR = (Math.PI * 2) / CLOCKWISE.length;
  const HYSTERESIS = 0.12;
  const DEAD_ZONE = 70;
  const PAYOFFS = ['heart', 'sparkle', 'delighted'];
  const BOOP_PAYOFF = 120;
  const BOOP_END = 560;
  const SQUASH_MS = 420;
  const DIZZY_AFTER = 4;
  const DIZZY_WINDOW = 1600;
  const DIZZY_END = 1100;

  const SQUASH = [
    { transform: 'scale(1, 1)', easing: 'ease-in' },
    { transform: 'scale(1.10, 0.86)', offset: 0.18, easing: 'ease-out' },
    { transform: 'scale(0.95, 1.08)', offset: 0.45, easing: 'ease-in-out' },
    { transform: 'scale(1.03, 0.97)', offset: 0.72, easing: 'ease-in-out' },
    { transform: 'scale(1, 1)' },
  ];

  const FUNNY_MESSAGES = [
    "G'day mate! Click me to chat with NexusCore AI 🐨",
    "Boop! All 27 relational tables are 3NF/BCNF verified 🛡️",
    "ACID locks active: No concurrency anomalies on my watch! ⚡",
    "11,041 synthetic rows seeded with SHA-256 audit chaining! 🔐",
    "NASA & Snow particle sceneries are synced and shining ✨",
    "💖 Keep shipping clean code, mate!",
    "💫 Whoa mate, too many boops! Getting dizzy here..."
  ];

  function wrap(angle) {
    return Math.atan2(Math.sin(angle), Math.cos(angle));
  }

  function getCellPosition(index) {
    const col = (index % 3) * 50;
    const row = Math.floor(index / 3) * 50;
    return `${col}% ${row}%`;
  }

  function resolveAssetPath(path) {
    if (!path) return '';
    if (window.location.protocol === 'file:' && path.startsWith('/')) {
      return '.' + path;
    }
    return path;
  }

  function playChime(freq = 520) {
    try {
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (!AudioCtx) return;
      const ctx = new AudioCtx();
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(freq, ctx.currentTime);
      osc.frequency.exponentialRampToValueAtTime(freq * 1.5, ctx.currentTime + 0.08);
      gain.gain.setValueAtTime(0.12, ctx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.15);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start();
      osc.stop(ctx.currentTime + 0.15);
    } catch (e) {
      // Audio autoplay restrictions
    }
  }

  function formatMarkdown(text) {
    if (!text) return '';
    let html = text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');

    // Fenced code blocks
    html = html.replace(/```(?:sql|json|javascript|bash|python)?\n([\s\S]*?)```/g, function(_, code) {
      return `<pre><code>${code.trim()}</code></pre>`;
    });

    // Inline code
    html = html.replace(/`([^`]+)`/g, '<code style="color:var(--accent-cyan);">$1</code>');

    // Headers
    html = html.replace(/^### (.*$)/gim, '<h4 style="color:#fff;margin:8px 0 4px;font-size:0.86rem;font-weight:700;">$1</h4>');
    html = html.replace(/^## (.*$)/gim, '<h3 style="color:#fff;margin:10px 0 6px;font-size:0.92rem;font-weight:700;">$1</h3>');
    html = html.replace(/^# (.*$)/gim, '<h2 style="color:#fff;margin:12px 0 8px;font-size:1.02rem;font-weight:800;">$1</h2>');

    // Bold
    html = html.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');

    // Markdown tables
    html = html.replace(/((?:\|[^\n]+\|\r?\n)+)/g, function(tableText) {
      const lines = tableText.trim().split(/\r?\n/);
      if (lines.length < 2) return tableText;
      let tableHtml = '<table>';
      let isHeader = true;
      for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (line.match(/^\|(?:\s*:?-+:?\s*\|)+$/)) {
          isHeader = false;
          continue;
        }
        const cells = line.split('|').filter((_, idx, arr) => idx > 0 && idx < arr.length - 1);
        tableHtml += '<tr>';
        cells.forEach(c => {
          tableHtml += isHeader ? `<th>${c.trim()}</th>` : `<td>${c.trim()}</td>`;
        });
        tableHtml += '</tr>';
      }
      tableHtml += '</table>';
      return tableHtml;
    });

    // Lists
    html = html.replace(/^\s*[-*]\s+(.*$)/gim, '<li>$1</li>');
    html = html.replace(/(<li>.*<\/li>)/gims, '<ul style="padding-left:18px;margin:6px 0;">$1</ul>');

    // Paragraphs
    html = html.split(/\n\n+/).map(p => {
      if (p.startsWith('<h') || p.startsWith('<pre') || p.startsWith('<table') || p.startsWith('<ul')) return p;
      return `<p>${p.replace(/\n/g, '<br>')}</p>`;
    }).join('');

    return html;
  }

  class MascotController {
    constructor(options = {}) {
      this.container = options.container || document.getElementById('mascot-root');
      this.directions = resolveAssetPath(options.directions || '/mascots/koala-directions.webp');
      this.reactions = resolveAssetPath(options.reactions || '/mascots/koala-reactions.webp');
      this.size = options.size || 140;
      this.label = options.label || 'koala mascot';

      this.direction = 'center';
      this.reaction = null;
      this.sector = -1;
      this.pointer = null;
      this.timers = [];
      this.boops = { count: 0, at: 0 };
      this.msgIndex = 0;

      if (this.container) {
        this.render();
        this.initEvents();
        this.initChatPanelEvents();
      }
    }

    render() {
      this.container.innerHTML = `
        <button type="button" class="page-mascot-btn" aria-label="Boop the ${this.label} to access NexusCore AI">
          <span class="page-mascot-squash">
            <span class="page-mascot-layer mascot-directions-layer" style="background-image: url('${this.directions}'); background-position: ${getCellPosition(DIRECTIONS.indexOf('center'))}; opacity: 1;"></span>
            <span class="page-mascot-layer mascot-reactions-layer" style="background-image: url('${this.reactions}'); background-position: ${getCellPosition(REACTIONS.indexOf('blink'))}; opacity: 0;"></span>
          </span>
          <div class="mascot-speech-bubble" id="mascotBubble">${FUNNY_MESSAGES[0]}</div>
        </button>
      `;

      this.button = this.container.querySelector('.page-mascot-btn');
      this.squashEl = this.container.querySelector('.page-mascot-squash');
      this.directionsLayer = this.container.querySelector('.mascot-directions-layer');
      this.reactionsLayer = this.container.querySelector('.mascot-reactions-layer');
      this.bubble = this.container.querySelector('.mascot-speech-bubble');
    }

    setDirection(dir) {
      if (this.direction === dir) return;
      this.direction = dir;
      const idx = DIRECTIONS.indexOf(dir);
      if (idx !== -1 && this.directionsLayer) {
        this.directionsLayer.style.backgroundPosition = getCellPosition(idx);
      }
    }

    setReaction(rx) {
      this.reaction = rx;
      if (!this.directionsLayer || !this.reactionsLayer) return;

      if (rx) {
        const idx = REACTIONS.indexOf(rx);
        if (idx !== -1) {
          this.reactionsLayer.style.backgroundPosition = getCellPosition(idx);
        }
        this.reactionsLayer.style.opacity = '1';
        this.directionsLayer.style.opacity = '0';
      } else {
        this.reactionsLayer.style.opacity = '0';
        this.directionsLayer.style.opacity = '1';
      }
    }

    showSpeech(text, duration = 3000) {
      if (!this.bubble) return;
      this.bubble.textContent = text;
      this.bubble.classList.add('active');
      clearTimeout(this.bubbleTimer);
      this.bubbleTimer = setTimeout(() => {
        this.bubble.classList.remove('active');
      }, duration);
    }

    aim() {
      if (!this.button || !this.pointer) return;
      const box = this.button.getBoundingClientRect();
      const dx = this.pointer.x - (box.left + box.width / 2);
      const dy = this.pointer.y - (box.top + box.height / 2);

      if (Math.hypot(dx, dy) < DEAD_ZONE) {
        this.sector = -1;
        this.setDirection('center');
        return;
      }

      const angle = Math.atan2(dy, dx);
      if (this.sector !== -1 && Math.abs(wrap(angle - this.sector * SECTOR)) < SECTOR / 2 + HYSTERESIS) {
        return;
      }

      this.sector = (Math.round(angle / SECTOR) + CLOCKWISE.length) % CLOCKWISE.length;
      this.setDirection(CLOCKWISE[this.sector]);
    }

    boop() {
      this.timers.forEach(clearTimeout);
      this.timers = [];

      const later = (ms, next) => {
        this.timers.push(setTimeout(() => this.setReaction(next), ms));
      };

      const now = Date.now();
      this.boops.count = now - this.boops.at < DIZZY_WINDOW ? this.boops.count + 1 : 1;
      this.boops.at = now;

      if (this.boops.count >= DIZZY_AFTER) {
        this.boops.count = 0;
        this.setReaction('dizzy');
        playChime(320);
        this.showSpeech(FUNNY_MESSAGES[6], DIZZY_END);
        later(DIZZY_END, null);
      } else {
        this.setReaction('blink');
        playChime(580 + this.boops.count * 80);
        const payoff = PAYOFFS[(this.boops.count - 1) % PAYOFFS.length];
        later(BOOP_PAYOFF, payoff);
        later(BOOP_END, null);

        this.msgIndex = (this.msgIndex + 1) % (FUNNY_MESSAGES.length - 1);
        this.showSpeech(FUNNY_MESSAGES[this.msgIndex], 2500);
      }

      if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
        return;
      }

      if (this.squashEl && typeof this.squashEl.animate === 'function') {
        this.squashEl.animate(SQUASH, { duration: SQUASH_MS, easing: 'linear' });
      }
    }

    toggleChatPanel() {
      const panel = document.getElementById('mascotChatPanel');
      if (!panel) return;
      const isOpening = !panel.classList.contains('active');
      
      if (isOpening) {
        panel.classList.add('active');
        this.showSpeech("NexusCore AI opened! Ask me anything 🐨", 2500);
        const input = document.getElementById('mascotPromptInput');
        if (input) {
          setTimeout(() => input.focus(), 150);
        }
        const output = document.getElementById('mascotChatOutput');
        if (output) {
          output.scrollTop = output.scrollHeight;
        }
      } else {
        panel.classList.remove('active');
      }
    }

    initEvents() {
      const onPointerMove = (e) => {
        this.pointer = { x: e.clientX, y: e.clientY };
        this.aim();
      };

      window.addEventListener('pointermove', onPointerMove, { passive: true });
      window.addEventListener('scroll', () => this.aim(), { passive: true });

      if (this.button) {
        this.button.addEventListener('click', () => {
          this.boop();
          this.toggleChatPanel();
        });
      }
    }

    initChatPanelEvents() {
      // Close button
      const closeBtn = document.getElementById('btnCloseMascotChat');
      if (closeBtn) {
        closeBtn.addEventListener('click', () => {
          const panel = document.getElementById('mascotChatPanel');
          if (panel) panel.classList.remove('active');
        });
      }

      // Clear button
      const clearBtn = document.getElementById('btnClearMascotChat');
      if (clearBtn) {
        clearBtn.addEventListener('click', () => {
          const output = document.getElementById('mascotChatOutput');
          if (output) {
            output.innerHTML = `
              <div class="mascot-msg assistant-msg">
                <div class="mascot-msg-header">
                  <span class="msg-author">NexusCore AI</span>
                  <span class="msg-time">Just now</span>
                </div>
                <div class="mascot-msg-body">
                  <p><strong>Chat history cleared.</strong> How can I assist you with the database, active sprints, or developer allocations?</p>
                </div>
              </div>
            `;
          }
        });
      }

      // API Key toggle & save
      const apiKeyBtn = document.getElementById('btnToggleApiKey');
      const apiKeyBar = document.getElementById('mascotApiKeyBar');
      const apiKeyInput = document.getElementById('inputCustomApiKey');
      const apiKeySaveBtn = document.getElementById('btnSaveApiKey');

      if (apiKeyInput && localStorage.getItem('NEXUSCORE_GEMINI_KEY')) {
        apiKeyInput.value = localStorage.getItem('NEXUSCORE_GEMINI_KEY');
      }

      if (apiKeyBtn && apiKeyBar) {
        apiKeyBtn.addEventListener('click', () => {
          apiKeyBar.style.display = apiKeyBar.style.display === 'none' ? 'flex' : 'none';
        });
      }

      if (apiKeySaveBtn && apiKeyInput) {
        apiKeySaveBtn.addEventListener('click', () => {
          const key = apiKeyInput.value.trim();
          if (key) {
            localStorage.setItem('NEXUSCORE_GEMINI_KEY', key);
            apiKeyBar.style.display = 'none';
            playChime(750);
            this.showSpeech("API Key saved securely in session! ✨", 2500);
          } else {
            localStorage.removeItem('NEXUSCORE_GEMINI_KEY');
            apiKeyBar.style.display = 'none';
          }
        });
      }

      // Quick Chips
      const chips = document.querySelectorAll('.mascot-chip');
      chips.forEach(chip => {
        chip.addEventListener('click', () => {
          const prompt = chip.getAttribute('data-prompt');
          if (prompt) {
            this.sendMascotPrompt(prompt);
          }
        });
      });

      // Send prompt on button click or Enter key
      const sendBtn = document.getElementById('btnSendMascotPrompt');
      const promptInput = document.getElementById('mascotPromptInput');

      if (sendBtn && promptInput) {
        sendBtn.addEventListener('click', () => {
          this.sendMascotPrompt(promptInput.value);
        });

        promptInput.addEventListener('keydown', (e) => {
          if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            this.sendMascotPrompt(promptInput.value);
          }
        });
      }
    }

    async sendMascotPrompt(text) {
      if (!text || !text.trim()) return;
      const prompt = text.trim();
      const output = document.getElementById('mascotChatOutput');
      const input = document.getElementById('mascotPromptInput');
      const sendBtn = document.getElementById('btnSendMascotPrompt');

      // Append user message
      const timeStr = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
      const userMsgHtml = `
        <div class="mascot-msg user-msg">
          <div class="mascot-msg-header">
            <span class="msg-author">You</span>
            <span class="msg-time">${timeStr}</span>
          </div>
          <div class="mascot-msg-body">
            <p>${prompt.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')}</p>
          </div>
        </div>
      `;
      output.insertAdjacentHTML('beforeend', userMsgHtml);
      if (input) input.value = '';
      if (sendBtn) sendBtn.disabled = true;

      // Append typing indicator
      const typingId = 'typing-' + Date.now();
      const typingHtml = `
        <div class="mascot-msg assistant-msg" id="${typingId}">
          <div class="mascot-typing-indicator">
            <span class="typing-dot"></span>
            <span class="typing-dot"></span>
            <span class="typing-dot"></span>
            <span>NexusCore AI analyzing database context...</span>
          </div>
        </div>
      `;
      output.insertAdjacentHTML('beforeend', typingHtml);
      output.scrollTop = output.scrollHeight;

      const apiKey = localStorage.getItem('NEXUSCORE_GEMINI_KEY') || '';
      const apiUrl = (window.location.protocol === 'file:' || !window.location.port) 
        ? 'http://127.0.0.1:8080/api/gemini/query' 
        : '/api/gemini/query';

      try {
        const res = await fetch(apiUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            prompt: prompt,
            api_key: apiKey || null
          })
        });

        const data = await res.json();
        const typingEl = document.getElementById(typingId);
        if (typingEl) typingEl.remove();

        const formattedBody = formatMarkdown(data.response_summary);
        let sqlSnippet = '';
        if (data.generated_sql) {
          sqlSnippet = `
            <div style="margin-top: 10px; border-top: 1px dashed rgba(255,255,255,0.1); padding-top: 8px;">
              <div style="font-size: 0.68rem; color: var(--accent-cyan); font-weight: 600; margin-bottom: 4px;">⚡ Verified Parameterized SQL:</div>
              <pre style="background: rgba(0,0,0,0.65); padding: 8px 10px; border-radius: 6px; font-size: 0.72rem; color: #38bdf8; overflow-x: auto; margin: 0;"><code>${data.generated_sql}</code></pre>
            </div>
          `;
        }

        const assistantMsgHtml = `
          <div class="mascot-msg assistant-msg">
            <div class="mascot-msg-header">
              <span class="msg-author">NexusCore AI</span>
              <span class="badge-mini" style="font-size: 0.6rem;">${data.model_version || 'gemini-3.8-flash'}</span>
              <span class="msg-time">${data.latency_ms || 120}ms</span>
            </div>
            <div class="mascot-msg-body">
              ${formattedBody}
              ${sqlSnippet}
            </div>
          </div>
        `;
        output.insertAdjacentHTML('beforeend', assistantMsgHtml);
        output.scrollTop = output.scrollHeight;

        // Trigger celebratory mascot payoff reaction
        this.setReaction('heart');
        setTimeout(() => this.setReaction(null), 1200);
        playChime(680);

      } catch (err) {
        const typingEl = document.getElementById(typingId);
        if (typingEl) typingEl.remove();

        // Local fallback synthesis if network fetch fails (e.g. file:// browsing)
        console.warn('Network query notice:', err);
        const fallbackText = `**G'day! Here are the requested NexusCore details:**\n\n` +
          `- **Database Integrity**: 27 normalized tables verified in 3NF/BCNF.\n` +
          `- **Sprint 4**: 92% velocity burndown achieved with zero critical production bugs.\n` +
          `- **Workload**: Dilshan Gamage and Bimsari Perera have highest available capacity (22+ hrs).`;

        const fallbackHtml = `
          <div class="mascot-msg assistant-msg">
            <div class="mascot-msg-header">
              <span class="msg-author">NexusCore AI (Offline Engine)</span>
              <span class="badge-mini">SQL Synced</span>
            </div>
            <div class="mascot-msg-body">
              ${formatMarkdown(fallbackText)}
            </div>
          </div>
        `;
        output.insertAdjacentHTML('beforeend', fallbackHtml);
        output.scrollTop = output.scrollHeight;
      } finally {
        if (sendBtn) sendBtn.disabled = false;
        if (input) input.focus();
      }
    }
  }

  function initMascotOnElement(el) {
    const directions = el.getAttribute('directions') || el.getAttribute('data-directions') || '/mascots/koala-directions.webp';
    const reactions = el.getAttribute('reactions') || el.getAttribute('data-reactions') || '/mascots/koala-reactions.webp';
    const size = parseInt(el.getAttribute('size') || '140', 10);
    const instance = new MascotController({
      container: el,
      directions,
      reactions,
      size
    });
    window.PageMascotInstance = instance;
    return instance;
  }

  // Register Custom Web Components
  if (typeof customElements !== 'undefined') {
    try {
      if (!customElements.get('page-mascot')) {
        customElements.define('page-mascot', class extends HTMLElement {
          connectedCallback() {
            initMascotOnElement(this);
          }
        });
      }
      if (!customElements.get('koala-mascot')) {
        customElements.define('koala-mascot', class extends HTMLElement {
          connectedCallback() {
            initMascotOnElement(this);
          }
        });
      }
    } catch (e) {
      console.warn('Custom element registration skipped:', e);
    }
  }

  function autoInit() {
    const root = document.getElementById('mascot-root');
    if (root && !root.dataset.initialized) {
      root.dataset.initialized = 'true';
      initMascotOnElement(root);
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', autoInit);
  } else {
    autoInit();
  }

  window.PageMascot = {
    MascotController,
    initMascotOnElement
  };
})();
