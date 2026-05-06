function Connect-PSU {
    <#
    .SYNOPSIS
        Connects to a PowerShell Universal instance.

    .DESCRIPTION
        Authenticates to PSU by reading credentials from a .env file or accepting
        parameters directly. Defaults to the local adam-server PSU instance and
        reads LOCAL_PSU_URL from .env unless -Azure is used.

    .PARAMETER Url
        The PSU server URL. If not specified, reads LOCAL_PSU_URL from .env by
        default, or AZURE_PSU_URL from .env when -Azure is used.

    .PARAMETER Token
        The PSU app token. If not specified, reads from LOCAL_PSU_TOKEN by
        default, or AZURE_PSU_TOKEN when -Azure is used.

    .PARAMETER EnvFilePath
        Path to the .env file. Defaults to .env in the current directory or repository root.

    .PARAMETER ResourceGroup
        Azure resource group name (for Azure-hosted PSU). Enables filesystem operations.

    .PARAMETER WebAppName
        Azure web app name (for Azure-hosted PSU). Enables filesystem operations.

    .PARAMETER Local
        Connect to local PSU instance (reads LOCAL_PSU_URL and LOCAL_PSU_TOKEN from .env).

    .PARAMETER Azure
        Connect to Azure PSU instance (reads AZURE_PSU_URL and AZURE_PSU_TOKEN from .env).

    .EXAMPLE
        Connect-PSU
        # Connects to the local adam-server PSU instance using .env

    .EXAMPLE
        Connect-PSU -Url "https://psu.example.com" -Token "my-token"
        # Uses explicit parameters

    .EXAMPLE
        Connect-PSU -Local
        # Connect to local PSU instance

    .EXAMPLE
        Connect-PSU -Azure
        # Connect to Azure PSU instance
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
        [switch]$Local,

        [Parameter()]
        [switch]$Azure
    )

    $ErrorActionPreference = 'Stop'

    if ($Local -and $Azure) {
        throw 'Connect-PSU accepts either -Local or -Azure, not both.'
    }

    $targetName = if ($Azure) { 'azure' } else { 'local' }
    $runtimeTarget = GetCIEMRuntimeTarget `
        -Name $targetName `
        -EnvFilePath $EnvFilePath `
        -Url $Url `
        -Token $Token `
        -ResourceGroup $ResourceGroup `
        -WebAppName $WebAppName

    $Url = $runtimeTarget.Url
    $Token = $runtimeTarget.Token
    $ResourceGroup = $runtimeTarget.ResourceGroup
    $WebAppName = $runtimeTarget.WebAppName

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
            if (-not $runtimeTarget.IsAzure) {
                throw "Authentication failed. Local PSU may not be running in development mode, or may require a token."
            }
            throw "Authentication failed. Check your PSU token."
        }
        throw "Failed to connect to PSU at $Url. Error: $_"
    }

    # Store connection info for Invoke-CIEMCommand (our REST-based command executor)
    $script:PSUConnection.Url = $Url
    $script:PSUConnection.Token = $Token
    $script:PSUConnection.IsAzure = $runtimeTarget.IsAzure
    $script:PSUConnection.ResourceGroup = $ResourceGroup
    $script:PSUConnection.WebAppName = $WebAppName

    # Also call Connect-PSUServer (the official Universal module cmdlet) so that
    # PSU cmdlets like Get-PSUScript, Invoke-PSUScript, Get-PSUJob, etc. work
    # without needing -ComputerName/-AppToken on every call.
    try {
        $connectPSUServerCommand = Get-Command Connect-PSUServer -ErrorAction Stop
    }
    catch {
        throw "Connect-PSUServer was not found. Install or import the Universal module before calling Connect-PSU."
    }
    if (-not $connectPSUServerCommand) {
        throw "Connect-PSUServer was not found. Install or import the Universal module before calling Connect-PSU."
    }

    Write-Verbose "Calling Connect-PSUServer for Universal module cmdlets..."
    if ($Token) {
        Connect-PSUServer -ComputerName $Url -AppToken $Token
    }
    else {
        Connect-PSUServer -ComputerName $Url
    }

    # Return connection info
    [PSCustomObject]@{
        Url           = $Url
        Status        = 'Connected'
        IsAzure       = $runtimeTarget.IsAzure
        ResourceGroup = $ResourceGroup
        WebAppName    = $WebAppName
    }
}
