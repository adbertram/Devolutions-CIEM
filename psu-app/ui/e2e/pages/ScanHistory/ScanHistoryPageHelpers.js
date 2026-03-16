const BasePage = require('../../_utils/BasePage');
const { testConfig } = require('../../_utils/test-config');

class ScanHistoryPageHelpers extends BasePage {
  constructor(page) {
    super(page);
    this.selectors = {
      pageTitle: "h4:has-text('Scan History')",
      subtitle: "text=Click on a scan to expand",
      dataGrid: '.MuiDataGrid-root',
      dataGridRows: '.MuiDataGrid-row',
      dataGridColumnHeaders: '.MuiDataGrid-columnHeader',
      pagination: '.MuiTablePagination-root',
      // Status chips in rows
      statusChip: '.MuiDataGrid-row .MuiChip-root',
      // MUI DataGrid detail panel expand toggle
      detailPanelToggle: '.MuiDataGrid-row [aria-label="Expand"]',
      // Export button (MUI DataGrid toolbar)
      exportButton: "button[aria-label='Export']",
      // Expanded detail content
      detailPanel: '.MuiDataGrid-detailPanel',
      detailSummaryChips: '.MuiDataGrid-detailPanel .MuiChip-root',
      detailDataGrid: '.MuiDataGrid-detailPanel .MuiDataGrid-root',
      detailDataGridColumns: '.MuiDataGrid-detailPanel .MuiDataGrid-columnHeader',
      detailDataGridRows: '.MuiDataGrid-detailPanel .MuiDataGrid-row',
      // Empty state
      emptyStateMessage: "text=No scan history available"
    };
  }

  async navigateToHistoryPage() {
    await this.goto(testConfig.pages.history);
    // Wait for dynamic content to load
    await this.page.waitForTimeout(3000);
  }

  async getPageTitle() {
    return await this.getText(this.selectors.pageTitle);
  }

  async isSubtitleVisible() {
    return await this.isElementVisible(this.selectors.subtitle);
  }

  async isDataGridVisible() {
    return await this.isElementVisible(this.selectors.dataGrid);
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

  async getRowCount() {
    await this.waitForElement(this.selectors.dataGrid);
    return await this.page.locator(this.selectors.dataGridRows).count();
  }

  async getRowChipTexts(rowIndex) {
    const row = this.page.locator(this.selectors.dataGridRows).nth(rowIndex);
    const chips = row.locator('.MuiChip-root');
    const count = await chips.count();
    const texts = [];
    for (let i = 0; i < count; i++) {
      texts.push((await chips.nth(i).textContent()).trim());
    }
    return texts;
  }

  async expandRow(rowIndex) {
    // MUI DataGrid with LoadDetailContent uses an expand toggle button per row
    const row = this.page.locator(this.selectors.dataGridRows).nth(rowIndex);
    // Try the detail panel toggle button first
    const toggle = row.locator('[aria-label="Expand"], [aria-label="expand row"]');
    const toggleCount = await toggle.count();
    if (toggleCount > 0) {
      await toggle.first().click();
    } else {
      // Fallback: click the row itself
      await row.click();
    }
    // Wait for detail panel to render (server-side content load)
    await this.page.waitForTimeout(3000);
  }

  async isDetailPanelVisible() {
    return await this.isElementVisible(this.selectors.detailPanel);
  }

  async getDetailSummaryChipTexts() {
    const chips = this.page.locator(this.selectors.detailSummaryChips);
    const count = await chips.count();
    const texts = [];
    for (let i = 0; i < count; i++) {
      texts.push((await chips.nth(i).textContent()).trim());
    }
    return texts;
  }

  async isDetailDataGridVisible() {
    return await this.isElementVisible(this.selectors.detailDataGrid);
  }

  async getDetailColumnHeaders() {
    const headers = this.page.locator(this.selectors.detailDataGridColumns);
    const count = await headers.count();
    const texts = [];
    for (let i = 0; i < count; i++) {
      const text = (await headers.nth(i).textContent()).trim();
      if (text.length > 0) texts.push(text);
    }
    return texts;
  }

  async getDetailRowCount() {
    return await this.page.locator(this.selectors.detailDataGridRows).count();
  }

  async isPaginationVisible() {
    return await this.isElementVisible(this.selectors.pagination);
  }

  async isExportButtonVisible() {
    return await this.isElementVisible(this.selectors.exportButton);
  }

  async openExportMenu() {
    await this.click(this.selectors.exportButton);
    await this.page.waitForTimeout(1000);
  }

  async getExportMenuItems() {
    const items = this.page.locator('[role="menuitem"]');
    const count = await items.count();
    const texts = [];
    for (let i = 0; i < count; i++) {
      texts.push((await items.nth(i).textContent()).trim());
    }
    return texts;
  }

  async isEmptyStateVisible() {
    return await this.isElementVisible(this.selectors.emptyStateMessage);
  }

  async hasScanData() {
    const gridVisible = await this.isElementVisible(this.selectors.dataGrid);
    if (!gridVisible) return false;
    const rowCount = await this.page.locator(this.selectors.dataGridRows).count();
    return rowCount > 0;
  }

  async findCompletedRowIndex() {
    // Find the first row with a "Completed" status chip (skip Running/Failed rows)
    const rows = this.page.locator(this.selectors.dataGridRows);
    const count = await rows.count();
    for (let i = 0; i < count; i++) {
      const chips = await this.getRowChipTexts(i);
      if (chips.includes('Completed')) return i;
    }
    return -1;
  }
}

module.exports = ScanHistoryPageHelpers;
