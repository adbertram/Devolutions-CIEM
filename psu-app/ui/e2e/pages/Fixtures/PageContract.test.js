const { test, expect } = require('../../_utils/BaseTestSetup');
const { validatePageRegistryContract } = require('../../_utils/page-contract');

test.describe('E2E page contract registry', () => {
  test('validates shared page registry test metadata', () => {
    expect(validatePageRegistryContract()).toBe(true);
  });
});
