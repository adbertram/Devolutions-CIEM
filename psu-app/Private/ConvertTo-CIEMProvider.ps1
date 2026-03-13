function ConvertTo-CIEMProvider {
    <#
    .SYNOPSIS
        Converts a PSCustomObject to a typed CIEMProvider instance.

    .DESCRIPTION
        Reconstructs a CIEMProvider class instance from a PSCustomObject.
        Handles objects deserialized from PSU cache where class type
        information is lost.

    .PARAMETER InputObject
        The PSCustomObject (or CIEMProvider) to convert.

    .OUTPUTS
        [CIEMProvider]
    #>
    [CmdletBinding()]
    [OutputType('CIEMProvider')]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $InputObject
    )

    process {
        if ($InputObject -is [CIEMProvider]) {
            return $InputObject
        }

        $provider = [CIEMProvider]::new()
        $provider.Name = $InputObject.Name
        $provider.Enabled = [bool]$InputObject.Enabled
        $provider.ResourceFilter = @($InputObject.ResourceFilter)

        if ($InputObject.Endpoints) {
            $provider.Endpoints = $InputObject.Endpoints
        }
        else {
            $provider.Endpoints = [PSCustomObject]@{}
        }

        $provider
    }
}
