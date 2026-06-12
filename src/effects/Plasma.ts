import { AdditiveBlending } from 'three';
import { FullscreenFx } from '../core/FullscreenFx';

/**
 * Classic multi-sine plasma in a synthwave palette. The field is built from a
 * handful of sine layers (the textbook Amiga plasma) and mapped through a
 * pink↔cyan↔purple gradient. Bass energy widens the palette cycling.
 */
const FRAG = /* glsl */ `
  precision highp float;
  varying vec2 vUv;
  uniform vec2 uRes;
  uniform float uTime;
  uniform float uOpacity;
  uniform float uBass;
  uniform float uMid;

  vec3 pal(float t) {
    // pink -> magenta -> purple -> cyan loop
    vec3 a = vec3(0.55, 0.25, 0.45);
    vec3 b = vec3(0.45, 0.30, 0.55);
    vec3 c = vec3(1.00, 1.00, 1.00);
    vec3 d = vec3(0.90, 0.55, 0.70);
    return a + b * cos(6.28318 * (c * t + d));
  }

  void main() {
    vec2 uv = vUv;
    float ar = uRes.x / uRes.y;
    vec2 p = (uv - 0.5) * vec2(ar, 1.0) * 4.0;
    float t = uTime * 0.6;

    float v = 0.0;
    v += sin(p.x * 1.3 + t);
    v += sin((p.y * 1.1 + t * 1.2));
    v += sin((p.x + p.y) * 0.9 + t * 0.8);
    float d = length(p) + sin(t * 0.7) * 1.5;
    v += sin(d * 1.6 - t * 1.5);
    v += sin(p.x * 0.7 - p.y * 0.9 + t * 1.3);
    v *= 0.2;

    float cycle = v + uTime * 0.05 + uBass * 0.5;
    vec3 col = pal(cycle);
    col *= 1.0 + uMid * 0.6;
    // gentle vertical darkening for depth
    col *= 0.8 + 0.3 * (1.0 - uv.y);

    gl_FragColor = vec4(col, uOpacity);
  }
`;

export class Plasma extends FullscreenFx {
  constructor() {
    super({ name: 'plasma', fragment: FRAG, blending: AdditiveBlending });
  }
}
