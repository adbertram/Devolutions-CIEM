# UI Helper functions for PSU dashboard components
# These must be module-level (not nested) so they're accessible in PSU page scopes

function Get-SeverityColor {
    param([string]$Severity)
    switch ($Severity) {
        'CRITICAL' { '#9c27b0' }
        'HIGH' { '#f44336' }
        'MEDIUM' { '#ff9800' }
        'LOW' { '#2196f3' }
        'INFO' { '#4caf50' }
        default { '#666' }
    }
}

function Get-StatusColor {
    param([string]$Status)
    if ($Status -eq 'FAIL') { '#f44336' } else { '#4caf50' }
}

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

function New-CIEMSuccessContent {
    param(
        [string]$Text = 'Complete!',
        [string]$Details,
        [scriptblock]$ActionButton
    )
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

function New-CIEMErrorContent {
    param(
        [string]$Text = 'Failed',
        [string]$Details
    )
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
