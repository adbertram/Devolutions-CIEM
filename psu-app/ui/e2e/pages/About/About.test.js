const { test, expect } = require('../../_utils/BaseTestSetup');
const AboutPageHelpers = require('./AboutPageHelpers');

test.describe('About Page', () => {
  let aboutPage;

  test.beforeEach(async ({ ciemPage }) => {
    aboutPage = new AboutPageHelpers(ciemPage);
    await aboutPage.navigateToAboutPage();
  });

  test.describe('when the CIEM module is loaded with providers', () => {
    test('should display checks and identities sections', async () => {
      const cardVisible = await aboutPage.isMainCardVisible();
      expect(cardVisible).toBe(true);
      const bodyText = await aboutPage.getText(aboutPage.selectors.mainCard);
      expect(bodyText).toContain('Checks');
      expect(bodyText).toContain('Identities');
    });

    test('should explain checks support with provider check counts', async () => {
      const checksText = await aboutPage.getChecksSectionText();
      expect(checksText).toContain('Azure');
      expect(checksText).toContain('AWS');
      expect(checksText).toContain('security checks');
      expect(checksText).toMatch(/\d+/);
    });

    test('should explain identity support and PAM remediation path', async () => {
      const identitiesText = await aboutPage.getIdentitiesSectionText();
      expect(identitiesText).toContain('identity inventory');
      expect(identitiesText).toContain('effective entitlement');
      expect(identitiesText).toContain('Devolutions PAM');
    });
  });

  test.describe('when version information is rendered from the loaded module', () => {
    test('should display the current module version number', async () => {
      const version = await aboutPage.getVersionText();
      // Version should match semver pattern (e.g., 0.3.38) or "Unknown" if Get-Module returns null
      expect(version.trim()).toMatch(/^(\d+\.\d+\.\d+|Unknown)/);
    });

    test('should display PowerShell Universal 5.5+ as platform', async () => {
      const platform = await aboutPage.getVersionTableCellValue('PowerShell Universal');
      expect(platform.trim()).toBe('5.5+');
    });

    test('should display Adam Bertram as author', async () => {
      const author = await aboutPage.getAuthorText();
      expect(author.trim()).toBe('Adam Bertram');
    });

    test('should display Devolutions Inc. as company', async () => {
      const company = await aboutPage.getVersionTableCellValue('Company');
      expect(company.trim()).toBe('Devolutions Inc.');
    });
  });

  test.describe('when external resource links are available', () => {
    test('should display Devolutions PAM link pointing to devolutions.net/pam', async () => {
      const present = await aboutPage.isPAMLinkPresent();
      expect(present).toBe(true);
      const href = await aboutPage.getPAMLinkHref();
      expect(href).toContain('devolutions.net/pam');
    });

    test('should display Documentation link pointing to docs.devolutions.net', async () => {
      const present = await aboutPage.isDocsLinkPresent();
      expect(present).toBe(true);
      const href = await aboutPage.getDocsLinkHref();
      expect(href).toContain('docs.devolutions.net');
    });
  });
});
