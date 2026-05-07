const { test, expect } = require('../../_utils/BaseTestSetup');
const IdentitiesPageHelpers = require('./IdentitiesPageHelpers');
const {
  seedIdentitiesPageData,
  seedIdentitiesPageLayoutData,
  cleanupIdentitiesPageData,
  getTestIdentitiesGraphEdgeCount,
  getTestIdentitiesLayoutIdentityCount,
  backupAndClearDashboardIdentityData,
  restoreDashboardIdentityData,
  TEST_PREFIX
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
    let identityBackup = null;

    test.beforeAll(() => {
      identityBackup = backupAndClearDashboardIdentityData();
      seedIdentitiesPageData();
      const count = getTestIdentitiesGraphEdgeCount();
      if (count !== 4) {
        throw new Error(`Expected seeded identity graph data, got ${count} edges`);
      }
      console.log(`[setup:identities] Seeded ${count} identity graph edge(s)`);
    });

    test.afterAll(() => {
      cleanupIdentitiesPageData();
      restoreDashboardIdentityData(identityBackup);
      console.log('[teardown:identities] Cleaned up seeded data');
    });

    test('should display one top-level row per identity and target access in detail content', async () => {
      const hasData = await identitiesPage.hasData();
      expect(hasData).toBe(true);

      const identityName = 'E2E Identities User';
      const targetName = 'E2E Identities Key Vault';
      await identitiesPage.filterRows(identityName);

      const identityRowCount = await identitiesPage.getIdentityRowCount(identityName);
      expect(identityRowCount).toBe(1);

      await identitiesPage.expandIdentityRow(identityName);

      const detailHasTargetAccess = await identitiesPage.detailHasTargetAccess(targetName, 'Can read Azure Key Vault properties in this Azure Key Vault');
      expect(detailHasTargetAccess).toBe(true);

      const hasIcon = await identitiesPage.detailTargetHasResourceIcon(targetName);
      expect(hasIcon).toBe(true);
    });

    test('should display identity risk summary columns and detail sections', async () => {
      const hasData = await identitiesPage.hasData();
      expect(hasData).toBe(true);

      const headers = await identitiesPage.getColumnHeaders();
      expect(headers).toContain('Object ID');
      expect(headers).toContain('Entitlements');
      expect(headers).toContain('Privileged Roles');
      expect(headers).toContain('Risk Level');
      expect(headers).toContain('Last Activity');

      const identityName = 'E2E Identities User';
      await identitiesPage.filterRows(identityName);
      await identitiesPage.expandIdentityRow(identityName);

      expect(await identitiesPage.objectIdIsVisible(`${TEST_PREFIX}identity-user-1`)).toBe(true);
      expect(await identitiesPage.isDetailSectionVisible('Target Access')).toBe(true);
      expect(await identitiesPage.isDetailSectionVisible('Sign-In Activity')).toBe(true);
      expect(await identitiesPage.isDetailSectionVisible('Identity Entitlements')).toBe(true);
      expect(await identitiesPage.isDetailSectionVisible('Risk Signals')).toBe(true);
      expect(await identitiesPage.isDetailSectionVisible('Attack Paths')).toBe(true);
      expect(await identitiesPage.hasDetailText('Holds privileged role with no sign-in activity for 120 days')).toBe(true);
    });

    test('should distinguish duplicate display names by type and object ID', async () => {
      const hasData = await identitiesPage.hasData();
      expect(hasData).toBe(true);

      await identitiesPage.filterRows('E2E Duplicate App');

      const duplicateRowCount = await identitiesPage.getIdentityRowCount('E2E Duplicate App');
      expect(duplicateRowCount).toBe(2);
      expect(await identitiesPage.objectIdIsVisible(`${TEST_PREFIX}identity-sp-duplicate`)).toBe(true);
      expect(await identitiesPage.objectIdIsVisible(`${TEST_PREFIX}identity-mi-duplicate`)).toBe(true);
      expect(await identitiesPage.rowWithTextIsVisible('ServicePrincipal')).toBe(true);
      expect(await identitiesPage.rowWithTextIsVisible('ManagedIdentity')).toBe(true);
    });
  });

  test.describe('when enough identity data exists to paginate', () => {
    let identityBackup = null;

    test.beforeAll(() => {
      identityBackup = backupAndClearDashboardIdentityData();
      seedIdentitiesPageLayoutData();
      const count = getTestIdentitiesLayoutIdentityCount();
      if (count !== 30) {
        throw new Error(`Expected 30 seeded layout identities, got ${count}`);
      }
      console.log(`[setup:identities-layout] Seeded ${count} identity row(s)`);
    });

    test.afterAll(() => {
      cleanupIdentitiesPageData();
      restoreDashboardIdentityData(identityBackup);
      console.log('[teardown:identities-layout] Cleaned up seeded layout data');
    });

    test('should keep pagination visible at 1080p without horizontal grid scrolling', async () => {
      await identitiesPage.page.setViewportSize({ width: 1920, height: 1080 });
      await identitiesPage.navigateToIdentitiesPage();

      const metrics = await identitiesPage.getPrimaryGridLayoutMetrics([
        'principal',
        'objectid',
        'principaltype',
        'identityentitlementcount',
        'identityprivilegedcount',
        'risklevel',
        'lastactivity'
      ]);

      expect(metrics.pagination.visibleInViewport, JSON.stringify(metrics.pagination)).toBe(true);
      expect(metrics.virtualScroller.hasHorizontalOverflow, JSON.stringify(metrics.virtualScroller)).toBe(false);
      expect(metrics.document.hasHorizontalOverflow, JSON.stringify(metrics.document)).toBe(false);
      for (const field of metrics.fields) {
        expect(field.header.visibleInGrid, `${field.field} header ${JSON.stringify(field.header)}`).toBe(true);
        expect(field.cell.visibleInGrid, `${field.field} cell ${JSON.stringify(field.cell)}`).toBe(true);
      }
    });

    test('should keep the Object ID column visible in a constrained browser content area', async () => {
      await identitiesPage.page.setViewportSize({ width: 1366, height: 768 });
      await identitiesPage.navigateToIdentitiesPage();

      const metrics = await identitiesPage.getPrimaryGridLayoutMetrics([
        'principal',
        'objectid',
        'principaltype',
        'identityentitlementcount',
        'identityprivilegedcount',
        'risklevel',
        'lastactivity'
      ]);

      expect(metrics.virtualScroller.hasHorizontalOverflow, JSON.stringify(metrics.virtualScroller)).toBe(false);
      expect(metrics.document.hasHorizontalOverflow, JSON.stringify(metrics.document)).toBe(false);
      const objectId = metrics.fields.find(field => field.field === 'objectid');
      expect(objectId.header.visibleInGrid, JSON.stringify(objectId.header)).toBe(true);
      expect(objectId.cell.visibleInGrid, JSON.stringify(objectId.cell)).toBe(true);
    });
  });
});
