function GetCIEMAzureCheckImplementationFingerprint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SharedCheckEngineFingerprint
    )

    $ErrorActionPreference = 'Stop'

    $checks = @(
        Get-CIEMCheck -Provider Azure |
            Where-Object { -not $_.Disabled } |
            Sort-Object -Property Id
    )

    foreach ($check in $checks) {
        $checkScript = [string]$check.CheckScript
        $checkScriptHash = $null
        if (-not [string]::IsNullOrWhiteSpace($checkScript)) {
            $scriptPath = Join-Path $script:ModuleRoot "modules/$($check.Provider)/Checks/$checkScript"
            if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
                throw "Check '$($check.Id)' references missing script '$checkScript'."
            }
            $checkScriptHash = (Get-FileHash -LiteralPath $scriptPath -Algorithm SHA256).Hash.ToLowerInvariant()
        }

        $payload = [ordered]@{
            id                         = [string]$check.Id
            provider                   = [string]$check.Provider
            service                    = [string]$check.Service
            severity                   = [string]$check.Severity
            executionMode              = [string]$check.ExecutionMode
            checkScript                = $checkScript
            dataNeeds                  = @($check.DataNeeds | Sort-Object)
            checkScriptHash            = $checkScriptHash
            sharedCheckEngineFingerprint = $SharedCheckEngineFingerprint
        } | ConvertTo-Json -Depth 10 -Compress

        GetCIEMSHA256Hash -InputText $payload
    }
}
