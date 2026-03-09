function New-CIEMIdentityScanRun {
    <#
    .SYNOPSIS
        Creates and executes an identity data collection run, returning the completed ScanRun.

    .DESCRIPTION
        Public entry point for collecting identity data (Entra ID + IAM). Creates a ScanRun
        record with Type = 'identity', delegates data collection to Invoke-CIEMIdentityScan,
        and returns the completed [CIEMScanRun] object.

        This function collects and persists identity data to SQLite. Use Update-CIEMIdentityGraph
        afterwards to build the identity graph from the persisted data.

    .PARAMETER Provider
        One or more cloud providers to collect identity data for ('Azure', 'AWS').
        Omit to collect for all enabled providers.

    .OUTPUTS
        [CIEMScanRun] The completed scan run (Type = 'identity').

    .EXAMPLE
        $scanRun = New-CIEMIdentityScanRun
        # Collects identity data for all enabled providers

    .EXAMPLE
        $scanRun = New-CIEMIdentityScanRun -Provider 'Azure'
        # Collects Entra + IAM data for Azure only
    #>
    [CmdletBinding()]
    [OutputType('CIEMScanRun')]
    param(
        [Parameter()]
        [string[]]$Provider
    )

    $ErrorActionPreference = 'Stop'

    Write-CIEMLog -Message "New-CIEMIdentityScanRun called: Provider=[$($Provider -join ',')]" -Severity INFO -Component 'IdentityScanRun'

    # --- Resolve providers: default to all enabled when not specified ---
    if (-not $Provider -or $Provider.Count -eq 0) {
        $Provider = @(Get-CIEMProvider | Where-Object Enabled | Select-Object -ExpandProperty Name)
        if ($Provider.Count -eq 0) {
            throw "No enabled providers configured. Use New-CIEMProvider to add providers."
        }
        Write-Verbose "No -Provider specified; collecting for all enabled providers: $($Provider -join ', ')"
    }

    # --- Create and persist ScanRun ---
    $scanRun = [CIEMScanRun]::new($Provider, @('Entra', 'IAM'), $false)
    $scanRun.Type = 'identity'
    $scanRun.Status = [CIEMScanRunStatus]::Running
    Save-CIEMScanRun -ScanRun $scanRun
    Write-Verbose "Started identity ScanRun: $($scanRun.Id) for providers: $($Provider -join ', ')"

    # --- Execute identity data collection ---
    try {
        Invoke-CIEMIdentityScan -Provider $Provider

        $scanRun.Complete()
        Save-CIEMScanRun -ScanRun $scanRun

        Write-CIEMLog -Message "Identity ScanRun completed: $($scanRun.Id)" -Severity INFO -Component 'IdentityScanRun'
        Write-Verbose "Identity ScanRun completed: $($scanRun.Id)"
    }
    catch {
        $scanRun.Fail($_.Exception.Message)
        Save-CIEMScanRun -ScanRun $scanRun

        Write-CIEMLog -Message "Identity ScanRun failed: $($scanRun.Id) — $($_.Exception.Message)" -Severity ERROR -Component 'IdentityScanRun'
        Write-Verbose "Identity ScanRun failed: $($scanRun.Id) — $($_.Exception.Message)"
        throw
    }

    return $scanRun
}
