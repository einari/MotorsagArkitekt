import {
  CanvasTexture,
  NearestFilter,
  Sprite,
  SpriteMaterial,
} from 'three';
import { OrthoLayer } from '../core/OrthoLayer';
import type { Frame } from '../core/Frame';
import { drawDancer } from '../sprites/draw';

/**
 * Rotoscoped dancer silhouettes (example.png). A few large figures cut as solid
 * silhouettes that switch pose on every beat, so they appear to dance in time
 * with the track over the moiré backdrop.
 */
export class Dancers extends OrthoLayer {
  readonly name = 'dancers';
  private sprites: Sprite[] = [];
  private poses: CanvasTexture[] = [];
  private ratio = 1;
  private lastBeatPose = 0;

  constructor(count = 3, color = '#0a0010') {
    super();
    const POSES = 4;
    for (let i = 0; i < POSES; i++) {
      const canvas = drawDancer(i, color);
      const tex = new CanvasTexture(canvas);
      tex.magFilter = NearestFilter;
      tex.minFilter = NearestFilter;
      tex.generateMipmaps = false;
      this.poses.push(tex);
      if (i === 0) this.ratio = canvas.width / canvas.height;
    }
    for (let i = 0; i < count; i++) {
      const mat = new SpriteMaterial({
        map: this.poses[i % POSES],
        transparent: true,
        depthTest: false,
        depthWrite: false,
      });
      const s = new Sprite(mat);
      const size = 1.4;
      s.scale.set(size * this.ratio, size, 1);
      const spread = count > 1 ? (i / (count - 1) - 0.5) : 0;
      s.position.set(spread * 1.4, -0.05, 0);
      s.userData.poseOffset = i;
      this.scene.add(s);
      this.sprites.push(s);
    }
  }

  update(f: Frame): void {
    if (f.audio.beat) this.lastBeatPose++;
    const POSES = this.poses.length;
    for (let i = 0; i < this.sprites.length; i++) {
      const s = this.sprites[i];
      const idx = (this.lastBeatPose + (s.userData.poseOffset as number)) % POSES;
      s.material.map = this.poses[idx];
      s.material.opacity = this.opacity;
      // little side-to-side groove
      const sway = Math.sin(f.time * 4 + i) * 0.04;
      s.position.x += (sway - s.position.x + (i / Math.max(1, this.sprites.length - 1) - 0.5) * 1.4) * 0;
      s.scale.x = this.ratio * 1.4 * (1 + f.audio.beatPulse * 0.04) * (Math.sin(f.time * 4 + i) > 0 ? 1 : -1);
      s.material.needsUpdate = true;
    }
  }

  dispose(): void {
    for (const t of this.poses) t.dispose();
    for (const s of this.sprites) s.material.dispose();
  }
}
