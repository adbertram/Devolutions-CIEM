const { test, expect } = require('../../_utils/BaseTestSetup');
const ConfigurationPageHelpers = require('./ConfigurationPageHelpers');
const { runPSUCommand, runPSUQuery } = require('../../_utils/psu-helpers');
const { backupAuthenticationProfileState, restoreAuthenticationProfileState } = require('../../_utils/cleanup');

test.describe('Configuration Page', () => {
  let configPage;
  let authProfileState;

  test.beforeAll(() => {
    authProfileState = backupAuthenticationProfileState();
  });

  test.afterAll(() => {
    restoreAuthenticationProfileState(authProfileState);
  });

  test.beforeEach(async ({ ciemPage }) => {
    restoreAuthenticationProfileState(authProfileState);
    configPage = new ConfigurationPageHelpers(ciemPage);
    await configPage.navigateToConfigPage();
  });

  test.describe('when the page loads', () => {
    test('should display the Configuration title and current scope', async () => {
      const title = await configPage.getPageTitle();
      const subtitle = await configPage.getSubtitleText();

      expect(title).toContain('Configuration');
      expect(subtitle).toContain('Configure authentication profiles, scheduled discovery, and outbound notifications');
    });

    test('should display authentication profiles as a table without editor fields', async () => {
      expect(await configPage.isAuthenticationProfilesCardVisible()).toBe(true);
      await configPage.waitForElement(configPage.selectors.authenticationProfilesTable);
      await configPage.waitForElement(configPage.selectors.newAuthenticationProfileBtn);
      await expect(configPage.page.locator(configPage.selectors.authenticationProfileForm)).toHaveCount(0);
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

    test('should display available notification channel types and the channel table without editor fields', async () => {
      expect(await configPage.isNotificationCardVisible()).toBe(true);
      await configPage.waitForElement(configPage.selectors.availableNotificationTypes);
      await configPage.waitForElement(configPage.selectors.addEmailNotificationChannelBtn);
      await configPage.waitForElement(configPage.selectors.notificationChannelsTable);
      await configPage.waitForElement(configPage.selectors.editEmailNotificationChannelBtn);
      await expect(configPage.page.locator(configPage.selectors.notificationFromAddress)).toHaveCount(0);
      await expect(configPage.page.locator(configPage.selectors.notificationToRecipients)).toHaveCount(0);
      await expect(configPage.page.locator(configPage.selectors.saveNotificationsBtn)).toHaveCount(0);
      await expect(configPage.page.locator('#notificationAuthMethod')).toHaveCount(0);
      await expect(configPage.page.locator('#notificationSmtpHost')).toHaveCount(0);
      await expect(configPage.page.locator('#notificationSmtpPassword')).toHaveCount(0);
    });
  });

  test.describe('when managing authentication profiles', () => {
    test('should open a new profile modal with no provider selected', async () => {
      await configPage.clickNewAuthenticationProfile();

      await expect(configPage.page.locator('#authProfileProviderOption_Azure')).toHaveClass(/MuiButton-outlined/);
      await expect(configPage.page.locator('#authProfileProviderOption_AWS')).toHaveClass(/MuiButton-outlined/);
      await expect(configPage.page.locator('#authProfileProviderOption_Email')).toHaveClass(/MuiButton-outlined/);
      expect(await configPage.page.locator('button[id^="authProfileMethodOption_"]').count()).toBe(0);
      expect(await configPage.page.locator('[id^="authProfileField_"]').count()).toBe(0);
      expect(await configPage.page.locator(configPage.selectors.saveAuthenticationProfileBtn).count()).toBe(0);
    });

    test('should move the selected Provider button styling away from Azure', async () => {
      await configPage.clickNewAuthenticationProfile();
      await expect(configPage.page.locator('#authProfileProviderOption_Azure')).toHaveClass(/MuiButton-outlined/);

      await configPage.selectAuthenticationProvider('Email');

      await expect(configPage.page.locator('#authProfileProviderOption_Azure')).toHaveClass(/MuiButton-outlined/);
      await expect(configPage.page.locator('#authProfileProviderOption_Email')).toHaveClass(/MuiButton-contained/);
    });

    test('should show only the selected provider schema and provider-scoped method options', async () => {
      await configPage.clickNewAuthenticationProfile();

      await configPage.selectAuthenticationProvider('Email');
      const emailMethods = await configPage.authenticationMethodOptionValues();
      expect(emailMethods).toEqual(['SmtpAnonymous', 'SmtpBasic']);
      await configPage.selectAuthenticationMethod('SmtpAnonymous');
      await configPage.waitForElement(configPage.selectors.host);
      expect(await configPage.page.locator(configPage.selectors.awsRegion).count()).toBe(0);
      expect(await configPage.page.locator(configPage.selectors.azureClientId).count()).toBe(0);

      await configPage.selectAuthenticationProvider('AWS');
      const awsMethods = await configPage.authenticationMethodOptionValues();
      expect(awsMethods).toEqual(['CurrentProfile', 'AccessKey']);
      await configPage.selectAuthenticationMethod('CurrentProfile');
      await configPage.waitForElement(configPage.selectors.awsRegion);
      expect(await configPage.page.locator(configPage.selectors.host).count()).toBe(0);
    });

    test('should create, edit, and remove an unassigned profile from the table and modal', async () => {
      await configPage.clickNewAuthenticationProfile();
      await configPage.fillSmtpAnonymousProfile('E2E SMTP Relay', 'smtp-relay.example.com', 25);
      await configPage.saveAuthenticationProfile();
      await configPage.waitForToastMessage('Authentication profile saved');
      await expect(configPage.page.locator(configPage.selectors.authenticationProfileDetailsDialog)).toHaveCount(0);
      await configPage.waitForAuthenticationProfileRow('E2E SMTP Relay');

      await configPage.editAuthenticationProfile('E2E SMTP Relay');
      await configPage.fill(configPage.selectors.host, 'smtp-relay-updated.example.com');
      await configPage.saveAuthenticationProfile();
      await configPage.waitForToastMessage('Authentication profile saved');
      await expect(configPage.page.locator(configPage.selectors.authenticationProfileDetailsDialog)).toHaveCount(0);
      await configPage.waitForAuthenticationProfileRow('E2E SMTP Relay');

      const updated = await runPSUQuery(`
$profile = Devolutions.CIEM\\Get-CIEMAuthenticationProfile | Where-Object Name -eq 'E2E SMTP Relay' | Select-Object -First 1
[pscustomobject]@{ Host = $profile.Settings.Host } | ConvertTo-Json -Compress
`);
      expect(updated.Host).toBe('smtp-relay-updated.example.com');

      await configPage.editAuthenticationProfile('E2E SMTP Relay');
      await configPage.removeSelectedAuthenticationProfile();
      await configPage.waitForToastMessage('Authentication profile removed');
      await configPage.waitForAuthenticationProfileRowRemoved('E2E SMTP Relay');
      expect(await configPage.authenticationProfileRowCount('E2E SMTP Relay')).toBe(0);
    });

    test('should edit the selected profile from a multi-profile table', async () => {
      const seed = await runPSUCommand(`
$first = Devolutions.CIEM\\Save-CIEMAuthenticationProfile -Name 'E2E Alpha SMTP' -Provider 'Email' -Method 'SmtpAnonymous' -Settings @{ Host = 'alpha.example.com'; Port = 25; TlsMode = 'None' } -SecretRefs @{}
$second = Devolutions.CIEM\\Save-CIEMAuthenticationProfile -Name 'E2E Zulu SMTP' -Provider 'Email' -Method 'SmtpAnonymous' -Settings @{ Host = 'zulu.example.com'; Port = 25; TlsMode = 'None' } -SecretRefs @{}
[pscustomobject]@{ First = $first.Id; Second = $second.Id } | ConvertTo-Json -Compress
`);
      expect(seed.status).toBe('Completed');
      await configPage.navigateToConfigPage();
      await configPage.waitForAuthenticationProfileRow('E2E Alpha SMTP');
      await configPage.waitForAuthenticationProfileRow('E2E Zulu SMTP');

      await configPage.editAuthenticationProfile('E2E Alpha SMTP');

      expect(await configPage.currentAuthenticationProfileName()).toBe('E2E Alpha SMTP');
    });

    test('should assign an Email profile to Email notifications and block removal while assigned', async () => {
      await configPage.clickNewAuthenticationProfile();
      await configPage.fillSmtpAnonymousProfile('E2E Assigned SMTP Relay', 'smtp-assigned.example.com', 25);
      await configPage.saveAuthenticationProfile();
      await configPage.waitForToastMessage('Authentication profile saved');
      await configPage.waitForAuthenticationProfileRow('E2E Assigned SMTP Relay');

      await configPage.editAuthenticationProfile('E2E Assigned SMTP Relay');
      await configPage.assignEmailNotifications();
      await configPage.waitForToastMessage('Assignment saved');
      await configPage.closeAuthenticationProfileDetails();
      await configPage.waitForAuthenticationProfileRow('E2E Assigned SMTP Relay');
      await configPage.editAuthenticationProfile('E2E Assigned SMTP Relay');
      await configPage.removeSelectedAuthenticationProfile();
      await configPage.waitForToastMessage('Remove failed');

      const assignment = await runPSUCommand(`
$assignment = Devolutions.CIEM\\Get-CIEMAuthenticationProfileAssignment -UsageType 'NotificationChannel' -UsageId 'email-default'
$profile = Devolutions.CIEM\\Get-CIEMAuthenticationProfile -Id $assignment.AuthenticationProfileId
[pscustomobject]@{
  UsageType = $assignment.UsageType
  UsageId = $assignment.UsageId
  Provider = $profile.Provider
} | ConvertTo-Json -Compress
`);
      expect(assignment.status).toBe('Completed');
      const saved = JSON.parse(assignment.output[0].message);
      expect(saved.UsageType).toBe('NotificationChannel');
      expect(saved.UsageId).toBe('email-default');
      expect(saved.Provider).toBe('Email');
    });

    test('should show Test Authentication for a selected Azure profile', async () => {
      const seed = await runPSUCommand(`
Devolutions.CIEM\\Set-CIEMSecret -Name 'CIEM_E2E_Azure_ClientSecret' -Value 'e2e-client-secret'
Devolutions.CIEM\\Save-CIEMAuthenticationProfile -Name 'E2E Azure Testable Profile' -Provider 'Azure' -Method 'ServicePrincipalSecret' -Settings @{ TenantId = '11111111-1111-1111-1111-111111111111'; ClientId = '22222222-2222-2222-2222-222222222222' } -SecretRefs @{ ClientSecret = 'CIEM_E2E_Azure_ClientSecret' } | Out-Null
`);
      expect(seed.status).toBe('Completed');
      await configPage.navigateToConfigPage();
      await configPage.waitForAuthenticationProfileRow('E2E Azure Testable Profile');
      await configPage.editAuthenticationProfile('E2E Azure Testable Profile');

      await configPage.waitForElement(configPage.selectors.testAuthenticationProfileBtn);
      await expect(configPage.page.locator(configPage.selectors.testAuthenticationProfileBtn)).toHaveText('Test Authentication');
      const testAuthBox = await configPage.page.locator(configPage.selectors.testAuthenticationProfileBtn).boundingBox();
      const assignmentsBox = await configPage.page.locator(configPage.selectors.authenticationProfileDetailsDialog)
        .getByRole('heading', { name: 'Assignments' })
        .boundingBox();
      expect(testAuthBox.y).toBeLessThan(assignmentsBox.y);
    });

    test('should assign an Azure profile to provider discovery', async () => {
      const seed = await runPSUCommand(`
Devolutions.CIEM\\Set-CIEMSecret -Name 'CIEM_E2E_Azure_ClientSecret' -Value 'e2e-client-secret'
Devolutions.CIEM\\Save-CIEMAuthenticationProfile -Name 'E2E Azure Service Principal' -Provider 'Azure' -Method 'ServicePrincipalSecret' -Settings @{ TenantId = '11111111-1111-1111-1111-111111111111'; ClientId = '22222222-2222-2222-2222-222222222222' } -SecretRefs @{ ClientSecret = 'CIEM_E2E_Azure_ClientSecret' } | Out-Null
`);
      expect(seed.status).toBe('Completed');
      await configPage.navigateToConfigPage();
      await configPage.waitForAuthenticationProfileRow('E2E Azure Service Principal');
      await configPage.editAuthenticationProfile('E2E Azure Service Principal');

      await configPage.assignProviderDiscovery();
      await configPage.waitForToastMessage('Assignment saved');

      const assignment = await runPSUCommand(`
$assignment = Devolutions.CIEM\\Get-CIEMAuthenticationProfileAssignment -UsageType 'ProviderDiscovery' -UsageId 'Azure'
$profile = Devolutions.CIEM\\Get-CIEMAuthenticationProfile -Id $assignment.AuthenticationProfileId
[pscustomobject]@{
  UsageType = $assignment.UsageType
  UsageId = $assignment.UsageId
  Provider = $profile.Provider
  Method = $profile.Method
} | ConvertTo-Json -Compress
`);
      expect(assignment.status).toBe('Completed');
      const saved = JSON.parse(assignment.output[0].message);
      expect(saved.UsageType).toBe('ProviderDiscovery');
      expect(saved.UsageId).toBe('Azure');
      expect(saved.Provider).toBe('Azure');
      expect(saved.Method).toBe('ServicePrincipalSecret');
    });

    test('should assign an AWS profile to provider discovery', async () => {
      await configPage.clickNewAuthenticationProfile();
      await configPage.fillAwsCurrentProfile('E2E AWS Current Profile', 'ciem-e2e', 'us-east-1');
      await configPage.saveAuthenticationProfile();
      await configPage.waitForToastMessage('Authentication profile saved');
      await configPage.waitForAuthenticationProfileRow('E2E AWS Current Profile');

      await configPage.editAuthenticationProfile('E2E AWS Current Profile');
      await configPage.assignProviderDiscovery();
      await configPage.waitForToastMessage('Assignment saved');

      const assignment = await runPSUCommand(`
$assignment = Devolutions.CIEM\\Get-CIEMAuthenticationProfileAssignment -UsageType 'ProviderDiscovery' -UsageId 'AWS'
$profile = Devolutions.CIEM\\Get-CIEMAuthenticationProfile -Id $assignment.AuthenticationProfileId
[pscustomobject]@{
  UsageType = $assignment.UsageType
  UsageId = $assignment.UsageId
  Provider = $profile.Provider
  Method = $profile.Method
} | ConvertTo-Json -Compress
`);
      expect(assignment.status).toBe('Completed');
      const saved = JSON.parse(assignment.output[0].message);
      expect(saved.UsageType).toBe('ProviderDiscovery');
      expect(saved.UsageId).toBe('AWS');
      expect(saved.Provider).toBe('AWS');
      expect(saved.Method).toBe('CurrentProfile');
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
    test('should save channel routing without touching authentication profiles or notification rules', async () => {
      const resetNotification = await runPSUCommand(`
$textTemplate = "{{Title}}\`n{{Evidence}}"
Devolutions.CIEM\\Set-CIEMNotification -Enabled $true -AutoSendScope 'ScheduledDiscovery' -ChangeTypes @('NewRisk', 'RiskIncrease', 'RemovedRisk') -MinimumSeverity 'Critical' -SubjectTemplate '[CIEM] {{Severity}} {{Title}}' -TextBodyTemplate $textTemplate -HtmlBodyTemplate '<p><strong>{{Severity}}</strong> {{Title}}</p><p>{{Evidence}}</p>' | Out-Null
`);
      expect(resetNotification.status).toBe('Completed');
      await configPage.navigateToConfigPage();

      await configPage.openEmailNotificationChannelPane();
      await configPage.fillNotificationConfig();
      await configPage.clickSaveNotifications();

      const toast = await configPage.waitForToastMessage('Notifications saved');
      await expect(toast).toContainText('Notifications saved');
      await expect(configPage.page.locator(configPage.selectors.notificationChannelDetailsDialog)).toHaveCount(0);
      await expect(configPage.page.locator(configPage.selectors.notificationFromAddress)).toHaveCount(0);
      await configPage.waitForElement(configPage.selectors.notificationChannelsTable);

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

    test('should edit every Email channel attribute from the table row action', async () => {
      const resetChannel = await runPSUCommand(`
Devolutions.CIEM\\Set-CIEMNotificationChannel -Enabled $true -FromAddress 'existing@example.com' -ToRecipients @('existing-to@example.com') -CcRecipients @('existing-cc@example.com') -BccRecipients @('existing-bcc@example.com') | Out-Null
`);
      expect(resetChannel.status).toBe('Completed');
      await configPage.navigateToConfigPage();

      await configPage.openEmailNotificationChannelEditPane();
      await configPage.fillNotificationChannelDetails();
      await configPage.clickSaveNotifications();

      const toast = await configPage.waitForToastMessage('Notifications saved');
      await expect(toast).toContainText('Notifications saved');
      await expect(configPage.page.locator(configPage.selectors.notificationFromAddress)).toHaveCount(0);

      const result = await runPSUCommand(`
$channel = Devolutions.CIEM\\Get-CIEMNotificationChannel -Id 'email-default'
[pscustomobject]@{
  Enabled = $channel.Enabled
  FromAddress = $channel.FromAddress
  ToRecipients = $channel.ToRecipients
  CcRecipients = $channel.CcRecipients
  BccRecipients = $channel.BccRecipients
} | ConvertTo-Json -Depth 5 -Compress
`);
      expect(result.status).toBe('Completed');
      const saved = JSON.parse(result.output[0].message);
      expect(saved.Enabled).toBe(true);
      expect(saved.FromAddress).toBe('alerts@example.com');
      expect(saved.ToRecipients).toContain('security@example.com');
      expect(saved.CcRecipients).toContain('manager@example.com');
      expect(saved.BccRecipients).toContain('audit@example.com');
    });
  });
});
