Describe 'Azure PSU diagnostics' {
    BeforeAll {
        $script:DiagnosticsScriptPath = Join-Path $PSScriptRoot '..' '..' '..' 'scripts' 'azure-psu-diagnostics.ps1'
        $script:DiagnosticsScript = Get-Content -Path $script:DiagnosticsScriptPath -Raw
    }

    It 'filters CIEM app registration locally after retrieving all PSU apps' {
        $script:DiagnosticsScript | Should -Not -Match "Get-PSUApp\s+-Name\s+'\*CIEM\*'"
        $script:DiagnosticsScript | Should -Match 'Get-PSUApp\)'
        $script:DiagnosticsScript | Should -Match "Name\s+-eq\s+'Devolutions CIEM'"
    }
}
