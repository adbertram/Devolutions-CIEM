const pageRegistry = require('../../../modules/Devolutions.CIEM.PSU/Data/pages.json');

function getPageHref(page) {
  return page.route === '/' ? '/ciem' : `/ciem${page.route}`;
}

function getPagePath(page) {
  return page.route === '/' ? '/ciem/ciem/' : `/ciem/ciem${page.route}`;
}

function getPageByName(name) {
  const page = pageRegistry.find((entry) => entry.name === name);
  if (!page) {
    throw new Error(`Unknown CIEM page registry name: ${name}`);
  }

  return page;
}

function getPagePathByName(name) {
  return getPagePath(getPageByName(name));
}

function getExpectedNavItems() {
  return pageRegistry
    .slice()
    .sort((left, right) => left.order - right.order)
    .map((page) => ({
      label: page.name,
      href: getPageHref(page),
      path: getPagePath(page)
    }));
}

module.exports = {
  pageRegistry,
  getExpectedNavItems,
  getPageByName,
  getPageHref,
  getPagePath,
  getPagePathByName
};
