import type { Audio } from './Audio';

/**
 * Per-frame state handed to every layer's `update`. Bundles the musical clock,
 * live audio analysis and frame timing so effects stay stateless where possible.
 */
export interface Frame {
  /** Song time in seconds. */
  time: number;
  /** Delta time in seconds (clamped). */
  dt: number;
  /** Monotonic frame counter. */
  frame: number;
  width: number;
  height: number;
  aspect: number;
  audio: Audio;
}
