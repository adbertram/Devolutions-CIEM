const path = require('path');
const BasePage = require('../../_utils/BasePage');
const { testConfig } = require('../../_utils/test-config');

class ConfigurationPageHelpers extends BasePage {
  constructor(page) {
    super(page);
    this.selectors = {
      pageTitle: "h4:has-text('Configuration')",
      subtitle: "text=Configure cloud provider authentication for CIEM security scans",
      authCard: ".MuiCard-root:has-text('Cloud Provider Authentication')",
      // Provider and auth dropdowns (MUI renders hidden input + visible combobox)
      cloudProvider: '#cloudProvider',
      cloudProviderCombobox: '[role="combobox"][aria-labelledby="cloudProviderlabel"]',
      authMethod: '#authMethod',
      authMethodCombobox: '[role="combobox"][aria-labelledby="authMethodlabel"]',
      // Auth method help text (caption below dropdown)
      authMethodHelpText: "text=Select the authentication method that matches your environment",
      // Azure SP Secret fields
      azTenantId: '#azTenantId',
      azSpClientId: '#azSpClientId',
      azSpClientSecret: '#azSpClientSecret',
      // Azure SP Certificate fields
      azCertClientId: '#azCertClientId',
      azCertPassword: '#azCertPassword',
      uploadCertButton: "[role='button']:has-text('Upload Certificate'), button:has-text('Upload Certificate')",
      uploadCertInput: '#azCertPfxUpload input[type="file"], input#azCertPfxUpload[type="file"]',
      // Certificate guidance text (shows upload instructions or stored status)
      certUploadGuidance: "text=Upload a PFX certificate file",
      certStoredGuidance: "text=Certificate file is stored",
      // AWS CurrentProfile fields
      awsProfile: '#awsProfile',
      awsRegion: '#awsRegion',
      // AWS AccessKey fields
      awsAccessKeyId: '#awsAccessKeyId',
      awsSecretAccessKey: '#awsSecretAccessKey',
      // Action buttons
      testAuthBtn: '#testAuthBtn',
      saveConfigBtn: "button:has-text('Save Configuration')",
      resetConfigBtn: '#resetConfigBtn',
      getPermissionsBtn: "button:has-text('Get Required Permissions')",
      // Environment chip
      environmentChip: ".MuiCard-root:has-text('Cloud Provider Authentication') .MuiChip-root",
      // Managed identity warning
      managedIdentityWarning: ".MuiAlert-root:has-text('Managed Identity will not work')",
      // Modal
      permissionsModal: '.MuiDialog-root',
      permissionsModalTitle: '.MuiDialog-root h6',
      permissionsModalBody: '[role="dialog"] .MuiDialogContent-root',
      permissionsModalCloseBtn: ".MuiDialog-root button:has-text('Close')",
      // AWS info alert
      awsCliAlert: ".MuiAlert-root:has-text('AWS CLI')",
      // Scheduled discovery
      scheduledDiscoveryCard: ".MuiCard-root:has-text('Scheduled Discovery')",
      scheduledDiscoveryCadence: '#azureDiscoveryScheduleCadence',
      scheduledDiscoveryCadenceCombobox: '[role="combobox"][aria-labelledby="azureDiscoveryScheduleCadencelabel"]',
      scheduledDiscoveryScope: '#azureDiscoveryScheduleScope',
      scheduledDiscoveryScopeCombobox: '[role="combobox"][aria-labelledby="azureDiscoveryScheduleScopelabel"]',
      scheduledDiscoveryEnabled: '#azureDiscoveryScheduleEnabled',
      saveAzureDiscoveryScheduleBtn: '#saveAzureDiscoveryScheduleBtn'
    };
  }

  async navigateToConfigPage() {
    await this.goto(testConfig.pages.config);
    // Wait for the auth method combobox to be visible (indicates dynamic content rendered)
    await this.waitForElement(this.selectors.authMethodCombobox);
  }

  async selectProvider(name) {
    await this.selectMUIOption('cloudProvider', name);
    await this.page.waitForFunction(
      ({ selectId, expectedValue }) => document.querySelector(`#${selectId}`)?.value === expectedValue,
      { selectId: 'cloudProvider', expectedValue: name }
    );
    // Wait for auth method combobox to re-render after provider change.
    await this.waitForElement(this.selectors.authMethodCombobox);

    const expectedRenderedField = {
      Azure: this.selectors.azTenantId,
      AWS: this.selectors.awsProfile
    }[name];

    if (expectedRenderedField) {
      await this.waitForElement(expectedRenderedField);
    }
    if (name === 'AWS') {
      await this.waitForElement(this.selectors.awsCliAlert);
    }
  }

