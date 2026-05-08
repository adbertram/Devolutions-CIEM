const BasePage = require('../../_utils/BasePage');
const { navigateToRegisteredPage } = require('../../_utils/page-contract');

class DashboardPageHelpers extends BasePage {
  constructor(page) {
    super(page);
    this.selectors = {
      pageTitle: "h4:has-text('Devolutions CIEM Dashboard')",
      subtitle: "text=Cloud Infrastructure Entitlement Management",
      scanRunSelector: '#scanRunSelector',
      scanRunSelectorCombobox: '[role="combobox"][aria-labelledby="scanRunSelectorlabel"]',
      lastDiscoveryHeader: '#ciemLastDiscoveryHeader',
      localLastDiscoverySummary: '#lastDiscoverySummary',
      runNewScanBtn: "button:has-text('Run New Scan')",
      dashboardOverviewSection: '#dashboardOverviewSection',
      dashboardPrimaryStateGrid: '#dashboardPrimaryStateGrid',
      dashboardStatusMetrics: '[data-ciem-dashboard-status-metric="true"]',
      dashboardPriorityWorkSection: '#dashboardPriorityWorkSection',
      dashboardSupportingEvidenceSection: '#dashboardSupportingEvidenceSection',
      dashboardSupportingEvidencePanelGroup: '#dashboardSupportingEvidencePanelGroup',
      dashboardSupportingPanels: '#dashboardSupportingEvidencePanelGroup [id^="dashboard"][id$="Panel"]',
      checksAndScansPanel: '#dashboardChecksAndScansPanel',
      identityAndPAMPanel: '#dashboardIdentityAndPAMPanel',
      needsAttentionSection: '#dashboardNeedsAttentionSection',
      needsAttentionItems: '[data-ciem-needs-attention-item="true"]',
      needsAttentionEmpty: '[data-ciem-needs-attention-empty="true"]',
      inspectIdentityButton: '[data-ciem-inspect-identity="true"] button',
      inspectAttackPathButton: '[data-ciem-inspect-attack-path="true"] button',
      pamProgressSection: '#dashboardPAMProgressSection',
      pamProgressMetrics: '[data-ciem-pam-progress-metric="true"]',
      pamProgressStages: '[data-ciem-pam-progress-stage="true"]',
      pamProgressCandidates: '[data-ciem-pam-progress-candidate="true"]',
      pamProgressEmpty: '[data-ciem-pam-progress-empty="true"]',
      scanEfficiencySection: '#dashboardScanEfficiencySection',
      scanEfficiencyMetrics: '[data-ciem-scan-efficiency-metric="true"]',
      scanEfficiencyRuns: '[data-ciem-scan-efficiency-run="true"]',
      scanEfficiencyEmpty: '[data-ciem-scan-efficiency-empty="true"]',
      discoveryPhaseTimingSection: '#dashboardDiscoveryPhaseTiming',
      discoveryPhaseMetrics: '[data-ciem-discovery-phase-metric="true"]',
      scanSection: '#dashboardScanSection',
      identitySection: '#dashboardIdentitySection',
      scanSectionHeading: "#dashboardScanSection:has-text('Checks & Scans')",
      identitySectionHeading: "#dashboardIdentitySection:has-text('Identity Stats')",
      // Summary cards
      summaryCards: '.MuiGrid-container .MuiCard-root',
      totalResultsCard: ".MuiCard-root:has-text('Total Results')",
      failedChecksCard: ".MuiCard-root:has-text('Failed Checks')",
      passedChecksCard: ".MuiCard-root:has-text('Passed Checks')",
      criticalIssuesCard: ".MuiCard-root:has-text('Critical Issues')",
      scanSectionTotalResultsCard: "#dashboardScanSection .MuiCard-root:has-text('Total Results')",
      scanSectionFailedChecksCard: "#dashboardScanSection .MuiCard-root:has-text('Failed Checks')",
      identityCountCard: "#dashboardIdentitySection .MuiCard-root:has-text('Identities')",
      entitlementsCard: "#dashboardIdentitySection .MuiCard-root:has-text('Entitlements')",
      // Charts
      severityChartCard: ".MuiCard-root:has-text('Results by Severity')",
      serviceChartCard: ".MuiCard-root:has-text('Results by Service')",
      // Critical & High Results
      critHighCard: ".MuiCard-root:has-text('Critical & High Results')",
      viewAllResultsBtn: "button:has-text('View All Results')",
      critHighTable: ".MuiCard-root:has-text('Critical & High Results') table",
      noCritHighMessage: "text=No critical or high severity results",
      // Empty state
      emptyStateCard: '#dashboardNoScanDataState',
      emptyStateIcon: '.MuiCard-root svg',
      runFirstScanBtn: "#dashboardNoScanDataState button:has-text('Run Your First Scan')",
      // Dynamic content
      dashboardContent: '#dashboardContent'
    };
  }

