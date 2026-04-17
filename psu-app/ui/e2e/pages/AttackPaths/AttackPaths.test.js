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
    test.beforeAll(() => {
      seedAttackPathsPageData();
      const count = getTestAttackPathNodeCount();
      if (count < 1) {
        throw new Error(`Expected seeded graph nodes, got ${count}`);
      }
      console.log(`[setup:attack-paths-page] Seeded ${count} graph nodes for attack path evaluation`);
    });

    test.afterAll(() => {
      cleanupAttackPathsPageData();
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
      expect(script).toContain('$ErrorActionPreference = \'Stop\'');
      expect(script).toMatch(/az (network nsg rule delete|role assignment delete|ad group member remove)/);
      expect(script).not.toContain('{{');
    });

    test('should copy remediation script when the script copy icon is clicked', async () => {
      const hasData = await attackPage.hasAttackPathData();
      expect(hasData).toBe(true);
      await attackPage.expandFirstRow();
      expect(await attackPage.isRemediationScriptCopyButtonVisible()).toBe(true);
      expect(await attackPage.isRemediationScriptCopyIdleVisible()).toBe(true);
      expect(await attackPage.isRemediationScriptCopySuccessVisible()).toBe(false);
      const script = await attackPage.getRemediationScriptText();
      await attackPage.copyRemediationScriptToClipboard();
      await expect.poll(async () => await attackPage.isRemediationScriptCopySuccessVisible()).toBe(true);
      await expect.poll(async () => await attackPage.getClipboardText()).toBe(script);
    });
  });
});
