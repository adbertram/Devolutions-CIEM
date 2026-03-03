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
        [Parameter(ParameterSetName = 'ByProperties')][string]$DependsOn,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject,
        [switch]$PassThru
    )
    process {
        $items = if ($PSCmdlet.ParameterSetName -eq 'InputObject') { $InputObject } else { @($null) }
        foreach ($item in $items) {
            if ($item) {
                $cId = $item.Id
                $setClauses = @(); $params = @{ id = $cId }
                # Update all fields from object
                $fieldMap = @{ provider='provider'; service='service'; title='title'; severity='severity'; check_script='CheckScript'; description='description'; risk='risk'; remediation_text='Remediation.Text'; remediation_url='Remediation.Url'; related_url='RelatedUrl'; disabled='Disabled' }
                $setClauses += "provider = @provider"; $params.provider = $item.Provider
                $setClauses += "service = @service"; $params.service = $item.Service
                $setClauses += "title = @title"; $params.title = $item.Title
                $setClauses += "severity = @severity"; $params.severity = [string]$item.Severity
                $setClauses += "check_script = @check_script"; $params.check_script = $item.CheckScript
                $setClauses += "description = @description"; $params.description = $item.Description
                $setClauses += "risk = @risk"; $params.risk = $item.Risk
                $setClauses += "remediation_text = @remediation_text"; $params.remediation_text = $item.Remediation.Text
                $setClauses += "remediation_url = @remediation_url"; $params.remediation_url = $item.Remediation.Url
                $setClauses += "related_url = @related_url"; $params.related_url = $item.RelatedUrl
                $setClauses += "disabled = @disabled"; $params.disabled = if ($item.Disabled) { 1 } else { 0 }
                if ($item.Permissions) { $setClauses += "permissions = @permissions"; $params.permissions = $item.Permissions | ConvertTo-Json -Compress }
                if ($item.DependsOn) { $setClauses += "depends_on = @depends_on"; $params.depends_on = $item.DependsOn | ConvertTo-Json -Compress }
            } else {
                $cId = $Id
                $existing = Invoke-CIEMQuery -Query "SELECT id FROM checks WHERE id = @id" -Parameters @{ id = $cId }
                if (-not $existing) { throw "Check '$cId' not found." }

                $setClauses = @(); $params = @{ id = $cId }
                $columnMap = @{
                    Provider='provider'; Service='service'; Title='title'; Severity='severity'; CheckScript='check_script'
                    Description='description'; Risk='risk'; RemediationText='remediation_text'; RemediationUrl='remediation_url'
                    RelatedUrl='related_url'; Disabled='disabled'; Permissions='permissions'; DependsOn='depends_on'
                }
                foreach ($paramName in $columnMap.Keys) {
                    if ($PSBoundParameters.ContainsKey($paramName)) {
                        $col = $columnMap[$paramName]
                        $val = $PSBoundParameters[$paramName]
                        if ($paramName -eq 'Disabled') { $val = if ($val) { 1 } else { 0 } }
                        $setClauses += "$col = @$col"
                        $params[$col] = $val
                    }
                }
            }

            if ($setClauses.Count -eq 0) { if ($PassThru) { Get-CIEMCheck -CheckId $cId }; continue }

            Invoke-CIEMQuery -Query "UPDATE checks SET $($setClauses -join ', ') WHERE id = @id" -Parameters $params -AsNonQuery | Out-Null
            if ($PassThru) { Get-CIEMCheck -CheckId $cId }
        }
    }
}
