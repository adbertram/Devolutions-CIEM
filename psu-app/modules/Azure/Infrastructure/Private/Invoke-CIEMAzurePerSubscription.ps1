function Invoke-CIEMAzurePerSubscription {
    <#
    .SYNOPSIS
        Iterates over all Azure subscriptions in the auth context and collects per-subscription data.
    .DESCRIPTION
        Shared boilerplate for Get-CIEMAzure*Data functions. Resolves subscription IDs
        and ARM API base URL, then invokes the provided scriptblock once per subscription.
        Returns a hashtable keyed by subscription ID.
    .PARAMETER ServiceName
        Friendly name used in log messages (e.g., 'Defender', 'Monitor').
    .PARAMETER ScriptBlock
        Scriptblock called per subscription. Receives two arguments:
        $subscriptionId [string] and $armApiBase [string]. Must return the
        per-subscription data structure (hashtable or array).
    .OUTPUTS
        [hashtable] Keyed by subscription ID with each value being the scriptblock's return.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$ServiceName,

        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock
    )

    $subscriptionIds = @($script:AzureAuthContext.SubscriptionIds)
    $data = @{}

    if ($subscriptionIds -and $subscriptionIds.Count -gt 0) {
        $armApiBase = (Get-CIEMProvider -Name 'Azure').Endpoints.armApi

        foreach ($subscriptionId in $subscriptionIds) {
            Write-CIEMLog -Severity DEBUG -Message "Loading $ServiceName resources for subscription: $subscriptionId"
            $data[$subscriptionId] = & $ScriptBlock $subscriptionId $armApiBase
        }
    }

    $data
}
