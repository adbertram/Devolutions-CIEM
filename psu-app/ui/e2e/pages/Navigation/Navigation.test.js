const { test, expect } = require('../../_utils/BaseTestSetup');
const NavigationPageHelpers = require('./NavigationPageHelpers');
const { getExpectedNavItems } = require('../../_utils/page-registry');
const { backupAndApplyFixture, restoreFixtureBackup } = require('../../_utils/fixtures');

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

    test('should display all registry navigation items', async () => {
      const labels = await navPage.getNavItemLabels();
      const expectedLabels = navPage.expectedNavItems.map((item) => item.label);

      expect(labels).toHaveLength(expectedLabels.length);
      for (const label of expectedLabels) {
        expect(labels).toContain(label);
      }
      expect(labels).not.toContain('Effective Permissions');
    });

    for (const expectedItem of [
      'Attack Path Patterns',
      'Dashboard',
      'Scan',
      'Scan History',
      'Identities',
      'Reports',
      'Configuration',
      'About'
    ]) {
      test(`should have registry-backed href for ${expectedItem} link`, async () => {
        const expected = navPage.expectedNavItems.find((item) => item.label === expectedItem);
        const href = await navPage.getNavItemHref(expectedItem);
        expect(href).toContain(expected.href);
      });
    }
  });

  test.describe('when a completed discovery run exists', () => {
    let backup = null;
    const expectedTimestamp = '2026-03-14 09:15 UTC';
    const pages = getExpectedNavItems().map((item) => ({ name: item.label, path: item.path }));

    test.beforeAll(() => {
      backup = backupAndApplyFixture('discovery-last-completed');
    });

    test.afterAll(() => {
      restoreFixtureBackup(backup);
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

    test('should navigate to the Reports page when Reports nav item is clicked', async () => {
      await navPage.clickNavItem('Reports');
      await navPage.page.waitForTimeout(2000);
      const pageText = await navPage.page.textContent('body');
      expect(pageText).toContain('Reports');
      expect(pageText).toContain('Azure Discovery Coverage');
    });
  });
});
