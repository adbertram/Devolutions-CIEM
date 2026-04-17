const BasePage = require('../../_utils/BasePage');
const { testConfig } = require('../../_utils/test-config');

class AttackPathsPageHelpers extends BasePage {
  constructor(page) {
    super(page);
    this.selectors = {
      pageTitle: "h4:has-text('Attack Paths')",
      subtitle: "text=Discovered attack paths",
      dataGrid: '.MuiDataGrid-root',
      dataGridRows: '.MuiDataGrid-row',
      dataGridColumnHeaders: '.MuiDataGrid-columnHeader',
      detailPanelToggle: '.MuiDataGrid-row [aria-label="Expand"], .MuiDataGrid-row [aria-label="expand row"]',
      detailPanel: '.MuiDataGrid-detailPanel',
      remediationBlock: '.MuiDataGrid-detailPanel [data-ciem-attack-path-remediation="true"]',
      remediationScriptBlock: '.MuiDataGrid-detailPanel [data-ciem-attack-path-remediation-script="true"]',
      remediationScriptCopyButton: '.MuiDataGrid-detailPanel [data-ciem-attack-path-remediation-script-copy="true"] a',
      remediationScriptCopyIdle: '.MuiDataGrid-detailPanel [data-ciem-copy-idle="true"]',
      remediationScriptCopySuccess: '.MuiDataGrid-detailPanel [data-ciem-copy-success="true"]',
      refreshButton: 'button:has-text("Refresh Attack Paths")',
      refreshSuccessToast: '.iziToast:has-text("Attack paths refreshed")',
      pagination: '.MuiTablePagination-root',
      severityChip: '.MuiDataGrid-row .MuiChip-root',
      quickFilter: '.MuiDataGrid-toolbarQuickFilter input',
      emptyStateMessage: "text=No attack path data available"
    };
  }

  async navigateToAttackPathsPage() {
    await this.goto(testConfig.pages.attackPaths);
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

  async hasAttackPathData() {
    const gridVisible = await this.isElementVisible(this.selectors.dataGrid);
    if (!gridVisible) return false;
    const rowCount = await this.page.locator(this.selectors.dataGridRows).count();
    return rowCount > 0;
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

  async expandFirstRow() {
    await this.waitForElement(this.selectors.dataGrid);
    const row = this.page.locator(this.selectors.dataGridRows).first();
    const toggle = row.locator('[aria-label="Expand"], [aria-label="expand row"]');
    const toggleCount = await toggle.count();
    if (toggleCount > 0) {
      await toggle.first().click();
    } else {
      await row.click();
    }

    await this.page.locator(this.selectors.detailPanel).waitFor({ state: 'visible' });
    await this.page.locator(this.selectors.remediationBlock).waitFor({ state: 'visible' });
    await this.page.locator(this.selectors.remediationScriptBlock).waitFor({ state: 'visible' });
  }

  async isRemediationBlockVisible() {
    return await this.isElementVisible(this.selectors.remediationBlock);
  }

  async getRemediationText() {
    return (await this.page.locator(this.selectors.remediationBlock).textContent()).trim();
  }

  async isRemediationScriptBlockVisible() {
    return await this.isElementVisible(this.selectors.remediationScriptBlock);
  }

  async getRemediationScriptText() {
    return (await this.page.locator(this.selectors.remediationScriptBlock).textContent()).trim();
  }

  async isRemediationScriptCopyButtonVisible() {
    return await this.isElementVisible(this.selectors.remediationScriptCopyButton);
  }

  async isRemediationScriptCopyIdleVisible() {
    return await this.isElementVisible(this.selectors.remediationScriptCopyIdle);
  }

  async isRemediationScriptCopySuccessVisible() {
    return await this.isElementVisible(this.selectors.remediationScriptCopySuccess);
  }

  async copyRemediationScriptToClipboard() {
    await this.page.locator(this.selectors.remediationScriptCopyButton).click();
  }

  async getClipboardText() {
    return await this.page.evaluate(() => navigator.clipboard.readText());
  }

  async isRefreshButtonVisible() {
    return await this.isElementVisible(this.selectors.refreshButton);
  }

  async refreshAttackPaths() {
    await this.page.locator(this.selectors.refreshButton).click();
  }

  async isRefreshSuccessToastVisible() {
    return await this.isElementVisible(this.selectors.refreshSuccessToast);
  }

  async isPaginationVisible() {
    return await this.isElementVisible(this.selectors.pagination);
  }

  async isEmptyStateVisible() {
    return await this.isElementVisible(this.selectors.emptyStateMessage);
  }

  async isQuickFilterVisible() {
    return await this.isElementVisible(this.selectors.quickFilter);
  }
}

module.exports = AttackPathsPageHelpers;
