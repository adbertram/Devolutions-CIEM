BeforeAll {
    $repoRoot = Join-Path $PSScriptRoot '..' '..' '..' '..'
    $moduleManifest = Join-Path $repoRoot 'Devolutions.CIEM.psd1'
    Remove-Module Devolutions.CIEM -ErrorAction SilentlyContinue
    Import-Module $moduleManifest

    $script:RegistryPath = Join-Path $PSScriptRoot '..' '..' 'Data' 'pages.json'
    $script:RegistryPages = @(Get-Content -Path $script:RegistryPath -Raw | ConvertFrom-Json -Depth 10)
    $script:AppFactoryContent = Get-Content -Path (Join-Path $PSScriptRoot '..' '..' 'Public' 'New-DevolutionsCIEMApp.ps1') -Raw
    $script:NavigationContent = Get-Content -Path (Join-Path $PSScriptRoot '..' '..' 'Pages' 'New-CIEMNavigation.ps1') -Raw
}

Describe 'CIEM PSU page registry' {
    It 'Defines strict page metadata for every app page' {
        $script:RegistryPath | Should -Exist
        $script:RegistryPages | Should -HaveCount 10

        foreach ($page in $script:RegistryPages) {
            $page.PSObject.Properties.Name | Sort-Object | Should -Be @('factory', 'icon', 'name', 'order', 'route', 'subtitle', 'test', 'title')
            [string]$page.name | Should -Not -BeNullOrEmpty
            [string]$page.route | Should -Match '^/($|[^/].*)'
            [string]$page.title | Should -Not -BeNullOrEmpty
            [string]$page.subtitle | Should -Not -BeNullOrEmpty
            [string]$page.icon | Should -Not -BeNullOrEmpty
            [string]$page.factory | Should -Match '^New-CIEM.+Page$'
            [int]$page.order | Should -BeGreaterThan 0
            $page.test.PSObject.Properties.Name | Sort-Object | Should -Be @('expectedColumns', 'smokeSelector')
            [string]$page.test.smokeSelector | Should -Not -BeNullOrEmpty
        }
    }

    It 'Has unique names, routes, factories, and orders' {
        @($script:RegistryPages.name | Sort-Object -Unique) | Should -HaveCount $script:RegistryPages.Count
        @($script:RegistryPages.route | Sort-Object -Unique) | Should -HaveCount $script:RegistryPages.Count
        @($script:RegistryPages.factory | Sort-Object -Unique) | Should -HaveCount $script:RegistryPages.Count
        @($script:RegistryPages.order | Sort-Object -Unique) | Should -HaveCount $script:RegistryPages.Count
    }

    It 'Returns pages sorted by registry order' {
        $orderedPages = InModuleScope Devolutions.CIEM { GetCIEMPSUPageRegistry }
        @($orderedPages.name) | Should -Be @($script:RegistryPages | Sort-Object order | Select-Object -ExpandProperty name)
    }

    It 'Resolves every page factory declared by the registry' {
        foreach ($page in $script:RegistryPages) {
            Get-Command -Name ([string]$page.factory) -Module Devolutions.CIEM -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
    }

    It 'Builds app pages from the registry instead of a hardcoded page list' {
        $script:AppFactoryContent | Should -Match 'GetCIEMPSUPageRegistry'
        $script:AppFactoryContent | Should -Match '\& \(\[string\]\$page\.factory\)'
        $script:AppFactoryContent | Should -Not -Match 'New-CIEMDashboardPage\s+-Navigation\s+\$Navigation'
    }

    It 'Builds sidebar navigation from the registry' {
        $script:NavigationContent | Should -Match 'GetCIEMPSUPageRegistry'
        $script:NavigationContent | Should -Match 'GetCIEMPSUPageHref'
        $script:NavigationContent | Should -Not -Match "New-UDListItem\s+-Label 'Dashboard'"
    }

    It 'Maps registry routes to CIEM app hrefs' {
        $hrefs = InModuleScope Devolutions.CIEM {
            GetCIEMPSUPageRegistry | ForEach-Object {
                [pscustomobject]@{
                    Name = $_.name
                    Href = GetCIEMPSUPageHref -Page $_
                }
            }
        }

        ($hrefs | Where-Object Name -eq 'Dashboard').Href | Should -Be '/ciem'
        ($hrefs | Where-Object Name -eq 'Scan').Href | Should -Be '/ciem/scan'
        ($hrefs | Where-Object Name -eq 'Reports').Href | Should -Be '/ciem/reports'
    }
}
