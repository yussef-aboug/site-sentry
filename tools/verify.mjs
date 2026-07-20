// Loads the built index.html at two viewports, checks for horizontal overflow
// and JS errors, and writes full-page screenshots to build/ (gitignored).
//   node tools/verify.mjs
// Requires a Chromium binary; set CHROMIUM_PATH or rely on the default below.
import { chromium } from 'playwright-core';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const url = 'file://' + path.join(root, 'index.html');
fs.mkdirSync(path.join(root, 'build'), { recursive: true });

const executablePath = process.env.CHROMIUM_PATH || '/opt/pw-browsers/chromium';
const browser = await chromium.launch({ executablePath, args: ['--no-sandbox'] });

for (const [name, vp] of [['mobile', { width: 390, height: 844 }], ['desktop', { width: 1440, height: 900 }]]) {
  const ctx = await browser.newContext({ viewport: vp, reducedMotion: 'reduce' });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  await page.goto(url, { waitUntil: 'load' });
  await page.waitForTimeout(600);
  const metrics = await page.evaluate(() => {
    const doc = document.documentElement;
    const over = [];
    document.querySelectorAll('*').forEach((el) => {
      const r = el.getBoundingClientRect();
      if (r.right > doc.clientWidth + 1 && r.width > 0) {
        const inScroller = el.closest('.math-wrap') !== null;
        if (!inScroller) over.push(el.tagName + '.' + String(el.className).split(' ')[0] + ' right=' + Math.round(r.right));
      }
    });
    return {
      viewportW: doc.clientWidth,
      scrollW: doc.scrollWidth,
      scrollH: doc.scrollHeight,
      overflowers: over.slice(0, 12),
    };
  });
  console.log(name, JSON.stringify(metrics, null, 1));
  console.log(name, 'js errors:', errors.length ? errors : 'none');
  await page.screenshot({ path: path.join(root, `build/pw-${name}.png`), fullPage: true });
  await ctx.close();
}
await browser.close();
console.log('screenshots written');
