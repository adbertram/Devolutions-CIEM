BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}

Describe 'Graph entity registry' {

    Context 'Registry contract' {
        It 'loads strict graph entity definitions for nodes and edges' {
            InModuleScope Devolutions.CIEM {
                TestCIEMGraphEntityRegistry | Should -BeTrue
                $registry = GetCIEMGraphEntityConfig
                $registry.Keys | Should -Contain 'Node'
                $registry.Keys | Should -Contain 'Edge'
            }
        }

        It 'declares table, class, columns, filters, writable fields, required values, and property map for every entity' {
            InModuleScope Devolutions.CIEM {
                $allowedFields = @(
                    'Table',
                    'Class',
                    'KeyColumns',
                    'SelectColumns',
                    'InsertColumns',
                    'FilterColumns',
                    'WritableColumns',
                    'RequiredSaveValues',
                    'PropertyMap'
                )

                $registry = GetCIEMGraphEntityConfig
                foreach ($entity in $registry.Keys) {
                    $entry = $registry[$entity]
                    @($entry.Keys) | Sort-Object | Should -Be (@($allowedFields) | Sort-Object)
                    $entry.Table | Should -Not -BeNullOrEmpty
                    $entry.Class | Should -BeIn @('CIEMGraphNode', 'CIEMGraphEdge')
                    ($entry.Class -as [type]) | Should -Not -BeNullOrEmpty
                    @($entry.KeyColumns).Count | Should -BeGreaterThan 0
                    @($entry.SelectColumns).Count | Should -BeGreaterThan 0
                    @($entry.InsertColumns).Count | Should -BeGreaterThan 0
                    $entry.FilterColumns.Count | Should -BeGreaterThan 0
                    @($entry.WritableColumns).Count | Should -BeGreaterThan 0
                    @($entry.RequiredSaveValues).Count | Should -BeGreaterThan 0
                    $entry.PropertyMap.Count | Should -BeGreaterThan 0
                }
            }
        }

        It 'rejects unknown filters and unknown hashtable save fields before database execution' {
            InModuleScope Devolutions.CIEM {
                { GetCIEMGraphEntity -Entity Node -Filters @{ Missing = 'value' } } |
                    Should -Throw "*unknown filter 'Missing'*"

                { SaveCIEMGraphEntity -Entity Node -Items @(@{ Id = 'node-1'; Kind = 'AzureVM'; Extra = 'bad' }) } |
                    Should -Throw "*unknown writable value 'Extra'*"
            }
        }
    }

    Context 'Public shim shape' {
        It 'graph CRUD public cmdlets delegate SQL construction to graph entity processors' {
            $publicFiles = @(
                'Get-CIEMGraphNode.ps1',
                'Get-CIEMGraphEdge.ps1',
                'Save-CIEMGraphNode.ps1',
                'Save-CIEMGraphEdge.ps1',
                'Remove-CIEMGraphNode.ps1',
                'Remove-CIEMGraphEdge.ps1'
            )

            foreach ($fileName in $publicFiles) {
                $path = Join-Path $PSScriptRoot '..' '..' 'Public' $fileName
                $content = Get-Content -Path $path -Raw
                $content | Should -Not -Match '(?i)\bSELECT\b.+\bFROM\s+graph_' -Because "$fileName should not build graph SELECT SQL"
                $content | Should -Not -Match '(?i)\bINSERT\s+OR\s+REPLACE\s+INTO\s+graph_' -Because "$fileName should not build graph INSERT SQL"
                $content | Should -Not -Match '(?i)\bDELETE\s+FROM\s+graph_' -Because "$fileName should not build graph DELETE SQL"
            }
        }
    }
}
