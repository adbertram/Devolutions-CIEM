const { cleanupTestData } = require('./cleanup');
const { runPSUCommand } = require('./psu-helpers');

module.exports = async function globalTeardown() {
  console.log('[teardown] Running global teardown...');

  // Restore auth profiles to pre-test state
  const backup = process.env._E2E_AUTH_PROFILES_BACKUP;
  if (backup && backup !== '[]') {
    try {
      const result = await runPSUCommand(`
        $profiles = '${backup.replace(/'/g, "''")}' | ConvertFrom-Json
        Set-PSUCache -Key 'CIEM:AuthProfiles:Azure' -Value @($profiles) -Persist
        @($profiles).Count
      `);
      const count = result.pipelineOutput && result.pipelineOutput.length > 0
        ? result.pipelineOutput[result.pipelineOutput.length - 1].value
        : '?';
      console.log(`[teardown] Restored ${count} auth profile(s).`);
    } catch (err) {
      console.log(`[teardown] WARNING: Failed to restore auth profiles: ${err.message}`);
    }
  }

  cleanupTestData();
  console.log('[teardown] Complete. PSU server left running.');
};
