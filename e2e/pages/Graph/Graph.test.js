const { test, expect } = require('../../_utils/BaseTestSetup');
const GraphPageHelpers = require('./GraphPageHelpers');

test.describe('Identity Graph Page', () => {
  let graphPage;

  test.beforeEach(async ({ ciemPage }) => {
    graphPage = new GraphPageHelpers(ciemPage);
    await graphPage.navigateToGraphPage();
  });

  test.describe('when the graph page loads without collected data', () => {
    test('should display page title', async () => {
      const title = await graphPage.getPageTitle();
      expect(title).toContain('Identity Graph');
    });

    test('should display subtitle', async () => {
      const visible = await graphPage.isSubtitleVisible();
      expect(visible).toBe(true);
    });

    test('should display empty state card when no graph data exists', async ({ }, testInfo) => {
      const hasData = await graphPage.hasCollectedData();
      if (hasData) {
        testInfo.skip();
        return;
      }
      const visible = await graphPage.isEmptyStateVisible();
      expect(visible).toBe(true);
    });

    test('should display No Identity Graph Available text', async ({ }, testInfo) => {
      const hasData = await graphPage.hasCollectedData();
      if (hasData) {
        testInfo.skip();
        return;
      }
      const visible = await graphPage.isEmptyStateTextVisible();
      expect(visible).toBe(true);
    });

    test('should display Run a Scan button', async ({ }, testInfo) => {
      const hasData = await graphPage.hasCollectedData();
      if (hasData) {
        testInfo.skip();
        return;
      }
      const visible = await graphPage.isRunScanButtonVisible();
      expect(visible).toBe(true);
    });
  });

  test.describe('when the user clicks Run a Scan from empty state', () => {
    test('should redirect to scan page', async ({ }, testInfo) => {
      const hasData = await graphPage.hasCollectedData();
      if (hasData) {
        testInfo.skip();
        return;
      }
      await graphPage.clickRunScan();
      // PSU Invoke-UDRedirect is async — wait for navigation to complete
      await graphPage.page.waitForURL('**/ciem/scan', { timeout: 15000 });
      expect(graphPage.page.url()).toContain('/ciem/scan');
    });
  });

  test.describe('when collected data exists', () => {
    test('should display tabs container with All Providers tab', async ({ }, testInfo) => {
      const hasData = await graphPage.hasCollectedData();
      if (!hasData) {
        testInfo.skip();
        return;
      }
      const tabsVisible = await graphPage.isTabsContainerVisible();
      expect(tabsVisible).toBe(true);
      const tabLabels = await graphPage.getTabLabels();
      expect(tabLabels).toContain('All Providers');
    });

    test('should display at least one provider tab', async ({ }, testInfo) => {
      const hasData = await graphPage.hasCollectedData();
      if (!hasData) {
        testInfo.skip();
        return;
      }
      const tabLabels = await graphPage.getTabLabels();
      // Should have "All Providers" + at least one individual provider
      expect(tabLabels.length).toBeGreaterThanOrEqual(2);
    });
  });
});
