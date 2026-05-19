const path = require('path');
const fs = require('fs');
const { chromium } = require('@playwright/test');
require('dotenv').config({ path: path.resolve(__dirname, '../../../../.env') });

const { isPSUReady, startPSU, waitForPSU, cancelRunningPSUJobs, runPSUCommand } = require('./psu-helpers');
const { cleanupTestData, seedChecks, seedTestData } = require('./cleanup');
const { testConfig } = require('./test-config');

const AUTH_STATE_PATH = path.resolve(__dirname, '../.auth/psu-ui-state.json');

function ensureEmptyAuthState() {
  fs.mkdirSync(path.dirname(AUTH_STATE_PATH), { recursive: true });
  fs.writeFileSync(AUTH_STATE_PATH, JSON.stringify({ cookies: [], origins: [] }, null, 2));
}

async function createAuthenticatedUiState() {
  if (!testConfig.environment.uiUsername || !testConfig.environment.uiPassword) {
    const prefix = testConfig.environment.name.toUpperCase();
    throw new Error(`${prefix}_PSU_USERNAME and ${prefix}_PSU_PASSWORD are required because ${testConfig.environment.name} PSU redirects CIEM pages to /login.`);
  }

  const browser = await chromium.launch({ headless: true });
  try {
    const context = await browser.newContext();
    const page = await context.newPage();
    await page.goto(`${testConfig.urls.psu}/ciem/ciem/config`, { waitUntil: 'networkidle' });
    if (!new URL(page.url()).pathname.startsWith('/login')) {
      await context.storageState({ path: AUTH_STATE_PATH });
      return;
    }

    await page.getByRole('textbox', { name: 'User Name' }).fill(testConfig.environment.uiUsername);
    await page.getByRole('textbox', { name: 'Password' }).fill(testConfig.environment.uiPassword);
    await page.getByRole('button', { name: 'Login' }).click();
    await page.waitForLoadState('networkidle');

    const finalPath = new URL(page.url()).pathname;
    if (finalPath.startsWith('/login')) {
      throw new Error(`PSU UI login failed for ${testConfig.environment.name}; browser remained on ${page.url()}.`);
    }

    await context.storageState({ path: AUTH_STATE_PATH });
  }
  finally {
    await browser.close();
  }
}

async function prepareUiAuthState() {
  ensureEmptyAuthState();

  const ciemUrl = `${testConfig.urls.psu}/ciem/ciem`;
  const response = await fetch(ciemUrl);
  const body = await response.text();
  const finalUrl = new URL(response.url);
  const requiresLogin = finalUrl.pathname.startsWith('/login') || body.includes('Log in to your account');

  if (requiresLogin) {
    await createAuthenticatedUiState();
  }

  return { response, requiresLogin };
}

module.exports = async function globalSetup() {
  console.log('[setup] Running global test setup...');

  // 1. Health check PSU — start local if not ready; remote targets must already be available
  const ready = await isPSUReady();
  if (!ready) {
    if (!testConfig.environment.usesPublishPointDatabase) {
      throw new Error(`${testConfig.environment.name} PSU is not ready at ${testConfig.urls.psu}${testConfig.psu.healthEndpoint}`);
    }
    console.log('[setup] PSU not ready, starting...');
    startPSU();
    await waitForPSU();
  } else {
    console.log('[setup] PSU is already running.');
  }

  // 2. Verify CIEM app is accessible
  try {
    const { response, requiresLogin } = await prepareUiAuthState();
    if (!response.ok) {
      throw new Error(`CIEM app returned ${response.status} at ${testConfig.urls.psu}/ciem/ciem`);
    }
    const authStatus = requiresLogin ? 'authenticated' : 'anonymous';
    console.log(`[setup] CIEM app is accessible (${authStatus}).`);
  } catch (error) {
    throw new Error(`Cannot reach CIEM app at ${testConfig.urls.psu}/ciem/ciem: ${error.message}`);
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
      $profiles = @(Invoke-CIEMQuery -Query "SELECT id, name, provider, method, settings_json, secret_refs_json, created_at, updated_at FROM authentication_profiles")
      $assignments = @(Invoke-CIEMQuery -Query "SELECT usage_type, usage_id, authentication_profile_id, created_at, updated_at FROM authentication_profile_assignments")
      [pscustomobject]@{
        Profiles = @($profiles | ForEach-Object {
          [pscustomobject]@{
            Id = [string]$_.id
            Name = [string]$_.name
            Provider = [string]$_.provider
            Method = [string]$_.method
            SettingsJson = [string]$_.settings_json
            SecretRefsJson = [string]$_.secret_refs_json
            CreatedAt = [string]$_.created_at
            UpdatedAt = [string]$_.updated_at
          }
        })
        Assignments = @($assignments | ForEach-Object {
          [pscustomobject]@{
            UsageType = [string]$_.usage_type
            UsageId = [string]$_.usage_id
            AuthenticationProfileId = [string]$_.authentication_profile_id
            CreatedAt = [string]$_.created_at
            UpdatedAt = [string]$_.updated_at
          }
        })
      } | ConvertTo-Json -Depth 10 -Compress
    `);
    if (backupResult.statusCode === 2 || backupResult.statusCode === 11) {
      const raw = backupResult.pipelineOutput && backupResult.pipelineOutput.length > 0
        ? backupResult.pipelineOutput[backupResult.pipelineOutput.length - 1].value
        : '{"Profiles":[],"Assignments":[]}';
      process.env._E2E_AUTH_PROFILES_BACKUP = raw;
      const backup = JSON.parse(raw);
      console.log(`[setup] Backed up ${backup.Profiles.length} auth profile(s) and ${backup.Assignments.length} assignment(s).`);
    } else {
      console.log(`[setup] Could not back up auth profiles (status: ${backupResult.status}).`);
      process.env._E2E_AUTH_PROFILES_BACKUP = '{"Profiles":[],"Assignments":[]}';
    }
  } catch (err) {
    console.log(`[setup] Auth profile backup failed: ${err.message}`);
    process.env._E2E_AUTH_PROFILES_BACKUP = '{"Profiles":[],"Assignments":[]}';
  }

  // 5. Clean stale test data and seed fresh data in the selected PSU target
  cleanupTestData();
  seedChecks();
  seedTestData();

  // 6. Export env vars for tests
  process.env.PSU_BASE_URL = testConfig.urls.psu;

  console.log('[setup] Global setup complete.');
};
