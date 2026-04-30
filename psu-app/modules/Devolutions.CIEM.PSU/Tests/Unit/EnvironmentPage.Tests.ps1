BeforeAll {
    $script:PageContent = Get-Content (Join-Path $PSScriptRoot '..' '..' 'Pages' 'New-CIEMEnvironmentPage.ps1') -Raw
    $script:IconResolverContent = Get-Content (Join-Path $PSScriptRoot '..' '..' 'Public' 'Resolve-CIEMResourceIconDataUri.ps1') -Raw
    $treeHelperPath = Join-Path $PSScriptRoot '..' '..' 'Public' 'New-CIEMEnvironmentTree.ps1'
    $script:TreeHelperContent = if (Test-Path $treeHelperPath) { Get-Content $treeHelperPath -Raw } else { '' }
    $assetHelperPath = Join-Path $PSScriptRoot '..' '..' 'Private' 'RegisterCIEMEnvironmentTreeAsset.ps1'
    $script:AssetHelperContent = if (Test-Path $assetHelperPath) { Get-Content $assetHelperPath -Raw } else { '' }
    $script:ModuleContent = Get-Content (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psm1') -Raw
}

Describe 'Environment page discovery cancellation' {
    It 'targets only the CIEM discovery PSU script when cancelling running jobs' {
        $script:PageContent | Should -Not -Match '\*Discovery\*'
        $script:PageContent | Should -Match "'Checks/Start-CIEMAzureDiscovery'"
    }

    It 'keeps the public icon resolver self-contained for PSU page runspaces' {
        $script:IconResolverContent | Should -Not -Match '(?m)^\s*function\s+Get-CIEMResourceIcon'
        $script:IconResolverContent | Should -Not -Match '(?m)(?<!\$)(?<![A-Za-z])Get-CIEMResourceIcon(?:Manifest|MapValue|DataUri)\b'
    }
}

Describe 'Environment page ECharts custom component' {
    It 'renders the tree through the PSU custom component helper' {
        $script:PageContent | Should -Match 'New-CIEMEnvironmentTree'
        $script:PageContent | Should -Not -Match 'cdn\.jsdelivr'
        $script:PageContent | Should -Not -Match 'New-UDHelmet'
        $script:PageContent | Should -Not -Match 'Invoke-UDJavaScript'
        $script:PageContent | Should -Not -Match 'New-UDHtml'
    }

    It 'exposes the fixed custom component helper parameters' {
        $script:TreeHelperContent | Should -Match 'function\s+New-CIEMEnvironmentTree'
        foreach ($parameter in @('Id', 'Data', 'Orientation', 'Height')) {
            $script:TreeHelperContent | Should -Match "\`$$parameter"
        }
        $script:TreeHelperContent | Should -Match 'RegisterCIEMEnvironmentTreeAsset'
        $script:TreeHelperContent | Should -Match "isPlugin\s*=\s*\`$true"
    }

    It 'registers the component asset from the component helper only' {
        $script:AssetHelperContent | Should -Match 'RegisterAsset'
        $script:AssetHelperContent | Should -Match 'Components/EnvironmentTree/dist'
        $script:AssetHelperContent | Should -Match 'Get-FileHash'
        $script:AssetHelperContent | Should -Match 'ciem-environment-tree-\$hash\.bundle\.js'
        $script:ModuleContent | Should -Not -Match 'RegisterCIEMEnvironmentTreeAsset'
    }
}
