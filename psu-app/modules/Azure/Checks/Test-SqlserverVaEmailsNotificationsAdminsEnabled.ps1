function Test-SqlserverVaEmailsNotificationsAdminsEnabled {
    <#
    .SYNOPSIS
        SQL Server has Vulnerability Assessment enabled and email notifications to subscription admins configured

    .DESCRIPTION
        **Azure SQL Server** Vulnerability Assessment configuration, specifically whether recurring scans are set to email results to subscription admins/owners via `Also send email notifications to admins and subscription owners`.

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

    # TODO: Implement check logic based on Prowler check: sqlserver_va_emails_notifications_admins_enabled

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check sqlserver_va_emails_notifications_admins_enabled for reference.', 'N/A', 'sqlserver Resources')
}
