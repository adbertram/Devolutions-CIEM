function SaveGitHubRepoSparseCheckout {
    <#
    .SYNOPSIS
        Clones a GitHub repo using sparse checkout to download only specified paths.

    .DESCRIPTION
        Uses git sparse checkout with --depth 1 --filter=blob:none to efficiently
        download only the requested directory paths from a GitHub repository. This is
        dramatically faster than per-file HTTP downloads for bulk operations.

        The clone fetches only commit metadata (~2.4MB for prowler), then
        sparse-checkout downloads only the requested paths' blobs via pack protocol.

    .PARAMETER Owner
        The GitHub repository owner (user or organization).

    .PARAMETER Repo
        The GitHub repository name.

    .PARAMETER Ref
        Branch name or tag to clone from. Defaults to 'master'.
        Note: commit SHAs are not supported (use branch/tag names).

    .PARAMETER Paths
        Array of repo-relative directory paths to include in the sparse checkout.
        For example: @('prowler/providers/aws/services/iam', 'prowler/providers/azure')

    .PARAMETER Destination
        Local directory path for the clone. Auto-generated temp path if not specified.

    .OUTPUTS
        [string] The clone directory path.

    .EXAMPLE
        SaveGitHubRepoSparseCheckout -Owner prowler-cloud -Repo prowler -Paths 'prowler/providers/aws'
        # Clones only the AWS provider directory (~7MB, ~2s)

    .EXAMPLE
        SaveGitHubRepoSparseCheckout -Owner prowler-cloud -Repo prowler -Paths @('prowler/providers/aws/services/iam', 'prowler/providers/aws/services/s3') -Destination /tmp/prowler-sparse
        # Clones only IAM and S3 service directories
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
        [string[]]$Paths,

        [Parameter()]
        [string]$Destination
    )

    $ErrorActionPreference = 'Stop'

    # Verify git is available
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "git is required for sparse checkout but was not found in PATH."
    }

    # Generate destination if not specified
    if (-not $Destination) {
        $Destination = Join-Path ([System.IO.Path]::GetTempPath()) "ciem-sparse-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    }

    $repoUrl = "https://github.com/$Owner/$Repo.git"

    Write-Verbose "Sparse checkout: $Owner/$Repo (ref: $Ref)"
    Write-Verbose "  Paths: $($Paths -join ', ')"
    Write-Verbose "  Destination: $Destination"

    # Clone with depth 1, blob filter, sparse checkout
    $cloneOutput = & git clone --depth 1 --filter=blob:none --sparse --branch $Ref $repoUrl $Destination 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git clone failed (exit code $LASTEXITCODE): $cloneOutput"
    }

    # Set sparse checkout to requested paths
    $sparseOutput = & git -C $Destination sparse-checkout set @Paths 2>&1
    if ($LASTEXITCODE -ne 0) {
        # Clean up failed clone
        Remove-Item $Destination -Recurse -Force -ErrorAction SilentlyContinue
        throw "git sparse-checkout set failed (exit code $LASTEXITCODE): $sparseOutput"
    }

    Write-Verbose "Sparse checkout complete at: $Destination"
    $Destination
}
