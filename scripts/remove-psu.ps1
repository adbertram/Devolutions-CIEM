<#
.SYNOPSIS
    Removes CIEM from a PSU target.

.DESCRIPTION
    Thin entrypoint for Remove-CIEMPSUModule in Devolutions.CIEM.Admin.

.EXAMPLE
    ./scripts/remove-psu.ps1 -Environment azure -Force

.EXAMPLE
    ./scripts/remove-psu.ps1 -Environment local -Force
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter()]
    [ValidateSet('local', 'azure')]
    [string]$Environment,

    [Parameter()]
    [string]$ModuleName,

    [Parameter()]
    [string]$ModulePath,

    [Parameter()]
    [string]$AdminModulePath,

    [Parameter()]
    [string]$EnvFilePath,

    [Parameter()]
    [string]$Url,

    [Parameter()]
    [string]$Token,

    [Parameter()]
    [string]$ResourceGroup,

    [Parameter()]
    [string]$WebAppName,

    [Parameter()]
    [string]$Version,

    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

if (-not $PSBoundParameters.ContainsKey('Environment')) {
    throw 'scripts/remove-psu.ps1 requires -Environment local or -Environment azure.'
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$adminManifest = if ($PSBoundParameters.ContainsKey('AdminModulePath')) {
    $AdminModulePath
}
else {
    Join-Path $repoRoot 'Devolutions.CIEM.Admin/Devolutions.CIEM.Admin.psd1'
}

Import-Module $adminManifest -ErrorAction Stop

$removeParams = @{}
foreach ($parameterName in @(
        'Environment'
        'ModuleName'
        'ModulePath'
        'EnvFilePath'
        'Url'
        'Token'
        'ResourceGroup'
        'WebAppName'
        'Version'
    )) {
    if ($PSBoundParameters.ContainsKey($parameterName)) {
        $removeParams[$parameterName] = Get-Variable -Name $parameterName -ValueOnly
    }
}
if ($Force) {
    $removeParams.Force = $true
}
if ($WhatIfPreference) {
    $removeParams.WhatIf = $true
}

Remove-CIEMPSUModule @removeParams
