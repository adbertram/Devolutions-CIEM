const { resolveTestEnvironment } = require('./test-environment');
const { getPagePathByName } = require('./page-registry');

const testEnvironment = resolveTestEnvironment();

const testConfig = {
  environment: testEnvironment,
  urls: {
    psu: testEnvironment.psuUrl
  },
  pages: {
    dashboard: getPagePathByName('Dashboard'),
    scan: getPagePathByName('Scan'),
    history: getPagePathByName('Scan History'),
    reports: getPagePathByName('Reports'),
    environment: getPagePathByName('Environment'),
    authenticationProfiles: getPagePathByName('Authentication Profiles'),
    config: getPagePathByName('Configuration'),
    about: getPagePathByName('About'),
    identities: getPagePathByName('Identities'),
    attackPaths: getPagePathByName('Attack Paths'),
    attackPathPatterns: getPagePathByName('Attack Path Patterns')
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
