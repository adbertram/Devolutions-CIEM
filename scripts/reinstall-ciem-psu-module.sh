#!/usr/bin/env bash
# Remove CIEM from a PSU target, then install the latest published Gallery module.

set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lib/log.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --environment local|azure  PSU target to reinstall [default: local]
  --module-path PATH         CIEM PSU module source path [default: <repo>/psu-app]
  --env-file PATH            .env file for PSU connection settings
  --validate-deployment      Bootstrap and validate CIEM after installing
  --what-if                  Show PowerShell WhatIf output without changing PSU resources
  --help                     Show this help
EOF
}

ENVIRONMENT="local"
MODULE_PATH="$REPO_ROOT/psu-app"
ENV_FILE_PATH=""
VALIDATE_DEPLOYMENT=0
WHAT_IF=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --module-path)
            MODULE_PATH="$2"
            shift 2
            ;;
        --env-file)
            ENV_FILE_PATH="$2"
            shift 2
            ;;
        --validate-deployment)
            VALIDATE_DEPLOYMENT=1
            shift
            ;;
        --what-if)
            WHAT_IF=1
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            log_error "unknown option: $1"
            usage >&2
            exit 2
            ;;
    esac
done

case "$ENVIRONMENT" in
    local|azure) ;;
    *)
        log_error "environment must be local or azure: $ENVIRONMENT"
        usage >&2
        exit 2
        ;;
esac

log_info "starting reinstall-ciem-psu-module.sh"
log_info "selected environment: $ENVIRONMENT"
log_info "selected module path: $MODULE_PATH"
if [[ -n "$ENV_FILE_PATH" ]]; then
    log_info "selected env file: $ENV_FILE_PATH"
fi
log_info "selected validate deployment: $VALIDATE_DEPLOYMENT"
log_info "selected what-if: $WHAT_IF"

echo "=== CIEM PSU Module Reinstall ==="
echo "Environment: $ENVIRONMENT"
echo "Module path:  $MODULE_PATH"
if [[ -n "$ENV_FILE_PATH" ]]; then
    echo "Env file:     $ENV_FILE_PATH"
fi
echo ""

if [[ "$VALIDATE_DEPLOYMENT" -eq 1 ]]; then
    log_info "pwsh PowerShell Gallery compatibility preflight"
    CIEM_MODULE_PATH="$MODULE_PATH" \
    pwsh -NoProfile -Command '
$ErrorActionPreference = "Stop"

$modulePath = Resolve-Path -Path $env:CIEM_MODULE_PATH -ErrorAction Stop | Select-Object -ExpandProperty Path
$manifestFile = Get-ChildItem -Path $modulePath -Filter "*.psd1" -File | Select-Object -First 1
if (-not $manifestFile) {
    throw "No .psd1 manifest found in: $modulePath"
}

$moduleName = $manifestFile.BaseName
$manifest = Import-PowerShellDataFile -Path $manifestFile.FullName
$localVersion = [version]$manifest.ModuleVersion
$publishedModule = Find-Module -Name $moduleName -ErrorAction Stop
$publishedVersion = [version]([string]$publishedModule.Version -replace "-.*$", "")

if ($publishedVersion -lt $localVersion) {
    throw "Latest PowerShell Gallery module ''$moduleName'' is $publishedVersion, but local validation requires $localVersion. Publish $localVersion or newer before running --validate-deployment."
}

[pscustomobject]@{
    ModuleName              = $moduleName
    LocalValidationVersion  = $localVersion
    PublishedGalleryVersion = $publishedVersion
    Status                  = "Compatible"
}
'
    log_info "pwsh PowerShell Gallery compatibility preflight completed"
fi

log_info "pwsh Remove-CIEMPSUModule (environment=$ENVIRONMENT)"
# shellcheck disable=SC2016
CIEM_REPO_ROOT="$REPO_ROOT" \
CIEM_TARGET_ENVIRONMENT="$ENVIRONMENT" \
CIEM_MODULE_PATH="$MODULE_PATH" \
CIEM_ENV_FILE_PATH="$ENV_FILE_PATH" \
CIEM_WHAT_IF="$WHAT_IF" \
pwsh -NoProfile -Command '
$ErrorActionPreference = "Stop"
Import-Module (Join-Path $env:CIEM_REPO_ROOT "Devolutions.CIEM.Admin/Devolutions.CIEM.Admin.psd1")

[ValidateSet("local", "azure")]
[string]$Environment = $env:CIEM_TARGET_ENVIRONMENT

$removeParams = @{
    Environment = $Environment
    ModulePath  = $env:CIEM_MODULE_PATH
    Force       = $true
}
if ($env:CIEM_ENV_FILE_PATH) {
    $removeParams.EnvFilePath = $env:CIEM_ENV_FILE_PATH
}
if ($env:CIEM_WHAT_IF -eq "1") {
    $removeParams.WhatIf = $true
}

Remove-CIEMPSUModule @removeParams
'
log_info "pwsh Remove-CIEMPSUModule completed"

log_info "pwsh Publish-PSUModule InstallPublishedVersion (environment=$ENVIRONMENT)"
# shellcheck disable=SC2016
CIEM_REPO_ROOT="$REPO_ROOT" \
CIEM_TARGET_ENVIRONMENT="$ENVIRONMENT" \
CIEM_MODULE_PATH="$MODULE_PATH" \
CIEM_ENV_FILE_PATH="$ENV_FILE_PATH" \
CIEM_VALIDATE_DEPLOYMENT="$VALIDATE_DEPLOYMENT" \
CIEM_WHAT_IF="$WHAT_IF" \
pwsh -NoProfile -Command '
$ErrorActionPreference = "Stop"
Import-Module (Join-Path $env:CIEM_REPO_ROOT "Devolutions.CIEM.Admin/Devolutions.CIEM.Admin.psd1")

[ValidateSet("local", "azure")]
[string]$Environment = $env:CIEM_TARGET_ENVIRONMENT

$connectParams = @{}
if ($env:CIEM_ENV_FILE_PATH) {
    $connectParams.EnvFilePath = $env:CIEM_ENV_FILE_PATH
}
if ($Environment -eq "local") {
    $connectParams.Local = $true
}
elseif ($Environment -eq "azure") {
    $connectParams.Azure = $true
}
Connect-PSU @connectParams | Out-Null

$publishParams = @{
    ModulePath               = $env:CIEM_MODULE_PATH
    InstallPublishedVersion  = $true
}
if ($env:CIEM_ENV_FILE_PATH) {
    $publishParams.EnvFilePath = $env:CIEM_ENV_FILE_PATH
}
if ($env:CIEM_VALIDATE_DEPLOYMENT -eq "1") {
    $publishParams.ValidateDeployment = $true
}
if ($env:CIEM_WHAT_IF -eq "1") {
    $publishParams.WhatIf = $true
}

Publish-PSUModule @publishParams
'
log_info "pwsh Publish-PSUModule InstallPublishedVersion completed"

log_info "done"
