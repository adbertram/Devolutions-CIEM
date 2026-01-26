function Invoke-CIEMDiscovery {
    <#
    .SYNOPSIS
        Executes the discovery phase to collect cloud resources and permissions.

    .DESCRIPTION
        Scans the specified cloud provider and scope to collect:
        - Resources and their metadata
        - Role assignments / IAM policies
        - Role definitions / policy documents
        - Identity information (users, groups, service principals)
        - Credential metadata (expiration, last used)

    .PARAMETER Provider
        The cloud provider to scan: 'Azure' or 'AWS'.

    .PARAMETER Scope
        The scope to scan. For Azure, this is a subscription ID. For AWS, this is an account ID.

    .EXAMPLE
        $data = Invoke-CIEMDiscovery -Provider Azure -Scope "12345678-1234-1234-1234-123456789012"

    .OUTPUTS
        PSCustomObject containing all discovered data in a normalized schema.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Azure', 'AWS')]
        [string]$Provider,

        [Parameter(Mandatory = $true)]
        [string]$Scope
    )

    begin {
        Write-Verbose "Starting discovery for $Provider scope: $Scope"
    }

    process {
        $discoveryData = [PSCustomObject]@{
            Provider          = $Provider
            Scope             = $Scope
            CollectedAt       = (Get-Date).ToUniversalTime().ToString('o')
            RoleAssignments   = @()
            RoleDefinitions   = @()
            Identities        = @()
            Resources         = @()
            Credentials       = @()
            ClassicAdmins     = @()
            Errors            = @()
        }

        switch ($Provider) {
            'Azure' {
                $discoveryData = Get-AzureDiscoveryData -Scope $Scope -DiscoveryData $discoveryData
            }
            'AWS' {
                $discoveryData = Get-AWSDiscoveryData -Scope $Scope -DiscoveryData $discoveryData
            }
        }

        # Store in module scope for potential re-analysis
        $script:DiscoveryData = $discoveryData

        # Summary
        Write-Host "  Discovered:" -ForegroundColor Gray
        Write-Host "    - $($discoveryData.RoleAssignments.Count) role assignments" -ForegroundColor Gray
        Write-Host "    - $($discoveryData.RoleDefinitions.Count) role definitions" -ForegroundColor Gray
        Write-Host "    - $($discoveryData.Identities.Count) identities" -ForegroundColor Gray
        Write-Host "    - $($discoveryData.Resources.Count) resources" -ForegroundColor Gray

        if ($discoveryData.Errors.Count -gt 0) {
            Write-Warning "  $($discoveryData.Errors.Count) errors occurred during discovery"
        }

        return $discoveryData
    }
}
