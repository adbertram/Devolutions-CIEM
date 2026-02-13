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
        Write-CIEMLog -Severity DEBUG -Message "Loading Defender resources for subscription: $subscriptionId"

        $data[$subscriptionId] = @{
            Pricings                 = @{}
            SecurityContacts         = @{}
            AutoProvisioningSettings = @{}
            Assessments              = @{}
            Settings                 = @{}
        }

        $securityBase = "$armApiBase/subscriptions/$subscriptionId/providers/Microsoft.Security"

        # --- Pricings (Defender plan tiers) ---
        $params = @{
            Uri          = "$securityBase/pricings?api-version=2024-01-01"
            ResourceName = "Defender Pricings ($subscriptionId)"
        }
        $pricings = Invoke-AzureApi @params

        if ($pricings) {
            foreach ($pricing in $pricings) {
                $pricingName = $pricing.name

                # Build extensions hashtable (extension name -> isEnabled)
                $extensions = @{}
                $extList = if ($pricing.PSObject.Properties['properties'] -and
                    $pricing.properties.PSObject.Properties['extensions']) {
                    $pricing.properties.extensions
                } else { @() }
                foreach ($ext in $extList) {
                    $extensions[$ext.name] = ($ext.isEnabled -eq 'True')
                }

                $data[$subscriptionId].Pricings[$pricingName] = [PSCustomObject]@{
                    ResourceId             = $pricing.id
                    ResourceName           = $pricingName
                    PricingTier            = if ($pricing.PSObject.Properties['properties']) { $pricing.properties.pricingTier } else { $null }
                    FreeTrialRemainingTime = if ($pricing.PSObject.Properties['properties'] -and
                        $pricing.properties.PSObject.Properties['freeTrialRemainingTime']) {
                        $pricing.properties.freeTrialRemainingTime
                    } else { $null }
                    Extensions             = $extensions
                }
            }
        }

        # --- Auto Provisioning Settings ---
        $params = @{
            Uri          = "$securityBase/autoProvisioningSettings?api-version=2017-08-01-preview"
            ResourceName = "Defender AutoProvisioning ($subscriptionId)"
        }
        $autoProvisioningList = Invoke-AzureApi @params

        if ($autoProvisioningList) {
            foreach ($ap in $autoProvisioningList) {
                $apName = $ap.name
                $data[$subscriptionId].AutoProvisioningSettings[$apName] = [PSCustomObject]@{
                    ResourceId   = $ap.id
                    ResourceName = $apName
                    ResourceType = $ap.type
                    AutoProvision = if ($ap.PSObject.Properties['properties']) { $ap.properties.autoProvision } else { $null }
                }
            }
        }

        # --- Assessments ---
        $params = @{
            Uri          = "$securityBase/assessments?api-version=2021-06-01"
            ResourceName = "Defender Assessments ($subscriptionId)"
        }
        $assessmentsList = Invoke-AzureApi @params

        if ($assessmentsList) {
            foreach ($assessment in $assessmentsList) {
                $displayName = if ($assessment.PSObject.Properties['properties'] -and
                    $assessment.properties.PSObject.Properties['displayName']) {
                    $assessment.properties.displayName
                } else { $assessment.name }

                $statusCode = if ($assessment.PSObject.Properties['properties'] -and
                    $assessment.properties.PSObject.Properties['status'] -and
                    $assessment.properties.status.PSObject.Properties['code']) {
                    $assessment.properties.status.code
                } else { $null }

                $data[$subscriptionId].Assessments[$displayName] = [PSCustomObject]@{
                    ResourceId   = $assessment.id
                    ResourceName = $assessment.name
                    Status       = $statusCode
                }
            }
        }

        # --- Settings (Advanced Threat Protection: MCAS, WDATP, etc.) ---
        $params = @{
            Uri          = "$securityBase/settings?api-version=2022-05-01"
            ResourceName = "Defender Settings ($subscriptionId)"
        }
        $settingsList = Invoke-AzureApi @params

        if ($settingsList) {
            foreach ($setting in $settingsList) {
                $settingName = $setting.name
                $data[$subscriptionId].Settings[$settingName] = [PSCustomObject]@{
                    ResourceId   = $setting.id
                    ResourceType = $setting.type
                    Kind         = $setting.kind
                    Enabled      = if ($setting.PSObject.Properties['properties'] -and
                        $setting.properties.PSObject.Properties['enabled']) {
                        $setting.properties.enabled
                    } else { $false }
                }
            }
        }

        # --- Security Contacts ---
        $params = @{
            Uri          = "$securityBase/securityContacts?api-version=2020-01-01-preview"
            ResourceName = "Defender SecurityContacts ($subscriptionId)"
        }
        $contactsList = Invoke-AzureApi @params

        if ($contactsList) {
            foreach ($contact in $contactsList) {
                $contactName = if ($contact.PSObject.Properties['name']) { $contact.name } else { 'default' }
                $props = if ($contact.PSObject.Properties['properties']) { $contact.properties } else { $null }

                # Parse notificationsByRole
                $notifByRoleState = $false
                $notifByRoleRoles = @()
                if ($props -and $props.PSObject.Properties['notificationsByRole']) {
                    $notifByRole = $props.notificationsByRole
                    if ($notifByRole.PSObject.Properties['state']) {
                        $notifByRoleState = ($notifByRole.state -eq 'On')
                    }
                    if ($notifByRole.PSObject.Properties['roles']) {
                        $notifByRoleRoles = @($notifByRole.roles)
                    }
                }

                # Parse notificationsSources for attack path risk level and alert severity
                $attackPathMinimalRiskLevel = $null
                $alertMinimalSeverity = $null
                if ($props -and $props.PSObject.Properties['notificationsSources']) {
                    foreach ($source in $props.notificationsSources) {
                        if ($source.PSObject.Properties['sourceType']) {
                            if ($source.sourceType -eq 'AttackPath' -and $source.PSObject.Properties['minimalRiskLevel']) {
                                $attackPathMinimalRiskLevel = $source.minimalRiskLevel
                            }
                            elseif ($source.sourceType -eq 'Alert' -and $source.PSObject.Properties['minimalSeverity']) {
                                $alertMinimalSeverity = $source.minimalSeverity
                            }
                        }
                    }
                }

                # Parse alertNotifications for older API format
                $alertNotificationsState = $false
                $alertNotificationsMinSeverity = $null
                if ($props -and $props.PSObject.Properties['alertNotifications']) {
                    $alertNotif = $props.alertNotifications
                    if ($alertNotif.PSObject.Properties['state']) {
                        $alertNotificationsState = ($alertNotif.state -eq 'On')
                    }
                    if ($alertNotif.PSObject.Properties['minimalSeverity']) {
                        $alertNotificationsMinSeverity = $alertNotif.minimalSeverity
                    }
                }

                # Use alertNotifications severity as fallback if notificationsSources not present
                if (-not $alertMinimalSeverity -and $alertNotificationsMinSeverity) {
                    $alertMinimalSeverity = $alertNotificationsMinSeverity
                }

                $data[$subscriptionId].SecurityContacts[$contactName] = [PSCustomObject]@{
                    Id                          = if ($contact.PSObject.Properties['id']) { $contact.id } else { '' }
                    Name                        = $contactName
                    Enabled                     = if ($props -and $props.PSObject.Properties['isEnabled']) { $props.isEnabled } else { $false }
                    Emails                      = if ($props -and $props.PSObject.Properties['emails'] -and $props.emails) {
                        @($props.emails -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
                    } else { @() }
                    Phone                       = if ($props -and $props.PSObject.Properties['phone']) { $props.phone } else { $null }
                    NotificationsByRoleState     = $notifByRoleState
                    NotificationsByRoleRoles     = $notifByRoleRoles
                    AttackPathMinimalRiskLevel  = $attackPathMinimalRiskLevel
                    AlertMinimalSeverity        = $alertMinimalSeverity
                    AlertNotificationsState     = $alertNotificationsState
                }
            }
        }

        # Log summary
        $counts = @{
            Pricings         = $data[$subscriptionId].Pricings.Count
            AutoProvisioning = $data[$subscriptionId].AutoProvisioningSettings.Count
            Assessments      = $data[$subscriptionId].Assessments.Count
            Settings         = $data[$subscriptionId].Settings.Count
            Contacts         = $data[$subscriptionId].SecurityContacts.Count
        }

        Write-CIEMLog -Severity DEBUG -Message "Defender loaded for $subscriptionId : $($counts.Pricings) pricings, $($counts.AutoProvisioning) auto-provisioning, $($counts.Assessments) assessments, $($counts.Settings) settings, $($counts.Contacts) contacts"
    }
}

$data
