function Test-AzureConnection {
    <#
    .SYNOPSIS
        Tests connectivity to Azure Graph and ARM APIs.

    .DESCRIPTION
        Validates that the current Azure authentication context can access
        both the Microsoft Graph API and Azure Resource Manager API.

    .OUTPUTS
        [bool] $true if both APIs are accessible, $false otherwise.

    .EXAMPLE
        if (Test-AzureConnection) {
            Write-Verbose "Azure connection validated"
        }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $ErrorActionPreference = 'Stop'

    # Check for existing context
    $context = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $context) {
        Write-Verbose "No Azure context found"
        $false
    }
    else {
        $graphApiBase = $script:Config.azure.endpoints.graphApi
        $armApiBase = $script:Config.azure.endpoints.armApi

        # Test Graph API
        Write-Verbose "Testing Graph API connectivity..."
        try {
            $graphResponse = Invoke-AzRestMethod -Uri "$graphApiBase/organization" -Method GET
            if ($graphResponse.StatusCode -ne 200) {
                Write-Verbose "Graph API returned status $($graphResponse.StatusCode)"
                $false
            }
            else {
                # Test ARM API
                Write-Verbose "Testing ARM API connectivity..."
                $armResponse = Invoke-AzRestMethod -Uri "$armApiBase/subscriptions?api-version=2020-01-01" -Method GET
                switch ($armResponse.StatusCode) {
                    200 {
                        Write-Verbose "Azure connection validated successfully"
                        $true
                    }
                    default {
                        Write-Verbose "ARM API returned status $($armResponse.StatusCode)"
                        $false
                    }
                }
            }
        }
        catch {
            Write-Verbose "API test failed: $($_.Exception.Message)"
            $false
        }
    }
}
