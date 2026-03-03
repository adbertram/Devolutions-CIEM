function Remove-CIEMAzureAuthenticationProfile {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')][string]$Id,
        [Parameter(Mandatory, ParameterSetName = 'ByProvider')][string]$ProviderId,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [CIEMAzureAuthenticationProfile[]]$InputObject
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
        $inPSUContext = $null -ne (Get-PSDrive -Name 'Secret' -ErrorAction SilentlyContinue)
        if (-not $inPSUContext) { return }

        # Read current array from PSU Variable
        $raw = (Get-PSUVariable -Name 'CIEM_AuthProfiles_Azure' -ErrorAction SilentlyContinue).Value
        $profiles = @()
        if ($raw) { $profiles = @($raw | ConvertFrom-Json) }

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
            # InputObject — ids collected in process block
            if ($idsToRemove.Count -gt 0) {
                $profiles = @($profiles | Where-Object { $_.Id -notin $idsToRemove })
            }
        }

        # Write back only if changed
        if ($profiles.Count -ne $originalCount) {
            $json = if ($profiles.Count -eq 0) { '[]' } else { ConvertTo-Json -InputObject @($profiles) -Depth 10 -Compress }
            $existingVar = Get-PSUVariable -Name 'CIEM_AuthProfiles_Azure' -ErrorAction SilentlyContinue
            if ($existingVar) {
                Set-PSUVariable -Variable $existingVar -Value $json | Out-Null
            } else {
                New-PSUVariable -Name 'CIEM_AuthProfiles_Azure' -Value $json | Out-Null
            }
        }
    }
}
