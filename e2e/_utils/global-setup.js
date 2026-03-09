const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../../.env') });

const { isPSUReady, startPSU, waitForPSU } = require('./psu-helpers');
const { cleanupTestData, seedTestData } = require('./cleanup');
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

  // 3. Clean stale test data and seed fresh data
  cleanupTestData();
  seedTestData();

  // 4. Export env vars for tests
  process.env.PSU_BASE_URL = testConfig.urls.psu;
  process.env.CIEM_DB_PATH = testConfig.database.path;

  console.log('[setup] Global setup complete.');
};
