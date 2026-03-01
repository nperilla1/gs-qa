---
name: visual-testing
description: "Screenshot-based visual regression testing. Captures screenshots of all frontend pages at multiple viewports, compares against baselines, and reports visual diffs using Claude's vision capabilities. Use when asked to 'visual test', 'screenshot test', 'visual regression', 'baseline screenshots', 'check UI appearance', 'does the UI look right', or 'visual QA'."
allowed-tools: Read, Grep, Glob, Write, Bash
---

# Visual Testing

You are performing visual regression testing by capturing screenshots of frontend pages and comparing them against baselines. This catches visual bugs that functional tests miss: layout shifts, missing elements, broken styles, and rendering issues.

## Target
$ARGUMENTS
(If no specific target, capture screenshots of all discoverable frontend routes)

## Phase 1: Discover Frontend Routes

Find all testable routes in the frontend:

### Next.js (App Router)
```bash
find . -path "*/app/*/page.*" | grep -v node_modules | sed 's|.*/app||; s|/page\.\(tsx\|ts\|jsx\|js\)$||' | sort
```

### Next.js (Pages Router)
```bash
find . -path "*/pages/*" -name "*.tsx" | grep -v node_modules | grep -v "_app\|_document\|_error\|api/" | sed 's|.*/pages||; s|\.tsx$||' | sort
```

### React Router
```bash
grep -rn "path=" --include="*.tsx" --include="*.jsx" . | grep -i route | grep -oP 'path="[^"]*"' | sort -u
```

### Vue Router
```bash
grep -rn "path:" --include="*.ts" --include="*.js" . | grep -i route | grep -oP "path:\s*'[^']*'" | sort -u
```

Build a route list:
```
/
/login
/dashboard
/settings
/items
/items/:id
```

## Phase 2: Start Dev Server

Check if the dev server is already running:
```bash
lsof -i :3000 2>/dev/null || lsof -i :5173 2>/dev/null || lsof -i :8080 2>/dev/null
```

If not running:
```bash
# Detect and start
if [ -f "package.json" ]; then
  npm run dev &
  DEV_PID=$!
  sleep 5
  echo "Dev server started on PID $DEV_PID"
fi
```

Verify the server is responsive:
```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000
```

## Phase 3: Configure Viewports

Test at these standard viewports:

| Name | Width | Height | Represents |
|------|-------|--------|-----------|
| mobile | 375 | 667 | iPhone SE |
| tablet | 768 | 1024 | iPad |
| desktop | 1280 | 720 | Laptop |
| wide | 1920 | 1080 | Desktop monitor |

## Phase 4: Capture Screenshots

Use Playwright to capture screenshots of each route at each viewport.

### Setup Script

```bash
# Ensure Playwright is available
npx playwright --version 2>/dev/null || npm install @playwright/test
npx playwright install chromium 2>/dev/null
```

### Capture Script

Create a temporary Playwright script for screenshot capture:

