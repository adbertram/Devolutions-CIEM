function Invoke-CIEMTest {
    <#
    .SYNOPSIS
        Runs CIEM test suites through one standardized entry point.

    .DESCRIPTION
        Centralizes local versus Azure test targeting. E2E and Playwright tests
        use explicit suite names and use -Environment to select the PSU target.

    .PARAMETER Suite
        Test suite to run: Unit, E2E, or Playwright.

    .PARAMETER Environment
        PSU target for environment-aware suites. Defaults to local.

    .PARAMETER Path
        Optional test path override. Relative paths resolve from the repo root for
        Pester and from psu-app/ui/e2e for Playwright.

    .PARAMETER Name
        Pester FullName filter or Playwright grep filter.

    .PARAMETER Tag
        Pester tag filter.

    .PARAMETER ScriptBlock
        Optional E2E runtime command to execute through Invoke-TestCommand.

    .PARAMETER Command
        Optional E2E runtime command string. Use this from scripts/invoke-ciem-tests.ps1
        when calling through pwsh -File.

    .EXAMPLE
        Invoke-CIEMTest -Suite Unit

    .EXAMPLE
        Invoke-CIEMTest -Suite E2E -Environment azure

    .EXAMPLE
        Invoke-CIEMTest -Suite E2E -Environment local -ScriptBlock { Get-CIEMProvider }

    .EXAMPLE
        Invoke-CIEMTest -Suite E2E -Environment azure -Command 'Get-CIEMProvider'
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateSet('Unit', 'E2E', 'Playwright')]
        [string]$Suite = 'Unit',

        [Parameter()]
        [ValidateSet('local', 'azure')]
        [string]$Environment = 'local',

        [Parameter()]
        [string[]]$Path,

        [Parameter()]
        [string]$Name,

        [Parameter()]
        [string[]]$Tag,

        [Parameter()]
        [ValidateSet('Normal', 'Detailed', 'Diagnostic')]
        [string]$Output = 'Detailed',

        [Parameter()]
        [scriptblock]$ScriptBlock,

        [Parameter()]
        [string]$Command,

        [Parameter()]
        [int]$TimeoutSeconds = 120
    )

    $ErrorActionPreference = 'Stop'

    switch ($Suite) {
        'Unit' {
            if ($ScriptBlock -or $Command) {
                throw 'Unit suite does not support -ScriptBlock or -Command.'
            }
            InvokeCIEMPesterSuite -Suite Unit -Environment $Environment -Path $Path -Name $Name -Tag $Tag -Output $Output
        }
        'E2E' {
            if ($ScriptBlock -and $Command) {
                throw 'Specify only one of -ScriptBlock or -Command.'
            }

            $e2eScriptBlock = $ScriptBlock
            if ($Command) {
                $e2eScriptBlock = [scriptblock]::Create($Command)
            }

            if ($e2eScriptBlock) {
                if ($Path -or $Name -or $Tag) {
                    throw 'E2E command validation does not support -Path, -Name, or -Tag.'
                }
                InvokeCIEME2ECommand -Environment $Environment -ScriptBlock $e2eScriptBlock -TimeoutSeconds $TimeoutSeconds
            }
            else {
                InvokeCIEMPesterSuite -Suite E2E -Environment $Environment -Path $Path -Name $Name -Tag $Tag -Output $Output
            }
        }
        'Playwright' {
            if ($ScriptBlock -or $Command) {
                throw 'Playwright suite does not support -ScriptBlock or -Command.'
            }
            InvokeCIEMPlaywrightSuite -Environment $Environment -Path $Path -Name $Name -Tag $Tag
        }
    }
}
