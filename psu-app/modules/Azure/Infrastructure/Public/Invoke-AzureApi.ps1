function Invoke-AzureApi {
    <#
    .SYNOPSIS
        Invokes Azure REST API (ARM, Graph, or KeyVault) with standardized error handling.

    .DESCRIPTION
        Single point of entry for all Azure API calls. Handles authentication
        internally - callers should not deal with tokens or auth logic.

        Supports two calling patterns:
        - ByUri: Pass a full URL via -Uri (existing, backward compat)
        - ByPath: Pass a relative path via -Path with a mandatory -Api selector.
          The base URL is resolved from the azure_provider_apis table.
          Optionally pass -SubscriptionId to loop over subscriptions and return
          a hashtable keyed by subscription ID.

        Automatically follows pagination links (@odata.nextLink for Graph API,
        nextLink for ARM API) and streams all results to the pipeline.
        Use -Raw to bypass pagination and get the raw response object.

        By default, non-success responses result in warnings (silent failure).
        Use -ErrorAction Stop to throw terminating errors on non-success responses.

    .PARAMETER Uri
        The full API URI to call. Mutually exclusive with -Path.

    .PARAMETER Path
        A relative API path (e.g., '/users?$select=id,displayName'). Requires -Api.
        Mutually exclusive with -Uri.

    .PARAMETER Api
        The API to target: ARM (Azure Resource Manager), Graph (Microsoft Graph),
        or KeyVault (Key Vault data plane). Required when using -Path; optional
        with -Uri (auto-detects from URI).

    .PARAMETER SubscriptionId
        One or more subscription IDs. Only valid with -Path and -Api ARM.
        Prepends /subscriptions/{id} to -Path and loops, returning a hashtable
        keyed by subscription ID.

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
        With -SubscriptionId, returns a [hashtable] keyed by subscription ID.

    .EXAMPLE
        Invoke-AzureApi -Uri 'https://graph.microsoft.com/v1.0/users' -ResourceName 'Users'

    .EXAMPLE
        Invoke-AzureApi -Api Graph -Path '/users?$select=id,displayName' -ResourceName 'Users'

    .EXAMPLE
        Invoke-AzureApi -Api ARM -Path '/providers/Microsoft.Security/pricings?api-version=2024-01-01' -SubscriptionId $subIds -ResourceName 'Pricings'

    .EXAMPLE
        # POST with body (e.g., Azure Resource Graph query)
        Invoke-AzureApi -Uri $armUri -Method POST -Body @{ query = 'Resources | limit 10'; subscriptions = @($subId) } -ResourceName 'Resource Graph'

    .EXAMPLE
        # Throw on error instead of warning
        Invoke-AzureApi -Uri $uri -ResourceName 'Critical Resource' -ErrorAction Stop
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByUri')]
    [OutputType([PSObject])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByUri')]
        [ValidateNotNullOrEmpty()]
        [string]$Uri,

        [Parameter(Mandatory, ParameterSetName = 'ByPath')]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(ParameterSetName = 'ByUri')]
        [Parameter(Mandatory, ParameterSetName = 'ByPath')]
        [ValidateSet('ARM', 'Graph', 'GraphBeta', 'KeyVault')]
        [string]$Api,

        [Parameter(ParameterSetName = 'ByPath')]
        [string[]]$SubscriptionId,

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

    # --- Resolve URI from Path if using ByPath parameter set ---
    if ($PSCmdlet.ParameterSetName -eq 'ByPath') {
        $apiRecord = Get-CIEMAzureProviderApi -Name $Api
        if (-not $apiRecord) {
            $msg = "No API endpoint record found for '$Api' in azure_provider_apis table."
            if ($shouldThrow) { throw $msg }
            Write-Warning $msg
            return
        }
        $baseUrl = $apiRecord.BaseUrl.TrimEnd('/')

        if ($SubscriptionId) {
            # Loop over subscriptions, return hashtable keyed by sub ID
            $results = @{}
            foreach ($subId in $SubscriptionId) {
                $fullUri = "$baseUrl/subscriptions/$subId/$($Path.TrimStart('/'))"
                $subResult = Invoke-AzureApi -Uri $fullUri -Api $Api -ResourceName "$ResourceName ($subId)" -Method $Method -Body $Body -Raw:$Raw
                $results[$subId] = $subResult
            }
            return $results
        }
        else {
            $Uri = "$baseUrl/$($Path.TrimStart('/'))"
        }
    }

    Write-Verbose "Loading $ResourceName..."

    # Auto-detect API from URI if not specified
    if (-not $Api) {
        $Api = if ($Uri -match 'graph\.microsoft\.com/beta') {
            'GraphBeta'
        } elseif ($Uri -match 'graph\.microsoft\.com') {
            'Graph'
        } elseif ($Uri -match '\.vault\.azure\.net') {
            'KeyVault'
        } else {
            'ARM'
        }
    }

    # Read tokens directly from auth context
    if (-not $script:AzureAuthContext -or -not $script:AzureAuthContext.IsConnected) {
        $msg = "Not connected to Azure. Run Connect-CIEM first."
        if ($shouldThrow) { throw $msg }
        Write-Warning $msg
        return
    }

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
            # Try to capture the error response body for diagnostics
            $errorBody = $null
            try { $errorBody = $_.ErrorDetails.Message } catch {}
            [PSCustomObject]@{
                StatusCode = $statusCode
                Content    = $errorBody
            }
        }
        catch {
            [PSCustomObject]@{
                StatusCode = 0
                Content    = $_.Exception.Message
            }
        }
    }

    # Resolve token for the target API directly from auth context
    $token = switch ($Api) {
        'Graph'     { $script:AzureAuthContext.GraphToken }
        'GraphBeta' { $script:AzureAuthContext.GraphToken }
        'ARM'       { $script:AzureAuthContext.ARMToken }
        'KeyVault'  { $script:AzureAuthContext.KeyVaultToken }
    }

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
                elseif ($content.PSObject.Properties.Name -contains '$skipToken' -and $content.'$skipToken' -and $Method -eq 'POST') {
                    # Resource Graph POST pagination: inject $skipToken back into the request body
                    $nextBody = if ($Body) { $Body.Clone() } else { @{} }
                    $nextBody['$skipToken'] = $content.'$skipToken'
                    $skipJsonBody = $nextBody | ConvertTo-Json -Depth 20 -Compress
                    $currentResponse = Invoke-SafeRestMethod -Uri $Uri -Headers $headers -Method $Method -JsonBody $skipJsonBody
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
            0 {
                # Non-HTTP error (PowerShell exception, network error, etc.)
                $detail = if ($currentResponse.Content) { $currentResponse.Content } else { 'Unknown error' }
                $msg = "Failed to load $ResourceName - $detail"
                if ($shouldThrow) { throw $msg }
                Write-Warning $msg
                $currentResponse = $null
            }
            429 {
                # Rate limited — parse Retry-After header and retry with backoff
                $maxRetries = 5
                $retryCount = 0
                $retryDelay = 1
                $retried = $false

                while ($retryCount -lt $maxRetries) {
                    $retryCount++
                    $retryAfter = $retryDelay

                    # Try to parse Retry-After from response content
                    try {
                        if ($currentResponse.Content) {
                            $errorContent = $currentResponse.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
                            if ($errorContent.retryAfter) {
                                $retryAfter = [int]$errorContent.retryAfter
                            }
                        }
                    } catch {}

                    Write-Verbose "[$ResourceName] Rate limited (429). Retry $retryCount of $maxRetries after ${retryAfter}s..."
                    Start-Sleep -Seconds $retryAfter
                    $retryDelay = $retryDelay * 2  # exponential backoff

                    $currentResponse = Invoke-SafeRestMethod -Uri $Uri -Headers $headers -Method $Method -JsonBody $jsonBody
                    if ($currentResponse.StatusCode -ne 429) {
                        $retried = $true
                        break
                    }
                }

                if (-not $retried) {
                    $msg = "Rate limit exceeded for $ResourceName after $maxRetries retries."
                    if ($shouldThrow) { throw $msg }
                    Write-Warning $msg
                    $currentResponse = $null
                }
            }
            default {
                $detail = if ($currentResponse.Content) { " - $($currentResponse.Content)" } else { '' }
                $msg = "Failed to load $ResourceName - Status: $($currentResponse.StatusCode)$detail"
                if ($shouldThrow) { throw $msg }
                Write-Warning $msg
                $currentResponse = $null
            }
        }
    }
}
