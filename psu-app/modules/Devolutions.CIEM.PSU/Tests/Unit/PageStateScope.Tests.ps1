BeforeAll {
    $script:PagesRoot = Join-Path $PSScriptRoot '..' '..' 'Pages'
    $script:PageFiles = @{}
    foreach ($fileName in @(
        'New-CIEMConfigPage.ps1',
        'New-CIEMAuthenticationProfilesPage.ps1',
        'New-CIEMScanPage.ps1',
        'New-CIEMDashboardPage.ps1',
        'New-CIEMIdentitiesPage.ps1',
        'New-CIEMEnvironmentPage.ps1',
        'New-CIEMAttackPathsPage.ps1'
    )) {
        $script:PageFiles[$fileName] = Get-Content (Join-Path $script:PagesRoot $fileName) -Raw
    }
}

Describe 'PSU page-local UI state' {
    $stateExpectations = @(
        @{
            File = 'New-CIEMAuthenticationProfilesPage.ps1'
            Variables = @('SelectedAuthenticationProfileId', 'UploadedAuthProfileSecretFiles')
        }
        @{
            File = 'New-CIEMScanPage.ps1'
            Variables = @('SelectedCheckIds', 'CheckStatusFilter', 'CIEMScanResults', 'CIEMScanTimestamp', 'CIEMIncludePassed')
        }
        @{
            File = 'New-CIEMDashboardPage.ps1'
            Variables = @('SelectedScanRunId')
        }
        @{
            File = 'New-CIEMIdentitiesPage.ps1'
            Variables = @('IdentitiesProvider', 'IdentitiesAccessLevel', 'IdentitiesPrivilege')
        }
        @{
            File = 'New-CIEMEnvironmentPage.ps1'
            Variables = @('SelectedEnvProvider', 'SelectedEnvView', 'SelectedEnvOrient', 'SelectedEnvAssignmentMode')
        }
        @{
            File = 'New-CIEMAttackPathsPage.ps1'
            Variables = @('CIEMAttackPathExecution')
        }
    )

    foreach ($expectation in $stateExpectations) {
        It "uses Page scope for UI-only state in $($expectation.File)" -TestCases @($expectation) {
            param(
                [string]$File,
                [string[]]$Variables
            )

            $content = $script:PageFiles[$File]
            foreach ($variable in $Variables) {
                $content | Should -Match ([regex]::Escape('$Page:' + $variable))
                $content | Should -Not -Match ([regex]::Escape('$Session:' + $variable))
            }
        }
    }
}
