function ConvertTo-CIEMAzureOdataType {
    <#
    .SYNOPSIS
        Converts an internal principal type string to the Graph API @odata.type value.
    .PARAMETER Type
        The internal type string (User, Group, ServicePrincipal).
    .OUTPUTS
        [string] The @odata.type value (e.g., '#microsoft.graph.user').
    #>
    param([string]$Type)

    switch ($Type) {
        'User'             { '#microsoft.graph.user' }
        'Group'            { '#microsoft.graph.group' }
        'ServicePrincipal' { '#microsoft.graph.servicePrincipal' }
        default            { '#microsoft.graph.directoryObject' }
    }
}
