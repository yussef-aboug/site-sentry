# Site Sentry — Website Care Plans landing page

A conversion-focused landing page for selling website maintenance / care plans to
small businesses. It ships as a **single self-contained `index.html`** — fonts, CSS,
and JavaScript are all inlined, so there are **zero external requests** at runtime.
Drop it on any host (GitHub Pages, Netlify, a plain web server) and it just works.

**Design concept — "The Night Watch":** the page opens in deep-night indigo (the
service quietly watching over your site while you sleep), warms to daylight paper for
the problem, process, and pricing, then returns to night for the guarantee and close.
A single amber "lamplight" accent carries every call to action. Green is reserved for
"protected / all-clear" states; red appears only beside the risk statistics.
Typeset in Fraunces (display) and Public Sans (body), both embedded.

## Quick start

Just open `index.html` in a browser, or deploy it — no build required to view it.

To rebuild after editing the source:

```bash
npm install        # one-time, for the optional verify step
npm run build      # regenerates index.html from src/
```

## Customize before you launch

Everything you need to change is marked on the page with a **dashed amber underline**.

1. **Replace the placeholders** (in `src/markup.html`, then rebuild):
   `[Business Name]`, the build price `[1,495]`, `[hello@yourbusiness.com]`,
   `[Your Area]`, the two testimonial slots, and the trust-badge numbers.
2. **Wire up the form:** search `src/markup.html` for `YOUR-FORM-ID` and paste your
   [Formspree](https://formspree.io) / [Basin](https://usebasin.com) / Netlify Forms
   endpoint, or swap the `<form>` for your provider's embed. Until then, the form
   shows a friendly "not connected yet" message instead of failing.
3. **Point the plan buttons** at payment or booking links when ready. By default they
   scroll to the health-check form and pre-fill the plan name.
4. **Delete the "Template note"** in the Client stories section once you add real
   testimonials.

The full marketing copy — plus notes on which claims to verify before publishing —
lives in [`docs/landing-copy.md`](docs/landing-copy.md).

## Project layout

```
index.html            Built, deployable page (generated — do not hand-edit long-term)
src/
  markup.html         Page structure and copy  ← edit here
  styles.css          Design system and all styling  ← edit here
  script.js           Scroll reveals, FAQ accordion, form guard  ← edit here
  fonts.css           Fraunces + Public Sans as base64 data URIs (generated)
tools/
  assemble.mjs        Inlines src/ into index.html   (npm run build)
  fetch-fonts.mjs     Re-downloads & embeds the fonts (npm run fonts)
  verify.mjs          Checks overflow + JS errors at 390px and 1440px (npm run verify)
docs/
  landing-copy.md     Source marketing copy + pre-launch checklist
```

Edit the files in `src/` and run `npm run build`; don't rely on hand-edits to
`index.html`, since the next build overwrites it.

## Deploy to GitHub Pages

Because `index.html` sits at the repo root, GitHub Pages needs no configuration:
in the repo settings, enable **Pages → Deploy from a branch → `main` / root**, and
the site goes live at `https://<user>.github.io/site-sentry/`.

## Accessibility & responsiveness

Semantic landmarks and headings, visible keyboard focus, `prefers-reduced-motion`
honored (all animation and smooth-scroll disabled), light/dark-friendly deep palette,
and verified free of horizontal overflow on mobile and desktop. The one hard-coded
external touchpoint is the form endpoint, which you supply.
