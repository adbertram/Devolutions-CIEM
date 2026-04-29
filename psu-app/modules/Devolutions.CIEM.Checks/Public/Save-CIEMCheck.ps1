function Save-CIEMCheck {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Upserts mutable check state')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Id,

        [Parameter(ParameterSetName = 'ByProperties')]
        [bool]$Disabled = $false,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject
    )

    begin {
        $ErrorActionPreference = 'Stop'

        function SaveCIEMCheckStateObject {
            param(
                [Parameter(Mandatory)]
                [object]$Item
            )

            $ErrorActionPreference = 'Stop'

            $staticFields = @(
                'Provider',
                'SourceCheckId',
                'Service',
                'Title',
                'Severity',
                'CheckScript',
                'Description',
                'Risk',
                'Remediation',
                'RemediationText',
                'RemediationUrl',
                'RelatedUrl',
                'ExecutionMode',
                'ManualReason',
                'Evaluator',
                'EvaluatorConfig',
                'Permissions',
                'DependsOn',
                'DataNeeds'
            )
            $suppliedStaticFields = @($staticFields | Where-Object { $Item.PSObject.Properties.Name -contains $_ })
            if ($suppliedStaticFields.Count -gt 0) {
                throw "Only disabled state can be updated for checks. Static check metadata is defined in provider catalogs."
            }

            $catalogCheck = @(Get-CIEMCheck -CheckId $Item.Id)
            if ($catalogCheck.Count -eq 0) {
                throw "Check '$($Item.Id)' not found in provider catalogs."
            }

            $disabledValue = if ($Item.PSObject.Properties.Name -contains 'Disabled') {
                [bool]$Item.Disabled
            }
            else {
                [bool]$catalogCheck[0].Disabled
            }

            SetCIEMCheckState -Id $Item.Id -Disabled $disabledValue
        }
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($item in $InputObject) {
                SaveCIEMCheckStateObject -Item $item
            }
        }
        else {
            SaveCIEMCheckStateObject -Item ([PSCustomObject]@{
                Id       = $Id
                Disabled = $Disabled
            })
        }
    }
}
