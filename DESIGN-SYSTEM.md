# Design System — McKenzie Carlile

## Quick start

To change any visual token on the site, open `/admin` in a browser after running the dev server. Edit the tokens, click **Copy CSS**, and paste the `:root {}` block at the top of `assets/style.css`.

---

## Token architecture

Tokens follow a two-tier system:

| Tier | Prefix | Purpose |
|---|---|---|
| **Reference** | `--ref-*` | Raw primitives — the specific color hex, exact pixel value, or font string. Never used directly in component CSS. |
| **System** | `--color-*`, `--font-*`, `--space-*`, `--radius-*` | Semantic aliases that point to reference tokens. These are what component CSS uses. |

### Why two tiers?

If you want to make the body text slightly lighter, you change `--color-text-primary` to point to a different `--ref-gray-*` value — one change, every component picks it up. If you want to shift the whole neutral palette slightly warmer, you change the reference hex values. The system tier stays the same.

---

## Fonts

### EB Garamond (loaded)
Used for all display text, headings, italicized titles, and the nav logo.
- **Google Fonts**: https://fonts.google.com/specimen/EB+Garamond
- **Usage**: `font-family: var(--font-serif)`
- **Weights in use**: 400 (regular), 400 italic, 500, 500 italic

### Geist (loaded)
Used for all body copy, labels, nav links, and metadata.
- **Vercel Geist**: https://vercel.com/font
- **Google Fonts mirror**: https://fonts.google.com/specimen/Geist
- **Usage**: `font-family: var(--font-sans)`
- **Weights in use**: 300, 400, 500

### Swapping fonts

1. Open `index.html` (and all other pages) and update the Google Fonts `<link>` in `<head>` to load your new font family.
2. In `assets/style.css`, update `--ref-font-serif` or `--ref-font-sans` in `:root`.
3. All components inherit the change automatically.

