function Save-CIEMProvider {
    <#
    .SYNOPSIS
        Upserts a CIEM cloud provider.
    .DESCRIPTION
        Performs an INSERT OR REPLACE on the providers table. Used for bulk or
        idempotent operations where the caller doesn't care if the row exists.
    .PARAMETER Name
        Provider name (e.g., 'Azure', 'AWS').
    .PARAMETER Enabled
        Whether the provider is enabled. Defaults to $true.
    .PARAMETER IsDefault
        Whether this provider is the default.
    .PARAMETER InputObject
        A CIEMProvider object to upsert.
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByProperties')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Upsert operation for bulk data')]
    [OutputType('CIEMProvider')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByProperties')]
        [string]$Name,

        [Parameter(ParameterSetName = 'ByProperties')]
        [bool]$Enabled = $true,

        [Parameter(ParameterSetName = 'ByProperties')]
        [switch]$IsDefault,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', ValueFromPipeline)]
        [PSObject[]]$InputObject,

        [Parameter()]
        [switch]$PassThru
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'InputObject') {
            foreach ($item in $InputObject) {
                $now = (Get-Date).ToString('o')
                Invoke-CIEMQuery -Query @"
INSERT OR REPLACE INTO providers (id, name, type, enabled, is_default, created_at, updated_at)
VALUES (@id, @name, @type, @enabled, @is_default, @now, @now)
"@ -Parameters @{
                    id         = $item.Name.ToLower()
                    name       = $item.Name
                    type       = $item.Name
                    enabled    = if ($item.Enabled) { 1 } else { 0 }
                    is_default = if ($item.IsDefault) { 1 } else { 0 }
                    now        = $now
                } -AsNonQuery | Out-Null

                if ($PassThru) { Get-CIEMProvider -Name $item.Name }
            }
        } else {
            $now = (Get-Date).ToString('o')
            $providerId = $Name.ToLower()
            Invoke-CIEMQuery -Query @"
INSERT OR REPLACE INTO providers (id, name, type, enabled, is_default, created_at, updated_at)
VALUES (@id, @name, @type, @enabled, @is_default, @now, @now)
"@ -Parameters @{
                id         = $providerId
                name       = $Name
                type       = $Name
                enabled    = if ($Enabled) { 1 } else { 0 }
                is_default = if ($IsDefault.IsPresent) { 1 } else { 0 }
                now        = $now
            } -AsNonQuery | Out-Null

            if ($PassThru) { Get-CIEMProvider -Name $Name }
        }
    }
}
