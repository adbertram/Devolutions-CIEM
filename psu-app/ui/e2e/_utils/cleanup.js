const { sshQuery, sshNonQuery } = require('./psu-helpers');

const TEST_PREFIX = '_E2E_TEST_';
const P = TEST_PREFIX; // shorthand for SQL literals

function cleanupTestData() {
  // Use '%_E2E_TEST_%' for tables with path-style IDs (e.g. /subscriptions/_E2E_TEST_sub-1)
  sshNonQuery([
    // Scan data
    `DELETE FROM scan_results WHERE scan_run_id LIKE '${P}%'`,
    `DELETE FROM scan_runs WHERE id LIKE '${P}%'`,
    `DELETE FROM checks WHERE id LIKE '${P}%'`,
    // Discovery data (path-style IDs need leading %)
    `DELETE FROM azure_arm_resources WHERE id LIKE '%${P}%'`,
    `DELETE FROM azure_entra_resources WHERE id LIKE '%${P}%'`,
    `DELETE FROM azure_effective_role_assignments WHERE principal_id LIKE '${P}%'`,
    // Graph data (edges first — path-style IDs need leading %)
    `DELETE FROM graph_edges WHERE source_id LIKE '%${P}%' OR target_id LIKE '%${P}%'`,
    `DELETE FROM graph_nodes WHERE id LIKE '%${P}%'`,
  ].join('; '));
  console.log('[cleanup] Test data cleaned up.');
}

function seedChecks() {
  const existing = sshQuery('SELECT COUNT(*) as cnt FROM checks')[0].cnt;
  if (existing > 0) return;

  const checks = [
    [P+'check_security_defaults',    'Azure','Entra',   'Ensure Security Defaults is enabled','Security defaults provide secure default settings for MFA and blocking legacy authentication.','Without security defaults, users may not be required to use MFA, leaving accounts vulnerable.','CRITICAL','Enable Security Defaults in Azure AD Properties.','azure_entra_security_defaults.ps1',0],
    [P+'check_mfa_enforcement',      'Azure','Entra',   'Ensure Multifactor Authentication is enforced for all users','Multi-factor authentication adds a second layer of identity verification.','Accounts without MFA are significantly more susceptible to compromise.','CRITICAL','Enable MFA for all users via Conditional Access policies.','azure_entra_mfa_enforcement.ps1',0],
    [P+'check_keyvault_access',      'Azure','KeyVault','Ensure Key Vault access is properly configured','Key Vault should use RBAC or access policies to control access.','Misconfigured Key Vault access may expose secrets and certificates.','HIGH','Configure RBAC-based access for Key Vault.','azure_keyvault_access.ps1',0],
    [P+'check_storage_encryption',   'Azure','Storage', 'Ensure storage account encryption is enabled','Azure Storage encrypts data at rest by default.','Unencrypted storage accounts expose data to unauthorized access.','MEDIUM','Enable encryption on all storage accounts.','azure_storage_encryption.ps1',0],
    [P+'check_nsg_rules',            'Azure','Network', 'Ensure NSG rules are properly configured','Network Security Groups control inbound and outbound traffic.','Overly permissive NSG rules may allow unauthorized network access.','MEDIUM','Review and tighten NSG rules.','azure_network_nsg_rules.ps1',0],
    [P+'check_resource_locks',       'Azure','ARM',     'Ensure resource locks are applied to critical resources','Resource locks prevent accidental deletion or modification.','Critical resources without locks may be accidentally deleted.','LOW','Apply CanNotDelete locks to production resources.','azure_arm_resource_locks.ps1',0],
    [P+'check_tags_compliance',      'Azure','ARM',     'Ensure resources have required tags','Tags help organize and manage Azure resources.','Missing tags make cost allocation and resource management difficult.','INFO','Apply organization-standard tags to all resources.','azure_arm_tags_compliance.ps1',0],
    [P+'check_disabled_legacy_auth', 'Azure','Entra',   'Ensure legacy authentication is disabled','Legacy authentication protocols do not support MFA.','Legacy auth bypass allows attackers to skip MFA requirements.','HIGH','Block legacy authentication via Conditional Access.','azure_entra_legacy_auth.ps1',1],
    [P+'check_disabled_guest_access','Azure','Entra',   'Ensure guest user access is restricted','Guest users should have limited access to directory resources.','Unrestricted guest access may expose sensitive directory information.','MEDIUM','Restrict guest user permissions in External Collaboration settings.','azure_entra_guest_access.ps1',1],
    [P+'check_disabled_public_access','Azure','Storage','Ensure public blob access is disabled','Public access to blob containers should be disabled.','Public blob access may expose sensitive data to the internet.','HIGH','Disable public access on all storage accounts.','azure_storage_public_access.ps1',1],
  ];
  const stmts = checks.map(c => {
    const vals = c.map(v => typeof v === 'number' ? v : `'${String(v).replace(/'/g, "''")}'`).join(', ');
    return `INSERT OR IGNORE INTO checks (id, provider, service, title, description, risk, severity, remediation_text, check_script, disabled) VALUES (${vals})`;
  });
  sshNonQuery(stmts.join('; '));
  console.log(`[seed] Seeded ${checks.length} test checks.`);
}

