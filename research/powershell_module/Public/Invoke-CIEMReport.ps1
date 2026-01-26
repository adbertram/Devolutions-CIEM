function Invoke-CIEMReport {
    <#
    .SYNOPSIS
        Generates the final JSON report from analysis results.

    .DESCRIPTION
        Creates a structured JSON report optimized for LLM analysis, containing:
        - Scan metadata (ID, timestamp, provider, scope)
        - All findings with severity, evidence, and remediation guidance
        - Summary statistics

    .PARAMETER ScanId
        Unique identifier for this scan.

    .PARAMETER Provider
        The cloud provider that was scanned.

    .PARAMETER Scope
        The scope that was scanned.

    .PARAMETER StartTime
        When the scan started.

    .PARAMETER DiscoveryData
        The discovery phase output.

    .PARAMETER AnalysisResults
        The analysis phase output (array of findings).

    .EXAMPLE
        $report = Invoke-CIEMReport -ScanId $id -Provider Azure -Scope $sub -StartTime $start -DiscoveryData $data -AnalysisResults $findings

    .OUTPUTS
        PSCustomObject containing the complete scan report.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScanId,

        [Parameter(Mandatory = $true)]
        [string]$Provider,

        [Parameter(Mandatory = $true)]
        [string]$Scope,

        [Parameter(Mandatory = $true)]
        [datetime]$StartTime,

        [Parameter(Mandatory = $true)]
        [PSCustomObject]$DiscoveryData,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$AnalysisResults
    )

    begin {
        Write-Verbose "Generating report for scan $ScanId"
    }

    process {
        $endTime = Get-Date

        # Build severity counts
        $severityCounts = @{
            Critical = 0
            High     = 0
            Medium   = 0
            Low      = 0
        }

        foreach ($finding in $AnalysisResults) {
            if ($severityCounts.ContainsKey($finding.Severity)) {
                $severityCounts[$finding.Severity]++
            }
        }

        # Build the report structure
        $report = [PSCustomObject]@{
            scanMetadata = [PSCustomObject]@{
                scanId        = $ScanId
                instanceId    = [System.Environment]::MachineName
                scanTimestamp = $StartTime.ToUniversalTime().ToString('o')
                completedAt   = $endTime.ToUniversalTime().ToString('o')
                durationMs    = [int]($endTime - $StartTime).TotalMilliseconds
                cloudProvider = $Provider.ToLower()
                scope         = $Scope
                toolVersion   = (Get-Module DevolutionsCIEM -ErrorAction SilentlyContinue).Version.ToString()
            }

            discoveryStats = [PSCustomObject]@{
                roleAssignments = $DiscoveryData.RoleAssignments.Count
                roleDefinitions = $DiscoveryData.RoleDefinitions.Count
                identities      = $DiscoveryData.Identities.Count
                resources       = $DiscoveryData.Resources.Count
                errors          = $DiscoveryData.Errors.Count
            }

            findings = $AnalysisResults | ForEach-Object {
                [PSCustomObject]@{
                    id          = $_.Id
                    ruleId      = $_.RuleId
                    type        = $_.Type
                    severity    = $_.Severity
                    resource    = $_.Resource
                    description = $_.Description
                    evidence    = $_.Evidence
                    remediation = $_.Remediation
                }
            }

            summary = [PSCustomObject]@{
                totalFindings = $AnalysisResults.Count
                bySeverity    = [PSCustomObject]$severityCounts
            }
        }

        Write-Host "  Report generated: $($AnalysisResults.Count) findings" -ForegroundColor Gray

        return $report
    }
}
