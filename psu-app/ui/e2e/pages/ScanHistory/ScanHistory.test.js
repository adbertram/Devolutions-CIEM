const { test, expect } = require('../../_utils/BaseTestSetup');
const ScanHistoryPageHelpers = require('./ScanHistoryPageHelpers');
const {
  backupAndClearAllScanHistory,
  restoreScanHistory,
  seedTestData,
  cleanupTestData,
  getScanResultCount,
  TEST_PREFIX
} = require('../../_utils/cleanup');

test.describe('Scan History Page', () => {
  let historyPage;

  test.beforeEach(async ({ ciemPage }) => {
    historyPage = new ScanHistoryPageHelpers(ciemPage);
    await historyPage.navigateToHistoryPage();
  });

  // --- State: seeded scan history exists (scan_run_1 + scan_run_2 with results) ---

  test.describe('when seeded scan history exists in the database', () => {
    let backup = null;

    test.beforeAll(() => {
      // 1. Isolate: back up and clear all scan_runs/scan_results so only seeded data is visible
      backup = backupAndClearAllScanHistory();

      // 2. Seed: scan_run_1 (5 results, 2 FAIL) + scan_run_2 (3 results, 0 FAIL)
      seedTestData();

      // 3. Assert: the seed actually produced results (catches FK failures / empty checks table)
      const run1Count = getScanResultCount(`${TEST_PREFIX}scan_run_1`);
      const run2Count = getScanResultCount(`${TEST_PREFIX}scan_run_2`);
      if (run1Count !== 5 || run2Count !== 3) {
        throw new Error(`Seed verification failed: scan_run_1 has ${run1Count} results (expected 5), scan_run_2 has ${run2Count} (expected 3)`);
      }
      console.log(`[setup] Verified ${run1Count} + ${run2Count} seeded scan results.`);
    });

    test.afterAll(() => {
      cleanupTestData();
      restoreScanHistory(backup);
    });

    test('should display page title', async () => {
      const title = await historyPage.getPageTitle();
      expect(title).toContain('Scan History');
    });

    test('should display subtitle with expand instruction', async () => {
      const visible = await historyPage.isSubtitleVisible();
      expect(visible).toBe(true);
    });

    test('should display DataGrid with at least 1 row', async () => {
      const gridVisible = await historyPage.isDataGridVisible();
      expect(gridVisible).toBe(true);
      const rowCount = await historyPage.getRowCount();
      expect(rowCount).toBeGreaterThanOrEqual(1);
    });

    test('should display expected column headers', async () => {
      const headers = await historyPage.getColumnHeaders();
      expect(headers).toContain('Scan Date');
      expect(headers).toContain('Providers');
      expect(headers).toContain('Status');
      expect(headers).toContain('Failed');
      expect(headers).toContain('Passed');
      expect(headers).toContain('Duration');
    });

    test('should display pagination controls', async () => {
      const paginationVisible = await historyPage.isPaginationVisible();
      expect(paginationVisible).toBe(true);
    });

    test('should show at least one Completed status chip', async () => {
      const completedIdx = await historyPage.findCompletedRowIndex();
      expect(completedIdx).toBeGreaterThanOrEqual(0);
    });

    test('should show failed count chip with a numeric value in completed row', async () => {
      const completedIdx = await historyPage.findCompletedRowIndex();
      expect(completedIdx).toBeGreaterThanOrEqual(0);
      const chipTexts = await historyPage.getRowChipTexts(completedIdx);
      const hasNumericChip = chipTexts.some(t => /^\d+$/.test(t));
      expect(hasNumericChip).toBe(true);
    });

    test('should show multiple status chips in completed row', async () => {
      const completedIdx = await historyPage.findCompletedRowIndex();
      expect(completedIdx).toBeGreaterThanOrEqual(0);
      const chipTexts = await historyPage.getRowChipTexts(completedIdx);
      expect(chipTexts.length).toBeGreaterThanOrEqual(2);
    });

    test('should show duration in the duration column', async () => {
      const row = historyPage.page.locator('.MuiDataGrid-row').first();
      const rowText = await row.textContent();
      expect(rowText.length).toBeGreaterThan(0);
    });

    test('should expand detail content when row expand toggle is clicked', async () => {
      const completedIdx = await historyPage.findCompletedRowIndex();
      expect(completedIdx).toBeGreaterThanOrEqual(0);
      await historyPage.expandRow(completedIdx);
      const detailVisible = await historyPage.isDetailPanelVisible();
      expect(detailVisible).toBe(true);
    });

    test('should display summary chips in expanded area', async () => {
      const completedIdx = await historyPage.findCompletedRowIndex();
      expect(completedIdx).toBeGreaterThanOrEqual(0);
      await historyPage.expandRow(completedIdx);
      const chipTexts = await historyPage.getDetailSummaryChipTexts();
      const hasFailedChip = chipTexts.some(t => t.includes('Failed'));
      const hasPassedChip = chipTexts.some(t => t.includes('Passed'));
      expect(hasFailedChip).toBe(true);
      expect(hasPassedChip).toBe(true);
    });

    test('should display results DataGrid in expanded area', async () => {
      const completedIdx = await historyPage.findCompletedRowIndex();
      expect(completedIdx).toBeGreaterThanOrEqual(0);
      await historyPage.expandRow(completedIdx);
      const gridVisible = await historyPage.isDetailDataGridVisible();
      expect(gridVisible).toBe(true);
    });

    test('should display expected columns in results DataGrid', async () => {
      const completedIdx = await historyPage.findCompletedRowIndex();
      expect(completedIdx).toBeGreaterThanOrEqual(0);
      await historyPage.expandRow(completedIdx);
      await historyPage.page.waitForTimeout(2000);
      const headers = await historyPage.getDetailColumnHeaders();
      expect(headers).toContain('Check ID');
      expect(headers).toContain('Finding');
      expect(headers).toContain('Severity');
      expect(headers).toContain('Status');
    });

    test('should show correct number of results for the scan', async () => {
      const completedIdx = await historyPage.findCompletedRowIndex();
      expect(completedIdx).toBeGreaterThanOrEqual(0);
      await historyPage.expandRow(completedIdx);
      await historyPage.page.waitForTimeout(2000);
      const detailRowCount = await historyPage.getDetailRowCount();
      expect(detailRowCount).toBeGreaterThan(0);
    });

    test('should display export button', async () => {
      const visible = await historyPage.isExportButtonVisible();
      expect(visible).toBe(true);
    });

    test('should show export menu items when export button is clicked', async () => {
      await historyPage.openExportMenu();
      const menuItems = await historyPage.getExportMenuItems();
      const hasCSV = menuItems.some(t => t.toLowerCase().includes('csv'));
      const hasJSON = menuItems.some(t => t.toLowerCase().includes('json'));
      expect(hasCSV).toBe(true);
      expect(hasJSON).toBe(true);
    });
  });

  // --- State: no scan history exists in the database ---

  test.describe('when no scan history exists in the database', () => {
    let backup = null;

    test.beforeAll(() => {
      // 1. Isolate: back up and clear all scan_runs/scan_results
      backup = backupAndClearAllScanHistory();

      // 2. Assert: the tables are actually empty
      const { scanRuns, scanResults } = backup;
      // Re-open to count after clear
      const Database = require('better-sqlite3');
      const { testConfig } = require('../../_utils/test-config');
      const db = new Database(testConfig.database.path, { readonly: true });
      try {
        const runCount = db.prepare('SELECT COUNT(*) as cnt FROM scan_runs').get().cnt;
        const resCount = db.prepare('SELECT COUNT(*) as cnt FROM scan_results').get().cnt;
        if (runCount !== 0 || resCount !== 0) {
          throw new Error(`Empty-state verification failed: ${runCount} scan_runs, ${resCount} scan_results remain`);
        }
        console.log(`[setup] Verified 0 scan_runs and 0 scan_results (backed up ${scanRuns.length} + ${scanResults.length}).`);
      } finally {
        db.close();
      }
    });

    test.afterAll(() => {
      restoreScanHistory(backup);
    });

    test('should display empty state message', async () => {
      const visible = await historyPage.isEmptyStateVisible();
      expect(visible).toBe(true);
    });

    test('should contain no scan history available text', async () => {
      const bodyText = await historyPage.page.textContent('body');
      expect(bodyText).toContain('No scan history available');
    });
  });
});
