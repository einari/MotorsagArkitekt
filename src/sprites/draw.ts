/**
 * Procedural pixel-art sprite drawing.
 *
 * Instead of shipping bitmap assets we draw the demo's cast — chainsaw cats,
 * architect horses, spaceships, dancers — into small canvases with vector
 * primitives, then let them be sampled with nearest-neighbour filtering so they
 * read as chunky pixel art. Each draw fn takes a canvas + an animation phase.
 */

export const SPRITE_SIZE = 64;

function newCanvas(w = SPRITE_SIZE, h = SPRITE_SIZE): { c: HTMLCanvasElement; x: CanvasRenderingContext2D } {
  const c = document.createElement('canvas');
  c.width = w;
  c.height = h;
  const x = c.getContext('2d')!;
  x.imageSmoothingEnabled = false;
  return { c, x };
}

function px(x: CanvasRenderingContext2D, gx: number, gy: number, w: number, h: number, color: string): void {
  x.fillStyle = color;
  x.fillRect(Math.round(gx), Math.round(gy), Math.ceil(w), Math.ceil(h));
}

/* ----------------------------- CHAINSAW CAT ----------------------------- */
/**
 * A black cat brandishing a chainsaw. `phase` (0..1) animates the saw blade
 * teeth and a shaking motor. Drawn on a 64x64 grid.
 */
export function drawChainsawCat(phase: number): HTMLCanvasElement {
  const { c, x } = newCanvas();
  const black = '#15131c';
  const black2 = '#262232';
  const pink = '#ff5ec7';

  const shake = Math.sin(phase * Math.PI * 2 * 6) * 1.0;

  // tail
  x.strokeStyle = black;
  x.lineWidth = 4;
  x.beginPath();
  x.moveTo(14, 40);
  x.quadraticCurveTo(4, 36, 8, 26);
  x.stroke();

  // body
  px(x, 16, 30, 22, 22, black);
  px(x, 15, 33, 24, 16, black);
  // head
  px(x, 30, 18, 18, 18, black);
  // ears
  x.fillStyle = black;
  x.beginPath();
  x.moveTo(31, 19); x.lineTo(34, 10); x.lineTo(38, 20); x.closePath(); x.fill();
  x.beginPath();
  x.moveTo(44, 19); x.lineTo(47, 10); x.lineTo(40, 20); x.closePath(); x.fill();
  // inner ear
  px(x, 34, 15, 2, 4, pink);
  px(x, 43, 15, 2, 4, pink);
  // eyes (glowing)
  px(x, 34, 25, 3, 3, '#9bf7ff');
  px(x, 41, 25, 3, 3, '#9bf7ff');
  // pupils
  px(x, 35, 26, 1, 2, '#0a2a30');
  px(x, 42, 26, 1, 2, '#0a2a30');
  // nose
  px(x, 38, 29, 2, 2, pink);
  // whiskers
  x.strokeStyle = '#5a5470';
  x.lineWidth = 1;
  x.beginPath(); x.moveTo(30, 30); x.lineTo(24, 28); x.moveTo(30, 31); x.lineTo(24, 32);
  x.moveTo(46, 30); x.lineTo(52, 28); x.moveTo(46, 31); x.lineTo(52, 32); x.stroke();

  // arms holding the saw (paws)
  px(x, 22, 40, 6, 4, black2);
  px(x, 30, 42, 6, 4, black2);

  // ---- chainsaw ----
  const sx = 18 + shake;
  const sy = 44;
  // motor body
  px(x, sx, sy - 6, 14, 10, '#ff8a3d');
  px(x, sx + 1, sy - 5, 12, 8, '#ffb24d');
  px(x, sx + 2, sy - 4, 4, 3, '#2a2030'); // pull cord housing
  // handle
  x.strokeStyle = '#cc5a1f';
  x.lineWidth = 3;
  x.beginPath();
  x.moveTo(sx + 12, sy - 8); x.quadraticCurveTo(sx + 20, sy - 10, sx + 18, sy - 1);
  x.stroke();
  // bar (blade)
  const bx = sx + 14;
  const by = sy - 3;
  px(x, bx, by, 30, 5, '#c9cdd6');
  px(x, bx, by + 1, 30, 3, '#9aa0ad');
  // rounded tip
  x.fillStyle = '#c9cdd6';
  x.beginPath();
  x.arc(bx + 30, by + 2.5, 2.5, 0, Math.PI * 2);
  x.fill();
  // animated teeth
  x.fillStyle = '#3a3f49';
  const toff = (phase * 6) % 3;
  for (let i = 0; i < 12; i++) {
    const tx = bx + 1 + ((i * 3 + toff) % 30);
    px(x, tx, by - 1.5, 1.5, 1.5, '#5b616d');
    px(x, tx, by + 5, 1.5, 1.5, '#5b616d');
  }
  // motion spark
  if (Math.sin(phase * Math.PI * 2 * 3) > 0.6) {
    px(x, bx + 28, by - 3, 2, 2, '#ffe45e');
    px(x, bx + 31, by + 5, 2, 2, '#ff5ec7');
  }
  return c;
}