  async navigateToDashboard() {
    await navigateToRegisteredPage(this, 'Dashboard');
    await this.waitForDashboardState();
  }

  async waitForDashboardState() {
    await this.page.locator(this.selectors.dashboardOverviewSection).waitFor({ state: 'visible', timeout: 15000 });
    await this.page
      .locator(`${this.selectors.needsAttentionSection}, ${this.selectors.emptyStateCard}`)
      .first()
      .waitFor({ state: 'visible', timeout: 15000 });
  }

  async getPageTitle() {
    return await this.getText(this.selectors.pageTitle);
  }

  async isSubtitleVisible() {
    return await this.isElementVisible(this.selectors.subtitle);
  }

  async isScanRunSelectorVisible() {
    return await this.isElementVisible(this.selectors.scanRunSelectorCombobox);
  }

  async isRunNewScanButtonVisible() {
    return await this.isElementVisible(this.selectors.runNewScanBtn);
  }

  async isScanSectionVisible() {
    return await this.isElementVisible(this.selectors.scanSection);
  }

  async isIdentitySectionVisible() {
    return await this.isElementVisible(this.selectors.identitySection);
  }

  async isScanSectionHideable() {
    return await this.page.locator(this.selectors.scanSection).getAttribute('data-hideable') === 'true';
  }

  async isIdentitySectionHideable() {
    return await this.page.locator(this.selectors.identitySection).getAttribute('data-hideable') === 'true';
  }

  async clickScanPanelHeader() {
    await this.expandChecksAndScansDetails();
  }

  async expandChecksAndScansDetails() {
    await this.expandSupportingPanel(this.selectors.checksAndScansPanel, this.selectors.scanSection, 'Checks & Scans');
  }

  async expandIdentityAndPAMDetails() {
    await this.expandSupportingPanel(this.selectors.identityAndPAMPanel, this.selectors.identitySection, 'Identity & PAM');
  }

  async expandSupportingPanel(panelSelector, visibleContentSelector, title) {
    if (await this.page.locator(visibleContentSelector).isVisible()) {
      return;
    }
    await this.page.locator(panelSelector).getByText(title).first().click();
    await this.page.locator(visibleContentSelector).waitFor({ state: 'visible', timeout: 15000 });
  }

  async getDashboardContentText() {
    await this.waitForDashboardState();
    return await this.page.locator('body').textContent();
  }

  async getAtAGlanceLayoutMetrics() {
    await this.page.locator(this.selectors.dashboardOverviewSection).waitFor({ state: 'visible', timeout: 15000 });
    await this.page.locator(this.selectors.dashboardPriorityWorkSection).waitFor({ state: 'visible', timeout: 15000 });
    await this.page.locator(this.selectors.dashboardSupportingEvidenceSection).waitFor({ state: 'visible', timeout: 15000 });
    await this.page.locator(this.selectors.dashboardSupportingEvidencePanelGroup).waitFor({ state: 'visible', timeout: 15000 });

    return await this.page.evaluate((selectors) => {
      const rectFor = (selector) => {
        const element = document.querySelector(selector);
        if (!element) {
          throw new Error(`Expected selector to be rendered: ${selector}`);
        }
        const rect = element.getBoundingClientRect();
        return {
          top: rect.top,
          bottom: rect.bottom,
          height: rect.height
        };
      };

      const metricRects = Array.from(document.querySelectorAll(selectors.dashboardStatusMetrics)).map((element) => {
        const rect = element.getBoundingClientRect();
        return {
          top: Math.round(rect.top),
          bottom: Math.round(rect.bottom),
          height: Math.round(rect.height)
        };
      });

      return {
        viewportHeight: window.innerHeight,
        documentScrollWidth: document.documentElement.scrollWidth,
        windowInnerWidth: window.innerWidth,
        hasHorizontalOverflow: document.documentElement.scrollWidth > window.innerWidth + 1,
        overview: rectFor(selectors.dashboardOverviewSection),
        priorityWork: rectFor(selectors.dashboardPriorityWorkSection),
        supportingEvidence: rectFor(selectors.dashboardSupportingEvidenceSection),
        metricCount: metricRects.length,
        metricRows: new Set(metricRects.map((rect) => rect.top)).size,
        metricRects
      };
    }, this.selectors);
  }

