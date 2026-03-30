const { test, expect } = require('../../_utils/BaseTestSetup');
const NavigationPageHelpers = require('./NavigationPageHelpers');

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

    test('should display all 6 navigation items', async () => {
      const labels = await navPage.getNavItemLabels();
      expect(labels).toHaveLength(6);
      expect(labels).toContain('Dashboard');
      expect(labels).toContain('Scan');
      expect(labels).toContain('Scan History');
      expect(labels).toContain('Environment');
      expect(labels).toContain('Configuration');
      expect(labels).toContain('About');
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

    test('should have correct href for Configuration link', async () => {
      const href = await navPage.getNavItemHref('Configuration');
      expect(href).toContain('/ciem/config');
    });

    test('should have correct href for About link', async () => {
      const href = await navPage.getNavItemHref('About');
      expect(href).toContain('/ciem/about');
    });
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
