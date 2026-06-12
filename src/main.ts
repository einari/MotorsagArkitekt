import { Audio } from './core/Audio';
import { Demo } from './core/Demo';
import { loadFonts } from './text/fonts';

/**
 * Boot sequence:
 *   1. preload the embedded fonts and stream/decode the soundtrack
 *   2. wait for a user click (browsers require a gesture to start audio)
 *   3. unlock the audio context, hide the boot screen, and run the demo
 */
async function boot(): Promise<void> {
  const canvas = document.getElementById('gl') as HTMLCanvasElement;
  const bootEl = document.getElementById('boot') as HTMLDivElement;
  const action = document.getElementById('bootAction') as HTMLDivElement;

  const audio = new Audio();

  const tasks = Promise.all([
    loadFonts(),
    audio.load((p) => {
      action.textContent = `loading music… ${Math.round(p * 100)}%`;
    }),
  ]);

  await tasks;

  // Ready — invite the user to start.
  action.textContent = '▶ CLICK TO START ◀';
  action.className = 'boot-start';

  const startDemo = async (): Promise<void> => {
    bootEl.removeEventListener('click', startDemo);
    window.removeEventListener('keydown', onKey);
    await audio.unlock();
    bootEl.classList.add('hidden');
    const demo = new Demo(canvas, audio);
    demo.start();
  };
  const onKey = (e: KeyboardEvent): void => {
    if (e.key === 'Enter' || e.key === ' ') void startDemo();
  };

  bootEl.addEventListener('click', startDemo);
  window.addEventListener('keydown', onKey);
}

boot().catch((err) => {
  console.error('Boot failed:', err);
  const action = document.getElementById('bootAction');
  if (action) action.textContent = 'failed to load — check console';
});
