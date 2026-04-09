const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../../../../.env') });

const { isPSUReady, startPSU, waitForPSU, cancelRunningPSUJobs, runPSUCommand } = require('./psu-helpers');
const { cleanupTestData, seedChecks, seedTestData } = require('./cleanup');
const { testConfig } = require('./test-config');

module.exports = async function globalSetup() {
  console.log('[setup] Running global test setup...');

  // 1. Health check PSU — start if not ready
  const ready = await isPSUReady();
  if (!ready) {
    console.log('[setup] PSU not ready, starting...');
    startPSU();
    await waitForPSU();
  } else {
    console.log('[setup] PSU is already running.');
  }

  // 2. Verify CIEM app is accessible
  const ciemUrl = `${testConfig.urls.psu}/ciem/ciem`;
  try {
    const response = await fetch(ciemUrl);
    if (!response.ok) {
      throw new Error(`CIEM app returned ${response.status} at ${ciemUrl}`);
    }
    console.log('[setup] CIEM app is accessible.');
  } catch (error) {
    throw new Error(`Cannot reach CIEM app at ${ciemUrl}: ${error.message}`);
  }

  // 3. Cancel any zombie PSU jobs from previous killed test runs
  try {
    const { cancelled, running, queued } = await cancelRunningPSUJobs();
    if (cancelled > 0) {
      console.log(`[setup] Cancelled ${cancelled} zombie PSU jobs (${running} running, ${queued} queued).`);
    }
  } catch (err) {
    console.log(`[setup] Could not check PSU jobs: ${err.message}`);
  }

  // 4. Back up auth profiles so tests can't corrupt real credentials
  try {
    const backupResult = await runPSUCommand(`
      $profiles = @(Get-PSUCache -Key 'CIEM:AuthProfiles:Azure' -ErrorAction SilentlyContinue)
      if ($profiles.Count -gt 0) {
        $profiles | ConvertTo-Json -Depth 10 -Compress
      } else {
        '[]'
      }
    `);
    if (backupResult.statusCode === 2 || backupResult.statusCode === 11) {
      const raw = backupResult.pipelineOutput && backupResult.pipelineOutput.length > 0
        ? backupResult.pipelineOutput[backupResult.pipelineOutput.length - 1].value
        : '[]';
      process.env._E2E_AUTH_PROFILES_BACKUP = raw;
      const count = JSON.parse(raw).length;
      console.log(`[setup] Backed up ${count} auth profile(s).`);
    } else {
      console.log(`[setup] Could not back up auth profiles (status: ${backupResult.status}).`);
      process.env._E2E_AUTH_PROFILES_BACKUP = '[]';
    }
  } catch (err) {
    console.log(`[setup] Auth profile backup failed: ${err.message}`);
    process.env._E2E_AUTH_PROFILES_BACKUP = '[]';
  }

  // 5. Clean stale test data and seed fresh data (all via SSH+sqlite3)
  cleanupTestData();
  seedChecks();
  seedTestData();

  // 6. Export env vars for tests
  process.env.PSU_BASE_URL = testConfig.urls.psu;

  console.log('[setup] Global setup complete.');
};
