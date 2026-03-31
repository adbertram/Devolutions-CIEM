function ParseCIEMIdentityProperties {
    <#
    .SYNOPSIS
        Parses Entra resource properties JSON into structured identity metadata.
    .DESCRIPTION
        Extracts accountEnabled, sign-in activity, managed identity status, and principal type
        from an Entra resource's properties JSON. Used by both risk summary and risk signals functions.
    .PARAMETER PropertiesJson
        The raw JSON string from azure_entra_resources.properties column.
    .PARAMETER EntraType
        The Entra resource type (user, group, servicePrincipal).
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [string]$PropertiesJson,

        [Parameter(Mandatory)]
        [string]$EntraType
    )

    $ErrorActionPreference = 'Stop'

    $props = $null
    if ($PropertiesJson) {
        $props = $PropertiesJson | ConvertFrom-Json
    }

    $accountEnabled = if ($null -ne $props -and $null -ne $props.accountEnabled) {
        [bool]$props.accountEnabled
    } else {
        $true
    }

    # Extract both interactive and non-interactive sign-in timestamps
    $lastInteractive = $null
    $lastNonInteractive = $null
    if ($null -ne $props -and $null -ne $props.signInActivity) {
        if ($props.signInActivity.lastSignInDateTime) {
            $lastInteractive = [datetime]$props.signInActivity.lastSignInDateTime
        }
        if ($props.signInActivity.lastNonInteractiveSignInDateTime) {
            $lastNonInteractive = [datetime]$props.signInActivity.lastNonInteractiveSignInDateTime
        }
    }

    # Coalesce: most recent of interactive and non-interactive
    $lastActivity = $null
    if ($lastInteractive -and $lastNonInteractive) {
        $lastActivity = if ($lastInteractive -gt $lastNonInteractive) { $lastInteractive } else { $lastNonInteractive }
    } elseif ($lastInteractive) {
        $lastActivity = $lastInteractive
    } elseif ($lastNonInteractive) {
        $lastActivity = $lastNonInteractive
    }

    $lastSignIn = if ($lastActivity) { $lastActivity.ToString('o') } else { $null }
    $daysSinceSignIn = if ($lastActivity) { [math]::Floor(((Get-Date) - $lastActivity).TotalDays) } else { $null }

    $isManagedIdentity = ($EntraType -eq 'servicePrincipal' -and
                          $null -ne $props -and
                          $props.servicePrincipalType -eq 'ManagedIdentity')

    $principalType = switch ($EntraType) {
        'user'  { 'User' }
        'group' { 'Group' }
        'servicePrincipal' {
            if ($isManagedIdentity) { 'ManagedIdentity' } else { 'ServicePrincipal' }
        }
    }

    [PSCustomObject]@{
        AccountEnabled           = $accountEnabled
        LastSignIn               = $lastSignIn
        DaysSinceSignIn          = $daysSinceSignIn
        LastInteractiveSignIn    = if ($lastInteractive) { $lastInteractive.ToString('o') } else { $null }
        LastNonInteractiveSignIn = if ($lastNonInteractive) { $lastNonInteractive.ToString('o') } else { $null }
        IsManagedIdentity        = $isManagedIdentity
        PrincipalType            = $principalType
    }
}