/* ------------------------------ ARCHITECT HORSE ------------------------------ */
/**
 * A horse on a quest for architecture assignments — it carries a tiny T-square /
 * blueprint tube. `phase` animates a gentle gallop bob and a blinking blueprint.
 */
export function drawArchitectHorse(phase: number): HTMLCanvasElement {
  const { c, x } = newCanvas();
  const body = '#b06cff';
  const bodyDark = '#7b2ff7';
  const mane = '#2bd4ff';
  const bob = Math.sin(phase * Math.PI * 2) * 1.5;

  // legs (animated trot)
  x.strokeStyle = bodyDark;
  x.lineWidth = 3;
  const legSwing = Math.sin(phase * Math.PI * 2 * 2) * 3;
  const legs = [
    [20, 44, 18 - legSwing],
    [27, 44, 18 + legSwing],
    [40, 44, 18 + legSwing],
    [47, 44, 18 - legSwing],
  ];
  for (const [lx, ly, len] of legs) {
    x.beginPath();
    x.moveTo(lx, ly);
    x.lineTo(lx, ly + len);
    x.stroke();
  }

  // body
  x.fillStyle = body;
  roundRect(x, 16, 26 + bob, 34, 18, 7);
  x.fill();
  // neck
  x.save();
  x.translate(44, 30 + bob);
  x.rotate(-0.5);
  x.fillStyle = body;
  roundRect(x, -4, -16, 12, 22, 5);
  x.fill();
  x.restore();
  // head
  px(x, 48, 14 + bob, 12, 9, body);
  px(x, 56, 17 + bob, 6, 5, body); // muzzle
  // ear
  x.fillStyle = bodyDark;
  x.beginPath();
  x.moveTo(49, 15 + bob); x.lineTo(50, 9 + bob); x.lineTo(53, 15 + bob); x.closePath(); x.fill();
  // eye
  px(x, 53, 17 + bob, 2, 2, '#0a0414');
  // mane
  x.fillStyle = mane;
  for (let i = 0; i < 7; i++) {
    px(x, 44 - i * 1.5, 14 + i * 2 + bob, 4, 4, i % 2 ? mane : '#6ee7ff');
  }
  // tail
  x.strokeStyle = mane;
  x.lineWidth = 3;
  x.beginPath();
  x.moveTo(16, 30 + bob);
  x.quadraticCurveTo(8, 34 + bob, 10, 46 + bob);
  x.stroke();

  // blueprint tube on the back (the architecture quest!)
  x.save();
  x.translate(26, 24 + bob);
  x.rotate(-0.35);
  px(x, 0, 0, 16, 5, '#ffe45e');
  px(x, 0, 0, 16, 2, '#fff3a8');
  px(x, -1, -1, 3, 7, '#2bd4ff'); // rolled blueprint sticking out
  x.restore();

  return c;
}

/* --------------------------------- SPACESHIP --------------------------------- */
/**
 * Sleek synthwave shuttle echoing style.png: dark hull, cyan underglow and
 * engine flare that flickers with `phase`. Used both as a 2D sprite and as a
 * texture; the real hero ships are 3D (see Spaceships.ts).
 */
