// ============================================================
//  HERO CANVAS v5 — "The Blue Trade Current"
//  Olist Data Department
//
//  APPROACH: Brazil's silhouette is defined as a real SVG path,
//  sampled at runtime into a dense grid of particle targets.
//  Particles are born at the "Olist" title, burst outward,
//  then spring into formation on the left side.
//
//  Colors: 🟡 Yellow outline  🟢 Green outline  🟢 Green fill
//          🟡 Yellow (#FFD700) accent fill
//  Leaves: Emerald green, crisp, right-side only
// ============================================================

(function () {
  'use strict';

  // ── Canvas setup ─────────────────────────────────────────
  const canvas = document.getElementById('heroCanvas');
  const ctx    = canvas.getContext('2d');

  let W = 0, H = 0;
  let titleX = 0, titleY = 0;
  let mouseX = 0, mouseY = 0;
  let smoothX = 0, smoothY = 0;
  let rafId   = null;
  let frame   = 0;
  let sceneBuilt = false;

  window.addEventListener('mousemove', e => { mouseX = e.clientX; mouseY = e.clientY; });
  window.addEventListener('resize', () => { resize(); });

  function isDark() {
    return document.documentElement.getAttribute('data-theme') === 'dark';
  }

  // ── Resize ───────────────────────────────────────────────
  function resize() {
    W = canvas.width  = window.innerWidth;
    H = canvas.height = window.innerHeight;
    smoothX = mouseX = W / 2;
    smoothY = mouseY = H / 2;
    locateTitle();
    sampleBrazilShape();
    if (!sceneBuilt) { buildScene(); sceneBuilt = true; }
  }

  // ── Locate the "Olist" title ─────────────────────────────
  function locateTitle() {
    const el = document.querySelector('.hero-title .line1')
            || document.querySelector('.hero-title')
            || document.querySelector('#hero h1')
            || document.querySelector('#hero .hero-content');
    if (el) {
      const r = el.getBoundingClientRect();
      titleX = r.left + r.width  / 2;
      titleY = r.top  + r.height / 2;
    } else {
      titleX = W / 2;
      titleY = H * 0.40;
    }
  }

  // ── Brazil silhouette — real SVG path ────────────────────
  // This path was hand-crafted to match the actual Brazil border
  // with correct NE bulge, Amazon basin, and narrow south tip.
  // ViewBox: 0 0 1000 1000  (we scale to fit the left panel)
  const BRAZIL_SVG_PATH =
    'M 620,40 L 600,30 L 570,22 L 540,20 L 510,26 L 480,42 L 465,58 ' +
    'L 445,52 L 420,46 L 390,46 L 360,54 L 335,68 L 312,88 L 292,112 ' +
    'L 275,140 L 263,170 L 255,200 ' +
    // Northwest indent (Colombia border)
    'L 235,188 L 215,175 L 195,172 L 178,180 L 165,198 L 155,220 ' +
    'L 148,246 L 148,272 L 155,298 L 165,322 ' +
    // West side (Peru/Bolivia border going south)
    'L 138,342 L 118,365 L 106,392 L 102,422 L 108,450 L 116,478 ' +
    'L 118,506 L 112,534 L 108,562 L 112,590 L 122,618 ' +
    // SW corner (Argentina/Paraguay border)
    'L 140,645 L 162,672 L 188,696 L 216,716 L 244,732 L 268,744 ' +
    // South tip (Uruguay border)
    'L 282,770 L 295,800 L 312,826 L 338,848 L 368,860 L 395,868 ' +
    'L 420,876 L 438,890 L 446,912 L 452,930 L 458,912 ' +
    // SE coast going N (Atlantic coast)
    'L 472,888 L 490,860 L 510,832 L 528,802 L 546,772 L 560,742 ' +
    'L 572,710 L 582,678 L 590,646 L 596,614 L 600,582 ' +
    'L 606,550 L 612,518 L 618,486 L 624,454 L 630,422 ' +
    'L 636,390 L 642,358 L 648,326 ' +
    // NE bulge (Fortaleza / Natal / Recife — far right)
    'L 662,308 L 682,286 L 708,266 L 735,250 L 762,238 ' +
    'L 792,226 L 822,218 L 852,212 L 882,208 L 910,206 ' +
    'L 938,204 L 958,200 L 972,192 L 978,178 L 970,162 ' +
    'L 955,150 L 934,140 L 910,132 L 882,124 L 852,116 ' +
    'L 820,108 L 788,100 L 756,092 L 724,082 L 692,070 ' +
    'L 660,056 L 636,046 L 620,040';

  // ── Sample the SVG path into particle target points ───────
  // We draw the path onto an offscreen canvas, then scan pixels
  // to find outline and interior positions.
  let outlineTargets = [];
  let fillTargets    = [];

  // Map region on screen: left side, vertically centered
  // The SVG viewBox is 1000×1000; we scale it to fit this region
  const MAP_LEFT   = 0.015;  // x start (fraction of W)
  const MAP_WIDTH  = 0.42;   // width (fraction of W)
  const MAP_TOP    = 0.04;   // y start (fraction of H)
  const MAP_HEIGHT = 0.92;   // height (fraction of H)

  function sampleBrazilShape() {
    // Offscreen canvas for shape sampling
    const VBOX = 1000;
    const oc  = document.createElement('canvas');
    oc.width  = VBOX;
    oc.height = VBOX;
    const ox  = oc.getContext('2d');

    // Draw filled Brazil shape
    const path2d = new Path2D(BRAZIL_SVG_PATH);
    ox.fillStyle = '#ffffff';
    ox.fill(path2d);

    // Draw outline separately (wider stroke for outline sampling)
    ox.strokeStyle = '#ff0000';
    ox.lineWidth   = 10;
    ox.stroke(path2d);

    const imgData = ox.getImageData(0, 0, VBOX, VBOX).data;

    // Map pixel coords to screen coords
    const mapL = MAP_LEFT   * W;
    const mapW = MAP_WIDTH  * W;
    const mapT = MAP_TOP    * H;
    const mapH = MAP_HEIGHT * H;

    outlineTargets = [];
    fillTargets    = [];

    // Sample every Nth pixel to get ~60 outline + ~140 fill points
    const OUTLINE_STEP = 12; // px in SVG space
    const FILL_STEP    = 48; // px in SVG space

    for (let py = 0; py < VBOX; py++) {
      for (let px = 0; px < VBOX; px++) {
        const idx = (py * VBOX + px) * 4;
        const r = imgData[idx];
        const g = imgData[idx + 1];
        const b = imgData[idx + 2];
        const a = imgData[idx + 3];
        if (a < 128) continue;

        const sx = mapL + (px / VBOX) * mapW;
        const sy = mapT + (py / VBOX) * mapH;

        // Red channel high = outline stroke pixel
        if (r > 200 && g < 100 && py % OUTLINE_STEP === 0 && px % OUTLINE_STEP === 0) {
          outlineTargets.push({ x: sx, y: sy });
        }
        // White = fill interior
        else if (r > 200 && g > 200 && b > 200 && py % FILL_STEP === 0 && px % FILL_STEP === 0) {
          fillTargets.push({ x: sx, y: sy });
        }
      }
    }

    // Rebuild particles if scene already exists
    if (sceneBuilt) rebuildParticles();
  }

  // ── Particle colors — pure vivid for maximum clarity ─────
  const C = {
    dark: {
      green:   '#00FF6A',   // vivid neon green
      green2:  '#00E676',   // slightly softer green
      yellow:  '#FFE600',   // pure bright yellow
      yellow2: '#FFAB00',   // amber yellow
      blue:    '#00D9FF',   // cyan (title match)
    },
    light: {
      green:   '#00C040',
      green2:  '#00A832',
      yellow:  '#F5C400',
      yellow2: '#E09000',
      blue:    '#0066FF',
    },
  };

  function palette() { return isDark() ? C.dark : C.light; }

  function randomFillColor() {
    const p = palette();
    const r = Math.random();
    if (r < 0.38) return p.green;
    if (r < 0.65) return p.green2;
    if (r < 0.82) return p.yellow;
    return p.yellow2;
  }

  // ── Map Particle class ────────────────────────────────────
  class MapParticle {
    constructor(target, isOutline, launchFrame) {
      this.target      = target;
      this.isOutline   = isOutline;
      this.launchFrame = launchFrame;
      this.active      = false;

      // Position starts at title
      this.x = titleX + (Math.random() - 0.5) * 6;
      this.y = titleY + (Math.random() - 0.5) * 6;
      this.vx = 0;
      this.vy = 0;

      // Vibration fingerprint
      this.vpx = Math.random() * Math.PI * 2;
      this.vpy = Math.random() * Math.PI * 2;
      this.vamp = isOutline ? 1.1 : 2.0;
      this.vspd = 0.013 + Math.random() * 0.011;

      // Dot size — bigger for visibility
      this.r = isOutline
        ? (2.5 + Math.random() * 1.0)
        : (1.6 + Math.random() * 1.4);

      // Burst angle — biased toward the left side where the map is
      const biasDeg = 160 + (Math.random() - 0.5) * 130; // ~95°–225°
      this.burstA = biasDeg * Math.PI / 180;
      this.burstS = 1.0 + Math.random() * 1.8;

      // Color
      this.color = isOutline
        ? (Math.random() < 0.55 ? palette().yellow : palette().green)
        : randomFillColor();

      // Scatter
      this.scatterVx   = 0;
      this.scatterVy   = 0;
      this.reformDelay = 0;

      this.opacity = 0;
    }

    launch() {
      this.active = true;
      this.x  = titleX + (Math.random() - 0.5) * 12;
      this.y  = titleY + (Math.random() - 0.5) * 12;
      this.vx = Math.cos(this.burstA) * this.burstS;
      this.vy = Math.sin(this.burstA) * this.burstS;
    }

    update(t, mx, my) {
      if (frame < this.launchFrame) return;
      if (!this.active) this.launch();

      // Fade in smoothly
      this.opacity = Math.min(1, this.opacity + 0.014);

      const tx   = this.target.x;
      const ty   = this.target.y;
      const dxT  = tx - this.x;
      const dyT  = ty - this.y;
      const dist = Math.sqrt(dxT * dxT + dyT * dyT);

      // Mouse scatter
      const dxM = this.x - mx;
      const dyM = this.y - my;
      const dm  = Math.sqrt(dxM * dxM + dyM * dyM);
      const dr  = Math.min(W, H) * 0.15;
      if (dm < dr) {
        const force = (1 - dm / dr) * 4.5;
        this.scatterVx  += (dxM / (dm + 0.5)) * force;
        this.scatterVy  += (dyM / (dm + 0.5)) * force;
        this.reformDelay = 75;
      }
      if (this.reformDelay > 0) this.reformDelay--;
      this.scatterVx *= 0.83;
      this.scatterVy *= 0.83;

      // Spring to target — weak far away, strong when close
      const k = this.reformDelay > 0
        ? 0.009
        : dist < W * 0.20 ? 0.062 : 0.018;
      this.vx += dxT * k;
      this.vy += dyT * k;

      // Vibration (alive feel) — only when near target
      if (dist < W * 0.25) {
        const vs = this.reformDelay > 0 ? 0.15 : 1.0;
        this.vx += Math.sin(t * this.vspd + this.vpx) * this.vamp * vs;
        this.vy += Math.cos(t * this.vspd + this.vpy) * this.vamp * vs;
      }

      const fric = dist < 30 ? 0.68 : 0.80;
      this.vx *= fric;
      this.vy *= fric;
      this.x  += this.vx + this.scatterVx;
      this.y  += this.vy + this.scatterVy;
    }

    draw() {
      if (!this.active || this.opacity <= 0.01) return;

      const dxT = this.x - this.target.x;
      const dyT = this.y - this.target.y;
      const near = Math.sqrt(dxT * dxT + dyT * dyT) < 30;

      let alpha = this.isOutline
        ? (near ? 1.00 : 0.72) * this.opacity
        : (near ? 0.92 : 0.52) * this.opacity;

      ctx.globalAlpha = alpha;
      ctx.fillStyle   = this.color;
      ctx.beginPath();
      ctx.arc(this.x, this.y, this.r, 0, Math.PI * 2);
      ctx.fill();

      // Glow halo on outline dots
      if (this.isOutline && near && this.opacity > 0.8) {
        ctx.globalAlpha = alpha * 0.22;
        ctx.beginPath();
        ctx.arc(this.x, this.y, this.r * 4.5, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  }

  // ── Leaf class ────────────────────────────────────────────
  class TropicalLeaf {
    constructor(layer) {
      this.layer = layer;
      this.reset(true);
    }
    reset(init) {
      // Right 55% only — never overlaps map
      this.x = W * 0.44 + Math.random() * W * 0.58;
      this.y = init ? Math.random() * H : H + 170;
      this.size  = ([72, 110, 152][this.layer]) + Math.random() * 52;
      this.rot   = Math.random() * Math.PI * 2;
      this.swayP = Math.random() * Math.PI * 2;
      this.swayA = (0.028 + Math.random() * 0.046) * (this.layer + 1);
      this.swayS = 0.004 + Math.random() * 0.006;
      this.vy    = -(0.08 + Math.random() * 0.16) * (this.layer * 0.4 + 0.6);
      this.vx    = (Math.random() - 0.5) * 0.06;
      this.px    = [0.06, 0.13, 0.27][this.layer];
      this.op    = [0.30, 0.54, 0.78][this.layer] + Math.random() * 0.12;
      this.rVx   = 0; this.rVy = 0;
      this.lobes = 5 + Math.floor(Math.random() * 4);
      this.cRot  = this.rot;
    }
    update(t) {
      this.cRot = this.rot + Math.sin(t * this.swayS + this.swayP) * this.swayA;
      const po = ((mouseX - W/2)/W) * this.px * 13;
      const qo = ((mouseY - H/2)/H) * this.px * 8;
      const dx = this.x - mouseX, dy = this.y - mouseY;
      const d  = Math.sqrt(dx*dx + dy*dy);
      const rR = 130 + this.layer * 50;
      if (d < rR && d > 1) {
        const f = (1 - d/rR) * 0.40;
        this.rVx += (dx/d)*f; this.rVy += (dy/d)*f;
      }
      this.rVx *= 0.88; this.rVy *= 0.88;
      this.x += this.vx + po*0.015 + this.rVx;
      this.y += this.vy + qo*0.015 + this.rVy;
      if (this.y < -this.size*2) this.reset(false);
    }
    draw() {
      const s = this.size, dark = isDark();
      ctx.save();
      ctx.translate(this.x, this.y);
      ctx.rotate(this.cRot);
      ctx.globalAlpha = this.op;

      ctx.beginPath(); this._path(s);
      ctx.fillStyle = dark ? 'rgba(0,200,85,0.66)' : 'rgba(0,162,68,0.74)';
      ctx.fill();

      ctx.beginPath(); this._path(s);
      ctx.strokeStyle = dark ? 'rgba(0,255,118,0.58)' : 'rgba(0,132,44,0.68)';
      ctx.lineWidth = this.layer===2 ? 1.6 : 1.0;
      ctx.lineJoin  = 'round'; ctx.stroke();

      ctx.beginPath();
      ctx.moveTo(0,-s*0.50); ctx.quadraticCurveTo(s*0.04,0,0,s*0.50);
      ctx.strokeStyle = dark ? 'rgba(128,255,170,0.65)' : 'rgba(0,195,75,0.68)';
      ctx.lineWidth = this.layer===2 ? 1.2 : 0.8; ctx.stroke();

      ctx.globalAlpha = this.op * 0.55;
      ctx.lineWidth = 0.55;
      const vc = this.lobes + 2;
      for (let i = 0; i < vc; i++) {
        const tv = (i+0.5)/vc, vy = -s*0.46+tv*s, vx = s*0.32*Math.sin(tv*Math.PI);
        ctx.beginPath(); ctx.moveTo(0,vy);
        ctx.quadraticCurveTo(vx*0.5,vy+s*0.044,vx,vy+s*0.018); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(0,vy);
        ctx.quadraticCurveTo(-vx*0.5,vy+s*0.044,-vx,vy+s*0.018); ctx.stroke();
      }
      ctx.globalAlpha = this.op * 0.13;
      ctx.strokeStyle = 'rgba(255,255,255,1)';
      ctx.lineWidth = this.layer===2 ? 2.0 : 1.3;
      ctx.beginPath();
      ctx.moveTo(-s*0.09,-s*0.26); ctx.quadraticCurveTo(-s*0.19,0,-s*0.07,s*0.24); ctx.stroke();
      ctx.restore();
    }
    _path(s) {
      for (let i = 0; i <= 72; i++) {
        const a = (i/72)*Math.PI*2;
        const l = 1 + 0.13*Math.cos(this.lobes*a);
        const n = 1 - 0.20*Math.pow(Math.max(0,Math.cos(this.lobes*a)),6);
        const r = s*0.44*l*n;
        i===0 ? ctx.moveTo(r*Math.cos(a),r*Math.sin(a)*1.34)
              : ctx.lineTo(r*Math.cos(a),r*Math.sin(a)*1.34);
      }
      ctx.closePath();
    }
  }

  // ── Title Orbit Dots — circle the Olist word ─────────────
  // 3 rings of dots orbit/pulse around the title at different
  // radii and speeds, using the Brazilian flag colors.
  class TitleOrbitDot {
    constructor(ring) {
      this.ring   = ring;                          // 0 = inner, 1 = mid, 2 = outer
      this.angle  = Math.random() * Math.PI * 2;
      // Each ring: radius, speed, size, color group
      const cfg = [
        { rBase: 68,  speed:  0.012, size: 2.6 },
        { rBase: 110, speed: -0.008, size: 2.0 },
        { rBase: 155, speed:  0.005, size: 1.5 },
      ][ring];
      this.rBase  = cfg.rBase;
      this.speed  = cfg.speed;
      this.size   = cfg.size + Math.random() * 1.0;
      // Slight radius wobble so it looks organic, not mechanical
      this.wobblePhase = Math.random() * Math.PI * 2;
      this.wobbleAmp   = 8 + Math.random() * 10;
      this.wobbleSpeed = 0.008 + Math.random() * 0.006;
      // Pick color — flag palette
      const roll = Math.random();
      this.colorKey = roll < 0.40 ? 'green'
                    : roll < 0.72 ? 'yellow'
                    : roll < 0.88 ? 'yellow2'
                    : 'green2';
      this.opacity = 0.55 + Math.random() * 0.35;
      // Pulse phase (size breathes)
      this.pulsePhase = Math.random() * Math.PI * 2;
    }

    update(t) {
      this.angle += this.speed;
    }

    draw(t) {
      const p   = palette();
      const col = p[this.colorKey];
      // Wobbling radius
      const r   = this.rBase + Math.sin(t * this.wobbleSpeed + this.wobblePhase) * this.wobbleAmp;
      // Pulsing size
      const sz  = this.size * (0.80 + 0.20 * Math.sin(t * 0.018 + this.pulsePhase));

      const x = titleX + Math.cos(this.angle) * r;
      const y = titleY + Math.sin(this.angle) * r;

      ctx.globalAlpha = this.opacity;
      ctx.fillStyle   = col;
      ctx.beginPath();
      ctx.arc(x, y, sz, 0, Math.PI * 2);
      ctx.fill();

      // Small glow halo
      ctx.globalAlpha = this.opacity * 0.25;
      ctx.beginPath();
      ctx.arc(x, y, sz * 3.5, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  // ── Background dots ───────────────────────────────────────
  class FloatDot {
    constructor() { this.reset(true); }
    reset(init) {
      this.x  = Math.random()*W; this.y = init ? Math.random()*H : H+6;
      this.r  = 0.6 + Math.random()*1.3;
      this.vy = -(0.03 + Math.random()*0.07);
      this.vx = (Math.random()-0.5)*0.04;
      this.t  = Math.random()*Math.PI*2;
      this.op = 0.024 + Math.random()*0.050;
    }
    update() {
      this.t += 0.006; this.x += this.vx + Math.sin(this.t)*0.22; this.y += this.vy;
      if (this.y < -8) this.reset(false);
    }
    draw() {
      ctx.globalAlpha = this.op;
      ctx.fillStyle   = isDark() ? '#00D9FF' : '#0066FF';
      ctx.beginPath(); ctx.arc(this.x,this.y,this.r,0,Math.PI*2); ctx.fill();
    }
  }

  // ── Scene ─────────────────────────────────────────────────
  let particles = [];
  let bgLeaves = [], midLeaves = [], fgLeaves = [];
  let floatDots = [];
  let orbitDots = [];

  function rebuildParticles() {
    particles = [];

    // Outline particles — staggered, one per 3 frames, biased left
    outlineTargets.forEach((t, i) => {
      const p = palette();
      const color = i % 2 === 0 ? p.yellow : p.green;
      const mp = new MapParticle(t, true, i * 3);
      mp.color = color;
      particles.push(mp);
    });

    // Fill particles — random delays within 0–200 frames
    fillTargets.forEach(t => {
      const mp = new MapParticle(t, false, Math.floor(Math.random() * 200));
      mp.color = randomFillColor();
      particles.push(mp);
    });
  }

  function buildScene() {
    rebuildParticles();
    bgLeaves  = Array.from({ length: 5 }, () => new TropicalLeaf(0));
    midLeaves = Array.from({ length: 7 }, () => new TropicalLeaf(1));
    fgLeaves  = Array.from({ length: 4 }, () => new TropicalLeaf(2));
    floatDots = Array.from({ length: 28 }, () => new FloatDot());
    // 3 rings: inner 10, mid 14, outer 9 dots
    orbitDots = [
      ...Array.from({ length: 10 }, () => new TitleOrbitDot(0)),
      ...Array.from({ length: 14 }, () => new TitleOrbitDot(1)),
      ...Array.from({ length: 9  }, () => new TitleOrbitDot(2)),
    ];
    // Space them evenly per ring so they don't all clump
    [0, 1, 2].forEach(ring => {
      const inRing = orbitDots.filter(d => d.ring === ring);
      inRing.forEach((d, i) => {
        d.angle = (i / inRing.length) * Math.PI * 2 + Math.random() * 0.3;
      });
    });
  }

  // ── Background ────────────────────────────────────────────
  function drawBG() {
    const dark = isDark();
    ctx.globalAlpha = 1;
    ctx.fillStyle   = dark ? '#001F3D' : '#FAFBFC';
    ctx.fillRect(0, 0, W, H);

    // Mouse glow
    const mg = ctx.createRadialGradient(smoothX, smoothY, 0, smoothX, smoothY, W*0.34);
    mg.addColorStop(0, dark ? 'rgba(0,217,255,0.06)' : 'rgba(0,102,255,0.04)');
    mg.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = mg; ctx.fillRect(0, 0, W, H);

    // Dot grid
    ctx.globalAlpha = dark ? 0.025 : 0.015;
    ctx.fillStyle   = dark ? '#00D9FF' : '#0066FF';
    const gap = 85, ox = (smoothX*0.01)%gap, oy = (smoothY*0.01)%gap;
    for (let gx=-gap+ox; gx<W+gap; gx+=gap)
      for (let gy=-gap+oy; gy<H+gap; gy+=gap) {
        ctx.beginPath(); ctx.arc(gx,gy,1,0,Math.PI*2); ctx.fill();
      }
  }

  function drawLabel() {
    const dark = isDark();
    // Place label below the map
    const cx = MAP_LEFT*W + MAP_WIDTH*W * 0.50;
    const cy = (MAP_TOP + MAP_HEIGHT)*H + 18;
    ctx.save();
    ctx.globalAlpha = dark ? 0.040 : 0.028;
    ctx.fillStyle   = dark ? '#00D9FF' : '#001F3D';
    ctx.font        = `600 ${Math.round(W*0.015)}px 'Inter',sans-serif`;
    ctx.textAlign   = 'center';
    ctx.fillText('BRASIL', cx, cy);
    ctx.restore();
  }

  // ── Animation loop ────────────────────────────────────────
  function animate() {
    rafId = requestAnimationFrame(animate);
    frame++;

    smoothX += (mouseX - smoothX) * 0.05;
    smoothY += (mouseY - smoothY) * 0.05;
    if (frame % 60 === 0) locateTitle();

    drawBG();

    ctx.globalAlpha = 1;
    floatDots.forEach(d => { d.update(); d.draw(); });
    bgLeaves.forEach(l  => { l.update(frame); l.draw(); });

    // Orbit dots around the Olist title
    ctx.globalAlpha = 1;
    orbitDots.forEach(d => { d.update(frame); d.draw(frame); });

    // Map particles
    ctx.globalAlpha = 1;
    particles.forEach(p => { p.update(frame, smoothX, smoothY); p.draw(); });
    drawLabel();

    ctx.globalAlpha = 1;
    midLeaves.forEach(l => { l.update(frame); l.draw(); });
    fgLeaves.forEach(l  => { l.update(frame); l.draw(); });

    ctx.globalAlpha = 1;
  }

  // ── Init ─────────────────────────────────────────────────
  function init() {
    resize();
    if (rafId) cancelAnimationFrame(rafId);
    animate();
  }

  new MutationObserver(() => {})
    .observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });

  document.addEventListener('visibilitychange', () => {
    if (document.hidden) cancelAnimationFrame(rafId); else animate();
  });

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();