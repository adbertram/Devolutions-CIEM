function Get-GitHubRepoTree {
    <#
    .SYNOPSIS
        Lists files in a public GitHub repository using the Trees API.

    .DESCRIPTION
        Retrieves the full file tree of a public GitHub repository via the Git Trees API
        with recursive listing. Optionally filters results to paths starting with a given
        prefix. No authentication is required, but unauthenticated requests are limited
        to 60 per hour.

        By default, non-success responses result in warnings (silent failure).
        Use -ErrorAction Stop to throw terminating errors on non-success responses.

    .PARAMETER Owner
        The GitHub repository owner (user or organization). For example, 'prowler-cloud'.

    .PARAMETER Repo
        The GitHub repository name. For example, 'prowler'.

    .PARAMETER Ref
        The branch name, tag, or commit SHA to list. Defaults to 'master'.

    .PARAMETER Path
        Optional path prefix to filter results. Only entries whose path starts with this
        value are returned. For example, 'prowler/providers/azure'.

    .OUTPUTS
        [PSCustomObject[]] Objects with Path (string), Type (blob|tree), and Size (int) properties.
        Returns nothing on error (unless -ErrorAction Stop is specified).

    .EXAMPLE
        Get-GitHubRepoTree -Owner prowler-cloud -Repo prowler
        # Lists all files and directories in the prowler repo at the master branch.

    .EXAMPLE
        Get-GitHubRepoTree -Owner prowler-cloud -Repo prowler -Path 'prowler/providers/azure/services/entra' -Verbose
        # Lists only entries under the entra services directory.

    .EXAMPLE
        Get-GitHubRepoTree -Owner prowler-cloud -Repo prowler -Ref 'v4.0.0' -ErrorAction Stop
        # Lists files at tag v4.0.0, throwing on any error.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Owner,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Repo,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Ref = 'master',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    # Capture caller's ErrorAction before we override
    $shouldThrow = $ErrorActionPreference -eq 'Stop'

    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    # Check cache first - key is Owner/Repo/Ref, stores full tree to avoid repeated API calls
    $cacheKey = "$Owner/$Repo/$Ref"
    if ($script:GitHubTreeCache.ContainsKey($cacheKey)) {
        Write-Verbose "Using cached tree for $cacheKey"
        $tree = $script:GitHubTreeCache[$cacheKey]
    }
    else {
        $uri = "https://api.github.com/repos/$Owner/$Repo/git/trees/${Ref}?recursive=1"
        $headers = @{
            'User-Agent' = 'Devolutions-CIEM'
            'Accept'     = 'application/vnd.github+json'
        }

        Write-Verbose "Fetching tree for $Owner/$Repo at ref '$Ref'..."

        try {
            $response = Invoke-RestMethod -Uri $uri -Headers $headers -ErrorAction Stop
        }
        catch [Microsoft.PowerShell.Commands.HttpResponseException] {
            $statusCode = [int]$_.Exception.Response.StatusCode

            switch ($statusCode) {
                403 {
                    $msg = "GitHub API rate limit exceeded for $Owner/$Repo. Unauthenticated requests are limited to 60 per hour."
                    if ($shouldThrow) { throw $msg }
                    Write-Warning $msg
                    return
                }
                404 {
                    $msg = "Repository not found: $Owner/$Repo (ref: $Ref)"
                    if ($shouldThrow) { throw $msg }
                    Write-Warning $msg
                    return
                }
                default {
                    $msg = "GitHub API error ($statusCode) fetching tree for $Owner/$Repo"
                    if ($shouldThrow) { throw $msg }
                    Write-Warning $msg
                    return
                }
            }
        }
        catch {
            $msg = "Failed to fetch GitHub tree for $Owner/${Repo}: $_"
            if ($shouldThrow) { throw $msg }
            Write-Warning $msg
            return
        }

        if ($response.truncated) {
            Write-Warning "GitHub tree response was truncated. The repository $Owner/$Repo has more files than the API can return in a single request."
        }

        $tree = $response.tree
        $script:GitHubTreeCache[$cacheKey] = $tree
        Write-Verbose "Cached tree for $cacheKey ($($tree.Count) entries)"
    }

    # Filter by path prefix if specified
    if ($Path) {
        $normalizedPath = $Path.TrimEnd('/')
        $tree = $tree | Where-Object { $_.path -like "$normalizedPath/*" -or $_.path -eq $normalizedPath }
        Write-Verbose "Filtered to $($tree.Count) entries matching prefix '$normalizedPath'"
    }

    foreach ($item in $tree) {
        [PSCustomObject]@{
            Path = $item.path
            Type = $item.type
            Size = if ($item.PSObject.Properties['size']) { $item.size } else { $null }
        }
    }
}
