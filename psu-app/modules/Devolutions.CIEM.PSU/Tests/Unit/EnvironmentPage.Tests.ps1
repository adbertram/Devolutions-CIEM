BeforeAll {
    $script:PageContent = Get-Content (Join-Path $PSScriptRoot '..' '..' 'Pages' 'New-CIEMEnvironmentPage.ps1') -Raw
    $script:IconResolverContent = Get-Content (Join-Path $PSScriptRoot '..' '..' 'Public' 'Resolve-CIEMResourceIconDataUri.ps1') -Raw
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
