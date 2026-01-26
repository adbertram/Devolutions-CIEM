function Invoke-CIEMAnalysis {
    <#
    .SYNOPSIS
        Executes the analysis phase to identify security issues in discovered data.

    .DESCRIPTION
        Applies detection rules against the discovery data to identify:
        - Orphaned role assignments
        - Overprivileged identities
        - Wildcard permissions
        - Stale credentials
        - And other CIEM security issues

    .PARAMETER DiscoveryData
        The output from Invoke-CIEMDiscovery containing collected cloud data.

    .PARAMETER Rules
        Optional array of rule IDs to run. If not specified, runs all applicable rules.

    .EXAMPLE
        $results = Invoke-CIEMAnalysis -DiscoveryData $discoveryData

    .EXAMPLE
        $results = Invoke-CIEMAnalysis -DiscoveryData $discoveryData -Rules @('AZURE-001', 'AZURE-002')

    .OUTPUTS
        Array of finding objects, each containing the detection results.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$DiscoveryData,

        [Parameter(Mandatory = $false)]
        [string[]]$Rules
    )

    begin {
        Write-Verbose "Starting analysis phase"
        $findings = @()
    }

    process {
        # Get applicable rules for the provider
        $applicableRules = Get-CIEMRules -Provider $DiscoveryData.Provider

        if ($Rules) {
            $applicableRules = $applicableRules | Where-Object { $_.Id -in $Rules }
        }

        Write-Host "  Running $($applicableRules.Count) detection rules..." -ForegroundColor Gray

        foreach ($rule in $applicableRules) {
            Write-Verbose "Executing rule: $($rule.Id) - $($rule.Name)"

            try {
                $ruleFindings = & $rule.ScriptBlock -DiscoveryData $DiscoveryData

                if ($ruleFindings) {
                    $findings += $ruleFindings
                    Write-Verbose "  Rule $($rule.Id) found $($ruleFindings.Count) issue(s)"
                }
            }
            catch {
                Write-Warning "Rule $($rule.Id) failed: $_"
            }
        }

        # Store in module scope
        $script:AnalysisResults = $findings

        # Summary by severity
        $bySeverity = $findings | Group-Object -Property Severity
        Write-Host "  Findings:" -ForegroundColor Gray
        foreach ($group in $bySeverity | Sort-Object Name) {
            $color = switch ($group.Name) {
                'Critical' { 'Red' }
                'High' { 'DarkYellow' }
                'Medium' { 'Yellow' }
                'Low' { 'Gray' }
                default { 'White' }
            }
            Write-Host "    - $($group.Name): $($group.Count)" -ForegroundColor $color
        }

        return $findings
    }
}
