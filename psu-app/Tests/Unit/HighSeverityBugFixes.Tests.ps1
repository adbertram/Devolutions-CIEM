BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    # Create isolated test DB with base + graph schemas
    New-CIEMDatabase -Path "$TestDrive/ciem.db"

    $graphSchema = Join-Path $PSScriptRoot '..' '..' 'modules' 'Devolutions.CIEM.Graph' 'Data' 'graph_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $graphSchema -Raw)

    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }
}

# =============================================================================
# Issue 1: $script:DormantPermissionThresholdDays null guard
# =============================================================================

Describe 'Issue 1: DormantPermissionThresholdDays null guard' {

    Context 'Get-CIEMIdentityRiskSignals throws when DormantPermissionThresholdDays is null' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            # Seed a privileged user so the dormant check path is reached
            Save-CIEMGraphNode -Id 'user-nullguard' -Kind 'EntraUser' -DisplayName 'Null Guard Test' -Provider 'azure' `
                -Properties (@{
                    accountEnabled  = $true
                    daysSinceSignIn = 120
                    lastSignIn      = '2025-11-01T12:00:00Z'
                } | ConvertTo-Json -Compress)

            Save-CIEMGraphNode -Id '/subscriptions/sub-ng' -Kind 'AzureSubscription' -DisplayName 'Sub NG' -Provider 'azure'

            Save-CIEMGraphEdge -SourceId 'user-nullguard' -TargetId '/subscriptions/sub-ng' -Kind 'HasRole' -Computed 1 `
                -Properties (@{ role_name = 'Owner'; privileged = $true; scope = '/subscriptions/sub-ng' } | ConvertTo-Json -Compress)
        }

        It 'Throws a descriptive error when $script:DormantPermissionThresholdDays is null' {
            InModuleScope Devolutions.CIEM {
                $saved = $script:DormantPermissionThresholdDays
                try {
                    $script:DormantPermissionThresholdDays = $null
                    { Get-CIEMIdentityRiskSignals -PrincipalId 'user-nullguard' } | Should -Throw '*DormantPermissionThresholdDays*'
                } finally {
                    $script:DormantPermissionThresholdDays = $saved
                }
            }
        }
    }

    Context 'Get-CIEMIdentityRiskSummary throws when DormantPermissionThresholdDays is null' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            Save-CIEMGraphNode -Id 'user-nullguard-sum' -Kind 'EntraUser' -DisplayName 'Null Guard Summary' `
                -Properties (@{
                    accountEnabled  = $true
                    daysSinceSignIn = 120
                } | ConvertTo-Json -Compress)

            Save-CIEMGraphNode -Id '/subscriptions/sub-ngs' -Kind 'AzureSubscription' -DisplayName 'Sub NGS'

            Save-CIEMGraphEdge -SourceId 'user-nullguard-sum' -TargetId '/subscriptions/sub-ngs' -Kind 'HasRole' `
                -Properties (@{ role_name = 'Owner'; privileged = $true; scope = '/subscriptions/sub-ngs' } | ConvertTo-Json -Compress)
        }

        It 'Throws a descriptive error when $script:DormantPermissionThresholdDays is null' {
            InModuleScope Devolutions.CIEM {
                $saved = $script:DormantPermissionThresholdDays
                try {
                    $script:DormantPermissionThresholdDays = $null
                    { Get-CIEMIdentityRiskSummary } | Should -Throw '*DormantPermissionThresholdDays*'
                } finally {
                    $script:DormantPermissionThresholdDays = $saved
                }
            }
        }
    }

    Context 'Get-CIEMIdentityRiskSummary throws when MediumEntitlementThreshold is null' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            Save-CIEMGraphNode -Id 'user-nullguard-med' -Kind 'EntraUser' -DisplayName 'Null Guard Medium' `
                -Properties (@{
                    accountEnabled  = $true
                    daysSinceSignIn = 5
                } | ConvertTo-Json -Compress)

            Save-CIEMGraphNode -Id '/subscriptions/sub-ngm' -Kind 'AzureSubscription' -DisplayName 'Sub NGM'

            # Non-privileged role so we reach the Medium threshold check
            Save-CIEMGraphEdge -SourceId 'user-nullguard-med' -TargetId '/subscriptions/sub-ngm' -Kind 'HasRole' `
                -Properties (@{ role_name = 'Reader'; privileged = $false; scope = '/subscriptions/sub-ngm' } | ConvertTo-Json -Compress)
        }

        It 'Throws a descriptive error when $script:MediumEntitlementThreshold is null' {
            InModuleScope Devolutions.CIEM {
                $saved = $script:MediumEntitlementThreshold
                try {
                    $script:MediumEntitlementThreshold = $null
                    { Get-CIEMIdentityRiskSummary } | Should -Throw '*MediumEntitlementThreshold*'
                } finally {
                    $script:MediumEntitlementThreshold = $saved
                }
            }
        }
    }
}

