import {
  Color,
  Mesh,
  OrthographicCamera,
  PlaneGeometry,
  Scene,
  ShaderMaterial,
  NormalBlending,
  type WebGLRenderer,
} from 'three';
import { BaseLayer } from '../core/Layer';
import type { Frame } from '../core/Frame';

/**
 * Fullscreen solid-color overlay for transitions: black fade in/out and white
 * beat flashes. The {@link Director} drives {@link color} and {@link alpha};
 * flashes are triggered with {@link flash} and decay automatically.
 */
export class FadeOverlay extends BaseLayer {
  readonly name = 'fade';
  private scene = new Scene();
  private camera = new OrthographicCamera(-1, 1, 1, -1, 0, 1);
  private material: ShaderMaterial;

  color = new Color('#000000');
  alpha = 0;
  private flashAmount = 0;
  private flashColor = new Color('#ffffff');

  constructor() {
    super();
    this.material = new ShaderMaterial({
      transparent: true,
      depthTest: false,
      depthWrite: false,
      blending: NormalBlending,
      uniforms: {
        uColor: { value: new Color('#000000') },
        uAlpha: { value: 0 },
      },
      vertexShader: `void main(){ gl_Position = vec4(position.xy,0.0,1.0); }`,
      fragmentShader: `
        precision highp float;
        uniform vec3 uColor; uniform float uAlpha;
        void main(){ gl_FragColor = vec4(uColor, uAlpha); }
      `,
    });
    const mesh = new Mesh(new PlaneGeometry(2, 2), this.material);
    mesh.frustumCulled = false;
    this.scene.add(mesh);
  }

  /** Trigger a flash of the given color and strength (0..1). */
  flash(amount = 0.8, color = '#ffffff'): void {
    this.flashAmount = Math.max(this.flashAmount, amount);
    this.flashColor.set(color);
  }

  update(f: Frame): void {
    this.flashAmount = Math.max(0, this.flashAmount - f.dt * 3.0);

    // composite the steady fade with the transient flash
    let a = this.alpha;
    let col = this.color;
    if (this.flashAmount > a) {
      a = this.flashAmount;
      col = this.flashColor;
    }
    this.material.uniforms.uColor.value.copy(col);
    this.material.uniforms.uAlpha.value = a;
    this.opacity = a > 0.001 ? 1 : 0;
  }

  render(renderer: WebGLRenderer): void {
    if (this.material.uniforms.uAlpha.value <= 0.001) return;
    renderer.render(this.scene, this.camera);
  }
}
