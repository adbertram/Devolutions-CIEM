function Test-AccountSecurityContactInformationIsRegistered {
    <#
    .SYNOPSIS
        AWS account has security alternate contact registered

    .DESCRIPTION
        Account settings contain a **Security alternate contact** in Alternate Contacts (name, `EmailAddress`, `PhoneNumber`) for targeted AWS security notifications.

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

    # TODO: Implement check logic based on Prowler check: account_security_contact_information_is_registered

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check account_security_contact_information_is_registered for reference.', 'N/A', 'account Resources')
}
