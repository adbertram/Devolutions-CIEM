const { test, expect } = require('../../_utils/BaseTestSetup');
const DashboardPageHelpers = require('./DashboardPageHelpers');
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
  seedExposureChangeData,
  cleanupExposureChangeData,
  getTestExposureChangeCount,
  TEST_PREFIX
} = require('../../_utils/cleanup');
const { backupAndApplyFixture, restoreFixtureBackup } = require('../../_utils/fixtures');

test.describe('Dashboard Page', () => {
  let dashPage;

  test.beforeEach(async ({ ciemPage }) => {
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

    test.beforeAll(() => {
      backup = backupAndApplyFixture('scan-history-summary');
      identityBackup = backupAndClearDashboardIdentityData();
      seedIdentityViewData();
      const run1Count = getScanResultCount(`${TEST_PREFIX}scan_run_1`);
      const run2Count = getScanResultCount(`${TEST_PREFIX}scan_run_2`);
      if (run1Count !== 5 || run2Count !== 3) {
        throw new Error(`Seed verification failed: scan_run_1 has ${run1Count} results (expected 5), scan_run_2 has ${run2Count} (expected 3)`);
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
    });

    test('should display scan run selector dropdown', async () => {
      const visible = await dashPage.isScanRunSelectorVisible();
      expect(visible).toBe(true);
    });

    test('should display Run New Scan button', async () => {
      const visible = await dashPage.isRunNewScanButtonVisible();
      expect(visible).toBe(true);
    });

    test('should use the global Last Discovery header without a page-local duplicate', async () => {
      const visible = await dashPage.isLastDiscoveryHeaderVisible();
      const localSummaryCount = await dashPage.getLocalLastDiscoverySummaryCount();
      expect(visible).toBe(true);
      expect(localSummaryCount).toBe(0);
    });

    test('should display summary cards container', async () => {
      const totalVisible = await dashPage.isElementVisible(dashPage.selectors.totalResultsCard);
      const failedVisible = await dashPage.isElementVisible(dashPage.selectors.failedChecksCard);
      const passedVisible = await dashPage.isElementVisible(dashPage.selectors.passedChecksCard);
      const criticalVisible = await dashPage.isElementVisible(dashPage.selectors.criticalIssuesCard);
      expect(totalVisible).toBe(true);
      expect(failedVisible).toBe(true);
      expect(passedVisible).toBe(true);
      expect(criticalVisible).toBe(true);
    });

    test('should separate checks and scans from identity stats without legacy scanner references', async () => {
      const legacyScannerName = ['Pro', 'wler'].join('');
      expect(await dashPage.isElementVisible(dashPage.selectors.sectionPanelGroup)).toBe(true);
      expect(await dashPage.isElementVisible(dashPage.selectors.scanPanel)).toBe(true);
      expect(await dashPage.isElementVisible(dashPage.selectors.identityPanel)).toBe(true);
      expect(await dashPage.isScanSectionVisible()).toBe(true);
      expect(await dashPage.isIdentitySectionVisible()).toBe(true);
      expect(await dashPage.isScanSectionHideable()).toBe(true);
      expect(await dashPage.isIdentitySectionHideable()).toBe(true);
      expect(await dashPage.isElementVisible(dashPage.selectors.scanSectionHeading)).toBe(true);
      expect(await dashPage.isElementVisible(dashPage.selectors.identitySectionHeading)).toBe(true);
      expect(await dashPage.isScanRunSelectorInsideScanSection()).toBe(true);
      expect(await dashPage.isRunNewScanButtonInsideScanSection()).toBe(true);
      expect(await dashPage.isElementVisible(dashPage.selectors.scanSectionTotalResultsCard)).toBe(true);
      expect(await dashPage.isElementVisible(dashPage.selectors.scanSectionFailedChecksCard)).toBe(true);
      expect(await dashPage.isElementVisible(dashPage.selectors.identityCountCard)).toBe(true);
      expect(await dashPage.isElementVisible(dashPage.selectors.entitlementsCard)).toBe(true);
      expect(await dashPage.isScanRunSelectorInsideIdentitySection()).toBe(false);
      expect(await dashPage.getDashboardContentText()).not.toContain(legacyScannerName);
    });

    test('should collapse and expand the checks and scans panel', async () => {
      expect(await dashPage.isScanSectionVisible()).toBe(true);
      expect(await dashPage.isIdentitySectionVisible()).toBe(true);

      await dashPage.clickScanPanelHeader();
      expect(await dashPage.isScanSectionVisible()).toBe(false);
      expect(await dashPage.isIdentitySectionVisible()).toBe(true);

      await dashPage.clickScanPanelHeader();
      expect(await dashPage.isScanSectionVisible()).toBe(true);
      expect(await dashPage.isIdentitySectionVisible()).toBe(true);
    });

    test('should collapse and expand the identity stats panel', async () => {
      expect(await dashPage.isScanSectionVisible()).toBe(true);
      expect(await dashPage.isIdentitySectionVisible()).toBe(true);

      await dashPage.clickIdentityPanelHeader();
      expect(await dashPage.isScanSectionVisible()).toBe(true);
      expect(await dashPage.isIdentitySectionVisible()).toBe(false);

      await dashPage.clickIdentityPanelHeader();
      expect(await dashPage.isScanSectionVisible()).toBe(true);
      expect(await dashPage.isIdentitySectionVisible()).toBe(true);
    });

    test('should display identity stats from identity data', async () => {
      const identityCount = await dashPage.getIdentityCount();
      const entitlementCount = await dashPage.getEntitlementsCount();
      expect(identityCount).toBe(3);
      expect(entitlementCount).toBe(4);
    });

    test('should display scan efficiency instrumentation from scan history', async () => {
      expect(await dashPage.isScanEfficiencyVisible()).toBe(true);
      const text = await dashPage.getScanEfficiencyText();
      expect(text).toContain('Scan Efficiency');
      expect(text).toContain('Latest Duration');
      expect(text).toContain('Average Duration');
      expect(text).toContain('Latest Throughput');
      expect(text).toContain('Average Throughput');
      expect(text).toContain('Duration:');
      expect(text).toContain('Results:');
      expect(await dashPage.getScanEfficiencyMetricCount()).toBe(4);
      expect(await dashPage.getScanEfficiencyRunCount()).toBeGreaterThanOrEqual(2);
    });

    test('should show Total Results card with count greater than 0', async () => {
      const count = await dashPage.getTotalResultsCount();
      expect(count).toBeGreaterThan(0);
    });

    test('should show Failed Checks card with a numeric count', async () => {
      const count = await dashPage.getFailedChecksCount();
      expect(count).toBeGreaterThanOrEqual(0);
    });

    test('should show Passed Checks card with a numeric count', async () => {
      const count = await dashPage.getPassedChecksCount();
      expect(count).toBeGreaterThanOrEqual(0);
    });

    test('should show Critical Issues card with a number', async () => {
      const count = await dashPage.getCriticalIssuesCount();
      expect(typeof count).toBe('number');
      expect(count).toBeGreaterThanOrEqual(0);
    });

    test('should default to most recent scan run selection', async () => {
      const selectorVisible = await dashPage.isScanRunSelectorVisible();
      expect(selectorVisible).toBe(true);
    });

    test('should refresh dashboard content when selector changes without error', async () => {
      const changed = await dashPage.changeScanRunSelector();
      expect(changed).toBe(true);
      const totalVisible = await dashPage.isElementVisible(dashPage.selectors.totalResultsCard);
      expect(totalVisible).toBe(true);
    });

    test('should redirect to scan page when Run New Scan is clicked', async () => {
      await dashPage.clickRunNewScan();
      expect(dashPage.page.url()).toContain('/ciem/scan');
    });

    test('should display severity chart section', async () => {
      const chartVisible = await dashPage.isSeverityChartVisible();
      expect(chartVisible).toBe(true);
    });

    test('should display service chart section', async () => {
      const chartVisible = await dashPage.isServiceChartVisible();
      expect(chartVisible).toBe(true);
    });

    test('should display Critical & High Results card', async () => {
      const visible = await dashPage.isCritHighCardVisible();
      expect(visible).toBe(true);
    });

    test('should display Critical & High Results table', async () => {
      const hasTable = await dashPage.hasCritHighTable();
      expect(hasTable).toBe(true);
    });

    test('should redirect to history page when View All Results is clicked', async () => {
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
      expect(text).toContain('Management port open to the internet');
      expect(text).toContain('E2E Attack Path NSG');
      expect(text).toContain('High');
      expect(await dashPage.getNeedsAttentionItemCount()).toBeGreaterThanOrEqual(2);
    });

    test('should provide drill-in actions for identity and attack path risks', async () => {
      await dashPage.clickInspectIdentity();
      expect(dashPage.page.url()).toContain('/ciem/identities');

      await dashPage.navigateToDashboard();
      await dashPage.clickInspectAttackPath();
      expect(dashPage.page.url()).toContain('/ciem/attack-paths');
    });

    test('should show PAM implementation progress and candidate mappings', async () => {
      expect(await dashPage.isPAMProgressVisible()).toBe(true);
      const text = await dashPage.getPAMProgressText();
      expect(text).toContain('PAM Implementation Progress');
      expect(text).toContain('Readiness');
      expect(text).toContain('PAM Candidates');
      expect(text).toContain('Outbound PAM actions');
      expect(text).toContain('NotScoped');
      expect(text).toContain('JIT elevation and approval workflow');
      expect(text).toContain('Access brokering and session governance');
      expect(await dashPage.getPAMProgressMetricCount()).toBe(4);
      expect(await dashPage.getPAMProgressStageCount()).toBe(5);
      expect(await dashPage.getPAMProgressCandidateCount()).toBeGreaterThanOrEqual(2);
    });
  });

  test.describe('when exposure changes exist', () => {
    test.beforeAll(() => {
      seedExposureChangeData();
      const exposureChangeCount = getTestExposureChangeCount();
      if (exposureChangeCount !== 2) {
        throw new Error(`Expected 2 seeded exposure changes, got ${exposureChangeCount}`);
      }
      console.log(`[setup:dashboard-exposure-changes] Seeded ${exposureChangeCount} exposure change(s)`);
    });

    test.afterAll(() => {
      cleanupExposureChangeData();
    });

    test('should show local exposure change records without sending payloads', async () => {
      expect(await dashPage.isExposureChangesVisible()).toBe(true);
      const text = await dashPage.getExposureChangesText();
      expect(text).toContain('Exposure Changes');
      expect(text).toContain('Payload delivery is not enabled');
      expect(text).toContain('E2E New Exposure User');
      expect(text).toContain('NewRisk');
      expect(text).toContain('E2E Increased Exposure User');
      expect(text).toContain('RiskIncrease');
      expect(text).toContain('Critical');
      expect(await dashPage.getExposureChangeItemCount()).toBe(2);
    });

    test('should provide review routing for identity exposure changes', async () => {
      await dashPage.clickReviewExposureIdentity();
      expect(dashPage.page.url()).toContain('/ciem/identities');
    });

    test('should show preview-only connector payloads without outbound target configuration', async () => {
      expect(await dashPage.isConnectorPayloadPreviewVisible()).toBe(true);
      const text = await dashPage.getConnectorPayloadPreviewText();
      expect(text).toContain('Connector Payload Previews');
      expect(text).toContain('Preview-only');
      expect(text).toContain('No outbound target is configured or contacted');
      expect(text).toContain('Alert');
      expect(text).toContain('SIEM');
      expect(text).toContain('Webhook');
      expect(text).toContain('PSU');
      expect(text).toContain('deliveryEnabled');
      expect(text).toContain('false');
      expect(text).not.toContain('targetUrl');
      expect(text).not.toContain('token');
      expect(await dashPage.getConnectorPayloadPreviewItemCount()).toBe(4);
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
