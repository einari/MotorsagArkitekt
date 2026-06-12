/**
 * Global demo configuration.
 *
 * All musical timing derives from analysis of `music.mp3` ("Motorsag Arkitekt"
 * by kim_jensen): ~129 BPM, first downbeat at ~0.408s, total length ~117.7s.
 * Effect cues and scene boundaries are expressed in seconds and snapped to
 * the bar grid so everything lands on the beat.
 */
export const MUSIC = {
  url: 'assets/music.mp3',
  bpm: 129,
  /** Time (s) of the first kick / downbeat. */
  firstBeat: 0.408,
  duration: 117.72,
} as const;

export const beatLength = 60 / MUSIC.bpm; // ~0.465s
export const barLength = beatLength * 4; // ~1.86s

/** Convert a bar index (from firstBeat) to seconds. */
export function bar(n: number): number {
  return MUSIC.firstBeat + n * barLength;
}

export const FONTS = {
  heading: 'PressStart',
  scroller: 'VT323',
} as const;

/** Synthwave palette pulled from style.png (pink city / cyan neon). */
export const PALETTE = {
  hotPink: '#ff2ea6',
  pink: '#ff5ec7',
  magenta: '#c724b1',
  purple: '#7b2ff7',
  deepPurple: '#2a0a3a',
  cyan: '#2bd4ff',
  iceBlue: '#6ee7ff',
  yellow: '#ffe45e',
  orange: '#ff8a3d',
  night: '#0a0414',
} as const;

/** Hex string -> THREE-friendly 0xRRGGBB number. */
export function hex(s: string): number {
  return parseInt(s.replace('#', ''), 16);
}
