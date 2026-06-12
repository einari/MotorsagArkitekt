import type { WebGLRenderer } from 'three';
import type { Frame } from './Frame';

/**
 * A Layer is one self-contained visual element (an effect or a 3D scene).
 *
 * Layers render in order into a shared offscreen buffer, compositing over one
 * another (most use additive or alpha blending). The {@link Director} decides
 * which layers are active at any moment and drives their {@link opacity} for
 * fades; a layer is responsible for honoring its own opacity in its output.
 */
export interface Layer {
  readonly name: string;

  /** 0..1 fade weight set by the director. */
  opacity: number;

  /** Advance simulation/animation for this frame. */
  update(f: Frame): void;

  /**
   * Draw into the currently-bound render target. The renderer is configured
   * with autoClear = false; 3D layers should clear depth themselves.
   */
  render(renderer: WebGLRenderer): void;

  resize(width: number, height: number): void;

  /** Free GPU resources. */
  dispose(): void;
}

/** Convenience base class with no-op lifecycle and an opacity field. */
export abstract class BaseLayer implements Layer {
  abstract readonly name: string;
  opacity = 1;
  abstract update(f: Frame): void;
  abstract render(renderer: WebGLRenderer): void;
  resize(_width: number, _height: number): void {}
  dispose(): void {}
}
