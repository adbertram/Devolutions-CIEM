function Remove-CIEMAzureAuthenticationProfile {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')][string]$Id,
        [Parameter(Mandatory, ParameterSetName = 'ByProvider')][string]$ProviderId,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [object[]]$InputObject
    )
    begin {
        $ErrorActionPreference = 'Stop'
        $idsToRemove = [System.Collections.Generic.List[string]]::new()
    }
    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($item in $InputObject) {
                if ($PSCmdlet.ShouldProcess($item.Id, 'Remove Azure authentication profile')) {
                    $idsToRemove.Add($item.Id)
                }
            }
        }
    }
    end {
        $profiles = GetCIEMAzureAuthProfileCache
        $originalCount = $profiles.Count

        if ($PSCmdlet.ParameterSetName -eq 'ByProvider') {
            if ($PSCmdlet.ShouldProcess("provider '$ProviderId'", 'Remove all Azure authentication profiles')) {
                $filtered = @($profiles | Where-Object { $_.ProviderId -ne $ProviderId })
            }
        } elseif ($PSCmdlet.ParameterSetName -eq 'ById') {
            if ($PSCmdlet.ShouldProcess($Id, 'Remove Azure authentication profile')) {
                $filtered = @($profiles | Where-Object { $_.Id -ne $Id })
            }
        } else {
            if ($idsToRemove.Count -gt 0) {
                $filtered = @($profiles | Where-Object { $_.Id -notin $idsToRemove })
            }
        }

        if ($null -ne $filtered -and $filtered.Count -ne $originalCount) {
            SetCIEMAzureAuthProfileCache -Profiles $filtered
        }
    }
}