  async selectAuthMethod(value) {
    await this.selectMUIOption('authMethod', value);
    await this.page.waitForFunction(
      ({ selectId, expectedValue }) => document.querySelector(`#${selectId}`)?.value === expectedValue,
      { selectId: 'authMethod', expectedValue: value }
    );

    const expectedRenderedField = {
      ServicePrincipalSecret: this.selectors.azSpClientSecret,
      ServicePrincipalCertificate: this.selectors.azCertClientId,
      CurrentProfile: this.selectors.awsProfile,
      AccessKey: this.selectors.awsAccessKeyId,
      ManagedIdentity: this.selectors.managedIdentityWarning
    }[value];

    if (expectedRenderedField) {
      await this.waitForElement(expectedRenderedField);
    }
  }

  async getSelectedProvider() {
    return await this.getMUISelectValue('cloudProvider');
  }

  async getSelectedAuthMethod() {
    return await this.getMUISelectValue('authMethod');
  }

  async fillTenantId(value) {
    await this.fill(this.selectors.azTenantId, value);
  }

  async fillClientId(value) {
    const spSecret = await this.isElementVisible(this.selectors.azSpClientId);
    if (spSecret) {
      await this.fill(this.selectors.azSpClientId, value);
    } else {
      await this.fill(this.selectors.azCertClientId, value);
    }
  }

  async fillClientSecret(value) {
    await this.fill(this.selectors.azSpClientSecret, value);
  }

  async uploadCertificateFixture(fileName = 'test-certificate.pfx') {
    const filePath = path.join(__dirname, '..', '..', 'fixtures', fileName);
    await this.page.locator(this.selectors.uploadCertInput).setInputFiles(filePath);
    await this.page.locator(`text=${fileName}`).waitFor({ state: 'visible', timeout: 10000 });
  }

  async fillAWSAccessKey(value) {
    await this.fill(this.selectors.awsAccessKeyId, value);
  }

  async fillAWSSecretKey(value) {
    await this.fill(this.selectors.awsSecretAccessKey, value);
  }

  async fillAWSRegion(value) {
    await this.fill(this.selectors.awsRegion, value);
  }

  async clickTestAuth() {
    await this.click(this.selectors.testAuthBtn);
  }

  async clickSave() {
    await this.click(this.selectors.saveConfigBtn);
  }

  async clickReset() {
    await this.click(this.selectors.resetConfigBtn);
    await this.waitForAuthFieldState('Azure', 'ServicePrincipalSecret');
  }

  async clickGetPermissions() {
    await this.click(this.selectors.getPermissionsBtn);
    // PSU runs server-side Get-CIEMRequiredPermission before Show-UDModal — wait for dialog
    await this.waitForElement('[role="dialog"]');
  }

  async isPermissionsModalVisible() {
    return await this.isElementVisible('[role="dialog"]');
  }

  async getPermissionsModalTitle() {
    await this.waitForSelector('[role="dialog"] h6');
    return await this.page.locator('[role="dialog"] h6').first().textContent();
  }

  async closePermissionsModal() {
    await this.click("[role='dialog'] button:has-text('Close')");
    await this.page.locator('[role="dialog"]').waitFor({ state: 'hidden', timeout: 10000 });
  }

  async isFieldVisible(fieldId) {
    return await this.isElementVisible(`#${fieldId}`);
  }

  async isScheduledDiscoveryCardVisible() {
    const cards = this.page.locator(this.selectors.scheduledDiscoveryCard);
    const count = await cards.count();
    for (let i = 0; i < count; i++) {
      if (await cards.nth(i).isVisible()) {
        return true;
      }
    }
    return false;
  }

  async selectScheduleCadence(value) {
    await this.selectMUIOption('azureDiscoveryScheduleCadence', value);
    await this.page.waitForFunction(
      ({ selectId, expectedValue }) => document.querySelector(`#${selectId}`)?.value === expectedValue,
      { selectId: 'azureDiscoveryScheduleCadence', expectedValue: value }
    );
  }

