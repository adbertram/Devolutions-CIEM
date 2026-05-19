const BasePage = require('../../_utils/BasePage');
const { testConfig } = require('../../_utils/test-config');

class ConfigurationPageHelpers extends BasePage {
  constructor(page) {
    super(page);
    this.providerMethods = {
      Azure: ['ServicePrincipalSecret', 'ServicePrincipalCertificate', 'ManagedIdentity'],
      AWS: ['CurrentProfile', 'AccessKey'],
      Email: ['SmtpAnonymous', 'SmtpBasic']
    };
    this.methodReadySelectors = {
      ServicePrincipalSecret: '#authProfileField_Azure_ServicePrincipalSecret_TenantId',
      ServicePrincipalCertificate: '#authProfileField_Azure_ServicePrincipalCertificate_TenantId',
      ManagedIdentity: '#authProfileField_Azure_ManagedIdentity_ManagedIdentityClientId',
      CurrentProfile: '#authProfileField_AWS_CurrentProfile_Region',
      AccessKey: '#authProfileField_AWS_AccessKey_Region',
      SmtpAnonymous: '#authProfileField_Email_SmtpAnonymous_Host',
      SmtpBasic: '#authProfileField_Email_SmtpBasic_Host'
    };
    this.selectors = {
      pageTitle: "h4:has-text('Configuration')",
      subtitle: "text=Configure authentication profiles, scheduled discovery, and outbound notifications",
      authCard: ".MuiCard-root:has-text('Cloud Provider Authentication')",
      authMethodCombobox: '[role="combobox"][aria-labelledby="authMethodlabel"]',
      cloudProviderCombobox: '[role="combobox"][aria-labelledby="cloudProviderlabel"]',
      testAuthBtn: '#testAuthBtn',
      getPermissionsBtn: "button:has-text('Get Required Permissions')",
      authenticationProfilesCard: ".MuiCard-root:has-text('Authentication Profiles')",
      authenticationProfilesTable: '#authenticationProfilesTable',
      newAuthenticationProfileBtn: '#newAuthenticationProfileBtn',
      authenticationProfileDetailsDialog: '.MuiDialog-root:has-text("Authentication Profile Details")',
      authenticationProfileForm: '#authenticationProfileForm',
      authProfileName: '#authProfileName',
      azureTenantId: '#authProfileField_Azure_ServicePrincipalSecret_TenantId',
      azureClientId: '#authProfileField_Azure_ServicePrincipalSecret_ClientId',
      azureClientSecret: '#authProfileField_Azure_ServicePrincipalSecret_ClientSecret',
      host: '#authProfileField_Email_SmtpAnonymous_Host',
      port: '#authProfileField_Email_SmtpAnonymous_Port',
      managedIdentityClientId: '#authProfileField_Azure_ManagedIdentity_ManagedIdentityClientId',
      awsProfile: '#authProfileField_AWS_CurrentProfile_Profile',
      awsRegion: '#authProfileField_AWS_CurrentProfile_Region',
      tlsModeCombobox: '[role="combobox"][aria-labelledby="authProfileField_Email_SmtpAnonymous_TlsModelabel"]',
      saveAuthenticationProfileBtn: '#saveAuthenticationProfileBtn',
      testAuthenticationProfileBtn: '#testAuthenticationProfileBtn',
      assignProviderDiscoveryBtn: '#assignProviderDiscoveryBtn',
      assignEmailNotificationBtn: '#assignEmailNotificationBtn',
      removeAuthenticationProfileBtn: '#removeAuthenticationProfileBtn',
      cancelAuthenticationProfileEditBtn: '#cancelAuthenticationProfileEditBtn',
      scheduledDiscoveryCard: '#scheduledDiscoveryWrapper .MuiCard-root',
      scheduledDiscoveryCadenceCombobox: '[role="combobox"][aria-labelledby="azureDiscoveryScheduleCadencelabel"]',
      scheduledDiscoveryScopeCombobox: '[role="combobox"][aria-labelledby="azureDiscoveryScheduleScopelabel"]',
      saveAzureDiscoveryScheduleBtn: '#saveAzureDiscoveryScheduleBtn',
      notificationCard: ".MuiCard-root:has-text('Notification Channels')",
      availableNotificationTypes: '#availableNotificationChannelTypes',
      addEmailNotificationChannelBtn: '#addEmailNotificationChannelBtn',
      notificationChannelsTable: '#notificationChannelsTable',
      notificationChannelEditorPane: '#notificationChannelEditorPane',
      editEmailNotificationChannelBtn: '#editNotificationChannel_email-default',
      notificationChannelDetailsDialog: '.MuiDialog-root:has-text("Notification Channel Details")',
      notificationChannelEnabled: '#notificationChannelEnabled',
      notificationFromAddress: '#notificationFromAddress',
      notificationToRecipients: '#notificationToRecipients',
      notificationCcRecipients: '#notificationCcRecipients',
      notificationBccRecipients: '#notificationBccRecipients',
      saveNotificationsBtn: '#saveNotificationsBtn',
      cancelNotificationChannelEditBtn: '#cancelNotificationChannelEditBtn',
      testNotificationEmailBtn: '#testNotificationEmailBtn',
      notificationHistoryEmpty: "text=No notification history"
    };
  }

