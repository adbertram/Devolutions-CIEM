function Invoke-AzureApi {
    <#
    .SYNOPSIS
        Invokes Azure REST API (ARM, Graph, or KeyVault) with standardized error handling.

    .DESCRIPTION
        Single point of entry for all Azure API calls. Handles authentication
        internally - callers should not deal with tokens or auth logic.

        Supports three calling patterns:
        - ByUri: Pass a full URL via -Uri
        - ByPath: Pass a relative path via -Path with a mandatory -Api selector
        - Batch: Pass Graph sub-requests via -Requests to call Microsoft Graph $batch

    .PARAMETER Uri
        Full API URL (ByUri set). Mutually exclusive with -Path and -Requests.

    .PARAMETER Path
        Relative path appended to the base URL resolved from azure_provider_apis.

    .PARAMETER Requests
        Graph batch sub-requests. Each entry must have Id, Method, and Path.

    .PARAMETER Api
        Target API selector (ARM, Graph, GraphBeta, KeyVault). Mandatory for
        all parameter sets — the old URI host auto-detection path has been
        removed.

    .PARAMETER ResourceName
        Friendly resource name used in error messages.

    .PARAMETER Method
        HTTP method for ByUri/ByPath calls. Defaults to GET.

    .PARAMETER Body
        Hashtable/PSCustomObject request body for POST/PUT/PATCH.

    .PARAMETER Raw
        Return the raw response envelope with StatusCode/Body/Headers instead of
        unwrapping paginated `value`/`data` collections.
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

        [Parameter(Mandatory, ParameterSetName = 'Batch')]
        [AllowEmptyCollection()]
        [hashtable[]]$Requests,

        [Parameter(Mandatory, ParameterSetName = 'ByUri')]
        [Parameter(Mandatory, ParameterSetName = 'ByPath')]
        [Parameter(Mandatory, ParameterSetName = 'Batch')]
        [ValidateSet('ARM', 'Graph', 'GraphBeta', 'KeyVault')]
        [string]$Api,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceName,

        [Parameter(ParameterSetName = 'ByUri')]
        [Parameter(ParameterSetName = 'ByPath')]
        [ValidateSet('GET', 'POST', 'PUT', 'PATCH', 'DELETE')]
        [string]$Method = 'GET',

        [Parameter(ParameterSetName = 'ByUri')]
        [Parameter(ParameterSetName = 'ByPath')]
        [object]$Body,

        [Parameter(ParameterSetName = 'ByUri')]
        [Parameter(ParameterSetName = 'ByPath')]
        [switch]$Raw
    )

    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    if ($PSCmdlet.ParameterSetName -eq 'ByPath') {
        $apiRecord = GetCIEMAzureProviderApi -Name $Api
        if (-not $apiRecord) {
            throw "No API endpoint record found for '$Api' in azure_provider_apis table."
        }

        $baseUrl = $apiRecord.BaseUrl.TrimEnd('/')
        $Uri = "$baseUrl/$($Path.TrimStart('/'))"
    }

    if (-not $script:AzureAuthContext -or -not $script:AzureAuthContext.IsConnected) {
        throw 'Not connected to Azure. Run Connect-CIEM first.'
    }

    $jsonBody = $null
    if ($Body) {
        $jsonBody = $Body | ConvertTo-Json -Depth 20 -Compress
    }

    $tokenPropertyMap = @{
        'Graph'     = 'GraphToken'
        'GraphBeta' = 'GraphToken'
        'ARM'       = 'ARMToken'
        'KeyVault'  = 'KeyVaultToken'
    }
    $token = $script:AzureAuthContext.($tokenPropertyMap[$Api])

    if (-not $token) {
        throw "$Api API call requested but no $Api token available. Run Connect-CIEM first."
    }

    $headers = @{ Authorization = "Bearer $token" }

    if ($PSCmdlet.ParameterSetName -eq 'Batch') {
        return InvokeAzureBatchRequests -BatchRequests $Requests -BatchApi $Api -BatchHeaders $headers -BatchResourceName $ResourceName
    }

    Write-Verbose "Loading $ResourceName..."

    $currentUri = $Uri
    $currentMethod = $Method
    $currentJsonBody = $jsonBody
    $currentBodyObject = $Body
    $pageCount = 0
    $lastNextLink = $null
    $hasWrittenPaginationProgress = $false

    try {
        while ($currentUri) {
            $currentResponse = InvokeAzureRequestWithRetry -RequestUri $currentUri -RequestHeaders $headers -RequestMethod $currentMethod -JsonBody $currentJsonBody -FriendlyName $ResourceName
            AssertSuccessfulAzureResponse -Response $currentResponse -FriendlyName $ResourceName

            if ($Raw) {
                return $currentResponse
            }

            $statusCode = [int]$currentResponse.StatusCode

            if ($statusCode -eq 200) {
                $content = $currentResponse.Body
                if (-not $content) {
                    $currentUri = $null
                    continue
                }

                $pageCount++
                $isValueCollection = $content.PSObject.Properties.Name -contains 'value'
                $isDataCollection = $content.PSObject.Properties.Name -contains 'data'

                if (-not ($isValueCollection -or $isDataCollection)) {
                    # Single-object response — emit and exit the loop
                    $content
                    $currentUri = $null
                    continue
                }

                $items = if ($isValueCollection) { @($content.value) } else { @($content.data) }
                $nextLink = if ($content.PSObject.Properties.Name -contains '@odata.nextLink') {
                    $content.'@odata.nextLink'
                }
                elseif ($content.PSObject.Properties.Name -contains 'nextLink') {
                    $content.nextLink
                }
                else {
                    $null
                }

                if ($items.Count -eq 0 -and $nextLink) {
                    $currentUri = $null
                    continue
                }

                if ($nextLink) {
                    if ($lastNextLink -and $nextLink -eq $lastNextLink) {
                        throw "Failed to load $ResourceName - pagination cycle detected at '$nextLink'."
                    }

                    $lastNextLink = $nextLink
                    $hasWrittenPaginationProgress = $true
                    Write-Progress -Activity "Loading $ResourceName" -Status "Page $pageCount" -CurrentOperation $nextLink
                }
                elseif ($hasWrittenPaginationProgress) {
                    Write-Progress -Activity "Loading $ResourceName" -Status "Page $pageCount"
                }

                $items

                if ($nextLink) {
                    $currentUri = $nextLink
                    $currentMethod = 'GET'
                    $currentJsonBody = $null
                    continue
                }

                if ($content.PSObject.Properties.Name -contains '$skipToken' -and $content.'$skipToken' -and $currentMethod -eq 'POST') {
                    $currentBodyObject = ConvertToSkipTokenBody -BodyObject $currentBodyObject -SkipToken $content.'$skipToken'
                    $currentJsonBody = $currentBodyObject | ConvertTo-Json -Depth 20 -Compress
                    $hasWrittenPaginationProgress = $true
                    Write-Progress -Activity "Loading $ResourceName" -Status "Page $pageCount"
                    continue
                }

                $currentUri = $null
                continue
            }

            $currentUri = $null
        }
    }
    finally {
        if ($hasWrittenPaginationProgress) {
            Write-Progress -Activity "Loading $ResourceName" -Completed
        }
    }
}
