function Update-CIEMAzureEntraResource {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType('CIEMAzureEntraResource[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Id,
        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Type,
        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$DisplayName,
        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$ParentId,
        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Properties,
        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$CollectedAt,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject,

        [switch]$PassThru
    )
    process {
        $ErrorActionPreference = 'Stop'
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($item in $InputObject) {
                UpdateCIEMAzureEntity -Entity 'EntraResource' -Filters @{ Id = $item.Id } -Values @{
                    Type = $item.Type
                    DisplayName = $item.DisplayName
                    ParentId = $item.ParentId
                    Properties = $item.Properties
                    CollectedAt = $item.CollectedAt
                    LastSeenAt = $item.LastSeenAt
                }
                if ($PassThru) { Get-CIEMAzureEntraResource -Id $item.Id }
            }
        } else {
            $values = @{}
            foreach ($paramName in @('Type', 'DisplayName', 'ParentId', 'Properties', 'CollectedAt')) {
                if ($PSBoundParameters.ContainsKey($paramName)) {
                    $values[$paramName] = $PSBoundParameters[$paramName]
                }
            }

            if ($values.Count -eq 0) {
                if ($PassThru) { Get-CIEMAzureEntraResource -Id $Id }
                return
            }

            UpdateCIEMAzureEntity -Entity 'EntraResource' -Filters @{ Id = $Id } -Values $values
            if ($PassThru) { Get-CIEMAzureEntraResource -Id $Id }
        }
    }
}
