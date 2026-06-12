import { NormalBlending } from 'three';
import { FullscreenFx } from '../core/FullscreenFx';

/**
 * Halftone moiré field in the spirit of example.png: a rotozoomed dot screen
 * laid over expanding concentric rings. Two interfering ring sets produce the
 * shimmering moiré; the dot grid is rotated and zoomed over time (a classic
 * "rotozoomer"). Palette flips between hot retro hues.
 *
 * A silhouette cut-out (the rotoscoped dancer) is composited separately on top.
 */
const FRAG = /* glsl */ `
  precision highp float;
  varying vec2 vUv;
  uniform vec2 uRes;
  uniform float uTime;
  uniform float uOpacity;
  uniform float uBass;
  uniform float uMid;

  mat2 rot(float a) { return mat2(cos(a), -sin(a), sin(a), cos(a)); }

  void main() {
    float ar = uRes.x / uRes.y;
    vec2 p = (vUv - 0.5) * vec2(ar, 1.0);

    // two ring sources drifting apart -> moiré
    vec2 c1 = vec2(sin(uTime * 0.6) * 0.25, cos(uTime * 0.5) * 0.2);
    vec2 c2 = vec2(sin(uTime * 0.6 + 2.0) * 0.25, cos(uTime * 0.43 + 1.0) * 0.2);
    float r1 = length(p - c1);
    float r2 = length(p - c2);
    float freq = 60.0 + uBass * 40.0;
    float rings = sin(r1 * freq) * sin(r2 * freq);

    // rotozoomed halftone dot grid
    float zoom = 18.0 + sin(uTime * 0.4) * 8.0;
    vec2 g = rot(uTime * 0.3) * p * zoom;
    vec2 cell = fract(g) - 0.5;
    float dot = smoothstep(0.42, 0.30, length(cell) + rings * 0.18);

    // palette cycling between retro hues
    float t = floor(r1 * 8.0 - uTime * 1.5) ;
    vec3 a = vec3(0.95, 0.15, 0.15); // red
    vec3 b = vec3(0.95, 0.75, 0.10); // yellow/orange
    vec3 cc = vec3(0.15, 0.65, 0.30); // green
    float sel = mod(t, 3.0);
    vec3 ring = sel < 1.0 ? a : (sel < 2.0 ? b : cc);
    ring = mix(ring, vec3(1.0, 0.4, 0.7), uMid * 0.4);

    vec3 col = mix(vec3(0.05, 0.0, 0.08), ring, dot);
    col += ring * (0.5 + 0.5 * rings) * 0.25;

    gl_FragColor = vec4(col, uOpacity);
  }
`;

export class Moire extends FullscreenFx {
  constructor() {
    super({ name: 'moire', fragment: FRAG, blending: NormalBlending });
  }
}
