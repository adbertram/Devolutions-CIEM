const path = require('path');
const fs = require('fs');

require('dotenv').config({ path: path.resolve(__dirname, '../../../../.env') });

/**
 * Resolves the database path used by the local PSU instance.
 * The CIEM module stores its DB OUTSIDE the module version directory so data
 * survives module upgrades. The DB lives at local-psu/data/ciem.db (sibling of Repository/).
 */
function resolvePsuDatabasePath() {
  const psuDataDb = path.resolve(__dirname, '../../../../local-psu/data/ciem.db');
  if (fs.existsSync(psuDataDb)) {
    return psuDataDb;
  }
  // Fallback to development DB (won't be seen by PSU but allows offline test runs)
  return path.resolve(__dirname, '../../../data/ciem.db');
}

const testConfig = {
  urls: {
    psu: process.env.LOCAL_PSU_URL || 'http://localhost:5001'
  },
  pages: {
    dashboard: '/ciem/ciem/',
    scan: '/ciem/ciem/scan',
    history: '/ciem/ciem/history',
    graph: '/ciem/ciem/graph',
    environment: '/ciem/ciem/environment',
    config: '/ciem/ciem/config',
    about: '/ciem/ciem/about',
    identities: '/ciem/ciem/identities',
    attackPaths: '/ciem/ciem/attack-paths'
  },
  database: {
    path: resolvePsuDatabasePath()
  },
  psu: {
    setupScript: path.resolve(__dirname, '../../../../scripts/setup-local-psu.sh'),
    healthEndpoint: '/api/v1/alive'
  },
  timeouts: {
    pageLoad: 30000,
    dynamicContent: 15000,
    scanPoll: 300000,
    serverStart: 120000
  }
};

module.exports = { testConfig };
