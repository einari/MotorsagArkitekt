import {
  Mesh,
  OrthographicCamera,
  PlaneGeometry,
  Scene,
  ShaderMaterial,
  Texture,
  Vector2,
  type WebGLRenderer,
} from 'three';
import type { Frame } from '../core/Frame';

/**
 * Final-stage CRT emulation: barrel (pincushion) distortion, scanlines, an RGB
 * shadow mask, chromatic aberration toward the edges, vignette, rolling bright
 * bar, and a soft glow. Intensity reacts a little to the music so the tube
 * "breathes" with the bass.
 */
const FRAG = /* glsl */ `
  precision highp float;
  varying vec2 vUv;
  uniform sampler2D uTex;
  uniform vec2 uRes;
  uniform float uTime;
  uniform float uBeat;
  uniform float uCurvature;
  uniform float uScanline;
  uniform float uAberration;
  uniform float uVignette;
  uniform float uGlow;

  // Barrel distortion of UV around center.
  vec2 curve(vec2 uv) {
    uv = uv * 2.0 - 1.0;
    vec2 offset = abs(uv.yx) / uCurvature;
    uv = uv + uv * offset * offset;
    return uv * 0.5 + 0.5;
  }

  vec3 sampleGlow(vec2 uv) {
    // cheap separable-ish blur for the glow term
    vec3 sum = vec3(0.0);
    vec2 px = 1.5 / uRes;
    sum += texture2D(uTex, uv).rgb * 0.30;
    sum += texture2D(uTex, uv + vec2(px.x, 0.0)).rgb * 0.16;
    sum += texture2D(uTex, uv - vec2(px.x, 0.0)).rgb * 0.16;
    sum += texture2D(uTex, uv + vec2(0.0, px.y)).rgb * 0.16;
    sum += texture2D(uTex, uv - vec2(0.0, px.y)).rgb * 0.16;
    sum += texture2D(uTex, uv + px * 2.0).rgb * 0.03;
    sum += texture2D(uTex, uv - px * 2.0).rgb * 0.03;
    return sum;
  }

  void main() {
    vec2 uv = curve(vUv);

    // Outside-the-tube => black bezel.
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
      gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
      return;
    }

    // Chromatic aberration grows toward edges.
    vec2 dir = uv - 0.5;
    float ca = uAberration * (0.4 + dot(dir, dir) * 2.0) * (1.0 + uBeat * 0.6);
    float r = texture2D(uTex, uv + dir * ca).r;
    float g = texture2D(uTex, uv).g;
    float b = texture2D(uTex, uv - dir * ca).b;
    vec3 col = vec3(r, g, b);

    // Soft glow / bloom.
    col += sampleGlow(uv) * uGlow * (0.8 + uBeat * 0.5);

    // Scanlines (vertical resolution dependent).
    float sl = sin(uv.y * uRes.y * 1.0) * 0.5 + 0.5;
    col *= 1.0 - uScanline * (1.0 - sl);

    // RGB shadow mask (aperture-grille style).
    float m = mod(gl_FragCoord.x, 3.0);
    vec3 mask = vec3(0.92);
    if (m < 1.0) mask = vec3(1.05, 0.92, 0.92);
    else if (m < 2.0) mask = vec3(0.92, 1.05, 0.92);
    else mask = vec3(0.92, 0.92, 1.05);
    col *= mask;

    // Rolling bright bar (slow vertical scan).
    float roll = sin((uv.y - uTime * 0.06) * 6.2831) * 0.5 + 0.5;
    col *= 1.0 + roll * 0.04;

    // Vignette.
    float vig = 1.0 - dot(dir, dir) * uVignette;
    col *= clamp(vig, 0.0, 1.0);

    // Subtle flicker + grain.
    float flick = 0.97 + 0.03 * sin(uTime * 50.0);
    float grain = fract(sin(dot(gl_FragCoord.xy + uTime, vec2(12.9898, 78.233))) * 43758.5453);
    col *= flick;
    col += (grain - 0.5) * 0.025;

    gl_FragColor = vec4(col, 1.0);
  }
`;

const VERT = /* glsl */ `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = vec4(position.xy, 0.0, 1.0);
  }
`;

export class CRTPass {
  private scene = new Scene();
  private camera = new OrthographicCamera(-1, 1, 1, -1, 0, 1);
  private material: ShaderMaterial;

  /** Global strength multiplier (director can fade the whole effect). */
  strength = 1;

  constructor() {
    this.material = new ShaderMaterial({
      vertexShader: VERT,
      fragmentShader: FRAG,
      depthTest: false,
      depthWrite: false,
      uniforms: {
        uTex: { value: null as Texture | null },
        uRes: { value: new Vector2(1, 1) },
        uTime: { value: 0 },
        uBeat: { value: 0 },
        uCurvature: { value: 6.0 },
        uScanline: { value: 0.28 },
        uAberration: { value: 0.0016 },
        uVignette: { value: 0.55 },
        uGlow: { value: 0.55 },
      },
    });
    const mesh = new Mesh(new PlaneGeometry(2, 2), this.material);
    mesh.frustumCulled = false;
    this.scene.add(mesh);
  }

  render(renderer: WebGLRenderer, tex: Texture, f: Frame): void {
    const u = this.material.uniforms;
    u.uTex.value = tex;
    u.uRes.value.set(f.width, f.height);
    u.uTime.value = f.time;
    u.uBeat.value = f.audio.beatPulse * this.strength;
    u.uScanline.value = 0.28 * this.strength;
    u.uGlow.value = 0.55 * this.strength;
    u.uAberration.value = 0.0016 * this.strength;
    renderer.render(this.scene, this.camera);
  }

  resize(width: number, height: number): void {
    this.material.uniforms.uRes.value.set(width, height);
  }
}
