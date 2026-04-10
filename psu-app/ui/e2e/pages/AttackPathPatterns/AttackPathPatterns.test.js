const { test, expect } = require('../../_utils/BaseTestSetup');
const AttackPathPatternsPageHelpers = require('./AttackPathPatternsPageHelpers');

test.describe('Attack Path Patterns Page', () => {
  let patternsPage;

  test.beforeEach(async ({ ciemPage }) => {
    patternsPage = new AttackPathPatternsPageHelpers(ciemPage);
    await patternsPage.navigateToAttackPathPatternsPage();
  });

  // No seeding — the cmdlet reads shipped JSON files, so data is always present
  test.describe('when the page loads', () => {
    test('should display page title', async () => {
      const title = await patternsPage.getPageTitle();
      expect(title).toContain('Attack Path Patterns');
    });

    test('should display subtitle', async () => {
      const visible = await patternsPage.isSubtitleVisible();
      expect(visible).toBe(true);
    });

    test('should display DataGrid with at least 6 shipped patterns', async () => {
      const hasData = await patternsPage.hasData();
      expect(hasData).toBe(true);
      const rowCount = await patternsPage.getRowCount();
      expect(rowCount).toBeGreaterThanOrEqual(6);
    });

    test('should display expected column headers', async () => {
      const headers = await patternsPage.getColumnHeaders();
      expect(headers).toContain('Name');
      expect(headers).toContain('Severity');
      expect(headers).toContain('Category');
      expect(headers).toContain('Description');
      expect(headers).toContain('Steps');
    });

    test('should display severity chips with valid levels', async () => {
      const chipTexts = await patternsPage.getSeverityChipTexts();
      const validLevels = ['critical', 'high', 'medium', 'low'];
      const hasValidChip = chipTexts.some(t => validLevels.includes(t));
      expect(hasValidChip).toBe(true);
    });

    test('should sort rows critical-first (row 0 has critical severity)', async () => {
      const firstRowSeverity = await patternsPage.getRowSeverity(0);
      expect(firstRowSeverity).toBe('critical');
    });

    test('should render severity column in monotonic rank order', async () => {
      // Map severity → rank (matches severity_catalog.json)
      const rankByName = { critical: 1, high: 2, medium: 3, low: 4, info: 5 };
      const chipTexts = await patternsPage.getSeverityChipTexts();
      // Only consider chips inside grid rows (getSeverityChipTexts targets .MuiDataGrid-row .MuiChip-root)
      const ranks = chipTexts.map(t => rankByName[t] ?? 999);
      for (let i = 1; i < ranks.length; i++) {
        expect(ranks[i]).toBeGreaterThanOrEqual(ranks[i - 1]);
      }
    });

    test('should display pagination controls', async () => {
      const paginationVisible = await patternsPage.isPaginationVisible();
      expect(paginationVisible).toBe(true);
    });

    test('should display quick filter', async () => {
      const filterVisible = await patternsPage.isQuickFilterVisible();
      expect(filterVisible).toBe(true);
    });
  });
});
