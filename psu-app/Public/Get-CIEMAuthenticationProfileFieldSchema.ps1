function Get-CIEMAuthenticationProfileFieldSchema {
    <#
    .SYNOPSIS
        Returns generic authentication profile field schema definitions.

    .DESCRIPTION
        Exposes the data-driven authentication profile field schema used by PSU
        pages and tests. The schema is keyed by Provider and Method.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Azure', 'AWS', 'Email')]
        [string]$Provider,

        [Parameter()]
        [string]$Method
    )

    $ErrorActionPreference = 'Stop'

    $parameters = @{}
    if ($PSBoundParameters.ContainsKey('Provider')) {
        $parameters.Provider = $Provider
    }
    if ($PSBoundParameters.ContainsKey('Method')) {
        $parameters.Method = $Method
    }

    GetCIEMAuthenticationProfileFieldSchema @parameters
}
