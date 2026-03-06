function Get-CIEMAzurePolicyData {
    <#
    .SYNOPSIS
        Fetches Azure Policy assignment data for all subscriptions in the current auth context.

    .DESCRIPTION
        Retrieves Azure Policy assignments from the ARM API for every subscription
        registered in the active CIEM Azure authentication context. Returns a
        hashtable keyed by subscription ID, where each value contains a nested
        hashtable of PolicyAssignments indexed by assignment name.

    .OUTPUTS
        [hashtable]
        A hashtable keyed by subscription ID. Each entry contains:
            PolicyAssignments - hashtable of PSCustomObject entries with Id, Name, EnforcementMode.

    .EXAMPLE
        $policyData = Get-CIEMAzurePolicyData
        $policyData['00000000-0000-0000-0000-000000000000'].PolicyAssignments
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $ErrorActionPreference = 'Stop'

    $subscriptionIds = @($script:AzureAuthContext.SubscriptionIds)
    $data = @{}

    foreach ($subscriptionId in $subscriptionIds) {
        Write-CIEMLog -Severity DEBUG -Message "Loading Policy resources for subscription: $subscriptionId"

        $subData = @{
            PolicyAssignments = @{}
        }

        # --- Policy Assignments ---
        $assignments = Invoke-AzureApi -Api ARM -Path "providers/Microsoft.Authorization/policyAssignments?api-version=2022-06-01" -SubscriptionId $subscriptionId -ResourceName "Policy Assignments"
        $assignments = $assignments[$subscriptionId]

        if ($assignments) {
            foreach ($assignment in $assignments) {
                $assignmentName = $assignment.name

                $subData.PolicyAssignments[$assignmentName] = [PSCustomObject]@{
                    Id              = $assignment.id
                    Name            = $assignmentName
                    EnforcementMode = if ($assignment.PSObject.Properties['properties'] -and
                        $assignment.properties.PSObject.Properties['enforcementMode']) {
                        $assignment.properties.enforcementMode
                    } else { $null }
                }
            }

            Write-CIEMLog -Severity DEBUG -Message "Policy loaded for $subscriptionId : $($assignments.Count) assignments"
        }
        else {
            Write-CIEMLog -Severity DEBUG -Message "No Policy Assignments found in subscription $subscriptionId"
        }

        $data[$subscriptionId] = $subData
    }

    $data
}
