BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
}

Describe 'Severity catalog module state' {

    It 'Loads $script:SeverityByName with all 5 entries' {
        InModuleScope Devolutions.CIEM {
            $script:SeverityByName | Should -Not -BeNullOrEmpty
            $script:SeverityByName.Keys | Should -HaveCount 5
            $script:SeverityByName.Keys | Should -Contain 'critical'
            $script:SeverityByName.Keys | Should -Contain 'high'
            $script:SeverityByName.Keys | Should -Contain 'medium'
            $script:SeverityByName.Keys | Should -Contain 'low'
            $script:SeverityByName.Keys | Should -Contain 'info'
        }
    }

    It 'Each catalog entry has name, rank, color, label properties' {
        InModuleScope Devolutions.CIEM {
            foreach ($key in $script:SeverityByName.Keys) {
                $entry = $script:SeverityByName[$key]
                $entry.name  | Should -Not -BeNullOrEmpty
                $entry.rank  | Should -Not -BeNullOrEmpty
                $entry.color | Should -Match '^#[0-9a-fA-F]{6}$'
                $entry.label | Should -Not -BeNullOrEmpty
            }
        }
    }

    It 'Ranks are 1..5 in expected order (critical=1, info=5)' {
        InModuleScope Devolutions.CIEM {
            [int]$script:SeverityByName['critical'].rank | Should -Be 1
            [int]$script:SeverityByName['high'].rank     | Should -Be 2
            [int]$script:SeverityByName['medium'].rank   | Should -Be 3
            [int]$script:SeverityByName['low'].rank      | Should -Be 4
            [int]$script:SeverityByName['info'].rank     | Should -Be 5
        }
    }
}

Describe 'Get-SeverityColor (catalog-backed)' {

    It 'Returns purple (#9c27b0) for critical (lowercase)' {
        Get-SeverityColor -Severity 'critical' | Should -Be '#9c27b0'
    }

    It 'Returns red (#f44336) for high (lowercase)' {
        Get-SeverityColor -Severity 'high' | Should -Be '#f44336'
    }

    It 'Returns orange (#ff9800) for medium' {
        Get-SeverityColor -Severity 'medium' | Should -Be '#ff9800'
    }

    It 'Returns green (#4caf50) for low' {
        Get-SeverityColor -Severity 'low' | Should -Be '#4caf50'
    }

    It 'Returns blue (#2196f3) for info' {
        Get-SeverityColor -Severity 'info' | Should -Be '#2196f3'
    }

    It 'Is case-insensitive (uppercase CRITICAL returns critical color)' {
        Get-SeverityColor -Severity 'CRITICAL' | Should -Be '#9c27b0'
    }

    It 'Is case-insensitive (mixed-case High returns high color)' {
        Get-SeverityColor -Severity 'High' | Should -Be '#f44336'
    }

    It 'Throws for unknown severity' {
        { Get-SeverityColor -Severity 'bogus' } | Should -Throw "*Unknown severity 'bogus'*"
    }
}

Describe 'Get-StatusColor (catalog-backed)' {

    It 'Returns red (#f44336) for FAIL' {
        Get-StatusColor -Status 'FAIL' | Should -Be '#f44336'
    }

    It 'Returns green (#4caf50) for PASS' {
        Get-StatusColor -Status 'PASS' | Should -Be '#4caf50'
    }

    It 'Returns orange (#ff9800) for MANUAL' {
        Get-StatusColor -Status 'MANUAL' | Should -Be '#ff9800'
    }

    It 'Returns gray (#9e9e9e) for SKIPPED' {
        Get-StatusColor -Status 'SKIPPED' | Should -Be '#9e9e9e'
    }

    It 'Returns red (#f44336) for ERROR' {
        Get-StatusColor -Status 'ERROR' | Should -Be '#f44336'
    }

    It 'Is case-insensitive (lowercase fail returns FAIL color)' {
        Get-StatusColor -Status 'fail' | Should -Be '#f44336'
    }

    It 'Throws for unknown status' {
        { Get-StatusColor -Status 'bogus' } | Should -Throw "*Unknown status 'bogus'*"
    }
}

Describe 'Get-CIEMSeverityRank' {

    It 'Is available as a public command' {
        Get-Command -Module Devolutions.CIEM -Name Get-CIEMSeverityRank -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }

    It 'Returns 1 for critical' {
        Get-CIEMSeverityRank -Severity 'critical' | Should -Be 1
    }

    It 'Returns 2 for high' {
        Get-CIEMSeverityRank -Severity 'high' | Should -Be 2
    }

    It 'Returns 3 for medium' {
        Get-CIEMSeverityRank -Severity 'medium' | Should -Be 3
    }

    It 'Returns 4 for low' {
        Get-CIEMSeverityRank -Severity 'low' | Should -Be 4
    }

    It 'Returns 5 for info' {
        Get-CIEMSeverityRank -Severity 'info' | Should -Be 5
    }

    It 'Is case-insensitive (uppercase CRITICAL returns 1)' {
        Get-CIEMSeverityRank -Severity 'CRITICAL' | Should -Be 1
    }

    It 'Returns 999 (sorts last) for unknown severity' {
        Get-CIEMSeverityRank -Severity 'bogus' | Should -Be 999
    }

    It 'Returns an [int] type (not string) so Sort-Object works numerically' {
        Get-CIEMSeverityRank -Severity 'critical' | Should -BeOfType [int]
    }

    It 'Sorting by rank produces critical-first order' {
        $severities = @('low', 'critical', 'high', 'medium', 'info')
        $sorted = $severities | Sort-Object @{ Expression = { Get-CIEMSeverityRank -Severity $_ } }
        $sorted | Should -Be @('critical', 'high', 'medium', 'low', 'info')
    }
}
