function Invoke-AzureApi {
    <#
    .SYNOPSIS
        Invokes Azure REST API (Graph or ARM) with standardized error handling.

    .DESCRIPTION
        Unified helper function to make Azure API calls using Invoke-AzRestMethod.
        Handles common response patterns including single objects and collections,
        and provides consistent error messaging for common HTTP status codes.

    .PARAMETER Uri
        The full API URI to call.

    .PARAMETER ResourceName
        A friendly name for the resource being loaded, used in verbose/warning messages.

    .EXAMPLE
        $params = @{
            Uri          = 'https://graph.microsoft.com/v1.0/users'
            ResourceName = 'Users'
        }
        Invoke-AzureApi @params

    .EXAMPLE
        $params = @{
            Uri          = "$armApiBase/subscriptions/$subId/providers/Microsoft.KeyVault/vaults?api-version=2023-07-01"
            ResourceName = "KeyVaults ($subId)"
        }
        Invoke-AzureApi @params
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Uri,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceName
    )

    $ErrorActionPreference = 'Stop'

    Write-Verbose "Loading $ResourceName..."
    $response = Invoke-AzRestMethod -Uri $Uri -Method GET

    if (-not $response) {
        Write-Warning "Failed to load $ResourceName - No response"
    }
    else {
        switch ($response.StatusCode) {
            200 {
                $content = $response.Content | ConvertFrom-Json
                if ($content.PSObject.Properties.Name -contains 'value') {
                    $content.value
                }
                else {
                    $content
                }
            }
            403 { Write-Warning "Access denied loading $ResourceName - missing permissions" }
            404 { Write-Verbose "Resource not found: $ResourceName" }
            default { Write-Warning "Failed to load $ResourceName - Status: $($response.StatusCode)" }
        }
    }
}