  async selectScheduleScope(value) {
    await this.selectMUIOption('azureDiscoveryScheduleScope', value);
    await this.page.waitForFunction(
      ({ selectId, expectedValue }) => document.querySelector(`#${selectId}`)?.value === expectedValue,
      { selectId: 'azureDiscoveryScheduleScope', expectedValue: value }
    );
  }

  async getSelectedScheduleCadence() {
    return await this.getMUISelectValue('azureDiscoveryScheduleCadence');
  }

  async getSelectedScheduleScope() {
    return await this.getMUISelectValue('azureDiscoveryScheduleScope');
  }

  async isManagedIdentityWarningVisible() {
    return await this.isElementVisible(this.selectors.managedIdentityWarning);
  }

  async waitForDynamicFieldsLoad() {
    await this.waitForElement(this.selectors.authMethodCombobox);
  }

  getExpectedAuthFieldSelector(provider, method) {
    const selectors = {
      Azure: {
        ServicePrincipalSecret: this.selectors.azTenantId,
        ServicePrincipalCertificate: this.selectors.azTenantId,
        ManagedIdentity: this.selectors.managedIdentityWarning
      },
      AWS: {
        CurrentProfile: this.selectors.awsProfile,
        AccessKey: this.selectors.awsAccessKeyId
      }
    };

    if (!Object.prototype.hasOwnProperty.call(selectors, provider)) {
      throw new Error(`Unsupported provider '${provider}'`);
    }

    if (!Object.prototype.hasOwnProperty.call(selectors[provider], method)) {
      throw new Error(`Unsupported authentication method '${method}' for provider '${provider}'`);
    }

    return selectors[provider][method];
  }

  async waitForAuthFieldState(provider, method) {
    const expectedSelector = this.getExpectedAuthFieldSelector(provider, method);

    await this.page.waitForFunction(
      ({ provider, method, expectedSelector }) => {
        const providerElement = document.querySelector('#cloudProvider');
        const methodElement = document.querySelector('#authMethod');
        const expectedElement = document.querySelector(expectedSelector);

        if (providerElement === null || methodElement === null || expectedElement === null) {
          return false;
        }

        if (providerElement.value !== provider || methodElement.value !== method) {
          return false;
        }

        const style = window.getComputedStyle(expectedElement);
        return style.visibility !== 'hidden' && style.display !== 'none' && expectedElement.getClientRects().length > 0;
      },
      { provider, method, expectedSelector },
      { timeout: 15000 }
    );
  }

  async getEnvironmentChipText() {
    const chip = this.page.locator(this.selectors.environmentChip).first();
    return await chip.textContent();
  }

  async waitForToastMessage(text) {
    return await this.waitForToast(text);
  }

  async getPageTitle() {
    return await this.getText(this.selectors.pageTitle);
  }

  async getSubtitleText() {
    await this.waitForSelector(this.selectors.subtitle);
    return await this.page.locator(this.selectors.subtitle).textContent();
  }

  async isAuthCardVisible() {
    return await this.isElementVisible(this.selectors.authCard);
  }

  async isAuthMethodHelpTextVisible() {
    return await this.isElementVisible(this.selectors.authMethodHelpText);
  }

  async getCertUploadGuidanceText() {
    // Certificate guidance can be either "Upload a PFX..." or "Certificate file is stored..."
    const uploadGuidance = await this.isElementVisible(this.selectors.certUploadGuidance);
    if (uploadGuidance) {
      return await this.page.locator(this.selectors.certUploadGuidance).textContent();
    }
    const storedGuidance = await this.isElementVisible(this.selectors.certStoredGuidance);
    if (storedGuidance) {
      return await this.page.locator(this.selectors.certStoredGuidance).textContent();
    }
    return null;
  }

  async getPermissionsModalBodyText() {
    await this.waitForSelector(this.selectors.permissionsModalBody);
    return await this.page.locator(this.selectors.permissionsModalBody).textContent();
  }

  async getAuthMethodOptions() {
    // Open the auth method dropdown and collect available option texts
    const combobox = this.page.locator(this.selectors.authMethodCombobox);
    await combobox.click();
    const options = this.page.locator('[role="option"]');
    const count = await options.count();
    const optionTexts = [];
    for (let i = 0; i < count; i++) {
      optionTexts.push(await options.nth(i).textContent());
    }
    // Close the dropdown by pressing Escape
    await this.page.keyboard.press('Escape');
    return optionTexts;
  }
}

module.exports = ConfigurationPageHelpers;
