function New-CIEMAboutPage {
    <#
    .SYNOPSIS
        Creates the About page with module info, features, and version details.
    .PARAMETER Navigation
        Array of UDListItem components for sidebar navigation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Navigation
    )

    New-UDPage -Name 'About' -Url '/ciem/about' -Content {
        Import-Module Devolutions.CIEM.PSU -Force -ErrorAction SilentlyContinue

        New-UDTypography -Text 'About Devolutions CIEM' -Variant 'h4' -Style @{ marginBottom = '20px'; marginTop = '10px' }

        New-UDCard -Title 'Cloud Infrastructure Entitlement Management' -Content {
            New-UDTypography -Text 'Devolutions CIEM is a security scanning solution that helps identify identity and access management issues across your cloud infrastructure.' -Variant 'body1' -Style @{ marginBottom = '20px' }

            # Dynamic provider/check info
            $providers = @(Get-CIEMProvider)
            $featureItems = @()
            foreach ($p in $providers) {
                $featureItems += "$($p.CheckCount) $($p.Name) security checks"
            }

            New-UDTypography -Text 'Key Features:' -Variant 'h6' -Style @{ marginTop = '20px' }
            New-UDList -Content {
                foreach ($item in $featureItems) {
                    New-UDListItem -Label $item
                }
                New-UDListItem -Label 'Multi-provider support (Azure + AWS)'
                New-UDListItem -Label 'Identity and entitlement focused checks'
                New-UDListItem -Label 'Integration with Devolutions PAM for remediation'
            }

            New-UDTypography -Text 'Version Information:' -Variant 'h6' -Style @{ marginTop = '20px' }
            $moduleVersion = (Get-Module Devolutions.CIEM.PSU -ListAvailable | Select-Object -First 1).Version.ToString()
            New-UDTable -Data @(
                @{ Property = 'Module Version'; Value = $moduleVersion }
                @{ Property = 'PowerShell Universal'; Value = '5.5+' }
                @{ Property = 'Author'; Value = 'Adam Bertram' }
                @{ Property = 'Company'; Value = 'Devolutions Inc.' }
            ) -Columns @(
                New-UDTableColumn -Property 'Property' -Title 'Property'
                New-UDTableColumn -Property 'Value' -Title 'Value'
            ) -Dense

            New-UDTypography -Text 'Learn More:' -Variant 'h6' -Style @{ marginTop = '20px' }
            New-UDButton -Text 'Devolutions PAM' -Href 'https://devolutions.net/pam' -Variant 'outlined' -Style @{ marginRight = '10px' }
            New-UDButton -Text 'Documentation' -Href 'https://docs.devolutions.net' -Variant 'outlined'
        }
    } -Navigation $Navigation -NavigationLayout permanent
}
