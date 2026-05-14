const { test, expect } = require('../../_utils/BaseTestSetup');
const ConfigurationPageHelpers = require('./ConfigurationPageHelpers');
const { runPSUCommand } = require('../../_utils/psu-helpers');

test.describe('Configuration Page', () => {
  let configPage;

  test.beforeEach(async ({ ciemPage }) => {
    configPage = new ConfigurationPageHelpers(ciemPage);
    await configPage.navigateToConfigPage();
  });

  test.describe('when the page loads', () => {
    test('should display the Configuration title and current scope', async () => {
      const title = await configPage.getPageTitle();
      const subtitle = await configPage.getSubtitleText();

      expect(title).toContain('Configuration');
      expect(subtitle).toContain('Configure scheduled discovery and outbound notifications');
    });

    test('should not display authentication management controls', async () => {
      expect(await configPage.isAuthCardVisible()).toBe(false);
      await expect(configPage.page.locator(configPage.selectors.authMethodCombobox)).toHaveCount(0);
      await expect(configPage.page.locator(configPage.selectors.cloudProviderCombobox)).toHaveCount(0);
      await expect(configPage.page.locator(configPage.selectors.testAuthBtn)).toHaveCount(0);
      await expect(configPage.page.locator(configPage.selectors.getPermissionsBtn)).toHaveCount(0);
    });

    test('should display scheduled discovery controls', async () => {
      expect(await configPage.isScheduledDiscoveryCardVisible()).toBe(true);
      await configPage.waitForElement(configPage.selectors.scheduledDiscoveryCadenceCombobox);
      await configPage.waitForElement(configPage.selectors.scheduledDiscoveryScopeCombobox);
      await configPage.waitForElement(configPage.selectors.saveAzureDiscoveryScheduleBtn);
    });

    test('should display notification channel controls without SMTP auth settings', async () => {
      expect(await configPage.isNotificationCardVisible()).toBe(true);
      await configPage.waitForElement(configPage.selectors.notificationFromAddress);
      await configPage.waitForElement(configPage.selectors.notificationToRecipients);
      await configPage.waitForElement(configPage.selectors.saveNotificationsBtn);
      await expect(configPage.page.locator('#notificationAuthMethod')).toHaveCount(0);
      await expect(configPage.page.locator('#notificationSmtpHost')).toHaveCount(0);
      await expect(configPage.page.locator('#notificationSmtpPassword')).toHaveCount(0);
    });
  });

  test.describe('when configuring scheduled discovery', () => {
    test.beforeEach(async () => {
      const resetSchedule = await runPSUCommand("Devolutions.CIEM\\Set-CIEMAzureDiscoverySchedule -Scope 'All' -Cron '0 2 * * *' -Enabled $false | Out-Null");
      expect(resetSchedule.status).toBe('Completed');
      await configPage.navigateToConfigPage();
    });

    test('should allow selecting scheduled discovery cadence and scope without running discovery', async () => {
      await configPage.selectScheduleCadence('weekly');
      await configPage.selectScheduleScope('ARM');

      expect(await configPage.getSelectedScheduleCadence()).toBe('weekly');
      expect(await configPage.getSelectedScheduleScope()).toBe('ARM');
    });
  });

  test.describe('when configuring notification channels', () => {
    test('should save channel routing and notification template without touching authentication profiles', async () => {
      await configPage.fillNotificationConfig();
      await configPage.clickSaveNotifications();

      const toast = await configPage.waitForToastMessage('Notifications saved');
      await expect(toast).toContainText('Notifications saved');

      const result = await runPSUCommand(`
$channel = Devolutions.CIEM\\Get-CIEMNotificationChannel -Id 'email-default'
$notification = Devolutions.CIEM\\Get-CIEMNotification -Id 'exposure-change-default'
[pscustomobject]@{
  HasAuthenticationProfileId = $null -ne $channel.PSObject.Properties['AuthenticationProfileId']
  FromAddress = $channel.FromAddress
  ToRecipients = $channel.ToRecipients
  AutoSendScope = $notification.AutoSendScope
  MinimumSeverity = $notification.MinimumSeverity
} | ConvertTo-Json -Depth 5 -Compress
`);
      expect(result.status).toBe('Completed');
      const saved = JSON.parse(result.output[0].message);
      expect(saved.HasAuthenticationProfileId).toBe(false);
      expect(saved.FromAddress).toBe('ciem@example.com');
      expect(saved.ToRecipients).toContain('security@example.com');
      expect(saved.AutoSendScope).toBe('ScheduledDiscovery');
      expect(saved.MinimumSeverity).toBe('Critical');
    });
  });
});
