function Remove-CIEMScanRun {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string]$Id,
        [Parameter(Mandatory, ParameterSetName = 'ByProvider')]
        [string]$ProviderId,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [object[]]$InputObject
    )
    process {
        $ErrorActionPreference = 'Stop'
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($item in $InputObject) {
                $itemId = if ($item.Id) { $item.Id } else { $item }
                if ($PSCmdlet.ShouldProcess($itemId, 'Remove CIEM scan run')) {
                    Write-CIEMLog -Message "DELETE scan_runs WHERE id='$itemId' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-ScanRun'
                    Invoke-CIEMQuery -Query "DELETE FROM scan_runs WHERE id = @id" -Parameters @{ id = $itemId } -AsNonQuery | Out-Null
                }
            }
        } elseif ($PSCmdlet.ParameterSetName -eq 'ByProvider') {
            if ($PSCmdlet.ShouldProcess("provider '$ProviderId'", 'Remove all CIEM scan runs')) {
                $providerName = @(ConvertToCIEMCanonicalProviderList -Providers @($ProviderId))[0]
                Write-CIEMLog -Message "DELETE scan_runs WHERE scan_run_providers.provider='$providerName' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-ScanRun'
                Invoke-CIEMQuery -Query @'
DELETE FROM scan_runs
WHERE id IN (
    SELECT scan_run_id
    FROM scan_run_providers
    WHERE provider = @provider
)
'@ -Parameters @{ provider = $providerName } -AsNonQuery | Out-Null
            }
        } else {
            if ($PSCmdlet.ShouldProcess($Id, 'Remove CIEM scan run')) {
                Write-CIEMLog -Message "DELETE scan_runs WHERE id='$Id' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-ScanRun'
                Invoke-CIEMQuery -Query "DELETE FROM scan_runs WHERE id = @id" -Parameters @{ id = $Id } -AsNonQuery | Out-Null
            }
        }
    }
}
