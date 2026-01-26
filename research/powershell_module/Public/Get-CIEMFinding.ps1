function Get-CIEMFinding {
    <#
    .SYNOPSIS
        Retrieves findings from the most recent analysis.

    .DESCRIPTION
        Returns findings from the last Invoke-CIEMAnalysis run, with optional filtering.

    .PARAMETER Severity
        Filter findings by severity level.

    .PARAMETER RuleId
        Filter findings by rule ID.

    .PARAMETER Type
        Filter findings by detection type.

    .EXAMPLE
        Get-CIEMFinding -Severity Critical

    .EXAMPLE
        Get-CIEMFinding -RuleId 'AZURE-001'

    .OUTPUTS
        Array of finding objects matching the filter criteria.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('Critical', 'High', 'Medium', 'Low')]
        [string]$Severity,

        [Parameter(Mandatory = $false)]
        [string]$RuleId,

        [Parameter(Mandatory = $false)]
        [string]$Type
    )

    process {
        if (-not $script:AnalysisResults) {
            Write-Warning "No analysis results available. Run Invoke-CIEMAnalysis first."
            return @()
        }

        $results = $script:AnalysisResults

        if ($Severity) {
            $results = $results | Where-Object { $_.Severity -eq $Severity }
        }

        if ($RuleId) {
            $results = $results | Where-Object { $_.RuleId -eq $RuleId }
        }

        if ($Type) {
            $results = $results | Where-Object { $_.Type -like "*$Type*" }
        }

        return $results
    }
}
