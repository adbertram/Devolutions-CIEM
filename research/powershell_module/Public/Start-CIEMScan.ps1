function Start-CIEMScan {
    <#
    .SYNOPSIS
        Orchestrates a complete CIEM scan: Discovery -> Analysis -> Reporting.

    .DESCRIPTION
        Runs the full CIEM pipeline against the specified cloud provider and scope.
        This is the main entry point for running scans.

    .PARAMETER Provider
        The cloud provider to scan: 'Azure' or 'AWS'.

    .PARAMETER Scope
        The scope to scan. For Azure, this is a subscription ID. For AWS, this is an account ID.

    .PARAMETER OutputPath
        Path to write the JSON report. If not specified, returns the report object.

    .PARAMETER Rules
        Optional array of rule IDs to run. If not specified, runs all rules.

    .EXAMPLE
        Start-CIEMScan -Provider Azure -Scope "12345678-1234-1234-1234-123456789012"

    .EXAMPLE
        Start-CIEMScan -Provider AWS -Scope "123456789012" -OutputPath "./report.json"

    .OUTPUTS
        PSCustomObject containing the full scan report, or writes JSON to OutputPath.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Azure', 'AWS')]
        [string]$Provider,

        [Parameter(Mandatory = $true)]
        [string]$Scope,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [string[]]$Rules
    )

    begin {
        $scanId = [guid]::NewGuid().ToString()
        $startTime = Get-Date

        Write-Host "Starting CIEM scan..." -ForegroundColor Cyan
        Write-Host "  Scan ID: $scanId" -ForegroundColor Gray
        Write-Host "  Provider: $Provider" -ForegroundColor Gray
        Write-Host "  Scope: $Scope" -ForegroundColor Gray
    }

    process {
        try {
            # Phase 1: Discovery
            Write-Host "`n[1/3] Discovery Phase" -ForegroundColor Yellow
            $discoveryParams = @{
                Provider = $Provider
                Scope    = $Scope
            }
            $discoveryData = Invoke-CIEMDiscovery @discoveryParams

            if (-not $discoveryData) {
                throw "Discovery phase returned no data"
            }

            # Phase 2: Analysis
            Write-Host "`n[2/3] Analysis Phase" -ForegroundColor Yellow
            $analysisParams = @{
                DiscoveryData = $discoveryData
            }
            if ($Rules) {
                $analysisParams.Rules = $Rules
            }
            $analysisResults = Invoke-CIEMAnalysis @analysisParams

            # Phase 3: Reporting
            Write-Host "`n[3/3] Reporting Phase" -ForegroundColor Yellow
            $reportParams = @{
                ScanId          = $scanId
                Provider        = $Provider
                Scope           = $Scope
                StartTime       = $startTime
                DiscoveryData   = $discoveryData
                AnalysisResults = $analysisResults
            }
            $report = Invoke-CIEMReport @reportParams

            # Output
            if ($OutputPath) {
                $report | ConvertTo-Json -Depth 20 | Out-File -FilePath $OutputPath -Encoding UTF8
                Write-Host "`nReport written to: $OutputPath" -ForegroundColor Green
            }

            return $report
        }
        catch {
            Write-Error "Scan failed: $_"
            throw
        }
    }

    end {
        $duration = (Get-Date) - $startTime
        Write-Host "`nScan completed in $($duration.TotalSeconds.ToString('F2')) seconds" -ForegroundColor Cyan
    }
}
