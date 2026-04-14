function ConvertCIEMEffectivePermissionAction {
    [CmdletBinding()]
    [OutputType([CIEMEffectivePermissionAction[]])]
    param(
        [Parameter(Mandatory)]
        [CIEMEffectivePermissionProvider]$Provider,

        [Parameter()]
        [AllowNull()]
        [string]$PermissionsJson,

        [Parameter()]
        [AllowNull()]
        [string]$EntitlementName,

        [Parameter()]
        [AllowEmptyCollection()]
        [string[]]$NativeAction,

        [Parameter()]
        [CIEMPermissionEffect]$Effect = [CIEMPermissionEffect]::Allow,

        [Parameter()]
        [bool]$Privileged
    )

    $ErrorActionPreference = 'Stop'

    function ResolveAccessLevel {
        param(
            [Parameter()]
            [AllowNull()]
            [string]$Action,

            [Parameter()]
            [bool]$IsDataAction
        )

        $ErrorActionPreference = 'Stop'

        if (-not $Action) { return [CIEMAccessLevel]::Unclassified }

        $a = $Action.ToLowerInvariant()

        if ($a -eq '*') { return [CIEMAccessLevel]::Manage }
        if ($a -match 'administrator|admin|microsoft\.authorization/.*/roleassignments/(write|delete)|microsoft\.authorization/.*/roledefinitions/(write|delete)|microsoft\.authorization/elevateaccess') {
            return [CIEMAccessLevel]::PermissionAdmin
        }
        if ($a -match 'sts:assumerole|iam:passrole') { return [CIEMAccessLevel]::AssumeRole }
        if ($a -match 'impersonate') { return [CIEMAccessLevel]::Impersonate }
        if ($IsDataAction -and $a -match 'secret|keyvault|certificate') { return [CIEMAccessLevel]::SecretAccess }
        if ($IsDataAction) { return [CIEMAccessLevel]::DataAccess }
        if ($a -match '(^|[.:/])read($|[.:/])|(^|[.:/])get($|[.:/])|(^|[.:/])list($|[.:/])|describe') { return [CIEMAccessLevel]::Read }
        if ($a -match '(^|[.:/])write($|[.:/])|(^|[.:/])delete($|[.:/])|(^|[.:/])put($|[.:/])|(^|[.:/])create($|[.:/])|(^|[.:/])update($|[.:/])|/action$|:invoke') {
            return [CIEMAccessLevel]::Write
        }

        [CIEMAccessLevel]::Unclassified
    }

    function NewAction {
        param(
            [Parameter()]
            [AllowNull()]
            [string]$Action,

            [Parameter()]
            [bool]$IsDataAction
        )

        $ErrorActionPreference = 'Stop'

        $obj = [CIEMEffectivePermissionAction]::new()
        $obj.NativeAction = $Action
        $obj.AccessLevel = ResolveAccessLevel -Action $Action -IsDataAction $IsDataAction
        $obj.Effect = $Effect
        $obj.Privileged = $Privileged
        $obj
    }

    $actions = [System.Collections.Generic.List[object]]::new()

    if ($PSBoundParameters.ContainsKey('NativeAction')) {
        foreach ($action in $NativeAction) {
            if ([string]::IsNullOrWhiteSpace($action)) {
                throw 'NativeAction contains an empty action.'
            }
            $actions.Add((NewAction -Action $action -IsDataAction:$false))
        }
    }

    if ($PermissionsJson) {
        $permissions = @($PermissionsJson | ConvertFrom-Json -ErrorAction Stop)
        foreach ($permission in $permissions) {
            foreach ($action in @($permission.actions)) {
                if ([string]::IsNullOrWhiteSpace($action)) {
                    throw 'PermissionsJson contains an empty control-plane action.'
                }
                $actions.Add((NewAction -Action $action -IsDataAction:$false))
            }
            foreach ($action in @($permission.dataActions)) {
                if ([string]::IsNullOrWhiteSpace($action)) {
                    throw 'PermissionsJson contains an empty data-plane action.'
                }
                $actions.Add((NewAction -Action $action -IsDataAction:$true))
            }
        }
    }

    if ($actions.Count -eq 0) {
        if ([string]::IsNullOrWhiteSpace($EntitlementName)) {
            throw 'Cannot derive effective permission actions without NativeAction, PermissionsJson, or EntitlementName.'
        }
        $actions.Add((NewAction -Action $EntitlementName -IsDataAction:$false))
    }

    @($actions)
}
