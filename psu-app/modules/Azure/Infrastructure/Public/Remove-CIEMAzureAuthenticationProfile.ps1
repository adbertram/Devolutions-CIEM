function Remove-CIEMAzureAuthenticationProfile {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')][string]$Id,
        [Parameter(Mandatory, ParameterSetName = 'ByProvider')][string]$ProviderId,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [object[]]$InputObject
    )
    begin {
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
        if ($null -eq (Get-Command -Name 'Get-PSUCache' -ErrorAction SilentlyContinue)) { return }

        $profiles = @(Get-CIEMAzureAuthProfileCache)
        $originalCount = $profiles.Count

        if ($PSCmdlet.ParameterSetName -eq 'ByProvider') {
            if ($PSCmdlet.ShouldProcess("provider '$ProviderId'", 'Remove all Azure authentication profiles')) {
                $profiles = @($profiles | Where-Object { $_.ProviderId -ne $ProviderId })
            }
        } elseif ($PSCmdlet.ParameterSetName -eq 'ById') {
            if ($PSCmdlet.ShouldProcess($Id, 'Remove Azure authentication profile')) {
                $profiles = @($profiles | Where-Object { $_.Id -ne $Id })
            }
        } else {
            if ($idsToRemove.Count -gt 0) {
                $profiles = @($profiles | Where-Object { $_.Id -notin $idsToRemove })
            }
        }

        if ($profiles.Count -ne $originalCount) {
            Set-CIEMAzureAuthProfileCache -Profiles $profiles
        }
    }
}
