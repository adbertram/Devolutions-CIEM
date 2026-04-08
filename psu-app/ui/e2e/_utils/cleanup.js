const Database = require('better-sqlite3');
const { testConfig } = require('./test-config');

const TEST_PREFIX = '_E2E_TEST_';

function cleanupTestData() {
  let db;
  try {
    db = new Database(testConfig.database.path, { readonly: false });
    db.pragma('foreign_keys = ON');

    db.prepare(`DELETE FROM scan_results WHERE scan_run_id LIKE '${TEST_PREFIX}%'`).run();
    db.prepare(`DELETE FROM scan_runs WHERE id LIKE '${TEST_PREFIX}%'`).run();
    db.prepare(`DELETE FROM checks WHERE id LIKE '${TEST_PREFIX}%'`).run();
    db.prepare(`DELETE FROM azure_arm_resources WHERE id LIKE '${TEST_PREFIX}%'`).run();

    console.log('[cleanup] Test data cleaned up.');
  } finally {
    if (db) db.close();
  }
}

/**
 * Ensures checks exist in the database for E2E tests.
 * Checks are normally populated by running a scan, but E2E tests need them pre-seeded.
 * Inserts test checks with varied severities and enabled/disabled states.
 */
function seedChecks() {
  let db;
  try {
    db = new Database(testConfig.database.path, { readonly: false });
    db.pragma('foreign_keys = ON');

    const existing = db.prepare('SELECT COUNT(*) as cnt FROM checks').get();
    if (existing.cnt > 0) return;

    console.log('[seed] No checks in DB — seeding test checks...');

    const insert = db.prepare(`
      INSERT OR IGNORE INTO checks (id, provider, service, title, description, risk, severity, remediation_text, check_script, disabled)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    const checks = [
      [`${TEST_PREFIX}check_security_defaults`,     'Azure', 'Entra',    'Ensure Security Defaults is enabled',                'Security defaults provide secure default settings for MFA and blocking legacy authentication.', 'Without security defaults, users may not be required to use MFA, leaving accounts vulnerable.', 'CRITICAL', 'Enable Security Defaults in Azure AD Properties.', 'azure_entra_security_defaults.ps1', 0],
      [`${TEST_PREFIX}check_mfa_enforcement`,        'Azure', 'Entra',    'Ensure Multifactor Authentication is enforced for all users', 'Multi-factor authentication adds a second layer of identity verification.',                       'Accounts without MFA are significantly more susceptible to compromise.',                        'CRITICAL', 'Enable MFA for all users via Conditional Access policies.', 'azure_entra_mfa_enforcement.ps1', 0],
      [`${TEST_PREFIX}check_keyvault_access`,        'Azure', 'KeyVault', 'Ensure Key Vault access is properly configured',     'Key Vault should use RBAC or access policies to control access.',                                 'Misconfigured Key Vault access may expose secrets and certificates.',                           'HIGH',     'Configure RBAC-based access for Key Vault.', 'azure_keyvault_access.ps1', 0],
      [`${TEST_PREFIX}check_storage_encryption`,     'Azure', 'Storage',  'Ensure storage account encryption is enabled',       'Azure Storage encrypts data at rest by default.',                                                 'Unencrypted storage accounts expose data to unauthorized access.',                              'MEDIUM',   'Enable encryption on all storage accounts.', 'azure_storage_encryption.ps1', 0],
      [`${TEST_PREFIX}check_nsg_rules`,              'Azure', 'Network',  'Ensure NSG rules are properly configured',           'Network Security Groups control inbound and outbound traffic.',                                   'Overly permissive NSG rules may allow unauthorized network access.',                            'MEDIUM',   'Review and tighten NSG rules.', 'azure_network_nsg_rules.ps1', 0],
      [`${TEST_PREFIX}check_resource_locks`,         'Azure', 'ARM',      'Ensure resource locks are applied to critical resources', 'Resource locks prevent accidental deletion or modification.',                                 'Critical resources without locks may be accidentally deleted.',                                 'LOW',      'Apply CanNotDelete locks to production resources.', 'azure_arm_resource_locks.ps1', 0],
      [`${TEST_PREFIX}check_tags_compliance`,        'Azure', 'ARM',      'Ensure resources have required tags',                'Tags help organize and manage Azure resources.',                                                  'Missing tags make cost allocation and resource management difficult.',                          'INFO',     'Apply organization-standard tags to all resources.', 'azure_arm_tags_compliance.ps1', 0],
      [`${TEST_PREFIX}check_disabled_legacy_auth`,   'Azure', 'Entra',    'Ensure legacy authentication is disabled',           'Legacy authentication protocols do not support MFA.',                                              'Legacy auth bypass allows attackers to skip MFA requirements.',                                 'HIGH',     'Block legacy authentication via Conditional Access.', 'azure_entra_legacy_auth.ps1', 1],
      [`${TEST_PREFIX}check_disabled_guest_access`,  'Azure', 'Entra',    'Ensure guest user access is restricted',             'Guest users should have limited access to directory resources.',                                   'Unrestricted guest access may expose sensitive directory information.',                          'MEDIUM',   'Restrict guest user permissions in External Collaboration settings.', 'azure_entra_guest_access.ps1', 1],
      [`${TEST_PREFIX}check_disabled_public_access`,  'Azure', 'Storage',  'Ensure public blob access is disabled',             'Public access to blob containers should be disabled.',                                            'Public blob access may expose sensitive data to the internet.',                                 'HIGH',     'Disable public access on all storage accounts.', 'azure_storage_public_access.ps1', 1],
    ];

    const insertMany = db.transaction((items) => {
      for (const row of items) { insert.run(...row); }
    });
    insertMany(checks);
    db.pragma('wal_checkpoint(TRUNCATE)');

    console.log(`[seed] Seeded ${checks.length} test checks (${checks.filter(c => c[9] === 0).length} enabled, ${checks.filter(c => c[9] === 1).length} disabled).`);
  } finally {
    if (db) db.close();
  }
}

function seedTestData() {
  let db;
  try {
    db = new Database(testConfig.database.path, { readonly: false });
    db.pragma('foreign_keys = ON');

    // Get the first provider ID for the FK
    const provider = db.prepare('SELECT id FROM providers LIMIT 1').get();
    if (!provider) {
      console.log('[seed] No providers in DB — skipping seed.');
      return;
    }

    // Get real check IDs with severity for FK compliance
    const checks = db.prepare('SELECT id, severity FROM checks LIMIT 10').all();
    if (checks.length === 0) {
      console.log('[seed] No checks in DB — skipping seed.');
      return;
    }

    const now = new Date().toISOString();

    // --- Scan Run 1 (most recent): 5 results, includes CRITICAL/HIGH failures ---
    const scanRunId1 = `${TEST_PREFIX}scan_run_1`;
    const failCount1 = 2;
    const passCount1 = Math.min(checks.length, 5) - failCount1;

    db.prepare(`
      INSERT OR REPLACE INTO scan_runs (id, provider_id, status, started_at, completed_at, duration_seconds, total_results, failed_results, passed_results)
      VALUES (?, ?, 'Completed', ?, ?, 42.5, ?, ?, ?)
    `).run(scanRunId1, provider.id, now, now, failCount1 + passCount1, failCount1, passCount1);

    const insertResult = db.prepare(`
      INSERT OR REPLACE INTO scan_results (scan_run_id, check_id, status, status_extended, resource_id, resource_name)
      VALUES (?, ?, ?, ?, ?, ?)
    `);

    // Pick checks: prefer CRITICAL/HIGH severity for the FAIL results
    const critHighChecks = checks.filter(c => ['CRITICAL', 'HIGH'].includes((c.severity || '').toUpperCase()));
    const otherChecks = checks.filter(c => !['CRITICAL', 'HIGH'].includes((c.severity || '').toUpperCase()));
    const orderedChecks = [...critHighChecks, ...otherChecks].slice(0, 5);

    const statuses1 = ['FAIL', 'FAIL', 'PASS', 'PASS', 'PASS'];
    const statusDescs1 = [
      'Security defaults are not enabled for this tenant',
      'MFA is not enforced for all users',
      'Key vault access is properly configured',
      'Storage account encryption is enabled',
      'Network security groups are configured correctly'
    ];
    for (let i = 0; i < orderedChecks.length; i++) {
      insertResult.run(
        scanRunId1,
        orderedChecks[i].id,
        statuses1[i] || 'PASS',
        statusDescs1[i] || '',
        `${TEST_PREFIX}resource_${i}`,
        `Test Resource ${i}`
      );
    }

    // --- Scan Run 2 (older): 3 results, all passed ---
    const scanRunId2 = `${TEST_PREFIX}scan_run_2`;
    const olderDate = new Date(Date.now() - 86400000).toISOString(); // 1 day ago
    const run2Checks = checks.slice(0, 3);

    db.prepare(`
      INSERT OR REPLACE INTO scan_runs (id, provider_id, status, started_at, completed_at, duration_seconds, total_results, failed_results, passed_results)
      VALUES (?, ?, 'Completed', ?, ?, 18.2, ?, ?, ?)
    `).run(scanRunId2, provider.id, olderDate, olderDate, run2Checks.length, 0, run2Checks.length);

    for (let i = 0; i < run2Checks.length; i++) {
      insertResult.run(
        scanRunId2,
        run2Checks[i].id,
        'PASS',
        'Check passed successfully',
        `${TEST_PREFIX}resource_old_${i}`,
        `Old Test Resource ${i}`
      );
    }

    db.pragma('wal_checkpoint(TRUNCATE)');

    console.log(`[seed] Seeded scan run 1 (${orderedChecks.length} results, ${failCount1} FAIL) and scan run 2 (${run2Checks.length} results, 0 FAIL).`);
  } finally {
    if (db) db.close();
  }
}

/**
 * Back up and clear ALL scan_runs and scan_results (both real and test-prefixed).
 * Returns { scanRuns, scanResults } for later restoration.
 * Enables full test isolation — the tests see only what they seed.
 */
function backupAndClearAllScanHistory() {
  let db;
  try {
    db = new Database(testConfig.database.path, { readonly: false });
    db.pragma('foreign_keys = ON');
    const scanRuns = db.prepare('SELECT * FROM scan_runs').all();
    const scanResults = db.prepare('SELECT * FROM scan_results').all();
    db.prepare('DELETE FROM scan_results').run();
    db.prepare('DELETE FROM scan_runs').run();
    db.pragma('wal_checkpoint(TRUNCATE)');
    console.log(`[setup] Backed up ${scanRuns.length} scan runs and ${scanResults.length} scan results, cleared tables.`);
    return { scanRuns, scanResults };
  } finally {
    if (db) db.close();
  }
}

/**
 * Restore previously backed-up scan_runs and scan_results.
 * Clears the current tables first so the restore is authoritative.
 */
function restoreScanHistory(backup) {
  if (!backup) return;
  let db;
  try {
    db = new Database(testConfig.database.path, { readonly: false });
    db.pragma('foreign_keys = ON');
    db.prepare('DELETE FROM scan_results').run();
    db.prepare('DELETE FROM scan_runs').run();

    if (backup.scanRuns.length > 0) {
      const runCols = Object.keys(backup.scanRuns[0]);
      const runPlaceholders = runCols.map(c => `@${c}`).join(', ');
      const insertRun = db.prepare(`INSERT OR REPLACE INTO scan_runs (${runCols.join(', ')}) VALUES (${runPlaceholders})`);
      const insertRuns = db.transaction((items) => { for (const r of items) insertRun.run(r); });
      insertRuns(backup.scanRuns);
    }

    if (backup.scanResults.length > 0) {
      const resCols = Object.keys(backup.scanResults[0]);
      const resPlaceholders = resCols.map(c => `@${c}`).join(', ');
      const insertRes = db.prepare(`INSERT OR REPLACE INTO scan_results (${resCols.join(', ')}) VALUES (${resPlaceholders})`);
      const insertResMany = db.transaction((items) => { for (const r of items) insertRes.run(r); });
      insertResMany(backup.scanResults);
    }

    db.pragma('wal_checkpoint(TRUNCATE)');
    console.log(`[teardown] Restored ${backup.scanRuns.length} scan runs and ${backup.scanResults.length} scan results.`);
  } finally {
    if (db) db.close();
  }
}

/**
 * Returns the count of seeded scan_results for a given scan_run_id.
 * Used in beforeAll assertions to verify the seed actually produced results.
 */
function getScanResultCount(scanRunId) {
  let db;
  try {
    db = new Database(testConfig.database.path, { readonly: true });
    const row = db.prepare('SELECT COUNT(*) as cnt FROM scan_results WHERE scan_run_id = ?').get(scanRunId);
    return row.cnt;
  } finally {
    if (db) db.close();
  }
}

function seedEnvironmentData() {
  let db;
  try {
    db = new Database(testConfig.database.path, { readonly: false });
    db.pragma('foreign_keys = ON');

    const now = new Date().toISOString();
    const tenantId = `${TEST_PREFIX}tenant-0000-0000-0000-000000000001`;
    const sub1Id = `${TEST_PREFIX}sub-0000-0000-0000-000000000001`;
    const sub2Id = `${TEST_PREFIX}sub-0000-0000-0000-000000000002`;

    const insert = db.prepare(`
      INSERT OR REPLACE INTO azure_arm_resources (id, type, name, location, resource_group, subscription_id, tenant_id, collected_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `);

    // 2 subscriptions, 2 resource groups, 4 resources — enough to exercise the hierarchy tree
    const rows = [
      [`${TEST_PREFIX}rg1-vnet`,   'microsoft.network/virtualnetworks', 'e2e-vnet-1',     'eastus',  'e2e-rg-1', sub1Id, tenantId, now],
      [`${TEST_PREFIX}rg1-nsg`,    'microsoft.network/networksecuritygroups', 'e2e-nsg-1', 'eastus',  'e2e-rg-1', sub1Id, tenantId, now],
      [`${TEST_PREFIX}rg1-sa`,     'microsoft.storage/storageaccounts', 'e2esa1',          'eastus',  'e2e-rg-1', sub1Id, tenantId, now],
      [`${TEST_PREFIX}rg2-kv`,     'microsoft.keyvault/vaults',         'e2e-kv-1',        'westus2', 'e2e-rg-2', sub2Id, tenantId, now],
    ];

    const insertMany = db.transaction((items) => {
      for (const row of items) {
        insert.run(...row);
      }
    });
    insertMany(rows);

    // Force WAL checkpoint so PSU's Microsoft.Data.Sqlite sees the data immediately
    db.pragma('wal_checkpoint(TRUNCATE)');

    console.log(`[seed] Seeded ${rows.length} ARM resources for Environment page tests.`);
  } finally {
    if (db) db.close();
  }
}

function cleanupEnvironmentData() {
  let db;
  try {
    db = new Database(testConfig.database.path, { readonly: false });
    db.prepare(`DELETE FROM azure_arm_resources WHERE id LIKE '${TEST_PREFIX}%'`).run();
    db.pragma('wal_checkpoint(TRUNCATE)');
    console.log('[cleanup] Environment test data cleaned up.');
  } finally {
    if (db) db.close();
  }
}

/**
 * Returns the count of ARM resources in the PSU database.
 */
function getArmResourceCount() {
  let db;
  try {
    db = new Database(testConfig.database.path, { readonly: true });
    const row = db.prepare('SELECT COUNT(*) as count FROM azure_arm_resources').get();
    return row.count;
  } finally {
    if (db) db.close();
  }
}

/**
 * Returns the count of test-prefixed ARM resources in the PSU database.
 */
function getTestArmResourceCount() {
  let db;
  try {
    db = new Database(testConfig.database.path, { readonly: true });
    const row = db.prepare(`SELECT COUNT(*) as count FROM azure_arm_resources WHERE id LIKE '${TEST_PREFIX}%'`).get();
    return row.count;
  } finally {
    if (db) db.close();
  }
}

/**
 * Back up all non-test ARM resources and delete them.
 * Returns the backed-up rows for later restoration.
 */
function backupAndClearAllArmResources() {
  let db;
  try {
    db = new Database(testConfig.database.path, { readonly: false });
    const rows = db.prepare(`SELECT * FROM azure_arm_resources WHERE id NOT LIKE '${TEST_PREFIX}%'`).all();
    db.prepare('DELETE FROM azure_arm_resources').run();
    db.pragma('wal_checkpoint(TRUNCATE)');
    console.log(`[setup] Backed up ${rows.length} ARM resources and cleared table.`);
    return rows;
  } finally {
    if (db) db.close();
  }
}

/**
 * Restore previously backed-up ARM resources.
 */
function restoreArmResources(rows) {
  if (!rows || rows.length === 0) return;
  let db;
  try {
    db = new Database(testConfig.database.path, { readonly: false });
    const insert = db.prepare(`
      INSERT OR REPLACE INTO azure_arm_resources (id, type, name, location, resource_group, subscription_id, tenant_id, kind, sku, identity, managed_by, plan, zones, tags, properties, collected_at)
      VALUES (@id, @type, @name, @location, @resource_group, @subscription_id, @tenant_id, @kind, @sku, @identity, @managed_by, @plan, @zones, @tags, @properties, @collected_at)
    `);
    const insertMany = db.transaction((items) => {
      for (const row of items) { insert.run(row); }
    });
    insertMany(rows);
    db.pragma('wal_checkpoint(TRUNCATE)');
    console.log(`[teardown] Restored ${rows.length} ARM resources.`);
  } finally {
    if (db) db.close();
  }
}

function clearStaleDiscoveryRuns() {
  let db;
  try {
    db = new Database(testConfig.database.path, { readonly: false });
    const result = db.prepare("UPDATE azure_discovery_runs SET status = 'Failed', completed_at = datetime('now') WHERE status = 'Running'").run();
    if (result.changes > 0) {
      console.log(`[cleanup] Cleared ${result.changes} stale Running discovery runs.`);
    }
  } finally {
    if (db) db.close();
  }
}

/**
 * Seed effective role assignment data for Identity View E2E tests.
 * Creates 2 users, 1 group, 1 SP with various role assignments.
 */
function seedIdentityViewData() {
  let db;
  try {
    db = new Database(testConfig.database.path, { readonly: false });
    db.pragma('foreign_keys = ON');

    const now = new Date().toISOString();

    // Seed Entra resources (identities) for display name resolution
    const insertEntra = db.prepare(`
      INSERT OR REPLACE INTO azure_entra_resources (id, type, display_name, properties, collected_at)
      VALUES (?, ?, ?, ?, ?)
    `);
    insertEntra.run(`${TEST_PREFIX}user-1`, 'user', 'E2E Test User', '{}', now);
    insertEntra.run(`${TEST_PREFIX}sp-1`, 'servicePrincipal', 'E2E Test SP', '{}', now);
    insertEntra.run(`${TEST_PREFIX}group-1`, 'group', 'E2E Test Group', '{}', now);

    // Seed subscription for scope label resolution
    const insertArm = db.prepare(`
      INSERT OR REPLACE INTO azure_arm_resources (id, type, name, subscription_id, tenant_id, collected_at)
      VALUES (?, ?, ?, ?, ?, ?)
    `);
    insertArm.run(`/subscriptions/${TEST_PREFIX}sub-1`, 'microsoft.resources/subscriptions',
      'E2E Test Subscription', `${TEST_PREFIX}sub-1`, `${TEST_PREFIX}tenant-1`, now);

    // Seed effective role assignments
    const insertEra = db.prepare(`
      INSERT OR REPLACE INTO azure_effective_role_assignments
        (principal_id, principal_type, principal_display_name, original_principal_id, original_principal_type,
         role_definition_id, role_name, scope, computed_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);

    // User1: direct Contributor on RG
    insertEra.run(`${TEST_PREFIX}user-1`, 'User', 'E2E Test User',
      `${TEST_PREFIX}user-1`, 'User',
      `${TEST_PREFIX}roledef-contrib`, 'Contributor',
      `/subscriptions/${TEST_PREFIX}sub-1/resourceGroups/e2e-rg-1`, now);

    // User1: inherited Owner via group
    insertEra.run(`${TEST_PREFIX}user-1`, 'User', 'E2E Test User',
      `${TEST_PREFIX}group-1`, 'Group',
      `${TEST_PREFIX}roledef-owner`, 'Owner',
      `/subscriptions/${TEST_PREFIX}sub-1`, now);

    // SP: direct Reader on subscription
    insertEra.run(`${TEST_PREFIX}sp-1`, 'ServicePrincipal', 'E2E Test SP',
      `${TEST_PREFIX}sp-1`, 'ServicePrincipal',
      `${TEST_PREFIX}roledef-reader`, 'Reader',
      `/subscriptions/${TEST_PREFIX}sub-1`, now);

    // Group: direct Owner on subscription
    insertEra.run(`${TEST_PREFIX}group-1`, 'Group', 'E2E Test Group',
      `${TEST_PREFIX}group-1`, 'Group',
      `${TEST_PREFIX}roledef-owner`, 'Owner',
      `/subscriptions/${TEST_PREFIX}sub-1`, now);

    db.pragma('wal_checkpoint(TRUNCATE)');
    console.log('[seed] Seeded 4 effective role assignments for Identity View tests.');
  } finally {
    if (db) db.close();
  }
}

/**
 * Clean up Identity View E2E test data.
 */
function cleanupIdentityViewData() {
  let db;
  try {
    db = new Database(testConfig.database.path, { readonly: false });
    db.prepare(`DELETE FROM azure_effective_role_assignments WHERE principal_id LIKE '${TEST_PREFIX}%'`).run();
    db.prepare(`DELETE FROM azure_entra_resources WHERE id LIKE '${TEST_PREFIX}%'`).run();
    db.pragma('wal_checkpoint(TRUNCATE)');
    console.log('[cleanup] Identity View test data cleaned up.');
  } finally {
    if (db) db.close();
  }
}

/**
 * Returns the count of test-prefixed effective role assignments.
 */
function getTestEffectiveRoleAssignmentCount() {
  let db;
  try {
    db = new Database(testConfig.database.path, { readonly: true });
    const row = db.prepare(`SELECT COUNT(*) as count FROM azure_effective_role_assignments WHERE principal_id LIKE '${TEST_PREFIX}%'`).get();
    return row.count;
  } finally {
    if (db) db.close();
  }
}


/**
 * Seed graph_nodes and graph_edges for the test user identity so that
 * Get-CIEMAttackPath -PrincipalId returns results in the drill-down panel.
 * Creates a chain: Internet -> AllowsInbound -> NSG -> AttachedTo -> VM -> HasManagedIdentity -> MI(user-1) -> HasRole -> Subscription
 * The MI node ID matches the test user's Entra resource ID so the attack path links to the identity.
 */
function seedIdentityAttackPathData() {
  let db;
  try {
    db = new Database(testConfig.database.path, { readonly: false });
    db.pragma('foreign_keys = ON');

    const now = new Date().toISOString();

    const insertNode = db.prepare(`
      INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, collected_at)
      VALUES (?, ?, ?, ?, ?)
    `);
    insertNode.run('__internet__', 'Internet', 'Internet', 'global', now);
    insertNode.run(`${TEST_PREFIX}nsg-ap-1`, 'AzureNSG', 'E2E NSG', 'azure', now);
    insertNode.run(`${TEST_PREFIX}vm-ap-1`, 'AzureVM', 'E2E VM', 'azure', now);
    // MI node uses user-1 ID so it matches the seeded identity
    insertNode.run(`${TEST_PREFIX}user-1`, 'EntraManagedIdentity', 'E2E Test User', 'azure', now);
    insertNode.run(`/subscriptions/${TEST_PREFIX}sub-1`, 'AzureSubscription', 'E2E Subscription', 'azure', now);

    const insertEdge = db.prepare(`
      INSERT OR REPLACE INTO graph_edges (source_id, target_id, kind, properties, computed, collected_at)
      VALUES (?, ?, ?, ?, ?, ?)
    `);
    insertEdge.run('__internet__', `${TEST_PREFIX}nsg-ap-1`, 'AllowsInbound',
      '{"open_ports":[{"port":3389,"protocol":"TCP","rule_name":"AllowRDP"}]}', 1, now);
    insertEdge.run(`${TEST_PREFIX}nsg-ap-1`, `${TEST_PREFIX}vm-ap-1`, 'AttachedTo', null, 1, now);
    insertEdge.run(`${TEST_PREFIX}vm-ap-1`, `${TEST_PREFIX}user-1`, 'HasManagedIdentity', null, 0, now);
    insertEdge.run(`${TEST_PREFIX}user-1`, `/subscriptions/${TEST_PREFIX}sub-1`, 'HasRole',
      '{"roleName":"Owner","privileged":true}', 0, now);

    db.pragma('wal_checkpoint(TRUNCATE)');
    console.log('[seed] Seeded graph nodes/edges for Identity Attack Path tests.');
  } finally {
    if (db) db.close();
  }
}

/**
 * Clean up graph data seeded for identity attack path tests.
 */
function cleanupIdentityAttackPathData() {
  let db;
  try {
    db = new Database(testConfig.database.path, { readonly: false });
    const likePattern = `${TEST_PREFIX}%`;
    db.prepare(`DELETE FROM graph_edges WHERE source_id LIKE ? OR target_id LIKE ?`).run(likePattern, likePattern);
    db.prepare(`DELETE FROM graph_nodes WHERE id LIKE ?`).run(likePattern);
    db.pragma('wal_checkpoint(TRUNCATE)');
    console.log('[cleanup] Identity Attack Path graph data cleaned up.');
  } finally {
    if (db) db.close();
  }
}

/**
 * Seed graph_nodes and graph_edges for the Attack Paths page E2E tests.
 * Creates data matching two attack path patterns:
 * 1. open-management-port (3-step): Internet -> AllowsInbound (port 3389) -> NSG
 * 2. disabled-account-with-roles (2-step): disabled EntraUser -> HasRole -> Subscription
 */
function seedAttackPathsPageData() {
  let db;
  try {
    db = new Database(testConfig.database.path, { readonly: false });
    db.pragma('foreign_keys = ON');

    const now = new Date().toISOString();

    const insertNode = db.prepare(`
      INSERT OR REPLACE INTO graph_nodes (id, kind, display_name, provider, properties, collected_at)
      VALUES (?, ?, ?, ?, ?, ?)
    `);
    const insertEdge = db.prepare(`
      INSERT OR REPLACE INTO graph_edges (source_id, target_id, kind, properties, computed, collected_at)
      VALUES (?, ?, ?, ?, ?, ?)
    `);

    // Pattern 1: open-management-port — Internet -> AllowsInbound -> NSG
    insertNode.run('__internet__', 'Internet', 'Internet', 'global', null, now);
    insertNode.run(`${TEST_PREFIX}ap-nsg-1`, 'AzureNSG', 'E2E Attack Path NSG', 'azure', null, now);
    insertEdge.run('__internet__', `${TEST_PREFIX}ap-nsg-1`, 'AllowsInbound',
      '{"open_ports":[{"port":3389,"protocol":"TCP","rule_name":"AllowRDP"}]}', 1, now);

    // Pattern 2: disabled-account-with-roles — disabled user -> HasRole -> subscription
    insertNode.run(`${TEST_PREFIX}ap-disabled-user`, 'EntraUser', 'E2E Disabled User', 'azure',
      '{"accountEnabled":false}', now);
    insertNode.run(`${TEST_PREFIX}ap-sub-1`, 'AzureSubscription', 'E2E Subscription', 'azure', null, now);
    insertEdge.run(`${TEST_PREFIX}ap-disabled-user`, `${TEST_PREFIX}ap-sub-1`, 'HasRole',
      '{"roleName":"Contributor","privileged":false}', 0, now);

    db.pragma('wal_checkpoint(TRUNCATE)');
    console.log('[seed] Seeded graph nodes/edges for Attack Paths page tests (2 patterns).');
  } finally {
    if (db) db.close();
  }
}

/**
 * Clean up Attack Paths page E2E test graph data.
 */
function cleanupAttackPathsPageData() {
  let db;
  try {
    db = new Database(testConfig.database.path, { readonly: false });
    const likePattern = `${TEST_PREFIX}ap-%`;
    db.prepare(`DELETE FROM graph_edges WHERE source_id LIKE ? OR target_id LIKE ?`).run(likePattern, likePattern);
    db.prepare(`DELETE FROM graph_nodes WHERE id LIKE ?`).run(likePattern);
    db.pragma('wal_checkpoint(TRUNCATE)');
    console.log('[cleanup] Attack Paths page graph data cleaned up.');
  } finally {
    if (db) db.close();
  }
}

/**
 * Returns the count of test-prefixed attack path graph nodes.
 */
function getTestAttackPathNodeCount() {
  let db;
  try {
    db = new Database(testConfig.database.path, { readonly: true });
    const row = db.prepare(`SELECT COUNT(*) as count FROM graph_nodes WHERE id LIKE '${TEST_PREFIX}ap-%'`).get();
    return row.count;
  } finally {
    if (db) db.close();
  }
}

module.exports = {
  cleanupTestData, seedChecks, seedTestData,
  backupAndClearAllScanHistory, restoreScanHistory, getScanResultCount,
  seedEnvironmentData, cleanupEnvironmentData,
  getArmResourceCount, getTestArmResourceCount,
  backupAndClearAllArmResources, restoreArmResources,
  clearStaleDiscoveryRuns,
  seedIdentityViewData, cleanupIdentityViewData, getTestEffectiveRoleAssignmentCount,
  seedIdentityAttackPathData, cleanupIdentityAttackPathData,
  seedAttackPathsPageData, cleanupAttackPathsPageData, getTestAttackPathNodeCount,
  TEST_PREFIX
};
