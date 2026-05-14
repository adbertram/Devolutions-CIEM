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
      reportRunSelector: '#reportRunSelector'
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
    await this.page.waitForFunction(selector => {
      const text = document.querySelector(selector)?.textContent ?? '';
      return /Run #\d+/.test(text) && text.includes('Scope ') && text.includes('Status ');
    }, this.selectors.reportContext);
    return (await this.page.locator(this.selectors.reportContext).textContent()).trim();
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
}

module.exports = ReportsPageHelpers;
