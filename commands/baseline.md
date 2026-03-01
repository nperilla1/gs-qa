---
name: qa:baseline
description: "Create or update visual test baselines by screenshotting all frontend pages."
---

# /qa:baseline -- Visual Test Baseline Manager

You are creating or updating visual test baselines for the frontend.

## Pre-Flight

### Step 1: Detect Frontend

Look for frontend indicators:
- `package.json` with React, Next.js, Vue, or Svelte dependencies
- `src/` or `app/` directories with `.tsx`, `.jsx`, `.vue`, `.svelte` files
- A `vite.config.*`, `next.config.*`, or similar framework config

If no frontend is detected:
```
No frontend detected in this project. Visual baselines require a web frontend.
Skipping visual testing.
```

### Step 2: Route Discovery

Discover all pages/routes to screenshot:
- **Next.js**: Scan `app/` or `pages/` directory for page files
- **React Router**: Search for `<Route` components or route config
- **Static pages**: Look for HTML entry points

### Step 3: Start Dev Server

Check if a dev server is already running:
```bash
lsof -i :3000 2>/dev/null || lsof -i :5173 2>/dev/null
```

If not running, start it:
```bash
npm run dev &
# or: yarn dev &
# or: pnpm dev &
```

Wait for the server to be ready (check health endpoint or poll the port).

## Baseline Capture

### Step 4: Screenshot Each Route

For each discovered route:
1. Navigate to the page using Playwright
2. Wait for network idle
3. Take a full-page screenshot
4. Save to `visual-baselines/[route-name].png`

Capture at two viewports:
- Desktop: 1280x720
- Mobile: 375x812

### Step 5: Save Baseline Manifest

Write `visual-baselines/manifest.json`:
```json
{
  "generated_at": "ISO-timestamp",
  "viewport_desktop": "1280x720",
  "viewport_mobile": "375x812",
  "pages": [
    {
      "route": "/",
      "name": "home",
      "desktop": "home-desktop.png",
      "mobile": "home-mobile.png"
    }
  ]
}
```

### Step 6: Report

```
VISUAL BASELINES CREATED
========================
Pages captured: X
Viewports: desktop (1280x720), mobile (375x812)
Total screenshots: X
Saved to: visual-baselines/

Baselines:
  / (home)           -- desktop + mobile
  /dashboard         -- desktop + mobile
  ...

Run /qa:sweep to compare against these baselines.
```

## Updating Baselines

If `visual-baselines/` already exists:
1. Ask the user: "Baselines already exist. Overwrite all, or update specific pages?"
2. If overwriting, back up existing baselines to `visual-baselines/backup-[timestamp]/`
3. Recapture all pages
4. Show a diff summary (which pages changed)

## Rules

- Always capture at both desktop and mobile viewports
- Wait for all network requests to complete before screenshotting
- Hide dynamic content (timestamps, random IDs) if possible
- Stop the dev server if this command started it
- If Playwright is not installed, install it first
