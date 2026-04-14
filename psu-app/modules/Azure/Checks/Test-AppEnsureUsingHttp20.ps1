function Test-AppEnsureUsingHttp20 {
    <#
    .SYNOPSIS
        App Service web app has HTTP/2.0 enabled

    .DESCRIPTION
        **Azure App Service web apps** are evaluated for **HTTP/2 support** via the `http20_enabled` configuration, indicating whether the site serves traffic using the HTTP/2 protocol

    .PARAMETER Check
        CIEMCheck object containing check metadata.
    #>
    [CmdletBinding()]
    [OutputType('CIEMScanResult[]')]
    param(
        [Parameter(Mandatory)]
        $Check
    )

    $ErrorActionPreference = 'Stop'

    # TODO: Implement check logic based on Prowler check: app_ensure_using_http20

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check app_ensure_using_http20 for reference.', 'N/A', 'app Resources')
}
