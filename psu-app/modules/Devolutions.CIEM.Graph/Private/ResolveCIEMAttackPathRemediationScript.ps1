function ConvertToCIEMAttackPathRuleSlug {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $ErrorActionPreference = 'Stop'

    $slug = $Name.Trim().ToLowerInvariant() -replace '[^a-z0-9]+', '-' -replace '^-|-$', ''
    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw "Attack path rule name '$Name' cannot be converted to a remediation script folder slug."
    }
    $slug
}

function ConvertToCIEMAttackPathPsuScriptName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$RemediationScriptPath
    )

    $ErrorActionPreference = 'Stop'

    $normalizedPath = $RemediationScriptPath.Replace('\', '/')
    $leaf = @($normalizedPath -split '/')[-1]
    $scriptName = [System.IO.Path]::GetFileNameWithoutExtension($leaf)
    if ([string]::IsNullOrWhiteSpace($scriptName)) {
        throw "Attack path remediation script path '$RemediationScriptPath' cannot be converted to a PSU script name."
    }

    $scriptName
}

function GetCIEMAttackPathRemediationScriptTemplateContent {
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    $templatePath = Join-Path $script:GraphRoot 'Data/attack_path_remediation_script_template.ps1'
    if (-not (Test-Path -Path $templatePath -PathType Leaf)) {
        throw "Attack path remediation script template not found: $templatePath"
    }

    $content = Get-Content -Path $templatePath -Raw
    if ([string]::IsNullOrWhiteSpace($content)) {
        throw "Attack path remediation script template is empty: $templatePath"
    }

    $content
}

function MergeCIEMAttackPathRemediationScriptTemplate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TemplateContent,

        [Parameter(Mandatory)]
        [string]$ScriptBodyContent,

        [Parameter(Mandatory)]
        [string]$ScriptName
    )

    $ErrorActionPreference = 'Stop'

    if ([string]::IsNullOrWhiteSpace($TemplateContent)) {
        throw "Cannot create attack path remediation script '$ScriptName' because the shared template is empty."
    }

    if ([string]::IsNullOrWhiteSpace($ScriptBodyContent)) {
        throw "Cannot create attack path remediation script '$ScriptName' because the script body is empty."
    }

    $helpPlaceholder = '{{CIEM_ATTACK_PATH_SCRIPT_HELP}}'
    $bodyPlaceholder = '{{CIEM_ATTACK_PATH_SCRIPT_BODY}}'

    $helpPlaceholderCount = [regex]::Matches($TemplateContent, [regex]::Escape($helpPlaceholder)).Count
    if ($helpPlaceholderCount -ne 1) {
        throw "Cannot create attack path remediation script '$ScriptName' because the shared template must contain exactly one $helpPlaceholder placeholder."
    }

    $bodyPlaceholderCount = [regex]::Matches($TemplateContent, [regex]::Escape($bodyPlaceholder)).Count
    if ($bodyPlaceholderCount -ne 1) {
        throw "Cannot create attack path remediation script '$ScriptName' because the shared template must contain exactly one $bodyPlaceholder placeholder."
    }

    $scriptBodyContent = $ScriptBodyContent.Trim()
    $commentMatch = [regex]::Match($scriptBodyContent, '^(?<comment><#[\s\S]*?#>)\s*(?<body>[\s\S]*)$')
    if (-not $commentMatch.Success) {
        throw "Cannot create attack path remediation script '$ScriptName' because the script body must start with a PowerShell comment-help block."
    }

    $scriptHelpContent = $commentMatch.Groups['comment'].Value.TrimEnd()
    $scriptBodyOnly = $commentMatch.Groups['body'].Value.Trim()
    if ([string]::IsNullOrWhiteSpace($scriptBodyOnly)) {
        throw "Cannot create attack path remediation script '$ScriptName' because the script body has no executable commands after the comment-help block."
    }

    $TemplateContent.Replace($helpPlaceholder, $scriptHelpContent).Replace($bodyPlaceholder, $scriptBodyOnly).TrimEnd()
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

    $ErrorActionPreference = 'Stop'

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "Cannot render remediation script because '$Name' is empty."
    }

    "'$($Value.Replace("'", "''"))'"
}

