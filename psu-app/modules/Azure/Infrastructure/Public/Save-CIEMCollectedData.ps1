function Save-CIEMCollectedData {
    <#
    .SYNOPSIS
        Persists all collected service data to normalized Azure tables.
    .DESCRIPTION
        Orchestrator that delegates to per-service save functions. Called during a
        scan after service data has been collected. Each service parameter is optional;
        only provided services are persisted (and their tables cleared).

        Per-service functions:
          Save-CIEMAzureEntraData, Save-CIEMAzureIAMData, Save-CIEMAzureDefenderData,
          Save-CIEMAzureMonitorData, Save-CIEMAzureNetworkData, Save-CIEMAzurePolicyData,
          Save-CIEMAzureVmData

        Callers that need only a subset of services (e.g., the identity module needs
        only Entra + IAM) should call the per-service functions directly.
    .PARAMETER ProviderId
        The provider ID (lowercase name, e.g., 'azure').
    .PARAMETER EntraData
        The Entra service data hashtable from Get-CIEMAzureEntraData.
    .PARAMETER IAMData
        The IAM service data hashtable from Get-CIEMAzureIAMData.
    .PARAMETER DefenderData
        The Defender service cache hashtable (keyed by subscription ID).
    .PARAMETER MonitorData
        The Monitor service cache hashtable (keyed by subscription ID).
    .PARAMETER NetworkData
        The Network service cache hashtable (keyed by subscription ID).
    .PARAMETER PolicyData
        The Policy service cache hashtable (keyed by subscription ID).
    .PARAMETER VmData
        The Vm service cache hashtable (keyed by subscription ID).
    .PARAMETER TenantId
        The Azure AD tenant ID (for context).
    .EXAMPLE
        Save-CIEMCollectedData -ProviderId 'azure' -EntraData $entra -IAMData $iam -DefenderData $defender
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Persists collected data to database')]
    param(
        [Parameter(Mandatory)]
        [string]$ProviderId,

        [Parameter()]
        [hashtable]$EntraData,

        [Parameter()]
        [hashtable]$IAMData,

        [Parameter()]
        [hashtable]$DefenderData,

        [Parameter()]
        [hashtable]$MonitorData,

        [Parameter()]
        [hashtable]$NetworkData,

        [Parameter()]
        [hashtable]$PolicyData,

        [Parameter()]
        [hashtable]$VmData,

        [Parameter()]
        [string]$TenantId
    )

    $ErrorActionPreference = 'Stop'

    $dbPath = Get-CIEMDatabasePath
    if (-not $dbPath) {
        Write-Verbose "Save-CIEMCollectedData: No database path — skipping."
        return
    }

    # Delegate to per-service save functions (each handles its own clear + insert)
    if ($EntraData) {
        try {
            Save-CIEMAzureEntraData -ProviderId $ProviderId -Data $EntraData
        }
        catch {
            Write-Warning "Save-CIEMCollectedData: Failed to persist Entra data: $($_.Exception.Message)"
        }
    }

    if ($IAMData) {
        try {
            Save-CIEMAzureIAMData -ProviderId $ProviderId -Data $IAMData
        }
        catch {
            Write-Warning "Save-CIEMCollectedData: Failed to persist IAM data: $($_.Exception.Message)"
        }
    }

    if ($DefenderData) {
        try {
            Save-CIEMAzureDefenderData -ProviderId $ProviderId -Data $DefenderData
        }
        catch {
            Write-Warning "Save-CIEMCollectedData: Failed to persist Defender data: $($_.Exception.Message)"
        }
    }

    if ($MonitorData) {
        try {
            Save-CIEMAzureMonitorData -ProviderId $ProviderId -Data $MonitorData
        }
        catch {
            Write-Warning "Save-CIEMCollectedData: Failed to persist Monitor data: $($_.Exception.Message)"
        }
    }

    if ($NetworkData) {
        try {
            Save-CIEMAzureNetworkData -ProviderId $ProviderId -Data $NetworkData
        }
        catch {
            Write-Warning "Save-CIEMCollectedData: Failed to persist Network data: $($_.Exception.Message)"
        }
    }

    if ($PolicyData) {
        try {
            Save-CIEMAzurePolicyData -ProviderId $ProviderId -Data $PolicyData
        }
        catch {
            Write-Warning "Save-CIEMCollectedData: Failed to persist Policy data: $($_.Exception.Message)"
        }
    }

    if ($VmData) {
        try {
            Save-CIEMAzureVmData -ProviderId $ProviderId -Data $VmData
        }
        catch {
            Write-Warning "Save-CIEMCollectedData: Failed to persist Vm data: $($_.Exception.Message)"
        }
    }

    Write-Verbose "Save-CIEMCollectedData: Persisted collected data for provider '$ProviderId'"
}
