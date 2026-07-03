const fs = require('fs');
const path = require('path');
const { sshQuery, sshNonQuery } = require('./psu-helpers');

const FIXTURE_DIR = path.resolve(__dirname, '..', 'fixtures');
const CLEANUP_MODE = 'restoreTouchedTables';
const FIXTURE_NAME_PATTERN = /^[a-z0-9][a-z0-9-]*$/;
const SQL_IDENTIFIER_PATTERN = /^[A-Za-z_][A-Za-z0-9_]*$/;
const ALLOWED_FIELDS = new Set([
  'name',
  'description',
  'touchedTables',
  'tables',
  'preconditions',
  'expectedCounts',
  'cleanup'
]);
const REQUIRED_FIELDS = [
  'name',
  'description',
  'touchedTables',
  'tables',
  'expectedCounts',
  'cleanup'
];

function hasOwn(obj, key) {
  return Object.prototype.hasOwnProperty.call(obj, key);
}

function assertPlainObject(value, pathName) {
  if (value === null || Array.isArray(value) || typeof value !== 'object') {
    throw new Error(`${pathName} must be an object`);
  }
}

function assertString(value, pathName) {
  if (typeof value !== 'string' || value.length === 0) {
    throw new Error(`${pathName} must be a non-empty string`);
  }
}

function assertSqlIdentifier(value, pathName) {
  assertString(value, pathName);
  if (!SQL_IDENTIFIER_PATTERN.test(value)) {
    throw new Error(`${pathName} has invalid SQL identifier '${value}'`);
  }
}

function assertArray(value, pathName) {
  if (!Array.isArray(value)) {
    throw new Error(`${pathName} must be an array`);
  }
}

function assertSameMembers(actual, expected, pathName) {
  const actualSorted = [...actual].sort();
  const expectedSorted = [...expected].sort();
  if (actualSorted.length !== expectedSorted.length) {
    throw new Error(`${pathName} must contain exactly: ${expectedSorted.join(', ')}`);
  }

  for (let i = 0; i < actualSorted.length; i++) {
    if (actualSorted[i] !== expectedSorted[i]) {
      throw new Error(`${pathName} must contain exactly: ${expectedSorted.join(', ')}`);
    }
  }
}

function assertJsonScalar(value, pathName) {
  const valueType = typeof value;
  if (value === null || valueType === 'string' || valueType === 'number') {
    return;
  }

  throw new Error(`${pathName} must be a string, number, or null`);
}

function validateFixture(fixture) {
  assertPlainObject(fixture, 'fixture');

  for (const field of Object.keys(fixture)) {
    if (!ALLOWED_FIELDS.has(field)) {
      throw new Error(`Unknown fixture field '${field}'`);
    }
  }

  for (const field of REQUIRED_FIELDS) {
    if (!hasOwn(fixture, field)) {
      throw new Error(`Fixture is missing required field '${field}'`);
    }
  }

  assertString(fixture.name, 'fixture.name');
  if (!FIXTURE_NAME_PATTERN.test(fixture.name)) {
    throw new Error(`fixture.name has invalid value '${fixture.name}'`);
  }

  assertString(fixture.description, 'fixture.description');
  assertArray(fixture.touchedTables, 'fixture.touchedTables');
  if (fixture.touchedTables.length === 0) {
    throw new Error('fixture.touchedTables must include at least one table');
  }

  const touchedTableSet = new Set();
  for (let i = 0; i < fixture.touchedTables.length; i++) {
    const table = fixture.touchedTables[i];
    assertSqlIdentifier(table, `fixture.touchedTables[${i}]`);
    if (touchedTableSet.has(table)) {
      throw new Error(`fixture.touchedTables contains duplicate table '${table}'`);
    }
    touchedTableSet.add(table);
  }

  assertPlainObject(fixture.tables, 'fixture.tables');
  assertPlainObject(fixture.expectedCounts, 'fixture.expectedCounts');
  assertSameMembers(Object.keys(fixture.tables), fixture.touchedTables, 'fixture.tables');
  assertSameMembers(Object.keys(fixture.expectedCounts), fixture.touchedTables, 'fixture.expectedCounts');

  for (const table of fixture.touchedTables) {
    const rows = fixture.tables[table];
    assertArray(rows, `fixture.tables.${table}`);

    let expectedColumns = null;
    for (let rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      const row = rows[rowIndex];
      assertPlainObject(row, `fixture.tables.${table}[${rowIndex}]`);
      const columns = Object.keys(row);
      if (columns.length === 0) {
        throw new Error(`fixture.tables.${table}[${rowIndex}] must include at least one column`);
      }

      for (const column of columns) {
        assertSqlIdentifier(column, `fixture.tables.${table}[${rowIndex}].${column}`);
        assertJsonScalar(row[column], `fixture.tables.${table}[${rowIndex}].${column}`);
      }

      if (expectedColumns === null) {
        expectedColumns = columns;
      } else {
        assertSameMembers(columns, expectedColumns, `fixture.tables.${table}[${rowIndex}] columns`);
      }
    }

    const expectedCount = fixture.expectedCounts[table];
    if (!Number.isInteger(expectedCount) || expectedCount < 0) {
      throw new Error(`fixture.expectedCounts.${table} must be a non-negative integer`);
    }
  }

  if (hasOwn(fixture, 'preconditions')) {
    assertArray(fixture.preconditions, 'fixture.preconditions');
    for (let i = 0; i < fixture.preconditions.length; i++) {
      assertString(fixture.preconditions[i], `fixture.preconditions[${i}]`);
    }
  }

  if (fixture.cleanup !== CLEANUP_MODE) {
    throw new Error(`fixture.cleanup must be '${CLEANUP_MODE}'`);
  }

  return fixture;
}

