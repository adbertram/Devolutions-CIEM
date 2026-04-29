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

    $playwrightCli = Join-Path $e2eRoot 'node_modules/@playwright/test/cli.js'
    if (-not (Test-Path $playwrightCli)) {
        throw "Playwright CLI not found: $playwrightCli. Run npm install from $e2eRoot."
    }

    $previousEnvironment = $env:CIEM_TEST_ENVIRONMENT
    $hadPreviousEnvironment = Test-Path Env:CIEM_TEST_ENVIRONMENT
    $previousNoColor = $env:NO_COLOR
    $hadPreviousNoColor = Test-Path Env:NO_COLOR

    try {
        $env:CIEM_TEST_ENVIRONMENT = $Environment
        if (Test-Path Env:NO_COLOR) {
            Remove-Item Env:NO_COLOR
        }

        Push-Location $e2eRoot

        $playwrightArgs = @($playwrightCli, 'test')
        if ($Path) {
            $playwrightArgs += $Path
        }
        if ($Name) {
            $playwrightArgs += @('-g', $Name)
        }

        & node @playwrightArgs
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

        if ($hadPreviousNoColor) {
            $env:NO_COLOR = $previousNoColor
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
