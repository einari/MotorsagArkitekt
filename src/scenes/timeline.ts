import { PALETTE, bar } from '../core/config';
import type { TextStyle } from '../text/canvasText';
import type { TextCue } from '../effects/TextOverlay';

/**
 * The demo script. Everything here is data: which layers are on screen when,
 * the lyric cues, and the punctuating flashes. Times are in seconds and were
 * chosen against the analysed song structure (129 BPM; build 0–36s, drop
 * 36–64s, verse/chorus 64–94s, finale 94–114s, outro 114–118s).
 *
 * Tweaking the show is meant to be done here, not in engine code.
 */

/** A layer's on-screen window with fade envelopes. */
export interface LayerCue {
  layer: string;
  in: number;
  out: number;
  fadeIn?: number;
  fadeOut?: number;
  /** peak opacity (default 1). */
  level?: number;
}

/** Render order, back (first) to front (last). */
export const Z_ORDER = [
  'outrunGrid',
  'plasma',
  'moire',
  'tunnel',
  'starfield',
  'copperBars',
  'bobs',
  'magicCircles',
  'spaceships',
  'dancers',
  'horseFlock',
  'catFlock',
  'shipFlock',
  'lyrics',
  'scroller',
  'greets',
  'title',
  'fade',
] as const;

// Section anchors (seconds)
const INTRO_END = 4;
const DROP = 36;
const BREAK1 = 64;
const DROP2 = 66;
const BREAK2 = 94;
const FINALE = 96;
const OUTRO = 114;
const END = 118;

// ---- Measured vocal anchors (read off the demo with the "D" timecode HUD) ----
//   first "Kattene"          -> 7.72s
//   first "...er fantastisk" -> 32.0s
// The verse lines sit between those two points; ~2.61s/line (≈1.4 bars) makes
// the hook land exactly on the anchor. Same spacing is reused for the repeat.
export const V1_START = 7.72; // first "Kattene"
const V1_HOOK = 32.0; // first "...er fantastisk!"
export const VERSE_STEP = (V1_HOOK - 6 - V1_START) / 7; // ≈2.61s; 8 verse lines fit before the bridge
const V2_START = 66.0; // second "Kattene" (repeat) — refine from the HUD if needed

export const LAYER_CUES: LayerCue[] = [
  // ---- Intro (0–4): starfield + copper behind the title ----
  { layer: 'starfield', in: 0, out: DROP, fadeIn: 1.5 },
  { layer: 'copperBars', in: 1.5, out: DROP, fadeIn: 2 },

  // ---- Build / verse (4–36): plasma bed, cats & horses, magic circles ----
  { layer: 'plasma', in: INTRO_END, out: DROP, fadeIn: 2, level: 0.9 },
  { layer: 'catFlock', in: bar(4), out: DROP, fadeIn: 1 },
  { layer: 'horseFlock', in: V1_START + 3 * VERSE_STEP, out: DROP, fadeIn: 0.5 },
  { layer: 'magicCircles', in: bar(8), out: DROP, fadeIn: 2, level: 0.8 },

  // ---- DROP / chorus (36–64): outrun grid + 3D spaceships ----
  { layer: 'outrunGrid', in: DROP, out: BREAK1, fadeIn: 0.2 },
  { layer: 'spaceships', in: DROP, out: BREAK1, fadeIn: 0.5 },
  { layer: 'copperBars', in: DROP, out: BREAK1, fadeIn: 0.5, level: 0.7 },
  { layer: 'starfield', in: DROP, out: BREAK1, fadeIn: 0.5, level: 0.6 },

  // ---- Verse/chorus 2 (64–94): tunnel, moiré dancers, bobs ----
  { layer: 'tunnel', in: BREAK1, out: BREAK2, fadeIn: 0.6 },
  { layer: 'moire', in: DROP2 + 6, out: BREAK2, fadeIn: 1.5, level: 0.85 },
  { layer: 'dancers', in: DROP2 + 6, out: BREAK2, fadeIn: 1.5 },
  { layer: 'magicCircles', in: DROP2, out: BREAK2, fadeIn: 1, level: 0.9 },
  { layer: 'bobs', in: DROP2, out: BREAK2, fadeIn: 1.5, level: 0.8 },
  { layer: 'catFlock', in: BREAK1, out: DROP2 + 8, fadeIn: 1, level: 0.9 },
  { layer: 'horseFlock', in: DROP2 + 4, out: BREAK2, fadeIn: 1, level: 0.9 },

  // ---- Finale (96–114): everything, greetings, ships ----
  { layer: 'outrunGrid', in: FINALE, out: END, fadeIn: 0.4 },
  { layer: 'plasma', in: FINALE, out: OUTRO, fadeIn: 0.4, level: 0.6 },
  { layer: 'copperBars', in: FINALE, out: END, fadeIn: 0.4, level: 0.8 },
  { layer: 'spaceships', in: FINALE, out: END, fadeIn: 0.4 },
  { layer: 'starfield', in: FINALE, out: END, fadeIn: 0.4, level: 0.7 },
  { layer: 'shipFlock', in: FINALE, out: OUTRO, fadeIn: 1, level: 0.9 },
  { layer: 'magicCircles', in: FINALE, out: OUTRO, fadeIn: 1, level: 0.7 },

  // ---- Scroller: credits during build, greetings later ----
  { layer: 'scroller', in: bar(6), out: DROP, fadeIn: 1 },
  { layer: 'greets', in: BREAK1, out: END, fadeIn: 1 },

  // ---- Title / lyric overlay always available (content time-gated inside) ----
  { layer: 'lyrics', in: 0, out: END, fadeIn: 0.5 },
  { layer: 'title', in: 0, out: END, fadeIn: 0.5 },
];

