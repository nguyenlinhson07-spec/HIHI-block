(function () {
  'use strict';

  // ============================================================
  // CONSTANTS
  // ============================================================
  const LEVELS = window.LEVELS;

  // Part F — reduced motion: shortens FX durations, drops camera shake,
  // and thins particle counts, without removing gameplay-critical feedback.
  const REDUCED_MOTION = !!(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches);
  function rm(full, reduced) { return REDUCED_MOTION ? reduced : full; }

  const SWIPE_MIN_DIST = 42; // logical px — C2/C3 threshold (35-55 range); below this a gesture is a TAP -> CIRCLE

  // World-unit brick/ball proportions (scaled to CSS px by worldScale()).
  // worldScale() = min(GW,H)/640, so brick/ball width is always a fixed
  // fraction of the gameplay column (BRICK_W/640 ≈ 47%, BALL_RADIUS*2/640
  // = 15%) regardless of device size — matching the reference's relative
  // proportions at any screen width, calibrated against a ~500px-wide
  // reference canvas (220-250px bricks, 68-82px ball there).
  const BRICK_W = 300;
  const BRICK_H = 94;
  const BRICK_GAP = 5;
  const BRICK_SPACING = BRICK_H + BRICK_GAP;
  const BALL_RADIUS = 48;
  const BALL_REST_RADII = 2.0;  // resting gap above the active brick, in ball radii
  const BALL_RISE_FRACTION = 0.7; // bounce apex height, as a fraction of BRICK_H
  const BOUNCE_RISE_MIN_PX = 70, BOUNCE_RISE_MAX_PX = 110; // A3 — clamps the on-screen bounce travel to a consistent, gentle band regardless of viewport scale
  const VISIBLE_BRICKS = 6; // how many stack slots are rendered below the ball
  const STACK_EASE = 8;     // per-second lerp rate for the stack-slide animation (~125ms)

  // LEVEL_CLEAR_IDLE_BOUNCE — a separate, decorative-only bounce used while
  // state === 'win'. Deliberately not driven by cycleElapsed/bouncePeriod or
  // any collision logic, so it can never re-trigger gameplay events.
  const IDLE_BOUNCE_PERIOD = 1.3;   // seconds — within the 1.1-1.5s target
  const IDLE_BOUNCE_HEIGHT_PX = 46; // within the 35-60px target

  // Red danger bricks only show their spike row while they are the current
  // ACTIVE brick (not while buried lower in the stack) — see isActive in
  // drawBrick(). Since spikes only ever appear on the active slot, right
  // under the ball's existing bounce headroom, the stack keeps uniform
  // spacing; no per-brick extra room is reserved.
  const SPIKE_COUNT = 5;
  const SPIKE_H = 34;     // world units (~26px displayed at the 500px reference width)
  const SPIKE_REVEAL_DURATION = 0.13; // seconds — quick rise-out animation, within 100-160ms
  const RED_BALL_EXTRA_CLEARANCE = 20; // world units — a little extra visual headroom above an active red brick's spikes

  // Centralized color tokens for the canvas-drawn gameplay scene (mirrors
  // the --game-* CSS variables used by the DOM-based in-game HUD).
  const GAME_THEME = {
    bgOuter: '#140f2e',
    bgCenterTop: '#4a3a8f',
    bgCenterBottom: '#241a52',
    brickBlue: '#4fd1ff',
    brickBlueDark: '#1f8fc4',
    brickHighlight: 'rgba(255,255,255,0.5)',
    brickRed: '#ff5c5c',
    brickRedDark: '#b02e2e',
    brickGreen: '#7ee787',
    brickGreenDark: '#2e9c4f',
    brickOutline: '#ffffff',
    panelTeal: '#0e5c68',
    panelRed: '#7a1414',
    panelGreen: '#0e5c2a',
    baseTan: '#e0a35c',
    baseTanDark: '#a8702f',
    baseStem: '#8a5a2e',
  };
  function brickPalette(type) {
    if (type === 'red') return { body: GAME_THEME.brickRed, dark: GAME_THEME.brickRedDark, panel: GAME_THEME.panelRed };
    if (type === 'green') return { body: GAME_THEME.brickGreen, dark: GAME_THEME.brickGreenDark, panel: GAME_THEME.panelGreen };
    return { body: GAME_THEME.brickBlue, dark: GAME_THEME.brickBlueDark, panel: GAME_THEME.panelTeal };
  }

  // ============================================================
  // DOM
  // ============================================================
  const canvas = document.getElementById('game-canvas');
  const ctx = canvas.getContext('2d');
  const bgCanvas = document.getElementById('bg-canvas');
  const bgCtx = bgCanvas.getContext('2d');
  const hudLevel = document.getElementById('hud-level');
  const levelBanner = document.getElementById('level-banner');
  const swipeArea = document.getElementById('swipe-area');

  const overlayStart = document.getElementById('overlay-start');
  const overlayWin = document.getElementById('overlay-win');
  const overlayLose = document.getElementById('overlay-lose');
  const overlayLevels = document.getElementById('overlay-levels');
  const overlaySkins = document.getElementById('overlay-skins');
  const overlaySettings = document.getElementById('overlay-settings');
  const winTitleEl = document.getElementById('win-title');
  const levelPagesEl = document.getElementById('level-pages');
  const pageDotsEl = document.getElementById('page-dots');
  const btnPagePrev = document.getElementById('btn-page-prev');
  const btnPageNext = document.getElementById('btn-page-next');
  const startLevelNumEl = document.getElementById('start-level-num');
  const previewCanvas = document.getElementById('preview-canvas');
  const previewCtx = previewCanvas.getContext('2d');

  const soundSettingsStateEl = document.getElementById('sound-settings-state');

  // ============================================================
  // PERSISTENCE
  // ============================================================
  function getBest(levelIdx) {
    try { return parseInt(localStorage.getItem('bricksMaster_best_' + levelIdx) || '0', 10); }
    catch (e) { return 0; }
  }
  function setBest(levelIdx, score) {
    try {
      if (score > getBest(levelIdx)) localStorage.setItem('bricksMaster_best_' + levelIdx, String(score));
    } catch (e) { /* storage unavailable — ignore */ }
  }
  function getUnlocked() {
    try { return parseInt(localStorage.getItem('bricksMaster_unlocked') || '0', 10); }
    catch (e) { return 0; }
  }
  function setUnlocked(idx) {
    try {
      if (idx > getUnlocked()) localStorage.setItem('bricksMaster_unlocked', String(idx));
    } catch (e) { /* ignore */ }
  }
  function getStars(levelIdx) {
    try { return parseInt(localStorage.getItem('bricksMaster_stars_' + levelIdx) || '0', 10); }
    catch (e) { return 0; }
  }
  function setStars(levelIdx, stars) {
    try {
      if (stars > getStars(levelIdx)) localStorage.setItem('bricksMaster_stars_' + levelIdx, String(stars));
    } catch (e) { /* ignore */ }
  }
  function resetProgress() {
    try {
      for (let i = 0; i < LEVELS.length; i++) {
        localStorage.removeItem('bricksMaster_best_' + i);
        localStorage.removeItem('bricksMaster_stars_' + i);
      }
      localStorage.removeItem('bricksMaster_unlocked');
    } catch (e) { /* ignore */ }
  }

  // ============================================================
  // SOUND (lightweight WebAudio beep hooks — no external assets)
  // ============================================================
  let soundOn = true;
  try { soundOn = localStorage.getItem('bricksMaster_sound') !== 'off'; } catch (e) { /* ignore */ }
  let audioCtx = null;
  function ensureAudio() {
    if (!audioCtx) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (AC) audioCtx = new AC();
    }
    if (audioCtx && audioCtx.state === 'suspended') audioCtx.resume();
    return audioCtx;
  }
  function beep(freq, dur, type, vol) {
    if (!soundOn) return;
    const ac = ensureAudio();
    if (!ac) return;
    const osc = ac.createOscillator();
    const gain = ac.createGain();
    osc.type = type || 'sine';
    osc.frequency.value = freq;
    gain.gain.value = vol || 0.08;
    gain.gain.exponentialRampToValueAtTime(0.001, ac.currentTime + dur);
    osc.connect(gain).connect(ac.destination);
    osc.start();
    osc.stop(ac.currentTime + dur);
  }
  const sfx = {
    bounce: () => beep(220, 0.07, 'sine', 0.04),
    break: () => beep(440, 0.12, 'triangle', 0.07),
    danger: () => beep(90, 0.35, 'sawtooth', 0.09),
    wrong: () => beep(140, 0.14, 'sawtooth', 0.05),
    win: () => beep(880, 0.3, 'triangle', 0.08),
  };
  function setSound(on) {
    soundOn = on;
    try { localStorage.setItem('bricksMaster_sound', on ? 'on' : 'off'); } catch (e) { /* ignore */ }
    document.querySelectorAll('.icon-button[aria-label="Toggle sound"]').forEach((b) => { b.textContent = on ? '🔊' : '🔇'; });
    const gameSoundIcon = document.getElementById('sound-icon-game');
    if (gameSoundIcon) gameSoundIcon.classList.toggle('muted', !on);
    if (soundSettingsStateEl) soundSettingsStateEl.textContent = on ? 'ON' : 'OFF';
  }

  // ============================================================
  // RESPONSIVE CANVAS
  // ============================================================
  let dpr = Math.max(1, Math.min(window.devicePixelRatio || 1, 2.5));
  let W = 0, H = 0;  // full viewport CSS pixel size (bg-canvas)
  let GW = 0;        // narrow centered gameplay-column width (game-canvas) — full width on
                      // mobile, clamped on desktop so the tower never stretches edge-to-edge
  const MAX_GAME_WIDTH = 500;

  function resize() {
    W = window.innerWidth;
    H = window.innerHeight;
    GW = Math.min(W, MAX_GAME_WIDTH);
    dpr = Math.max(1, Math.min(window.devicePixelRatio || 1, 2.5));

    canvas.width = Math.round(GW * dpr);
    canvas.height = Math.round(H * dpr);
    canvas.style.width = GW + 'px';
    canvas.style.height = H + 'px';
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    bgCanvas.width = Math.round(W * dpr);
    bgCanvas.height = Math.round(H * dpr);
    bgCanvas.style.width = W + 'px';
    bgCanvas.style.height = H + 'px';
    bgCtx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }
  window.addEventListener('resize', resize);
  window.addEventListener('orientationchange', resize);
  resize();

  function worldScale() {
    return Math.min(GW, H) / 640;
  }

  // ============================================================
  // BACKGROUND THEMES (drawn on the separate low-cost bg-canvas)
  // ============================================================
  const THEME_GRADIENTS = {
    sky:     ['#8fd8ff', '#4fa8e8'],
    candy:   ['#ffd6f0', '#c9a8ff'],
    sunset:  ['#ff9f6e', '#6a3aa0'],
    space:   ['#1b1440', '#05030f'],
    toyroom: ['#ffe08a', '#ff9fd6'],
  };
  let bgTheme = 'sky';
  let bgShapes = [];
  function localRng(seed) {
    let s = seed >>> 0;
    return function () {
      s ^= s << 13; s >>>= 0;
      s ^= s >>> 17;
      s ^= s << 5; s >>>= 0;
      return (s >>> 0) / 4294967296;
    };
  }
  function pick(rng, arr) { return arr[Math.floor(rng() * arr.length) % arr.length]; }
  function buildBackground(themeName) {
    bgTheme = themeName;
    bgShapes = [];
    const rng = localRng(42);
    if (themeName === 'space') {
      for (let i = 0; i < 40; i++) bgShapes.push({ x: rng(), y: rng(), r: 0.6 + rng() * 1.4, tw: rng() * Math.PI * 2, kind: 'star' });
      for (let i = 0; i < 2; i++) bgShapes.push({ x: rng(), y: rng() * 0.5, r: 16 + rng() * 20, kind: 'planet', hue: pick(rng, ['#c084fc', '#ff8fd6']) });
    } else if (themeName === 'sky') {
      for (let i = 0; i < 5; i++) bgShapes.push({ x: rng(), y: rng() * 0.35, r: 22 + rng() * 16, kind: 'cloud' });
    } else if (themeName === 'candy') {
      for (let i = 0; i < 8; i++) bgShapes.push({ x: rng(), y: rng(), r: 6 + rng() * 10, kind: 'dot', hue: pick(rng, ['#ffffff', '#ffe08a']) });
    } else if (themeName === 'sunset') {
      for (let i = 0; i < 3; i++) bgShapes.push({ x: rng(), y: 0.62 + rng() * 0.2, r: 34 + rng() * 24, kind: 'hill' });
    } else if (themeName === 'toyroom') {
      for (let i = 0; i < 6; i++) bgShapes.push({ x: rng(), y: rng(), r: 8 + rng() * 12, kind: pick(rng, ['dot', 'ring']), hue: pick(rng, ['#ffffff', '#4fd1ff']) });
    }
  }

  function drawBg(timeSec) {
    // Gameplay/win/lose screens use a flat, quiet dark-purple outer field
    // (win/lose overlays sit on top of the still-visible gameplay scene) —
    // no clouds/scenery, so the bricks stay the visual focus. The themed
    // menu backdrop only plays on the home/level-select screens.
    if (state === 'playing' || state === 'dying' || state === 'win' || state === 'lose') {
      bgCtx.fillStyle = GAME_THEME.bgOuter;
      bgCtx.fillRect(0, 0, W, H);
      return;
    }

    const grad = bgCtx.createLinearGradient(0, 0, 0, H);
    const stops = THEME_GRADIENTS[bgTheme] || THEME_GRADIENTS.sky;
    grad.addColorStop(0, stops[0]);
    grad.addColorStop(1, stops[1]);
    bgCtx.fillStyle = grad;
    bgCtx.fillRect(0, 0, W, H);

    for (let i = 0; i < bgShapes.length; i++) {
      const s = bgShapes[i];
      const sx = s.x * W;
      const sy = s.y * H + Math.sin(timeSec * 0.12 + i) * 5;
      if (s.kind === 'star') {
        bgCtx.globalAlpha = 0.5 + 0.5 * Math.sin(timeSec * 1.4 + s.tw);
        bgCtx.fillStyle = '#ffffff';
        bgCtx.beginPath(); bgCtx.arc(sx, sy, s.r, 0, Math.PI * 2); bgCtx.fill();
        bgCtx.globalAlpha = 1;
      } else if (s.kind === 'planet') {
        bgCtx.globalAlpha = 0.5;
        bgCtx.fillStyle = s.hue;
        bgCtx.beginPath(); bgCtx.arc(sx, sy, s.r, 0, Math.PI * 2); bgCtx.fill();
        bgCtx.globalAlpha = 1;
      } else if (s.kind === 'cloud') {
        bgCtx.fillStyle = 'rgba(255,255,255,0.7)';
        bgCtx.beginPath();
        bgCtx.ellipse(sx, sy, s.r, s.r * 0.55, 0, 0, Math.PI * 2);
        bgCtx.ellipse(sx + s.r * 0.7, sy + s.r * 0.1, s.r * 0.6, s.r * 0.38, 0, 0, Math.PI * 2);
        bgCtx.fill();
      } else if (s.kind === 'dot') {
        bgCtx.globalAlpha = 0.3;
        bgCtx.fillStyle = s.hue;
        bgCtx.beginPath(); bgCtx.arc(sx, sy, s.r, 0, Math.PI * 2); bgCtx.fill();
        bgCtx.globalAlpha = 1;
      } else if (s.kind === 'ring') {
        bgCtx.globalAlpha = 0.3;
        bgCtx.strokeStyle = s.hue; bgCtx.lineWidth = 2;
        bgCtx.beginPath(); bgCtx.arc(sx, sy, s.r, 0, Math.PI * 2); bgCtx.stroke();
        bgCtx.globalAlpha = 1;
      } else if (s.kind === 'hill') {
        bgCtx.globalAlpha = 0.25;
        bgCtx.fillStyle = '#3a2a7a';
        bgCtx.beginPath(); bgCtx.ellipse(sx, sy, s.r, s.r * 0.5, 0, 0, Math.PI * 2); bgCtx.fill();
        bgCtx.globalAlpha = 1;
      }
    }
  }

  // ============================================================
  // PARTICLES (object pool)
  // ============================================================
  const MAX_PARTICLES = 160;
  const particles = [];
  for (let i = 0; i < MAX_PARTICLES; i++) {
    particles.push({ active: false, x: 0, y: 0, vx: 0, vy: 0, life: 0, maxLife: 1, color: '#fff', size: 4 });
  }
  function spawnParticles(x, y, color, count, spread) {
    let spawned = 0;
    for (let i = 0; i < particles.length && spawned < count; i++) {
      const p = particles[i];
      if (p.active) continue;
      const ang = Math.random() * Math.PI * 2;
      const spd = (spread || 220) * (0.4 + Math.random() * 0.8);
      p.active = true;
      p.x = x; p.y = y;
      p.vx = Math.cos(ang) * spd;
      p.vy = Math.sin(ang) * spd - 80;
      p.life = p.maxLife = 0.4 + Math.random() * 0.3;
      p.color = color;
      p.size = 3 + Math.random() * 4;
      spawned++;
    }
  }
  function updateParticles(dt) {
    for (let i = 0; i < particles.length; i++) {
      const p = particles[i];
      if (!p.active) continue;
      p.vy += 520 * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
      if (p.life <= 0) p.active = false;
    }
  }
  function renderParticles(originX, originY, scale) {
    for (let i = 0; i < particles.length; i++) {
      const p = particles[i];
      if (!p.active) continue;
      const a = Math.max(0, p.life / p.maxLife);
      ctx.globalAlpha = a;
      ctx.fillStyle = p.color;
      ctx.beginPath();
      ctx.arc(originX + p.x * scale, originY + p.y * scale, p.size * scale, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }

  // ============================================================
  // FRAGMENTS (block-break pieces, pooled like particles)
  // ============================================================
  const MAX_FRAGMENTS = 40;
  const fragments = [];
  for (let i = 0; i < MAX_FRAGMENTS; i++) {
    fragments.push({ active: false, x: 0, y: 0, vx: 0, vy: 0, rot: 0, vrot: 0, life: 0, maxLife: 1, color: '#fff', w: 6, h: 6 });
  }
  // A brick splits into a small, deliberate set of chunky pieces (a left
  // half, a right half, and two small drop chunks) rather than a burst of
  // many small particles — closer to a real cracked block.
  const FRAGMENT_LAYOUT = [
    { dx: -1, dy: -0.35, w: 34, h: 42, rot: -0.25 },
    { dx: 1, dy: -0.35, w: 34, h: 42, rot: 0.25 },
    { dx: -0.4, dy: 0.7, w: 16, h: 16, rot: -0.6 },
    { dx: 0.4, dy: 0.7, w: 16, h: 16, rot: 0.6 },
  ];
  function spawnFragments(x, y, color) {
    let spawned = 0;
    for (let i = 0; i < fragments.length && spawned < FRAGMENT_LAYOUT.length; i++) {
      const f = fragments[i];
      if (f.active) continue;
      const p = FRAGMENT_LAYOUT[spawned];
      f.active = true;
      f.x = x; f.y = y;
      f.vx = p.dx * (140 + Math.random() * 40);
      f.vy = p.dy * 170 - 60;
      f.rot = p.rot;
      f.vrot = p.dx * 6;
      f.life = f.maxLife = 0.28 + Math.random() * 0.08;
      f.color = color;
      f.w = p.w; f.h = p.h;
      f.round = false;
      spawned++;
    }
  }
  // Radial burst variant (ball-explosion chunks) — pieces fly outward evenly
  // around a circle rather than splitting into a fixed left/right layout.
  function spawnRadialFragments(x, y, count, colors) {
    let spawned = 0;
    for (let i = 0; i < fragments.length && spawned < count; i++) {
      const f = fragments[i];
      if (f.active) continue;
      const ang = (spawned / count) * Math.PI * 2 + (Math.random() - 0.5) * 0.5;
      const spd = 160 + Math.random() * 140;
      f.active = true;
      f.x = x; f.y = y;
      f.vx = Math.cos(ang) * spd;
      f.vy = Math.sin(ang) * spd - 40;
      f.rot = Math.random() * Math.PI * 2;
      f.vrot = (Math.random() - 0.5) * 9;
      f.life = f.maxLife = rm(0.32, 0.18) + Math.random() * 0.1;
      f.color = colors[spawned % colors.length];
      const sz = 10 + Math.random() * 8;
      f.w = sz; f.h = sz;
      f.round = true;
      spawned++;
    }
  }
  function updateFragments(dt) {
    for (let i = 0; i < fragments.length; i++) {
      const f = fragments[i];
      if (!f.active) continue;
      f.vy += 560 * dt;
      f.x += f.vx * dt;
      f.y += f.vy * dt;
      f.rot += f.vrot * dt;
      f.life -= dt;
      if (f.life <= 0) f.active = false;
    }
  }
  function renderFragments(originX, originY, scale) {
    for (let i = 0; i < fragments.length; i++) {
      const f = fragments[i];
      if (!f.active) continue;
      const a = Math.max(0, f.life / f.maxLife);
      const s = 0.6 + a * 0.4; // scale down slightly as it fades, per B3
      ctx.save();
      ctx.globalAlpha = a;
      ctx.translate(originX + f.x * scale, originY + f.y * scale);
      ctx.rotate(f.rot);
      ctx.fillStyle = f.color;
      if (f.round) {
        ctx.beginPath();
        ctx.arc(0, 0, f.w * scale * s / 2, 0, Math.PI * 2);
        ctx.fill();
      } else {
        ctx.fillRect(-f.w * scale * s / 2, -f.h * scale * s / 2, f.w * scale * s, f.h * scale * s);
      }
      ctx.restore();
    }
    ctx.globalAlpha = 1;
  }

  // ============================================================
  // RINGS (shockwave / impact-flash pool — shared by brick FX and BallDeathFX)
  // ============================================================
  const MAX_RINGS = 16;
  const rings = [];
  for (let i = 0; i < MAX_RINGS; i++) {
    rings.push({ active: false, x: 0, y: 0, r: 0, startR: 2, maxR: 40, life: 0, maxLife: 0.2, color: '#fff', filled: false, lineWidth: 4 });
  }
  function spawnRing(x, y, opts) {
    for (let i = 0; i < rings.length; i++) {
      const r = rings[i];
      if (r.active) continue;
      r.active = true;
      r.x = x; r.y = y;
      r.startR = opts.startR || 2;
      r.r = r.startR;
      r.maxR = opts.maxR || 60;
      r.life = r.maxLife = opts.life || 0.25;
      r.color = opts.color || '#ffffff';
      r.filled = !!opts.filled;
      r.lineWidth = opts.lineWidth || 5;
      return;
    }
  }
  function updateRings(dt) {
    for (let i = 0; i < rings.length; i++) {
      const r = rings[i];
      if (!r.active) continue;
      const t = 1 - Math.max(0, r.life / r.maxLife);
      r.r = r.startR + (r.maxR - (r.startR || 2)) * t;
      r.life -= dt;
      if (r.life <= 0) r.active = false;
    }
  }
  function renderRings(originX, originY, scale) {
    for (let i = 0; i < rings.length; i++) {
      const r = rings[i];
      if (!r.active) continue;
      const a = Math.max(0, r.life / r.maxLife);
      ctx.save();
      ctx.globalAlpha = a;
      ctx.beginPath();
      ctx.arc(originX + r.x * scale, originY + r.y * scale, Math.max(1, r.r * scale), 0, Math.PI * 2);
      if (r.filled) {
        ctx.fillStyle = r.color;
        ctx.fill();
      } else {
        ctx.strokeStyle = r.color;
        ctx.lineWidth = r.lineWidth * scale;
        ctx.stroke();
      }
      ctx.restore();
    }
    ctx.globalAlpha = 1;
  }

  function clearAllEffects() {
    for (let i = 0; i < particles.length; i++) particles[i].active = false;
    for (let i = 0; i < fragments.length; i++) fragments[i].active = false;
    for (let i = 0; i < rings.length; i++) rings[i].active = false;
  }

  // ============================================================
  // INPUT CONTROLLER — only three commands exist: LEFT, RIGHT, CIRCLE.
  // Mobile: swipe left/right, or tap anywhere for CIRCLE. Desktop:
  // A/Left Arrow, D/Right Arrow, S/Down Arrow for CIRCLE.
  // ============================================================
  let onCommand = null; // set once game starts

  // A short/vertical gesture is treated as a tap -> CIRCLE. Only a clearly
  // horizontal drag resolves to LEFT/RIGHT. There is no up/down command.
  function resolveGesture(dx, dy) {
    if (Math.max(Math.abs(dx), Math.abs(dy)) < SWIPE_MIN_DIST) return 'circle';
    if (Math.abs(dx) > Math.abs(dy)) return dx > 0 ? 'right' : 'left';
    return 'circle';
  }

  let dragStart = null;
  swipeArea.addEventListener('pointerdown', (e) => {
    ensureAudio(); // C15 — unlock/resume WebAudio on the first gameplay gesture too, not just the Play button
    dragStart = { x: e.clientX, y: e.clientY, id: e.pointerId };
  });
  swipeArea.addEventListener('pointerup', (e) => {
    if (!dragStart || e.pointerId !== dragStart.id) return;
    const cmd = resolveGesture(e.clientX - dragStart.x, e.clientY - dragStart.y);
    dragStart = null;
    if (onCommand) onCommand(cmd);
  });
  swipeArea.addEventListener('pointercancel', () => { dragStart = null; });
  swipeArea.addEventListener('contextmenu', (e) => e.preventDefault());

  const KEY_MAP = {
    ArrowLeft: 'left', KeyA: 'left',
    ArrowRight: 'right', KeyD: 'right',
    ArrowDown: 'circle', KeyS: 'circle',
  };
  window.addEventListener('keydown', (e) => {
    const cmd = KEY_MAP[e.code];
    if (!cmd) return;
    e.preventDefault();
    if (e.repeat) return;
    if (onCommand) onCommand(cmd);
  }, { passive: false });

  // ============================================================
  // GAME STATE
  // ============================================================
  let state = 'menu'; // 'menu' | 'playing' | 'dying' | 'win' | 'lose'
  let levelIdx = 0;
  let runtimeBricks = [];
  let activeIndex = 0;
  let visualIndex = 0;
  let bouncePeriod = 0.75;
  let cycleElapsed = 0;

  // Seconds since the current active brick became active — resets on every
  // brick advance (never on a mere non-destroying bounce). Drives the red
  // spike reveal animation; only the active brick's danger visuals read it.
  let activeBrickTime = 0;

  const ball = { squash: 0, punch: 0 };
  let ballAlive = true; // BallDeathFX: false the instant the burst is spawned, hides the normal ball draw

  // BallDeathFX sequencing — see triggerDeath()/updateGame(). deathTimer is
  // advanced with raw (non hit-stopped) dt so the "wait, then show Game
  // Over" delay reads as real time even while the world is in slow-mo.
  let deathTimer = 0;
  const DEATH_TO_GAMEOVER_DELAY = rm(0.55, 0.32);

  // Free-running timer for the LEVEL_CLEAR_IDLE_BOUNCE — only ever advances
  // while state === 'win' (see updateGame), completely independent of the
  // gameplay bounce-cycle timer.
  let idleBounceT = 0;

  let shakeTime = 0, shakeMag = 0;
  let hitStop = 0;
  const breakingVisuals = []; // transient list of {brick, fromIndex, kind, t, duration, fxDone}

  let score = 0, combo = 0, comboTimer = 0;
  let correctCount = 0, wrongCount = 0;

  function cloneBricks(bricks) {
    return bricks.map((b) => Object.assign({}, b));
  }

  function loadLevel(idx) {
    const def = LEVELS[idx];
    levelIdx = idx;
    runtimeBricks = cloneBricks(def.bricks);
    activeIndex = 0;
    visualIndex = 0;
    bouncePeriod = def.bouncePeriod;
    cycleElapsed = 0;
    activeBrickTime = 0;
    breakingVisuals.length = 0;

    ball.squash = 0;
    ball.punch = 0;
    ballAlive = true;
    deathTimer = 0;
    idleBounceT = 0;

    shakeTime = 0;
    hitStop = 0;
    clearAllEffects(); // restart cleanup (B9) — never let a repeated death/restart stack FX

    score = 0; combo = 0; comboTimer = 0;
    correctCount = 0; wrongCount = 0;

    hudLevel.textContent = String(idx + 1);

    showBanner(def.name);
  }

  function showBanner(text) {
    levelBanner.textContent = text;
    levelBanner.classList.add('show');
    setTimeout(() => levelBanner.classList.remove('show'), 1200);
  }

  // Score/combo internals are unchanged and still drive the score
  // multiplier and the (silent, persisted-only) star rating — the
  // minimal reference-style HUD just doesn't display them anywhere.
  function addScore(base) {
    const mult = 1 + combo * 0.12;
    score += Math.round(base * mult);
  }

  function bumpCombo() {
    combo++;
    comboTimer = 1.6;
  }
  function resetCombo() {
    combo = 0;
  }

  function triggerShake(mag, dur) {
    if (REDUCED_MOTION) return; // Part F — camera shake fully disabled under reduced motion
    shakeMag = mag; shakeTime = dur;
  }

  // ============================================================
  // CORE RULES — StackController / BallBounceController
  // ============================================================
  function activeBrick() {
    return runtimeBricks[activeIndex] || null;
  }

  function handleCommand(cmd) {
    if (state !== 'playing') return;
    const brick = activeBrick();
    if (!brick || brick.type === 'green') return; // green never takes player input

    if (brick.cmd === cmd) {
      destroyActiveBrick();
    } else {
      brick.feedback = 1;
      brick.shakeT = 1;
      resetCombo();
      wrongCount++;
      sfx.wrong();
    }
  }
  onCommand = handleCommand;

  // BrickFX kind: green always bursts in place (no direction — it's
  // automatic, the player made no choice); every other brick exits in the
  // direction of the command that destroyed it (or cracks in half for CIRCLE).
  function fxKindFor(brick) {
    if (brick.type === 'green') return 'green';
    return brick.cmd === 'circle' ? 'circle' : brick.cmd; // 'left' | 'right' | 'circle'
  }

  function destroyActiveBrick() {
    const brick = activeBrick();
    if (!brick) return;
    const kind = fxKindFor(brick);
    const duration = rm(kind === 'green' ? 0.3 : kind === 'circle' ? 0.26 : 0.24, kind === 'green' ? 0.16 : 0.14);
    breakingVisuals.push({ brick, fromIndex: activeIndex, kind, t: 0, duration, fxDone: false });

    triggerShake(brick.type === 'red' ? 7 : 4, 0.16);
    hitStop = 0.07;
    ball.punch = 1;
    ball.squash = 1;
    addScore(brick.type === 'red' ? 20 : 10);
    bumpCombo();
    correctCount++;
    sfx.break();

    activeIndex++;
    cycleElapsed = 0;
    activeBrickTime = 0;

    if (activeIndex >= runtimeBricks.length) {
      winLevel();
    }
  }

  // Star rating is a display-only rating derived from the existing
  // wrong/correct counters — it does not alter score, combo, or the win
  // condition itself.
  function computeStars() {
    const total = correctCount + wrongCount;
    const acc = total === 0 ? 100 : (correctCount / total) * 100;
    if (wrongCount === 0) return 3;
    if (acc >= 70) return 2;
    return 1;
  }

  function winLevel() {
    state = 'win';
    idleBounceT = 0; // LEVEL_CLEAR_IDLE_BOUNCE starts fresh every time
    setBest(levelIdx, score);
    setUnlocked(levelIdx + 1);
    setStars(levelIdx, computeStars()); // silent — only shown later on the Level Select nodes
    triggerShake(5, 0.25);
    sfx.win();
    spawnConfetti();
    // C12 — the final level swaps "LEVEL CLEAR" -> "ALL LEVELS CLEAR!"; the
    // NEXT button below is retargeted to open Level Select instead of
    // advancing past the end of the LEVELS array.
    const isLastLevel = levelIdx >= LEVELS.length - 1;
    winTitleEl.textContent = isLastLevel ? 'ALL LEVELS CLEAR!' : 'LEVEL CLEAR';
    overlayWin.classList.add('show');
  }

  // BallDeathFX — sequence: impact freeze -> squash -> burst -> shockwave ->
  // camera shake -> (after DEATH_TO_GAMEOVER_DELAY) Game Over UI. See B1-B9.
  // hitStop already scales dt to 10% while active, so fragments/particles
  // spawned right here naturally play out in a brief "impact freeze" slow-mo
  // before speeding back up — no separate freeze state machine needed.
  function triggerDeath(brick) {
    if (state !== 'playing') return;
    state = 'dying';
    deathTimer = 0;
    ballAlive = false;
    hitStop = rm(0.07, 0.03);
    ball.squash = 1;
    triggerShake(9, rm(0.16, 0));
    brick.deathReact = 1; // B7 — active red brick reacts, but is never removed

    const scale = worldScale();
    // Ball's world-space position at the instant of contact, relative to
    // topBrickY (matches the phase===0 resting position render() computes —
    // the ball has just bottomed out onto the spikes).
    const worldY = -(BALL_RADIUS * BALL_REST_RADII * scale + RED_BALL_EXTRA_CLEARANCE * scale);

    spawnRing(0, worldY, { color: '#ffffff', maxR: 70 * scale, life: rm(0.13, 0.08), filled: true, startR: 4 });
    spawnRing(0, worldY, { color: '#ffd166', maxR: 130 * scale, life: rm(0.32, 0.18), lineWidth: 5, startR: 6 });
    spawnRadialFragments(0, worldY, rm(9, 5), ['#ffd166', '#ff9f43', '#ffffff']);
    spawnParticles(0, worldY, '#ffd166', rm(12, 6), 260);

    sfx.danger();
    setBest(levelIdx, score);
  }

  function finishDeath() {
    state = 'lose';
    triggerShake(14, rm(0.25, 0));
    overlayLose.classList.add('show');
  }

  function spawnConfetti() {
    const colors = ['#ffd166', '#7ee787', '#4fd1ff', '#ff8fd6', '#c084fc'];
    for (let i = 0; i < colors.length; i++) spawnParticles(0, -BRICK_H, colors[i], 7, 280);
  }

  // ============================================================
  // UPDATE LOOP
  // ============================================================
  function updateGame(dt) {
    if (state === 'playing' || state === 'win') {
      // stack slide easing — the tower moves, not a camera. Kept running
      // briefly into 'win' too so the stack finishes settling onto the base
      // instead of freezing mid-slide right as LEVEL CLEAR appears.
      visualIndex += (activeIndex - visualIndex) * Math.min(1, dt * STACK_EASE);
      if (Math.abs(activeIndex - visualIndex) < 0.002) visualIndex = activeIndex;
    }

    if (state === 'playing') {
      const brick = activeBrick();
      if (brick) {
        activeBrickTime += dt;
        cycleElapsed += dt;
        if (cycleElapsed >= bouncePeriod) {
          cycleElapsed -= bouncePeriod;
          ball.squash = 1;
          if (brick.type === 'red') {
            triggerDeath(brick);
          } else if (brick.type === 'green') {
            destroyActiveBrick(); // auto-break — no command required
          } else {
            // A2 — soft landing feedback on a normal (non-destroying) bounce
            const s = worldScale();
            spawnRing(0, -(BALL_RADIUS * BALL_REST_RADII * s), { color: '#ffffff', maxR: 30 * s, life: rm(0.12, 0.07), lineWidth: 3, startR: 2 });
            sfx.bounce();
          }
        }
      }
    } else if (state === 'win') {
      // LEVEL_CLEAR_IDLE_BOUNCE — a plain timer, no collision/danger logic
      // reads or writes it. This is the ONLY thing that runs for the ball
      // while state === 'win'.
      idleBounceT += dt;
    } else if (state === 'dying') {
      // dt here is briefly hit-stop-scaled (the impact freeze itself), then
      // full-speed — see B8: don't show Game Over on the same frame as the
      // collision, wait for the burst to actually play out first.
      deathTimer += dt;
      if (deathTimer >= DEATH_TO_GAMEOVER_DELAY) finishDeath();
    }

    // cosmetic animation keeps playing briefly after win/lose so impact
    // effects don't freeze mid-motion. Faster decay (was *7/*8) settles the
    // softened squash/punch within the 80-140ms target (A2) instead of
    // lingering.
    ball.squash *= Math.max(0, 1 - dt * 10);
    ball.punch *= Math.max(0, 1 - dt * 11);

    if (shakeTime > 0) shakeTime = Math.max(0, shakeTime - dt);

    if (comboTimer > 0) {
      comboTimer -= dt;
      if (comboTimer <= 0) resetCombo();
    }

    for (let i = 0; i < runtimeBricks.length; i++) {
      const b = runtimeBricks[i];
      if (b.feedback) b.feedback = Math.max(0, b.feedback - dt * 3);
      if (b.shakeT) b.shakeT = Math.max(0, b.shakeT - dt * 5);
      if (b.deathReact) b.deathReact = Math.max(0, b.deathReact - dt * 6);
    }

    for (let i = breakingVisuals.length - 1; i >= 0; i--) {
      breakingVisuals[i].t += dt;
      if (breakingVisuals[i].t > breakingVisuals[i].duration) breakingVisuals.splice(i, 1);
    }

    updateParticles(dt);
    updateFragments(dt);
    updateRings(dt);
  }

  // ============================================================
  // RENDERING
  // ============================================================
  function roundRect(x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }

  function lighten(hex, amt) {
    const c = hexToRgb(hex);
    if (!c) return hex;
    const r = Math.min(255, Math.round(c.r + (255 - c.r) * amt));
    const g = Math.min(255, Math.round(c.g + (255 - c.g) * amt));
    const b = Math.min(255, Math.round(c.b + (255 - c.b) * amt));
    return 'rgb(' + r + ',' + g + ',' + b + ')';
  }
  function darken(hex, amt) { return lighten(hex, -amt); }
  function mix(hexA, hexB, t) {
    const a = hexToRgb(hexA), b = hexToRgb(hexB);
    if (!a || !b) return hexB;
    const r = Math.round(a.r + (b.r - a.r) * t);
    const g = Math.round(a.g + (b.g - a.g) * t);
    const bl = Math.round(a.b + (b.b - a.b) * t);
    return 'rgb(' + r + ',' + g + ',' + bl + ')';
  }
  function hexToRgb(hex) {
    if (!hex || hex[0] !== '#') return null;
    const n = parseInt(hex.slice(1), 16);
    return { r: (n >> 16) & 255, g: (n >> 8) & 255, b: n & 255 };
  }

  // Thick rounded command icon — a vector shape (not a text glyph) so it
  // reads clearly at any size. Only three commands exist: LEFT/RIGHT
  // (a chunky arrow, mirrored via scale) and CIRCLE (a thick ring).
  function drawCommandIcon(cmd, size) {
    ctx.save();
    if (cmd === 'circle') {
      ctx.lineWidth = size * 0.22;
      ctx.strokeStyle = '#ffffff';
      ctx.beginPath();
      ctx.arc(0, 0, size * 0.32, 0, Math.PI * 2);
      ctx.stroke();
      ctx.restore();
      return;
    }
    if (cmd === 'left') ctx.scale(-1, 1);
    const headH = size * 0.6, stemW = size * 0.32, stemLen = size * 0.4;
    const tipX = size / 2, kinkX = tipX - headH, tailX = kinkX - stemLen;
    ctx.beginPath();
    ctx.moveTo(tipX, 0);
    ctx.lineTo(kinkX, -headH / 2);
    ctx.lineTo(kinkX, -stemW / 2);
    ctx.lineTo(tailX, -stemW / 2);
    ctx.lineTo(tailX, stemW / 2);
    ctx.lineTo(kinkX, stemW / 2);
    ctx.lineTo(kinkX, headH / 2);
    ctx.closePath();
    ctx.lineJoin = 'round';
    ctx.lineWidth = size * 0.12;
    ctx.fillStyle = '#ffffff';
    ctx.strokeStyle = '#ffffff';
    ctx.fill();
    ctx.stroke();
    ctx.restore();
  }

  // A single chunky, layered brick: white outline, colored body with a
  // darker bottom shadow band and a lighter top highlight strip, plus a
  // dark center panel holding the command icon. Color alone distinguishes
  // blue/red/green — no spikes, no extra ornamentation.
  // flashAmt (0..1, optional) briefly brightens the fill toward white — used
  // by BrickFX for the "command icon / center circle flashes" impact beat.
  // Scale/alpha/rotation for the break-exit motion itself are applied by the
  // caller via ctx transforms before this runs (see renderBreakingBrick).
  function drawBrick(cx, cy, brick, scale, flashAmt, isActive, spikeRevealT) {
    const w = BRICK_W * scale;
    const h = BRICK_H * scale;
    let jitter = 0;
    if (brick.shakeT) jitter = Math.sin(brick.shakeT * 50) * 5 * scale;

    const isRed = brick.type === 'red';
    // Danger visuals (spikes + glow) only ever show on the current ACTIVE
    // red brick — a buried red brick reads as a plain colored capsule,
    // same as any other brick, until it becomes the top/active one.
    const showDanger = isRed && isActive;
    const pal = brickPalette(brick.type);
    const r = h * 0.5; // heavily rounded — half the brick height

    ctx.save();
    ctx.translate(cx + jitter, cy);

    let scalePop = 1;
    const alpha = 1;
    if (isActive) scalePop = 1.03; // subtle emphasis on the topmost active brick
    // B7 — spike reaction: brief downward compression when the ball dies on
    // this brick's spikes, without ever removing/hiding the brick itself.
    const deathSqueeze = brick.deathReact ? brick.deathReact * 0.08 : 0;
    ctx.scale(scalePop, scalePop * (1 - deathSqueeze));

    // drop shadow
    ctx.save();
    ctx.translate(0, 4 * scale);
    roundRect(-w / 2, -h / 2, w, h, r);
    ctx.fillStyle = 'rgba(0,0,0,0.28)';
    ctx.fill();
    ctx.restore();

    // subtle red pulse glow (color communicates danger; this just softens it further)
    let dangerPulse = 0;
    if (showDanger) {
      dangerPulse = 0.5 + 0.5 * Math.sin(performance.now() / 260);
      ctx.save();
      roundRect(-w / 2 - 4 * scale, -h / 2 - 4 * scale, w + 8 * scale, h + 8 * scale, r + 4 * scale);
      ctx.fillStyle = 'rgba(230,50,60,' + (0.16 + dangerPulse * 0.12) + ')';
      ctx.fill();
      ctx.restore();
    }
    if (isActive) {
      ctx.save();
      roundRect(-w / 2 - 3 * scale, -h / 2 - 3 * scale, w + 6 * scale, h + 6 * scale, r + 3 * scale);
      ctx.fillStyle = 'rgba(255,255,255,0.14)';
      ctx.fill();
      ctx.restore();
    }

    // bottom shadow band (darker), then the main body on top leaving a
    // thin visible band along the bottom edge for a soft 2.5D toy feel
    roundRect(-w / 2, -h / 2 + h * 0.06, w, h, r);
    ctx.fillStyle = pal.dark;
    ctx.fill();

    roundRect(-w / 2, -h / 2, w, h * 0.92, r);
    const fillColor = isRed ? mix(GAME_THEME.brickRed, '#ff8f8f', dangerPulse * 0.3) : pal.body;
    let finalFill = fillColor;
    if (brick.feedback) finalFill = mix('#ffffff', fillColor, 1 - brick.feedback * 0.7);
    if (flashAmt) finalFill = mix(finalFill, '#ffffff', Math.min(1, flashAmt));
    ctx.fillStyle = finalFill;
    ctx.fill();
    if (brick.deathReact) {
      roundRect(-w / 2, -h / 2, w, h, r);
      ctx.fillStyle = 'rgba(255,255,255,' + (brick.deathReact * 0.55) + ')';
      ctx.fill();
    }

    // white outer outline
    roundRect(-w / 2, -h / 2, w, h, r);
    ctx.lineWidth = Math.max(2, 8 * scale);
    ctx.strokeStyle = GAME_THEME.brickOutline;
    ctx.stroke();

    // glossy top highlight strip — same language as every brick; for red
    // bricks the spikes are drawn on top right after, naturally covering
    // the portion of the gloss that would otherwise sit under them.
    roundRect(-w / 2 + w * 0.08, -h / 2 + h * 0.14, w * 0.5, h * 0.16, h * 0.08);
    ctx.fillStyle = GAME_THEME.brickHighlight;
    ctx.globalAlpha *= 0.5;
    ctx.fill();
    ctx.globalAlpha = alpha;

    // row of danger spikes along the top edge — ONLY on the active red
    // brick (see showDanger above). A single connected zigzag (not
    // floating separate triangles), same fill as the body so it reads as
    // one object, with its own white outline along the zigzag edge only.
    // A quick rise-out reveal (translateY + scaleY + opacity, ease-out)
    // plays the moment this brick becomes active; spikeRevealT is 1 for
    // the mid-break render call, so a destroyed active red brick's spikes
    // stay fully shown while they pop/fade away together with the body.
    if (showDanger) {
      const reveal = spikeRevealT === undefined ? 1 : spikeRevealT;
      const spikeH = SPIKE_H * scale * (0.6 + 0.4 * reveal);
      const revealOffsetY = 8 * scale * (1 - reveal);
      const spikeAlpha = reveal;
      const spanW = w * 0.7;
      const baseY = -h / 2 + h * 0.1 + revealOffsetY; // overlap slightly into the body top
      const segW = spanW / SPIKE_COUNT;
      const pts = [];
      for (let k = 0; k < SPIKE_COUNT; k++) {
        pts.push({ x: -spanW / 2 + segW * k, y: baseY });
        pts.push({ x: -spanW / 2 + segW * (k + 0.5), y: baseY - spikeH });
      }
      pts.push({ x: spanW / 2, y: baseY });

      const priorAlpha = ctx.globalAlpha;
      ctx.globalAlpha = priorAlpha * spikeAlpha;

      ctx.beginPath();
      ctx.moveTo(pts[0].x, pts[0].y);
      for (let k = 1; k < pts.length; k++) ctx.lineTo(pts[k].x, pts[k].y);
      ctx.lineTo(pts[pts.length - 1].x, baseY + h * 0.12);
      ctx.lineTo(pts[0].x, baseY + h * 0.12);
      ctx.closePath();
      ctx.fillStyle = finalFill;
      ctx.fill();

      ctx.beginPath();
      ctx.moveTo(pts[0].x, pts[0].y);
      for (let k = 1; k < pts.length; k++) ctx.lineTo(pts[k].x, pts[k].y);
      ctx.lineJoin = 'round';
      ctx.lineCap = 'round';
      ctx.lineWidth = Math.max(2, 8 * scale);
      ctx.strokeStyle = GAME_THEME.brickOutline;
      ctx.stroke();

      ctx.globalAlpha = priorAlpha;
    }

    // dark center panel + command icon — always drawn (also while a
    // directional break is flying out, so the flashing icon stays legible)
    const panelW = w * 0.4, panelH = h * 0.62, panelR = panelH * 0.3;
    roundRect(-panelW / 2, -panelH / 2, panelW, panelH, panelR);
    ctx.fillStyle = pal.panel;
    ctx.fill();
    drawCommandIcon(brick.cmd, Math.min(panelW, panelH) * 0.88);

    ctx.restore();
  }

  // Reference-style pedestal at the bottom of the stack, revealed once the
  // last brick is close enough to be in view — a wide rounded cap on a
  // narrower stem, warm tan/brown, matching the reference's "base."
  function drawBase(cx, cy, scale) {
    const capW = BRICK_W * scale * 0.92;
    const capH = BRICK_H * scale * 0.5;
    const stemW = capW * 0.42;
    const stemH = BRICK_H * scale * 0.62;

    ctx.save();
    ctx.translate(cx, cy);

    roundRect(-stemW / 2, capH * 0.15, stemW, stemH, stemW * 0.18);
    ctx.fillStyle = GAME_THEME.baseStem;
    ctx.fill();
    ctx.lineWidth = Math.max(2, 6 * scale);
    ctx.strokeStyle = '#ffffff';
    ctx.stroke();

    roundRect(-capW / 2, -capH / 2, capW, capH, capH * 0.45);
    const grad = ctx.createLinearGradient(0, -capH / 2, 0, capH / 2);
    grad.addColorStop(0, GAME_THEME.baseTan);
    grad.addColorStop(1, GAME_THEME.baseTanDark);
    ctx.fillStyle = grad;
    ctx.fill();
    ctx.lineWidth = Math.max(2, 6 * scale);
    ctx.strokeStyle = '#ffffff';
    ctx.stroke();

    roundRect(-capW * 0.32, -capH * 0.32, capW * 0.38, capH * 0.22, capH * 0.1);
    ctx.fillStyle = 'rgba(255,255,255,0.4)';
    ctx.fill();

    ctx.restore();
  }

  function drawGameplayBackdrop() {
    // Two-layer look: bg-canvas behind supplies the flat dark-purple
    // outer field; this fills the narrow game-canvas column itself with
    // a lighter violet gradient so it reads as a distinct "playable area".
    const grad = ctx.createLinearGradient(0, 0, 0, H);
    grad.addColorStop(0, GAME_THEME.bgCenterTop);
    grad.addColorStop(1, GAME_THEME.bgCenterBottom);
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, GW, H);
  }

  function render(timeSec) {
    const scale = worldScale();
    const anchorX = GW / 2;
    const anchorY = H * 0.3;

    let shakeX = 0, shakeY = 0;
    if (shakeTime > 0) {
      shakeX = (Math.random() * 2 - 1) * shakeMag;
      shakeY = (Math.random() * 2 - 1) * shakeMag;
    }

    drawGameplayBackdrop();
    ctx.save();
    ctx.translate(shakeX, shakeY);

    const topBrickY = anchorY + (BALL_RADIUS * (BALL_REST_RADII + 1) + BRICK_H * 0.5) * scale;
    const spikeRevealT = 1 - Math.pow(1 - Math.min(1, activeBrickTime / SPIKE_REVEAL_DURATION), 2); // ease-out

    // stack — only the upcoming bricks, sliding into place, uniform
    // spacing (spikes only ever appear on the active slot and use the
    // headroom already reserved for the ball, so no brick keeps extra
    // permanent gap just for being red).
    for (let i = 0; i < VISIBLE_BRICKS; i++) {
      const brickIndex = activeIndex + i;
      const brick = runtimeBricks[brickIndex];
      if (!brick) break;
      const slot = brickIndex - visualIndex;
      const sy = topBrickY + slot * BRICK_SPACING * scale;
      if (sy < -80 || sy > H + 80) continue;
      const depthT = Math.min(1, i / VISIBLE_BRICKS);
      ctx.globalAlpha = Math.max(0.5, 1 - depthT * 0.55);
      drawBrick(anchorX, sy, brick, scale * (1 - depthT * 0.04), undefined, i === 0, spikeRevealT);
      ctx.globalAlpha = 1;
    }

    // base pedestal, revealed once the stack has been cleared down to it
    const baseSlot = runtimeBricks.length - visualIndex;
    const baseSy = topBrickY + baseSlot * BRICK_SPACING * scale;
    if (baseSy > -80 && baseSy < H + 200) drawBase(anchorX, baseSy, scale);

    // bricks currently mid-break — BrickFX: directional exit / crack-split /
    // auto-burst, per brick command (see renderBreakingBrick).
    for (let i = 0; i < breakingVisuals.length; i++) {
      const bv = breakingVisuals[i];
      const slot = bv.fromIndex - visualIndex;
      const sy = topBrickY + slot * BRICK_SPACING * scale;
      spawnBreakEffectsOnce(bv, sy - topBrickY);
      renderBreakingBrick(anchorX, sy, bv, scale);
    }

    // ball — fixed X. Two entirely separate motion modes (never mixed in
    // the same frame): the normal gameplay bounce above the active brick,
    // and the decorative LEVEL_CLEAR_IDLE_BOUNCE on the final base once the
    // level is won. Picking one or the other is the ONLY place state==='win'
    // affects ball rendering — no collision/danger logic is ever involved.
    const bx = anchorX;
    let by, shadowCx, shadowCy, shadowShrink, squashX, squashY;

    if (state === 'win') {
      // LEVEL_CLEAR_IDLE_BOUNCE — simple deterministic timer-driven arc,
      // independent of cycleElapsed/bouncePeriod/ball.squash/ball.punch.
      const capH = BRICK_H * scale * 0.5;
      const restY = baseSy - capH * 0.5 - BALL_RADIUS * scale; // ball bottom rests exactly on the base's top surface
      const idlePhase = (idleBounceT % IDLE_BOUNCE_PERIOD) / IDLE_BOUNCE_PERIOD;
      const idleArc = Math.sin(Math.PI * idlePhase); // 0 -> 1 -> 0, gentle rise/fall
      by = restY - IDLE_BOUNCE_HEIGHT_PX * scale * idleArc;
      shadowCx = bx; shadowCy = restY + BALL_RADIUS * scale * 0.55;
      shadowShrink = 0.55 + 0.45 * (1 - idleArc);
      // subtle squash only in a short window right at touchdown (idlePhase 0/1)
      const touchdown = Math.max(0, 1 - idlePhase / 0.06) + Math.max(0, 1 - (1 - idlePhase) / 0.06);
      const s = Math.min(1, touchdown);
      squashX = 1 + s * 0.06; // 1.05-1.08 target
      squashY = 1 - s * 0.05; // 0.93-0.96 target
    } else {
      // Normal gameplay bounce above the active brick. A little extra
      // visual-only headroom is added while the active brick is red, so the
      // ball's flight doesn't visually clip its spike tips — this never
      // touches cycleElapsed/bouncePeriod, so impact timing (and therefore
      // danger-brick death timing) is completely unaffected.
      const phase = Math.min(1, cycleElapsed / bouncePeriod);
      const riseHeightRaw = BRICK_H * BALL_RISE_FRACTION * scale;
      const riseHeight = Math.min(BOUNCE_RISE_MAX_PX, Math.max(BOUNCE_RISE_MIN_PX, riseHeightRaw)); // A3 — clamped travel band
      const bounceOffset = -riseHeight * Math.sin(Math.PI * phase);
      const punchOffset = ball.punch * 6 * scale; // softened (was 10) — A7 tiny impulse, not a jolt
      const activeBrickNow = runtimeBricks[activeIndex];
      const redClearance = (activeBrickNow && activeBrickNow.type === 'red') ? RED_BALL_EXTRA_CLEARANCE * scale : 0;
      by = topBrickY - BALL_RADIUS * BALL_REST_RADII * scale - redClearance + bounceOffset + punchOffset;
      shadowCx = bx; shadowCy = topBrickY - BRICK_H * 0.1 * scale;
      shadowShrink = 0.5 + 0.5 * (1 - Math.abs(bounceOffset) / riseHeight);

      // squash/stretch — softened to a gentle 1.06-1.09 / 0.93-0.96 band
      // (was up to 1.28/0.65, which read as an abrupt "snap" on impact)
      const flightStretch = Math.sin(Math.PI * phase);
      squashX = 1 + ball.squash * 0.09 - flightStretch * 0.015;
      squashY = 1 - ball.squash * 0.07 + flightStretch * 0.02;
    }

    if (ballAlive) {
      // shadow on the active brick / base
      ctx.beginPath();
      ctx.ellipse(shadowCx, shadowCy, 18 * scale * shadowShrink, 6 * scale * shadowShrink, 0, 0, Math.PI * 2);
      ctx.fillStyle = 'rgba(0,0,0,0.25)';
      ctx.fill();

      const rx = BALL_RADIUS * scale * squashX;
      const ry = BALL_RADIUS * scale * squashY;

      ctx.save();
      ctx.translate(bx, by);
      const bg = ctx.createRadialGradient(-rx * 0.3, -ry * 0.4, rx * 0.2, 0, 0, rx * 1.3);
      bg.addColorStop(0, '#ffffff');
      bg.addColorStop(0.35, '#ffd166');
      bg.addColorStop(1, '#ff9f43');
      ctx.beginPath();
      ctx.ellipse(0, 0, rx, ry, 0, 0, Math.PI * 2);
      ctx.fillStyle = bg;
      ctx.fill();
      ctx.lineWidth = Math.max(2, 5 * scale);
      ctx.strokeStyle = '#ffffff';
      ctx.stroke();
      ctx.beginPath();
      ctx.ellipse(-rx * 0.32, -ry * 0.4, rx * 0.28, ry * 0.2, -0.4, 0, Math.PI * 2);
      ctx.fillStyle = 'rgba(255,255,255,0.8)';
      ctx.fill();
      ctx.restore();
    }

    renderRings(anchorX, topBrickY, scale);
    renderFragments(anchorX, topBrickY, scale);
    renderParticles(anchorX, topBrickY, scale);

    ctx.restore();
  }

  // BrickFX — renders one mid-break brick per its kind (fxKindFor):
  //   left/right — brick launches off the stack in that direction, rotating,
  //                compressing briefly on impact, flashing, then fading.
  //   circle     — center flash + compress, then the body is replaced by the
  //                existing split-fragment crack (drawBrick stops rendering).
  //   green      — auto-burst in place: quick flash + scale pop + fade,
  //                shockwave ring carries the "it broke" read instead of motion.
  function renderBreakingBrick(anchorX, sy, bv, scale) {
    const p = Math.min(1, bv.t / bv.duration);
    const brick = bv.brick;
    const isRed = brick.type === 'red';
    const forceActive = isRed; // keeps a red brick's spikes attached through its exit (A4)

    ctx.save();

    if (bv.kind === 'circle') {
      // Center flash + brief compress, then the crack/fragment split (spawned
      // once in spawnBreakEffectsOnce) takes over and the solid body is gone.
      if (p < 0.4) {
        const flashAmt = Math.max(0, 1 - p / 0.4);
        const compress = 1 - Math.min(0.14, (p / 0.4) * 0.14);
        ctx.globalAlpha = Math.max(0, 1 - p / 0.4);
        ctx.translate(anchorX, sy);
        ctx.scale(1, compress);
        drawBrick(0, 0, brick, scale, flashAmt, forceActive, 1);
      }
      ctx.restore();
      return;
    }

    if (bv.kind === 'green') {
      // Auto-burst in place — a quick scale-pop + fade, no directional travel.
      const alpha = Math.max(0, 1 - p);
      const scalePop = 1 + p * 0.18;
      const flashAmt = Math.max(0, 1 - p / 0.35);
      ctx.globalAlpha = alpha;
      ctx.translate(anchorX, sy);
      ctx.scale(scalePop, scalePop);
      drawBrick(0, 0, brick, scale, flashAmt, false, 1);
      ctx.restore();
      return;
    }

    // 'left' / 'right' — the brick is knocked off the stack in that direction.
    const dir = bv.kind === 'left' ? -1 : 1;
    const ease = p * p; // accelerates off the stack (A1.5)
    const exitDist = 420 * scale;
    const offsetX = dir * ease * exitDist;
    const rot = dir * 0.55 * p; // left -> ccw, right -> cw (canvas rotate is cw-positive)
    const impactCompress = p < 0.14 ? 1 - (p / 0.14) * 0.1 : 1;
    const flashAmt = Math.max(0, 1 - p / 0.25);
    const alpha = p < 0.55 ? 1 : Math.max(0, 1 - (p - 0.55) / 0.45);

    ctx.globalAlpha = alpha;
    ctx.translate(anchorX + offsetX, sy);
    ctx.rotate(rot);
    ctx.scale(impactCompress, impactCompress);
    drawBrick(0, 0, brick, scale, flashAmt, forceActive, 1);
    ctx.restore();
  }

  // fires the particle/fragment/ring burst exactly once per break, on the
  // first render frame — counts follow A8 (normal 3-6, red 5-8, green 5-10).
  function spawnBreakEffectsOnce(bv, worldY) {
    if (bv.fxDone) return;
    bv.fxDone = true;
    const brick = bv.brick;
    const isRed = brick.type === 'red';
    const color = brickPalette(brick.type).body;

    if (bv.kind === 'green') {
      spawnParticles(0, worldY, color, rm(8, 4), 300);
      spawnRing(0, worldY, { color: GAME_THEME.brickGreen, maxR: 90 * (worldScale()), life: rm(0.3, 0.18), lineWidth: 4 });
      return;
    }
    if (bv.kind === 'circle') {
      spawnFragments(0, worldY, isRed ? GAME_THEME.brickRed : color); // reused left/right-half split for the crack
      spawnParticles(0, worldY, isRed ? '#ffffff' : color, isRed ? 6 : 4, 210);
      spawnRing(0, worldY, { color: '#ffffff', maxR: 60 * worldScale(), life: rm(0.12, 0.08), filled: true, startR: 4 });
      if (isRed) triggerShake(3, 0.08);
      return;
    }
    // directional left/right — a few small particles trail behind the exit,
    // opposite the travel direction, instead of the brick fully shattering.
    const dir = bv.kind === 'left' ? -1 : 1;
    const count = rm(isRed ? 6 : 4, isRed ? 4 : 2);
    spawnParticles(dir * -20, worldY, isRed ? '#ff5c5c' : color, count, 110);
    if (isRed) {
      spawnParticles(dir * -20, worldY, '#ffffff', 2, 100);
      triggerShake(3, 0.08);
    }
  }

  // ============================================================
  // MAIN LOOP
  // ============================================================
  let lastTime = performance.now();
  let gameTime = 0, ambientTime = 0;
  function loop(now) {
    let dt = (now - lastTime) / 1000;
    lastTime = now;
    if (dt > 1 / 20) dt = 1 / 20;
    ambientTime += dt;
    const effDt = hitStop > 0 ? dt * 0.1 : dt;
    if (hitStop > 0) hitStop = Math.max(0, hitStop - dt);
    updateGame(effDt);
    gameTime += effDt;
    drawBg(ambientTime);
    render(gameTime);
    requestAnimationFrame(loop);
  }
  requestAnimationFrame((t) => { lastTime = t; requestAnimationFrame(loop); });

  document.addEventListener('visibilitychange', () => {
    if (!document.hidden) lastTime = performance.now();
  });

  // ============================================================
  // MENU / OVERLAY WIRING
  // ============================================================
  // ---------- Level Select pagination (C2-C5) — 16 levels/page, 4x4 ----------
  const LEVELS_PER_PAGE = 16;
  const totalLevelPages = Math.ceil(LEVELS.length / LEVELS_PER_PAGE);
  let levelPage = 0;

  function buildLevelSelect() {
    levelPagesEl.innerHTML = '';
    pageDotsEl.innerHTML = '';
    // C8 — migration safety: clamp a stale/dev localStorage value into the
    // current LEVELS range instead of ever wiping it.
    const unlocked = Math.min(getUnlocked(), LEVELS.length - 1);
    startLevelNumEl.textContent = String(levelIdx + 1);

    for (let page = 0; page < totalLevelPages; page++) {
      const pageEl = document.createElement('div');
      pageEl.className = 'level-page';
      const gridEl = document.createElement('div');
      gridEl.className = 'level-grid';

      const start = page * LEVELS_PER_PAGE;
      const end = Math.min(LEVELS.length, start + LEVELS_PER_PAGE);
      for (let i = start; i < end; i++) {
        const locked = i > unlocked;
        const completed = i < unlocked;
        const current = !locked && i === levelIdx;
        const stars = getStars(i);
        const btn = document.createElement('button');
        btn.className = 'level-node' +
          (locked ? ' locked' : current ? ' current' : completed ? ' completed unlocked' : ' unlocked');
        btn.innerHTML = (locked ? '🔒' : String(i + 1)) +
          (completed ? '<span class="node-check">✓</span>' : '') +
          (!locked && stars > 0 ? '<span class="node-stars">' + '★'.repeat(stars) + '☆'.repeat(3 - stars) + '</span>' : '');
        btn.addEventListener('click', () => {
          if (locked) {
            btn.classList.remove('shake');
            void btn.offsetWidth; // restart animation
            btn.classList.add('shake');
            return;
          }
          levelIdx = i;
          overlayLevels.classList.remove('show');
          startGame(i);
        });
        gridEl.appendChild(btn);
      }
      pageEl.appendChild(gridEl);
      levelPagesEl.appendChild(pageEl);

      const dot = document.createElement('span');
      dot.className = 'page-dot';
      pageDotsEl.appendChild(dot);
    }

    showLevelPage(Math.min(levelPage, totalLevelPages - 1));
  }

  function showLevelPage(idx) {
    levelPage = Math.max(0, Math.min(totalLevelPages - 1, idx));
    levelPagesEl.style.transform = 'translateX(' + (-levelPage * 100) + '%)';
    const dots = pageDotsEl.children;
    for (let i = 0; i < dots.length; i++) dots[i].classList.toggle('active', i === levelPage);
    btnPagePrev.disabled = levelPage === 0;
    btnPageNext.disabled = levelPage === totalLevelPages - 1;
  }

  function hideAllOverlays() {
    overlayStart.classList.remove('show');
    overlayWin.classList.remove('show');
    overlayLose.classList.remove('show');
    overlayLevels.classList.remove('show');
    overlaySkins.classList.remove('show');
    overlaySettings.classList.remove('show');
  }

  function startGame(idx) {
    hideAllOverlays();
    stopHomePreview();
    loadLevel(idx);
    state = 'playing';
  }

  function goHome() {
    hideAllOverlays();
    buildLevelSelect();
    overlayStart.classList.add('show');
    state = 'menu';
    startHomePreview();
  }

  document.getElementById('btn-start-play').addEventListener('click', () => { ensureAudio(); startGame(levelIdx); });
  document.getElementById('btn-continue').addEventListener('click', () => {
    overlayWin.classList.remove('show');
    if (levelIdx + 1 < LEVELS.length) {
      startGame(levelIdx + 1);
    } else {
      // C12 — "ALL LEVELS CLEAR!" completion state: go to Level Select
      // instead of trying to start a level past the end of the array.
      goHome();
      levelPage = Math.floor(levelIdx / LEVELS_PER_PAGE);
      buildLevelSelect();
      overlayLevels.classList.add('show');
    }
  });
  document.getElementById('btn-replay-win').addEventListener('click', () => startGame(levelIdx));
  document.getElementById('btn-home-win').addEventListener('click', goHome);
  document.getElementById('btn-restart').addEventListener('click', () => startGame(levelIdx));
  document.getElementById('btn-menu').addEventListener('click', goHome);
  document.getElementById('btn-home-game').addEventListener('click', goHome);
  document.getElementById('btn-sound-game').addEventListener('click', () => setSound(!soundOn));

  // ---------- level select / skins / settings screens ----------
  document.getElementById('btn-open-levels').addEventListener('click', () => {
    levelPage = Math.floor(levelIdx / LEVELS_PER_PAGE);
    buildLevelSelect();
    overlayLevels.classList.add('show');
  });
  document.getElementById('btn-levels-back').addEventListener('click', () => overlayLevels.classList.remove('show'));
  btnPagePrev.addEventListener('click', () => showLevelPage(levelPage - 1));
  btnPageNext.addEventListener('click', () => showLevelPage(levelPage + 1));

  document.getElementById('btn-open-skins').addEventListener('click', () => overlaySkins.classList.add('show'));
  document.getElementById('btn-skins-back').addEventListener('click', () => overlaySkins.classList.remove('show'));

  document.getElementById('btn-settings').addEventListener('click', () => overlaySettings.classList.add('show'));
  document.getElementById('btn-settings-back').addEventListener('click', () => overlaySettings.classList.remove('show'));
  document.getElementById('btn-sound-settings').addEventListener('click', () => setSound(!soundOn));
  document.getElementById('btn-reset-progress').addEventListener('click', () => {
    if (window.confirm('Reset all level progress, best scores, and stars?')) {
      resetProgress();
      buildLevelSelect();
    }
  });

  // ---------- sound toggle ----------
  setSound(soundOn);
  document.getElementById('btn-sound').addEventListener('click', () => setSound(!soundOn));

  // ---------- start-screen animated preview (bouncing ball on a brick) ----------
  function roundRectOn(c, x, y, w, h, r) {
    c.beginPath();
    c.moveTo(x + r, y);
    c.arcTo(x + w, y, x + w, y + h, r);
    c.arcTo(x + w, y + h, x, y + h, r);
    c.arcTo(x, y + h, x, y, r);
    c.arcTo(x, y, x + w, y, r);
    c.closePath();
  }
  // Deterministic bounce curve driven by loop-relative elapsed seconds
  // (never the raw rAF timestamp, which is large and non-zero at start —
  // that mismatch was the cause of the previous jitter). Position (height)
  // and squash are two separate outputs of the same curve so they never
  // fight each other.
  const PREVIEW_LOOP_SECONDS = 1.6; // within the requested 1.4–1.8s range
  const PREVIEW_AIR_FRACTION = 0.82; // ball airborne for 0–82% of the loop, then a brief squash
  function previewBounceCurve(phase) {
    if (phase < PREVIEW_AIR_FRACTION) {
      const p = phase / PREVIEW_AIR_FRACTION;
      return { height: Math.sin(p * Math.PI), squash: 0 }; // peak ~41%, lands ~82%
    }
    const p = (phase - PREVIEW_AIR_FRACTION) / (1 - PREVIEW_AIR_FRACTION);
    return { height: 0, squash: Math.sin(p * Math.PI) }; // squash pulse ~88–94%
  }

  function renderPreview(elapsedSeconds) {
    const pw = previewCanvas.width, ph = previewCanvas.height;
    previewCtx.clearRect(0, 0, pw, ph);
    const g = previewCtx.createLinearGradient(0, 0, 0, ph);
    g.addColorStop(0, '#8fd8ff');
    g.addColorStop(1, '#4fa8e8');
    previewCtx.fillStyle = g;
    roundRectOn(previewCtx, 0, 0, pw, ph, 14);
    previewCtx.fill();

    const cx = pw / 2;
    const platY = ph * 0.72;
    previewCtx.fillStyle = '#ffd166';
    roundRectOn(previewCtx, cx - 42, platY - 8, 84, 16, 8);
    previewCtx.fill();

    const phase = (elapsedSeconds % PREVIEW_LOOP_SECONDS) / PREVIEW_LOOP_SECONDS;
    const curve = previewBounceCurve(phase);

    // shadow: shrinks/lightens as the ball rises, widens briefly on landing
    const shadowScale = 1 - curve.height * 0.35 + curve.squash * 0.15;
    previewCtx.fillStyle = 'rgba(0,0,0,' + (0.15 - curve.height * 0.06) + ')';
    previewCtx.beginPath();
    previewCtx.ellipse(cx, platY + 10, 40 * shadowScale, 8 * shadowScale, 0, 0, Math.PI * 2);
    previewCtx.fill();

    const travel = 46; // canvas-space px; scales with the canvas via CSS, so it stays proportional on mobile
    const by = platY - 14 - curve.height * travel;
    const squashY = 1 + curve.height * 0.05 - curve.squash * 0.10;
    const squashX = 1 - curve.height * 0.04 + curve.squash * 0.08;

    previewCtx.save();
    previewCtx.translate(cx, by);
    previewCtx.scale(squashX, squashY);
    const bg = previewCtx.createRadialGradient(-6, -8, 3, 0, 0, 16);
    bg.addColorStop(0, '#ffffff');
    bg.addColorStop(0.4, '#ff8fd6');
    bg.addColorStop(1, '#ff4fa0');
    previewCtx.beginPath();
    previewCtx.arc(0, 0, 14, 0, Math.PI * 2);
    previewCtx.fillStyle = bg;
    previewCtx.fill();
    previewCtx.restore();
  }

  // Single owner of the Home decorative-ball loop. start/stop are
  // idempotent so re-entering Home repeatedly can never spawn a second
  // concurrent rAF chain, and leaving Home fully cancels it.
  let previewRafId = null;
  let previewStartTime = null;
  function previewLoop(now) {
    if (previewStartTime === null) previewStartTime = now;
    renderPreview((now - previewStartTime) / 1000);
    previewRafId = requestAnimationFrame(previewLoop);
  }
  function startHomePreview() {
    if (previewRafId !== null) return; // already running — do not stack a second loop
    previewStartTime = null;
    previewRafId = requestAnimationFrame(previewLoop);
  }
  function stopHomePreview() {
    if (previewRafId !== null) {
      cancelAnimationFrame(previewRafId);
      previewRafId = null;
    }
  }

  buildBackground('sky');
  buildLevelSelect();
  startHomePreview();
})();
