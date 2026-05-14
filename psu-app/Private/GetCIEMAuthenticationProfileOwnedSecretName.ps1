function GetCIEMAuthenticationProfileOwnedSecretName {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$ProfileId,

        [Parameter(Mandatory)]
        [pscustomobject]$SecretRefs
    )

    $ErrorActionPreference = 'Stop'

    $prefix = "CIEM_AuthProfile_${ProfileId}_"
    foreach ($property in @($SecretRefs.PSObject.Properties)) {
        $secretName = [string]$property.Value
        if ($secretName.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
            $secretName
        }
    }
}
