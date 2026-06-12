import {
  AdditiveBlending,
  BufferGeometry,
  Color,
  Float32BufferAttribute,
  Points,
  ShaderMaterial,
} from 'three';
import { SceneLayer } from '../core/SceneLayer';
import type { Frame } from '../core/Frame';

/**
 * Warp starfield — points stream past the camera toward +Z and recycle when
 * they pass behind it. Stars are tinted across the synth palette, twinkle, and
 * accelerate with the bass for that "hyperspace on the drop" feel.
 */
export class Starfield extends SceneLayer {
  readonly name = 'starfield';
  private points: Points;
  private velocities: Float32Array;
  private count: number;
  private speed = 14;

  constructor(count = 1400) {
    super(70);
    this.count = count;
    const positions = new Float32Array(count * 3);
    const colors = new Float32Array(count * 3);
    const sizes = new Float32Array(count);
    this.velocities = new Float32Array(count);

    const palette = [
      new Color('#ff5ec7'),
      new Color('#6ee7ff'),
      new Color('#ffe45e'),
      new Color('#ffffff'),
      new Color('#b58cff'),
    ];

    for (let i = 0; i < count; i++) {
      this.respawn(positions, i, true);
      const c = palette[(Math.random() * palette.length) | 0];
      colors[i * 3] = c.r;
      colors[i * 3 + 1] = c.g;
      colors[i * 3 + 2] = c.b;
      sizes[i] = 0.6 + Math.random() * 2.2;
      this.velocities[i] = 0.6 + Math.random() * 1.4;
    }

    const geo = new BufferGeometry();
    geo.setAttribute('position', new Float32BufferAttribute(positions, 3));
    geo.setAttribute('color', new Float32BufferAttribute(colors, 3));
    geo.setAttribute('aSize', new Float32BufferAttribute(sizes, 1));

    const mat = new ShaderMaterial({
      transparent: true,
      depthTest: false,
      depthWrite: false,
      blending: AdditiveBlending,
      uniforms: { uOpacity: { value: 1 }, uTime: { value: 0 } },
      vertexShader: /* glsl */ `
        attribute float aSize;
        varying vec3 vColor;
        varying float vZ;
        uniform float uTime;
        void main() {
          vColor = color;
          vec4 mv = modelViewMatrix * vec4(position, 1.0);
          vZ = -mv.z;
          gl_Position = projectionMatrix * mv;
          gl_PointSize = aSize * (60.0 / max(vZ, 0.5));
        }
      `,
      fragmentShader: /* glsl */ `
        precision highp float;
        varying vec3 vColor;
        varying float vZ;
        uniform float uOpacity;
        void main() {
          vec2 d = gl_PointCoord - 0.5;
          float r = length(d);
          float glow = smoothstep(0.5, 0.0, r);
          float fade = clamp(vZ / 40.0, 0.0, 1.0);
          float bright = mix(1.0, 0.2, fade);
          gl_FragColor = vec4(vColor * glow * bright, glow * uOpacity);
        }
      `,
    });
    (mat as any).vertexColors = true;

    this.points = new Points(geo, mat);
    this.points.frustumCulled = false;
    this.scene.add(this.points);
    this.camera.position.set(0, 0, 0);
  }

  private respawn(pos: Float32Array, i: number, anywhere: boolean): void {
    const spreadR = 26;
    const a = Math.random() * Math.PI * 2;
    const rad = Math.sqrt(Math.random()) * spreadR;
    pos[i * 3] = Math.cos(a) * rad;
    pos[i * 3 + 1] = Math.sin(a) * rad;
    pos[i * 3 + 2] = anywhere ? -Math.random() * 60 - 1 : -60;
  }

  update(f: Frame): void {
    const u = (this.points.material as ShaderMaterial).uniforms;
    u.uOpacity.value = this.opacity;
    u.uTime.value = f.time;

    const pos = this.points.geometry.getAttribute('position');
    const arr = pos.array as Float32Array;
    const v = (this.speed + f.audio.bass * 40) * f.dt;
    for (let i = 0; i < this.count; i++) {
      arr[i * 3 + 2] += v * this.velocities[i];
      if (arr[i * 3 + 2] > 1) this.respawn(arr, i, false);
    }
    pos.needsUpdate = true;
  }
}
