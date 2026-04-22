const { resolveTestEnvironment } = require('./test-environment');

const testEnvironment = resolveTestEnvironment();

const testConfig = {
  environment: testEnvironment,
  urls: {
    psu: testEnvironment.psuUrl
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
    healthEndpoint: testEnvironment.healthEndpoint,
    token: testEnvironment.psuToken
  },
  timeouts: {
    pageLoad: 30000,
    dynamicContent: 15000,
    scanPoll: 300000,
    serverStart: 120000
  }
};

module.exports = { testConfig };
