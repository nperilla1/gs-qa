---
name: frontend-testing
description: "Write frontend E2E tests using Playwright. Includes Page Object Model pattern, accessible selectors, multi-browser testing, and visual regression. Use when asked to 'write E2E tests', 'test frontend', 'playwright tests', 'test UI', 'write browser tests', or 'end to end testing'."
allowed-tools: Read, Grep, Glob, Write, Bash
---

# Frontend Testing

You are writing frontend E2E tests using Playwright. Follow these patterns to produce reliable, maintainable browser tests.

## Target
$ARGUMENTS
(If no specific target, write tests for the routes specified in test-plan.json)

## Pre-Flight Checks

Before writing any tests:

1. **Check Playwright is installed**:
   ```bash
   npx playwright --version 2>/dev/null || echo "Playwright not installed"
   ```

2. **Read existing Playwright config**:
   ```bash
   cat playwright.config.ts 2>/dev/null || cat playwright.config.js 2>/dev/null || echo "No config found"
   ```

3. **Read existing tests** to match conventions:
   ```bash
   find . -name "*.spec.ts" -o -name "*.test.ts" | grep -v node_modules | head -10
   ```

4. **Find all routes/pages** to understand what can be tested:
   ```bash
   # Next.js
   find . -path "*/app/*/page.*" -o -path "*/pages/*.tsx" | grep -v node_modules

   # React Router
   grep -rn "Route.*path=" --include="*.tsx" --include="*.jsx" .

   # Vue Router
   grep -rn "path:" --include="*.ts" --include="*.js" . | grep -i route
   ```

## Page Object Model (POM)

Every page under test gets a Page Object. This separates test logic from page interaction details.

### Page Object Structure

```typescript
// pages/login.page.ts
import { type Page, type Locator, expect } from '@playwright/test';

export class LoginPage {
  readonly page: Page;
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly submitButton: Locator;
  readonly errorMessage: Locator;

  constructor(page: Page) {
    this.page = page;
    // Use accessible selectors
    this.emailInput = page.getByLabel('Email');
    this.passwordInput = page.getByLabel('Password');
    this.submitButton = page.getByRole('button', { name: 'Sign in' });
    this.errorMessage = page.getByRole('alert');
  }

  async goto() {
    await this.page.goto('/login');
  }

  async login(email: string, password: string) {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.submitButton.click();
  }

  async expectError(message: string) {
    await expect(this.errorMessage).toContainText(message);
  }

  async expectLoggedIn() {
    await expect(this.page).toHaveURL(/.*dashboard/);
  }
}
```

### File Layout

```
tests/
├── e2e/
│   ├── pages/               # Page Objects
│   │   ├── login.page.ts
│   │   ├── dashboard.page.ts
│   │   └── settings.page.ts
│   ├── fixtures/             # Custom fixtures
│   │   └── test-fixtures.ts
│   ├── auth.spec.ts          # Test specs
│   ├── dashboard.spec.ts
│   └── settings.spec.ts
├── playwright.config.ts
```

## Selector Strategy

Use accessible selectors in this priority order:

1. **`getByRole`** — best, matches how users interact:
   ```typescript
   page.getByRole('button', { name: 'Submit' })
   page.getByRole('heading', { name: 'Dashboard' })
   page.getByRole('link', { name: 'Settings' })
   page.getByRole('textbox', { name: 'Search' })
   page.getByRole('checkbox', { name: 'Remember me' })
   ```

2. **`getByLabel`** — for form inputs:
   ```typescript
   page.getByLabel('Email address')
   page.getByLabel('Password')
   ```

3. **`getByText`** — for text content:
   ```typescript
   page.getByText('Welcome back')
   page.getByText(/\d+ results found/)
   ```

4. **`getByPlaceholder`** — when no label exists:
   ```typescript
   page.getByPlaceholder('Search...')
   ```

5. **`getByTestId`** — last resort, for complex components:
   ```typescript
   page.getByTestId('user-avatar')
   ```

AVOID: CSS selectors, XPath, class names. These break when UI is restyled.

## Test Patterns

### Basic Page Test

```typescript
import { test, expect } from '@playwright/test';
import { LoginPage } from './pages/login.page';

test.describe('Login Page', () => {
  test('should display login form', async ({ page }) => {
    const loginPage = new LoginPage(page);
    await loginPage.goto();

    await expect(loginPage.emailInput).toBeVisible();
    await expect(loginPage.passwordInput).toBeVisible();
    await expect(loginPage.submitButton).toBeVisible();
  });

  test('should login with valid credentials', async ({ page }) => {
    const loginPage = new LoginPage(page);
    await loginPage.goto();
    await loginPage.login('user@test.com', 'password123');
    await loginPage.expectLoggedIn();
  });

  test('should show error for invalid credentials', async ({ page }) => {
    const loginPage = new LoginPage(page);
    await loginPage.goto();
    await loginPage.login('user@test.com', 'wrong');
    await loginPage.expectError('Invalid credentials');
  });
});
```

### Form Interaction Testing

