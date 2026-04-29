const { test, expect } = require('../../_utils/BaseTestSetup');
const ReportsPageHelpers = require('./ReportsPageHelpers');
const {
  backupAndClearAllDiscoveryRuns,
  restoreDiscoveryRuns,
  seedCompletedDiscoveryRun,
  getCompletedDiscoveryRunCount
} = require('../../_utils/cleanup');

test.describe('Reports Page', () => {
  let reportsPage;
  let discoveryBackup;
  let seededRunId;

  test.beforeAll(async () => {
    discoveryBackup = backupAndClearAllDiscoveryRuns();
    seededRunId = seedCompletedDiscoveryRun();
    const count = getCompletedDiscoveryRunCount();
    if (count !== 1) {
      throw new Error(`Expected 1 completed discovery run, got ${count}`);
    }
  });

  test.afterAll(async () => {
    restoreDiscoveryRuns(discoveryBackup);
  });

  test.beforeEach(async ({ ciemPage }) => {
    reportsPage = new ReportsPageHelpers(ciemPage);
    await reportsPage.navigateToReportsPage();
  });

  test.describe('when the page loads', () => {
    test('should display the Reports page title', async () => {
      const title = await reportsPage.getPageTitle();
      expect(title.trim()).toBe('Reports');
    });

    test('should render the Azure Discovery Coverage report for the latest completed discovery run', async () => {
      const resultVisible = await reportsPage.isReportResultVisible();
      expect(resultVisible).toBe(true);

      const contextText = await reportsPage.getReportContextText();
      expect(contextText).toContain('Azure Discovery Coverage');
      expect(contextText).toContain(`Run #${seededRunId}`);
      expect(contextText).toContain('Scope All');
      expect(contextText).toContain('Status Completed');

      const summaryText = await reportsPage.getReportSummaryText();
      expect(summaryText).toContain('Collected');
      expect(summaryText).toContain('4');

      const tableText = await reportsPage.getReportResultTableText();
      expect(tableText).toContain('ARM resources');
      expect(tableText).toContain('Entra resources');
      expect(tableText).toContain('Entra relationships');
      expect(tableText).toContain('Effective role assignments');
    });
  });
});
