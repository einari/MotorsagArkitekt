import { MUSIC, beatLength } from './config';

/**
 * Audio engine: streams the soundtrack through the Web Audio graph and exposes
 * a realtime frequency/level analysis plus a musical clock the whole demo is
 * driven from.
 *
 * Browsers block autoplay, so {@link unlock} must be called from a user gesture
 * (the boot screen click) before {@link play}.
 */
export class Audio {
  readonly ctx: AudioContext;
  private analyser: AnalyserNode;
  private gain: GainNode;
  private source: AudioBufferSourceNode | null = null;
  private buffer: AudioBuffer | null = null;

  private freqData: Uint8Array<ArrayBuffer>;
  private timeData: Uint8Array<ArrayBuffer>;

  /** Frequency-band energies in [0,1], smoothed. */
  bass = 0;
  mid = 0;
  treble = 0;
  level = 0; // overall loudness

  /** True on the frame a kick is detected. */
  beat = false;
  /** Ramps 1 -> 0 after every detected beat (nice for pulsing visuals). */
  beatPulse = 0;

  private startTime = 0;
  private started = false;
  private bassHistory: number[] = [];

  constructor() {
    this.ctx = new AudioContext();
    this.analyser = this.ctx.createAnalyser();
    this.analyser.fftSize = 1024;
    this.analyser.smoothingTimeConstant = 0.75;
    this.gain = this.ctx.createGain();
    this.gain.gain.value = 0.9;
    this.analyser.connect(this.gain);
    this.gain.connect(this.ctx.destination);
    this.freqData = new Uint8Array(new ArrayBuffer(this.analyser.frequencyBinCount));
    this.timeData = new Uint8Array(new ArrayBuffer(this.analyser.fftSize));
  }

  async load(onProgress?: (p: number) => void): Promise<void> {
    const res = await fetch(MUSIC.url);
    if (!res.body || !res.headers.get('content-length')) {
      const buf = await res.arrayBuffer();
      this.buffer = await this.ctx.decodeAudioData(buf);
      onProgress?.(1);
      return;
    }
    const total = parseInt(res.headers.get('content-length')!, 10);
    const reader = res.body.getReader();
    const chunks: Uint8Array[] = [];
    let received = 0;
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      chunks.push(value);
      received += value.length;
      onProgress?.(received / total);
    }
    const merged = new Uint8Array(received);
    let off = 0;
    for (const c of chunks) {
      merged.set(c, off);
      off += c.length;
    }
    this.buffer = await this.ctx.decodeAudioData(merged.buffer);
  }

  async unlock(): Promise<void> {
    // iOS routes Web Audio into the "ambient" session by default, which is
    // silenced by the hardware Ring/Silent switch (Safari still shows the tab
    // sound indicator, but nothing is audible). Asking for the "playback"
    // category makes it play like media audio. Safari 16.4+; ignored elsewhere.
    const audioSession = (navigator as unknown as { audioSession?: { type: string } }).audioSession;
    if (audioSession) audioSession.type = 'playback';
    if (this.ctx.state === 'suspended') await this.ctx.resume();
  }

  play(): void {
    if (!this.buffer || this.started) return;
    this.source = this.ctx.createBufferSource();
    this.source.buffer = this.buffer;
    this.source.connect(this.analyser);
    this.startTime = this.ctx.currentTime;
    this.source.start();
    this.started = true;
  }

  /** Playback position in seconds. */
  get time(): number {
    if (!this.started) return 0;
    return this.ctx.currentTime - this.startTime;
  }

  get isPlaying(): boolean {
    return this.started && this.time < MUSIC.duration + 0.5;
  }

  /** Phase within the current beat, 0..1. */
  beatPhase(): number {
    const t = this.time - MUSIC.firstBeat;
    if (t < 0) return 0;
    return (t % beatLength) / beatLength;
  }

  /** Analyse the current audio frame. Call once per rAF. */
  update(dt: number): void {
    this.analyser.getByteFrequencyData(this.freqData);
    this.analyser.getByteTimeDomainData(this.timeData);

    const bins = this.freqData;
    const n = bins.length;
    const band = (lo: number, hi: number) => {
      let s = 0;
      const a = Math.floor(lo * n);
      const b = Math.floor(hi * n);
      for (let i = a; i < b; i++) s += bins[i];
      return s / ((b - a) * 255);
    };

    const bass = band(0.0, 0.08);
    const mid = band(0.08, 0.35);
    const treble = band(0.35, 0.9);

    // Smooth for display use.
    this.bass += (bass - this.bass) * Math.min(1, dt * 18);
    this.mid += (mid - this.mid) * Math.min(1, dt * 14);
    this.treble += (treble - this.treble) * Math.min(1, dt * 12);
    this.level += (band(0, 1) - this.level) * Math.min(1, dt * 12);

    // Simple onset detection on bass energy vs. local average.
    this.bassHistory.push(bass);
    if (this.bassHistory.length > 43) this.bassHistory.shift();
    const avg =
      this.bassHistory.reduce((a, b) => a + b, 0) / this.bassHistory.length;
    this.beat = false;
    if (bass > avg * 1.35 && bass > 0.32 && this.beatPulse < 0.45) {
      this.beat = true;
      this.beatPulse = 1;
    }
    this.beatPulse = Math.max(0, this.beatPulse - dt * 3.2);
  }

  setVolume(v: number): void {
    this.gain.gain.value = v;
  }
}
