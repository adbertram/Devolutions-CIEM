function Install-PSUModule {
    <#
    .SYNOPSIS
        Installs a module from the PowerShell Gallery into PowerShell Universal.

    .DESCRIPTION
        Installs a module from the PowerShell Gallery (or another repository) into
        the PSU instance. If no version is specified, automatically finds and installs
        the latest version.

    .PARAMETER Name
        The name of the module to install.

    .PARAMETER Version
        Specific version to install. If not specified, installs the latest version.

    .PARAMETER Repository
        The repository to install from. Defaults to 'PSGallery'.

    .PARAMETER Prerelease
        Allow prerelease versions when searching for the latest version.

    .PARAMETER NoSync
        Skip the configuration sync after installing.

    .EXAMPLE
        Install-PSUModule -Name "Devolutions.CIEM"

    .EXAMPLE
        Install-PSUModule -Name "Devolutions.CIEM" -Version "0.2.21"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter()]
        [string]$Version,

        [Parameter()]
        [string]$Repository = 'PSGallery',

        [Parameter()]
        [switch]$Prerelease,

        [Parameter()]
        [switch]$NoSync
    )

    Assert-PSUConnection

    $headers = @{
        'Authorization'              = "Bearer $($script:PSUConnection.Token)"
        'Accept'                     = 'application/json'
        'Content-Type'               = 'application/json'
        # ngrok free tunnels return a browser-warning HTML interstitial unless
        # this header is set, which silently breaks Invoke-RestMethod parsing.
        'ngrok-skip-browser-warning' = 'true'
    }

    if (-not $Version) {
        Write-Verbose "No version specified. Searching for latest version of '$Name' in $Repository..."

        $searchUri = "$($script:PSUConnection.Url)/api/v1/module/find/$Repository/$Name"

        try {
            $searchResults = Invoke-RestMethod -Uri $searchUri -Headers $headers -Method Get -ErrorAction Stop
        }
        catch {
            throw "Failed to search for module '$Name' in $Repository. Error: $_"
        }

        if (-not $searchResults -or $searchResults.Count -eq 0) {
            throw "Module '$Name' not found in $Repository."
        }

        $exactMatch = $searchResults | Where-Object { $_.name -eq $Name } | Select-Object -First 1

        if (-not $exactMatch) {
            throw "Module '$Name' not found in $Repository. Found similar: $($searchResults.name -join ', ')"
        }

        $Version = $exactMatch.version
        Write-Verbose "Found latest version: $Version"
    }

    $body = @{
        name       = $Name
        version    = $Version
        repository = $Repository
    }

    if ($Prerelease) {
        $body.prerelease = $true
    }

    $bodyJson = $body | ConvertTo-Json

    Write-Verbose "Installing $Name v$Version from $Repository..."

    $saveUri = "$($script:PSUConnection.Url)/api/v1/module/save"

    try {
        Invoke-RestMethod -Uri $saveUri -Headers $headers -Method Post -Body $bodyJson -ErrorAction Stop
        Write-Verbose "Module installed successfully."
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        throw "Failed to install module '$Name' v$Version. Status: $statusCode. Error: $_"
    }

    if (-not $NoSync) {
        Write-Verbose "Syncing PSU configuration to load the module..."
        try {
            Sync-PSUConfiguration | Out-Null
            Write-Verbose "Configuration synced."
        }
        catch {
            Write-Warning "Module installed but configuration sync failed: $_"
            Write-Warning "You may need to manually call: Sync-PSUConfiguration"
        }
    }

    [PSCustomObject]@{
        Name       = $Name
        Version    = $Version
        Repository = $Repository
        Status     = 'Installed'
    }
}
