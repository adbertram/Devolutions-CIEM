const BasePage = require('../../_utils/BasePage');
const { testConfig } = require('../../_utils/test-config');

class NavigationPageHelpers extends BasePage {
  constructor(page) {
    super(page);
    // PSU renders two MuiDrawer-root elements (left nav + bottom); target the left one
    this.selectors = {
      navDrawer: '.MuiDrawer-anchorLeft',
      navList: '.MuiDrawer-anchorLeft .MuiList-root',
      navItem: '.MuiDrawer-anchorLeft .MuiListItem-root',
      navItemByLabel: (label) => `.MuiDrawer-anchorLeft .MuiListItem-root:has-text("${label}")`
    };
    this.expectedNavItems = [
      { label: 'Dashboard', href: '/ciem' },
      { label: 'Scan', href: '/ciem/scan' },
      { label: 'Scan History', href: '/ciem/history' },
      { label: 'Configuration', href: '/ciem/config' },
      { label: 'About', href: '/ciem/about' }
    ];
  }

  async navigateToDashboard() {
    await this.goto(testConfig.pages.dashboard);
  }

  async isNavDrawerVisible() {
    return await this.isElementVisible(this.selectors.navDrawer);
  }

  async getNavItemLabels() {
    await this.waitForSelector(this.selectors.navItem);
    const items = this.page.locator(this.selectors.navItem);
    const count = await items.count();
    const labels = [];
    for (let i = 0; i < count; i++) {
      labels.push((await items.nth(i).textContent()).trim());
    }
    return labels;
  }

  async getNavItemHref(label) {
    // PSU UDListItem with -Href renders <li button="/ciem/scan"> (href stored in "button" attribute)
    // Use exact text match to avoid "Scan" matching "Scan History"
    const item = this.page.locator(this.selectors.navItem).filter({ hasText: new RegExp(`^${label}$`) });
    const buttonAttr = await item.getAttribute('button');
    if (buttonAttr) return buttonAttr;
    // Fallback: check for nested <a> element
    const anchor = item.locator('a').first();
    const anchorCount = await anchor.count();
    if (anchorCount > 0) {
      return await anchor.getAttribute('href');
    }
    return await item.getAttribute('href');
  }

  async clickNavItem(label) {
    const item = this.page.locator(this.selectors.navItem).filter({ hasText: new RegExp(`^${label}$`) });
    await item.click();
    await this.waitForNavigation();
    await this.waitForPSUReady();
  }
}

module.exports = NavigationPageHelpers;
