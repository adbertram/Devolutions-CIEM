const {
  sshQuery,
  sshNonQuery,
  LONG_RUNNING_ATTACK_PATH_RULE_ID,
  LONG_RUNNING_ATTACK_PATH_SCRIPT_NAME,
  LONG_RUNNING_ATTACK_PATH_REMEDIATION_SCRIPT_PATH
} = require('./psu-helpers');
const { insertFixtureRows, loadFixture } = require('./fixtures');

const TEST_PREFIX = '_E2E_TEST_';
const P = TEST_PREFIX; // shorthand for SQL literals
const SCAN_HISTORY_FIXTURE = 'scan-history-summary';
const EXPOSURE_PREVIOUS_RUN_ID = 910001;
const EXPOSURE_CURRENT_RUN_ID = 910002;
const DASHBOARD_DISCOVERY_PHASE_JOB_ID = -920301;

function sqlValue(value) {
  return value == null ? 'NULL' : `'${String(value).replace(/'/g, "''")}'`;
}

function backupAuthenticationProfileState() {
  const profiles = sshQuery('SELECT id, name, provider, method, settings_json, secret_refs_json, created_at, updated_at FROM authentication_profiles');
  const assignments = sshQuery('SELECT usage_type, usage_id, authentication_profile_id, created_at, updated_at FROM authentication_profile_assignments');
  console.log(`[setup] Backed up ${profiles.length} auth profile(s) and ${assignments.length} assignment(s).`);
  return { profiles, assignments };
}

function restoreAuthenticationProfileState(state) {
  if (!state) {
    throw new Error('Authentication profile backup state is required.');
  }

  const statements = [
    'DELETE FROM authentication_profile_assignments',
    'DELETE FROM authentication_profiles'
  ];

  for (const row of state.profiles) {
    const cols = ['id', 'name', 'provider', 'method', 'settings_json', 'secret_refs_json', 'created_at', 'updated_at'];
    const values = cols.map(col => sqlValue(row[col])).join(', ');
    statements.push(`INSERT INTO authentication_profiles (${cols.join(', ')}) VALUES (${values})`);
  }

  for (const row of state.assignments) {
    const cols = ['usage_type', 'usage_id', 'authentication_profile_id', 'created_at', 'updated_at'];
    const values = cols.map(col => sqlValue(row[col])).join(', ');
    statements.push(`INSERT INTO authentication_profile_assignments (${cols.join(', ')}) VALUES (${values})`);
  }

  sshNonQuery(statements.join('; '));
  console.log(`[teardown] Restored ${state.profiles.length} auth profile(s) and ${state.assignments.length} assignment(s).`);
}

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
    // Exposure-change data
    `DELETE FROM ciem_exposure_changes WHERE id LIKE '%${P}%' OR impacted_identity_id LIKE '${P}%' OR impacted_resource_id LIKE '%${P}%' OR current_discovery_run_id IN (${EXPOSURE_PREVIOUS_RUN_ID}, ${EXPOSURE_CURRENT_RUN_ID})`,
    `DELETE FROM ciem_exposure_snapshot_items WHERE exposure_key LIKE '%${P}%' OR impacted_identity_id LIKE '${P}%' OR impacted_resource_id LIKE '%${P}%' OR discovery_run_id IN (${EXPOSURE_PREVIOUS_RUN_ID}, ${EXPOSURE_CURRENT_RUN_ID})`,
    `DELETE FROM azure_discovery_phase_metrics WHERE evidence LIKE '%${P}%' OR discovery_run_id IN (SELECT id FROM azure_discovery_runs WHERE psu_job_id = ${DASHBOARD_DISCOVERY_PHASE_JOB_ID})`,
    `DELETE FROM azure_discovery_runs WHERE id IN (${EXPOSURE_PREVIOUS_RUN_ID}, ${EXPOSURE_CURRENT_RUN_ID})`,
    `DELETE FROM azure_discovery_runs WHERE psu_job_id = ${DASHBOARD_DISCOVERY_PHASE_JOB_ID}`,
    // Materialized attack paths
    `DELETE FROM attack_paths WHERE id LIKE '${P}%' OR path_json LIKE '%${P}%' OR edges_json LIKE '%${P}%' OR path_chain LIKE '%${P}%'`,
    `DELETE FROM attack_path_rules WHERE id = '${LONG_RUNNING_ATTACK_PATH_RULE_ID}'`,
    // Graph data (edges first — path-style IDs need leading %)
    `DELETE FROM graph_edges WHERE source_id LIKE '%${P}%' OR target_id LIKE '%${P}%'`,
    `DELETE FROM graph_nodes WHERE id LIKE '%${P}%'`,
  ].join('; '));
  console.log('[cleanup] Test data cleaned up.');
}

function seedChecks() {
  const checks = loadFixture(SCAN_HISTORY_FIXTURE).tables.checks;
  const stmts = checks.map(c => {
    return `INSERT OR REPLACE INTO checks (id, disabled) VALUES (${sqlValue(c.id)}, ${sqlValue(c.disabled)})`;
  });
  sshNonQuery(stmts.join('; '));
  console.log(`[seed] Seeded mutable state for ${checks.length} catalog checks.`);
}

function backupAndClearAllChecks() {
  const checks = loadFixture(SCAN_HISTORY_FIXTURE).tables.checks;
  const ids = checks.map(c => sqlValue(c.id)).join(', ');
  const rows = sshQuery(`SELECT id, disabled FROM checks WHERE id IN (${ids})`);
  sshNonQuery(`DELETE FROM checks WHERE id IN (${ids})`);
  console.log(`[setup] Backed up mutable state for ${rows.length} catalog checks.`);
  return rows;
}

function restoreChecks(rows) {
  if (!rows) return;

  if (rows.length > 0) {
    const stmts = rows.map(r => `INSERT OR REPLACE INTO checks (id, disabled) VALUES (${sqlValue(r.id)}, ${sqlValue(r.disabled)})`);
    sshNonQuery(stmts.join('; '));
  }
  console.log(`[teardown] Restored mutable state for ${rows.length} catalog checks.`);
}

