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
    db.prepare(`DELETE FROM azure_arm_resources WHERE id LIKE '${TEST_PREFIX}%'`).run();

    console.log('[cleanup] Test data cleaned up.');
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

    console.log(`[seed] Seeded scan run 1 (${orderedChecks.length} results, ${failCount1} FAIL) and scan run 2 (${run2Checks.length} results, 0 FAIL).`);
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

module.exports = {
  cleanupTestData, seedTestData,
  seedEnvironmentData, cleanupEnvironmentData,
  getArmResourceCount, getTestArmResourceCount,
  backupAndClearAllArmResources, restoreArmResources,
  clearStaleDiscoveryRuns,
  TEST_PREFIX
};
