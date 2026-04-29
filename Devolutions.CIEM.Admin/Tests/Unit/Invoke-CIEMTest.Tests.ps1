BeforeAll {
    $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '../..')
    $manifest = Join-Path $moduleRoot 'Devolutions.CIEM.Admin.psd1'

    Remove-Module Devolutions.CIEM.Admin -Force -ErrorAction SilentlyContinue
    Import-Module $manifest
}

Describe 'Invoke-CIEMTest' {
    Context 'Suite surface' {
        BeforeAll {
            $script:command = Get-Command Invoke-CIEMTest
            $script:scriptSource = Get-Content (Join-Path $moduleRoot '../scripts/invoke-ciem-tests.ps1') -Raw
        }

        It 'exposes only Unit, E2E, and Playwright suites' {
            $suiteAttribute = $script:command.Parameters['Suite'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }

            $suiteAttribute.ValidValues | Should -Be @('Unit', 'E2E', 'Playwright')
        }

        It 'keeps the script wrapper suite list aligned with Invoke-CIEMTest' {
            $script:scriptSource | Should -Match "\[ValidateSet\('Unit', 'E2E', 'Playwright'\)\]"
        }
    }

    Context 'Pester suite invocation' {
        BeforeAll {
            $script:testPath = Join-Path $TestDrive 'Unit'
            New-Item -Path $script:testPath -ItemType Directory | Out-Null

            Set-Content -Path (Join-Path $script:testPath 'Environment.Tests.ps1') -Value @'
Describe 'Nested environment test' {
    It 'receives the selected CIEM test environment' {
        $env:CIEM_TEST_ENVIRONMENT | Should -Be 'azure'
    }
}
'@

            $script:result = Invoke-CIEMTest -Suite E2E -Environment azure -Path $script:testPath -Output Normal
        }

        It 'returns a structured Pester result' {
            $script:result.Suite | Should -Be 'E2E'
            $script:result.Environment | Should -Be 'azure'
            $script:result.Framework | Should -Be 'Pester'
            $script:result.PassedCount | Should -Be 1
        }
    }

    Context 'Pester failures' {
        BeforeAll {
            $script:failedPath = Join-Path $TestDrive 'FailedUnit'
            New-Item -Path $script:failedPath -ItemType Directory | Out-Null

            Set-Content -Path (Join-Path $script:failedPath 'Failure.Tests.ps1') -Value @'
Describe 'Nested failure test' {
    It 'fails deliberately so the runner throws' {
        'actual' | Should -Be 'expected'
    }
}
'@
        }

        It 'throws when Pester reports failed tests' {
            { Invoke-CIEMTest -Suite Unit -Path $script:failedPath -Output Normal } |
                Should -Throw -ExpectedMessage "*Pester suite 'Unit' failed*"
        }
    }

    Context 'E2E command routing' {
        BeforeAll {
            $script:invokeSource = Get-Content (Join-Path $moduleRoot 'Public/Invoke-CIEMTest.ps1') -Raw
            $script:e2eCommandSource = Get-Content (Join-Path $moduleRoot 'Private/Invoke-CIEME2ECommand.ps1') -Raw
        }

        It 'passes the selected environment to Invoke-TestCommand' {
            $script:e2eCommandSource | Should -Match 'Invoke-TestCommand[\s\S]+-Environment \$Environment'
        }

        It 'reports runtime command results as E2E results' {
            $script:e2eCommandSource | Should -Match "Suite\s+=\s+'E2E'"
        }

        It 'converts -Command strings into E2E scriptblocks for CLI callers' {
            $script:invokeSource | Should -Match '\[scriptblock\]::Create\(\$Command\)'
        }

        It 'rejects simultaneous -ScriptBlock and -Command values' {
            $script:invokeSource | Should -Match 'Specify only one of -ScriptBlock or -Command'
        }
    }

    Context 'Playwright suite targeting' {
        BeforeAll {
            $script:playwrightSource = Get-Content (Join-Path $moduleRoot 'Private/Invoke-CIEMPlaywrightSuite.ps1') -Raw
            $script:playwrightPackage = Get-Content (Join-Path $moduleRoot '../psu-app/ui/e2e/package.json') -Raw |
                ConvertFrom-Json
        }

        It 'allows Playwright to target the selected environment' {
            $script:playwrightSource | Should -Match '\$env:CIEM_TEST_ENVIRONMENT = \$Environment'
        }

        It 'does not reject Azure Playwright runs at the runner layer' {
            $script:playwrightSource | Should -Not -Match "\$Environment -eq 'azure'"
        }

        It 'runs the locally installed Playwright CLI through node instead of npx' {
            $script:playwrightSource | Should -Match 'node_modules/@playwright/test/cli\.js'
            $script:playwrightSource | Should -Match '& node @playwrightArgs'
            $script:playwrightSource | Should -Not -Match '& npx'
        }

        It 'removes NO_COLOR before invoking Playwright and restores it afterward' {
            $script:playwrightSource | Should -Match 'Remove-Item Env:NO_COLOR'
            $script:playwrightSource | Should -Match '\$env:NO_COLOR = \$previousNoColor'
        }

        It 'keeps Playwright package scripts on the local CLI path' {
            $scriptValues = $script:playwrightPackage.scripts.PSObject.Properties.Value -join "`n"

            $scriptValues | Should -Match 'node ./node_modules/@playwright/test/cli\.js'
            $scriptValues | Should -Not -Match '\bnpx\b'
        }
    }
}
