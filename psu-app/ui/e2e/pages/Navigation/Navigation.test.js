const { test, expect } = require('../../_utils/BaseTestSetup');
const NavigationPageHelpers = require('./NavigationPageHelpers');
const { testConfig } = require('../../_utils/test-config');
const {
  backupAndClearAllDiscoveryRuns,
  restoreDiscoveryRuns,
  seedCompletedDiscoveryRunAt
} = require('../../_utils/cleanup');

test.describe('Navigation', () => {
  let navPage;

  test.beforeEach(async ({ ciemPage }) => {
    navPage = new NavigationPageHelpers(ciemPage);
    await navPage.navigateToDashboard();
  });

  test.describe('when the sidebar navigation is rendered on the Dashboard', () => {
    test('should display the navigation drawer', async () => {
      const visible = await navPage.isNavDrawerVisible();
      expect(visible).toBe(true);
    });

    test('should display all 9 navigation items', async () => {
      const labels = await navPage.getNavItemLabels();
      expect(labels).toHaveLength(9);
      expect(labels).toContain('Dashboard');
      expect(labels).toContain('Scan');
      expect(labels).toContain('Scan History');
      expect(labels).toContain('Identities');
      expect(labels).not.toContain('Effective Permissions');
      expect(labels).toContain('Attack Paths');
      expect(labels).toContain('Attack Path Patterns');
      expect(labels).toContain('Environment');
      expect(labels).toContain('Configuration');
      expect(labels).toContain('About');
    });

    test('should have correct href for Attack Path Patterns link', async () => {
      const href = await navPage.getNavItemHref('Attack Path Patterns');
      expect(href).toContain('/ciem/attack-path-patterns');
    });

    test('should have correct href for Dashboard link', async () => {
      const href = await navPage.getNavItemHref('Dashboard');
      expect(href).toContain('/ciem');
    });

    test('should have correct href for Scan link', async () => {
      const href = await navPage.getNavItemHref('Scan');
      expect(href).toContain('/ciem/scan');
    });

    test('should have correct href for Scan History link', async () => {
      const href = await navPage.getNavItemHref('Scan History');
      expect(href).toContain('/ciem/history');
    });

    test('should have correct href for Identities link', async () => {
      const href = await navPage.getNavItemHref('Identities');
      expect(href).toContain('/ciem/identities');
    });

    test('should have correct href for Configuration link', async () => {
      const href = await navPage.getNavItemHref('Configuration');
      expect(href).toContain('/ciem/config');
    });

    test('should have correct href for About link', async () => {
      const href = await navPage.getNavItemHref('About');
      expect(href).toContain('/ciem/about');
    });
  });

  test.describe('when a completed discovery run exists', () => {
    let backup = null;
    const completedAt = '2026-03-14T09:15:30Z';
    const expectedTimestamp = '2026-03-14 09:15 UTC';
    const pages = [
      { name: 'Dashboard', path: testConfig.pages.dashboard },
      { name: 'Scan', path: testConfig.pages.scan },
      { name: 'Scan History', path: testConfig.pages.history },
      { name: 'Identities', path: testConfig.pages.identities },
      { name: 'Attack Paths', path: testConfig.pages.attackPaths },
      { name: 'Attack Path Patterns', path: testConfig.pages.attackPathPatterns },
      { name: 'Environment', path: testConfig.pages.environment },
      { name: 'Configuration', path: testConfig.pages.config },
      { name: 'About', path: testConfig.pages.about }
    ];

    test.beforeAll(() => {
      backup = backupAndClearAllDiscoveryRuns();
      seedCompletedDiscoveryRunAt(completedAt);
    });

    test.afterAll(() => {
      restoreDiscoveryRuns(backup);
    });

    for (const pageConfig of pages) {
      test(`should visibly render the latest discovery timestamp box on the ${pageConfig.name} page`, async () => {
        await navPage.navigateToPage(pageConfig.path);
        const header = await navPage.getLastDiscoveryHeaderRenderState();

        expect(header.text).toContain('Last discovery generated');
        expect(header.text).toContain(expectedTimestamp);
        expect(header.box.width).toBeGreaterThan(0);
        expect(header.box.height).toBeGreaterThan(0);
        expect(header.box.x).toBeGreaterThanOrEqual(0);
        expect(header.box.y).toBeGreaterThanOrEqual(0);
        expect(header.box.x + header.box.width).toBeLessThanOrEqual(header.viewport.width);
        expect(header.box.y + header.box.height).toBeLessThanOrEqual(header.viewport.height);
        expect(header.styles.backgroundColor).toBe('rgb(255, 255, 255)');
        expect(header.styles.borderTopColor).toBe('rgba(0, 0, 0, 0.23)');
        expect(header.styles.borderTopStyle).toBe('solid');
        expect(header.styles.borderTopWidth).toBe('1px');
        expect(header.styles.color).toBe('rgb(51, 51, 51)');
      });
    }
  });

  test.describe('when the user clicks a navigation item', () => {
    test('should navigate to the Scan page when Scan nav item is clicked', async () => {
      await navPage.clickNavItem('Scan');
      await navPage.page.waitForTimeout(2000);
      const pageText = await navPage.page.textContent('body');
      expect(pageText).toContain('Run CIEM Scan');
    });

    test('should navigate to the About page when About nav item is clicked', async () => {
      await navPage.clickNavItem('About');
      await navPage.page.waitForTimeout(2000);
      const pageText = await navPage.page.textContent('body');
      expect(pageText).toContain('About Devolutions CIEM');
    });
  });
});
