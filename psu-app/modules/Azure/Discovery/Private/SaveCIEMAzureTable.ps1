function SaveCIEMAzureTable {
    <#
    .SYNOPSIS
        Generic INSERT OR REPLACE core for every Save-CIEMAzure* shim.

    .DESCRIPTION
        Reads table + column configuration from $script:CIEMSaveTablesConfig (loaded
        from Discovery/Data/save-tables.psd1 at module init) and delegates to
        InvokeCIEMBatchInsert. Each Save-CIEMAzure* public shim calls this with the
        matching -Entity key so there's a single code path for batch inserts.

    .PARAMETER Entity
        Logical entity name matching a top-level key in save-tables.psd1
        (e.g., 'ArmResource', 'EntraResource', 'ResourceRelationship',
        'EffectiveRoleAssignment').

    .PARAMETER Items
        Items to insert. Each item may be a hashtable, PSCustomObject, or a
        module-defined class instance — InvokeCIEMBatchInsert handles property lookup.

    .PARAMETER Connection
        Optional SqliteConnection to join an outer transaction.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Entity,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Items,

        [Parameter()]
        [object]$Connection
    )

    $ErrorActionPreference = 'Stop'

    if (-not $script:CIEMSaveTablesConfig) {
        throw 'SaveCIEMAzureTable: $script:CIEMSaveTablesConfig is not loaded. Module init failed.'
    }

    if (-not $script:CIEMSaveTablesConfig.ContainsKey($Entity)) {
        $known = ($script:CIEMSaveTablesConfig.Keys | Sort-Object) -join ', '
        throw "SaveCIEMAzureTable: unknown entity '$Entity'. Known entities: $known"
    }

    $entityConfig = $script:CIEMSaveTablesConfig[$Entity]
    InvokeCIEMBatchInsert -Table $entityConfig.Table -Columns $entityConfig.Columns -Items $Items -Connection $Connection
}