  async navigateToConfigPage() {
    await this.goto(testConfig.pages.config);
    await this.waitForElement(this.selectors.scheduledDiscoveryCard);
  }

  async getPageTitle() {
    return await this.getText(this.selectors.pageTitle);
  }

  async getSubtitleText() {
    await this.waitForElement(this.selectors.subtitle);
    return await this.page.locator(this.selectors.subtitle).textContent();
  }

  async isAuthCardVisible() {
    return await this.isElementVisible(this.selectors.authCard);
  }

  async isScheduledDiscoveryCardVisible() {
    return await this.isElementVisible(this.selectors.scheduledDiscoveryCard);
  }

  async isNotificationCardVisible() {
    return await this.isElementVisible(this.selectors.notificationCard);
  }

  async isAuthenticationProfilesCardVisible() {
    return await this.isElementVisible(this.selectors.authenticationProfilesCard);
  }

  async clickNewAuthenticationProfile() {
    await this.click(this.selectors.newAuthenticationProfileBtn);
    await this.waitForElement(this.selectors.authenticationProfileDetailsDialog);
    await this.waitForElement(this.selectors.authenticationProfileForm);
    await this.page.waitForFunction(
      () => {
        const providerValue = document.querySelector('#authProfileProvider')?.value;
        const actualValues = Array.from(document.querySelectorAll('button[id^="authProfileMethodOption_"]'))
          .map(node => node.id.replace('authProfileMethodOption_', ''));
        const nameValue = document.querySelector('#authProfileName')?.value;
        const selectedProviderButtons = Array.from(document.querySelectorAll('button[id^="authProfileProviderOption_"]'))
          .filter(node => node.className.includes('MuiButton-contained'));
        return providerValue === '' &&
          nameValue === '' &&
          selectedProviderButtons.length === 0 &&
          actualValues.length === 0 &&
          document.querySelector('#saveAuthenticationProfileBtn') === null &&
          document.querySelector('[id^="authProfileField_"]') === null;
      }
    );
  }

  async selectAuthenticationProvider(value) {
    const providerButton = this.page.locator(`#authProfileProviderOption_${value}`);
    await providerButton.waitFor({ state: 'visible', timeout: 15000 });
    for (let attempt = 0; attempt < 3; attempt++) {
      await providerButton.scrollIntoViewIfNeeded();
      await providerButton.click();
      try {
        await this.page.waitForFunction(
          ({ expectedProvider, expectedValues }) => {
            const providerValue = document.querySelector('#authProfileProvider')?.value;
            const actualValues = Array.from(document.querySelectorAll('button[id^="authProfileMethodOption_"]'))
              .map(node => node.id.replace('authProfileMethodOption_', ''));
            return providerValue === expectedProvider &&
              expectedValues.length === actualValues.length &&
              expectedValues.every((value, index) => actualValues[index] === value);
          },
          { expectedProvider: value, expectedValues: this.providerMethods[value] },
          { timeout: 5000 }
        );
        break;
      } catch (error) {
        if (attempt === 2) {
          throw error;
        }
      }
    }
    await this.waitForElement(this.methodReadySelectors[this.providerMethods[value][0]]);
    await this.page.waitForLoadState('networkidle');
  }

