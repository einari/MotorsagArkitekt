import { FONTS } from '../core/config';

/** Ensure the embedded webfonts are decoded before we rasterize to canvas. */
export async function loadFonts(): Promise<void> {
  const probes = [
    `48px ${FONTS.heading}`,
    `64px ${FONTS.scroller}`,
  ];
  try {
    await Promise.all(probes.map((p) => (document as any).fonts.load(p)));
    await (document as any).fonts.ready;
  } catch {
    /* fonts API not critical — fall back to whatever is available */
  }
}

export interface TextStyle {
  font: string;
  size: number;
  /** css fill or gradient stops top->bottom */
  fill?: string | string[];
  stroke?: string;
  strokeWidth?: number;
  glow?: string;
  glowBlur?: number;
  letterSpacing?: number;
  align?: CanvasTextAlign;
}

/**
 * Rasterize a single line of text to its own tightly-fit canvas, with optional
 * vertical gradient fill, outline and neon glow. Returns the canvas plus the
 * baseline metrics callers need for layout.
 */
export function renderLine(
  text: string,
  style: TextStyle,
): { canvas: HTMLCanvasElement; width: number; height: number } {
  const measure = document.createElement('canvas').getContext('2d')!;
  const fontStr = `${style.size}px ${style.font}`;
  measure.font = fontStr;
  const spacing = style.letterSpacing ?? 0;

  let textWidth = 0;
  for (const ch of text) textWidth += measure.measureText(ch).width + spacing;
  textWidth = Math.max(1, textWidth - spacing);

  const pad = (style.glowBlur ?? 0) + (style.strokeWidth ?? 0) + style.size * 0.4;
  const w = Math.ceil(textWidth + pad * 2);
  const h = Math.ceil(style.size * 1.6 + pad * 2);

  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext('2d')!;
  ctx.font = fontStr;
  ctx.textBaseline = 'middle';
  ctx.textAlign = 'left';

  const baselineY = h / 2;
  let x = pad;

  const fill = style.fill ?? '#ffffff';
  let fillStyle: string | CanvasGradient = '#ffffff';
  if (Array.isArray(fill)) {
    const g = ctx.createLinearGradient(0, baselineY - style.size * 0.6, 0, baselineY + style.size * 0.6);
    fill.forEach((c, i) => g.addColorStop(i / (fill.length - 1), c));
    fillStyle = g;
  } else {
    fillStyle = fill;
  }

  // Draw glyph by glyph so we control spacing.
  const drawPass = (mode: 'glow' | 'stroke' | 'fill') => {
    let cx = pad;
    for (const ch of text) {
      const cw = measure.measureText(ch).width;
      if (mode === 'glow' && style.glow) {
        ctx.shadowColor = style.glow;
        ctx.shadowBlur = style.glowBlur ?? 16;
        ctx.fillStyle = fillStyle;
        ctx.fillText(ch, cx, baselineY);
      } else if (mode === 'stroke' && style.stroke) {
        ctx.shadowBlur = 0;
        ctx.lineWidth = style.strokeWidth ?? 3;
        ctx.strokeStyle = style.stroke;
        ctx.lineJoin = 'round';
        ctx.strokeText(ch, cx, baselineY);
      } else if (mode === 'fill') {
        ctx.shadowBlur = 0;
        ctx.fillStyle = fillStyle;
        ctx.fillText(ch, cx, baselineY);
      }
      cx += cw + spacing;
    }
  };

  if (style.glow) {
    drawPass('glow');
    drawPass('glow'); // double for stronger neon
  }
  if (style.stroke) drawPass('stroke');
  drawPass('fill');

  void x;
  return { canvas, width: w, height: h };
}