```typescript
test('should validate required fields', async ({ page }) => {
  await page.goto('/create');

  // Submit without filling anything
  await page.getByRole('button', { name: 'Create' }).click();

  // Check validation messages
  await expect(page.getByText('Name is required')).toBeVisible();
  await expect(page.getByText('Email is required')).toBeVisible();
});

test('should submit form with valid data', async ({ page }) => {
  await page.goto('/create');

  await page.getByLabel('Name').fill('Test User');
  await page.getByLabel('Email').fill('test@example.com');
  await page.getByRole('combobox', { name: 'Role' }).selectOption('admin');
  await page.getByRole('checkbox', { name: 'Active' }).check();

  await page.getByRole('button', { name: 'Create' }).click();

  // Verify success
  await expect(page.getByText('Created successfully')).toBeVisible();
});
```

### Navigation Testing

```typescript
test('should navigate between pages', async ({ page }) => {
  await page.goto('/');

  await page.getByRole('link', { name: 'Dashboard' }).click();
  await expect(page).toHaveURL('/dashboard');
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();

  await page.getByRole('link', { name: 'Settings' }).click();
  await expect(page).toHaveURL('/settings');
});
```

### Wait Strategies

```typescript
// Wait for element
await expect(page.getByRole('table')).toBeVisible({ timeout: 10000 });

// Wait for network response
await page.waitForResponse(resp =>
  resp.url().includes('/api/data') && resp.status() === 200
);

// Wait for navigation
await Promise.all([
  page.waitForURL('/dashboard'),
  page.getByRole('button', { name: 'Go' }).click(),
]);

// Wait for loading to finish
await expect(page.getByText('Loading...')).toBeHidden();
```

### Error State Testing

```typescript
test('should show error page on 500', async ({ page }) => {
  // Intercept API call and return error
  await page.route('/api/data', route =>
    route.fulfill({ status: 500, body: 'Internal Server Error' })
  );

  await page.goto('/dashboard');
  await expect(page.getByText('Something went wrong')).toBeVisible();
  await expect(page.getByRole('button', { name: 'Retry' })).toBeVisible();
});

test('should handle network failure', async ({ page }) => {
  await page.route('/api/data', route => route.abort());
  await page.goto('/dashboard');
  await expect(page.getByText('Network error')).toBeVisible();
});
```

## Multi-Viewport Testing

```typescript
// In playwright.config.ts
projects: [
  { name: 'desktop', use: { viewport: { width: 1280, height: 720 } } },
  { name: 'tablet', use: { viewport: { width: 768, height: 1024 } } },
  { name: 'mobile', use: { viewport: { width: 375, height: 667 } } },
]

// In tests — viewport-specific behavior
test('should show mobile menu on small screens', async ({ page, isMobile }) => {
  await page.goto('/');
  if (isMobile) {
    await expect(page.getByRole('button', { name: 'Menu' })).toBeVisible();
    await expect(page.getByRole('navigation')).toBeHidden();
  } else {
    await expect(page.getByRole('navigation')).toBeVisible();
  }
});
```

## Screenshot Comparison

```typescript
test('should match visual baseline', async ({ page }) => {
  await page.goto('/dashboard');

  // Full page screenshot
  await expect(page).toHaveScreenshot('dashboard.png', {
    maxDiffPixelRatio: 0.01,
  });

  // Component screenshot
  const chart = page.getByTestId('revenue-chart');
  await expect(chart).toHaveScreenshot('revenue-chart.png');
});
```

## Authentication Fixtures

```typescript
// fixtures/test-fixtures.ts
import { test as base } from '@playwright/test';

type Fixtures = {
  authenticatedPage: Page;
};

export const test = base.extend<Fixtures>({
  authenticatedPage: async ({ page }, use) => {
    // Login via API (faster than UI login)
    const response = await page.request.post('/api/auth/login', {
      data: { email: 'test@test.com', password: 'test' }
    });
    const { token } = await response.json();

    // Set auth cookie/header
    await page.context().addCookies([{
      name: 'auth_token',
      value: token,
      domain: 'localhost',
      path: '/',
    }]);

    await use(page);
  },
});
```

## Test Quality Checklist

- [ ] Uses Page Object Model for page interactions
- [ ] Uses accessible selectors (getByRole, getByLabel, getByText)
- [ ] No CSS selector or XPath selectors
- [ ] No hardcoded wait times (use proper wait strategies)
- [ ] Tests are independent (each test starts from a clean state)
- [ ] Error states are tested (500, network failure, validation errors)
- [ ] Forms are tested for both valid and invalid submissions
- [ ] Navigation is verified (URL changes, heading updates)
- [ ] Multi-viewport scenarios are considered

## Rules

- Use Page Objects for any page tested more than once
- Use accessible selectors — never use CSS classes or XPath
- Do not use `page.waitForTimeout()` — use proper wait strategies
- Each test should start from a known state (use `beforeEach` for navigation)
- Test user-visible behavior, not implementation details
- Mock API responses for error state testing
- Keep tests fast — use API login instead of UI login where possible
- Name test files: `<feature>.spec.ts`
