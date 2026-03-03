function Get-CIEMAzurePolicyData {
    <#
    .SYNOPSIS
        Fetches Azure Policy assignment data for all subscriptions in the current auth context.

    .DESCRIPTION
        Retrieves Azure Policy assignments from the ARM API for every subscription
        registered in the active CIEM Azure authentication context. Returns a
        hashtable keyed by subscription ID, where each value contains a nested
        hashtable of PolicyAssignments indexed by assignment name.

    .PARAMETER Api
        Reserved for future use. Accepted but not used by this function.

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
    param(
        [Parameter()]
        [CIEMAzureProviderApi]$Api
    )

    $ErrorActionPreference = 'Stop'

    Invoke-CIEMAzurePerSubscription -ServiceName 'Policy' -ScriptBlock {
        param($subscriptionId, $armApiBase)

        $subData = @{
            PolicyAssignments = @{}
        }

        # --- Policy Assignments ---
        $params = @{
            Uri          = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.Authorization/policyAssignments?api-version=2022-06-01"
            ResourceName = "Policy Assignments ($subscriptionId)"
        }
        $assignments = Invoke-AzureApi @params

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

        $subData
    }
}
