BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
}

Describe 'Start-CIEMAzureDiscovery' {

    Context 'Stub behavior' {
        It 'Start-CIEMAzureDiscovery is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Start-CIEMAzureDiscovery -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
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
            # Default value should be 'All' — verify by checking the function's DefaultParameterValues or AST
            $funcDef = (Get-Command -Module Devolutions.CIEM -Name Start-CIEMAzureDiscovery).ScriptBlock.ToString()
            $funcDef | Should -Match '\$Scope\s*=\s*''All'''
        }

        It 'Throws "Not implemented" when called' {
            { Start-CIEMAzureDiscovery } | Should -Throw '*not implemented*'
        }

        It 'OutputType is CIEMAzureDiscoveryRun' {
            $cmd = Get-Command -Module Devolutions.CIEM -Name Start-CIEMAzureDiscovery
            $outputTypes = $cmd.OutputType.Name
            $outputTypes | Should -Contain 'CIEMAzureDiscoveryRun'
        }
    }

    Context 'Private collection stubs exist' {
        It 'InvokeCIEMResourceGraphQuery exists (private, no dash)' {
            InModuleScope Devolutions.CIEM {
                Get-Command InvokeCIEMResourceGraphQuery -ErrorAction SilentlyContinue
            } | Should -Not -BeNullOrEmpty
        }

        It 'GetCIEMBuiltInRoleDefinitions exists (private)' {
            InModuleScope Devolutions.CIEM {
                Get-Command GetCIEMBuiltInRoleDefinitions -ErrorAction SilentlyContinue
            } | Should -Not -BeNullOrEmpty
        }

        It 'InvokeCIEMEntraEntityCollection exists (private)' {
            InModuleScope Devolutions.CIEM {
                Get-Command InvokeCIEMEntraEntityCollection -ErrorAction SilentlyContinue
            } | Should -Not -BeNullOrEmpty
        }

        It 'InvokeCIEMEntraPermissionCollection exists (private)' {
            InModuleScope Devolutions.CIEM {
                Get-Command InvokeCIEMEntraPermissionCollection -ErrorAction SilentlyContinue
            } | Should -Not -BeNullOrEmpty
        }

        It 'InvokeCIEMEntraRelationshipCollection exists (private)' {
            InModuleScope Devolutions.CIEM {
                Get-Command InvokeCIEMEntraRelationshipCollection -ErrorAction SilentlyContinue
            } | Should -Not -BeNullOrEmpty
        }
    }
}
