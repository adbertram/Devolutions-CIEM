function Invoke-AzureApi {
    <#
    .SYNOPSIS
        Invokes Azure REST API (ARM, Graph, or KeyVault) with standardized error handling.

    .DESCRIPTION
        Single point of entry for all Azure API calls. Handles authentication
        internally - callers should not deal with tokens or auth logic.

        By default, non-success responses result in warnings (silent failure).
        Use -ErrorAction Stop to throw terminating errors on non-success responses.

    .PARAMETER Uri
        The full API URI to call.

    .PARAMETER Api
        The API to target: ARM (Azure Resource Manager), Graph (Microsoft Graph),
        or KeyVault (Key Vault data plane). If not specified, auto-detects from URI.

    .PARAMETER ResourceName
        A friendly name for the resource being loaded, used in verbose/warning messages.

    .PARAMETER Raw
        Return the raw response object (StatusCode, Content) instead of parsed content.
        Used internally for pagination support.

    .OUTPUTS
        [PSObject] The API response content. For collection endpoints, returns the
        'value' array. For single-resource endpoints, returns the full response object.
        Returns nothing on error (unless -ErrorAction Stop is specified).
        With -Raw, returns the response object with StatusCode and Content properties.

    .EXAMPLE
        Invoke-AzureApi -Uri 'https://graph.microsoft.com/v1.0/users' -ResourceName 'Users'

    .EXAMPLE
        Invoke-AzureApi -Uri $armUri -Api ARM -ResourceName 'KeyVaults'

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
        [switch]$Raw
    )

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

    # Helper to invoke REST API with proper error handling
    # Invoke-RestMethod throws HttpResponseException on 4xx/5xx even with -ErrorAction SilentlyContinue
    function Invoke-SafeRestMethod {
        param($Uri, $Headers)
        try {
            $restResponse = Invoke-RestMethod -Uri $Uri -Method GET -Headers $Headers -ErrorAction Stop
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

    # Make the API call based on target API
    switch ($Api) {
        'Graph' {
            if (-not $tokens.GraphToken) {
                $msg = "Graph API call requested but no Graph token available. Run Connect-CIEM first."
                if ($shouldThrow) { throw $msg }
                Write-Warning $msg
                return
            }
            $headers = @{ Authorization = "Bearer $($tokens.GraphToken)" }
            $response = Invoke-SafeRestMethod -Uri $Uri -Headers $headers
        }
        'ARM' {
            if (-not $tokens.ARMToken) {
                # Fall back to Invoke-AzRestMethod which uses Az context
                $response = Invoke-AzRestMethod -Uri $Uri -Method GET
            }
            else {
                $headers = @{ Authorization = "Bearer $($tokens.ARMToken)" }
                $response = Invoke-SafeRestMethod -Uri $Uri -Headers $headers
            }
        }
        'KeyVault' {
            if (-not $tokens.KeyVaultToken) {
                $msg = "KeyVault API call requested but no KeyVault token available. Run Connect-CIEM first."
                if ($shouldThrow) { throw $msg }
                Write-Warning $msg
                return
            }
            $headers = @{ Authorization = "Bearer $($tokens.KeyVaultToken)" }
            $response = Invoke-SafeRestMethod -Uri $Uri -Headers $headers
        }
    }

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

    # Parse and return content
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
        401 {
            $msg = "Unauthorized loading $ResourceName - invalid or expired token"
            if ($shouldThrow) { throw $msg }
            Write-Warning $msg
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
