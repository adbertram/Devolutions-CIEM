BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'Devolutions.CIEM.Graph.psd1') -Force
}

Describe 'Test-AzureActionMatch' {

    Context 'Exact matches' {
        It 'Matches identical action strings' {
            InModuleScope Devolutions.CIEM.Graph {
                Test-AzureActionMatch -Pattern 'Microsoft.Sql/servers/read' -Action 'Microsoft.Sql/servers/read' | Should -BeTrue
            }
        }

        It 'Is case-insensitive' {
            InModuleScope Devolutions.CIEM.Graph {
                Test-AzureActionMatch -Pattern 'microsoft.sql/servers/read' -Action 'Microsoft.Sql/servers/read' | Should -BeTrue
            }
        }

        It 'Does not match different actions' {
            InModuleScope Devolutions.CIEM.Graph {
                Test-AzureActionMatch -Pattern 'Microsoft.Sql/servers/read' -Action 'Microsoft.Sql/servers/write' | Should -BeFalse
            }
        }
    }

    Context 'Wildcard * matches' {
        It 'Star matches everything' {
            InModuleScope Devolutions.CIEM.Graph {
                Test-AzureActionMatch -Pattern '*' -Action 'Microsoft.Sql/servers/read' | Should -BeTrue
            }
        }

        It 'Trailing star matches all under namespace' {
            InModuleScope Devolutions.CIEM.Graph {
                Test-AzureActionMatch -Pattern 'Microsoft.Sql/servers/*' -Action 'Microsoft.Sql/servers/delete' | Should -BeTrue
            }
        }

        It 'Trailing star matches nested resources' {
            InModuleScope Devolutions.CIEM.Graph {
                Test-AzureActionMatch -Pattern 'Microsoft.Sql/servers/*' -Action 'Microsoft.Sql/servers/databases/read' | Should -BeTrue
            }
        }

        It 'Prefix star matches all read operations' {
            InModuleScope Devolutions.CIEM.Graph {
                Test-AzureActionMatch -Pattern '*/read' -Action 'Microsoft.Sql/servers/read' | Should -BeTrue
            }
        }

        It 'Does not match across namespace boundaries incorrectly' {
            InModuleScope Devolutions.CIEM.Graph {
                Test-AzureActionMatch -Pattern 'Microsoft.Sql/*' -Action 'Microsoft.Storage/storageAccounts/read' | Should -BeFalse
            }
        }

        It 'Matches middle wildcard' {
            InModuleScope Devolutions.CIEM.Graph {
                Test-AzureActionMatch -Pattern 'Microsoft.*/read' -Action 'Microsoft.Sql/servers/read' | Should -BeTrue
            }
        }
    }

    Context 'Question mark ? matches' {
        It 'Question mark matches single character' {
            InModuleScope Devolutions.CIEM.Graph {
                Test-AzureActionMatch -Pattern 'Microsoft.Sql/server?/read' -Action 'Microsoft.Sql/servers/read' | Should -BeTrue
            }
        }

        It 'Question mark does not match zero characters' {
            InModuleScope Devolutions.CIEM.Graph {
                Test-AzureActionMatch -Pattern 'Microsoft.Sql/server?/read' -Action 'Microsoft.Sql/server/read' | Should -BeFalse
            }
        }
    }

    Context 'Non-matches' {
        It 'Does not partially match' {
            InModuleScope Devolutions.CIEM.Graph {
                Test-AzureActionMatch -Pattern 'Microsoft.Sql/servers/read' -Action 'Microsoft.Sql/servers/readMore' | Should -BeFalse
            }
        }

        It 'Does not match shorter string' {
            InModuleScope Devolutions.CIEM.Graph {
                Test-AzureActionMatch -Pattern 'Microsoft.Sql/servers/databases/read' -Action 'Microsoft.Sql/servers/read' | Should -BeFalse
            }
        }
    }
}
