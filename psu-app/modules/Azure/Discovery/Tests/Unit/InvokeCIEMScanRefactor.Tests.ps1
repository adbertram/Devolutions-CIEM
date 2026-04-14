BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' '..' 'Devolutions.CIEM.psd1')

    # Read the InvokeCIEMScan source and its private helpers for structural assertions.
    # Entra/ARM resource dispatch lives in GetCIEMEntraNeeds/GetCIEMIAMNeeds after the refactor.
    $checksPrivate = Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.Checks' 'Private'
    $script:ScanSource = (Get-Content (Join-Path $checksPrivate 'InvokeCIEMScan.ps1') -Raw) +
        "`n" + (Get-Content (Join-Path $checksPrivate 'GetCIEMEntraNeeds.ps1') -Raw) +
        "`n" + (Get-Content (Join-Path $checksPrivate 'GetCIEMIAMNeeds.ps1') -Raw)
}

Describe 'InvokeCIEMScan Refactor' {

    Context 'Old data function references removed from source' {
        It 'Does not reference Get-CIEMAzureEntraData' {
            $script:ScanSource | Should -Not -Match 'Get-CIEMAzureEntraData'
        }

        It 'Does not reference Get-CIEMAzureIAMData' {
            $script:ScanSource | Should -Not -Match 'Get-CIEMAzureIAMData'
        }

        It 'Does not reference Save-CIEMCollectedData' {
            $script:ScanSource | Should -Not -Match 'Save-CIEMCollectedData'
        }

        It 'Does not reference Get-CIEMAzureDefenderData' {
            $script:ScanSource | Should -Not -Match 'Get-CIEMAzureDefenderData'
        }

        It 'Does not reference Get-CIEMAzureMonitorData' {
            $script:ScanSource | Should -Not -Match 'Get-CIEMAzureMonitorData'
        }

        It 'Does not reference Get-CIEMAzureNetworkData' {
            $script:ScanSource | Should -Not -Match 'Get-CIEMAzureNetworkData'
        }

        It 'Does not reference Get-CIEMAzurePolicyData' {
            $script:ScanSource | Should -Not -Match 'Get-CIEMAzurePolicyData'
        }

        It 'Does not reference Get-CIEMAzureVmData' {
            $script:ScanSource | Should -Not -Match 'Get-CIEMAzureVmData'
        }
    }

    Context 'New discovery data references present' {
        It 'References Get-CIEMAzureDiscoveryRun' {
            $script:ScanSource | Should -Match 'Get-CIEMAzureDiscoveryRun'
        }

        It 'References Get-CIEMAzureEntraResource' {
            $script:ScanSource | Should -Match 'Get-CIEMAzureEntraResource'
        }

        It 'References Get-CIEMAzureArmResource' {
            $script:ScanSource | Should -Match 'Get-CIEMAzureArmResource'
        }
    }
}
