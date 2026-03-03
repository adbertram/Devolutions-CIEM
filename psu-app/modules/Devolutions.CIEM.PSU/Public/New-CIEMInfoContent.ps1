function New-CIEMInfoContent {
    param(
        [string]$Text = 'Info',
        [string]$Details
    )
    New-UDCard -Style @{ backgroundColor = '#fff3e0'; marginTop = '12px'; marginBottom = '12px' } -Content {
        New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
            New-UDIcon -Icon 'InfoCircle' -Size 'lg' -Style @{ color = '#ff9800' }
            New-UDElement -Tag 'div' -Content {
                New-UDTypography -Text $Text -Variant 'body1' -Style @{ fontWeight = 'bold'; color = '#e65100' }
                if ($Details) {
                    New-UDTypography -Text $Details -Variant 'body2' -Style @{ color = '#666' }
                }
            }
        }
    }
}
