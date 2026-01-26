function Get-CheckMetadata {
    <#
    .SYNOPSIS
        Loads check metadata from AzureChecks.json.

    .DESCRIPTION
        Reads and parses the AzureChecks.json metadata file, handling both
        array format and object-with-checks-property format.

    .OUTPUTS
        [object[]] Array of check metadata objects.

    .EXAMPLE
        $checks = Get-CheckMetadata
        # Returns array of check definitions
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Metadata is a mass noun, not plural')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '', Justification = 'Array subexpression returns correct type')]
    [OutputType([object[]])]
    param()

    $ErrorActionPreference = 'Stop'

    $checksPath = Join-Path $script:ModuleRoot 'AzureChecks.json'

    if (-not (Test-Path $checksPath)) {
        throw "Checks metadata file not found: $checksPath"
    }

    $metadata = Get-Content $checksPath -Raw | ConvertFrom-Json

    # Handle both array format and object-with-checks-property format
    if ($metadata.PSObject.Properties.Name -contains 'checks') {
        @($metadata.checks)
    }
    else {
        @($metadata)
    }
}
