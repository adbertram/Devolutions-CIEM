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

    function ConvertToHeaderMap {
        param(
            [Parameter()]
            [object]$HeaderSource
        )

        $ErrorActionPreference = 'Stop'

        $headerMap = @{}
        if (-not $HeaderSource) {
            return $headerMap
        }

        if ($HeaderSource -is [System.Net.Http.Headers.HttpHeaders]) {
            foreach ($entry in $HeaderSource) {
                $headerMap[([string]$entry.Key).ToLowerInvariant()] = (@($entry.Value) | ForEach-Object { [string]$_ }) -join ','
            }
            return $headerMap
        }

        if ($HeaderSource -is [System.Collections.IDictionary]) {
            foreach ($key in @($HeaderSource.Keys)) {
                if ($null -eq $key) {
                    continue
                }

                $value = $HeaderSource[$key]
                if ($null -eq $value) {
                    continue
                }

                $normalizedKey = ([string]$key).ToLowerInvariant()
                $headerMap[$normalizedKey] = if ($value -is [System.Array]) {
                    @($value) -join ','
                }
                else {
                    [string]$value
                }
            }
            return $headerMap
        }

        foreach ($property in $HeaderSource.PSObject.Properties) {
            if ($null -eq $property.Value) {
                continue
            }

            $normalizedKey = ([string]$property.Name).ToLowerInvariant()
            $headerMap[$normalizedKey] = if ($property.Value -is [System.Array]) {
                @($property.Value) -join ','
            }
            else {
                [string]$property.Value
            }
        }

        $headerMap
    }

    function GetHeaderValue {
        param(
            [Parameter()]
            [hashtable]$Headers,
            [Parameter(Mandatory)]
            [string]$Name
        )

        $ErrorActionPreference = 'Stop'

        if (-not $Headers) {
            return $null
        }

        $lookupName = $Name.ToLowerInvariant()
        if ($Headers.ContainsKey($lookupName)) {
            return $Headers[$lookupName]
        }

        $null
    }

    function ConvertErrorBodyToObject {
        param(
            [Parameter()]
            [string]$ErrorText
        )

        $ErrorActionPreference = 'Stop'

        if (-not $ErrorText) {
            return $null
        }

        # Error responses may be free-form text in rare cases (e.g., HTML error pages
        # from intermediary proxies). Try JSON first and wrap raw text in a
        # pscustomobject so the downstream shape is consistent with the success path.
        try {
            return ($ErrorText | ConvertFrom-Json -ErrorAction Stop)
        }
        catch [System.ArgumentException], [System.Text.Json.JsonException] {
            return [pscustomobject]@{ rawText = $ErrorText }
        }
    }

    function InvokeSafeRestMethod {
        param(
            [Parameter(Mandatory)]
            [string]$RequestUri,
            [Parameter(Mandatory)]
            [hashtable]$RequestHeaders,
            [Parameter(Mandatory)]
            [string]$RequestMethod,
            [Parameter()]
            [string]$JsonBody
        )

        $ErrorActionPreference = 'Stop'

        try {
            $responseHeaders = $null
            $restParams = @{
                Uri                     = $RequestUri
                Method                  = $RequestMethod
                Headers                 = $RequestHeaders
                ErrorAction             = 'Stop'
                ResponseHeadersVariable = 'responseHeaders'
            }

            if ($JsonBody) {
                $restParams.Body = $JsonBody
                $restParams.ContentType = 'application/json'
            }

            $restResponse = Invoke-RestMethod @restParams

            [pscustomobject]@{
                StatusCode = 200
                Body = $restResponse
                Headers = ConvertToHeaderMap -HeaderSource $responseHeaders
            }
        }
        catch [Microsoft.PowerShell.Commands.HttpResponseException] {
            $errorRecord = $_
            $errorText = $null
            if ($errorRecord.ErrorDetails -and $errorRecord.ErrorDetails.Message) {
                $errorText = $errorRecord.ErrorDetails.Message
            }

            [pscustomobject]@{
                StatusCode = [int]$errorRecord.Exception.Response.StatusCode
                Body = ConvertErrorBodyToObject -ErrorText $errorText
                Headers = ConvertToHeaderMap -HeaderSource $errorRecord.Exception.Response.Headers
            }
        }
        catch {
            [pscustomobject]@{
                StatusCode = 0
                Body = [pscustomobject]@{ rawText = $_.Exception.Message }
                Headers = @{}
            }
        }
    }

    function GetRetryDelaySeconds {
        param(
            [Parameter(Mandatory)]
            [object]$Response,
            [Parameter(Mandatory)]
            [int]$RetryAttempt
        )

        $ErrorActionPreference = 'Stop'

        # Cast to double so [Math]::Min picks the double overload. Otherwise
        # [Math]::Min(60, 1.2) picks the int overload and returns 1.
        [double]$maxDelay = 60

        $retryAfterHeader = GetHeaderValue -Headers $Response.Headers -Name 'Retry-After'
        if ($retryAfterHeader) {
            $parsedRetryAfter = $null
            if ([System.Net.Http.Headers.RetryConditionHeaderValue]::TryParse($retryAfterHeader, [ref]$parsedRetryAfter)) {
                if ($parsedRetryAfter.Delta -and $parsedRetryAfter.Delta.TotalSeconds -gt 0) {
                    return [Math]::Min($maxDelay, [math]::Ceiling($parsedRetryAfter.Delta.TotalSeconds))
                }

                if ($parsedRetryAfter.Date) {
                    $headerDelay = [math]::Ceiling(($parsedRetryAfter.Date - [DateTimeOffset]::UtcNow).TotalSeconds)
                    if ($headerDelay -gt 0) {
                        return [Math]::Min($maxDelay, $headerDelay)
                    }
                }
            }
        }

        # Body-level retryAfter (already parsed by InvokeSafeRestMethod / ConvertErrorBodyToObject)
        if ($Response.Body -and $Response.Body.PSObject.Properties.Name -contains 'retryAfter') {
            $bodyDelay = [double]$Response.Body.retryAfter
            if ($bodyDelay -gt 0) {
                return [Math]::Min($maxDelay, $bodyDelay)
            }
        }

        $baseDelay = [math]::Pow(2, $RetryAttempt - 1)
        $jitter = Get-Random -Minimum 0.8 -Maximum 1.2
        [Math]::Min($maxDelay, [math]::Round($baseDelay * $jitter, 2))
    }

    function InvokeAzureRequestWithRetry {
        param(
            [Parameter(Mandatory)]
            [string]$RequestUri,
            [Parameter(Mandatory)]
            [hashtable]$RequestHeaders,
            [Parameter(Mandatory)]
            [string]$RequestMethod,
            [Parameter()]
            [string]$JsonBody,
            [Parameter(Mandatory)]
            [string]$FriendlyName
        )

        $ErrorActionPreference = 'Stop'

        $maxRetries = 5
        $retryAttempts = 0

        while ($true) {
            $response = InvokeSafeRestMethod -RequestUri $RequestUri -RequestHeaders $RequestHeaders -RequestMethod $RequestMethod -JsonBody $JsonBody
            if ($response.StatusCode -ne 429) {
                return $response
            }

            if ($retryAttempts -ge $maxRetries) {
                throw "Failed to load $FriendlyName - retries exhausted after $maxRetries retries."
            }

            $retryAttempts++
            $retryDelay = GetRetryDelaySeconds -Response $response -RetryAttempt $retryAttempts
            Write-Verbose "[$FriendlyName] Rate limited (429). Retry $retryAttempts of $maxRetries after ${retryDelay}s..."
            InvokeCIEMAzureSleep -Seconds $retryDelay
        }
    }

    function GetParsedErrorMessage {
        param(
            [Parameter()]
            [object]$Body
        )

        $ErrorActionPreference = 'Stop'

        if (-not $Body) {
            return $null
        }

        if ($Body -is [string]) {
            return $Body
        }

        if ($Body.PSObject.Properties.Name -contains 'rawText' -and $Body.rawText) {
            return [string]$Body.rawText
        }

        if ($Body.PSObject.Properties.Name -contains 'error' -and $Body.error) {
            if ($Body.error.PSObject.Properties.Name -contains 'message') {
                return [string]$Body.error.message
            }
        }

        $Body | ConvertTo-Json -Depth 20 -Compress
    }

    function AssertSuccessfulAzureResponse {
        param(
            [Parameter(Mandatory)]
            [object]$Response,
            [Parameter(Mandatory)]
            [string]$FriendlyName
        )

        $ErrorActionPreference = 'Stop'

        $statusCode = [int]$Response.StatusCode
        if ($statusCode -ge 200 -and $statusCode -lt 300) {
            return
        }

        if ($statusCode -eq 401) {
            throw "Unauthorized loading $FriendlyName - invalid or expired token"
        }
        if ($statusCode -eq 403) {
            throw "Access denied loading $FriendlyName - missing permissions"
        }
        if ($statusCode -eq 404) {
            throw "Resource not found: $FriendlyName"
        }
        if ($statusCode -eq 0) {
            $detail = GetParsedErrorMessage -Body $Response.Body
            if (-not $detail) { $detail = 'Unknown error' }
            throw "Failed to load $FriendlyName - $detail"
        }

        $detail = GetParsedErrorMessage -Body $Response.Body
        $msg = "Failed to load $FriendlyName - Status: $statusCode"
        if ($detail) {
            $msg += " - $detail"
        }
        throw $msg
    }

    function ConvertToSkipTokenBody {
        # Takes the previous POST body (hashtable or pscustomobject) and returns
        # a fresh hashtable with $skipToken appended, suitable for re-serialization.
        # This is used by Azure Resource Graph pagination where the next page is
        # requested by re-posting the original body plus a $skipToken field.
        param(
            [Parameter()]
            [object]$BodyObject,
            [Parameter(Mandatory)]
            [string]$SkipToken
        )

        $ErrorActionPreference = 'Stop'

        $nextBody = if ($BodyObject) {
            # Round-trip via JSON so we get a detached hashtable we can mutate
            # without disturbing the caller's original object.
            $BodyObject | ConvertTo-Json -Depth 20 -Compress | ConvertFrom-Json -AsHashtable
        }
        else {
            @{}
        }

        $nextBody['$skipToken'] = $SkipToken
        $nextBody
    }

    function InvokeAzureBatchRequests {
        param(
            [Parameter(Mandatory)]
            [AllowEmptyCollection()]
            [hashtable[]]$BatchRequests,
            [Parameter(Mandatory)]
            [string]$BatchApi,
            [Parameter(Mandatory)]
            [hashtable]$BatchHeaders,
            [Parameter(Mandatory)]
            [string]$BatchResourceName
        )

        $ErrorActionPreference = 'Stop'

        if (@($BatchRequests).Count -eq 0) {
            throw 'Invoke-AzureApi batch mode requires at least one batch request.'
        }

        if ($BatchApi -notin @('Graph', 'GraphBeta')) {
            throw "Invoke-AzureApi batch mode supports Graph APIs only. Received '$BatchApi'."
        }

        $batchEndpoint = (GetCIEMAzureProviderApi -Name $BatchApi).BaseUrl.TrimEnd('/')
        $batchUri = "$batchEndpoint/`$batch"
        $results = @{}

        $wallClockCapSeconds = if ($script:CIEMGraphBatchWallClockSeconds -and $script:CIEMGraphBatchWallClockSeconds -gt 0) {
            $script:CIEMGraphBatchWallClockSeconds
        }
        else {
            300
        }

        for ($offset = 0; $offset -lt $BatchRequests.Count; $offset += $script:CIEMGraphBatchSize) {
            $remaining = $BatchRequests.Count - $offset
            $chunkSize = [Math]::Min($script:CIEMGraphBatchSize, $remaining)
            $pendingRequests = @(
                for ($i = $offset; $i -lt $offset + $chunkSize; $i++) {
                    $BatchRequests[$i]
                }
            )
            $retryAttempts = @{}
            $chunkStart = [DateTimeOffset]::UtcNow

            while ($pendingRequests.Count -gt 0) {
                if (([DateTimeOffset]::UtcNow - $chunkStart).TotalSeconds -ge $wallClockCapSeconds) {
                    throw "Failed to load $BatchResourceName batch - wall-clock retry budget ($wallClockCapSeconds s) exceeded."
                }

                $payloadRequests = foreach ($request in $pendingRequests) {
                    if (-not $request.Id) {
                        throw 'Invoke-AzureApi batch requests must include Id.'
                    }
                    if (-not $request.Method) {
                        throw "Invoke-AzureApi batch request '$($request.Id)' is missing Method."
                    }
                    if (-not $request.Path) {
                        throw "Invoke-AzureApi batch request '$($request.Id)' is missing Path."
                    }

                    @{
                        id = [string]$request.Id
                        method = [string]$request.Method
                        url = $request.Path.TrimStart('/')
                    }
                }

                $payload = @{
                    requests = $payloadRequests
                }

                $payloadJson = $payload | ConvertTo-Json -Depth 20 -Compress
                $batchResponse = InvokeAzureRequestWithRetry -RequestUri $batchUri -RequestHeaders $BatchHeaders -RequestMethod 'POST' -JsonBody $payloadJson -FriendlyName "$BatchResourceName batch"

                if ($batchResponse.StatusCode -ne 200) {
                    $errorDetail = GetParsedErrorMessage -Body $batchResponse.Body
                    throw "Failed to load $BatchResourceName batch - Status: $($batchResponse.StatusCode) - $errorDetail"
                }

                $parsedBatchResponse = $batchResponse.Body
                if (-not $parsedBatchResponse -or -not ($parsedBatchResponse.PSObject.Properties.Name -contains 'responses')) {
                    throw "Failed to load $BatchResourceName batch - malformed batch response."
                }

                $subResponsesById = @{}
                foreach ($subResponse in @($parsedBatchResponse.responses)) {
                    $subResponsesById[[string]$subResponse.id] = $subResponse
                }

                $nextPending = [System.Collections.Generic.List[hashtable]]::new()
                $retryDelays = [System.Collections.Generic.List[double]]::new()

                foreach ($request in $pendingRequests) {
                    $requestId = [string]$request.Id
                    if (-not $subResponsesById.ContainsKey($requestId)) {
                        throw "Failed to load $BatchResourceName batch - missing response for request '$requestId'."
                    }

                    $subResponse = $subResponsesById[$requestId]
                    $statusCode = [int]$subResponse.status

                    if ($statusCode -eq 429) {
                        $currentRetryCount = if ($retryAttempts.ContainsKey($requestId)) { $retryAttempts[$requestId] } else { 0 }
                        if ($currentRetryCount -ge 5) {
                            throw "Failed to load $BatchResourceName - batch sub-request '$requestId' retries exhausted."
                        }

                        $retryAttempts[$requestId] = $currentRetryCount + 1
                        $retryResponse = [pscustomobject]@{
                            StatusCode = 429
                            Body = $subResponse.body
                            Headers = ConvertToHeaderMap -HeaderSource $subResponse.headers
                        }
                        $retryDelays.Add((GetRetryDelaySeconds -Response $retryResponse -RetryAttempt $retryAttempts[$requestId]))
                        $nextPending.Add($request)
                        continue
                    }

                    $subBody = $subResponse.body
                    if ($statusCode -lt 200 -or $statusCode -ge 300) {
                        $results[$requestId] = [pscustomobject]@{
                            Id = $requestId
                            Success = $false
                            StatusCode = $statusCode
                            Items = @()
                            Content = $subBody
                            Error = GetParsedErrorMessage -Body $subBody
                        }
                        continue
                    }

                    $items = @()
                    if ($subBody) {
                        if ($subBody.PSObject.Properties.Name -contains 'value') {
                            $items = @($subBody.value)
                        }
                        elseif ($subBody -is [System.Array]) {
                            $items = @($subBody)
                        }
                        else {
                            $items = @($subBody)
                        }

                        if ($subBody.PSObject.Properties.Name -contains '@odata.nextLink' -and $subBody.'@odata.nextLink') {
                            $items += @(Invoke-AzureApi -Uri $subBody.'@odata.nextLink' -Api $BatchApi -ResourceName "$BatchResourceName/$requestId" -ErrorAction Stop)
                        }
                    }

                    $results[$requestId] = [pscustomobject]@{
                        Id = $requestId
                        Success = $true
                        StatusCode = $statusCode
                        Items = @($items)
                        Content = $subBody
                        Error = $null
                    }
                }

                if ($nextPending.Count -gt 0) {
                    $sleepSeconds = ($retryDelays | Measure-Object -Maximum).Maximum
                    if ($sleepSeconds -gt 0) {
                        InvokeCIEMAzureSleep -Seconds $sleepSeconds
                    }
                    $pendingRequests = @($nextPending.ToArray())
                    continue
                }

                break
            }
        }

        $results
    }

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
