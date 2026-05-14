const BasePage = require('../../_utils/BasePage');
const { testConfig } = require('../../_utils/test-config');

class ConfigurationPageHelpers extends BasePage {
  constructor(page) {
    super(page);
    this.selectors = {
      pageTitle: "h4:has-text('Configuration')",
      subtitle: "text=Configure scheduled discovery and outbound notifications",
      authCard: ".MuiCard-root:has-text('Cloud Provider Authentication')",
      authMethodCombobox: '[role="combobox"][aria-labelledby="authMethodlabel"]',
      cloudProviderCombobox: '[role="combobox"][aria-labelledby="cloudProviderlabel"]',
      testAuthBtn: '#testAuthBtn',
      getPermissionsBtn: "button:has-text('Get Required Permissions')",
      scheduledDiscoveryCard: '#scheduledDiscoveryWrapper .MuiCard-root',
      scheduledDiscoveryCadenceCombobox: '[role="combobox"][aria-labelledby="azureDiscoveryScheduleCadencelabel"]',
      scheduledDiscoveryScopeCombobox: '[role="combobox"][aria-labelledby="azureDiscoveryScheduleScopelabel"]',
      saveAzureDiscoveryScheduleBtn: '#saveAzureDiscoveryScheduleBtn',
      notificationCard: ".MuiCard-root:has-text('Notification Channels')",
      notificationFromAddress: '#notificationFromAddress',
      notificationToRecipients: '#notificationToRecipients',
      notificationSubjectTemplate: '#notificationSubjectTemplate',
      notificationTextBodyTemplate: '#notificationTextBodyTemplate',
      notificationHtmlBodyTemplate: '#notificationHtmlBodyTemplate',
      notificationAutoSendScopeCombobox: '[role="combobox"][aria-labelledby="notificationAutoSendScopelabel"]',
      notificationMinimumSeverityCombobox: '[role="combobox"][aria-labelledby="notificationMinimumSeveritylabel"]',
      saveNotificationsBtn: '#saveNotificationsBtn',
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

  async selectNotificationAutoSendScope(value) {
    await this.selectMUIOption('notificationAutoSendScope', value);
    await this.page.waitForFunction(
      ({ selectId, expectedValue }) => document.querySelector(`#${selectId}`)?.value === expectedValue,
      { selectId: 'notificationAutoSendScope', expectedValue: value }
    );
  }

  async selectNotificationMinimumSeverity(value) {
    await this.selectMUIOption('notificationMinimumSeverity', value);
    await this.page.waitForFunction(
      ({ selectId, expectedValue }) => document.querySelector(`#${selectId}`)?.value === expectedValue,
      { selectId: 'notificationMinimumSeverity', expectedValue: value }
    );
  }

  async fillNotificationConfig() {
    await this.fill(this.selectors.notificationFromAddress, 'ciem@example.com');
    await this.fill(this.selectors.notificationToRecipients, 'security@example.com, it@example.com');
    await this.selectNotificationAutoSendScope('ScheduledDiscovery');
    await this.selectNotificationMinimumSeverity('Critical');
    await this.fill(this.selectors.notificationSubjectTemplate, '[CIEM] {{Severity}} {{Title}}');
    await this.fill(this.selectors.notificationTextBodyTemplate, 'Text {{Title}} {{Evidence}}');
    await this.fill(this.selectors.notificationHtmlBodyTemplate, '<p>{{Title}} {{Evidence}}</p>');
  }

  async clickSaveNotifications() {
    await this.click(this.selectors.saveNotificationsBtn);
  }

  async waitForToastMessage(text) {
    return await this.waitForToast(text);
  }
}

module.exports = ConfigurationPageHelpers;
