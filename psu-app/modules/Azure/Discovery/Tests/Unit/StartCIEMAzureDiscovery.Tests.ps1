BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    # Create isolated test DB with base + azure + discovery schemas
    New-CIEMDatabase -Path "$TestDrive/ciem.db"

    $azureSchema = Join-Path $PSScriptRoot '..' '..' '..' 'Infrastructure' 'Data' 'azure_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $azureSchema -Raw)

    $discoverySchema = Join-Path $PSScriptRoot '..' '..' 'Data' 'discovery_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $discoverySchema -Raw)

    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
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
