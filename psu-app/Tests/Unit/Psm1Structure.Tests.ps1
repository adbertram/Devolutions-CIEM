BeforeAll {
    $repoRoot = Join-Path $PSScriptRoot '..' '..'
    $script:Psm1Content = Get-Content (Join-Path $repoRoot 'Devolutions.CIEM.psm1') -Raw
    $script:Psm1Ast = [System.Management.Automation.Language.Parser]::ParseInput($script:Psm1Content, [ref]$null, [ref]$null)
    $script:NewDatabaseContent = Get-Content (Join-Path $repoRoot 'Public' 'New-CIEMDatabase.ps1') -Raw
    $script:GetDatabasePathContent = Get-Content (Join-Path $repoRoot 'Public' 'Get-CIEMDatabasePath.ps1') -Raw
    $script:InvokeQueryContent = Get-Content (Join-Path $repoRoot 'Public' 'Invoke-CIEMQuery.ps1') -Raw
    $script:ConfigPageContent = Get-Content (Join-Path $repoRoot 'modules' 'Devolutions.CIEM.PSU' 'Pages' 'New-CIEMConfigPage.ps1') -Raw
    $script:ManifestPath = Join-Path $repoRoot 'Devolutions.CIEM.psd1'
    $script:ModuleRootsPath = Join-Path $repoRoot 'Data' 'module_roots.psd1'
    $script:UniversalRoot = Join-Path $repoRoot '.universal'
    $script:InitializeContent = if (Test-Path (Join-Path $script:UniversalRoot 'initialize.ps1') -PathType Leaf) {
        Get-Content (Join-Path $script:UniversalRoot 'initialize.ps1') -Raw
    } else {
        ''
    }
}

