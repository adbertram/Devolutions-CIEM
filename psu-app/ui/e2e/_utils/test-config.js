const path = require('path');

require('dotenv').config({ path: path.resolve(__dirname, '../../../../.env') });

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
    attackPaths: '/ciem/ciem/attack-paths',
    attackPathPatterns: '/ciem/ciem/attack-path-patterns'
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