function loadFixture(fixtureName) {
  assertString(fixtureName, 'fixtureName');
  if (!FIXTURE_NAME_PATTERN.test(fixtureName)) {
    throw new Error(`fixtureName has invalid value '${fixtureName}'`);
  }

  const fixturePath = path.join(FIXTURE_DIR, `${fixtureName}.json`);
  const fixture = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));
  if (fixture.name !== fixtureName) {
    throw new Error(`Fixture filename '${fixtureName}' does not match fixture.name '${fixture.name}'`);
  }

  return validateFixture(fixture);
}

function sqlValue(value) {
  if (value === null) {
    return 'NULL';
  }

  if (typeof value === 'number') {
    return String(value);
  }

  if (typeof value === 'string') {
    return `'${value.replace(/'/g, "''")}'`;
  }

  throw new Error(`Unsupported SQL value type '${typeof value}'`);
}

function sqlInList(values) {
  if (values.length === 0) {
    throw new Error('SQL IN list must include at least one value');
  }

  return values.map(sqlValue).join(', ');
}

function isMutableCatalogTable(table) {
  return table === 'checks';
}

function getFixtureTableIds(fixture, table) {
  const ids = fixture.tables[table].map(row => {
    if (!hasOwn(row, 'id')) {
      throw new Error(`fixture.tables.${table} rows must include id`);
    }
    return row.id;
  });

  return ids;
}

function selectAllRows(table) {
  assertSqlIdentifier(table, 'table');
  return sshQuery(`SELECT * FROM ${table}`);
}

function selectFixtureRows(fixture, table) {
  assertSqlIdentifier(table, 'table');

  if (!isMutableCatalogTable(table)) {
    return selectAllRows(table);
  }

  return sshQuery(`SELECT id, disabled FROM ${table} WHERE id IN (${sqlInList(getFixtureTableIds(fixture, table))})`);
}

function deleteTables(touchedTables, tables = null) {
  const deleteOrder = [...touchedTables].reverse();
  const statements = deleteOrder.map(table => {
    assertSqlIdentifier(table, 'table');
    if (isMutableCatalogTable(table)) {
      if (!tables || !Array.isArray(tables[table])) {
        throw new Error(`Cannot delete mutable catalog table '${table}' without fixture rows`);
      }

      return `DELETE FROM ${table} WHERE id IN (${sqlInList(tables[table].map(row => row.id))})`;
    }

    return `DELETE FROM ${table}`;
  });
  if (statements.length > 0) {
    sshNonQuery(statements.join('; '));
  }
}

