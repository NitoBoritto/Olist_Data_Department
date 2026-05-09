/**
 * farghaly.js — 3m Farghaly 🤖  v2.0
 * ─────────────────────────────────────
 * Drop this ONE file into your js/ folder.
 * Add ONE line to index.html:  <script src="js/farghaly.js"></script>
 *
 * It calls the Anthropic API directly from the browser.
 * Set your API key in the CONFIG block below.
 *
 * NO backend, NO npm, NO build step required.
 */

(function () {
  'use strict';

  /* ═══════════════════════════════════════════════════════════
     ✏️  CONFIG — only edit these two lines
  ═══════════════════════════════════════════════════════════ */
  const ANTHROPIC_API_KEY = 'REMOVED';   // ← paste your sk-ant-... key here
  const MODEL             = 'claude-haiku-4-5-20251001';     // fast + cheap, change to claude-opus-4-5 for smarter

  /* ═══════════════════════════════════════════════════════════
     SYSTEM PROMPT
  ═══════════════════════════════════════════════════════════ */
  const SYSTEM_PROMPT = `You are 3m Farghaly 🤖, the elite AI data assistant for the Olist E-commerce Business Intelligence platform. You were built by the Olist Data Team.

PERSONALITY:
- Professional, sharp, and genuinely witty. Like a senior data analyst who actually enjoys their job.
- Use relevant emojis naturally. Never say "Great question!" — just answer.
- When you do not know something, say so and suggest what to check.
- Never fabricate data values. Give SQL to run instead.

OLIST COMPANY KNOWLEDGE:
Olist is a Brazilian e-commerce SaaS platform founded in 2015 by Tiago Dalvi, headquartered in Curitiba, Parana. It connects small and medium businesses to major Brazilian marketplaces (Americanas, Shopee, Mercado Livre, etc.) under a single storefront. Olist handles logistics via Correios and charges a monthly subscription plus commission.

Key milestones:
- 2015: Founded — democratising e-commerce for SMBs in Brazil
- 2018: ~100k orders/month; released the public dataset used for data science
- 2021: Acquired Pax (now Vnda) for D2C; raised Series D funding
- 2022: Launched Olist Pay (fintech); ~1,000 employees
- Dataset covers Sep 2016 to Sep 2018; ~100k orders; 9 relational tables

DATASET TABLES:
olist_orders, olist_order_items, olist_order_payments, olist_order_reviews,
olist_customers, olist_sellers, olist_products,
olist_product_category_name_translation, olist_geolocation

DATA QUERY RULES:
- Write clean SQL with CTEs for readability
- Always alias tables: olist_orders o, olist_order_items oi, etc.
- Filter cancelled orders unless asked: WHERE o.order_status NOT IN ('canceled','unavailable')
- Format numbers with commas; use R$ for Brazilian Real
- Wrap SQL in triple-backtick sql fences
- After SQL, add a 2-sentence plain-English interpretation

RESPONSE FORMAT:
- Concise but complete. No padding.
- Use **bold** for key terms, backtick-code for column/table names.
- State assumptions if the question is ambiguous.`;

  /* ═══════════════════════════════════════════════════════════
     QUICK PROMPTS
  ═══════════════════════════════════════════════════════════ */
  const QUICK_PROMPTS = [
    { label: '🛒 What is Olist?',    text: 'What is Olist and how does it work?' },
    { label: '📊 Top categories',     text: 'What are the top 5 product categories by revenue?' },
    { label: '🚚 Delivery times',     text: 'What is the average delivery time by Brazilian state?' },
    { label: '📈 Order trends',       text: 'Show me monthly order trends for 2017' },
    { label: '⭐ Review insights',     text: 'What factors drive 5-star reviews on Olist?' },
    { label: '🏆 Top sellers',        text: 'Who are the best performing sellers?' },
    { label: '💰 Revenue by region',  text: 'Show revenue breakdown by Brazilian state' },
    { label: '🔄 Late deliveries',    text: 'What percentage of orders were delivered late?' },
  ];

  const THINKING_LABELS = [
    '⚙️ Querying the oracle…',
    '🔍 Scanning 100k orders…',
    '🧠 Consulting the dataset gods…',
    '📡 Pinging the SQL dimension…',
    '☕ Brewing insight… hang on…',
    '🤯 Mind = blown (temporarily)…',
    '🚀 Launching data rockets…',
    '🎯 Targeting your answer…',
    '🧮 Running the numbers…',
    '🕵️ Investigating the data…',
    '⚡ Sparking synapses…',
  ];

  /* ═══════════════════════════════════════════════════════════
     INJECT CSS
  ═══════════════════════════════════════════════════════════ */
  const styleEl = document.createElement('style');
  styleEl.textContent = `
  #fgFab {
    position:fixed; bottom:28px; right:28px;
    width:60px; height:60px; border-radius:18px;
    background:linear-gradient(135deg,var(--primary,#0066FF),var(--primary-light,#00D9FF));
    border:none; cursor:pointer; font-size:26px;
    display:flex; align-items:center; justify-content:center;
    box-shadow:0 8px 30px rgba(0,102,255,0.45);
    transition:all 0.3s; z-index:9000;
    animation:fgFabPop 0.5s cubic-bezier(0.34,1.56,0.64,1) 0.8s both;
  }
  #fgFab:hover { transform:scale(1.1) rotate(-8deg); box-shadow:0 12px 40px rgba(0,217,255,0.55); }
  .fg-fab-dot {
    position:absolute; top:-4px; right:-4px;
    width:14px; height:14px; background:var(--success,#00C853);
    border-radius:50%; border:2px solid var(--bg,#001F3D);
    animation:fgBlink 2s infinite;
  }
  @keyframes fgFabPop { from{opacity:0;transform:scale(0);} to{opacity:1;transform:scale(1);} }
  @keyframes fgBlink  { 0%,100%{opacity:1;} 50%{opacity:0.3;} }

  #fgWindow {
    position:fixed; bottom:100px; right:28px;
    width:400px; max-width:calc(100vw - 40px);
    height:620px; max-height:calc(100vh - 120px);
    flex-direction:column; border-radius:20px; overflow:hidden;
    border:1px solid var(--border,rgba(0,102,255,0.2));
    background:var(--bg2,#002855);
    backdrop-filter:blur(15px); -webkit-backdrop-filter:blur(15px);
    box-shadow:0 0 0 1px var(--border2,rgba(0,102,255,0.1)),0 24px 80px rgba(0,20,60,0.5),0 0 60px rgba(0,102,255,0.1);
    z-index:8999; display:none;
    animation:fgWinPop 0.4s cubic-bezier(0.34,1.56,0.64,1) both;
  }
  @keyframes fgWinPop { from{opacity:0;transform:scale(0.88) translateY(16px);} to{opacity:1;transform:scale(1) translateY(0);} }
  #fgWindow::before {
    content:''; position:absolute; top:0; left:0; right:0; height:3px;
    background:linear-gradient(90deg,var(--primary,#0066FF),var(--primary-light,#00D9FF),#00D9FF);
    background-size:200% 100%; animation:fgScan 3s linear infinite; z-index:10;
  }
  @keyframes fgScan { to{background-position:-200% 0%;} }

  .fg-header {
    flex-shrink:0; padding:14px 16px 12px;
    background:var(--surface,#004080);
    border-bottom:1px solid var(--border2,rgba(0,102,255,0.1));
    display:flex; align-items:center; gap:12px;
  }
  .fg-av-wrap { position:relative; flex-shrink:0; }
  .fg-avatar {
    width:42px; height:42px; border-radius:12px;
    background:linear-gradient(135deg,var(--primary,#0066FF),var(--primary-light,#00D9FF));
    display:flex; align-items:center; justify-content:center; font-size:20px;
    border:1px solid var(--border,rgba(0,102,255,0.2));
    animation:fgPulse 3s ease-in-out infinite;
  }
  @keyframes fgPulse { 0%,100%{box-shadow:0 0 10px rgba(0,102,255,0.3);} 50%{box-shadow:0 0 22px rgba(0,217,255,0.5);} }
  .fg-sdot {
    position:absolute; bottom:-2px; right:-2px; width:11px; height:11px;
    background:var(--success,#00C853); border-radius:50%;
    border:2px solid var(--surface,#004080); animation:fgBlink 2s infinite;
  }
  .fg-info { flex:1; min-width:0; }
  .fg-name { font-weight:800; font-size:14px; letter-spacing:-0.3px; color:var(--text,#fff); display:flex; align-items:center; gap:6px; font-family:'Inter',sans-serif; }
  .fg-badge { font-size:9px; font-weight:700; letter-spacing:1px; text-transform:uppercase; color:var(--primary-light,#00D9FF); background:rgba(0,102,255,0.15); border:1px solid var(--border,rgba(0,102,255,0.2)); border-radius:4px; padding:2px 6px; font-family:'Inter',sans-serif; }
  .fg-online { font-size:11px; color:var(--success,#00C853); margin-top:2px; font-weight:500; font-family:'Inter',sans-serif; }
  .fg-online::before { content:'● '; font-size:7px; }
  .fg-hdr-actions { display:flex; gap:6px; }
  .fg-btn { width:30px; height:30px; border-radius:7px; background:transparent; border:1px solid var(--border2,rgba(0,102,255,0.1)); color:var(--text-dim,#B8C5D6); cursor:pointer; display:flex; align-items:center; justify-content:center; font-size:13px; transition:all 0.2s; font-family:'Inter',sans-serif; }
  .fg-btn:hover { border-color:var(--primary,#0066FF); color:var(--primary-light,#00D9FF); background:rgba(0,102,255,0.08); }

  .fg-chips { flex-shrink:0; padding:8px 12px; display:flex; gap:7px; overflow-x:auto; scrollbar-width:none; background:var(--bg2,#002855); border-bottom:1px solid var(--border2,rgba(0,102,255,0.1)); }
  .fg-chips::-webkit-scrollbar { display:none; }
  .fg-chip { flex-shrink:0; font-family:'Inter',sans-serif; font-size:11px; font-weight:600; padding:5px 12px; border-radius:20px; border:1px solid var(--border,rgba(0,102,255,0.2)); background:var(--surface,#004080); color:var(--text-dim,#B8C5D6); cursor:pointer; white-space:nowrap; transition:all 0.2s; }
  .fg-chip:hover { border-color:var(--primary-light,#00D9FF); color:var(--primary-light,#00D9FF); background:rgba(0,217,255,0.07); transform:translateY(-1px); }

  .fg-messages { flex:1; overflow-y:auto; padding:14px 13px; display:flex; flex-direction:column; gap:12px; scrollbar-width:thin; scrollbar-color:var(--border,rgba(0,102,255,0.2)) transparent; }
  .fg-messages::-webkit-scrollbar { width:3px; }
  .fg-messages::-webkit-scrollbar-thumb { background:var(--border,rgba(0,102,255,0.2)); border-radius:2px; }

  .fg-welcome { text-align:center; padding:22px 14px 16px; }
  .fg-welcome-icon { font-size:36px; margin-bottom:8px; }
  .fg-welcome-title { font-size:16px; font-weight:800; color:var(--text,#fff); letter-spacing:-0.5px; margin-bottom:5px; font-family:'Inter',sans-serif; }
  .fg-welcome-sub { font-size:12px; color:var(--text-dim,#B8C5D6); line-height:1.6; max-width:270px; margin:0 auto; font-family:'Inter',sans-serif; }
  .fg-welcome-hr { margin:12px 0; border:none; border-top:1px solid var(--border2,rgba(0,102,255,0.1)); }
  .fg-welcome-foot { font-size:10px; color:var(--text-dimmer,#6B7C93); font-family:'Inter',sans-serif; }

  .fg-msg { display:flex; gap:8px; align-items:flex-end; animation:fgMsgIn 0.3s ease both; }
  @keyframes fgMsgIn { from{opacity:0;transform:translateY(8px);} to{opacity:1;transform:translateY(0);} }
  .fg-msg.fg-user { flex-direction:row-reverse; }
  .fg-av-sm { width:26px; height:26px; border-radius:7px; flex-shrink:0; background:linear-gradient(135deg,var(--primary,#0066FF),var(--primary-light,#00D9FF)); display:flex; align-items:center; justify-content:center; font-size:13px; border:1px solid var(--border,rgba(0,102,255,0.2)); }
  .fg-av-sm.u { background:rgba(0,102,255,0.2); font-size:9px; font-weight:700; color:var(--primary-light,#00D9FF); letter-spacing:-0.3px; font-family:'Inter',sans-serif; }
  .fg-bubble { max-width:82%; padding:10px 13px; border-radius:14px; font-size:13px; line-height:1.65; word-break:break-word; font-family:'Inter',sans-serif; }
  .fg-msg:not(.fg-user) .fg-bubble { background:var(--surface,#004080); border:1px solid var(--border2,rgba(0,102,255,0.1)); color:var(--text,#fff); border-bottom-left-radius:4px; }
  .fg-msg.fg-user .fg-bubble { background:linear-gradient(135deg,var(--primary,#0066FF),var(--primary-dark,#0052CC)); color:#fff; border-bottom-right-radius:4px; box-shadow:0 4px 16px rgba(0,102,255,0.3); }
  .fg-bubble code { font-family:'Share Tech Mono',monospace; font-size:11px; background:rgba(0,217,255,0.12); color:var(--cyan,#00D9FF); padding:1px 5px; border-radius:4px; }
  .fg-bubble pre { font-family:'Share Tech Mono',monospace; font-size:11px; background:rgba(0,0,0,0.3); border:1px solid var(--border,rgba(0,102,255,0.2)); border-radius:8px; padding:10px 12px; overflow-x:auto; margin-top:8px; color:var(--cyan,#00D9FF); line-height:1.6; white-space:pre; }
  .fg-bubble strong { font-weight:700; color:var(--primary-light,#00D9FF); }
  .fg-msg.fg-user .fg-bubble strong { color:#fff; }
  .fg-time { font-size:10px; color:var(--text-dimmer,#6B7C93); margin-top:3px; padding:0 3px; font-family:'Inter',sans-serif; }
  .fg-msg:not(.fg-user) .fg-time { text-align:left; }
  .fg-msg.fg-user .fg-time { text-align:right; }

  .fg-thinking { display:flex; gap:8px; align-items:flex-end; animation:fgMsgIn 0.3s ease both; }
  .fg-think-bub { background:var(--surface,#004080); border:1px solid var(--border2,rgba(0,102,255,0.1)); border-radius:14px; border-bottom-left-radius:4px; padding:11px 15px; display:flex; flex-direction:column; gap:7px; }
  .fg-think-lbl { font-size:11px; color:var(--primary-light,#00D9FF); font-weight:600; display:flex; align-items:center; gap:5px; font-family:'Inter',sans-serif; }
  .fg-spin { animation:fgSpin 1.5s linear infinite; display:inline-block; }
  @keyframes fgSpin { to{transform:rotate(360deg);} }
  .fg-skels { display:flex; flex-direction:column; gap:5px; }
  .fg-skel { height:9px; border-radius:5px; background:linear-gradient(90deg,var(--border2,rgba(0,102,255,0.1)) 25%,var(--border,rgba(0,102,255,0.2)) 50%,var(--border2,rgba(0,102,255,0.1)) 75%); background-size:200% 100%; animation:fgShimmer 1.4s linear infinite; }
  @keyframes fgShimmer { to{background-position:-200% 0%;} }
  .fg-skel.s1{width:80%;} .fg-skel.s2{width:58%;} .fg-skel.s3{width:70%;}

  .fg-error { background:rgba(255,107,157,0.08); border:1px solid rgba(255,107,157,0.3); border-radius:10px; padding:9px 13px; font-size:12px; color:var(--pink,#FF6B9D); font-family:'Inter',sans-serif; line-height:1.5; }

  .fg-input-area { flex-shrink:0; padding:11px 12px 13px; background:var(--surface,#004080); border-top:1px solid var(--border2,rgba(0,102,255,0.1)); }
  .fg-input-row { display:flex; gap:8px; align-items:flex-end; background:var(--bg2,#002855); border:1px solid var(--border,rgba(0,102,255,0.2)); border-radius:12px; padding:9px 10px; transition:border-color 0.2s; }
  .fg-input-row:focus-within { border-color:var(--primary,#0066FF); box-shadow:0 0 0 3px rgba(0,102,255,0.12); }
  #fgInput { flex:1; background:transparent; border:none; outline:none; font-family:'Inter',sans-serif; font-size:13px; color:var(--text,#fff); resize:none; max-height:90px; line-height:1.5; scrollbar-width:none; }
  #fgInput::-webkit-scrollbar { display:none; }
  #fgInput::placeholder { color:var(--text-dimmer,#6B7C93); }
  #fgSend { width:34px; height:34px; border-radius:9px; flex-shrink:0; background:linear-gradient(135deg,var(--primary,#0066FF),var(--primary-light,#00D9FF)); border:none; cursor:pointer; color:#fff; font-size:16px; display:flex; align-items:center; justify-content:center; box-shadow:0 4px 12px rgba(0,102,255,0.4); transition:all 0.2s; }
  #fgSend:hover:not(:disabled) { transform:scale(1.08); box-shadow:0 6px 20px rgba(0,102,255,0.55); }
  #fgSend:disabled { opacity:0.35; cursor:not-allowed; transform:none; }
  .fg-footer2 { display:flex; justify-content:space-between; margin-top:6px; padding:0 2px; }
  .fg-hint { font-size:10px; color:var(--text-dimmer,#6B7C93); font-family:'Inter',sans-serif; }
  .fg-chars { font-size:10px; color:var(--text-dimmer,#6B7C93); font-family:'Share Tech Mono',monospace; }

  @media(max-width:480px){ #fgWindow{right:10px;left:10px;width:auto;bottom:88px;} #fgFab{bottom:20px;right:16px;} }
  `;
  document.head.appendChild(styleEl);

  /* ═══════════════════════════════════════════════════════════
     STATE
  ═══════════════════════════════════════════════════════════ */
  let history  = [];
  let loading  = false;
  let winOpen  = false;
  let thinkEl  = null;
  let thinkIv  = null;

  /* ═══════════════════════════════════════════════════════════
     BUILD DOM
  ═══════════════════════════════════════════════════════════ */
  function buildDOM() {
    // FAB button
    const fab = document.createElement('button');
    fab.id = 'fgFab';
    fab.title = 'Chat with 3m Farghaly';
    fab.innerHTML = '🤖<span class="fg-fab-dot"></span>';
    fab.addEventListener('click', toggleWindow);
    document.body.appendChild(fab);

    // Chat window
    const win = document.createElement('div');
    win.id = 'fgWindow';
    win.innerHTML = `
      <div class="fg-header">
        <div class="fg-av-wrap">
          <div class="fg-avatar">🤖</div>
          <span class="fg-sdot"></span>
        </div>
        <div class="fg-info">
          <div class="fg-name">3m Farghaly <span class="fg-badge">AI</span></div>
          <div class="fg-online">Online — Ready to crunch data</div>
        </div>
        <div class="fg-hdr-actions">
          <button class="fg-btn" id="fgClearBtn" title="Clear chat">🗑️</button>
          <button class="fg-btn" id="fgExportBtn" title="Export chat">💾</button>
          <button class="fg-btn" id="fgCloseBtn" title="Close">✕</button>
        </div>
      </div>

      <div class="fg-chips" id="fgChips"></div>

      <div class="fg-messages" id="fgMessages">
        <div class="fg-welcome" id="fgWelcome">
          <div class="fg-welcome-icon">🤖</div>
          <div class="fg-welcome-title">Salut! I'm 3m Farghaly</div>
          <div class="fg-welcome-sub">
            Your elite Olist data buddy. Ask me about company history,
            SQL queries, delivery times, top sellers — anything.<br>
            I don't bite… datasets do. 😈
          </div>
          <div class="fg-welcome-hr"></div>
          <div class="fg-welcome-foot">🔗 Olist Dataset &nbsp;·&nbsp; ⚡ Claude AI</div>
        </div>
      </div>

      <div class="fg-input-area">
        <div class="fg-input-row">
          <textarea id="fgInput" rows="1" placeholder="Ask 3m Farghaly anything…" maxlength="1000"></textarea>
          <button id="fgSend" title="Send (Enter)">➤</button>
        </div>
        <div class="fg-footer2">
          <span class="fg-hint">⏎ Send &nbsp;·&nbsp; ⇧⏎ New line</span>
          <span class="fg-chars" id="fgChars">0 / 1000</span>
        </div>
      </div>
    `;
    document.body.appendChild(win);

    // Wire header buttons
    win.querySelector('#fgCloseBtn').addEventListener('click', toggleWindow);
    win.querySelector('#fgClearBtn').addEventListener('click', clearChat);
    win.querySelector('#fgExportBtn').addEventListener('click', exportChat);

    // Wire input
    const input = win.querySelector('#fgInput');
    input.addEventListener('input', onInput);
    input.addEventListener('keydown', onKey);
    win.querySelector('#fgSend').addEventListener('click', sendMessage);

    // Render quick-prompt chips
    const chipsRow = win.querySelector('#fgChips');
    QUICK_PROMPTS.forEach(function(p) {
      const btn = document.createElement('button');
      btn.className = 'fg-chip';
      btn.textContent = p.label;
      btn.addEventListener('click', function() { quickSend(p.text); });
      chipsRow.appendChild(btn);
    });
  }

  /* ═══════════════════════════════════════════════════════════
     TOGGLE
  ═══════════════════════════════════════════════════════════ */
  function toggleWindow() {
    winOpen = !winOpen;
    var win = document.getElementById('fgWindow');
    var fab = document.getElementById('fgFab');
    if (winOpen) {
      win.style.display = 'flex';
      fab.style.display = 'none';
      setTimeout(function() {
        var inp = document.getElementById('fgInput');
        if (inp) inp.focus();
      }, 60);
    } else {
      win.style.display = 'none';
      fab.style.display = 'flex';
    }
  }

  /* ═══════════════════════════════════════════════════════════
     INPUT
  ═══════════════════════════════════════════════════════════ */
  function onInput() {
    var el = document.getElementById('fgInput');
    el.style.height = 'auto';
    el.style.height = Math.min(el.scrollHeight, 90) + 'px';
    document.getElementById('fgChars').textContent = el.value.length + ' / 1000';
  }

  function onKey(e) {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendMessage(); }
  }

  function quickSend(text) {
    if (loading) return;
    var el = document.getElementById('fgInput');
    el.value = text;
    onInput();
    sendMessage();
  }

  /* ═══════════════════════════════════════════════════════════
     SEND
  ═══════════════════════════════════════════════════════════ */
  async function sendMessage() {
    if (loading) return;
    var input = document.getElementById('fgInput');
    var text  = input.value.trim();
    if (!text) return;

    var wc = document.getElementById('fgWelcome');
    if (wc) wc.remove();

    input.value = '';
    input.style.height = 'auto';
    document.getElementById('fgChars').textContent = '0 / 1000';

    loading = true;
    document.getElementById('fgSend').disabled = true;

    appendUser(text);
    history.push({ role: 'user', content: text });
    showThinking();

    try {
      var reply = await callClaude(history);
      removeThinking();
      appendBot(reply);
      history.push({ role: 'assistant', content: reply });
    } catch (err) {
      removeThinking();
      appendError(err.message);
    } finally {
      loading = false;
      document.getElementById('fgSend').disabled = false;
      var inp = document.getElementById('fgInput');
      if (inp) inp.focus();
    }
  }

  /* ═══════════════════════════════════════════════════════════
     CALL CLAUDE
  ═══════════════════════════════════════════════════════════ */
  async function callClaude(msgs) {
    if (!ANTHROPIC_API_KEY || ANTHROPIC_API_KEY === 'YOUR_API_KEY_HERE') {
      throw new Error('No API key set! Open js/farghaly.js and paste your Anthropic key into ANTHROPIC_API_KEY at the top of the file.');
    }

    var res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type':      'application/json',
        'x-api-key':         ANTHROPIC_API_KEY,
        'anthropic-version': '2023-06-01',
        'anthropic-dangerous-direct-browser-access': 'true',
      },
      body: JSON.stringify({
        model:      MODEL,
        max_tokens: 1024,
        system:     SYSTEM_PROMPT,
        messages:   msgs.slice(-12),
      }),
    });

    if (!res.ok) {
      var err = {};
      try { err = await res.json(); } catch(_) {}
      var msg = (err && err.error && err.error.message) ? err.error.message : ('HTTP ' + res.status);
      if (res.status === 401) throw new Error('Invalid API key — double-check it in js/farghaly.js');
      if (res.status === 429) throw new Error('Rate limit hit — wait 10 seconds then try again 😅');
      throw new Error(msg);
    }

    var data = await res.json();
    return (data.content && data.content[0] && data.content[0].text) ? data.content[0].text : '(no response)';
  }

  /* ═══════════════════════════════════════════════════════════
     DOM HELPERS
  ═══════════════════════════════════════════════════════════ */
  function scrollBottom() {
    var a = document.getElementById('fgMessages');
    if (a) a.scrollTo({ top: a.scrollHeight, behavior: 'smooth' });
  }

  function timeNow() {
    return new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }

  function esc(s) {
    return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
  }

  function renderMd(text) {
    return text
      .replace(/```(\w*)\n?([\s\S]*?)```/g, function(_,__,code){ return '<pre>' + esc(code.trim()) + '</pre>'; })
      .replace(/`([^`\n]+)`/g,    function(_,c){ return '<code>' + esc(c) + '</code>'; })
      .replace(/\*\*([^*]+)\*\*/g,'<strong>$1</strong>')
      .replace(/\*([^*\n]+)\*/g,  '<em>$1</em>')
      .replace(/\n/g, '<br>');
  }

  function appendUser(text) {
    var el = document.createElement('div');
    el.className = 'fg-msg fg-user';
    el.innerHTML = '<div><div class="fg-bubble">' + esc(text) + '</div><div class="fg-time">' + timeNow() + '</div></div><div class="fg-av-sm u">ME</div>';
    document.getElementById('fgMessages').appendChild(el);
    scrollBottom();
  }

  function appendBot(text) {
    var el = document.createElement('div');
    el.className = 'fg-msg';
    el.innerHTML = '<div class="fg-av-sm">🤖</div><div><div class="fg-bubble">' + renderMd(text) + '</div><div class="fg-time">' + timeNow() + '</div></div>';
    document.getElementById('fgMessages').appendChild(el);
    scrollBottom();
  }

  function appendError(msg) {
    var el = document.createElement('div');
    el.className = 'fg-error';
    el.textContent = '🚨 ' + msg;
    document.getElementById('fgMessages').appendChild(el);
    scrollBottom();
  }

  function randThink() {
    return THINKING_LABELS[Math.floor(Math.random() * THINKING_LABELS.length)];
  }

  function showThinking() {
    thinkEl = document.createElement('div');
    thinkEl.className = 'fg-thinking';
    thinkEl.innerHTML = '<div class="fg-av-sm">🤖</div><div class="fg-think-bub"><div class="fg-think-lbl"><span class="fg-spin">⚙️</span><span id="fgThinkTxt">' + randThink() + '</span></div><div class="fg-skels"><div class="fg-skel s1"></div><div class="fg-skel s2"></div><div class="fg-skel s3"></div></div></div>';
    document.getElementById('fgMessages').appendChild(thinkEl);
    scrollBottom();
    thinkIv = setInterval(function() {
      var t = document.getElementById('fgThinkTxt');
      if (t) t.textContent = randThink();
    }, 1800);
  }

  function removeThinking() {
    clearInterval(thinkIv);
    if (thinkEl && thinkEl.parentNode) thinkEl.parentNode.removeChild(thinkEl);
    thinkEl = null;
  }

  /* ═══════════════════════════════════════════════════════════
     CLEAR & EXPORT
  ═══════════════════════════════════════════════════════════ */
  function clearChat() {
    if (!confirm('Wipe the board? 3m Farghaly will forget everything 😅')) return;
    history = [];
    var area = document.getElementById('fgMessages');
    area.innerHTML = '';
    var wc = document.createElement('div');
    wc.className = 'fg-welcome';
    wc.id = 'fgWelcome';
    wc.innerHTML = '<div class="fg-welcome-icon">🤖</div><div class="fg-welcome-title">Fresh start!</div><div class="fg-welcome-sub">What data mystery shall we solve today? 🕵️</div><div class="fg-welcome-hr"></div><div class="fg-welcome-foot">🔗 Olist Dataset &nbsp;·&nbsp; ⚡ Claude AI</div>';
    area.appendChild(wc);
  }

  function exportChat() {
    if (!history.length) { alert('Nothing to export yet! Chat first 😄'); return; }
    var lines = history.map(function(m){ return '[' + m.role.toUpperCase() + ']\n' + m.content + '\n'; }).join('\n');
    var blob  = new Blob(['3m Farghaly — Chat Export\n' + '─'.repeat(40) + '\n\n' + lines], { type:'text/plain' });
    var a     = document.createElement('a');
    a.href    = URL.createObjectURL(blob);
    a.download = 'farghaly-' + Date.now() + '.txt';
    a.click();
  }

  /* ═══════════════════════════════════════════════════════════
     INIT
  ═══════════════════════════════════════════════════════════ */
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', buildDOM);
  } else {
    buildDOM();
  }

})();