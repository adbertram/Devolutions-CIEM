BeforeAll {
    $moduleRoot = Resolve-Path (Join-Path $PSScriptRoot '../..')
    $manifest = Join-Path $moduleRoot 'Devolutions.CIEM.Admin.psd1'

    Remove-Module Devolutions.CIEM.Admin -Force -ErrorAction SilentlyContinue
    Import-Module $manifest
}

Describe 'Invoke-TestCommand' {
    Context 'remote CIEM module availability' {
        BeforeEach {
            $script:capturedScriptBlock = $null
            $script:connectEnvFilePaths = [System.Collections.Generic.List[string]]::new()
            $script:connectAzureFlags = [System.Collections.Generic.List[bool]]::new()

            Mock -ModuleName Devolutions.CIEM.Admin Connect-PSU {
                $script:connectEnvFilePaths.Add([string]$EnvFilePath)
                $script:connectAzureFlags.Add([bool]$Azure)
            }
            Mock -ModuleName Devolutions.CIEM.Admin Invoke-CIEMCommand {
                $script:capturedScriptBlock = $ScriptBlock
                [PSCustomObject]@{ Status = 'Completed' }
            }
        }

        It 'imports the CIEM module only when the remote runspace has not loaded it' {
            Invoke-TestCommand -Environment azure -ScriptBlock { Get-CIEMProvider } | Out-Null

            $script:capturedScriptBlock | Should -Not -BeNullOrEmpty
            $script:capturedScriptBlock.ToString() | Should -Match 'if \(-not \(Get-Module -Name Devolutions\.CIEM\)\)'
            $script:capturedScriptBlock.ToString() | Should -Match 'Import-Module Devolutions\.CIEM'
            $script:capturedScriptBlock.ToString() | Should -Not -Match 'Import-Module Devolutions\.CIEM -Force'
            $script:capturedScriptBlock.ToString() | Should -Match 'Get-CIEMProvider'
        }

        It 'passes a custom env file to the selected PSU connection' {
            Invoke-TestCommand -Environment azure -EnvFilePath '/tmp/custom-ciem.env' -ScriptBlock { Get-CIEMProvider } | Out-Null

            $script:connectEnvFilePaths[0] | Should -Be '/tmp/custom-ciem.env'
        }

        It 'uses the explicit Azure PSU connection switch for Azure runtime commands' {
            Invoke-TestCommand -Environment azure -ScriptBlock { Get-CIEMProvider } | Out-Null

            $script:connectAzureFlags[0] | Should -BeTrue
        }
    }
}
