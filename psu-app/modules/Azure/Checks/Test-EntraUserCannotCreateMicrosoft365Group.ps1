function Test-EntraUserCannotCreateMicrosoft365Group {
    <#
    .SYNOPSIS
        Tests if users are restricted from creating Microsoft 365 groups.

    .DESCRIPTION
        This check verifies that the group settings have 'EnableGroupCreation' set to a value
        other than 'true', restricting Microsoft 365 group creation.

        The setting is found in the GroupSettings collection under the template
        'Group.Unified' with the name 'EnableGroupCreation'.

    .PARAMETER Check
        CIEMCheck object containing check metadata.

    .EXAMPLE
        Test-EntraUsersCannotCreateMicrosoft365Groups -Check $metadata
    #>
    [CmdletBinding()]
    [OutputType('CIEMScanResult[]')]
    param(
        [Parameter(Mandatory)]
        $Check,

        [Parameter(Mandatory)]
        [CIEMServiceCache[]]$ServiceCache
    )

    $ErrorActionPreference = 'Stop'

    $svc = ($ServiceCache | Where-Object { $_.ServiceName -eq 'Entra' }).CacheData

    # Default to FAIL
    $status = 'FAIL'
    $statusExtended = 'Users can create Microsoft 365 groups.'
    $resourceId = 'Microsoft365 Groups'
    $resourceName = 'Microsoft365 Groups'

    # Check if Group Settings data is available
    if ($svc.GroupSettings -and $svc.GroupSettings.Count -gt 0) {
        foreach ($setting in $svc.GroupSettings) {
            # Look for Group.Unified settings
            $isGroupUnified = if ($setting.PSObject.Properties['displayName']) {
                $setting.displayName -eq 'Group.Unified'
            }
            else {
                $false
            }

            if ($isGroupUnified) {
                $resourceId = if ($setting.PSObject.Properties['id']) { $setting.id } else { 'Microsoft365 Groups' }

                # Look for EnableGroupCreation setting
                $values = if ($setting.PSObject.Properties['values']) { $setting.values } else { @() }
                foreach ($settingValue in $values) {
                    $valueName = if ($settingValue.PSObject.Properties['name']) { $settingValue.name } else { $null }
                    $valueContent = if ($settingValue.PSObject.Properties['value']) { $settingValue.value } else { $null }

                    if ($valueName -eq 'EnableGroupCreation' -and $valueContent -ne 'true') {
                        $status = 'PASS'
                        $statusExtended = 'Users cannot create Microsoft 365 groups.'
                        break
                    }
                }
                break
            }
        }
    }

    [CIEMScanResult]::Create($Check, $status, $statusExtended, $resourceId, $resourceName)
}
