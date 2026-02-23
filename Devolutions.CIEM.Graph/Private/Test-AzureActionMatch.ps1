function Test-AzureActionMatch {
    <#
    .SYNOPSIS
        Tests if an Azure action string matches a wildcard permission pattern.

    .DESCRIPTION
        Converts Azure permission wildcards to regex for matching.
        Azure uses * for wildcard (any characters) and ? for single character.
        Matching is case-insensitive and full-match (anchored).

    .PARAMETER Pattern
        The permission pattern, e.g., "Microsoft.Sql/servers/*" or "*/read".

    .PARAMETER Action
        The action to test, e.g., "Microsoft.Sql/servers/delete".

    .OUTPUTS
        [bool] True if the action matches the pattern.

    .EXAMPLE
        Test-AzureActionMatch -Pattern "Microsoft.Sql/servers/*" -Action "Microsoft.Sql/servers/delete"
        # Returns $true

    .EXAMPLE
        Test-AzureActionMatch -Pattern "*/read" -Action "Microsoft.Sql/servers/read"
        # Returns $true

    .EXAMPLE
        Test-AzureActionMatch -Pattern "Microsoft.Sql/servers/read" -Action "Microsoft.Sql/servers/write"
        # Returns $false
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [string]$Action
    )
    $ErrorActionPreference = 'Stop'

    # Special case: "*" matches everything
    if ($Pattern -eq '*') { return $true }

    # Escape regex special characters, then convert Azure wildcards to regex
    $regexPattern = [regex]::Escape($Pattern)
    $regexPattern = $regexPattern -replace '\\\*', '.*'
    $regexPattern = $regexPattern -replace '\\\?', '.'

    # Full match with anchors, case-insensitive
    return $Action -match "^$regexPattern$"
}
