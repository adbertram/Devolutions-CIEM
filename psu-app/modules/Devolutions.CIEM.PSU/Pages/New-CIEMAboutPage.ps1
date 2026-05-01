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

    $ErrorActionPreference = 'Stop'

    New-UDPage -Name 'About' -Url '/ciem/about' -Content {
        New-UDTypography -Text 'About Devolutions CIEM' -Variant 'h4' -Style @{ marginBottom = '20px'; marginTop = '10px' }

        New-UDCard -Title 'Cloud Infrastructure Entitlement Management' -Content {
            New-UDTypography -Text 'Devolutions CIEM identifies cloud entitlement risk by combining provider checks with identity and access relationship data.' -Variant 'body1' -Style @{ marginBottom = '20px' }

            # Dynamic provider/check info
            $providers = @(Devolutions.CIEM\Get-CIEMProvider)

            New-UDGrid -Container -Spacing 3 -Content {
                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                    New-UDElement -Tag 'section' -Attributes @{ 'data-ciem-about-section' = 'checks' } -Content {
                        New-UDTypography -Text 'Checks' -Variant 'h5' -Style @{ marginBottom = '10px' }
                        New-UDTypography -Text 'Checks validate cloud configuration, entitlement, and control conditions across supported providers. Each result includes severity, evidence, and remediation guidance for scan review.' -Variant 'body1' -Style @{ marginBottom = '14px' }
                        New-UDList -Content {
                            foreach ($p in $providers) {
                                New-UDListItem -Label "$($p.CheckCount) $($p.Name) security checks"
                            }
                        }
                    }
                }

                New-UDGrid -Item -ExtraSmallSize 12 -MediumSize 6 -Content {
                    New-UDElement -Tag 'section' -Attributes @{ 'data-ciem-about-section' = 'identities' } -Content {
                        New-UDTypography -Text 'Identities' -Variant 'h5' -Style @{ marginBottom = '10px' }
                        New-UDTypography -Text 'Identities cover identity inventory, role assignments, effective entitlement computation, and relationship paths that explain who can reach privileged cloud resources.' -Variant 'body1' -Style @{ marginBottom = '14px' }
                        New-UDTypography -Text 'Devolutions CIEM surfaces these findings so remediation can move into Devolutions PAM workflows where privileged access can be controlled.' -Variant 'body1'
                    }
                }
            }

            New-UDTypography -Text 'Version Information:' -Variant 'h6' -Style @{ marginTop = '20px' }
            $module = Get-Module Devolutions.CIEM | Select-Object -First 1
            $moduleVersion = if ($module) { $module.Version.ToString() } else { 'Unknown' }
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
