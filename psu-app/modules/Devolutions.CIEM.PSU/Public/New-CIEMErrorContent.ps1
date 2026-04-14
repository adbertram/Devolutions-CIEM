function New-CIEMErrorContent {
    [CmdletBinding()]
    param(
        [string]$Text = 'Failed',
        [string]$Details
    )

    $ErrorActionPreference = 'Stop'

    New-UDCard -Style @{ backgroundColor = '#ffebee'; marginTop = '12px'; marginBottom = '12px' } -Content {
        New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
            New-UDIcon -Icon 'TimesCircle' -Size 'lg' -Style @{ color = '#f44336' }
            New-UDElement -Tag 'div' -Content {
                New-UDTypography -Text $Text -Variant 'body1' -Style @{ fontWeight = 'bold'; color = '#c62828' }
                if ($Details) {
                    New-UDTypography -Text $Details -Variant 'body2' -Style @{ color = '#666' }
                }
            }
        }
    }
}