function seedTestData() {
  const provider = sshQuery('SELECT id FROM providers LIMIT 1')[0];
  if (!provider) { console.log('[seed] No providers -- skipping.'); return; }
  const checks = sshQuery('SELECT id, severity FROM checks LIMIT 10');
  if (checks.length === 0) { console.log('[seed] No checks -- skipping.'); return; }

  const now = new Date().toISOString();
  const critHigh = checks.filter(c => ['CRITICAL','HIGH'].includes((c.severity||'').toUpperCase()));
  const other = checks.filter(c => !['CRITICAL','HIGH'].includes((c.severity||'').toUpperCase()));
  const ordered = [...critHigh, ...other].slice(0, 5);
  const failCount = Math.min(2, ordered.length);
  const passCount = ordered.length - failCount;

  const stmts = [];
  // Scan Run 1 (most recent): 5 results, includes CRITICAL/HIGH failures
  stmts.push(`INSERT OR REPLACE INTO scan_runs (id, provider_id, status, started_at, completed_at, duration_seconds, total_results, failed_results, passed_results) VALUES ('${P}scan_run_1', '${provider.id}', 'Completed', '${now}', '${now}', 42.5, ${ordered.length}, ${failCount}, ${passCount})`);
  const statuses = ['FAIL','FAIL','PASS','PASS','PASS'];
  const descs = ['Security defaults are not enabled','MFA is not enforced','Key vault access is properly configured','Storage encryption is enabled','NSGs are configured correctly'];
  for (let i = 0; i < ordered.length; i++) {
    stmts.push(`INSERT OR REPLACE INTO scan_results (scan_run_id, check_id, status, status_extended, resource_id, resource_name) VALUES ('${P}scan_run_1', '${ordered[i].id}', '${statuses[i]}', '${descs[i]}', '${P}resource_${i}', 'Test Resource ${i}')`);
  }

  // Scan Run 2 (older): 3 results, all passed
  const olderDate = new Date(Date.now() - 86400000).toISOString();
  const run2Checks = checks.slice(0, 3);
  stmts.push(`INSERT OR REPLACE INTO scan_runs (id, provider_id, status, started_at, completed_at, duration_seconds, total_results, failed_results, passed_results) VALUES ('${P}scan_run_2', '${provider.id}', 'Completed', '${olderDate}', '${olderDate}', 18.2, ${run2Checks.length}, 0, ${run2Checks.length})`);
  for (let i = 0; i < run2Checks.length; i++) {
    stmts.push(`INSERT OR REPLACE INTO scan_results (scan_run_id, check_id, status, status_extended, resource_id, resource_name) VALUES ('${P}scan_run_2', '${run2Checks[i].id}', 'PASS', 'Check passed successfully', '${P}resource_old_${i}', 'Old Test Resource ${i}')`);
  }

  sshNonQuery(stmts.join('; '));
  console.log(`[seed] Seeded scan run 1 (${ordered.length} results, ${failCount} FAIL) and scan run 2 (${run2Checks.length} results, 0 FAIL).`);
}

function backupAndClearAllScanHistory() {
  const scanRuns = sshQuery('SELECT * FROM scan_runs');
  const scanResults = sshQuery('SELECT * FROM scan_results');
  sshNonQuery('DELETE FROM scan_results; DELETE FROM scan_runs');
  console.log(`[setup] Backed up ${scanRuns.length} scan runs and ${scanResults.length} scan results, cleared tables.`);
  return { scanRuns, scanResults, scanRunCount: scanRuns.length, scanResultCount: scanResults.length };
}

