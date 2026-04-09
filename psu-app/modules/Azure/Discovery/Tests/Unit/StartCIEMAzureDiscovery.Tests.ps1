BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    # Create isolated test DB with base + azure + discovery schemas
    New-CIEMDatabase -Path "$TestDrive/ciem.db"

    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }

    foreach ($schemaPath in @(
        (Join-Path $PSScriptRoot '..' '..' '..' 'Infrastructure' 'Data' 'azure_schema.sql'),
        (Join-Path $PSScriptRoot '..' '..' 'Data' 'discovery_schema.sql')
    )) {
        foreach ($statement in ((Get-Content $schemaPath -Raw) -split ';\s*\n' | Where-Object { $_.Trim() })) {
            Invoke-CIEMQuery -Query $statement.Trim() -AsNonQuery | Out-Null
        }
    }
}

Describe 'Start-CIEMAzureDiscovery' {

    Context 'Command structure' {
        It 'Start-CIEMAzureDiscovery is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Start-CIEMAzureDiscovery -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Accepts -Scope parameter with ValidateSet All, ARM, Entra' {
            $cmd = Get-Command -Module Devolutions.CIEM -Name Start-CIEMAzureDiscovery
            $scopeParam = $cmd.Parameters['Scope']
            $scopeParam | Should -Not -BeNullOrEmpty
            $validateSet = $scopeParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSet | Should -Not -BeNullOrEmpty
            $validateSet.ValidValues | Should -Contain 'All'
            $validateSet.ValidValues | Should -Contain 'ARM'
            $validateSet.ValidValues | Should -Contain 'Entra'
        }

        It 'Scope defaults to All' {
            $cmd = Get-Command -Module Devolutions.CIEM -Name Start-CIEMAzureDiscovery
            $scopeParam = $cmd.Parameters['Scope']
            $scopeParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } |
                ForEach-Object { $_.Mandatory | Should -BeFalse }
            $funcDef = (Get-Command -Module Devolutions.CIEM -Name Start-CIEMAzureDiscovery).ScriptBlock.ToString()
            $funcDef | Should -Match '\$Scope\s*=\s*''All'''
        }

        It 'OutputType is CIEMAzureDiscoveryRun' {
            $cmd = Get-Command -Module Devolutions.CIEM -Name Start-CIEMAzureDiscovery
            $outputTypes = $cmd.OutputType.Name
            $outputTypes | Should -Contain 'CIEMAzureDiscoveryRun'
        }
    }

    Context 'Concurrency guard' {
        BeforeEach {
            InModuleScope Devolutions.CIEM {
                # Fake an established auth context so the function reaches the concurrency guard
                $script:AzureAuthContext = [PSCustomObject]@{ IsConnected = $true }
                $script:existingRun = New-CIEMAzureDiscoveryRun -Scope 'All' -Status 'Running' -StartedAt (Get-Date).ToString('o')
            }
        }

        AfterEach {
            InModuleScope Devolutions.CIEM {
                Remove-CIEMAzureDiscoveryRun -Id $script:existingRun.Id -Confirm:$false
            }
        }

        It 'Throws if a Running discovery run already exists' {
            InModuleScope Devolutions.CIEM {
                { Start-CIEMAzureDiscovery } | Should -Throw '*already in progress*'
            }
        }
    }

    Context 'Phase array refactor' {
        BeforeAll {
            $script:StartDiscoverySource = Get-Content (Join-Path $PSScriptRoot '..' '..' 'Public' 'Start-CIEMAzureDiscovery.ps1') -Raw
        }

        It 'Invoke-CIEMDiscoveryPhase generic runner exists (private, no dash)' {
            InModuleScope Devolutions.CIEM {
                Get-Command -Name 'InvokeCIEMDiscoveryPhase' -ErrorAction Stop | Should -Not -BeNullOrEmpty
            }
        }

        It 'ResolveCIEMResourceTypeMetadata lookup helper exists' {
            InModuleScope Devolutions.CIEM {
                Get-Command -Name 'ResolveCIEMResourceTypeMetadata' -ErrorAction Stop | Should -Not -BeNullOrEmpty
            }
        }

        It 'ResolveCIEMResourceTypeMetadata returns ResourceGraph + ResourceContainers for microsoft.resources/* types' {
            InModuleScope Devolutions.CIEM {
                $result = ResolveCIEMResourceTypeMetadata -Type 'microsoft.resources/subscriptions'
                $result.ApiSource | Should -Be 'ResourceGraph'
                $result.GraphTable | Should -Be 'ResourceContainers'
            }
        }

        It 'ResolveCIEMResourceTypeMetadata returns ResourceGraph + AuthorizationResources for microsoft.authorization/* types' {
            InModuleScope Devolutions.CIEM {
                $result = ResolveCIEMResourceTypeMetadata -Type 'microsoft.authorization/roleassignments'
                $result.ApiSource | Should -Be 'ResourceGraph'
                $result.GraphTable | Should -Be 'AuthorizationResources'
            }
        }

        It 'ResolveCIEMResourceTypeMetadata returns ResourceGraph + Resources for generic microsoft.* types' {
            InModuleScope Devolutions.CIEM {
                $result = ResolveCIEMResourceTypeMetadata -Type 'microsoft.compute/virtualmachines'
                $result.ApiSource | Should -Be 'ResourceGraph'
                $result.GraphTable | Should -Be 'Resources'
            }
        }

        It 'ResolveCIEMResourceTypeMetadata returns Graph + null GraphTable for non-microsoft types' {
            InModuleScope Devolutions.CIEM {
                $result = ResolveCIEMResourceTypeMetadata -Type 'user'
                $result.ApiSource | Should -Be 'Graph'
                $result.GraphTable | Should -BeNullOrEmpty
            }
        }

        It 'Start-CIEMAzureDiscovery source file no longer contains the monolithic if/elif Save-ResourceTypes chain' {
            # The old helper had a 3-arm if/elseif chain matching resource type prefixes.
            # After refactor, the chain should be replaced with a single hashtable lookup.
            # Count the chained elseif+match clauses that reference microsoft.* prefixes.
            $chainCount = ([regex]::Matches($script:StartDiscoverySource, "-match\s+'\^microsoft\\\.")).Count
            $chainCount | Should -BeLessThan 3
        }

        It 'Start-CIEMAzureDiscovery defines a phase array driving Invoke-CIEMDiscoveryPhase' {
            # After refactor the function body should invoke Invoke-CIEMDiscoveryPhase
            # at least once (ideally multiple times in a foreach loop).
            $script:StartDiscoverySource | Should -Match 'InvokeCIEMDiscoveryPhase'
        }
    }

    Context 'Private collection helpers exist' {
        It 'InvokeCIEMResourceGraphQuery exists (private, no dash)' {
            InModuleScope Devolutions.CIEM {
                Get-Command InvokeCIEMResourceGraphQuery -ErrorAction Stop
            } | Should -Not -BeNullOrEmpty
        }

        It 'GetCIEMBuiltInRoleDefinitions exists (private)' {
            InModuleScope Devolutions.CIEM {
                Get-Command GetCIEMBuiltInRoleDefinitions -ErrorAction Stop
            } | Should -Not -BeNullOrEmpty
        }

        It 'InvokeCIEMEntraEntityCollection exists (private)' {
            InModuleScope Devolutions.CIEM {
                Get-Command InvokeCIEMEntraEntityCollection -ErrorAction Stop
            } | Should -Not -BeNullOrEmpty
        }

        It 'InvokeCIEMEntraPermissionCollection exists (private)' {
            InModuleScope Devolutions.CIEM {
                Get-Command InvokeCIEMEntraPermissionCollection -ErrorAction Stop
            } | Should -Not -BeNullOrEmpty
        }

        It 'InvokeCIEMEntraRelationshipCollection exists (private)' {
            InModuleScope Devolutions.CIEM {
                Get-Command InvokeCIEMEntraRelationshipCollection -ErrorAction Stop
            } | Should -Not -BeNullOrEmpty
        }

        It 'InvokeCIEMTransaction exists (private)' {
            InModuleScope Devolutions.CIEM {
                Get-Command InvokeCIEMTransaction -ErrorAction Stop
            } | Should -Not -BeNullOrEmpty
        }

        It 'InvokeCIEMAzureEffectiveRoleAssignmentBuild exists (private)' {
            InModuleScope Devolutions.CIEM {
                Get-Command InvokeCIEMAzureEffectiveRoleAssignmentBuild -ErrorAction Stop
            } | Should -Not -BeNullOrEmpty
        }
    }
}
