BeforeAll {
    Remove-Module Devolutions.CIEM -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '..' '..' '..' '..' 'Devolutions.CIEM.psd1')
    Mock -ModuleName Devolutions.CIEM Write-CIEMLog {}

    Mock -ModuleName Devolutions.CIEM New-UDTypography {
        param(
            [string]$Text,
            [string]$Variant,
            [hashtable]$Style
        )

        $script:lastTypographyText = $Text
        [pscustomobject]@{
            Text    = $Text
            Variant = $Variant
            Style   = $Style
        }
    }

    Mock -ModuleName Devolutions.CIEM New-UDElement {
        param(
            [string]$Tag,
            [string]$Id,
            [hashtable]$Attributes,
            [scriptblock]$Content
        )

        $script:lastTypographyText = $null
        $renderedContent = & $Content
        [pscustomobject]@{
            Tag         = $Tag
            Id          = $Id
            Attributes  = $Attributes
            Content     = $renderedContent
            TextContent = $script:lastTypographyText
        }
    }
}

Describe 'New-CIEMLastDiscoveryHeader' {
    Context 'Command structure' {
        It 'Is available as a public command' {
            Get-Command New-CIEMLastDiscoveryHeader -Module Devolutions.CIEM -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
    }

    Context 'when no completed discovery run exists' {
        BeforeAll {
            Mock -ModuleName Devolutions.CIEM Get-CIEMAzureDiscoveryRun { @() }
            $script:header = New-CIEMLastDiscoveryHeader
        }

        It 'renders the empty discovery state in the header box' {
            $script:header.Id | Should -Be 'ciemLastDiscoveryHeader'
            $script:header.TextContent | Should -Be 'No discovery generated'
        }

        It 'renders visible box styling for the light app bar' {
            $script:header.Attributes.style.backgroundColor | Should -Be '#fff'
            $script:header.Attributes.style.border | Should -Be '1px solid rgba(0,0,0,0.23)'
            $script:header.Attributes.style.color | Should -Be '#333'
            $script:header.Content.Style.color | Should -Be '#333'
        }
    }

    Context 'when a completed discovery run exists' {
        BeforeAll {
            Mock -ModuleName Devolutions.CIEM Get-CIEMAzureDiscoveryRun {
                @(
                    [pscustomobject]@{
                        Id          = 42
                        CompletedAt = '2026-03-14T09:15:30Z'
                    }
                )
            }
            $script:header = New-CIEMLastDiscoveryHeader
        }

        It 'renders the completed discovery timestamp in UTC' {
            $script:header.Id | Should -Be 'ciemLastDiscoveryHeader'
            $script:header.TextContent | Should -Be 'Last discovery generated 2026-03-14 09:15 UTC'
        }
    }

    Context 'when a completed discovery run has no completed timestamp' {
        BeforeAll {
            Mock -ModuleName Devolutions.CIEM Get-CIEMAzureDiscoveryRun {
                @(
                    [pscustomobject]@{
                        Id          = 43
                        CompletedAt = $null
                    }
                )
            }
        }

        It 'throws a clear data integrity error' {
            { New-CIEMLastDiscoveryHeader } | Should -Throw "*Completed discovery run '43' has no completed timestamp*"
        }
    }
}
