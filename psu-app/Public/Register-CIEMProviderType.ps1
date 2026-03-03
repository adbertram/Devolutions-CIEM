function Register-CIEMProviderType {
    <#
    .SYNOPSIS
        Registers a cloud provider type with CIEM Base.

    .DESCRIPTION
        Provider modules call this during import to register their capabilities.
        Base stores registrations in $script:ProviderTypes and uses them to
        dispatch provider-specific operations (auth, schema, testing) without
        hardcoding any provider knowledge.

    .PARAMETER Name
        Provider type name (e.g., 'Azure', 'AWS').

    .PARAMETER Callbacks
        Hashtable of scriptblock callbacks and static properties:

        QueryAuth       [scriptblock] () -> @{ Columns; JoinClause }
                        Returns SQL fragments for Get-CIEMProvider SELECT queries.

        ReadAuth        [scriptblock] ($Row, [bool]$IncludeSecrets) -> [PSCustomObject]
                        Converts a DB row into an auth PSCustomObject.
                        When IncludeSecrets is true, probes PSU secret store.

        WriteAuth       [scriptblock] ($Connection, $ProviderId, $Auth, $Timestamp)
                        Persists auth to provider-specific tables within a transaction.
                        If $Auth is [bool], syncs only the enabled flag.

        TestAuth        [scriptblock] ($Provider) -> @{ Authenticated; Account; TenantId }
                        Tests actual API connectivity.

        BuildAuth       [scriptblock] ($Params) -> [PSCustomObject]
                        Builds auth PSCustomObject from user params and saves secrets.

        SeedDefaults    [scriptblock] ($Connection, $Timestamp)
                        INSERT OR IGNORE default provider and auth rows.

        DefaultEndpoints [PSCustomObject]
                        Default API endpoint URLs for new providers.

    .EXAMPLE
        Register-CIEMProviderType -Name 'Azure' -Callbacks @{
            QueryAuth  = { @{ Columns = '...'; JoinClause = '...' } }
            ReadAuth   = { param($Row, $IncludeSecrets) ... }
            WriteAuth  = { param($Connection, $ProviderId, $Auth, $Timestamp) ... }
            TestAuth   = { param($Provider) ... }
            BuildAuth  = { param($Params) ... }
            SeedDefaults = { param($Connection, $Timestamp) ... }
            DefaultEndpoints = [PSCustomObject]@{ graphApi = '...'; armApi = '...' }
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [hashtable]$Callbacks
    )

    $ErrorActionPreference = 'Stop'

    # Store the registration
    $script:ProviderTypes[$Name] = $Callbacks

    Write-Verbose "Registered provider type: $Name"

    # Seed defaults if database is available
    if ($Callbacks.SeedDefaults) {
        try {
            $dbPath = Get-CIEMDatabasePath
            if ($dbPath) {
                $conn = Open-PSUSQLiteConnection -Database $dbPath
                try {
                    $now = (Get-Date).ToString('o')
                    & $Callbacks.SeedDefaults $conn $now
                }
                finally {
                    $conn.Dispose()
                }
            }
        }
        catch {
            Write-Verbose "Provider type '$Name' seeding skipped: $($_.Exception.Message)"
        }
    }
}
