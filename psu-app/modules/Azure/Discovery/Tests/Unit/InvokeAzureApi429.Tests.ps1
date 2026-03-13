BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')

    # Read the source file for structural assertions
    $script:ApiSource = Get-Content (Join-Path $PSScriptRoot '..' '..' 'Infrastructure' 'Public' 'Invoke-AzureApi.ps1') -Raw
}

Describe 'Invoke-AzureApi 429 Retry' {

    Context '429 case exists in source code' {
        It 'Invoke-AzureApi.ps1 contains a 429 switch case' {
            $script:ApiSource | Should -Match '429'
        }

        It 'Contains retry loop with max retries' {
            $script:ApiSource | Should -Match '(?i)max.*retr|retry.*max|retryCount|maxRetries'
        }

        It 'Contains exponential backoff (retryDelay * 2)' {
            $script:ApiSource | Should -Match '(?i)retryDelay\s*\*\s*2|\*=\s*2|backoff'
        }

        It 'Contains Retry-After header parsing' {
            $script:ApiSource | Should -Match '(?i)Retry-After'
        }
    }
}
