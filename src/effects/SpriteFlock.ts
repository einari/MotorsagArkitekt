import {
  CanvasTexture,
  NearestFilter,
  Sprite,
  SpriteMaterial,
} from 'three';
import { OrthoLayer } from '../core/OrthoLayer';
import type { Frame } from '../core/Frame';

export interface FlockOptions {
  name: string;
  /** Draws one animation frame at the given phase (0..1). */
  draw: (phase: number) => HTMLCanvasElement;
  /** Number of pre-rendered animation frames. */
  frames?: number;
  /** How many sprites. */
  count?: number;
  /** World height of a sprite (camera spans -1..1 vertically). */
  scale?: number;
  /** Horizontal drift speed (world units/sec). Sign sets direction. */
  speed?: number;
  /** Vertical bob amplitude. */
  bob?: number;
  /** Animation playback speed multiplier. */
  animSpeed?: number;
  /** Random rotation wobble. */
  spin?: boolean;
}

interface Boid {
  sprite: Sprite;
  baseY: number;
  bobPhase: number;
  bobSpeed: number;
  animOffset: number;
  scaleJitter: number;
}

/**
 * A drifting flock of animated pixel-art sprites (chainsaw cats, architect
 * horses, shuttles…). Animation frames are pre-rendered once to nearest-filtered
 * canvas textures; each sprite scrolls across screen, wraps around, and bobs.
 */
export class SpriteFlock extends OrthoLayer {
  readonly name: string;
  private textures: CanvasTexture[] = [];
  private boids: Boid[] = [];
  private opts: Required<FlockOptions>;

  constructor(opts: FlockOptions) {
    super();
    this.name = opts.name;
    this.opts = {
      frames: 8,
      count: 5,
      scale: 0.34,
      speed: 0.18,
      bob: 0.12,
      animSpeed: 1,
      spin: false,
      ...opts,
    } as Required<FlockOptions>;

    for (let i = 0; i < this.opts.frames; i++) {
      const canvas = this.opts.draw(i / this.opts.frames);
      const tex = new CanvasTexture(canvas);
      tex.magFilter = NearestFilter;
      tex.minFilter = NearestFilter;
      tex.generateMipmaps = false;
      this.textures.push(tex);
    }

    const aspect0 = 16 / 9;
    for (let i = 0; i < this.opts.count; i++) {
      const mat = new SpriteMaterial({
        map: this.textures[0],
        transparent: true,
        depthTest: false,
        depthWrite: false,
        opacity: 1,
      });
      const sprite = new Sprite(mat);
      const sJ = 0.7 + Math.random() * 0.6;
      const baseY = (Math.random() * 2 - 1) * 0.7;
      const w = this.opts.scale * sJ;
      const ratio = this.textures[0].image.width / this.textures[0].image.height;
      sprite.scale.set(w * ratio, w, 1);
      sprite.position.set(
        (Math.random() * 2 - 1) * aspect0 * 1.2,
        baseY,
        i * 0.001,
      );
      this.scene.add(sprite);
      this.boids.push({
        sprite,
        baseY,
        bobPhase: Math.random() * Math.PI * 2,
        bobSpeed: 1 + Math.random() * 1.5,
        animOffset: Math.random(),
        scaleJitter: sJ,
      });
    }
  }

  update(f: Frame): void {
    const o = this.opts;
    const frameCount = this.textures.length;
    for (const b of this.boids) {
      const sp = b.sprite;
      sp.position.x += o.speed * f.dt;
      const edge = this.aspect * 1.25;
      if (o.speed > 0 && sp.position.x > edge) sp.position.x = -edge;
      if (o.speed < 0 && sp.position.x < -edge) sp.position.x = edge;
      b.bobPhase += f.dt * b.bobSpeed;
      sp.position.y = b.baseY + Math.sin(b.bobPhase) * o.bob;

      if (o.spin) sp.material.rotation = Math.sin(b.bobPhase * 0.5) * 0.25;

      // advance animation, boosted by the beat for extra liveliness
      const t = (f.time * o.animSpeed * (1 + f.audio.beatPulse * 0.6) + b.animOffset) % 1;
      const fi = Math.min(frameCount - 1, Math.floor(t * frameCount));
      sp.material.map = this.textures[fi];
      sp.material.opacity = this.opacity;
      sp.material.needsUpdate = true;
    }
  }

  dispose(): void {
    for (const t of this.textures) t.dispose();
    for (const b of this.boids) b.sprite.material.dispose();
  }
}
