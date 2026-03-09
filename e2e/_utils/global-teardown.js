const { cleanupTestData } = require('./cleanup');
const { close } = require('./database');

module.exports = async function globalTeardown() {
  console.log('[teardown] Running global teardown...');

  cleanupTestData();
  close();

  console.log('[teardown] Complete. PSU server left running.');
};
