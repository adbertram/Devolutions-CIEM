function Test-EntraConditionalAccessPolicyRequireMfaForManagementApi {
    <#
    .SYNOPSIS
        Tests if any Conditional Access policy requires MFA for Windows Azure Service Management API.

    .DESCRIPTION
        This check verifies that there is at least one enabled Conditional Access policy that requires
        multifactor authentication when accessing the Windows Azure Service Management API
        (appId = 797f4846-ba00-4fd7-ba43-dac1f8f63013).

    .PARAMETER Check
        CIEMCheck object containing check metadata.

    .EXAMPLE
        Test-EntraConditionalAccessPolicyRequireMfaForManagementApi -Check $metadata
    #>
    [CmdletBinding()]
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter(Mandatory)]
        $Check
    )

    $ErrorActionPreference = 'Stop'
    $azureManagementApiAppId = '797f4846-ba00-4fd7-ba43-dac1f8f63013'

    # Check if Conditional Access policies data is available
    if (-not $script:EntraService.ConditionalAccessPolicies) {
        [CIEMScanResult]::Create(
            $Check,
            'SKIPPED',
            'Unable to retrieve Conditional Access policies - Azure AD Premium P1/P2 license required',
            'N/A',
            'Conditional Access Policies'
        )
    }
    else {
        # Look for enabled policies that require MFA for Azure Management API
        $mfaPolicyNames = @()

        foreach ($policy in $script:EntraService.ConditionalAccessPolicies) {
            # Skip disabled policies
            if ($policy.state -ne 'enabled') {
                continue
            }

            # Check if policy targets ALL users
            $targetsAllUsers = $false
            if ($policy.conditions.users) {
                $includeUsers = $policy.conditions.users.includeUsers
                if ($includeUsers -contains 'All') {
                    $targetsAllUsers = $true
                }
            }

            if (-not $targetsAllUsers) {
                continue
            }

            # Check if policy targets the Azure Management API
            $targetsManagementApi = $false

            if ($policy.conditions.applications) {
                $includeApps = $policy.conditions.applications.includeApplications

                # Check if policy specifically targets the Azure Management API
                if ($includeApps -contains $azureManagementApiAppId) {
                    $targetsManagementApi = $true
                }
            }

            if (-not $targetsManagementApi) {
                continue
            }

            # Check if policy requires MFA
            $requiresMfa = $false

            if ($policy.grantControls) {
                $builtInControls = $policy.grantControls.builtInControls
                if ($builtInControls -contains 'mfa') {
                    $requiresMfa = $true
                }
            }

            if ($targetsManagementApi -and $requiresMfa) {
                $mfaPolicyNames += $policy.displayName
            }
        }

        if ($mfaPolicyNames.Count -gt 0) {
            $policyNames = $mfaPolicyNames -join ', '
            [CIEMScanResult]::Create(
                $Check,
                'PASS',
                "Found $($mfaPolicyNames.Count) Conditional Access policy(ies) requiring MFA for Windows Azure Service Management API: $policyNames",
                'conditional-access-policies',
                'Conditional Access Policies'
            )
        }
        else {
            [CIEMScanResult]::Create(
                $Check,
                'FAIL',
                'No Conditional Access policy requires MFA for Windows Azure Service Management API (appId: 797f4846-ba00-4fd7-ba43-dac1f8f63013)',
                'conditional-access-policies',
                'Conditional Access Policies'
            )
        }
    }
}
