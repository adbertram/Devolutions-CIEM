function Remove-CIEMProvider {
    <#
    .SYNOPSIS
        Removes a CIEM cloud provider.

    .DESCRIPTION
        Removes a provider from the CIEM:Providers cache. If the removed
        provider was the default and other providers remain, the first
        remaining provider becomes the new default.

    .PARAMETER Name
        Provider name to remove (case-insensitive).

    .OUTPUTS
        None.

    .EXAMPLE
        Remove-CIEMProvider -Name 'GCP' -Confirm:$false
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $ErrorActionPreference = 'Stop'

    # Load existing providers
    $providers = @(Get-CIEMProvider)

    # Find the target provider
    $target = $providers | Where-Object { $_.Name -eq $Name }
    if (-not $target) {
        throw "Provider '$Name' not found."
    }

    if (-not $PSCmdlet.ShouldProcess($Name, 'Remove CIEM provider')) {
        return
    }

    $wasDefault = $target.IsDefault
    $remaining = @($providers | Where-Object { $_.Name -ne $Name })

    # If removed provider was default and others remain, set first as default
    if ($wasDefault -and $remaining.Count -gt 0) {
        $remaining[0] | Add-Member -NotePropertyName 'IsDefault' -NotePropertyValue $true -Force
    }

    # Remove computed CheckCount before persisting
    $toCache = $remaining | ForEach-Object {
        [PSCustomObject]@{
            Name           = $_.Name
            Enabled        = $_.Enabled
            IsDefault      = $_.IsDefault
            Authentication = $_.Authentication
            Endpoints      = $_.Endpoints
            ResourceFilter = @($_.ResourceFilter)
        }
    }

    # Persist to PSU cache
    Set-PSUCache -Key 'CIEM:Providers' -Value @($toCache) -ErrorAction SilentlyContinue
}
