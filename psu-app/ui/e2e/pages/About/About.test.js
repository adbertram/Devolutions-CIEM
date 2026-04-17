const { test, expect } = require('../../_utils/BaseTestSetup');
const AboutPageHelpers = require('./AboutPageHelpers');

test.describe('About Page', () => {
  let aboutPage;

  test.beforeEach(async ({ ciemPage }) => {
    aboutPage = new AboutPageHelpers(ciemPage);
    await aboutPage.navigateToAboutPage();
  });

  test.describe('when the CIEM module is loaded with providers', () => {
    test('should display module description mentioning security scanning', async () => {
      const cardVisible = await aboutPage.isMainCardVisible();
      expect(cardVisible).toBe(true);
      const bodyText = await aboutPage.getText(aboutPage.selectors.mainCard);
      expect(bodyText).toContain('security scanning solution');
    });

    test('should list Azure security checks with count from provider data', async () => {
      const features = await aboutPage.getFeatureTexts();
      const azureFeature = features.find(f => f.includes('Azure') && f.includes('security checks'));
      expect(azureFeature).toBeTruthy();
      // Should contain a number (the check count)
      expect(azureFeature).toMatch(/\d+/);
    });

    test('should list AWS security checks with count from provider data', async () => {
      const features = await aboutPage.getFeatureTexts();
      const awsFeature = features.find(f => f.includes('AWS') && f.includes('security checks'));
      expect(awsFeature).toBeTruthy();
      expect(awsFeature).toMatch(/\d+/);
    });

    test('should include multi-provider support in features list', async () => {
      const features = await aboutPage.getFeatureTexts();
      const multiProvider = features.find(f => f.includes('Multi-provider'));
      expect(multiProvider).toBeTruthy();
    });

    test('should include identity and entitlement focused checks in features list', async () => {
      const features = await aboutPage.getFeatureTexts();
      const identityFeature = features.find(f => f.includes('Identities') || f.includes('entitlement'));
      expect(identityFeature).toBeTruthy();
    });

    test('should include PAM integration in features list', async () => {
      const features = await aboutPage.getFeatureTexts();
      const pamFeature = features.find(f => f.includes('PAM') || f.includes('remediation'));
      expect(pamFeature).toBeTruthy();
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
