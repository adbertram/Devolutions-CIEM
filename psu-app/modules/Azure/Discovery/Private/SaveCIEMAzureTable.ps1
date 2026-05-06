function SaveCIEMAzureTable {
    <#
    .SYNOPSIS
        Generic INSERT OR REPLACE core for every Save-CIEMAzure* shim.

    .DESCRIPTION
        Reads table + insert-column configuration from the Azure discovery entity
        registry loaded from Discovery/Data/entities.psdata and delegates to
        InvokeCIEMBatchInsert. Each Save-CIEMAzure* public shim calls this with the
        matching -Entity key so there's a single code path for batch inserts.

    .PARAMETER Entity
        Logical entity name matching a top-level key in entities.psdata
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

    $entityConfig = GetCIEMAzureEntityConfig -Entity $Entity
    InvokeCIEMBatchInsert -Table $entityConfig.Table -Columns $entityConfig.InsertColumns -Items $Items -Connection $Connection
}
