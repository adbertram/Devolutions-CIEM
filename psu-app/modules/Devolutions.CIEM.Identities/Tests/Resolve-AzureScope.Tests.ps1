BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..' 'Devolutions.CIEM.Identities.psd1') -Force
}

Describe 'Resolve-AzureScope' {

    Context 'Root scope' {
        It 'Root scope covers subscriptions' {
            InModuleScope Devolutions.CIEM.Identities {
                Resolve-AzureScope -AssignmentScope '/' -TargetScope '/subscriptions/abc' | Should -BeTrue
            }
        }

        It 'Root scope covers resource groups' {
            InModuleScope Devolutions.CIEM.Identities {
                Resolve-AzureScope -AssignmentScope '/' -TargetScope '/subscriptions/abc/resourceGroups/rg1' | Should -BeTrue
            }
        }

        It 'Root scope covers resources' {
            InModuleScope Devolutions.CIEM.Identities {
                Resolve-AzureScope -AssignmentScope '/' -TargetScope '/subscriptions/abc/resourceGroups/rg1/providers/Microsoft.Sql/servers/srv1' | Should -BeTrue
            }
        }
    }

    Context 'Subscription scope' {
        It 'Subscription covers its resource groups' {
            InModuleScope Devolutions.CIEM.Identities {
                Resolve-AzureScope -AssignmentScope '/subscriptions/abc' -TargetScope '/subscriptions/abc/resourceGroups/rg1' | Should -BeTrue
            }
        }

        It 'Subscription covers its resources' {
            InModuleScope Devolutions.CIEM.Identities {
                Resolve-AzureScope -AssignmentScope '/subscriptions/abc' -TargetScope '/subscriptions/abc/resourceGroups/rg1/providers/Microsoft.Sql/servers/srv1' | Should -BeTrue
            }
        }

        It 'Subscription does not cover other subscriptions' {
            InModuleScope Devolutions.CIEM.Identities {
                Resolve-AzureScope -AssignmentScope '/subscriptions/abc' -TargetScope '/subscriptions/def' | Should -BeFalse
            }
        }

        It 'Subscription does not match similar-prefix subscription' {
            InModuleScope Devolutions.CIEM.Identities {
                Resolve-AzureScope -AssignmentScope '/subscriptions/abc' -TargetScope '/subscriptions/abcdef' | Should -BeFalse
            }
        }
    }

    Context 'Resource group scope' {
        It 'Resource group covers its resources' {
            InModuleScope Devolutions.CIEM.Identities {
                Resolve-AzureScope -AssignmentScope '/subscriptions/abc/resourceGroups/rg1' -TargetScope '/subscriptions/abc/resourceGroups/rg1/providers/Microsoft.Sql/servers/srv1' | Should -BeTrue
            }
        }

        It 'Resource group does not cover parent subscription' {
            InModuleScope Devolutions.CIEM.Identities {
                Resolve-AzureScope -AssignmentScope '/subscriptions/abc/resourceGroups/rg1' -TargetScope '/subscriptions/abc' | Should -BeFalse
            }
        }

        It 'Resource group does not cover other resource groups' {
            InModuleScope Devolutions.CIEM.Identities {
                Resolve-AzureScope -AssignmentScope '/subscriptions/abc/resourceGroups/rg1' -TargetScope '/subscriptions/abc/resourceGroups/rg2' | Should -BeFalse
            }
        }
    }

    Context 'Exact match' {
        It 'Same scope matches' {
            InModuleScope Devolutions.CIEM.Identities {
                Resolve-AzureScope -AssignmentScope '/subscriptions/abc' -TargetScope '/subscriptions/abc' | Should -BeTrue
            }
        }

        It 'Same scope matches with trailing slash normalization' {
            InModuleScope Devolutions.CIEM.Identities {
                Resolve-AzureScope -AssignmentScope '/subscriptions/abc/' -TargetScope '/subscriptions/abc' | Should -BeTrue
            }
        }
    }

    Context 'Case insensitivity' {
        It 'Is case-insensitive' {
            InModuleScope Devolutions.CIEM.Identities {
                Resolve-AzureScope -AssignmentScope '/Subscriptions/ABC' -TargetScope '/subscriptions/abc/resourceGroups/rg1' | Should -BeTrue
            }
        }
    }
}
