function Save-CIEMAzureDefenderData {
    <#
    .SYNOPSIS
        Persists Defender data to the azure_service_data table.
    .PARAMETER ProviderId
        The provider ID (lowercase name, e.g., 'azure').
    .PARAMETER Data
        The Defender service data hashtable (keyed by subscription ID).
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Persists collected data to database')]
    param(
        [Parameter(Mandatory)]
        [string]$ProviderId,

        [Parameter(Mandatory)]
        [hashtable]$Data
    )

    $ErrorActionPreference = 'Stop'

    # Clear previous Defender data
    Remove-CIEMAzureServiceData -ProviderId $ProviderId -ServiceName 'Defender' -Confirm:$false

    foreach ($subscriptionId in $Data.Keys) {
        $sub = $Data[$subscriptionId]
        if (-not $sub) { continue }

        if ($sub.Pricings) {
            foreach ($key in @($sub.Pricings.Keys)) {
                Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                    -ServiceName 'Defender' -ResourceType 'Pricing' `
                    -ResourceId $key -ResourceName $key -Data $sub.Pricings[$key]
            }
        }

        if ($sub.AutoProvisioningSettings) {
            foreach ($key in @($sub.AutoProvisioningSettings.Keys)) {
                Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                    -ServiceName 'Defender' -ResourceType 'AutoProvisioningSetting' `
                    -ResourceId $key -ResourceName $key -Data $sub.AutoProvisioningSettings[$key]
            }
        }

        if ($sub.Assessments) {
            foreach ($key in @($sub.Assessments.Keys)) {
                $a = $sub.Assessments[$key]
                Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                    -ServiceName 'Defender' -ResourceType 'Assessment' `
                    -ResourceId $a.ResourceId -ResourceName $key -Data $a
            }
        }

        if ($sub.Settings) {
            foreach ($key in @($sub.Settings.Keys)) {
                Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                    -ServiceName 'Defender' -ResourceType 'Setting' `
                    -ResourceId $key -ResourceName $key -Data $sub.Settings[$key]
            }
        }

        if ($sub.SecurityContacts) {
            foreach ($key in @($sub.SecurityContacts.Keys)) {
                $c = $sub.SecurityContacts[$key]
                Save-CIEMAzureServiceData -ProviderId $ProviderId -SubscriptionId $subscriptionId `
                    -ServiceName 'Defender' -ResourceType 'SecurityContact' `
                    -ResourceId $c.Id -ResourceName $c.Name -Data $c
            }
        }
    }
}
