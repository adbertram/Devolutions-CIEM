BeforeAll {
    . (Join-Path $PSScriptRoot 'TestSetup.ps1')
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    $script:LegacyPermissionFixture = Get-Content (Join-Path $PSScriptRoot '..' 'Fixtures' 'legacy-permission-output.json') -Raw | ConvertFrom-Json
}

Describe 'InvokeCIEMEntraPermissionCollection' {
    BeforeEach {
        Initialize-DiscoveryTestDatabase
        $script:permissionBatchCallSizes = @()
        Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
        Mock -ModuleName Devolutions.CIEM Write-Progress {}
    }

    It 'Uses Graph batch requests for service principal app role assignments' {
        $servicePrincipals = foreach ($index in 1..100) {
            [pscustomobject]@{ Id = "sp-$index"; DisplayName = "SP $index"; Type = 'servicePrincipal' }
        }

        Mock -ModuleName Devolutions.CIEM Invoke-AzureApi {
            param($Requests)

            if ($null -ne $Requests) {
                $script:permissionBatchCallSizes += @($Requests).Count
                $results = @{}
                foreach ($request in @($Requests)) {
                    $results[$request.Id] = [pscustomobject]@{
                        Success = $true
                        StatusCode = 200
                        Items = @()
                    }
                }
                return $results
            }

            @()
        }

        $result = InModuleScope Devolutions.CIEM -Parameters @{ servicePrincipals = $servicePrincipals } {
            @(InvokeCIEMEntraPermissionCollection -ServicePrincipals $servicePrincipals)
        }

        $result | Should -HaveCount 0
        $script:permissionBatchCallSizes | Should -HaveCount 1
        $script:permissionBatchCallSizes[0] | Should -Be 100
    }

    It 'Materializes appRoleAssignment rows from batched results' {
        $servicePrincipals = @(
            [pscustomobject]@{ Id = 'sp-1'; DisplayName = 'SP 1'; Type = 'servicePrincipal' }
        )

        Mock -ModuleName Devolutions.CIEM Invoke-AzureApi {
            param($Requests)

            if ($null -ne $Requests) {
                @{
                    'sp-1' = [pscustomobject]@{
                        Success = $true
                        StatusCode = 200
                        Items = @(
                            [pscustomobject]@{ id = 'assignment-1'; resourceId = 'res-1' }
                            [pscustomobject]@{ id = 'assignment-2'; resourceId = 'res-2' }
                        )
                    }
                }
                return
            }

            @()
        }

        $results = InModuleScope Devolutions.CIEM -Parameters @{ servicePrincipals = $servicePrincipals } {
            @(InvokeCIEMEntraPermissionCollection -ServicePrincipals $servicePrincipals)
        }

        $results | Should -HaveCount 2
        ($results | ForEach-Object { $_.Type } | Select-Object -Unique) | Should -Be @('appRoleAssignment')
        ($results | ForEach-Object { $_.ParentId } | Select-Object -Unique) | Should -Be @('sp-1')

        $normalizedResults = @(
            $results |
                Sort-Object Id |
                ForEach-Object {
                    [pscustomobject]@{
                        Id = $_.Id
                        Type = $_.Type
                        ParentId = $_.ParentId
                    }
                }
        )
        $normalizedFixture = @($script:LegacyPermissionFixture | Sort-Object Id)

        ($normalizedResults | ConvertTo-Json -Depth 5) | Should -Be ($normalizedFixture | ConvertTo-Json -Depth 5)
    }
}
