import { WebGLRenderer } from 'three';
import { Audio } from './Audio';
import { Compositor } from './Compositor';
import { Director } from './Director';
import { CRTPass } from '../post/CRTPass';
import type { Layer } from './Layer';
import type { Frame } from './Frame';

import { OutrunGrid } from '../effects/OutrunGrid';
import { Plasma } from '../effects/Plasma';
import { Moire } from '../effects/Moire';
import { Tunnel } from '../effects/Tunnel';
import { Starfield } from '../effects/Starfield';
import { CopperBars } from '../effects/CopperBars';
import { Bobs } from '../effects/Bobs';
import { MagicCircles } from '../effects/MagicCircles';
import { Spaceships } from '../effects/Spaceships';
import { Dancers } from '../effects/Dancers';
import { SpriteFlock } from '../effects/SpriteFlock';
import { TextOverlay } from '../effects/TextOverlay';
import { SineScroller } from '../effects/SineScroller';
import { FadeOverlay } from '../effects/FadeOverlay';
import {
  drawChainsawCat,
  drawArchitectHorse,
  drawSpaceship,
} from '../sprites/draw';
import {
  LYRIC_CUES,
  TITLE_CUES,
  CREDITS_TEXT,
  GREETS_TEXT,
} from '../scenes/timeline';

/**
 * Top-level demo runtime. Builds the renderer, all layers and the director,
 * then runs the audio-synced animation loop. The clock is the audio playback
 * position, so visuals never drift from the music.
 */
export class Demo {
  private renderer: WebGLRenderer;
  private compositor: Compositor;
  private director: Director;
  private crt: CRTPass;
  private fade: FadeOverlay;
  private layers = new Map<string, Layer>();
  private frameCount = 0;
  private lastTs = 0;
  private running = false;
  private hud: HTMLDivElement;

  constructor(
    private canvas: HTMLCanvasElement,
    public audio: Audio,
  ) {
    this.renderer = new WebGLRenderer({
      canvas,
      antialias: false,
      powerPreference: 'high-performance',
      alpha: false,
    });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    this.renderer.autoClear = false;

    this.crt = new CRTPass();
    this.fade = new FadeOverlay();

    this.buildLayers();

    const { w, h } = this.size();
    this.compositor = new Compositor(this.renderer, this.crt, w, h);
    this.director = new Director(this.layers, this.fade, this.crt);
    this.compositor.active = this.director.ordered();

    this.hud = this.makeHud();

    this.resize();
    window.addEventListener('resize', () => this.resize());
  }

  /**
   * Toggleable timecode HUD (press "D"). Shows the song clock so lyric/effect
   * cues can be read off the running demo. Hidden by default; never affects the
   * render. Also logs the time on Space, to jot down anchor points.
   */
  private makeHud(): HTMLDivElement {
    const el = document.createElement('div');
    el.style.cssText = [
      'position:fixed', 'left:8px', 'bottom:8px', 'z-index:20',
      'font:600 14px/1.4 ui-monospace,Menlo,monospace',
      'color:#6ee7ff', 'background:rgba(8,4,20,0.6)', 'padding:4px 8px',
      'border:1px solid #2bd4ff', 'border-radius:4px', 'pointer-events:none',
      'text-shadow:0 0 6px #2bd4ff', 'display:none', 'white-space:pre',
    ].join(';');
    document.body.appendChild(el);
    window.addEventListener('keydown', (e) => {
      if (e.key === 'd' || e.key === 'D') {
        el.style.display = el.style.display === 'none' ? 'block' : 'none';
      } else if (e.key === ' ') {
        // eslint-disable-next-line no-console
        console.log(`⏱ ${this.audio.time.toFixed(2)}s`);
      }
    });
    return el;
  }

  private add(layer: Layer): void {
    this.layers.set(layer.name, layer);
  }

  private buildLayers(): void {
    this.add(new OutrunGrid());
    this.add(new Plasma());
    this.add(new Moire());
    this.add(new Tunnel());
    this.add(new Starfield());
    this.add(new CopperBars());
    this.add(new Bobs());
    this.add(new MagicCircles());
    this.add(new Spaceships());
    this.add(new Dancers(3));

    const catFlock = new SpriteFlock({
      name: 'catFlock',
      draw: drawChainsawCat,
      frames: 8,
      count: 5,
      scale: 0.34,
      speed: 0.22,
      bob: 0.14,
      animSpeed: 3,
    });
    this.add(catFlock);

    const horseFlock = new SpriteFlock({
      name: 'horseFlock',
      draw: drawArchitectHorse,
      frames: 8,
      count: 4,
      scale: 0.34,
      speed: -0.18,
      bob: 0.1,
      animSpeed: 2,
    });
    this.add(horseFlock);

    const shipFlock = new SpriteFlock({
      name: 'shipFlock',
      draw: drawSpaceship,
      frames: 8,
      count: 4,
      scale: 0.24,
      speed: 0.4,
      bob: 0.18,
      animSpeed: 4,
      spin: true,
    });
    this.add(shipFlock);

    this.add(new TextOverlay('lyrics', LYRIC_CUES));
    this.add(new TextOverlay('title', TITLE_CUES));

    this.add(
      new SineScroller({
        name: 'scroller',
        text: CREDITS_TEXT,
        speed: 3,
        bandY: 0.13,
        amp: 0.05,
        freq: 0.5,
      }),
    );

    this.add(
      new SineScroller({
        name: 'greets',
        text: GREETS_TEXT,
        speed: 3.3,
        bandY: 0.13,
        amp: 0.07,
        freq: 0.6,
      }),
    );
  }

  private size(): { w: number; h: number } {
    return {
      w: this.canvas.clientWidth || window.innerWidth,
      h: this.canvas.clientHeight || window.innerHeight,
    };
  }

  private resize(): void {
    const { w, h } = this.size();
    this.renderer.setSize(w, h, false);
    this.crt.resize(w, h);
    this.compositor.resize(w, h);
    for (const l of this.layers.values()) l.resize(w, h);
  }

  start(): void {
    if (this.running) return;
    this.running = true;
    this.audio.play();
    this.lastTs = performance.now();
    requestAnimationFrame(this.loop);
  }

  private loop = (ts: number): void => {
    if (!this.running) return;
    const dtReal = (ts - this.lastTs) / 1000;
    this.lastTs = ts;
    const dt = Math.min(0.05, Math.max(0.0001, dtReal));

    this.audio.update(dt);

    const { w, h } = this.size();
    const f: Frame = {
      time: this.audio.time,
      dt,
      frame: this.frameCount++,
      width: w * this.renderer.getPixelRatio(),
      height: h * this.renderer.getPixelRatio(),
      aspect: w / h,
      audio: this.audio,
    };

    this.director.update(f);
    for (const l of this.layers.values()) l.update(f);
    this.fade.update(f);

    this.compositor.render(f);

    if (this.hud.style.display !== 'none') {
      const t = f.time;
      const mm = Math.floor(t / 60);
      const ss = (t % 60).toFixed(2).padStart(5, '0');
      this.hud.textContent = `t = ${t.toFixed(2)}s   (${mm}:${ss})\n[D] hide  ·  [Space] log time`;
    }

    requestAnimationFrame(this.loop);
  };
}
