BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    New-CIEMDatabase -Path "$TestDrive/ciem.db"

    $azureSchema = Join-Path $PSScriptRoot '..' '..' '..' 'Azure' 'Infrastructure' 'Data' 'azure_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $azureSchema -Raw)

    $discoverySchema = Join-Path $PSScriptRoot '..' '..' '..' 'Azure' 'Discovery' 'Data' 'discovery_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $discoverySchema -Raw)

    $graphSchema = Join-Path $PSScriptRoot '..' '..' '..' 'Devolutions.CIEM.Graph' 'Data' 'graph_schema.sql'
    Invoke-CIEMQuery -Query (Get-Content $graphSchema -Raw)

    InModuleScope Devolutions.CIEM {
        $script:DatabasePath = "$TestDrive/ciem.db"
    }

    $script:NewTestCIEMAzurePermissionJson = {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [AllowEmptyCollection()]
            [string[]]$Actions,

            [Parameter(Mandatory)]
            [AllowEmptyCollection()]
            [string[]]$DataActions
        )

        @(
            @{
                actions = @($Actions)
                notActions = @()
                dataActions = @($DataActions)
                notDataActions = @()
            }
        ) | ConvertTo-Json -Depth 5 -Compress
    }
}

Describe 'Get-CIEMEffectivePermission' {

    Context 'when validating the public command contract' {

        It 'Is available as a public command' {
            Get-Command -Module Devolutions.CIEM -Name Get-CIEMEffectivePermission -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }

        It 'Reports unavailable provider data instead of synthesizing AWS results' {
            { Get-CIEMEffectivePermission -Provider AWS } | Should -Throw '*AWS effective permission data is not available*'
        }

        It 'Does not call provider APIs from the effective-permissions projection layer' {
            $moduleRoot = Join-Path $PSScriptRoot '..' '..'
            $source = @(
                Get-ChildItem (Join-Path $moduleRoot 'Public') -File -Filter '*.ps1'
                Get-ChildItem (Join-Path $moduleRoot 'Private') -File -Filter '*.ps1'
                Get-ChildItem (Join-Path $moduleRoot 'Classes') -File -Filter '*.ps1'
            ) |
                ForEach-Object { Get-Content $_.FullName -Raw }

            $source | Should -Not -Match 'Invoke-AzureApi'
            $source | Should -Not -Match 'InvokeCIEMResourceGraphQuery'
            $source | Should -Not -Match 'Invoke-CIEMResourceGraphQuery'
            $source | Should -Not -Match 'Invoke-RestMethod'
            $source | Should -Not -Match 'Invoke-WebRequest'
            $source | Should -Not -Match 'Connect-CIEM'
        }
    }

    Context 'when direct and inherited Azure RBAC graph edges exist' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            Save-CIEMGraphNode -Id 'user-direct' -Kind 'EntraUser' -DisplayName 'Direct User' -Provider 'azure'
            Save-CIEMGraphNode -Id 'user-inherited' -Kind 'EntraUser' -DisplayName 'Inherited User' -Provider 'azure'
            Save-CIEMGraphNode -Id 'group-admins' -Kind 'EntraGroup' -DisplayName 'Cloud Admins' -Provider 'azure'
            Save-CIEMGraphNode -Id '/subscriptions/sub-1' -Kind 'AzureSubscription' -DisplayName 'Sub 1' -Provider 'azure' -SubscriptionId 'sub-1'

            $readerPermissions = & $script:NewTestCIEMAzurePermissionJson `
                -Actions @('Microsoft.Resources/subscriptions/resourceGroups/read') `
                -DataActions @()

            $ownerPermissions = & $script:NewTestCIEMAzurePermissionJson `
                -Actions @('*') `
                -DataActions @()

            Save-CIEMGraphEdge -SourceId 'user-direct' -TargetId '/subscriptions/sub-1' -Kind 'HasRole' -Computed 1 `
                -Properties (@{
                    role_name = 'Reader'
                    role_definition_id = 'role-reader'
                    permissions_json = $readerPermissions
                    privileged = $false
                    principal_type = 'User'
                } | ConvertTo-Json -Compress)

            Save-CIEMGraphEdge -SourceId 'user-inherited' -TargetId '/subscriptions/sub-1' -Kind 'InheritedRole' -Computed 1 `
                -Properties (@{
                    role_name = 'Owner'
                    role_definition_id = 'role-owner'
                    permissions_json = $ownerPermissions
                    privileged = $true
                    principal_type = 'User'
                    inherited_from = 'group-admins'
                    inherited_from_name = 'Cloud Admins'
                } | ConvertTo-Json -Compress)

            $script:results = @(Get-CIEMEffectivePermission -Provider Azure)
        }

        It 'Returns typed effective permission objects' {
            $script:results[0].GetType().Name | Should -Be 'CIEMEffectivePermission'
        }

        It 'Returns typed nested principal objects' {
            $script:results[0].Principal.GetType().Name | Should -Be 'CIEMEffectivePrincipal'
        }

        It 'Projects direct role assignment as a direct path' {
            $direct = $script:results | Where-Object { $_.Principal.Id -eq 'user-direct' }
            [string]$direct.Path[0].Type | Should -Be 'Direct'
        }

        It 'Projects inherited role assignment with inherited group evidence' {
            $inherited = $script:results | Where-Object { $_.Principal.Id -eq 'user-inherited' }
            [string]$inherited.Path[0].Type | Should -Be 'GroupInherited'
            $inherited.Path[0].SourceName | Should -Be 'Cloud Admins'
        }

        It 'Classifies wildcard role actions as Manage access' {
            $inherited = $script:results | Where-Object { $_.Principal.Id -eq 'user-inherited' }
            [string]$inherited.Actions[0].AccessLevel | Should -Be 'Manage'
        }
    }

    Context 'when Azure RBAC actions need friendly descriptions' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            Save-CIEMGraphNode -Id 'user-friendly' -Kind 'EntraUser' -DisplayName 'Friendly User' -Provider 'azure'
            Save-CIEMGraphNode -Id 'tenant-friendly' -Kind 'AzureTenant' -DisplayName 'Tenant' -Provider 'azure'
            Save-CIEMGraphNode -Id '/subscriptions/sub-friendly/resourceGroups/rg/providers/Microsoft.KeyVault/vaults/vault-friendly' `
                -Kind 'AzureKeyVault' `
                -DisplayName 'Friendly Vault' `
                -Provider 'azure' `
                -Properties '{"arm_type":"microsoft.keyvault/vaults"}'

            $tenantReaderPermissions = & $script:NewTestCIEMAzurePermissionJson `
                -Actions @('*/read') `
                -DataActions @()

            $keyVaultSecretPermissions = & $script:NewTestCIEMAzurePermissionJson `
                -Actions @() `
                -DataActions @(
                    'Microsoft.KeyVault/vaults/secrets/getSecret/action',
                    'Microsoft.KeyVault/vaults/secrets/readMetadata/action'
                )

            Save-CIEMGraphEdge -SourceId 'user-friendly' -TargetId 'tenant-friendly' -Kind 'HasRole' -Computed 1 `
                -Properties (@{
                    role_name = 'Tenant Reader'
                    role_definition_id = 'role-tenant-reader'
                    permissions_json = $tenantReaderPermissions
                    privileged = $false
                    principal_type = 'User'
                } | ConvertTo-Json -Compress)

            Save-CIEMGraphEdge -SourceId 'user-friendly' -TargetId '/subscriptions/sub-friendly/resourceGroups/rg/providers/Microsoft.KeyVault/vaults/vault-friendly' -Kind 'HasRole' -Computed 1 `
                -Properties (@{
                    role_name = 'Key Vault Secrets User'
                    role_definition_id = 'role-keyvault-secrets'
                    permissions_json = $keyVaultSecretPermissions
                    privileged = $true
                    principal_type = 'User'
                } | ConvertTo-Json -Compress)

            $script:friendlyResults = @(Get-CIEMEffectivePermission -Provider Azure)
        }

        It 'Describes wildcard tenant read access in plain language' {
            $tenantPermission = $script:friendlyResults | Where-Object { $_.Target.Type -eq 'AzureTenant' }
            $tenantPermission.Actions[0].Description | Should -Be 'Can read all resources in the Azure tenant'
        }

        It 'Describes Key Vault secret data actions in plain language' {
            $keyVaultPermission = $script:friendlyResults | Where-Object { $_.Target.Type -eq 'AzureKeyVault' }
            $keyVaultPermission.Actions.Description | Should -Contain 'Can read secret values in this Azure Key Vault'
            $keyVaultPermission.Actions.Description | Should -Contain 'Can read secret metadata in this Azure Key Vault'
        }

        It 'Describes wildcard Azure authorization actions in plain language' {
            InModuleScope Devolutions.CIEM {
                ResolveCIEMEffectivePermissionActionDescription `
                    -Provider Azure `
                    -NativeAction 'Microsoft.Authorization/classicAdministrators/roleAssignments/write' `
                    -TargetType 'AzureSubscription' |
                    Should -Be 'Can modify Azure role assignments in this Azure subscription'
            }
        }
    }

    Context 'when directory role and app consent graph edges exist' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            Save-CIEMGraphNode -Id 'sp-client' -Kind 'EntraServicePrincipal' -DisplayName 'Client App' -Provider 'azure'
            Save-CIEMGraphNode -Id 'sp-resource' -Kind 'EntraServicePrincipal' -DisplayName 'Resource API' -Provider 'azure'
            Save-CIEMGraphNode -Id 'user-admin' -Kind 'EntraUser' -DisplayName 'Directory Admin' -Provider 'azure'
            Save-CIEMGraphNode -Id 'dir-role-1' -Kind 'EntraDirectoryRole' -DisplayName 'Global Administrator' -Provider 'azure'

            Save-CIEMGraphEdge -SourceId 'user-admin' -TargetId 'dir-role-1' -Kind 'HasRoleMember' -Computed 0

            Save-CIEMGraphEdge -SourceId 'sp-client' -TargetId 'sp-resource' -Kind 'HasAppRoleAssignment' -Computed 1 `
                -Properties (@{
                    assignment_id = 'assignment-1'
                    app_role_id = 'app-role-1'
                    principal_type = 'ServicePrincipal'
                } | ConvertTo-Json -Compress)

            Save-CIEMGraphEdge -SourceId 'sp-client' -TargetId 'sp-resource' -Kind 'HasOAuthGrant' -Computed 1 `
                -Properties (@{
                    grant_id = 'grant-1'
                    scope = 'User.Read Directory.Read.All Activity.Read.All User.ReadBasic.All Sites.FullControl.All Directory.AccessAsUser.All TeamsAppInstallation.ReadWriteForTeam openid'
                    consent_type = 'AllPrincipals'
                } | ConvertTo-Json -Compress)

            $script:results = @(Get-CIEMEffectivePermission -Provider Azure)
        }

        It 'Projects directory role membership as a directory role entitlement' {
            $directoryRole = $script:results | Where-Object { [string]$_.Entitlement.Type -eq 'DirectoryRole' }
            $directoryRole.Principal.DisplayName | Should -Be 'Directory Admin'
        }

        It 'Describes directory roles as actions the principal can perform' {
            $directoryRole = $script:results | Where-Object { [string]$_.Entitlement.Type -eq 'DirectoryRole' }
            $directoryRole.Actions[0].Description | Should -Be 'Can administer all Microsoft Entra resources'
        }

        It 'Projects OAuth grants as typed OAuth grant entitlements' {
            $oauthGrant = $script:results | Where-Object { [string]$_.Entitlement.Type -eq 'OAuthGrant' }
            $oauthGrant.Actions[0].NativeAction | Should -Be 'User.Read'
        }

        It 'Describes OAuth grants as Microsoft Graph actions' {
            $oauthGrant = $script:results | Where-Object { [string]$_.Entitlement.Type -eq 'OAuthGrant' }
            $oauthGrant.Actions.Description | Should -Contain 'Can read Microsoft Graph user data'
            $oauthGrant.Actions.Description | Should -Contain 'Can read Microsoft Graph directory data'
            $oauthGrant.Actions.Description | Should -Contain 'Can read Microsoft Graph activity data'
            $oauthGrant.Actions.Description | Should -Contain 'Can read basic Microsoft Graph user data'
            $oauthGrant.Actions.Description | Should -Contain 'Can fully control Microsoft Graph site data'
            $oauthGrant.Actions.Description | Should -Contain 'Can access Microsoft Graph directory data as the signed-in user'
            $oauthGrant.Actions.Description | Should -Contain 'Can read and modify Microsoft Teams app installations for teams'
            $oauthGrant.Actions.Description | Should -Contain 'Can sign the user in with OpenID Connect'
        }

        It 'Describes app role assignments as application access actions' {
            $appRoleAssignment = $script:results | Where-Object { [string]$_.Entitlement.Type -eq 'AppRoleAssignment' }
            $appRoleAssignment.Actions[0].Description | Should -Be 'Can access this enterprise application'
        }

        It 'Does not describe effective actions as held roles or entitlements' {
            $actionDescriptions = @($script:results | ForEach-Object { $_.Actions.Description })
            ($actionDescriptions -join "`n") | Should -Not -Match '\b(hold|entitlement|directory role)\b'
        }
    }

    Context 'when description catalog mappings are missing' {

        It 'Throws for <Name>' -TestCases @(
            @{
                Name = 'unmapped Microsoft Graph permission subjects'
                NativeAction = 'UnknownSubject.Read.All'
                TargetType = 'EntraServicePrincipal'
                ExpectedMessage = "*Microsoft Graph permission subject 'UnknownSubject'*"
            },
            @{
                Name = 'unmapped Microsoft Graph permission verbs'
                NativeAction = 'User.UnknownVerb.All'
                TargetType = 'EntraServicePrincipal'
                ExpectedMessage = "*Microsoft Graph permission verb 'UnknownVerb'*"
            },
            @{
                Name = 'unmapped Microsoft Entra directory roles'
                NativeAction = 'Unknown Directory Role'
                TargetType = 'EntraDirectoryRole'
                ExpectedMessage = "*Microsoft Entra directory role 'Unknown Directory Role'*"
            },
            @{
                Name = 'unmapped effective permission target scopes'
                NativeAction = '*/read'
                TargetType = 'AzureUnknownResource'
                ExpectedMessage = "*target scope 'AzureUnknownResource'*"
            },
            @{
                Name = 'unmapped Azure action resource paths'
                NativeAction = 'Microsoft.Unknown/widgets/read'
                TargetType = 'AzureSubscription'
                ExpectedMessage = "*Azure resource path 'Microsoft.Unknown/widgets'*"
            }
        ) {
            param(
                [string]$Name,
                [string]$NativeAction,
                [string]$TargetType,
                [string]$ExpectedMessage
            )

            InModuleScope Devolutions.CIEM -Parameters @{
                NativeAction = $NativeAction
                TargetType = $TargetType
                ExpectedMessage = $ExpectedMessage
            } {
                { ResolveCIEMEffectivePermissionActionDescription -Provider Azure -NativeAction $NativeAction -TargetType $TargetType } |
                    Should -Throw $ExpectedMessage
            }
        }
    }

    Context 'when filtering effective permissions' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            Save-CIEMGraphNode -Id 'user-reader' -Kind 'EntraUser' -DisplayName 'Reader User' -Provider 'azure'
            Save-CIEMGraphNode -Id 'user-owner' -Kind 'EntraUser' -DisplayName 'Owner User' -Provider 'azure'
            Save-CIEMGraphNode -Id '/subscriptions/sub-filter' -Kind 'AzureSubscription' -DisplayName 'Sub Filter' -Provider 'azure' -SubscriptionId 'sub-filter'

            Save-CIEMGraphEdge -SourceId 'user-reader' -TargetId '/subscriptions/sub-filter' -Kind 'HasRole' -Computed 1 `
                -Properties (@{ role_name = 'Reader'; role_definition_id = 'reader'; permissions_json = $null; privileged = $false; principal_type = 'User' } | ConvertTo-Json -Compress)

            Save-CIEMGraphEdge -SourceId 'user-owner' -TargetId '/subscriptions/sub-filter' -Kind 'HasRole' -Computed 1 `
                -Properties (@{ role_name = 'Owner'; role_definition_id = 'owner'; permissions_json = $null; privileged = $true; principal_type = 'User' } | ConvertTo-Json -Compress)

            $script:privilegedResults = @(Get-CIEMEffectivePermission -Provider Azure -PrivilegedOnly)
            $script:principalResults = @(Get-CIEMEffectivePermission -Provider Azure -PrincipalId 'user-reader')
        }

        It 'Returns only privileged rows when PrivilegedOnly is specified' {
            $script:privilegedResults | Should -HaveCount 1
            $script:privilegedResults[0].Principal.Id | Should -Be 'user-owner'
        }

        It 'Returns only selected principal rows when PrincipalId is specified' {
            $script:principalResults | Should -HaveCount 1
            $script:principalResults[0].Principal.Id | Should -Be 'user-reader'
        }

        It 'Describes Azure role names as actions when permission JSON is absent' {
            $script:principalResults[0].Actions[0].Description | Should -Be 'Can read Azure resources in this Azure subscription'
        }
    }

    Context 'when app role and OAuth grants are already discovered' {

        BeforeAll {
            Invoke-CIEMQuery -Query "DELETE FROM graph_edges"
            Invoke-CIEMQuery -Query "DELETE FROM graph_nodes"

            Save-CIEMGraphNode -Id 'sp-client' -Kind 'EntraServicePrincipal' -DisplayName 'Client App' -Provider 'azure'
            Save-CIEMGraphNode -Id 'sp-resource' -Kind 'EntraServicePrincipal' -DisplayName 'Resource API' -Provider 'azure'

            $script:entraResources = @(
                [pscustomobject]@{
                    Id = 'sp-client_app-role-assignment-1'
                    Type = 'appRoleAssignment'
                    ParentId = 'sp-client'
                    Properties = (@{
                        id = 'app-role-assignment-1'
                        appRoleId = 'app-role-1'
                        principalId = 'sp-client'
                        principalType = 'ServicePrincipal'
                        resourceId = 'sp-resource'
                        resourceDisplayName = 'Resource API'
                    } | ConvertTo-Json -Compress)
                },
                [pscustomobject]@{
                    Id = 'oauth-grant-1'
                    Type = 'oauth2PermissionGrant'
                    ParentId = 'sp-client'
                    Properties = (@{
                        id = 'oauth-grant-1'
                        clientId = 'sp-client'
                        consentType = 'AllPrincipals'
                        resourceId = 'sp-resource'
                        scope = 'User.Read Directory.Read.All'
                    } | ConvertTo-Json -Compress)
                }
            )

            InModuleScope Devolutions.CIEM -Parameters @{ entraResources = $script:entraResources } {
                InvokeCIEMGraphComputedEdgeBuild -ArmResources @() -EntraResources $entraResources -Relationships @() -Connection $null -CollectedAt '2026-01-01T00:00:00Z'
            }

            $script:appRoleEdges = @(Get-CIEMGraphEdge -SourceId 'sp-client' -TargetId 'sp-resource' -Kind 'HasAppRoleAssignment')
            $script:oauthEdges = @(Get-CIEMGraphEdge -SourceId 'sp-client' -TargetId 'sp-resource' -Kind 'HasOAuthGrant')
        }

        It 'Projects discovered app role assignments into graph edges' {
            $script:appRoleEdges | Should -HaveCount 1
        }

        It 'Projects discovered OAuth grants into graph edges' {
            $script:oauthEdges | Should -HaveCount 1
        }
    }
}
