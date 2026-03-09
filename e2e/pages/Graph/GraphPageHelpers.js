const BasePage = require('../../_utils/BasePage');
const { testConfig } = require('../../_utils/test-config');

class GraphPageHelpers extends BasePage {
  constructor(page) {
    super(page);
    this.selectors = {
      pageTitle: "h4:has-text('Identity Graph')",
      subtitle: "text=Explore identity-to-resource relationships",
      // Empty state
      emptyStateCard: ".MuiCard-root:has-text('No Identity Graph Available')",
      emptyStateText: "text=No Identity Graph Available",
      emptyStateDescription: "text=Run a security scan to build",
      runScanBtn: "button:has-text('Run a Scan')",
      // Populated state (tabs)
      tabsContainer: '[role="tablist"]',
      allProvidersTab: "[role='tab']:has-text('All Providers')",
      providerTab: "[role='tab']"
    };
  }

  async navigateToGraphPage() {
    await this.goto(testConfig.pages.graph);
    // Wait for dynamic content
    await this.page.waitForTimeout(3000);
  }

  async getPageTitle() {
    return await this.getText(this.selectors.pageTitle);
  }

  async isSubtitleVisible() {
    return await this.isElementVisible(this.selectors.subtitle);
  }

  // Empty state
  async isEmptyStateVisible() {
    return await this.isElementVisible(this.selectors.emptyStateCard);
  }

  async isEmptyStateTextVisible() {
    return await this.isElementVisible(this.selectors.emptyStateText);
  }

  async isRunScanButtonVisible() {
    return await this.isElementVisible(this.selectors.runScanBtn);
  }

  async clickRunScan() {
    await this.click(this.selectors.runScanBtn);
    await this.waitForNavigation();
  }

  // Populated state
  async hasCollectedData() {
    return await this.isElementVisible(this.selectors.tabsContainer);
  }

  async isTabsContainerVisible() {
    return await this.isElementVisible(this.selectors.tabsContainer);
  }

  async getTabLabels() {
    const tabs = this.page.locator(this.selectors.providerTab);
    const count = await tabs.count();
    const labels = [];
    for (let i = 0; i < count; i++) {
      labels.push((await tabs.nth(i).textContent()).trim());
    }
    return labels;
  }
}

module.exports = GraphPageHelpers;