function ConvertToCIEMUriPathSegment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Value,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $ErrorActionPreference = 'Stop'

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "Cannot render remediation script because '$Name' is empty."
    }

    [uri]::EscapeDataString($Value)
}

function NewCIEMAzureRestDeleteCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('ARM', 'Graph')]
        [string]$Api,

        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter(Mandatory)]
        [string]$ResourceName
    )

    $ErrorActionPreference = 'Stop'

    "Devolutions.CIEM\Invoke-AzureApi -Api $Api -Method DELETE -Uri $(ConvertToCIEMPowerShellSingleQuotedString -Value $Uri -Name 'URI') -ResourceName $(ConvertToCIEMPowerShellSingleQuotedString -Value $ResourceName -Name 'resource name') -Raw | Out-Null"
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

    $ErrorActionPreference = 'Stop'

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

    $ErrorActionPreference = 'Stop'

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
        [object]$AttackPath
    )

    $ErrorActionPreference = 'Stop'

    $commands = [System.Collections.Generic.List[string]]::new()
    foreach ($edge in @($AttackPath.Edges | Where-Object { $_.kind -eq 'HasRole' })) {
        $props = ConvertFromCIEMAttackPathProperties -PropertiesJson $edge.properties -Context 'HasRole edge'
        $roleAssignmentId = GetCIEMRequiredObjectValue -Object $props -PropertyName 'role_assignment_id' -Context 'HasRole edge properties'
        $uri = "https://management.azure.com${roleAssignmentId}?api-version=2022-04-01"

        $commands.Add((NewCIEMAzureRestDeleteCommand -Api ARM -Uri $uri -ResourceName "Azure RBAC role assignment $roleAssignmentId"))
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
        [object]$AttackPath
    )

    $ErrorActionPreference = 'Stop'

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
                $uri = "https://management.azure.com${ruleId}?api-version=2023-09-01"
                $commands.Add((NewCIEMAzureRestDeleteCommand -Api ARM -Uri $uri -ResourceName "Azure NSG rule $ruleId"))
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
        [object]$AttackPath
    )

    $ErrorActionPreference = 'Stop'

    $commands = [System.Collections.Generic.List[string]]::new()
    $seenMemberships = @{}

    foreach ($edge in @($AttackPath.Edges | Where-Object { $_.kind -eq 'MemberOf' })) {
        $memberId = GetCIEMRequiredObjectValue -Object $edge -PropertyName 'source_id' -Context 'MemberOf edge'
        $groupId = GetCIEMRequiredObjectValue -Object $edge -PropertyName 'target_id' -Context 'MemberOf edge'
        $membershipKey = "$groupId|$memberId"
        if (-not $seenMemberships.ContainsKey($membershipKey)) {
            $seenMemberships[$membershipKey] = $true
            $uri = 'https://graph.microsoft.com/v1.0/groups/{0}/members/{1}/$ref' -f (ConvertToCIEMUriPathSegment -Value $groupId -Name 'group id'), (ConvertToCIEMUriPathSegment -Value $memberId -Name 'member id')
            $commands.Add((NewCIEMAzureRestDeleteCommand -Api Graph -Uri $uri -ResourceName "Microsoft Graph group member $groupId/$memberId"))
        }
    }

    foreach ($edge in @($AttackPath.Edges | Where-Object { $_.kind -eq 'InheritedRole' })) {
        $memberId = GetCIEMRequiredObjectValue -Object $edge -PropertyName 'source_id' -Context 'InheritedRole edge'
        $props = ConvertFromCIEMAttackPathProperties -PropertiesJson $edge.properties -Context 'InheritedRole edge'
        $groupId = GetCIEMRequiredObjectValue -Object $props -PropertyName 'inherited_from' -Context 'InheritedRole edge properties'
        $membershipKey = "$groupId|$memberId"
        if (-not $seenMemberships.ContainsKey($membershipKey)) {
            $seenMemberships[$membershipKey] = $true
            $uri = 'https://graph.microsoft.com/v1.0/groups/{0}/members/{1}/$ref' -f (ConvertToCIEMUriPathSegment -Value $groupId -Name 'group id'), (ConvertToCIEMUriPathSegment -Value $memberId -Name 'member id')
            $commands.Add((NewCIEMAzureRestDeleteCommand -Api Graph -Uri $uri -ResourceName "Microsoft Graph group member $groupId/$memberId"))
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
        [object]$AttackPath
    )

    $ErrorActionPreference = 'Stop'

    $labels = @($AttackPath.Path | ForEach-Object {
        $label = if ($_.display_name) { $_.display_name } else { $_.id }
        "$label ($($_.kind))"
    })
    $labels -join ' -> '
}

