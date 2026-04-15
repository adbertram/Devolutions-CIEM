const BasePage = require('../../_utils/BasePage');
const { testConfig } = require('../../_utils/test-config');

class IdentitiesPageHelpers extends BasePage {
  constructor(page) {
    super(page);
    this.selectors = {
      pageTitle: "h4:has-text('Identities')",
      subtitle: "text=Explore identities and the effective actions",
      dataGrid: '.MuiDataGrid-root',
      dataGridRows: '.MuiDataGrid-row',
      dataGridColumnHeaders: '.MuiDataGrid-columnHeader',
      detailPanelToggle: '.MuiDataGrid-row [aria-label="Expand"], .MuiDataGrid-row [aria-label="expand row"]',
      detailPanel: '.MuiDataGrid-detailPanel',
      canDoCell: '.MuiDataGrid-cell[data-field="actions"]',
      quickFilter: '.MuiDataGrid-toolbarQuickFilter input',
      targetCell: '.MuiDataGrid-cell[data-field="target"]',
      targetIcon: 'img[data-ciem-resource-icon="target"]',
      pagination: '.MuiTablePagination-root'
    };
  }

  async navigateToIdentitiesPage() {
    await this.goto(testConfig.pages.identities);
    await this.page.waitForTimeout(3000);
  }

  async getPageTitle() {
    return await this.getText(this.selectors.pageTitle);
  }

  async hasData() {
    const gridVisible = await this.isElementVisible(this.selectors.dataGrid);
    if (!gridVisible) return false;
    return (await this.page.locator(this.selectors.dataGridRows).count()) > 0;
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

  async filterRows(text) {
    const quickFilter = this.page.locator(this.selectors.quickFilter);
    await quickFilter.waitFor({ state: 'visible' });
    await quickFilter.fill(text);
  }

  getTargetRow(targetName) {
    return this.page.locator(this.selectors.dataGridRows, { hasText: targetName }).first();
  }

  getTargetCell(targetName) {
    return this.getTargetRow(targetName).locator(this.selectors.targetCell);
  }

  async targetCellHasResourceIcon(targetName) {
    const targetCell = this.getTargetCell(targetName);
    await targetCell.waitFor({ state: 'visible' });
    return await targetCell.locator(this.selectors.targetIcon).count() === 1;
  }

  async targetRowHasCanDoDescription(targetName, description) {
    const row = this.getTargetRow(targetName);
    await row.waitFor({ state: 'visible' });
    return await row.locator(this.selectors.canDoCell, { hasText: description }).count() > 0;
  }

  async expandTargetRow(targetName) {
    const row = this.getTargetRow(targetName);
    await row.waitFor({ state: 'visible' });
    const toggle = row.locator('[aria-label="Expand"], [aria-label="expand row"]');
    const toggleCount = await toggle.count();
    if (toggleCount > 0) {
      await toggle.first().click();
    } else {
      await row.click();
    }
    await this.page.locator(this.selectors.detailPanel).waitFor({ state: 'visible' });
    await this.page.locator(this.selectors.detailPanel, { hasText: 'Entitlement Path' }).waitFor({ state: 'visible' });
  }

  async isDetailSectionVisible(sectionName) {
    return await this.hasDetailText(sectionName);
  }

  async hasDetailText(text) {
    return await this.page.locator(this.selectors.detailPanel, { hasText: text }).count() > 0;
  }
}

module.exports = IdentitiesPageHelpers;
