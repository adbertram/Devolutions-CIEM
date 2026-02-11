function Test-StorageAccountProperty {
    <#
    .SYNOPSIS
        Tests a boolean/simple property on all storage accounts.

    .DESCRIPTION
        Parameterized helper function that checks a property value across all storage
        accounts in all subscriptions. Used by multiple check functions that verify
        whether certain storage account settings are configured correctly.

    .PARAMETER Check
        CIEMCheck object containing check metadata.

    .PARAMETER PropertyPath
        Dot-notation path to the property (e.g., 'properties.supportsHttpsTrafficOnly').

    .PARAMETER ExpectedValue
        The expected value that indicates a passing check.

    .PARAMETER PassMessage
        Message format for pass. Use {0} for account name, {1} for property value.

    .PARAMETER FailMessage
        Message format for fail. Use {0} for account name, {1} for current value.

    .PARAMETER DefaultValue
        Value to use if property is null.

    .OUTPUTS
        [CIEMScanResult[]] Array of scan result objects.
    #>
    [CmdletBinding()]
    [OutputType([CIEMScanResult[]])]
    param(
        [Parameter(Mandatory)]
        $Check,

        [Parameter(Mandatory)]
        [string]$PropertyPath,

        [Parameter(Mandatory)]
        $ExpectedValue,

        [Parameter(Mandatory)]
        [string]$PassMessage,

        [Parameter(Mandatory)]
        [string]$FailMessage,

        [Parameter()]
        $DefaultValue = $null
    )

    $ErrorActionPreference = 'Stop'

    foreach ($subscriptionId in $script:StorageService.Keys) {
        $storageData = $script:StorageService[$subscriptionId]

        foreach ($account in $storageData.StorageAccounts) {
            $accountName = $account.name
            $resourceId = $account.id
            $location = $account.location

            # Navigate the property path using PSObject.Properties for strict mode compliance
            $propertyValue = $account
            foreach ($segment in $PropertyPath.Split('.')) {
                if ($null -eq $propertyValue) { break }
                if ($propertyValue.PSObject.Properties[$segment]) {
                    $propertyValue = $propertyValue.$segment
                }
                else {
                    $propertyValue = $null
                    break
                }
            }

            # Apply default if null
            if ($null -eq $propertyValue -and $null -ne $DefaultValue) {
                $propertyValue = $DefaultValue
            }

            # Compare to expected value
            if ($propertyValue -eq $ExpectedValue) {
                $message = $PassMessage -f $accountName, $propertyValue
                [CIEMScanResult]::Create($Check, 'PASS', $message, $resourceId, $accountName, $location)
            }
            else {
                $displayValue = if ($null -eq $propertyValue) { 'not set' } else { $propertyValue }
                $message = $FailMessage -f $accountName, $displayValue
                [CIEMScanResult]::Create($Check, 'FAIL', $message, $resourceId, $accountName, $location)
            }
        }
    }
}
