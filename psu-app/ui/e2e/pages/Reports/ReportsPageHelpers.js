const BasePage = require('../../_utils/BasePage');
const { testConfig } = require('../../_utils/test-config');

class ReportsPageHelpers extends BasePage {
  constructor(page) {
    super(page);
    this.selectors = {
      pageTitle: "h4:has-text('Reports')",
      reportResult: '[data-ciem-report-result="true"]',
      reportContext: '[data-ciem-report-context="true"]',
      reportSummary: '[data-ciem-report-summary="true"]',
      reportResultTable: '[data-ciem-report-result-table="true"]',
      generateReportButton: '#generateReportBtn',
      reportHistory: '[data-ciem-report-history="true"]',
      reportRunSelector: '#reportRunSelector',
      reportEvidencePairSelector: '#reportEvidencePairSelector',
      contextChip: key => `[data-ciem-report-context-chip="${key}"]`
    };
  }

  async navigateToReportsPage() {
    await this.goto(testConfig.pages.reports);
  }

  async getPageTitle() {
    return await this.getText(this.selectors.pageTitle);
  }

  async isReportResultVisible() {
    return await this.isElementVisible(this.selectors.reportResult);
  }

  async getReportContextText() {
    await this.waitForSelector(this.selectors.reportContext);
    return (await this.page.locator(this.selectors.reportContext).textContent()).trim();
  }

  async waitForContextChip(key) {
    await this.waitForSelector(this.selectors.contextChip(key));
  }

  async getContextChipText(key) {
    await this.waitForContextChip(key);
    return (await this.page.locator(this.selectors.contextChip(key)).textContent()).trim();
  }

  async getReportSummaryText() {
    await this.waitForSelector(this.selectors.reportSummary);
    return (await this.page.locator(this.selectors.reportSummary).textContent()).trim();
  }

  async getReportResultTableText() {
    await this.waitForSelector(this.selectors.reportResultTable);
    return (await this.page.locator(this.selectors.reportResultTable).textContent()).trim();
  }

  async isGenerateReportButtonVisible() {
    return await this.isElementVisible(this.selectors.generateReportButton);
  }

  async clickGenerateReport() {
    await this.click(this.selectors.generateReportButton);
    await this.waitForSelector(this.selectors.reportResult);
  }

  async getReportHistoryText() {
    await this.waitForSelector(this.selectors.reportHistory);
    return (await this.page.locator(this.selectors.reportHistory).textContent()).trim();
  }

  async isReportRunSelectorVisible() {
    return await this.isElementVisible(this.selectors.reportRunSelector);
  }

  async isReportEvidencePairSelectorVisible() {
    return await this.isElementVisible(this.selectors.reportEvidencePairSelector);
  }

  async expectEnvironmentalProgressCell({ status, signalType, signalKey }) {
    const tableText = await this.getReportResultTableText();
    if (!tableText.includes(status) || !tableText.includes(signalType) || !tableText.includes(signalKey)) {
      throw new Error(`Expected environmental progress row ${status}/${signalType}/${signalKey}`);
    }
  }
}

module.exports = ReportsPageHelpers;