```typescript
// /tmp/visual-capture.spec.ts
import { test } from '@playwright/test';

const routes = [
  { path: '/', name: 'home' },
  { path: '/login', name: 'login' },
  { path: '/dashboard', name: 'dashboard' },
  // ... discovered routes
];

const viewports = [
  { name: 'mobile', width: 375, height: 667 },
  { name: 'tablet', width: 768, height: 1024 },
  { name: 'desktop', width: 1280, height: 720 },
];

for (const route of routes) {
  for (const viewport of viewports) {
    test(`${route.name} at ${viewport.name}`, async ({ page }) => {
      await page.setViewportSize({ width: viewport.width, height: viewport.height });
      await page.goto(`http://localhost:3000${route.path}`);

      // Wait for content to load
      await page.waitForLoadState('networkidle');

      // Hide dynamic content (timestamps, animations)
      await page.evaluate(() => {
        document.querySelectorAll('[data-testid="timestamp"], .animate-pulse, .animate-spin')
          .forEach(el => (el as HTMLElement).style.visibility = 'hidden');
      });

      await page.screenshot({
        path: `screenshots/${route.name}-${viewport.name}.png`,
        fullPage: true,
      });
    });
  }
}
```

Run the capture:
```bash
mkdir -p screenshots
npx playwright test /tmp/visual-capture.spec.ts --reporter=list 2>&1
```

## Phase 5: Baseline Management

### First Run (Create Baselines)
```bash
# Move screenshots to baseline directory
mkdir -p screenshots/baseline
cp screenshots/*.png screenshots/baseline/
echo "Baselines created: $(ls screenshots/baseline/ | wc -l) screenshots"
```

### Subsequent Runs (Compare Against Baselines)

Use Playwright's built-in snapshot comparison:

```typescript
test('visual regression check', async ({ page }) => {
  await page.goto('/dashboard');
  await page.waitForLoadState('networkidle');
  await expect(page).toHaveScreenshot('dashboard-desktop.png', {
    maxDiffPixelRatio: 0.01,  // Allow 1% pixel difference
    threshold: 0.2,           // Color difference threshold
  });
});
```

Or use manual comparison by reading both images and asking Claude to compare:

```bash
# List baseline and current screenshots
ls -la screenshots/baseline/
ls -la screenshots/
```

For each pair (baseline vs current), read both images and compare visually.

## Phase 6: Visual Analysis

For each screenshot, analyze for common visual issues:

### Layout Issues
- Elements overlapping
- Content overflowing containers
- Missing padding/margin
- Misaligned elements
- Broken flexbox/grid layouts

### Typography Issues
- Text truncated or overflowing
- Wrong font size or weight
- Poor contrast (text hard to read)
- Text overlapping other elements

### Responsive Issues
- Content not adapting to viewport
- Horizontal scrollbar on mobile
- Touch targets too small on mobile
- Navigation not collapsing on mobile

### State Issues
- Loading states stuck
- Error states not showing
- Empty states missing
- Active/selected states incorrect

### Accessibility Issues
- Missing focus indicators
- Insufficient color contrast
- Text too small (below 16px on mobile)
- Interactive elements without visible boundaries

## Phase 7: Report

Output a visual testing report:

```
## Visual Testing Report

### Summary
- Routes tested: N
- Viewports tested: N (mobile, tablet, desktop)
- Total screenshots: N
- Visual issues found: N

### Route Coverage
| Route | Mobile | Tablet | Desktop | Status |
|-------|--------|--------|---------|--------|
| / | OK | OK | OK | PASS |
| /login | ISSUE | OK | OK | WARN |
| /dashboard | OK | ISSUE | OK | WARN |

### Issues Found
1. [HIGH] /login (mobile) — Login button overflows container at 375px width
   - Screenshot: screenshots/login-mobile.png
   - Expected: Button fits within form container
   - Actual: Button extends 20px beyond right edge

2. [MEDIUM] /dashboard (tablet) — Sidebar overlaps main content
   - Screenshot: screenshots/dashboard-tablet.png
   - Expected: Sidebar collapses or sits beside content
   - Actual: Sidebar and content overlap at 768px

### Baseline Updates Needed
- screenshots/baseline/home-desktop.png — intentional redesign, update baseline
```

## Cleanup

```bash
# Stop dev server if we started it
kill $DEV_PID 2>/dev/null

# Clean up temp files
rm -f /tmp/visual-capture.spec.ts
```

## Rules

- Always wait for `networkidle` before capturing screenshots
- Hide dynamic content (timestamps, loading spinners, animations) before capture
- Use `fullPage: true` to capture entire page, not just viewport
- Compare at pixel level with reasonable tolerance (1% diff ratio)
- Report issues with specific viewport and route
- Do not modify application code during visual testing
- Save baselines separately from current screenshots
- When updating baselines, explain why each update is intentional
