# PSUniversal.psm1
# PowerShell Universal management module for Devolutions CIEM

# Module-level variables for connection state
$script:PSUConnection = @{
    Url           = $null
    Token         = $null
    IsAzure       = $false
    ResourceGroup = $null
    WebAppName    = $null
}

function Connect-PSU {
    <#
    .SYNOPSIS
        Connects to a PowerShell Universal instance.

    .DESCRIPTION
        Authenticates to PSU by reading credentials from a .env file or accepting
        parameters directly. Sets up the module-level connection for subsequent commands.

    .PARAMETER Url
        The PSU server URL. If not specified, reads from AZURE_PSU_URL or LOCAL_PSU_URL in .env file.

    .PARAMETER Token
        The PSU app token. If not specified, reads from AZURE_PSU_TOKEN or LOCAL_PSU_TOKEN in .env file.

    .PARAMETER EnvFilePath
        Path to the .env file. Defaults to .env in the current directory or repository root.

    .PARAMETER ResourceGroup
        Azure resource group name (for Azure-hosted PSU). Enables filesystem operations.

    .PARAMETER WebAppName
        Azure web app name (for Azure-hosted PSU). Enables filesystem operations.

    .EXAMPLE
        Connect-PSU
        # Reads from .env file in current or parent directories

    .EXAMPLE
        Connect-PSU -Url "https://psu.example.com" -Token "my-token"
        # Uses explicit parameters

    .EXAMPLE
        Connect-PSU -ResourceGroup "my-rg" -WebAppName "my-psu"
        # Connect to Azure-hosted PSU with filesystem access

    .EXAMPLE
        Connect-PSU -Local
        # Connect to local PSU instance (uses LOCAL_PSU_URL and LOCAL_PSU_TOKEN from .env)
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Url,

        [Parameter()]
        [string]$Token,

        [Parameter()]
        [string]$EnvFilePath,

        [Parameter()]
        [string]$ResourceGroup,

        [Parameter()]
        [string]$WebAppName,

        [Parameter()]
        [switch]$Local
    )

    # Find .env file if not specified
    if (-not $EnvFilePath) {
        $searchPaths = @(
            (Join-Path $PWD '.env'),
            (Join-Path $PSScriptRoot '../.env'),
            (Join-Path $PSScriptRoot '.env')
        )

        foreach ($path in $searchPaths) {
            if (Test-Path $path) {
                $EnvFilePath = $path
                break
            }
        }
    }

    # Read from .env file if we have one and parameters weren't provided
    $envVars = @{}
    if ($EnvFilePath -and (Test-Path $EnvFilePath)) {
        Write-Verbose "Reading configuration from: $EnvFilePath"
        $envContent = Get-Content $EnvFilePath -ErrorAction Stop

        foreach ($line in $envContent) {
            if ($line -match '^\s*#' -or $line -match '^\s*$') {
                continue
            }

            if ($line -match '^([^=]+)=(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                $envVars[$key] = $value

                switch ($key) {
                    'AZURE_PSU_URL' {
                        if (-not $Url -and -not $Local) { $Url = $value }
                    }
                    'AZURE_PSU_TOKEN' {
                        if (-not $Token -and -not $Local) { $Token = $value }
                    }
                    'LOCAL_PSU_URL' {
                        if (-not $Url -and $Local) { $Url = $value }
                    }
                    'LOCAL_PSU_TOKEN' {
                        if (-not $Token -and $Local) { $Token = $value }
                    }
                }
            }
        }
    }

    # Validate required parameters
    $target = if ($Local) { 'LOCAL' } else { 'AZURE' }
    if (-not $Url) {
        throw "PSU URL is required. Provide -Url parameter or set ${target}_PSU_URL in .env file."
    }
    if (-not $Token) {
        throw "PSU Token is required. Provide -Token parameter or set ${target}_PSU_TOKEN in .env file."
    }

    # Normalize URL (remove trailing slash)
    $Url = $Url.TrimEnd('/')

    # Test connection by calling the module endpoint
    Write-Verbose "Testing connection to $Url"
    $headers = @{
        'Accept' = 'application/json'
    }
    if ($Token) {
        $headers['Authorization'] = "Bearer $Token"
    }

    try {
        # Use the module endpoint to verify connection (returns 401 if bad token, 200 if good)
        $null = Invoke-RestMethod -Uri "$Url/api/v1/module" -Headers $headers -Method Get -ErrorAction Stop
        Write-Verbose "Connected successfully."
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq 401) {
            if ($Local) {
                throw "Authentication failed. Local PSU may not be running in development mode, or may require a token."
            }
            throw "Authentication failed. Check your PSU token."
        }
        throw "Failed to connect to PSU at $Url. Error: $_"
    }

    # Detect Azure hosting from URL pattern
    $isAzure = $Url -match '\.azurewebsites\.net'

    # Auto-detect webapp name from URL if not provided
    if ($isAzure -and -not $WebAppName) {
        if ($Url -match 'https://([^.]+)\.azurewebsites\.net') {
            $WebAppName = $matches[1]
            Write-Verbose "Auto-detected Azure webapp name: $WebAppName"
        }
    }

    # Default resource group for this project
    if ($isAzure -and -not $ResourceGroup) {
        $ResourceGroup = 'devolutions-ciem-rg'
        Write-Verbose "Using default resource group: $ResourceGroup"
    }

    # Store connection info
    $script:PSUConnection.Url = $Url
    $script:PSUConnection.Token = $Token
    $script:PSUConnection.IsAzure = $isAzure
    $script:PSUConnection.ResourceGroup = $ResourceGroup
    $script:PSUConnection.WebAppName = $WebAppName

    # Return connection info
    [PSCustomObject]@{
        Url           = $Url
        Status        = 'Connected'
        IsAzure       = $isAzure
        ResourceGroup = $ResourceGroup
        WebAppName    = $WebAppName
    }
}

function Get-PSUModule {
    <#
    .SYNOPSIS
        Gets modules installed in PowerShell Universal.

    .DESCRIPTION
        Retrieves a list of all modules installed in the PSU instance,
        or a specific module by name.

    .PARAMETER Name
        Optional module name to filter by. Supports wildcards.

    .EXAMPLE
        Get-PSUModule
        # Lists all installed modules

    .EXAMPLE
        Get-PSUModule -Name "Devolutions.CIEM"
        # Gets a specific module
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Name
    )

    Assert-PSUConnection

    $headers = @{
        'Authorization' = "Bearer $($script:PSUConnection.Token)"
        'Accept'        = 'application/json'
    }

    $uri = "$($script:PSUConnection.Url)/api/v1/module"

    try {
        $modules = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
    }
    catch {
        throw "Failed to get modules: $_"
    }

    # Filter by name if specified
    if ($Name) {
        $modules = $modules | Where-Object { $_.name -like $Name }
    }

    $modules
}

