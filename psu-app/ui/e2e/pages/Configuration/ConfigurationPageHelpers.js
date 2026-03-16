const BasePage = require('../../_utils/BasePage');
const { testConfig } = require('../../_utils/test-config');

class ConfigurationPageHelpers extends BasePage {
  constructor(page) {
    super(page);
    this.selectors = {
      pageTitle: "h4:has-text('Configuration')",
      // Provider and auth dropdowns (MUI renders hidden input + visible combobox)
      cloudProvider: '#cloudProvider',
      cloudProviderCombobox: '[role="combobox"][aria-labelledby="cloudProviderlabel"]',
      authMethod: '#authMethod',
      authMethodCombobox: '[role="combobox"][aria-labelledby="authMethodlabel"]',
      // Azure SP Secret fields
      azTenantId: '#azTenantId',
      azSpClientId: '#azSpClientId',
      azSpClientSecret: '#azSpClientSecret',
      // Azure SP Certificate fields
      azCertClientId: '#azCertClientId',
      azCertPassword: '#azCertPassword',
      uploadCertButton: "button:has-text('Upload Certificate')",
      // AWS CurrentProfile fields
      awsProfile: '#awsProfile',
      awsRegion: '#awsRegion',
      // AWS AccessKey fields
      awsAccessKeyId: '#awsAccessKeyId',
      awsSecretAccessKey: '#awsSecretAccessKey',
      // Action buttons
      testAuthBtn: '#testAuthBtn',
      saveConfigBtn: '#saveConfigBtn',
      resetConfigBtn: '#resetConfigBtn',
      getPermissionsBtn: "button:has-text('Get Required Permissions')",
      // Environment chip
      environmentChip: '.MuiChip-root',
      // Managed identity warning
      managedIdentityWarning: ".MuiAlert-root:has-text('Managed Identity will not work')",
      // Modal
      permissionsModal: '.MuiDialog-root',
      permissionsModalTitle: '.MuiDialog-root h6',
      permissionsModalCloseBtn: ".MuiDialog-root button:has-text('Close')",
      // AWS info alert
      awsCliAlert: ".MuiAlert-root:has-text('AWS CLI')"
    };
  }

  async navigateToConfigPage() {
    await this.goto(testConfig.pages.config);
    // Wait for the auth method combobox to be visible (indicates dynamic content rendered)
    await this.waitForElement(this.selectors.authMethodCombobox);
  }

  async selectProvider(name) {
    await this.selectMUIOption('cloudProvider', name);
    // Wait for auth method combobox to re-render after provider change
    await this.waitForElement(this.selectors.authMethodCombobox);
    // Brief wait for PSU server-side re-render of auth fields
    await this.page.waitForTimeout(1000);
  }

  async selectAuthMethod(value) {
    await this.selectMUIOption('authMethod', value);
    // Brief wait for PSU server-side re-render of auth fields
    await this.page.waitForTimeout(1000);
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

  async isManagedIdentityWarningVisible() {
    return await this.isElementVisible(this.selectors.managedIdentityWarning);
  }

  async waitForDynamicFieldsLoad() {
    // Wait for auth method combobox to be visible after dynamic re-render
    await this.waitForElement(this.selectors.authMethodCombobox);
    await this.page.waitForTimeout(1000);
  }

  async getEnvironmentChipText() {
    const chip = this.page.locator(this.selectors.environmentChip).first();
    return await chip.textContent();
  }

  async waitForToastMessage(text) {
    return await this.waitForToast(text);
  }
}

module.exports = ConfigurationPageHelpers;
