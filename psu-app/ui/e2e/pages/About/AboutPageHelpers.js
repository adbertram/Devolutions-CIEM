const BasePage = require('../../_utils/BasePage');
const { testConfig } = require('../../_utils/test-config');

class AboutPageHelpers extends BasePage {
  constructor(page) {
    super(page);
    this.selectors = {
      pageTitle: "h4:has-text('About Devolutions CIEM')",
      mainCard: ".MuiCard-root:has-text('Cloud Infrastructure Entitlement Management')",
      description: "text=security scanning solution",
      featuresHeading: "h6:has-text('Key Features:')",
      featureItems: '.MuiListItem-root',
      versionHeading: "h6:has-text('Version Information:')",
      versionTable: 'table',
      learnMoreHeading: "h6:has-text('Learn More:')",
      pamLink: "a:has-text('Devolutions PAM')",
      docsLink: "a:has-text('Documentation')"
    };
  }

  async navigateToAboutPage() {
    await this.goto(testConfig.pages.about);
  }

  async isMainCardVisible() {
    return await this.isElementVisible(this.selectors.mainCard);
  }

  async getFeatureCount() {
    await this.waitForSelector(this.selectors.featureItems);
    return await this.page.locator(this.selectors.featureItems).count();
  }

  async getFeatureTexts() {
    await this.waitForSelector(this.selectors.featureItems);
    const items = this.page.locator(this.selectors.featureItems);
    const count = await items.count();
    const texts = [];
    for (let i = 0; i < count; i++) {
      texts.push(await items.nth(i).textContent());
    }
    return texts;
  }

  async isVersionTableVisible() {
    return await this.isElementVisible(this.selectors.versionTable);
  }

  async getVersionTableCellValue(propertyName) {
    await this.waitForSelector(this.selectors.versionTable);
    const row = this.page.locator(`tr:has-text("${propertyName}")`);
    const cells = row.locator('td');
    return await cells.nth(1).textContent();
  }

  async getVersionText() {
    return await this.getVersionTableCellValue('Module Version');
  }

  async getAuthorText() {
    return await this.getVersionTableCellValue('Author');
  }

  async isPAMLinkPresent() {
    return await this.isElementVisible(this.selectors.pamLink);
  }

  async isDocsLinkPresent() {
    return await this.isElementVisible(this.selectors.docsLink);
  }

  async getPAMLinkHref() {
    const link = this.page.locator(this.selectors.pamLink).first();
    return await link.getAttribute('href');
  }

  async getDocsLinkHref() {
    const link = this.page.locator(this.selectors.docsLink).first();
    return await link.getAttribute('href');
  }
}

module.exports = AboutPageHelpers;
