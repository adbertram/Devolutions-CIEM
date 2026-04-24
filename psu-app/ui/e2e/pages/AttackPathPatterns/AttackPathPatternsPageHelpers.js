const BasePage = require('../../_utils/BasePage');
const { testConfig } = require('../../_utils/test-config');

class AttackPathPatternsPageHelpers extends BasePage {
  constructor(page) {
    super(page);
    this.selectors = {
      pageTitle: "h4:has-text('Attack Path Patterns')",
      subtitle: "text=Catalog of attack path patterns",
      dataGrid: '.MuiDataGrid-root',
      dataGridRows: '.MuiDataGrid-row',
      dataGridColumnHeaders: '.MuiDataGrid-columnHeader',
      detailPanel: '.MuiDataGrid-detailPanel',
      descriptionBlock: '.MuiDataGrid-detailPanel [data-ciem-attack-path-pattern-description="true"]',
      pagination: '.MuiTablePagination-root',
      severityChip: '.MuiDataGrid-row .MuiChip-root',
      quickFilter: '.MuiDataGrid-toolbarQuickFilter input',
      emptyStateMessage: "text=No attack path patterns found"
    };
  }

  async navigateToAttackPathPatternsPage() {
    await this.goto(testConfig.pages.attackPathPatterns);
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

  async hasData() {
    const gridVisible = await this.isElementVisible(this.selectors.dataGrid);
    if (!gridVisible) return false;
    return (await this.page.locator(this.selectors.dataGridRows).count()) > 0;
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

  // Returns the severity value from the row at the given index (0-based).
  async getRowSeverity(rowIndex) {
    const rows = this.page.locator(this.selectors.dataGridRows);
    const row = rows.nth(rowIndex);
    const chip = row.locator('.MuiChip-root').first();
    return (await chip.textContent()).trim();
  }

  async getPatternRowText(patternName) {
    await this.waitForElement(this.selectors.dataGrid);
    const row = this.page.locator(this.selectors.dataGridRows).filter({ hasText: patternName }).first();
    await row.waitFor({ state: 'visible' });
    return (await row.textContent()).trim();
  }

  async expandPattern(patternName) {
    await this.waitForElement(this.selectors.dataGrid);
    const row = this.page.locator(this.selectors.dataGridRows).filter({ hasText: patternName }).first();
    await row.waitFor({ state: 'visible' });
    await row.getByRole('button', { name: /^Expand$/i }).click();
    await this.page.locator(this.selectors.detailPanel).waitFor({ state: 'visible' });
    await this.page.locator(this.selectors.descriptionBlock).waitFor({ state: 'visible' });
  }

  async isDetailHeadingVisible(heading) {
    return await this.page.locator(this.selectors.detailPanel).getByText(heading, { exact: true }).isVisible();
  }

  async getDescriptionText() {
    return (await this.page.locator(this.selectors.descriptionBlock).textContent()).trim();
  }

  async isPaginationVisible() {
    return await this.isElementVisible(this.selectors.pagination);
  }

  async isQuickFilterVisible() {
    return await this.isElementVisible(this.selectors.quickFilter);
  }

  async isEmptyStateVisible() {
    return await this.isElementVisible(this.selectors.emptyStateMessage);
  }
}

module.exports = AttackPathPatternsPageHelpers;
