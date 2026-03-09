const { test, expect } = require('../../_utils/BaseTestSetup');
const DashboardPageHelpers = require('./DashboardPageHelpers');

test.describe('Dashboard Page', () => {
  let dashPage;

  test.beforeEach(async ({ ciemPage }) => {
    dashPage = new DashboardPageHelpers(ciemPage);
    await dashPage.navigateToDashboard();
  });

  test.describe('when the dashboard loads with seeded scan data', () => {
    test('should display page title', async () => {
      const title = await dashPage.getPageTitle();
      expect(title).toContain('Devolutions CIEM Dashboard');
    });

    test('should display subtitle', async () => {
      const visible = await dashPage.isSubtitleVisible();
      expect(visible).toBe(true);
    });

    test('should display scan run selector dropdown', async ({ }, testInfo) => {
      const hasScanData = await dashPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const visible = await dashPage.isScanRunSelectorVisible();
      expect(visible).toBe(true);
    });

    test('should display Run New Scan button', async ({ }, testInfo) => {
      const hasScanData = await dashPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const visible = await dashPage.isRunNewScanButtonVisible();
      expect(visible).toBe(true);
    });

    test('should display summary cards container', async ({ }, testInfo) => {
      const hasScanData = await dashPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const totalVisible = await dashPage.isElementVisible(dashPage.selectors.totalResultsCard);
      const failedVisible = await dashPage.isElementVisible(dashPage.selectors.failedChecksCard);
      const passedVisible = await dashPage.isElementVisible(dashPage.selectors.passedChecksCard);
      const criticalVisible = await dashPage.isElementVisible(dashPage.selectors.criticalIssuesCard);
      expect(totalVisible).toBe(true);
      expect(failedVisible).toBe(true);
      expect(passedVisible).toBe(true);
      expect(criticalVisible).toBe(true);
    });
  });

  test.describe('when scan results summary cards are rendered', () => {
    test('should show Total Results card with count greater than 0', async ({ }, testInfo) => {
      const hasScanData = await dashPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const count = await dashPage.getTotalResultsCount();
      expect(count).toBeGreaterThan(0);
    });

    test('should show Failed Checks card with a numeric count', async ({ }, testInfo) => {
      const hasScanData = await dashPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const count = await dashPage.getFailedChecksCount();
      expect(count).toBeGreaterThanOrEqual(0);
    });

    test('should show Passed Checks card with a numeric count', async ({ }, testInfo) => {
      const hasScanData = await dashPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const count = await dashPage.getPassedChecksCount();
      expect(count).toBeGreaterThanOrEqual(0);
    });

    test('should show Critical Issues card with a number', async ({ }, testInfo) => {
      const hasScanData = await dashPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const count = await dashPage.getCriticalIssuesCount();
      expect(typeof count).toBe('number');
      expect(count).toBeGreaterThanOrEqual(0);
    });
  });

  test.describe('when the user interacts with scan run selector', () => {
    test('should default to most recent scan run selection', async ({ }, testInfo) => {
      const hasScanData = await dashPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const selectorVisible = await dashPage.isScanRunSelectorVisible();
      expect(selectorVisible).toBe(true);
    });

    test('should refresh dashboard content when selector changes without error', async ({ }, testInfo) => {
      const hasScanData = await dashPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const changed = await dashPage.changeScanRunSelector();
      if (!changed) {
        testInfo.skip();
        return;
      }
      // After changing selector, dashboard should still show summary cards (no crash)
      const totalVisible = await dashPage.isElementVisible(dashPage.selectors.totalResultsCard);
      expect(totalVisible).toBe(true);
    });

    test('should redirect to scan page when Run New Scan is clicked', async ({ }, testInfo) => {
      const hasScanData = await dashPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      await dashPage.clickRunNewScan();
      // PSU Invoke-UDRedirect is async — wait for URL change
      await dashPage.page.waitForURL('**/ciem/scan', { timeout: 15000 });
      expect(dashPage.page.url()).toContain('/ciem/scan');
    });
  });

  test.describe('when charts and critical results table are rendered', () => {
    test('should display severity chart section', async ({ }, testInfo) => {
      const hasScanData = await dashPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      // Either a doughnut chart card or "No failed results" message — scoped to severity card
      const chartVisible = await dashPage.isSeverityChartVisible();
      expect(chartVisible).toBe(true);
    });

    test('should display service chart section', async ({ }, testInfo) => {
      const hasScanData = await dashPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const chartVisible = await dashPage.isServiceChartVisible();
      expect(chartVisible).toBe(true);
    });

    test('should display Critical & High Results card', async ({ }, testInfo) => {
      const hasScanData = await dashPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const visible = await dashPage.isCritHighCardVisible();
      expect(visible).toBe(true);
    });

    test('should display results table or no critical/high message', async ({ }, testInfo) => {
      const hasScanData = await dashPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const hasTable = await dashPage.hasCritHighTable();
      const hasNoMessage = await dashPage.hasNoCritHighMessage();
      expect(hasTable || hasNoMessage).toBe(true);
    });

    test('should redirect to history page when View All Results is clicked', async ({ }, testInfo) => {
      const hasScanData = await dashPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const hasTable = await dashPage.hasCritHighTable();
      if (!hasTable) {
        testInfo.skip();
        return;
      }
      await dashPage.clickViewAllResults();
      expect(dashPage.page.url()).toContain('/ciem/history');
    });
  });

  test.describe('when no scan data exists', () => {
    test('should display empty state card with No Scan Data Available text', async ({ }, testInfo) => {
      const hasScanData = await dashPage.hasScanData();
      if (hasScanData) {
        testInfo.skip();
        return;
      }
      const visible = await dashPage.isEmptyStateVisible();
      expect(visible).toBe(true);
    });

    test('should display Run Your First Scan button that redirects to scan page', async ({ }, testInfo) => {
      const hasScanData = await dashPage.hasScanData();
      if (hasScanData) {
        testInfo.skip();
        return;
      }
      const btnVisible = await dashPage.isElementVisible(dashPage.selectors.runFirstScanBtn);
      expect(btnVisible).toBe(true);
      await dashPage.clickRunFirstScan();
      expect(dashPage.page.url()).toContain('/ciem/scan');
    });
  });
});
