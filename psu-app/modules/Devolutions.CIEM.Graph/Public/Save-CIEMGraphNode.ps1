function Save-CIEMGraphNode {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Upsert operation for bulk data')]
    [OutputType('CIEMGraphNode[]')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Id,

        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Kind,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$DisplayName,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$Provider,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$SubscriptionId,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$ResourceGroup,

        [Parameter(ParameterSetName = 'ByProperties')]
        [AllowNull()]
        [string]$Properties = $null,

        [Parameter(ParameterSetName = 'ByProperties')]
        [string]$CollectedAt,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject,

        [Parameter()]
        [Microsoft.Data.Sqlite.SqliteConnection]$Connection
    )

    process {
        $ErrorActionPreference = 'Stop'

        $items = [System.Collections.Generic.List[object]]::new()
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($obj in $InputObject) {
                $effectiveCollectedAt = if ([string]::IsNullOrWhiteSpace([string]$obj.CollectedAt)) {
                    (Get-Date).ToString('o')
                }
                else {
                    [string]$obj.CollectedAt
                }

                $effectiveProvider = if ([string]::IsNullOrWhiteSpace([string]$obj.Provider)) {
                    'azure'
                }
                else {
                    [string]$obj.Provider
                }

                $items.Add(@{
                    Id             = $obj.Id
                    Kind           = $obj.Kind
                    DisplayName    = $obj.DisplayName
                    Provider       = $effectiveProvider
                    SubscriptionId = $obj.SubscriptionId
                    ResourceGroup  = $obj.ResourceGroup
                    Properties     = $obj.Properties
                    CollectedAt    = $effectiveCollectedAt
                })
            }
        }
        else {
            $effectiveCollectedAt = if ([string]::IsNullOrWhiteSpace($CollectedAt)) {
                (Get-Date).ToString('o')
            }
            else {
                $CollectedAt
            }

            $effectiveProvider = if ([string]::IsNullOrWhiteSpace($Provider)) {
                'azure'
            }
            else {
                $Provider
            }

            $items.Add(@{
                Id             = $Id
                Kind           = $Kind
                DisplayName    = $DisplayName
                Provider       = $effectiveProvider
                SubscriptionId = $SubscriptionId
                ResourceGroup  = $ResourceGroup
                Properties     = $Properties
                CollectedAt    = $effectiveCollectedAt
            })
        }

        SaveCIEMGraphEntity -Entity Node -Items $items.ToArray() -Connection $Connection
    }
}
