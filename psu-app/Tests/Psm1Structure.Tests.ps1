BeforeAll {
    $script:Psm1Content = Get-Content (Join-Path $PSScriptRoot '..' 'Devolutions.CIEM.psm1') -Raw
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

        It 'Does NOT contain Identity classes loading block (CIEMGraphNode, etc.)' {
            $script:Psm1Content | Should -Not -Match 'CIEMGraphNode'
            $script:Psm1Content | Should -Not -Match 'CIEMIdentityNodes'
            $script:Psm1Content | Should -Not -Match 'CIEMRBACNodes'
            $script:Psm1Content | Should -Not -Match 'CIEMGraphEdge'
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
