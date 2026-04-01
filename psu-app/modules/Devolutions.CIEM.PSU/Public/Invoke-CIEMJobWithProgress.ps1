function Invoke-CIEMJobWithProgress {
    <#
    .SYNOPSIS
        Launches a PSU script as a job and polls for completion, rendering live progress in a UI element.
    .DESCRIPTION
        Starts a registered PSU script via Invoke-PSUScript, then polls Get-PSUJob in a loop.
        While running, it renders a progress card (indeterminate or determinate) into ProgressElementId.
        On completion it returns the pipeline output; on failure it throws.
    .PARAMETER ScriptName
        The registered PSU script name (e.g. 'Devolutions.CIEM\Start-CIEMAzureDiscovery').
    .PARAMETER ProgressElementId
        The HTML element ID where progress UI will be rendered via Set-UDElement.
    .PARAMETER DisableElementIds
        Optional button IDs to disable during execution and re-enable on completion.
    .PARAMETER PollIntervalSeconds
        Seconds between each Get-PSUJob poll. Default 3.
    .PARAMETER MaxPollSeconds
        Maximum seconds to poll before timing out. Default 1800 (30 minutes).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ScriptName,

        [Parameter(Mandatory)]
        [string]$ProgressElementId,

        [string[]]$DisableElementIds,

        [int]$PollIntervalSeconds = 3,

        [int]$MaxPollSeconds = 1800
    )

    $ErrorActionPreference = 'Stop'

    # Disable buttons while running
    foreach ($btnId in $DisableElementIds) {
        Set-UDElement -Id $btnId -Properties @{ disabled = $true }
    }

    try {
        Write-CIEMLog -Message "JOB: starting '$ScriptName', progressEl=$ProgressElementId, disableEls=$($DisableElementIds -join ',')" -Severity INFO -Component 'PSU-Progress'

        # Render initial indeterminate progress
        Set-UDElement -Id $ProgressElementId -Content {
            New-UDCard -Style @{ marginTop = '16px'; marginBottom = '16px' } -Content {
                New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
                    New-UDProgress -Circular -Size 'small'
                    New-UDTypography -Text 'Initializing...' -Variant 'body2' -Style @{ color = '#666' }
                }
            }
        }

        # Launch the job
        $job = Invoke-PSUScript -Name $ScriptName -Integrated
        Write-CIEMLog -Message "JOB: launched job Id=$($job.Id) for script '$ScriptName'" -Severity INFO -Component 'PSU-Progress'

        # Poll loop
        $elapsed = 0
        $pollCount = 0
        $lastLoggedStatus = ''
        while ($elapsed -lt $MaxPollSeconds) {
            Start-Sleep -Seconds $PollIntervalSeconds
            $elapsed += $PollIntervalSeconds
            $pollCount++

            $job = Get-PSUJob -Id $job.Id -Integrated

            # Build status text from Write-Progress data
            $progressParts = @()
            if ($job.Activity) { $progressParts += $job.Activity }
            else { $progressParts += 'Running...' }
            if ($job.StatusDescription) { $progressParts += "— $($job.StatusDescription)" }
            if ($job.PercentComplete -gt 0) { $progressParts += "($($job.PercentComplete)%)" }
            if ($job.CurrentOperation) { $progressParts += "- $($job.CurrentOperation)" }
            $statusText = $progressParts -join ' '

            # Log status changes and every 10th poll
            $currentStatus = "$($job.Status)"
            if ($currentStatus -ne $lastLoggedStatus -or ($pollCount % 10 -eq 0)) {
                Write-CIEMLog -Message "JOB: poll #$pollCount (${elapsed}s), status=$currentStatus, pct=$($job.PercentComplete), activity=$($job.Activity), statusDesc=$($job.StatusDescription), op=$($job.CurrentOperation)" -Severity INFO -Component 'PSU-Progress'
                $lastLoggedStatus = $currentStatus
            }

            # Render progress UI
            $pct = $job.PercentComplete
            Set-UDElement -Id $ProgressElementId -Content {
                New-UDCard -Style @{ marginTop = '16px'; marginBottom = '16px' } -Content {
                    if ($pct -gt 0) {
                        New-UDProgress -PercentComplete $pct
                    } else {
                        New-UDProgress
                    }
                    New-UDTypography -Text $statusText -Variant 'body2' -Style @{ color = '#666'; marginTop = '8px' }
                }
            }

            # Break on terminal status
            if ($currentStatus -notin @('Running', 'Queued', 'WaitingOnFeedback', 'Active')) {
                Write-CIEMLog -Message "JOB: terminal status reached: $currentStatus after ${elapsed}s ($pollCount polls)" -Severity INFO -Component 'PSU-Progress'
                break
            }
        }

        # Handle terminal states
        # 'Warning' = job completed but produced Write-Warning output (still successful)
        $status = "$($job.Status)"
        if ($status -eq 'Completed' -or $status -eq 'Warning') {
            Write-CIEMLog -Message "JOB: retrieving pipeline output for job $($job.Id)" -Severity INFO -Component 'PSU-Progress'
            $output = Get-PSUJobPipelineOutput -JobId $job.Id -Integrated | Select-Object -First 1
            Write-CIEMLog -Message "JOB: job $($job.Id) completed (status=$status), output type=$($output.GetType().Name), output=$($output | ConvertTo-Json -Depth 2 -Compress -ErrorAction SilentlyContinue)" -Severity INFO -Component 'PSU-Progress'
            return $output
        }
        elseif ($status -eq 'Failed' -or $status -eq 'Error') {
            $errorOutput = Get-PSUJobOutput -Job $job -Integrated | Where-Object { $_ } | Select-Object -First 5
            $errorMsg = if ($errorOutput) { ($errorOutput -join "`n") } else { "Job failed (status: $status)" }
            Write-CIEMLog -Message "JOB: job $($job.Id) FAILED: $errorMsg" -Severity ERROR -Component 'PSU-Progress'
            throw $errorMsg
        }
        elseif ($status -eq 'TimedOut') {
            Write-CIEMLog -Message "JOB: job $($job.Id) timed out" -Severity ERROR -Component 'PSU-Progress'
            throw "Job timed out."
        }
        elseif ($status -eq 'Canceled' -or $status -eq 'Canceling') {
            Write-CIEMLog -Message "JOB: job $($job.Id) cancelled" -Severity WARNING -Component 'PSU-Progress'
            throw "Job was cancelled."
        }
        elseif ($elapsed -ge $MaxPollSeconds) {
            Write-CIEMLog -Message "JOB: poll timeout after ${elapsed}s for job $($job.Id)" -Severity ERROR -Component 'PSU-Progress'
            throw "Job polling timed out after $($MaxPollSeconds / 60) minutes."
        }
        else {
            Write-CIEMLog -Message "JOB: job $($job.Id) unexpected status: $status" -Severity ERROR -Component 'PSU-Progress'
            throw "Job ended with unexpected status: $status"
        }
    }
    finally {
        # Re-enable buttons
        foreach ($btnId in $DisableElementIds) {
            Set-UDElement -Id $btnId -Properties @{ disabled = $false }
        }
    }
}
