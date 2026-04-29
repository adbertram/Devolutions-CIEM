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
      sectionPanelGroup: '#dashboardSectionPanels',
      scanPanel: '#dashboardScanPanel',
      identityPanel: '#dashboardIdentityPanel',
      scanSection: '#dashboardScanSection',
      identitySection: '#dashboardIdentitySection',
      scanSectionHeading: "#dashboardScanPanel:has-text('Prowler Checks & Scans')",
      identitySectionHeading: "#dashboardIdentityPanel:has-text('Identity Stats')",
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
      emptyStateCard: ".MuiCard-root:has-text('No Scan Data Available')",
      emptyStateIcon: '.MuiCard-root svg',
      runFirstScanBtn: "button:has-text('Run Your First Scan')",
      // Dynamic content
      dashboardContent: '#dashboardContent'
    };
  }

  async navigateToDashboard() {
    await navigateToRegisteredPage(this, 'Dashboard');
    await this.waitForDashboardState();
  }

  async waitForDashboardState() {
    await this.page.locator(this.selectors.sectionPanelGroup).waitFor({ state: 'visible', timeout: 15000 });
    await this.page
      .locator(`${this.selectors.totalResultsCard}, ${this.selectors.emptyStateCard}`)
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
    const section = this.page.locator(this.selectors.scanSection);
    const visibleBeforeClick = await section.isVisible();
    await this.page.locator(this.selectors.scanPanel).getByText('Prowler Checks & Scans').first().click();
    await section.waitFor({ state: visibleBeforeClick ? 'hidden' : 'visible', timeout: 15000 });
  }

  async clickIdentityPanelHeader() {
    const section = this.page.locator(this.selectors.identitySection);
    const visibleBeforeClick = await section.isVisible();
    await this.page.locator(this.selectors.identityPanel).getByText('Identity Stats').first().click();
    await section.waitFor({ state: visibleBeforeClick ? 'hidden' : 'visible', timeout: 15000 });
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
