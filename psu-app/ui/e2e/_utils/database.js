const { sshQuery } = require('./psu-helpers');

function query(sql, params = []) {
  // Substitute positional ? params with values for sqlite3 CLI
  let finalSql = sql;
  for (const val of params) {
    finalSql = finalSql.replace('?', `'${String(val).replace(/'/g, "''")}'`);
  }
  return sshQuery(finalSql);
}

function queryOne(sql, params = []) {
  const rows = query(sql, params);
  return Array.isArray(rows) ? rows[0] || null : rows;
}

function getScanRunCount() {
  const row = queryOne('SELECT COUNT(*) as count FROM scan_runs');
  return row ? row.count : 0;
}

function getLatestScanRun() {
  return queryOne('SELECT * FROM scan_runs ORDER BY started_at DESC LIMIT 1');
}

function getScanResults(scanRunId) {
  return query('SELECT * FROM scan_results WHERE scan_run_id = ?', [scanRunId]);
}

function getCheckCount() {
  const row = queryOne('SELECT COUNT(*) as count FROM checks');
  return row ? row.count : 0;
}

function getEnabledCheckCount() {
  const row = queryOne('SELECT COUNT(*) as count FROM checks WHERE disabled = 0');
  return row ? row.count : 0;
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
  query,
  queryOne,
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
