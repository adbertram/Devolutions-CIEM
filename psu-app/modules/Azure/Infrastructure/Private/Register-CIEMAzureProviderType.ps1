function Register-CIEMAzureProviderType {
    <#
    .SYNOPSIS
        Registers the Azure provider type with the CIEM Base module.

    .DESCRIPTION
        Calls Register-CIEMProviderType to register Azure default endpoints and
        seed the Azure provider row in the database.
    #>
    [CmdletBinding()]
    param()

    $callbacks = @{

        # -- Default API endpoints --
        DefaultEndpoints = {
            [PSCustomObject]@{
                graphApi = 'https://graph.microsoft.com/v1.0'
                armApi   = 'https://management.azure.com'
            }
        }

        # -- SeedDefaults: Seed Azure as default provider --
        SeedDefaults = {
            param($Connection, [string]$Timestamp)

            Invoke-PSUSQLiteQuery -Connection $Connection -Query "INSERT OR IGNORE INTO providers (id, name, type, enabled, is_default, created_at, updated_at) VALUES (@id, @name, @type, @enabled, @is_default, @now, @now)" -Parameters @{
                id = 'azure'; name = 'Azure'; type = 'Azure'; enabled = 1; is_default = 1; now = $Timestamp
            } -AsNonQuery | Out-Null
        }
    }

    Register-CIEMProviderType -Name 'Azure' -Callbacks $callbacks
}
