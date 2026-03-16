const { execSync } = require('child_process');
const { testConfig } = require('./test-config');

async function isPSUReady() {
  try {
    const url = `${testConfig.urls.psu}${testConfig.psu.healthEndpoint}`;
    const response = await fetch(url);
    if (!response.ok) return false;
    const data = await response.json();
    return data.loading === false;
  } catch {
    return false;
  }
}

function startPSU() {
  console.log('[psu] Starting local PSU server...');
  execSync(`"${testConfig.psu.setupScript}" start --no-wait`, {
    stdio: 'inherit',
    timeout: 30000
  });
}

async function waitForPSU(timeoutMs = testConfig.timeouts.serverStart) {
  const start = Date.now();
  const pollInterval = 2000;
  console.log(`[psu] Waiting for PSU to be ready (timeout: ${timeoutMs / 1000}s)...`);

  while (Date.now() - start < timeoutMs) {
    if (await isPSUReady()) {
      console.log(`[psu] PSU is ready (took ${Math.round((Date.now() - start) / 1000)}s)`);
      return;
    }
    await new Promise(r => setTimeout(r, pollInterval));
  }

  throw new Error(`PSU server did not become ready within ${timeoutMs / 1000}s`);
}

module.exports = { isPSUReady, startPSU, waitForPSU };
