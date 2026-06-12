import pressStartUrl from '../assets/fonts/PressStart2P.ttf';
import vt323Url from '../assets/fonts/VT323.ttf';
import { FONTS } from '../core/config';

/**
 * Font loading via the FontFace API instead of CSS @font-face.
 *
 * The TTFs are imported so Vite fingerprints them and emits base-correct URLs —
 * which is what makes the build portable to a GitHub Pages project subpath
 * (e.g. /MotorsagArkitekt/). Once registered on `document.fonts` they are also
 * picked up by the boot-screen CSS that references the same family names.
 */
export async function loadFonts(): Promise<void> {
  const faces = [
    new FontFace(FONTS.heading, `url(${pressStartUrl})`),
    new FontFace(FONTS.scroller, `url(${vt323Url})`),
  ];
  try {
    await Promise.all(
      faces.map(async (f) => {
        await f.load();
        (document as any).fonts.add(f);
      }),
    );
    await (document as any).fonts.ready;
  } catch {
    /* non-fatal: fall back to system monospace */
  }
}
