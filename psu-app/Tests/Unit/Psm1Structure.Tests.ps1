BeforeAll {
    $script:Psm1Content = Get-Content (Join-Path $PSScriptRoot '..' '..' 'Devolutions.CIEM.psm1') -Raw
    $script:Psm1Ast = [System.Management.Automation.Language.Parser]::ParseInput($script:Psm1Content, [ref]$null, [ref]$null)
}

Describe 'Devolutions.CIEM.psm1 Structure' {

    Context 'Sub-module root variables' {
        It 'Contains $script:AzureDiscoveryRoot assignment' {
            $script:Psm1Content | Should -Match '\$script:AzureDiscoveryRoot\s*='
        }

        It 'Does NOT contain $script:AzurePermissionsRoot' {
            $script:Psm1Content | Should -Not -Match '\$script:AzurePermissionsRoot'
        }

        It 'Does NOT contain $script:IdentitiesRoot' {
            $script:Psm1Content | Should -Not -Match '\$script:IdentitiesRoot'
        }
    }

    Context 'Class loading' {
        It 'Loads CIEMAuthenticationContext and CIEMProvider base classes' {
            $script:Psm1Content | Should -Match "'CIEMAuthenticationContext'"
            $script:Psm1Content | Should -Match "'CIEMProvider'"
        }

        It 'Does NOT load CIEMIdentity or CIEMResourceType' {
            $script:Psm1Content | Should -Not -Match "'CIEMIdentity'"
            $script:Psm1Content | Should -Not -Match "'CIEMResourceType'"
        }

        It 'Does NOT contain Identity classes loading block' {
            $script:Psm1Content | Should -Not -Match 'CIEMIdentityNodes'
            $script:Psm1Content | Should -Not -Match 'CIEMRBACNodes'
            $script:Psm1Content | Should -Not -Match 'CIEMIdentityResourceAccess'
        }
    }

    Context 'Schema application' {
        It 'Contains discovery_schema.sql in schema loop' {
            $script:Psm1Content | Should -Match 'discovery_schema\.sql'
        }

        It 'Contains AzureDiscovery label' {
            $script:Psm1Content | Should -Match "Label\s*=\s*'AzureDiscovery'"
        }
    }

    Context 'Dead cache keys removed' {
        It 'Does NOT contain GraphLatestCacheKey' {
            $script:Psm1Content | Should -Not -Match 'GraphLatestCacheKey'
        }

        It 'Does NOT contain GraphAzureCacheKey' {
            $script:Psm1Content | Should -Not -Match 'GraphAzureCacheKey'
        }
    }

    Context 'App registration references' {
        BeforeAll {
            $script:AppContent = Get-Content (Join-Path $PSScriptRoot '..' '..' 'modules' 'Devolutions.CIEM.PSU' 'Public' 'New-DevolutionsCIEMApp.ps1') -Raw
        }

        It 'Does NOT reference New-CIEMGraphPage (dead function)' {
            $script:AppContent | Should -Not -Match 'New-CIEMGraphPage'
        }

        It 'Does NOT reference New-CIEMIdentityRiskPage' {
            $script:AppContent | Should -Not -Match 'New-CIEMIdentityRiskPage'
        }

        It 'References New-CIEMIdentitiesPage' {
            $script:AppContent | Should -Match 'New-CIEMIdentitiesPage'
        }

        It 'References New-CIEMAttackPathsPage' {
            $script:AppContent | Should -Match 'New-CIEMAttackPathsPage'
        }
    }

    Context 'No empty catch blocks' {
        It 'Does not contain catch {}' {
            $script:Psm1Content | Should -Not -Match 'catch\s*\{\s*\}'
        }

        It 'throws after logging module initialization failures' {
            $violations = @($script:Psm1Ast.FindAll(
                { param($node) $node -is [System.Management.Automation.Language.CatchClauseAst] },
                $true
            ) | Where-Object {
                $_.Body.Extent.Text -match 'FAILED to load|schema failed|Database initialization failed' -and
                -not $_.Body.Find({ param($node) $node -is [System.Management.Automation.Language.ThrowStatementAst] }, $true)
            })

            $violations | Should -BeNullOrEmpty
        }
    }

    Context 'Schema application fail-fast behavior' {
        It 'Throws when an expected provider schema path is missing' {
            $script:Psm1Content | Should -Match 'Schema file not found'
        }

        It 'Throws when the module database path is unavailable before schema application' {
            $script:Psm1Content | Should -Match 'Database path not resolved'
        }
    }

    Context 'Sub-module roots array' {
        It '$subModuleRoots contains $script:AzureDiscoveryRoot' {
            $script:Psm1Content | Should -Match '\$subModuleRoots\s*=\s*@\([^)]*\$script:AzureDiscoveryRoot'
        }

        It '$subModuleRoots does NOT contain $script:AzurePermissionsRoot' {
            # Extract the $subModuleRoots block and check it doesn't reference the old roots
            $script:Psm1Content | Should -Not -Match '\$subModuleRoots\s*=\s*@\([^)]*AzurePermissionsRoot'
        }

        It '$subModuleRoots does NOT contain $script:IdentitiesRoot' {
            $script:Psm1Content | Should -Not -Match '\$subModuleRoots\s*=\s*@\([^)]*IdentitiesRoot'
        }
    }
}
