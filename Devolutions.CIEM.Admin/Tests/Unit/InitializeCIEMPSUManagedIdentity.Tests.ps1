BeforeAll {
    $script:ModuleRoot = Resolve-Path (Join-Path $PSScriptRoot '../..')
    $script:Manifest = Join-Path $script:ModuleRoot 'Devolutions.CIEM.Admin.psd1'

    Remove-Module Devolutions.CIEM.Admin -Force -ErrorAction SilentlyContinue
    Import-Module $script:Manifest

    $script:DefaultGraphPermissions = @(
        'Directory.Read.All'
        'Policy.Read.All'
        'RoleManagement.Read.Directory'
        'User.Read.All'
        'UserAuthenticationMethod.Read.All'
    )

    $script:GraphAppRoleMap = @{
        'Directory.Read.All'              = '7ab1d382-f21e-4acd-a863-ba3e13f7da61'
        'Policy.Read.All'                 = '246dd0d5-5bd0-4def-940b-0421030a5b68'
        'RoleManagement.Read.Directory'   = '483bed4a-2ad3-4361-a73b-c83ccdbdc53c'
        'User.Read.All'                   = 'df021288-bdef-4463-88db-98f22de89214'
        'UserAuthenticationMethod.Read.All' = '38d9df27-64da-44fd-b7c5-a6fbac20248f'
    }

    $script:GraphSpId = '00000000-0000-0000-0000-aaaaaaaaaaaa'
    $script:PrincipalId = '00000000-0000-0000-0000-bbbbbbbbbbbb'
    $script:DefaultSubscriptionId = '11111111-1111-1111-1111-111111111111'
}

AfterAll {
    Remove-Module Devolutions.CIEM.Admin -Force -ErrorAction SilentlyContinue
}