To use a locally installed font (e.g. Geograph from your Mac's font library), add a `@font-face` declaration in `assets/style.css` before `:root`:

```css
@font-face {
  font-family: 'Geograph';
  src: local('Geograph'), url('../assets/fonts/Geograph-Regular.woff2') format('woff2');
  font-weight: 400;
  font-style: normal;
}
```

Then update `--ref-font-sans` to `'Geograph', system-ui, sans-serif`.

---

## Colors

All colors live in `assets/style.css` inside `:root`. Reference values are plain hex; system values use `var(--ref-*)` aliases.

### Editing colors

**Option A — Admin UI**: Open `/admin`, use the color pickers, copy the generated CSS.

**Option B — Direct edit**: Change hex values in the `--ref-*` block at the top of `assets/style.css`.

### Adding a new color

1. Add a new `--ref-color-name: #hex;` primitive in the Reference Colors section.
2. Add or update a `--color-semantic-name: var(--ref-color-name);` system token.
3. Use `var(--color-semantic-name)` in your component CSS.

---

## Spacing & layout

Spacing uses an 8-point base scale (`--ref-size-8` through `--ref-size-88`). Page padding, section gaps, and grid gutters all reference these primitives through system tokens:

| Token | Default | Used for |
|---|---|---|
| `--space-page` | 16px | Body padding (edge-to-edge margin) |
| `--space-section` | 80px | Vertical space between page sections |
| `--space-gap` | 8px | Grid and thumbnail gutters |

---

## Deployment

### Vercel (current)

This is a static HTML site deployed via Vercel. No build step for the site itself — `package.json` exists only so Vercel can `npm install` the one dependency (`@vercel/functions`) that `middleware.js` needs.

1. Push to GitHub: `git push`
2. Vercel auto-deploys on every push to `main`
3. `vercel.json` sets `cleanUrls: true` so `/field-reports` works without `.html`

**Vercel docs**: https://vercel.com/docs/frameworks/html  
**Custom domains**: https://vercel.com/docs/projects/domains  
**Environment variables** (if needed later): https://vercel.com/docs/projects/environment-variables

### Subdomain: shop.mckenziecarlile.com

The listing page lives at `/shop` in this same repo and project — no separate Vercel project needed. It's a standalone camper-for-sale poster page with its own look (Archivo Black + DM Mono, paper/ink/sale-green palette in `shop/style.css`) rather than the main site's design tokens, and its nav only links back to `mckenziecarlile.com`. Routing is handled by `middleware.js` (Vercel Routing Middleware), which checks the request's `Host` header and rewrites `shop.mckenziecarlile.com/` to `/shop` while every other host keeps serving the homepage normally.

> Note: a plain `vercel.json` rewrite with `"has": [{ "type": "host", ... }]` looks like it should do this, but that condition isn't reliably supported outside Next.js — it silently no-ops. Routing Middleware (a `middleware.js` file at the project root) is the supported way to branch on hostname for any project type. It requires the `@vercel/functions` package (see `package.json`) for the `rewrite()` helper, and `"type": "module"` in `package.json` so Vercel treats `middleware.js` as ESM.

To go live, two things need to happen outside this repo:

1. **Vercel dashboard** → this project → Settings → Domains → add `shop.mckenziecarlile.com`.
2. **DNS** (wherever `mckenziecarlile.com` is registered) → add the CNAME record Vercel shows you (typically `shop` → `cname.vercel-dns.com`, though Vercel may show a per-domain value instead — use whatever it actually displays).

Once DNS propagates, `shop.mckenziecarlile.com` resolves to this project and the middleware rewrites `/` to `/shop`. `mckenziecarlile.vercel.app/shop` (the project's default Vercel domain) also works directly, which is useful for previewing before DNS is set up — the apex `mckenziecarlile.com` currently points elsewhere (see below), so `mckenziecarlile.com/shop/` won't work as a preview.

### First deploy (one time)

```bash
npm i -g vercel
vercel login
vercel --prod
```

---

## Adding content

### New field report

1. Create a new directory: `field-reports/your-slug/`
2. Copy `field-reports/miter-basin/index.html` into it
3. Update the title, hero image `src`, date, and body copy
4. Add a card for it in `field-reports/index.html` (copy an existing `.report-card` block)
5. Add a thumbnail to the homepage `field-grid` in `index.html`
6. Add your images to `assets/images/`

### New design work case study (future)

If you want internal case study pages instead of external links:
1. Create `design-work/your-slug/index.html`
2. Use the same nav/footer shell as the field report pages
3. Update the `href` on the matching `.work-item` in `index.html`

---

## File structure

```
mckenziecarlile/
├── index.html                        Homepage
├── contact/index.html                Contact page
├── shop/
│   ├── index.html                    1987 Pilgrim 7330 listing (shop.mckenziecarlile.com)
│   └── style.css                     Standalone poster-style sheet, not part of the main token system
├── field-reports/
│   ├── index.html                    Field reports index
│   ├── ne-couloir-mt-langley/        Field report detail
│   ├── south-fork-flathead/
│   └── miter-basin/
├── admin/index.html                  Token admin UI
├── assets/
│   ├── style.css                     All styles + token system (used by every page except /shop)
│   └── images/                       Hero, report, and shop listing photos
├── middleware.js                     Host-based routing for shop.mckenziecarlile.com
├── package.json                      Declares @vercel/functions for middleware.js
├── vercel.json                       Vercel routing config
└── DESIGN-SYSTEM.md                  This file
```

---

## Resources

| Resource | URL |
|---|---|
| Vercel static site docs | https://vercel.com/docs/frameworks/html |
| EB Garamond on Google Fonts | https://fonts.google.com/specimen/EB+Garamond |
| Geist font | https://vercel.com/font |
| MDN CSS custom properties | https://developer.mozilla.org/en-US/docs/Web/CSS/Using_CSS_custom_properties |
| MDN CSS clamp() | https://developer.mozilla.org/en-US/docs/Web/CSS/clamp |
| MDN CSS grid | https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_grid_layout |
| Utopia type scale tool | https://utopia.fyi |
| Reasonable colors palette | https://reasonable.work/colors |
