function Remove-CIEMCheck {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [string]$Id,
        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject
    )
    process {
        $ErrorActionPreference = 'Stop'
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($item in $InputObject) {
                if ($PSCmdlet.ShouldProcess($item.Id, 'Remove CIEM check')) {
                    Write-CIEMLog -Message "DELETE checks WHERE id='$($item.Id)' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-Check'
                    Invoke-CIEMQuery -Query "DELETE FROM checks WHERE id = @id" -Parameters @{ id = $item.Id } -AsNonQuery | Out-Null
                }
            }
        } else {
            if ($PSCmdlet.ShouldProcess($Id, 'Remove CIEM check')) {
                Write-CIEMLog -Message "DELETE checks WHERE id='$Id' (caller: $((Get-PSCallStack)[1].Command))" -Severity WARNING -Component 'Remove-Check'
                Invoke-CIEMQuery -Query "DELETE FROM checks WHERE id = @id" -Parameters @{ id = $Id } -AsNonQuery | Out-Null
            }
        }
    }
}