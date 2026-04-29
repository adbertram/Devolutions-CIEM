function TestGitRemote {
    <#
    .SYNOPSIS
        Verifies the upstream git remote is configured for Prowler.

    .DESCRIPTION
        Checks that the configured upstream remote exists and points to the
        Prowler repository. Throws an error with setup instructions if not configured.

    .OUTPUTS
        [void] - Throws on failure, returns nothing on success.

    .EXAMPLE
        TestGitRemote
        # Verifies upstream remote is configured
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    $ErrorActionPreference = 'Stop'

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "git is required but was not found in PATH."
    }

    $upstreamRemote = 'upstream'
    $remotes = (git remote -v 2>&1) -join "`n"

    if ($remotes -notmatch "(?m)^$upstreamRemote\s.*prowler-cloud/prowler") {
        throw @"
Upstream remote '$upstreamRemote' not configured. Please run:
    git remote add $upstreamRemote https://github.com/prowler-cloud/prowler.git
"@
    }
}
