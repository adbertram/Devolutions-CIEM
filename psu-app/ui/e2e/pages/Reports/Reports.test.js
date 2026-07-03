const { test, expect } = require('../../_utils/BaseTestSetup');
const ReportsPageHelpers = require('./ReportsPageHelpers');
const { getCompletedDiscoveryRunCount } = require('../../_utils/cleanup');
const { backupAndApplyFixture, restoreFixtureBackup } = require('../../_utils/fixtures');

test.describe('Reports Page', () => {
  let reportsPage;
  let discoveryBackup;
  let seededRunId;

  test.beforeAll(async () => {
    discoveryBackup = backupAndApplyFixture('coverage-completed-discovery');
    seededRunId = 930001;
    const count = getCompletedDiscoveryRunCount();
    if (count !== 1) {
      throw new Error(`Expected 1 completed discovery run, got ${count}`);
    }
  });

  test.afterAll(async () => {
    restoreFixtureBackup(discoveryBackup);
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

    test('should display report generation controls and completed discovery run history', async () => {
      expect(await reportsPage.isGenerateReportButtonVisible()).toBe(true);
      expect(await reportsPage.isReportRunSelectorVisible()).toBe(true);

      const historyText = await reportsPage.getReportHistoryText();
      expect(historyText).toContain('Report Selection');
      expect(historyText).toContain(`Run #${seededRunId}`);
    });

    test('should render the Azure Discovery Coverage report on demand', async () => {
      await reportsPage.clickGenerateReport();

      const resultVisible = await reportsPage.isReportResultVisible();
      expect(resultVisible).toBe(true);

      const contextText = await reportsPage.getReportContextText();
      expect(contextText).toContain('Azure Discovery Coverage');
      await reportsPage.waitForContextChip('RunId');
      await reportsPage.waitForContextChip('Scope');
      await reportsPage.waitForContextChip('Status');
      expect(await reportsPage.getContextChipText('RunId')).toContain(String(seededRunId));
      expect(await reportsPage.getContextChipText('Scope')).toContain('All');
      expect(await reportsPage.getContextChipText('Status')).toContain('Completed');

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