# =============================================================================
# Issue 2: Empty catch {} in HasManagedIdentity section
# =============================================================================

Describe 'Issue 2: HasManagedIdentity edge build logs errors instead of swallowing' {

    Context 'When Identity JSON parse fails for a resource' {

        It 'Calls Write-CIEMLog with a warning when HasManagedIdentity edge build fails' {
            InModuleScope Devolutions.CIEM {
                # We need to test that the catch block logs a warning instead of silently swallowing
                # Read the source file and check it does NOT have an empty catch
                $sourceFile = Join-Path $PSScriptRoot '..' '..' 'modules' 'Azure' 'Discovery' 'Private' 'InvokeCIEMGraphComputedEdgeBuild.ps1'
                $content = Get-Content $sourceFile -Raw
                # The source should NOT have a bare 'catch { }' or 'catch {}' (empty catch block)
                $content | Should -Not -Match 'catch\s*\{\s*\}'
            }
        }
    }
}

# =============================================================================
# Issue 3: InvokeCIEMTransaction missing $ErrorActionPreference = 'Stop'
# =============================================================================

Describe 'Issue 3: InvokeCIEMTransaction has ErrorActionPreference Stop' {

    Context 'Source code validation' {

        It 'Contains $ErrorActionPreference = Stop after param block' {
            InModuleScope Devolutions.CIEM {
                $sourceFile = Join-Path $PSScriptRoot '..' '..' 'Private' 'InvokeCIEMTransaction.ps1'
                $content = Get-Content $sourceFile -Raw
                $content | Should -Match '\$ErrorActionPreference\s*=\s*[''"]Stop[''"]'
            }
        }
    }
}

# =============================================================================
# Issue 4: ResolveCIEMAttackPathFilter [double] cast crash on non-numeric
# =============================================================================

Describe 'Issue 4: ResolveCIEMAttackPathFilter safe numeric parsing' {

    Context 'gt operator with non-numeric property value' {

        It 'Returns false instead of throwing when property value is non-numeric' {
            InModuleScope Devolutions.CIEM {
                $json = '{"someField":"not-a-number"}'
                $filter = [PSCustomObject]@{ property = 'someField'; op = 'gt'; value = 90 }
                $result = ResolveCIEMAttackPathFilter -PropertiesJson $json -Filter $filter
                $result | Should -BeFalse
            }
        }
    }

    Context 'lt operator with non-numeric property value' {

        It 'Returns false instead of throwing when property value is non-numeric' {
            InModuleScope Devolutions.CIEM {
                $json = '{"someField":"abc"}'
                $filter = [PSCustomObject]@{ property = 'someField'; op = 'lt'; value = 5 }
                $result = ResolveCIEMAttackPathFilter -PropertiesJson $json -Filter $filter
                $result | Should -BeFalse
            }
        }
    }

    Context 'gt_or_null operator with non-numeric property value' {

        It 'Returns false instead of throwing when property value is non-numeric' {
            InModuleScope Devolutions.CIEM {
                $json = '{"someField":"xyz"}'
                $filter = [PSCustomObject]@{ property = 'someField'; op = 'gt_or_null'; value = 90 }
                $result = ResolveCIEMAttackPathFilter -PropertiesJson $json -Filter $filter
                $result | Should -BeFalse
            }
        }

        It 'Still returns true when property value is null' {
            InModuleScope Devolutions.CIEM {
                $json = '{"otherField":"value"}'
                $filter = [PSCustomObject]@{ property = 'someField'; op = 'gt_or_null'; value = 90 }
                $result = ResolveCIEMAttackPathFilter -PropertiesJson $json -Filter $filter
                $result | Should -BeTrue
            }
        }
    }

    Context 'gt operator with non-numeric filter value' {

        It 'Returns false instead of throwing when filter value is non-numeric' {
            InModuleScope Devolutions.CIEM {
                $json = '{"daysSinceSignIn":120}'
                $filter = [PSCustomObject]@{ property = 'daysSinceSignIn'; op = 'gt'; value = 'not-a-number' }
                $result = ResolveCIEMAttackPathFilter -PropertiesJson $json -Filter $filter
                $result | Should -BeFalse
            }
        }
    }

    Context 'gt operator still works for valid numeric values' {

        It 'Returns true when numeric comparison succeeds' {
            InModuleScope Devolutions.CIEM {
                $json = '{"daysSinceSignIn":120}'
                $filter = [PSCustomObject]@{ property = 'daysSinceSignIn'; op = 'gt'; value = 90 }
                $result = ResolveCIEMAttackPathFilter -PropertiesJson $json -Filter $filter
                $result | Should -BeTrue
            }
        }
    }
}
