#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Runs a PowerShell command locally or on a PSU instance.

.DESCRIPTION
    Unified test harness for running commands against the Devolutions CIEM module
    in three contexts:

    - local:          Import the module in the current PowerShell process and run
    - local_psu_app:  Run on the local PSU instance via Invoke-PSUCommand
    - azure_psu_app:  Run on the Azure PSU instance via Invoke-PSUCommand

    For PSU destinations, handles Connect-PSU and formats the output.
    For local, imports the module fresh and executes the scriptblock directly.

.PARAMETER ScriptBlock
    The PowerShell code to execute.

.PARAMETER Destination
    Where to run the command: local, local_psu_app, or azure_psu_app.

.PARAMETER TimeoutSeconds
    Maximum wait time for PSU commands. Defaults to 120.

.EXAMPLE
    ./scripts/Invoke-TestCommand.ps1 -ScriptBlock { Get-CIEMProvider } -Destination local

.EXAMPLE
    ./scripts/Invoke-TestCommand.ps1 -ScriptBlock { Get-Module Devolutions.CIEM | Select-Object Version } -Destination local_psu_app

.EXAMPLE
    ./scripts/Invoke-TestCommand.ps1 -ScriptBlock { Invoke-CIEMScan -Service Entra -Verbose } -Destination azure_psu_app
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [scriptblock]$ScriptBlock,

    [Parameter(Mandatory)]
    [ValidateSet('local', 'local_psu_app', 'azure_psu_app')]
    [string]$Destination,

    [Parameter()]
    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'

$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) { $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }
$repoRoot = Split-Path -Parent $scriptRoot

switch ($Destination) {
    'local' {
        Write-Host "[local] Importing module..." -ForegroundColor Cyan
        Import-Module (Join-Path $repoRoot 'PSUSQLite') -Force -ErrorAction Stop
        Import-Module (Join-Path $repoRoot 'Devolutions.CIEM.Base') -Force -ErrorAction Stop
        Import-Module (Join-Path $repoRoot 'Devolutions.CIEM.Graph') -Force -ErrorAction Stop
        Import-Module (Join-Path $repoRoot 'Devolutions.CIEM.Checks') -Force -ErrorAction Stop
        Write-Host "[local] Executing scriptblock..." -ForegroundColor Cyan
        & $ScriptBlock
    }

    'local_psu_app' {
        Write-Host "[local_psu_app] Connecting to local PSU..." -ForegroundColor Cyan
        Import-Module (Join-Path $scriptRoot 'PSUniversal.psm1') -Force -ErrorAction Stop
        Connect-PSU -Local
        Write-Host "[local_psu_app] Executing on local PSU..." -ForegroundColor Cyan
        Invoke-PSUCommand -ScriptBlock $ScriptBlock -TimeoutSeconds $TimeoutSeconds
    }

    'azure_psu_app' {
        Write-Host "[azure_psu_app] Connecting to Azure PSU..." -ForegroundColor Cyan
        Import-Module (Join-Path $scriptRoot 'PSUniversal.psm1') -Force -ErrorAction Stop
        Connect-PSU
        Write-Host "[azure_psu_app] Executing on Azure PSU..." -ForegroundColor Cyan
        Invoke-PSUCommand -ScriptBlock $ScriptBlock -TimeoutSeconds $TimeoutSeconds
    }
}
