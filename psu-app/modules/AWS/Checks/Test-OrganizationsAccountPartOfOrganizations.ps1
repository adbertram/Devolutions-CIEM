function Test-OrganizationsAccountPartOfOrganizations {
    <#
    .SYNOPSIS
        AWS account is a member of an active AWS Organization

    .DESCRIPTION
        **AWS account** membership in **AWS Organizations** with organization status `ACTIVE`.
        
        Assesses if the account is associated with an organization and that the organization state is `ACTIVE`.

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

    # TODO: Implement check logic based on Prowler check: organizations_account_part_of_organizations

    [CIEMScanResult]::Create($Check, 'MANUAL', 'This check requires manual implementation. See Prowler check organizations_account_part_of_organizations for reference.', 'N/A', 'organizations Resources')
}
