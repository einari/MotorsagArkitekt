import {
  Mesh,
  OrthographicCamera,
  PlaneGeometry,
  Scene,
  ShaderMaterial,
  type IUniform,
  type WebGLRenderer,
  type WebGLRenderTarget,
  type Blending,
  NormalBlending,
} from 'three';
import { BaseLayer } from './Layer';
import type { Frame } from './Frame';

const VERT = /* glsl */ `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = vec4(position.xy, 0.0, 1.0);
  }
`;

export interface FullscreenOptions {
  name: string;
  fragment: string;
  uniforms?: Record<string, IUniform>;
  blending?: Blending;
  transparent?: boolean;
  depthTest?: boolean;
}

/**
 * Base layer for full-screen fragment-shader effects. Renders a single clip-space
 * triangle/quad with the supplied fragment shader. Provides standard uniforms
 * (`uTime`, `uRes`, `uOpacity`, `uBass`, `uMid`, `uTreble`, `uBeat`) and a hook
 * for per-frame uniform updates.
 */
export class FullscreenFx extends BaseLayer {
  readonly name: string;
  protected scene = new Scene();
  protected camera = new OrthographicCamera(-1, 1, 1, -1, 0, 1);
  protected material: ShaderMaterial;
  protected mesh: Mesh;
  /** Optional custom per-frame updater (set by subclass or caller). */
  onUpdate?: (f: Frame, u: Record<string, IUniform>) => void;

  constructor(opts: FullscreenOptions) {
    super();
    this.name = opts.name;
    this.material = new ShaderMaterial({
      vertexShader: VERT,
      fragmentShader: opts.fragment,
      transparent: opts.transparent ?? true,
      depthTest: opts.depthTest ?? false,
      depthWrite: false,
      blending: opts.blending ?? NormalBlending,
      uniforms: {
        uTime: { value: 0 },
        uRes: { value: [1, 1] },
        uOpacity: { value: 1 },
        uBass: { value: 0 },
        uMid: { value: 0 },
        uTreble: { value: 0 },
        uBeat: { value: 0 },
        ...(opts.uniforms ?? {}),
      },
    });
    this.mesh = new Mesh(new PlaneGeometry(2, 2), this.material);
    this.mesh.frustumCulled = false;
    this.scene.add(this.mesh);
  }

  get uniforms(): Record<string, IUniform> {
    return this.material.uniforms;
  }

  update(f: Frame): void {
    const u = this.material.uniforms;
    u.uTime.value = f.time;
    u.uRes.value = [f.width, f.height];
    u.uOpacity.value = this.opacity;
    u.uBass.value = f.audio.bass;
    u.uMid.value = f.audio.mid;
    u.uTreble.value = f.audio.treble;
    u.uBeat.value = f.audio.beatPulse;
    this.onUpdate?.(f, u);
  }

  render(renderer: WebGLRenderer): void {
    if (this.opacity <= 0.001) return;
    renderer.render(this.scene, this.camera);
  }

  /** Render to an explicit target (used by post passes). */
  renderTo(renderer: WebGLRenderer, target: WebGLRenderTarget | null): void {
    renderer.setRenderTarget(target);
    renderer.render(this.scene, this.camera);
  }

  resize(width: number, height: number): void {
    this.material.uniforms.uRes.value = [width, height];
  }

  dispose(): void {
    this.mesh.geometry.dispose();
    this.material.dispose();
  }
}