function ConvertToCIEMAttackPathId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PatternId,

        [Parameter(Mandatory)]
        [object[]]$Path,

        [Parameter(Mandatory)]
        [object[]]$Edges
    )

    $ErrorActionPreference = 'Stop'

    if ([string]::IsNullOrWhiteSpace($PatternId)) {
        throw 'Cannot create attack path id because PatternId is empty.'
    }

    if (@($Path).Count -eq 0) {
        throw "Cannot create attack path id for '$PatternId' because Path is empty."
    }

    $parts = [System.Collections.Generic.List[string]]::new()
    $parts.Add($PatternId)
    foreach ($node in @($Path)) {
        $parts.Add((GetCIEMRequiredObjectValue -Object $node -PropertyName 'id' -Context "attack path '$PatternId' node"))
    }
    foreach ($edge in @($Edges)) {
        $edgeId = GetCIEMRequiredObjectValue -Object $edge -PropertyName 'id' -Context "attack path '$PatternId' edge"
        $sourceId = GetCIEMRequiredObjectValue -Object $edge -PropertyName 'source_id' -Context "attack path '$PatternId' edge"
        $targetId = GetCIEMRequiredObjectValue -Object $edge -PropertyName 'target_id' -Context "attack path '$PatternId' edge"
        $kind = GetCIEMRequiredObjectValue -Object $edge -PropertyName 'kind' -Context "attack path '$PatternId' edge"
        $parts.Add("$edgeId/$sourceId/$targetId/$kind")
    }

    $content = $parts -join '|'
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($content)
        $hash = [System.BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }

    "$PatternId-$($hash.Substring(0, 16))"
}

function GetCIEMActiveAzureAuthenticationProfileForAttackPathScript {
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    $profiles = @(Get-CIEMAzureAuthenticationProfile -ProviderId 'azure' -IsActive $true)
    if ($profiles.Count -ne 1) {
        throw "Cannot render attack path remediation script because exactly one active Azure authentication profile is required; found $($profiles.Count)."
    }

    $profiles[0]
}

function GetCIEMRequiredTokenObjectValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Object,

        [Parameter(Mandatory)]
        [string]$PropertyName,

        [Parameter(Mandatory)]
        [string]$Context
    )

    $ErrorActionPreference = 'Stop'

    if (-not $Object.PSObject.Properties[$PropertyName]) {
        throw "Cannot render attack path remediation script because $Context is missing '$PropertyName'."
    }

    $value = [string]$Object.$PropertyName
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Cannot render attack path remediation script because $Context '$PropertyName' is empty."
    }

    $value
}

function ResolveCIEMAttackPathScriptContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Pattern,

        [Parameter(Mandatory)]
        [object]$AttackPath,

        [Parameter(Mandatory)]
        [string]$ScriptContent
    )

    $ErrorActionPreference = 'Stop'

    if ([string]::IsNullOrWhiteSpace($ScriptContent)) {
        throw "Cannot render attack path remediation script because script content is empty for '$($AttackPath.PsuScriptName)'."
    }

    $content = $ScriptContent
    $tokens = @([regex]::Matches($content, '{{([A-Z0-9_]+)}}') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    $authProfile = $null
    $psuEnvironment = $null

    foreach ($token in $tokens) {
        $value = switch ($token) {
            'PATTERN_NAME' { [string]$Pattern.Name; break }
            'PATH_CHAIN' { GetCIEMAttackPathChainText -AttackPath $AttackPath; break }
            'ROLE_ASSIGNMENT_DELETE_COMMANDS' { NewCIEMRoleAssignmentDeleteCommandBlock -AttackPath $AttackPath; break }
            'NSG_RULE_DELETE_COMMANDS' { NewCIEMNsgRuleDeleteCommandBlock -AttackPath $AttackPath; break }
            'GROUP_MEMBER_REMOVE_COMMANDS' { NewCIEMGroupMemberRemoveCommandBlock -AttackPath $AttackPath; break }
            'AUTH_PROFILE_ID' {
                if ($null -eq $authProfile) { $authProfile = GetCIEMActiveAzureAuthenticationProfileForAttackPathScript }
                GetCIEMRequiredTokenObjectValue -Object $authProfile -PropertyName 'Id' -Context 'active Azure authentication profile'
                break
            }
            'AUTH_PROFILE_NAME' {
                if ($null -eq $authProfile) { $authProfile = GetCIEMActiveAzureAuthenticationProfileForAttackPathScript }
                GetCIEMRequiredTokenObjectValue -Object $authProfile -PropertyName 'Name' -Context 'active Azure authentication profile'
                break
            }
            'AUTH_PROFILE_METHOD' {
                if ($null -eq $authProfile) { $authProfile = GetCIEMActiveAzureAuthenticationProfileForAttackPathScript }
                GetCIEMRequiredTokenObjectValue -Object $authProfile -PropertyName 'Method' -Context 'active Azure authentication profile'
                break
            }
            'TENANT_ID' {
                if ($null -eq $authProfile) { $authProfile = GetCIEMActiveAzureAuthenticationProfileForAttackPathScript }
                GetCIEMRequiredTokenObjectValue -Object $authProfile -PropertyName 'TenantId' -Context 'active Azure authentication profile'
                break
            }
            'CLIENT_ID' {
                if ($null -eq $authProfile) { $authProfile = GetCIEMActiveAzureAuthenticationProfileForAttackPathScript }
                GetCIEMRequiredTokenObjectValue -Object $authProfile -PropertyName 'ClientId' -Context 'active Azure authentication profile'
                break
            }
            'MANAGED_IDENTITY_CLIENT_ID' {
                if ($null -eq $authProfile) { $authProfile = GetCIEMActiveAzureAuthenticationProfileForAttackPathScript }
                GetCIEMRequiredTokenObjectValue -Object $authProfile -PropertyName 'ManagedIdentityClientId' -Context 'active Azure authentication profile'
                break
            }
            'PSU_ENVIRONMENT' {
                if ($null -eq $psuEnvironment) { $psuEnvironment = Get-PSUInstalledEnvironment }
                GetCIEMRequiredTokenObjectValue -Object $psuEnvironment -PropertyName 'Environment' -Context 'PSU environment'
                break
            }
            'PSU_WEBSITE_NAME' {
                if ($null -eq $psuEnvironment) { $psuEnvironment = Get-PSUInstalledEnvironment }
                GetCIEMRequiredTokenObjectValue -Object $psuEnvironment -PropertyName 'WebsiteName' -Context 'PSU environment'
                break
            }
            default { throw "Attack path remediation script '$($AttackPath.PsuScriptName)' contains unknown token '$token'." }
        }
        $content = $content.Replace("{{$token}}", [string]$value)
    }

    if ($content -match '{{[A-Z0-9_]+}}') {
        throw "Attack path remediation script '$($AttackPath.PsuScriptName)' contains unresolved tokens."
    }

    $content.TrimEnd()
}

function ResolveCIEMAttackPathRemediationScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Pattern,

        [Parameter(Mandatory)]
        [object]$AttackPath
    )

    $ErrorActionPreference = 'Stop'

    $relativeScriptPath = [string]$Pattern.RemediationScriptPath
    if ([string]::IsNullOrWhiteSpace($relativeScriptPath)) {
        throw "Attack path pattern '$($Pattern.Id)' is missing RemediationScriptPath."
    }

    $scriptPath = Join-Path $script:ModuleRoot $relativeScriptPath
    if (-not (Test-Path -Path $scriptPath -PathType Leaf)) {
        throw "Attack path pattern '$($Pattern.Id)' references missing remediation script '$relativeScriptPath'."
    }

    $templateContent = GetCIEMAttackPathRemediationScriptTemplateContent
    $scriptContent = MergeCIEMAttackPathRemediationScriptTemplate `
        -TemplateContent $templateContent `
        -ScriptBodyContent (Get-Content -Path $scriptPath -Raw) `
        -ScriptName $relativeScriptPath

    $content = ResolveCIEMAttackPathScriptContent -Pattern $Pattern -AttackPath $AttackPath -ScriptContent $scriptContent

    [pscustomobject]@{
        RelativePath = $relativeScriptPath
        Content      = $content
    }
}
