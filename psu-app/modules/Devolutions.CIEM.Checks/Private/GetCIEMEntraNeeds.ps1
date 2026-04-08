function GetCIEMEntraNeeds {
    <#
    .SYNOPSIS
        Loads Entra (Microsoft Graph) discovery data into the scan service-data
        hashtable for each requested 'entra:*' need key.

    .DESCRIPTION
        Called by GetCIEMAzureScanServiceCache when at least one selected check
        declares an entra:* data need. Iterates the requested need keys and
        populates $ServiceData['Entra'] with the corresponding discovery rows.
        Uses ConvertFromCIEMStoredResource to rehydrate JSON blobs.

        Throws on unknown need keys — discovery of unexpected keys is a bug, not
        a graceful-degradation case.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$NeedKeys,

        [Parameter(Mandatory)]
        [hashtable]$ServiceData,

        [Parameter(Mandatory)]
        [hashtable]$ServiceErrors,

        [Parameter(Mandatory)]
        [hashtable]$ServiceStarted
    )

    $ErrorActionPreference = 'Stop'

    $entraNeeds = @($NeedKeys | Where-Object { $_ -like 'entra:*' })
    if ($entraNeeds.Count -eq 0) {
        return
    }

    if (-not $ServiceData.ContainsKey('Entra')) {
        $ServiceData['Entra'] = @{}
        $ServiceErrors['Entra'] = @()
        $ServiceStarted['Entra'] = [Diagnostics.Stopwatch]::StartNew()
    }

    foreach ($needKey in ($entraNeeds | Select-Object -Unique)) {
        if ($needKey -cne $needKey.ToLowerInvariant()) {
            throw "Data need '$needKey' must use lowercase canonical form."
        }

        switch ($needKey) {
            'entra:users' {
                $ServiceData['Entra'].Users = @(Get-CIEMAzureEntraResource -Type 'user' | ForEach-Object { ConvertFromCIEMStoredResource -Resource $_ })
            }
            'entra:groups' {
                $ServiceData['Entra'].Groups = @(Get-CIEMAzureEntraResource -Type 'group' | ForEach-Object { ConvertFromCIEMStoredResource -Resource $_ })
            }
            'entra:serviceprincipals' {
                $ServiceData['Entra'].ServicePrincipals = @(Get-CIEMAzureEntraResource -Type 'servicePrincipal' | ForEach-Object { ConvertFromCIEMStoredResource -Resource $_ })
            }
            'entra:applications' {
                $ServiceData['Entra'].Applications = @(Get-CIEMAzureEntraResource -Type 'application' | ForEach-Object { ConvertFromCIEMStoredResource -Resource $_ })
            }
            'entra:directoryroles' {
                $ServiceData['Entra'].DirectoryRoles = @(Get-CIEMAzureEntraResource -Type 'directoryRole' | ForEach-Object { ConvertFromCIEMStoredResource -Resource $_ })
            }
            'entra:directoryrolemembers' {
                $lookup = @{}
                foreach ($relationship in @(Get-CIEMAzureResourceRelationship -Relationship 'has_role_member')) {
                    if (-not $lookup.ContainsKey($relationship.TargetId)) {
                        $lookup[$relationship.TargetId] = @()
                    }
                    $lookup[$relationship.TargetId] += [pscustomobject]@{
                        id = $relationship.SourceId
                        type = $relationship.SourceType
                    }
                }
                $ServiceData['Entra'].DirectoryRoleMembers = $lookup
            }
            'entra:usermfastatus' {
                $ServiceData['Entra'].UserMFAStatus = @(Get-CIEMAzureEntraResource -Type 'userRegistrationDetail' | ForEach-Object { ConvertFromCIEMStoredResource -Resource $_ })
            }
            'entra:securitydefaults' {
                $ServiceData['Entra'].SecurityDefaults = @(Get-CIEMAzureEntraResource -Type 'securityDefaults' | ForEach-Object { ConvertFromCIEMStoredResource -Resource $_ } | Select-Object -First 1)
            }
            'entra:authorizationpolicy' {
                $ServiceData['Entra'].AuthorizationPolicy = @(Get-CIEMAzureEntraResource -Type 'authorizationPolicy' | ForEach-Object { ConvertFromCIEMStoredResource -Resource $_ } | Select-Object -First 1)
            }
            'entra:groupsettings' {
                $ServiceData['Entra'].GroupSettings = @(Get-CIEMAzureEntraResource -Type 'groupSetting' | ForEach-Object { ConvertFromCIEMStoredResource -Resource $_ })
            }
            'entra:namedlocations' {
                $ServiceData['Entra'].NamedLocations = @(Get-CIEMAzureEntraResource -Type 'namedLocation' | ForEach-Object { ConvertFromCIEMStoredResource -Resource $_ })
            }
            'entra:conditionalaccesspolicies' {
                $ServiceData['Entra'].ConditionalAccessPolicies = @(Get-CIEMAzureEntraResource -Type 'conditionalAccessPolicy' | ForEach-Object { ConvertFromCIEMStoredResource -Resource $_ })
            }
            default {
                throw "Unknown data need '$needKey'."
            }
        }
    }
}
