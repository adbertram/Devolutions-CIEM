class BasePage {
  constructor(page) {
    this.page = page;
  }

  async goto(path) {
    await this.page.goto(path, { waitUntil: 'networkidle' });
    await this.waitForPSUReady();
  }

  async waitForSelector(selector, options = {}) {
    await this.page.waitForSelector(selector, {
      state: 'visible',
      timeout: 15000,
      ...options
    });
  }

  async getElement(selector) {
    await this.waitForSelector(selector);
    return this.page.locator(selector);
  }

  async click(selector) {
    await this.waitForSelector(selector);
    await this.page.click(selector);
  }

  async fill(selector, value) {
    await this.waitForSelector(selector);
    await this.page.fill(selector, value);
  }

  async getText(selector) {
    await this.waitForSelector(selector);
    return this.page.locator(selector).textContent();
  }

  async isElementVisible(selector) {
    return await this.page.locator(selector).isVisible();
  }

  async waitForNavigation() {
    await this.page.waitForLoadState('networkidle');
  }

  async waitForPSUReady() {
    // Wait for MUI circular progress spinner to disappear (PSU server-side rendering indicator)
    const spinner = this.page.locator('.MuiCircularProgress-root');
    const spinnerCount = await spinner.count();
    if (spinnerCount > 0) {
      await spinner.first().waitFor({ state: 'hidden', timeout: 30000 });
    }
  }

  async waitForElement(selector, timeout = 15000) {
    await this.page.locator(selector).waitFor({ state: 'visible', timeout });
  }

  async waitForToast(textContains) {
    // PSU uses iziToast, not MUI Snackbar
    const toast = this.page.locator(`.iziToast:has-text("${textContains}")`);
    await toast.waitFor({ state: 'visible', timeout: 15000 });
    return toast;
  }

  async selectMUIOption(selectId, optionValue) {
    // PSU MUI Select: hidden <input id="selectId"> + visible <div role="combobox">
    // Click the combobox div (not the hidden input) to open the dropdown
    const combobox = this.page.locator(`[role="combobox"][aria-labelledby="${selectId}label"]`);
    await combobox.click();
    // Click the option by data-value attribute
    await this.page.locator(`[role="option"][data-value="${optionValue}"]`).click();
  }

  async getMUISelectValue(selectId) {
    // Read from the hidden input that holds the actual value
    return await this.page.locator(`#${selectId}`).inputValue();
  }
}

module.exports = BasePage;
