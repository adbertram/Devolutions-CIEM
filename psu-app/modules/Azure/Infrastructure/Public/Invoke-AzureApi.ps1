function Invoke-AzureApi {
    <#
    .SYNOPSIS
        Invokes Azure REST API (ARM, Graph, or KeyVault) with standardized error handling.

    .DESCRIPTION
        Single point of entry for all Azure API calls. Handles authentication
        internally - callers should not deal with tokens or auth logic.

        Automatically follows pagination links (@odata.nextLink for Graph API,
        nextLink for ARM API) and streams all results to the pipeline.
        Use -Raw to bypass pagination and get the raw response object.

        By default, non-success responses result in warnings (silent failure).
        Use -ErrorAction Stop to throw terminating errors on non-success responses.

    .PARAMETER Uri
        The full API URI to call.

    .PARAMETER Api
        The API to target: ARM (Azure Resource Manager), Graph (Microsoft Graph),
        or KeyVault (Key Vault data plane). If not specified, auto-detects from URI.

    .PARAMETER ResourceName
        A friendly name for the resource being loaded, used in verbose/warning messages.

    .PARAMETER Method
        HTTP method to use. Defaults to GET.

    .PARAMETER Body
        Request body for POST/PUT/PATCH requests. Pass a hashtable or PSCustomObject;
        it will be serialized to JSON automatically.

    .PARAMETER Raw
        Return the raw response object (StatusCode, Content) instead of parsed content.
        Used internally for pagination support.

    .OUTPUTS
        [PSObject] The API response content. For collection endpoints, returns all
        items from the 'value' array across all pages (pagination is automatic).
        For single-resource endpoints, returns the full response object.
        Returns nothing on error (unless -ErrorAction Stop is specified).
        With -Raw, returns the first page's response object with StatusCode and
        Content properties (no automatic pagination).

    .EXAMPLE
        Invoke-AzureApi -Uri 'https://graph.microsoft.com/v1.0/users' -ResourceName 'Users'

    .EXAMPLE
        Invoke-AzureApi -Uri $armUri -Api ARM -ResourceName 'KeyVaults'

    .EXAMPLE
        # POST with body (e.g., Azure Resource Graph query)
        Invoke-AzureApi -Uri $rgUri -Method POST -Body @{ query = 'Resources | limit 10'; subscriptions = @($subId) } -ResourceName 'Resource Graph'

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

        [Parameter()]
        [ValidateSet('ARM', 'Graph', 'KeyVault')]
        [string]$Api,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceName,

        [Parameter()]
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')]
        [string]$Method = 'GET',

        [Parameter()]
        [object]$Body,

        [Parameter()]
        [switch]$Raw
    )

    # Suppress Invoke-RestMethod progress bar (noisy in PSU)
    $ProgressPreference = 'SilentlyContinue'

    # Capture caller's ErrorAction before we override
    $shouldThrow = $ErrorActionPreference -eq 'Stop'

    $ErrorActionPreference = 'Stop'

    Write-Verbose "Loading $ResourceName..."

    # Auto-detect API from URI if not specified
    if (-not $Api) {
        $Api = if ($Uri -match 'graph\.microsoft\.com') {
            'Graph'
        } elseif ($Uri -match '\.vault\.azure\.net') {
            'KeyVault'
        } else {
            'ARM'
        }
    }

    # Get tokens via centralized helper
    $tokens = Get-CIEMToken

    # Serialize body to JSON if provided
    $jsonBody = $null
    if ($Body) {
        $jsonBody = $Body | ConvertTo-Json -Depth 20 -Compress
    }

    # Helper to invoke REST API with proper error handling
    # Invoke-RestMethod throws HttpResponseException on 4xx/5xx even with -ErrorAction SilentlyContinue
    function Invoke-SafeRestMethod {
        param($Uri, $Headers, $Method, $JsonBody)
        try {
            $restParams = @{
                Uri         = $Uri
                Method      = $Method
                Headers     = $Headers
                ErrorAction = 'Stop'
            }
            if ($JsonBody) {
                $restParams.Body        = $JsonBody
                $restParams.ContentType = 'application/json'
            }
            $restResponse = Invoke-RestMethod @restParams
            [PSCustomObject]@{
                StatusCode = 200
                Content    = $restResponse | ConvertTo-Json -Depth 20
            }
        }
        catch [Microsoft.PowerShell.Commands.HttpResponseException] {
            $statusCode = [int]$_.Exception.Response.StatusCode
            [PSCustomObject]@{
                StatusCode = $statusCode
                Content    = $null
            }
        }
        catch {
            [PSCustomObject]@{
                StatusCode = 500
                Content    = $null
            }
        }
    }

    # Resolve token for the target API
    $tokenMap = @{
        Graph    = 'GraphToken'
        ARM      = 'ARMToken'
        KeyVault = 'KeyVaultToken'
    }
    $token = $tokens.($tokenMap[$Api])

    if (-not $token) {
        $msg = "$Api API call requested but no $Api token available. Run Connect-CIEM first."
        if ($shouldThrow) { throw $msg }
        Write-Warning $msg
        return
    }

    $headers = @{ Authorization = "Bearer $token" }
    $response = Invoke-SafeRestMethod -Uri $Uri -Headers $headers -Method $Method -JsonBody $jsonBody

    # Handle no response
    if (-not $response) {
        $msg = "Failed to load $ResourceName - No response"
        if ($shouldThrow) { throw $msg }
        Write-Warning $msg
        return
    }

    # Raw mode returns response object directly (for pagination)
    if ($Raw) {
        return $response
    }

    # Parse and return content with automatic pagination
    $currentResponse = $response
    while ($currentResponse) {
        switch ($currentResponse.StatusCode) {
            200 {
                $content = $currentResponse.Content | ConvertFrom-Json
                if ($content.PSObject.Properties.Name -contains 'value') {
                    $content.value
                }
                else {
                    # Single resource endpoint - no pagination possible
                    $content
                    $currentResponse = $null
                    continue
                }

                # Check for next page (@odata.nextLink for Graph, nextLink for ARM)
                $nextLink = if ($content.PSObject.Properties.Name -contains '@odata.nextLink') {
                    $content.'@odata.nextLink'
                }
                elseif ($content.PSObject.Properties.Name -contains 'nextLink') {
                    $content.nextLink
                }
                else {
                    $null
                }

                if ($nextLink) {
                    $currentResponse = Invoke-SafeRestMethod -Uri $nextLink -Headers $headers -Method 'GET' -JsonBody $null
                }
                else {
                    $currentResponse = $null
                }
            }
            401 {
                $msg = "Unauthorized loading $ResourceName - invalid or expired token"
                if ($shouldThrow) { throw $msg }
                Write-Warning $msg
                $currentResponse = $null
            }
            403 {
                $msg = "Access denied loading $ResourceName - missing permissions"
                if ($shouldThrow) { throw $msg }
                Write-Warning $msg
                $currentResponse = $null
            }
            404 {
                $msg = "Resource not found: $ResourceName"
                if ($shouldThrow) { throw $msg }
                Write-Verbose $msg
                $currentResponse = $null
            }
            default {
                $msg = "Failed to load $ResourceName - Status: $($currentResponse.StatusCode)"
                if ($shouldThrow) { throw $msg }
                Write-Warning $msg
                $currentResponse = $null
            }
        }
    }
}