  async getSupportingPanelIds() {
    await this.page.locator(this.selectors.dashboardSupportingEvidencePanelGroup).waitFor({ state: 'visible', timeout: 15000 });
    return await this.page.locator(this.selectors.dashboardSupportingPanels).evaluateAll((nodes) => nodes.map((node) => node.id));
  }

  async isNeedsAttentionVisible() {
    return await this.isElementVisible(this.selectors.needsAttentionSection);
  }

  async getNeedsAttentionText() {
    await this.page.locator(this.selectors.needsAttentionSection).waitFor({ state: 'visible', timeout: 15000 });
    return (await this.page.locator(this.selectors.needsAttentionSection).textContent()).trim();
  }

  async getNeedsAttentionItemCount() {
    await this.page.locator(this.selectors.needsAttentionSection).waitFor({ state: 'visible', timeout: 15000 });
    return await this.page.locator(this.selectors.needsAttentionItems).count();
  }

  async hasNeedsAttentionEmptyState() {
    return await this.isElementVisible(this.selectors.needsAttentionEmpty);
  }

  async clickInspectIdentity() {
    await this.page.locator(this.selectors.inspectIdentityButton).first().click();
    await this.page.waitForURL('**/ciem/identities', { timeout: 15000 });
  }

  async clickInspectAttackPath() {
    await this.page.locator(this.selectors.inspectAttackPathButton).first().click();
    await this.page.waitForURL(/\/ciem\/attack-paths\?attackPathId=.+/, { timeout: 15000 });
  }

  async isPAMProgressVisible() {
    return await this.isElementVisible(this.selectors.pamProgressSection);
  }

  async getPAMProgressText() {
    await this.page.locator(this.selectors.pamProgressSection).waitFor({ state: 'visible', timeout: 15000 });
    return (await this.page.locator(this.selectors.pamProgressSection).textContent()).trim();
  }

  async getPAMProgressMetricCount() {
    await this.page.locator(this.selectors.pamProgressSection).waitFor({ state: 'visible', timeout: 15000 });
    return await this.page.locator(this.selectors.pamProgressMetrics).count();
  }

  async getPAMProgressStageCount() {
    await this.page.locator(this.selectors.pamProgressSection).waitFor({ state: 'visible', timeout: 15000 });
    return await this.page.locator(this.selectors.pamProgressStages).count();
  }

  async getPAMProgressCandidateCount() {
    await this.page.locator(this.selectors.pamProgressSection).waitFor({ state: 'visible', timeout: 15000 });
    return await this.page.locator(this.selectors.pamProgressCandidates).count();
  }

  async hasPAMProgressEmptyState() {
    return await this.isElementVisible(this.selectors.pamProgressEmpty);
  }

  async isScanEfficiencyVisible() {
    return await this.isElementVisible(this.selectors.scanEfficiencySection);
  }

  async getScanEfficiencyText() {
    await this.page.locator(this.selectors.scanEfficiencySection).waitFor({ state: 'visible', timeout: 15000 });
    return (await this.page.locator(this.selectors.scanEfficiencySection).textContent()).trim();
  }

  async getScanEfficiencyMetricCount() {
    await this.page.locator(this.selectors.scanEfficiencySection).waitFor({ state: 'visible', timeout: 15000 });
    return await this.page.locator(this.selectors.scanEfficiencyMetrics).count();
  }

  async getScanEfficiencyRunCount() {
    await this.page.locator(this.selectors.scanEfficiencySection).waitFor({ state: 'visible', timeout: 15000 });
    return await this.page.locator(this.selectors.scanEfficiencyRuns).count();
  }

  async getDiscoveryPhaseMetricCount() {
    await this.page.locator(this.selectors.discoveryPhaseTimingSection).waitFor({ state: 'visible', timeout: 15000 });
    return await this.page.locator(this.selectors.discoveryPhaseMetrics).count();
  }

  async hasScanEfficiencyEmptyState() {
    return await this.isElementVisible(this.selectors.scanEfficiencyEmpty);
  }

