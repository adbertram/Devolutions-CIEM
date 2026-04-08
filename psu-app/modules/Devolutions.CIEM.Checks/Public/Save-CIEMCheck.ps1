function Save-CIEMCheck {
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Upsert operation for bulk data')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Id,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Provider,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Service,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$Title,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][ValidateSet('critical','high','medium','low')][string]$Severity,
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')][string]$CheckScript,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Description,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Risk,
        [Parameter(ParameterSetName = 'ByProperties')][string]$RemediationText,
        [Parameter(ParameterSetName = 'ByProperties')][string]$RemediationUrl,
        [Parameter(ParameterSetName = 'ByProperties')][string]$RelatedUrl,
        [Parameter(ParameterSetName = 'ByProperties')][bool]$Disabled = $false,
        [Parameter(ParameterSetName = 'ByProperties')][string]$Permissions,
        [Parameter(ParameterSetName = 'ByProperties')][string[]]$DependsOn,
        [Parameter(ParameterSetName = 'ByProperties')][string[]]$DataNeeds,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject
    )
    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($item in $InputObject) {
                if ($item.PSObject.Properties.Name -contains 'DataNeeds' -and $null -ne $item.DataNeeds -and @($item.DataNeeds).Count -eq 0) {
                    throw "Check '$($item.Id)' must declare at least one data need."
                }
                $cId = $item.Id; $cProvider = $item.Provider; $cService = $item.Service; $cTitle = $item.Title
                $cSeverity = [string]$item.Severity; $cCheckScript = $item.CheckScript; $cDescription = $item.Description
                $cRisk = $item.Risk; $cRemediationText = $item.Remediation.Text; $cRemediationUrl = $item.Remediation.Url
                $cRelatedUrl = $item.RelatedUrl; $cDisabled = $item.Disabled
                $cPermissions = if ($item.Permissions) { $item.Permissions | ConvertTo-Json -Compress } else { $null }
                $cDependsOn = if ($item.DependsOn) { ConvertTo-Json -InputObject @($item.DependsOn) -Compress } else { $null }
                $cDataNeeds = if ($item.PSObject.Properties.Name -contains 'DataNeeds' -and $null -ne $item.DataNeeds) { ConvertTo-Json -InputObject @($item.DataNeeds) -Compress } else { $null }
                Invoke-CIEMQuery -Query "INSERT OR REPLACE INTO checks (id, provider, service, title, description, risk, severity, remediation_text, remediation_url, related_url, check_script, disabled, permissions, depends_on, data_needs) VALUES (@id, @provider, @service, @title, @description, @risk, @severity, @remediation_text, @remediation_url, @related_url, @check_script, @disabled, @permissions, @depends_on, @data_needs)" -Parameters @{
                    id = $cId; provider = $cProvider; service = $cService; title = $cTitle
                    description = $cDescription; risk = $cRisk; severity = $cSeverity
                    remediation_text = $cRemediationText; remediation_url = $cRemediationUrl
                    related_url = $cRelatedUrl; check_script = $cCheckScript
                    disabled = if ($cDisabled) { 1 } else { 0 }; permissions = $cPermissions; depends_on = $cDependsOn; data_needs = $cDataNeeds
                } -AsNonQuery | Out-Null
            }
        } else {
            if ($PSBoundParameters.ContainsKey('DataNeeds') -and @($DataNeeds).Count -eq 0) {
                throw "Check '$Id' must declare at least one data need."
            }

            Invoke-CIEMQuery -Query "INSERT OR REPLACE INTO checks (id, provider, service, title, description, risk, severity, remediation_text, remediation_url, related_url, check_script, disabled, permissions, depends_on, data_needs) VALUES (@id, @provider, @service, @title, @description, @risk, @severity, @remediation_text, @remediation_url, @related_url, @check_script, @disabled, @permissions, @depends_on, @data_needs)" -Parameters @{
                id = $Id; provider = $Provider; service = $Service; title = $Title
                description = $Description; risk = $Risk; severity = $Severity
                remediation_text = $RemediationText; remediation_url = $RemediationUrl
                related_url = $RelatedUrl; check_script = $CheckScript
                disabled = if ($Disabled) { 1 } else { 0 }; permissions = $Permissions
                depends_on = if ($PSBoundParameters.ContainsKey('DependsOn')) { ConvertTo-Json -InputObject @($DependsOn) -Compress } else { $null }
                data_needs = if ($PSBoundParameters.ContainsKey('DataNeeds')) { ConvertTo-Json -InputObject @($DataNeeds) -Compress } else { $null }
            } -AsNonQuery | Out-Null
        }
    }
}
