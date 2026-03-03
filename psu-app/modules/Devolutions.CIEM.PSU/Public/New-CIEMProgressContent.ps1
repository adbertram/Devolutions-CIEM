function New-CIEMProgressContent {
    param(
        [string]$Text = 'Processing...'
    )
    New-UDCard -Style @{ backgroundColor = '#f5f5f5'; marginTop = '12px'; marginBottom = '12px' } -Content {
        New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
            New-UDProgress -Circular -Size 'small'
            New-UDTypography -Text $Text -Variant 'body2'
        }
    }
}
