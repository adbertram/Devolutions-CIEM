function Update-CIEMAzureResourceRelationship {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType('CIEMAzureResourceRelationship[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [int]$Id,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$SourceId,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$SourceType,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$TargetId,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$TargetType,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Relationship,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$CollectedAt,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject,

        [switch]$PassThru
    )

    process {
        $ErrorActionPreference = 'Stop'
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                UpdateCIEMAzureEntity -Entity 'ResourceRelationship' -Filters @{ Id = $obj.Id } -Values @{
                    SourceId = $obj.SourceId
                    SourceType = $obj.SourceType
                    TargetId = $obj.TargetId
                    TargetType = $obj.TargetType
                    Relationship = $obj.Relationship
                    CollectedAt = $obj.CollectedAt
                }
                if ($PassThru) { Get-CIEMAzureResourceRelationship -Id $obj.Id }
            }
        } else {
            $values = @{}
            foreach ($paramName in @('SourceId', 'SourceType', 'TargetId', 'TargetType', 'Relationship', 'CollectedAt')) {
                if ($PSBoundParameters.ContainsKey($paramName)) {
                    $values[$paramName] = $PSBoundParameters[$paramName]
                }
            }
            if ($values.Count -gt 0) {
                UpdateCIEMAzureEntity -Entity 'ResourceRelationship' -Filters @{ Id = $Id } -Values $values
            }
            if ($PassThru) { Get-CIEMAzureResourceRelationship -Id $Id }
        }
    }
}