function buildInsertStatements(table, rows) {
  assertSqlIdentifier(table, 'table');
  const statements = [];

  for (const row of rows) {
    const columns = Object.keys(row);
    if (columns.length === 0) {
      throw new Error(`Cannot insert empty row into ${table}`);
    }

    for (const column of columns) {
      assertSqlIdentifier(column, `column ${column}`);
    }

    const values = columns.map(column => sqlValue(row[column])).join(', ');
    statements.push(`INSERT OR REPLACE INTO ${table} (${columns.join(', ')}) VALUES (${values})`);
  }

  return statements;
}

function buildCheckUpdateStatements(rows) {
  const statements = [];

  for (const row of rows) {
    if (!hasOwn(row, 'id') || !hasOwn(row, 'disabled')) {
      throw new Error('checks fixture rows must include id and disabled');
    }

    statements.push(`INSERT OR REPLACE INTO checks (id, disabled) VALUES (${sqlValue(row.id)}, ${sqlValue(row.disabled)})`);
  }

  return statements;
}

function insertTableRows(tables, touchedTables) {
  const statements = [];

  for (const table of touchedTables) {
    if (isMutableCatalogTable(table)) {
      statements.push(...buildCheckUpdateStatements(tables[table]));
    } else {
      statements.push(...buildInsertStatements(table, tables[table]));
    }
  }

  if (statements.length > 0) {
    sshNonQuery(statements.join('; '));
  }
}

function getFixtureTableCounts(fixtureName) {
  const fixture = loadFixture(fixtureName);
  const counts = {};

  for (const table of fixture.touchedTables) {
    const sql = isMutableCatalogTable(table)
      ? `SELECT COUNT(*) as count FROM ${table} WHERE id IN (${sqlInList(getFixtureTableIds(fixture, table))})`
      : `SELECT COUNT(*) as count FROM ${table}`;
    const row = sshQuery(sql)[0];
    counts[table] = Number(row.count);
  }

  return counts;
}

function verifyFixtureCounts(fixture) {
  const counts = getFixtureTableCounts(fixture.name);

  for (const table of fixture.touchedTables) {
    const expected = fixture.expectedCounts[table];
    const actual = counts[table];
    if (actual !== expected) {
      throw new Error(`Fixture '${fixture.name}' expected ${expected} rows in ${table}, got ${actual}`);
    }
  }
}

function backupFixtureTables(fixtureName) {
  const fixture = loadFixture(fixtureName);
  const tables = {};

  for (const table of fixture.touchedTables) {
    tables[table] = selectFixtureRows(fixture, table);
  }

  return {
    fixtureName: fixture.name,
    touchedTables: fixture.touchedTables,
    tables
  };
}

function backupAndApplyFixture(fixtureName) {
  const fixture = loadFixture(fixtureName);
  const backup = backupFixtureTables(fixtureName);

  deleteTables(fixture.touchedTables, fixture.tables);
  insertTableRows(fixture.tables, fixture.touchedTables);
  verifyFixtureCounts(fixture);
  console.log(`[fixture] Applied '${fixture.name}'.`);

  return backup;
}

function insertFixtureRows(fixtureName) {
  const fixture = loadFixture(fixtureName);
  insertTableRows(fixture.tables, fixture.touchedTables);
  console.log(`[fixture] Inserted rows for '${fixture.name}'.`);
}

function restoreFixtureBackup(backup) {
  assertPlainObject(backup, 'backup');
  assertString(backup.fixtureName, 'backup.fixtureName');
  assertArray(backup.touchedTables, 'backup.touchedTables');
  assertPlainObject(backup.tables, 'backup.tables');
  assertSameMembers(Object.keys(backup.tables), backup.touchedTables, 'backup.tables');

  for (const table of backup.touchedTables) {
    assertSqlIdentifier(table, 'backup.touchedTables table');
    assertArray(backup.tables[table], `backup.tables.${table}`);
  }

  const fixture = loadFixture(backup.fixtureName);
  deleteTables(backup.touchedTables, fixture.tables);
  insertTableRows(backup.tables, backup.touchedTables);
  console.log(`[fixture] Restored '${backup.fixtureName}'.`);
}

module.exports = {
  backupAndApplyFixture,
  backupFixtureTables,
  getFixtureTableCounts,
  insertFixtureRows,
  loadFixture,
  restoreFixtureBackup,
  validateFixture
};
