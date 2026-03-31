const { test, expect } = require('../../_utils/BaseTestSetup');
const IdentityRiskPageHelpers = require('./IdentityRiskPageHelpers');
const { seedIdentityViewData, cleanupIdentityViewData, getTestEffectiveRoleAssignmentCount } = require('../../_utils/cleanup');

test.describe('Identity Risk Page', () => {
  let riskPage;

  test.beforeEach(async ({ ciemPage }) => {
    riskPage = new IdentityRiskPageHelpers(ciemPage);
    await riskPage.navigateToIdentityRiskPage();
  });

  test.describe('when the page loads', () => {
    test('should display page title', async () => {
      const title = await riskPage.getPageTitle();
      expect(title).toContain('Identities');
    });

    test('should display subtitle with drill-down instruction', async () => {
      const visible = await riskPage.isSubtitleVisible();
      expect(visible).toBe(true);
    });
  });

  test.describe('when identity data exists in the database', () => {
    test.beforeAll(async () => {
      seedIdentityViewData();
      const count = getTestEffectiveRoleAssignmentCount();
      if (count < 1) {
        throw new Error(`Expected seeded identity risk data, got ${count} rows`);
      }
      console.log(`[setup:identity-risk] Seeded ${count} effective role assignments`);
    });

    test.afterAll(async () => {
      cleanupIdentityViewData();
      console.log('[teardown:identity-risk] Cleaned up seeded data');
    });

    test('should display DataGrid with at least 1 row', async () => {
      const hasData = await riskPage.hasIdentityData();
      expect(hasData).toBe(true);
      const rowCount = await riskPage.getRowCount();
      expect(rowCount).toBeGreaterThanOrEqual(1);
    });

    test('should display expected column headers', async () => {
      const hasData = await riskPage.hasIdentityData();
      if (!hasData) {
        test.skip(true, 'No identity data to display columns');
        return;
      }
      const headers = await riskPage.getColumnHeaders();
      expect(headers).toContain('Name');
      expect(headers).toContain('Type');
      expect(headers).toContain('Entitlements');
      expect(headers).toContain('Risk Level');
    });

    test('should display risk level chips', async () => {
      const hasData = await riskPage.hasIdentityData();
      if (!hasData) {
        test.skip(true, 'No identity data to display risk chips');
        return;
      }
      const chipTexts = await riskPage.getRiskChipTexts();
      const validLevels = ['Critical', 'High', 'Medium', 'Low'];
      const hasValidChip = chipTexts.some(t => validLevels.includes(t));
      expect(hasValidChip).toBe(true);
    });

    test('should display pagination controls', async () => {
      const hasData = await riskPage.hasIdentityData();
      if (!hasData) {
        test.skip(true, 'No identity data to display pagination');
        return;
      }
      const paginationVisible = await riskPage.isPaginationVisible();
      expect(paginationVisible).toBe(true);
    });
  });

  test.describe('when an identity row is expanded', () => {
    test.beforeAll(async () => {
      seedIdentityViewData();
    });

    test.afterAll(async () => {
      cleanupIdentityViewData();
    });

    test('should show detail panel with Entitlements and Risk Signals sections', async () => {
      const hasData = await riskPage.hasIdentityData();
      if (!hasData) {
        test.skip(true, 'No identity data to expand');
        return;
      }
      await riskPage.expandRow(0);
      const detailVisible = await riskPage.isDetailPanelVisible();
      expect(detailVisible).toBe(true);
      const sectionsVisible = await riskPage.areDetailSectionsVisible();
      expect(sectionsVisible).toBe(true);
    });
  });
});