/** White flashes on big section hits. */
export const FLASHES: { time: number; amount: number; color?: string }[] = [
  { time: DROP, amount: 1.0 },
  { time: DROP + 0.01, amount: 1.0 },
  { time: BREAK1, amount: 0.7, color: '#6ee7ff' },
  { time: DROP2, amount: 0.9 },
  { time: BREAK2, amount: 0.7, color: '#ff5ec7' },
  { time: FINALE, amount: 1.0 },
];

// ---- Lyric styling ----
const titleStyle: TextStyle = {
  font: 'PressStart',
  size: 96,
  fill: [PALETTE.iceBlue, PALETTE.pink, PALETTE.hotPink],
  stroke: PALETTE.deepPurple,
  strokeWidth: 8,
  glow: PALETTE.hotPink,
  glowBlur: 28,
  letterSpacing: 4,
};
const lyricStyle: TextStyle = {
  font: 'PressStart',
  size: 64,
  fill: ['#ffffff', PALETTE.iceBlue],
  stroke: PALETTE.purple,
  strokeWidth: 6,
  glow: PALETTE.cyan,
  glowBlur: 22,
  letterSpacing: 2,
};
const lyricPink: TextStyle = {
  ...lyricStyle,
  fill: ['#ffffff', PALETTE.pink],
  glow: PALETTE.hotPink,
};
const hookStyle: TextStyle = {
  font: 'PressStart',
  size: 88,
  fill: [PALETTE.yellow, PALETTE.orange, PALETTE.hotPink],
  stroke: PALETTE.deepPurple,
  strokeWidth: 8,
  glow: PALETTE.yellow,
  glowBlur: 30,
  letterSpacing: 3,
};
const oohStyle: TextStyle = {
  font: 'VT323',
  size: 90,
  fill: [PALETTE.iceBlue, PALETTE.cyan],
  glow: PALETTE.cyan,
  glowBlur: 24,
};

/** Build a verse block (cats/horses) starting at time `t0`, returns cues. */
function verseBlock(t0: number, step: number): TextCue[] {
  const L = (i: number, text: string, style: TextStyle, opts: Partial<TextCue> = {}): TextCue => ({
    start: t0 + i * step,
    end: t0 + i * step + step * 0.95,
    text,
    style,
    y: 0.12,
    size: 0.14,
    anim: 'pop',
    pulse: true,
    ...opts,
  });
  return [
    L(0, 'KATTENE', lyricPink, { size: 0.2, anim: 'zoom' }),
    L(1, 'de leker seg med motorsag', lyricStyle, { size: 0.11 }),
    L(2, '( oohh )', oohStyle, { size: 0.13, y: 0.0 }),
    L(3, 'HESTENE', lyricPink, { size: 0.2, anim: 'zoom' }),
    L(4, 'de søker arkitektoppdrag', lyricStyle, { size: 0.11 }),
    L(5, '( oohh )', oohStyle, { size: 0.13, y: 0.0 }),
    L(6, 'hvorfor det?', lyricStyle, { size: 0.13 }),
    L(7, 'det er faktisk ikke godt å si', lyricStyle, { size: 0.1 }),
  ];
}

