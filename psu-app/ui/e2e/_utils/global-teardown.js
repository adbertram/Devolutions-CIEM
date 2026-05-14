const { cleanupTestData } = require('./cleanup');
const { runPSUCommand } = require('./psu-helpers');

module.exports = async function globalTeardown() {
  console.log('[teardown] Running global teardown...');

  // Restore auth profiles to pre-test state
  const backup = process.env._E2E_AUTH_PROFILES_BACKUP;
  if (backup) {
    try {
      const result = await runPSUCommand(`
        $backup = '${backup.replace(/'/g, "''")}' | ConvertFrom-Json
        Invoke-CIEMQuery -Query "DELETE FROM authentication_profile_assignments" -AsNonQuery | Out-Null
        Invoke-CIEMQuery -Query "DELETE FROM authentication_profiles" -AsNonQuery | Out-Null
        foreach ($profile in @($backup.Profiles)) {
          Invoke-CIEMQuery -Query @"
INSERT INTO authentication_profiles (
  id, name, provider, method, settings_json, secret_refs_json, created_at, updated_at
) VALUES (
  @id, @name, @provider, @method, @settings_json, @secret_refs_json, @created_at, @updated_at
)
"@ -Parameters @{
            id = [string]$profile.Id
            name = [string]$profile.Name
            provider = [string]$profile.Provider
            method = [string]$profile.Method
            settings_json = [string]$profile.SettingsJson
            secret_refs_json = [string]$profile.SecretRefsJson
            created_at = [string]$profile.CreatedAt
            updated_at = [string]$profile.UpdatedAt
          } -AsNonQuery | Out-Null
        }
        foreach ($assignment in @($backup.Assignments)) {
          Invoke-CIEMQuery -Query @"
INSERT INTO authentication_profile_assignments (
  usage_type, usage_id, authentication_profile_id, created_at, updated_at
) VALUES (
  @usage_type, @usage_id, @authentication_profile_id, @created_at, @updated_at
)
"@ -Parameters @{
            usage_type = [string]$assignment.UsageType
            usage_id = [string]$assignment.UsageId
            authentication_profile_id = [string]$assignment.AuthenticationProfileId
            created_at = [string]$assignment.CreatedAt
            updated_at = [string]$assignment.UpdatedAt
          } -AsNonQuery | Out-Null
        }
        [pscustomobject]@{
          Profiles = @($backup.Profiles).Count
          Assignments = @($backup.Assignments).Count
        } | ConvertTo-Json -Compress
      `);
      const restored = result.pipelineOutput && result.pipelineOutput.length > 0
        ? result.pipelineOutput[result.pipelineOutput.length - 1].value
        : '{"Profiles":0,"Assignments":0}';
      console.log(`[teardown] Restored auth profile state: ${restored}.`);
    } catch (err) {
      console.log(`[teardown] WARNING: Failed to restore auth profiles: ${err.message}`);
    }
  }

  cleanupTestData();
  console.log('[teardown] Complete. PSU server left running.');
};
