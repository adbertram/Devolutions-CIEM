[CmdletBinding()]
param(
    [Parameter()]
    [string[]]$SubscriptionIds = @()
)

$ErrorActionPreference = 'Stop'

# Initialize service hashtable keyed by subscription
$data = @{}

if (-not $SubscriptionIds -or $SubscriptionIds.Count -eq 0) {
    # Nothing to process - script ends naturally
}
else {
    $armApiBase = (Get-CIEMProvider -Name 'Azure').Endpoints.armApi

    foreach ($subscriptionId in $SubscriptionIds) {
        Write-CIEMLog -Severity DEBUG -Message "Loading Policy resources for subscription: $subscriptionId"

        $data[$subscriptionId] = @{
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

                $data[$subscriptionId].PolicyAssignments[$assignmentName] = [PSCustomObject]@{
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
    }
}

$data
