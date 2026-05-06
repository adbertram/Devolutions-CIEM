@{
    ResourceGraphResources = @{
        Order = 10
        Name = 'ResourceGraph/Resources'
        Scope = @('All', 'ARM')
        Executor = 'InvokeCIEMResourceGraphQuery'
        Query = 'Resources'
        FailureMode = 'FailRun'
        DependsOn = @()
    }

    ResourceGraphResourceContainers = @{
        Order = 20
        Name = 'ResourceGraph/ResourceContainers'
        Scope = @('All', 'ARM')
        Executor = 'InvokeCIEMResourceGraphQuery'
        Query = 'ResourceContainers'
        FailureMode = 'FailRun'
        DependsOn = @('ResourceGraphResources')
    }

    ResourceGraphAuthorizationResources = @{
        Order = 30
        Name = 'ResourceGraph/AuthorizationResources'
        Scope = @('All', 'ARM')
        Executor = 'InvokeCIEMResourceGraphQuery'
        Query = 'AuthorizationResources'
        FailureMode = 'FailRun'
        DependsOn = @('ResourceGraphResourceContainers')
    }

    BuiltInRoleDefinitions = @{
        Order = 40
        Name = 'BuiltInRoleDefinitions'
        Scope = @('All', 'ARM')
        Executor = 'GetCIEMBuiltInRoleDefinitions'
        FailureMode = 'FailRun'
        DependsOn = @('ResourceGraphAuthorizationResources')
    }

    EntraEntityCollection = @{
        Order = 50
        Name = 'Entra entity collection'
        Scope = @('All', 'Entra')
        Executor = 'InvokeCIEMEntraEntityCollection'
        FailureMode = 'FailRun'
        DependsOn = @()
    }

    EntraPermissionCollection = @{
        Order = 60
        Name = 'Entra permission collection'
        Scope = @('All', 'Entra')
        Executor = 'InvokeCIEMEntraPermissionCollection'
        FailureMode = 'FailRun'
        DependsOn = @('EntraEntityCollection')
    }

    EntraRelationshipCollection = @{
        Order = 70
        Name = 'Entra relationship collection'
        Scope = @('All', 'Entra')
        Executor = 'InvokeCIEMEntraRelationshipCollection'
        FailureMode = 'FailRun'
        DependsOn = @('EntraEntityCollection')
    }
}
