SUBSCRIPTION_ID := 3e4b93a6-966a-4d17-af62-540ffd96a13c
REGION          := germanywestcentral

STAGING_DIR := infra/envs/staging
PROD_DIR    := infra/envs/prod

.PHONY: help bootstrap init init-staging init-prod \
        plan plan-staging plan-prod \
        apply-staging apply-prod up down down-staging down-prod \
        kubeconfig-staging kubeconfig-prod

help:
	@echo ""
	@echo "ShopLite platform — one-command targets"
	@echo ""
	@echo "  bootstrap          Create Terraform remote-state storage account (run once)"
	@echo ""
	@echo "  init               terraform init in both env dirs"
	@echo "  init-staging       terraform init in staging only"
	@echo "  init-prod          terraform init in prod only"
	@echo ""
	@echo "  plan               terraform plan in both envs (preview, no changes)"
	@echo "  plan-staging       terraform plan staging only"
	@echo "  plan-prod          terraform plan prod only"
	@echo ""
	@echo "  apply-staging      terraform apply staging"
	@echo "  apply-prod         terraform apply prod"
	@echo "  up                 Apply staging, then prod (full bring-up)"
	@echo ""
	@echo "  down-staging       Destroy staging only"
	@echo "  down-prod          Destroy prod only"
	@echo "  down               Destroy both envs (prod first, then staging)"
	@echo ""
	@echo "  kubeconfig-staging Merge staging AKS creds into ~/.kube/config"
	@echo "  kubeconfig-prod    Merge prod AKS creds into ~/.kube/config"
	@echo ""

# ---------------------------------------------------------------------------
# Bootstrap — run once per subscription to create tfstate storage.
# ---------------------------------------------------------------------------
bootstrap:
	@bash scripts/bootstrap-tfstate.sh $(SUBSCRIPTION_ID) $(REGION)

# ---------------------------------------------------------------------------
# init
# ---------------------------------------------------------------------------
init: init-staging init-prod

init-staging:
	cd $(STAGING_DIR) && terraform init

init-prod:
	cd $(PROD_DIR) && terraform init

# ---------------------------------------------------------------------------
# plan — read-only. Safe to run anytime.
# ---------------------------------------------------------------------------
plan: plan-staging plan-prod

plan-staging:
	cd $(STAGING_DIR) && terraform plan

plan-prod:
	cd $(PROD_DIR) && terraform plan

# ---------------------------------------------------------------------------
# apply — writes to Azure. Interactive (requires typing "yes").
# ---------------------------------------------------------------------------
apply-staging:
	cd $(STAGING_DIR) && terraform apply

apply-prod:
	cd $(PROD_DIR) && terraform apply

# Full bring-up: staging first, then prod. If staging fails, prod does not run.
up: apply-staging apply-prod

# ---------------------------------------------------------------------------
# destroy — tears everything down. Interactive. Prod before staging to
# mirror the dependency order (nothing depends across envs, but convention).
# ---------------------------------------------------------------------------
down: down-prod down-staging

down-staging:
	cd $(STAGING_DIR) && terraform destroy

down-prod:
	cd $(PROD_DIR) && terraform destroy

# ---------------------------------------------------------------------------
# kubeconfig — pull AKS creds for kubectl. Uses Entra auth (no admin keys).
# ---------------------------------------------------------------------------
kubeconfig-staging:
	az aks get-credentials \
		--resource-group rg-shoplite-staging \
		--name aks-shoplite-staging \
		--only-show-errors

kubeconfig-prod:
	az aks get-credentials \
		--resource-group rg-shoplite-prod \
		--name aks-shoplite-prod \
		--only-show-errors
