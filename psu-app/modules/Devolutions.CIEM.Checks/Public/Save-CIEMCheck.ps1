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
        [Parameter(ParameterSetName = 'ByProperties')][string]$DependsOn,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMCheck[]]$InputObject
    )
    process {
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            if ($item) {
                $cId = $item.Id; $cProvider = $item.Provider; $cService = $item.Service; $cTitle = $item.Title
                $cSeverity = [string]$item.Severity; $cCheckScript = $item.CheckScript; $cDescription = $item.Description
                $cRisk = $item.Risk; $cRemediationText = $item.Remediation.Text; $cRemediationUrl = $item.Remediation.Url
                $cRelatedUrl = $item.RelatedUrl; $cDisabled = $item.Disabled
                $cPermissions = if ($item.Permissions) { $item.Permissions | ConvertTo-Json -Compress } else { $null }
                $cDependsOn = if ($item.DependsOn) { $item.DependsOn | ConvertTo-Json -Compress } else { $null }
            } else {
                $cId = $Id; $cProvider = $Provider; $cService = $Service; $cTitle = $Title
                $cSeverity = $Severity; $cCheckScript = $CheckScript; $cDescription = $Description
                $cRisk = $Risk; $cRemediationText = $RemediationText; $cRemediationUrl = $RemediationUrl
                $cRelatedUrl = $RelatedUrl; $cDisabled = $Disabled; $cPermissions = $Permissions; $cDependsOn = $DependsOn
            }
            Invoke-CIEMQuery -Query @"
INSERT OR REPLACE INTO checks (id, provider, service, title, description, risk, severity, remediation_text, remediation_url, related_url, check_script, disabled, permissions, depends_on)
VALUES (@id, @provider, @service, @title, @description, @risk, @severity, @remediation_text, @remediation_url, @related_url, @check_script, @disabled, @permissions, @depends_on)
"@ -Parameters @{
                id = $cId; provider = $cProvider; service = $cService; title = $cTitle
                description = $cDescription; risk = $cRisk; severity = $cSeverity
                remediation_text = $cRemediationText; remediation_url = $cRemediationUrl
                related_url = $cRelatedUrl; check_script = $cCheckScript
                disabled = if ($cDisabled) { 1 } else { 0 }; permissions = $cPermissions; depends_on = $cDependsOn
            } -AsNonQuery | Out-Null
        }
    }
}
