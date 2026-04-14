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
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($item in $InputObject) {
                $existing = Invoke-CIEMQuery -Query "SELECT id FROM checks WHERE id = @id" -Parameters @{ id = $item.Id }
                if ($existing) { throw "Check '$($item.Id)' already exists. Use Update-CIEMCheck or Save-CIEMCheck." }
                Save-CIEMCheck -InputObject $item
                Get-CIEMCheck -CheckId $item.Id
            }
        } else {
            $existing = Invoke-CIEMQuery -Query "SELECT id FROM checks WHERE id = @id" -Parameters @{ id = $Id }
            if ($existing) { throw "Check '$Id' already exists. Use Update-CIEMCheck or Save-CIEMCheck." }
            # Forward all bound parameters to Save-CIEMCheck (excluding InputObject which is a different param set)
            Save-CIEMCheck @PSBoundParameters
            Get-CIEMCheck -CheckId $Id
        }
    }
}