  async clickIdentityPanelHeader() {
    await this.expandIdentityAndPAMDetails();
  }

  async isScanRunSelectorInsideScanSection() {
    return await this.isElementVisible(`${this.selectors.scanSection} ${this.selectors.scanRunSelectorCombobox}`);
  }

  async isRunNewScanButtonInsideScanSection() {
    return await this.isElementVisible(`${this.selectors.scanSection} button:has-text('Run New Scan')`);
  }

  async isScanRunSelectorInsideIdentitySection() {
    return await this.isElementVisible(`${this.selectors.identitySection} ${this.selectors.scanRunSelectorCombobox}`);
  }

  async isLastDiscoveryHeaderVisible() {
    return await this.isElementVisible(this.selectors.lastDiscoveryHeader);
  }

  async getLocalLastDiscoverySummaryCount() {
    return await this.page.locator(this.selectors.localLastDiscoverySummary).count();
  }

  async getCardValue(cardSelector) {
    await this.waitForSelector(cardSelector);
    const card = this.page.locator(cardSelector);
    const h3 = card.locator('h3');
    return (await h3.textContent()).trim();
  }

  async getTotalResultsCount() {
    return parseInt(await this.getCardValue(this.selectors.totalResultsCard));
  }

  async getFailedChecksCount() {
    return parseInt(await this.getCardValue(this.selectors.failedChecksCard));
  }

  async getPassedChecksCount() {
    return parseInt(await this.getCardValue(this.selectors.passedChecksCard));
  }

  async getCriticalIssuesCount() {
    return parseInt(await this.getCardValue(this.selectors.criticalIssuesCard));
  }

  async getIdentityCount() {
    return parseInt(await this.getCardValue(this.selectors.identityCountCard));
  }

  async getEntitlementsCount() {
    return parseInt(await this.getCardValue(this.selectors.entitlementsCard));
  }

  async clickRunNewScan() {
    await this.click(this.selectors.runNewScanBtn);
    // PSU Invoke-UDRedirect is async — wait for URL change
    await this.page.waitForURL('**/ciem/scan', { timeout: 15000 });
  }

  async changeScanRunSelector() {
    const previousValue = await this.page.locator(this.selectors.scanRunSelector).inputValue();
    const combobox = this.page.locator(this.selectors.scanRunSelectorCombobox);
    await combobox.click();

    const options = this.page.locator('[role="option"]');
    const count = await options.count();
    if (count > 1) {
      await options.nth(1).click();
      await this.page.waitForFunction(
        ({ selector, previous }) => document.querySelector(selector).value !== previous,
        { selector: this.selectors.scanRunSelector, previous: previousValue },
        { timeout: 15000 }
      );
      await this.page
        .locator(`${this.selectors.scanSection} [role="progressbar"]`)
        .waitFor({ state: 'hidden', timeout: 15000 });
      await this.page.locator(this.selectors.totalResultsCard).waitFor({ state: 'visible', timeout: 15000 });
      return true;
    }
    return false;
  }

  async isSeverityChartVisible() {
    return await this.isElementVisible(this.selectors.severityChartCard);
  }

  async isServiceChartVisible() {
    return await this.isElementVisible(this.selectors.serviceChartCard);
  }

  async isCritHighCardVisible() {
    return await this.isElementVisible(this.selectors.critHighCard);
  }

  async hasCritHighTable() {
    return await this.isElementVisible(this.selectors.critHighTable);
  }

  async hasNoCritHighMessage() {
    return await this.isElementVisible(this.selectors.noCritHighMessage);
  }

  async clickViewAllResults() {
    await this.click(this.selectors.viewAllResultsBtn);
    await this.page.waitForURL('**/ciem/history', { timeout: 15000 });
  }

  // Empty state helpers
  async isEmptyStateVisible() {
    return await this.isElementVisible(this.selectors.emptyStateCard);
  }

  async clickRunFirstScan() {
    await this.click(this.selectors.runFirstScanBtn);
    await this.page.waitForURL('**/ciem/scan', { timeout: 15000 });
  }

  async hasScanData() {
    // Check if we have scan selector (data exists) or empty state (no data)
    const selectorVisible = await this.isElementVisible(this.selectors.scanRunSelectorCombobox);
    return selectorVisible;
  }
}

module.exports = DashboardPageHelpers;