function seedTestData() {
  insertFixtureRows(SCAN_HISTORY_FIXTURE);
  const run1Count = getScanResultCount(`${P}scan_run_1`);
  const run2Count = getScanResultCount(`${P}scan_run_2`);
  console.log(`[seed] Seeded scan-history fixture (${run1Count} + ${run2Count} results).`);
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

  const stmts = ['DELETE FROM scan_results', 'DELETE FROM scan_runs'];
  for (const r of scanRuns) {
    const v = [r.id, r.provider_id, r.status, r.started_at, r.completed_at, r.duration_seconds, r.total_results, r.failed_results, r.passed_results]
      .map(sqlValue).join(', ');
    stmts.push(`INSERT OR REPLACE INTO scan_runs (id, provider_id, status, started_at, completed_at, duration_seconds, total_results, failed_results, passed_results) VALUES (${v})`);
  }
  for (const r of scanResults) {
    const v = [r.scan_run_id, r.check_id, r.status, r.status_extended, r.resource_id, r.resource_name]
      .map(sqlValue).join(', ');
    stmts.push(`INSERT OR REPLACE INTO scan_results (scan_run_id, check_id, status, status_extended, resource_id, resource_name) VALUES (${v})`);
  }
  sshNonQuery(stmts.join('; '));
  console.log(`[teardown] Restored ${scanRuns.length} scan runs and ${scanResults.length} scan results.`);
}

function getScanResultCount(scanRunId) {
  return sshQuery(`SELECT COUNT(*) as cnt FROM scan_results WHERE scan_run_id = '${scanRunId}'`)[0].cnt;
}

function getScanHistoryCounts() {
  return sshQuery('SELECT (SELECT COUNT(*) FROM scan_runs) as scanRunCount, (SELECT COUNT(*) FROM scan_results) as scanResultCount')[0];
}

function getTestCheckCounts() {
  return sshQuery('SELECT SUM(CASE WHEN disabled = 0 THEN 1 ELSE 0 END) as enabled, SUM(CASE WHEN disabled = 1 THEN 1 ELSE 0 END) as disabled FROM checks')[0];
}

function seedEnvironmentData() {
  const now = new Date().toISOString();
  const tenant = `${P}tenant-0000-0000-0000-000000000001`;
  const sub1 = `${P}sub-0000-0000-0000-000000000001`;
  const sub2 = `${P}sub-0000-0000-0000-000000000002`;
  sshNonQuery([
    `INSERT OR REPLACE INTO azure_arm_resources (id, type, name, location, resource_group, subscription_id, tenant_id, collected_at) VALUES ('/subscriptions/${sub1}/resourceGroups/e2e-rg-1','microsoft.resources/subscriptions/resourcegroups','e2e-rg-1','eastus','e2e-rg-1','${sub1}','${tenant}','${now}')`,
    `INSERT OR REPLACE INTO azure_arm_resources (id, type, name, location, resource_group, subscription_id, tenant_id, collected_at) VALUES ('${P}rg1-vnet','microsoft.network/virtualnetworks','e2e-vnet-1','eastus','e2e-rg-1','${sub1}','${tenant}','${now}')`,
    `INSERT OR REPLACE INTO azure_arm_resources (id, type, name, location, resource_group, subscription_id, tenant_id, collected_at) VALUES ('${P}rg1-nsg','microsoft.network/networksecuritygroups','e2e-nsg-1','eastus','e2e-rg-1','${sub1}','${tenant}','${now}')`,
    `INSERT OR REPLACE INTO azure_arm_resources (id, type, name, location, resource_group, subscription_id, tenant_id, collected_at) VALUES ('${P}rg1-sa','microsoft.storage/storageaccounts','e2esa1','eastus','e2e-rg-1','${sub1}','${tenant}','${now}')`,
    `INSERT OR REPLACE INTO azure_arm_resources (id, type, name, location, resource_group, subscription_id, tenant_id, collected_at) VALUES ('${P}rg2-kv','microsoft.keyvault/vaults','e2e-kv-1','westus2','e2e-rg-2','${sub2}','${tenant}','${now}')`,
  ].join('; '));
  console.log('[seed] Seeded 5 ARM resources for Environment page tests.');
}

function cleanupEnvironmentData() {
  sshNonQuery(`DELETE FROM azure_arm_resources WHERE id LIKE '%${P}%'`);
  console.log('[cleanup] Environment test data cleaned up.');
}

function getArmResourceCount() {
  return sshQuery('SELECT COUNT(*) as count FROM azure_arm_resources')[0].count;
}

function getTestArmResourceCount() {
  return sshQuery(`SELECT COUNT(*) as count FROM azure_arm_resources WHERE id LIKE '%${P}%'`)[0].count;
}

