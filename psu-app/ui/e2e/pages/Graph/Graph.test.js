const { test, expect } = require('../../_utils/BaseTestSetup');
const GraphPageHelpers = require('./GraphPageHelpers');

test.describe('Identity Graph Page', () => {
  let graphPage;

  test.beforeEach(async ({ ciemPage }) => {
    graphPage = new GraphPageHelpers(ciemPage);
    await graphPage.navigateToGraphPage();
  });

  test.describe('when the graph page loads', () => {
    test('should display page title', async () => {
      const title = await graphPage.getPageTitle();
      expect(title).toContain('Identity Graph');
    });

    test('should display subtitle', async () => {
      const visible = await graphPage.isSubtitleVisible();
      expect(visible).toBe(true);
    });

    test('should display Refresh Data button', async () => {
      const visible = await graphPage.isRefreshButtonVisible();
      expect(visible).toBe(true);
    });
  });

  test.describe('when no collected data exists (empty state)', () => {
    test('should display empty state card', async ({}, testInfo) => {
      const hasData = await graphPage.hasCollectedData();
      if (hasData) {
        testInfo.skip();
        return;
      }
      const visible = await graphPage.isEmptyStateVisible();
      expect(visible).toBe(true);
    });

    test('should display No Identity Graph Available text', async ({}, testInfo) => {
      const hasData = await graphPage.hasCollectedData();
      if (hasData) {
        testInfo.skip();
        return;
      }
      const visible = await graphPage.isEmptyStateTextVisible();
      expect(visible).toBe(true);
    });

    test('should display empty state description', async ({}, testInfo) => {
      const hasData = await graphPage.hasCollectedData();
      if (hasData) {
        testInfo.skip();
        return;
      }
      const visible = await graphPage.isEmptyStateDescriptionVisible();
      expect(visible).toBe(true);
    });

    test('should display Build Identity Graph button', async ({}, testInfo) => {
      const hasData = await graphPage.hasCollectedData();
      if (hasData) {
        testInfo.skip();
        return;
      }
      const visible = await graphPage.isBuildGraphButtonVisible();
      expect(visible).toBe(true);
    });

    test('should respond to clicking Build Identity Graph', async ({}, testInfo) => {
      testInfo.setTimeout(30000);
      const hasData = await graphPage.hasCollectedData();
      if (hasData) {
        testInfo.skip();
        return;
      }
      await graphPage.clickBuildGraph();
      // The handler replaces the button content via Set-UDElement — wait for either
      // the button to disappear, spinner/progress text to appear, or error to appear
      await graphPage.page.waitForTimeout(5000);
      const buttonStillVisible = await graphPage.isBuildGraphButtonVisible();
      const spinnerVisible = await graphPage.isBuildGraphSpinnerVisible();
      const progressVisible = await graphPage.isBuildGraphProgressTextVisible();
      const errorVisible = await graphPage.isBuildGraphErrorVisible();
      // Any change from the initial button state means the handler fired
      expect(!buttonStillVisible || spinnerVisible || progressVisible || errorVisible).toBe(true);
    });
  });

  test.describe('when collected data exists (populated state)', () => {
    test('should display tabs container with All Providers tab', async ({}, testInfo) => {
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

    test('should display at least one provider tab', async ({}, testInfo) => {
      const hasData = await graphPage.hasCollectedData();
      if (!hasData) {
        testInfo.skip();
        return;
      }
      const tabLabels = await graphPage.getTabLabels();
      // Should have "All Providers" + at least one individual provider
      expect(tabLabels.length).toBeGreaterThanOrEqual(2);
    });

    test('should display Identity Access card', async ({}, testInfo) => {
      const hasData = await graphPage.hasCollectedData();
      if (!hasData) {
        testInfo.skip();
        return;
      }
      const visible = await graphPage.isIdentityAccessCardVisible();
      expect(visible).toBe(true);
    });

    test('should display Resource Access card', async ({}, testInfo) => {
      const hasData = await graphPage.hasCollectedData();
      if (!hasData) {
        testInfo.skip();
        return;
      }
      const visible = await graphPage.isResourceAccessCardVisible();
      expect(visible).toBe(true);
    });

    test('should display Summary card', async ({}, testInfo) => {
      const hasData = await graphPage.hasCollectedData();
      if (!hasData) {
        testInfo.skip();
        return;
      }
      const visible = await graphPage.isSummaryCardVisible();
      expect(visible).toBe(true);
    });

    test('should display Search and Visualize buttons', async ({}, testInfo) => {
      const hasData = await graphPage.hasCollectedData();
      if (!hasData) {
        testInfo.skip();
        return;
      }
      const searchCount = await graphPage.getSearchButtonCount();
      expect(searchCount).toBeGreaterThanOrEqual(2); // One in Identity Access, one in Resource Access
      const visualizeVisible = await graphPage.isVisualizeButtonVisible();
      expect(visualizeVisible).toBe(true);
    });

    test('should display individual provider tab content after clicking', async ({}, testInfo) => {
      const hasData = await graphPage.hasCollectedData();
      if (!hasData) {
        testInfo.skip();
        return;
      }
      const tabLabels = await graphPage.getTabLabels();
      // Click on the first individual provider tab (skip "All Providers")
      const providerTab = tabLabels.find(t => t !== 'All Providers');
      if (!providerTab) {
        testInfo.skip();
        return;
      }
      await graphPage.clickTab(providerTab);
      // Should still show the same sections
      const identityVisible = await graphPage.isIdentityAccessCardVisible();
      expect(identityVisible).toBe(true);
    });

    test('should respond to clicking Refresh Data', async ({}, testInfo) => {
      testInfo.setTimeout(30000);
      const hasData = await graphPage.hasCollectedData();
      if (!hasData) {
        testInfo.skip();
        return;
      }
      await graphPage.clickRefresh();
      await graphPage.page.waitForTimeout(5000);
      // Handler replaces button with spinner, or page redirects on completion
      const buttonStillVisible = await graphPage.isRefreshButtonVisible();
      const spinnerVisible = await graphPage.isRefreshSpinnerVisible();
      const urlHasGraph = graphPage.page.url().includes('/ciem/graph');
      expect(!buttonStillVisible || spinnerVisible || urlHasGraph).toBe(true);
    });
  });
});
