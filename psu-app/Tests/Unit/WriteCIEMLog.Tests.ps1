BeforeAll {
    $script:LogFunctionContent = Get-Content (Join-Path $PSScriptRoot '..' '..' 'Public' 'Write-CIEMLog.ps1') -Raw
    $script:ModuleContent = Get-Content (Join-Path $PSScriptRoot '..' '..' 'Devolutions.CIEM.psm1') -Raw
}

Describe 'Write-CIEMLog PSU logging integration' {
    It 'routes runtime logging through Write-PSULog when the PSU cmdlet is available' {
        $script:LogFunctionContent | Should -Match 'Get-Command\s+Write-PSULog'
        $script:LogFunctionContent | Should -Match "Write-PSULog\s+-Feature\s+'CIEM'"
        $script:LogFunctionContent | Should -Match '-Resource\s+\$Component'
        $script:LogFunctionContent | Should -Match '-Level\s+\$psuLevel'
    }

    It 'keeps file logging for non-PSU bootstrap/runtime contexts' {
        $script:LogFunctionContent | Should -Match 'Add-Content\s+-Path\s+\$logPath'
        $script:ModuleContent | Should -Match 'function\s+_BootLog'
        $script:ModuleContent | Should -Match 'Add-Content\s+-Path\s+\$script:_BootLogPath'
    }
}
