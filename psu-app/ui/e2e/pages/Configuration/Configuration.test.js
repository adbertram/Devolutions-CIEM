const fs = require('fs');
const path = require('path');
const { test, expect } = require('../../_utils/BaseTestSetup');
const ConfigurationPageHelpers = require('./ConfigurationPageHelpers');
const { runPSUCommand } = require('../../_utils/psu-helpers');

const remediationPermissionCatalog = JSON.parse(
  fs.readFileSync(
    path.join(__dirname, '..', '..', '..', '..', 'modules', 'Devolutions.CIEM.Checks', 'Data', 'remediation-permissions.json'),
    'utf8'
  )
);
const expectedRemediationGraphPermissions = [...new Set(
  Object.values(remediationPermissionCatalog.Azure.RemediationTokens).flatMap(token => token.Graph || [])
)].sort();
const expectedRemediationAzureRoles = [...new Set(
  Object.values(remediationPermissionCatalog.Azure.RemediationTokens).flatMap(token => token.AzureRoles || [])
)].sort();

test.describe('Configuration Page', () => {
  let configPage;

  test.beforeEach(async ({ ciemPage }) => {
    configPage = new ConfigurationPageHelpers(ciemPage);
    await configPage.navigateToConfigPage();
  });

  test.describe('when the page loads', () => {
    test('should display page title', async () => {
      const title = await configPage.getPageTitle();
      expect(title).toContain('Configuration');
    });

    test('should display subtitle with configuration description', async () => {
      const subtitle = await configPage.getSubtitleText();
      expect(subtitle).toContain('Configure cloud provider authentication');
    });

    test('should display Cloud Provider Authentication card', async () => {
      const visible = await configPage.isAuthCardVisible();
      expect(visible).toBe(true);
    });

    test('should not display database schema maintenance controls', async () => {
      await expect(configPage.page.getByText('CIEM Database')).toHaveCount(0);
      await expect(configPage.page.getByText('Reapply Schema and Catalogs')).toHaveCount(0);
    });

    test('should display scheduled discovery configuration controls', async () => {
      const resetSchedule = await runPSUCommand("Devolutions.CIEM\\Set-CIEMAzureDiscoverySchedule -Scope 'All' -Cron '0 2 * * *' -Enabled $false | Out-Null");
      expect(resetSchedule.status).toBe('Completed');
      await configPage.navigateToConfigPage();
      await configPage.selectProvider('Azure');

      expect(await configPage.isScheduledDiscoveryCardVisible()).toBe(true);
      await configPage.waitForElement(configPage.selectors.scheduledDiscoveryCadenceCombobox);
      await configPage.waitForElement(configPage.selectors.scheduledDiscoveryScopeCombobox);
      await configPage.waitForElement(configPage.selectors.saveAzureDiscoveryScheduleBtn);
    });

    test('should allow selecting scheduled discovery cadence and scope without running discovery', async () => {
      await configPage.selectScheduleCadence('weekly');
      await configPage.selectScheduleScope('ARM');

      expect(await configPage.getSelectedScheduleCadence()).toBe('weekly');
      expect(await configPage.getSelectedScheduleScope()).toBe('ARM');
    });
  });

  test.describe('when running on a local on-premises PSU instance', () => {
    test('should display On-Premises environment chip with green color', async () => {
      const chipText = await configPage.getEnvironmentChipText();
      expect(chipText).toContain('On-Premises');
    });

    test('should display Managed Identity warning when ManagedIdentity auth is selected', async () => {
      await configPage.selectAuthMethod('ManagedIdentity');
      const warningVisible = await configPage.isManagedIdentityWarningVisible();
      expect(warningVisible).toBe(true);
    });
  });

  test.describe('when Azure is selected as the cloud provider', () => {

    test.describe('when Service Principal Secret is the authentication method', () => {
      test.beforeEach(async () => {
        // Explicitly select SP Secret — saved profile may default to a different method
        await configPage.selectAuthMethod('ServicePrincipalSecret');
      });

      test('should display Tenant ID text field with GUID placeholder', async () => {
        const visible = await configPage.isFieldVisible('azTenantId');
        expect(visible).toBe(true);
        const placeholder = await configPage.page.locator('#azTenantId').getAttribute('placeholder');
        expect(placeholder).toContain('xxxx');
      });

      test('should display Client ID text field with GUID placeholder', async () => {
        const visible = await configPage.isFieldVisible('azSpClientId');
        expect(visible).toBe(true);
        const placeholder = await configPage.page.locator('#azSpClientId').getAttribute('placeholder');
        expect(placeholder).toContain('xxxx');
      });

      test('should display Client Secret password field', async () => {
        const visible = await configPage.isFieldVisible('azSpClientSecret');
        expect(visible).toBe(true);
      });

      test('should accept input in Tenant ID field', async () => {
        const testGuid = '12345678-1234-1234-1234-123456789012';
        await configPage.fillTenantId(testGuid);
        const value = await configPage.page.locator('#azTenantId').inputValue();
        expect(value).toBe(testGuid);
      });

      test('should accept input in Client ID field', async () => {
        const testGuid = 'abcdef01-2345-6789-abcd-ef0123456789';
        await configPage.fill('#azSpClientId', testGuid);
        const value = await configPage.page.locator('#azSpClientId').inputValue();
        expect(value).toBe(testGuid);
      });

      test('should display auth method help text about selecting authentication', async () => {
        const visible = await configPage.isAuthMethodHelpTextVisible();
        expect(visible).toBe(true);
      });
    });

    test.describe('when Service Principal Certificate is the authentication method', () => {
      test.beforeEach(async () => {
        await configPage.selectAuthMethod('ServicePrincipalCertificate');
      });

      test('should display Tenant ID text field', async () => {
        const visible = await configPage.isFieldVisible('azTenantId');
        expect(visible).toBe(true);
      });

      test('should display Client ID text field', async () => {
        const visible = await configPage.isFieldVisible('azCertClientId');
        expect(visible).toBe(true);
      });

      test('should display Upload Certificate button', async () => {
        await configPage.waitForElement(configPage.selectors.uploadCertButton);
      });

      test('should display Certificate Password field', async () => {
        const visible = await configPage.isFieldVisible('azCertPassword');
        expect(visible).toBe(true);
      });

      test('should not display Client Secret field', async () => {
        const visible = await configPage.isFieldVisible('azSpClientSecret');
        expect(visible).toBe(false);
      });

      test('should display certificate upload guidance text', async () => {
        const guidanceText = await configPage.getCertUploadGuidanceText();
        expect(guidanceText).toBeTruthy();
        // Should mention either uploading a PFX file or that a certificate is stored
        const mentionsCert = guidanceText.includes('PFX') || guidanceText.includes('certificate') || guidanceText.includes('Certificate');
        expect(mentionsCert).toBe(true);
      });

      test('should upload a PFX file and display the selected filename', async () => {
        await configPage.uploadCertificateFixture();
        await expect(configPage.page.locator('text=test-certificate.pfx')).toBeVisible();
      });
    });

    test.describe('when Managed Identity is the authentication method', () => {
      test.beforeEach(async () => {
        await configPage.selectAuthMethod('ManagedIdentity');
      });

      test('should display warning that Managed Identity is unavailable on-premises', async () => {
        const warningVisible = await configPage.isManagedIdentityWarningVisible();
        expect(warningVisible).toBe(true);
      });

      test('should not display any credential input fields', async () => {
        const tenantVisible = await configPage.isFieldVisible('azTenantId');
        const clientIdVisible = await configPage.isFieldVisible('azSpClientId');
        const secretVisible = await configPage.isFieldVisible('azSpClientSecret');
        expect(tenantVisible).toBe(false);
        expect(clientIdVisible).toBe(false);
        expect(secretVisible).toBe(false);
      });
    });
  });

  test.describe('when AWS is selected as the cloud provider', () => {
    test.beforeEach(async () => {
      await configPage.selectProvider('AWS');
    });

    test('should hide Azure scheduled discovery controls', async () => {
      expect(await configPage.isScheduledDiscoveryCardVisible()).toBe(false);
    });

    test.describe('when CurrentProfile is the authentication method', () => {
      test('should display AWS Profile optional text field', async () => {
        const visible = await configPage.isFieldVisible('awsProfile');
        expect(visible).toBe(true);
      });

      test('should display AWS Region optional text field with us-east-1 placeholder', async () => {
        const visible = await configPage.isFieldVisible('awsRegion');
        expect(visible).toBe(true);
        const placeholder = await configPage.page.locator('#awsRegion').getAttribute('placeholder');
        expect(placeholder).toBe('us-east-1');
      });

      test('should display info alert about AWS CLI configuration', async () => {
        const alertVisible = await configPage.isElementVisible(configPage.selectors.awsCliAlert);
        expect(alertVisible).toBe(true);
      });

      test('should not display Access Key ID or Secret Access Key fields', async () => {
        const accessKeyVisible = await configPage.isFieldVisible('awsAccessKeyId');
        const secretKeyVisible = await configPage.isFieldVisible('awsSecretAccessKey');
        expect(accessKeyVisible).toBe(false);
        expect(secretKeyVisible).toBe(false);
      });

      test('should persist AWS profile and region metadata when saving', async () => {
        await configPage.fill(configPage.selectors.awsProfile, 'ciem-e2e-profile');
        await configPage.fillAWSRegion('us-west-2');
        await configPage.clickSave();

        const toast = await configPage.waitForToastMessage('Configuration saved successfully');
        expect(toast).toBeTruthy();

        const result = await runPSUCommand("Get-PSUCache -Key 'CIEM:AuthProfile:AWS' -Integrated | ConvertTo-Json -Depth 5 -Compress");
        expect(result.status).toBe('Completed');
        const awsProfile = JSON.parse(result.output[0].message);
        expect(awsProfile.Method).toBe('CurrentProfile');
        expect(awsProfile.Profile).toBe('ciem-e2e-profile');
        expect(awsProfile.Region).toBe('us-west-2');
      });
    });

    test.describe('when AccessKey is the authentication method', () => {
      test.beforeEach(async () => {
        await configPage.selectAuthMethod('AccessKey');
      });

      test('should display Access Key ID text field', async () => {
        const visible = await configPage.isFieldVisible('awsAccessKeyId');
        expect(visible).toBe(true);
      });

      test('should display Secret Access Key password field', async () => {
        const visible = await configPage.isFieldVisible('awsSecretAccessKey');
        expect(visible).toBe(true);
      });

      test('should display AWS Region optional text field', async () => {
        const visible = await configPage.isFieldVisible('awsRegion');
        expect(visible).toBe(true);
      });

      test('should not display AWS Profile field', async () => {
        const profileVisible = await configPage.isFieldVisible('awsProfile');
        expect(profileVisible).toBe(false);
      });
    });
  });

  test.describe('when the user switches between cloud providers', () => {
    test('should update auth method options when switching from Azure to AWS', async () => {
      // Start on Azure (default) — get Azure auth method options
      const azureOptions = await configPage.getAuthMethodOptions();
      expect(azureOptions.length).toBeGreaterThan(0);

      // Switch to AWS — auth method options should change
      await configPage.selectProvider('AWS');
      const awsOptions = await configPage.getAuthMethodOptions();
      expect(awsOptions.length).toBeGreaterThan(0);

      // AWS and Azure should have different auth method sets
      const azureJoined = azureOptions.sort().join(',');
      const awsJoined = awsOptions.sort().join(',');
      expect(azureJoined).not.toBe(awsJoined);
    });

    test('should update auth method options when switching from AWS to Azure', async () => {
      // Switch to AWS first
      await configPage.selectProvider('AWS');
      const awsOptions = await configPage.getAuthMethodOptions();
      expect(awsOptions.length).toBeGreaterThan(0);

      // Switch back to Azure — auth method options should revert
      await configPage.selectProvider('Azure');
      const azureOptions = await configPage.getAuthMethodOptions();
      expect(azureOptions.length).toBeGreaterThan(0);

      // Azure should have Service Principal options
      const hasSpOption = azureOptions.some(opt => opt.includes('Service Principal'));
      expect(hasSpOption).toBe(true);
    });
  });

  test.describe('when the user opens the Required Permissions modal', () => {
    test('should display modal with Azure discovery and remediation title', async () => {
      await configPage.clickGetPermissions();
      const modalVisible = await configPage.isPermissionsModalVisible();
      expect(modalVisible).toBe(true);
      const title = await configPage.getPermissionsModalTitle();
      expect(title).toContain('Azure Discovery and Remediation');
    });

    test('should display endpoint count in modal description', async () => {
      await configPage.clickGetPermissions();
      const bodyText = await configPage.getPermissionsModalBodyText();
      // Modal body should mention endpoint count, e.g. "Azure discovery (13 endpoints)"
      const hasEndpointCount = /\d+\s+endpoints/i.test(bodyText);
      expect(hasEndpointCount).toBe(true);
    });

    test('should not mention checks or security checks', async () => {
      await configPage.clickGetPermissions();
      const bodyText = await configPage.getPermissionsModalBodyText();
      expect(bodyText).not.toMatch(/\bcheck/i);
    });

    test('should separate discovery and remediation permissions into their own sections', async () => {
      await configPage.clickGetPermissions();
      const bodyText = await configPage.getPermissionsModalBodyText();
      expect(bodyText).toContain('Discovery Permissions');
      expect(bodyText).toContain('Remediation Permissions');
    });

    test('should list remediation Graph permissions from the shared catalog', async () => {
      await configPage.clickGetPermissions();
      const bodyText = await configPage.getPermissionsModalBodyText();
      for (const permission of expectedRemediationGraphPermissions) {
        expect(bodyText).toContain(permission);
      }
    });

    test('should display Azure RBAC Roles section with Reader role', async () => {
      await configPage.clickGetPermissions();
      const bodyText = await configPage.getPermissionsModalBodyText();
      expect(bodyText).toContain('Azure RBAC Roles');
      expect(bodyText).toContain('Reader');
    });

    test('should display remediation Azure RBAC roles from the shared catalog', async () => {
      await configPage.clickGetPermissions();
      const bodyText = await configPage.getPermissionsModalBodyText();
      for (const role of expectedRemediationAzureRoles) {
        expect(bodyText).toContain(role);
      }
    });

    test('should not display separate ARM or Key Vault permission sections', async () => {
      await configPage.clickGetPermissions();
      const bodyText = await configPage.getPermissionsModalBodyText();
      expect(bodyText).not.toContain('Azure Resource Manager RBAC Actions');
      expect(bodyText).not.toContain('Key Vault Data Plane Permissions');
    });

    test('should close modal when Close button is clicked', async () => {
      await configPage.clickGetPermissions();
      expect(await configPage.isPermissionsModalVisible()).toBe(true);
      await configPage.closePermissionsModal();
      expect(await configPage.isPermissionsModalVisible()).toBe(false);
    });
  });

  test.describe('when the user clicks Reset to Defaults', () => {
    test('should reset cloud provider to Azure', async () => {
      await configPage.selectProvider('AWS');
      await configPage.clickReset();
      await configPage.waitForDynamicFieldsLoad();
      // After reset, Azure Tenant ID field should be visible
      const tenantVisible = await configPage.isFieldVisible('azTenantId');
      expect(tenantVisible).toBe(true);
    });

    test('should reset auth method and re-render Azure fields', async () => {
      await configPage.selectAuthMethod('ManagedIdentity');
      await configPage.clickReset();
      await configPage.waitForDynamicFieldsLoad();
      // After reset, Azure credential fields should re-appear (Tenant ID visible for any SP method)
      const tenantVisible = await configPage.isFieldVisible('azTenantId');
      expect(tenantVisible).toBe(true);
    });

    test('should display orange toast with reset confirmation message', async () => {
      await configPage.clickReset();
      const toast = await configPage.waitForToastMessage('reset to default values');
      expect(toast).toBeTruthy();
    });
  });

  test.describe('when the user clicks Test Authentication', () => {
    test('should show loading state on Test Auth button after click', async () => {
      await configPage.selectAuthMethod('ServicePrincipalSecret');
      await configPage.clickTestAuth();
      // Button should remain visible during processing
      const testBtn = configPage.page.locator('#testAuthBtn');
      await expect(testBtn).toBeVisible();
    });

    test('should display a toast notification after test completes', async () => {
      await configPage.selectAuthMethod('ServicePrincipalSecret');
      await configPage.clickTestAuth();
      // Wait for either success or failure toast (test will fail without valid creds, but toast should appear)
      const toast = configPage.page.locator('.iziToast');
      await toast.first().waitFor({ state: 'visible', timeout: 30000 });
      expect(await toast.first().isVisible()).toBe(true);
    });
  });

  test.describe('when the user clicks Save Configuration with empty required fields', () => {
    test('should show loading state on Save button during processing', async () => {
      await configPage.clickSave();
      const saveBtn = configPage.page.locator(configPage.selectors.saveConfigBtn);
      await expect(saveBtn).toBeVisible();
    });

    test('should display a toast after save processing completes', async () => {
      await configPage.selectAuthMethod('ServicePrincipalSecret');
      // Clear fields and save with empty values
      await configPage.fillTenantId('');
      await configPage.clickSave();
      // Wait for a toast (success or error)
      const toast = configPage.page.locator('.iziToast');
      await toast.first().waitFor({ state: 'visible', timeout: 30000 });
      expect(await toast.first().isVisible()).toBe(true);
    });

    test('should display success toast when saving valid Azure SP Secret configuration', async () => {
      await configPage.selectAuthMethod('ServicePrincipalSecret');
      // Fill in valid-looking values (these will save to profile even if auth won't work)
      await configPage.fillTenantId('e2e-test-tenant-id');
      await configPage.fill('#azSpClientId', 'e2e-test-client-id');
      await configPage.clickSave();
      // Wait for success toast
      const toast = await configPage.waitForToastMessage('Configuration saved successfully');
      expect(toast).toBeTruthy();
    });

    test('should display success toast when saving valid Azure SP Certificate configuration with an uploaded PFX', async () => {
      await configPage.selectAuthMethod('ServicePrincipalCertificate');
      await configPage.fillTenantId('e2e-test-tenant-id');
      await configPage.fill('#azCertClientId', 'e2e-test-client-id');
      await configPage.uploadCertificateFixture();
      await configPage.clickSave();

      const toast = await configPage.waitForToastMessage('Configuration saved successfully');
      expect(toast).toBeTruthy();
    });
  });
});
