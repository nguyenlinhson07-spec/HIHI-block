/*
 * Level configuration for Bricks Master — single vertical brick stack.
 *
 * A level is DATA, not gameplay logic — the engine (game.js) only ever
 * reads a `bricks` array + `bouncePeriod`. Each brick is one of:
 *   { type: 'blue',  cmd: 'left'|'right'|'circle' }
 *   { type: 'red',   cmd: 'left'|'right'|'circle' }
 *   { type: 'green', cmd: 'left'|'right'|'circle' }
 *
 * There is no up/down command — only LEFT, RIGHT, and CIRCLE (tap) exist.
 *
 * 'blue'  — safe. The matching command destroys it; a wrong command just
 *           shakes it and the player can keep retrying, no penalty.
 * 'red'   — same command rule as blue, but the destruction must happen
 *           before the ball's next bounce contacts it (see the
 *           bounce-cycle timer in game.js). Fail in time -> game over.
 * 'green' — safe and automatic. No command needed; it breaks on its own
 *           the moment the ball's bounce cycle reaches it.
 *
 * Levels are hand-authored / deterministically built (no RNG) so every
 * level is guaranteed to be exactly what a player can read and react to.
 *
 * SOLVABILITY INVARIANT (see C11 in the design brief): every brick, of any
 * type, gets the FULL `bouncePeriod` seconds of reaction time. game.js
 * resets `cycleElapsed` (the bounce-cycle timer) to 0 the instant a brick
 * is destroyed — via player command OR an automatic green auto-break — so
 * a brick that becomes active right after a green (or right after another
 * red) is never handed a shortened window. This means sequences like
 * GREEN, GREEN, RED or RED, RED are always exactly as fair as a single
 * isolated red brick at the same bouncePeriod: there is no "impossible"
 * chain by construction. The only lever that affects difficulty is
 * bouncePeriod itself, which we keep >= MIN_SAFE_REACTION below.
 */

const CMD_CYCLE = ['left', 'right', 'circle'];
const MIN_SAFE_REACTION = 0.4; // seconds — floor for bouncePeriod, keeps every red brick humanly reactable

function blueBrick(cmd) { return { type: 'blue', cmd }; }
function redBrick(cmd) { return { type: 'red', cmd }; }
function greenBrick(cmd) { return { type: 'green', cmd }; }

// Deterministic filler sequence — a pure function of index, no randomness.
//   dangerEvery/dangerOffset   — insert a single red brick every N bricks
//   greenChainEvery/Len        — insert a short run of auto-break greens
//   doubleRedEvery/Offset      — insert two reds back-to-back every N bricks
//                                 (each still gets its own full bouncePeriod)
function buildSequence(count, opts) {
  const {
    dangerEvery = 0, dangerOffset = 1,
    greenChainEvery = 0, greenChainLen = 0,
    doubleRedEvery = 0, doubleRedOffset = 2,
  } = opts;
  const seq = [];
  while (seq.length < count) {
    const idx = seq.length;
    if (greenChainEvery > 0 && idx > 0 && idx % greenChainEvery === 0) {
      for (let g = 0; g < greenChainLen && seq.length < count; g++) {
        seq.push(greenBrick(CMD_CYCLE[seq.length % 3]));
      }
      continue;
    }
    if (doubleRedEvery > 0 && idx > 0 && idx % doubleRedEvery === 0) {
      seq.push(redBrick(CMD_CYCLE[(idx + doubleRedOffset) % 3]));
      if (seq.length < count) seq.push(redBrick(CMD_CYCLE[(idx + doubleRedOffset + 1) % 3]));
      continue;
    }
    if (dangerEvery > 0 && idx > 0 && idx % dangerEvery === 0) {
      seq.push(redBrick(CMD_CYCLE[(idx + dangerOffset) % 3]));
    } else {
      seq.push(blueBrick(CMD_CYCLE[idx % 3]));
    }
  }
  return seq;
}

function lerp(a, b, t) { return Math.round(a + (b - a) * t); }

// Brick-count target for level index i (0-based), following the C10 length
// progression: 1-4:8-12, 5-8:12-16, 9-16:15-20, 17-24:18-24, 25-31:22-28, 32:~30.
function countForIndex(i) {
  if (i < 4) return lerp(8, 12, i / 3);
  if (i < 8) return lerp(12, 16, (i - 4) / 3);
  if (i < 16) return lerp(15, 20, (i - 8) / 7);
  if (i < 24) return lerp(18, 24, (i - 16) / 7);
  if (i < 31) return lerp(22, 28, (i - 24) / 6);
  return 30;
}

// Smoothly ramps the bounce period (= reaction window) down from a very
// forgiving 0.95s to a floor of MIN_SAFE_REACTION across all 32 levels.
function bouncePeriodForIndex(i) {
  return Math.max(MIN_SAFE_REACTION, +(0.95 - i * 0.0177).toFixed(3));
}