function Remove-PSUModule {
    <#
    .SYNOPSIS
        Removes a module from PowerShell Universal.

    .DESCRIPTION
        Uninstalls a module from the PSU instance by name. For Azure-hosted PSU,
        this also removes the module files from the filesystem via the Kudu API.

        The PSU REST API DELETE endpoint only removes database entries, not files.
        For persistent removal, filesystem cleanup is required.

    .PARAMETER Name
        The name of the module to remove.

    .PARAMETER Version
        Specific version to remove. If not specified, removes all versions.

    .PARAMETER Force
        Skip confirmation prompt.

    .EXAMPLE
        Remove-PSUModule -Name "Devolutions.CIEM"
        # Removes all versions of the module

    .EXAMPLE
        Remove-PSUModule -Name "Devolutions.CIEM" -Version "0.2.18"
        # Removes a specific version

    .EXAMPLE
        Remove-PSUModule -Name "Devolutions.CIEM" -Force
        # Removes without confirmation
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter()]
        [string]$Version,

        [Parameter()]
        [switch]$Force
    )

    Assert-PSUConnection

    # Find the module(s) by name
    $modules = Get-PSUModule -Name $Name | Where-Object { $_.name -eq $Name }

    if (-not $modules) {
        throw "Module '$Name' not found in PSU."
    }

    # Filter by version if specified
    if ($Version) {
        $modules = $modules | Where-Object { $_.version -eq $Version }
        if (-not $modules) {
            throw "Module '$Name' version '$Version' not found in PSU."
        }
    }

    # Convert to array for consistent handling
    $modules = @($modules)

    $headers = @{
        'Authorization' = "Bearer $($script:PSUConnection.Token)"
        'Accept'        = 'application/json'
    }

    $targetDesc = if ($Version) { "$Name v$Version" } else { "$Name (all versions: $($modules.version -join ', '))" }

    # Early exit if user declines
    if (-not $Force -and -not $PSCmdlet.ShouldProcess($targetDesc, "Remove module")) {
        # User declined - no output
    }
    else {
        $results = @()

        # Remove each module entry via REST API
        foreach ($mod in $modules) {
            Write-Verbose "Removing $($mod.name) v$($mod.version) (ID: $($mod.id)) from PSU database..."
            $uri = "$($script:PSUConnection.Url)/api/v1/module/$($mod.id)"

            try {
                Invoke-RestMethod -Uri $uri -Headers $headers -Method Delete -ErrorAction Stop
                Write-Verbose "Database entry removed for $($mod.name) v$($mod.version)"
            }
            catch {
                Write-Warning "Failed to remove database entry for $($mod.name) v$($mod.version): $_"
            }
        }

        # For Azure, also remove the filesystem files via Kudu API
        if ($script:PSUConnection.IsAzure) {
            Write-Verbose "Azure hosting detected. Removing module files from filesystem..."

            $rg = $script:PSUConnection.ResourceGroup
            $webApp = $script:PSUConnection.WebAppName

            if (-not $rg -or -not $webApp) {
                Write-Warning "Azure resource group or webapp name not configured. Filesystem cleanup skipped."
            }
            else {
                # Get Kudu credentials
                try {
                    $azParams = @(
                        'webapp', 'deployment', 'list-publishing-profiles',
                        '--resource-group', $rg,
                        '--name', $webApp,
                        '--query', "[?publishMethod=='MSDeploy']",
                        '--output', 'json'
                    )
                    $publishProfile = az @azParams 2>$null | ConvertFrom-Json

                    if (-not $publishProfile) {
                        throw "Could not get publishing profile"
                    }

                    $kuduUser = $publishProfile[0].userName
                    $kuduPass = $publishProfile[0].userPWD
                    $kuduBase = "https://$webApp.scm.azurewebsites.net"

                    $kuduAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${kuduUser}:${kuduPass}"))

                    # Determine what to delete
                    $deletePath = if ($Version) {
                        "/home/Repository/Modules/$Name/$Version"
                    }
                    else {
                        "/home/Repository/Modules/$Name"
                    }

                    Write-Verbose "Deleting folder: $deletePath"

                    # Use Kudu command API for recursive delete (VFS API doesn't support recursive)
                    $cmdUri = "$kuduBase/api/command"
                    $cmdBody = @{
                        command = "rm -rf `"$deletePath`""
                        dir     = "/home"
                    } | ConvertTo-Json

                    $cmdHeaders = @{
                        'Authorization' = "Basic $kuduAuth"
                        'Content-Type'  = 'application/json'
                    }

                    $cmdResult = Invoke-RestMethod -Uri $cmdUri -Headers $cmdHeaders -Method Post -Body $cmdBody -ErrorAction Stop

                    if ($cmdResult.ExitCode -ne 0) {
                        throw "Command failed with exit code $($cmdResult.ExitCode): $($cmdResult.Error)"
                    }

                    $results += [PSCustomObject]@{
                        Name    = $Name
                        Version = if ($Version) { $Version } else { 'All' }
                        Status  = 'Removed'
                        Source  = 'Filesystem'
                    }

                    Write-Verbose "Filesystem cleanup completed successfully."
                }
                catch {
                    Write-Warning "Failed to remove module files from Azure filesystem: $_"
                    Write-Warning "You may need to manually delete: Repository/Modules/$Name/"
                }
            }
        }
        else {
            Write-Warning "Non-Azure PSU detected. REST API DELETE only removes database entries."
            Write-Warning "Module files may still exist on the PSU server filesystem."
        }

        # Sync configuration to clear PSU's in-memory module cache
        Write-Verbose "Syncing PSU configuration to clear module cache..."
        try {
            Sync-PSUConfiguration -Reset | Out-Null
            Write-Verbose "Configuration sync completed."
        }
        catch {
            Write-Warning "Failed to sync configuration: $_"
            Write-Warning "You may need to manually call: Sync-PSUConfiguration -Reset"
        }

        # Return summary
        if ($results.Count -eq 0) {
            [PSCustomObject]@{
                Name    = $Name
                Version = if ($Version) { $Version } else { 'All' }
                Status  = 'RemovedFromDatabase'
                Note    = 'Filesystem cleanup may be required'
            }
        }
        else {
            $results
        }
    }
}

function Sync-PSUConfiguration {
    <#
    .SYNOPSIS
        Synchronizes PSU configuration and clears in-memory caches.

    .DESCRIPTION
        Calls the PSU configuration sync API to reload configuration files
        and clear in-memory caches. Use -Reset for a complete reset similar
        to restarting the service.

    .PARAMETER Reset
        Perform a complete reset, similar to restarting the PSU service.
        This clears all in-memory state including cached module information.

    .EXAMPLE
        Sync-PSUConfiguration
        # Reloads configuration files

    .EXAMPLE
        Sync-PSUConfiguration -Reset
        # Complete reset, clears all caches
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$Reset
    )

    Assert-PSUConnection

    $headers = @{
        'Authorization' = "Bearer $($script:PSUConnection.Token)"
        'Accept'        = 'application/json'
    }

    $uri = "$($script:PSUConnection.Url)/api/v1/configuration"
    if ($Reset) {
        $uri += "?reset=true"
    }

    Write-Verbose "Syncing PSU configuration (Reset: $Reset)..."

    try {
        Invoke-RestMethod -Uri $uri -Headers $headers -Method Post -ErrorAction Stop
        Write-Verbose "Configuration sync completed."

        [PSCustomObject]@{
            Status = 'Synced'
            Reset  = $Reset.IsPresent
        }
    }
    catch {
        throw "Failed to sync configuration: $_"
    }
}

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
        Skip the configuration sync after installing. By default, configuration
        is synced to ensure the module is immediately available.

    .EXAMPLE
        Install-PSUModule -Name "Devolutions.CIEM"
        # Installs the latest version from PSGallery

    .EXAMPLE
        Install-PSUModule -Name "Devolutions.CIEM" -Version "0.2.21"
        # Installs a specific version

    .EXAMPLE
        Install-PSUModule -Name "Az.Accounts" -NoSync
        # Installs without triggering a configuration sync
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
        'Authorization' = "Bearer $($script:PSUConnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/json'
    }

    # If no version specified, find the latest version
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

        # Find exact match (search may return partial matches)
        $exactMatch = $searchResults | Where-Object { $_.name -eq $Name } | Select-Object -First 1

        if (-not $exactMatch) {
            throw "Module '$Name' not found in $Repository. Found similar: $($searchResults.name -join ', ')"
        }

        $Version = $exactMatch.version
        Write-Verbose "Found latest version: $Version"
    }

    # Build request body
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

    # Sync configuration to ensure module is loaded
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

    # Return result
    [PSCustomObject]@{
        Name       = $Name
        Version    = $Version
        Repository = $Repository
        Status     = 'Installed'
    }
}

function Get-PSUApp {
    <#
    .SYNOPSIS
        Gets apps (dashboards) from PowerShell Universal.

    .DESCRIPTION
        Retrieves a list of all apps in the PSU instance, or a specific app by name.
        In PSU v5, apps and dashboards are the same thing.

    .PARAMETER Name
        Optional app name to filter by. Supports wildcards.

    .PARAMETER Id
        Optional app ID to retrieve directly.

    .EXAMPLE
        Get-PSUApp
        # Lists all apps

    .EXAMPLE
        Get-PSUApp -Name "CIEM"
        # Gets a specific app by name

    .EXAMPLE
        Get-PSUApp -Id 2
        # Gets a specific app by ID
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(ParameterSetName = 'ByName')]
        [string]$Name,

        [Parameter(ParameterSetName = 'ById')]
        [int]$Id
    )

    Assert-PSUConnection

    $headers = @{
        'Authorization' = "Bearer $($script:PSUConnection.Token)"
        'Accept'        = 'application/json'
    }

    if ($PSCmdlet.ParameterSetName -eq 'ById') {
        $uri = "$($script:PSUConnection.Url)/api/v1/dashboard/$Id"
        try {
            Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
        }
        catch {
            throw "Failed to get app with ID $Id. Error: $_"
        }
    }
    else {
        $uri = "$($script:PSUConnection.Url)/api/v1/dashboard"
        try {
            $apps = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
        }
        catch {
            throw "Failed to get apps. Error: $_"
        }

        # Filter by name if specified
        if ($Name) {
            $apps = $apps | Where-Object { $_.name -like $Name }
        }

        $apps
    }
}

function Start-PSUApp {
    <#
    .SYNOPSIS
        Starts a PowerShell Universal app.

    .DESCRIPTION
        Starts a stopped PSU app (dashboard). The app must exist and be in a stopped state.

    .PARAMETER Name
        The name of the app to start.

    .PARAMETER Id
        The ID of the app to start.

    .PARAMETER PassThru
        Return the app object after starting.

    .EXAMPLE
        Start-PSUApp -Name "CIEM"
        # Starts the CIEM app

    .EXAMPLE
        Start-PSUApp -Id 2 -PassThru
        # Starts app ID 2 and returns the app object
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName', SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName', Position = 0)]
        [string]$Name,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [int]$Id,

        [Parameter()]
        [switch]$PassThru
    )

    Assert-PSUConnection

    # Resolve app ID if name was provided
    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $app = Get-PSUApp -Name $Name | Where-Object { $_.name -eq $Name }
        if (-not $app) {
            throw "App '$Name' not found."
        }
        if (@($app).Count -gt 1) {
            throw "Multiple apps found matching '$Name'. Use -Id to specify."
        }
        $Id = $app.id
        $appName = $app.name
    }
    else {
        $app = Get-PSUApp -Id $Id
        $appName = $app.name
    }

    $headers = @{
        'Authorization' = "Bearer $($script:PSUConnection.Token)"
        'Accept'        = 'application/json'
    }

    $uri = "$($script:PSUConnection.Url)/api/v1/dashboard/$Id/status"

    if ($PSCmdlet.ShouldProcess($appName, "Start PSU app")) {
        Write-Verbose "Starting app '$appName' (ID: $Id)..."

        try {
            $null = Invoke-RestMethod -Uri $uri -Headers $headers -Method Put -ErrorAction Stop
            Write-Verbose "App started successfully."
        }
        catch {
            throw "Failed to start app '$appName'. Error: $_"
        }

        if ($PassThru.IsPresent) {
            Get-PSUApp -Id $Id
        }
        else {
            [PSCustomObject]@{
                Id     = $Id
                Name   = $appName
                Status = 'Started'
            }
        }
    }
}

function Stop-PSUApp {
    <#
    .SYNOPSIS
        Stops a PowerShell Universal app.

    .DESCRIPTION
        Stops a running PSU app (dashboard). The app must exist and be in a running state.

    .PARAMETER Name
        The name of the app to stop.

    .PARAMETER Id
        The ID of the app to stop.

    .PARAMETER PassThru
        Return the app object after stopping.

    .EXAMPLE
        Stop-PSUApp -Name "CIEM"
        # Stops the CIEM app

    .EXAMPLE
        Stop-PSUApp -Id 2
        # Stops app ID 2
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName', SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName', Position = 0)]
        [string]$Name,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [int]$Id,

        [Parameter()]
        [switch]$PassThru
    )

    Assert-PSUConnection

    # Resolve app ID if name was provided
    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $app = Get-PSUApp -Name $Name | Where-Object { $_.name -eq $Name }
        if (-not $app) {
            throw "App '$Name' not found."
        }
        if (@($app).Count -gt 1) {
            throw "Multiple apps found matching '$Name'. Use -Id to specify."
        }
        $Id = $app.id
        $appName = $app.name
    }
    else {
        $app = Get-PSUApp -Id $Id
        $appName = $app.name
    }

    $headers = @{
        'Authorization' = "Bearer $($script:PSUConnection.Token)"
        'Accept'        = 'application/json'
    }

    $uri = "$($script:PSUConnection.Url)/api/v1/dashboard/$Id/status"

    if ($PSCmdlet.ShouldProcess($appName, "Stop PSU app")) {
        Write-Verbose "Stopping app '$appName' (ID: $Id)..."

        try {
            $null = Invoke-RestMethod -Uri $uri -Headers $headers -Method Delete -ErrorAction Stop
            Write-Verbose "App stopped successfully."
        }
        catch {
            throw "Failed to stop app '$appName'. Error: $_"
        }

        if ($PassThru.IsPresent) {
            Get-PSUApp -Id $Id
        }
        else {
            [PSCustomObject]@{
                Id     = $Id
                Name   = $appName
                Status = 'Stopped'
            }
        }
    }
}

function Restart-PSUApp {
    <#
    .SYNOPSIS
        Restarts a PowerShell Universal app.

    .DESCRIPTION
        Restarts a PSU app (dashboard). This is useful after making changes to
        the app or its dependencies.

    .PARAMETER Name
        The name of the app to restart.

    .PARAMETER Id
        The ID of the app to restart.

    .PARAMETER PassThru
        Return the app object after restarting.

    .EXAMPLE
        Restart-PSUApp -Name "CIEM"
        # Restarts the CIEM app

    .EXAMPLE
        Restart-PSUApp -Id 2 -PassThru
        # Restarts app ID 2 and returns the app object
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByName', SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName', Position = 0)]
        [string]$Name,

        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [int]$Id,

        [Parameter()]
        [switch]$PassThru
    )

    Assert-PSUConnection

    # Resolve app ID if name was provided
    if ($PSCmdlet.ParameterSetName -eq 'ByName') {
        $app = Get-PSUApp -Name $Name | Where-Object { $_.name -eq $Name }
        if (-not $app) {
            throw "App '$Name' not found."
        }
        if (@($app).Count -gt 1) {
            throw "Multiple apps found matching '$Name'. Use -Id to specify."
        }
        $Id = $app.id
        $appName = $app.name
    }
    else {
        $app = Get-PSUApp -Id $Id
        $appName = $app.name
    }

    $headers = @{
        'Authorization' = "Bearer $($script:PSUConnection.Token)"
        'Accept'        = 'application/json'
    }

    $uri = "$($script:PSUConnection.Url)/api/v1/dashboard/$Id/status/restart"

    if ($PSCmdlet.ShouldProcess($appName, "Restart PSU app")) {
        Write-Verbose "Restarting app '$appName' (ID: $Id)..."

        try {
            # Use a timeout to prevent hanging if the restart takes too long
            # The restart endpoint may wait for the app to fully restart before returning
            $null = Invoke-RestMethod -Uri $uri -Headers $headers -Method Put -TimeoutSec 30 -ErrorAction Stop
            Write-Verbose "App restarted successfully."
        }
        catch [System.Threading.Tasks.TaskCanceledException] {
            # Timeout occurred - the restart was likely initiated but took too long to confirm
            Write-Verbose "Restart request timed out after 30s. The app restart may still be in progress."
        }
        catch {
            throw "Failed to restart app '$appName'. Error: $_"
        }

        if ($PassThru.IsPresent) {
            Get-PSUApp -Id $Id
        }
        else {
            [PSCustomObject]@{
                Id     = $Id
                Name   = $appName
                Status = 'Restarted'
            }
        }
    }
}

function Publish-PSUModule {
    <#
    .SYNOPSIS
        Publishes a PowerShell module to the PowerShell Gallery.

    .DESCRIPTION
        Automatically bumps the version and publishes a module to PowerShell Gallery.
        Modules with the 'PowerShellUniversal' tag appear in the PSU Gallery.

        Optionally imports the published module to a connected PSU instance.

    .PARAMETER ModulePath
        Path to the module directory. Required.

    .PARAMETER NuGetApiKey
        PowerShell Gallery API key. If not provided, checks NUGET_API_KEY from
        environment variable or .env file.

    .PARAMETER BumpVersion
        Version component to increment: Patch (default), Minor, or Major.
        - Patch: 0.2.0 -> 0.2.1
        - Minor: 0.2.0 -> 0.3.0
        - Major: 0.2.0 -> 1.0.0

    .PARAMETER SkipValidation
        Skip module structure validation (not recommended).

    .PARAMETER EnvFilePath
        Path to .env file for loading NuGetApiKey. Defaults to .env in module
        parent directory.

    .EXAMPLE
        Publish-PSUModule -ModulePath ./Devolutions.CIEM
        # Bumps patch version and publishes

    .EXAMPLE
        Publish-PSUModule -ModulePath ./Devolutions.CIEM -BumpVersion Minor
        # Bumps minor version and publishes

    .PARAMETER LocalOnly
        Skip PowerShell Gallery publishing entirely and import the module
        directly to a local PSU instance. This:
        - Skips version bump (no PSGallery versioning needed)
        - Skips publishing to PowerShell Gallery
        - Connects to local PSU using Connect-PSU -Local
        - Imports the module to local PSU using Install-PSUModule

    .EXAMPLE
        Publish-PSUModule -ModulePath ./Devolutions.CIEM -WhatIf
        # Shows what would be published without actually publishing

    .EXAMPLE
        Publish-PSUModule -ModulePath ./Devolutions.CIEM -LocalOnly
        # Imports the module directly to a local PSU instance (no PSGallery)
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'CLI tooling requires colored user feedback for step progress and status messages')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$ModulePath,

        [Parameter()]
        [string]$NuGetApiKey,

        [Parameter()]
        [ValidateSet('Patch', 'Minor', 'Major')]
        [string]$BumpVersion = 'Patch',

        [Parameter()]
        [switch]$SkipValidation,

        [Parameter()]
        [string]$EnvFilePath,

        [Parameter()]
        [switch]$LocalOnly
    )

    $ErrorActionPreference = 'Stop'

    # Resolve module path
    $ModulePath = Resolve-Path $ModulePath -ErrorAction Stop | Select-Object -ExpandProperty Path

    # Find manifest
    $moduleName = Split-Path $ModulePath -Leaf
    $manifestPath = Join-Path $ModulePath "$moduleName.psd1"

    if (-not (Test-Path $manifestPath)) {
        throw "Module manifest not found: $manifestPath"
    }

    # ========================================================================
    # LocalOnly Mode: Skip PSGallery entirely, import to local PSU
    # ========================================================================
    if ($LocalOnly) {
        Write-Host '========================================' -ForegroundColor Cyan
        Write-Host "Importing $moduleName to Local PSU" -ForegroundColor Cyan
        Write-Host '========================================' -ForegroundColor Cyan
        Write-Host "Module: $ModulePath"
        Write-Host ''

        # Step 1: Connect to local PSU
        Write-Host 'Step 1: Connecting to local PSU...' -ForegroundColor Yellow
        try {
            $null = Connect-PSU -Local -ErrorAction Stop
            Write-Host '  [OK] Connected to local PSU' -ForegroundColor Green
        }
        catch {
            throw "Failed to connect to local PSU: $_"
        }

        # Step 2: Copy local module files to local PSU
        Write-Host ''
        Write-Host 'Step 2: Installing module to local PSU...' -ForegroundColor Yellow

        if ($PSCmdlet.ShouldProcess($moduleName, "Install to local PSU")) {
            $manifest = Import-PowerShellDataFile -Path $manifestPath
            $moduleVersion = $manifest.ModuleVersion
            $projectRoot = Split-Path $ModulePath -Parent
            $localPsuModulesDir = Join-Path $projectRoot 'local-psu' 'Repository' 'Modules'
            $targetModuleDir = Join-Path $localPsuModulesDir $moduleName

            if (-not (Test-Path $localPsuModulesDir)) {
                throw "Local PSU modules directory not found: $localPsuModulesDir"
            }

            # Remove all existing versions of this module
            if (Test-Path $targetModuleDir) {
                Write-Verbose "Removing existing module at: $targetModuleDir"
                Remove-Item -Path $targetModuleDir -Recurse -Force
            }

            # Copy local files to versioned directory
            $targetVersionDir = Join-Path $targetModuleDir $moduleVersion
            Write-Verbose "Copying module to: $targetVersionDir"
            Copy-Item -Path $ModulePath -Destination $targetVersionDir -Recurse -Force

            Write-Host "  [OK] Module installed: $moduleName v$moduleVersion" -ForegroundColor Green

            # Step 3: Restart app if defined by this module
            $dashboardsPath = Join-Path -Path $ModulePath -ChildPath '.universal' -AdditionalChildPath 'dashboards.ps1'
            if (Test-Path $dashboardsPath) {
                $dashboardContent = Get-Content $dashboardsPath -Raw
                if ($dashboardContent -match "New-PSUApp\s+-Name\s+'([^']+)'") {
                    $appName = $matches[1]
                    Write-Host ''
                    Write-Host 'Step 3: Restarting app...' -ForegroundColor Yellow
                    try {
                        Restart-PSUApp -Name $appName
                        Write-Host "  [OK] App '$appName' restarted" -ForegroundColor Green
                    }
                    catch {
                        Write-Host "  [WARN] Could not restart app '$appName': $_" -ForegroundColor Yellow
                    }
                }
            }

            Write-Host ''
            Write-Host '========================================' -ForegroundColor Cyan
            Write-Host 'Local Import Successful!' -ForegroundColor Green
            Write-Host '========================================' -ForegroundColor Cyan

            return [PSCustomObject]@{
                ModuleName = $moduleName
                Version    = $moduleVersion
                GalleryUrl = $null
                UpdatedPSU = $true
                Status     = 'LocalImport'
            }
        }
        else {
            Write-Host ''
            $manifest = Import-PowerShellDataFile -Path $manifestPath
            Write-Host '[DRY RUN] Would import to local PSU:' -ForegroundColor Yellow
            Write-Host "  Module: $moduleName"
            Write-Host "  Version: $($manifest.ModuleVersion)"
            Write-Host "  Path: $ModulePath"

            return [PSCustomObject]@{
                ModuleName = $moduleName
                Version    = $manifest.ModuleVersion
                GalleryUrl = $null
                UpdatedPSU = $false
                Status     = 'DryRun'
            }
        }
    }

    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host "Publishing $moduleName to PowerShell Gallery" -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host "Module: $ModulePath"
    Write-Host ''

    # ========================================================================
    # Step 1: Validate Module Structure
    # ========================================================================
    if (-not $SkipValidation) {
        Write-Host 'Step 1: Validating module structure...' -ForegroundColor Yellow

        $requiredFiles = @(
            "$moduleName.psm1"
        )

        foreach ($file in $requiredFiles) {
            $fullPath = Join-Path $ModulePath $file
            if (Test-Path $fullPath) {
                Write-Host "  [OK] $file" -ForegroundColor Green
            }
            else {
                throw "Missing required file: $file"
            }
        }

        # Check for PSU-specific files (optional but noted)
        $psuFiles = @('.universal/dashboards.ps1', 'config.json')
        foreach ($file in $psuFiles) {
            $fullPath = Join-Path $ModulePath $file
            if (Test-Path $fullPath) {
                Write-Host "  [OK] $file (PSU)" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host 'Step 1: Skipping validation...' -ForegroundColor Yellow
    }

    # ========================================================================
    # Step 2: Query Gallery and Calculate New Version
    # ========================================================================
    Write-Host ''
    Write-Host 'Step 2: Querying PowerShell Gallery for current version...' -ForegroundColor Yellow

    $manifest = Import-PowerShellDataFile -Path $manifestPath
    $localVersion = [version]$manifest.ModuleVersion
    Write-Host "  Local manifest version: $localVersion" -ForegroundColor Gray

    # Query PowerShell Gallery for the published version
    $galleryVersion = $null
    try {
        $existing = Find-Module -Name $moduleName -AllowPrerelease -ErrorAction SilentlyContinue
        if ($existing) {
            # Handle prerelease versions (e.g., "0.2.23-beta" -> "0.2.23")
            $versionString = $existing.Version -replace '-.*$', ''
            $galleryVersion = [version]$versionString
            Write-Host "  Gallery version: $galleryVersion" -ForegroundColor Cyan
        }
        else {
            Write-Host '  Gallery version: Not published yet (first release)' -ForegroundColor Cyan
        }
    }
    catch {
        Write-Host '  Gallery version: Not published yet (first release)' -ForegroundColor Cyan
    }

    # Use the higher of gallery or local version as the base
    if ($galleryVersion) {
        $baseVersion = if ($galleryVersion -gt $localVersion) { $galleryVersion } else { $localVersion }
        Write-Host "  Base version for bump: $baseVersion" -ForegroundColor Gray
    }
    else {
        $baseVersion = $localVersion
        Write-Host "  Base version for bump: $baseVersion (local)" -ForegroundColor Gray
    }

    # Calculate new version
    $newVersion = switch ($BumpVersion) {
        'Major' { [version]::new($baseVersion.Major + 1, 0, 0) }
        'Minor' { [version]::new($baseVersion.Major, $baseVersion.Minor + 1, 0) }
        'Patch' { [version]::new($baseVersion.Major, $baseVersion.Minor, $baseVersion.Build + 1) }
    }

    Write-Host "  New version: $newVersion ($BumpVersion bump)" -ForegroundColor Green

    # Update the manifest file
    $manifestContent = Get-Content -Path $manifestPath -Raw
    $updatedContent = $manifestContent -replace "ModuleVersion\s*=\s*'[^']*'", "ModuleVersion = '$newVersion'"

    if ($PSCmdlet.ShouldProcess($manifestPath, "Update ModuleVersion to $newVersion")) {
        Set-Content -Path $manifestPath -Value $updatedContent -NoNewline
        Write-Host "  [OK] Updated $manifestPath" -ForegroundColor Green
    }

    # Re-read manifest to get updated values
    $manifest = Import-PowerShellDataFile -Path $manifestPath
    $tags = $manifest.PrivateData.PSData.Tags
    if ($tags) {
        Write-Host "  [OK] Tags: $($tags -join ', ')" -ForegroundColor Green
    }

    # ========================================================================
    # Step 3: Get API Key
    # ========================================================================
    Write-Host ''
    Write-Host 'Step 3: Checking API key...' -ForegroundColor Yellow

    if (-not $NuGetApiKey) {
        $NuGetApiKey = $env:NUGET_API_KEY
    }

    # Try to load from .env file if not set
    if (-not $NuGetApiKey) {
        if (-not $EnvFilePath) {
            $projectRoot = Split-Path $ModulePath -Parent
            $EnvFilePath = Join-Path $projectRoot '.env'
        }

        if (Test-Path $EnvFilePath) {
            Write-Host "  Loading from .env file..." -ForegroundColor Gray
            $envContent = Get-Content $EnvFilePath -ErrorAction SilentlyContinue
            foreach ($line in $envContent) {
                if ($line -match '^NUGET_API_KEY=(.+)$') {
                    $NuGetApiKey = $Matches[1].Trim()
                    break
                }
            }
        }
    }

    if (-not $NuGetApiKey) {
        throw @"
NuGet API key required. Options:
  1. Pass as parameter: -NuGetApiKey 'your-key'
  2. Set environment variable: `$env:NUGET_API_KEY = 'your-key'
  3. Add NUGET_API_KEY=your-key to .env file
  4. Get a key from: https://www.powershellgallery.com/account/apikeys
"@
    }

    Write-Host '  [OK] API key provided' -ForegroundColor Green

    # ========================================================================
    # Step 4: Prepare Version String
    # ========================================================================
    Write-Host ''
    Write-Host 'Step 4: Preparing to publish...' -ForegroundColor Yellow

    $moduleVersion = $newVersion.ToString()
    if ($manifest.PrivateData.PSData.Prerelease) {
        $fullVersion = "$moduleVersion-$($manifest.PrivateData.PSData.Prerelease)"
    }
    else {
        $fullVersion = $moduleVersion
    }

    Write-Host "  [OK] Will publish version: $fullVersion" -ForegroundColor Green

    # ========================================================================
    # Step 5: Publish to PowerShell Gallery
    # ========================================================================
    Write-Host ''
    Write-Host 'Step 5: Publishing to PowerShell Gallery...' -ForegroundColor Yellow
    Write-Host '  Using Publish-PSResource (PSResourceGet) to include hidden directories' -ForegroundColor Gray

    if ($PSCmdlet.ShouldProcess($moduleName, "Publish version $fullVersion to PowerShell Gallery")) {
        $publishParams = @{
            Path        = $ModulePath
            ApiKey      = $NuGetApiKey
            Repository  = 'PSGallery'
            ErrorAction = 'Stop'
        }

        Publish-PSResource @publishParams

        # ====================================================================
        # Step 6: Verify Publication
        # ====================================================================
        Write-Host ''
        Write-Host 'Step 6: Verifying publication...' -ForegroundColor Yellow

        $maxRetries = 6
        $retryDelay = 10
        $verified = $false

        for ($i = 1; $i -le $maxRetries; $i++) {
            Write-Host "  Checking PowerShell Gallery (attempt $i/$maxRetries)..." -ForegroundColor Gray
            $published = Find-Module -Name $moduleName -AllowPrerelease -ErrorAction SilentlyContinue
            if ($published -and $published.Version -eq $fullVersion) {
                $verified = $true
                break
            }
            if ($i -lt $maxRetries) {
                Write-Host "  Not found yet, waiting ${retryDelay}s..." -ForegroundColor Gray
                Start-Sleep -Seconds $retryDelay
            }
        }

        if ($verified) {
            Write-Host "  [OK] Verified: $moduleName $fullVersion is available" -ForegroundColor Green
        }
        else {
            Write-Host "  [WARN] Could not verify within $($maxRetries * $retryDelay)s" -ForegroundColor Yellow
            Write-Host "  The module may still be propagating." -ForegroundColor Yellow
        }

        # ====================================================================
        # Step 7: Update PSU (always - auto-connect if needed)
        # ====================================================================
        $updatedPSU = $false
        Write-Host ''
        Write-Host 'Step 7: Updating PSU server...' -ForegroundColor Yellow

        # Auto-connect to PSU if not already connected
        if (-not $script:PSUConnection.Url) {
            Write-Host '  Not connected to PSU. Attempting auto-connect...' -ForegroundColor Gray
            try {
                $null = Connect-PSU -ErrorAction Stop
                Write-Host '  [OK] Connected to PSU' -ForegroundColor Green
            }
            catch {
                Write-Host "  [WARN] Could not auto-connect to PSU: $_" -ForegroundColor Yellow
                Write-Host '  Ensure AZURE_PSU_URL and AZURE_PSU_TOKEN are set in .env file' -ForegroundColor Gray
            }
        }

        if ($script:PSUConnection.Url) {
            try {
                Write-Host "  Importing $moduleName $fullVersion to PSU..." -ForegroundColor Gray
                Install-PSUModule -Name $moduleName -Version $fullVersion -NoSync
                Write-Host "  [OK] Module imported" -ForegroundColor Green
                $updatedPSU = $true

                # Find and restart the app defined by this module
                $dashboardsPath = Join-Path -Path $ModulePath -ChildPath '.universal' -AdditionalChildPath 'dashboards.ps1'
                if (Test-Path $dashboardsPath) {
                    $dashboardContent = Get-Content $dashboardsPath -Raw
                    if ($dashboardContent -match "New-PSUApp\s+-Name\s+'([^']+)'") {
                        $appName = $matches[1]
                        Write-Host "  Restarting app '$appName'..." -ForegroundColor Gray
                        try {
                            Restart-PSUApp -Name $appName
                            Write-Host "  [OK] App restarted" -ForegroundColor Green
                        }
                        catch {
                            Write-Host "  [WARN] Could not restart app: $_" -ForegroundColor Yellow
                        }
                    }
                }
            }
            catch {
                Write-Host "  [ERROR] Failed to update PSU: $_" -ForegroundColor Red
            }
        }

        Write-Host ''
        Write-Host '========================================' -ForegroundColor Cyan
        Write-Host 'Publication Successful!' -ForegroundColor Green
        Write-Host '========================================' -ForegroundColor Cyan

        # Return result object
        [PSCustomObject]@{
            ModuleName  = $moduleName
            Version     = $fullVersion
            GalleryUrl  = "https://www.powershellgallery.com/packages/$moduleName"
            UpdatedPSU  = $updatedPSU
            Status      = 'Published'
        }
    }
    else {
        Write-Host ''
        Write-Host '[DRY RUN] Would publish:' -ForegroundColor Yellow
        Write-Host "  Module: $moduleName"
        Write-Host "  Current version: $currentVersion"
        Write-Host "  New version: $fullVersion"
        Write-Host "  Path: $ModulePath"

        [PSCustomObject]@{
            ModuleName  = $moduleName
            Version     = $fullVersion
            GalleryUrl  = "https://www.powershellgallery.com/packages/$moduleName"
            UpdatedPSU  = $false
            Status      = 'DryRun'
        }
    }
}

function Invoke-PSUCommand {
    <#
    .SYNOPSIS
        Executes a PowerShell command on the PSU server and returns the output.

    .DESCRIPTION
        Creates a temporary script on the PSU server, executes it, waits for completion,
        retrieves the output, and cleans up the temporary script. This is useful for
        debugging and running ad-hoc commands on the PSU server.

    .PARAMETER Command
        The PowerShell command to execute as a string.

    .PARAMETER ScriptBlock
        The PowerShell command to execute as a script block.

    .PARAMETER TimeoutSeconds
        Maximum time to wait for the command to complete. Defaults to 120 seconds.

    .PARAMETER KeepScript
        If specified, does not delete the temporary script after execution.
        Useful for debugging.

    .PARAMETER Environment
        The PSU environment to run the script in. If not specified, uses the default.

    .EXAMPLE
        Invoke-PSUCommand -Command 'Get-Module -ListAvailable'
        # Lists available modules on the PSU server

    .EXAMPLE
        Invoke-PSUCommand -Command 'Import-Module Devolutions.CIEM -Verbose' -TimeoutSeconds 60
        # Imports a module with verbose output

    .EXAMPLE
        Invoke-PSUCommand -ScriptBlock { Get-Process | Select-Object -First 5 }
        # Gets first 5 processes from PSU server

    .EXAMPLE
        Connect-PSU
        Invoke-PSUCommand -Command '$PSVersionTable'
        # Shows PowerShell version on the PSU server
    #>
    [CmdletBinding(DefaultParameterSetName = 'Command')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'CLI tooling requires visual output for command results')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Command', Position = 0)]
        [string]$Command,

        [Parameter(Mandatory, ParameterSetName = 'ScriptBlock')]
        [scriptblock]$ScriptBlock,

        [Parameter()]
        [int]$TimeoutSeconds = 120,

        [Parameter()]
        [switch]$KeepScript,

        [Parameter()]
        [string]$Environment
    )

    # Auto-connect if not connected
    if (-not $script:PSUConnection.Url -or -not $script:PSUConnection.Token) {
        Write-Verbose "Not connected to PSU. Attempting auto-connect..."
        try {
            $null = Connect-PSU -ErrorAction Stop
            Write-Verbose "Connected to PSU."
        }
        catch {
            throw "Not connected to PSU and auto-connect failed: $_"
        }
    }

    # Convert ScriptBlock to Command string if needed
    if ($PSCmdlet.ParameterSetName -eq 'ScriptBlock') {
        $Command = $ScriptBlock.ToString()
    }

    $headers = @{
        'Authorization' = "Bearer $($script:PSUConnection.Token)"
        'Accept'        = 'application/json'
        'Content-Type'  = 'application/json'
    }

    $baseUrl = $script:PSUConnection.Url
    $scriptId = $null
    $jobId = $null

    try {
        # ====================================================================
        # Step 1: Create a temporary script
        # ====================================================================
        $scriptName = "InvokePSUCommand_$(Get-Date -Format 'yyyyMMdd_HHmmss')_$([guid]::NewGuid().ToString('N').Substring(0, 8)).ps1"

        Write-Verbose "Creating temporary script: $scriptName"

        $scriptBody = @{
            name        = $scriptName
            fullPath    = $scriptName
            content     = $Command
            description = 'Temporary script created by Invoke-PSUCommand'
            maxHistory  = 1
        }

        if ($Environment) {
            $scriptBody.environment = $Environment
        }

        $scriptJson = $scriptBody | ConvertTo-Json -Depth 10

        $createScriptUri = "$baseUrl/api/v1/script"
        $script = Invoke-RestMethod -Uri $createScriptUri -Headers $headers -Method Post -Body $scriptJson -ErrorAction Stop
        $scriptId = $script.id

        Write-Verbose "Created script with ID: $scriptId"

        # ====================================================================
        # Step 2: Invoke the script
        # ====================================================================
        Write-Verbose "Invoking script..."

        $invokeUri = "$baseUrl/api/v1/script/$scriptId"
        $invokeBody = @{} | ConvertTo-Json

        $jobResponse = Invoke-RestMethod -Uri $invokeUri -Headers $headers -Method Post -Body $invokeBody -ErrorAction Stop

        # The API returns just the job ID as an integer
        if ($jobResponse -is [int] -or $jobResponse -is [long]) {
            $jobId = $jobResponse
        }
        elseif ($jobResponse.id) {
            $jobId = $jobResponse.id
        }
        else {
            throw "Unexpected job response format: $($jobResponse | ConvertTo-Json -Compress)"
        }

        Write-Verbose "Started job with ID: $jobId"

        # ====================================================================
        # Step 3: Poll for job completion
        # ====================================================================
        Write-Verbose "Waiting for job to complete (timeout: ${TimeoutSeconds}s)..."

        $startTime = Get-Date
        $jobStatus = $null
        # PSU Job Status enum: 0=Queued, 1=Running, 2=Completed, 3=Failed, 4=WaitingOnFeedback,
        # 5=Canceled, 6=Canceling, 7=Historical, 8=Active, 9=TimedOut, 10=Warning
        $terminalStatuses = @(2, 3, 5, 9, 10)  # Completed, Failed, Canceled, TimedOut, Warning
        $statusNames = @{
            0  = 'Queued'
            1  = 'Running'
            2  = 'Completed'
            3  = 'Failed'
            4  = 'WaitingOnFeedback'
            5  = 'Canceled'
            6  = 'Canceling'
            7  = 'Historical'
            8  = 'Active'
            9  = 'TimedOut'
            10 = 'Warning'
        }

        do {
            Start-Sleep -Milliseconds 500

            $jobUri = "$baseUrl/api/v1/job/$jobId"
            $jobDetails = Invoke-RestMethod -Uri $jobUri -Headers $headers -Method Get -ErrorAction Stop
            $jobStatus = [int]$jobDetails.status
            $statusName = $statusNames[$jobStatus]

            $elapsed = (Get-Date) - $startTime
            if ($elapsed.TotalSeconds -ge $TimeoutSeconds) {
                Write-Warning "Job timed out after ${TimeoutSeconds}s. Status: $statusName"
                break
            }

            Write-Verbose "Job status: $statusName (elapsed: $([math]::Round($elapsed.TotalSeconds, 1))s)"

        } while ($jobStatus -notin $terminalStatuses)

        $finalStatusName = $statusNames[$jobStatus]
        Write-Verbose "Job completed with status: $finalStatusName"

        # ====================================================================
        # Step 4: Get job output
        # ====================================================================
        $outputUri = "$baseUrl/api/v1/job/$jobId/output"
        $output = Invoke-RestMethod -Uri $outputUri -Headers $headers -Method Get -ErrorAction Stop

        # Also get pipeline output if available
        $pipelineUri = "$baseUrl/api/v1/job/$jobId/pipelineOutput"
        $pipelineOutput = $null
        try {
            $pipelineOutput = Invoke-RestMethod -Uri $pipelineUri -Headers $headers -Method Get -ErrorAction SilentlyContinue
        }
        catch {
            Write-Verbose "No pipeline output available or error retrieving it."
        }

        # Build result object
        $result = [PSCustomObject]@{
            JobId          = $jobId
            ScriptId       = $scriptId
            Status         = $finalStatusName
            Output         = $output
            PipelineOutput = $pipelineOutput
            StartTime      = $jobDetails.startTime
            EndTime        = $jobDetails.endTime
        }

        # Format and return output
        if ($output) {
            Write-Host "`n--- Command Output ---" -ForegroundColor Cyan
            $output | ForEach-Object {
                if ($_ -is [string]) {
                    Write-Host $_
                }
                elseif ($_.message) {
                    # PSU output format has 'message' field with actual output
                    Write-Host $_.message
                }
                elseif ($_.data) {
                    Write-Host $_.data
                }
                else {
                    Write-Host ($_ | Out-String)
                }
            }
            Write-Host "--- End Output ---`n" -ForegroundColor Cyan
        }

        if ($pipelineOutput) {
            Write-Verbose "Pipeline output available. Access via result.PipelineOutput"
        }

        $result
    }
    catch {
        throw "Failed to execute command on PSU: $_"
    }
    finally {
        # ====================================================================
        # Step 5: Clean up temporary script (unless -KeepScript)
        # ====================================================================
        if ($scriptId -and -not $KeepScript) {
            Write-Verbose "Cleaning up temporary script (ID: $scriptId)..."
            try {
                $deleteUri = "$baseUrl/api/v1/script/$scriptId"
                $null = Invoke-RestMethod -Uri $deleteUri -Headers $headers -Method Delete -ErrorAction SilentlyContinue
                Write-Verbose "Temporary script deleted."
            }
            catch {
                Write-Warning "Failed to delete temporary script: $_"
            }
        }
        elseif ($KeepScript -and $scriptId) {
            Write-Verbose "Keeping temporary script (ID: $scriptId, Name: $scriptName)"
        }
    }
}

function Assert-PSUConnection {
    <#
    .SYNOPSIS
        Validates that a PSU connection exists.

    .DESCRIPTION
        Checks the module-level connection state to ensure a valid connection
        to PowerShell Universal has been established via Connect-PSU. Throws
        a terminating error if no connection exists.

        This function is called internally by other PSU cmdlets to ensure
        a connection is available before making API calls.

    .OUTPUTS
        None. This function returns nothing on success and throws on failure.

    .EXAMPLE
        Assert-PSUConnection
        # Throws if not connected, returns nothing if connected
    #>
    [CmdletBinding()]
    param()

    if (-not $script:PSUConnection.Url -or -not $script:PSUConnection.Token) {
        throw "Not connected to PSU. Run Connect-PSU first."
    }
}

# Export all public functions (those starting with approved verbs)
Export-ModuleMember -Function *-PSU*