function restoreScanHistory(backup) {
  if (!backup) return;
  const { scanRuns = [], scanResults = [] } = backup;
  if (scanRuns.length === 0 && scanResults.length === 0) return;

  const stmts = ['DELETE FROM scan_results', 'DELETE FROM scan_runs'];
  for (const r of scanRuns) {
    const v = [r.id, r.provider_id, r.status, r.started_at, r.completed_at, r.duration_seconds, r.total_results, r.failed_results, r.passed_results]
      .map(x => x == null ? 'NULL' : `'${String(x).replace(/'/g, "''")}'`).join(', ');
    stmts.push(`INSERT OR REPLACE INTO scan_runs (id, provider_id, status, started_at, completed_at, duration_seconds, total_results, failed_results, passed_results) VALUES (${v})`);
  }
  for (const r of scanResults) {
    const v = [r.scan_run_id, r.check_id, r.status, r.status_extended, r.resource_id, r.resource_name]
      .map(x => x == null ? 'NULL' : `'${String(x).replace(/'/g, "''")}'`).join(', ');
    stmts.push(`INSERT OR REPLACE INTO scan_results (scan_run_id, check_id, status, status_extended, resource_id, resource_name) VALUES (${v})`);
  }
  sshNonQuery(stmts.join('; '));
  console.log(`[teardown] Restored ${scanRuns.length} scan runs and ${scanResults.length} scan results.`);
}

function getScanResultCount(scanRunId) {
  return sshQuery(`SELECT COUNT(*) as cnt FROM scan_results WHERE scan_run_id = '${scanRunId}'`)[0].cnt;
}

function seedEnvironmentData() {
  const now = new Date().toISOString();
  const tenant = `${P}tenant-0000-0000-0000-000000000001`;
  const sub1 = `${P}sub-0000-0000-0000-000000000001`;
  const sub2 = `${P}sub-0000-0000-0000-000000000002`;
  sshNonQuery([
    `INSERT OR REPLACE INTO azure_arm_resources (id, type, name, location, resource_group, subscription_id, tenant_id, collected_at) VALUES ('${P}rg1-vnet','microsoft.network/virtualnetworks','e2e-vnet-1','eastus','e2e-rg-1','${sub1}','${tenant}','${now}')`,
    `INSERT OR REPLACE INTO azure_arm_resources (id, type, name, location, resource_group, subscription_id, tenant_id, collected_at) VALUES ('${P}rg1-nsg','microsoft.network/networksecuritygroups','e2e-nsg-1','eastus','e2e-rg-1','${sub1}','${tenant}','${now}')`,
    `INSERT OR REPLACE INTO azure_arm_resources (id, type, name, location, resource_group, subscription_id, tenant_id, collected_at) VALUES ('${P}rg1-sa','microsoft.storage/storageaccounts','e2esa1','eastus','e2e-rg-1','${sub1}','${tenant}','${now}')`,
    `INSERT OR REPLACE INTO azure_arm_resources (id, type, name, location, resource_group, subscription_id, tenant_id, collected_at) VALUES ('${P}rg2-kv','microsoft.keyvault/vaults','e2e-kv-1','westus2','e2e-rg-2','${sub2}','${tenant}','${now}')`,
  ].join('; '));
  console.log('[seed] Seeded 4 ARM resources for Environment page tests.');
}

function cleanupEnvironmentData() {
  sshNonQuery(`DELETE FROM azure_arm_resources WHERE id LIKE '${P}%'`);
  console.log('[cleanup] Environment test data cleaned up.');
}

function getArmResourceCount() {
  return sshQuery('SELECT COUNT(*) as count FROM azure_arm_resources')[0].count;
}

function getTestArmResourceCount() {
  return sshQuery(`SELECT COUNT(*) as count FROM azure_arm_resources WHERE id LIKE '${P}%'`)[0].count;
}

function backupAndClearAllArmResources() {
  const rows = sshQuery(`SELECT * FROM azure_arm_resources WHERE id NOT LIKE '${P}%'`);
  sshNonQuery('DELETE FROM azure_arm_resources');
  console.log(`[setup] Backed up ${rows.length} ARM resources and cleared table.`);
  return rows;
}

function restoreArmResources(rows) {
  if (!rows || rows.length === 0) return;
  const cols = ['id','type','name','location','resource_group','subscription_id','tenant_id','kind','sku','identity','managed_by','plan','zones','tags','properties','collected_at'];
  const stmts = rows.map(r => {
    const vals = cols.map(c => r[c] == null ? 'NULL' : `'${String(r[c]).replace(/'/g, "''")}'`).join(', ');
    return `INSERT OR REPLACE INTO azure_arm_resources (${cols.join(', ')}) VALUES (${vals})`;
  });
  sshNonQuery(stmts.join('; '));
  console.log(`[teardown] Restored ${rows.length} ARM resources.`);
}

