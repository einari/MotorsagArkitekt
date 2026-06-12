import { AdditiveBlending } from 'three';
import { FullscreenFx } from '../core/FullscreenFx';

/**
 * Amiga "copper bars" — horizontal raster bars with a bright specular center
 * that bob vertically on stacked sine waves. Colors cycle through the synth
 * palette and the whole stack jolts on each beat.
 */
const FRAG = /* glsl */ `
  precision highp float;
  varying vec2 vUv;
  uniform float uTime;
  uniform float uOpacity;
  uniform float uBeat;
  uniform float uBass;

  // one bar: returns intensity (0..1) and tint
  float barShape(float y, float center, float halfH) {
    float d = abs(y - center);
    float core = smoothstep(halfH, 0.0, d);
    // metallic highlight stripe in the middle
    float hi = smoothstep(halfH * 0.35, 0.0, d);
    return core * 0.7 + hi * 0.6;
  }

  vec3 hsv(float h, float s, float v) {
    vec3 c = abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0;
    return v * mix(vec3(1.0), clamp(c, 0.0, 1.0), s);
  }

  void main() {
    float y = vUv.y;
    vec3 col = vec3(0.0);
    const int N = 7;
    float beat = uBeat * 0.04;
    for (int i = 0; i < N; i++) {
      float fi = float(i);
      float phase = uTime * 0.7 + fi * 0.9;
      float center = 0.5 + sin(phase) * (0.34 + beat) + sin(phase * 0.5 + fi) * 0.08;
      float halfH = 0.045 + 0.02 * sin(uTime + fi);
      float s = barShape(y, center, halfH);
      float hue = fract(fi / float(N) + uTime * 0.05);
      vec3 tint = hsv(hue, 0.8, 1.0);
      col += s * tint;
    }
    col *= 1.0 + uBass * 0.6;
    float a = clamp(max(col.r, max(col.g, col.b)), 0.0, 1.0) * uOpacity;
    gl_FragColor = vec4(col, a);
  }
`;

export class CopperBars extends FullscreenFx {
  constructor() {
    super({ name: 'copperBars', fragment: FRAG, blending: AdditiveBlending });
  }
}
