const { test: base, expect } = require('@playwright/test');

const fixtures = {
  ciemPage: async ({ page }, use) => {
    await use(page);
  }
};

const test = base.extend(fixtures);

module.exports = { test, expect };
