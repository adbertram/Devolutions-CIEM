function InvokeCIEMDiscoveryPhase {
    <#
    .SYNOPSIS
        Runs one named phase of Start-CIEMAzureDiscovery with uniform
        stopwatch + try/catch + logging semantics.

    .DESCRIPTION
        Every collection/persistence step of discovery follows the same shape:
        start a stopwatch, run an action, log elapsed time, and route any
        exceptions into a shared error accumulator so the run can complete as
        Partial only when the phase declares a non-fatal failure mode.

        This helper centralizes that shell so individual phase Actions contain
        only the domain logic.

        On success, returns the Action's output. On failure, returns $null and
        mutates $ErrorMessages with a phase-prefixed message. The caller can
        then decide whether to set a per-phase success flag.

    .PARAMETER Name
        Human-readable phase label used in logs and error messages.

    .PARAMETER Action
        Scriptblock executing the phase. May return any value; its output is
        forwarded to the caller.

    .PARAMETER ErrorMessages
        Shared error accumulator list. Failed phases append
        "<Name> failed: <message>" entries.

    .PARAMETER WarningCounter
        Ref to an integer counter. Failed phases increment it.

    .PARAMETER FailureMode
        FailRun throws after recording the phase failure. RecordUnsupported records
        the failure and returns a failed phase result.

    .PARAMETER OnSuccess
        Optional scriptblock invoked after a successful Action with the
        Action's output as $args[0]. Use this to update row counts or set
        per-phase success flags.

    .PARAMETER DetailBuilder
        Optional scriptblock invoked (with the Action output as $args[0])
        to produce a log-detail suffix like "123 rows".
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$Action,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$ErrorMessages,

        [Parameter(Mandatory)]
        [ref]$WarningCounter,

        [Parameter(Mandatory)]
        [ValidateSet('FailRun', 'RecordUnsupported')]
        [string]$FailureMode,

        [Parameter()]
        [scriptblock]$OnSuccess,

        [Parameter()]
        [scriptblock]$DetailBuilder
    )

    $ErrorActionPreference = 'Stop'

    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $result = $null
    $succeeded = $true
    $phaseException = $null

    try {
        $result = & $Action
    }
    catch {
        $succeeded = $false
        $WarningCounter.Value++
        $failMessage = "${Name} failed: $($_.Exception.Message)"
        $ErrorMessages.Add($failMessage)
        Write-Warning $failMessage
        $phaseException = [System.InvalidOperationException]::new($failMessage, $_.Exception)
    }

    $stopwatch.Stop()
    $elapsed = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)

    if ($succeeded) {
        $detail = if ($DetailBuilder) {
            & $DetailBuilder $result
        }
        else { $null }

        $logMessage = "Phase ${Name} completed in ${elapsed}s"
        if ($detail) { $logMessage += " - $detail" }
        Write-CIEMLog -Message $logMessage -Component 'Discovery'

        if ($OnSuccess) {
            & $OnSuccess $result
        }
    }
    else {
        Write-CIEMLog -Message "Phase ${Name} failed after ${elapsed}s" -Severity WARNING -Component 'Discovery'
        if ($FailureMode -eq 'FailRun') {
            throw $phaseException
        }
    }

    [pscustomobject]@{
        Name = $Name
        Succeeded = $succeeded
        Result = $result
        ElapsedSeconds = $elapsed
    }
}
