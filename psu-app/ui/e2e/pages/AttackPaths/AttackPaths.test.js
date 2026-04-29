const { test, expect } = require('../../_utils/BaseTestSetup');
const AttackPathsPageHelpers = require('./AttackPathsPageHelpers');
const {
  seedAttackPathsPageData,
  seedAttackPathsRefreshGraphData,
  backupAndClearAttackPathGraphData,
  restoreAttackPathGraphData,
  cleanupAttackPathsPageData,
  getTestAttackPathNodeCount,
  getTestAttackPathCount
} = require('../../_utils/cleanup');
const {
  registerLongRunningAttackPathRemediationScript,
  removeLongRunningAttackPathRemediationScript
} = require('../../_utils/psu-helpers');

test.describe('Attack Paths Page', () => {
  let attackPage;

  test.beforeEach(async ({ ciemPage }) => {
    await ciemPage.addInitScript(() => {
      let clipboardText = '';
      const originalExecCommand = document.execCommand.bind(document);
      document.execCommand = (command) => {
        if (command === 'copy') {
          const activeElement = document.activeElement;
          clipboardText = activeElement && 'value' in activeElement ? activeElement.value : window.getSelection().toString();
          return true;
        }
        return originalExecCommand(command);
      };
      Object.defineProperty(navigator, 'clipboard', {
        value: {
          writeText: async (value) => { clipboardText = value; },
          readText: async () => clipboardText
        },
        configurable: true
      });
    });
    attackPage = new AttackPathsPageHelpers(ciemPage);
    await attackPage.navigateToAttackPathsPage();
  });

  test.describe('when the page loads', () => {
    test('should display page title', async () => {
      const title = await attackPage.getPageTitle();
      expect(title).toContain('Attack Paths');
    });

    test('should display subtitle', async () => {
      const visible = await attackPage.isSubtitleVisible();
      expect(visible).toBe(true);
    });

    test('should display refresh button', async () => {
      const visible = await attackPage.isRefreshButtonVisible();
      expect(visible).toBe(true);
    });
  });

  test.describe('when graph data exists without materialized attack paths', () => {
    let graphBackup;

    test.beforeAll(() => {
      graphBackup = backupAndClearAttackPathGraphData();
      seedAttackPathsRefreshGraphData();
      const nodeCount = getTestAttackPathNodeCount();
      if (nodeCount !== 1) {
        throw new Error(`Expected 1 seeded attack path graph node, got ${nodeCount}`);
      }
      const attackPathCount = getTestAttackPathCount();
      if (attackPathCount !== 0) {
        throw new Error(`Expected no materialized test attack paths, got ${attackPathCount}`);
      }
      console.log('[setup:attack-paths-refresh] Seeded graph data without materialized attack paths');
    });

    test.afterAll(() => {
      restoreAttackPathGraphData(graphBackup);
      console.log('[teardown:attack-paths-refresh] Cleaned up refresh test graph data');
    });

    test('should materialize attack paths and reload the table when Refresh Attack Paths is clicked', async () => {
      await attackPage.refreshAttackPaths();
      await expect.poll(() => getTestAttackPathCount()).toBeGreaterThanOrEqual(1);
      await expect.poll(async () => await attackPage.isRefreshSuccessToastVisible()).toBe(true);
      await expect.poll(async () => await attackPage.hasAttackPathData()).toBe(true);
    });
  });

  test.describe('when attack path data exists in the graph', () => {
    let graphBackup;

    test.beforeAll(() => {
      registerLongRunningAttackPathRemediationScript();
      graphBackup = backupAndClearAttackPathGraphData();
      seedAttackPathsPageData();
      const count = getTestAttackPathNodeCount();
      if (count < 1) {
        throw new Error(`Expected seeded graph nodes, got ${count}`);
      }
      console.log(`[setup:attack-paths-page] Seeded ${count} graph nodes for attack path evaluation`);
    });

    test.afterAll(() => {
      cleanupAttackPathsPageData();
      if (graphBackup) {
        restoreAttackPathGraphData(graphBackup);
      }
      removeLongRunningAttackPathRemediationScript();
      console.log('[teardown:attack-paths-page] Cleaned up graph data');
    });

    test('should display DataGrid with at least 1 row', async () => {
      const hasData = await attackPage.hasAttackPathData();
      expect(hasData).toBe(true);
      const rowCount = await attackPage.getRowCount();
      expect(rowCount).toBeGreaterThanOrEqual(1);
    });

    test('should display expected column headers', async () => {
      const hasData = await attackPage.hasAttackPathData();
      expect(hasData).toBe(true);
      const headers = await attackPage.getColumnHeaders();
      expect(headers).toContain('Pattern Name');
      expect(headers).toContain('Severity');
      expect(headers).toContain('Category');
      expect(headers).toContain('Path Chain');
      expect(headers).toContain('Steps');
    });

    test('should display severity chips with valid levels', async () => {
      const hasData = await attackPage.hasAttackPathData();
      expect(hasData).toBe(true);
      const chipTexts = await attackPage.getSeverityChipTexts();
      const validLevels = ['critical', 'high', 'medium', 'low'];
      const hasValidChip = chipTexts.some(t => validLevels.includes(t));
      expect(hasValidChip).toBe(true);
    });

    test('should display pagination controls', async () => {
      const hasData = await attackPage.hasAttackPathData();
      expect(hasData).toBe(true);
      const paginationVisible = await attackPage.isPaginationVisible();
      expect(paginationVisible).toBe(true);
    });

    test('should display quick filter', async () => {
      const hasData = await attackPage.hasAttackPathData();
      expect(hasData).toBe(true);
      const filterVisible = await attackPage.isQuickFilterVisible();
      expect(filterVisible).toBe(true);
    });

    test('should show attack path details when an attack path is clicked', async () => {
      await expect.poll(async () => await attackPage.hasAttackPathData()).toBe(true);

      await attackPage.clickAttackPath('Management port open to the internet');

      expect(await attackPage.isDetailHeadingVisible('Remediation')).toBe(true);
      expect(await attackPage.isDetailHeadingVisible('Remediation Script')).toBe(true);
      expect(await attackPage.isDetailHeadingVisible('Path Chain')).toBe(true);
      expect(await attackPage.isRemediationBlockVisible()).toBe(true);
      expect(await attackPage.isRemediationScriptBlockVisible()).toBe(true);
      expect(await attackPage.isRemediationScriptCopyButtonVisible()).toBe(true);
      expect(await attackPage.isRemediationScriptExecuteButtonVisible()).toBe(true);

      const detailText = await attackPage.getDetailPanelText();
      expect(detailText).toContain('Internet (Internet)');
      expect(detailText).toContain('E2E Attack Path NSG (AzureNSG)');

      const remediation = await attackPage.getRemediationText();
      expect(remediation).toContain('Restrict or remove the inbound management rule');

      const script = await attackPage.getRemediationScriptText();
      expect(script).toContain('Remediates the attack path finding "Management port open to the internet"');
      expect(script).toContain('Azure REST API');
      expect(script).not.toContain('{{');
    });

    test('should display remediation guidance when an attack path row is expanded', async () => {
      const hasData = await attackPage.hasAttackPathData();
      expect(hasData).toBe(true);
      await attackPage.expandFirstRow();
      expect(await attackPage.isRemediationBlockVisible()).toBe(true);
      const remediation = await attackPage.getRemediationText();
      expect(remediation).toMatch(/^1\./);
      expect(remediation).toContain('rerun Azure discovery');
      expect(await attackPage.isRemediationScriptBlockVisible()).toBe(true);
      const script = await attackPage.getRemediationScriptText();
      expect(script).toMatch(/^<#/);
      expect(script).toContain('.SYNOPSIS');
      expect(script).toContain('.DESCRIPTION');
      expect(script).toContain('Remediates the attack path finding');
      expect(script).toContain('This generated remediation script targets the specific attack path chain below');
      expect(script).toContain('authentication profile');
      expect(script).toContain('Azure REST API');
      expect(script).toContain('Devolutions.CIEM\\Connect-CIEMAzure');
      expect(script).toContain('Devolutions.CIEM\\Invoke-AzureApi');
      expect(script).toContain('$ErrorActionPreference = \'Stop\'');
      expect(script).toMatch(/-Api (ARM|Graph)/);
      expect(script).not.toMatch(/\baz /);
      expect(script).not.toContain('{{');
    });

    test('should copy remediation script when the script copy icon is clicked', async () => {
      const hasData = await attackPage.hasAttackPathData();
      expect(hasData).toBe(true);
      await attackPage.expandFirstRow();
      expect(await attackPage.isRemediationScriptCopyButtonVisible()).toBe(true);
      expect(await attackPage.isRemediationScriptExecuteButtonVisible()).toBe(true);
      expect(await attackPage.isRemediationScriptCopyIdleVisible()).toBe(true);
      expect(await attackPage.isRemediationScriptCopySuccessVisible()).toBe(false);
      const script = await attackPage.getRemediationScriptText();
      await attackPage.copyRemediationScriptToClipboard();
      await expect.poll(async () => await attackPage.isRemediationScriptCopySuccessVisible()).toBe(true);
      await expect.poll(async () => await attackPage.getClipboardText()).toBe(script);
    });

    test('should align remediation script action buttons with matching style', async () => {
      await expect.poll(async () => await attackPage.hasAttackPathData()).toBe(true);
      await attackPage.expandFirstRow();

      const metrics = await attackPage.getRemediationScriptActionButtonMetrics();
      expect(metrics.actions.display).toBe('flex');
      expect(metrics.actions.alignItems).toBe('center');
      expect(metrics.actions.gap).toBe('8px');
      expect(Math.abs(metrics.copy.y - metrics.execute.y)).toBeLessThanOrEqual(1);
      expect(Math.abs(metrics.copy.width - metrics.execute.width)).toBeLessThanOrEqual(1);
      expect(Math.abs(metrics.copy.height - metrics.execute.height)).toBeLessThanOrEqual(1);
      expect(metrics.execute.x).toBeGreaterThan(metrics.copy.x + metrics.copy.width);
      expect(metrics.copy.borderRadius).toBe(metrics.execute.borderRadius);
      expect(metrics.copy.borderTopWidth).toBe(metrics.execute.borderTopWidth);
      expect(metrics.copy.borderTopStyle).toBe(metrics.execute.borderTopStyle);
      expect(metrics.copy.backgroundColor).toBe(metrics.execute.backgroundColor);
      expect(metrics.copy.color).toBe(metrics.execute.color);
      expect(metrics.copy.fontSize).toBe(metrics.execute.fontSize);
      expect(metrics.copy.fontWeight).toBe(metrics.execute.fontWeight);
    });

    test('should show the executing script and realtime streams when the execute button is clicked', async () => {
      await expect.poll(async () => await attackPage.hasAttackPathData()).toBe(true);
      await attackPage.expandFirstRow();
      expect(getTestAttackPathCount()).toBeGreaterThanOrEqual(1);
      const script = await attackPage.getRemediationScriptText();
      await attackPage.executeRemediationScript();
      await expect.poll(async () => await attackPage.isExecutionDialogVisible()).toBe(true);
      expect(getTestAttackPathCount()).toBeGreaterThanOrEqual(1);
      expect(await attackPage.getExecutionScriptText()).toBe(script);
      await expect.poll(async () => await attackPage.isExecutionStreamsVisible()).toBe(true);
      await expect.poll(async () => await attackPage.getExecutionStreamsText()).toContain('Execution started');
      expect(getTestAttackPathCount()).toBeGreaterThanOrEqual(1);
      await attackPage.terminateExecution();
      await expect.poll(async () => await attackPage.isExecutionDialogVisible()).toBe(false);
      expect(getTestAttackPathCount()).toBeGreaterThanOrEqual(1);
    });

    test('should warn before closing while the remediation script is still running', async () => {
      await expect.poll(async () => await attackPage.hasAttackPathData()).toBe(true);
      await attackPage.clickAttackPath('ZZZ Long running remediation fixture');
      await attackPage.executeRemediationScript();
      await expect.poll(async () => await attackPage.isExecutionDialogVisible()).toBe(true);
      await attackPage.closeExecutionDialog();
      await expect.poll(async () => await attackPage.isExecutionCloseWarningVisible()).toBe(true);
      await expect.poll(async () => await attackPage.isExecutionLeaveRunningButtonVisible()).toBe(true);
      await attackPage.terminateExecutionFromWarning();
      await expect.poll(async () => await attackPage.isExecutionDialogVisible()).toBe(false);
    });
  });
});
