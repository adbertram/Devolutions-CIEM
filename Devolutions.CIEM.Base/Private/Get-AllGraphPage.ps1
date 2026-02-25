function Get-AllGraphPage {
    <#
    .SYNOPSIS
        Retrieves all pages of results from an Azure API endpoint.

    .DESCRIPTION
        Pagination wrapper for Invoke-AzureApi. Automatically follows @odata.nextLink
        to retrieve all pages and streams results to the pipeline.

        By default, non-success responses result in warnings (silent failure).
        Use -ErrorAction Stop to throw terminating errors on non-success responses.

    .PARAMETER Uri
        The initial API URI to call.

    .PARAMETER ResourceName
        A friendly name for the resource being loaded, used in warning messages.

    .OUTPUTS
        [PSObject] Individual items from the 'value' array of each page, streamed
        to the pipeline as they are retrieved.

    .EXAMPLE
        Get-AllGraphPage -Uri 'https://graph.microsoft.com/v1.0/users' -ResourceName 'Users'

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

    $currentUri = $Uri

    while ($currentUri) {
        $response = Invoke-AzureApi -Uri $currentUri -ResourceName $ResourceName -Raw -ErrorAction $ErrorActionPreference

        if ($response -and $response.StatusCode -eq 200) {
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
            $currentUri = $null
        }
    }
}
