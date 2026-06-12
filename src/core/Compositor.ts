import {
  LinearFilter,
  RGBAFormat,
  WebGLRenderTarget,
  type WebGLRenderer,
} from 'three';
import type { Layer } from './Layer';
import type { Frame } from './Frame';
import type { CRTPass } from '../post/CRTPass';

/**
 * Owns the offscreen scene buffer and drives the render pipeline:
 *
 *   1. clear the scene target to black
 *   2. render every active layer in order, compositing over one another
 *   3. run the CRT post pass from the scene target to the screen
 *
 * Layers are added once; the {@link Director} toggles their presence in the
 * active set and animates opacity.
 */
export class Compositor {
  private target: WebGLRenderTarget;
  active: Layer[] = [];

  constructor(
    private renderer: WebGLRenderer,
    private crt: CRTPass,
    width: number,
    height: number,
  ) {
    this.target = new WebGLRenderTarget(width, height, {
      minFilter: LinearFilter,
      magFilter: LinearFilter,
      format: RGBAFormat,
      depthBuffer: true,
      stencilBuffer: false,
    });
  }

  render(f: Frame): void {
    const r = this.renderer;
    r.autoClear = false;

    r.setRenderTarget(this.target);
    r.setClearColor(0x000000, 1);
    r.clear(true, true, true);

    for (const layer of this.active) {
      if (layer.opacity <= 0.001) continue;
      layer.render(r);
    }

    r.setRenderTarget(null);
    r.clear(true, true, true);
    this.crt.render(r, this.target.texture, f);
  }

  resize(width: number, height: number): void {
    this.target.setSize(width, height);
  }
}