  async selectAuthenticationMethod(value) {
    const methodButton = this.page.locator(`#authProfileMethodOption_${value}`);
    await methodButton.waitFor({ state: 'visible', timeout: 15000 });
    const className = await methodButton.getAttribute('class');
    if (className.includes('MuiButton-contained')) {
      await this.waitForElement(this.methodReadySelectors[value]);
      return;
    }
    await this.activateButtonUntil(
      methodButton,
      selector => Boolean(document.querySelector(selector)),
      this.methodReadySelectors[value]
    );
    await this.waitForElement(this.methodReadySelectors[value]);
    await this.page.waitForLoadState('networkidle');
  }

  async activateButtonUntil(button, predicate, arg) {
    for (let attempt = 0; attempt < 3; attempt++) {
      await button.scrollIntoViewIfNeeded();
      await button.focus();
      await this.page.keyboard.press('Enter');
      try {
        await this.page.waitForFunction(predicate, arg, { timeout: 5000 });
        return;
      } catch (error) {
        if (attempt === 2) {
          throw error;
        }
      }
    }
  }

  async authenticationMethodOptionValues() {
    const options = this.page.locator('button[id^="authProfileMethodOption_"]');
    await options.first().waitFor({ state: 'visible', timeout: 15000 });
    const values = await options.evaluateAll(nodes => nodes.map(node => node.id.replace('authProfileMethodOption_', '')));
    return values;
  }

  async selectAuthenticationTlsMode(value) {
    const currentValue = await this.page.locator('#authProfileField_Email_SmtpAnonymous_TlsMode').inputValue();
    if (currentValue === value) {
      return;
    }
    const combobox = this.page.locator(this.selectors.tlsModeCombobox);
    await combobox.waitFor({ state: 'visible', timeout: 15000 });
    await combobox.click();
    const option = this.page.locator(`[role="listbox"] [role="option"][data-value="${value}"]`).first();
    await option.waitFor({ state: 'visible', timeout: 15000 });
    await option.click({ force: true });
    await this.page.waitForFunction(
      ({ selectId, expectedValue }) => document.querySelector(`#${selectId}`)?.value === expectedValue,
      { selectId: 'authProfileField_Email_SmtpAnonymous_TlsMode', expectedValue: value }
    );
  }

  async fillSmtpAnonymousProfile(name, host, port) {
    await this.selectAuthenticationProvider('Email');
    await this.selectAuthenticationMethod('SmtpAnonymous');
    await this.fill(this.selectors.authProfileName, name);
    await this.fill(this.selectors.host, host);
    await this.fill(this.selectors.port, String(port));
    await this.selectAuthenticationTlsMode('None');
  }

  async fillAzureServicePrincipalSecretProfile(name, tenantId, clientId, clientSecret) {
    await this.selectAuthenticationProvider('Azure');
    await this.selectAuthenticationMethod('ServicePrincipalSecret');
    await this.fill(this.selectors.authProfileName, name);
    await this.fill(this.selectors.azureTenantId, tenantId);
    await this.fill(this.selectors.azureClientId, clientId);
    await this.fill(this.selectors.azureClientSecret, clientSecret);
  }

  async fillAwsCurrentProfile(name, profile, region) {
    await this.selectAuthenticationProvider('AWS');
    await this.selectAuthenticationMethod('CurrentProfile');
    await this.fill(this.selectors.authProfileName, name);
    await this.fill(this.selectors.awsProfile, profile);
    await this.fill(this.selectors.awsRegion, region);
  }

  async saveAuthenticationProfile() {
    await this.commitFocusedAuthInput();
    await this.waitForToastToClear('Authentication profile saved');
    const saveButton = this.page.locator(this.selectors.saveAuthenticationProfileBtn).last();
    await saveButton.waitFor({ state: 'visible', timeout: 15000 });
    await this.activateButtonUntil(
      saveButton,
      () => Array.from(document.querySelectorAll('.iziToast'))
        .some(node => (node.offsetWidth || node.offsetHeight || node.getClientRects().length) &&
          (node.textContent.includes('Authentication profile saved') || node.textContent.includes('Authentication profile save failed'))),
      null
    );
  }

  async commitFocusedAuthInput() {
    const activeAuthInputId = await this.page.evaluate(() => {
      const active = document.activeElement;
      if (!active || !active.id) return '';
      if (active.id === 'authProfileName') return active.id;
      if (active.id.startsWith('authProfileField_')) return active.id;
      return '';
    });

    if (!activeAuthInputId) {
      return;
    }

    await this.page.evaluate(() => document.activeElement.blur());
    await this.page.waitForFunction(
      id => document.activeElement?.id !== id,
      activeAuthInputId
    );
    await this.page.waitForTimeout(500);
  }

