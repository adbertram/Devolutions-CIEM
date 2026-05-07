BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}

Describe 'Get-CIEMConnectorPayloadPreview' {
    BeforeEach {
        Mock -ModuleName Devolutions.CIEM Get-CIEMDashboardNeedsAttention {
            @(
                [PSCustomObject]@{
                    Id           = 'identity:user-critical'
                    SourceType   = 'Identity'
                    Severity     = 'Critical'
                    SeverityRank = 1
                    Title        = 'Dormant Admin'
                    Identity     = 'Dormant Admin'
                    IdentityId   = 'user-critical'
                    IdentityType = 'User'
                    TargetId     = '/subscriptions/prod'
                    Target       = '/subscriptions/prod'
                    Reason       = 'Holds privileged role with no sign-in activity for 120 days'
                    Evidence     = '1 entitlement(s); 1 privileged; target /subscriptions/prod'
                    DrillInUrl   = '/ciem/identities'
                }
            )
        }

        Mock -ModuleName Devolutions.CIEM Get-CIEMExposureChange {
            @(
                [PSCustomObject]@{
                    Id                   = '99:NewRisk:identity:user-critical'
                    ChangeType           = 'NewRisk'
                    ExposureType         = 'IdentityRisk'
                    Severity             = 'Critical'
                    SeverityRank         = 1
                    Title                = 'Dormant Admin'
                    PreviousSeverity     = ''
                    CurrentSeverity      = 'Critical'
                    ImpactedIdentityId   = 'user-critical'
                    ImpactedIdentityName = 'Dormant Admin'
                    ImpactedIdentityType = 'User'
                    ImpactedResourceId   = '/subscriptions/prod'
                    ImpactedResourceName = 'Production Subscription'
                    Evidence             = 'Dormant Admin exposure is Critical'
                }
            )
        }
    }

    It 'exports the connector preview command with strict connector and signal parameters' {
        $command = Get-Command Get-CIEMConnectorPayloadPreview -Module Devolutions.CIEM -ErrorAction Stop
        $command | Should -Not -BeNullOrEmpty

        $connectorValidateSet = $command.Parameters['ConnectorType'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
        $signalValidateSet = $command.Parameters['SignalType'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }

        $connectorValidateSet.ValidValues | Should -Contain 'Alert'
        $connectorValidateSet.ValidValues | Should -Contain 'SIEM'
        $connectorValidateSet.ValidValues | Should -Contain 'Webhook'
        $connectorValidateSet.ValidValues | Should -Contain 'PSU'
        $signalValidateSet.ValidValues | Should -Contain 'NeedsAttention'
        $signalValidateSet.ValidValues | Should -Contain 'ExposureChange'
    }

    It 'renders preview-only payloads for all connector families from exposure changes' {
        $previews = @(Get-CIEMConnectorPayloadPreview -SignalType ExposureChange -ConnectorType Alert, SIEM, Webhook, PSU -Limit 1)

        $previews | Should -HaveCount 4
        $previews.ConnectorType | Should -Contain 'Alert'
        $previews.ConnectorType | Should -Contain 'SIEM'
        $previews.ConnectorType | Should -Contain 'Webhook'
        $previews.ConnectorType | Should -Contain 'PSU'

        foreach ($preview in $previews) {
            $payload = $preview.PayloadJson | ConvertFrom-Json
            $payload.previewOnly | Should -BeTrue
            $payload.deliveryEnabled | Should -BeFalse
            $payload.eventName | Should -Be 'ciem.exposure.changed'
            $payload.signalType | Should -Be 'ExposureChange'
            $payload.identity.id | Should -Be 'user-critical'
            $payload.target.name | Should -Be 'Production Subscription'
            $payload.review.action | Should -Be 'ReviewIdentity'
            $payload.review.route | Should -Be '/ciem/identities'
            $payload.PSObject.Properties.Name | Should -Not -Contain 'targetUrl'
            $payload.PSObject.Properties.Name | Should -Not -Contain 'token'
        }
    }

    It 'renders Needs Attention payloads with the dashboard drill-in route' {
        $preview = @(Get-CIEMConnectorPayloadPreview -SignalType NeedsAttention -ConnectorType Webhook -Limit 1)[0]
        $payload = $preview.PayloadJson | ConvertFrom-Json

        $preview.EventName | Should -Be 'ciem.risk.needs_attention'
        $preview.ReviewRoute | Should -Be '/ciem/identities'
        $payload.reason | Should -Be 'Holds privileged role with no sign-in activity for 120 days'
        $payload.connectorPreview.method | Should -Be 'POST'
        $payload.connectorPreview.body | Should -Be 'json'
    }

    It 'keeps Needs Attention target IDs distinct from display names' {
        Mock -ModuleName Devolutions.CIEM Get-CIEMDashboardNeedsAttention {
            @(
                [PSCustomObject]@{
                    Id           = 'attack-path:public-nsg'
                    SourceType   = 'AttackPath'
                    Severity     = 'High'
                    SeverityRank = 2
                    Title        = 'Management port open to the internet'
                    Identity     = ''
                    IdentityId   = ''
                    IdentityType = ''
                    TargetId     = '/subscriptions/prod/resourceGroups/rg/providers/Microsoft.Network/networkSecurityGroups/nsg-public'
                    Target       = 'Public NSG'
                    Reason       = 'Attack path exposes Public NSG'
                    Evidence     = 'Internet -> Public NSG'
                    DrillInUrl   = '/ciem/attack-paths'
                }
            )
        }

        $preview = @(Get-CIEMConnectorPayloadPreview -SignalType NeedsAttention -ConnectorType Webhook -Limit 1)[0]
        $payload = $preview.PayloadJson | ConvertFrom-Json

        $payload.target.id | Should -Be '/subscriptions/prod/resourceGroups/rg/providers/Microsoft.Network/networkSecurityGroups/nsg-public'
        $payload.target.name | Should -Be 'Public NSG'
        $payload.review.action | Should -Be 'ReviewAttackPath'
        $payload.review.route | Should -Be '/ciem/attack-paths'
    }

    It 'keeps exposure-change titles from the stored change record' {
        Mock -ModuleName Devolutions.CIEM Get-CIEMExposureChange {
            @(
                [PSCustomObject]@{
                    Id                   = '99:NewRisk:attack-path:public-nsg'
                    ChangeType           = 'NewRisk'
                    ExposureType         = 'AttackPath'
                    Severity             = 'High'
                    SeverityRank         = 2
                    Title                = 'Management port open to the internet'
                    PreviousSeverity     = ''
                    CurrentSeverity      = 'High'
                    ImpactedIdentityId   = ''
                    ImpactedIdentityName = ''
                    ImpactedIdentityType = ''
                    ImpactedResourceId   = '/subscriptions/prod/resourceGroups/rg/providers/Microsoft.Network/networkSecurityGroups/nsg-public'
                    ImpactedResourceName = 'Public NSG'
                    Evidence             = 'Internet -> Public NSG'
                }
            )
        }

        $preview = @(Get-CIEMConnectorPayloadPreview -SignalType ExposureChange -ConnectorType Alert -Limit 1)[0]
        $payload = $preview.PayloadJson | ConvertFrom-Json

        $preview.Title | Should -Be 'Management port open to the internet'
        $payload.title | Should -Be 'Management port open to the internet'
        $payload.target.id | Should -Be '/subscriptions/prod/resourceGroups/rg/providers/Microsoft.Network/networkSecurityGroups/nsg-public'
        $payload.target.name | Should -Be 'Public NSG'
    }

    It 'honors source limits for every selected signal source' {
        Get-CIEMConnectorPayloadPreview -SignalType All -ConnectorType Alert -Limit 1 | Out-Null

        Should -Invoke -CommandName Get-CIEMDashboardNeedsAttention -ModuleName Devolutions.CIEM -Times 1 -ParameterFilter {
            $Limit -eq 1
        }
        Should -Invoke -CommandName Get-CIEMExposureChange -ModuleName Devolutions.CIEM -Times 1 -ParameterFilter {
            $Last -eq 1
        }
    }

    It 'throws instead of formatting unsupported source types' {
        Mock -ModuleName Devolutions.CIEM Get-CIEMExposureChange {
            @(
                [PSCustomObject]@{
                    Id                   = '99:NewRisk:unsupported:item'
                    ChangeType           = 'NewRisk'
                    ExposureType         = 'Unsupported'
                    Severity             = 'Critical'
                    SeverityRank         = 1
                    Title                = 'Unsupported'
                    PreviousSeverity     = ''
                    CurrentSeverity      = 'Critical'
                    ImpactedIdentityId   = 'user-critical'
                    ImpactedIdentityName = 'Dormant Admin'
                    ImpactedIdentityType = 'User'
                    ImpactedResourceId   = '/subscriptions/prod'
                    ImpactedResourceName = 'Production Subscription'
                    Evidence             = 'Unsupported exposure'
                }
            )
        }

        { Get-CIEMConnectorPayloadPreview -SignalType ExposureChange -ConnectorType Alert -Limit 1 } |
            Should -Throw "Unsupported ExposureChange connector preview source type 'Unsupported'."
    }
}
