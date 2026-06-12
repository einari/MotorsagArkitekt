import { AdditiveBlending } from 'three';
import { FullscreenFx } from '../core/FullscreenFx';

/**
 * Amiga "bobs" rendered as glowing metaballs. A set of blobs travel along
 * Lissajous paths; their summed inverse-square fields are thresholded into
 * soft, merging neon globs. They scatter outward a touch on every beat.
 */
const FRAG = /* glsl */ `
  precision highp float;
  varying vec2 vUv;
  uniform vec2 uRes;
  uniform float uTime;
  uniform float uOpacity;
  uniform float uBeat;
  uniform float uMid;

  void main() {
    float ar = uRes.x / uRes.y;
    vec2 p = (vUv - 0.5) * vec2(ar, 1.0);

    const int N = 6;
    float field = 0.0;
    vec3 acc = vec3(0.0);
    float spread = 1.0 + uBeat * 0.25;
    for (int i = 0; i < N; i++) {
      float fi = float(i);
      vec2 c = vec2(
        sin(uTime * (0.5 + fi * 0.13) + fi * 1.7) * 0.55 * spread,
        sin(uTime * (0.4 + fi * 0.11) + fi * 2.3) * 0.42 * spread
      );
      float d = length(p - c);
      float w = 0.018 / (d * d + 0.004);
      field += w;
      float hue = fract(fi / float(N) + uTime * 0.05);
      vec3 tint = 0.5 + 0.5 * cos(6.28318 * (hue + vec3(0.0, 0.33, 0.66)));
      acc += tint * w;
    }
    vec3 col = acc / max(field, 0.0001);
    float m = smoothstep(0.8, 1.6, field);
    col *= m * (1.0 + uMid * 0.5);
    float a = m * uOpacity;
    gl_FragColor = vec4(col, a);
  }
`;

export class Bobs extends FullscreenFx {
  constructor() {
    super({ name: 'bobs', fragment: FRAG, blending: AdditiveBlending });
  }
}