function clearStaleDiscoveryRuns() {
  sshNonQuery("UPDATE azure_discovery_runs SET status = 'Failed', completed_at = datetime('now') WHERE status = 'Running'");
}

function seedIdentityViewData() {
  const now = new Date().toISOString();
  sshNonQuery([
    // Graph nodes for identities (required by Identity Risk page query)
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, collected_at) VALUES ('${P}user-1','EntraUser','E2E Test User','azure','${now}')`,
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, collected_at) VALUES ('${P}sp-1','EntraServicePrincipal','E2E Test SP','azure','${now}')`,
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, collected_at) VALUES ('${P}group-1','EntraGroup','E2E Test Group','azure','${now}')`,
    // Entra resources
    `INSERT OR REPLACE INTO azure_entra_resources (id, type, display_name, properties, collected_at) VALUES ('${P}user-1','user','E2E Test User','{}','${now}')`,
    `INSERT OR REPLACE INTO azure_entra_resources (id, type, display_name, properties, collected_at) VALUES ('${P}sp-1','servicePrincipal','E2E Test SP','{}','${now}')`,
    `INSERT OR REPLACE INTO azure_entra_resources (id, type, display_name, properties, collected_at) VALUES ('${P}group-1','group','E2E Test Group','{}','${now}')`,
    // Subscription
    `INSERT OR REPLACE INTO azure_arm_resources (id, type, name, subscription_id, tenant_id, collected_at) VALUES ('/subscriptions/${P}sub-1','microsoft.resources/subscriptions','E2E Test Subscription','${P}sub-1','${P}tenant-1','${now}')`,
    // Effective role assignments
    `INSERT OR REPLACE INTO azure_effective_role_assignments (principal_id, principal_type, principal_display_name, original_principal_id, original_principal_type, role_definition_id, role_name, scope, computed_at) VALUES ('${P}user-1','User','E2E Test User','${P}user-1','User','${P}roledef-contrib','Contributor','/subscriptions/${P}sub-1/resourceGroups/e2e-rg-1','${now}')`,
    `INSERT OR REPLACE INTO azure_effective_role_assignments (principal_id, principal_type, principal_display_name, original_principal_id, original_principal_type, role_definition_id, role_name, scope, computed_at) VALUES ('${P}user-1','User','E2E Test User','${P}group-1','Group','${P}roledef-owner','Owner','/subscriptions/${P}sub-1','${now}')`,
    `INSERT OR REPLACE INTO azure_effective_role_assignments (principal_id, principal_type, principal_display_name, original_principal_id, original_principal_type, role_definition_id, role_name, scope, computed_at) VALUES ('${P}sp-1','ServicePrincipal','E2E Test SP','${P}sp-1','ServicePrincipal','${P}roledef-reader','Reader','/subscriptions/${P}sub-1','${now}')`,
    `INSERT OR REPLACE INTO azure_effective_role_assignments (principal_id, principal_type, principal_display_name, original_principal_id, original_principal_type, role_definition_id, role_name, scope, computed_at) VALUES ('${P}group-1','Group','E2E Test Group','${P}group-1','Group','${P}roledef-owner','Owner','/subscriptions/${P}sub-1','${now}')`,
  ].join('; '));
  console.log('[seed] Seeded identity view data (3 graph nodes, 3 entra resources, 1 subscription, 4 role assignments).');
}

function cleanupIdentityViewData() {
  sshNonQuery(`DELETE FROM azure_effective_role_assignments WHERE principal_id LIKE '${P}%'; DELETE FROM azure_entra_resources WHERE id LIKE '${P}%'; DELETE FROM graph_nodes WHERE id LIKE '${P}%' AND kind IN ('EntraUser','EntraServicePrincipal','EntraGroup')`);
  console.log('[cleanup] Identity View test data cleaned up.');
}

function getTestEffectiveRoleAssignmentCount() {
  return sshQuery(`SELECT COUNT(*) as count FROM azure_effective_role_assignments WHERE principal_id LIKE '${P}%'`)[0].count;
}

function seedIdentityAttackPathData() {
  const now = new Date().toISOString();
  sshNonQuery([
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, collected_at) VALUES ('__internet__','Internet','Internet','global','${now}')`,
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, collected_at) VALUES ('${P}nsg-ap-1','AzureNSG','E2E NSG','azure','${now}')`,
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, collected_at) VALUES ('${P}vm-ap-1','AzureVM','E2E VM','azure','${now}')`,
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, collected_at) VALUES ('${P}user-1','EntraManagedIdentity','E2E Test User','azure','${now}')`,
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, collected_at) VALUES ('/subscriptions/${P}sub-1','AzureSubscription','E2E Subscription','azure','${now}')`,
    `INSERT OR REPLACE INTO graph_edges (source_id, target_id, kind, properties, computed, collected_at) VALUES ('__internet__','${P}nsg-ap-1','AllowsInbound','{"open_ports":[{"port":3389,"protocol":"TCP","rule_name":"AllowRDP"}]}',1,'${now}')`,
    `INSERT OR REPLACE INTO graph_edges (source_id, target_id, kind, properties, computed, collected_at) VALUES ('${P}nsg-ap-1','${P}vm-ap-1','AttachedTo',null,1,'${now}')`,
    `INSERT OR REPLACE INTO graph_edges (source_id, target_id, kind, properties, computed, collected_at) VALUES ('${P}vm-ap-1','${P}user-1','HasManagedIdentity',null,0,'${now}')`,
    `INSERT OR REPLACE INTO graph_edges (source_id, target_id, kind, properties, computed, collected_at) VALUES ('${P}user-1','/subscriptions/${P}sub-1','HasRole','{"roleName":"Owner","privileged":true}',0,'${now}')`,
  ].join('; '));
  console.log('[seed] Seeded graph nodes/edges for Identity Attack Path tests.');
}

