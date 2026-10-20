#!/usr/bin/env bash
# Bootstraps the Terraform remote state backend in Azure.
# Run once per subscription, before any terraform init.
# Usage: bash scripts/bootstrap-tfstate.sh <subscription-id> <region>
set -euo pipefail

SUBSCRIPTION_ID="${1:?subscription-id required}"
REGION="${2:?region required}"

RG_NAME="rg-tfstate-shoplite"
SA_NAME="tfstateshoplite$(echo $SUBSCRIPTION_ID | tr -d '-' | cut -c1-8)"
CONTAINER_NAME="tfstate"
OWNER_TAG="pavan"

echo "==> Setting subscription"
az account set --subscription "$SUBSCRIPTION_ID"

echo "==> Creating resource group: $RG_NAME"
az group create \
  --name "$RG_NAME" \
  --location "$REGION" \
  --tags owner="$OWNER_TAG" task=1 env=shared

echo "==> Creating storage account: $SA_NAME"
az storage account create \
  --name "$SA_NAME" \
  --resource-group "$RG_NAME" \
  --location "$REGION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --tags owner="$OWNER_TAG" task=1 env=shared

echo "==> Creating blob container: $CONTAINER_NAME"
az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$SA_NAME" \
  --auth-mode login

echo ""
echo "==> Done! Add this backend block to infra/envs/staging/main.tf and infra/envs/prod/main.tf:"
echo ""
echo 'terraform {'
echo '  backend "azurerm" {'
echo "    resource_group_name  = \"$RG_NAME\""
echo "    storage_account_name = \"$SA_NAME\""
echo "    container_name       = \"$CONTAINER_NAME\""
echo '    key                  = "staging.tfstate"  # change to prod.tfstate for prod'
echo '  }'
echo '}'
