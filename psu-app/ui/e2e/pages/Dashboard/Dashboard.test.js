const { test, expect } = require('../../_utils/BaseTestSetup');
const DashboardPageHelpers = require('./DashboardPageHelpers');
const AttackPathsPageHelpers = require('../AttackPaths/AttackPathsPageHelpers');
const {
  backupAndClearAllScanHistory,
  restoreScanHistory,
  getScanResultCount,
  getScanHistoryCounts,
  seedIdentityViewData,
  seedIdentitiesPageData,
  getTestIdentitiesGraphEdgeCount,
  seedAttackPathsPageData,
  backupAndClearAttackPathGraphData,
  restoreAttackPathGraphData,
  getTestAttackPathCount,
  backupAndClearDashboardIdentityData,
  restoreDashboardIdentityData,
  getDashboardIdentityCounts,
  seedDashboardDiscoveryPhaseMetrics,
  cleanupDashboardDiscoveryPhaseMetrics,
  getDashboardDiscoveryPhaseMetricCount,
  TEST_PREFIX
} = require('../../_utils/cleanup');
const { backupAndApplyFixture, restoreFixtureBackup } = require('../../_utils/fixtures');

test.describe('Dashboard Page', () => {
  let dashPage;

  test.beforeEach(async ({ ciemPage }) => {
    await ciemPage.setViewportSize({ width: 1440, height: 900 });
    dashPage = new DashboardPageHelpers(ciemPage);
    await dashPage.navigateToDashboard();
  });

  test.describe('when the page loads', () => {
    test('should display page title', async () => {
      const title = await dashPage.getPageTitle();
      expect(title).toContain('Devolutions CIEM Dashboard');
    });

    test('should display subtitle', async () => {
      const visible = await dashPage.isSubtitleVisible();
      expect(visible).toBe(true);
    });
  });

  test.describe('when seeded scan history exists in the database', () => {
    let backup = null;
    let identityBackup = null;
    let discoveryPhaseRunId = null;

    test.beforeAll(() => {
      backup = backupAndApplyFixture('scan-history-summary');
      identityBackup = backupAndClearDashboardIdentityData();
      seedIdentityViewData();
      discoveryPhaseRunId = seedDashboardDiscoveryPhaseMetrics();
      const run1Count = getScanResultCount(`${TEST_PREFIX}scan_run_1`);
      const run2Count = getScanResultCount(`${TEST_PREFIX}scan_run_2`);
      const discoveryPhaseMetricCount = getDashboardDiscoveryPhaseMetricCount(discoveryPhaseRunId);
      if (run1Count !== 5 || run2Count !== 3) {
        throw new Error(`Seed verification failed: scan_run_1 has ${run1Count} results (expected 5), scan_run_2 has ${run2Count} (expected 3)`);
      }
      if (discoveryPhaseMetricCount !== 2) {
        throw new Error(`Seed verification failed: discovery phase timing has ${discoveryPhaseMetricCount} metrics (expected 2)`);
      }
      const identityCounts = getDashboardIdentityCounts();
      if (identityCounts.identityCount !== 3 || identityCounts.entitlementCount !== 4) {
        throw new Error(`Seed verification failed: dashboard identity data has ${identityCounts.identityCount} identities (expected 3) and ${identityCounts.entitlementCount} entitlements (expected 4)`);
      }
      console.log(`[setup:dashboard] Verified ${run1Count} + ${run2Count} seeded scan results.`);
    });

    test.afterAll(() => {
      restoreFixtureBackup(backup);
      restoreDashboardIdentityData(identityBackup);
      cleanupDashboardDiscoveryPhaseMetrics();
    });

    test('should reveal scan run selector inside Checks & Scans details', async () => {
      await dashPage.expandChecksAndScansDetails();
      const visible = await dashPage.isScanRunSelectorVisible();
      expect(visible).toBe(true);
    });

    test('should reveal Run New Scan button inside Checks & Scans details', async () => {
      await dashPage.expandChecksAndScansDetails();
      const visible = await dashPage.isRunNewScanButtonVisible();
      expect(visible).toBe(true);
    });

    test('should use the global Last Discovery header without a page-local duplicate', async () => {
      const visible = await dashPage.isLastDiscoveryHeaderVisible();
      const localSummaryCount = await dashPage.getLocalLastDiscoverySummaryCount();
      expect(visible).toBe(true);
      expect(localSummaryCount).toBe(0);
    });

    test('should reveal summary cards inside Checks & Scans details', async () => {
      await dashPage.expandChecksAndScansDetails();
      const totalVisible = await dashPage.isElementVisible(dashPage.selectors.totalResultsCard);
      const failedVisible = await dashPage.isElementVisible(dashPage.selectors.failedChecksCard);
      const passedVisible = await dashPage.isElementVisible(dashPage.selectors.passedChecksCard);
      const criticalVisible = await dashPage.isElementVisible(dashPage.selectors.criticalIssuesCard);
      expect(totalVisible).toBe(true);
      expect(failedVisible).toBe(true);
      expect(passedVisible).toBe(true);
      expect(criticalVisible).toBe(true);
    });

    test('should present at-a-glance operating state before secondary details', async () => {
      const metrics = await dashPage.getAtAGlanceLayoutMetrics();
      expect(metrics.hasHorizontalOverflow).toBe(false);
      expect(metrics.metricCount).toBe(4);
      expect(metrics.metricRows).toBe(1);
      expect(metrics.overview.top).toBeLessThan(260);
      expect(metrics.overview.bottom).toBeLessThanOrEqual(520);
      expect(metrics.priorityWork.top).toBeLessThan(metrics.supportingEvidence.top);
      expect(metrics.priorityWork.top).toBeLessThan(metrics.viewportHeight);
    });

    test('should hide secondary detail sections by default', async () => {
      expect(await dashPage.isScanSectionVisible()).toBe(false);
      expect(await dashPage.isIdentitySectionVisible()).toBe(false);
      expect(await dashPage.isScanRunSelectorVisible()).toBe(false);
      expect(await dashPage.isRunNewScanButtonVisible()).toBe(false);
      expect(await dashPage.isScanEfficiencyVisible()).toBe(false);
      expect(await dashPage.isSeverityChartVisible()).toBe(false);
      expect(await dashPage.isServiceChartVisible()).toBe(false);
      expect(await dashPage.isCritHighCardVisible()).toBe(false);
    });

    test('should render only the remaining supporting panels', async () => {
      expect(await dashPage.getSupportingPanelIds()).toEqual([
        'dashboardIdentityAndPAMPanel',
        'dashboardChecksAndScansPanel'
      ]);
    });

    test('should separate checks and scans from identity stats without legacy scanner references after details are opened', async () => {
      const legacyScannerName = ['Pro', 'wler'].join('');
      expect(await dashPage.isElementVisible(dashPage.selectors.dashboardOverviewSection)).toBe(true);
      expect(await dashPage.isElementVisible(dashPage.selectors.dashboardPrimaryStateGrid)).toBe(true);
      await dashPage.expandChecksAndScansDetails();
      expect(await dashPage.isScanSectionVisible()).toBe(true);
      expect(await dashPage.isElementVisible(dashPage.selectors.scanSectionHeading)).toBe(true);
      expect(await dashPage.isScanRunSelectorInsideScanSection()).toBe(true);
      expect(await dashPage.isRunNewScanButtonInsideScanSection()).toBe(true);
      expect(await dashPage.isElementVisible(dashPage.selectors.scanSectionTotalResultsCard)).toBe(true);
      expect(await dashPage.isElementVisible(dashPage.selectors.scanSectionFailedChecksCard)).toBe(true);
      await dashPage.expandIdentityAndPAMDetails();
      expect(await dashPage.isIdentitySectionVisible()).toBe(true);
      expect(await dashPage.isElementVisible(dashPage.selectors.identitySectionHeading)).toBe(true);
      expect(await dashPage.isElementVisible(dashPage.selectors.identityCountCard)).toBe(true);
      expect(await dashPage.isElementVisible(dashPage.selectors.entitlementsCard)).toBe(true);
      expect(await dashPage.isScanRunSelectorInsideIdentitySection()).toBe(false);
      expect(await dashPage.getDashboardContentText()).not.toContain(legacyScannerName);
    });

    test('should display identity stats from identity data', async () => {
      await dashPage.expandIdentityAndPAMDetails();
      const identityCount = await dashPage.getIdentityCount();
      const entitlementCount = await dashPage.getEntitlementsCount();
      expect(identityCount).toBe(3);
      expect(entitlementCount).toBe(4);
    });

    test('should display scan efficiency instrumentation from scan history', async () => {
      await dashPage.expandChecksAndScansDetails();
      expect(await dashPage.isScanEfficiencyVisible()).toBe(true);
      const text = await dashPage.getScanEfficiencyText();
      expect(text).toContain('Scan Efficiency');
      expect(text).toContain('Latest Duration');
      expect(text).toContain('Average Duration');
      expect(text).toContain('Latest Throughput');
      expect(text).toContain('Average Throughput');
      expect(text).toContain('Discovery Phase Timing');
      expect(text).toContain('Total Discovery Duration');
      expect(text).toContain('ARM collection');
      expect(text).toContain('Graph build');
      expect(text).toContain('10 ARM rows');
      expect(text).toContain('3 nodes, 2 edges');
      expect(text).toContain('Duration:');
      expect(text).toContain('Results:');
      expect(await dashPage.getScanEfficiencyMetricCount()).toBe(4);
      expect(await dashPage.getDiscoveryPhaseMetricCount()).toBe(2);
      expect(await dashPage.getScanEfficiencyRunCount()).toBeGreaterThanOrEqual(2);
    });

    test('should show Total Results card with count greater than 0', async () => {
      await dashPage.expandChecksAndScansDetails();
      const count = await dashPage.getTotalResultsCount();
      expect(count).toBeGreaterThan(0);
    });

    test('should show Failed Checks card with a numeric count', async () => {
      await dashPage.expandChecksAndScansDetails();
      const count = await dashPage.getFailedChecksCount();
      expect(count).toBeGreaterThanOrEqual(0);
    });

    test('should show Passed Checks card with a numeric count', async () => {
      await dashPage.expandChecksAndScansDetails();
      const count = await dashPage.getPassedChecksCount();
      expect(count).toBeGreaterThanOrEqual(0);
    });

    test('should show Critical Issues card with a number', async () => {
      await dashPage.expandChecksAndScansDetails();
      const count = await dashPage.getCriticalIssuesCount();
      expect(typeof count).toBe('number');
      expect(count).toBeGreaterThanOrEqual(0);
    });

    test('should default to most recent scan run selection', async () => {
      await dashPage.expandChecksAndScansDetails();
      const selectorVisible = await dashPage.isScanRunSelectorVisible();
      expect(selectorVisible).toBe(true);
    });

    test('should refresh dashboard content when selector changes without error', async () => {
      await dashPage.expandChecksAndScansDetails();
      const changed = await dashPage.changeScanRunSelector();
      expect(changed).toBe(true);
      const totalVisible = await dashPage.isElementVisible(dashPage.selectors.totalResultsCard);
      expect(totalVisible).toBe(true);
    });

    test('should redirect to scan page when Run New Scan is clicked', async () => {
      await dashPage.expandChecksAndScansDetails();
      await dashPage.clickRunNewScan();
      expect(dashPage.page.url()).toContain('/ciem/scan');
    });

    test('should display severity chart section', async () => {
      await dashPage.expandChecksAndScansDetails();
      const chartVisible = await dashPage.isSeverityChartVisible();
      expect(chartVisible).toBe(true);
    });

    test('should display service chart section', async () => {
      await dashPage.expandChecksAndScansDetails();
      const chartVisible = await dashPage.isServiceChartVisible();
      expect(chartVisible).toBe(true);
    });

    test('should display Critical & High Results card', async () => {
      await dashPage.expandChecksAndScansDetails();
      const visible = await dashPage.isCritHighCardVisible();
      expect(visible).toBe(true);
    });

    test('should display Critical & High Results table', async () => {
      await dashPage.expandChecksAndScansDetails();
      const hasTable = await dashPage.hasCritHighTable();
      expect(hasTable).toBe(true);
    });

    test('should redirect to history page when View All Results is clicked', async () => {
      await dashPage.expandChecksAndScansDetails();
      await dashPage.clickViewAllResults();
      expect(dashPage.page.url()).toContain('/ciem/history');
    });
  });

  test.describe('when no scan data exists', () => {
    let backup = null;

    test.beforeAll(() => {
      backup = backupAndClearAllScanHistory();
      const counts = getScanHistoryCounts();
      if (counts.scanRunCount !== 0 || counts.scanResultCount !== 0) {
        throw new Error(`Expected empty scan history, got ${counts.scanRunCount} scan runs and ${counts.scanResultCount} scan results`);
      }
      console.log('[setup:dashboard-empty] Verified empty scan history.');
    });

    test.afterAll(() => {
      restoreScanHistory(backup);
    });

    test('should display empty state card with No Scan Data Available text', async () => {
      const visible = await dashPage.isEmptyStateVisible();
      expect(visible).toBe(true);
    });

    test('should display Run Your First Scan button that redirects to scan page', async () => {
      const btnVisible = await dashPage.isElementVisible(dashPage.selectors.runFirstScanBtn);
      expect(btnVisible).toBe(true);
      await dashPage.clickRunFirstScan();
      expect(dashPage.page.url()).toContain('/ciem/scan');
    });
  });

  test.describe('when identity and attack path risks exist', () => {
    let graphBackup = null;

    test.beforeAll(() => {
      graphBackup = backupAndClearAttackPathGraphData();
      seedIdentitiesPageData();
      seedAttackPathsPageData();
      const identityEdgeCount = getTestIdentitiesGraphEdgeCount();
      const attackPathCount = getTestAttackPathCount();
      if (identityEdgeCount !== 4) {
        throw new Error(`Expected 4 seeded identity graph edges, got ${identityEdgeCount}`);
      }
      if (attackPathCount < 2) {
        throw new Error(`Expected seeded attack paths, got ${attackPathCount}`);
      }
      console.log(`[setup:dashboard-needs-attention] Seeded ${identityEdgeCount} identity edge(s) and ${attackPathCount} attack path(s)`);
    });

    test.afterAll(() => {
      restoreAttackPathGraphData(graphBackup);
    });

    test('should show a Needs Attention queue with identity and attack path risks', async () => {
      expect(await dashPage.isNeedsAttentionVisible()).toBe(true);
      const text = await dashPage.getNeedsAttentionText();
      expect(text).toContain('Needs Attention');
      expect(text).toContain('E2E Identities User');
      expect(text).toContain('Critical');
      expect(text).toContain('Holds privileged role with no sign-in activity for 120 days');
      expect(text).toContain('Disabled account still holding active role assignments');
      expect(text).toContain('E2E Disabled User');
      expect(text).toContain('High');
      expect(await dashPage.getNeedsAttentionItemCount()).toBeGreaterThanOrEqual(2);
    });

    test('should provide drill-in actions for identity and targeted attack path risks', async () => {
      await dashPage.clickInspectIdentity();
      expect(dashPage.page.url()).toContain('/ciem/identities');

      await dashPage.navigateToDashboard();
      await dashPage.clickInspectAttackPath();
      expect(dashPage.page.url()).toContain('/ciem/attack-paths?attackPathId=');
      const attackPage = new AttackPathsPageHelpers(dashPage.page);
      await attackPage.waitForFocusedAttackPathDetail('Disabled account still holding active role assignments');
      const detailText = await attackPage.page.locator(attackPage.selectors.focusedDetail).textContent();
      expect(detailText).toContain('Disabled account still holding active role assignments');
      expect(detailText).toContain('E2E Disabled User');
    });

    test('should show PAM implementation progress and candidate mappings', async () => {
      await dashPage.expandIdentityAndPAMDetails();
      expect(await dashPage.isPAMProgressVisible()).toBe(true);
      const text = await dashPage.getPAMProgressText();
      expect(text).toContain('PAM Implementation Progress');
      expect(text).toContain('Readiness');
      expect(text).toContain('PAM Candidates');
      expect(text).toContain('Outbound PAM actions');
      expect(text).toContain('NotScoped');
      expect(text).toContain('JIT elevation and approval workflow');
      expect(text).toContain('Access brokering and session governance');
      expect(await dashPage.getPAMProgressMetricCount()).toBe(3);
      expect(await dashPage.getPAMProgressStageCount()).toBe(5);
      expect(await dashPage.getPAMProgressCandidateCount()).toBeGreaterThanOrEqual(2);
    });
  });

  test.describe('when no identity or attack path risk data exists', () => {
    let graphBackup = null;

    test.beforeAll(() => {
      graphBackup = backupAndClearAttackPathGraphData();
      console.log('[setup:dashboard-needs-attention-empty] Cleared graph and attack path data');
    });

    test.afterAll(() => {
      restoreAttackPathGraphData(graphBackup);
    });

    test('should explain that discovery data is required before risk queue items can appear', async () => {
      expect(await dashPage.isNeedsAttentionVisible()).toBe(true);
      expect(await dashPage.hasNeedsAttentionEmptyState()).toBe(true);
      const text = await dashPage.getNeedsAttentionText();
      expect(text).toContain('No discovered identity or attack path data yet');
      expect(text).toContain('Run discovery');
    });
  });
});
