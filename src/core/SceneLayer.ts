import {
  PerspectiveCamera,
  Scene,
  type WebGLRenderer,
} from 'three';
import { BaseLayer } from './Layer';

/**
 * Base for layers that own a real 3D Three.js scene + perspective camera.
 * Clears the depth buffer before drawing so its geometry sorts correctly while
 * still compositing its colors over whatever previous layers produced.
 */
export abstract class SceneLayer extends BaseLayer {
  protected scene = new Scene();
  protected camera: PerspectiveCamera;

  constructor(fov = 60) {
    super();
    this.camera = new PerspectiveCamera(fov, 1, 0.1, 200);
    this.camera.position.set(0, 0, 6);
  }

  render(renderer: WebGLRenderer): void {
    if (this.opacity <= 0.001) return;
    renderer.clearDepth();
    renderer.render(this.scene, this.camera);
  }

  resize(width: number, height: number): void {
    this.camera.aspect = width / height;
    this.camera.updateProjectionMatrix();
  }
}
