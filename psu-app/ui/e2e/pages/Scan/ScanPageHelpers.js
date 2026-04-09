const BasePage = require('../../_utils/BasePage');
const { testConfig } = require('../../_utils/test-config');

class ScanPageHelpers extends BasePage {
  constructor(page) {
    super(page);
    this.selectors = {
      pageTitle: "h4:has-text('Run CIEM Scan')",
      subtitle: "text=Configure and execute a CIEM security scan",
      checkSelectionCard: ".MuiCard-root:has-text('Check Selection')",

      // Selection summary
      selectionSummary: 'text=/\\d+ \\/ \\d+ enabled checks selected/',

      // Status filter
      statusFilter: '#checkStatusFilter',
      statusFilterCombobox: '[role="combobox"][aria-labelledby="checkStatusFilterlabel"]',

      // DataGrid
      dataGrid: '.MuiDataGrid-root',
      dataGridRows: '.MuiDataGrid-row',
      dataGridColumnHeaders: '.MuiDataGrid-columnHeader',
      headerCheckbox: '.MuiDataGrid-columnHeaderCheckbox input[type="checkbox"]',
      rowCheckbox: '.MuiDataGrid-row input[type="checkbox"]',
      quickFilter: 'input[placeholder="Search…"]',
      pagination: '.MuiTablePagination-root',
      severityChip: '.MuiDataGrid-row .MuiChip-root',

      // Discovery required alert
      discoveryRequiredAlert: '.MuiAlert-root:has-text("Run Azure Discovery")',

      // Action buttons
      startScanBtn: '#startScanBtn',

      // Scan progress
      scanProgressArea: '#scanProgressArea',
      scanProgressBar: '#scanProgressArea .MuiLinearProgress-root',
      scanProgressText: '#scanProgressArea .MuiTypography-body2',
      scanCompleteIcon: "#scanProgressArea .MuiCard-root:has-text('Scan Complete!')",

      // Info modal
      infoModal: '[role="dialog"]',
      infoModalTitle: '[role="dialog"] h6',
      infoModalCloseBtn: "[role='dialog'] button:has-text('Close')",
      infoButton: '.MuiDataGrid-row button',

      // Error state
      scanErrorCard: "#scanProgressArea .MuiCard-root:has-text('Scan Failed')"
    };
  }

  async navigateToScanPage() {
    await this.goto(testConfig.pages.scan);
    // Wait for the DataGrid to render rows
    await this.waitForElement(this.selectors.dataGrid);
    // Give PSU time to load data into the grid
    await this.page.waitForTimeout(2000);
  }

  // --- Selection Summary ---

  async getSelectionSummaryText() {
    const el = this.page.locator(this.selectors.selectionSummary);
    return await el.textContent();
  }

  async getSelectionCounts() {
    const text = await this.getSelectionSummaryText();
    const match = text.match(/(\d+) \/ (\d+) enabled checks selected \((\d+) disabled\)/);
    if (!match) return null;
    return {
      selected: parseInt(match[1]),
      enabled: parseInt(match[2]),
      disabled: parseInt(match[3])
    };
  }

  // --- Status Filter ---

  async selectStatusFilter(value) {
    await this.selectMUIOption('checkStatusFilter', value);
    // Wait for grid to re-render with new data
    await this.page.waitForTimeout(2000);
  }

  async getSelectedStatusFilter() {
    return await this.getMUISelectValue('checkStatusFilter');
  }

  // --- DataGrid ---

  async getRowCount() {
    await this.waitForElement(this.selectors.dataGrid);
    return await this.page.locator(this.selectors.dataGridRows).count();
  }

  async getColumnHeaders() {
    const headers = this.page.locator(this.selectors.dataGridColumnHeaders);
    const count = await headers.count();
    const texts = [];
    for (let i = 0; i < count; i++) {
      const text = (await headers.nth(i).textContent()).trim();
      if (text.length > 0) texts.push(text);
    }
    return texts;
  }

  async getRowData(rowIndex) {
    const row = this.page.locator(this.selectors.dataGridRows).nth(rowIndex);
    const cells = row.locator('.MuiDataGrid-cell');
    const count = await cells.count();
    const data = [];
    for (let i = 0; i < count; i++) {
      data.push((await cells.nth(i).textContent()).trim());
    }
    return data;
  }

  async getSeverityChipTexts() {
    const chips = this.page.locator(this.selectors.severityChip);
    const count = await chips.count();
    const texts = [];
    for (let i = 0; i < count; i++) {
      texts.push((await chips.nth(i).textContent()).trim());
    }
    return texts;
  }

  // --- Checkbox Selection ---

  async clickHeaderCheckbox() {
    await this.page.locator(this.selectors.headerCheckbox).click();
    await this.page.waitForTimeout(500);
  }

  async clickRowCheckbox(rowIndex) {
    const checkbox = this.page.locator(this.selectors.dataGridRows).nth(rowIndex).locator('input[type="checkbox"]');
    await checkbox.click();
    await this.page.waitForTimeout(500);
  }

