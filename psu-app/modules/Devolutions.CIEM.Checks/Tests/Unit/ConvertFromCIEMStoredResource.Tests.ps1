BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
}

Describe 'ConvertFromCIEMStoredResource' {
    # The function rehydrates a stored resource row back to the original Azure API
    # envelope shape. Discovery stores the API's `properties` subobject as a JSON
    # blob plus indexed columns (Id, DisplayName, Name, Type, ParentId,
    # SubscriptionId, ResourceGroup). The output MUST match the original API
    # shape `{id, type, ..., properties: {...}}` because every check function
    # was written against that shape (e.g., `$role.properties.permissions`).

    Context 'when the stored resource has a Properties JSON blob' {
        It 'exposes the parsed JSON object under the .properties property' {
            $resource = [pscustomobject]@{
                Id              = '/subscriptions/sub-1/providers/Microsoft.Authorization/roleDefinitions/abc'
                DisplayName     = 'Custom Lock Admin'
                Name            = 'abc'
                Type            = 'CustomRole'
                ParentId        = '/subscriptions/sub-1'
                SubscriptionId  = 'sub-1'
                ResourceGroup   = $null
                Properties      = '{"roleName":"Custom Lock Admin","permissions":[{"actions":["Microsoft.Authorization/locks/*"]}],"assignableScopes":["/subscriptions/sub-1"]}'
            }

            $result = InModuleScope Devolutions.CIEM -Parameters @{ Resource = $resource } {
                param($Resource)
                ConvertFromCIEMStoredResource -Resource $Resource
            }

            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties.Name | Should -Contain 'properties' -Because 'check functions reference $obj.properties.X — the parsed JSON must be exposed there'
            $result.properties | Should -Not -BeNullOrEmpty
            $result.properties.roleName | Should -Be 'Custom Lock Admin'
            $result.properties.permissions[0].actions[0] | Should -Be 'Microsoft.Authorization/locks/*'
            $result.properties.assignableScopes[0] | Should -Be '/subscriptions/sub-1'
        }

        It 'preserves indexed columns at the top level (id, type, name, etc.)' {
            $resource = [pscustomobject]@{
                Id              = '/subscriptions/sub-1/abc'
                DisplayName     = 'My Resource'
                Name            = 'abc'
                Type            = 'CustomRole'
                ParentId        = '/subscriptions/sub-1'
                SubscriptionId  = 'sub-1'
                ResourceGroup   = 'rg-1'
                Properties      = '{"roleName":"X"}'
            }

            $result = InModuleScope Devolutions.CIEM -Parameters @{ Resource = $resource } {
                param($Resource)
                ConvertFromCIEMStoredResource -Resource $Resource
            }

            $result.id              | Should -Be '/subscriptions/sub-1/abc'
            $result.displayName     | Should -Be 'My Resource'
            $result.name            | Should -Be 'abc'
            $result.type            | Should -Be 'CustomRole'
            $result.parentId        | Should -Be '/subscriptions/sub-1'
            $result.subscriptionId  | Should -Be 'sub-1'
            $result.resourceGroup   | Should -Be 'rg-1'
        }
    }

    Context 'when the stored resource has no Properties JSON blob' {
        It 'still exposes an empty .properties object so consumers can safely dereference' {
            $resource = [pscustomobject]@{
                Id              = '/subscriptions/sub-1/abc'
                Type            = 'CustomRole'
                Properties      = $null
            }

            $result = InModuleScope Devolutions.CIEM -Parameters @{ Resource = $resource } {
                param($Resource)
                ConvertFromCIEMStoredResource -Resource $Resource
            }

            $result.PSObject.Properties.Name | Should -Contain 'properties' -Because 'consumers must always be able to dereference .properties without null-guards'
            ($null -ne $result.properties) | Should -BeTrue -Because 'an empty PSCustomObject is the safe default; consumers can probe via PSObject.Properties[name]'
            $result.properties.GetType().Name | Should -Be 'PSCustomObject'
        }
    }
}
