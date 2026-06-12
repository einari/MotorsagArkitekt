import { OrthographicCamera, Scene, type WebGLRenderer } from 'three';
import { BaseLayer } from './Layer';

/**
 * Base for 2D layers that work in a pixel-ish orthographic space. The camera
 * spans [-aspect..aspect] horizontally and [-1..1] vertically, so positions are
 * resolution-independent and easy to reason about.
 */
export abstract class OrthoLayer extends BaseLayer {
  protected scene = new Scene();
  protected camera = new OrthographicCamera(-1, 1, 1, -1, -100, 100);
  protected aspect = 1;

  render(renderer: WebGLRenderer): void {
    if (this.opacity <= 0.001) return;
    renderer.render(this.scene, this.camera);
  }

  resize(width: number, height: number): void {
    this.aspect = width / height;
    this.camera.left = -this.aspect;
    this.camera.right = this.aspect;
    this.camera.top = 1;
    this.camera.bottom = -1;
    this.camera.updateProjectionMatrix();
  }
}
