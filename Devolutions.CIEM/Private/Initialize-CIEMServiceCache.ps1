function Initialize-CIEMServiceCache {
    <#
    .SYNOPSIS
        Initializes service caches by invoking provider-specific service scripts.

    .DESCRIPTION
        Orchestrates the initialization of cloud service data by invoking scripts
        in the Services/{Provider}/ directory. Each script loads API data and returns
        a hashtable that gets wrapped in a CIEMServiceCache object.

        Streams CIEMServiceCache objects to the pipeline as each service completes,
        capturing timing, errors, and warnings.

    .PARAMETER Provider
        CIEMProvider object specifying the cloud provider.

    .PARAMETER Name
        Optional array of service names to initialize. If not specified, all
        service scripts in the provider folder are discovered and invoked.

    .PARAMETER SubscriptionIds
        Array of subscription/account IDs to pass to service scripts.

    .OUTPUTS
        [CIEMServiceCache] Streamed per-service cache objects.

    .EXAMPLE
        Initialize-CIEMServiceCache -Provider (Get-CIEMProvider -Name Azure)
        # Initializes all Azure services

    .EXAMPLE
        Initialize-CIEMServiceCache -Provider (Get-CIEMProvider -Name Azure) -Name Entra -Verbose
        # Initializes only the Entra service with verbose output
    #>
    [CmdletBinding()]
    [OutputType([CIEMServiceCache])]
    param(
        [Parameter(Mandatory)]
        [CIEMProvider]$Provider,

        [Parameter()]
        [string[]]$Name,

        [Parameter()]
        [string[]]$SubscriptionIds = @()
    )

    $servicesPath = Join-Path $script:ModuleRoot "Services/$($Provider.Name)"

    # If Name not provided, enumerate all service scripts in the provider folder
    if (-not $Name) {
        $Name = Get-ChildItem -Path $servicesPath -Filter '*.ps1' -ErrorAction SilentlyContinue |
            ForEach-Object { $_.BaseName }
    }

    foreach ($serviceName in $Name) {
        $cache = [CIEMServiceCache]::new()
        $cache.ServiceName = $serviceName
        $cache.Errors = @()
        $cache.Warnings = @()
        $cache.Output = @()
        $cache.CacheData = @{}

        $scriptPath = Join-Path $servicesPath "$serviceName.ps1"
        if (-not (Test-Path $scriptPath)) {
            $cache.Success = $false
            $cache.Duration = [timespan]::Zero
            $cache.Errors = @("Service script not found: $scriptPath")
            $cache  # stream out
            continue
        }

        $sw = [Diagnostics.Stopwatch]::StartNew()
        try {
            # Invoke the plain script, capturing streams
            $capturedWarnings = $null
            $capturedErrors = $null
            $returnedData = . $scriptPath -SubscriptionIds $SubscriptionIds `
                -WarningVariable capturedWarnings `
                -ErrorVariable capturedErrors

            $sw.Stop()
            $cache.Success = $true
            $cache.Duration = $sw.Elapsed
            $cache.CacheData = if ($returnedData -is [hashtable]) { $returnedData } else { @{} }
            $cache.Warnings = @($capturedWarnings | ForEach-Object { $_.ToString() })
            $cache.Errors = @($capturedErrors | ForEach-Object { $_.ToString() })
        }
        catch {
            $sw.Stop()
            $cache.Success = $false
            $cache.Duration = $sw.Elapsed
            $cache.Errors = @($_.Exception.Message)
            $cache.Warnings = @(if ($capturedWarnings) { $capturedWarnings | ForEach-Object { $_.ToString() } })
        }

        $cache  # stream out
    }
}
