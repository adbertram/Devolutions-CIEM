function Invoke-AzureApi {
    <#
    .SYNOPSIS
        Invokes Azure REST API (Graph or ARM) with standardized error handling.

    .DESCRIPTION
        Unified helper function to make Azure API calls using Invoke-AzRestMethod.
        Handles common response patterns including single objects and collections,
        and provides consistent error messaging for common HTTP status codes.

        By default, non-success responses result in warnings (silent failure).
        Use -ErrorAction Stop to throw terminating errors on non-success responses.

    .PARAMETER Uri
        The full API URI to call.

    .PARAMETER ResourceName
        A friendly name for the resource being loaded, used in verbose/warning messages.

    .OUTPUTS
        [PSObject] The API response content. For collection endpoints, returns the
        'value' array. For single-resource endpoints, returns the full response object.
        Returns nothing on error (unless -ErrorAction Stop is specified).

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

    .EXAMPLE
        # Throw on error instead of warning
        Invoke-AzureApi -Uri $uri -ResourceName 'Critical Resource' -ErrorAction Stop
    #>
    [CmdletBinding()]
    [OutputType([PSObject])]
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

    # Determine if caller wants errors to throw (respects -ErrorAction parameter)
    $shouldThrow = $ErrorActionPreference -eq 'Stop'

    if (-not $response) {
        $msg = "Failed to load $ResourceName - No response"
        if ($shouldThrow) {
            throw $msg
        }
        Write-Warning $msg
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
            403 {
                $msg = "Access denied loading $ResourceName - missing permissions"
                if ($shouldThrow) { throw $msg }
                Write-Warning $msg
            }
            404 {
                $msg = "Resource not found: $ResourceName"
                if ($shouldThrow) { throw $msg }
                Write-Verbose $msg
            }
            default {
                $msg = "Failed to load $ResourceName - Status: $($response.StatusCode)"
                if ($shouldThrow) { throw $msg }
                Write-Warning $msg
            }
        }
    }
}
