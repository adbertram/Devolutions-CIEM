function GetCIEMAzureProgressScopeHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AttackPathScopeHash,

        [Parameter(Mandatory)]
        [string]$DiscoveryScopeHash
    )

    $ErrorActionPreference = 'Stop'

    if ([string]::IsNullOrWhiteSpace($AttackPathScopeHash)) {
        throw "Attack path scope hash is required for Azure progress scope hashing."
    }
    if ([string]::IsNullOrWhiteSpace($DiscoveryScopeHash)) {
        throw "Discovery scope hash is required for Azure progress scope hashing."
    }

    $sharedCheckEngineFingerprint = GetCIEMSharedCheckEngineFingerprint
    $checkFingerprints = @(
        GetCIEMAzureCheckImplementationFingerprint -SharedCheckEngineFingerprint $sharedCheckEngineFingerprint |
            Sort-Object
    )

    $lines = @(
        'checks'
        $checkFingerprints
        'sharedCheckEngine'
        $sharedCheckEngineFingerprint
        'attackPathRules'
        $AttackPathScopeHash
        'discoveryScope'
        $DiscoveryScopeHash
    )

    GetCIEMSHA256Hash -InputText ($lines -join "`n")
}
