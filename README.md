# MOTORSAG ARKITEKT

A synthwave **demoscene** production for the web — cats with chainsaws,
architecture-seeking horses, and spaceships, all synced to *"Motorsag Arkitekt"*
by **kim_jensen** (~129 BPM).

▶ **Live:** <https://einari.github.io/MotorsagArkitekt/>

Built with **TypeScript**, **Three.js** and **WebGL**, bundled by **Vite**.
Classic Amiga/C64 effects (plasma, copper bars, raster tunnel, starfield,
metaball bobs, rotozoomed moiré, an outrun grid, a sine scroller) mixed with 3D
scenes, all finished off with a CRT post-processing filter.

## Develop

```bash
npm install
npm run dev      # http://localhost:5173
```

## Build

```bash
npm run build    # type-checks, then outputs static files to dist/
npm run preview  # serve the production build locally
```

## Deployment (GitHub Pages)

Every push to `main` is built and published to GitHub Pages automatically by
[`.github/workflows/deploy.yml`](.github/workflows/deploy.yml):

1. `npm ci` + `npm run build` produce `dist/`.
2. `dist/` is uploaded as a Pages artifact and deployed.

Pages is configured with **Source = GitHub Actions** (no `gh-pages` branch).
The build is path-portable: fonts are imported so Vite fingerprints them, and
runtime assets (the soundtrack) resolve through `import.meta.env.BASE_URL`, so it
works from the `/MotorsagArkitekt/` project subpath as well as the domain root.

To deploy manually, run the workflow from the **Actions** tab
(`workflow_dispatch`).

## Project layout

```text
src/
  core/      engine: audio clock + analysis, compositor, director, timeline
  effects/   the visual layers (plasma, copper, tunnel, ships, scroller, …)
  post/      CRT post-processing pass
  sprites/   procedural pixel-art (chainsaw cats, architect horses, ships)
  text/      font loading + canvas text rasterization
  scenes/    timeline.ts — the data-driven show script (tweak the demo here)
public/assets/  music.mp3
```

The whole show is driven by the audio playback clock, so visuals never drift
from the music. To re-time or re-stage the demo, edit `src/scenes/timeline.ts`.
