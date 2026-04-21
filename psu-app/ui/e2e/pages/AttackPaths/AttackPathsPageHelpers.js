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
      remediationScriptActions: '.MuiDataGrid-detailPanel [data-ciem-attack-path-remediation-script-actions="true"]',
      remediationScriptCopyButton: '.MuiDataGrid-detailPanel [data-ciem-attack-path-remediation-script-copy="true"] a',
      remediationScriptExecuteButton: '.MuiDataGrid-detailPanel [data-ciem-attack-path-remediation-script-execute="true"] button',
      remediationScriptCopyIdle: '.MuiDataGrid-detailPanel [data-ciem-copy-idle="true"]',
      remediationScriptCopySuccess: '.MuiDataGrid-detailPanel [data-ciem-copy-success="true"]',
      executionDialog: '[data-ciem-attack-path-execution-dialog="true"]',
      executionScript: '[data-ciem-attack-path-execution-script="true"]',
      executionStreams: '[data-ciem-attack-path-execution-streams="true"] textarea:not([aria-hidden="true"])',
      executionCloseButton: '[data-ciem-attack-path-execution-close="true"] button',
      executionTerminateButton: '[data-ciem-attack-path-execution-terminate="true"] button',
      executionCloseWarning: '[data-ciem-attack-path-execution-close-warning="true"]',
      executionWarningTerminateButton: '[data-ciem-attack-path-execution-warning-terminate="true"] button',
      executionLeaveRunningButton: '[data-ciem-attack-path-execution-leave-running="true"] button',
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
    await this.page.waitForFunction((selector) => {
      const element = document.querySelector(selector);
      return element && element.textContent.trim().length > 0;
    }, this.selectors.remediationScriptBlock);
  }

  async clickAttackPath(patternName) {
    await this.waitForElement(this.selectors.dataGrid);
    const row = this.page.locator(this.selectors.dataGridRows).filter({ hasText: patternName }).first();
    await row.waitFor({ state: 'visible' });
    await row.getByRole('gridcell', { name: patternName }).click();
    await row.getByRole('button', { name: /^Expand$/i }).click();

    await this.page.locator(this.selectors.detailPanel).waitFor({ state: 'visible' });
    await this.page.locator(this.selectors.remediationBlock).waitFor({ state: 'visible' });
    await this.page.locator(this.selectors.remediationScriptBlock).waitFor({ state: 'visible' });
    await this.page.waitForFunction((selector) => {
      const element = document.querySelector(selector);
      return element && element.textContent.trim().length > 0;
    }, this.selectors.remediationScriptBlock);
  }

  async isDetailHeadingVisible(heading) {
    return await this.page.locator(this.selectors.detailPanel).getByText(heading, { exact: true }).isVisible();
  }

  async getDetailPanelText() {
    return (await this.page.locator(this.selectors.detailPanel).textContent()).trim();
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

  async getRemediationScriptActionButtonMetrics() {
    return await this.page.evaluate(({ actionsSelector, copySelector, executeSelector }) => {
      const actions = document.querySelector(actionsSelector);
      const copy = document.querySelector(copySelector);
      const execute = document.querySelector(executeSelector);
      if (!actions || !copy || !execute) {
        throw new Error('Remediation script action buttons were not rendered.');
      }

      const actionsBox = actions.getBoundingClientRect();
      const copyBox = copy.getBoundingClientRect();
      const executeBox = execute.getBoundingClientRect();
      const actionsStyle = window.getComputedStyle(actions);
      const copyStyle = window.getComputedStyle(copy);
      const executeStyle = window.getComputedStyle(execute);

      return {
        actions: {
          display: actionsStyle.getPropertyValue('display'),
          alignItems: actionsStyle.getPropertyValue('align-items'),
          gap: actionsStyle.getPropertyValue('gap'),
          y: actionsBox.y,
          height: actionsBox.height
        },
        copy: {
          x: copyBox.x,
          y: copyBox.y,
          width: copyBox.width,
          height: copyBox.height,
          borderRadius: copyStyle.borderRadius,
          borderTopWidth: copyStyle.borderTopWidth,
          borderTopStyle: copyStyle.borderTopStyle,
          backgroundColor: copyStyle.backgroundColor,
          color: copyStyle.color,
          fontSize: copyStyle.fontSize,
          fontWeight: copyStyle.fontWeight
        },
        execute: {
          x: executeBox.x,
          y: executeBox.y,
          width: executeBox.width,
          height: executeBox.height,
          borderRadius: executeStyle.borderRadius,
          borderTopWidth: executeStyle.borderTopWidth,
          borderTopStyle: executeStyle.borderTopStyle,
          backgroundColor: executeStyle.backgroundColor,
          color: executeStyle.color,
          fontSize: executeStyle.fontSize,
          fontWeight: executeStyle.fontWeight
        }
      };
    }, {
      actionsSelector: this.selectors.remediationScriptActions,
      copySelector: this.selectors.remediationScriptCopyButton,
      executeSelector: this.selectors.remediationScriptExecuteButton
    });
  }

  async isRemediationScriptExecuteButtonVisible() {
    return await this.isElementVisible(this.selectors.remediationScriptExecuteButton);
  }

  async executeRemediationScript() {
    await this.page.locator(this.selectors.remediationScriptExecuteButton).click();
  }

  async isExecutionDialogVisible() {
    return await this.isElementVisible(this.selectors.executionDialog);
  }

  async getExecutionScriptText() {
    return (await this.page.locator(this.selectors.executionScript).textContent()).trim();
  }

  async isExecutionStreamsVisible() {
    return await this.isElementVisible(this.selectors.executionStreams);
  }

  async getExecutionStreamsText() {
    return await this.page.locator(this.selectors.executionStreams).inputValue();
  }

  async closeExecutionDialog() {
    await this.page.locator(this.selectors.executionCloseButton).click();
  }

  async terminateExecution() {
    await this.page.locator(this.selectors.executionTerminateButton).click();
  }

  async terminateExecutionFromWarning() {
    await this.page.locator(this.selectors.executionWarningTerminateButton).click();
  }

  async isExecutionCloseWarningVisible() {
    return await this.isElementVisible(this.selectors.executionCloseWarning);
  }

  async isExecutionLeaveRunningButtonVisible() {
    return await this.isElementVisible(this.selectors.executionLeaveRunningButton);
  }

  async leaveExecutionRunning() {
    await this.page.locator(this.selectors.executionLeaveRunningButton).click();
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