Describe 'Initialize-CIEMPSUManagedIdentity' {
    BeforeEach {
        $script:azCalls = [System.Collections.Generic.List[object]]::new()
        $script:restCalls = [System.Collections.Generic.List[string]]::new()
        $script:sleepCalls = 0
        $script:azFailureAt = ''

        Mock -ModuleName Devolutions.CIEM.Admin az {
            $script:azCalls.Add(@($args))
            $commandText = @($args) -join ' '
            if ($script:azFailureAt -and $commandText -match "^$([regex]::Escape($script:azFailureAt))") {
                $global:LASTEXITCODE = 13
                return 'mock az failure'
            }
            $global:LASTEXITCODE = 0
            switch -Regex ($commandText) {
                '^webapp identity assign' {
                    return (@{ principalId = $script:PrincipalId; type = 'SystemAssigned' } | ConvertTo-Json -Compress)
                }
                '^account show.*--query id' {
                    return $script:DefaultSubscriptionId
                }
                '^role assignment create' {
                    return (@{ id = "ra-$([guid]::NewGuid())"; principalId = $script:PrincipalId } | ConvertTo-Json -Compress)
                }
                "appId eq '00000003-0000-0000-c000-000000000000'" {
                    $appRoles = $script:GraphAppRoleMap.GetEnumerator() | ForEach-Object {
                        @{ id = $_.Value; value = $_.Key }
                    }
                    return (@{ value = @(@{ id = $script:GraphSpId; appRoles = @($appRoles) }) } | ConvertTo-Json -Depth 10 -Compress)
                }
                '/appRoleAssignments' {
                    return (@{ id = "ar-$([guid]::NewGuid())" } | ConvertTo-Json -Compress)
                }
                '^webapp restart' {
                    return $null
                }
                default { return $null }
            }
        }

        Mock -ModuleName Devolutions.CIEM.Admin Invoke-RestMethod {
            $script:restCalls.Add($Uri)
            [pscustomobject]@{ loading = $false; hasError = $false; loadingInfo = '' }
        }
        Mock -ModuleName Devolutions.CIEM.Admin Start-Sleep { $script:sleepCalls++ }
    }

    It 'enables system-assigned identity, grants Reader on the current subscription, and grants the default Graph permissions' {
        $result = Initialize-CIEMPSUManagedIdentity `
            -ResourceGroup 'devolutions-ciem-rg' `
            -SiteName 'devolutions-ciem-psu'

        $result.PrincipalId | Should -Be $script:PrincipalId
        $result.SiteName | Should -Be 'devolutions-ciem-psu'
        $result.ResourceGroup | Should -Be 'devolutions-ciem-rg'
        $result.SubscriptionsGranted | Should -Contain $script:DefaultSubscriptionId
        $result.GraphPermissionsGranted | Should -Be $script:DefaultGraphPermissions

        @($script:azCalls | Where-Object { (@($_) -join ' ') -match '^webapp identity assign' }).Count | Should -Be 1
        @($script:azCalls | Where-Object { (@($_) -join ' ') -match '^account show' }).Count | Should -Be 1
        $roleCalls = @($script:azCalls | Where-Object { (@($_) -join ' ') -match '^role assignment create' })
        $roleCalls.Count | Should -Be 1
        ($roleCalls[0] -join ' ') | Should -Match '--role Reader'
        ($roleCalls[0] -join ' ') | Should -Match "--assignee-object-id $script:PrincipalId"
        ($roleCalls[0] -join ' ') | Should -Match "--scope /subscriptions/$script:DefaultSubscriptionId"
        ($roleCalls[0] -join ' ') | Should -Match '--assignee-principal-type ServicePrincipal'

        $graphLookups = @($script:azCalls | Where-Object { (@($_) -join ' ') -match "appId eq '00000003-0000-0000-c000-000000000000'" })
        $graphLookups.Count | Should -Be 1

        $assignCalls = @($script:azCalls | Where-Object { (@($_) -join ' ') -match '/appRoleAssignments' })
        $assignCalls.Count | Should -Be $script:DefaultGraphPermissions.Count

        foreach ($perm in $script:DefaultGraphPermissions) {
            $expectedAppRoleId = $script:GraphAppRoleMap[$perm]
            $matched = $assignCalls | Where-Object { (@($_) -join ' ') -match [regex]::Escape($expectedAppRoleId) }
            $matched | Should -Not -BeNullOrEmpty -Because "an appRoleAssignment must be posted for $perm ($expectedAppRoleId)"
        }
    }

    It 'grants Reader on every supplied SubscriptionId' {
        $subs = @('22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333')
        $null = Initialize-CIEMPSUManagedIdentity `
            -ResourceGroup 'rg' `
            -SiteName 'site' `
            -SubscriptionId $subs

        @($script:azCalls | Where-Object { (@($_) -join ' ') -match '^account show' }).Count | Should -Be 0
        $roleCalls = @($script:azCalls | Where-Object { (@($_) -join ' ') -match '^role assignment create' })
        $roleCalls.Count | Should -Be 2
        foreach ($sub in $subs) {
            @($roleCalls | Where-Object { (@($_) -join ' ') -match "--scope /subscriptions/$sub" }).Count | Should -Be 1
        }
    }

    It 'grants only the requested Graph permissions when -GraphPermission is specified' {
        $result = Initialize-CIEMPSUManagedIdentity `
            -ResourceGroup 'rg' `
            -SiteName 'site' `
            -GraphPermission @('Directory.Read.All', 'Policy.Read.All')

        $result.GraphPermissionsGranted | Should -Be @('Directory.Read.All', 'Policy.Read.All')

        $assignCalls = @($script:azCalls | Where-Object { (@($_) -join ' ') -match '/appRoleAssignments' })
        $assignCalls.Count | Should -Be 2

        $unexpectedRoleId = $script:GraphAppRoleMap['User.Read.All']
        @($assignCalls | Where-Object { (@($_) -join ' ') -match [regex]::Escape($unexpectedRoleId) }).Count | Should -Be 0
    }

    It 'skips Graph permissions when -GraphPermission is an empty array' {
        $result = Initialize-CIEMPSUManagedIdentity `
            -ResourceGroup 'rg' `
            -SiteName 'site' `
            -GraphPermission @()

        $result.GraphPermissionsGranted | Should -BeNullOrEmpty

        @($script:azCalls | Where-Object { (@($_) -join ' ') -match "appId eq '00000003-0000-0000-c000-000000000000'" }).Count | Should -Be 0
        @($script:azCalls | Where-Object { (@($_) -join ' ') -match '/appRoleAssignments' }).Count | Should -Be 0
    }

    It 'restarts the web app and waits for the alive endpoint when -Restart is set' {
        $result = Initialize-CIEMPSUManagedIdentity `
            -ResourceGroup 'rg' `
            -SiteName 'devolutions-ciem-psu' `
            -GraphPermission @() `
            -Restart `
            -TimeoutSeconds 30 `
            -PollIntervalSeconds 1

        $result.Restarted | Should -BeTrue
        $result.AppReady | Should -BeTrue

        @($script:azCalls | Where-Object { (@($_) -join ' ') -match '^webapp restart' }).Count | Should -Be 1
        $script:restCalls | Should -Contain 'https://devolutions-ciem-psu.azurewebsites.net/api/v1/alive'
    }

    It 'does not restart the web app when -Restart is not specified' {
        $result = Initialize-CIEMPSUManagedIdentity `
            -ResourceGroup 'rg' `
            -SiteName 'site' `
            -GraphPermission @()

        $result.Restarted | Should -BeFalse
        @($script:azCalls | Where-Object { (@($_) -join ' ') -match '^webapp restart' }).Count | Should -Be 0
        $script:restCalls.Count | Should -Be 0
    }

    It 'is idempotent for Graph permissions: ignores 400 "already exists" errors and continues' {
        Mock -ModuleName Devolutions.CIEM.Admin az {
            $script:azCalls.Add(@($args))
            $commandText = @($args) -join ' '
            $global:LASTEXITCODE = 0
            switch -Regex ($commandText) {
                '^webapp identity assign' {
                    return (@{ principalId = $script:PrincipalId } | ConvertTo-Json -Compress)
                }
                '^account show.*--query id' { return $script:DefaultSubscriptionId }
                '^role assignment create' { return (@{ id = 'ra-1' } | ConvertTo-Json -Compress) }
                "appId eq '00000003-0000-0000-c000-000000000000'" {
                    $appRoles = $script:GraphAppRoleMap.GetEnumerator() | ForEach-Object {
                        @{ id = $_.Value; value = $_.Key }
                    }
                    return (@{ value = @(@{ id = $script:GraphSpId; appRoles = @($appRoles) }) } | ConvertTo-Json -Depth 10 -Compress)
                }
                '/appRoleAssignments' {
                    $global:LASTEXITCODE = 1
                    return 'Permission being assigned already exists on the object'
                }
                default { return $null }
            }
        }

        $result = $null
        $threw = $null
        try {
            $result = Initialize-CIEMPSUManagedIdentity -ResourceGroup 'rg' -SiteName 'site' -GraphPermission @('Directory.Read.All')
        }
        catch {
            $threw = $_
        }

        $threw | Should -BeNullOrEmpty
        $result.GraphPermissionsGranted | Should -Be @('Directory.Read.All')
    }

    It 'throws if az webapp identity assign fails' {
        $script:azFailureAt = 'webapp identity assign'

        $err = $null
        try {
            Initialize-CIEMPSUManagedIdentity -ResourceGroup 'rg' -SiteName 'site' -GraphPermission @()
        }
        catch {
            $err = $_
        }

        $err | Should -Not -BeNullOrEmpty
        $err.Exception.Message | Should -Match 'az webapp identity failed'
    }
}

Describe 'Initialize-CIEMPSUManagedIdentity export' {
    It 'is exported by the Admin module manifest' {
        $manifestData = Import-PowerShellDataFile -Path $script:Manifest
        $manifestData.FunctionsToExport | Should -Contain 'Initialize-CIEMPSUManagedIdentity'
        Get-Command -Module Devolutions.CIEM.Admin -Name 'Initialize-CIEMPSUManagedIdentity' | Should -Not -BeNullOrEmpty
    }
}
