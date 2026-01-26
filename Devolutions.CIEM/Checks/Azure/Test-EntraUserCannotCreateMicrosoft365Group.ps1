function Test-EntraUserCannotCreateMicrosoft365Group {
    <#
    .SYNOPSIS
        Tests if users are restricted from creating Microsoft 365 groups.

    .DESCRIPTION
        This check verifies that the group settings have 'EnableGroupCreation' set to a value
        other than 'true', restricting Microsoft 365 group creation.

        The setting is found in the GroupSettings collection under the template
        'Group.Unified' with the name 'EnableGroupCreation'.

    .PARAMETER CheckMetadata
        Hashtable containing check metadata including id and severity.

    .EXAMPLE
        Test-EntraUsersCannotCreateMicrosoft365Groups -CheckMetadata $metadata
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [hashtable]$CheckMetadata
    )

    $ErrorActionPreference = 'Stop'

    # Default to FAIL
    $status = 'FAIL'
    $statusExtended = 'Users can create Microsoft 365 groups.'
    $resourceId = 'Microsoft365 Groups'
    $resourceName = 'Microsoft365 Groups'

    # Check if Group Settings data is available
    if ($script:EntraService.GroupSettings -and $script:EntraService.GroupSettings.Count -gt 0) {
        foreach ($setting in $script:EntraService.GroupSettings) {
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

    $findingParams = @{
        CheckMetadata  = $CheckMetadata
        Status         = $status
        StatusExtended = $statusExtended
        ResourceId     = $resourceId
        ResourceName   = $resourceName
    }
    New-CIEMFinding @findingParams
}
