const { test, expect } = require('../../_utils/BaseTestSetup');
const EnvironmentPageHelpers = require('./EnvironmentPageHelpers');
const {
  seedEnvironmentData, cleanupEnvironmentData,
  getTestArmResourceCount, getArmResourceCount,
  backupAndClearAllArmResources, restoreArmResources,
  clearStaleDiscoveryRuns,
  seedIdentityViewData, cleanupIdentityViewData, getTestEffectiveRoleAssignmentCount
} = require('../../_utils/cleanup');
const {
  deactivateAzureAuthProfile, activateAzureAuthProfile,
  getActiveAzureAuthProfileCount, cancelRunningPSUJobs
} = require('../../_utils/psu-helpers');

test.describe('Environment Page', () => {
  let envPage;

  test.beforeEach(async ({ ciemPage }) => {
    envPage = new EnvironmentPageHelpers(ciemPage);
    await envPage.navigateToEnvironmentPage();
  });

  // --- Static UI verification (no state dependency) ---

  test.describe('when the page loads', () => {
    test('should display page title', async () => {
      const title = await envPage.getPageTitle();
      expect(title).toContain('Environment Explorer');
    });

    test('should display subtitle', async () => {
      const visible = await envPage.isSubtitleVisible();
      expect(visible).toBe(true);
    });

    test('should display Provider select with Azure default', async () => {
      const visible = await envPage.isProviderSelectVisible();
      expect(visible).toBe(true);
      const value = await envPage.getSelectedProvider();
      expect(value).toBe('Azure');
    });

    test('should display Layout select with Left to Right default', async () => {
      const visible = await envPage.isLayoutSelectVisible();
      expect(visible).toBe(true);
      const value = await envPage.getSelectedLayout();
      expect(value).toBe('LR');
    });

    test('should display Start Discovery button', async () => {
      const visible = await envPage.isStartDiscoveryButtonVisible();
      expect(visible).toBe(true);
    });

    test('should NOT display a Load Environment button', async () => {
      const btn = envPage.page.locator('#loadEnvBtn');
      await expect(btn).toHaveCount(0);
    });
  });

  // --- Auth profile state: no active profile ---

  test.describe('when no active authentication profile exists', () => {
    let previousActiveProfileId = null;

    test.beforeAll(async () => {
      try {
        console.log('[setup:auth] Starting auth profile deactivation...');

        // Clear any stuck/running PSU jobs from previous test runs
        const { cancelled, running, queued } = await cancelRunningPSUJobs();
        if (cancelled > 0) {
          console.log(`[setup:auth] Cancelled ${cancelled} PSU jobs (${running} running, ${queued} queued).`);
        }

        // Deactivate any active profile
        const { previousActiveId, result: deactivateResult } = await deactivateAzureAuthProfile();
        console.log(`[setup:auth] Deactivation result: status=${deactivateResult.status}, previousActiveId=${previousActiveId}`);
        if (deactivateResult.statusCode === -1) {
          test.skip(true, `Could not deactivate auth profile: PSU command ${deactivateResult.status} (jobId: ${deactivateResult.jobId})`);
          return;
        }
        previousActiveProfileId = previousActiveId;

        // Assert: verify no active profile remains
        const { count, result: countResult } = await getActiveAzureAuthProfileCount();
        console.log(`[setup:auth] Active profile count: ${count} (PSU status: ${countResult.status})`);
        if (countResult.statusCode === -1) {
          test.skip(true, `Could not verify auth state: PSU command ${countResult.status}`);
          return;
        }
        if (count !== 0) {
          test.skip(true, `Could not deactivate auth profile (${count} still active)`);
          return;
        }
        console.log(`[setup:auth] State established: 0 active auth profiles.`);
      } catch (err) {
        console.log(`[setup:auth] ERROR: ${err.message}`);
        test.skip(true, `Auth setup failed: ${err.message}`);
      }
    });

    test.afterAll(async () => {
      if (previousActiveProfileId) {
        const restoreResult = await activateAzureAuthProfile(previousActiveProfileId);
        console.log(`[teardown] Restored auth profile '${previousActiveProfileId}' (status: ${restoreResult.status}).`);
      }
    });

    test('should complete discovery without crashing when clicking Start Discovery', async ({}, testInfo) => {
      testInfo.setTimeout(600000); // Discovery may run with stale auth from PSU runspace pool
      await cancelRunningPSUJobs();
      clearStaleDiscoveryRuns();
      await envPage.clickStartDiscovery();

      const startingToast = envPage.page.locator('.iziToast:has-text("Starting Azure discovery")');
      await expect(startingToast).toBeVisible({ timeout: 10000 });

      // Poll for discovery to complete — button re-enables when OnClick handler finishes
      const startBtn = envPage.page.locator(envPage.selectors.startDiscoveryBtn);
      for (let i = 0; i < 180; i++) { // 180 × 3s = 9 minutes max
        await envPage.page.waitForTimeout(3000);
        const isDisabled = await startBtn.getAttribute('disabled');
        if (isDisabled === null) break;
      }

      // After discovery completes, tree auto-reloads via Sync-UDElement.
      // Page should be in a valid state (tree loaded or no-resources shown).
      const chartArea = envPage.page.locator(envPage.selectors.chartArea);
      const chartText = (await chartArea.textContent()).trim();
      // Must NEVER see crash indicators
      expect(chartText).not.toContain('unexpected status');
      expect(chartText).not.toContain('Error');
      // Chart area must have some content (either tree or no-resources state)
      expect(chartText.length).toBeGreaterThan(0);
    });
  });

  // --- Discovery execution: active auth profile ---

  test.describe('when discovery runs with an active authentication profile', () => {
    test.beforeAll(async () => {
      await cancelRunningPSUJobs();
      clearStaleDiscoveryRuns();
    });

    test('should complete discovery and auto-load environment tree', async ({}, testInfo) => {
      testInfo.setTimeout(600000); // 10 minutes — real discovery is slow

      await envPage.clickStartDiscovery();

      // 1. Starting toast must appear
      const startingToast = envPage.page.locator('.iziToast:has-text("Starting Azure discovery")');
      await expect(startingToast).toBeVisible({ timeout: 10000 });

      // 2. Wait for discovery to complete — button re-enables when OnClick handler finishes
      const startBtn = envPage.page.locator(envPage.selectors.startDiscoveryBtn);
      for (let i = 0; i < 180; i++) { // 180 × 3s = 9 minutes max
        await envPage.page.waitForTimeout(3000);
        const isDisabled = await startBtn.getAttribute('disabled');
        if (isDisabled === null) break;
      }

      // 3. After discovery, Sync-UDElement triggers tree auto-reload.
      // Wait for the summary card to appear (tree loaded with data).
      await envPage.waitForEnvironmentLoaded(30000);

      // 4. Verify summary counts — confirms discovery found resources
      const summaryVisible = await envPage.isSummaryCardVisible();
      expect(summaryVisible).toBe(true);

      const tenantText = await envPage.getSummaryCount('Tenants');
      expect(parseInt(tenantText)).toBeGreaterThanOrEqual(1);

      const subText = await envPage.getSummaryCount('Subscriptions');
      expect(parseInt(subText)).toBeGreaterThanOrEqual(1);

      // 5. Tree visualization must be rendered
      const treeVisible = await envPage.isTreeContainerVisible();
      expect(treeVisible).toBe(true);

      // 6. Button must be re-enabled after completion
      const startDisabled = await startBtn.getAttribute('disabled');
      expect(startDisabled).toBeNull();
    });
  });

  // --- Discovery data state: data exists ---

  test.describe('when discovery data exists in the database', () => {
    test.beforeAll(() => {
      seedEnvironmentData();
      // Assert: verify seeded rows are in the DB
      const count = getTestArmResourceCount();
      if (count !== 4) {
        throw new Error(`Expected 4 seeded ARM resources, got ${count}`);
      }
      console.log(`[setup] Verified ${count} test ARM resources seeded.`);
    });

    test.beforeEach(async () => {
      // Wait for auto-load to complete (page navigation already happened in outer beforeEach)
      await envPage.waitForEnvironmentLoaded();
    });

    test.afterAll(() => {
      cleanupEnvironmentData();
    });

    test('should auto-load summary card with resource counts', async () => {
      const summaryVisible = await envPage.isSummaryCardVisible();
      expect(summaryVisible).toBe(true);
    });

    test('should display tenant count greater than or equal to one', async () => {
      const tenantText = await envPage.getSummaryCount('Tenants');
      const tenantCount = parseInt(tenantText);
      expect(tenantCount).toBeGreaterThanOrEqual(1);
    });

    test('should display subscription count greater than or equal to one', async () => {
      const subText = await envPage.getSummaryCount('Subscriptions');
      const subCount = parseInt(subText);
      expect(subCount).toBeGreaterThanOrEqual(1);
    });

    test('should render tree visualization container', async () => {
      const treeVisible = await envPage.isTreeContainerVisible();
      expect(treeVisible).toBe(true);
    });

    test('should re-render tree when layout orientation is changed', async () => {
      await envPage.selectLayout('TB');
      // Layout change triggers Sync-UDElement — wait for tree to re-render
      await envPage.waitForEnvironmentLoaded();
      const treeVisible = await envPage.isTreeContainerVisible();
      expect(treeVisible).toBe(true);
    });
  });

  // --- Discovery data state: no data ---

  test.describe('when no discovery data exists in the database', () => {
    let backedUpRows = null;

    test.beforeAll(() => {
      backedUpRows = backupAndClearAllArmResources();
      // Assert: verify table is empty
      const count = getArmResourceCount();
      if (count !== 0) {
        throw new Error(`Expected 0 ARM resources after clearing, got ${count}`);
      }
      console.log('[setup] Verified 0 ARM resources in database.');
    });

    test.beforeEach(async () => {
      // Wait for auto-load to complete (shows no-resources state when DB is empty)
      await envPage.waitForEnvironmentLoaded();
    });

    test.afterAll(() => {
      restoreArmResources(backedUpRows);
    });

    test('should display No Resources Discovered message', async () => {
      const noResourcesVisible = await envPage.isNoResourcesTextVisible();
      expect(noResourcesVisible).toBe(true);
    });

    test('should display description about running discovery first', async () => {
      const descVisible = await envPage.isNoResourcesDescriptionVisible();
      expect(descVisible).toBe(true);
    });
  });

  // --- View toggle ---

  test.describe('when the page loads with view toggle', () => {
    test('should display View select with Infrastructure default', async () => {
      const visible = await envPage.isViewSelectVisible();
      expect(visible).toBe(true);
      const value = await envPage.getSelectedView();
      expect(value).toBe('Infrastructure');
    });

    test('should NOT display assignment mode select in Infrastructure view', async () => {
      const visible = await envPage.isAssignmentModeSelectVisible();
      expect(visible).toBe(false);
    });
  });

  // --- Identity view with seeded data ---

  test.describe('when identity data exists and Identity view is selected', () => {
    test.beforeAll(() => {
      seedEnvironmentData(); // Need ARM resources for subscription name resolution
      seedIdentityViewData();
      // Assert: verify seeded rows
      const eraCount = getTestEffectiveRoleAssignmentCount();
      if (eraCount < 4) {
        throw new Error(`Expected >= 4 seeded effective role assignments, got ${eraCount}`);
      }
      console.log(`[setup] Verified ${eraCount} test effective role assignments seeded.`);
    });

    test.afterAll(() => {
      cleanupIdentityViewData();
      cleanupEnvironmentData();
    });

    test('should switch to Identity view and display identity summary card', async () => {
      await envPage.selectView('Identity');
      await envPage.waitForEnvironmentLoaded();
      const identitySummary = await envPage.isIdentitySummaryCardVisible();
      expect(identitySummary).toBe(true);
    });

    test('should display identity-specific summary counts', async () => {
      await envPage.selectView('Identity');
      await envPage.waitForEnvironmentLoaded();
      const identityCount = await envPage.getSummaryCount('Identities');
      expect(parseInt(identityCount)).toBeGreaterThanOrEqual(1);
      const roleCount = await envPage.getSummaryCount('Roles');
      expect(parseInt(roleCount)).toBeGreaterThanOrEqual(1);
    });

    test('should render tree container in Identity view', async () => {
      await envPage.selectView('Identity');
      await envPage.waitForEnvironmentLoaded();
      const treeVisible = await envPage.isTreeContainerVisible();
      expect(treeVisible).toBe(true);
    });

    test('should display assignment mode select in Identity view', async () => {
      await envPage.selectView('Identity');
      await envPage.waitForEnvironmentLoaded();
      const visible = await envPage.isAssignmentModeSelectVisible();
      expect(visible).toBe(true);
    });

    test('should switch back to Infrastructure view', async () => {
      await envPage.selectView('Identity');
      await envPage.waitForEnvironmentLoaded();
      await envPage.selectView('Infrastructure');
      await envPage.waitForEnvironmentLoaded();
      const infraSummary = await envPage.isSummaryCardVisible();
      expect(infraSummary).toBe(true);
    });
  });
});
