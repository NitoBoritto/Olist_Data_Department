// ============================================================
//  THE BLUE TRADE CURRENT — hero-canvas.js
//  Olist Data Department | Brazilian E-Commerce Background
//  Three-layer parallax · Monstera leaves · Data pulse streams
//  Magnetic mouse interaction · Dark/Light theme reactive
// ============================================================

(function () {
  'use strict';

  // ── Canvas Setup ─────────────────────────────────────────
  const canvas = document.getElementById('heroCanvas');
  const ctx    = canvas.getContext('2d');

  let W = 0, H = 0;
  let mouseX = 0, mouseY = 0;
  let targetMouseX = 0, targetMouseY = 0;
  let frame = 0;
  let isDark = false;
  let rafId  = null;

  function resize() {
    W = canvas.width  = window.innerWidth;
    H = canvas.height = window.innerHeight;
    mouseX = targetMouseX = W / 2;
    mouseY = targetMouseY = H / 2;
    rebuildBrazilPaths();
  }

  window.addEventListener('resize', resize);
  window.addEventListener('mousemove', e => {
    targetMouseX = e.clientX;
    targetMouseY = e.clientY;
  });

  // ── Theme Detection ───────────────────────────────────────
  function getTheme() {
    isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    return isDark;
  }

  // Palette pulled from variables.css + extended for canvas art
  const PALETTE = {
    dark: {
      bg1:        '#001F3D',
      bg2:        '#002855',
      leafStroke: 'rgba(0, 217, 255, 0.18)',
      leafFill:   'rgba(0, 100, 200, 0.07)',
      veinColor:  'rgba(0, 217, 255, 0.25)',
      particle:   '#00D9FF',
      particleAlt:'#FFD700',
      pathColor:  'rgba(0, 102, 255, 0.12)',
      mouseGlow:  'rgba(0, 217, 255, 0.15)',
      pulseColor: 'rgba(0, 217, 255, 0.6)',
      gridColor:  'rgba(0, 102, 255, 0.04)',
      nodeColor:  'rgba(0, 217, 255, 0.4)',
    },
    light: {
      bg1:        '#FAFBFC',
      bg2:        '#EEF4FF',
      leafStroke: 'rgba(0, 102, 255, 0.22)',
      leafFill:   'rgba(0, 153, 255, 0.06)',
      veinColor:  'rgba(0, 102, 255, 0.28)',
      particle:   '#0066FF',
      particleAlt:'#00A86B',   // Brazilian emerald green
      pathColor:  'rgba(0, 102, 255, 0.08)',
      mouseGlow:  'rgba(0, 102, 255, 0.10)',
      pulseColor: 'rgba(0, 102, 255, 0.7)',
      gridColor:  'rgba(0, 102, 255, 0.025)',
      nodeColor:  'rgba(0, 102, 255, 0.35)',
    }
  };

  function P() { return isDark ? PALETTE.dark : PALETTE.light; }

  // ── Brazil Map Path (abstract silhouette, normalized 0–1) ─
  // A set of key control-point nodes that loosely trace Brazil's shape
  const BRAZIL_NODES_NORM = [
    // North coast
    [0.20, 0.10], [0.30, 0.05], [0.40, 0.04], [0.52, 0.08], [0.60, 0.06],
    // Northeast bulge
    [0.72, 0.10], [0.80, 0.18], [0.82, 0.28], [0.78, 0.36],
    // East coast going south
    [0.76, 0.44], [0.78, 0.52], [0.74, 0.60], [0.70, 0.68],
    [0.66, 0.74], [0.60, 0.80], [0.52, 0.86],
    // South tip
    [0.44, 0.90], [0.36, 0.88], [0.30, 0.84],
    // West coast going north
    [0.24, 0.78], [0.18, 0.70], [0.14, 0.60],
    [0.12, 0.50], [0.10, 0.40], [0.12, 0.30],
    [0.14, 0.22], [0.16, 0.14], [0.20, 0.10],
  ];

  // Interior "cities" — data pulse origin points (major Olist hubs)
  const CITY_NODES_NORM = [
    { x: 0.55, y: 0.45, label: 'SP', size: 3.2 },  // São Paulo – largest hub
    { x: 0.68, y: 0.35, label: 'RJ', size: 2.4 },
    { x: 0.72, y: 0.25, label: 'BA', size: 1.8 },
    { x: 0.30, y: 0.20, label: 'AM', size: 1.6 },
    { x: 0.40, y: 0.42, label: 'MT', size: 1.4 },
    { x: 0.48, y: 0.60, label: 'PR', size: 1.8 },
    { x: 0.46, y: 0.70, label: 'RS', size: 1.6 },
    { x: 0.60, y: 0.58, label: 'SC', size: 1.4 },
    { x: 0.36, y: 0.32, label: 'GO', size: 1.3 },
    { x: 0.52, y: 0.30, label: 'MG', size: 2.0 },
  ];

  let brazilNodes  = [];
  let cityNodes    = [];
  let brazilPaths  = []; // Bezier path segments between cities

  function rebuildBrazilPaths() {
    brazilNodes = BRAZIL_NODES_NORM.map(([nx, ny]) => ({ x: nx * W, y: ny * H }));
    cityNodes   = CITY_NODES_NORM.map(n => ({ ...n, x: n.x * W, y: n.y * H }));

    // Build trade-route paths between cities
    brazilPaths = [];
    const routes = [
      [0, 1], [0, 2], [0, 3], [0, 4], [1, 2], [1, 5],
      [2, 4], [3, 7], [4, 5], [4, 6], [5, 6], [5, 7],
      [0, 9], [1, 9], [2, 8], [8, 9], [8, 4], [9, 5],
    ];
    for (const [a, b] of routes) {
      if (cityNodes[a] && cityNodes[b]) {
        const ca = cityNodes[a], cb = cityNodes[b];
        // Control points for curved routes
        const cpx = (ca.x + cb.x) / 2 + (Math.random() - 0.5) * W * 0.08;
        const cpy = (ca.y + cb.y) / 2 + (Math.random() - 0.5) * H * 0.08;
        brazilPaths.push({ ax: ca.x, ay: ca.y, bx: cb.x, by: cb.y, cpx, cpy });
      }
    }
  }

  // ── Layer 1 Background — Monstera Leaves ─────────────────
  class MonsteraLeaf {
    constructor(layer) {
      this.layer = layer; // 0=bg, 1=mid, 2=fg
      this.reset(true);
    }

    reset(init) {
      const spread = [1.4, 1.0, 0.6][this.layer];
      this.x    = Math.random() * W * spread - W * (spread - 1) / 2;
      this.y    = init ? Math.random() * H : H + 120;
      this.size = ([60, 90, 130][this.layer]) + Math.random() * ([40, 50, 60][this.layer]);
      this.rot  = Math.random() * Math.PI * 2;
      this.rotV = (Math.random() - 0.5) * 0.0004 * (this.layer + 1);
      const baseSpeed = [0.10, 0.18, 0.30][this.layer];
      this.vy   = -(baseSpeed + Math.random() * 0.15); // drift upward slowly
      this.vx   = (Math.random() - 0.5) * 0.12;
      this.opacity = ([0.12, 0.20, 0.28][this.layer]) + Math.random() * 0.10;
      this.opacityTarget = this.opacity;
      this.parallaxFactor = [0.15, 0.30, 0.50][this.layer];
      // Each leaf has a unique lobe count & split pattern
      this.lobes = 5 + Math.floor(Math.random() * 4);
      this.splitDepth = 0.55 + Math.random() * 0.25;
      // Mouse repel tracking
      this.repelVx = 0;
      this.repelVy = 0;
    }

    update() {
      // Parallax mouse influence
      const px = (mouseX - W / 2) * this.parallaxFactor * 0.002;
      const py = (mouseY - H / 2) * this.parallaxFactor * 0.002;

      // Mouse repulsion
      const dx = this.x - mouseX;
      const dy = this.y - mouseY;
      const dist = Math.sqrt(dx * dx + dy * dy);
      const repelRadius = 180 * this.parallaxFactor;
      if (dist < repelRadius && dist > 1) {
        const force = (1 - dist / repelRadius) * 0.6;
        this.repelVx += (dx / dist) * force;
        this.repelVy += (dy / dist) * force;
        // Gentle rotation away from cursor
        this.rot += force * 0.02;
      }
      this.repelVx *= 0.92;
      this.repelVy *= 0.92;

      this.x   += this.vx + px + this.repelVx;
      this.y   += this.vy + py + this.repelVy;
      this.rot += this.rotV;

      // Gentle pulse opacity
      this.opacity += (this.opacityTarget - this.opacity) * 0.01;

      if (this.y < -this.size * 2) this.reset(false);
    }

    draw() {
      const pal = P();
      ctx.save();
      ctx.translate(this.x, this.y);
      ctx.rotate(this.rot);
      ctx.globalAlpha = this.opacity;

      // Fill
      ctx.fillStyle = pal.leafFill;
      this._drawShape();
      ctx.fill();

      // Stroke / veins
      ctx.strokeStyle = pal.leafStroke;
      ctx.lineWidth = this.layer === 2 ? 1.2 : 0.8;
      this._drawShape();
      ctx.stroke();

      // Central vein
      ctx.strokeStyle = pal.veinColor;
      ctx.lineWidth = this.layer === 2 ? 1.0 : 0.6;
      ctx.beginPath();
      ctx.moveTo(0, -this.size * 0.5);
      ctx.quadraticCurveTo(this.size * 0.05, 0, 0, this.size * 0.5);
      ctx.stroke();

      // Side veins
      ctx.lineWidth = 0.5;
      ctx.globalAlpha = this.opacity * 0.7;
      for (let i = 0; i < this.lobes; i++) {
        const t  = (i + 0.5) / this.lobes;
        const vy = -this.size * 0.5 + t * this.size;
        const vx = this.size * 0.35 * Math.sin(t * Math.PI);
        ctx.beginPath();
        ctx.moveTo(0, vy);
        ctx.quadraticCurveTo(vx * 0.5, vy + this.size * 0.06, vx, vy + this.size * 0.04);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(0, vy);
        ctx.quadraticCurveTo(-vx * 0.5, vy + this.size * 0.06, -vx, vy + this.size * 0.04);
        ctx.stroke();
      }

      ctx.restore();
    }

    _drawShape() {
      // Monstera split-leaf outline
      const s = this.size;
      const lobes = this.lobes;
      ctx.beginPath();
      // Overall egg shape with lobed edges
      for (let a = 0; a < Math.PI * 2; a += 0.05) {
        const r = s * 0.45 * (1 + 0.18 * Math.cos(lobes * a));
        const lobeNotch = 1 - this.splitDepth * 0.3 * Math.pow(Math.max(0, Math.cos(lobes * a)), 4);
        const px = r * lobeNotch * Math.cos(a);
        const py = r * lobeNotch * Math.sin(a) * 1.35;
        if (a < 0.05) ctx.moveTo(px, py); else ctx.lineTo(px, py);
      }
      ctx.closePath();
    }
  }

  // ── Layer 2 — Data Stream Particles ──────────────────────
  class DataParticle {
    constructor() {
      this.pathIdx = Math.floor(Math.random() * Math.max(brazilPaths.length, 1));
      this.t       = Math.random();
      this.speed   = 0.0008 + Math.random() * 0.0012;
      this.size    = 1.5 + Math.random() * 2.5;
      this.isGold  = Math.random() < 0.25; // 25% golden "high-value orders"
      this.trail   = [];
      this.trailLen = 6 + Math.floor(Math.random() * 8);
      this.attractVx = 0;
      this.attractVy = 0;
      this.active  = true;
    }

    getPos(t) {
      if (!brazilPaths.length) return { x: Math.random() * W, y: Math.random() * H };
      const p = brazilPaths[this.pathIdx % brazilPaths.length];
      if (!p) return { x: W / 2, y: H / 2 };
      const inv = 1 - t;
      return {
        x: inv * inv * p.ax + 2 * inv * t * p.cpx + t * t * p.bx,
        y: inv * inv * p.ay + 2 * inv * t * p.cpy + t * t * p.by,
      };
    }

    update() {
      if (!brazilPaths.length) return;
      const pos = this.getPos(this.t);

      // Magnetic attraction toward mouse
      const dx   = mouseX - pos.x;
      const dy   = mouseY - pos.y;
      const dist = Math.sqrt(dx * dx + dy * dy);
      const magRadius = 220;
      let speedBoost = 1;
      if (dist < magRadius && dist > 1) {
        speedBoost = 1 + (1 - dist / magRadius) * 3.5; // up to 4.5× faster
      }

      this.trail.push({ x: pos.x, y: pos.y });
      if (this.trail.length > this.trailLen) this.trail.shift();

      this.t += this.speed * speedBoost;
      if (this.t >= 1) {
        this.t       = 0;
        this.pathIdx = Math.floor(Math.random() * brazilPaths.length);
        this.trail   = [];
        this.isGold  = Math.random() < 0.25;
      }
    }

    draw() {
      if (!brazilPaths.length || this.trail.length < 2) return;
      const pal   = P();
      const color = this.isGold ? pal.particleAlt : pal.particle;

      // Draw trail
      for (let i = 1; i < this.trail.length; i++) {
        const alpha = (i / this.trail.length) * 0.7;
        ctx.globalAlpha = alpha;
        ctx.strokeStyle = color;
        ctx.lineWidth   = this.size * (i / this.trail.length);
        ctx.beginPath();
        ctx.moveTo(this.trail[i - 1].x, this.trail[i - 1].y);
        ctx.lineTo(this.trail[i].x, this.trail[i].y);
        ctx.stroke();
      }

      // Draw head glow
      const head = this.trail[this.trail.length - 1];
      ctx.globalAlpha = 1;
      const grd = ctx.createRadialGradient(head.x, head.y, 0, head.x, head.y, this.size * 3);
      grd.addColorStop(0, color);
      grd.addColorStop(0.4, color.replace(')', ', 0.5)').replace('rgb', 'rgba'));
      grd.addColorStop(1, 'transparent');
      ctx.fillStyle = grd;
      ctx.beginPath();
      ctx.arc(head.x, head.y, this.size * 3, 0, Math.PI * 2);
      ctx.fill();

      // Solid core
      ctx.fillStyle = '#ffffff';
      ctx.globalAlpha = 0.9;
      ctx.beginPath();
      ctx.arc(head.x, head.y, this.size * 0.5, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  // ── Layer 3 — City Node Pulses ────────────────────────────
  class CityPulse {
    constructor(city) {
      this.city  = city;
      this.rings = [];
      this.timer = Math.random() * 180;
    }

    update() {
      this.timer++;
      if (this.timer % 90 === 0) {
        this.rings.push({ r: this.city.size * 4, alpha: 0.8, speed: 0.6 + Math.random() * 0.4 });
      }
      this.rings = this.rings.filter(ring => {
        ring.r     += ring.speed * 2.2;
        ring.alpha -= 0.012;
        return ring.alpha > 0;
      });
    }

    draw() {
      const pal = P();
      const { x, y, size } = this.city;

      // Rings
      for (const ring of this.rings) {
        ctx.globalAlpha = ring.alpha * 0.6;
        ctx.strokeStyle = pal.nodeColor;
        ctx.lineWidth   = 1.2;
        ctx.beginPath();
        ctx.arc(x, y, ring.r, 0, Math.PI * 2);
        ctx.stroke();
      }

      // Core dot
      ctx.globalAlpha = 0.7;
      ctx.fillStyle   = pal.particle;
      ctx.beginPath();
      ctx.arc(x, y, size * 2.5, 0, Math.PI * 2);
      ctx.fill();

      // Inner bright
      ctx.globalAlpha = 1;
      ctx.fillStyle   = '#ffffff';
      ctx.beginPath();
      ctx.arc(x, y, size * 0.9, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  // ── Calathea Pattern Dots (decorative, background layer) ──
  class CalatheDot {
    constructor() {
      this.reset();
    }
    reset() {
      this.x   = Math.random() * W;
      this.y   = Math.random() * H;
      this.r   = 1 + Math.random() * 2.5;
      this.vy  = -0.05 - Math.random() * 0.10;
      this.vx  = (Math.random() - 0.5) * 0.05;
      this.t   = Math.random() * Math.PI * 2;
      this.amp = 0.3 + Math.random() * 0.5;
      this.opacity = 0.06 + Math.random() * 0.12;
    }
    update() {
      this.t  += 0.008;
      this.x  += this.vx + Math.sin(this.t) * this.amp;
      this.y  += this.vy;
      if (this.y < -10) this.reset();
    }
    draw() {
      const pal = P();
      ctx.globalAlpha = this.opacity;
      ctx.fillStyle   = pal.particle;
      ctx.beginPath();
      ctx.arc(this.x, this.y, this.r, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  // ── Object Pools ──────────────────────────────────────────
  let bgLeaves  = [];
  let midLeaves = [];
  let fgLeaves  = [];
  let particles = [];
  let pulses    = [];
  let calatheDots = [];

  function buildScene() {
    bgLeaves    = Array.from({ length: 7  }, () => new MonsteraLeaf(0));
    midLeaves   = Array.from({ length: 9  }, () => new MonsteraLeaf(1));
    fgLeaves    = Array.from({ length: 5  }, () => new MonsteraLeaf(2));
    particles   = Array.from({ length: 55 }, () => new DataParticle());
    calatheDots = Array.from({ length: 40 }, () => new CalatheDot());
    pulses      = cityNodes.map(c => new CityPulse(c));
  }

  // ── Background Gradient ───────────────────────────────────
  function drawBackground() {
    const pal = P();
    ctx.globalAlpha = 1;

    // Base solid
    ctx.fillStyle = pal.bg1;
    ctx.fillRect(0, 0, W, H);

    // Radial mouse glow
    const mg = ctx.createRadialGradient(mouseX, mouseY, 0, mouseX, mouseY, W * 0.45);
    mg.addColorStop(0,   pal.mouseGlow);
    mg.addColorStop(0.5, 'rgba(0,0,0,0)');
    mg.addColorStop(1,   'rgba(0,0,0,0)');
    ctx.fillStyle = mg;
    ctx.fillRect(0, 0, W, H);

    // Atmospheric vignette corner gradients
    const corners = [
      { cx: 0,   cy: 0   },
      { cx: W,   cy: 0   },
      { cx: 0,   cy: H   },
      { cx: W,   cy: H   },
    ];
    for (const { cx, cy } of corners) {
      const cg = ctx.createRadialGradient(cx, cy, 0, cx, cy, W * 0.5);
      cg.addColorStop(0,   isDark ? 'rgba(0,102,255,0.05)' : 'rgba(0,102,255,0.03)');
      cg.addColorStop(1,   'rgba(0,0,0,0)');
      ctx.fillStyle = cg;
      ctx.fillRect(0, 0, W, H);
    }
  }

  // ── Subtle Grid ───────────────────────────────────────────
  function drawGrid() {
    const pal = P();
    ctx.globalAlpha = 1;
    ctx.strokeStyle = pal.gridColor;
    ctx.lineWidth   = 1;

    const gap    = 80;
    const offsetX = (mouseX * 0.02) % gap;
    const offsetY = (mouseY * 0.02) % gap;

    for (let x = -gap + offsetX; x < W + gap; x += gap) {
      ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, H); ctx.stroke();
    }
    for (let y = -gap + offsetY; y < H + gap; y += gap) {
      ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(W, y); ctx.stroke();
    }
  }

  // ── Brazil Map Ghost ──────────────────────────────────────
  function drawBrazilMap() {
    if (brazilNodes.length < 3) return;
    const pal = P();
    ctx.globalAlpha = isDark ? 0.07 : 0.05;
    ctx.strokeStyle = pal.pathColor;
    ctx.lineWidth   = 1.5;

    ctx.beginPath();
    ctx.moveTo(brazilNodes[0].x, brazilNodes[0].y);
    for (let i = 1; i < brazilNodes.length; i++) {
      const prev = brazilNodes[i - 1];
      const curr = brazilNodes[i];
      const cpx  = (prev.x + curr.x) / 2;
      const cpy  = (prev.y + curr.y) / 2;
      ctx.quadraticCurveTo(prev.x, prev.y, cpx, cpy);
    }
    ctx.stroke();

    // Trade route bezier paths
    ctx.globalAlpha = isDark ? 0.10 : 0.07;
    ctx.lineWidth   = 0.8;
    for (const p of brazilPaths) {
      ctx.beginPath();
      ctx.moveTo(p.ax, p.ay);
      ctx.quadraticCurveTo(p.cpx, p.cpy, p.bx, p.by);
      ctx.stroke();
    }
  }

  // ── Main Loop ─────────────────────────────────────────────
  let lastTheme = null;

  function animate() {
    rafId = requestAnimationFrame(animate);
    frame++;

    // Smooth mouse follow
    mouseX += (targetMouseX - mouseX) * 0.06;
    mouseY += (targetMouseY - mouseY) * 0.06;

    // Detect theme change and rebuild colors
    const currentTheme = document.documentElement.getAttribute('data-theme');
    if (currentTheme !== lastTheme) {
      getTheme();
      lastTheme = currentTheme;
    }

    ctx.clearRect(0, 0, W, H);

    // — Draw background
    drawBackground();
    drawGrid();
    drawBrazilMap();

    // — Layer 0: Background leaves + calathea dots
    ctx.globalAlpha = 1;
    calatheDots.forEach(d => { d.update(); d.draw(); });
    bgLeaves.forEach(l => { l.update(); l.draw(); });

    // — Layer 1: Data particles + city pulses
    ctx.globalAlpha = 1;
    particles.forEach(p => { p.update(); p.draw(); });
    pulses.forEach(p => { p.update(); p.draw(); });

    // — Layer 2: Mid leaves
    ctx.globalAlpha = 1;
    midLeaves.forEach(l => { l.update(); l.draw(); });

    // — Layer 3: Foreground leaves
    ctx.globalAlpha = 1;
    fgLeaves.forEach(l => { l.update(); l.draw(); });

    // Reset alpha
    ctx.globalAlpha = 1;
  }

  // ── Init ──────────────────────────────────────────────────
  function init() {
    getTheme();
    resize();
    buildScene();
    if (rafId) cancelAnimationFrame(rafId);
    animate();
  }

  // Observe theme changes via MutationObserver
  new MutationObserver(() => getTheme())
    .observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });

  // Pause animation when tab is hidden (CPU savings)
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
      cancelAnimationFrame(rafId);
    } else {
      animate();
    }
  });

  // Kick it off
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();