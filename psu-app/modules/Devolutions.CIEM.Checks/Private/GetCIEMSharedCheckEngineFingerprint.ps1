function GetCIEMSharedCheckEngineFingerprint {
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    $relativePaths = @(
        'modules/Devolutions.CIEM.Checks/Private/InvokeCIEMScan.ps1',
        'modules/Devolutions.CIEM.Checks/Private/InvokeCIEMCheck.ps1',
        'modules/Devolutions.CIEM.Checks/Private/ConvertFromCIEMStoredResource.ps1',
        'modules/Devolutions.CIEM.Checks/Private/GetCIEMIAMNeeds.ps1',
        'modules/Devolutions.CIEM.Checks/Private/GetCIEMEntraNeeds.ps1'
    )

    $fileHashes = @(foreach ($relativePath in $relativePaths) {
        $path = Join-Path $script:ModuleRoot $relativePath
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Shared check-engine fingerprint file was not found: $path"
        }

        [ordered]@{
            path = $relativePath
            hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    })

    $payload = [ordered]@{
        files = $fileHashes
    } | ConvertTo-Json -Depth 10 -Compress

    GetCIEMSHA256Hash -InputText $payload
}
