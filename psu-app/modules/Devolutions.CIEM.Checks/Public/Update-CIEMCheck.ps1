function Update-CIEMCheck {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Id,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Provider,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Service,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Title,
        [Parameter(ParameterSetName = 'ByProperties')][ValidateSet('critical','high','medium','low')][string]$Severity,
        [Parameter(ParameterSetName = 'ByProperties')][string]$CheckScript,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Description,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Risk,
        [Parameter(ParameterSetName = 'ByProperties')][string]$RemediationText,
        [Parameter(ParameterSetName = 'ByProperties')][string]$RemediationUrl,
        [Parameter(ParameterSetName = 'ByProperties')][string]$RelatedUrl,
        [Parameter(ParameterSetName = 'ByProperties')][ValidateSet('script', 'rule', 'manual', 'notImplemented')][string]$ExecutionMode,
        [Parameter(ParameterSetName = 'ByProperties')][AllowEmptyString()][string]$ManualReason,
        [Parameter(ParameterSetName = 'ByProperties')][AllowEmptyString()][string]$Evaluator,
        [Parameter(ParameterSetName = 'ByProperties')][AllowEmptyString()][string]$EvaluatorConfig,
        [Parameter(ParameterSetName = 'ByProperties')][bool]$Disabled,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Permissions,
        [Parameter(ParameterSetName = 'ByProperties')][string[]]$DependsOn,
        [Parameter(ParameterSetName = 'ByProperties')][string[]]$DataNeeds,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject,
        [switch]$PassThru
    )

    begin {
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

        $updateCIEMCheckStateObject = {
            param(
                [Parameter(Mandatory)]
                [object]$Item,

                [Parameter(Mandatory)]
                [bool]$HasDisabled
            )

            $ErrorActionPreference = 'Stop'

            $suppliedStaticFields = @($staticFields | Where-Object { $Item.PSObject.Properties.Name -contains $_ })
            if ($suppliedStaticFields.Count -gt 0) {
                throw "Only disabled state can be updated for checks. Static check metadata is defined in provider catalogs."
            }

            $existing = @(Get-CIEMCheck -CheckId $Item.Id)
            if ($existing.Count -eq 0) {
                throw "Check '$($Item.Id)' not found."
            }

            if ($HasDisabled) {
                SetCIEMCheckState -Id $Item.Id -Disabled ([bool]$Item.Disabled)
            }

            if ($PassThru) {
                Get-CIEMCheck -CheckId $Item.Id
            }
        }
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($item in $InputObject) {
                & $updateCIEMCheckStateObject -Item $item -HasDisabled ($item.PSObject.Properties.Name -contains 'Disabled')
            }
        }
        else {
            $item = [PSCustomObject]@{ Id = $Id }
            if ($PSBoundParameters.ContainsKey('Disabled')) {
                $item | Add-Member -NotePropertyName Disabled -NotePropertyValue $Disabled
            }
            foreach ($fieldName in $staticFields) {
                if ($PSBoundParameters.ContainsKey($fieldName)) {
                    $item | Add-Member -NotePropertyName $fieldName -NotePropertyValue $PSBoundParameters[$fieldName]
                }
            }

            & $updateCIEMCheckStateObject -Item $item -HasDisabled ($PSBoundParameters.ContainsKey('Disabled'))
        }
    }
}
