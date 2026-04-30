BeforeAll {
    $script:PublicRoot = Join-Path $PSScriptRoot '..' '..' 'Public'
    $script:PrivateRoot = Join-Path $PSScriptRoot '..' '..' 'Private'
    $script:ManifestPath = Join-Path $PSScriptRoot '..' '..' 'Devolutions.CIEM.Admin.psd1'
}

Describe 'PSU native app and configuration cmdlets' {
    $removedWrapperFiles = @(
        'Get-PSUApp.ps1',
        'Start-PSUApp.ps1',
        'Stop-PSUApp.ps1',
        'Restart-PSUApp.ps1',
        'Sync-PSUConfiguration.ps1'
    )

    foreach ($fileName in $removedWrapperFiles) {
        It "$fileName is not implemented as a Devolutions.CIEM.Admin wrapper" -TestCases @(@{ FileName = $fileName }) {
            param([string]$FileName)

            Join-Path $script:PublicRoot $FileName | Should -Not -Exist
        }
    }

    It 'does not keep a private native command resolver helper' {
        Join-Path $script:PrivateRoot 'GetPSUNativeCommand.ps1' | Should -Not -Exist
    }

    It 'does not export PSU native app and configuration wrapper names' {
        $manifest = Import-PowerShellDataFile -Path $script:ManifestPath

        foreach ($commandName in @('Get-PSUApp', 'Start-PSUApp', 'Stop-PSUApp', 'Restart-PSUApp', 'Sync-PSUConfiguration')) {
            $manifest.FunctionsToExport | Should -Not -Contain $commandName
        }
    }
}
