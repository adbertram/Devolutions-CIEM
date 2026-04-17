function New-CIEMLastDiscoveryHeader {
    <#
    .SYNOPSIS
        Renders the latest Azure discovery completion time for the app header.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param()

    $ErrorActionPreference = 'Stop'

    $lastRun = @(Get-CIEMAzureDiscoveryRun -Status 'Completed' -Last 1)
    $text = 'No discovery generated'

    if ($lastRun.Count -gt 0) {
        if (-not $lastRun[0].CompletedAt) {
            throw "Completed discovery run '$($lastRun[0].Id)' has no completed timestamp."
        }

        $completedAt = [datetimeoffset]::Parse($lastRun[0].CompletedAt).UtcDateTime
        $text = "Last discovery generated $($completedAt.ToString("yyyy-MM-dd HH:mm 'UTC'"))"
    }

    New-UDElement -Tag 'div' -Id 'ciemLastDiscoveryHeader' -Attributes @{
        style = @{
            display = 'flex'
            alignItems = 'center'
            padding = '6px 10px'
            border = '1px solid rgba(0,0,0,0.23)'
            borderRadius = '6px'
            backgroundColor = '#fff'
            boxShadow = '0 1px 3px rgba(0,0,0,0.16)'
            color = '#333'
            fontSize = '0.82rem'
            lineHeight = '1.2'
            whiteSpace = 'nowrap'
        }
    } -Content {
        New-UDTypography -Text $text -Variant 'caption' -Style @{
            color = '#333'
            lineHeight = '1.2'
            letterSpacing = '0'
        }
    }
}
