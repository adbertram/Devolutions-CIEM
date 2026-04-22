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

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$adminManifest = Join-Path $repoRoot 'Devolutions.CIEM.Admin/Devolutions.CIEM.Admin.psd1'

Import-Module $adminManifest
Invoke-CIEMTest @PSBoundParameters
