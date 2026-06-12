import { NormalBlending } from 'three';
import { FullscreenFx } from '../core/FullscreenFx';

/**
 * Classic raster tunnel: screen polar coordinates map to (angle, 1/radius)
 * texture coordinates, producing the illusion of flying down an infinite tube.
 * The procedural "texture" is a neon brick/stripe pattern; zoom speed and the
 * fish-eye wobble pulse with the music.
 */
const FRAG = /* glsl */ `
  precision highp float;
  varying vec2 vUv;
  uniform vec2 uRes;
  uniform float uTime;
  uniform float uOpacity;
  uniform float uBass;
  uniform float uTreble;

  vec3 pal(float t) {
    return 0.5 + 0.5 * cos(6.28318 * (vec3(1.0) * t + vec3(0.0, 0.33, 0.66)));
  }

  void main() {
    float ar = uRes.x / uRes.y;
    vec2 p = (vUv - 0.5) * vec2(ar, 1.0);
    float r = length(p);
    float a = atan(p.y, p.x);

    float speed = 0.6 + uBass * 0.8;
    float u = a / 6.28318 * 6.0;            // 6 segments around
    float v = 0.30 / (r + 0.04) + uTime * speed;

    // neon grid pattern
    float gridU = abs(fract(u * 2.0) - 0.5);
    float gridV = abs(fract(v) - 0.5);
    float line = smoothstep(0.46, 0.5, max(gridU, gridV));
    float cell = floor(v) + floor(u * 2.0);

    vec3 base = pal(cell * 0.12 + uTime * 0.08);
    vec3 col = base * (0.25 + line * 1.1);
    col += pal(v * 0.2) * (1.0 - line) * 0.25;

    // glow toward the vanishing point, plus treble sparkle on the walls
    col *= smoothstep(0.0, 0.25, r) * 1.4;
    col += vec3(0.6, 0.9, 1.0) * smoothstep(0.18, 0.0, r) * (0.6 + uBass);
    col += line * uTreble * 0.6;

    gl_FragColor = vec4(col, uOpacity);
  }
`;

export class Tunnel extends FullscreenFx {
  constructor() {
    super({ name: 'tunnel', fragment: FRAG, blending: NormalBlending });
  }
}
