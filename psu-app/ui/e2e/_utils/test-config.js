const path = require('path');

require('dotenv').config({ path: path.resolve(__dirname, '../../../../.env') });

/**
 * Resolves the database path used by the PSU instance on adam-server.
 * Tests run on adam-server where PSU lives at ~/psu/.
 */
function resolvePsuDatabasePath() {
  return '/Users/adam/psu/data/ciem.db';
}

const testConfig = {
  urls: {
    psu: process.env.LOCAL_PSU_URL || 'http://localhost:5001'
  },
  pages: {
    dashboard: '/ciem/ciem/',
    scan: '/ciem/ciem/scan',
    history: '/ciem/ciem/history',

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
