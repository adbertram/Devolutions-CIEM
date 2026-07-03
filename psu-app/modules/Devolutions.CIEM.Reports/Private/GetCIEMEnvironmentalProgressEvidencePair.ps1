function NewCIEMEnvironmentalProgressEvidencePair {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('NoProgressData', 'BaselineReady', 'NoComparableProgressData', 'ProgressTracked')]
        [string]$Status,

        [Parameter()]
        [object]$Baseline,

        [Parameter()]
        [object]$Current
    )

    $ErrorActionPreference = 'Stop'

    $evidencePairId = $null
    if ($Status -eq 'ProgressTracked') {
        $evidencePairId = 'baselineDiscovery:{0}|baselineScan:{1}|currentDiscovery:{2}|currentScan:{3}' -f @(
            $Baseline.DiscoveryRunId,
            $Baseline.ScanRunId,
            $Current.DiscoveryRunId,
            $Current.ScanRunId
        )
    }

    [pscustomobject]@{
        Status                 = $Status
        EvidencePairId         = $evidencePairId
        BaselineDiscoveryRunId = if ($Baseline) { [int]$Baseline.DiscoveryRunId } else { $null }
        CurrentDiscoveryRunId  = if ($Current) { [int]$Current.DiscoveryRunId } else { $null }
        BaselineCompletedAt    = if ($Baseline) { [string]$Baseline.ScanCompletedAt } else { $null }
        CurrentCompletedAt     = if ($Current) { [string]$Current.ScanCompletedAt } else { $null }
        BaselineScanRunId      = if ($Baseline) { [string]$Baseline.ScanRunId } else { $null }
        CurrentScanRunId       = if ($Current) { [string]$Current.ScanRunId } else { $null }
        ProgressScopeHash      = if ($Current) { [string]$Current.ProgressScopeHash } elseif ($Baseline) { [string]$Baseline.ProgressScopeHash } else { $null }
    }
}

function GetCIEMEnvironmentalProgressEvidencePair {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByPairId')]
        [string]$EvidencePairId,

        [Parameter(Mandatory, ParameterSetName = 'List')]
        [switch]$All
    )

    $ErrorActionPreference = 'Stop'

    $points = @(GetCIEMEnvironmentalProgressEvidencePoint)

    if ($PSCmdlet.ParameterSetName -eq 'List') {
        $pairs = @()
        for ($currentIndex = 0; $currentIndex -lt $points.Count; $currentIndex++) {
            $current = $points[$currentIndex]
            $baselines = @(
                $points |
                    Where-Object {
                        $_.DiscoveryRunId -ne $current.DiscoveryRunId -and
                        $_.ProgressScopeHash -eq $current.ProgressScopeHash -and
                        ([datetime]$_.ScanCompletedAt) -lt ([datetime]$current.ScanCompletedAt)
                    } |
                    Sort-Object -Property @{ Expression = { [datetime]$_.ScanCompletedAt }; Descending = $true }
            )
            foreach ($baseline in $baselines) {
                $pairs += NewCIEMEnvironmentalProgressEvidencePair -Status ProgressTracked -Baseline $baseline -Current $current
            }
        }
        return @(
            $pairs |
                Sort-Object -Property @{ Expression = { [datetime]$_.CurrentCompletedAt }; Descending = $true },
                                      @{ Expression = { [datetime]$_.BaselineCompletedAt }; Descending = $true }
        )
    }

    if ($PSCmdlet.ParameterSetName -eq 'ByPairId') {
        if ($EvidencePairId -notmatch '^baselineDiscovery:(\d+)\|baselineScan:([^|]+)\|currentDiscovery:(\d+)\|currentScan:([^|]+)$') {
            throw "EvidencePairId '$EvidencePairId' is not in the canonical environmental progress pair format."
        }

        $baselineDiscoveryRunId = [int]$Matches[1]
        $baselineScanRunId = [string]$Matches[2]
        $currentDiscoveryRunId = [int]$Matches[3]
        $currentScanRunId = [string]$Matches[4]

        $baseline = @(GetCIEMEnvironmentalProgressEvidencePoint -DiscoveryRunId $baselineDiscoveryRunId -ScanRunId $baselineScanRunId)
        $current = @(GetCIEMEnvironmentalProgressEvidencePoint -DiscoveryRunId $currentDiscoveryRunId -ScanRunId $currentScanRunId)
        if ($baseline.Count -ne 1 -or $current.Count -ne 1) {
            throw "EvidencePairId '$EvidencePairId' does not reference eligible environmental progress evidence."
        }
        if ($baseline[0].DiscoveryRunId -eq $current[0].DiscoveryRunId -or $baseline[0].ScanRunId -eq $current[0].ScanRunId) {
            throw "EvidencePairId '$EvidencePairId' must reference distinct baseline and current evidence points."
        }
        if ($baseline[0].ProgressScopeHash -ne $current[0].ProgressScopeHash) {
            throw "EvidencePairId '$EvidencePairId' references evidence points with different progress scope hashes."
        }
        if (([datetime]$baseline[0].ScanCompletedAt) -ge ([datetime]$current[0].ScanCompletedAt)) {
            throw "EvidencePairId '$EvidencePairId' does not reference a baseline scan older than the current scan."
        }

        return NewCIEMEnvironmentalProgressEvidencePair -Status ProgressTracked -Baseline $baseline[0] -Current $current[0]
    }

    if ($points.Count -eq 0) {
        return NewCIEMEnvironmentalProgressEvidencePair -Status NoProgressData
    }

    $currentPoint = $points[0]
    if ($points.Count -eq 1) {
        return NewCIEMEnvironmentalProgressEvidencePair -Status BaselineReady -Current $currentPoint
    }

    $baselinePoint = @(
        $points |
            Where-Object {
                $_.DiscoveryRunId -ne $currentPoint.DiscoveryRunId -and
                $_.ProgressScopeHash -eq $currentPoint.ProgressScopeHash -and
                ([datetime]$_.ScanCompletedAt) -lt ([datetime]$currentPoint.ScanCompletedAt)
            } |
            Sort-Object -Property @{ Expression = { [datetime]$_.ScanCompletedAt }; Descending = $true } |
            Select-Object -First 1
    )

    if ($baselinePoint.Count -eq 0) {
        return NewCIEMEnvironmentalProgressEvidencePair -Status NoComparableProgressData -Current $currentPoint
    }

    NewCIEMEnvironmentalProgressEvidencePair -Status ProgressTracked -Baseline $baselinePoint[0] -Current $currentPoint
}
