import { NormalBlending } from 'three';
import { FullscreenFx } from '../core/FullscreenFx';

/**
 * The quintessential 80s "outrun" backdrop: a gradient sky, a banded neon sun
 * on the horizon, distant city silhouette (a nod to style.png), and an infinite
 * perspective wireframe floor scrolling toward the camera. The floor scroll
 * speed and sun glow track the bass.
 */
const FRAG = /* glsl */ `
  precision highp float;
  varying vec2 vUv;
  uniform vec2 uRes;
  uniform float uTime;
  uniform float uOpacity;
  uniform float uBass;
  uniform float uBeat;

  float gridLine(float coord, float width) {
    float g = abs(fract(coord) - 0.5);
    return smoothstep(0.5 - width, 0.5, g);
  }

  // simple skyline silhouette via stacked rectangles using hash
  float hash(float x) { return fract(sin(x * 91.17) * 43758.5453); }
  float skyline(float x, float baseY, float yv) {
    float col = floor(x * 24.0);
    float h = 0.10 + hash(col) * 0.16;
    float top = baseY + h;
    float band = step(yv, top) * step(baseY - 0.02, yv);
    // window flicker
    return band;
  }

  void main() {
    vec2 uv = vUv;
    float ar = uRes.x / uRes.y;
    vec3 col;

    float horizon = 0.42;

    if (uv.y > horizon) {
      // ---- SKY ----
      float sky = (uv.y - horizon) / (1.0 - horizon);
      vec3 top = vec3(0.05, 0.02, 0.10);
      vec3 bot = vec3(0.45, 0.06, 0.30);
      col = mix(bot, top, sky);

      // sun
      vec2 sc = vec2((uv.x - 0.5) * ar, uv.y - (horizon + 0.18));
      float sd = length(sc * vec2(1.0, 1.2));
      float sun = smoothstep(0.20, 0.18, sd);
      // horizontal bands cut into the sun
      float bands = step(0.0, sin((uv.y - horizon) * 90.0));
      float bandMask = smoothstep(0.0, 0.14, uv.y - (horizon + 0.06));
      sun *= mix(1.0, bands, bandMask);
      vec3 sunCol = mix(vec3(1.0, 0.95, 0.3), vec3(1.0, 0.2, 0.55), smoothstep(0.0, 0.36, sc.y + 0.18));
      col = mix(col, sunCol, sun);
      col += sunCol * smoothstep(0.34, 0.0, sd) * (0.25 + uBass * 0.4);

      // city silhouette near horizon
      float city = skyline(uv.x * ar, horizon, uv.y) ;
      city = max(city, skyline(uv.x * ar + 7.3, horizon, uv.y));
      col = mix(col, vec3(0.10, 0.02, 0.18), city * smoothstep(horizon + 0.22, horizon, uv.y));

      // stars
      float star = step(0.997, hash(floor(uv.x * 220.0) + floor(uv.y * 220.0) * 13.0));
      col += star * sky * 0.8;
    } else {
      // ---- FLOOR ----
      float depth = horizon - uv.y;          // 0 at horizon
      float z = 0.25 / (depth + 0.02);        // perspective
      float speed = (1.0 + uBass * 1.5);
      float rows = gridLine(z - uTime * speed, 0.04 + depth * 0.5);
      float xw = (uv.x - 0.5) * ar * z * 2.0;
      float cols = gridLine(xw, 0.03 + depth * 0.4);
      float g = max(rows, cols);

      vec3 floorCol = vec3(0.02, 0.0, 0.06);
      vec3 lineCol = mix(vec3(0.2, 1.0, 1.0), vec3(1.0, 0.2, 0.8), uv.x);
      col = mix(floorCol, lineCol, g);
      // fade into horizon haze
      float haze = smoothstep(0.0, 0.18, depth);
      col = mix(vec3(0.35, 0.05, 0.28), col, haze);
      col += lineCol * g * uBeat * 0.4;
    }

    gl_FragColor = vec4(col, uOpacity);
  }
`;

export class OutrunGrid extends FullscreenFx {
  constructor() {
    super({
      name: 'outrunGrid',
      fragment: FRAG,
      blending: NormalBlending,
      transparent: true,
    });
  }
}