function backupAndClearAllArmResources() {
  const rows = sshQuery(`SELECT * FROM azure_arm_resources WHERE id NOT LIKE '%${P}%'`);
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

function backupAndClearDashboardIdentityData() {
  const state = {
    graphNodes: sshQuery('SELECT id, kind, display_name, provider, subscription_id, resource_group, properties, collected_at FROM graph_nodes'),
    graphEdges: sshQuery('SELECT id, source_id, target_id, kind, properties, computed, collected_at FROM graph_edges'),
    entraResources: sshQuery('SELECT id, type, display_name, parent_id, properties, collected_at, last_seen_at FROM azure_entra_resources'),
    armResources: sshQuery('SELECT id, type, name, location, resource_group, subscription_id, tenant_id, kind, sku, identity, managed_by, plan, zones, tags, properties, collected_at, last_seen_at FROM azure_arm_resources'),
    effectiveRoleAssignments: sshQuery('SELECT id, principal_id, principal_type, principal_display_name, original_principal_id, original_principal_type, role_definition_id, role_name, scope, permissions_json, computed_at FROM azure_effective_role_assignments')
  };
  sshNonQuery('DELETE FROM graph_edges; DELETE FROM graph_nodes; DELETE FROM azure_effective_role_assignments; DELETE FROM azure_entra_resources; DELETE FROM azure_arm_resources');
  console.log(`[setup] Backed up and cleared dashboard identity data (${state.graphNodes.length} graph nodes, ${state.effectiveRoleAssignments.length} role assignments).`);
  return state;
}

function restoreDashboardIdentityData(state) {
  const stmts = [
    'DELETE FROM graph_edges',
    'DELETE FROM graph_nodes',
    'DELETE FROM azure_effective_role_assignments',
    'DELETE FROM azure_entra_resources',
    'DELETE FROM azure_arm_resources'
  ];

  for (const row of state.armResources) {
    const cols = ['id', 'type', 'name', 'location', 'resource_group', 'subscription_id', 'tenant_id', 'kind', 'sku', 'identity', 'managed_by', 'plan', 'zones', 'tags', 'properties', 'collected_at', 'last_seen_at'];
    const vals = cols.map(c => sqlValue(row[c])).join(', ');
    stmts.push(`INSERT OR REPLACE INTO azure_arm_resources (${cols.join(', ')}) VALUES (${vals})`);
  }

  for (const row of state.entraResources) {
    const cols = ['id', 'type', 'display_name', 'parent_id', 'properties', 'collected_at', 'last_seen_at'];
    const vals = cols.map(c => sqlValue(row[c])).join(', ');
    stmts.push(`INSERT OR REPLACE INTO azure_entra_resources (${cols.join(', ')}) VALUES (${vals})`);
  }

  for (const row of state.graphNodes) {
    const cols = ['id', 'kind', 'display_name', 'provider', 'subscription_id', 'resource_group', 'properties', 'collected_at'];
    const vals = cols.map(c => sqlValue(row[c])).join(', ');
    stmts.push(`INSERT OR REPLACE INTO graph_nodes (${cols.join(', ')}) VALUES (${vals})`);
  }

  for (const row of state.effectiveRoleAssignments) {
    const cols = ['id', 'principal_id', 'principal_type', 'principal_display_name', 'original_principal_id', 'original_principal_type', 'role_definition_id', 'role_name', 'scope', 'permissions_json', 'computed_at'];
    const vals = cols.map(c => sqlValue(row[c])).join(', ');
    stmts.push(`INSERT OR REPLACE INTO azure_effective_role_assignments (${cols.join(', ')}) VALUES (${vals})`);
  }

  for (const row of state.graphEdges) {
    const cols = ['id', 'source_id', 'target_id', 'kind', 'properties', 'computed', 'collected_at'];
    const vals = cols.map(c => sqlValue(row[c])).join(', ');
    stmts.push(`INSERT OR REPLACE INTO graph_edges (${cols.join(', ')}) VALUES (${vals})`);
  }

  sshNonQuery(stmts.join('; '));
  console.log(`[teardown] Restored dashboard identity data (${state.graphNodes.length} graph nodes, ${state.effectiveRoleAssignments.length} role assignments).`);
}

function getDashboardIdentityCounts() {
  return sshQuery(`
    SELECT
      (SELECT COUNT(*) FROM graph_nodes WHERE kind IN ('EntraUser','EntraServicePrincipal','EntraGroup')) as identityCount,
      (SELECT COUNT(*) FROM azure_effective_role_assignments) as entitlementCount
  `)[0];
}

function seedIdentitiesPageData() {
  const now = new Date().toISOString();
  const keyVaultPermissionsJson = JSON.stringify([
    {
      Actions: ['Microsoft.KeyVault/vaults/read'],
      NotActions: [],
      DataActions: [],
      NotDataActions: []
    }
  ]);
  const ownerPermissionsJson = JSON.stringify([
    {
      Actions: ['Microsoft.Authorization/roleAssignments/write'],
      NotActions: [],
      DataActions: [],
      NotDataActions: []
    }
  ]);
  const identityProperties = JSON.stringify({
    accountEnabled: true,
    daysSinceSignIn: 120,
    lastSignIn: '2025-12-01T12:30:00Z',
    lastInteractiveSignIn: '2025-12-01T12:30:00Z',
    lastNonInteractiveSignIn: '2025-12-02T08:15:00Z'
  });
  const keyVaultRoleProperties = JSON.stringify({
    role_definition_id: `${P}roledef-keyvault-reader`,
    role_name: 'Key Vault Reader',
    permissions_json: keyVaultPermissionsJson,
    privileged: false
  });
  const ownerRoleProperties = JSON.stringify({
    role_definition_id: `${P}roledef-owner`,
    role_name: 'Owner',
    permissions_json: ownerPermissionsJson,
    privileged: true,
    scope: `/subscriptions/${P}sub-1`
  });
  const duplicateReaderRoleProperties = JSON.stringify({
    role_definition_id: `${P}roledef-duplicate-reader`,
    role_name: 'Reader',
    permissions_json: null,
    privileged: false,
    scope: `/subscriptions/${P}sub-1`
  });
  const duplicateOwnerRoleProperties = JSON.stringify({
    role_definition_id: `${P}roledef-duplicate-owner`,
    role_name: 'Owner',
    permissions_json: null,
    privileged: true,
    scope: `/subscriptions/${P}sub-1`
  });
  sshNonQuery([
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, properties, collected_at) VALUES ('${P}identity-user-1','EntraUser','E2E Identities User','azure',${sqlValue(identityProperties)},'${now}')`,
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, properties, collected_at) VALUES ('${P}identity-sp-duplicate','EntraServicePrincipal','E2E Duplicate App','azure','{}','${now}')`,
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, properties, collected_at) VALUES ('${P}identity-mi-duplicate','EntraManagedIdentity','E2E Duplicate App','azure','{}','${now}')`,
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, subscription_id, resource_group, properties, collected_at) VALUES ('${P}identity-keyvault-1','AzureKeyVault','E2E Identities Key Vault','azure','${P}sub-1','e2e-rg-1','{"arm_type":"microsoft.keyvault/vaults"}','${now}')`,
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, properties, collected_at) VALUES ('/subscriptions/${P}sub-1','AzureSubscription','E2E Identities Subscription','azure','{}','${now}')`,
    `INSERT OR REPLACE INTO graph_edges (source_id, target_id, kind, properties, computed, collected_at) VALUES ('${P}identity-user-1','${P}identity-keyvault-1','HasRole',${sqlValue(keyVaultRoleProperties)},0,'${now}')`,
    `INSERT OR REPLACE INTO graph_edges (source_id, target_id, kind, properties, computed, collected_at) VALUES ('${P}identity-user-1','/subscriptions/${P}sub-1','HasRole',${sqlValue(ownerRoleProperties)},0,'${now}')`,
    `INSERT OR REPLACE INTO graph_edges (source_id, target_id, kind, properties, computed, collected_at) VALUES ('${P}identity-sp-duplicate','/subscriptions/${P}sub-1','HasRole',${sqlValue(duplicateReaderRoleProperties)},0,'${now}')`,
    `INSERT OR REPLACE INTO graph_edges (source_id, target_id, kind, properties, computed, collected_at) VALUES ('${P}identity-mi-duplicate','/subscriptions/${P}sub-1','HasRole',${sqlValue(duplicateOwnerRoleProperties)},0,'${now}')`,
  ].join('; '));
  console.log('[seed] Seeded Identities page graph data.');
}

function seedIdentitiesPageLayoutData() {
  const now = new Date().toISOString();
  const roleProperties = JSON.stringify({
    role_definition_id: `${P}roledef-layout-reader`,
    role_name: 'Reader',
    permissions_json: null,
    privileged: false,
    scope: `/subscriptions/${P}sub-1`
  });
  const statements = [
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, properties, collected_at) VALUES ('/subscriptions/${P}sub-1','AzureSubscription','E2E Identities Subscription','azure','{}','${now}')`
  ];

  for (let i = 1; i <= 30; i++) {
    const suffix = String(i).padStart(2, '0');
    const identityId = `${P}identity-layout-${suffix}`;
    statements.push(`INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, properties, collected_at) VALUES ('${identityId}','EntraUser','E2E Layout Identity ${suffix}','azure','{}','${now}')`);
    statements.push(`INSERT OR REPLACE INTO graph_edges (source_id, target_id, kind, properties, computed, collected_at) VALUES ('${identityId}','/subscriptions/${P}sub-1','HasRole',${sqlValue(roleProperties)},0,'${now}')`);
  }

  sshNonQuery(statements.join('; '));
  console.log('[seed] Seeded Identities page layout graph data.');
}

