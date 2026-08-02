#!/usr/bin/env node
/**
 * SiteSentry — turn a prospect scan into a client-ready health-check report.
 *
 *   bash scripts/prospect-scan.sh example.com > /tmp/scan.txt
 *   node scripts/make-report.mjs --scan /tmp/scan.txt \
 *        --site example.com --name "Sarah" --business "Sunrise Bakery" \
 *        --plan "Peace of Mind" --why "..." --concern "it went down last month" \
 *        --out reports/sunrise-bakery.html
 *
 * Produces ONE self-contained HTML file (no external requests, prints cleanly to
 * PDF from the browser). It is a DRAFT for the operator — never sent automatically.
 *
 * Optional --findings <file.json> replaces the parsed finding text with the
 * agent's reworded version, so wording can be softened without losing the
 * deterministic structure. Shape: {"urgent":[...],"advised":[...],"good":[...],
 * "unknown":[...]} — arrays of plain strings.
 */

import fs from 'node:fs';
import path from 'node:path';

/* ---------------------------------------------------------------- args ---- */
const args = {};
for (let i = 2; i < process.argv.length; i++) {
  const a = process.argv[i];
  if (a.startsWith('--')) args[a.slice(2)] = process.argv[i + 1]?.startsWith('--') ? true : process.argv[++i];
}
const need = (k) => { if (!args[k]) { console.error(`missing required --${k}`); process.exit(1); } return args[k]; };

const scanPath = need('scan');
const site     = need('site');
const outPath  = args.out || 'health-check.html';
const name     = args.name || '';
const business = args.business || site;
const planRec  = args.plan || '';
const planWhy  = args.why || '';
const concern  = args.concern || '';
const brand    = args.brand || 'SiteSentry';

const scan = fs.readFileSync(scanPath, 'utf8');

/* ------------------------------------------------------------- refuse ----- */
// Fail closed, exactly like the scanner. A report built from a scan that never
// reached the site would tell a stranger their site is fine on the strength of
// zero evidence. That is the one output this tool must never produce.
if (/SCAN ABORTED/.test(scan) || /Could not reach/.test(scan)) {
  console.error('REFUSING to build a report: the scan aborted — the site was never reached.');
  console.error('Nothing was checked, so there are no findings to report. Confirm the URL in a');
  console.error('browser and re-run the scan first.');
  process.exit(2);
}

/* -------------------------------------------------------------- parse ----- */
const findings = { urgent: [], advised: [], good: [], unknown: [] };
let scannedAt = '';
for (const raw of scan.split('\n')) {
  const line = raw.trim();
  const at = line.match(/^(\d{4}-\d{2}-\d{2} \d{2}:\d{2} UTC)/);
  if (at) scannedAt = at[1];
  const m = line.match(/^\[(FAIL|WARN|PASS|INFO)\]\s+(.*)$/);
  if (!m) continue;
  const [, level, text] = m;
  if (/^Could not check/i.test(text)) { findings.unknown.push(text.replace(/^Could not check\s*/i, '')); continue; }
  if (level === 'FAIL') findings.urgent.push(text);
  else if (level === 'WARN') findings.advised.push(text);
  else if (level === 'PASS') findings.good.push(text);
}

if (args.findings) {
  const o = JSON.parse(fs.readFileSync(args.findings, 'utf8'));
  for (const k of ['urgent', 'advised', 'good', 'unknown']) if (Array.isArray(o[k])) findings[k] = o[k];
}

/* --------------------------------------------------------------- copy ----- */
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const nU = findings.urgent.length, nA = findings.advised.length, nG = findings.good.length;

const verdict = nU > 0
  ? `We found ${nU === 1 ? 'one thing' : `${nU} things`} that ${nU === 1 ? 'needs' : 'need'} attention soon — plus ${nA} smaller improvement${nA === 1 ? '' : 's'} worth making.`
  : nA > 3
    ? `Nothing is broken today. Your site is working, but it's carrying more risk than it needs to — ${nA} improvements would meaningfully harden it.`
    : `Good news: your site is in decent shape. ${nA ? `Only ${nA} small improvement${nA === 1 ? '' : 's'} stood out.` : 'Nothing urgent stood out.'}`;

const dateStr = new Date().toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric' });

/* status palette — validated for this paper surface (#FFFDF9):
   lightness band PASS · chroma PASS · CVD separation PASS (worst ΔE 14.8 protan)
   · normal-vision floor PASS (24.6) · contrast ≥3:1 PASS.
   Colour NEVER carries meaning alone here — every status ships an icon + a word. */
const ST = { urgent: '#9B1C1C', advised: '#C28400', good: '#0F6B3D' };

