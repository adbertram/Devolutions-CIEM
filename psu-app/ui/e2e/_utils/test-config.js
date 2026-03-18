const path = require('path');
const fs = require('fs');

require('dotenv').config({ path: path.resolve(__dirname, '../../../../.env') });

/**
 * Resolves the database path used by the local PSU instance.
 * PSU loads the published module from local-psu/Repository/Modules/Devolutions.CIEM/<version>/data/ciem.db,
 * NOT the development source at psu-app/data/ciem.db.
 */
function resolvePsuDatabasePath() {
  const modulesDir = path.resolve(__dirname, '../../../../local-psu/Repository/Modules/Devolutions.CIEM');
  if (fs.existsSync(modulesDir)) {
    const versions = fs.readdirSync(modulesDir).filter(d =>
      fs.statSync(path.join(modulesDir, d)).isDirectory()
    ).sort();
    if (versions.length > 0) {
      const latestVersion = versions[versions.length - 1];
      const dbPath = path.join(modulesDir, latestVersion, 'data', 'ciem.db');
      if (fs.existsSync(dbPath)) {
        return dbPath;
      }
    }
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
    about: '/ciem/ciem/about'
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
