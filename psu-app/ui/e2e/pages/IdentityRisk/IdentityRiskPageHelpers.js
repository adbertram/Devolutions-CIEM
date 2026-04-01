const BasePage = require('../../_utils/BasePage');
const { testConfig } = require('../../_utils/test-config');

class IdentityRiskPageHelpers extends BasePage {
  constructor(page) {
    super(page);
    this.selectors = {
      pageTitle: "h4:has-text('Identities')",
      subtitle: "text=Drill down from identity",
      dataGrid: '.MuiDataGrid-root',
      dataGridRows: '.MuiDataGrid-row',
      dataGridColumnHeaders: '.MuiDataGrid-columnHeader',
      pagination: '.MuiTablePagination-root',
      // Risk level chips in rows
      riskChip: '.MuiDataGrid-row .MuiChip-root',
      // MUI DataGrid detail panel
      detailPanelToggle: '.MuiDataGrid-row [aria-label="Expand"], .MuiDataGrid-row [aria-label="expand row"]',
      detailPanel: '.MuiDataGrid-detailPanel',
      entitlementsHeading: '.MuiDataGrid-detailPanel h6:has-text("Entitlements")',
      riskSignalsHeading: '.MuiDataGrid-detailPanel h6:has-text("Risk Signals")',
      attackPathsHeading: '.MuiDataGrid-detailPanel h6:has-text("Attack Paths")',
      attackPathChip: '.MuiDataGrid-detailPanel h6:has-text("Attack Paths") ~ div .MuiChip-root, .MuiDataGrid-detailPanel h6:has-text("Attack Paths") + div .MuiChip-root',
      noAttackPathsMessage: '.MuiDataGrid-detailPanel:has-text("No attack paths detected.")',
      detailDataGrid: '.MuiDataGrid-detailPanel .MuiDataGrid-root',
      // Empty state
      emptyStateMessage: "text=No identity data available"
    };
  }

  async navigateToIdentityRiskPage() {
    await this.goto(testConfig.pages.identities);
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

  async expandRow(rowIndex) {
    const row = this.page.locator(this.selectors.dataGridRows).nth(rowIndex);
    const toggle = row.locator('[aria-label="Expand"], [aria-label="expand row"]');
    const toggleCount = await toggle.count();
    if (toggleCount > 0) {
      await toggle.first().click();
    } else {
      await row.click();
    }
    await this.page.waitForTimeout(3000);
  }

  async isDetailPanelVisible() {
    return await this.isElementVisible(this.selectors.detailPanel);
  }

  async areDetailSectionsVisible() {
    const entitlements = await this.isElementVisible(this.selectors.entitlementsHeading);
    const riskSignals = await this.isElementVisible(this.selectors.riskSignalsHeading);
    return entitlements && riskSignals;
  }

  async isAttackPathsSectionVisible() {
    return await this.isElementVisible(this.selectors.attackPathsHeading);
  }

  async hasAttackPathFindings() {
    const noFindings = await this.isElementVisible(this.selectors.noAttackPathsMessage);
    return !noFindings;
  }

  async isPaginationVisible() {
    return await this.isElementVisible(this.selectors.pagination);
  }

  async isEmptyStateVisible() {
    return await this.isElementVisible(this.selectors.emptyStateMessage);
  }

  async hasIdentityData() {
    const gridVisible = await this.isElementVisible(this.selectors.dataGrid);
    if (!gridVisible) return false;
    const rowCount = await this.page.locator(this.selectors.dataGridRows).count();
    return rowCount > 0;
  }

  async getRiskChipTexts() {
    const chips = this.page.locator(this.selectors.riskChip);
    const count = await chips.count();
    const texts = [];
    for (let i = 0; i < count; i++) {
      texts.push((await chips.nth(i).textContent()).trim());
    }
    return texts;
  }
}

module.exports = IdentityRiskPageHelpers;
