function Initialize-CIEMPSUManagedIdentity {
    <#
    .SYNOPSIS
        Provisions a system-assigned managed identity for an Azure CIEM PSU instance and grants the Azure RBAC and Microsoft Graph permissions CIEM needs.

    .DESCRIPTION
        Enables system-assigned managed identity on the PSU App Service, grants Reader on each
        target subscription, and grants Microsoft Graph application permissions to the new
        principal so the CIEM module can use ManagedIdentity authentication out of the box.

        Defaults to the Microsoft Graph permissions referenced by the CIEM Azure check catalog
        (Directory.Read.All, Policy.Read.All, RoleManagement.Read.Directory, User.Read.All,
        UserAuthenticationMethod.Read.All). Reader covers every ARM permission CIEM checks
        require (roleDefinitions/diagnosticSettings/keyVault/storage reads).

    .PARAMETER ResourceGroup
        Resource group containing the PSU App Service.

    .PARAMETER SiteName
        Name of the PSU App Service (Microsoft.Web/sites resource).

    .PARAMETER SubscriptionId
        Subscription IDs to grant Reader on. Defaults to the current az subscription.

    .PARAMETER GraphPermission
        Microsoft Graph application permission names to grant the principal. Defaults to the
        permissions referenced by the CIEM Azure check catalog. Pass an empty array (@()) to
        skip Graph permission setup.

    .PARAMETER Restart
        Restart the App Service after enabling the identity so App Service injects the MSI
        environment variables (IDENTITY_ENDPOINT / IDENTITY_HEADER) into the container.

    .PARAMETER TimeoutSeconds
        Maximum time to wait for /api/v1/alive after restart.

    .PARAMETER PollIntervalSeconds
        Poll interval while waiting for /api/v1/alive.

    .OUTPUTS
        [pscustomobject] with PrincipalId, ResourceGroup, SiteName, Url, SubscriptionsGranted,
        GraphPermissionsGranted, Restarted, AppReady.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [string]$ResourceGroup = 'devolutions-ciem-rg',

        [Parameter()]
        [string]$SiteName = 'devolutions-ciem-psu',

        [Parameter()]
        [string[]]$SubscriptionId,

        [Parameter()]
        [AllowEmptyCollection()]
        [string[]]$GraphPermission = @(
            'Directory.Read.All'
            'Policy.Read.All'
            'RoleManagement.Read.Directory'
            'User.Read.All'
            'UserAuthenticationMethod.Read.All'
        ),

        [Parameter()]
        [switch]$Restart,

        [Parameter()]
        [int]$TimeoutSeconds = 600,

        [Parameter()]
        [int]$PollIntervalSeconds = 10
    )

    $ErrorActionPreference = 'Stop'

    # 1. Enable system-assigned managed identity (idempotent — returns existing if already on)
    $identityJson = @(Invoke-CIEMAzCommand -ArgumentList @(
            'webapp', 'identity', 'assign'
            '--name', $SiteName
            '--resource-group', $ResourceGroup
            '-o', 'json'
        )) -join "`n"

    $identity = $identityJson | ConvertFrom-Json
    $principalId = [string]$identity.principalId
    if ([string]::IsNullOrWhiteSpace($principalId)) {
        throw "az webapp identity assign returned no principalId. Output: $identityJson"
    }

    Write-Verbose "Managed identity principalId: $principalId"

    # 2. Resolve target subscriptions (default to current)
    if (-not $SubscriptionId -or $SubscriptionId.Count -eq 0) {
        $current = @(Invoke-CIEMAzCommand -ArgumentList @('account', 'show', '--query', 'id', '-o', 'tsv')) -join "`n"
        $current = ([string]$current).Trim()
        if ([string]::IsNullOrWhiteSpace($current)) {
            throw 'Unable to resolve current Azure subscription. Pass -SubscriptionId or run az login.'
        }
        $SubscriptionId = @($current)
    }

    # 3. Grant Reader on each subscription
    $subscriptionsGranted = [System.Collections.Generic.List[string]]::new()
    foreach ($sub in $SubscriptionId) {
        Write-Verbose "Granting Reader on /subscriptions/$sub"
        Invoke-CIEMAzCommand -ArgumentList @(
            'role', 'assignment', 'create'
            '--assignee-object-id', $principalId
            '--assignee-principal-type', 'ServicePrincipal'
            '--role', 'Reader'
            '--scope', "/subscriptions/$sub"
            '-o', 'none'
        ) | Out-Null
        $subscriptionsGranted.Add($sub)
    }

    # 4. Grant Microsoft Graph application permissions
    $graphGranted = [System.Collections.Generic.List[string]]::new()
    if ($GraphPermission -and $GraphPermission.Count -gt 0) {
        $graphSpJson = @(Invoke-CIEMAzCommand -ArgumentList @(
                'rest'
                '--method', 'get'
                '--url', "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=appId eq '00000003-0000-0000-c000-000000000000'"
            )) -join "`n"

        $graphSp = ($graphSpJson | ConvertFrom-Json).value | Select-Object -First 1
        if (-not $graphSp) {
            throw 'Unable to resolve Microsoft Graph service principal in this tenant.'
        }
        $graphSpId = [string]$graphSp.id
        $appRoleByName = @{}
        foreach ($role in $graphSp.appRoles) {
            $appRoleByName[$role.value] = $role.id
        }

        foreach ($permName in $GraphPermission) {
            $appRoleId = $appRoleByName[$permName]
            if (-not $appRoleId) {
                throw "Microsoft Graph application permission '$permName' not found on the Graph service principal."
            }

            $body = @{
                principalId = $principalId
                resourceId  = $graphSpId
                appRoleId   = $appRoleId
            } | ConvertTo-Json -Compress

            $url = "https://graph.microsoft.com/v1.0/servicePrincipals/$principalId/appRoleAssignments"

            $output = az rest `
                --method post `
                --url $url `
                --headers 'Content-Type=application/json' `
                --body $body 2>&1
            $exit = $global:LASTEXITCODE

            if ($exit -ne 0) {
                $combined = @($output) -join "`n"
                if ($combined -match 'already exists' -or $combined -match 'Permission being assigned already exists') {
                    Write-Verbose "Graph permission '$permName' already granted; continuing."
                }
                else {
                    throw "Failed to grant Microsoft Graph permission '$permName'. Output: $combined"
                }
            }

            $graphGranted.Add($permName)
        }
    }

    # 5. Optional restart + readiness probe
    $restarted = $false
    $appReady = $false
    if ($Restart) {
        Invoke-CIEMAzCommand -ArgumentList @(
            'webapp', 'restart'
            '--name', $SiteName
            '--resource-group', $ResourceGroup
            '-o', 'none'
        ) | Out-Null
        $restarted = $true

        $aliveUrl = "https://$SiteName.azurewebsites.net/api/v1/alive"
        $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
        do {
            try {
                $resp = Invoke-RestMethod -Uri $aliveUrl -Headers @{ 'ngrok-skip-browser-warning' = 'true' } -Method Get -TimeoutSec 10 -ErrorAction Stop
                if ($resp.loading -eq $false -and $resp.hasError -eq $false) {
                    $appReady = $true
                    break
                }
            }
            catch {
                # transient — keep polling until deadline
            }
            if ((Get-Date) -lt $deadline) {
                Start-Sleep -Seconds $PollIntervalSeconds
            }
        } while ((Get-Date) -lt $deadline)

        if (-not $appReady) {
            throw "PSU /api/v1/alive did not report ready within $TimeoutSeconds seconds after restart."
        }
    }

    [pscustomobject]@{
        PrincipalId             = $principalId
        ResourceGroup           = $ResourceGroup
        SiteName                = $SiteName
        Url                     = "https://$SiteName.azurewebsites.net"
        SubscriptionsGranted    = $subscriptionsGranted.ToArray()
        GraphPermissionsGranted = $graphGranted.ToArray()
        Restarted               = $restarted
        AppReady                = $appReady
    }
}
