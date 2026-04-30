function ReadPSUCache {
    <#
    .SYNOPSIS
        Reads a value from PSU cache, distinguishing missing keys from infrastructure failures.

    .DESCRIPTION
        Wraps Get-PSUCache to provide clear semantics:
        - Key exists: returns the cached value
        - Key does not exist: returns $null
        - PSU cache unavailable (not in PSU context): throws
        - Infrastructure failure (connection error, etc.): throws

        PSU's Get-PSUCache throws "You cannot call a method on a null-valued expression"
        when a key doesn't exist. This helper catches that specific error and returns $null,
        while re-throwing all other exceptions.

    .PARAMETER Key
        The PSU cache key to read.

    .OUTPUTS
        The cached value, or $null if the key doesn't exist.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Key
    )

    $ErrorActionPreference = 'Stop'

    $getCacheCommand = Get-Command -Name 'Get-PSUCache' -ErrorAction Stop
    if (-not $getCacheCommand) {
        throw "Get-PSUCache is required to read PSU cache key '$Key'."
    }

    try {
        Get-PSUCache -Key $Key -Integrated -ErrorAction Stop
    }
    catch {
        if ($_.Exception.Message -match 'null-valued expression') {
            return $null
        }
        throw
    }
}
