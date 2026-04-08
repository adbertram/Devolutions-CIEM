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
      // View select
      viewSelect: '#envViewSelect',
      viewSelectCombobox: '[role="combobox"][aria-labelledby="envViewSelectlabel"]',
      // Assignment mode select (only visible in Identity view)
      assignmentModeSelect: '#envAssignmentModeSelect',
      assignmentModeSelectCombobox: '[role="combobox"][aria-labelledby="envAssignmentModeSelectlabel"]',
      // Action buttons
      startDiscoveryBtn: '#startDiscoveryBtn',
      // Summary cards (rendered inline in auto-load dynamic region)
      summaryCard: "#envChartArea .MuiCard-root:has-text('Tenants')",
      identitySummaryCard: "#envChartArea .MuiCard-root:has-text('Identities')",
      // Progress indicators (visible during async discovery job — in separate container)
      progressCircular: '#envDiscoveryProgress .MuiCircularProgress-root',
      progressBar: '#envDiscoveryProgress .MuiLinearProgress-root',
      progressText: '#envDiscoveryProgress .MuiTypography-body2',
      // Chart area (outer wrapper preserves #envChartArea for selectors)
      chartArea: '#envChartArea',
      treeContainer: '#ciemEnvTreeContainer',
      // Loading indicator (shown by New-UDDynamic -LoadingComponent during auto-load)
      loadingIndicator: '#envChartArea .MuiCircularProgress-root',
      // No resources discovered state (shown by auto-load when no discovery data)
      noResourcesText: "text=No Data Discovered",
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

  async clickStartDiscovery() {
    await this.click(this.selectors.startDiscoveryBtn);
  }

  async isStartDiscoveryButtonLoading() {
    // PSU -ShowLoading adds MuiCircularProgress inside the button while processing
    const btn = this.page.locator(this.selectors.startDiscoveryBtn);
    const spinner = btn.locator('.MuiCircularProgress-root');
    return await spinner.isVisible();
  }

  async waitForEnvironmentLoaded(timeout = 30000) {
    // Wait for auto-load to complete — either summary card (data) or no-resources text (empty)
    const infraSummary = this.page.locator(this.selectors.summaryCard);
    const identitySummary = this.page.locator(this.selectors.identitySummaryCard);
    const noResources = this.page.locator(this.selectors.noResourcesText);
    await infraSummary.or(identitySummary).or(noResources).first().waitFor({ state: 'visible', timeout });
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
    const caption = this.page.locator('#envChartArea .MuiTypography-caption', { hasText: new RegExp(`^${label}$`) });
    const countEl = caption.locator('..').locator('h6');
    return await countEl.textContent();
  }

  // --- Tree visualization (populated state) ---

  async isTreeContainerVisible() {
    return await this.isElementVisible(this.selectors.treeContainer);
  }

  // --- View select ---

  async isViewSelectVisible() {
    return await this.isElementVisible(this.selectors.viewSelectCombobox);
  }

  async getSelectedView() {
    return await this.getMUISelectValue('envViewSelect');
  }

  async selectView(value) {
    await this.selectMUIOption('envViewSelect', value);
    await this.page.waitForTimeout(2000);
  }

  // --- Assignment mode select (Identity view only) ---

  async isAssignmentModeSelectVisible() {
    return await this.isElementVisible(this.selectors.assignmentModeSelectCombobox);
  }

  async getSelectedAssignmentMode() {
    return await this.getMUISelectValue('envAssignmentModeSelect');
  }

  async selectAssignmentMode(value) {
    await this.selectMUIOption('envAssignmentModeSelect', value);
    await this.page.waitForTimeout(2000);
  }

  // --- Identity summary card ---

  async isIdentitySummaryCardVisible() {
    return await this.isElementVisible(this.selectors.identitySummaryCard);
  }

  // --- State detection ---

  async hasEnvironmentData() {
    // Check if summary card appeared (data auto-loaded) vs no-resources state
    const infraVisible = await this.isElementVisible(this.selectors.summaryCard);
    const identityVisible = await this.isElementVisible(this.selectors.identitySummaryCard);
    return infraVisible || identityVisible;
  }

  async waitForToastMessage(text) {
    return await this.waitForToast(text);
  }
}

module.exports = EnvironmentPageHelpers;
