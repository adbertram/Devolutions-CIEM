function GetCIEMIAMNeeds {
    <#
    .SYNOPSIS
        Loads IAM (Azure RBAC) discovery data into the scan service-data hashtable
        for each requested 'iam:*' need key.

    .DESCRIPTION
        Called by GetCIEMAzureScanServiceCache when at least one selected check
        declares an iam:* data need. Populates $ServiceData['IAM'] as a
        per-subscription hashtable containing RoleAssignments, RoleDefinitions,
        and CustomRoles arrays.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$NeedKeys,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$SubscriptionIds,

        [Parameter(Mandatory)]
        [hashtable]$ServiceData,

        [Parameter(Mandatory)]
        [hashtable]$ServiceErrors,

        [Parameter(Mandatory)]
        [hashtable]$ServiceStarted
    )

    $ErrorActionPreference = 'Stop'

    $iamNeeds = @($NeedKeys | Where-Object { $_ -like 'iam:*' })
    if ($iamNeeds.Count -eq 0) {
        return
    }

    if (-not $ServiceData.ContainsKey('IAM')) {
        $ServiceData['IAM'] = @{}
        $ServiceErrors['IAM'] = @()
        $ServiceStarted['IAM'] = [Diagnostics.Stopwatch]::StartNew()
    }

    $ensureBucket = {
        param([string]$SubId)
        if (-not $ServiceData['IAM'].ContainsKey($SubId)) {
            $ServiceData['IAM'][$SubId] = @{
                RoleAssignments = @()
                RoleDefinitions = @()
                CustomRoles = @()
            }
        }
    }

    # Always pre-create the known subscription buckets so downstream checks don't
    # have to handle the missing-key case.
    foreach ($subscriptionId in $SubscriptionIds) {
        & $ensureBucket $subscriptionId
    }

    foreach ($needKey in ($iamNeeds | Select-Object -Unique)) {
        if ($needKey -cne $needKey.ToLowerInvariant()) {
            throw "Data need '$needKey' must use lowercase canonical form."
        }

        switch ($needKey) {
            'iam:roleassignments' {
                foreach ($resource in @(Get-CIEMAzureArmResource -Type 'microsoft.authorization/roleassignments')) {
                    $subscriptionId = $resource.SubscriptionId
                    if (-not $subscriptionId -and $resource.Id -match '^/subscriptions/([^/]+)') {
                        $subscriptionId = $Matches[1]
                    }
                    if (-not $subscriptionId) {
                        continue
                    }
                    & $ensureBucket $subscriptionId
                    $ServiceData['IAM'][$subscriptionId].RoleAssignments += ConvertFromCIEMStoredResource -Resource $resource
                }
            }
            'iam:roledefinitions' {
                foreach ($resource in @(Get-CIEMAzureArmResource -Type 'microsoft.authorization/roledefinitions')) {
                    $definition = ConvertFromCIEMStoredResource -Resource $resource
                    $targetSubscriptions = @()
                    foreach ($scope in @($definition.assignableScopes)) {
                        if ($scope -match '^/subscriptions/([^/]+)') {
                            $targetSubscriptions += $Matches[1]
                        }
                    }
                    if ($targetSubscriptions.Count -eq 0) {
                        $targetSubscriptions = @($SubscriptionIds)
                    }
                    foreach ($subscriptionId in ($targetSubscriptions | Select-Object -Unique)) {
                        if (-not $subscriptionId) {
                            continue
                        }
                        & $ensureBucket $subscriptionId
                        $ServiceData['IAM'][$subscriptionId].RoleDefinitions += $definition
                        if ($definition.PSObject.Properties.Name -contains 'type' -and $definition.type -eq 'CustomRole') {
                            $ServiceData['IAM'][$subscriptionId].CustomRoles += $definition
                        }
                    }
                }
            }
            default {
                throw "Unknown data need '$needKey'."
            }
        }
    }
}
