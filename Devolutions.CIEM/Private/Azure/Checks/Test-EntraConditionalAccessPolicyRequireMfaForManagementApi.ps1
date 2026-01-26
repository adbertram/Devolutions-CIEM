function Test-EntraConditionalAccessPolicyRequireMfaForManagementApi {
    <#
    .SYNOPSIS
        Tests if any Conditional Access policy requires MFA for Windows Azure Service Management API.

    .DESCRIPTION
        This check verifies that there is at least one enabled Conditional Access policy that requires
        multifactor authentication when accessing the Windows Azure Service Management API
        (appId = 797f4846-ba00-4fd7-ba43-dac1f8f63013).

    .PARAMETER CheckMetadata
        Hashtable containing check metadata including id and severity.

    .EXAMPLE
        Test-EntraConditionalAccessPolicyRequireMfaForManagementApi -CheckMetadata $metadata
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CheckMetadata
    )

    $ErrorActionPreference = 'Stop'
    $azureManagementApiAppId = '797f4846-ba00-4fd7-ba43-dac1f8f63013'

    # Check if Conditional Access policies data is available
    if (-not $script:EntraService.ConditionalAccessPolicies) {
        [PSCustomObject]@{
            CheckId        = $CheckMetadata.id
            Status         = 'SKIPPED'
            StatusExtended = 'Unable to retrieve Conditional Access policies - missing permissions or no policies configured'
            ResourceId     = 'N/A'
            ResourceName   = 'Conditional Access Policies'
            Location       = 'Global'
            Severity       = $CheckMetadata.severity
        }
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
            [PSCustomObject]@{
                CheckId        = $CheckMetadata.id
                Status         = 'PASS'
                StatusExtended = "Found $($mfaPolicyNames.Count) Conditional Access policy(ies) requiring MFA for Windows Azure Service Management API: $policyNames"
                ResourceId     = 'conditional-access-policies'
                ResourceName   = 'Conditional Access Policies'
                Location       = 'Global'
                Severity       = $CheckMetadata.severity
            }
        }
        else {
            [PSCustomObject]@{
                CheckId        = $CheckMetadata.id
                Status         = 'FAIL'
                StatusExtended = 'No Conditional Access policy requires MFA for Windows Azure Service Management API (appId: 797f4846-ba00-4fd7-ba43-dac1f8f63013)'
                ResourceId     = 'conditional-access-policies'
                ResourceName   = 'Conditional Access Policies'
                Location       = 'Global'
                Severity       = $CheckMetadata.severity
            }
        }
    }
}