export function drawSpaceship(phase: number): HTMLCanvasElement {
  const { c, x } = newCanvas(72, 40);
  const hull = '#1b1822';
  const hull2 = '#2c2838';
  const cyan = '#39e6ff';

  // engine flare
  const flare = 0.6 + Math.sin(phase * Math.PI * 2 * 8) * 0.4;
  const grd = x.createLinearGradient(2, 20, 18, 20);
  grd.addColorStop(0, 'rgba(255,120,40,0)');
  grd.addColorStop(0.5, `rgba(255,150,60,${0.8 * flare})`);
  grd.addColorStop(1, `rgba(120,230,255,${flare})`);
  x.fillStyle = grd;
  x.beginPath();
  x.moveTo(4, 20); x.lineTo(18, 16); x.lineTo(18, 24); x.closePath(); x.fill();

  // hull
  x.fillStyle = hull;
  x.beginPath();
  x.moveTo(16, 18);
  x.lineTo(58, 12);
  x.quadraticCurveTo(70, 16, 66, 20);
  x.quadraticCurveTo(70, 22, 58, 26);
  x.lineTo(16, 22);
  x.closePath();
  x.fill();
  // top fin / cockpit
  x.fillStyle = hull2;
  x.beginPath();
  x.moveTo(34, 13); x.lineTo(46, 6); x.lineTo(52, 12); x.closePath(); x.fill();
  // cockpit glow
  px(x, 44, 14, 10, 3, cyan);
  px(x, 46, 15, 6, 1, '#bff6ff');
  // underglow strip
  x.fillStyle = cyan;
  x.fillRect(20, 23, 36, 1.5);
  px(x, 24, 24, 3, 1, '#bff6ff');
  px(x, 40, 24, 3, 1, '#bff6ff');

  return c;
}

/* ----------------------------------- DANCER ----------------------------------- */
/**
 * Rotoscope-style dancer silhouette (see example.png) — a solid black figure
 * that we cut out of the moiré background. `pose` selects one of several
 * keyframes; callers cycle it on the beat.
 */
export function drawDancer(pose: number, color = '#000000'): HTMLCanvasElement {
  const { c, x } = newCanvas(64, 96);
  x.fillStyle = color;
  x.strokeStyle = color;
  x.lineCap = 'round';
  x.lineJoin = 'round';

  const cx = 32;
  const poses = [
    { arms: [-2.4, -0.7], legs: [0.3, -0.3], lean: 0.0, head: 0 },
    { arms: [-2.0, -2.4], legs: [0.5, 0.1], lean: 0.15, head: 2 },
    { arms: [-0.6, -2.6], legs: [-0.2, 0.4], lean: -0.12, head: -2 },
    { arms: [-2.8, -0.4], legs: [0.1, 0.1], lean: 0.05, head: 1 },
  ];
  const p = poses[pose % poses.length];

  x.save();
  x.translate(cx, 30);
  x.rotate(p.lean);

  // torso
  x.lineWidth = 11;
  x.beginPath();
  x.moveTo(0, 0);
  x.lineTo(0, 30);
  x.stroke();
  // head
  x.beginPath();
  x.arc(p.head, -12, 8, 0, Math.PI * 2);
  x.fill();

  // arms
  x.lineWidth = 7;
  const shoulder = 4;
  for (let i = 0; i < 2; i++) {
    const a = p.arms[i];
    const dir = i === 0 ? -1 : 1;
    const ex = Math.cos(a) * 18 * dir;
    const ey = Math.sin(a) * 18 + 2;
    x.beginPath();
    x.moveTo(0, shoulder);
    x.lineTo(ex, ey);
    // forearm
    x.lineTo(ex + Math.cos(a + dir * 0.6) * 14 * dir, ey + Math.sin(a + 0.5) * 14 + 4);
    x.stroke();
  }

  // legs
  x.lineWidth = 8;
  for (let i = 0; i < 2; i++) {
    const a = p.legs[i] + (i === 0 ? -0.15 : 0.15);
    const dir = i === 0 ? -1 : 1;
    const kx = Math.sin(a) * 10 * dir;
    const ky = 30 + Math.cos(a) * 18;
    x.beginPath();
    x.moveTo(0, 30);
    x.lineTo(kx, ky);
    x.lineTo(kx + Math.sin(a * 1.3) * 8 * dir, ky + 18);
    x.stroke();
  }
  x.restore();
  return c;
}

function roundRect(x: CanvasRenderingContext2D, rx: number, ry: number, w: number, h: number, r: number): void {
  x.beginPath();
  x.moveTo(rx + r, ry);
  x.arcTo(rx + w, ry, rx + w, ry + h, r);
  x.arcTo(rx + w, ry + h, rx, ry + h, r);
  x.arcTo(rx, ry + h, rx, ry, r);
  x.arcTo(rx, ry, rx + w, ry, r);
  x.closePath();
}
