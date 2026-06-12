import type { Layer } from './Layer';
import type { Frame } from './Frame';
import type { FadeOverlay } from '../effects/FadeOverlay';
import type { CRTPass } from '../post/CRTPass';
import { LAYER_CUES, FLASHES, Z_ORDER } from '../scenes/timeline';
import { MUSIC } from './config';

/**
 * Drives the show. Owns no visuals itself — it computes each layer's opacity
 * from the timeline cues every frame, fires section flashes, runs the global
 * intro/outro fade, and modulates CRT intensity so the tube swells on the drops.
 */
export class Director {
  private firedFlashes = new Set<number>();

  constructor(
    private layers: Map<string, Layer>,
    private fade: FadeOverlay,
    private crt: CRTPass,
  ) {}

  /** Layers in composit order, including the fade overlay last. */
  ordered(): Layer[] {
    const out: Layer[] = [];
    for (const name of Z_ORDER) {
      if (name === 'fade') continue;
      const l = this.layers.get(name);
      if (l) out.push(l);
    }
    out.push(this.fade);
    return out;
  }

  private envelope(t: number, cue: (typeof LAYER_CUES)[number]): number {
    if (t < cue.in || t > cue.out) return 0;
    const fi = cue.fadeIn ?? 0.5;
    const fo = cue.fadeOut ?? 0.5;
    const up = fi > 0 ? (t - cue.in) / fi : 1;
    const down = fo > 0 ? (cue.out - t) / fo : 1;
    const env = Math.min(up, down, 1);
    return Math.max(0, env) * (cue.level ?? 1);
  }

  update(f: Frame): void {
    const t = f.time;

    // 1) reset all opacities, then take the max over active cues
    for (const l of this.layers.values()) l.opacity = 0;
    for (const cue of LAYER_CUES) {
      const layer = this.layers.get(cue.layer);
      if (!layer) continue;
      const o = this.envelope(t, cue);
      if (o > layer.opacity) layer.opacity = o;
    }

    // 2) section flashes (once each)
    for (let i = 0; i < FLASHES.length; i++) {
      const fl = FLASHES[i];
      if (!this.firedFlashes.has(i) && t >= fl.time && t < fl.time + 0.25) {
        this.fade.flash(fl.amount, fl.color);
        this.firedFlashes.add(i);
      }
    }

    // 3) global intro / outro fade from-and-to black
    let fadeAlpha = 0;
    if (t < 1.2) fadeAlpha = 1 - t / 1.2; // fade in
    const fadeOutStart = MUSIC.duration - 2.0;
    if (t > fadeOutStart) fadeAlpha = Math.max(fadeAlpha, Math.min(1, (t - fadeOutStart) / 2.0));
    this.fade.color.set('#000000');
    this.fade.alpha = fadeAlpha;

    // 4) CRT intensity: calmer in the build, hot on the drops/finale
    let crt = 0.8;
    if (t >= 36 && t < 64) crt = 1.15;
    if (t >= 96) crt = 1.25;
    crt += f.audio.bass * 0.15;
    this.crt.strength += (crt - this.crt.strength) * Math.min(1, f.dt * 3);
  }
}
