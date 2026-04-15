const { test, expect } = require('../../_utils/BaseTestSetup');
const IdentitiesPageHelpers = require('./IdentitiesPageHelpers');
const {
  seedIdentitiesPageData,
  cleanupIdentitiesPageData,
  getTestIdentitiesGraphEdgeCount
} = require('../../_utils/cleanup');

test.describe('Identities Page', () => {
  let identitiesPage;

  test.beforeEach(async ({ ciemPage }) => {
    identitiesPage = new IdentitiesPageHelpers(ciemPage);
    await identitiesPage.navigateToIdentitiesPage();
  });

  test.describe('when the page loads', () => {
    test('should display page title', async () => {
      const title = await identitiesPage.getPageTitle();
      expect(title).toContain('Identities');
    });
  });

  test.describe('when identity permission data exists in the database', () => {
    test.beforeAll(() => {
      seedIdentitiesPageData();
      const count = getTestIdentitiesGraphEdgeCount();
      if (count < 2) {
        throw new Error(`Expected seeded identity graph data, got ${count} edges`);
      }
      console.log(`[setup:identities] Seeded ${count} identity graph edge(s)`);
    });

    test.afterAll(() => {
      cleanupIdentitiesPageData();
      console.log('[teardown:identities] Cleaned up seeded data');
    });

    test('should display target resource details in plain language', async () => {
      const hasData = await identitiesPage.hasData();
      expect(hasData).toBe(true);

      const targetName = 'E2E Identities Key Vault';
      await identitiesPage.filterRows(targetName);

      const hasIcon = await identitiesPage.targetCellHasResourceIcon(targetName);
      expect(hasIcon).toBe(true);

      const hasFriendlyDescription = await identitiesPage.targetRowHasCanDoDescription(targetName, 'Can read Azure Key Vault properties in this Azure Key Vault');
      expect(hasFriendlyDescription).toBe(true);
    });

    test('should display identity risk summary columns and detail sections', async () => {
      const hasData = await identitiesPage.hasData();
      expect(hasData).toBe(true);

      const headers = await identitiesPage.getColumnHeaders();
      expect(headers).toContain('Entitlements');
      expect(headers).toContain('Privileged Roles');
      expect(headers).toContain('Risk Level');
      expect(headers).toContain('Last Activity');

      const targetName = 'E2E Identities Key Vault';
      await identitiesPage.filterRows(targetName);
      await identitiesPage.expandTargetRow(targetName);

      expect(await identitiesPage.isDetailSectionVisible('Sign-In Activity')).toBe(true);
      expect(await identitiesPage.isDetailSectionVisible('Identity Entitlements')).toBe(true);
      expect(await identitiesPage.isDetailSectionVisible('Risk Signals')).toBe(true);
      expect(await identitiesPage.isDetailSectionVisible('Attack Paths')).toBe(true);
      expect(await identitiesPage.hasDetailText('Holds privileged role with no sign-in activity for 120 days')).toBe(true);
    });
  });
});
