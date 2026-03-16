const BasePage = require('../../_utils/BasePage');
const { testConfig } = require('../../_utils/test-config');

class GraphPageHelpers extends BasePage {
  constructor(page) {
    super(page);
    this.selectors = {
      pageTitle: "h4:has-text('Identity Graph')",
      subtitle: "text=Explore identity-to-resource relationships and permissions",
      // Refresh button (always visible in header)
      refreshBtn: "button:has-text('Refresh Data')",
      refreshSpinner: '.MuiCircularProgress-root',
      // Empty state
      emptyStateCard: ".MuiCard-root:has-text('No Identity Graph Available')",
      emptyStateText: "text=No Identity Graph Available",
      emptyStateDescription: "text=Collect identity data from Azure to build the identity relationship graph.",
      buildGraphBtn: "button:has-text('Build Identity Graph')",
      buildGraphSpinner: '.MuiCircularProgress-root',
      buildGraphProgress: "text=/Starting identity graph build|Collecting|Building|Identity Data Collection/",
      buildGraphError: 'text=/Error:/',
      retryBtn: "button:has-text('Retry')",
      // Populated state (tabs)
      tabsContainer: '[role="tablist"]',
      allProvidersTab: "[role='tab']:has-text('All Providers')",
      providerTab: "[role='tab']",
      // Identity Access section
      identityAccessCard: ".MuiCard-root:has-text('Identity Access')",
      identityTypeSelect: "[role='combobox']",
      identitySearchInput: "[role='combobox']",
      expandGroupsSwitch: "input[type='checkbox']",
      searchBtn: "button:has-text('Search')",
      // Resource Access section
      resourceAccessCard: ".MuiCard-root:has-text('Resource Access')",
      visualizeBtn: "button:has-text('Visualize')",
      // Summary section
      summaryCard: ".MuiCard-root:has-text('Summary')"
    };
  }

  async navigateToGraphPage() {
    await this.goto(testConfig.pages.graph);
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

  async isEmptyStateDescriptionVisible() {
    return await this.isElementVisible(this.selectors.emptyStateDescription);
  }

  async isBuildGraphButtonVisible() {
    return await this.isElementVisible(this.selectors.buildGraphBtn);
  }

  async clickBuildGraph() {
    await this.click(this.selectors.buildGraphBtn);
  }

  async isBuildGraphSpinnerVisible() {
    return await this.isElementVisible(this.selectors.buildGraphSpinner);
  }

  async isBuildGraphProgressTextVisible() {
    return await this.isElementVisible(this.selectors.buildGraphProgress);
  }

  async isBuildGraphErrorVisible() {
    return await this.isElementVisible(this.selectors.buildGraphError);
  }

  async isRetryButtonVisible() {
    return await this.isElementVisible(this.selectors.retryBtn);
  }

  // Refresh button
  async isRefreshButtonVisible() {
    return await this.isElementVisible(this.selectors.refreshBtn);
  }

  async clickRefresh() {
    await this.click(this.selectors.refreshBtn);
  }

  async isRefreshSpinnerVisible() {
    return await this.isElementVisible(this.selectors.refreshSpinner);
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

  async clickTab(tabText) {
    await this.click(`[role='tab']:has-text('${tabText}')`);
    await this.page.waitForTimeout(2000);
  }

  // Content sections (populated state)
  async isIdentityAccessCardVisible() {
    return await this.isElementVisible(this.selectors.identityAccessCard);
  }

  async isResourceAccessCardVisible() {
    return await this.isElementVisible(this.selectors.resourceAccessCard);
  }

  async isSummaryCardVisible() {
    return await this.isElementVisible(this.selectors.summaryCard);
  }

  async isVisualizeButtonVisible() {
    return await this.isElementVisible(this.selectors.visualizeBtn);
  }

  async getSearchButtonCount() {
    return await this.page.locator(this.selectors.searchBtn).count();
  }
}

module.exports = GraphPageHelpers;
