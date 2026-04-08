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
        [Parameter(ParameterSetName = 'ByProperties')][bool]$Disabled,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Permissions,
        [Parameter(ParameterSetName = 'ByProperties')][string[]]$DependsOn,
        [Parameter(ParameterSetName = 'ByProperties')][string[]]$DataNeeds,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject,
        [switch]$PassThru
    )

    process {
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @([pscustomobject]@{ Id = $Id }) }
        foreach ($item in $items) {
            $checkId = $item.Id
            $existing = @(Get-CIEMCheck -CheckId $checkId)
            if ($existing.Count -eq 0) {
                throw "Check '$checkId' not found."
            }

            $merged = [pscustomobject]@{
                Id = $existing[0].Id
                Provider = $existing[0].Provider
                Service = $existing[0].Service
                Title = $existing[0].Title
                Severity = $existing[0].Severity
                CheckScript = $existing[0].CheckScript
                Description = $existing[0].Description
                Risk = $existing[0].Risk
                RelatedUrl = $existing[0].RelatedUrl
                Disabled = [bool]$existing[0].Disabled
                Permissions = $existing[0].Permissions
                DependsOn = if ($null -ne $existing[0].DependsOn) { @($existing[0].DependsOn) } else { @() }
                DataNeeds = if ($null -ne $existing[0].DataNeeds) { @($existing[0].DataNeeds) } else { $null }
                Remediation = [pscustomobject]@{
                    Text = $existing[0].Remediation.Text
                    Url = $existing[0].Remediation.Url
                }
            }

            if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
                foreach ($propertyName in @('Provider', 'Service', 'Title', 'Severity', 'CheckScript', 'Description', 'Risk', 'RelatedUrl', 'Disabled', 'Permissions')) {
                    if ($item.PSObject.Properties.Name -contains $propertyName) {
                        $merged.$propertyName = $item.$propertyName
                    }
                }

                if ($item.PSObject.Properties.Name -contains 'DependsOn') {
                    $merged.DependsOn = if ($null -ne $item.DependsOn) { @($item.DependsOn) } else { @() }
                }

                if ($item.PSObject.Properties.Name -contains 'DataNeeds') {
                    if ($null -ne $item.DataNeeds -and @($item.DataNeeds).Count -eq 0) {
                        throw "Check '$checkId' must declare at least one data need."
                    }
                    $merged.DataNeeds = if ($null -ne $item.DataNeeds) { @($item.DataNeeds) } else { $null }
                }

                if ($item.PSObject.Properties.Name -contains 'Remediation') {
                    if ($item.Remediation.PSObject.Properties.Name -contains 'Text') {
                        $merged.Remediation.Text = $item.Remediation.Text
                    }
                    if ($item.Remediation.PSObject.Properties.Name -contains 'Url') {
                        $merged.Remediation.Url = $item.Remediation.Url
                    }
                }
            }
            else {
                foreach ($propertyName in @('Provider', 'Service', 'Title', 'Severity', 'CheckScript', 'Description', 'Risk', 'RelatedUrl', 'Disabled', 'Permissions')) {
                    if ($PSBoundParameters.ContainsKey($propertyName)) {
                        $merged.$propertyName = $PSBoundParameters[$propertyName]
                    }
                }

                if ($PSBoundParameters.ContainsKey('DependsOn')) {
                    $merged.DependsOn = @($DependsOn)
                }

                if ($PSBoundParameters.ContainsKey('DataNeeds')) {
                    if (@($DataNeeds).Count -eq 0) {
                        throw "Check '$checkId' must declare at least one data need."
                    }
                    $merged.DataNeeds = @($DataNeeds)
                }

                if ($PSBoundParameters.ContainsKey('RemediationText')) {
                    $merged.Remediation.Text = $RemediationText
                }

                if ($PSBoundParameters.ContainsKey('RemediationUrl')) {
                    $merged.Remediation.Url = $RemediationUrl
                }
            }

            Save-CIEMCheck -InputObject $merged
            if ($PassThru) {
                Get-CIEMCheck -CheckId $checkId
            }
        }
    }
}
