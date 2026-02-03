function Get-AllGraphPage {
    <#
    .SYNOPSIS
        Retrieves all pages of results from a Microsoft Graph API endpoint.

    .DESCRIPTION
        Helper function to handle paginated results from Microsoft Graph API.
        Automatically follows @odata.nextLink to retrieve all pages and streams
        results to the pipeline as they are retrieved.

        By default, non-success responses result in warnings (silent failure).
        Use -ErrorAction Stop to throw terminating errors on non-success responses.

    .PARAMETER Uri
        The initial Microsoft Graph API URI to call.

    .PARAMETER ResourceName
        A friendly name for the resource being loaded, used in warning messages.

    .OUTPUTS
        [PSObject] Individual items from the 'value' array of each page, streamed
        to the pipeline as they are retrieved. Returns nothing on error (unless
        -ErrorAction Stop is specified).

    .EXAMPLE
        Get-AllGraphPage -Uri 'https://graph.microsoft.com/v1.0/users' -ResourceName 'Users'
        Retrieves all users from Microsoft Graph, handling pagination automatically.

    .EXAMPLE
        $usersUri = "$graphApiBase/users?`$select=id,displayName,userPrincipalName"
        $users = @(Get-AllGraphPage -Uri $usersUri -ResourceName "Users")

    .EXAMPLE
        # Throw on error instead of warning
        Get-AllGraphPage -Uri $uri -ResourceName 'Critical Data' -ErrorAction Stop
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

    # Capture caller's ErrorAction preference before we override it
    $shouldThrow = $ErrorActionPreference -eq 'Stop'

    $ErrorActionPreference = 'Stop'

    $currentUri = $Uri

    while ($currentUri) {
        $response = Invoke-AzRestMethod -Uri $currentUri -Method GET

        if (-not $response) {
            $msg = "Failed to load page for $ResourceName - No response"
            if ($shouldThrow) { throw $msg }
            Write-Warning $msg
            $currentUri = $null
        }
        elseif ($response.StatusCode -eq 200) {
            $content = $response.Content | ConvertFrom-Json
            if ($content.PSObject.Properties.Name -contains 'value') {
                $content.value
            }

            # Check for next page
            $currentUri = if ($content.PSObject.Properties.Name -contains '@odata.nextLink') {
                $content.'@odata.nextLink'
            }
            else {
                $null
            }
        }
        else {
            switch ($response.StatusCode) {
                403 {
                    $msg = "Access denied loading page for $ResourceName - missing permissions"
                    if ($shouldThrow) { throw $msg }
                    Write-Warning $msg
                }
                default {
                    $msg = "Failed to load page for $ResourceName - Status: $($response.StatusCode)"
                    if ($shouldThrow) { throw $msg }
                    Write-Warning $msg
                }
            }
            $currentUri = $null
        }
    }
}
