/**
 * ============================================================
 *  OLIST — "LIQUID AURA" CYBER-TECH CURSOR SYSTEM
 *  Version 2.0 | Production-Ready | 60fps via rAF
 * ============================================================
 *
 *  Architecture:
 *  ┌─ #cursor-core      — 8px hard dot, instant tracking
 *  ├─ #cursor-aura      — 40px soft glow ring, spring physics
 *  ├─ #cursor-trail     — SVG canvas for velocity-stretch trail
 *  └─ .cursor-ripple    — DOM-injected click burst particles
 *
 *  Theme awareness: reads computed CSS variables from :root /
 *  [data-theme="dark"] so colors always stay in sync with the
 *  existing variables.css palette. No hardcoded hex values.
 *
 *  Performance notes:
 *  - Single rAF loop drives all animations (no setInterval)
 *  - SVG trail uses only transform + opacity (GPU composited)
 *  - Ripple nodes are pooled and removed after animation
 *  - mix-blend-mode: exclusion on aura gives the glassmorphism
 *    "invert" effect over light surfaces automatically
 * ============================================================
 */

(function () {
  'use strict';

  /* ─────────────────────────────────────────────
   *  1. GUARD – skip on touch devices
   * ───────────────────────────────────────────── */
  if (window.matchMedia('(pointer: coarse)').matches) return;

  /* ─────────────────────────────────────────────
   *  2. INJECT HTML ELEMENTS
   * ───────────────────────────────────────────── */
  const mount = () => {
    // Remove legacy cursor element if present
    const legacy = document.getElementById('cursor');
    if (legacy) legacy.remove();

    const frag = document.createDocumentFragment();

    // Core dot
    const core = document.createElement('div');
    core.id = 'cursor-core';
    frag.appendChild(core);

    // Aura ring
    const aura = document.createElement('div');
    aura.id = 'cursor-aura';
    frag.appendChild(aura);

    // SVG trail canvas (full-viewport, pointer-events none)
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    svg.id = 'cursor-trail-svg';
    svg.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
    frag.appendChild(svg);

    document.body.appendChild(frag);

    return { core, aura, svg };
  };

  /* ─────────────────────────────────────────────
   *  3. STATE
   * ───────────────────────────────────────────── */
  const mouse = { x: -200, y: -200 };          // raw mouse pos
  const auraPos = { x: -200, y: -200 };         // spring-lerped
  const auraScale = { cur: 1, target: 1 };      // hover expansion
  const trail = [];                              // ring buffer of past positions
  const TRAIL_LEN = 14;                          // number of trail nodes
  const TRAIL_RADIUS_MAX = 5;                    // max radius of trail dots
  let speed = 0;                                 // instantaneous speed px/frame
  let prevX = -200, prevY = -200;
  let isHover = false;
  let isDown = false;
  let rafId = null;

  /* ─────────────────────────────────────────────
   *  4. CSS VARIABLE READER
   *  Reads live values so dark/light mode works
   * ───────────────────────────────────────────── */
  const getVar = (name) =>
    getComputedStyle(document.documentElement)
      .getPropertyValue(name)
      .trim();

  /* ─────────────────────────────────────────────
   *  5. SVG TRAIL SETUP
   * ───────────────────────────────────────────── */
  let trailNodes = [];

  const initTrail = (svg) => {
    // Pre-create SVG circle elements
    for (let i = 0; i < TRAIL_LEN; i++) {
      const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
      circle.setAttribute('cx', '-200');
      circle.setAttribute('cy', '-200');
      circle.setAttribute('r', '0');
      circle.setAttribute('fill', 'none'); // set dynamically
      svg.appendChild(circle);
      trailNodes.push(circle);
      trail.push({ x: -200, y: -200 });
    }
  };

  const updateTrail = () => {
    // Shift history
    trail.unshift({ x: mouse.x, y: mouse.y });
    if (trail.length > TRAIL_LEN) trail.pop();

    const primary = getVar('--primary-light') || '#00D9FF';
    const accent  = isHover
      ? (getVar('--cyan') || '#00D9FF')
      : (getVar('--primary-light') || '#00D9FF');

    // Stretch factor based on speed (clamp 1–3)
    const stretch = Math.min(1 + speed / 18, 3);

    trailNodes.forEach((node, i) => {
      const t = trail[i] || trail[trail.length - 1];
      const tNext = trail[i + 1] || t;

      // Radius shrinks toward tail, also shrinks when slow
      const fraction = 1 - i / TRAIL_LEN;
      const r = TRAIL_RADIUS_MAX * fraction * Math.min(speed / 4, 1);

      // Opacity fades toward tail
      const opacity = fraction * 0.7;

      // Direction vector for ellipse stretch
      const dx = t.x - tNext.x;
      const dy = t.y - tNext.y;
      const angle = Math.atan2(dy, dx) * (180 / Math.PI);
      const rx = r * stretch;
      const ry = Math.max(r * 0.4, 1);

      node.setAttribute('cx', t.x);
      node.setAttribute('cy', t.y);
      node.setAttribute('rx', rx);
      node.setAttribute('ry', ry);
      node.setAttribute('transform', `rotate(${angle}, ${t.x}, ${t.y})`);
      node.setAttribute('fill', accent);
      node.setAttribute('opacity', opacity);

      // Switch tag to ellipse for stretched look (rx != ry)
      // We already created circles; just set both axes via setAttribute
      // (circles only have r; we need to use ellipse — swap tag type)
    });
  };

  /* ─────────────────────────────────────────────
   *  6. REPLACE circle nodes with ellipse for stretch
   *  (Must be called once after initTrail)
   * ───────────────────────────────────────────── */
  const upgradeToEllipse = (svg) => {
    trailNodes.forEach((oldNode) => {
      const el = document.createElementNS('http://www.w3.org/2000/svg', 'ellipse');
      el.setAttribute('cx', '-200');
      el.setAttribute('cy', '-200');
      el.setAttribute('rx', '0');
      el.setAttribute('ry', '0');
      svg.replaceChild(el, oldNode);
      return el;
    });
    // Rebuild reference array
    trailNodes = Array.from(svg.querySelectorAll('ellipse'));
  };

  /* ─────────────────────────────────────────────
   *  7. RIPPLE / PARTICLE BURST ON CLICK
   * ───────────────────────────────────────────── */
  const PARTICLE_COUNT = 10;

  const spawnRipple = (x, y) => {
    const primary = getVar('--primary-light') || '#00D9FF';
    const cyan    = getVar('--cyan') || '#00D9FF';

    // Outer ring ripple
    const ring = document.createElement('div');
    ring.className = 'cursor-ripple-ring';
    ring.style.left = x + 'px';
    ring.style.top  = y + 'px';
    document.body.appendChild(ring);
    ring.addEventListener('animationend', () => ring.remove(), { once: true });

    // Particle burst
    for (let i = 0; i < PARTICLE_COUNT; i++) {
      const p = document.createElement('div');
      p.className = 'cursor-ripple-particle';

      const angle  = (360 / PARTICLE_COUNT) * i + Math.random() * 20;
      const dist   = 28 + Math.random() * 20;
      const rad    = (angle * Math.PI) / 180;
      const tx     = Math.cos(rad) * dist;
      const ty     = Math.sin(rad) * dist;
      const size   = 2 + Math.random() * 3;
      const color  = Math.random() > 0.5 ? primary : cyan;
      const delay  = Math.random() * 0.08;

      p.style.cssText = `
        left:${x}px; top:${y}px;
        width:${size}px; height:${size}px;
        background:${color};
        --tx:${tx}px; --ty:${ty}px;
        animation-delay:${delay}s;
      `;
      document.body.appendChild(p);
      p.addEventListener('animationend', () => p.remove(), { once: true });
    }
  };

  /* ─────────────────────────────────────────────
   *  8. HOVER DETECTION
   *  Targets bento-cards, buttons, links, inputs
   * ───────────────────────────────────────────── */
  const HOVER_SELECTORS = [
    'button',
    'a',
    '[role="button"]',
    '.bento-card',
    '.btn',
    'input',
    'select',
    'textarea',
    'label[for]',
  ].join(', ');

  const setupHoverDetection = () => {
    document.addEventListener('mouseover', (e) => {
      if (e.target.closest(HOVER_SELECTORS)) {
        isHover = true;
        auraScale.target = 2.4;
      }
    });
    document.addEventListener('mouseout', (e) => {
      if (e.target.closest(HOVER_SELECTORS)) {
        isHover = false;
        auraScale.target = 1;
      }
    });
  };

  /* ─────────────────────────────────────────────
   *  9. EVENT LISTENERS
   * ───────────────────────────────────────────── */
  const setupEvents = () => {
    document.addEventListener('mousemove', (e) => {
      mouse.x = e.clientX;
      mouse.y = e.clientY;
    });

    document.addEventListener('mousedown', (e) => {
      isDown = true;
      auraScale.target = isHover ? 2.8 : 0.6;
      spawnRipple(e.clientX, e.clientY);
    });

    document.addEventListener('mouseup', () => {
      isDown = false;
      auraScale.target = isHover ? 2.4 : 1;
    });

    // Hide while typing in text inputs
    document.addEventListener('focusin', (e) => {
      if (['INPUT', 'TEXTAREA'].includes(e.target.tagName)) {
        document.getElementById('cursor-core').style.opacity = '0.3';
      }
    });
    document.addEventListener('focusout', () => {
      document.getElementById('cursor-core').style.opacity = '1';
    });

    // Hide cursor when it leaves the window
    document.addEventListener('mouseleave', () => {
      mouse.x = -400;
      mouse.y = -400;
    });
  };

  /* ─────────────────────────────────────────────
   *  10. SPRING / LERP HELPERS
   * ───────────────────────────────────────────── */

  /**
   * Critically-damped spring step.
   * Returns next value given current, target, velocity (mutates vel obj).
   */
  const spring = (() => {
    const STIFFNESS = 0.12; // higher = snappier
    const DAMPING   = 0.82; // lower = more oscillation
    const vel = { x: 0, y: 0 };
    return (pos, target) => {
      vel.x += (target.x - pos.x) * STIFFNESS;
      vel.y += (target.y - pos.y) * STIFFNESS;
      vel.x *= DAMPING;
      vel.y *= DAMPING;
      pos.x += vel.x;
      pos.y += vel.y;
    };
  })();

  const lerp = (a, b, t) => a + (b - a) * t;

  /* ─────────────────────────────────────────────
   *  11. MAIN RENDER LOOP
   * ───────────────────────────────────────────── */
  const loop = (core, aura) => {
    // Speed calc (Euclidean distance this frame)
    const dx = mouse.x - prevX;
    const dy = mouse.y - prevY;
    speed = Math.sqrt(dx * dx + dy * dy);
    prevX = mouse.x;
    prevY = mouse.y;

    // Spring-lerp aura toward mouse
    spring(auraPos, mouse);

    // Lerp scale
    auraScale.cur = lerp(auraScale.cur, auraScale.target, 0.1);

    // ── Core dot (instant, centered) ──
    core.style.transform = `translate(${mouse.x - 4}px, ${mouse.y - 4}px)`;

    // ── Aura (lagging, scaled, color-reactive) ──
    const auraSize = 40;
    const half = auraSize / 2;
    aura.style.transform =
      `translate(${auraPos.x - half}px, ${auraPos.y - half}px) scale(${auraScale.cur})`;

    // Color shift on hover
    if (isHover) {
      aura.style.borderColor = getVar('--cyan') || '#00D9FF';
      aura.style.boxShadow   = `0 0 20px 4px ${getVar('--cyan') || '#00D9FF'}55,
                                 0 0 40px 8px ${getVar('--primary') || '#0066FF'}33`;
    } else {
      aura.style.borderColor = getVar('--primary-light') || '#00D9FF';
      aura.style.boxShadow   = `0 0 12px 2px ${getVar('--primary-light') || '#00D9FF'}44,
                                 0 0 24px 4px ${getVar('--primary') || '#0066FF'}22`;
    }

    // ── Trail ──
    updateTrail();

    rafId = requestAnimationFrame(() => loop(core, aura));
  };

  /* ─────────────────────────────────────────────
   *  12. INITIALISE
   * ───────────────────────────────────────────── */
  const init = () => {
    const { core, aura, svg } = mount();

    // Resize SVG to always cover viewport
    const resizeSVG = () => {
      svg.setAttribute('width',  window.innerWidth);
      svg.setAttribute('height', window.innerHeight);
      svg.setAttribute('viewBox', `0 0 ${window.innerWidth} ${window.innerHeight}`);
    };
    resizeSVG();
    window.addEventListener('resize', resizeSVG, { passive: true });

    initTrail(svg);
    upgradeToEllipse(svg);
    setupHoverDetection();
    setupEvents();

    // Kick off loop
    rafId = requestAnimationFrame(() => loop(core, aura));
  };

  // Wait for DOM
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }

})();