function cleanupIdentitiesPageData() {
  sshNonQuery(`DELETE FROM graph_edges WHERE source_id LIKE '${P}identity-%' OR target_id LIKE '${P}identity-%' OR target_id = '/subscriptions/${P}sub-1'; DELETE FROM graph_nodes WHERE id LIKE '${P}identity-%' OR id = '/subscriptions/${P}sub-1'`);
  console.log('[cleanup] Identities page graph data cleaned up.');
}

function getTestIdentitiesGraphEdgeCount() {
  return sshQuery(`SELECT COUNT(*) as count FROM graph_edges WHERE source_id LIKE '${P}identity-%' OR target_id LIKE '${P}identity-%' OR target_id = '/subscriptions/${P}sub-1'`)[0].count;
}

function getTestIdentitiesLayoutIdentityCount() {
  return sshQuery(`SELECT COUNT(*) as count FROM graph_nodes WHERE id LIKE '${P}identity-layout-%'`)[0].count;
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
  const openManagementPathJson = JSON.stringify([
    { id: '__internet__', kind: 'Internet', display_name: 'Internet', properties: null, _type: 'node' },
    { id: `${P}ap-nsg-1`, kind: 'AzureNSG', display_name: 'E2E Attack Path NSG', properties: null, _type: 'node' }
  ]);
  const openManagementEdgesJson = JSON.stringify([
    {
      id: `${P}ap-edge-open-management`,
      source_id: '__internet__',
      target_id: `${P}ap-nsg-1`,
      kind: 'AllowsInbound',
      properties: '{"open_ports":[{"port":3389,"protocol":"TCP","rule_name":"AllowRDP"}]}',
      _type: 'edge'
    }
  ]);
  const disabledAccountPathJson = JSON.stringify([
    { id: `${P}ap-disabled-user`, kind: 'EntraUser', display_name: 'E2E Disabled User', properties: '{"accountEnabled":false}', _type: 'node' },
    { id: `/subscriptions/${P}ap-sub-1`, kind: 'AzureSubscription', display_name: 'E2E Subscription', properties: null, _type: 'node' }
  ]);
  const disabledAccountEdgesJson = JSON.stringify([
    {
      id: `${P}ap-edge-disabled-role`,
      source_id: `${P}ap-disabled-user`,
      target_id: `/subscriptions/${P}ap-sub-1`,
      kind: 'HasRole',
      properties: `{"role_name":"Contributor","role_definition_id":"/subscriptions/${P}ap-sub-1/providers/Microsoft.Authorization/roleDefinitions/contributor-role","role_assignment_id":"/subscriptions/${P}ap-sub-1/providers/Microsoft.Authorization/roleAssignments/e2e-disabled-role","privileged":false}`,
      _type: 'edge'
    }
  ]);
  const longRunningPathJson = JSON.stringify([
    { id: `${P}ap-long-running-user`, kind: 'EntraUser', display_name: 'E2E Long Running User', properties: '{"accountEnabled":false}', _type: 'node' },
    { id: `/subscriptions/${P}ap-long-running-sub`, kind: 'AzureSubscription', display_name: 'E2E Long Running Subscription', properties: null, _type: 'node' }
  ]);
  const longRunningEdgesJson = JSON.stringify([
    {
      id: `${P}ap-edge-long-running-role`,
      source_id: `${P}ap-long-running-user`,
      target_id: `/subscriptions/${P}ap-long-running-sub`,
      kind: 'HasRole',
      properties: `{"role_name":"Reader","role_definition_id":"/subscriptions/${P}ap-long-running-sub/providers/Microsoft.Authorization/roleDefinitions/reader-role","role_assignment_id":"/subscriptions/${P}ap-long-running-sub/providers/Microsoft.Authorization/roleAssignments/e2e-long-running-role","privileged":false}`,
      _type: 'edge'
    }
  ]);
  const longRunningStepsJson = JSON.stringify([
    { kind: 'EntraUser' },
    { edge: 'HasRole', direction: 'outbound' },
    { kind: 'AzureSubscription' }
  ]);
  sshNonQuery([
    `DELETE FROM attack_path_rules WHERE id = '${LONG_RUNNING_ATTACK_PATH_RULE_ID}'`,
    `DELETE FROM attack_paths WHERE id LIKE '${P}ap-%' OR path_json LIKE '%${P}ap-%' OR edges_json LIKE '%${P}ap-%' OR path_chain LIKE '%${P}ap-%'`,
    // Pattern 1: open-management-port
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, properties, collected_at) VALUES ('__internet__','Internet','Internet','global',null,'${now}')`,
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, properties, collected_at) VALUES ('${P}ap-nsg-1','AzureNSG','E2E Attack Path NSG','azure',null,'${now}')`,
    `INSERT OR REPLACE INTO graph_edges (source_id, target_id, kind, properties, computed, collected_at) VALUES ('__internet__','${P}ap-nsg-1','AllowsInbound','{"open_ports":[{"port":3389,"protocol":"TCP","rule_name":"AllowRDP"}]}',1,'${now}')`,
    // Pattern 2: disabled-account-with-roles
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, properties, collected_at) VALUES ('${P}ap-disabled-user','EntraUser','E2E Disabled User','azure','{"accountEnabled":false}','${now}')`,
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, properties, collected_at) VALUES ('/subscriptions/${P}ap-sub-1','AzureSubscription','E2E Subscription','azure',null,'${now}')`,
    `INSERT OR REPLACE INTO graph_edges (source_id, target_id, kind, properties, computed, collected_at) VALUES ('${P}ap-disabled-user','/subscriptions/${P}ap-sub-1','HasRole','{"role_name":"Contributor","role_definition_id":"/subscriptions/${P}ap-sub-1/providers/Microsoft.Authorization/roleDefinitions/contributor-role","role_assignment_id":"/subscriptions/${P}ap-sub-1/providers/Microsoft.Authorization/roleAssignments/e2e-disabled-role","privileged":false}',0,'${now}')`,
    // Pattern 3: long-running remediation fixture
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, properties, collected_at) VALUES ('${P}ap-long-running-user','EntraUser','E2E Long Running User','azure','{"accountEnabled":false}','${now}')`,
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, properties, collected_at) VALUES ('/subscriptions/${P}ap-long-running-sub','AzureSubscription','E2E Long Running Subscription','azure',null,'${now}')`,
    `INSERT OR REPLACE INTO graph_edges (source_id, target_id, kind, properties, computed, collected_at) VALUES ('${P}ap-long-running-user','/subscriptions/${P}ap-long-running-sub','HasRole','{"role_name":"Reader","role_definition_id":"/subscriptions/${P}ap-long-running-sub/providers/Microsoft.Authorization/roleDefinitions/reader-role","role_assignment_id":"/subscriptions/${P}ap-long-running-sub/providers/Microsoft.Authorization/roleAssignments/e2e-long-running-role","privileged":false}',0,'${now}')`,
    `INSERT INTO attack_path_rules (id, name, severity, category, description, remediation, remediation_script_path, psu_script_name, steps_json, disabled, updated_at) VALUES ('${LONG_RUNNING_ATTACK_PATH_RULE_ID}','ZZZ Long running remediation fixture','low','identity-hygiene','E2E fixture used to verify the remediation close-warning dialog while a script is still running.','1. Keep the test remediation running long enough to exercise the close-warning branch.\n2. Terminate the PSU job from the warning dialog.','${LONG_RUNNING_ATTACK_PATH_REMEDIATION_SCRIPT_PATH}','${LONG_RUNNING_ATTACK_PATH_SCRIPT_NAME}',${sqlValue(longRunningStepsJson)},0,'${now}')`,
    `INSERT OR REPLACE INTO attack_paths (id, rule_id, pattern_name, severity, category, remediation, psu_script_name, path_json, edges_json, path_chain, evaluated_at) VALUES ('${P}ap-open-management-port','open-management-port','Management port open to the internet','high','network-exposure','1. Restrict or remove the inbound management rule that allows internet access to SSH, RDP, or WinRM.\n2. Replace public management access with Azure Bastion, VPN, private endpoint access, or Just-in-Time VM access.\n3. If a management rule must remain, limit the source to approved administrative IP ranges and document the exception owner.\n4. Confirm attached resources no longer have public management exposure.\n5. rerun Azure discovery and confirm this attack path no longer appears.','management-port-open-to-the-internet',${sqlValue(openManagementPathJson)},${sqlValue(openManagementEdgesJson)},'Internet (Internet) -> E2E Attack Path NSG (AzureNSG)','${now}')`,
    `INSERT OR REPLACE INTO attack_paths (id, rule_id, pattern_name, severity, category, remediation, psu_script_name, path_json, edges_json, path_chain, evaluated_at) VALUES ('${P}ap-disabled-account','disabled-account-with-roles','Disabled account still holding active role assignments','high','identity-hygiene','1. Open the disabled identity in Microsoft Entra ID and confirm it should remain disabled.\n2. In Azure RBAC, find every active role assignment for this identity at the listed scope.\n3. Remove active role assignments from the disabled identity.\n4. If access is still required, assign it to an active owner-approved identity instead of re-enabling the disabled account.\n5. rerun Azure discovery and confirm this attack path no longer appears.','disabled-account-still-holding-active-role-assignments',${sqlValue(disabledAccountPathJson)},${sqlValue(disabledAccountEdgesJson)},'E2E Disabled User (EntraUser) -> E2E Subscription (AzureSubscription)','${now}')`,
    `INSERT OR REPLACE INTO attack_paths (id, rule_id, pattern_name, severity, category, remediation, psu_script_name, path_json, edges_json, path_chain, evaluated_at) VALUES ('${P}ap-long-running-remediation','${LONG_RUNNING_ATTACK_PATH_RULE_ID}','ZZZ Long running remediation fixture','low','identity-hygiene','1. Keep the test remediation running long enough to exercise the close-warning branch.\n2. Terminate the PSU job from the warning dialog.','${LONG_RUNNING_ATTACK_PATH_SCRIPT_NAME}',${sqlValue(longRunningPathJson)},${sqlValue(longRunningEdgesJson)},'E2E Long Running User (EntraUser) -> E2E Long Running Subscription (AzureSubscription)','${now}')`,
  ].join('; '));
  console.log('[seed] Seeded graph and materialized attack path data for Attack Paths page tests (3 patterns).');
}

