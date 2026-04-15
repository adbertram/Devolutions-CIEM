const { test, expect } = require('../../_utils/BaseTestSetup');
const EffectivePermissionsPageHelpers = require('./EffectivePermissionsPageHelpers');
const {
  seedEffectivePermissionsPageData,
  cleanupEffectivePermissionsPageData,
  getTestEffectivePermissionGraphEdgeCount
} = require('../../_utils/cleanup');

test.describe('Effective Permissions Page', () => {
  let effectivePermissionsPage;

  test.beforeEach(async ({ ciemPage }) => {
    effectivePermissionsPage = new EffectivePermissionsPageHelpers(ciemPage);
    await effectivePermissionsPage.navigateToEffectivePermissionsPage();
  });

  test.describe('when the page loads', () => {
    test('should display page title', async () => {
      const title = await effectivePermissionsPage.getPageTitle();
      expect(title).toContain('Effective Permissions');
    });
  });

  test.describe('when effective permission data exists in the database', () => {
    test.beforeAll(() => {
      seedEffectivePermissionsPageData();
      const count = getTestEffectivePermissionGraphEdgeCount();
      if (count < 1) {
        throw new Error(`Expected seeded effective permission graph data, got ${count} edges`);
      }
      console.log(`[setup:effective-permissions] Seeded ${count} effective permission graph edge(s)`);
    });

    test.afterAll(() => {
      cleanupEffectivePermissionsPageData();
      console.log('[teardown:effective-permissions] Cleaned up seeded data');
    });

    test('should display a resource type icon beside the target resource', async () => {
      const hasData = await effectivePermissionsPage.hasData();
      expect(hasData).toBe(true);

      const hasIcon = await effectivePermissionsPage.targetCellHasResourceIcon('E2E Effective Permissions Key Vault');
      expect(hasIcon).toBe(true);
    });
  });
});
