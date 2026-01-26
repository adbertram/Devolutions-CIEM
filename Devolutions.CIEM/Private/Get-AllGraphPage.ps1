function Get-AllGraphPage {
    <#
    .SYNOPSIS
        Retrieves all pages of results from a Microsoft Graph API endpoint.

    .DESCRIPTION
        Helper function to handle paginated results from Microsoft Graph API.
        Automatically follows @odata.nextLink to retrieve all pages and streams
        results to the pipeline as they are retrieved.

    .PARAMETER Uri
        The initial Microsoft Graph API URI to call.

    .PARAMETER ResourceName
        A friendly name for the resource being loaded, used in warning messages.

    .EXAMPLE
        Get-AllGraphPage -Uri 'https://graph.microsoft.com/v1.0/users' -ResourceName 'Users'
        Retrieves all users from Microsoft Graph, handling pagination automatically.

    .EXAMPLE
        $usersUri = "$graphApiBase/users?`$select=id,displayName,userPrincipalName"
        $users = @(Get-AllGraphPage -Uri $usersUri -ResourceName "Users")
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

    $currentUri = $Uri

    while ($currentUri) {
        $response = Invoke-AzRestMethod -Uri $currentUri -Method GET

        if (-not $response) {
            Write-Warning "Failed to load page for $ResourceName - No response"
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
                403 { Write-Warning "Access denied loading page for $ResourceName - missing permissions" }
                default { Write-Warning "Failed to load page for $ResourceName - Status: $($response.StatusCode)" }
            }
            $currentUri = $null
        }
    }
}
