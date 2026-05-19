const path = require('path');
const dotenv = require('dotenv');

dotenv.config({ path: path.resolve(__dirname, '../../../../.env') });

const ENVIRONMENTS = {
  local: {
    urlVariable: 'LOCAL_PSU_URL',
    tokenVariable: 'LOCAL_PSU_TOKEN',
    usernameVariable: 'LOCAL_PSU_USERNAME',
    passwordVariable: 'LOCAL_PSU_PASSWORD',
    usesPublishPointDatabase: true
  },
  azure: {
    urlVariable: 'AZURE_PSU_URL',
    tokenVariable: 'AZURE_PSU_TOKEN',
    usernameVariable: 'AZURE_PSU_USERNAME',
    passwordVariable: 'AZURE_PSU_PASSWORD',
    usesPublishPointDatabase: false
  }
};

function getRequiredEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} is required for CIEM E2E tests`);
  }
  return value;
}

function normalizeUrl(url) {
  return url.replace(/\/+$/, '');
}

function resolveTestEnvironment(name = process.env.CIEM_TEST_ENVIRONMENT || 'local') {
  const definition = ENVIRONMENTS[name];
  if (!definition) {
    throw new Error(`Unsupported CIEM test environment '${name}'. Expected local or azure.`);
  }

  const environment = {
    name,
    psuUrl: normalizeUrl(getRequiredEnv(definition.urlVariable)),
    psuToken: getRequiredEnv(definition.tokenVariable),
    uiUsername: process.env[definition.usernameVariable] || '',
    uiPassword: process.env[definition.passwordVariable] || '',
    healthEndpoint: '/api/v1/alive',
    usesPublishPointDatabase: definition.usesPublishPointDatabase
  };

  if (definition.usesPublishPointDatabase) {
    const publishPointPath = getRequiredEnv('PUBLISH_POINT_PSU_PATH');
    environment.publishPointSsh = getRequiredEnv('PUBLISH_POINT_SSH');
    environment.publishPointPsuPath = publishPointPath;
    environment.databasePath = path.posix.join(publishPointPath, 'data/ciem.db');
  }

  return environment;
}

module.exports = {
  resolveTestEnvironment
};
