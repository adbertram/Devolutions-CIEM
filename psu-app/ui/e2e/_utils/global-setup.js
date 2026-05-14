const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../../../../.env') });

const { isPSUReady, startPSU, waitForPSU, cancelRunningPSUJobs, runPSUCommand } = require('./psu-helpers');
const { cleanupTestData, seedChecks, seedTestData } = require('./cleanup');
const { testConfig } = require('./test-config');

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
