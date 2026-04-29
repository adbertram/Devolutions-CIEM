const BasePage = require('../../_utils/BasePage');
const {
  getVisibleColumnHeaders,
  navigateToRegisteredPage
} = require('../../_utils/page-contract');

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
    await navigateToRegisteredPage(this, 'Scan History');
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
    return await getVisibleColumnHeaders(this.page, this.selectors.dataGridColumnHeaders);
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
    const row = this.page.locator(this.selectors.dataGridRows).nth(rowIndex);
    const toggle = row.locator('[aria-label="Expand"], [aria-label="expand row"]');
    await toggle.first().waitFor({ state: 'visible', timeout: 15000 });
    await toggle.first().click();
    await this.page.locator(this.selectors.detailPanel).waitFor({ state: 'visible', timeout: 15000 });
  }

  async isDetailPanelVisible() {
    return await this.isElementVisible(this.selectors.detailPanel);
  }

  async getDetailSummaryChipTexts() {
    const chips = this.page.locator(this.selectors.detailSummaryChips);
    await chips.first().waitFor({ state: 'visible', timeout: 15000 });
    const count = await chips.count();
    const texts = [];
    for (let i = 0; i < count; i++) {
      texts.push((await chips.nth(i).textContent()).trim());
    }
    return texts;
  }

  async isDetailDataGridVisible() {
    await this.page.locator(this.selectors.detailDataGrid).waitFor({ state: 'visible', timeout: 15000 });
    return await this.isElementVisible(this.selectors.detailDataGrid);
  }

  async getDetailColumnHeaders() {
    await this.page.locator(this.selectors.detailDataGrid).waitFor({ state: 'visible', timeout: 15000 });
    return await getVisibleColumnHeaders(this.page, this.selectors.detailDataGridColumns);
  }

  async getDetailRowCount() {
    await this.page.locator(this.selectors.detailDataGridRows).first().waitFor({ state: 'visible', timeout: 15000 });
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
    await this.page.locator('[role="menuitem"]').first().waitFor({ state: 'visible', timeout: 15000 });
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
