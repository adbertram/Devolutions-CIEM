#Requires -Version 5.1

<#
.SYNOPSIS
    Devolutions CIEM - Cloud Infrastructure Entitlement Management Module

.DESCRIPTION
    Scans Azure and AWS cloud permissions and produces JSON reports for LLM analysis.

    Architecture:
    - Discovery: Collects resources, identities, and permissions from cloud providers
    - Analysis: Applies detection rules to identify security issues
    - Reporting: Generates JSON output optimized for LLM consumption
#>

# Module-level variables
$script:ModuleRoot = $PSScriptRoot
$script:DiscoveryData = $null
$script:AnalysisResults = $null

# Import private functions
$PrivateFunctions = Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue
foreach ($Function in $PrivateFunctions) {
    try {
        . $Function.FullName
        Write-Verbose "Imported private function: $($Function.BaseName)"
    }
    catch {
        Write-Error "Failed to import private function $($Function.FullName): $_"
    }
}

# Import public functions
$PublicFunctions = Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue
foreach ($Function in $PublicFunctions) {
    try {
        . $Function.FullName
        Write-Verbose "Imported public function: $($Function.BaseName)"
    }
    catch {
        Write-Error "Failed to import public function $($Function.FullName): $_"
    }
}

# Export public functions
Export-ModuleMember -Function $PublicFunctions.BaseName
