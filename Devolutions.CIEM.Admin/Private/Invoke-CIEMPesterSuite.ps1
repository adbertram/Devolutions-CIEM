function InvokeCIEMPesterSuite {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Unit', 'E2E')]
        [string]$Suite,

        [Parameter(Mandatory)]
        [ValidateSet('local', 'azure')]
        [string]$Environment,

        [Parameter()]
        [string[]]$Path,

        [Parameter()]
        [string]$Name,

        [Parameter()]
        [string[]]$Tag,

        [Parameter()]
        [ValidateSet('Normal', 'Detailed', 'Diagnostic')]
        [string]$Output = 'Detailed'
    )

    $ErrorActionPreference = 'Stop'

    try {
        $null = Get-Command Invoke-Pester -ErrorAction Stop
    }
    catch {
        throw 'Invoke-Pester is required to run CIEM Pester suites.'
    }

    $resolvedPaths = @(GetCIEMTestPath -Suite $Suite -Path $Path)
    $summaryPath = Join-Path ([System.IO.Path]::GetTempPath()) "ciem-pester-$([guid]::NewGuid()).json"

    $pathsJson = ConvertTo-Json -InputObject @($resolvedPaths) -Compress
    $nameJson = ConvertTo-Json -InputObject $Name -Compress
    $tagJson = if ($Tag) { ConvertTo-Json -InputObject @($Tag) -Compress } else { '[]' }

    $environmentLine = if ($Suite -eq 'E2E') {
        "`$env:CIEM_TEST_ENVIRONMENT = '$Environment'"
    }
    else {
        ''
    }

    $childScript = @"
`$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath @'
$script:RepoRoot
'@
$environmentLine

`$paths = @'
$pathsJson
'@ | ConvertFrom-Json
`$name = @'
$nameJson
'@ | ConvertFrom-Json
`$tags = @'
$tagJson
'@ | ConvertFrom-Json

`$configuration = New-PesterConfiguration
`$configuration.Run.Path = @(`$paths)
`$configuration.Run.PassThru = `$true
`$configuration.Run.Exit = `$false
`$configuration.Run.Throw = `$false
`$configuration.Output.Verbosity = '$Output'

if (`$null -ne `$name -and `$name.Length -gt 0) {
    `$configuration.Filter.FullName = `$name
}

if (`$null -ne `$tags -and @(`$tags).Count -gt 0) {
    `$configuration.Filter.Tag = @(`$tags)
}

`$result = Invoke-Pester -Configuration `$configuration
`$summary = [PSCustomObject]@{
    PassedCount = `$result.PassedCount
    FailedCount = `$result.FailedCount
    FailedBlocksCount = `$result.FailedBlocksCount
    FailedContainersCount = `$result.FailedContainersCount
    SkippedCount = `$result.SkippedCount
}
`$summary | ConvertTo-Json -Depth 5 | Set-Content -Path @'
$summaryPath
'@

if (`$result.FailedCount -gt 0 -or `$result.FailedBlocksCount -gt 0 -or `$result.FailedContainersCount -gt 0) {
    exit 1
}
"@

    $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($childScript))

    & pwsh -NoProfile -OutputFormat Text -EncodedCommand $encodedCommand
    $exitCode = $global:LASTEXITCODE

    if (-not (Test-Path $summaryPath)) {
        throw "Pester suite '$Suite' did not write a result summary. Child process exit code: $exitCode."
    }

    try {
        $summary = Get-Content $summaryPath -Raw | ConvertFrom-Json
    }
    finally {
        if (Test-Path $summaryPath) {
            Remove-Item $summaryPath
        }
    }

    if ($exitCode -ne 0) {
        throw "Pester suite '$Suite' failed: $($summary.FailedCount) test(s), $($summary.FailedBlocksCount) block(s), $($summary.FailedContainersCount) container(s)."
    }

    [PSCustomObject]@{
        Suite                 = $Suite
        Environment           = if ($Suite -eq 'E2E') { $Environment } else { $null }
        Framework             = 'Pester'
        Path                  = $resolvedPaths
        PassedCount           = $summary.PassedCount
        FailedCount           = $summary.FailedCount
        FailedBlocksCount     = $summary.FailedBlocksCount
        FailedContainersCount = $summary.FailedContainersCount
        SkippedCount          = $summary.SkippedCount
        ExitCode              = $exitCode
    }
}
