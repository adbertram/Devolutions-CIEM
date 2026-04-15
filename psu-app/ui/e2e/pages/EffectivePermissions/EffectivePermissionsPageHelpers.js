const BasePage = require('../../_utils/BasePage');
const { testConfig } = require('../../_utils/test-config');

class EffectivePermissionsPageHelpers extends BasePage {
  constructor(page) {
    super(page);
    this.selectors = {
      pageTitle: "h4:has-text('Effective Permissions')",
      subtitle: "text=Explore who can perform which effective actions",
      dataGrid: '.MuiDataGrid-root',
      dataGridRows: '.MuiDataGrid-row',
      targetCell: '.MuiDataGrid-row .MuiDataGrid-cell[data-field="target"]',
      targetIcon: 'img[data-ciem-resource-icon="target"]',
      pagination: '.MuiTablePagination-root'
    };
  }

  async navigateToEffectivePermissionsPage() {
    await this.goto(testConfig.pages.effectivePermissions);
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

  async getTargetCell(targetName) {
    return this.page.locator(this.selectors.targetCell, { hasText: targetName }).first();
  }

  async targetCellHasResourceIcon(targetName) {
    const targetCell = await this.getTargetCell(targetName);
    await targetCell.waitFor({ state: 'visible' });
    return await targetCell.locator(this.selectors.targetIcon).count() === 1;
  }
}

module.exports = EffectivePermissionsPageHelpers;
