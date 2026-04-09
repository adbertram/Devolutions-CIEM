function Connect-PSU {
    <#
    .SYNOPSIS
        Connects to a PowerShell Universal instance.

    .DESCRIPTION
        Authenticates to PSU by reading credentials from a .env file or accepting
        parameters directly. For local connections, reads LOCAL_PSU_URL from .env.

    .PARAMETER Url
        The PSU server URL. If not specified, reads AZURE_PSU_URL from .env for Azure,
        or LOCAL_PSU_URL from .env when -Local is used.

    .PARAMETER Token
        The PSU app token. If not specified, reads from AZURE_PSU_TOKEN or LOCAL_PSU_TOKEN in .env file.

    .PARAMETER EnvFilePath
        Path to the .env file. Defaults to .env in the current directory or repository root.

    .PARAMETER ResourceGroup
        Azure resource group name (for Azure-hosted PSU). Enables filesystem operations.

    .PARAMETER WebAppName
        Azure web app name (for Azure-hosted PSU). Enables filesystem operations.

    .PARAMETER Local
        Connect to local PSU instance (reads LOCAL_PSU_URL and LOCAL_PSU_TOKEN from .env).

    .EXAMPLE
        Connect-PSU
        # Reads from .env file in current or parent directories

    .EXAMPLE
        Connect-PSU -Url "https://psu.example.com" -Token "my-token"
        # Uses explicit parameters

    .EXAMPLE
        Connect-PSU -Local
        # Connect to local PSU instance
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
            (Join-Path $script:RepoRoot '.env'),
            (Join-Path $script:AdminRoot '.env')
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

    if ($Local -and -not $Url) {
        throw "LOCAL_PSU_URL is required in .env for -Local connections. Set it to the PSU publish point URL (e.g., http://192.168.86.30:5001)."
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
        'Accept'                     = 'application/json'
        'ngrok-skip-browser-warning' = 'true'
    }
    if ($Token) {
        $headers['Authorization'] = "Bearer $Token"
    }

    try {
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

    # Store connection info for Invoke-CIEMCommand (our REST-based command executor)
    $script:PSUConnection.Url = $Url
    $script:PSUConnection.Token = $Token
    $script:PSUConnection.IsAzure = $isAzure
    $script:PSUConnection.ResourceGroup = $ResourceGroup
    $script:PSUConnection.WebAppName = $WebAppName

    # Also call Connect-PSUServer (the official Universal module cmdlet) so that
    # PSU cmdlets like Get-PSUScript, Invoke-PSUScript, Get-PSUJob, etc. work
    # without needing -ComputerName/-AppToken on every call.
    if (Get-Command Connect-PSUServer -ErrorAction SilentlyContinue) {
        Write-Verbose "Calling Connect-PSUServer for Universal module cmdlets..."
        if ($Token) {
            Connect-PSUServer -ComputerName $Url -AppToken $Token
        }
        else {
            Connect-PSUServer -ComputerName $Url
        }
    }
    else {
        Write-Warning "Connect-PSUServer not found. Install the 'Universal' module to use PSU cmdlets (Get-PSUScript, Invoke-PSUScript, etc.) directly."
    }

    # Return connection info
    [PSCustomObject]@{
        Url           = $Url
        Status        = 'Connected'
        IsAzure       = $isAzure
        ResourceGroup = $ResourceGroup
        WebAppName    = $WebAppName
    }
}
