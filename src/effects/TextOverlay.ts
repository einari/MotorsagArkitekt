import {
  CanvasTexture,
  LinearFilter,
  Sprite,
  SpriteMaterial,
} from 'three';
import { OrthoLayer } from '../core/OrthoLayer';
import type { Frame } from '../core/Frame';
import { renderLine, type TextStyle } from '../text/canvasText';

export type Anim = 'fade' | 'pop' | 'slide' | 'zoom';

export interface TextCue {
  start: number;
  end: number;
  text: string;
  style: TextStyle;
  /** vertical center, -1 (bottom) .. 1 (top). */
  y?: number;
  /** sprite height in world units (camera spans -1..1). */
  size?: number;
  anim?: Anim;
  /** beat pulse scaling. */
  pulse?: boolean;
}

interface Entry {
  cue: TextCue;
  sprite: Sprite;
  ratio: number;
}

/**
 * Timed text overlay used for the lyrics and title/end cards. Each cue is
 * rasterized once (neon styled) and shown between its start/end times with a
 * configurable intro animation and an optional beat pulse.
 */
export class TextOverlay extends OrthoLayer {
  readonly name: string;
  private entries: Entry[] = [];

  constructor(name: string, cues: TextCue[]) {
    super();
    this.name = name;
    for (const cue of cues) {
      const { canvas, width, height } = renderLine(cue.text, cue.style);
      const tex = new CanvasTexture(canvas);
      tex.minFilter = LinearFilter;
      tex.magFilter = LinearFilter;
      tex.generateMipmaps = false;
      const mat = new SpriteMaterial({
        map: tex,
        transparent: true,
        depthTest: false,
        depthWrite: false,
        opacity: 0,
      });
      const sprite = new Sprite(mat);
      sprite.visible = false;
      const ratio = width / height;
      const size = cue.size ?? 0.16;
      sprite.scale.set(size * ratio, size, 1);
      sprite.position.set(0, cue.y ?? 0, 0);
      this.scene.add(sprite);
      this.entries.push({ cue, sprite, ratio });
    }
  }

  update(f: Frame): void {
    const t = f.time;
    for (const e of this.entries) {
      const { cue, sprite } = e;
      const active = t >= cue.start && t <= cue.end;
      sprite.visible = active && this.opacity > 0.01;
      if (!active) continue;

      const inDur = 0.4;
      const outDur = 0.4;
      const tin = Math.min(1, (t - cue.start) / inDur);
      const tout = Math.min(1, (cue.end - t) / outDur);
      const env = Math.min(tin, tout);
      const ease = env * env * (3 - 2 * env);

      const size = cue.size ?? 0.16;
      let scale = 1;
      let dx = 0;
      switch (cue.anim ?? 'fade') {
        case 'pop':
          scale = 0.6 + ease * 0.4 + (1 - tin) * 0.3;
          break;
        case 'zoom':
          scale = 0.2 + tin * 0.8 + (t - cue.start) * 0.04;
          break;
        case 'slide':
          dx = (1 - ease) * this.aspect * 1.2;
          break;
      }
      if (cue.pulse) scale *= 1 + f.audio.beatPulse * 0.08;

      sprite.material.opacity = ease * this.opacity;
      sprite.scale.set(size * e.ratio * scale, size * scale, 1);
      sprite.position.x = dx;
      sprite.position.y = cue.y ?? 0;
    }
  }

  dispose(): void {
    for (const e of this.entries) {
      (e.sprite.material as SpriteMaterial).map?.dispose();
      e.sprite.material.dispose();
    }
  }
}
