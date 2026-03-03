function Get-CIEMRelationshipColor {
    <#
    .SYNOPSIS
        Returns the display color for a CIEM graph relationship type.
    .DESCRIPTION
        Looks up the hex color for a relationship type (CAN_MANAGE, CAN_WRITE, CAN_READ, HAS_ROLE)
        from the module-scope color map. Returns a neutral gray fallback for unknown types.
    .PARAMETER Relationship
        The relationship type name (e.g., 'CAN_MANAGE', 'CAN_READ').
    .OUTPUTS
        [string] Hex color code (e.g., '#f44336').
    .EXAMPLE
        Get-CIEMRelationshipColor -Relationship 'CAN_MANAGE'
        # Returns '#f44336'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Relationship
    )

    if ($script:RelationshipColors.ContainsKey($Relationship)) {
        $script:RelationshipColors[$Relationship]
    } else {
        '#607d8b'
    }
}
