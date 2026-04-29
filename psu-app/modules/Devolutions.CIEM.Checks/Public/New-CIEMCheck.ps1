function New-CIEMCheck {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates a configuration object in database')]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Id,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Provider,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Service,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Title,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [ValidateSet('critical', 'high', 'medium', 'low')]
        [string]$Severity,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$CheckScript,
        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Description,
        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Risk,
        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$RemediationText,
        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$RemediationUrl,
        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$RelatedUrl,
        [Parameter(ParameterSetName = 'ByProperties')]
        [bool]$Disabled = $false,
        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Permissions,
        [Parameter(ParameterSetName = 'ByProperties')]
        [string[]]$DependsOn,
        [Parameter(ParameterSetName = 'ByProperties')]
        [string[]]$DataNeeds,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject
    )
    process {
        $ErrorActionPreference = 'Stop'
        throw "Static check metadata is defined in provider catalogs. Add or update the provider check catalog instead of calling New-CIEMCheck."
    }
}
