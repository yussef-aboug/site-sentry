// Assembles src/ into a single self-contained index.html at the repo root.
// No external requests at runtime: fonts, CSS, and JS are all inlined.
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const read = (p) => fs.readFileSync(path.join(root, p), 'utf8');

const fonts = read('src/fonts.css');
const styles = read('src/styles.css');
const markup = read('src/markup.html');
const script = read('src/script.js');

const title = 'Website Care Plans — Your Website, Protected 24/7';
const description =
  'Security updates, nightly off-site backups, 24/7 monitoring, and same-day support for small business websites. Month-to-month care plans from $129 — so you never think about your website again.';

const howTo = `<!--
  SITE SENTRY — single-file landing page (no build step, no external requests).
  This file is GENERATED from /src by tools/assemble.mjs. Edit the source, not this
  file, then run \`npm run build\`. (Editing here directly is fine for a quick tweak,
  but the next build will overwrite it.)

  BEFORE LAUNCH
  1. Replace every bracketed placeholder (dashed amber underline on the page):
     [Business Name], [1,495], [hello@yourbusiness.com], [Your Area],
     the two testimonial slots, and the trust-badge numbers.
  2. WIRE THE FORM: search for "YOUR-FORM-ID" and paste your Formspree / Basin /
     Netlify Forms endpoint, or swap the <form> for your provider's embed.
  3. PLAN BUTTONS scroll to the health-check form and pre-fill the plan name.
     Point them at payment or booking links whenever you're ready.
  4. Delete the "Template note" block in the Client stories section.
-->`;

const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
<meta name="description" content="${description}">
<meta property="og:title" content="${title}">
<meta property="og:description" content="${description}">
<meta property="og:type" content="website">
<meta name="theme-color" content="#0D1526">
${howTo}
<style>
${fonts}
${styles}
</style>
</head>
<body>
${markup}
<script>
${script}
</script>
</body>
</html>
`;

fs.writeFileSync(path.join(root, 'index.html'), html);
const kb = (fs.statSync(path.join(root, 'index.html')).size / 1024).toFixed(1);
console.log(`built index.html (${kb} KB, zero external requests)`);