  async editAuthenticationProfile(name) {
    const row = this.page.locator('#authenticationProfilesTable tr').filter({ hasText: name }).first();
    await row.locator("button:has-text('Edit')").click();
    await this.waitForElement(this.selectors.authenticationProfileDetailsDialog);
    await this.waitForElement(this.selectors.authenticationProfileForm);
    await this.page.waitForFunction(
      ({ selector, expectedValue }) => document.querySelector(selector)?.value === expectedValue,
      { selector: this.selectors.authProfileName, expectedValue: name }
    );
  }

  async assignEmailNotifications() {
    await this.waitForToastToClear('Assignment saved');
    await this.click(this.selectors.assignEmailNotificationBtn);
  }

  async assignProviderDiscovery() {
    await this.waitForToastToClear('Assignment saved');
    await this.click(this.selectors.assignProviderDiscoveryBtn);
  }

  async removeSelectedAuthenticationProfile() {
    await this.waitForToastToClear('Assignment saved');
    await this.waitForToastToClear('Authentication profile removed');
    await this.waitForToastToClear('Remove failed');
    const removeButton = this.page.locator(this.selectors.removeAuthenticationProfileBtn).last();
    await removeButton.waitFor({ state: 'visible', timeout: 15000 });
    await this.activateButtonUntil(
      removeButton,
      () => Array.from(document.querySelectorAll('.iziToast'))
        .some(node => (node.offsetWidth || node.offsetHeight || node.getClientRects().length) &&
          (node.textContent.includes('Authentication profile removed') || node.textContent.includes('Remove failed'))),
      null
    );
  }

  async closeAuthenticationProfileDetails() {
    await this.click(this.selectors.cancelAuthenticationProfileEditBtn);
    await this.page.locator(this.selectors.authenticationProfileDetailsDialog).waitFor({ state: 'hidden', timeout: 15000 });
  }

  async waitForAuthenticationProfileRow(name) {
    await this.page.locator('#authenticationProfilesTable tr').filter({ hasText: name }).first().waitFor({ state: 'visible', timeout: 15000 });
  }

  async waitForAuthenticationProfileRowRemoved(name) {
    await this.page.locator('#authenticationProfilesTable tr').filter({ hasText: name }).first().waitFor({ state: 'hidden', timeout: 15000 });
  }

  async currentAuthenticationProfileName() {
    await this.waitForElement(this.selectors.authProfileName);
    return await this.page.locator(this.selectors.authProfileName).inputValue();
  }

  async authenticationProfileRowCount(name) {
    return await this.page.locator('#authenticationProfilesTable tr').filter({ hasText: name }).count();
  }

  async waitForToastToClear(text) {
    const toast = this.page.locator(`.iziToast:visible:has-text("${text}")`);
    if (await toast.count() > 0) {
      await toast.last().waitFor({ state: 'hidden', timeout: 8000 });
    }
  }

  async openEmailNotificationChannelPane() {
    await this.click(this.selectors.addEmailNotificationChannelBtn);
    await this.waitForElement(this.selectors.notificationFromAddress);
  }

  async openEmailNotificationChannelEditPane() {
    await this.click(this.selectors.editEmailNotificationChannelBtn);
    await this.waitForElement(this.selectors.notificationChannelDetailsDialog);
    await this.waitForElement(this.selectors.notificationCcRecipients);
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

  async fillNotificationConfig() {
    await this.fill(this.selectors.notificationFromAddress, 'ciem@example.com');
    await this.fill(this.selectors.notificationToRecipients, 'security@example.com, it@example.com');
  }

  async fillNotificationChannelDetails() {
    await this.fill(this.selectors.notificationFromAddress, 'alerts@example.com');
    await this.fill(this.selectors.notificationToRecipients, 'security@example.com');
    await this.fill(this.selectors.notificationCcRecipients, 'manager@example.com');
    await this.fill(this.selectors.notificationBccRecipients, 'audit@example.com');
  }

  async clickSaveNotifications() {
    await this.click(this.selectors.saveNotificationsBtn);
  }

  async waitForToastMessage(text) {
    return await this.waitForToast(text);
  }
}

module.exports = ConfigurationPageHelpers;
