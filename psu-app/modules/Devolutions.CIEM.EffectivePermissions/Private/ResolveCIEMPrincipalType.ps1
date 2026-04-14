function ResolveCIEMPrincipalType {
    [CmdletBinding()]
    [OutputType([CIEMPrincipalType])]
    param(
        [Parameter(Mandatory)]
        [string]$Kind
    )

    $ErrorActionPreference = 'Stop'

    switch ($Kind) {
        'EntraUser'             { [CIEMPrincipalType]::User; break }
        'EntraGroup'            { [CIEMPrincipalType]::Group; break }
        'EntraServicePrincipal' { [CIEMPrincipalType]::ServicePrincipal; break }
        'EntraManagedIdentity'  { [CIEMPrincipalType]::ManagedIdentity; break }
        'EntraApplication'      { [CIEMPrincipalType]::Application; break }
        'AWSUser'               { [CIEMPrincipalType]::User; break }
        'AWSGroup'              { [CIEMPrincipalType]::Group; break }
        'AWSRole'               { [CIEMPrincipalType]::Role; break }
        'GCPServiceAccount'     { [CIEMPrincipalType]::ServiceAccount; break }
        default                 { [CIEMPrincipalType]::Unknown }
    }
}
