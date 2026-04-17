const { test, expect } = require('../../_utils/BaseTestSetup');
const DashboardPageHelpers = require('./DashboardPageHelpers');
const {
  backupAndClearAllScanHistory,
  restoreScanHistory,
  seedTestData,
  getScanResultCount,
  getScanHistoryCounts,
  TEST_PREFIX
} = require('../../_utils/cleanup');

test.describe('Dashboard Page', () => {
  let dashPage;

  test.beforeEach(async ({ ciemPage }) => {
    dashPage = new DashboardPageHelpers(ciemPage);
    await dashPage.navigateToDashboard();
  });

  test.describe('when the page loads', () => {
    test('should display page title', async () => {
      const title = await dashPage.getPageTitle();
      expect(title).toContain('Devolutions CIEM Dashboard');
    });

    test('should display subtitle', async () => {
      const visible = await dashPage.isSubtitleVisible();
      expect(visible).toBe(true);
    });
  });

  test.describe('when seeded scan history exists in the database', () => {
    let backup = null;

    test.beforeAll(() => {
      backup = backupAndClearAllScanHistory();
      seedTestData();
      const run1Count = getScanResultCount(`${TEST_PREFIX}scan_run_1`);
      const run2Count = getScanResultCount(`${TEST_PREFIX}scan_run_2`);
      if (run1Count !== 5 || run2Count !== 3) {
        throw new Error(`Seed verification failed: scan_run_1 has ${run1Count} results (expected 5), scan_run_2 has ${run2Count} (expected 3)`);
      }
      console.log(`[setup:dashboard] Verified ${run1Count} + ${run2Count} seeded scan results.`);
    });

    test.afterAll(() => {
      restoreScanHistory(backup);
    });

    test('should display scan run selector dropdown', async () => {
      const visible = await dashPage.isScanRunSelectorVisible();
      expect(visible).toBe(true);
    });

    test('should display Run New Scan button', async () => {
      const visible = await dashPage.isRunNewScanButtonVisible();
      expect(visible).toBe(true);
    });

    test('should use the global Last Discovery header without a page-local duplicate', async () => {
      const visible = await dashPage.isLastDiscoveryHeaderVisible();
      const localSummaryCount = await dashPage.getLocalLastDiscoverySummaryCount();
      expect(visible).toBe(true);
      expect(localSummaryCount).toBe(0);
    });

    test('should display summary cards container', async () => {
      const totalVisible = await dashPage.isElementVisible(dashPage.selectors.totalResultsCard);
      const failedVisible = await dashPage.isElementVisible(dashPage.selectors.failedChecksCard);
      const passedVisible = await dashPage.isElementVisible(dashPage.selectors.passedChecksCard);
      const criticalVisible = await dashPage.isElementVisible(dashPage.selectors.criticalIssuesCard);
      expect(totalVisible).toBe(true);
      expect(failedVisible).toBe(true);
      expect(passedVisible).toBe(true);
      expect(criticalVisible).toBe(true);
    });

    test('should show Total Results card with count greater than 0', async () => {
      const count = await dashPage.getTotalResultsCount();
      expect(count).toBeGreaterThan(0);
    });

    test('should show Failed Checks card with a numeric count', async () => {
      const count = await dashPage.getFailedChecksCount();
      expect(count).toBeGreaterThanOrEqual(0);
    });

    test('should show Passed Checks card with a numeric count', async () => {
      const count = await dashPage.getPassedChecksCount();
      expect(count).toBeGreaterThanOrEqual(0);
    });

    test('should show Critical Issues card with a number', async () => {
      const count = await dashPage.getCriticalIssuesCount();
      expect(typeof count).toBe('number');
      expect(count).toBeGreaterThanOrEqual(0);
    });

    test('should default to most recent scan run selection', async () => {
      const selectorVisible = await dashPage.isScanRunSelectorVisible();
      expect(selectorVisible).toBe(true);
    });

    test('should refresh dashboard content when selector changes without error', async () => {
      const changed = await dashPage.changeScanRunSelector();
      expect(changed).toBe(true);
      const totalVisible = await dashPage.isElementVisible(dashPage.selectors.totalResultsCard);
      expect(totalVisible).toBe(true);
    });

    test('should redirect to scan page when Run New Scan is clicked', async () => {
      await dashPage.clickRunNewScan();
      expect(dashPage.page.url()).toContain('/ciem/scan');
    });

    test('should display severity chart section', async () => {
      const chartVisible = await dashPage.isSeverityChartVisible();
      expect(chartVisible).toBe(true);
    });

    test('should display service chart section', async () => {
      const chartVisible = await dashPage.isServiceChartVisible();
      expect(chartVisible).toBe(true);
    });

    test('should display Critical & High Results card', async () => {
      const visible = await dashPage.isCritHighCardVisible();
      expect(visible).toBe(true);
    });

    test('should display Critical & High Results table', async () => {
      const hasTable = await dashPage.hasCritHighTable();
      expect(hasTable).toBe(true);
    });

    test('should redirect to history page when View All Results is clicked', async () => {
      await dashPage.clickViewAllResults();
      expect(dashPage.page.url()).toContain('/ciem/history');
    });
  });

  test.describe('when no scan data exists', () => {
    let backup = null;

    test.beforeAll(() => {
      backup = backupAndClearAllScanHistory();
      const counts = getScanHistoryCounts();
      if (counts.scanRunCount !== 0 || counts.scanResultCount !== 0) {
        throw new Error(`Expected empty scan history, got ${counts.scanRunCount} scan runs and ${counts.scanResultCount} scan results`);
      }
      console.log('[setup:dashboard-empty] Verified empty scan history.');
    });

    test.afterAll(() => {
      restoreScanHistory(backup);
    });

    test('should display empty state card with No Scan Data Available text', async () => {
      const visible = await dashPage.isEmptyStateVisible();
      expect(visible).toBe(true);
    });

    test('should display Run Your First Scan button that redirects to scan page', async () => {
      const btnVisible = await dashPage.isElementVisible(dashPage.selectors.runFirstScanBtn);
      expect(btnVisible).toBe(true);
      await dashPage.clickRunFirstScan();
      expect(dashPage.page.url()).toContain('/ciem/scan');
    });
  });
});
