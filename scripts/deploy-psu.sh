#!/bin/bash
set -euo pipefail

# Deploy PSU to Azure
# Usage: ./scripts/deploy-psu.sh [--tier S1] [--version 5.5.4] [--location westus2]

# Defaults
RESOURCE_GROUP="devolutions-ciem-rg"
SITE_NAME="devolutions-ciem-psu"
LOCATION="westus2"
TIER="S1"
PSU_VERSION="5.5.4"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --tier) TIER="$2"; shift 2 ;;
        --version) PSU_VERSION="$2"; shift 2 ;;
        --location) LOCATION="$2"; shift 2 ;;
        --help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --tier      App Service tier (B1, S1, P1V2, etc.) [default: S1]"
            echo "  --version   PSU version [default: 5.5.4]"
            echo "  --location  Azure region [default: westus2]"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo "=== PSU Deployment ==="
echo "Resource Group: $RESOURCE_GROUP"
echo "Site Name:      $SITE_NAME"
echo "Location:       $LOCATION"
echo "Tier:           $TIER"
echo "PSU Version:    $PSU_VERSION"
echo ""

# Check Azure CLI login
echo "Checking Azure login..."
if ! az account show &>/dev/null; then
    echo "ERROR: Not logged in to Azure. Run 'az login' first."
    exit 1
fi

SUBSCRIPTION=$(az account show --query name -o tsv)
echo "Using subscription: $SUBSCRIPTION"
echo ""

# Create resource group
echo "Creating resource group..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" -o none

# Generate JWT signing key
echo "Generating JWT signing key..."
JWT_KEY=$(openssl rand -base64 48 | tr -d '\n')

# Deploy Bicep template
echo "Deploying PSU..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/../deploy/psu_standalone.bicep"

if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo "ERROR: Bicep template not found at $TEMPLATE_FILE"
    exit 1
fi

az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file "$TEMPLATE_FILE" \
    --parameters \
        siteName="$SITE_NAME" \
        version="$PSU_VERSION" \
        servicePlanPricingTier="$TIER" \
        jwtSigningKey="$JWT_KEY" \
    -o none

echo "Deployment complete."
echo ""

# Get the URL
APP_URL="https://${SITE_NAME}.azurewebsites.net"
echo "PSU URL: $APP_URL"
echo ""

# Wait for PSU to be healthy
echo "Waiting for PSU to start (this may take 2-3 minutes)..."
MAX_ATTEMPTS=30
ATTEMPT=0

while [[ $ATTEMPT -lt $MAX_ATTEMPTS ]]; do
    ATTEMPT=$((ATTEMPT + 1))
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$APP_URL" 2>/dev/null || echo "000")

    if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "302" ]]; then
        echo "PSU is ready! (HTTP $HTTP_CODE)"
        break
    fi

    echo "  Attempt $ATTEMPT/$MAX_ATTEMPTS: HTTP $HTTP_CODE (waiting 10s...)"
    sleep 10
done

if [[ $ATTEMPT -eq $MAX_ATTEMPTS ]]; then
    echo "WARNING: PSU may not be fully ready. Check manually at $APP_URL"
fi

echo ""
echo "=== Deployment Summary ==="
echo "URL:            $APP_URL"
echo "Resource Group: $RESOURCE_GROUP"
echo "Tier:           $TIER"
echo "PSU Version:    $PSU_VERSION"
echo ""
echo "Next steps:"
echo "  1. Open $APP_URL in a browser"
echo "  2. Create an admin account on first access"
echo "  3. Import Devolutions.CIEM module from PowerShell Gallery"
echo ""
echo "To update .env with PSU URL:"
echo "  echo 'PSU_URL=$APP_URL' >> .env"
