function ResolveCIEMAwsEffectivePermission {
    [CmdletBinding()]
    [OutputType([CIEMEffectivePermission[]])]
    param()

    $ErrorActionPreference = 'Stop'

    throw 'AWS effective permission data is not available because AWS identity and policy discovery tables are not implemented yet.'
}
