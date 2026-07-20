// Regenerates src/fonts.css by downloading the webfonts and embedding them as
// base64 data URIs. Run this only when changing typefaces — src/fonts.css is
// committed, so the normal build needs no network access.
//   node tools/fetch-fonts.mjs
import { execSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const outFile = path.join(root, 'src/fonts.css');

const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';
const cssUrl =
  'https://fonts.googleapis.com/css2?family=Fraunces:ital,wght@0,600;1,500&family=Public+Sans:wght@400;600&display=swap';

const css = execSync(`curl -sS -A "${UA}" "${cssUrl}"`, { maxBuffer: 10 * 1024 * 1024 }).toString();
const re = /\/\*\s*([a-z0-9-]+)\s*\*\/\s*@font-face\s*\{([^}]+)\}/g;

let out = '';
let count = 0;
let m;
while ((m = re.exec(css))) {
  if (m[1] !== 'latin') continue;
  const body = m[2];
  const fam = /font-family:\s*'([^']+)'/.exec(body)[1];
  const style = /font-style:\s*(\w+)/.exec(body)[1];
  const weight = /font-weight:\s*(\d+)/.exec(body)[1];
  const url = /url\((https:[^)]+)\)/.exec(body)[1];
  const buf = execSync(`curl -sS "${url}"`, { maxBuffer: 10 * 1024 * 1024 });
  if (buf.length < 5000) throw new Error(`suspiciously small font: ${fam} ${style} ${weight} (${buf.length}B)`);
  out += `@font-face{font-family:'${fam}';font-style:${style};font-weight:${weight};font-display:swap;src:url(data:font/woff2;base64,${buf.toString('base64')}) format('woff2');}\n`;
  console.log(`${fam} ${style} ${weight}: ${(buf.length / 1024).toFixed(1)} KB`);
  count++;
}
if (count !== 4) throw new Error(`expected 4 latin faces, got ${count}`);
fs.writeFileSync(outFile, out);
console.log(`wrote ${outFile} (${(fs.statSync(outFile).size / 1024).toFixed(1)} KB)`);
