const { test, expect } = require('../../_utils/BaseTestSetup');
const AuthenticationProfilesPageHelpers = require('./AuthenticationProfilesPageHelpers');
const { runPSUCommand, runPSUQuery } = require('../../_utils/psu-helpers');
const { backupAuthenticationProfileState, restoreAuthenticationProfileState } = require('../../_utils/cleanup');

test.describe('Authentication Profiles Page', () => {
  let authPage;
  let authProfileState;

  test.beforeAll(() => {
    authProfileState = backupAuthenticationProfileState();
  });

  test.afterAll(() => {
    restoreAuthenticationProfileState(authProfileState);
  });

  test.beforeEach(async ({ ciemPage }) => {
    restoreAuthenticationProfileState(authProfileState);
    authPage = new AuthenticationProfilesPageHelpers(ciemPage);
    await authPage.navigateToAuthenticationProfilesPage();
  });

  test.describe('when the page loads', () => {
    test('should render the split profile list and details panes', async () => {
      await authPage.waitForElement(authPage.selectors.listPane);
      await authPage.waitForElement(authPage.selectors.detailsPane);
      await authPage.waitForElement(authPage.selectors.providerCombobox);
      await authPage.waitForElement(authPage.selectors.methodCombobox);
    });
  });

  test.describe('when managing Email profiles', () => {
    test('should move the selected Provider button styling away from Azure', async () => {
      await authPage.clickNewProfile();
      await expect(authPage.page.locator('#authProfileProviderOption_Azure')).toHaveClass(/MuiButton-contained/);

      await authPage.selectProvider('Email');

      await expect(authPage.page.locator('#authProfileProviderOption_Azure')).toHaveClass(/MuiButton-outlined/);
      await expect(authPage.page.locator('#authProfileProviderOption_Email')).toHaveClass(/MuiButton-contained/);
    });

    test('should show only the selected provider schema and provider-scoped method options', async () => {
      await authPage.clickNewProfile();

      await authPage.selectProvider('Email');
      const emailMethods = await authPage.methodOptionValues();
      expect(emailMethods).toEqual(['SmtpAnonymous', 'SmtpBasic']);
      await authPage.selectMethod('SmtpAnonymous');
      await authPage.waitForElement(authPage.selectors.host);
      expect(await authPage.page.locator(authPage.selectors.awsRegion).count()).toBe(0);
      expect(await authPage.page.locator(authPage.selectors.azureClientId).count()).toBe(0);

      await authPage.selectProvider('AWS');
      const awsMethods = await authPage.methodOptionValues();
      expect(awsMethods).toEqual(['CurrentProfile', 'AccessKey']);
      await authPage.selectMethod('CurrentProfile');
      await authPage.waitForElement(authPage.selectors.awsRegion);
      expect(await authPage.page.locator(authPage.selectors.host).count()).toBe(0);
    });

    test('should create, edit, and remove an unassigned profile', async () => {
      await authPage.clickNewProfile();
      await authPage.fillSmtpAnonymousProfile('E2E SMTP Relay', 'smtp-relay.example.com', 25);
      await authPage.saveProfile();
      await authPage.waitForToastMessage('Authentication profile saved');
      await authPage.waitForProfileCard('E2E SMTP Relay');

      await authPage.editProfile('E2E SMTP Relay');
      await authPage.fill(authPage.selectors.host, 'smtp-relay-updated.example.com');
      await authPage.saveProfile();
      await authPage.waitForToastMessage('Authentication profile saved');
      await authPage.waitForProfileCard('E2E SMTP Relay');

      const updated = await runPSUQuery(`
$profile = Devolutions.CIEM\\Get-CIEMAuthenticationProfile | Where-Object Name -eq 'E2E SMTP Relay' | Select-Object -First 1
[pscustomobject]@{ Host = $profile.Settings.Host } | ConvertTo-Json -Compress
`);
      expect(updated.Host).toBe('smtp-relay-updated.example.com');

      await authPage.removeSelectedProfile();
      await authPage.waitForToastMessage('Authentication profile removed');
      await authPage.waitForProfileCardRemoved('E2E SMTP Relay');
      expect(await authPage.profileCardCount('E2E SMTP Relay')).toBe(0);
    });

    test('should edit the selected profile from a multi-profile list', async () => {
      const seed = await runPSUCommand(`
$first = Devolutions.CIEM\\Save-CIEMAuthenticationProfile -Name 'E2E Alpha SMTP' -Provider 'Email' -Method 'SmtpAnonymous' -Settings @{ Host = 'alpha.example.com'; Port = 25; TlsMode = 'None' } -SecretRefs @{}
$second = Devolutions.CIEM\\Save-CIEMAuthenticationProfile -Name 'E2E Zulu SMTP' -Provider 'Email' -Method 'SmtpAnonymous' -Settings @{ Host = 'zulu.example.com'; Port = 25; TlsMode = 'None' } -SecretRefs @{}
[pscustomobject]@{ First = $first.Id; Second = $second.Id } | ConvertTo-Json -Compress
`);
      expect(seed.status).toBe('Completed');
      await authPage.navigateToAuthenticationProfilesPage();
      await authPage.waitForProfileCard('E2E Alpha SMTP');
      await authPage.waitForProfileCard('E2E Zulu SMTP');

      await authPage.editProfile('E2E Alpha SMTP');

      expect(await authPage.currentProfileName()).toBe('E2E Alpha SMTP');
    });

    test('should assign an Email profile to Email notifications and block removal while assigned', async () => {
      await authPage.clickNewProfile();
      await authPage.fillSmtpAnonymousProfile('E2E Assigned SMTP Relay', 'smtp-assigned.example.com', 25);
      await authPage.saveProfile();
      await authPage.waitForToastMessage('Authentication profile saved');
      await authPage.waitForProfileCard('E2E Assigned SMTP Relay');

      await authPage.assignEmailNotifications();
      await authPage.waitForToastMessage('Assignment saved');
      await authPage.removeSelectedProfile();
      await authPage.waitForToastMessage('Remove failed');

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
  });

  test.describe('when assigning provider discovery profiles', () => {
    test('should assign an Azure profile to provider discovery', async () => {
      const seed = await runPSUCommand(`
Devolutions.CIEM\\Set-CIEMSecret -Name 'CIEM_E2E_Azure_ClientSecret' -Value 'e2e-client-secret'
Devolutions.CIEM\\Save-CIEMAuthenticationProfile -Name 'E2E Azure Service Principal' -Provider 'Azure' -Method 'ServicePrincipalSecret' -Settings @{ TenantId = '11111111-1111-1111-1111-111111111111'; ClientId = '22222222-2222-2222-2222-222222222222' } -SecretRefs @{ ClientSecret = 'CIEM_E2E_Azure_ClientSecret' } | Out-Null
`);
      expect(seed.status).toBe('Completed');
      await authPage.navigateToAuthenticationProfilesPage();
      await authPage.waitForProfileCard('E2E Azure Service Principal');
      await authPage.editProfile('E2E Azure Service Principal');

      await authPage.assignProviderDiscovery();
      await authPage.waitForToastMessage('Assignment saved');

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
      await authPage.clickNewProfile();
      await authPage.fillAwsCurrentProfile('E2E AWS Current Profile', 'ciem-e2e', 'us-east-1');
      await authPage.saveProfile();
      await authPage.waitForToastMessage('Authentication profile saved');
      await authPage.waitForProfileCard('E2E AWS Current Profile');

      await authPage.assignProviderDiscovery();
      await authPage.waitForToastMessage('Assignment saved');

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
});