const LEVEL_NAMES = [
  'First Steps', 'Left & Right', 'Circle Practice', 'Full Cycle',
  'Danger Debut', 'Quick Hands', 'Reflex Check', 'Spike Alley',
  'Green Light', 'Chain Reaction', 'Double Trouble', 'Steady Hands',
  'More Spikes', 'Fast Fingers', 'Back to Back', 'Tower Climb',
  'All Mixed Up', 'Chain of Danger', 'Sharp Reflexes', 'No Mercy',
  'Snap Decisions', 'Red Alert', 'Circle Storm', 'Overdrive',
  'Advanced Drill', 'Twin Spikes', 'Precision Run', 'Iron Nerves',
  'Marathon', 'Chain Gauntlet', 'Endless Climb', 'Bricks Master',
];

const LEVEL_DEFS = [];
for (let i = 0; i < 32; i++) {
  const count = countForIndex(i);
  const bouncePeriod = bouncePeriodForIndex(i);
  let bricks;

  if (i === 0) {
    // Pure tutorial block: teach LEFT, then RIGHT, then CIRCLE in isolation
    // before any mixing at all.
    bricks = ['left', 'left', 'right', 'right', 'circle', 'circle', 'left', 'right'].map(blueBrick);
  } else if (i === 1) {
    bricks = buildSequence(count, {});
  } else if (i === 2) {
    bricks = buildSequence(count, {});
  } else if (i === 3) {
    bricks = buildSequence(count, {});
  } else if (i < 8) {
    // 5-8: mix faster, introduce first red danger bricks with generous
    // blue padding between them.
    bricks = buildSequence(count, { dangerEvery: 9 - i, dangerOffset: (i % 3) + 1 });
  } else if (i === 8) {
    // 9: first-ever green — a single auto-break brick surrounded by blue
    // (teaches BLUE -> GREEN -> BLUE with zero danger involved).
    bricks = buildSequence(count, { greenChainEvery: 6, greenChainLen: 1 });
  } else if (i === 9) {
    // 10: green immediately followed by a red (BLUE -> GREEN -> RED).
    bricks = buildSequence(count, { greenChainEvery: 6, greenChainLen: 1, dangerEvery: 7, dangerOffset: 1 });
  } else if (i < 16) {
    // 11-16: more red, longer green chains, occasional adjacent reds.
    const chainLen = i < 13 ? 2 : 3;
    bricks = buildSequence(count, {
      greenChainEvery: 6,
      greenChainLen: chainLen,
      dangerEvery: i >= 14 ? 5 : 7,
      dangerOffset: (i % 3) + 1,
      doubleRedEvery: i >= 15 ? 12 : 0,
      doubleRedOffset: 1,
    });
  } else if (i < 20) {
    // 17-20: mix everything; explicitly land a red right after a 2-green
    // chain (GREEN, GREEN, RED) every 8 bricks.
    bricks = buildSequence(count, {
      greenChainEvery: 8,
      greenChainLen: 2,
      dangerEvery: 10,
      dangerOffset: 0, // idx 10 is right after the chain at idx 8-9
    });
  } else if (i < 24) {
    // 21-24: faster decisions, more red, more circle taps.
    bricks = buildSequence(count, {
      dangerEvery: 4,
      dangerOffset: (i % 3) + 1,
      greenChainEvery: 9,
      greenChainLen: 2,
    });
  } else if (i < 28) {
    // 25-28: advanced sequences with occasional consecutive red bricks.
    bricks = buildSequence(count, {
      dangerEvery: 4,
      dangerOffset: (i % 3),
      greenChainEvery: 10,
      greenChainLen: 2,
      doubleRedEvery: 9,
      doubleRedOffset: 1,
    });
  } else if (i < 31) {
    // 29-31: very challenging — long stacks, mixed green-chain + red
    // reaction patterns, frequent back-to-back reds.
    bricks = buildSequence(count, {
      dangerEvery: 4,
      dangerOffset: (i % 3) + 1,
      greenChainEvery: 7,
      greenChainLen: 3,
      doubleRedEvery: 8,
      doubleRedOffset: 2,
    });
  } else {
    // 32: final challenge — uses every mechanic learned so far.
    bricks = buildSequence(count, {
      dangerEvery: 4,
      dangerOffset: 1,
      greenChainEvery: 6,
      greenChainLen: 3,
      doubleRedEvery: 7,
      doubleRedOffset: 2,
    });
  }

  LEVEL_DEFS.push({ name: LEVEL_NAMES[i], bouncePeriod, bricks });
}

const LEVELS = LEVEL_DEFS.map((def, i) => ({
  id: i + 1,
  name: def.name,
  bouncePeriod: def.bouncePeriod,
  bricks: def.bricks,
}));

// Dev-time solvability guard (see the SOLVABILITY INVARIANT note above) —
// every level's bounce period must stay at/above the human-reaction floor.
// This never fires unless bouncePeriodForIndex() is edited unsafely.
if (typeof console !== 'undefined') {
  LEVELS.forEach((lvl) => {
    console.assert(lvl.bouncePeriod >= MIN_SAFE_REACTION, 'Level ' + lvl.id + ' bouncePeriod below safe reaction floor');
    console.assert(lvl.bricks.length >= 8, 'Level ' + lvl.id + ' too short');
  });
}

// Exposed globally (plain <script>, no bundler/module system needed).
window.LEVELS = LEVELS;
