const BasePage = require('../../_utils/BasePage');
const { testConfig } = require('../../_utils/test-config');

class EnvironmentPageHelpers extends BasePage {
  constructor(page) {
    super(page);
    this.selectors = {
      pageTitle: "h4:has-text('Environment Explorer')",
      subtitle: "text=Explore your cloud infrastructure hierarchy - expand and collapse nodes to navigate resources",
      // Provider and Layout selects (MUI renders hidden input + visible combobox)
      providerSelect: '#envProviderSelect',
      providerSelectCombobox: '[role="combobox"][aria-labelledby="envProviderSelectlabel"]',
      layoutSelect: '#envOrientSelect',
      layoutSelectCombobox: '[role="combobox"][aria-labelledby="envOrientSelectlabel"]',
      // Action buttons
      startDiscoveryBtn: '#startDiscoveryBtn',
      loadEnvBtn: '#loadEnvBtn',
      // Summary area (populated after Load Environment)
      summaryArea: '#envSummary',
      summaryCard: "#envSummary .MuiCard-root",
      // Count selectors use getSummaryCount() locator chaining — not CSS selectors
      // Progress indicators (visible during async discovery job)
      progressCircular: '#envChartArea .MuiCircularProgress-root',
      progressBar: '#envChartArea .MuiLinearProgress-root',
      progressText: '#envChartArea .MuiTypography-body2',
      // Chart area
      chartArea: '#envChartArea',
      treeContainer: '#ciemEnvTreeContainer',
      // Empty state (initial, before Load Environment)
      emptyStateCard: "#envChartArea .MuiCard-root:has-text('No Environment Data Loaded')",
      emptyStateText: "text=No Environment Data Loaded",
      emptyStateDescription: "text=Select a provider and click",
      // No resources discovered state (after Load, but no discovery data)
      noResourcesText: "text=No Resources Discovered",
      noResourcesDescription: "text=Run Azure discovery first"
    };
  }

  async navigateToEnvironmentPage() {
    await this.goto(testConfig.pages.environment);
    // Wait for PSU dynamic content to render
    await this.page.waitForTimeout(3000);
  }

  // --- Page header ---

  async getPageTitle() {
    return await this.getText(this.selectors.pageTitle);
  }

  async isSubtitleVisible() {
    return await this.isElementVisible(this.selectors.subtitle);
  }

  // --- Provider select ---

  async isProviderSelectVisible() {
    return await this.isElementVisible(this.selectors.providerSelectCombobox);
  }

  async getSelectedProvider() {
    return await this.getMUISelectValue('envProviderSelect');
  }

  async selectProvider(value) {
    await this.selectMUIOption('envProviderSelect', value);
    await this.page.waitForTimeout(1000);
  }

  // --- Layout select ---

  async isLayoutSelectVisible() {
    return await this.isElementVisible(this.selectors.layoutSelectCombobox);
  }

  async getSelectedLayout() {
    return await this.getMUISelectValue('envOrientSelect');
  }

  async selectLayout(value) {
    await this.selectMUIOption('envOrientSelect', value);
    await this.page.waitForTimeout(1000);
  }

  // --- Action buttons ---

  async isStartDiscoveryButtonVisible() {
    return await this.isElementVisible(this.selectors.startDiscoveryBtn);
  }

  async isLoadEnvironmentButtonVisible() {
    return await this.isElementVisible(this.selectors.loadEnvBtn);
  }

  async clickStartDiscovery() {
    await this.click(this.selectors.startDiscoveryBtn);
  }

  async isStartDiscoveryButtonLoading() {
    // PSU -ShowLoading adds MuiCircularProgress inside the button while processing
    const btn = this.page.locator(this.selectors.startDiscoveryBtn);
    const spinner = btn.locator('.MuiCircularProgress-root');
    return await spinner.isVisible();
  }

  async clickLoadEnvironment() {
    await this.click(this.selectors.loadEnvBtn);
    // Wait for PSU server-side processing (fetches hierarchy, builds tree, renders chart)
    // -ShowLoading blocks UI during processing; 873 ARM resources takes ~10-15s
    try {
      await this.page.waitForSelector(this.selectors.summaryCard, { state: 'visible', timeout: 30000 });
    } catch {
      // Summary card may not appear if no data — fall through to hasEnvironmentData() check
      await this.page.waitForTimeout(3000);
    }
  }

  // --- Progress indicators (during async discovery) ---

  async isProgressVisible() {
    // Check for either circular (initial render) or linear (active polling) progress
    const circular = await this.isElementVisible(this.selectors.progressCircular);
    const linear = await this.isElementVisible(this.selectors.progressBar);
    return circular || linear;
  }

  async waitForProgress(timeout = 15000) {
    // Wait for either circular or linear progress to appear
    const indicator = this.page.locator(
      `${this.selectors.progressCircular}, ${this.selectors.progressBar}`
    );
    await indicator.first().waitFor({ state: 'visible', timeout });
  }

  async getProgressText() {
    const el = this.page.locator(this.selectors.progressText).first();
    if (await el.isVisible()) {
      return await el.textContent();
    }
    return null;
  }

  // --- Empty state (before load) ---

  async isEmptyStateCardVisible() {
    return await this.isElementVisible(this.selectors.emptyStateCard);
  }

  async isEmptyStateTextVisible() {
    return await this.isElementVisible(this.selectors.emptyStateText);
  }

  async isEmptyStateDescriptionVisible() {
    return await this.isElementVisible(this.selectors.emptyStateDescription);
  }

  // --- No resources discovered state ---

  async isNoResourcesTextVisible() {
    return await this.isElementVisible(this.selectors.noResourcesText);
  }

  async isNoResourcesDescriptionVisible() {
    return await this.isElementVisible(this.selectors.noResourcesDescription);
  }

  // --- Summary card (populated state) ---

  async isSummaryCardVisible() {
    return await this.isElementVisible(this.selectors.summaryCard);
  }

  async getSummaryCount(label) {
    // Find the caption label, go up to parent div, then get the h6 count value.
    // This avoids :has-text() ambiguity where ancestor divs also match.
    const caption = this.page.locator('#envSummary .MuiTypography-caption', { hasText: new RegExp(`^${label}$`) });
    const countEl = caption.locator('..').locator('h6');
    return await countEl.textContent();
  }

  // --- Tree visualization (populated state) ---

  async isTreeContainerVisible() {
    return await this.isElementVisible(this.selectors.treeContainer);
  }

  // --- State detection ---

  async hasEnvironmentData() {
    // After clicking Load Environment, check if summary card appeared (data loaded)
    // vs empty state or no-resources state
    return await this.isElementVisible(this.selectors.summaryCard);
  }

  async waitForToastMessage(text) {
    return await this.waitForToast(text);
  }
}

module.exports = EnvironmentPageHelpers;