function cleanupIdentityAttackPathData() {
  sshNonQuery(`DELETE FROM graph_edges WHERE source_id LIKE '${P}%' OR target_id LIKE '${P}%'; DELETE FROM graph_nodes WHERE id LIKE '${P}%'`);
  console.log('[cleanup] Identity Attack Path graph data cleaned up.');
}

function seedAttackPathsPageData() {
  const now = new Date().toISOString();
  sshNonQuery([
    // Pattern 1: open-management-port
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, properties, collected_at) VALUES ('__internet__','Internet','Internet','global',null,'${now}')`,
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, properties, collected_at) VALUES ('${P}ap-nsg-1','AzureNSG','E2E Attack Path NSG','azure',null,'${now}')`,
    `INSERT OR REPLACE INTO graph_edges (source_id, target_id, kind, properties, computed, collected_at) VALUES ('__internet__','${P}ap-nsg-1','AllowsInbound','{"open_ports":[{"port":3389,"protocol":"TCP","rule_name":"AllowRDP"}]}',1,'${now}')`,
    // Pattern 2: disabled-account-with-roles
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, properties, collected_at) VALUES ('${P}ap-disabled-user','EntraUser','E2E Disabled User','azure','{"accountEnabled":false}','${now}')`,
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, properties, collected_at) VALUES ('${P}ap-sub-1','AzureSubscription','E2E Subscription','azure',null,'${now}')`,
    `INSERT OR REPLACE INTO graph_edges (source_id, target_id, kind, properties, computed, collected_at) VALUES ('${P}ap-disabled-user','${P}ap-sub-1','HasRole','{"roleName":"Contributor","privileged":false}',0,'${now}')`,
  ].join('; '));
  console.log('[seed] Seeded graph data for Attack Paths page tests (2 patterns).');
}

function cleanupAttackPathsPageData() {
  sshNonQuery(`DELETE FROM graph_edges WHERE source_id LIKE '${P}ap-%' OR target_id LIKE '${P}ap-%'; DELETE FROM graph_nodes WHERE id LIKE '${P}ap-%'`);
  console.log('[cleanup] Attack Paths page graph data cleaned up.');
}

function getTestAttackPathNodeCount() {
  return sshQuery(`SELECT COUNT(*) as count FROM graph_nodes WHERE id LIKE '${P}ap-%'`)[0].count;
}

function getCompletedDiscoveryRunCount() {
  return sshQuery("SELECT COUNT(*) as count FROM azure_discovery_runs WHERE status = 'Completed'")[0].count;
}

module.exports = {
  cleanupTestData, seedChecks, seedTestData,
  backupAndClearAllScanHistory, restoreScanHistory, getScanResultCount,
  seedEnvironmentData, cleanupEnvironmentData,
  getArmResourceCount, getTestArmResourceCount,
  backupAndClearAllArmResources, restoreArmResources,
  clearStaleDiscoveryRuns, getCompletedDiscoveryRunCount,
  seedIdentityViewData, cleanupIdentityViewData, getTestEffectiveRoleAssignmentCount,
  seedIdentityAttackPathData, cleanupIdentityAttackPathData,
  seedAttackPathsPageData, cleanupAttackPathsPageData, getTestAttackPathNodeCount,
  TEST_PREFIX
};
