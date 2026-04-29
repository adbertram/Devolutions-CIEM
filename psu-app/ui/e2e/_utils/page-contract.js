const {
  getPageByName,
  getPagePathByName,
  pageRegistry
} = require('./page-registry');

const PAGE_FIELDS = [
  'factory',
  'icon',
  'name',
  'order',
  'route',
  'subtitle',
  'test',
  'title'
];
const TEST_FIELDS = [
  'expectedColumns',
  'smokeSelector'
];

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

function assertArray(value, pathName) {
  if (!Array.isArray(value)) {
    throw new Error(`${pathName} must be an array`);
  }
}

function assertExactFields(actualFields, expectedFields, pathName) {
  const actual = [...actualFields].sort();
  const expected = [...expectedFields].sort();
  if (actual.length !== expected.length) {
    throw new Error(`${pathName} must contain exactly: ${expected.join(', ')}`);
  }

  for (let i = 0; i < actual.length; i++) {
    if (actual[i] !== expected[i]) {
      throw new Error(`${pathName} must contain exactly: ${expected.join(', ')}`);
    }
  }
}

function assertUnique(value, seen, pathName) {
  if (seen.has(value)) {
    throw new Error(`${pathName} contains duplicate value '${value}'`);
  }

  seen.add(value);
}

function validatePageRegistryContract() {
  if (!Array.isArray(pageRegistry) || pageRegistry.length === 0) {
    throw new Error('Page registry must contain at least one page');
  }

  const names = new Set();
  const routes = new Set();
  const factories = new Set();
  const orders = new Set();

  for (let i = 0; i < pageRegistry.length; i++) {
    const page = pageRegistry[i];
    const pagePath = `pageRegistry[${i}]`;

    assertPlainObject(page, pagePath);
    assertExactFields(Object.keys(page), PAGE_FIELDS, pagePath);

    for (const field of ['name', 'route', 'title', 'subtitle', 'icon', 'factory']) {
      assertString(page[field], `${pagePath}.${field}`);
    }

    if (!/^\/($|[^/].*)/.test(page.route)) {
      throw new Error(`${pagePath}.route must start with one slash and no double slash`);
    }

    if (!Number.isInteger(page.order) || page.order <= 0) {
      throw new Error(`${pagePath}.order must be a positive integer`);
    }

    assertUnique(page.name.toLowerCase(), names, 'Page registry names');
    assertUnique(page.route.toLowerCase(), routes, 'Page registry routes');
    assertUnique(page.factory.toLowerCase(), factories, 'Page registry factories');
    assertUnique(page.order, orders, 'Page registry orders');

    assertPlainObject(page.test, `${pagePath}.test`);
    assertExactFields(Object.keys(page.test), TEST_FIELDS, `${pagePath}.test`);
    assertString(page.test.smokeSelector, `${pagePath}.test.smokeSelector`);
    assertArray(page.test.expectedColumns, `${pagePath}.test.expectedColumns`);
  }

  return true;
}

async function navigateToRegisteredPage(pageHelper, pageName) {
  const page = getPageByName(pageName);
  await pageHelper.goto(getPagePathByName(pageName));
  await pageHelper.waitForElement(page.test.smokeSelector);
}

async function getVisibleColumnHeaders(page, selector) {
  const headers = page.locator(selector);
  await headers.first().waitFor({ state: 'visible', timeout: 15000 });

  return await headers.evaluateAll(nodes =>
    nodes
      .map(node => node.textContent.trim())
      .filter(text => text.length > 0)
  );
}

module.exports = {
  getVisibleColumnHeaders,
  navigateToRegisteredPage,
  validatePageRegistryContract
};