const ICON = {
  urgent: '<path d="M12 4.6l8.6 14.9H3.4z"/><path d="M12 10.2v4"/><path d="M12 17.1v.02"/>',
  advised: '<circle cx="12" cy="12" r="8.4"/><path d="M12 8.2v4.4"/><path d="M12 15.6v.02"/>',
  good: '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
  unknown: '<circle cx="12" cy="12" r="8.4"/><path d="M9.6 9.6a2.5 2.5 0 114 2.2c-.9.6-1.6 1-1.6 2"/><path d="M12 16.6v.02"/>',
};
const icon = (k, size = 17) =>
  `<svg class="ic" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${ICON[k]}</svg>`;

const list = (items, kind, labelWord) => items.length ? `
      <ul class="findings ${kind}">
        ${items.map((t) => `<li><span class="mk" aria-hidden="true">${icon(kind)}</span><span class="sr">${labelWord}:</span> ${esc(t)}</li>`).join('\n        ')}
      </ul>` : '';

/* --------------------------------------------------------------- html ----- */
const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Website Health Check — ${esc(business)}</title>
<style>
  /* A printable client document: deliberately light-only, so what they read on
     screen and what comes out of the printer are the same page. */
  *, *::before, *::after { box-sizing: border-box; }
  body {
    margin: 0; background: #F2F0E9; color: #1D2534;
    font: 16px/1.62 ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    -webkit-font-smoothing: antialiased;
  }
  .sheet { max-width: 780px; margin: 32px auto; background: #FFFDF9; border: 1px solid #E1DCCD;
           border-radius: 16px; overflow: hidden; }
  .head { background: #0D1526; color: #EFEDE5; padding: 30px 40px 26px; }
  .brandline { display: flex; align-items: center; gap: 9px; font-weight: 600; font-size: .95rem; color: #E8A63C; }
  .head h1 { margin: 14px 0 6px; font-size: 1.72rem; line-height: 1.2; letter-spacing: -.01em; }
  .head .sub { margin: 0; color: #97A2B6; font-size: .95rem; }
  .head .sub b { color: #EFEDE5; font-weight: 600; }
  .body { padding: 32px 40px 40px; }

  h2 { font-size: 1.06rem; letter-spacing: .04em; text-transform: uppercase; color: #5A6373;
       margin: 34px 0 12px; padding-bottom: 8px; border-bottom: 1px solid #E1DCCD; }
  h2:first-of-type { margin-top: 8px; }
  p { margin: 0 0 14px; }
  .verdict { font-size: 1.12rem; line-height: 1.55; margin-bottom: 24px; }

  /* KPI row — three headline numbers. Per the form heuristic these are stat
     tiles, not a chart: a 3-bar chart of three counts adds nothing to read. */
  .kpis { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; margin: 0 0 8px; }
  .kpi { border: 1px solid #E1DCCD; border-radius: 12px; padding: 14px 16px; background: #FFFDF9; }
  .kpi .n { font-size: 1.9rem; font-weight: 700; line-height: 1.1; letter-spacing: -.02em; }
  .kpi .k { display: flex; align-items: center; gap: 6px; font-size: .78rem; font-weight: 600;
            text-transform: uppercase; letter-spacing: .05em; color: #5A6373; margin-top: 3px; }
  /* the tile's number wears ink, never the status hue — the icon+word carries state */
  .kpi.urgent  .k .ic { color: ${ST.urgent}; }
  .kpi.advised .k .ic { color: ${ST.advised}; }
  .kpi.good    .k .ic { color: ${ST.good}; }

  .findings { list-style: none; margin: 0 0 6px; padding: 0; }
  .findings li { position: relative; padding: 9px 0 9px 30px; border-bottom: 1px solid #EFEBE1; }
  .findings li:last-child { border-bottom: 0; }
  .mk { position: absolute; left: 0; top: 10px; display: inline-flex; }
  .findings.urgent  .mk { color: ${ST.urgent}; }
  .findings.advised .mk { color: ${ST.advised}; }
  .findings.good    .mk { color: ${ST.good}; }
  .findings.unknown .mk { color: #5A6373; }
  .sr { position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden;
        clip: rect(0 0 0 0); white-space: nowrap; border: 0; }

  .note { background: #F7F5EF; border: 1px solid #E1DCCD; border-radius: 12px; padding: 16px 18px; font-size: .94rem; color: #3A4353; }
  .rec { border: 2px solid #E8A63C; border-radius: 14px; padding: 20px 22px; background: #FFFBF2; }
  .rec .lbl { font-size: .78rem; font-weight: 700; letter-spacing: .06em; text-transform: uppercase; color: #8F6512; }
  .rec .plan { font-size: 1.4rem; font-weight: 700; margin: 4px 0 8px; }
  .foot { margin-top: 30px; padding-top: 18px; border-top: 1px solid #E1DCCD; font-size: .86rem; color: #5A6373; }

  @media (max-width: 620px) {
    .sheet { margin: 0; border-radius: 0; border-left: 0; border-right: 0; }
    .head, .body { padding-left: 22px; padding-right: 22px; }
    .kpis { grid-template-columns: 1fr; }
  }
  @media print {
    body { background: #fff; }
    .sheet { margin: 0; max-width: none; border: 0; border-radius: 0; }
    h2 { break-after: avoid; } .findings li, .rec, .note { break-inside: avoid; }
  }
</style>
</head>
<body>
<div class="sheet">
  <div class="head">
    <div class="brandline">
      <svg width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 3.2l7 2.8v5.1c0 4.6-2.9 8.2-7 9.7-4.1-1.5-7-5.1-7-9.7V6z"/><path d="M8.9 11.9l2.2 2.2 4-4"/></svg>
      ${esc(brand)}
    </div>
    <h1>Website Health Check</h1>
    <p class="sub"><b>${esc(business)}</b> · ${esc(site)} · ${esc(dateStr)}</p>
  </div>

  <div class="body">
    <p class="verdict">${name ? `${esc(name)}, h` : 'H'}ere's what we found when we looked at your website from the outside. ${esc(verdict)}</p>
${concern ? `
    <div class="note"><strong>You told us:</strong> “${esc(concern)}” — we looked at that first. See the notes below; if it isn't covered here, it's something we'd need inside access to diagnose properly.</div>
` : ''}
    <div class="kpis">
      <div class="kpi urgent"><div class="n">${nU}</div><div class="k">${icon('urgent', 14)} Needs attention</div></div>
      <div class="kpi advised"><div class="n">${nA}</div><div class="k">${icon('advised', 14)} Recommended</div></div>
      <div class="kpi good"><div class="n">${nG}</div><div class="k">${icon('good', 14)} Working well</div></div>
    </div>
${nG ? `
    <h2>What's working well</h2>
    <p>Credit where it's due — these are already in good shape:</p>
    ${list(findings.good, 'good', 'Working well')}
` : ''}
${nU ? `
    <h2>Needs attention now</h2>
    <p>These are the ones we'd fix first.</p>
    ${list(findings.urgent, 'urgent', 'Needs attention')}
` : ''}
${nA ? `
    <h2>Recommended improvements</h2>
    <p>Not emergencies — but each one closes a door that's currently open.</p>
    ${list(findings.advised, 'advised', 'Recommended')}
` : ''}
    <h2>What we couldn't see from outside</h2>
    <p>This check was done from the public internet, without logging in. That means some
    important things are genuinely unknown right now:</p>
    <ul class="findings unknown">
      <li><span class="mk" aria-hidden="true">${icon('unknown')}</span><span class="sr">Unknown:</span> Whether your backups exist — and more importantly, whether they actually restore.</li>
      <li><span class="mk" aria-hidden="true">${icon('unknown')}</span><span class="sr">Unknown:</span> Which updates are pending, and whether any are security fixes.</li>
      <li><span class="mk" aria-hidden="true">${icon('unknown')}</span><span class="sr">Unknown:</span> Whether anything malicious is already on the server.</li>
      <li><span class="mk" aria-hidden="true">${icon('unknown')}</span><span class="sr">Unknown:</span> The full plugin list, and whether any are abandoned by their developers.</li>
${findings.unknown.map((t) => `      <li><span class="mk" aria-hidden="true">${icon('unknown')}</span><span class="sr">Unknown:</span> ${esc(t)} — blocked from checking this remotely.</li>`).join('\n')}
    </ul>
    <p style="margin-top:12px">A full internal audit is the first thing we do when a site comes into our care.</p>
${planRec ? `
    <h2>What we'd recommend</h2>
    <div class="rec">
      <div class="lbl">Our honest recommendation</div>
      <div class="plan">${esc(planRec)}</div>
      ${planWhy ? `<p style="margin:0">${esc(planWhy)}</p>` : ''}
    </div>
` : ''}
    <div class="foot">
      Checked ${esc(scannedAt || dateStr)} from the public internet — read-only, with no changes made
      to your site and no login used. Prepared by ${esc(brand)}${name ? ` for ${esc(name)}` : ''}.
    </div>
  </div>
</div>
</body>
</html>
`;

fs.mkdirSync(path.dirname(path.resolve(outPath)), { recursive: true });
fs.writeFileSync(outPath, html);
console.log(`Report written: ${outPath}`);
console.log(`  ${nU} urgent · ${nA} recommended · ${nG} working well`);
console.log('  DRAFT — review it, then YOU send it. Never sent automatically.');