  async isRowCheckboxChecked(rowIndex) {
    const checkbox = this.page.locator(this.selectors.dataGridRows).nth(rowIndex).locator('input[type="checkbox"]');
    return await checkbox.isChecked();
  }

  // --- Quick Filter ---

  async searchChecks(text) {
    await this.page.locator(this.selectors.quickFilter).fill(text);
    await this.page.waitForTimeout(2000);
  }

  async clearSearch() {
    await this.page.locator(this.selectors.quickFilter).fill('');
    await this.page.waitForTimeout(2000);
  }

  // --- Info Modal ---

  async clickInfoButton(rowIndex) {
    const row = this.page.locator(this.selectors.dataGridRows).nth(rowIndex);
    await row.locator('button').first().click();
    await this.waitForElement('[role="dialog"]');
  }

  async getInfoModalTitle() {
    await this.waitForSelector('[role="dialog"] h6');
    return await this.page.locator('[role="dialog"] h6').first().textContent();
  }

  async getInfoModalChips() {
    const chips = this.page.locator('[role="dialog"] .MuiChip-root');
    const count = await chips.count();
    const texts = [];
    for (let i = 0; i < count; i++) {
      texts.push((await chips.nth(i).textContent()).trim());
    }
    return texts;
  }

  async getInfoModalSections() {
    const sections = this.page.locator('[role="dialog"] [class*="subtitle2"]');
    const count = await sections.count();
    const texts = [];
    for (let i = 0; i < count; i++) {
      texts.push((await sections.nth(i).textContent()).trim());
    }
    return texts;
  }

  async getInfoModalButtons() {
    const buttons = this.page.locator('[role="dialog"] button');
    const count = await buttons.count();
    const texts = [];
    for (let i = 0; i < count; i++) {
      texts.push((await buttons.nth(i).textContent()).trim());
    }
    return texts.filter(t => t.length > 0);
  }

  async isInfoModalVisible() {
    return await this.isElementVisible('[role="dialog"]');
  }

  async closeInfoModal() {
    await this.click("[role='dialog'] button:has-text('Close')");
    await this.page.locator('[role="dialog"]').waitFor({ state: 'hidden', timeout: 10000 });
  }

  // --- Start Scan ---

  async clickStartScan() {
    await this.click(this.selectors.startScanBtn);
  }

  async isStartScanButtonEnabled() {
    const btn = this.page.locator(this.selectors.startScanBtn);
    const disabled = await btn.getAttribute('disabled');
    return disabled === null;
  }

  async getStartScanButtonText() {
    return (await this.page.locator(this.selectors.startScanBtn).textContent()).trim();
  }

  async isDiscoveryRequiredAlertVisible() {
    return await this.isElementVisible(this.selectors.discoveryRequiredAlert);
  }

  async getStartScanButtonTooltip() {
    const btn = this.page.locator(this.selectors.startScanBtn);
    // MUI wraps disabled buttons in a span with title for tooltip
    const parent = btn.locator('..');
    return await parent.getAttribute('title');
  }

  // --- Progress Area ---

  async isScanProgressAreaEmpty() {
    const area = this.page.locator(this.selectors.scanProgressArea);
    const children = await area.evaluate(el => el.children.length);
    return children === 0;
  }

  async getScanProgressText() {
    const textEl = this.page.locator(this.selectors.scanProgressText).first();
    try {
      await textEl.waitFor({ state: 'visible', timeout: 10000 });
      return (await textEl.textContent()).trim();
    } catch {
      return '';
    }
  }

  // --- Pagination ---

  async getPaginationText() {
    return (await this.page.locator(this.selectors.pagination).textContent()).trim();
  }

  // --- Scan Execution ---

  async selectSingleCheckBySearch(searchTerm) {
    // Filter to a specific check, then select it
    await this.searchChecks(searchTerm);
    const rowCount = await this.getRowCount();
    if (rowCount === 0) throw new Error(`No checks found matching "${searchTerm}"`);
    await this.clickRowCheckbox(0);
  }

  async waitForScanProgress(timeout = 15000) {
    // Wait for either circular progress (initial render) or linear progress bar (after first poll)
    const circularOrLinear = this.page.locator(
      `${this.selectors.scanProgressArea} .MuiCircularProgress-root, ${this.selectors.scanProgressBar}`
    );
    await circularOrLinear.first().waitFor({ state: 'visible', timeout });
  }

  async waitForScanComplete(timeout = 300000) {
    // Wait for either "Scan Complete!" or "Scan Failed" to appear
    const completeOrFail = this.page.locator(`${this.selectors.scanCompleteIcon}, ${this.selectors.scanErrorCard}`);
    await completeOrFail.first().waitFor({ state: 'visible', timeout });
  }

  async isScanCompleteVisible() {
    return await this.isElementVisible(this.selectors.scanCompleteIcon);
  }

  async isScanErrorVisible() {
    return await this.isElementVisible(this.selectors.scanErrorCard);
  }

  async getScanCompleteSummaryText() {
    const card = this.page.locator(this.selectors.scanCompleteIcon);
    return (await card.textContent()).trim();
  }
}

module.exports = ScanPageHelpers;
