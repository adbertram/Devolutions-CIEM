function ConvertToCIEMAttackPathRuleSlug {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $slug = $Name.Trim().ToLowerInvariant() -replace '[^a-z0-9]+', '-' -replace '^-|-$', ''
    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw "Attack path rule name '$Name' cannot be converted to a remediation script folder slug."
    }
    $slug
}

function ConvertToCIEMPowerShellSingleQuotedString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "Cannot render remediation script because '$Name' is empty."
    }

    "'$($Value.Replace("'", "''"))'"
}

function ConvertFromCIEMAttackPathProperties {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [string]$PropertiesJson,

        [Parameter(Mandatory)]
        [string]$Context
    )

    if ([string]::IsNullOrWhiteSpace($PropertiesJson)) {
        [pscustomobject]@{}
        return
    }

    try {
        $PropertiesJson | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Cannot render remediation script because $Context properties are invalid JSON: $($_.Exception.Message)"
    }
}

function GetCIEMRequiredObjectValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Object,

        [Parameter(Mandatory)]
        [string]$PropertyName,

        [Parameter(Mandatory)]
        [string]$Context
    )

    if (-not $Object.PSObject.Properties[$PropertyName]) {
        throw "Cannot render remediation script because $Context is missing '$PropertyName'."
    }

    $value = [string]$Object.$PropertyName
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Cannot render remediation script because $Context '$PropertyName' is empty."
    }

    $value
}

function NewCIEMRoleAssignmentDeleteCommandBlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [CIEMAttackPath]$AttackPath
    )

    $commands = [System.Collections.Generic.List[string]]::new()
    foreach ($edge in @($AttackPath.Edges | Where-Object { $_.kind -eq 'HasRole' })) {
        $principalId = GetCIEMRequiredObjectValue -Object $edge -PropertyName 'source_id' -Context 'HasRole edge'
        $scope = GetCIEMRequiredObjectValue -Object $edge -PropertyName 'target_id' -Context 'HasRole edge'
        $props = ConvertFromCIEMAttackPathProperties -PropertiesJson $edge.properties -Context 'HasRole edge'
        $roleDefinitionId = GetCIEMRequiredObjectValue -Object $props -PropertyName 'role_definition_id' -Context 'HasRole edge properties'

        $commands.Add("az role assignment delete --assignee-object-id $(ConvertToCIEMPowerShellSingleQuotedString -Value $principalId -Name 'principal id') --role $(ConvertToCIEMPowerShellSingleQuotedString -Value $roleDefinitionId -Name 'role definition id') --scope $(ConvertToCIEMPowerShellSingleQuotedString -Value $scope -Name 'scope') --only-show-errors")
    }

    if ($commands.Count -eq 0) {
        throw "Cannot render remediation script because attack path '$($AttackPath.PatternId)' has no direct HasRole edge."
    }

    $commands -join "`n"
}

function NewCIEMNsgRuleDeleteCommandBlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [CIEMAttackPath]$AttackPath
    )

    $commands = [System.Collections.Generic.List[string]]::new()
    $seenRuleIds = @{}
    foreach ($edge in @($AttackPath.Edges | Where-Object { $_.kind -eq 'AllowsInbound' })) {
        $nsgId = GetCIEMRequiredObjectValue -Object $edge -PropertyName 'target_id' -Context 'AllowsInbound edge'
        $props = ConvertFromCIEMAttackPathProperties -PropertiesJson $edge.properties -Context 'AllowsInbound edge'
        if (-not $props.PSObject.Properties['open_ports'] -or @($props.open_ports).Count -eq 0) {
            throw "Cannot render remediation script because AllowsInbound edge properties are missing 'open_ports'."
        }

        foreach ($openPort in @($props.open_ports)) {
            $ruleName = GetCIEMRequiredObjectValue -Object $openPort -PropertyName 'rule_name' -Context 'AllowsInbound open_ports entry'
            $ruleId = "$nsgId/securityRules/$ruleName"
            if (-not $seenRuleIds.ContainsKey($ruleId)) {
                $seenRuleIds[$ruleId] = $true
                $commands.Add("az network nsg rule delete --ids $(ConvertToCIEMPowerShellSingleQuotedString -Value $ruleId -Name 'NSG rule id') --only-show-errors")
            }
        }
    }

    if ($commands.Count -eq 0) {
        throw "Cannot render remediation script because attack path '$($AttackPath.PatternId)' has no AllowsInbound edge."
    }

    $commands -join "`n"
}

