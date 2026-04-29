const { test, expect } = require('../../_utils/BaseTestSetup');
const ScanPageHelpers = require('./ScanPageHelpers');
const {
  seedChecks,
  backupAndClearAllChecks,
  restoreChecks,
  getTestCheckCounts,
  getCompletedDiscoveryRunCount,
  backupAndClearAllDiscoveryRuns,
  restoreDiscoveryRuns,
  seedCompletedDiscoveryRun,
  backupAndClearAllScanHistory,
  restoreScanHistory
} = require('../../_utils/cleanup');

test.describe('Scan Page', () => {
  let scanPage;
  let checksBackup = null;

  test.beforeAll(() => {
    checksBackup = backupAndClearAllChecks();
    seedChecks();
    const counts = getTestCheckCounts();
    if (counts.enabled <= 0 || counts.disabled <= 0) {
      throw new Error(`Expected enabled and disabled catalog check state, got ${counts.enabled} enabled and ${counts.disabled} disabled`);
    }
    console.log(`[setup:scan-checks] Verified ${counts.enabled} enabled and ${counts.disabled} disabled catalog check state rows.`);
  });

  test.afterAll(() => {
    restoreChecks(checksBackup);
  });

  test.beforeEach(async ({ ciemPage }) => {
    scanPage = new ScanPageHelpers(ciemPage);
    await scanPage.navigateToScanPage();
  });

  test.describe('when no Azure discovery has been run', () => {
    let discoveryBackup = null;

    test.beforeAll(() => {
      discoveryBackup = backupAndClearAllDiscoveryRuns();
      const count = getCompletedDiscoveryRunCount();
      if (count !== 0) {
        throw new Error(`Expected 0 completed discovery runs, got ${count}`);
      }
      console.log(`[setup:no-discovery] Verified 0 completed discovery runs`);
    });

    test.afterAll(() => {
      restoreDiscoveryRuns(discoveryBackup);
    });

    test('should disable the Start Scan button', async () => {
      const enabled = await scanPage.isStartScanButtonEnabled();
      expect(enabled).toBe(false);
    });

    test('should show a discovery required alert', async () => {
      const visible = await scanPage.isDiscoveryRequiredAlertVisible();
      expect(visible).toBe(true);
    });
  });

  test.describe('when the scan page loads with check data', () => {
    test('should display page title and subtitle', async () => {
      const title = await scanPage.getText(scanPage.selectors.pageTitle);
      expect(title).toContain('Run CIEM Scan');
      const subtitle = await scanPage.isElementVisible(scanPage.selectors.subtitle);
      expect(subtitle).toBe(true);
    });

    test('should display Check Selection card', async () => {
      const cardVisible = await scanPage.isElementVisible(scanPage.selectors.checkSelectionCard);
      expect(cardVisible).toBe(true);
    });

    test('should display selection summary with check counts', async () => {
      const counts = await scanPage.getSelectionCounts();
      expect(counts).not.toBeNull();
      expect(counts.enabled).toBeGreaterThan(0);
      expect(counts.disabled).toBeGreaterThan(0);
    });

    test('should display Start Scan button with correct text', async () => {
      const text = await scanPage.getStartScanButtonText();
      expect(text).toBe('Start Scan');
    });

    test('should have empty scan progress area initially', async () => {
      const empty = await scanPage.isScanProgressAreaEmpty();
      expect(empty).toBe(true);
    });
  });

  test.describe('when the check DataGrid renders with enabled checks', () => {
    test('should display expected column headers', async () => {
      const headers = await scanPage.getColumnHeaders();
      expect(headers).toContain('Severity');
      expect(headers).toContain('Provider');
      expect(headers).toContain('Service');
      expect(headers).toContain('Title');
      expect(headers).toContain('Check ID');
    });

    test('should display rows matching the enabled check count', async () => {
      const counts = await scanPage.getSelectionCounts();
      const rowCount = await scanPage.getRowCount();
      expect(rowCount).toBe(counts.enabled);
    });

    test('should render severity as colored chips', async () => {
      const chipTexts = await scanPage.getSeverityChipTexts();
      expect(chipTexts.length).toBeGreaterThan(0);
      const validSeverities = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'INFO'];
      for (const text of chipTexts) {
        expect(validSeverities).toContain(text);
      }
    });

    test('should display checkbox column with header checkbox for select-all', async () => {
      const headerCb = scanPage.page.locator(scanPage.selectors.headerCheckbox);
      expect(await headerCb.isVisible()).toBe(true);
    });

    test('should display quick filter search input', async () => {
      const visible = await scanPage.isElementVisible(scanPage.selectors.quickFilter);
      expect(visible).toBe(true);
    });

    test('should display pagination controls', async () => {
      const pagText = await scanPage.getPaginationText();
      expect(pagText).toContain('of');
    });
  });

  test.describe('when the user changes the status filter', () => {
    test('should default to Enabled filter showing only enabled checks', async () => {
      const filterValue = await scanPage.getSelectedStatusFilter();
      expect(filterValue).toBe('enabled');
    });

    test('should show disabled checks when Disabled filter is selected', async () => {
      const initialCount = await scanPage.getRowCount();
      await scanPage.selectStatusFilter('disabled');
      const disabledCount = await scanPage.getRowCount();
      // Disabled checks should be a different set than enabled
      expect(disabledCount).toBeGreaterThan(0);
      expect(disabledCount).not.toBe(initialCount);
    });

    test('should show all checks when All filter is selected', async () => {
      const enabledCount = await scanPage.getRowCount();
      await scanPage.selectStatusFilter('all');
      const allCount = await scanPage.getRowCount();
      // All should be >= enabled (paginated to 25)
      expect(allCount).toBeGreaterThanOrEqual(enabledCount);
    });

    test('should return to enabled checks when switching back to Enabled', async () => {
      const initialCount = await scanPage.getRowCount();
      await scanPage.selectStatusFilter('disabled');
      await scanPage.selectStatusFilter('enabled');
      const restoredCount = await scanPage.getRowCount();
      expect(restoredCount).toBe(initialCount);
    });
  });

  test.describe('when the user selects checks via checkboxes', () => {
    test('should update selection summary when a single row is checked', async () => {
      // Ensure clean state by deselecting all first
      await scanPage.clickHeaderCheckbox(); // select all
      await scanPage.clickHeaderCheckbox(); // deselect all
      const before = await scanPage.getSelectionCounts();
      expect(before.selected).toBe(0);
      await scanPage.clickRowCheckbox(0);
      const after = await scanPage.getSelectionCounts();
      expect(after.selected).toBe(1);
    });

    test('should select all visible rows when header checkbox is clicked', async () => {
      await scanPage.clickHeaderCheckbox();
      const counts = await scanPage.getSelectionCounts();
      expect(counts.selected).toBe(counts.enabled);
    });

    test('should deselect all rows when header checkbox is clicked again', async () => {
      await scanPage.clickHeaderCheckbox(); // select all
      await scanPage.clickHeaderCheckbox(); // deselect all
      const counts = await scanPage.getSelectionCounts();
      expect(counts.selected).toBe(0);
    });

    test('should track individual row checkbox state', async () => {
      await scanPage.clickRowCheckbox(0);
      const checked = await scanPage.isRowCheckboxChecked(0);
      expect(checked).toBe(true);
      const unchecked = await scanPage.isRowCheckboxChecked(1);
      expect(unchecked).toBe(false);
    });
  });

  test.describe('when the user types in the quick filter search', () => {
    test('should filter rows to match the search term', async () => {
      const initialCount = await scanPage.getRowCount();
      await scanPage.searchChecks('Multifactor');
      const filteredCount = await scanPage.getRowCount();
      expect(filteredCount).toBeGreaterThan(0);
      expect(filteredCount).toBeLessThan(initialCount);
    });

    test('should show no rows when search term matches nothing', async () => {
      await scanPage.searchChecks('ZZZZNONEXISTENT');
      const rowCount = await scanPage.getRowCount();
      expect(rowCount).toBe(0);
    });

    test('should restore all rows when search is cleared', async () => {
      const initialCount = await scanPage.getRowCount();
      await scanPage.searchChecks('Multifactor');
      await scanPage.clearSearch();
      const restoredCount = await scanPage.getRowCount();
      expect(restoredCount).toBe(initialCount);
    });
  });

  test.describe('when the user clicks the info icon on a check row', () => {
    test.afterEach(async () => {
      if (await scanPage.isInfoModalVisible()) {
        await scanPage.closeInfoModal();
      }
    });

    test('should open a modal with the check title', async () => {
      await scanPage.clickInfoButton(0);
      const visible = await scanPage.isInfoModalVisible();
      expect(visible).toBe(true);
      const title = await scanPage.getInfoModalTitle();
      expect(title.length).toBeGreaterThan(0);
    });

    test('should display severity, provider, and service chips in the modal', async () => {
      await scanPage.clickInfoButton(0);
      const chips = await scanPage.getInfoModalChips();
      expect(chips.length).toBeGreaterThanOrEqual(3);
      // First chip is severity (uppercase)
      const validSeverities = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'INFO'];
      expect(validSeverities).toContain(chips[0]);
    });

    test('should display Description, Risk, and Check ID sections', async () => {
      await scanPage.clickInfoButton(0);
      const sections = await scanPage.getInfoModalSections();
      expect(sections).toContain('Description');
      expect(sections).toContain('Risk');
      expect(sections).toContain('Check ID');
    });

    test('should display Close button in the modal footer', async () => {
      await scanPage.clickInfoButton(0);
      const buttons = await scanPage.getInfoModalButtons();
      expect(buttons).toContain('Close');
    });

    test('should close the modal when Close is clicked', async () => {
      await scanPage.clickInfoButton(0);
      expect(await scanPage.isInfoModalVisible()).toBe(true);
      await scanPage.closeInfoModal();
      expect(await scanPage.isInfoModalVisible()).toBe(false);
    });
  });

  test.describe('when completed Azure discovery data exists', () => {
    let discoveryBackup = null;
    let scanHistoryBackup = null;

    test.beforeAll(() => {
      discoveryBackup = backupAndClearAllDiscoveryRuns();
      scanHistoryBackup = backupAndClearAllScanHistory();
      seedCompletedDiscoveryRun();
      const count = getCompletedDiscoveryRunCount();
      if (count !== 1) {
        throw new Error(`Expected 1 completed discovery run, got ${count}`);
      }
      console.log(`[setup:completed-discovery] Verified ${count} completed discovery run.`);
    });

    test.afterAll(() => {
      restoreScanHistory(scanHistoryBackup);
      restoreDiscoveryRuns(discoveryBackup);
    });

    test.describe('when the user clicks Start Scan without selecting any checks', () => {
      test('should display a warning toast asking to select checks', async () => {
        await scanPage.clickStartScan();
        const toast = await scanPage.waitForToast('select at least one check');
        expect(toast).toBeTruthy();
      });

      test('should not show scan progress area', async () => {
        await scanPage.clickStartScan();
        await scanPage.page.waitForTimeout(1000);
        const empty = await scanPage.isScanProgressAreaEmpty();
        expect(empty).toBe(true);
      });

      test('should keep the Start Scan button enabled', async () => {
        await scanPage.clickStartScan();
        await scanPage.page.waitForTimeout(1000);
        const enabled = await scanPage.isStartScanButtonEnabled();
        expect(enabled).toBe(true);
      });
    });

    test.describe('when the user executes a scan with a single check', () => {
      test('should show progress UI with disabled button and starting toast', async () => {
        await scanPage.selectSingleCheckBySearch('security_defaults');
        await scanPage.clickStartScan();
        await scanPage.waitForScanProgress();
        const statusText = await scanPage.getScanProgressText();
        expect(statusText.length).toBeGreaterThan(0);
        const enabled = await scanPage.isStartScanButtonEnabled();
        expect(enabled).toBe(false);
        const toast = await scanPage.waitForToast('Starting CIEM scan');
        expect(toast).toBeTruthy();
      });

      test('should complete scan with terminal state card and re-enable button', async ({ }, testInfo) => {
        testInfo.setTimeout(600000);
        await scanPage.selectSingleCheckBySearch('security_defaults');
        await scanPage.clickStartScan();
        await scanPage.waitForScanComplete(540000);
        const isComplete = await scanPage.isScanCompleteVisible();
        const isError = await scanPage.isScanErrorVisible();
        expect(isComplete || isError).toBe(true);
        const progressArea = scanPage.page.locator(scanPage.selectors.scanProgressArea);
        const text = (await progressArea.textContent()).trim();
        expect(text.length).toBeGreaterThan(0);
        const enabled = await scanPage.isStartScanButtonEnabled();
        expect(enabled).toBe(true);
      });
    });
  });
});
