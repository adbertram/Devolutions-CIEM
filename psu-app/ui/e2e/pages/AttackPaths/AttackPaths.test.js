const { test, expect } = require('../../_utils/BaseTestSetup');
const AttackPathsPageHelpers = require('./AttackPathsPageHelpers');
const { seedAttackPathsPageData, cleanupAttackPathsPageData, getTestAttackPathNodeCount } = require('../../_utils/cleanup');

test.describe('Attack Paths Page', () => {
  let attackPage;

  test.beforeEach(async ({ ciemPage }) => {
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
  });
});
