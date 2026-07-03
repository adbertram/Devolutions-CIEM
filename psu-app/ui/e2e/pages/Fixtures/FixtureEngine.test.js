const { test, expect } = require('../../_utils/BaseTestSetup');
const {
  backupAndApplyFixture,
  getFixtureTableCounts,
  loadFixture,
  restoreFixtureBackup,
  validateFixture
} = require('../../_utils/fixtures');

test.describe('E2E fixture engine', () => {
  test('rejects unknown fixture fields', () => {
    const fixture = loadFixture('scan-history-summary');
    const invalid = { ...fixture, unknownField: true };

    expect(() => validateFixture(invalid)).toThrow(/Unknown fixture field 'unknownField'/);
  });

  test('backs up, applies, verifies, and restores the scan history fixture', () => {
    const backup = backupAndApplyFixture('scan-history-summary');

    try {
      const counts = getFixtureTableCounts('scan-history-summary');
      expect(counts.checks).toBe(10);
      expect(counts.scan_runs).toBe(2);
      expect(counts.scan_run_providers).toBe(2);
      expect(counts.scan_run_check_snapshots).toBe(8);
      expect(counts.scan_results).toBe(8);
    } finally {
      restoreFixtureBackup(backup);
    }
  });
});
