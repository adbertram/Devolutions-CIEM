const { defineConfig, devices } = require('@playwright/test');
const { testConfig } = require('./_utils/test-config');

const baseURL = testConfig.urls.psu;

module.exports = defineConfig({
  testDir: './pages',
  testMatch: '**/*.test.js',
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: 0,
  workers: 1,
  reporter: 'list',
  timeout: 120000,
  expect: {
    timeout: 15000
  },
  globalSetup: require.resolve('./_utils/global-setup.js'),
  globalTeardown: require.resolve('./_utils/global-teardown.js'),
  use: {
    baseURL,
    trace: 'on-first-retry',
    headless: true,
    actionTimeout: 15000,
    navigationTimeout: 30000
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] }
    }
  ]
});