function NewCIEMGroupMemberRemoveCommandBlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [CIEMAttackPath]$AttackPath
    )

    $commands = [System.Collections.Generic.List[string]]::new()
    $seenMemberships = @{}

    foreach ($edge in @($AttackPath.Edges | Where-Object { $_.kind -eq 'MemberOf' })) {
        $memberId = GetCIEMRequiredObjectValue -Object $edge -PropertyName 'source_id' -Context 'MemberOf edge'
        $groupId = GetCIEMRequiredObjectValue -Object $edge -PropertyName 'target_id' -Context 'MemberOf edge'
        $membershipKey = "$groupId|$memberId"
        if (-not $seenMemberships.ContainsKey($membershipKey)) {
            $seenMemberships[$membershipKey] = $true
            $commands.Add("az ad group member remove --group $(ConvertToCIEMPowerShellSingleQuotedString -Value $groupId -Name 'group id') --member-id $(ConvertToCIEMPowerShellSingleQuotedString -Value $memberId -Name 'member id') --only-show-errors")
        }
    }

    foreach ($edge in @($AttackPath.Edges | Where-Object { $_.kind -eq 'InheritedRole' })) {
        $memberId = GetCIEMRequiredObjectValue -Object $edge -PropertyName 'source_id' -Context 'InheritedRole edge'
        $props = ConvertFromCIEMAttackPathProperties -PropertiesJson $edge.properties -Context 'InheritedRole edge'
        $groupId = GetCIEMRequiredObjectValue -Object $props -PropertyName 'inherited_from' -Context 'InheritedRole edge properties'
        $membershipKey = "$groupId|$memberId"
        if (-not $seenMemberships.ContainsKey($membershipKey)) {
            $seenMemberships[$membershipKey] = $true
            $commands.Add("az ad group member remove --group $(ConvertToCIEMPowerShellSingleQuotedString -Value $groupId -Name 'group id') --member-id $(ConvertToCIEMPowerShellSingleQuotedString -Value $memberId -Name 'member id') --only-show-errors")
        }
    }

    if ($commands.Count -eq 0) {
        throw "Cannot render remediation script because attack path '$($AttackPath.PatternId)' has no group membership edge."
    }

    $commands -join "`n"
}

function GetCIEMAttackPathChainText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [CIEMAttackPath]$AttackPath
    )

    $labels = @($AttackPath.Path | ForEach-Object {
        $label = if ($_.display_name) { $_.display_name } else { $_.id }
        "$label ($($_.kind))"
    })
    $labels -join ' -> '
}

function ResolveCIEMAttackPathRemediationScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Pattern,

        [Parameter(Mandatory)]
        [CIEMAttackPath]$AttackPath
    )

    $relativeScriptPath = [string]$Pattern.remediation_script
    if ([string]::IsNullOrWhiteSpace($relativeScriptPath)) {
        throw "Attack path pattern '$($Pattern.id)' is missing remediation_script."
    }

    $scriptPath = Join-Path (Join-Path $script:GraphRoot 'Data') $relativeScriptPath
    if (-not (Test-Path -Path $scriptPath -PathType Leaf)) {
        throw "Attack path pattern '$($Pattern.id)' references missing remediation script '$relativeScriptPath'."
    }

    $content = Get-Content -Path $scriptPath -Raw
    $tokens = @([regex]::Matches($content, '{{([A-Z0-9_]+)}}') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)

    foreach ($token in $tokens) {
        $value = switch ($token) {
            'PATTERN_NAME' { [string]$Pattern.name; break }
            'PATH_CHAIN' { GetCIEMAttackPathChainText -AttackPath $AttackPath; break }
            'ROLE_ASSIGNMENT_DELETE_COMMANDS' { NewCIEMRoleAssignmentDeleteCommandBlock -AttackPath $AttackPath; break }
            'NSG_RULE_DELETE_COMMANDS' { NewCIEMNsgRuleDeleteCommandBlock -AttackPath $AttackPath; break }
            'GROUP_MEMBER_REMOVE_COMMANDS' { NewCIEMGroupMemberRemoveCommandBlock -AttackPath $AttackPath; break }
            default { throw "Attack path remediation script '$relativeScriptPath' contains unknown token '$token'." }
        }
        $content = $content.Replace("{{$token}}", $value)
    }

    if ($content -match '{{[A-Z0-9_]+}}') {
        throw "Attack path remediation script '$relativeScriptPath' contains unresolved tokens."
    }

    [pscustomobject]@{
        RelativePath = $relativeScriptPath
        Content      = $content.TrimEnd()
    }
}
