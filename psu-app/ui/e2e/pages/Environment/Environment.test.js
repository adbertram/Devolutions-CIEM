const { test, expect } = require('../../_utils/BaseTestSetup');
const EnvironmentPageHelpers = require('./EnvironmentPageHelpers');
const {
  seedEnvironmentData, cleanupEnvironmentData,
  getTestArmResourceCount, getArmResourceCount,
  backupAndClearAllArmResources, restoreArmResources,
  clearStaleDiscoveryRuns
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

    test('should display Load Environment button', async () => {
      const visible = await envPage.isLoadEnvironmentButtonVisible();
      expect(visible).toBe(true);
    });

    test('should display empty state card before any action', async () => {
      const visible = await envPage.isEmptyStateCardVisible();
      expect(visible).toBe(true);
    });

    test('should display No Environment Data Loaded text before any action', async () => {
      const visible = await envPage.isEmptyStateTextVisible();
      expect(visible).toBe(true);
    });

    test('should display empty state description about selecting a provider', async () => {
      const visible = await envPage.isEmptyStateDescriptionVisible();
      expect(visible).toBe(true);
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

    test('should complete discovery without unexpected status errors when clicking Start Discovery', async ({}, testInfo) => {
      testInfo.setTimeout(600000); // Discovery may run with stale auth from PSU runspace pool
      await cancelRunningPSUJobs();
      clearStaleDiscoveryRuns();
      await envPage.clickStartDiscovery();

      const startingToast = envPage.page.locator('.iziToast:has-text("Starting Azure discovery")');
      await expect(startingToast).toBeVisible({ timeout: 10000 });

      // Poll for terminal state — discovery may complete quickly (auth error) or
      // take minutes (stale auth from PSU runspace pool runs real API calls)
      const chartArea = envPage.page.locator(envPage.selectors.chartArea);
      for (let i = 0; i < 180; i++) { // 180 × 3s = 9 minutes max
        await envPage.page.waitForTimeout(3000);
        const text = (await chartArea.textContent()).trim();
        if (text.includes('Discovery completed') || text.includes('Discovery partially') ||
            text.includes('Discovery finished') || text.includes('Discovery Failed')) {
          break;
        }
      }

      const chartText = (await chartArea.textContent()).trim();
      // Guard: must NEVER see the "unexpected status" crash — this was the original bug
      expect(chartText).not.toContain('unexpected status');
      // Must be a recognized result (success, partial, failed, or auth error)
      const isRecognizedResult = chartText.includes('Discovery completed') ||
                                  chartText.includes('Discovery partially') ||
                                  chartText.includes('Discovery finished with status') ||
                                  chartText.includes('Discovery Failed');
      expect(isRecognizedResult).toBe(true);
    });
  });

  // --- Discovery execution: active auth profile ---

  test.describe('when discovery runs with an active authentication profile', () => {
    test.beforeAll(async () => {
      await cancelRunningPSUJobs();
      clearStaleDiscoveryRuns();
    });

    test('should show progress updates and complete without unexpected status errors', async ({}, testInfo) => {
      testInfo.setTimeout(600000); // 10 minutes — real discovery is slow

      await envPage.clickStartDiscovery();

      // 1. Starting toast must appear
      const startingToast = envPage.page.locator('.iziToast:has-text("Starting Azure discovery")');
      await expect(startingToast).toBeVisible({ timeout: 10000 });

      // 2. Wait for the chart area to leave the initial empty state — either
      //    progress appears or a terminal result card replaces the empty state
      const chartArea = envPage.page.locator(envPage.selectors.chartArea);
      await expect(chartArea).not.toContainText('No Environment Data Loaded', { timeout: 30000 });

      // 3. Wait for terminal state — poll until chart area shows a result
      for (let i = 0; i < 180; i++) { // 180 × 3s = 9 minutes max
        await envPage.page.waitForTimeout(3000);
        const chartText = (await chartArea.textContent()).trim();
        if (chartText.includes('Discovery completed') || chartText.includes('Discovery partially') ||
            chartText.includes('Discovery finished') || chartText.includes('Discovery Failed')) {
          break;
        }
      }

      const chartText = (await chartArea.textContent()).trim();
      // Guard: must NEVER see the "unexpected status" crash — this was the original bug
      expect(chartText).not.toContain('unexpected status');
      // Must be a recognized terminal state
      const isRecognizedResult = chartText.includes('Discovery completed') ||
                                  chartText.includes('Discovery partially') ||
                                  chartText.includes('Discovery finished with status') ||
                                  chartText.includes('Discovery Failed');
      expect(isRecognizedResult).toBe(true);

      // 4. Buttons must be re-enabled after completion
      const startBtn = envPage.page.locator(envPage.selectors.startDiscoveryBtn);
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

    test.afterAll(() => {
      cleanupEnvironmentData();
    });

    test('should display summary card with resource counts', async () => {
      await envPage.clickLoadEnvironment();
      const summaryVisible = await envPage.isSummaryCardVisible();
      expect(summaryVisible).toBe(true);
    });

    test('should display tenant count greater than or equal to one', async () => {
      await envPage.clickLoadEnvironment();
      const tenantText = await envPage.getSummaryCount('Tenants');
      const tenantCount = parseInt(tenantText);
      expect(tenantCount).toBeGreaterThanOrEqual(1);
    });

    test('should display subscription count greater than or equal to one', async () => {
      await envPage.clickLoadEnvironment();
      const subText = await envPage.getSummaryCount('Subscriptions');
      const subCount = parseInt(subText);
      expect(subCount).toBeGreaterThanOrEqual(1);
    });

    test('should render tree visualization container', async () => {
      await envPage.clickLoadEnvironment();
      const treeVisible = await envPage.isTreeContainerVisible();
      expect(treeVisible).toBe(true);
    });

    test('should show toast notification with resource counts', async () => {
      await envPage.clickLoadEnvironment();
      const toast = await envPage.waitForToastMessage('resources across');
      expect(toast).toBeTruthy();
    });

    test('should render tree in Top to Bottom layout when selected', async () => {
      await envPage.selectLayout('TB');
      await envPage.clickLoadEnvironment();
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

    test.afterAll(() => {
      restoreArmResources(backedUpRows);
    });

    test('should display No Resources Discovered message', async () => {
      await envPage.clickLoadEnvironment();
      const noResourcesVisible = await envPage.isNoResourcesTextVisible();
      expect(noResourcesVisible).toBe(true);
    });

    test('should display description about running discovery first', async () => {
      await envPage.clickLoadEnvironment();
      const descVisible = await envPage.isNoResourcesDescriptionVisible();
      expect(descVisible).toBe(true);
    });
  });
});