export const TITLE_CUES: TextCue[] = [
  { start: 0.5, end: 4.2, text: 'KATTENE', style: titleStyle, y: 0.18, size: 0.26, anim: 'zoom', pulse: true },
  { start: 0.5, end: 4.2, text: 'presenterer', style: { ...lyricStyle, font: 'VT323', size: 54, glow: PALETTE.cyan }, y: -0.05, size: 0.1, anim: 'fade' },
  { start: 1.4, end: 4.2, text: 'MOTORSAG ARKITEKT', style: { ...lyricStyle, size: 40 }, y: -0.45, size: 0.075, anim: 'slide' },

  // end card
  { start: OUTRO + 0.5, end: END, text: 'TUSEN TAKK', style: titleStyle, y: 0.2, size: 0.22, anim: 'zoom', pulse: true },
  { start: OUTRO + 1.0, end: END, text: 'romskip er fantastisk', style: { ...lyricStyle, font: 'VT323', size: 60, glow: PALETTE.cyan }, y: -0.05, size: 0.11 },
  { start: OUTRO + 1.5, end: END, text: 'kim_jensen · 2026', style: { ...lyricStyle, font: 'VT323', size: 46 }, y: -0.5, size: 0.08 },
];

/** The bridge + hook that close a verse block, anchored to the block's hook time. */
function hookTail(hookTime: number, opts: { big?: boolean } = {}): TextCue[] {
  const fantSize = opts.big ? 0.26 : 0.24;
  return [
    { start: hookTime - 3.4, end: hookTime - 2.0, text: 'nei · nei · nei', style: lyricPink, y: 0.0, size: 0.16, anim: 'pop', pulse: true },
    { start: hookTime - 2.0, end: hookTime, text: 'men det vi vet er at romskip', style: lyricStyle, y: 0.15, size: 0.1, anim: 'slide' },
    { start: hookTime, end: hookTime + 4.0, text: 'ER FANTASTISK!', style: hookStyle, y: -0.02, size: fantSize, anim: 'zoom', pulse: true },
  ];
}

export const LYRIC_CUES: TextCue[] = [
  // ---- Verse 1 (build): Kattene 7.72s … hook 32s ----
  ...verseBlock(V1_START, VERSE_STEP),
  ...hookTail(V1_HOOK),

  // ---- Verse 2 (repeat) ----
  ...verseBlock(V2_START, VERSE_STEP),
  ...hookTail(V2_START + 7 * VERSE_STEP + 6, { big: true }),
];

// ---- Scroller texts ----
export const CREDITS_TEXT =
  '*** MOTORSAG ARKITEKT *** ' +
  'en KATTENE produksjon anno 2026 .' +
  'musikk av kim_jensen fremsummet fra suno sine dybder.... ' +
  'kode, grafikk og effekter av claude - promptmaster 2000; einar_ingebrigtsen .... ' +
  'ekte sanntids demoscene-magi rett i nettleseren din. ' +
  'katter med motorsag - hester paa jakt etter arkitektoppdrag - og sjoelvsagt ROMSKIP! ....      ';

export const GREETS_TEXT =
  '   GREETINGS FLY OUT TO ALL THE LEGENDS OF THE SCENE !!   ' +
  'FAIRLIGHT .. RAZOR 1911 .. THE BLACK LOTUS .. FARBRAUSCH .. CRYPTOBURNERS .. ' +
  'SPACEBALLS .. MELON DEZIGN .. SCOOPEX .. ANDROMEDA .. KEFRENS .. SANITY .. ' +
  'COMPLEX .. PHENOMENA .. ANARCHY .. LEMON. .. ASCII .. and YOU watching this !!   ' +
  'remember: the horses are still looking for architecture assignments ....      ';
