function New-CIEMSuccessContent {
    [CmdletBinding()]
    param(
        [string]$Text = 'Complete!',
        [string]$Details,
        [scriptblock]$ActionButton
    )

    $ErrorActionPreference = 'Stop'
    New-UDCard -Style @{ backgroundColor = '#e8f5e9'; marginTop = '12px'; marginBottom = '12px' } -Content {
        New-UDStack -Direction 'row' -Spacing 2 -AlignItems 'center' -Content {
            New-UDIcon -Icon 'CheckCircle' -Size 'lg' -Style @{ color = '#4caf50' }
            New-UDElement -Tag 'div' -Content {
                New-UDTypography -Text $Text -Variant 'body1' -Style @{ fontWeight = 'bold'; color = '#2e7d32' }
                if ($Details) {
                    New-UDTypography -Text $Details -Variant 'body2' -Style @{ color = '#666' }
                }
            }
        }
        if ($ActionButton) {
            & $ActionButton
        }
    }
}
