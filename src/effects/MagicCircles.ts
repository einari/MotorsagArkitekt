import { AdditiveBlending } from 'three';
import { FullscreenFx } from '../core/FullscreenFx';

/**
 * Translucent "magic circles" — counter-rotating rune rings with radial ticks
 * and a soft glow, drifting around the screen (per example.png). Purely
 * additive so they read as glowing transparent overlays.
 */
const FRAG = /* glsl */ `
  precision highp float;
  varying vec2 vUv;
  uniform vec2 uRes;
  uniform float uTime;
  uniform float uOpacity;
  uniform float uMid;
  uniform float uBeat;

  float ring(vec2 p, float r, float w) {
    return smoothstep(w, 0.0, abs(length(p) - r));
  }

  // ticks around a circle
  float ticks(vec2 p, float r, float count, float w) {
    float ang = atan(p.y, p.x);
    float t = abs(fract(ang / 6.2831 * count) - 0.5);
    float rr = smoothstep(0.06, 0.0, abs(length(p) - r));
    return smoothstep(0.45, 0.5, t) * rr * w;
  }

  vec3 circleAt(vec2 p, float baseR, vec3 col, float t) {
    float v = 0.0;
    v += ring(p, baseR, 0.006);
    v += ring(p, baseR * 0.82, 0.004);
    v += ring(p, baseR * 0.6, 0.004);
    // rotating tick marks
    vec2 pr = mat2(cos(t), -sin(t), sin(t), cos(t)) * p;
    v += ticks(pr, baseR * 0.91, 24.0, 1.0);
    vec2 pr2 = mat2(cos(-t * 1.7), -sin(-t * 1.7), sin(-t * 1.7), cos(-t * 1.7)) * p;
    v += ticks(pr2, baseR * 0.7, 12.0, 1.0);
    // triangle (rotating)
    return col * v;
  }

  void main() {
    float ar = uRes.x / uRes.y;
    vec2 uv = (vUv - 0.5) * vec2(ar, 1.0);
    vec3 col = vec3(0.0);

    vec2 c1 = vec2(sin(uTime * 0.4) * 0.5, cos(uTime * 0.33) * 0.3);
    col += circleAt(uv - c1, 0.32 + uBeat * 0.02, vec3(0.4, 0.95, 1.0), uTime * 0.6);

    vec2 c2 = vec2(sin(uTime * 0.3 + 2.0) * 0.6, cos(uTime * 0.5 + 1.0) * 0.35);
    col += circleAt(uv - c2, 0.22, vec3(1.0, 0.45, 0.85), -uTime * 0.8);

    vec2 c3 = vec2(sin(uTime * 0.25 + 4.0) * 0.4, cos(uTime * 0.4 + 3.0) * 0.4);
    col += circleAt(uv - c3, 0.16, vec3(1.0, 0.9, 0.4), uTime);

    col *= 1.0 + uMid * 0.6;
    float a = clamp(max(col.r, max(col.g, col.b)), 0.0, 1.0) * uOpacity;
    gl_FragColor = vec4(col, a);
  }
`;

export class MagicCircles extends FullscreenFx {
  constructor() {
    super({ name: 'magicCircles', fragment: FRAG, blending: AdditiveBlending });
  }
}
