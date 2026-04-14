function Save-GitHubRepoFile {
    <#
    .SYNOPSIS
        Downloads a single file from a public GitHub repository to disk.

    .DESCRIPTION
        Downloads raw file content from a public GitHub repository using the
        raw.githubusercontent.com URL and saves it to a local path. Automatically
        creates the parent directory if it does not exist.

        By default, non-success responses result in warnings (silent failure).
        Use -ErrorAction Stop to throw terminating errors on non-success responses.

    .PARAMETER Owner
        The GitHub repository owner (user or organization). For example, 'prowler-cloud'.

    .PARAMETER Repo
        The GitHub repository name. For example, 'prowler'.

    .PARAMETER Ref
        The branch name, tag, or commit SHA to download from. Defaults to 'master'.

    .PARAMETER Path
        The file path within the repository. For example,
        'prowler/providers/azure/services/entra/entra_service.py'.

    .PARAMETER Destination
        The local file path to save the downloaded content to.

    .OUTPUTS
        [string] The Destination path on success, for pipeline chaining.
        Returns nothing on error (unless -ErrorAction Stop is specified).

    .EXAMPLE
        Save-GitHubRepoFile -Owner prowler-cloud -Repo prowler -Path 'README.md' -Destination '/tmp/readme.md'
        # Downloads the README from master and saves to /tmp/readme.md.

    .EXAMPLE
        Save-GitHubRepoFile -Owner prowler-cloud -Repo prowler -Ref 'v4.0.0' -Path 'setup.py' -Destination './setup.py' -Verbose
        # Downloads setup.py from the v4.0.0 tag.

    .EXAMPLE
        $file = Save-GitHubRepoFile -Owner prowler-cloud -Repo prowler -Path 'config.yaml' -Destination '/tmp/config.yaml'
        Get-Content $file
        # Downloads and then reads the file via pipeline chaining.
    #>
    [CmdletBinding()]
    [OutputType([string])]
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

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Destination
    )

    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'
    $shouldThrow = $true

    $uri = "https://raw.githubusercontent.com/$Owner/$Repo/$Ref/$Path"
    $headers = @{
        'User-Agent' = 'Devolutions-CIEM'
    }

    Write-Verbose "Downloading $Owner/$Repo/$Path (ref: $Ref) to $Destination..."

    # Create parent directory if it does not exist
    $parentDir = Split-Path -Path $Destination -Parent
    if ($parentDir -and -not (Test-Path -Path $parentDir)) {
        Write-Verbose "Creating directory: $parentDir"
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
    }

    try {
        Invoke-WebRequest -Uri $uri -Headers $headers -OutFile $Destination -ErrorAction Stop
    }
    catch [Microsoft.PowerShell.Commands.HttpResponseException] {
        $statusCode = [int]$_.Exception.Response.StatusCode

        switch ($statusCode) {
            404 {
                $msg = "File not found in repo: $Owner/$Repo/$Path (ref: $Ref)"
                if ($shouldThrow) { throw $msg }
                Write-Warning $msg
                return
            }
            403 {
                $msg = "GitHub rate limit exceeded downloading $Owner/$Repo/$Path. Unauthenticated requests are limited to 60 per hour."
                if ($shouldThrow) { throw $msg }
                Write-Warning $msg
                return
            }
            default {
                $msg = "GitHub download error ($statusCode) for $Owner/$Repo/$Path"
                if ($shouldThrow) { throw $msg }
                Write-Warning $msg
                return
            }
        }
    }
    catch {
        $msg = "Failed to download $Owner/$Repo/${Path}: $_"
        if ($shouldThrow) { throw $msg }
        Write-Warning $msg
        return
    }

    Write-Verbose "Saved to $Destination"
    $Destination
}