function seedAttackPathsRefreshGraphData() {
  const now = new Date().toISOString();
  sshNonQuery([
    `DELETE FROM attack_paths WHERE id LIKE '${P}ap-%' OR path_json LIKE '%${P}ap-%' OR edges_json LIKE '%${P}ap-%' OR path_chain LIKE '%${P}ap-%'`,
    `DELETE FROM graph_edges WHERE source_id LIKE '${P}ap-%' OR target_id LIKE '${P}ap-%' OR target_id = '/subscriptions/${P}ap-sub-1'`,
    `DELETE FROM graph_nodes WHERE id LIKE '${P}ap-%' OR id = '/subscriptions/${P}ap-sub-1'`,
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, properties, collected_at) VALUES ('__internet__','Internet','Internet','global',null,'${now}')`,
    `INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, properties, collected_at) VALUES ('${P}ap-nsg-1','AzureNSG','E2E Attack Path NSG','azure',null,'${now}')`,
    `INSERT OR REPLACE INTO graph_edges (source_id, target_id, kind, properties, computed, collected_at) VALUES ('__internet__','${P}ap-nsg-1','AllowsInbound','{"open_ports":[{"port":3389,"protocol":"TCP","rule_name":"AllowRDP"}]}',1,'${now}')`
  ].join('; '));
  console.log('[seed] Seeded graph-only attack path data for Attack Paths refresh tests.');
}

function backupAndClearAttackPathGraphData() {
  const state = {
    graphNodes: sshQuery('SELECT id, kind, display_name, provider, subscription_id, resource_group, properties, collected_at FROM graph_nodes'),
    graphEdges: sshQuery('SELECT id, source_id, target_id, kind, properties, computed, collected_at FROM graph_edges'),
    attackPaths: sshQuery('SELECT id, rule_id, pattern_name, severity, category, remediation, psu_script_name, path_json, edges_json, path_chain, evaluated_at FROM attack_paths')
  };
  sshNonQuery('DELETE FROM attack_paths; DELETE FROM graph_edges; DELETE FROM graph_nodes');
  console.log(`[setup] Backed up and cleared graph data (${state.graphNodes.length} nodes, ${state.graphEdges.length} edges, ${state.attackPaths.length} attack paths).`);
  return state;
}

function restoreAttackPathGraphData(state) {
  const stmts = [
    'DELETE FROM attack_paths',
    'DELETE FROM graph_edges',
    'DELETE FROM graph_nodes'
  ];

  for (const row of state.graphNodes) {
    const cols = ['id', 'kind', 'display_name', 'provider', 'subscription_id', 'resource_group', 'properties', 'collected_at'];
    const vals = cols.map(c => sqlValue(row[c])).join(', ');
    stmts.push(`INSERT OR REPLACE INTO graph_nodes (${cols.join(', ')}) VALUES (${vals})`);
  }

  for (const row of state.graphEdges) {
    const cols = ['id', 'source_id', 'target_id', 'kind', 'properties', 'computed', 'collected_at'];
    const vals = cols.map(c => sqlValue(row[c])).join(', ');
    stmts.push(`INSERT OR REPLACE INTO graph_edges (${cols.join(', ')}) VALUES (${vals})`);
  }

  for (const row of state.attackPaths) {
    const cols = ['id', 'rule_id', 'pattern_name', 'severity', 'category', 'remediation', 'psu_script_name', 'path_json', 'edges_json', 'path_chain', 'evaluated_at'];
    const vals = cols.map(c => sqlValue(row[c])).join(', ');
    stmts.push(`INSERT OR REPLACE INTO attack_paths (${cols.join(', ')}) VALUES (${vals})`);
  }

  sshNonQuery(stmts.join('; '));
  console.log(`[teardown] Restored graph data (${state.graphNodes.length} nodes, ${state.graphEdges.length} edges, ${state.attackPaths.length} attack paths).`);
}

function cleanupAttackPathsPageData() {
  sshNonQuery(`DELETE FROM attack_paths WHERE id LIKE '${P}ap-%' OR path_json LIKE '%${P}ap-%' OR edges_json LIKE '%${P}ap-%' OR path_chain LIKE '%${P}ap-%'; DELETE FROM attack_path_rules WHERE id = '${LONG_RUNNING_ATTACK_PATH_RULE_ID}'; DELETE FROM graph_edges WHERE source_id LIKE '${P}ap-%' OR target_id LIKE '${P}ap-%' OR target_id IN ('/subscriptions/${P}ap-sub-1','/subscriptions/${P}ap-long-running-sub'); DELETE FROM graph_nodes WHERE id LIKE '${P}ap-%' OR id IN ('/subscriptions/${P}ap-sub-1','/subscriptions/${P}ap-long-running-sub')`);
  console.log('[cleanup] Attack Paths page graph data cleaned up.');
}

function getTestAttackPathNodeCount() {
  return sshQuery(`SELECT COUNT(*) as count FROM graph_nodes WHERE id LIKE '${P}ap-%' OR id = '/subscriptions/${P}ap-sub-1'`)[0].count;
}

function getTestAttackPathCount() {
  return sshQuery(`SELECT COUNT(*) as count FROM attack_paths WHERE id LIKE '${P}ap-%' OR path_json LIKE '%${P}ap-%' OR edges_json LIKE '%${P}ap-%' OR path_chain LIKE '%${P}ap-%'`)[0].count;
}

function getCompletedDiscoveryRunCount() {
  return sshQuery("SELECT COUNT(*) as count FROM azure_discovery_runs WHERE status = 'Completed'")[0].count;
}

function backupAndClearAllDiscoveryRuns() {
  const rows = sshQuery('SELECT * FROM azure_discovery_runs');
  rows.phaseMetrics = sshQuery('SELECT * FROM azure_discovery_phase_metrics');
  sshNonQuery('DELETE FROM azure_discovery_phase_metrics; DELETE FROM azure_discovery_runs');
  console.log(`[setup] Backed up ${rows.length} discovery runs and ${rows.phaseMetrics.length} phase metrics, cleared tables.`);
  return rows;
}

function restoreDiscoveryRuns(rows) {
  if (!rows) return;

  const cols = ['id', 'psu_job_id', 'scope', 'status', 'started_at', 'completed_at', 'arm_type_count', 'arm_row_count', 'entra_type_count', 'entra_row_count', 'warning_count', 'error_message'];
  const metricCols = ['id', 'discovery_run_id', 'phase_name', 'succeeded', 'elapsed_seconds', 'evidence', 'recorded_at'];
  const stmts = ['DELETE FROM azure_discovery_phase_metrics', 'DELETE FROM azure_discovery_runs'];
  for (const r of rows) {
    const vals = cols.map(c => sqlValue(r[c])).join(', ');
    stmts.push(`INSERT OR REPLACE INTO azure_discovery_runs (${cols.join(', ')}) VALUES (${vals})`);
  }
  for (const r of rows.phaseMetrics) {
    const vals = metricCols.map(c => sqlValue(r[c])).join(', ');
    stmts.push(`INSERT OR REPLACE INTO azure_discovery_phase_metrics (${metricCols.join(', ')}) VALUES (${vals})`);
  }
  sshNonQuery(stmts.join('; '));
  console.log(`[teardown] Restored ${rows.length} discovery runs and ${rows.phaseMetrics.length} phase metrics.`);
}

function cleanupDashboardDiscoveryPhaseMetrics() {
  sshNonQuery(`DELETE FROM azure_discovery_phase_metrics WHERE discovery_run_id IN (SELECT id FROM azure_discovery_runs WHERE psu_job_id = ${DASHBOARD_DISCOVERY_PHASE_JOB_ID}); DELETE FROM azure_discovery_runs WHERE psu_job_id = ${DASHBOARD_DISCOVERY_PHASE_JOB_ID}`);
  console.log('[cleanup] Dashboard discovery phase timing data cleaned up.');
}

function seedDashboardDiscoveryPhaseMetrics() {
  cleanupDashboardDiscoveryPhaseMetrics();
  const startedAt = '2026-05-07T04:00:00.000Z';
  const completedAt = '2026-05-07T04:00:16.000Z';
  sshNonQuery(`INSERT INTO azure_discovery_runs (psu_job_id, scope, status, started_at, completed_at, arm_type_count, arm_row_count, entra_type_count, entra_row_count, warning_count, error_message) VALUES (${DASHBOARD_DISCOVERY_PHASE_JOB_ID}, 'All', 'Completed', '${startedAt}', '${completedAt}', 2, 10, 2, 8, 0, NULL)`);
  const rows = sshQuery(`SELECT id FROM azure_discovery_runs WHERE psu_job_id = ${DASHBOARD_DISCOVERY_PHASE_JOB_ID} ORDER BY id DESC LIMIT 1`);
  if (rows.length !== 1) {
    throw new Error('Seed verification failed: dashboard discovery run was not inserted');
  }

  const runId = rows[0].id;
  const stmts = [
    `INSERT INTO azure_discovery_phase_metrics (discovery_run_id, phase_name, succeeded, elapsed_seconds, evidence, recorded_at) VALUES (${runId}, 'ARM collection', 1, 10.12, '${P}10 ARM rows', '${completedAt}')`,
    `INSERT INTO azure_discovery_phase_metrics (discovery_run_id, phase_name, succeeded, elapsed_seconds, evidence, recorded_at) VALUES (${runId}, 'Graph build', 1, 5.33, '${P}3 nodes, 2 edges', '${completedAt}')`
  ];
  sshNonQuery(stmts.join('; '));

  const count = getDashboardDiscoveryPhaseMetricCount(runId);
  if (count !== 2) {
    throw new Error(`Seed verification failed: dashboard discovery phase metrics count is ${count}, expected 2`);
  }
  console.log(`[seed] Seeded dashboard discovery phase timing for run id=${runId}`);
  return runId;
}

function getDashboardDiscoveryPhaseMetricCount(runId) {
  return sshQuery(`SELECT COUNT(*) as count FROM azure_discovery_phase_metrics WHERE discovery_run_id = ${runId}`)[0].count;
}

function seedCompletedDiscoveryRun() {
  const now = new Date().toISOString();
  sshNonQuery(`INSERT INTO azure_discovery_runs (psu_job_id, scope, status, started_at, completed_at, arm_type_count, arm_row_count, entra_type_count, entra_row_count, warning_count, error_message) VALUES (-1, 'All', 'Completed', '${now}', '${now}', 1, 1, 1, 1, 0, NULL)`);
  const rows = sshQuery("SELECT id FROM azure_discovery_runs WHERE psu_job_id = -1 AND status = 'Completed' ORDER BY id DESC LIMIT 1");
  if (rows.length !== 1) {
    throw new Error('Seed verification failed: completed discovery run was not inserted');
  }
  const id = rows[0].id;
  console.log(`[seed] Seeded completed discovery run id=${id}`);
  return id;
}

function seedCompletedDiscoveryRunAt(completedAt) {
  sshNonQuery(`INSERT INTO azure_discovery_runs (psu_job_id, scope, status, started_at, completed_at, arm_type_count, arm_row_count, entra_type_count, entra_row_count, warning_count, error_message) VALUES (-2, 'All', 'Completed', '${completedAt}', '${completedAt}', 1, 1, 1, 1, 0, NULL)`);
  const rows = sshQuery(`SELECT id, completed_at FROM azure_discovery_runs WHERE psu_job_id = -2 AND status = 'Completed' AND completed_at = '${completedAt}' ORDER BY id DESC LIMIT 1`);
  if (rows.length !== 1) {
    throw new Error('Seed verification failed: fixed completed discovery run was not inserted');
  }
  const id = rows[0].id;
  console.log(`[seed] Seeded fixed completed discovery run id=${id}, completed_at=${completedAt}`);
  return id;
}

function seedRunningDiscoveryRun() {
  const now = new Date().toISOString();
  sshNonQuery(`INSERT INTO azure_discovery_runs (scope, status, started_at) VALUES ('All', 'Running', '${now}')`);
  const rows = sshQuery("SELECT id FROM azure_discovery_runs WHERE status = 'Running' ORDER BY id DESC LIMIT 1");
  const id = rows[0].id;
  console.log(`[seed] Seeded running discovery run id=${id}`);
  return id;
}

function cleanupDiscoveryRun(id) {
  sshNonQuery(`DELETE FROM azure_discovery_runs WHERE id = ${id}`);
  console.log(`[cleanup] Removed discovery run id=${id}`);
}

function getRunningDiscoveryRunCount() {
  return sshQuery("SELECT COUNT(*) as count FROM azure_discovery_runs WHERE status = 'Running'")[0].count;
}

function seedExposureChangeData() {
  const previousAt = '2026-05-06T01:00:00.000Z';
  const currentAt = '2026-05-07T01:00:00.000Z';
  const rows = [
    {
      id: `${EXPOSURE_CURRENT_RUN_ID}:NewRisk:identity:${P}exposure-new-user`,
      change_type: 'NewRisk',
      exposure_type: 'IdentityRisk',
      severity: 'High',
      severity_rank: 2,
      previous_severity: null,
      current_severity: 'High',
      identity_id: `${P}exposure-new-user`,
      identity_name: 'E2E New Exposure User',
      identity_type: 'User',
      resource_id: `/subscriptions/${P}exposure-sub`,
      resource_name: `/subscriptions/${P}exposure-sub`,
      previous_state_json: null,
      current_state_json: JSON.stringify({ RiskLevel: 'High', EntitlementCount: 3 }),
      evidence: 'New High IdentityRisk exposure: E2E New Exposure User'
    },
    {
      id: `${EXPOSURE_CURRENT_RUN_ID}:RiskIncrease:identity:${P}exposure-increase-user`,
      change_type: 'RiskIncrease',
      exposure_type: 'IdentityRisk',
      severity: 'Critical',
      severity_rank: 1,
      previous_severity: 'Medium',
      current_severity: 'Critical',
      identity_id: `${P}exposure-increase-user`,
      identity_name: 'E2E Increased Exposure User',
      identity_type: 'User',
      resource_id: `/subscriptions/${P}exposure-prod`,
      resource_name: `/subscriptions/${P}exposure-prod`,
      previous_state_json: JSON.stringify({ RiskLevel: 'Medium', EntitlementCount: 1 }),
      current_state_json: JSON.stringify({ RiskLevel: 'Critical', EntitlementCount: 4 }),
      evidence: 'IdentityRisk exposure increased from Medium to Critical: E2E Increased Exposure User'
    }
  ];

  const stmts = [
    `DELETE FROM ciem_exposure_changes WHERE current_discovery_run_id IN (${EXPOSURE_PREVIOUS_RUN_ID}, ${EXPOSURE_CURRENT_RUN_ID})`,
    `DELETE FROM ciem_exposure_snapshot_items WHERE discovery_run_id IN (${EXPOSURE_PREVIOUS_RUN_ID}, ${EXPOSURE_CURRENT_RUN_ID})`,
    `DELETE FROM azure_discovery_runs WHERE id IN (${EXPOSURE_PREVIOUS_RUN_ID}, ${EXPOSURE_CURRENT_RUN_ID})`,
    `INSERT INTO azure_discovery_runs (id, psu_job_id, scope, status, started_at, completed_at, arm_type_count, arm_row_count, entra_type_count, entra_row_count, warning_count, error_message) VALUES (${EXPOSURE_PREVIOUS_RUN_ID}, -910001, 'All', 'Completed', '${previousAt}', '${previousAt}', 1, 1, 1, 1, 0, NULL)`,
    `INSERT INTO azure_discovery_runs (id, psu_job_id, scope, status, started_at, completed_at, arm_type_count, arm_row_count, entra_type_count, entra_row_count, warning_count, error_message) VALUES (${EXPOSURE_CURRENT_RUN_ID}, -910002, 'All', 'Completed', '${currentAt}', '${currentAt}', 1, 1, 1, 1, 0, NULL)`
  ];

  for (const row of rows) {
    const cols = [
      'id', 'previous_discovery_run_id', 'current_discovery_run_id', 'exposure_key',
      'change_type', 'exposure_type', 'severity', 'severity_rank', 'previous_severity',
      'current_severity', 'impacted_identity_id', 'impacted_identity_name',
      'impacted_identity_type', 'impacted_resource_id', 'impacted_resource_name',
      'first_seen_at', 'previous_state_json', 'current_state_json', 'evidence', 'created_at'
    ];
    const values = [
      row.id, EXPOSURE_PREVIOUS_RUN_ID, EXPOSURE_CURRENT_RUN_ID, row.id.split(':').slice(2).join(':'),
      row.change_type, row.exposure_type, row.severity, row.severity_rank, row.previous_severity,
      row.current_severity, row.identity_id, row.identity_name,
      row.identity_type, row.resource_id, row.resource_name,
      currentAt, row.previous_state_json, row.current_state_json, row.evidence, currentAt
    ].map(sqlValue).join(', ');
    stmts.push(`INSERT INTO ciem_exposure_changes (${cols.join(', ')}) VALUES (${values})`);
  }

  sshNonQuery(stmts.join('; '));
  console.log(`[seed] Seeded ${rows.length} exposure change records.`);
}

function cleanupExposureChangeData() {
  sshNonQuery(`DELETE FROM ciem_exposure_changes WHERE current_discovery_run_id IN (${EXPOSURE_PREVIOUS_RUN_ID}, ${EXPOSURE_CURRENT_RUN_ID}); DELETE FROM ciem_exposure_snapshot_items WHERE discovery_run_id IN (${EXPOSURE_PREVIOUS_RUN_ID}, ${EXPOSURE_CURRENT_RUN_ID}); DELETE FROM azure_discovery_runs WHERE id IN (${EXPOSURE_PREVIOUS_RUN_ID}, ${EXPOSURE_CURRENT_RUN_ID})`);
  console.log('[cleanup] Exposure change test data cleaned up.');
}

function getTestExposureChangeCount() {
  return sshQuery(`SELECT COUNT(*) as count FROM ciem_exposure_changes WHERE current_discovery_run_id = ${EXPOSURE_CURRENT_RUN_ID}`)[0].count;
}

module.exports = {
  cleanupTestData, seedChecks, backupAndClearAllChecks, restoreChecks, seedTestData,
  backupAuthenticationProfileState, restoreAuthenticationProfileState,
  backupAndClearAllScanHistory, restoreScanHistory, getScanResultCount, getScanHistoryCounts, getTestCheckCounts,
  seedEnvironmentData, cleanupEnvironmentData,
  getArmResourceCount, getTestArmResourceCount,
  backupAndClearAllArmResources, restoreArmResources,
  clearStaleDiscoveryRuns, getCompletedDiscoveryRunCount,
  backupAndClearAllDiscoveryRuns, restoreDiscoveryRuns, seedCompletedDiscoveryRun,
  seedCompletedDiscoveryRunAt,
  seedDashboardDiscoveryPhaseMetrics, cleanupDashboardDiscoveryPhaseMetrics, getDashboardDiscoveryPhaseMetricCount,
  seedRunningDiscoveryRun, cleanupDiscoveryRun, getRunningDiscoveryRunCount,
  seedExposureChangeData, cleanupExposureChangeData, getTestExposureChangeCount,
  seedIdentityViewData, cleanupIdentityViewData, getTestEffectiveRoleAssignmentCount,
  backupAndClearDashboardIdentityData, restoreDashboardIdentityData, getDashboardIdentityCounts,
  seedIdentitiesPageData, seedIdentitiesPageLayoutData, cleanupIdentitiesPageData,
  getTestIdentitiesGraphEdgeCount, getTestIdentitiesLayoutIdentityCount,
  seedIdentityAttackPathData, cleanupIdentityAttackPathData,
  seedAttackPathsPageData, seedAttackPathsRefreshGraphData,
  backupAndClearAttackPathGraphData, restoreAttackPathGraphData,
  cleanupAttackPathsPageData,
  getTestAttackPathNodeCount, getTestAttackPathCount,
  TEST_PREFIX
};
