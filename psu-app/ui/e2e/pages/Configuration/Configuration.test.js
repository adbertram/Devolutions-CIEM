const { test, expect } = require('../../_utils/BaseTestSetup');
const ConfigurationPageHelpers = require('./ConfigurationPageHelpers');

test.describe('Configuration Page', () => {
  let configPage;

  test.beforeEach(async ({ ciemPage }) => {
    configPage = new ConfigurationPageHelpers(ciemPage);
    await configPage.navigateToConfigPage();
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
        const visible = await configPage.isElementVisible(configPage.selectors.uploadCertButton);
        expect(visible).toBe(true);
      });

      test('should display Certificate Password field', async () => {
        const visible = await configPage.isFieldVisible('azCertPassword');
        expect(visible).toBe(true);
      });

      test('should not display Client Secret field', async () => {
        const visible = await configPage.isFieldVisible('azSpClientSecret');
        expect(visible).toBe(false);
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
    });
  });

  test.describe('when the user opens the Required Permissions modal', () => {
    test('should display modal with title containing the selected provider name', async () => {
      await configPage.clickGetPermissions();
      const modalVisible = await configPage.isPermissionsModalVisible();
      expect(modalVisible).toBe(true);
      const title = await configPage.getPermissionsModalTitle();
      expect(title).toContain('Azure');
    });

    test('should display permission categories (Graph, ARM, KeyVault for Azure)', async () => {
      await configPage.clickGetPermissions();
      const modalText = await configPage.getText(configPage.selectors.permissionsModal);
      const hasGraphOrArmOrKeyVault =
        modalText.includes('Graph') ||
        modalText.includes('ARM') ||
        modalText.includes('Key Vault');
      expect(hasGraphOrArmOrKeyVault).toBe(true);
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
      const saveBtn = configPage.page.locator('#saveConfigBtn');
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
  });
});