Describe 'Devolutions.CIEM.psm1 Structure' {

    Context 'Sub-module root variables' {
        It 'Preserves $script:AzureDiscoveryRoot for runtime consumers' {
            $script:Psm1Content | Should -Match '\$script:AzureDiscoveryRoot'
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
        It 'Does not initialize the database during module import' {
            $script:Psm1Content | Should -Not -Match 'New-CIEMDatabase'
            $script:Psm1Content | Should -Not -Match 'Initializing database'
        }

        It 'Does not apply provider schemas during module import' {
            $script:Psm1Content | Should -Not -Match 'discovery_schema\.sql'
            $script:Psm1Content | Should -Not -Match "Label\s*=\s*'AzureDiscovery'"
        }

        It 'Does not sync attack path storage or rule catalogs during module import' {
            $script:Psm1Content | Should -Not -Match 'UpdateCIEMAttackPathStorageSchema'
            $script:Psm1Content | Should -Not -Match 'Sync-CIEMAttackPathRuleCatalog'
        }

        It 'Explicit database initialization applies provider schemas and catalogs' {
            $script:NewDatabaseContent | Should -Match 'discovery_schema\.sql'
            $script:NewDatabaseContent | Should -Match "Label\s*=\s*'AzureDiscovery'"
            $script:NewDatabaseContent | Should -Match 'UpdateCIEMAttackPathStorageSchema'
            $script:NewDatabaseContent | Should -Match 'Sync-CIEMAttackPathRuleCatalog'
        }

        It 'PSU initialize hook runs the automatic CIEM bootstrap' {
            Join-Path $script:UniversalRoot 'initialize.ps1' | Should -Exist
            $script:InitializeContent | Should -Match 'Import-Module\s+Devolutions\.CIEM'
            $script:InitializeContent | Should -Match 'Initialize-CIEMPSUInstance\s+-Integrated'
            $script:InitializeContent | Should -Not -Match 'New-CIEMDatabase'
            $script:InitializeContent | Should -Not -Match 'Import-CIEMScript'
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
            $script:PageRegistryContent = Get-Content (Join-Path $PSScriptRoot '..' '..' 'modules' 'Devolutions.CIEM.PSU' 'Data' 'pages.json') -Raw
        }

        It 'Does NOT reference New-CIEMGraphPage (dead function)' {
            $script:AppContent | Should -Not -Match 'New-CIEMGraphPage'
        }

        It 'Does NOT reference New-CIEMIdentityRiskPage' {
            $script:AppContent | Should -Not -Match 'New-CIEMIdentityRiskPage'
        }

        It 'References New-CIEMIdentitiesPage through the page registry' {
            $script:AppContent | Should -Match 'GetCIEMPSUPageRegistry'
            $script:PageRegistryContent | Should -Match '"factory"\s*:\s*"New-CIEMIdentitiesPage"'
        }

        It 'References New-CIEMAttackPathsPage through the page registry' {
            $script:AppContent | Should -Match 'GetCIEMPSUPageRegistry'
            $script:PageRegistryContent | Should -Match '"factory"\s*:\s*"New-CIEMAttackPathsPage"'
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
            $script:NewDatabaseContent | Should -Match 'Schema file not found'
        }

        It 'Throws when the module database path is unavailable before schema application' {
            $script:NewDatabaseContent | Should -Match 'Database path not resolved'
        }
    }

    Context 'Explicit database initialization' {
        It 'Does not lazy-create the database from Get-CIEMDatabasePath' {
            $script:GetDatabasePathContent | Should -Not -Match 'New-CIEMDatabase'
            $script:GetDatabasePathContent | Should -Match "Join-Path\s+.*DataRoot\s+'ciem\.db'"
        }

        It 'Does not lazy-create the database from Invoke-CIEMQuery' {
            $script:InvokeQueryContent | Should -Not -Match 'New-CIEMDatabase'
            $script:InvokeQueryContent | Should -Match 'CIEM database is not initialized'
        }

        It 'Configuration page keeps schema refresh as maintenance instead of a first-run gate' {
            $script:ConfigPageContent | Should -Match 'initializeCiemDatabaseBtn'
            $script:ConfigPageContent | Should -Match 'Devolutions\.CIEM\\New-CIEMDatabase'
            $script:ConfigPageContent | Should -Match 'Invoke-UDRedirect\s+''/ciem/config'''
            $script:ConfigPageContent | Should -Match 'Reapply Schema and Catalogs'
            $script:ConfigPageContent | Should -Not -Match 'Initialize the CIEM database before configuring providers or running scans'
            $script:ConfigPageContent | Should -Not -Match '\$databaseExists'
            $script:ConfigPageContent | Should -Not -Match 'if\s*\(\s*-not\s+\$databaseExists\s*\)'
        }
    }

    Context 'Production PSU package resources' {
        It 'Ships only CIEM-owned PSU configuration resources' {
            Join-Path $script:UniversalRoot 'dashboards.ps1' | Should -Exist
            Join-Path $script:UniversalRoot 'initialize.ps1' | Should -Exist
            Join-Path $script:UniversalRoot 'scripts.ps1' | Should -Not -Exist
            Join-Path $script:UniversalRoot 'authentication.ps1' | Should -Not -Exist
            Join-Path $script:UniversalRoot 'roles.ps1' | Should -Not -Exist
            Join-Path $script:UniversalRoot 'settings.ps1' | Should -Not -Exist
        }

        It 'Ships the bundled PSUSQLite module used by CIEM database functions' {
            Join-Path $repoRoot 'modules/PSUSQLite/PSUSQLite.psd1' | Should -Exist
            $script:Psm1Content | Should -Match 'modules/PSUSQLite/PSUSQLite\.psd1'
        }

        It 'Declares no external Gallery module dependencies because CIEM runtime dependencies are bundled or PSU-provided' {
            $manifest = Import-PowerShellDataFile -Path $script:ManifestPath
            $manifest.RequiredModules | Should -BeNullOrEmpty
            $manifest.PrivateData.PSData.ExternalModuleDependencies | Should -BeNullOrEmpty
        }
    }

    Context 'Sub-module root registry' {
        It 'Defines sub-module roots in a data manifest' {
            $script:ModuleRootsPath | Should -Exist
            $registry = Import-PowerShellDataFile -Path $script:ModuleRootsPath

            @($registry.Modules.Variable) | Should -Be @(
                'GraphRoot'
                'AzureRoot'
                'AzureDiscoveryRoot'
                'AWSRoot'
                'ChecksRoot'
                'EffectivePermissionsRoot'
                'ReportsRoot'
                'PSURoot'
            )
        }

        It 'Only enables class loading for modules that contain class files' {
            $registry = Import-PowerShellDataFile -Path $script:ModuleRootsPath
            foreach ($module in $registry.Modules) {
                if (-not [bool]$module.LoadClasses) {
                    continue
                }

                $classesPath = Join-Path (Join-Path $repoRoot ([string]$module.Path)) 'Classes'
                $classFiles = @(Get-ChildItem -LiteralPath $classesPath -Filter '*.ps1' -File)
                $classFiles.Count | Should -BeGreaterThan 0 -Because "$($module.Name) sets LoadClasses=true"
            }
        }

        It 'Loads sub-module roots from the data manifest' {
            $script:Psm1Content | Should -Match 'Data/module_roots\.psd1'
            $script:Psm1Content | Should -Match 'Import-PowerShellDataFile'
            $script:Psm1Content | Should -Match 'Set-Variable\s+-Name\s+\(\[string\]\$rootEntry\.Variable\)\s+-Scope\s+Script'
            $script:Psm1Content | Should -Match '\$subModuleRoots\s*=\s*@\(\$script:CIEMModuleRoots'
        }

        It 'Does NOT contain removed sub-module roots' {
            $script:Psm1Content | Should -Not -Match 'AzurePermissionsRoot'
            $script:Psm1Content | Should -Not -Match 'IdentitiesRoot'
            $script:ModuleRootsPath | Should -Exist
            $registry = Import-PowerShellDataFile -Path $script:ModuleRootsPath
            @($registry.Modules.Variable) | Should -Not -Contain 'AzurePermissionsRoot'
            @($registry.Modules.Variable) | Should -Not -Contain 'IdentitiesRoot'
        }
    }

    Context 'Export registry' {
        It 'Does not parse PSU page files with regex to build module exports' {
            $script:Psm1Content | Should -Not -Match '\[regex\]::Matches'
            $script:Psm1Content | Should -Not -Match 'Get-Content\s+\$pageFile\.FullName\s+-Raw'
        }

        It 'Exports PSU page factories from the page registry' {
            $script:Psm1Content | Should -Match 'GetCIEMPSUPageRegistry'
            $script:Psm1Content | Should -Match '\$_\.factory'
            $script:Psm1Content | Should -Match 'Export-ModuleMember\s+-Function\s+\$exportFunctions'
        }
    }

    Context 'Required loader paths fail fast' {
        It 'Does not silence required source discovery failures' {
            $script:Psm1Content | Should -Not -Match 'Get-ChildItem[^\r\n]+-ErrorAction\s+SilentlyContinue'
        }

        It 'Does not register page component assets during module import' {
            $script:Psm1Content | Should -Not -Match 'RegisterCIEMEnvironmentTreeAsset'
        }
    }
}
