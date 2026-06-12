import {
  CanvasTexture,
  LinearFilter,
  ClampToEdgeWrapping,
  RepeatWrapping,
} from 'three';
import { FullscreenFx } from '../core/FullscreenFx';
import type { Frame } from '../core/Frame';
import { FONTS } from '../core/config';

const FRAG = /* glsl */ `
  precision highp float;
  varying vec2 vUv;
  uniform vec2 uRes;
  uniform float uTime;
  uniform float uOpacity;
  uniform float uBass;

  uniform sampler2D uText;
  uniform float uTextAspect;   // textWidth / textHeight
  uniform float uScroll;       // horizontal scroll, in "text heights"
  uniform float uBandY;        // vertical center of the band (0..1)
  uniform float uBandH;        // half-height of the band in uv
  uniform float uAmp;          // sine amplitude (uv)
  uniform float uFreq;         // sine spatial frequency
  uniform float uWobble;       // per-glyph vertical wobble speed

  void main() {
    float ar = uRes.x / uRes.y;
    // how many text-heights fit across the screen band
    float bandPixelH = uBandH * 2.0;          // uv height of band
    float unitsAcross = ar / bandPixelH;       // text-units visible horizontally

    // horizontal text coordinate (in text-height units), scrolling
    float tx = vUv.x * unitsAcross + uScroll;

    // sine displacement of the baseline
    float yoff = sin(tx * uFreq + uTime * uWobble) * uAmp;
    yoff += sin(tx * uFreq * 0.5 - uTime * 0.7) * uAmp * 0.4;

    // vertical position within band, with displacement
    float ly = (vUv.y - (uBandY + yoff)) / uBandH; // -1..1 across band
    if (abs(ly) > 1.0) { gl_FragColor = vec4(0.0); return; }

    // sample text: u from scrolling tx (wrap), v from band-local
    float u = fract(tx / uTextAspect);
    float v = ly * 0.5 + 0.5;
    vec4 t = texture2D(uText, vec2(u, v));

    // rainbow tint based on column (classic copper-text feel)
    vec3 tint = 0.6 + 0.4 * cos(6.2831 * (tx * 0.04 + uTime * 0.1 + vec3(0.0, 0.33, 0.66)));
    tint = mix(tint, vec3(1.0), 0.25);
    vec3 col = t.rgb * tint * (1.0 + uBass * 0.5);

    gl_FragColor = vec4(col, t.a * uOpacity);
  }
`;

export interface ScrollerOptions {
  name?: string;
  text: string;
  speed?: number; // text-units per second
  bandY?: number; // 0=bottom .. 1=top
  amp?: number;
  freq?: number;
  fontSize?: number;
  height?: number; // band half-height in uv
}

/**
 * The obligatory sine scroller. A long message is rasterized once to a strip
 * texture; the shader scrolls it horizontally while riding a sine wave (plus a
 * secondary harmonic), tinted with a moving rainbow. Used for the credits and
 * the greetings roll.
 */
export class SineScroller extends FullscreenFx {
  private texture: CanvasTexture;
  private speed: number;

  constructor(opts: ScrollerOptions) {
    const fontSize = opts.fontSize ?? 96;
    const { canvas } = buildStrip(opts.text, fontSize);
    const texture = new CanvasTexture(canvas);
    texture.wrapS = RepeatWrapping;
    texture.wrapT = ClampToEdgeWrapping;
    texture.minFilter = LinearFilter;
    texture.magFilter = LinearFilter;
    texture.generateMipmaps = false;

    super({
      name: opts.name ?? 'sineScroller',
      fragment: FRAG,
      transparent: true,
      uniforms: {
        uText: { value: texture },
        uTextAspect: { value: canvas.width / canvas.height },
        uScroll: { value: 0 },
        uBandY: { value: opts.bandY ?? 0.16 },
        uBandH: { value: opts.height ?? 0.11 },
        uAmp: { value: opts.amp ?? 0.06 },
        uFreq: { value: opts.freq ?? 0.55 },
        uWobble: { value: 2.0 },
      },
    });
    this.texture = texture;
    this.speed = opts.speed ?? 2.2;
  }

  update(f: Frame): void {
    super.update(f);
    this.uniforms.uScroll.value += this.speed * f.dt * (1 + f.audio.beatPulse * 0.15);
  }

  dispose(): void {
    super.dispose();
    this.texture.dispose();
  }
}

/**
 * Rasterize the scroller message to a single-row strip. Height is fixed; width
 * grows with the text (clamped to a safe max texture size, wrapping if longer).
 */
function buildStrip(text: string, fontSize: number): { canvas: HTMLCanvasElement } {
  const pad = fontSize * 0.6;
  const measure = document.createElement('canvas').getContext('2d')!;
  const font = `${fontSize}px ${FONTS.scroller}`;
  measure.font = font;
  // add trailing spaces so the wrap has a gap
  const padded = text + '          ';
  const w = Math.min(8192, Math.ceil(measure.measureText(padded).width) + pad);
  const h = Math.ceil(fontSize * 1.6);

  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext('2d')!;
  ctx.font = font;
  ctx.textBaseline = 'middle';
  ctx.textAlign = 'left';

  // chunky bevel: dark drop shadow then bright fill, like the FALON scroller
  const cy = h / 2;
  ctx.fillStyle = '#0a0414';
  ctx.fillText(padded, 4, cy + 4);
  const grad = ctx.createLinearGradient(0, cy - fontSize * 0.6, 0, cy + fontSize * 0.6);
  grad.addColorStop(0, '#ffffff');
  grad.addColorStop(0.5, '#bfe9ff');
  grad.addColorStop(1, '#6ee7ff');
  ctx.fillStyle = grad;
  ctx.fillText(padded, 0, cy);
  ctx.lineWidth = 2;
  ctx.strokeStyle = '#2bd4ff';
  ctx.strokeText(padded, 0, cy);

  return { canvas };
}
