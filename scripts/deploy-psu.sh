#!/usr/bin/env bash
# Deploy the Azure PSU host through Devolutions.CIEM.Admin.

set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
# shellcheck disable=SC1091
. "$REPO_ROOT/scripts/lib/log.sh"

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --resource-group  Azure resource group [default: devolutions-ciem-rg]
  --site-name       Azure Web App name [default: devolutions-ciem-psu]
  --tier            App Service tier [default: S1]
  --version         PSU version [default: 5.5.4]
  --location        Azure region [default: westus2]
  --help            Show this help
EOF
}

RESOURCE_GROUP="devolutions-ciem-rg"
SITE_NAME="devolutions-ciem-psu"
LOCATION="westus2"
TIER="S1"
PSU_VERSION="5.5.4"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --resource-group) RESOURCE_GROUP="$2"; shift 2 ;;
        --site-name) SITE_NAME="$2"; shift 2 ;;
        --tier) TIER="$2"; shift 2 ;;
        --version) PSU_VERSION="$2"; shift 2 ;;
        --location) LOCATION="$2"; shift 2 ;;
        --help) usage; exit 0 ;;
        *) log_error "unknown option: $1"; usage >&2; exit 2 ;;
    esac
done

log_info "starting deploy-psu.sh"
log_info "selected resource group: $RESOURCE_GROUP"
log_info "selected site name: $SITE_NAME"
log_info "selected location: $LOCATION"
log_info "selected tier: $TIER"
log_info "selected PSU version: $PSU_VERSION"

echo "=== PSU Deployment ==="
echo "Resource Group: $RESOURCE_GROUP"
echo "Site Name:      $SITE_NAME"
echo "Location:       $LOCATION"
echo "Tier:           $TIER"
echo "PSU Version:    $PSU_VERSION"
echo ""

log_info "pwsh Deploy-CIEMPSUInstance (site=$SITE_NAME)"
# shellcheck disable=SC2016
CIEM_REPO_ROOT="$REPO_ROOT" \
CIEM_RESOURCE_GROUP="$RESOURCE_GROUP" \
CIEM_SITE_NAME="$SITE_NAME" \
CIEM_LOCATION="$LOCATION" \
CIEM_TIER="$TIER" \
CIEM_PSU_VERSION="$PSU_VERSION" \
pwsh -NoProfile -Command '
$ErrorActionPreference = "Stop"
Import-Module (Join-Path $env:CIEM_REPO_ROOT "Devolutions.CIEM.Admin/Devolutions.CIEM.Admin.psd1")
Deploy-CIEMPSUInstance `
    -ResourceGroup $env:CIEM_RESOURCE_GROUP `
    -SiteName $env:CIEM_SITE_NAME `
    -Location $env:CIEM_LOCATION `
    -ServicePlanPricingTier $env:CIEM_TIER `
    -PsuVersion $env:CIEM_PSU_VERSION
'
log_info "pwsh Deploy-CIEMPSUInstance completed"

log_info "done"
