function Test-SqlserverMicrosoftDefenderEnabled {
    <#
    .SYNOPSIS
        SQL Server has Microsoft Defender for SQL enabled

    .DESCRIPTION
        **Azure SQL Server** instances are evaluated for the server-level **security alert policy** of **Microsoft Defender for SQL**, expecting the policy state to be `Enabled`.

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

    # TODO: Implement check logic based on Prowler check: sqlserver_microsoft_defender_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check sqlserver_microsoft_defender_enabled for reference.', 'N/A', 'sqlserver Resources')
}
