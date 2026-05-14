const BasePage = require('../../_utils/BasePage');
const { testConfig } = require('../../_utils/test-config');

class AuthenticationProfilesPageHelpers extends BasePage {
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
      pageTitle: "h4:has-text('Authentication Profiles')",
      listPane: '#authProfileListPane',
      detailsPane: '#authProfileDetailsPane',
      search: '#authProfileSearch',
      newButton: '#newAuthenticationProfileBtn',
      form: '#authenticationProfileForm',
      name: '#authProfileName',
      providerCombobox: '#authProfileProviderOption_Azure',
      methodCombobox: '#authProfileMethodOption_ServicePrincipalSecret',
      azureTenantId: '#authProfileField_Azure_ServicePrincipalSecret_TenantId',
      azureClientId: '#authProfileField_Azure_ServicePrincipalSecret_ClientId',
      azureClientSecret: '#authProfileField_Azure_ServicePrincipalSecret_ClientSecret',
      host: '#authProfileField_Email_SmtpAnonymous_Host',
      port: '#authProfileField_Email_SmtpAnonymous_Port',
      managedIdentityClientId: '#authProfileField_Azure_ManagedIdentity_ManagedIdentityClientId',
      awsProfile: '#authProfileField_AWS_CurrentProfile_Profile',
      awsRegion: '#authProfileField_AWS_CurrentProfile_Region',
      tlsModeCombobox: '[role="combobox"][aria-labelledby="authProfileField_Email_SmtpAnonymous_TlsModelabel"]',
      saveButton: '#saveAuthenticationProfileBtn',
      assignProviderButton: '#assignProviderDiscoveryBtn',
      assignEmailButton: '#assignEmailNotificationBtn',
      removeButton: '#removeAuthenticationProfileBtn'
    };
  }

  async navigateToAuthenticationProfilesPage() {
    await this.goto(testConfig.pages.authenticationProfiles);
    await this.waitForElement(this.selectors.pageTitle);
  }

  async clickNewProfile() {
    await this.click(this.selectors.newButton);
    await this.waitForElement(this.selectors.form);
    await this.page.waitForFunction(
      expectedValues => {
        const providerValue = document.querySelector('#authProfileProvider')?.value;
        const actualValues = Array.from(document.querySelectorAll('button[id^="authProfileMethodOption_"]'))
          .map(node => node.id.replace('authProfileMethodOption_', ''));
        const defaultField = document.querySelector('#authProfileField_Azure_ServicePrincipalSecret_TenantId');
        return providerValue === 'Azure' &&
          Boolean(defaultField) &&
          expectedValues.length === actualValues.length &&
          expectedValues.every((value, index) => actualValues[index] === value);
      },
      this.providerMethods.Azure
    );
  }

  async selectProvider(value) {
    const providerButton = this.page.locator(`#authProfileProviderOption_${value}`);
    await providerButton.waitFor({ state: 'visible', timeout: 15000 });
    await this.activateButtonUntil(
      providerButton,
      expectedValues => {
        const actualValues = Array.from(document.querySelectorAll('button[id^="authProfileMethodOption_"]'))
          .map(node => node.id.replace('authProfileMethodOption_', ''));
        return expectedValues.length === actualValues.length && expectedValues.every((value, index) => actualValues[index] === value);
      },
      this.providerMethods[value]
    );
    await this.waitForElement(this.methodReadySelectors[this.providerMethods[value][0]]);
    await this.page.waitForLoadState('networkidle');
  }

  async selectMethod(value) {
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

  async methodOptionValues() {
    const options = this.page.locator('button[id^="authProfileMethodOption_"]');
    await options.first().waitFor({ state: 'visible', timeout: 15000 });
    const values = await options.evaluateAll(nodes => nodes.map(node => node.id.replace('authProfileMethodOption_', '')));
    return values;
  }

  async selectTlsMode(value) {
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
    await this.selectProvider('Email');
    await this.selectMethod('SmtpAnonymous');
    await this.fill(this.selectors.name, name);
    await this.fill(this.selectors.host, host);
    await this.fill(this.selectors.port, String(port));
    await this.selectTlsMode('None');
  }

  async fillAzureServicePrincipalSecretProfile(name, tenantId, clientId, clientSecret) {
    await this.fill(this.selectors.name, name);
    await this.fill(this.selectors.azureTenantId, tenantId);
    await this.fill(this.selectors.azureClientId, clientId);
    await this.fill(this.selectors.azureClientSecret, clientSecret);
  }

  async fillAwsCurrentProfile(name, profile, region) {
    await this.selectProvider('AWS');
    await this.selectMethod('CurrentProfile');
    await this.fill(this.selectors.name, name);
    await this.fill(this.selectors.awsProfile, profile);
    await this.fill(this.selectors.awsRegion, region);
  }

  async saveProfile() {
    await this.commitFocusedAuthInput();
    await this.waitForToastToClear('Authentication profile saved');
    const saveButton = this.page.locator(this.selectors.saveButton).last();
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

  async editProfile(name) {
    const card = this.page.locator('.MuiCard-root').filter({ hasText: name }).first();
    await card.locator("button:has-text('Edit')").click();
    await this.waitForElement(this.selectors.form);
    await this.page.waitForFunction(
      ({ selector, expectedValue }) => document.querySelector(selector)?.value === expectedValue,
      { selector: this.selectors.name, expectedValue: name }
    );
  }

  async assignEmailNotifications() {
    await this.waitForToastToClear('Assignment saved');
    await this.click(this.selectors.assignEmailButton);
  }

  async assignProviderDiscovery() {
    await this.waitForToastToClear('Assignment saved');
    await this.click(this.selectors.assignProviderButton);
  }

  async removeSelectedProfile() {
    await this.waitForToastToClear('Assignment saved');
    await this.waitForToastToClear('Authentication profile removed');
    await this.waitForToastToClear('Remove failed');
    const removeButton = this.page.locator(this.selectors.removeButton).last();
    await removeButton.waitFor({ state: 'visible', timeout: 15000 });
    await removeButton.scrollIntoViewIfNeeded();
    await removeButton.click();
  }

  async waitForProfileCard(name) {
    await this.page.locator('#authProfileListPane .MuiCard-root').filter({ hasText: name }).first().waitFor({ state: 'visible', timeout: 15000 });
  }

  async waitForProfileCardRemoved(name) {
    await this.page.locator('#authProfileListPane .MuiCard-root').filter({ hasText: name }).first().waitFor({ state: 'hidden', timeout: 15000 });
  }

  async currentProfileName() {
    await this.waitForElement(this.selectors.name);
    return await this.page.locator(this.selectors.name).inputValue();
  }

  async profileCardCount(name) {
    return await this.page.locator('#authProfileListPane .MuiCard-root').filter({ hasText: name }).count();
  }

  async waitForToastMessage(text) {
    const toast = this.page.locator(`.iziToast:visible:has-text("${text}")`).last();
    await toast.waitFor({ state: 'visible', timeout: 15000 });
    return toast;
  }

  async waitForToastToClear(text) {
    const toast = this.page.locator(`.iziToast:visible:has-text("${text}")`);
    if (await toast.count() > 0) {
      await toast.last().waitFor({ state: 'hidden', timeout: 8000 });
    }
  }
}

module.exports = AuthenticationProfilesPageHelpers;
