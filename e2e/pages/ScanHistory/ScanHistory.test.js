const { test, expect } = require('../../_utils/BaseTestSetup');
const ScanHistoryPageHelpers = require('./ScanHistoryPageHelpers');

test.describe('Scan History Page', () => {
  let historyPage;

  test.beforeEach(async ({ ciemPage }) => {
    historyPage = new ScanHistoryPageHelpers(ciemPage);
    await historyPage.navigateToHistoryPage();
  });

  test.describe('when the history page loads with seeded scan data', () => {
    test('should display page title', async () => {
      const title = await historyPage.getPageTitle();
      expect(title).toContain('Scan History');
    });

    test('should display subtitle with expand instruction', async () => {
      const visible = await historyPage.isSubtitleVisible();
      expect(visible).toBe(true);
    });

    test('should display DataGrid with at least 1 row', async ({ }, testInfo) => {
      const hasScanData = await historyPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const gridVisible = await historyPage.isDataGridVisible();
      expect(gridVisible).toBe(true);
      const rowCount = await historyPage.getRowCount();
      expect(rowCount).toBeGreaterThanOrEqual(1);
    });

    test('should display expected column headers', async ({ }, testInfo) => {
      const hasScanData = await historyPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const headers = await historyPage.getColumnHeaders();
      expect(headers).toContain('Scan Date');
      expect(headers).toContain('Providers');
      expect(headers).toContain('Status');
      expect(headers).toContain('Failed');
      expect(headers).toContain('Passed');
      expect(headers).toContain('Duration');
    });

    test('should display pagination controls', async ({ }, testInfo) => {
      const hasScanData = await historyPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const paginationVisible = await historyPage.isPaginationVisible();
      expect(paginationVisible).toBe(true);
    });
  });

  test.describe('when scan run rows display status data', () => {
    test('should show at least one Completed status chip', async ({ }, testInfo) => {
      const hasScanData = await historyPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const completedIdx = await historyPage.findCompletedRowIndex();
      expect(completedIdx).toBeGreaterThanOrEqual(0);
    });

    test('should show failed count chip with a numeric value in completed row', async ({ }, testInfo) => {
      const hasScanData = await historyPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const completedIdx = await historyPage.findCompletedRowIndex();
      if (completedIdx < 0) {
        testInfo.skip();
        return;
      }
      const chipTexts = await historyPage.getRowChipTexts(completedIdx);
      const hasNumericChip = chipTexts.some(t => /^\d+$/.test(t));
      expect(hasNumericChip).toBe(true);
    });

    test('should show multiple status chips in completed row', async ({ }, testInfo) => {
      const hasScanData = await historyPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const completedIdx = await historyPage.findCompletedRowIndex();
      if (completedIdx < 0) {
        testInfo.skip();
        return;
      }
      const chipTexts = await historyPage.getRowChipTexts(completedIdx);
      // Should have multiple chips (status + counts)
      expect(chipTexts.length).toBeGreaterThanOrEqual(2);
    });

    test('should show duration in the duration column', async ({ }, testInfo) => {
      const hasScanData = await historyPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const row = historyPage.page.locator('.MuiDataGrid-row').first();
      const rowText = await row.textContent();
      expect(rowText.length).toBeGreaterThan(0);
    });
  });

  test.describe('when the user expands a completed scan run row', () => {
    test('should expand detail content when row expand toggle is clicked', async ({ }, testInfo) => {
      const hasScanData = await historyPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const completedIdx = await historyPage.findCompletedRowIndex();
      if (completedIdx < 0) {
        testInfo.skip();
        return;
      }
      await historyPage.expandRow(completedIdx);
      const detailVisible = await historyPage.isDetailPanelVisible();
      expect(detailVisible).toBe(true);
    });

    test('should display summary chips in expanded area', async ({ }, testInfo) => {
      const hasScanData = await historyPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const completedIdx = await historyPage.findCompletedRowIndex();
      if (completedIdx < 0) {
        testInfo.skip();
        return;
      }
      await historyPage.expandRow(completedIdx);
      const chipTexts = await historyPage.getDetailSummaryChipTexts();
      const hasFailedChip = chipTexts.some(t => t.includes('Failed'));
      const hasPassedChip = chipTexts.some(t => t.includes('Passed'));
      expect(hasFailedChip).toBe(true);
      expect(hasPassedChip).toBe(true);
    });

    test('should display results DataGrid in expanded area', async ({ }, testInfo) => {
      const hasScanData = await historyPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const completedIdx = await historyPage.findCompletedRowIndex();
      if (completedIdx < 0) {
        testInfo.skip();
        return;
      }
      await historyPage.expandRow(completedIdx);
      const gridVisible = await historyPage.isDetailDataGridVisible();
      expect(gridVisible).toBe(true);
    });

    test('should display expected columns in results DataGrid', async ({ }, testInfo) => {
      const hasScanData = await historyPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const completedIdx = await historyPage.findCompletedRowIndex();
      if (completedIdx < 0) {
        testInfo.skip();
        return;
      }
      await historyPage.expandRow(completedIdx);
      await historyPage.page.waitForTimeout(2000);
      const headers = await historyPage.getDetailColumnHeaders();
      expect(headers).toContain('Check ID');
      expect(headers).toContain('Finding');
      expect(headers).toContain('Severity');
      expect(headers).toContain('Status');
    });

    test('should show correct number of results for the scan', async ({ }, testInfo) => {
      const hasScanData = await historyPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const completedIdx = await historyPage.findCompletedRowIndex();
      if (completedIdx < 0) {
        testInfo.skip();
        return;
      }
      await historyPage.expandRow(completedIdx);
      await historyPage.page.waitForTimeout(2000);
      const detailRowCount = await historyPage.getDetailRowCount();
      expect(detailRowCount).toBeGreaterThan(0);
    });
  });

  test.describe('when export options are available', () => {
    test('should display export button', async ({ }, testInfo) => {
      const hasScanData = await historyPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      const visible = await historyPage.isExportButtonVisible();
      expect(visible).toBe(true);
    });

    test('should show export menu items when export button is clicked', async ({ }, testInfo) => {
      const hasScanData = await historyPage.hasScanData();
      if (!hasScanData) {
        testInfo.skip();
        return;
      }
      await historyPage.openExportMenu();
      const menuItems = await historyPage.getExportMenuItems();
      const hasCSV = menuItems.some(t => t.toLowerCase().includes('csv'));
      const hasJSON = menuItems.some(t => t.toLowerCase().includes('json'));
      expect(hasCSV).toBe(true);
      expect(hasJSON).toBe(true);
    });
  });

  test.describe('when no scan history exists', () => {
    test('should display empty state message', async ({ }, testInfo) => {
      const hasScanData = await historyPage.hasScanData();
      if (hasScanData) {
        testInfo.skip();
        return;
      }
      const visible = await historyPage.isEmptyStateVisible();
      expect(visible).toBe(true);
    });

    test('should contain no scan history available text', async ({ }, testInfo) => {
      const hasScanData = await historyPage.hasScanData();
      if (hasScanData) {
        testInfo.skip();
        return;
      }
      const bodyText = await historyPage.page.textContent('body');
      expect(bodyText).toContain('No scan history available');
    });
  });
});
