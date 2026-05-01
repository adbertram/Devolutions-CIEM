BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')

    $script:ModuleRoot = Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' '..')
    $script:AWSChecksRoot = Join-Path $script:ModuleRoot 'modules' 'AWS' 'Checks'
    $script:ExpectedAWSScripts = @(
        'Test-IamNoRootAccessKey.ps1',
        'Test-IamPasswordPolicyLowercase.ps1',
        'Test-IamRootMfaEnabled.ps1',
        'Test-IamUserMfaEnabledConsoleAccess.ps1'
    ) | Sort-Object
    $script:ExpectedAWSCheckIds = @(
        'iam_no_root_access_key',
        'iam_password_policy_lowercase',
        'iam_root_mfa_enabled',
        'iam_user_mfa_enabled_console_access'
    ) | Sort-Object
}

Describe 'AWS check inventory' {
    It 'Contains only implemented AWS check scripts' {
        $scriptNames = @(
            Get-ChildItem -LiteralPath $script:AWSChecksRoot -Filter '*.ps1' -File |
                Select-Object -ExpandProperty Name |
                Sort-Object
        )

        Compare-Object -ReferenceObject $script:ExpectedAWSScripts -DifferenceObject $scriptNames | Should -BeNullOrEmpty
    }

    It 'Does not keep generated manual placeholder scripts' {
        $placeholderFiles = @(
            Get-ChildItem -LiteralPath $script:AWSChecksRoot -Filter '*.ps1' -File |
                Where-Object {
                    (Get-Content -LiteralPath $_.FullName -Raw) -match 'This check requires manual implementation|TODO: Implement check logic from generated source'
                }
        )

        $placeholderFiles | Should -BeNullOrEmpty
    }
}

Describe 'AWS check catalog' {
    BeforeEach {
        $script:TestDatabasePath = Join-Path $TestDrive ("ciem-" + [guid]::NewGuid().ToString('N') + '.db')
        $env:CIEM_TEST_DB_PATH = $script:TestDatabasePath
        New-CIEMDatabase -Path $script:TestDatabasePath

        InModuleScope Devolutions.CIEM {
            $script:DatabasePath = $env:CIEM_TEST_DB_PATH
        }

        Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}
    }

    It 'Catalogs only implemented AWS check rows' {
        InModuleScope Devolutions.CIEM {
            SyncCIEMCheckCatalog -Provider AWS
        }

        $checks = @(Get-CIEMCheck -Provider AWS)
        $checkIds = @($checks.Id | Sort-Object)
        $checkScripts = @($checks.CheckScript | Sort-Object)

        Compare-Object -ReferenceObject $script:ExpectedAWSCheckIds -DifferenceObject $checkIds | Should -BeNullOrEmpty
        Compare-Object -ReferenceObject $script:ExpectedAWSScripts -DifferenceObject $checkScripts | Should -BeNullOrEmpty
        @($checks | Where-Object { -not $_.Disabled }) | Should -BeNullOrEmpty
    }

    It 'Derives AWS IAM permissions from the AWS catalog rows' {
        InModuleScope Devolutions.CIEM {
            SyncCIEMCheckCatalog -Provider AWS
        }

        $permissions = Get-CIEMRequiredPermission -Provider AWS

        $permissions.CheckCount | Should -Be 4
        $permissions.IAM | Should -Be @(
            'iam:GenerateCredentialReport',
            'iam:GetAccountPasswordPolicy',
            'iam:GetCredentialReport'
        )
        $permissions.Summary | Should -Match 'AWS IAM Actions'
    }
}
