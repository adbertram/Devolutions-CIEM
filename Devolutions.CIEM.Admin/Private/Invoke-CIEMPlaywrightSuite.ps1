function Invoke-CIEMPlaywrightSuite {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('local', 'azure')]
        [string]$Environment,

        [Parameter()]
        [string[]]$Path,

        [Parameter()]
        [string]$Name,

        [Parameter()]
        [string[]]$Tag
    )

    $ErrorActionPreference = 'Stop'

    if ($Tag) {
        throw 'Playwright suite does not support -Tag. Use -Name for a Playwright grep filter.'
    }

    $e2eRoot = Join-Path $script:RepoRoot 'psu-app/ui/e2e'
    if (-not (Test-Path $e2eRoot)) {
        throw "Playwright E2E root not found: $e2eRoot"
    }

    $previousEnvironment = $env:CIEM_TEST_ENVIRONMENT
    $hadPreviousEnvironment = Test-Path Env:CIEM_TEST_ENVIRONMENT

    try {
        $env:CIEM_TEST_ENVIRONMENT = $Environment
        Push-Location $e2eRoot

        $playwrightArgs = @('playwright', 'test')
        if ($Path) {
            $playwrightArgs += $Path
        }
        if ($Name) {
            $playwrightArgs += @('-g', $Name)
        }

        & npx @playwrightArgs
        $exitCode = $global:LASTEXITCODE
    }
    finally {
        Pop-Location
        if ($hadPreviousEnvironment) {
            $env:CIEM_TEST_ENVIRONMENT = $previousEnvironment
        }
        else {
            Remove-Item Env:CIEM_TEST_ENVIRONMENT
        }
    }

    if ($exitCode -ne 0) {
        throw "Playwright suite failed with exit code $exitCode."
    }

    [PSCustomObject]@{
        Suite       = 'Playwright'
        Environment = $Environment
        Framework   = 'Playwright'
        Path        = $Path
        ExitCode    = $exitCode
    }
}
