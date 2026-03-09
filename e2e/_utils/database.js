const Database = require('better-sqlite3');
const { testConfig } = require('./test-config');

let db = null;

function getDb(readonly = true) {
  if (!db) {
    db = new Database(testConfig.database.path, { readonly });
  }
  return db;
}

function query(sql, params = []) {
  const stmt = getDb().prepare(sql);
  return stmt.all(...params);
}

function queryOne(sql, params = []) {
  const stmt = getDb().prepare(sql);
  return stmt.get(...params);
}

function close() {
  if (db) {
    db.close();
    db = null;
  }
}

function getScanRunCount() {
  const row = queryOne('SELECT COUNT(*) as count FROM scan_runs');
  return row.count;
}

function getLatestScanRun() {
  return queryOne('SELECT * FROM scan_runs ORDER BY started_at DESC LIMIT 1');
}

function getScanResults(scanRunId) {
  return query('SELECT * FROM scan_results WHERE scan_run_id = ?', [scanRunId]);
}

function getCheckCount() {
  const row = queryOne('SELECT COUNT(*) as count FROM checks');
  return row.count;
}

function getEnabledCheckCount() {
  const row = queryOne('SELECT COUNT(*) as count FROM checks WHERE disabled = 0');
  return row.count;
}

function getProviders() {
  return query('SELECT * FROM providers');
}

function getScanRuns() {
  return query('SELECT * FROM scan_runs ORDER BY started_at DESC');
}

function getTestScanRuns() {
  const { TEST_PREFIX } = require('./cleanup');
  return query(`SELECT * FROM scan_runs WHERE id LIKE '${TEST_PREFIX}%' ORDER BY started_at DESC`);
}

function getTestScanResults(scanRunId) {
  return query(`
    SELECT sr.*, c.severity, c.service, c.title as check_title
    FROM scan_results sr
    JOIN checks c ON sr.check_id = c.id
    WHERE sr.scan_run_id = ?
  `, [scanRunId]);
}

module.exports = {
  getDb,
  query,
  queryOne,
  close,
  getScanRunCount,
  getLatestScanRun,
  getScanResults,
  getCheckCount,
  getEnabledCheckCount,
  getProviders,
  getScanRuns,
  getTestScanRuns,
  getTestScanResults
};
