@{
    PATTERN_NAME = @{
        Name                 = 'PATTERN_NAME'
        Resolver             = 'ResolveCIEMAttackPathPatternNameToken'
        RequiredNodeKinds    = @()
        RequiredEdgeKinds    = @()
        RequiredEdgeKindMode = 'All'
        OutputType           = 'Text'
        Description          = 'Attack path pattern display name.'
    }
    PATH_CHAIN = @{
        Name                 = 'PATH_CHAIN'
        Resolver             = 'ResolveCIEMAttackPathChainToken'
        RequiredNodeKinds    = @('*')
        RequiredEdgeKinds    = @()
        RequiredEdgeKindMode = 'All'
        OutputType           = 'Text'
        Description          = 'Rendered finding path chain with node labels and kinds.'
    }
    ROLE_ASSIGNMENT_DELETE_COMMANDS = @{
        Name                 = 'ROLE_ASSIGNMENT_DELETE_COMMANDS'
        Resolver             = 'ResolveCIEMAttackPathRoleAssignmentDeleteCommandsToken'
        RequiredNodeKinds    = @()
        RequiredEdgeKinds    = @('HasRole')
        RequiredEdgeKindMode = 'All'
        OutputType           = 'PowerShell'
        Description          = 'PowerShell commands that delete direct Azure RBAC role assignments found in the path.'
    }
    NSG_RULE_DELETE_COMMANDS = @{
        Name                 = 'NSG_RULE_DELETE_COMMANDS'
        Resolver             = 'ResolveCIEMAttackPathNsgRuleDeleteCommandsToken'
        RequiredNodeKinds    = @()
        RequiredEdgeKinds    = @('AllowsInbound')
        RequiredEdgeKindMode = 'All'
        OutputType           = 'PowerShell'
        Description          = 'PowerShell commands that delete exposed Azure NSG security rules found in the path.'
    }
    GROUP_MEMBER_REMOVE_COMMANDS = @{
        Name                 = 'GROUP_MEMBER_REMOVE_COMMANDS'
        Resolver             = 'ResolveCIEMAttackPathGroupMemberRemoveCommandsToken'
        RequiredNodeKinds    = @()
        RequiredEdgeKinds    = @('MemberOf', 'InheritedRole')
        RequiredEdgeKindMode = 'Any'
        OutputType           = 'PowerShell'
        Description          = 'PowerShell commands that remove direct or inherited group memberships found in the path.'
    }
    AUTH_PROFILE_ID = @{
        Name                 = 'AUTH_PROFILE_ID'
        Resolver             = 'ResolveCIEMAttackPathAuthProfileIdToken'
        RequiredNodeKinds    = @()
        RequiredEdgeKinds    = @()
        RequiredEdgeKindMode = 'All'
        OutputType           = 'Text'
        Description          = 'Active Azure authentication profile identifier.'
    }
    AUTH_PROFILE_NAME = @{
        Name                 = 'AUTH_PROFILE_NAME'
        Resolver             = 'ResolveCIEMAttackPathAuthProfileNameToken'
        RequiredNodeKinds    = @()
        RequiredEdgeKinds    = @()
        RequiredEdgeKindMode = 'All'
        OutputType           = 'Text'
        Description          = 'Active Azure authentication profile display name.'
    }
    AUTH_PROFILE_METHOD = @{
        Name                 = 'AUTH_PROFILE_METHOD'
        Resolver             = 'ResolveCIEMAttackPathAuthProfileMethodToken'
        RequiredNodeKinds    = @()
        RequiredEdgeKinds    = @()
        RequiredEdgeKindMode = 'All'
        OutputType           = 'Text'
        Description          = 'Active Azure authentication profile method.'
    }
    TENANT_ID = @{
        Name                 = 'TENANT_ID'
        Resolver             = 'ResolveCIEMAttackPathTenantIdToken'
        RequiredNodeKinds    = @()
        RequiredEdgeKinds    = @()
        RequiredEdgeKindMode = 'All'
        OutputType           = 'Text'
        Description          = 'Tenant ID from the active Azure authentication profile.'
    }
    CLIENT_ID = @{
        Name                 = 'CLIENT_ID'
        Resolver             = 'ResolveCIEMAttackPathClientIdToken'
        RequiredNodeKinds    = @()
        RequiredEdgeKinds    = @()
        RequiredEdgeKindMode = 'All'
        OutputType           = 'Text'
        Description          = 'Client ID from the active Azure authentication profile.'
    }
    MANAGED_IDENTITY_CLIENT_ID = @{
        Name                 = 'MANAGED_IDENTITY_CLIENT_ID'
        Resolver             = 'ResolveCIEMAttackPathManagedIdentityClientIdToken'
        RequiredNodeKinds    = @()
        RequiredEdgeKinds    = @()
        RequiredEdgeKindMode = 'All'
        OutputType           = 'Text'
        Description          = 'Managed identity client ID from the active Azure authentication profile.'
    }
    PSU_ENVIRONMENT = @{
        Name                 = 'PSU_ENVIRONMENT'
        Resolver             = 'ResolveCIEMAttackPathPsuEnvironmentToken'
        RequiredNodeKinds    = @()
        RequiredEdgeKinds    = @()
        RequiredEdgeKindMode = 'All'
        OutputType           = 'Text'
        Description          = 'PowerShell Universal hosting environment name.'
    }
    PSU_WEBSITE_NAME = @{
        Name                 = 'PSU_WEBSITE_NAME'
        Resolver             = 'ResolveCIEMAttackPathPsuWebsiteNameToken'
        RequiredNodeKinds    = @()
        RequiredEdgeKinds    = @()
        RequiredEdgeKindMode = 'All'
        OutputType           = 'Text'
        Description          = 'PowerShell Universal website name when hosted on Azure App Service.'
    }
}
